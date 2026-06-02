-- ============================================================
-- FILE       : fn_SoNgayLamViec.sql
-- PROJECT    : Hệ Thống Quản Lý Nhân Sự & Tính Lương Tự Động
-- MỤC ĐÍCH   : Các hàm tính ngày công — nền tảng cho sp_TinhLuong
-- FUNCTIONS  :
--   1. fn_SoNgayChuanThang  — Scalar: ngày chuẩn làm việc/tháng
--                             (loại cuối tuần + lễ)
--   2. fn_SoNgayChamCong    — Scalar: ngày đi làm thực tế (từ ChamCong)
--   3. fn_SoNgayNghiCoLuong — Scalar: ngày nghỉ hưởng lương (phép + ốm)
--   4. fn_HeSoLuongThang    — Scalar: hệ số lương theo ngày công
--                             = SoNgayDiLam / SoNgayChuanThang
--   5. fn_TinhLuongLamThem  — Scalar: lương tăng ca kỳ tháng
-- DEPENDENCY : Chạy SAU fn_TinhBHXH.sql, cần seed_data.sql
-- ============================================================

USE HRPayrollDB;
GO

-- ============================================================
-- HÀM 1: fn_SoNgayChuanThang
-- ─────────────────────────────────────────────────────────────
-- Đếm số ngày làm việc tiêu chuẩn trong tháng:
--   = tổng ngày trong tháng - cuối tuần - ngày lễ chính thức
-- Dùng để tính: HeSoNgayCong = NgayDiLam / NgayChuanThang
-- ============================================================

IF OBJECT_ID('dbo.fn_SoNgayChuanThang', 'FN') IS NOT NULL
    DROP FUNCTION dbo.fn_SoNgayChuanThang;
GO

CREATE FUNCTION dbo.fn_SoNgayChuanThang
(
    @Thang  TINYINT,
    @Nam    SMALLINT
)
RETURNS TINYINT
AS
BEGIN
    -- Bảng ngày lễ cứng (không đổi hàng năm)
    -- Ngày lễ theo ngày dương (không tính Tết ÂL vì biến động)
    DECLARE @NgayDauThang  DATE = DATEFROMPARTS(@Nam, @Thang, 1);
    DECLARE @NgayCuoiThang DATE = EOMONTH(@NgayDauThang);
    DECLARE @NgayChuan     INT  = 0;
    DECLARE @NgayLay       DATE = @NgayDauThang;

    -- Duyệt từng ngày trong tháng
    WHILE @NgayLay <= @NgayCuoiThang
    BEGIN
        -- Chỉ đếm ngày trong tuần (thứ 2 đến thứ 6)
        IF DATENAME(WEEKDAY, @NgayLay) NOT IN ('Saturday','Sunday')
        BEGIN
            -- Loại ngày lễ cố định dương lịch:
            -- 01/01 Tết DL, 30/04 Ngày giải phóng,
            -- 01/05 Quốc tế LĐ, 02/09 Quốc khánh
            IF NOT (
                (MONTH(@NgayLay) = 1  AND DAY(@NgayLay) = 1 ) OR
                (MONTH(@NgayLay) = 4  AND DAY(@NgayLay) = 30) OR
                (MONTH(@NgayLay) = 5  AND DAY(@NgayLay) = 1 ) OR
                (MONTH(@NgayLay) = 9  AND DAY(@NgayLay) = 2 )
            )
            BEGIN
                -- Kiểm tra thêm ngày Tết ÂL & Giỗ Tổ trong bảng NghiLe
                -- (bảng được populate hàng năm bởi HR)
                IF NOT EXISTS (
                    SELECT 1 FROM dbo.NgayLe
                    WHERE NgayLe = @NgayLay
                )
                    SET @NgayChuan = @NgayChuan + 1;
            END
        END;
        SET @NgayLay = DATEADD(DAY, 1, @NgayLay);
    END;

    RETURN CAST(@NgayChuan AS TINYINT);
END;
GO

PRINT N'[OK] fn_SoNgayChuanThang — tạo thành công';
GO


-- ============================================================
-- HÀM 2: fn_SoNgayChamCong
-- ─────────────────────────────────────────────────────────────
-- Đếm số ngày làm việc thực tế từ bảng ChamCong:
--   TrangThai IN ('DL','WFH','CX') → tính là có mặt
--   'NP','OM'                      → nghỉ hưởng lương (tham số riêng)
--   'KP'                           → nghỉ không phép (trừ lương)
--   'NG'                           → lễ (không trừ, không cộng)
-- ============================================================

IF OBJECT_ID('dbo.fn_SoNgayChamCong', 'FN') IS NOT NULL
    DROP FUNCTION dbo.fn_SoNgayChamCong;
GO

CREATE FUNCTION dbo.fn_SoNgayChamCong
(
    @MaNV   NCHAR(10),
    @Thang  TINYINT,
    @Nam    SMALLINT
)
RETURNS DECIMAL(5,1)  -- 0.5 ngày nếu làm nửa ngày (mở rộng tương lai)
AS
BEGIN
    DECLARE @SoNgay DECIMAL(5,1);

    SELECT @SoNgay = COUNT(*)
    FROM dbo.ChamCong
    WHERE MaNV    = @MaNV
      AND MONTH(NgayCham) = @Thang
      AND YEAR(NgayCham)  = @Nam
      AND TrangThai IN ('DL', 'WFH', 'CX');
        -- DL  = Đi làm tại văn phòng
        -- WFH = Work From Home (tính đủ công)
        -- CX  = Công tác xa (tính đủ công)

    RETURN ISNULL(@SoNgay, 0);
END;
GO

PRINT N'[OK] fn_SoNgayChamCong — tạo thành công';
GO


-- ============================================================
-- HÀM 3: fn_SoNgayNghiCoLuong
-- ─────────────────────────────────────────────────────────────
-- Đếm ngày nghỉ HƯỞNG LƯƠNG: phép năm đã duyệt + nghỉ ốm
-- Những ngày này tính là "có công" trong sp_TinhLuong
-- ============================================================

IF OBJECT_ID('dbo.fn_SoNgayNghiCoLuong', 'FN') IS NOT NULL
    DROP FUNCTION dbo.fn_SoNgayNghiCoLuong;
GO

CREATE FUNCTION dbo.fn_SoNgayNghiCoLuong
(
    @MaNV   NCHAR(10),
    @Thang  TINYINT,
    @Nam    SMALLINT
)
RETURNS DECIMAL(5,1)
AS
BEGIN
    DECLARE @SoNgay DECIMAL(5,1);

    SELECT @SoNgay = COUNT(*)
    FROM dbo.ChamCong
    WHERE MaNV    = @MaNV
      AND MONTH(NgayCham) = @Thang
      AND YEAR(NgayCham)  = @Nam
      AND TrangThai IN ('NP', 'OM');
        -- NP = Nghỉ phép (hưởng lương)
        -- OM = Nghỉ ốm (hưởng lương BHXH)

    RETURN ISNULL(@SoNgay, 0);
END;
GO

PRINT N'[OK] fn_SoNgayNghiCoLuong — tạo thành công';
GO


-- ============================================================
-- HÀM 4: fn_SoNgayNghiKhongLuong
-- Đếm ngày nghỉ KHÔNG hưởng lương trong tháng
-- ============================================================

IF OBJECT_ID('dbo.fn_SoNgayNghiKhongLuong', 'FN') IS NOT NULL
    DROP FUNCTION dbo.fn_SoNgayNghiKhongLuong;
GO

CREATE FUNCTION dbo.fn_SoNgayNghiKhongLuong
(
    @MaNV   NCHAR(10),
    @Thang  TINYINT,
    @Nam    SMALLINT
)
RETURNS DECIMAL(5,1)
AS
BEGIN
    DECLARE @SoNgay DECIMAL(5,1);

    SELECT @SoNgay = COUNT(*)
    FROM dbo.ChamCong
    WHERE MaNV    = @MaNV
      AND MONTH(NgayCham) = @Thang
      AND YEAR(NgayCham)  = @Nam
      AND TrangThai = 'KP';   -- Vắng không phép → trừ lương

    RETURN ISNULL(@SoNgay, 0);
END;
GO

PRINT N'[OK] fn_SoNgayNghiKhongLuong — tạo thành công';
GO


-- ============================================================
-- HÀM 5: fn_HeSoLuongThang
-- ─────────────────────────────────────────────────────────────
-- Tính hệ số lương = (NgayDiLam + NgayNghiCoLuong) / NgayChuan
-- Dùng để nhân với LuongCoBan khi NV không làm đủ tháng
-- Ví dụ: vào làm ngày 15/3, ngày chuan=21, di lam=11 → 11/21 = 0.524
-- ============================================================

IF OBJECT_ID('dbo.fn_HeSoLuongThang', 'FN') IS NOT NULL
    DROP FUNCTION dbo.fn_HeSoLuongThang;
GO

CREATE FUNCTION dbo.fn_HeSoLuongThang
(
    @MaNV   NCHAR(10),
    @Thang  TINYINT,
    @Nam    SMALLINT
)
RETURNS DECIMAL(10,6)   -- Độ chính xác cao để tránh sai số làm tròn
AS
BEGIN
    DECLARE
        @NgayDiLam      DECIMAL(5,1) = dbo.fn_SoNgayChamCong(@MaNV, @Thang, @Nam),
        @NgayNghiCL     DECIMAL(5,1) = dbo.fn_SoNgayNghiCoLuong(@MaNV, @Thang, @Nam),
        @NgayChuan      TINYINT      = dbo.fn_SoNgayChuanThang(@Thang, @Nam);

    -- Tránh chia cho 0 khi tháng không có ngày làm việc
    IF @NgayChuan = 0 RETURN 0;

    -- Hệ số lương: cộng cả nghỉ phép hưởng lương
    DECLARE @HeSo DECIMAL(10,6) =
        CAST(@NgayDiLam + @NgayNghiCL AS DECIMAL(10,6)) / @NgayChuan;

    -- Cap tại 1.0: không thể > 100% dù có nghỉ bù cộng vào
    RETURN CASE WHEN @HeSo > 1.0 THEN 1.0 ELSE @HeSo END;
END;
GO

PRINT N'[OK] fn_HeSoLuongThang — tạo thành công';
GO


-- ============================================================
-- HÀM 6: fn_TinhLuongLamThem
-- ─────────────────────────────────────────────────────────────
-- Tính lương tăng ca trong tháng
-- Lương tăng ca 1 giờ = (LuongCoBan / NgayChuanThang / 8) × HeSo
-- BR-12: HeSo 1.5x ngày thường, 2.0x cuối tuần, 3.0x ngày lễ
-- ============================================================

IF OBJECT_ID('dbo.fn_TinhLuongLamThem', 'FN') IS NOT NULL
    DROP FUNCTION dbo.fn_TinhLuongLamThem;
GO

CREATE FUNCTION dbo.fn_TinhLuongLamThem
(
    @MaNV       NCHAR(10),
    @Thang      TINYINT,
    @Nam        SMALLINT,
    @LuongCoBan DECIMAL(18,2)
)
RETURNS DECIMAL(18,2)
AS
BEGIN
    DECLARE @NgayChuan  TINYINT       = dbo.fn_SoNgayChuanThang(@Thang, @Nam);

    -- Lương 1 giờ chuẩn
    DECLARE @LuongGioChuan DECIMAL(18,6) =
        @LuongCoBan / @NgayChuan / 8.0;

    -- Tổng lương tăng ca = SUM(SoGioTangCa × HeSoTangCa × LuongGio)
    DECLARE @TongLTC DECIMAL(18,2);

    SELECT @TongLTC = SUM(
        cc.SoGioTangCa * cc.HeSoTangCa * @LuongGioChuan
    )
    FROM dbo.ChamCong cc
    WHERE cc.MaNV           = @MaNV
      AND MONTH(cc.NgayCham) = @Thang
      AND YEAR(cc.NgayCham)  = @Nam
      AND cc.SoGioTangCa     > 0;

    RETURN ISNULL(ROUND(@TongLTC, 0), 0);
END;
GO

PRINT N'[OK] fn_TinhLuongLamThem — tạo thành công';
GO


-- ============================================================
-- KIỂM THỬ ĐẦY ĐỦ
-- ============================================================

PRINT N'';
PRINT N'════════════════════════════════════════════════════════';
PRINT N'  KIỂM THỬ CÁC HÀM NGÀY CÔNG';
PRINT N'════════════════════════════════════════════════════════';

-- Số ngày chuẩn Jan-Mar 2025
PRINT N'--- Số ngày làm việc chuẩn Jan-Mar 2025 ---';
SELECT
    Thang, Nam,
    dbo.fn_SoNgayChuanThang(Thang, Nam) AS NgayChuanLamViec
FROM (VALUES (1,2025),(2,2025),(3,2025),(4,2025),(5,2025)) T(Thang, Nam);
GO

-- Test thực tế với dữ liệu đã seed
PRINT N'';
PRINT N'--- Thống kê ngày công thực tế NV000001 (TGĐ) tháng 1-3/2025 ---';
SELECT
    Ky.Thang,
    Ky.Nam,
    dbo.fn_SoNgayChuanThang(Ky.Thang, Ky.Nam)     AS NgayChuan,
    dbo.fn_SoNgayChamCong('NV000001', Ky.Thang, Ky.Nam)  AS NgayDiLam,
    dbo.fn_SoNgayNghiCoLuong('NV000001', Ky.Thang, Ky.Nam) AS NgayNghiCL,
    dbo.fn_SoNgayNghiKhongLuong('NV000001', Ky.Thang, Ky.Nam) AS NgayKhongPhep,
    FORMAT(dbo.fn_HeSoLuongThang('NV000001', Ky.Thang, Ky.Nam),'P2') AS HeSoLuong,
    FORMAT(dbo.fn_TinhLuongLamThem('NV000001', Ky.Thang, Ky.Nam, 55000000),'N0')
        AS LuongTangCa
FROM (VALUES (1,2025),(2,2025),(3,2025)) Ky(Thang,Nam);
GO

-- Test NV có nghỉ phép (NV000004 - 3 ngày phép tháng 2)
PRINT N'';
PRINT N'--- NV000004 tháng 2/2025 (có 3 ngày phép) ---';
SELECT
    dbo.fn_SoNgayChuanThang(2, 2025)                      AS NgayChuan,
    dbo.fn_SoNgayChamCong('NV000004', 2, 2025)             AS NgayDiLam,
    dbo.fn_SoNgayNghiCoLuong('NV000004', 2, 2025)          AS NgayNghiPhep,
    FORMAT(dbo.fn_HeSoLuongThang('NV000004', 2, 2025),'P4') AS HeSoLuong,
    N'(Phép hưởng lương → vẫn tính đủ công)' AS GhiChu;
GO

-- Test NV vắng không phép (NV000049 tháng 2)
PRINT N'';
PRINT N'--- NV000049 tháng 2/2025 (có 2 ngày KP) ---';
SELECT
    dbo.fn_SoNgayChuanThang(2, 2025)                       AS NgayChuan,
    dbo.fn_SoNgayChamCong('NV000049', 2, 2025)              AS NgayDiLam,
    dbo.fn_SoNgayNghiKhongLuong('NV000049', 2, 2025)        AS NgayVangKP,
    FORMAT(dbo.fn_HeSoLuongThang('NV000049', 2, 2025),'P4') AS HeSoLuong,
    N'(KP không cộng vào hệ số → trừ lương)' AS GhiChu;
GO

-- Test đội CNTT tăng ca tháng 1/2025
PRINT N'';
PRINT N'--- Lương tăng ca team CNTT tháng 1/2025 ---';
SELECT
    nv.MaNV,
    nv.HoTen,
    dbo.fn_TinhLuongLamThem(nv.MaNV, 1, 2025, lcb.LuongCB) AS LuongTangCa,
    lcb.LuongCB AS LuongCoBan
FROM dbo.NhanVien nv
JOIN dbo.LuongCoBan lcb ON nv.MaNV = lcb.MaNV AND lcb.NgayHetHieuLuc IS NULL
WHERE nv.MaPB = 'PB0004'
  AND dbo.fn_TinhLuongLamThem(nv.MaNV, 1, 2025, lcb.LuongCB) > 0
ORDER BY LuongTangCa DESC;
GO

PRINT N'';
PRINT N'[DONE] fn_SoNgayLamViec.sql — 6 functions hoàn tất';
GO
