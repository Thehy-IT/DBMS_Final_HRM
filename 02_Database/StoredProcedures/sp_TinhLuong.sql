-- ============================================================
-- FILE       : sp_TinhLuong.sql
-- PROJECT    : Hệ Thống Quản Lý Nhân Sự & Tính Lương Tự Động
-- MỤC ĐÍCH   : Stored Procedure cốt lõi — tính lương tự động
--              toàn bộ nhân viên cho 1 kỳ lương (tháng/năm)
--
-- CÁCH GỌI:
--   EXEC sp_TinhLuong 3, 2025              -- Tính lương T3/2025 tất cả NV
--   EXEC sp_TinhLuong 3, 2025, 'NV000001' -- Tính riêng 1 NV
--   EXEC sp_TinhLuong 3, 2025, NULL, 1    -- Tính lại (ghi đè bản nháp)
--
-- PIPELINE 8 BƯỚC CHO MỖI NHÂN VIÊN:
--   A → Validate đầu vào & guard CHOT
--   B → Lấy danh sách NV active kỳ đó
--   C → Lấy HopDong & LuongCoBan hiệu lực
--   D → Tính ngày công (fn_SoNgayChamCong, fn_HeSoLuongThang)
--   E → Tính phụ cấp (NhanVienPhucLoi × LoaiPhucLoi)
--   F → Tính BH (fn_TinhBHXH_TVF) + Thuế (fn_TinhThueTNCN_Scalar)
--   G → Tổng hợp khấu trừ khác (KhauTru)
--   H → INSERT BangLuong + ChiTietLuong + ThueTNCN
--
-- DEPENDENCY:
--   fn_TinhThueTNCN.sql  fn_TinhBHXH.sql  fn_SoNgayLamViec.sql
--   seed_data.sql (dữ liệu ChamCong, HopDong, LuongCoBan...)
-- ============================================================

USE HRPayrollDB;
GO

IF OBJECT_ID('dbo.sp_TinhLuong', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_TinhLuong;
GO

CREATE PROCEDURE dbo.sp_TinhLuong
    @Thang          TINYINT,
    @Nam            SMALLINT,
    @MaNV_Filter    NCHAR(10)   = NULL,  -- NULL = tất cả NV
    @Override       BIT         = 0,     -- 1 = ghi đè bản nháp cũ
    @DryRun         BIT         = 0      -- 1 = chỉ xem kết quả, không ghi DB
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    -- ══════════════════════════════════════════════════════
    -- KHAI BÁO BIẾN TOÀN CỤC
    -- ══════════════════════════════════════════════════════
    DECLARE
        -- Điều hướng
        @NgayDauThang       DATE,
        @NgayCuoiThang      DATE,
        @NgayChuanThang     TINYINT,
        @ThoiGianBatDau     DATETIME    = GETDATE(),
        @SoNVXuLy           INT         = 0,
        @SoNVThanhCong      INT         = 0,
        @SoNVLoiToi         INT         = 0,
        @TongQuyLuong       DECIMAL(18,2) = 0,
        @ErrMsg             NVARCHAR(500),

        -- Biến từng NV (dùng trong CURSOR)
        @cur_MaNV           NCHAR(10),
        @cur_HoTen          NVARCHAR(100),
        @cur_TrangThaiNV    NCHAR(1),
        @cur_SoNguoiPT      TINYINT,

        -- Hợp đồng
        @cur_MaLoaiHD       TINYINT,
        @cur_LuongHD        DECIMAL(18,2),
        @cur_VungLuong      TINYINT,

        -- Lương cơ bản
        @cur_LuongCB        DECIMAL(18,2),
        @cur_LuongDongBH    DECIMAL(18,2),

        -- Ngày công
        @cur_NgayDiLam      DECIMAL(5,1),
        @cur_NgayNghiCL     DECIMAL(5,1),
        @cur_NgayKhongPhep  DECIMAL(5,1),
        @cur_HeSoLuong      DECIMAL(10,6),

        -- Lương tính toán
        @cur_LuongTheoNgay  DECIMAL(18,2),
        @cur_LuongLamThem   DECIMAL(18,2),
        @cur_TongPhuCap     DECIMAL(18,2),
        @cur_PhuCapChiuThue DECIMAL(18,2),
        @cur_LuongGross     DECIMAL(18,2),

        -- Bảo hiểm NLĐ
        @cur_BHXH_NLD       DECIMAL(18,2),
        @cur_BHYT_NLD       DECIMAL(18,2),
        @cur_BHTN_NLD       DECIMAL(18,2),
        @cur_TongBH_NLD     DECIMAL(18,2),

        -- Bảo hiểm NSDLĐ (chi phí DN)
        @cur_TongBH_NSDLD   DECIMAL(18,2),

        -- Thuế TNCN
        @cur_GiamTruBT      DECIMAL(18,2),
        @cur_GiamTruPT      DECIMAL(18,2),
        @cur_ThuNhapTT      DECIMAL(18,2),
        @cur_ThueTNCN       DECIMAL(18,2),
        @cur_BacThue        TINYINT,

        -- Khấu trừ khác
        @cur_TongKhauTru    DECIMAL(18,2),

        -- Kết quả
        @cur_LuongNet       DECIMAL(18,2),
        @cur_MaBL           BIGINT,

        -- Phụ cấp từng dòng (dùng khi INSERT ChiTietLuong)
        @pc_MaFL            NCHAR(10),
        @pc_TenFL           NVARCHAR(100),
        @pc_GiaTri          DECIMAL(18,2),
        @pc_LoaiGiaTri      CHAR(1),
        @pc_CoTinhThue      BIT;

    -- ══════════════════════════════════════════════════════
    -- BƯỚC A — VALIDATE ĐẦU VÀO
    -- ══════════════════════════════════════════════════════
    IF @Thang NOT BETWEEN 1 AND 12
    BEGIN
        RAISERROR(N'sp_TinhLuong: @Thang phải từ 1 đến 12.', 16, 1);
        RETURN -1;
    END;

    IF @Nam NOT BETWEEN 2000 AND 2100
    BEGIN
        RAISERROR(N'sp_TinhLuong: @Nam phải từ 2000 đến 2100.', 16, 1);
        RETURN -1;
    END;

    IF DATEFROMPARTS(@Nam, @Thang, 1) > CAST(GETDATE() AS DATE)
    BEGIN
        RAISERROR(N'sp_TinhLuong: Không thể tính lương cho kỳ tương lai.', 16, 1);
        RETURN -1;
    END;

    SET @NgayDauThang   = DATEFROMPARTS(@Nam, @Thang, 1);
    SET @NgayCuoiThang  = EOMONTH(@NgayDauThang);
    SET @NgayChuanThang = dbo.fn_SoNgayChuanThang(@Thang, @Nam);

    -- Guard: kiểm tra bảng lương đã CHOT chưa
    IF EXISTS (
        SELECT 1 FROM dbo.BangLuong
        WHERE Thang     = @Thang
          AND Nam       = @Nam
          AND TrangThai IN ('C','P','L')   -- Confirmed, Paid, Locked
          AND (@MaNV_Filter IS NULL OR MaNV = @MaNV_Filter)
    )
    BEGIN
        IF @Override = 0
        BEGIN
            RAISERROR(
                N'sp_TinhLuong: Bảng lương T%d/%d đã CHOT. Dùng @Override=1 để tính lại bản nháp.',
                16, 1, @Thang, @Nam
            );
            RETURN -2;
        END;
        -- Override = 1: xoá bản nháp cũ (chỉ NHAP = 'D')
        DELETE FROM dbo.ChiTietLuong
        WHERE MaBL IN (
            SELECT MaBL FROM dbo.BangLuong
            WHERE Thang = @Thang AND Nam = @Nam
              AND TrangThai = 'D'
              AND (@MaNV_Filter IS NULL OR MaNV = @MaNV_Filter)
        );
        DELETE FROM dbo.ThueTNCN
        WHERE Thang = @Thang AND Nam = @Nam
          AND (@MaNV_Filter IS NULL OR MaNV = @MaNV_Filter);

        DELETE FROM dbo.BangLuong
        WHERE Thang = @Thang AND Nam = @Nam AND TrangThai = 'D'
          AND (@MaNV_Filter IS NULL OR MaNV = @MaNV_Filter);
    END;

    PRINT N'════════════════════════════════════════════════════════';
    PRINT N'  sp_TinhLuong — Kỳ ' + CAST(@Thang AS NVARCHAR) + N'/' + CAST(@Nam AS NVARCHAR);
    PRINT N'  Ngày chuẩn tháng: ' + CAST(@NgayChuanThang AS NVARCHAR) + N' ngày';
    PRINT N'════════════════════════════════════════════════════════';

    IF @DryRun = 1
        PRINT N'  [DRY RUN] — Không ghi vào database';

    -- ══════════════════════════════════════════════════════
    -- BƯỚC B — DANH SÁCH NHÂN VIÊN CẦN TÍNH LƯƠNG
    -- Điều kiện: Active hoặc Probation, vào làm trước cuối tháng,
    --            chưa nghỉ việc hoặc nghỉ sau đầu tháng
    -- ══════════════════════════════════════════════════════
    DECLARE cur_NhanVien CURSOR LOCAL FAST_FORWARD FOR
        SELECT
            nv.MaNV,
            nv.HoTen,
            nv.TrangThai,
            nv.SoNguoiPhuThuoc
        FROM dbo.NhanVien nv
        WHERE nv.TrangThai IN ('A', 'P')     -- Active, Probation
          AND nv.NgayVaoLam   <= @NgayCuoiThang
          AND (nv.NgayNghiViec IS NULL OR nv.NgayNghiViec > @NgayDauThang)
          AND (@MaNV_Filter IS NULL OR nv.MaNV = @MaNV_Filter)
        ORDER BY nv.MaNV;

    -- ══════════════════════════════════════════════════════
    -- BƯỚC C → H — XỬ LÝ TỪNG NHÂN VIÊN
    -- ══════════════════════════════════════════════════════
    OPEN cur_NhanVien;
    FETCH NEXT FROM cur_NhanVien
        INTO @cur_MaNV, @cur_HoTen, @cur_TrangThaiNV, @cur_SoNguoiPT;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @SoNVXuLy = @SoNVXuLy + 1;

        BEGIN TRY
            BEGIN TRANSACTION;

            -- ── C.1: Lấy Hợp Đồng đang hiệu lực ──────────
            SELECT TOP 1
                @cur_MaLoaiHD   = hd.MaLoaiHD,
                @cur_LuongHD    = hd.LuongCoBan,
                @cur_VungLuong  = hd.VungLuong
            FROM dbo.HopDong hd
            WHERE hd.MaNV       = @cur_MaNV
              AND hd.TrangThai  = 'A'
              AND hd.NgayBatDau <= @NgayCuoiThang
              AND (hd.NgayKetThuc IS NULL OR hd.NgayKetThuc >= @NgayDauThang)
            ORDER BY hd.NgayBatDau DESC;

            IF @cur_MaLoaiHD IS NULL
            BEGIN
                PRINT N'  [SKIP] ' + @cur_MaNV + N' — Không có HĐ hiệu lực';
                IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
                SET @SoNVLoiToi = @SoNVLoiToi + 1;
                GOTO NextEmployee;
            END;

            -- ── C.2: Lấy Lương Cơ Bản hiệu lực ───────────
            SELECT TOP 1
                @cur_LuongCB     = lcb.LuongCB,
                @cur_LuongDongBH = dbo.fn_TinhLuongDongBH(lcb.LuongCB, @cur_MaLoaiHD)
            FROM dbo.LuongCoBan lcb
            WHERE lcb.MaNV       = @cur_MaNV
              AND lcb.NgayHieuLuc <= @NgayCuoiThang
              AND (lcb.NgayHetHieuLuc IS NULL OR lcb.NgayHetHieuLuc >= @NgayDauThang)
            ORDER BY lcb.NgayHieuLuc DESC;

            IF @cur_LuongCB IS NULL
            BEGIN
                PRINT N'  [SKIP] ' + @cur_MaNV + N' — Không có mức lương hiệu lực';
                IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
                SET @SoNVLoiToi = @SoNVLoiToi + 1;
                GOTO NextEmployee;
            END;

            -- ══════════════════════════════════════════════
            -- BƯỚC D — NGÀY CÔNG
            -- ══════════════════════════════════════════════
            SET @cur_NgayDiLam     = dbo.fn_SoNgayChamCong(@cur_MaNV, @Thang, @Nam);
            SET @cur_NgayNghiCL    = dbo.fn_SoNgayNghiCoLuong(@cur_MaNV, @Thang, @Nam);
            SET @cur_NgayKhongPhep = dbo.fn_SoNgayNghiKhongLuong(@cur_MaNV, @Thang, @Nam);
            SET @cur_HeSoLuong     = dbo.fn_HeSoLuongThang(@cur_MaNV, @Thang, @Nam);

            -- Lương theo ngày công thực tế
            -- = LuongCoBan × HeSoLuong (hệ số ≤ 1.0)
            SET @cur_LuongTheoNgay = ROUND(@cur_LuongCB * @cur_HeSoLuong, 0);

            -- Lương làm thêm giờ
            SET @cur_LuongLamThem  = dbo.fn_TinhLuongLamThem(
                                        @cur_MaNV, @Thang, @Nam, @cur_LuongCB);

            -- ══════════════════════════════════════════════
            -- BƯỚC E — PHỤ CẤP (NhanVienPhucLoi × LoaiPhucLoi)
            -- ══════════════════════════════════════════════
            SET @cur_TongPhuCap     = 0;
            SET @cur_PhuCapChiuThue = 0;

            -- Tổng hợp toàn bộ phụ cấp đang active trong kỳ
            SELECT
                @cur_TongPhuCap = @cur_TongPhuCap + SUM(
                    CASE lfl.LoaiGiaTri
                        WHEN 'F' THEN COALESCE(nvfl.GiaTriOverride, lfl.GiaTri)
                        WHEN 'P' THEN ROUND(
                            @cur_LuongCB * COALESCE(nvfl.GiaTriOverride, lfl.GiaTri) / 100.0
                        , 0)
                        ELSE 0
                    END
                ),
                @cur_PhuCapChiuThue = @cur_PhuCapChiuThue + SUM(
                    CASE WHEN lfl.CoTinhThue = 1
                         THEN CASE lfl.LoaiGiaTri
                                WHEN 'F' THEN COALESCE(nvfl.GiaTriOverride, lfl.GiaTri)
                                WHEN 'P' THEN ROUND(@cur_LuongCB
                                              * COALESCE(nvfl.GiaTriOverride,lfl.GiaTri)/100.0, 0)
                                ELSE 0 END
                         ELSE 0 END
                )
            FROM dbo.NhanVienPhucLoi nvfl
            JOIN dbo.LoaiPhucLoi     lfl  ON nvfl.MaFL = lfl.MaFL
            WHERE nvfl.MaNV     = @cur_MaNV
              AND nvfl.IsActive = 1
              AND nvfl.NgayApDung <= @NgayCuoiThang
              AND (nvfl.NgayKetThuc IS NULL OR nvfl.NgayKetThuc >= @NgayDauThang)
              AND lfl.IsActive  = 1;

            -- Đảm bảo không NULL
            SET @cur_TongPhuCap     = ISNULL(@cur_TongPhuCap, 0);
            SET @cur_PhuCapChiuThue = ISNULL(@cur_PhuCapChiuThue, 0);

            -- Lương Gross = LuongTheoNgay + LuongLamThem + TongPhuCap
            SET @cur_LuongGross = @cur_LuongTheoNgay
                                + @cur_LuongLamThem
                                + @cur_TongPhuCap;

            -- ══════════════════════════════════════════════
            -- BƯỚC F.1 — BẢO HIỂM XÃ HỘI (fn_TinhBHXH_TVF)
            -- ══════════════════════════════════════════════
            SELECT
                @cur_BHXH_NLD       = bh.BHXH_NLD,
                @cur_BHYT_NLD       = bh.BHYT_NLD,
                @cur_BHTN_NLD       = bh.BHTN_NLD,
                @cur_TongBH_NLD     = bh.Tong_BH_NLD,
                @cur_TongBH_NSDLD   = bh.Tong_BH_NSDLD
            FROM dbo.fn_TinhBHXH_TVF(@cur_LuongCB, @cur_MaLoaiHD) bh;

            -- ══════════════════════════════════════════════
            -- BƯỚC F.2 — THUẾ TNCN (fn_TinhThueTNCN_Scalar)
            -- ══════════════════════════════════════════════
            SET @cur_GiamTruBT  = 11000000;     -- Giảm trừ bản thân
            SET @cur_GiamTruPT  = dbo.fn_TinhGiamTruPhuThuoc(@cur_SoNguoiPT);

            -- Thu nhập tính thuế:
            -- = LuongTheoNgay + PhuCapChiuThue + LuongLamThem
            --   - BH_NLĐ - GiamTruBanThan - GiamTruPhuThuoc
            SET @cur_ThuNhapTT  =
                @cur_LuongTheoNgay
                + @cur_PhuCapChiuThue
                + @cur_LuongLamThem
                - @cur_TongBH_NLD
                - @cur_GiamTruBT
                - @cur_GiamTruPT;

            -- Không âm
            IF @cur_ThuNhapTT < 0 SET @cur_ThuNhapTT = 0;

            SET @cur_ThueTNCN = dbo.fn_TinhThueTNCN_Scalar(@cur_ThuNhapTT);
            SET @cur_BacThue  = dbo.fn_XacDinhBacThue(@cur_ThuNhapTT);

            -- ══════════════════════════════════════════════
            -- BƯỚC G — KHẤU TRỪ KHÁC (KhauTru Pending)
            -- ══════════════════════════════════════════════
            SELECT @cur_TongKhauTru = ISNULL(SUM(GiaTri), 0)
            FROM dbo.KhauTru
            WHERE MaNV      = @cur_MaNV
              AND Thang      = @Thang
              AND Nam        = @Nam
              AND TrangThai  = 'P';   -- Pending → chờ áp vào lương

            -- ══════════════════════════════════════════════
            -- BƯỚC H — LƯƠNG NET & GHI DATABASE
            -- ══════════════════════════════════════════════
            SET @cur_LuongNet = @cur_LuongGross
                              - @cur_TongBH_NLD
                              - @cur_ThueTNCN
                              - @cur_TongKhauTru;

            -- Đảm bảo lương net không âm (thực tế không thể âm)
            IF @cur_LuongNet < 0 SET @cur_LuongNet = 0;

            -- ── H.1: INSERT / UPDATE BangLuong ────────────
            IF @DryRun = 0
            BEGIN
                INSERT INTO dbo.BangLuong (
                    MaNV, Thang, Nam,
                    SoNgayCong, SoNgayLamChuan,
                    LuongCoBan, LuongGross, TongPhuCap,
                    BHXH_NLD, BHYT_NLD, BHTN_NLD, TongBaoHiem,
                    ThueTNCN, TongKhauTru, LuongNet,
                    TrangThai, NgayTinhLuong, NguoiTao
                )
                VALUES (
                    @cur_MaNV, @Thang, @Nam,
                    @cur_NgayDiLam + @cur_NgayNghiCL,
                    @NgayChuanThang,
                    @cur_LuongTheoNgay, @cur_LuongGross, @cur_TongPhuCap,
                    @cur_BHXH_NLD, @cur_BHYT_NLD, @cur_BHTN_NLD,
                    @cur_TongBH_NLD,
                    @cur_ThueTNCN, @cur_TongKhauTru, @cur_LuongNet,
                    'D',               -- Draft — chờ HR xác nhận
                    GETDATE(),
                    SYSTEM_USER
                );

                SET @cur_MaBL = SCOPE_IDENTITY();

                -- ── H.2: INSERT ChiTietLuong (từng dòng) ──
                -- Lương cơ bản theo ngày công
                INSERT INTO dbo.ChiTietLuong (MaBL, LoaiMuc, TenMuc, GiaTri, GhiChu)
                VALUES (@cur_MaBL, '+', N'Lương cơ bản theo ngày công',
                        @cur_LuongTheoNgay,
                        N'HeSo=' + FORMAT(@cur_HeSoLuong,'P2')
                        + N' | NgayDiLam=' + CAST(@cur_NgayDiLam AS NVARCHAR)
                        + N' | NgayChuan=' + CAST(@NgayChuanThang AS NVARCHAR));

                -- Lương làm thêm giờ (nếu có)
                IF @cur_LuongLamThem > 0
                    INSERT INTO dbo.ChiTietLuong (MaBL, LoaiMuc, TenMuc, GiaTri, GhiChu)
                    VALUES (@cur_MaBL, '+', N'Lương làm thêm giờ',
                            @cur_LuongLamThem, N'Tổng hợp tăng ca trong tháng');

                -- Từng khoản phụ cấp (chi tiết từng FL)
                DECLARE cur_PC CURSOR LOCAL FAST_FORWARD FOR
                    SELECT
                        lfl.MaFL, lfl.TenFL, lfl.LoaiGiaTri,
                        CASE lfl.LoaiGiaTri
                            WHEN 'F' THEN COALESCE(nvfl.GiaTriOverride, lfl.GiaTri)
                            WHEN 'P' THEN ROUND(
                                @cur_LuongCB
                                * COALESCE(nvfl.GiaTriOverride,lfl.GiaTri)/100.0,0)
                            ELSE 0 END
                    FROM dbo.NhanVienPhucLoi nvfl
                    JOIN dbo.LoaiPhucLoi lfl ON nvfl.MaFL = lfl.MaFL
                    WHERE nvfl.MaNV     = @cur_MaNV
                      AND nvfl.IsActive = 1
                      AND nvfl.NgayApDung <= @NgayCuoiThang
                      AND (nvfl.NgayKetThuc IS NULL
                           OR nvfl.NgayKetThuc >= @NgayDauThang)
                      AND lfl.IsActive  = 1;

                OPEN cur_PC;
                FETCH NEXT FROM cur_PC
                    INTO @pc_MaFL, @pc_TenFL, @pc_LoaiGiaTri, @pc_GiaTri;
                WHILE @@FETCH_STATUS = 0
                BEGIN
                    IF @pc_GiaTri > 0
                        INSERT INTO dbo.ChiTietLuong
                            (MaBL, LoaiMuc, TenMuc, GiaTri, GhiChu)
                        VALUES (@cur_MaBL, '+', N'Phụ cấp: ' + @pc_TenFL,
                                @pc_GiaTri, @pc_MaFL);
                    FETCH NEXT FROM cur_PC
                        INTO @pc_MaFL, @pc_TenFL, @pc_LoaiGiaTri, @pc_GiaTri;
                END;
                CLOSE cur_PC;
                DEALLOCATE cur_PC;

                -- BHXH nhân viên đóng (3 dòng)
                IF @cur_BHXH_NLD > 0
                BEGIN
                    INSERT INTO dbo.ChiTietLuong (MaBL,LoaiMuc,TenMuc,GiaTri,GhiChu)
                    VALUES
                        (@cur_MaBL, '-', N'BHXH nhân viên (8%)',
                         @cur_BHXH_NLD,
                         N'Lương đóng BH: ' + FORMAT(@cur_LuongDongBH,'N0')),
                        (@cur_MaBL, '-', N'BHYT nhân viên (1.5%)',
                         @cur_BHYT_NLD, NULL),
                        (@cur_MaBL, '-', N'BHTN nhân viên (1%)',
                         @cur_BHTN_NLD, NULL);
                END;

                -- Thuế TNCN
                IF @cur_ThueTNCN > 0
                    INSERT INTO dbo.ChiTietLuong (MaBL, LoaiMuc, TenMuc, GiaTri, GhiChu)
                    VALUES (@cur_MaBL, '-',
                            N'Thuế TNCN (Bậc ' + CAST(@cur_BacThue AS NVARCHAR) + N')',
                            @cur_ThueTNCN,
                            N'TNCT: ' + FORMAT(@cur_ThuNhapTT,'N0') + N' VNĐ');

                -- Các khoản khấu trừ khác
                DECLARE cur_KT CURSOR LOCAL FAST_FORWARD FOR
                    SELECT LoaiKhauTru, GiaTri, GhiChu
                    FROM   dbo.KhauTru
                    WHERE  MaNV = @cur_MaNV AND Thang = @Thang
                      AND  Nam  = @Nam      AND TrangThai = 'P';

                DECLARE @kt_Loai    NVARCHAR(50),
                        @kt_GiaTri  DECIMAL(18,2),
                        @kt_GhiChu  NVARCHAR(200);

                OPEN cur_KT;
                FETCH NEXT FROM cur_KT INTO @kt_Loai, @kt_GiaTri, @kt_GhiChu;
                WHILE @@FETCH_STATUS = 0
                BEGIN
                    INSERT INTO dbo.ChiTietLuong (MaBL, LoaiMuc, TenMuc, GiaTri, GhiChu)
                    VALUES (@cur_MaBL, '-',
                            N'Khấu trừ: ' + @kt_Loai,
                            @kt_GiaTri, @kt_GhiChu);
                    FETCH NEXT FROM cur_KT INTO @kt_Loai, @kt_GiaTri, @kt_GhiChu;
                END;
                CLOSE cur_KT; DEALLOCATE cur_KT;

                -- ── H.3: INSERT ThueTNCN (bảng chi tiết thuế) ──
                MERGE dbo.ThueTNCN AS tgt
                USING (SELECT @cur_MaNV MaNV, @Thang T, @Nam N) AS src
                      ON tgt.MaNV = src.MaNV AND tgt.Thang = src.T AND tgt.Nam = src.N
                WHEN MATCHED THEN UPDATE SET
                    MaBL                = @cur_MaBL,
                    ThuNhapGross        = @cur_LuongGross,
                    GiamTruBanThan      = @cur_GiamTruBT,
                    SoNguoiPhuThuoc     = @cur_SoNguoiPT,
                    GiamTruPhuThuoc     = @cur_GiamTruPT,
                    TongGiamTru         = @cur_GiamTruBT + @cur_GiamTruPT,
                    ThuNhapChiuThue     = @cur_ThuNhapTT,
                    BacThue             = @cur_BacThue,
                    TienThue            = @cur_ThueTNCN,
                    NgayTinh            = GETDATE()
                WHEN NOT MATCHED THEN INSERT (
                    MaNV, MaBL, Thang, Nam,
                    ThuNhapGross, GiamTruBanThan,
                    SoNguoiPhuThuoc, GiamTruPhuThuoc, TongGiamTru,
                    ThuNhapChiuThue, BacThue, TienThue, NgayTinh
                ) VALUES (
                    @cur_MaNV, @cur_MaBL, @Thang, @Nam,
                    @cur_LuongGross, @cur_GiamTruBT,
                    @cur_SoNguoiPT, @cur_GiamTruPT,
                    @cur_GiamTruBT + @cur_GiamTruPT,
                    @cur_ThuNhapTT, @cur_BacThue, @cur_ThueTNCN, GETDATE()
                );

                -- ── H.4: Đánh dấu KhauTru → Applied ──────
                UPDATE dbo.KhauTru
                SET TrangThai = 'A', MaBL = @cur_MaBL
                WHERE MaNV = @cur_MaNV AND Thang = @Thang
                  AND Nam  = @Nam      AND TrangThai = 'P';

            END; -- END IF DryRun = 0

            COMMIT TRANSACTION;

            SET @SoNVThanhCong = @SoNVThanhCong + 1;
            SET @TongQuyLuong  = @TongQuyLuong + @cur_LuongNet;

            PRINT N'  [OK] ' + @cur_MaNV + N' | '
                + LEFT(@cur_HoTen + REPLICATE(' ',25), 25)
                + N' | Gross: ' + FORMAT(@cur_LuongGross,'N0')
                + N' | BH: '   + FORMAT(@cur_TongBH_NLD,'N0')
                + N' | Thuế: ' + FORMAT(@cur_ThueTNCN,'N0')
                + N' | NET: '  + FORMAT(@cur_LuongNet,'N0');

        END TRY
        BEGIN CATCH
            IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

            SET @SoNVLoiToi = @SoNVLoiToi + 1;
            SET @ErrMsg = ERROR_MESSAGE();
            PRINT N'  [ERR] ' + @cur_MaNV + N' — ' + @ErrMsg;

            -- Ghi log lỗi vào AuditLog (không rollback log)
            BEGIN TRY
                INSERT INTO dbo.AuditLog_Luong (
                    MaNV, HanhDong, TenCot, GiaTriCu, GiaTriMoi
                ) VALUES (
                    @cur_MaNV, 'ERR',
                    N'sp_TinhLuong_' + CAST(@Thang AS NVARCHAR)
                        + '_' + CAST(@Nam AS NVARCHAR),
                    NULL,
                    LEFT(@ErrMsg, 4000)
                );
            END TRY BEGIN CATCH END CATCH;
        END CATCH;

        NextEmployee:
        -- Reset biến cho NV tiếp theo
        SELECT @cur_MaLoaiHD=NULL,@cur_LuongHD=NULL,@cur_LuongCB=NULL,
               @cur_MaBL=NULL,@cur_TongKhauTru=0,@cur_TongPhuCap=0,
               @cur_LuongLamThem=0,@cur_ThueTNCN=0;

        FETCH NEXT FROM cur_NhanVien
            INTO @cur_MaNV, @cur_HoTen, @cur_TrangThaiNV, @cur_SoNguoiPT;
    END; -- WHILE

    CLOSE cur_NhanVien;
    DEALLOCATE cur_NhanVien;

    -- ══════════════════════════════════════════════════════
    -- BÁO CÁO KẾT QUẢ THỰC THI
    -- ══════════════════════════════════════════════════════
    DECLARE @ThoiGianChay INT =
        DATEDIFF(MILLISECOND, @ThoiGianBatDau, GETDATE());

    PRINT N'';
    PRINT N'════════════════════════════════════════════════════════';
    PRINT N'  KẾT QUẢ sp_TinhLuong T'
        + CAST(@Thang AS NVARCHAR) + N'/' + CAST(@Nam AS NVARCHAR);
    PRINT N'────────────────────────────────────────────────────────';
    PRINT N'  Tổng NV xử lý  : ' + CAST(@SoNVXuLy AS NVARCHAR);
    PRINT N'  Thành công      : ' + CAST(@SoNVThanhCong AS NVARCHAR);
    PRINT N'  Lỗi / Bỏ qua   : ' + CAST(@SoNVLoiToi AS NVARCHAR);
    PRINT N'  Tổng lương NET  : ' + FORMAT(@TongQuyLuong, 'N0') + N' VNĐ';
    PRINT N'  Thời gian chạy  : ' + CAST(@ThoiGianChay AS NVARCHAR) + N' ms';
    IF @DryRun = 1
    PRINT N'  *** DRY RUN — Dữ liệu KHÔNG được ghi vào DB ***';
    PRINT N'════════════════════════════════════════════════════════';

    -- Trả về bảng tóm tắt để app có thể đọc
    SELECT
        bl.MaNV,
        nv.HoTen,
        pb.TenPB                                AS PhongBan,
        bl.SoNgayCong,
        bl.SoNgayLamChuan,
        FORMAT(bl.LuongCoBan,   'N0')           AS LuongCoBan,
        FORMAT(bl.TongPhuCap,   'N0')           AS TongPhuCap,
        FORMAT(bl.LuongGross,   'N0')           AS LuongGross,
        FORMAT(bl.TongBaoHiem,  'N0')           AS TongBaoHiem,
        FORMAT(bl.ThueTNCN,     'N0')           AS ThueTNCN,
        FORMAT(bl.TongKhauTru,  'N0')           AS TongKhauTru,
        FORMAT(bl.LuongNet,     'N0')           AS LuongNet,
        bl.TrangThai
    FROM dbo.BangLuong bl
    JOIN dbo.NhanVien  nv ON bl.MaNV = nv.MaNV
    JOIN dbo.PhongBan  pb ON nv.MaPB = pb.MaPB
    WHERE bl.Thang = @Thang AND bl.Nam = @Nam
      AND (@MaNV_Filter IS NULL OR bl.MaNV = @MaNV_Filter)
    ORDER BY pb.TenPB, nv.HoTen;

    RETURN @SoNVThanhCong;
END;
GO

PRINT N'[OK] sp_TinhLuong — tạo thành công';
GO


-- ============================================================
-- sp_XacNhanBangLuong — HR duyệt chuyển Draft → Confirmed
-- ============================================================
IF OBJECT_ID('dbo.sp_XacNhanBangLuong','P') IS NOT NULL
    DROP PROCEDURE dbo.sp_XacNhanBangLuong;
GO

CREATE PROCEDURE dbo.sp_XacNhanBangLuong
    @Thang      TINYINT,
    @Nam        SMALLINT,
    @NguoiDuyet NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (
        SELECT 1 FROM dbo.BangLuong
        WHERE Thang = @Thang AND Nam = @Nam AND TrangThai = 'D'
    )
    BEGIN
        RAISERROR(N'Không có bảng lương nháp T%d/%d để xác nhận.',16,1,@Thang,@Nam);
        RETURN;
    END;

    -- Kiểm tra: không có NV nào lương net < 0
    IF EXISTS (
        SELECT 1 FROM dbo.BangLuong
        WHERE Thang = @Thang AND Nam = @Nam
          AND TrangThai = 'D' AND LuongNet < 0
    )
    BEGIN
        RAISERROR(N'Tồn tại NV có lương NET âm. Kiểm tra lại trước khi xác nhận.',16,1);
        RETURN;
    END;

    BEGIN TRANSACTION;
    BEGIN TRY
        UPDATE dbo.BangLuong
        SET TrangThai   = 'C',                      -- Confirmed
            NgayXacNhan  = GETDATE(),
            NguoiChot    = ISNULL(@NguoiDuyet, SYSTEM_USER)
        WHERE Thang = @Thang AND Nam = @Nam AND TrangThai = 'D';

        DECLARE @SoNV INT = @@ROWCOUNT;
        COMMIT TRANSACTION;

        PRINT N'[OK] Đã xác nhận bảng lương T'
            + CAST(@Thang AS NVARCHAR) + N'/' + CAST(@Nam AS NVARCHAR)
            + N' cho ' + CAST(@SoNV AS NVARCHAR) + N' nhân viên.';
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

PRINT N'[OK] sp_XacNhanBangLuong — tạo thành công';
GO


-- ============================================================
-- DEMO CHẠY THỬ — Uncomment để test
-- ============================================================
/*
-- Tính lương tháng 1/2025 (lần đầu)
EXEC dbo.sp_TinhLuong 1, 2025;

-- Xem chi tiết 1 NV
EXEC dbo.sp_TinhLuong 1, 2025, 'NV000001';

-- Tính lại (override bản nháp)
EXEC dbo.sp_TinhLuong 1, 2025, NULL, 1;

-- Dry run tháng 2 (không ghi DB)
EXEC dbo.sp_TinhLuong 2, 2025, NULL, 0, 1;

-- HR xác nhận bảng lương tháng 1
EXEC dbo.sp_XacNhanBangLuong 1, 2025, N'Hoàng Thị Phương';

-- Xem kết quả bảng lương
SELECT bl.MaNV, nv.HoTen, pb.TenPB,
       FORMAT(bl.LuongCoBan,'N0') LCB,
       FORMAT(bl.LuongGross,'N0') Gross,
       FORMAT(bl.TongBaoHiem,'N0') BH,
       FORMAT(bl.ThueTNCN,'N0') Thue,
       FORMAT(bl.LuongNet,'N0') Net,
       bl.TrangThai
FROM dbo.BangLuong bl
JOIN dbo.NhanVien nv ON bl.MaNV = nv.MaNV
JOIN dbo.PhongBan pb ON nv.MaPB = pb.MaPB
WHERE bl.Thang = 1 AND bl.Nam = 2025
ORDER BY bl.LuongNet DESC;

-- Xem chi tiết lương từng dòng của TGĐ
SELECT LoaiMuc, TenMuc, FORMAT(GiaTri,'N0') GiaTri, GhiChu
FROM dbo.ChiTietLuong
WHERE MaBL = (SELECT TOP 1 MaBL FROM dbo.BangLuong
              WHERE MaNV='NV000001' AND Thang=1 AND Nam=2025);
*/
GO

PRINT N'';
PRINT N'[DONE] sp_TinhLuong.sql hoàn tất.';
PRINT N'Sử dụng: EXEC sp_TinhLuong @Thang, @Nam [,@MaNV] [,@Override] [,@DryRun]';
GO
