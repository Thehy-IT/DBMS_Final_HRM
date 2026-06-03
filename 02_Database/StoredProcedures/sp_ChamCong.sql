-- ============================================================
-- FILE       : sp_ChamCong.sql
-- PROJECT    : Hệ Thống Quản Lý Nhân Sự & Tính Lương Tự Động
-- MỤC ĐÍCH   : Stored Procedures quản lý toàn bộ vòng đời
--              chấm công: nhập liệu, cập nhật, đồng bộ,
--              phê duyệt nghỉ phép và báo cáo
-- ─────────────────────────────────────────────────────────────
-- PROCEDURES :
--   1. sp_ChamCong_NhapHangNgay   — UPSERT 1 NV 1 ngày
--   2. sp_ChamCong_NhapLoat       — Nhập hàng loạt từ bảng tạm
--   3. sp_ChamCong_CapNhat        — Sửa trạng thái / giờ giấc
--   4. sp_ChamCong_DongBoNghiPhep — Đồng bộ đơn đã duyệt → CC
--   5. sp_NghiPhep_PheDuyet       — Duyệt / từ chối đơn nghỉ
--   6. sp_ChamCong_BaoCaoThang    — Báo cáo tổng hợp kỳ lương
-- ─────────────────────────────────────────────────────────────
-- DEPENDENCY : sp_TinhLuong.sql, trg_LogLuong.sql, seed_data
-- BUSINESS RULES ĐƯỢC ÁP DỤNG:
--   BR-09: Trạng thái CC hợp lệ: DL/WFH/CX/NP/OM/KP/NG
--   BR-10: UNIQUE (MaNV, NgayCham) — 1 bản ghi/người/ngày
--   BR-11: Không chấm công tương lai
--   BR-12: Làm thêm: 1.5x thường / 2.0x cuối tuần / 3.0x lễ
-- ============================================================

USE HRPayrollDB;
GO

-- ============================================================
-- SP 1: sp_ChamCong_NhapHangNgay
-- ─────────────────────────────────────────────────────────────
-- UPSERT chấm công 1 nhân viên 1 ngày.
-- Nếu đã tồn tại bản ghi cho (MaNV, NgayCham) → UPDATE.
-- Nếu chưa → INSERT.
-- Tự động: tính SoGioLam, validate giờ giấc, kiểm tra HĐ active.
-- ============================================================
IF OBJECT_ID('dbo.sp_ChamCong_NhapHangNgay','P') IS NOT NULL
    DROP PROCEDURE dbo.sp_ChamCong_NhapHangNgay;
GO

CREATE PROCEDURE dbo.sp_ChamCong_NhapHangNgay
    @MaNV           NCHAR(10),
    @NgayCham       DATE,
    @TrangThai      NCHAR(3),           -- DL/WFH/CX/NP/OM/KP/NG
    @GioVao         TIME(0) = NULL,
    @GioRa          TIME(0) = NULL,
    @SoGioTangCa    DECIMAL(4,2) = 0,
    @HeSoTangCa     DECIMAL(4,2) = 1.50,
    @GhiChu         NVARCHAR(300) = NULL,
    @NguoiCapNhat   NVARCHAR(100) = NULL,
    @MaCC_Out       INT = NULL OUTPUT   -- Trả về MaCC vừa xử lý
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    -- ── Validate: NV tồn tại & đang làm việc ─────────────────
    IF NOT EXISTS (
        SELECT 1 FROM dbo.NhanVien
        WHERE MaNV = @MaNV AND TrangThai IN ('A','P','L')
    )
    BEGIN
        RAISERROR(N'sp_ChamCong_NhapHangNgay: NV [%s] không tồn tại hoặc đã nghỉ việc.',16,1,@MaNV);
        RETURN -1;
    END;

    -- ── Validate: không chấm tương lai (BR-11) ───────────────
    IF @NgayCham > CAST(GETDATE() AS DATE)
    BEGIN
        RAISERROR(N'sp_ChamCong_NhapHangNgay: Không được chấm công ngày tương lai (%s).',16,1,CONVERT(NVARCHAR,@NgayCham,103));
        RETURN -2;
    END;

    -- ── Validate: trạng thái hợp lệ (BR-09) ─────────────────
    IF @TrangThai NOT IN ('DL','WFH','CX','NP','OM','KP','NG')
    BEGIN
        RAISERROR(N'sp_ChamCong_NhapHangNgay: TrangThai [%s] không hợp lệ. Dùng: DL/WFH/CX/NP/OM/KP/NG.',16,1,@TrangThai);
        RETURN -3;
    END;

    -- ── Validate: giờ vào/ra logic ───────────────────────────
    IF @GioVao IS NOT NULL AND @GioRa IS NOT NULL AND @GioRa <= @GioVao
    BEGIN
        RAISERROR(N'sp_ChamCong_NhapHangNgay: GioRa (%s) phải sau GioVao (%s).',16,1,
            CONVERT(NVARCHAR,@GioRa,108), CONVERT(NVARCHAR,@GioVao,108));
        RETURN -4;
    END;

    -- ── Validate: hệ số làm thêm hợp lệ (BR-12) ─────────────
    IF @SoGioTangCa > 0 AND @HeSoTangCa NOT IN (1.00,1.50,2.00,3.00)
    BEGIN
        RAISERROR(N'sp_ChamCong_NhapHangNgay: HeSoTangCa phải là 1.00/1.50/2.00/3.00.',16,1);
        RETURN -5;
    END;

    -- ── Tự động suy luận HeSoTangCa nếu là 0 OT ─────────────
    -- Cuối tuần → 2.0x, Ngày lễ → 3.0x
    IF @SoGioTangCa > 0 AND @HeSoTangCa = 1.50
    BEGIN
        IF DATENAME(WEEKDAY,@NgayCham) IN ('Saturday','Sunday')
            SET @HeSoTangCa = 2.00;
        IF EXISTS (SELECT 1 FROM dbo.NgayLe WHERE NgayLe = @NgayCham)
            SET @HeSoTangCa = 3.00;
    END;

    -- ── Tính SoGioLam tự động ────────────────────────────────
    DECLARE @SoGioLam DECIMAL(4,2) = 0;
    IF @GioVao IS NOT NULL AND @GioRa IS NOT NULL
        AND @TrangThai IN ('DL','WFH','CX')
    BEGIN
        SET @SoGioLam =
            CAST(DATEDIFF(MINUTE,@GioVao,@GioRa) / 60.0 AS DECIMAL(4,2))
            -- Trừ 1h nghỉ trưa nếu ca > 5 tiếng
            - CASE WHEN DATEDIFF(MINUTE,@GioVao,@GioRa) > 300
                   THEN 1.0 ELSE 0.0 END;
        IF @SoGioLam < 0 SET @SoGioLam = 0;
    END;

    DECLARE @NguoiCN NVARCHAR(100) = ISNULL(@NguoiCapNhat, SYSTEM_USER);

    BEGIN TRANSACTION;
    BEGIN TRY
        -- UPSERT pattern (BR-10: UNIQUE MaNV + NgayCham)
        IF EXISTS (
            SELECT 1 FROM dbo.ChamCong
            WHERE MaNV = @MaNV AND NgayCham = @NgayCham
        )
        BEGIN
            -- UPDATE bản ghi cũ
            UPDATE dbo.ChamCong SET
                TrangThai       = @TrangThai,
                GioVao          = @GioVao,
                GioRa           = @GioRa,
                SoGioLam        = @SoGioLam,
                SoGioTangCa     = @SoGioTangCa,
                HeSoTangCa      = @HeSoTangCa,
                GhiChu          = @GhiChu,
                NguoiCapNhat    = @NguoiCN,
                NgayCapNhat     = GETDATE()
            WHERE MaNV = @MaNV AND NgayCham = @NgayCham;

            SELECT @MaCC_Out = MaCC
            FROM dbo.ChamCong WHERE MaNV=@MaNV AND NgayCham=@NgayCham;
        END
        ELSE
        BEGIN
            -- INSERT mới
            INSERT INTO dbo.ChamCong (
                MaNV, NgayCham, TrangThai,
                GioVao, GioRa, SoGioLam,
                SoGioTangCa, HeSoTangCa, GhiChu,
                NguoiCapNhat, NgayTao
            )
            VALUES (
                @MaNV, @NgayCham, @TrangThai,
                @GioVao, @GioRa, @SoGioLam,
                @SoGioTangCa, @HeSoTangCa, @GhiChu,
                @NguoiCN, GETDATE()
            );
            SET @MaCC_Out = SCOPE_IDENTITY();
        END;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO
PRINT N'[OK] sp_ChamCong_NhapHangNgay';
GO


-- ============================================================
-- SP 2: sp_ChamCong_NhapLoat
-- ─────────────────────────────────────────────────────────────
-- Nhập chấm công hàng loạt từ bảng tạm #ChamCongBulk.
-- HR nhập dữ liệu từ Excel → đổ vào temp table → gọi SP này.
-- SP xử lý từng dòng, gom lỗi vào bảng #BulkErrors.
-- ============================================================
IF OBJECT_ID('dbo.sp_ChamCong_NhapLoat','P') IS NOT NULL
    DROP PROCEDURE dbo.sp_ChamCong_NhapLoat;
GO

CREATE PROCEDURE dbo.sp_ChamCong_NhapLoat
    @Thang          TINYINT,
    @Nam            SMALLINT,
    @NguoiCapNhat   NVARCHAR(100) = NULL,
    @StopOnError    BIT = 0          -- 0=tiếp tục dù có lỗi, 1=dừng ngay
AS
BEGIN
    SET NOCOUNT ON;

    -- ── Kiểm tra bảng tạm tồn tại ────────────────────────────
    IF OBJECT_ID('tempdb..#ChamCongBulk') IS NULL
    BEGIN
        RAISERROR(N'sp_ChamCong_NhapLoat: Cần tạo #ChamCongBulk trước.
Cấu trúc:
  CREATE TABLE #ChamCongBulk (
      MaNV        NCHAR(10),
      NgayCham    DATE,
      TrangThai   NCHAR(3),
      GioVao      TIME(0) NULL,
      GioRa       TIME(0) NULL,
      SoGioTangCa DECIMAL(4,2) NULL,
      GhiChu      NVARCHAR(300) NULL
  );', 16, 1);
        RETURN -1;
    END;

    -- ── Bảng gom kết quả bulk ─────────────────────────────────
    IF OBJECT_ID('tempdb..#BulkErrors') IS NOT NULL
        DROP TABLE #BulkErrors;

    CREATE TABLE #BulkErrors (
        RowNum      INT,
        MaNV        NCHAR(10),
        NgayCham    DATE,
        TrangThai   NCHAR(3),
        ErrorMsg    NVARCHAR(500)
    );

    DECLARE
        @RowNum     INT = 0,
        @SoThanhCong INT = 0,
        @SoLoi      INT = 0,
        @MaCC_Out   INT,
        -- Cursor vars
        @b_MaNV     NCHAR(10),
        @b_Ngay     DATE,
        @b_TT       NCHAR(3),
        @b_Vao      TIME(0),
        @b_Ra       TIME(0),
        @b_OT       DECIMAL(4,2),
        @b_GhiChu   NVARCHAR(300);

    DECLARE cur_Bulk CURSOR LOCAL FAST_FORWARD FOR
        SELECT MaNV, NgayCham, TrangThai,
               GioVao, GioRa, ISNULL(SoGioTangCa,0), GhiChu
        FROM #ChamCongBulk
        WHERE MONTH(NgayCham) = @Thang AND YEAR(NgayCham) = @Nam
        ORDER BY NgayCham, MaNV;

    OPEN cur_Bulk;
    FETCH NEXT FROM cur_Bulk
        INTO @b_MaNV,@b_Ngay,@b_TT,@b_Vao,@b_Ra,@b_OT,@b_GhiChu;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @RowNum = @RowNum + 1;

        BEGIN TRY
            EXEC dbo.sp_ChamCong_NhapHangNgay
                @MaNV           = @b_MaNV,
                @NgayCham       = @b_Ngay,
                @TrangThai      = @b_TT,
                @GioVao         = @b_Vao,
                @GioRa          = @b_Ra,
                @SoGioTangCa    = @b_OT,
                @GhiChu         = @b_GhiChu,
                @NguoiCapNhat   = @NguoiCapNhat,
                @MaCC_Out       = @MaCC_Out OUTPUT;

            SET @SoThanhCong = @SoThanhCong + 1;
        END TRY
        BEGIN CATCH
            SET @SoLoi = @SoLoi + 1;
            INSERT #BulkErrors (RowNum,MaNV,NgayCham,TrangThai,ErrorMsg)
            VALUES (@RowNum,@b_MaNV,@b_Ngay,@b_TT,ERROR_MESSAGE());

            IF @StopOnError = 1
            BEGIN
                CLOSE cur_Bulk; DEALLOCATE cur_Bulk;
                RAISERROR(N'sp_ChamCong_NhapLoat: Dừng tại dòng %d — %s',
                    16,1,@RowNum,ERROR_MESSAGE());
                RETURN -2;
            END;
        END CATCH;

        FETCH NEXT FROM cur_Bulk
            INTO @b_MaNV,@b_Ngay,@b_TT,@b_Vao,@b_Ra,@b_OT,@b_GhiChu;
    END;

    CLOSE cur_Bulk; DEALLOCATE cur_Bulk;

    -- ── Báo cáo kết quả ──────────────────────────────────────
    PRINT N'';
    PRINT N'── Kết quả sp_ChamCong_NhapLoat T'
        + CAST(@Thang AS NVARCHAR) + N'/' + CAST(@Nam AS NVARCHAR)
        + N' ──────────────────';
    PRINT N'  Tổng dòng xử lý : ' + CAST(@RowNum AS NVARCHAR);
    PRINT N'  Thành công       : ' + CAST(@SoThanhCong AS NVARCHAR);
    PRINT N'  Lỗi              : ' + CAST(@SoLoi AS NVARCHAR);

    -- Trả về các dòng lỗi nếu có
    IF @SoLoi > 0
    BEGIN
        PRINT N'  ⚠️  Xem bảng lỗi bên dưới:';
        SELECT RowNum, MaNV,
               CONVERT(NVARCHAR,NgayCham,103) AS NgayCham,
               TrangThai, ErrorMsg
        FROM #BulkErrors ORDER BY RowNum;
    END;

    -- Tóm tắt chấm công đã nhập
    SELECT
        MONTH(NgayCham)                     AS Thang,
        TrangThai,
        COUNT(*)                            AS SoBanGhi
    FROM dbo.ChamCong
    WHERE MONTH(NgayCham) = @Thang
      AND YEAR(NgayCham)  = @Nam
    GROUP BY MONTH(NgayCham), TrangThai
    ORDER BY TrangThai;
END;
GO
PRINT N'[OK] sp_ChamCong_NhapLoat';
GO


-- ============================================================
-- SP 3: sp_ChamCong_CapNhat
-- ─────────────────────────────────────────────────────────────
-- Cập nhật 1 bản ghi chấm công cụ thể theo MaCC.
-- Dùng khi HR cần chỉnh sửa sau khi đã nhập.
-- Ghi lý do chỉnh sửa vào GhiChu + log timestamp.
-- ============================================================
IF OBJECT_ID('dbo.sp_ChamCong_CapNhat','P') IS NOT NULL
    DROP PROCEDURE dbo.sp_ChamCong_CapNhat;
GO

CREATE PROCEDURE dbo.sp_ChamCong_CapNhat
    @MaCC           INT,
    @TrangThai      NCHAR(3)        = NULL,
    @GioVao         TIME(0)         = NULL,
    @GioRa          TIME(0)         = NULL,
    @SoGioTangCa    DECIMAL(4,2)    = NULL,
    @HeSoTangCa     DECIMAL(4,2)    = NULL,
    @GhiChu         NVARCHAR(300)   = NULL,
    @LyDoChinhSua   NVARCHAR(300)   = NULL,
    @NguoiCapNhat   NVARCHAR(100)   = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    -- Kiểm tra bản ghi tồn tại
    IF NOT EXISTS (SELECT 1 FROM dbo.ChamCong WHERE MaCC = @MaCC)
    BEGIN
        RAISERROR(N'sp_ChamCong_CapNhat: MaCC [%d] không tồn tại.',16,1,@MaCC);
        RETURN -1;
    END;

    -- Lấy trạng thái hiện tại
    DECLARE
        @NgayCham_Cu    DATE,
        @MaNV_Cu        NCHAR(10),
        @TT_Cu          NCHAR(3),
        @Vao_Cu         TIME(0),
        @Ra_Cu          TIME(0);

    SELECT
        @NgayCham_Cu = NgayCham,
        @MaNV_Cu     = MaNV,
        @TT_Cu       = TrangThai,
        @Vao_Cu      = GioVao,
        @Ra_Cu       = GioRa
    FROM dbo.ChamCong WHERE MaCC = @MaCC;

    -- Không cho sửa ngày lễ nếu là tháng đã CHOT lương
    IF EXISTS (
        SELECT 1 FROM dbo.BangLuong
        WHERE MaNV  = @MaNV_Cu
          AND Thang = MONTH(@NgayCham_Cu)
          AND Nam   = YEAR(@NgayCham_Cu)
          AND TrangThai IN ('C','P','L')
    )
    BEGIN
        RAISERROR(
            N'sp_ChamCong_CapNhat: Bảng lương tháng %d/%d của [%s] đã CHOT. Không thể sửa chấm công.',
            16,1,MONTH(@NgayCham_Cu),YEAR(@NgayCham_Cu),@MaNV_Cu);
        RETURN -2;
    END;

    -- Validate trạng thái mới nếu có
    IF @TrangThai IS NOT NULL
       AND @TrangThai NOT IN ('DL','WFH','CX','NP','OM','KP','NG')
    BEGIN
        RAISERROR(N'sp_ChamCong_CapNhat: TrangThai [%s] không hợp lệ.',16,1,@TrangThai);
        RETURN -3;
    END;

    -- Validate giờ giấc mới
    DECLARE @Vao_Moi TIME(0) = ISNULL(@GioVao, @Vao_Cu);
    DECLARE @Ra_Moi  TIME(0) = ISNULL(@GioRa,  @Ra_Cu);
    IF @Vao_Moi IS NOT NULL AND @Ra_Moi IS NOT NULL AND @Ra_Moi <= @Vao_Moi
    BEGIN
        RAISERROR(N'sp_ChamCong_CapNhat: GioRa phải sau GioVao.',16,1);
        RETURN -4;
    END;

    -- Tính lại SoGioLam
    DECLARE @SoGioLam_Moi DECIMAL(4,2) = 0;
    DECLARE @TT_Moi NCHAR(3) = ISNULL(@TrangThai, @TT_Cu);
    IF @Vao_Moi IS NOT NULL AND @Ra_Moi IS NOT NULL
       AND @TT_Moi IN ('DL','WFH','CX')
    BEGIN
        SET @SoGioLam_Moi =
            CAST(DATEDIFF(MINUTE,@Vao_Moi,@Ra_Moi) / 60.0 AS DECIMAL(4,2))
            - CASE WHEN DATEDIFF(MINUTE,@Vao_Moi,@Ra_Moi) > 300
                   THEN 1.0 ELSE 0.0 END;
    END;

    -- Ghi chú chỉnh sửa
    DECLARE @GhiChuFinal NVARCHAR(300) =
        ISNULL(@GhiChu, '')
        + CASE WHEN @LyDoChinhSua IS NOT NULL
               THEN N' [Chỉnh sửa: ' + @LyDoChinhSua
                    + N' — ' + ISNULL(@NguoiCapNhat,SYSTEM_USER)
                    + N' lúc ' + CONVERT(NVARCHAR,GETDATE(),113) + N']'
               ELSE N'' END;

    BEGIN TRANSACTION;
    BEGIN TRY
        UPDATE dbo.ChamCong SET
            TrangThai       = ISNULL(@TrangThai,   TrangThai),
            GioVao          = ISNULL(@GioVao,       GioVao),
            GioRa           = ISNULL(@GioRa,        GioRa),
            SoGioLam        = @SoGioLam_Moi,
            SoGioTangCa     = ISNULL(@SoGioTangCa,  SoGioTangCa),
            HeSoTangCa      = ISNULL(@HeSoTangCa,   HeSoTangCa),
            GhiChu          = @GhiChuFinal,
            NguoiCapNhat    = ISNULL(@NguoiCapNhat, SYSTEM_USER),
            NgayCapNhat     = GETDATE()
        WHERE MaCC = @MaCC;

        COMMIT TRANSACTION;
        PRINT N'[OK] Đã cập nhật MaCC=' + CAST(@MaCC AS NVARCHAR)
            + N' | NV=' + @MaNV_Cu
            + N' | Ngày=' + CONVERT(NVARCHAR,@NgayCham_Cu,103)
            + N' | ' + @TT_Cu + N' → ' + ISNULL(@TrangThai,@TT_Cu);
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO
PRINT N'[OK] sp_ChamCong_CapNhat';
GO


-- ============================================================
-- SP 4: sp_ChamCong_DongBoNghiPhep
-- ─────────────────────────────────────────────────────────────
-- Đồng bộ đơn nghỉ đã được DUYỆT (TrangThai='A') vào bảng
-- ChamCong: các ngày trong khoảng [NgayBatDau, NgayKetThuc]
-- sẽ được đổi sang TrangThai='NP' hoặc 'OM' tùy LoaiNghi.
-- Chỉ tác động ngày làm việc (bỏ qua T7/CN và ngày lễ).
-- ============================================================
IF OBJECT_ID('dbo.sp_ChamCong_DongBoNghiPhep','P') IS NOT NULL
    DROP PROCEDURE dbo.sp_ChamCong_DongBoNghiPhep;
GO

CREATE PROCEDURE dbo.sp_ChamCong_DongBoNghiPhep
    @MaNP           INT     = NULL,     -- NULL = đồng bộ tất cả đơn chưa sync
    @NguoiCapNhat   NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @np_MaNP        INT,
        @np_MaNV        NCHAR(10),
        @np_MaLoai      TINYINT,
        @np_TuNgay      DATE,
        @np_DenNgay     DATE,
        @np_TrangThaiCC NCHAR(3),   -- NP hoặc OM
        @np_SoNgaySync  INT = 0,
        @TongSync       INT = 0,
        @NgayLoop       DATE,
        @NguoiCN        NVARCHAR(100) = ISNULL(@NguoiCapNhat,SYSTEM_USER);

    -- Cursor qua các đơn đã duyệt, chưa đồng bộ
    DECLARE cur_NP CURSOR LOCAL FAST_FORWARD FOR
        SELECT np.MaNP, np.MaNV, np.MaLoaiNghi,
               np.NgayBatDau, np.NgayKetThuc
        FROM dbo.NghiPhep np
        WHERE np.TrangThai = 'A'              -- Đã duyệt
          AND (@MaNP IS NULL OR np.MaNP = @MaNP)
          -- Chỉ đồng bộ đơn chưa được mark IsDaSyncCC
          AND (np.IsDaSyncCC = 0 OR np.IsDaSyncCC IS NULL)
        ORDER BY np.MaNV, np.NgayBatDau;

    OPEN cur_NP;
    FETCH NEXT FROM cur_NP
        INTO @np_MaNP, @np_MaNV, @np_MaLoai, @np_TuNgay, @np_DenNgay;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Xác định TrangThai CC tương ứng loại nghỉ
        SELECT @np_TrangThaiCC =
            CASE @np_MaLoai
                WHEN 1 THEN 'NP'    -- Phép năm
                WHEN 2 THEN 'OM'    -- Nghỉ ốm
                WHEN 3 THEN 'NP'    -- Thai sản (dài hạn)
                WHEN 4 THEN 'KP'    -- Không lương → KP
                WHEN 5 THEN 'NP'    -- Nghỉ bù
                ELSE       'NP'
            END;

        SET @np_SoNgaySync = 0;
        SET @NgayLoop = @np_TuNgay;

        BEGIN TRANSACTION;
        BEGIN TRY
            -- Duyệt từng ngày trong khoảng nghỉ
            WHILE @NgayLoop <= @np_DenNgay
            BEGIN
                -- Chỉ xử lý ngày làm việc (bỏ T7/CN + lễ)
                IF DATENAME(WEEKDAY,@NgayLoop) NOT IN ('Saturday','Sunday')
                   AND NOT EXISTS (
                        SELECT 1 FROM dbo.NgayLe WHERE NgayLe = @NgayLoop)
                BEGIN
                    -- UPSERT: đổi bản ghi đã có hoặc tạo mới
                    IF EXISTS (
                        SELECT 1 FROM dbo.ChamCong
                        WHERE MaNV=@np_MaNV AND NgayCham=@NgayLoop
                    )
                        UPDATE dbo.ChamCong SET
                            TrangThai    = @np_TrangThaiCC,
                            GioVao       = NULL,
                            GioRa        = NULL,
                            SoGioLam     = 0,
                            GhiChu       = N'Đồng bộ từ đơn nghỉ #'
                                           + CAST(@np_MaNP AS NVARCHAR),
                            NguoiCapNhat = @NguoiCN,
                            NgayCapNhat  = GETDATE()
                        WHERE MaNV=@np_MaNV AND NgayCham=@NgayLoop;
                    ELSE
                        INSERT INTO dbo.ChamCong
                            (MaNV,NgayCham,TrangThai,GioVao,GioRa,
                             SoGioLam,SoGioTangCa,HeSoTangCa,
                             GhiChu,NguoiCapNhat,NgayTao)
                        VALUES (
                            @np_MaNV,@NgayLoop,@np_TrangThaiCC,NULL,NULL,
                            0,0,1.50,
                            N'Đồng bộ từ đơn nghỉ #'+CAST(@np_MaNP AS NVARCHAR),
                            @NguoiCN,GETDATE()
                        );

                    SET @np_SoNgaySync = @np_SoNgaySync + 1;
                END;

                SET @NgayLoop = DATEADD(DAY,1,@NgayLoop);
            END; -- WHILE ngày

            -- Đánh dấu đơn đã được sync
            UPDATE dbo.NghiPhep
            SET IsDaSyncCC = 1,
                NgayCapNhat = GETDATE()
            WHERE MaNP = @np_MaNP;

            COMMIT TRANSACTION;
            SET @TongSync = @TongSync + @np_SoNgaySync;

            PRINT N'  [OK] Đơn #' + CAST(@np_MaNP AS NVARCHAR)
                + N' | NV=' + @np_MaNV
                + N' | ' + CONVERT(NVARCHAR,@np_TuNgay,103)
                + N' → ' + CONVERT(NVARCHAR,@np_DenNgay,103)
                + N' | Sync=' + CAST(@np_SoNgaySync AS NVARCHAR) + N' ngày';
        END TRY
        BEGIN CATCH
            IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
            PRINT N'  [ERR] Đơn #' + CAST(@np_MaNP AS NVARCHAR)
                + N' — ' + ERROR_MESSAGE();
        END CATCH;

        FETCH NEXT FROM cur_NP
            INTO @np_MaNP,@np_MaNV,@np_MaLoai,@np_TuNgay,@np_DenNgay;
    END;

    CLOSE cur_NP; DEALLOCATE cur_NP;

    PRINT N'[DONE] sp_ChamCong_DongBoNghiPhep — Tổng '
        + CAST(@TongSync AS NVARCHAR) + N' ngày CC được cập nhật.';
END;
GO
PRINT N'[OK] sp_ChamCong_DongBoNghiPhep';
GO


-- ============================================================
-- SP 5: sp_NghiPhep_PheDuyet
-- ─────────────────────────────────────────────────────────────
-- Trưởng phòng / HR duyệt hoặc từ chối đơn nghỉ phép.
-- Sau khi duyệt → tự động gọi sp_ChamCong_DongBoNghiPhep.
-- ============================================================
IF OBJECT_ID('dbo.sp_NghiPhep_PheDuyet','P') IS NOT NULL
    DROP PROCEDURE dbo.sp_NghiPhep_PheDuyet;
GO

CREATE PROCEDURE dbo.sp_NghiPhep_PheDuyet
    @MaNP               INT,
    @QuyetDinh          NCHAR(1),       -- 'A'=Approve / 'R'=Reject
    @MaNVDuyet          NCHAR(10),
    @GhiChuDuyet        NVARCHAR(300)   = NULL,
    @TuDongSyncChamCong BIT             = 1
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    -- Validate đơn tồn tại
    IF NOT EXISTS (SELECT 1 FROM dbo.NghiPhep WHERE MaNP=@MaNP)
    BEGIN
        RAISERROR(N'sp_NghiPhep_PheDuyet: Đơn #%d không tồn tại.',16,1,@MaNP);
        RETURN -1;
    END;

    -- Chỉ được duyệt đơn đang chờ
    IF NOT EXISTS (
        SELECT 1 FROM dbo.NghiPhep WHERE MaNP=@MaNP AND TrangThai='P'
    )
    BEGIN
        DECLARE @TT_Hien NCHAR(1);
        SELECT @TT_Hien = TrangThai FROM dbo.NghiPhep WHERE MaNP=@MaNP;
        RAISERROR(N'sp_NghiPhep_PheDuyet: Đơn #%d đang ở trạng thái [%s], không thể phê duyệt.',
            16,1,@MaNP,@TT_Hien);
        RETURN -2;
    END;

    -- Validate quyết định
    IF @QuyetDinh NOT IN ('A','R')
    BEGIN
        RAISERROR(N'sp_NghiPhep_PheDuyet: @QuyetDinh phải là A (Approve) hoặc R (Reject).',16,1);
        RETURN -3;
    END;

    -- Validate người duyệt tồn tại
    IF NOT EXISTS (
        SELECT 1 FROM dbo.NhanVien WHERE MaNV=@MaNVDuyet
    )
    BEGIN
        RAISERROR(N'sp_NghiPhep_PheDuyet: Người duyệt [%s] không tồn tại.',16,1,@MaNVDuyet);
        RETURN -4;
    END;

    BEGIN TRANSACTION;
    BEGIN TRY
        -- Cập nhật trạng thái đơn
        UPDATE dbo.NghiPhep SET
            TrangThai    = @QuyetDinh,
            MaNVDuyet    = @MaNVDuyet,
            NgayDuyet    = GETDATE(),
            GhiChuDuyet  = @GhiChuDuyet,
            NgayCapNhat  = GETDATE()
        WHERE MaNP = @MaNP;

        COMMIT TRANSACTION;

        DECLARE @TenNV NVARCHAR(100);
        SELECT @TenNV = HoTen FROM dbo.NhanVien
        WHERE MaNV = (SELECT MaNV FROM dbo.NghiPhep WHERE MaNP=@MaNP);

        PRINT N'[OK] Đơn #' + CAST(@MaNP AS NVARCHAR)
            + N' của ' + @TenNV + N' → '
            + CASE @QuyetDinh WHEN 'A' THEN N'✅ DUYỆT' ELSE N'❌ TỪ CHỐI' END;

        -- Nếu duyệt → đồng bộ chấm công ngay
        IF @QuyetDinh = 'A' AND @TuDongSyncChamCong = 1
        BEGIN
            PRINT N'  → Đồng bộ chấm công...';
            EXEC dbo.sp_ChamCong_DongBoNghiPhep
                @MaNP         = @MaNP,
                @NguoiCapNhat = @MaNVDuyet;
        END;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO
PRINT N'[OK] sp_NghiPhep_PheDuyet';
GO


-- ============================================================
-- SP 6: sp_ChamCong_BaoCaoThang
-- ─────────────────────────────────────────────────────────────
-- Báo cáo tổng hợp chấm công cho 1 kỳ tháng.
-- Xuất 3 result sets:
--   RS1: Tổng hợp theo từng nhân viên (cho HR xem + xuất Excel)
--   RS2: Danh sách NV vắng không phép (cần xử lý kỷ luật)
--   RS3: Top tăng ca trong tháng
-- ============================================================
IF OBJECT_ID('dbo.sp_ChamCong_BaoCaoThang','P') IS NOT NULL
    DROP PROCEDURE dbo.sp_ChamCong_BaoCaoThang;
GO

CREATE PROCEDURE dbo.sp_ChamCong_BaoCaoThang
    @Thang          TINYINT,
    @Nam            SMALLINT,
    @MaPB           NCHAR(10)   = NULL,     -- NULL = tất cả PB
    @ChiInVangKP    BIT         = 0          -- 1 = chỉ NV có vắng KP
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE
        @NgayChuanThang TINYINT = dbo.fn_SoNgayChuanThang(@Thang, @Nam),
        @TenThang       NVARCHAR(20) =
            N'Tháng ' + CAST(@Thang AS NVARCHAR) + N'/' + CAST(@Nam AS NVARCHAR);

    PRINT N'════════════════════════════════════════════════════════';
    PRINT N'  BÁO CÁO CHẤM CÔNG — ' + @TenThang;
    PRINT N'  Ngày làm việc chuẩn: ' + CAST(@NgayChuanThang AS NVARCHAR) + N' ngày';
    PRINT N'════════════════════════════════════════════════════════';

    -- ── RS1: Tổng hợp từng NV ────────────────────────────────
    SELECT
        pb.TenPB                                AS [Phòng Ban],
        nv.MaNV,
        nv.HoTen                                AS [Họ Tên],
        cv.TenCV                                AS [Chức Vụ],

        @NgayChuanThang                         AS [Ngày Chuẩn],

        COUNT(CASE WHEN cc.TrangThai='DL'  THEN 1 END) AS [Đi Làm],
        COUNT(CASE WHEN cc.TrangThai='WFH' THEN 1 END) AS [WFH],
        COUNT(CASE WHEN cc.TrangThai='CX'  THEN 1 END) AS [Công Tác],
        COUNT(CASE WHEN cc.TrangThai IN ('DL','WFH','CX') THEN 1 END)
                                                AS [Tổng Có Mặt],
        COUNT(CASE WHEN cc.TrangThai='NP'  THEN 1 END) AS [Nghỉ Phép],
        COUNT(CASE WHEN cc.TrangThai='OM'  THEN 1 END) AS [Nghỉ Ốm],
        COUNT(CASE WHEN cc.TrangThai='KP'  THEN 1 END) AS [Vắng KP ⚠️],
        COUNT(CASE WHEN cc.TrangThai='NG'  THEN 1 END) AS [Ngày Lễ],

        -- Ngày tính lương (ảnh hưởng hệ số)
        COUNT(CASE WHEN cc.TrangThai IN
              ('DL','WFH','CX','NP','OM') THEN 1 END)
                                                AS [Ngày Tính Lương],

        -- Tỷ lệ chuyên cần
        FORMAT(
            CAST(COUNT(CASE WHEN cc.TrangThai IN
                ('DL','WFH','CX') THEN 1 END) AS DECIMAL)
            / NULLIF(@NgayChuanThang,0),
            'P1'
        )                                       AS [Tỷ Lệ CC],

        -- Tăng ca
        FORMAT(SUM(ISNULL(cc.SoGioTangCa,0)),'N1') AS [Giờ Tăng Ca],
        FORMAT(SUM(ISNULL(cc.SoGioLam,0)),'N1')    AS [Tổng Giờ Làm]

    FROM dbo.NhanVien nv
    JOIN dbo.PhongBan  pb ON nv.MaPB = pb.MaPB
    JOIN dbo.ChucVu    cv ON nv.MaCV = cv.MaCV
    LEFT JOIN dbo.ChamCong cc
        ON nv.MaNV = cc.MaNV
       AND MONTH(cc.NgayCham) = @Thang
       AND YEAR(cc.NgayCham)  = @Nam
    WHERE nv.TrangThai IN ('A','P')
      AND (@MaPB IS NULL OR nv.MaPB = @MaPB)
    GROUP BY pb.TenPB, nv.MaNV, nv.HoTen, cv.TenCV
    HAVING (
        @ChiInVangKP = 0
        OR COUNT(CASE WHEN cc.TrangThai='KP' THEN 1 END) > 0
    )
    ORDER BY pb.TenPB, nv.HoTen;

    -- ── RS2: Danh sách vi phạm vắng KP ───────────────────────
    PRINT N'';
    PRINT N'── Danh sách vắng không phép (cần xử lý) ─────────────';
    SELECT
        nv.MaNV,
        nv.HoTen,
        pb.TenPB                                AS PhongBan,
        CONVERT(NVARCHAR,cc.NgayCham,103)       AS NgayVang,
        DATENAME(WEEKDAY,cc.NgayCham)           AS ThuTrongTuan,
        cc.GhiChu
    FROM dbo.ChamCong cc
    JOIN dbo.NhanVien nv ON cc.MaNV = nv.MaNV
    JOIN dbo.PhongBan pb ON nv.MaPB = pb.MaPB
    WHERE cc.TrangThai         = 'KP'
      AND MONTH(cc.NgayCham)   = @Thang
      AND YEAR(cc.NgayCham)    = @Nam
      AND (@MaPB IS NULL OR nv.MaPB = @MaPB)
    ORDER BY nv.MaNV, cc.NgayCham;

    -- ── RS3: Top 10 tăng ca nhiều nhất ───────────────────────
    PRINT N'';
    PRINT N'── Top 10 nhân viên tăng ca nhiều nhất ───────────────';
    SELECT TOP 10
        nv.MaNV,
        nv.HoTen,
        pb.TenPB                                AS PhongBan,
        FORMAT(SUM(cc.SoGioTangCa),'N1')        AS [Tổng Giờ TC],
        COUNT(CASE WHEN cc.SoGioTangCa>0 THEN 1 END)
                                                AS [Số Ngày TC],
        FORMAT(AVG(CASE WHEN cc.SoGioTangCa>0
                        THEN cc.SoGioTangCa END),'N1')
                                                AS [Giờ TC/Ngày TB]
    FROM dbo.ChamCong cc
    JOIN dbo.NhanVien nv ON cc.MaNV = nv.MaNV
    JOIN dbo.PhongBan pb ON nv.MaPB = pb.MaPB
    WHERE MONTH(cc.NgayCham) = @Thang
      AND YEAR(cc.NgayCham)  = @Nam
      AND cc.SoGioTangCa     > 0
      AND (@MaPB IS NULL OR nv.MaPB = @MaPB)
    GROUP BY nv.MaNV, nv.HoTen, pb.TenPB
    ORDER BY SUM(cc.SoGioTangCa) DESC;
END;
GO
PRINT N'[OK] sp_ChamCong_BaoCaoThang';
GO


-- ============================================================
-- DEMO & KIỂM THỬ
-- ============================================================
PRINT N'';
PRINT N'════════════════════════════════════════════════════════';
PRINT N'  DEMO — Chạy thử các Stored Procedures';
PRINT N'════════════════════════════════════════════════════════';

-- Test sp_ChamCong_NhapHangNgay: nhập 1 ngày cho NV000001
DECLARE @MaCC_Test INT;
EXEC dbo.sp_ChamCong_NhapHangNgay
    @MaNV           = 'NV000001',
    @NgayCham       = '2024-12-02',   -- Ngày đã qua
    @TrangThai      = 'DL',
    @GioVao         = '08:00',
    @GioRa          = '18:00',
    @SoGioTangCa    = 1.0,
    @GhiChu         = N'Test nhập ngày 02/12/2024',
    @MaCC_Out       = @MaCC_Test OUTPUT;
PRINT N'  → MaCC vừa tạo: ' + CAST(@MaCC_Test AS NVARCHAR);
GO

-- Test sp_ChamCong_CapNhat: sửa giờ vào
DECLARE @MaCC_Sua INT;
SELECT @MaCC_Sua = MaCC FROM dbo.ChamCong
WHERE MaNV='NV000001' AND NgayCham='2024-12-02';

EXEC dbo.sp_ChamCong_CapNhat
    @MaCC           = @MaCC_Sua,
    @GioVao         = '07:45',
    @LyDoChinhSua   = N'Nhân viên check-in lúc 7:45, cập nhật từ hệ thống',
    @NguoiCapNhat   = N'HR_ADMIN';
GO

-- Test sp_NghiPhep_PheDuyet: duyệt đơn chờ
PRINT N'';
PRINT N'--- Duyệt đơn nghỉ chờ phê duyệt ---';
SELECT MaNP, MaNV, MaLoaiNghi,
       CONVERT(NVARCHAR,NgayBatDau,103) NgayBD,
       CONVERT(NVARCHAR,NgayKetThuc,103) NgayKT,
       TrangThai
FROM dbo.NghiPhep WHERE TrangThai = 'P';
GO

-- Duyệt đơn NV000029 (đơn chờ từ seed_data)
EXEC dbo.sp_NghiPhep_PheDuyet
    @MaNP               = (SELECT TOP 1 MaNP FROM dbo.NghiPhep WHERE TrangThai='P' ORDER BY MaNP),
    @QuyetDinh          = 'A',
    @MaNVDuyet          = 'NV000003',
    @GhiChuDuyet        = N'Đồng ý, đảm bảo bàn giao công việc trước khi nghỉ.',
    @TuDongSyncChamCong = 1;
GO

-- Test sp_ChamCong_BaoCaoThang
PRINT N'';
PRINT N'--- Báo cáo chấm công tháng 3/2025 ---';
EXEC dbo.sp_ChamCong_BaoCaoThang
    @Thang = 3, @Nam = 2025;
GO

-- Test nhập loạt từ #ChamCongBulk
PRINT N'';
PRINT N'--- Test nhập loạt (5 bản ghi mẫu) ---';
CREATE TABLE #ChamCongBulk (
    MaNV        NCHAR(10),
    NgayCham    DATE,
    TrangThai   NCHAR(3),
    GioVao      TIME(0)      NULL,
    GioRa       TIME(0)      NULL,
    SoGioTangCa DECIMAL(4,2) NULL,
    GhiChu      NVARCHAR(300) NULL
);
INSERT #ChamCongBulk VALUES
    ('NV000005','2024-11-04','DL','08:00','17:30',0,   NULL),
    ('NV000005','2024-11-05','DL','08:00','17:30',2.0, N'Tăng ca dự án'),
    ('NV000005','2024-11-06','DL','08:00','17:30',0,   NULL),
    ('NV000005','2024-11-07','NP', NULL,  NULL,   0,   N'Nghỉ phép năm'),
    ('NV000005','2024-11-08','DL','08:30','17:30',0,   N'Đi trễ 30 phút');

EXEC dbo.sp_ChamCong_NhapLoat
    @Thang          = 11,
    @Nam            = 2024,
    @NguoiCapNhat   = 'HR_ADMIN',
    @StopOnError    = 0;

DROP TABLE #ChamCongBulk;
GO

PRINT N'';
PRINT N'[DONE] sp_ChamCong.sql — 6 stored procedures hoàn tất.';
PRINT N'';
PRINT N'Danh sách SP đã tạo:';
PRINT N'  1. sp_ChamCong_NhapHangNgay   — UPSERT 1 NV 1 ngày';
PRINT N'  2. sp_ChamCong_NhapLoat       — Nhập hàng loạt từ #ChamCongBulk';
PRINT N'  3. sp_ChamCong_CapNhat        — Sửa bản ghi theo MaCC';
PRINT N'  4. sp_ChamCong_DongBoNghiPhep — Sync đơn duyệt → ChamCong';
PRINT N'  5. sp_NghiPhep_PheDuyet       — Duyệt / từ chối + auto-sync';
PRINT N'  6. sp_ChamCong_BaoCaoThang    — 3 báo cáo: tổng hợp + KP + tăng ca';
GO
