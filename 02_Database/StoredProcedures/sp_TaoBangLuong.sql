-- ============================================================
-- FILE       : sp_TaoBangLuong.sql
-- PROJECT    : Hệ Thống Quản Lý Nhân Sự & Tính Lương Tự Động
-- DBMS       : Microsoft SQL Server 2019+
-- MỤC ĐÍCH   : Tạo đầy đủ các bảng lương chính thức, phiếu lương
--              và báo cáo pháp lý theo chuẩn doanh nghiệp Việt Nam
-- ─────────────────────────────────────────────────────────────
-- PROCEDURES :
--   1. sp_TaoBangLuong_ChinhThuc     — Bảng lương tổng hợp đầy đủ
--   2. sp_TaoBangLuong_PhieuLuong    — Phiếu lương chi tiết 1 NV
--   3. sp_TaoBangLuong_BHXH          — Danh sách đóng BHXH tháng
--   4. sp_TaoBangLuong_QuyetToanThue — Dữ liệu quyết toán thuế TNCN
--   5. sp_TaoBangLuong_SoSanh        — So sánh quỹ lương nhiều kỳ
--   6. sp_TaoBangLuong_ChiPhiNhanSu  — Chi phí nhân sự toàn DN
-- ─────────────────────────────────────────────────────────────
-- THỨ TỰ CHẠY:
--   sp_TinhLuong → sp_XacNhanBangLuong → sp_TaoBangLuong_*
-- ============================================================

USE HRPayrollDB;
GO

-- ============================================================
-- SP 1: sp_TaoBangLuong_ChinhThuc
-- ─────────────────────────────────────────────────────────────
-- Tạo bảng lương tổng hợp chính thức cho 1 kỳ tháng.
-- Format chuẩn dùng để ký duyệt + lưu trữ pháp lý.
-- Xuất 2 result sets:
--   RS1: Chi tiết từng nhân viên (tất cả cột thu nhập/khấu trừ)
--   RS2: Tổng hợp theo phòng ban + grand total
-- ============================================================
IF OBJECT_ID('dbo.sp_TaoBangLuong_ChinhThuc','P') IS NOT NULL
    DROP PROCEDURE dbo.sp_TaoBangLuong_ChinhThuc;
GO

CREATE PROCEDURE dbo.sp_TaoBangLuong_ChinhThuc
    @Thang          TINYINT,
    @Nam            SMALLINT,
    @MaPB           NCHAR(10)   = NULL,   -- NULL = tất cả phòng ban
    @TrangThai      NCHAR(1)    = NULL    -- NULL = tất cả trạng thái
AS
BEGIN
    SET NOCOUNT ON;

    -- Kiểm tra tồn tại dữ liệu
    IF NOT EXISTS (
        SELECT 1 FROM dbo.BangLuong
        WHERE Thang = @Thang AND Nam = @Nam
    )
    BEGIN
        RAISERROR(
            N'sp_TaoBangLuong_ChinhThuc: Chưa có dữ liệu bảng lương T%d/%d. '
            + N'Vui lòng chạy sp_TinhLuong trước.',
            16, 1, @Thang, @Nam);
        RETURN -1;
    END;

    DECLARE
        @TenKy          NVARCHAR(50) =
            N'Tháng ' + CAST(@Thang AS NVARCHAR) + N'/' + CAST(@Nam AS NVARCHAR),
        @NgayChuanThang TINYINT = dbo.fn_SoNgayChuanThang(@Thang, @Nam);

    PRINT N'════════════════════════════════════════════════════════';
    PRINT N'  BẢNG LƯƠNG ' + UPPER(@TenKy);
    PRINT N'  Số ngày làm việc chuẩn: '
        + CAST(@NgayChuanThang AS NVARCHAR) + N' ngày';
    PRINT N'  Phòng ban: '
        + ISNULL((SELECT TenPB FROM dbo.PhongBan WHERE MaPB=@MaPB), N'Tất cả');
    PRINT N'════════════════════════════════════════════════════════';

    -- ── RS1: Chi tiết từng nhân viên ─────────────────────────
    SELECT
        -- Số thứ tự
        ROW_NUMBER() OVER (
            PARTITION BY pb.MaPB
            ORDER BY nv.MaNV
        )                               AS [STT],

        -- Thông tin nhân viên
        nv.MaNV                         AS [Mã NV],
        nv.HoTen                        AS [Họ và Tên],
        pb.TenPB                        AS [Phòng Ban],
        cv.TenCV                        AS [Chức Vụ],
        lhd.TenLoaiHD                   AS [Loại HĐ],

        -- Ngày công
        bl.SoNgayLamChuan               AS [Ngày Chuẩn],
        bl.SoNgayCong                   AS [Ngày Công],
        FORMAT(
            CASE WHEN bl.SoNgayLamChuan > 0
                 THEN CAST(bl.SoNgayCong AS DECIMAL(10,4))
                      / bl.SoNgayLamChuan
                 ELSE 1 END,
        'P2')                           AS [Hệ Số Công],

        -- Thu nhập
        FORMAT(lcb.LuongCB,'N0')        AS [Lương CB (VNĐ)],
        FORMAT(bl.LuongCoBan,'N0')      AS [Lương Theo Ngày],
        FORMAT(
            ISNULL((
                SELECT SUM(GiaTri) FROM dbo.ChiTietLuong
                WHERE MaBL=bl.MaBL AND LoaiMuc='+' AND TenMuc LIKE N'%làm thêm%'
            ),0), 'N0'
        )                               AS [Lương Làm Thêm],
        FORMAT(bl.TongPhuCap,'N0')      AS [Tổng Phụ Cấp],
        FORMAT(bl.LuongGross,'N0')      AS [Thu Nhập Gộp],

        -- Bảo hiểm NLĐ đóng (3 dòng riêng)
        FORMAT(bl.BHXH_NLD,'N0')        AS [BHXH 8%],
        FORMAT(bl.BHYT_NLD,'N0')        AS [BHYT 1.5%],
        FORMAT(bl.BHTN_NLD,'N0')        AS [BHTN 1%],
        FORMAT(bl.TongBaoHiem,'N0')     AS [Tổng BH NLĐ],

        -- Thuế TNCN
        FORMAT(tt.ThuNhapChiuThue,'N0') AS [TNCT],
        CAST(tt.BacThue AS NVARCHAR)
            + N' (' + FORMAT(
                CASE tt.BacThue
                    WHEN 1 THEN 0.05 WHEN 2 THEN 0.10 WHEN 3 THEN 0.15
                    WHEN 4 THEN 0.20 WHEN 5 THEN 0.25 WHEN 6 THEN 0.30
                    WHEN 7 THEN 0.35 ELSE 0 END,'P0')
            + N')'                      AS [Bậc Thuế],
        FORMAT(bl.ThueTNCN,'N0')        AS [Thuế TNCN],

        -- Khấu trừ khác
        FORMAT(bl.TongKhauTru
               - bl.TongBaoHiem
               - bl.ThueTNCN,'N0')     AS [KT Khác],
        FORMAT(bl.TongKhauTru,'N0')    AS [Tổng Khấu Trừ],

        -- Thực lĩnh
        FORMAT(bl.LuongNet,'N0')        AS [Thực Lĩnh (VNĐ)],

        -- Tài khoản ngân hàng
        nv.SoTaiKhoanNH                 AS [Số TK],
        nv.TenNganHang                  AS [Ngân Hàng],

        -- Trạng thái + ký duyệt
        CASE bl.TrangThai
            WHEN 'D' THEN N'Nháp'
            WHEN 'C' THEN N'Đã xác nhận'
            WHEN 'P' THEN N'Đã thanh toán'
            WHEN 'L' THEN N'Đã khóa'
        END                             AS [Trạng Thái],
        FORMAT(bl.NgayXacNhan,
               'dd/MM/yyyy')            AS [Ngày XN],
        FORMAT(bl.NgayThanhToan,
               'dd/MM/yyyy')            AS [Ngày TT],

        -- Chữ ký
        N'................'             AS [Ký Nhận],
        bl.MaBL                         AS [MaBL]   -- Ẩn, dùng cho JOIN

    FROM dbo.BangLuong      bl
    JOIN dbo.NhanVien       nv  ON bl.MaNV  = nv.MaNV
    JOIN dbo.PhongBan       pb  ON nv.MaPB  = pb.MaPB
    JOIN dbo.ChucVu         cv  ON nv.MaCV  = cv.MaCV
    LEFT JOIN dbo.LuongCoBan lcb ON nv.MaNV = lcb.MaNV
                                 AND lcb.NgayHetHieuLuc IS NULL
    LEFT JOIN dbo.HopDong   hd  ON nv.MaNV  = hd.MaNV
                                 AND hd.TrangThai = 'A'
    LEFT JOIN dbo.LoaiHopDong lhd ON hd.MaLoaiHD = lhd.MaLoaiHD
    LEFT JOIN dbo.ThueTNCN  tt  ON bl.MaBL  = tt.MaBL

    WHERE bl.Thang = @Thang
      AND bl.Nam   = @Nam
      AND (@MaPB IS NULL OR nv.MaPB = @MaPB)
      AND (@TrangThai IS NULL OR bl.TrangThai = @TrangThai)

    ORDER BY pb.TenPB, nv.HoTen;

    -- ── RS2: Tổng hợp theo phòng ban ─────────────────────────
    SELECT
        pb.TenPB                        AS [Phòng Ban],
        COUNT(bl.MaBL)                  AS [Số NV],
        FORMAT(SUM(bl.LuongCoBan),'N0') AS [Tổng Lương NN],
        FORMAT(SUM(bl.TongPhuCap),'N0') AS [Tổng Phụ Cấp],
        FORMAT(SUM(bl.LuongGross),'N0') AS [Tổng Gross],
        FORMAT(SUM(bl.TongBaoHiem),'N0')AS [Tổng BH NLĐ],
        FORMAT(SUM(bl.ThueTNCN),'N0')   AS [Tổng Thuế],
        FORMAT(SUM(bl.TongKhauTru
            - bl.TongBaoHiem
            - bl.ThueTNCN),'N0')        AS [KT Khác],
        FORMAT(SUM(bl.LuongNet),'N0')   AS [Tổng Thực Lĩnh],
        FORMAT(SUM(
            ROUND(dbo.fn_TinhBH_NSDLD(lcb.LuongCB,
                ISNULL(hd.MaLoaiHD,2)),0)
        ),'N0')                         AS [BH NSDLĐ (CP DN)],
        FORMAT(SUM(bl.LuongGross) + SUM(
            ROUND(dbo.fn_TinhBH_NSDLD(lcb.LuongCB,
                ISNULL(hd.MaLoaiHD,2)),0)
        ),'N0')                         AS [Tổng CP Nhân Sự DN]
    FROM dbo.BangLuong      bl
    JOIN dbo.NhanVien       nv  ON bl.MaNV  = nv.MaNV
    JOIN dbo.PhongBan       pb  ON nv.MaPB  = pb.MaPB
    LEFT JOIN dbo.LuongCoBan lcb ON nv.MaNV = lcb.MaNV
                                 AND lcb.NgayHetHieuLuc IS NULL
    LEFT JOIN dbo.HopDong   hd  ON nv.MaNV  = hd.MaNV
                                 AND hd.TrangThai = 'A'
    WHERE bl.Thang = @Thang AND bl.Nam = @Nam
      AND (@MaPB IS NULL OR nv.MaPB = @MaPB)
      AND (@TrangThai IS NULL OR bl.TrangThai = @TrangThai)
    GROUP BY pb.TenPB

    UNION ALL  -- Grand Total

    SELECT
        N'══ TỔNG CỘNG ══',
        COUNT(bl.MaBL),
        FORMAT(SUM(bl.LuongCoBan),'N0'),
        FORMAT(SUM(bl.TongPhuCap),'N0'),
        FORMAT(SUM(bl.LuongGross),'N0'),
        FORMAT(SUM(bl.TongBaoHiem),'N0'),
        FORMAT(SUM(bl.ThueTNCN),'N0'),
        FORMAT(SUM(bl.TongKhauTru
            - bl.TongBaoHiem
            - bl.ThueTNCN),'N0'),
        FORMAT(SUM(bl.LuongNet),'N0'),
        FORMAT(SUM(ROUND(dbo.fn_TinhBH_NSDLD(lcb.LuongCB,
            ISNULL(hd.MaLoaiHD,2)),0)),'N0'),
        FORMAT(SUM(bl.LuongGross) + SUM(ROUND(dbo.fn_TinhBH_NSDLD(
            lcb.LuongCB,ISNULL(hd.MaLoaiHD,2)),0)),'N0')
    FROM dbo.BangLuong      bl
    JOIN dbo.NhanVien       nv  ON bl.MaNV = nv.MaNV
    LEFT JOIN dbo.LuongCoBan lcb ON nv.MaNV= lcb.MaNV
                                 AND lcb.NgayHetHieuLuc IS NULL
    LEFT JOIN dbo.HopDong   hd  ON nv.MaNV = hd.MaNV
                                 AND hd.TrangThai='A'
    WHERE bl.Thang = @Thang AND bl.Nam = @Nam
      AND (@MaPB IS NULL OR nv.MaPB = @MaPB)

    ORDER BY [Phòng Ban];
END;
GO
PRINT N'[OK] sp_TaoBangLuong_ChinhThuc';
GO


-- ============================================================
-- SP 2: sp_TaoBangLuong_PhieuLuong
-- ─────────────────────────────────────────────────────────────
-- Tạo phiếu lương chi tiết cho 1 nhân viên 1 kỳ.
-- Gồm đầy đủ: thu nhập theo từng khoản, khấu trừ từng dòng,
-- chi tiết thuế TNCN từng bậc, thông tin tài khoản ngân hàng.
-- ============================================================
IF OBJECT_ID('dbo.sp_TaoBangLuong_PhieuLuong','P') IS NOT NULL
    DROP PROCEDURE dbo.sp_TaoBangLuong_PhieuLuong;
GO

CREATE PROCEDURE dbo.sp_TaoBangLuong_PhieuLuong
    @MaNV   NCHAR(10),
    @Thang  TINYINT,
    @Nam    SMALLINT
AS
BEGIN
    SET NOCOUNT ON;

    -- Kiểm tra tồn tại
    IF NOT EXISTS (
        SELECT 1 FROM dbo.BangLuong
        WHERE MaNV=@MaNV AND Thang=@Thang AND Nam=@Nam
    )
    BEGIN
        RAISERROR(
            N'sp_TaoBangLuong_PhieuLuong: Chưa có bảng lương '
            + N'T%d/%d cho NV [%s].',16,1,@Thang,@Nam,@MaNV);
        RETURN -1;
    END;

    -- ── Header phiếu lương ───────────────────────────────────
    PRINT N'';
    PRINT N'╔══════════════════════════════════════════════════════╗';
    PRINT N'║           PHIẾU LƯƠNG NHÂN VIÊN                    ║';
    PRINT N'║    Tháng ' + CAST(@Thang AS NVARCHAR)
        + N'/' + CAST(@Nam AS NVARCHAR)
        + REPLICATE(N' ',42 - LEN(CAST(@Thang AS NVARCHAR))
            - LEN(CAST(@Nam AS NVARCHAR))) + N'║';
    PRINT N'╚══════════════════════════════════════════════════════╝';

    -- ── RS1: Thông tin cá nhân ───────────────────────────────
    SELECT
        nv.MaNV                         AS [Mã Nhân Viên],
        nv.HoTen                        AS [Họ Tên],
        pb.TenPB                        AS [Phòng Ban],
        cv.TenCV                        AS [Chức Vụ],
        lhd.TenLoaiHD                   AS [Loại Hợp Đồng],
        nv.MaSoThue                     AS [Mã Số Thuế TNCN],
        nv.SoTaiKhoanNH                 AS [Số Tài Khoản NH],
        nv.TenNganHang                  AS [Ngân Hàng],
        nv.SoNguoiPhuThuoc              AS [Số Người Phụ Thuộc],
        FORMAT(11000000,'N0') + N' VNĐ' AS [Giảm Trừ Bản Thân],
        FORMAT(dbo.fn_TinhGiamTruPhuThuoc(
            nv.SoNguoiPhuThuoc),'N0')
            + N' VNĐ'                   AS [Giảm Trừ Phụ Thuộc],
        CASE bl.TrangThai
            WHEN 'D' THEN N'📝 Nháp'
            WHEN 'C' THEN N'✅ Đã xác nhận'
            WHEN 'P' THEN N'💰 Đã thanh toán'
            WHEN 'L' THEN N'🔒 Đã khóa'
        END                             AS [Trạng Thái]
    FROM dbo.NhanVien       nv
    JOIN dbo.PhongBan       pb  ON nv.MaPB = pb.MaPB
    JOIN dbo.ChucVu         cv  ON nv.MaCV = cv.MaCV
    JOIN dbo.BangLuong      bl  ON nv.MaNV = bl.MaNV
                                AND bl.Thang = @Thang
                                AND bl.Nam   = @Nam
    LEFT JOIN dbo.HopDong   hd  ON nv.MaNV = hd.MaNV
                                AND hd.TrangThai = 'A'
    LEFT JOIN dbo.LoaiHopDong lhd ON hd.MaLoaiHD = lhd.MaLoaiHD
    WHERE nv.MaNV = @MaNV;

    -- ── RS2: Chi tiết thu nhập và khấu trừ ──────────────────
    SELECT
        CASE LoaiMuc WHEN '+' THEN N'Thu nhập' ELSE N'Khấu trừ' END AS [Loại],
        LoaiMuc                         AS [+/-],
        TenMuc                          AS [Khoản Mục],
        FORMAT(GiaTri,'N0') + N' VNĐ'  AS [Số Tiền],
        ISNULL(GhiChu,'')               AS [Ghi Chú]
    FROM dbo.ChiTietLuong
    WHERE MaBL = (
        SELECT MaBL FROM dbo.BangLuong
        WHERE MaNV=@MaNV AND Thang=@Thang AND Nam=@Nam
    )
    ORDER BY
        CASE LoaiMuc WHEN '+' THEN 0 ELSE 1 END,
        TenMuc;

    -- ── RS3: Tóm tắt và kết quả ─────────────────────────────
    SELECT
        FORMAT(bl.LuongGross,       'N0') + N' VNĐ' AS [Thu Nhập Gộp],
        FORMAT(bl.TongBaoHiem,      'N0') + N' VNĐ' AS [Tổng BH (NLĐ)],
        FORMAT(bl.ThueTNCN,         'N0') + N' VNĐ' AS [Thuế TNCN],
        FORMAT(bl.TongKhauTru
               - bl.TongBaoHiem
               - bl.ThueTNCN,      'N0') + N' VNĐ' AS [Khấu Trừ Khác],
        FORMAT(bl.TongKhauTru,      'N0') + N' VNĐ' AS [Tổng Khấu Trừ],
        FORMAT(bl.LuongNet,         'N0') + N' VNĐ' AS [THỰC LĨNH],
        bl.SoNgayCong               AS [Ngày Công],
        bl.SoNgayLamChuan           AS [Ngày Chuẩn],
        FORMAT(bl.NgayXacNhan,  'dd/MM/yyyy HH:mm') AS [Ngày Xác Nhận],
        FORMAT(bl.NgayThanhToan,'dd/MM/yyyy')        AS [Ngày Thanh Toán]
    FROM dbo.BangLuong bl
    WHERE MaNV=@MaNV AND Thang=@Thang AND Nam=@Nam;

    -- ── RS4: Chi tiết thuế TNCN từng bậc ────────────────────
    SELECT
        ct.BacThue                      AS [Bậc],
        FORMAT(ct.ThueSuat,'N2') + N'%' AS [Thuế Suất],
        FORMAT(ct.NguongDuoi,'N0')      AS [Từ (VNĐ)],
        ISNULL(FORMAT(ct.NguongTren,'N0'),N'Không giới hạn')
                                        AS [Đến (VNĐ)],
        FORMAT(ct.ThuNhapTinhBac,'N0')  AS [Phần TNCT Bậc Này],
        FORMAT(ct.TienThue_Bac,'N0')    AS [Thuế Bậc Này],
        FORMAT(ct.TienThue_LuyKe,'N0')  AS [Thuế Lũy Kế]
    FROM dbo.fn_TinhThueTNCN_ChiTiet(
        (SELECT ThuNhapChiuThue
         FROM dbo.ThueTNCN
         WHERE MaNV=@MaNV AND Thang=@Thang AND Nam=@Nam)
    ) ct
    WHERE ct.ThuNhapTinhBac > 0
    ORDER BY ct.BacThue;
END;
GO
PRINT N'[OK] sp_TaoBangLuong_PhieuLuong';
GO


-- ============================================================
-- SP 3: sp_TaoBangLuong_BHXH
-- ─────────────────────────────────────────────────────────────
-- Tạo danh sách đóng BHXH nộp cơ quan BHXH hàng tháng.
-- Theo mẫu D02-TS (Danh sách lao động tham gia BHXH/BHYT/BHTN).
-- Gồm cả phần NLĐ và NSDLĐ đóng.
-- ============================================================
IF OBJECT_ID('dbo.sp_TaoBangLuong_BHXH','P') IS NOT NULL
    DROP PROCEDURE dbo.sp_TaoBangLuong_BHXH;
GO

CREATE PROCEDURE dbo.sp_TaoBangLuong_BHXH
    @Thang  TINYINT,
    @Nam    SMALLINT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (
        SELECT 1 FROM dbo.BangLuong WHERE Thang=@Thang AND Nam=@Nam
    )
    BEGIN
        RAISERROR(
            N'sp_TaoBangLuong_BHXH: Chưa có bảng lương T%d/%d.',
            16,1,@Thang,@Nam);
        RETURN -1;
    END;

    PRINT N'════════════════════════════════════════════════════════';
    PRINT N'  DANH SÁCH ĐÓNG BHXH/BHYT/BHTN — Mẫu D02-TS';
    PRINT N'  Tháng ' + CAST(@Thang AS NVARCHAR)
        + N'/' + CAST(@Nam AS NVARCHAR);
    PRINT N'════════════════════════════════════════════════════════';

    -- ── RS1: Danh sách từng NV (mẫu nộp BHXH) ───────────────
    SELECT
        ROW_NUMBER() OVER (ORDER BY nv.MaNV) AS [STT],
        nv.MaNV                         AS [Mã NV],
        nv.HoTen                        AS [Họ Tên],
        FORMAT(nv.NgaySinh,'dd/MM/yyyy')AS [Ngày Sinh],
        nv.GioiTinh                     AS [GT],
        nv.CCCD                         AS [Số CCCD],
        lhd.TenLoaiHD                   AS [Loại HĐ],

        -- Lương đóng BH (đã được tính trần)
        FORMAT(dbo.fn_TinhLuongDongBH(
            lcb.LuongCB, ISNULL(hd.MaLoaiHD,2)
        ),'N0')                         AS [Lương Đóng BH],

        -- NLĐ đóng
        FORMAT(bl.BHXH_NLD,'N0')        AS [BHXH NLĐ 8%],
        FORMAT(bl.BHYT_NLD,'N0')        AS [BHYT NLĐ 1.5%],
        FORMAT(bl.BHTN_NLD,'N0')        AS [BHTN NLĐ 1%],
        FORMAT(bl.TongBaoHiem,'N0')     AS [Tổng NLĐ 10.5%],

        -- NSDLĐ đóng (chi phí DN)
        FORMAT(ROUND(dbo.fn_TinhLuongDongBH(
            lcb.LuongCB,ISNULL(hd.MaLoaiHD,2)) * 0.175,0),'N0')
                                        AS [BHXH NSDLĐ 17.5%],
        FORMAT(ROUND(dbo.fn_TinhLuongDongBH(
            lcb.LuongCB,ISNULL(hd.MaLoaiHD,2)) * 0.03,0),'N0')
                                        AS [BHYT NSDLĐ 3%],
        FORMAT(ROUND(dbo.fn_TinhLuongDongBH(
            lcb.LuongCB,ISNULL(hd.MaLoaiHD,2)) * 0.01,0),'N0')
                                        AS [BHTN NSDLĐ 1%],
        FORMAT(ROUND(dbo.fn_TinhLuongDongBH(
            lcb.LuongCB,ISNULL(hd.MaLoaiHD,2)) * 0.005,0),'N0')
                                        AS [TNLĐ-BNN 0.5%],
        FORMAT(ROUND(dbo.fn_TinhBH_NSDLD(
            lcb.LuongCB,ISNULL(hd.MaLoaiHD,2)),0),'N0')
                                        AS [Tổng NSDLĐ 22%],

        -- Tổng cộng
        FORMAT(bl.TongBaoHiem +
            ROUND(dbo.fn_TinhBH_NSDLD(
                lcb.LuongCB,ISNULL(hd.MaLoaiHD,2)),0),'N0')
                                        AS [Tổng Cộng 32.5%],

        -- Ghi chú đặc biệt
        CASE
            WHEN hd.MaLoaiHD = 1 THEN N'Thử việc — miễn BHXH'
            WHEN nv.TrangThai = 'L' THEN N'Nghỉ thai sản'
            ELSE NULL
        END                             AS [Ghi Chú]

    FROM dbo.BangLuong      bl
    JOIN dbo.NhanVien       nv  ON bl.MaNV  = nv.MaNV
    LEFT JOIN dbo.LuongCoBan lcb ON nv.MaNV = lcb.MaNV
                                 AND lcb.NgayHetHieuLuc IS NULL
    LEFT JOIN dbo.HopDong   hd  ON nv.MaNV  = hd.MaNV
                                 AND hd.TrangThai = 'A'
    LEFT JOIN dbo.LoaiHopDong lhd ON hd.MaLoaiHD = lhd.MaLoaiHD
    WHERE bl.Thang = @Thang AND bl.Nam = @Nam
    ORDER BY nv.MaNV;

    -- ── RS2: Tổng hợp toàn công ty ───────────────────────────
    SELECT
        COUNT(bl.MaBL)                  AS [Số Lao Động],
        FORMAT(SUM(bl.TongBaoHiem),'N0') + N' VNĐ'
                                        AS [Tổng NLĐ Đóng],
        FORMAT(SUM(ROUND(dbo.fn_TinhBH_NSDLD(
            lcb.LuongCB,ISNULL(hd.MaLoaiHD,2)),0)),'N0') + N' VNĐ'
                                        AS [Tổng NSDLĐ Đóng],
        FORMAT(SUM(bl.TongBaoHiem) + SUM(ROUND(dbo.fn_TinhBH_NSDLD(
            lcb.LuongCB,ISNULL(hd.MaLoaiHD,2)),0)),'N0') + N' VNĐ'
                                        AS [TỔNG NỘP BHXH],
        N'Nộp trước ngày 15/'
            + CAST(CASE WHEN @Thang=12 THEN 1 ELSE @Thang+1 END AS NVARCHAR)
            + N'/' + CAST(CASE WHEN @Thang=12 THEN @Nam+1 ELSE @Nam END AS NVARCHAR)
                                        AS [Hạn Nộp]
    FROM dbo.BangLuong      bl
    JOIN dbo.NhanVien       nv  ON bl.MaNV = nv.MaNV
    LEFT JOIN dbo.LuongCoBan lcb ON nv.MaNV= lcb.MaNV
                                AND lcb.NgayHetHieuLuc IS NULL
    LEFT JOIN dbo.HopDong   hd  ON nv.MaNV = hd.MaNV
                               AND hd.TrangThai='A'
    WHERE bl.Thang=@Thang AND bl.Nam=@Nam;
END;
GO
PRINT N'[OK] sp_TaoBangLuong_BHXH';
GO


-- ============================================================
-- SP 4: sp_TaoBangLuong_QuyetToanThue
-- ─────────────────────────────────────────────────────────────
-- Dữ liệu quyết toán thuế TNCN — nộp cơ quan thuế.
-- Gồm: Bảng kê thu nhập tháng + lũy kế từ đầu năm.
-- Theo mẫu 05/KK-TNCN (Bảng kê thu nhập chịu thuế).
-- ============================================================
IF OBJECT_ID('dbo.sp_TaoBangLuong_QuyetToanThue','P') IS NOT NULL
    DROP PROCEDURE dbo.sp_TaoBangLuong_QuyetToanThue;
GO

CREATE PROCEDURE dbo.sp_TaoBangLuong_QuyetToanThue
    @Thang      TINYINT,
    @Nam        SMALLINT,
    @LoaiBaoCao NCHAR(1) = 'T'  -- 'T'=Tháng, 'N'=Năm (lũy kế)
AS
BEGIN
    SET NOCOUNT ON;

    PRINT N'════════════════════════════════════════════════════════';
    PRINT N'  BẢNG KÊ KHẤU TRỪ THUẾ TNCN — Mẫu 05/KK-TNCN';
    PRINT N'  ' + CASE @LoaiBaoCao
        WHEN 'T' THEN N'Tháng ' + CAST(@Thang AS NVARCHAR) + N'/' + CAST(@Nam AS NVARCHAR)
        ELSE N'Lũy kế từ đầu năm ' + CAST(@Nam AS NVARCHAR)
    END;
    PRINT N'════════════════════════════════════════════════════════';

    IF @LoaiBaoCao = 'T'
    BEGIN
        -- Báo cáo theo tháng
        SELECT
            ROW_NUMBER() OVER (ORDER BY nv.MaNV) AS [STT],
            nv.MaNV                         AS [Mã NV],
            nv.HoTen                        AS [Họ Tên],
            nv.MaSoThue                     AS [MST TNCN],
            nv.CCCD                         AS [CMND/CCCD],
            nv.SoNguoiPhuThuoc              AS [Số NPI],
            FORMAT(tt.ThuNhapGross,'N0')    AS [Thu Nhập Gross],
            FORMAT(tt.GiamTruBanThan,'N0')  AS [GT Bản Thân],
            FORMAT(tt.GiamTruPhuThuoc,'N0') AS [GT Phụ Thuộc],
            FORMAT(bl.TongBaoHiem,'N0')     AS [Trừ BH],
            FORMAT(tt.ThuNhapChiuThue,'N0') AS [TNCT],
            FORMAT(tt.TienThue,'N0')        AS [Tiền Thuế],
            CAST(tt.BacThue AS NVARCHAR)    AS [Bậc]
        FROM dbo.ThueTNCN       tt
        JOIN dbo.BangLuong      bl ON tt.MaBL = bl.MaBL
        JOIN dbo.NhanVien       nv ON tt.MaNV = nv.MaNV
        WHERE tt.Thang = @Thang AND tt.Nam = @Nam
          AND tt.TienThue > 0
        ORDER BY nv.MaNV;
    END
    ELSE
    BEGIN
        -- Báo cáo lũy kế cả năm (quyết toán cuối năm)
        SELECT
            ROW_NUMBER() OVER (ORDER BY nv.MaNV) AS [STT],
            nv.MaNV                         AS [Mã NV],
            nv.HoTen                        AS [Họ Tên],
            nv.MaSoThue                     AS [MST TNCN],
            nv.CCCD                         AS [CMND/CCCD],
            COUNT(tt.MaTT)                  AS [Số Tháng],
            FORMAT(SUM(tt.ThuNhapGross),'N0')   AS [Tổng TN Gross],
            FORMAT(SUM(tt.GiamTruBanThan),'N0') AS [Tổng GT BT],
            FORMAT(SUM(tt.GiamTruPhuThuoc),'N0')AS [Tổng GT PT],
            FORMAT(SUM(bl.TongBaoHiem),'N0')    AS [Tổng Trừ BH],
            FORMAT(SUM(tt.ThuNhapChiuThue),'N0')AS [Tổng TNCT],
            FORMAT(SUM(tt.TienThue),'N0')       AS [Tổng Thuế Đã KT],
            MAX(tt.BacThue)                     AS [Bậc Thuế Cao Nhất]
        FROM dbo.ThueTNCN       tt
        JOIN dbo.BangLuong      bl ON tt.MaBL = bl.MaBL
        JOIN dbo.NhanVien       nv ON tt.MaNV = nv.MaNV
        WHERE tt.Nam = @Nam
          AND tt.Thang <= @Thang
        GROUP BY nv.MaNV, nv.HoTen, nv.MaSoThue, nv.CCCD
        ORDER BY SUM(tt.TienThue) DESC;
    END;

    -- RS cuối: tổng số thuế phải nộp
    SELECT
        @Thang                          AS [Tháng],
        @Nam                            AS [Năm],
        COUNT(DISTINCT tt.MaNV)         AS [Số NV Phải Nộp Thuế],
        FORMAT(SUM(tt.TienThue),'N0') + N' VNĐ'
                                        AS [Tổng Thuế TNCN],
        N'Nộp trước ngày 20/'
            + CAST(CASE WHEN @Thang=12 THEN 1 ELSE @Thang+1 END AS NVARCHAR)
            + N'/' + CAST(CASE WHEN @Thang=12 THEN @Nam+1 ELSE @Nam END AS NVARCHAR)
                                        AS [Hạn Kê Khai & Nộp]
    FROM dbo.ThueTNCN tt
    WHERE tt.Nam = @Nam
      AND (@LoaiBaoCao='N' OR tt.Thang=@Thang)
      AND tt.TienThue > 0;
END;
GO
PRINT N'[OK] sp_TaoBangLuong_QuyetToanThue';
GO


-- ============================================================
-- SP 5: sp_TaoBangLuong_SoSanh
-- ─────────────────────────────────────────────────────────────
-- So sánh quỹ lương nhiều kỳ liên tiếp.
-- Phát hiện biến động bất thường (tăng/giảm đột biến > 20%).
-- Dùng cho ban lãnh đạo / kế toán trưởng theo dõi chi phí.
-- ============================================================
IF OBJECT_ID('dbo.sp_TaoBangLuong_SoSanh','P') IS NOT NULL
    DROP PROCEDURE dbo.sp_TaoBangLuong_SoSanh;
GO

CREATE PROCEDURE dbo.sp_TaoBangLuong_SoSanh
    @TuThang    TINYINT,
    @TuNam      SMALLINT,
    @DenThang   TINYINT,
    @DenNam     SMALLINT,
    @MaPB       NCHAR(10) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    -- ── Bảng lương từng kỳ ───────────────────────────────────
    SELECT
        bl.Nam,
        bl.Thang,
        pb.TenPB                        AS [Phòng Ban],
        COUNT(bl.MaBL)                  AS [Số NV],
        FORMAT(SUM(bl.LuongGross),'N0') AS [Tổng Gross],
        FORMAT(SUM(bl.TongBaoHiem),'N0')AS [Tổng BH NLĐ],
        FORMAT(SUM(bl.ThueTNCN),'N0')   AS [Tổng Thuế],
        FORMAT(SUM(bl.LuongNet),'N0')   AS [Tổng Thực Lĩnh],

        -- So sánh với kỳ trước (LAG)
        FORMAT(
            SUM(bl.LuongNet) - LAG(SUM(bl.LuongNet),1)
                OVER (PARTITION BY nv.MaPB
                      ORDER BY bl.Nam, bl.Thang),
        'N0')                           AS [Chênh Lệch Kỳ Trước],

        FORMAT(
            CASE WHEN LAG(SUM(bl.LuongNet),1)
                    OVER (PARTITION BY nv.MaPB
                          ORDER BY bl.Nam, bl.Thang) > 0
                 THEN (SUM(bl.LuongNet)
                       - LAG(SUM(bl.LuongNet),1)
                           OVER (PARTITION BY nv.MaPB
                                 ORDER BY bl.Nam, bl.Thang))
                      / LAG(SUM(bl.LuongNet),1)
                          OVER (PARTITION BY nv.MaPB
                                ORDER BY bl.Nam, bl.Thang)
                 ELSE NULL END,
        'P2')                           AS [% Thay Đổi],

        -- Cờ cảnh báo biến động > 20%
        CASE WHEN ABS(
            CASE WHEN LAG(SUM(bl.LuongNet),1)
                    OVER (PARTITION BY nv.MaPB ORDER BY bl.Nam,bl.Thang) > 0
                 THEN (SUM(bl.LuongNet)
                       - LAG(SUM(bl.LuongNet),1)
                           OVER (PARTITION BY nv.MaPB ORDER BY bl.Nam,bl.Thang))
                      / LAG(SUM(bl.LuongNet),1)
                          OVER (PARTITION BY nv.MaPB ORDER BY bl.Nam,bl.Thang)
                 ELSE 0 END) > 0.20
             THEN N'⚠️ Biến động lớn'
             ELSE N''
        END                             AS [Cảnh Báo]

    FROM dbo.BangLuong      bl
    JOIN dbo.NhanVien       nv  ON bl.MaNV = nv.MaNV
    JOIN dbo.PhongBan       pb  ON nv.MaPB = pb.MaPB
    WHERE (bl.Nam > @TuNam OR (bl.Nam = @TuNam AND bl.Thang >= @TuThang))
      AND (bl.Nam < @DenNam OR (bl.Nam = @DenNam AND bl.Thang <= @DenThang))
      AND (@MaPB IS NULL OR nv.MaPB = @MaPB)
      AND bl.TrangThai IN ('C','P','L')
    GROUP BY bl.Nam, bl.Thang, pb.TenPB, nv.MaPB
    ORDER BY bl.Nam, bl.Thang, pb.TenPB;
END;
GO
PRINT N'[OK] sp_TaoBangLuong_SoSanh';
GO


-- ============================================================
-- SP 6: sp_TaoBangLuong_ChiPhiNhanSu
-- ─────────────────────────────────────────────────────────────
-- Tổng chi phí nhân sự toàn doanh nghiệp 1 kỳ lương:
--   Lương Gross + BH NSDLĐ (22%) + các chi phí khác.
-- Dùng cho báo cáo tài chính / ban lãnh đạo.
-- ============================================================
IF OBJECT_ID('dbo.sp_TaoBangLuong_ChiPhiNhanSu','P') IS NOT NULL
    DROP PROCEDURE dbo.sp_TaoBangLuong_ChiPhiNhanSu;
GO

CREATE PROCEDURE dbo.sp_TaoBangLuong_ChiPhiNhanSu
    @Thang  TINYINT,
    @Nam    SMALLINT
AS
BEGIN
    SET NOCOUNT ON;

    PRINT N'════════════════════════════════════════════════════════';
    PRINT N'  BÁO CÁO CHI PHÍ NHÂN SỰ TOÀN DOANH NGHIỆP';
    PRINT N'  Tháng ' + CAST(@Thang AS NVARCHAR)
        + N'/' + CAST(@Nam AS NVARCHAR);
    PRINT N'════════════════════════════════════════════════════════';

    -- ── RS1: Chi tiết từng phòng ban ─────────────────────────
    SELECT
        pb.TenPB                        AS [Phòng Ban],
        COUNT(bl.MaBL)                  AS [Nhân Sự],
        FORMAT(SUM(bl.LuongGross),'N0') AS [Lương Gross],
        FORMAT(SUM(ROUND(dbo.fn_TinhBH_NSDLD(
            lcb.LuongCB,ISNULL(hd.MaLoaiHD,2)),0)),'N0')
                                        AS [BH NSDLĐ 22%],
        FORMAT(SUM(bl.LuongGross)
             + SUM(ROUND(dbo.fn_TinhBH_NSDLD(
                 lcb.LuongCB,ISNULL(hd.MaLoaiHD,2)),0)),'N0')
                                        AS [Tổng CP Nhân Sự],
        FORMAT(
            AVG(bl.LuongGross
                + ROUND(dbo.fn_TinhBH_NSDLD(
                    lcb.LuongCB,ISNULL(hd.MaLoaiHD,2)),0)),'N0')
                                        AS [CP TB / Người],
        FORMAT(
            SUM(bl.LuongGross
                + ROUND(dbo.fn_TinhBH_NSDLD(
                    lcb.LuongCB,ISNULL(hd.MaLoaiHD,2)),0))
            * 100.0
            / NULLIF(SUM(SUM(bl.LuongGross
                + ROUND(dbo.fn_TinhBH_NSDLD(
                    lcb.LuongCB,ISNULL(hd.MaLoaiHD,2)),0)))
            OVER(),'N0'), 'N2') + N'%'  AS [Tỷ Trọng]
    FROM dbo.BangLuong      bl
    JOIN dbo.NhanVien       nv  ON bl.MaNV = nv.MaNV
    JOIN dbo.PhongBan       pb  ON nv.MaPB = pb.MaPB
    LEFT JOIN dbo.LuongCoBan lcb ON nv.MaNV = lcb.MaNV
                                 AND lcb.NgayHetHieuLuc IS NULL
    LEFT JOIN dbo.HopDong   hd  ON nv.MaNV = hd.MaNV
                                 AND hd.TrangThai='A'
    WHERE bl.Thang=@Thang AND bl.Nam=@Nam
    GROUP BY pb.TenPB
    ORDER BY SUM(bl.LuongGross) DESC;

    -- ── RS2: Cơ cấu chi phí toàn DN ─────────────────────────
    SELECT
        N'Lương cơ bản (theo ngày công)'    AS [Khoản Mục],
        FORMAT(SUM(bl.LuongCoBan),'N0')     AS [Số Tiền (VNĐ)],
        FORMAT(SUM(bl.LuongCoBan)*100.0
            /NULLIF(SUM(bl.LuongGross)+SUM(ROUND(
                dbo.fn_TinhBH_NSDLD(lcb.LuongCB,ISNULL(hd.MaLoaiHD,2))
            ,0)),0),'N2') + N'%'            AS [Tỷ Trọng CP]
    FROM dbo.BangLuong bl
    JOIN dbo.NhanVien nv ON bl.MaNV=nv.MaNV
    LEFT JOIN dbo.LuongCoBan lcb ON nv.MaNV=lcb.MaNV AND lcb.NgayHetHieuLuc IS NULL
    LEFT JOIN dbo.HopDong hd ON nv.MaNV=hd.MaNV AND hd.TrangThai='A'
    WHERE bl.Thang=@Thang AND bl.Nam=@Nam

    UNION ALL SELECT N'Phụ cấp',
        FORMAT(SUM(bl.TongPhuCap),'N0'),
        FORMAT(SUM(bl.TongPhuCap)*100.0/NULLIF(SUM(bl.LuongGross)
            +SUM(ROUND(dbo.fn_TinhBH_NSDLD(lcb.LuongCB,ISNULL(hd.MaLoaiHD,2)),0)),0),'N2')+'%'
    FROM dbo.BangLuong bl JOIN dbo.NhanVien nv ON bl.MaNV=nv.MaNV
    LEFT JOIN dbo.LuongCoBan lcb ON nv.MaNV=lcb.MaNV AND lcb.NgayHetHieuLuc IS NULL
    LEFT JOIN dbo.HopDong hd ON nv.MaNV=hd.MaNV AND hd.TrangThai='A'
    WHERE bl.Thang=@Thang AND bl.Nam=@Nam

    UNION ALL SELECT N'BH NSDLĐ đóng (22%)',
        FORMAT(SUM(ROUND(dbo.fn_TinhBH_NSDLD(lcb.LuongCB,ISNULL(hd.MaLoaiHD,2)),0)),'N0'),
        FORMAT(SUM(ROUND(dbo.fn_TinhBH_NSDLD(lcb.LuongCB,ISNULL(hd.MaLoaiHD,2)),0))*100.0
            /NULLIF(SUM(bl.LuongGross)+SUM(ROUND(dbo.fn_TinhBH_NSDLD(lcb.LuongCB,ISNULL(hd.MaLoaiHD,2)),0)),0),'N2')+'%'
    FROM dbo.BangLuong bl JOIN dbo.NhanVien nv ON bl.MaNV=nv.MaNV
    LEFT JOIN dbo.LuongCoBan lcb ON nv.MaNV=lcb.MaNV AND lcb.NgayHetHieuLuc IS NULL
    LEFT JOIN dbo.HopDong hd ON nv.MaNV=hd.MaNV AND hd.TrangThai='A'
    WHERE bl.Thang=@Thang AND bl.Nam=@Nam;
END;
GO
PRINT N'[OK] sp_TaoBangLuong_ChiPhiNhanSu';
GO


-- ============================================================
-- DEMO & KIỂM THỬ
-- ============================================================
PRINT N'';
PRINT N'════════════════════════════════════════════════════════';
PRINT N'  DEMO — sp_TaoBangLuong_* (cần có dữ liệu T1-T3/2025)';
PRINT N'════════════════════════════════════════════════════════';

-- Demo 1: Bảng lương chính thức tháng 3/2025
PRINT N'--- 1. Bảng lương chính thức T3/2025 ---';
EXEC dbo.sp_TaoBangLuong_ChinhThuc @Thang=3, @Nam=2025;
GO

-- Demo 2: Phiếu lương TGĐ tháng 3/2025
PRINT N'--- 2. Phiếu lương NV000001 T3/2025 ---';
EXEC dbo.sp_TaoBangLuong_PhieuLuong
    @MaNV='NV000001', @Thang=3, @Nam=2025;
GO

-- Demo 3: Danh sách đóng BHXH tháng 1/2025
PRINT N'--- 3. Danh sách BHXH T1/2025 ---';
EXEC dbo.sp_TaoBangLuong_BHXH @Thang=1, @Nam=2025;
GO

-- Demo 4: Quyết toán thuế tháng 3/2025
PRINT N'--- 4. Quyết toán thuế T3/2025 ---';
EXEC dbo.sp_TaoBangLuong_QuyetToanThue
    @Thang=3, @Nam=2025, @LoaiBaoCao='T';
GO

-- Demo 5: So sánh quỹ lương 3 tháng
PRINT N'--- 5. So sánh quỹ lương T1-T3/2025 ---';
EXEC dbo.sp_TaoBangLuong_SoSanh
    @TuThang=1, @TuNam=2025, @DenThang=3, @DenNam=2025;
GO

-- Demo 6: Chi phí nhân sự tháng 3/2025
PRINT N'--- 6. Chi phí nhân sự T3/2025 ---';
EXEC dbo.sp_TaoBangLuong_ChiPhiNhanSu @Thang=3, @Nam=2025;
GO

-- Kiểm tra nhanh số lượng SP đã tạo
PRINT N'';
PRINT N'════════════════════════════════════════════════════════';
PRINT N'  DANH SÁCH SPs ĐÃ TẠO TRONG FILE NÀY';
PRINT N'════════════════════════════════════════════════════════';
SELECT
    name                            AS [Tên Stored Procedure],
    FORMAT(create_date,'dd/MM/yyyy HH:mm') AS [Ngày Tạo],
    FORMAT(modify_date,'dd/MM/yyyy HH:mm') AS [Ngày Sửa]
FROM sys.procedures
WHERE name LIKE 'sp_TaoBangLuong%'
ORDER BY name;
GO

PRINT N'[DONE] sp_TaoBangLuong.sql — 6 stored procedures hoàn tất.';
PRINT N'';
PRINT N'Danh sách SPs:';
PRINT N'  1. sp_TaoBangLuong_ChinhThuc     — Bảng lương tổng hợp + grand total PB';
PRINT N'  2. sp_TaoBangLuong_PhieuLuong    — Phiếu lương chi tiết 4 RS';
PRINT N'  3. sp_TaoBangLuong_BHXH          — Danh sách D02-TS nộp cơ quan BHXH';
PRINT N'  4. sp_TaoBangLuong_QuyetToanThue — Mẫu 05/KK-TNCN tháng + lũy kế năm';
PRINT N'  5. sp_TaoBangLuong_SoSanh        — Trend quỹ lương + cảnh báo ±20%';
PRINT N'  6. sp_TaoBangLuong_ChiPhiNhanSu  — Cơ cấu chi phí nhân sự toàn DN';
GO
