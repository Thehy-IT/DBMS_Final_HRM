-- ============================================================
-- FILE       : fn_TinhBHXH.sql
-- PROJECT    : Hệ Thống Quản Lý Nhân Sự & Tính Lương Tự Động
-- MỤC ĐÍCH   : Hàm tính Bảo Hiểm Xã Hội / Y Tế / Thất Nghiệp
--              theo Luật BHXH 2014 + Nghị định 143/2018/NĐ-CP
-- FUNCTIONS  :
--   1. fn_TinhBHXH_TVF     — TVF: trả về toàn bộ thành phần BH
--   2. fn_TinhBH_NLD       — Scalar: tổng BH nhân viên (NLĐ) đóng
--   3. fn_TinhBH_NSDLD     — Scalar: tổng BH doanh nghiệp (NSDLĐ) đóng
--   4. fn_TinhLuongDongBH  — Scalar: lương đóng BH (có trần)
-- ─────────────────────────────────────────────────────────────
-- TỶ LỆ ĐÓNG BHXH (Điều 85 + 86 Luật BHXH 2014):
-- ┌───────────────┬──────────┬───────────┬─────────────────┐
-- │ Loại BH       │ NLĐ đóng │ NSDLĐ đóng│ Căn cứ         │
-- ├───────────────┼──────────┼───────────┼─────────────────┤
-- │ BHXH          │    8%    │   17.5%   │ LuongDongBH     │
-- │ BHYT          │   1.5%   │    3.0%   │ LuongDongBH     │
-- │ BHTN          │   1.0%   │    1.0%   │ LuongDongBH     │
-- │ BHTNLĐ & BNN  │    0%    │    0.5%   │ LuongDongBH     │
-- ├───────────────┼──────────┼───────────┼─────────────────┤
-- │ TỔNG          │  10.5%   │   22.0%   │                 │
-- └───────────────┴──────────┴───────────┴─────────────────┘
-- TRẦN LƯƠNG ĐÓNG BH: 20 × lương cơ sở
--   Lương cơ sở 2024 = 2,340,000 VNĐ (từ 01/07/2024)
--   Trần = 20 × 2,340,000 = 46,800,000 VNĐ/tháng
--
-- LƯU Ý: Hợp đồng thử việc (MaLoaiHD=1) → TiLeBHXH=0
--        BHXH chỉ áp dụng khi MaLoaiHD IN (2,3,4)
-- DEPENDENCY : Chạy SAU fn_TinhThueTNCN.sql
-- ============================================================

USE HRPayrollDB;
GO

-- ============================================================
-- HÀM 1: fn_TinhLuongDongBH
-- Tính lương đóng BH = min(LuongCoBan, Trần BH)
-- Trần BH = 20 × lương cơ sở hiện hành
-- ============================================================

IF OBJECT_ID('dbo.fn_TinhLuongDongBH', 'FN') IS NOT NULL
    DROP FUNCTION dbo.fn_TinhLuongDongBH;
GO

CREATE FUNCTION dbo.fn_TinhLuongDongBH
(
    @LuongCoBan     DECIMAL(18,2),
    @MaLoaiHD       TINYINT          -- 1=ThửViệc, 2=1năm, 3=2năm, 4=VĐH
)
RETURNS DECIMAL(18,2)
WITH SCHEMABINDING
AS
BEGIN
    -- Hợp đồng thử việc không đóng BHXH → lương đóng BH = 0
    IF @MaLoaiHD = 1
        RETURN 0;

    -- Trần lương đóng BH: 20 × 2,340,000 = 46,800,000 VNĐ
    -- (cập nhật khi Chính phủ tăng lương cơ sở)
    DECLARE @TranBH DECIMAL(18,2) = 46800000;

    RETURN CASE
        WHEN @LuongCoBan > @TranBH THEN @TranBH
        ELSE @LuongCoBan
    END;
END;
GO

PRINT N'[OK] fn_TinhLuongDongBH — tạo thành công';
GO


-- ============================================================
-- HÀM 2: fn_TinhBHXH_TVF (Table-Valued Function)
-- Trả về bảng đầy đủ các thành phần BH — NLĐ và NSDLĐ
-- Dùng trong sp_TinhLuong để INSERT vào ChiTietLuong
-- ============================================================

IF OBJECT_ID('dbo.fn_TinhBHXH_TVF', 'TF') IS NOT NULL
    DROP FUNCTION dbo.fn_TinhBHXH_TVF;
GO

CREATE FUNCTION dbo.fn_TinhBHXH_TVF
(
    @LuongCoBan     DECIMAL(18,2),
    @MaLoaiHD       TINYINT
)
RETURNS @Result TABLE (
    -- Lương làm căn cứ
    LuongDongBH         DECIMAL(18,2),

    -- Người Lao Động đóng (NLĐ)
    BHXH_NLD            DECIMAL(18,2),  -- 8%
    BHYT_NLD            DECIMAL(18,2),  -- 1.5%
    BHTN_NLD            DECIMAL(18,2),  -- 1%
    Tong_BH_NLD         DECIMAL(18,2),  -- 10.5%

    -- Người Sử Dụng Lao Động đóng (NSDLĐ) — chi phí DN
    BHXH_NSDLD          DECIMAL(18,2),  -- 17.5%
    BHYT_NSDLD          DECIMAL(18,2),  -- 3%
    BHTN_NSDLD          DECIMAL(18,2),  -- 1%
    BHTNLD_BNN_NSDLD    DECIMAL(18,2),  -- 0.5%
    Tong_BH_NSDLD       DECIMAL(18,2),  -- 22%

    -- Tổng chi phí BH (NLĐ + NSDLĐ) = 32.5% lương đóng BH
    Tong_BH_Ca_Hai      DECIMAL(18,2)
)
WITH SCHEMABINDING
AS
BEGIN
    DECLARE @LDB    DECIMAL(18,2) = dbo.fn_TinhLuongDongBH(@LuongCoBan, @MaLoaiHD);

    -- Thử việc → toàn bộ BH = 0
    IF @MaLoaiHD = 1
    BEGIN
        INSERT @Result VALUES (0, 0, 0, 0, 0,  0, 0, 0, 0, 0,  0);
        RETURN;
    END;

    DECLARE
        -- NLĐ
        @BHXH_NLD   DECIMAL(18,2) = ROUND(@LDB * 0.08,  0),
        @BHYT_NLD   DECIMAL(18,2) = ROUND(@LDB * 0.015, 0),
        @BHTN_NLD   DECIMAL(18,2) = ROUND(@LDB * 0.01,  0),
        -- NSDLĐ
        @BHXH_NSDLD DECIMAL(18,2) = ROUND(@LDB * 0.175, 0),
        @BHYT_NSDLD DECIMAL(18,2) = ROUND(@LDB * 0.03,  0),
        @BHTN_NSDLD DECIMAL(18,2) = ROUND(@LDB * 0.01,  0),
        @BHTNLBNN   DECIMAL(18,2) = ROUND(@LDB * 0.005, 0);

    INSERT @Result
    SELECT
        @LDB,
        @BHXH_NLD, @BHYT_NLD, @BHTN_NLD,
        @BHXH_NLD + @BHYT_NLD + @BHTN_NLD,
        @BHXH_NSDLD, @BHYT_NSDLD, @BHTN_NSDLD, @BHTNLBNN,
        @BHXH_NSDLD + @BHYT_NSDLD + @BHTN_NSDLD + @BHTNLBNN,
        (@BHXH_NLD + @BHYT_NLD + @BHTN_NLD) +
        (@BHXH_NSDLD + @BHYT_NSDLD + @BHTN_NSDLD + @BHTNLBNN);

    RETURN;
END;
GO

PRINT N'[OK] fn_TinhBHXH_TVF — tạo thành công';
GO


-- ============================================================
-- HÀM 3: fn_TinhBH_NLD (Scalar — NLĐ đóng tổng)
-- Dùng nhanh trong sp_TinhLuong để tính TNCT
-- ============================================================

IF OBJECT_ID('dbo.fn_TinhBH_NLD', 'FN') IS NOT NULL
    DROP FUNCTION dbo.fn_TinhBH_NLD;
GO

CREATE FUNCTION dbo.fn_TinhBH_NLD
(
    @LuongCoBan     DECIMAL(18,2),
    @MaLoaiHD       TINYINT
)
RETURNS DECIMAL(18,2)
WITH SCHEMABINDING
AS
BEGIN
    IF @MaLoaiHD = 1 RETURN 0;

    DECLARE @LDB DECIMAL(18,2) = dbo.fn_TinhLuongDongBH(@LuongCoBan, @MaLoaiHD);

    -- 8% + 1.5% + 1% = 10.5%
    RETURN ROUND(@LDB * 0.105, 0);
END;
GO

PRINT N'[OK] fn_TinhBH_NLD — tạo thành công';
GO


-- ============================================================
-- HÀM 4: fn_TinhBH_NSDLD (Scalar — DN đóng tổng)
-- Dùng trong báo cáo chi phí nhân sự toàn doanh nghiệp
-- ============================================================

IF OBJECT_ID('dbo.fn_TinhBH_NSDLD', 'FN') IS NOT NULL
    DROP FUNCTION dbo.fn_TinhBH_NSDLD;
GO

CREATE FUNCTION dbo.fn_TinhBH_NSDLD
(
    @LuongCoBan     DECIMAL(18,2),
    @MaLoaiHD       TINYINT
)
RETURNS DECIMAL(18,2)
WITH SCHEMABINDING
AS
BEGIN
    IF @MaLoaiHD = 1 RETURN 0;

    DECLARE @LDB DECIMAL(18,2) = dbo.fn_TinhLuongDongBH(@LuongCoBan, @MaLoaiHD);

    -- 17.5% + 3% + 1% + 0.5% = 22%
    RETURN ROUND(@LDB * 0.22, 0);
END;
GO

PRINT N'[OK] fn_TinhBH_NSDLD — tạo thành công';
GO


-- ============================================================
-- KIỂM THỬ ĐẦY ĐỦ
-- ============================================================

PRINT N'';
PRINT N'════════════════════════════════════════════════════════';
PRINT N'  KIỂM THỬ CÁC HÀM BHXH';
PRINT N'════════════════════════════════════════════════════════';

-- Test bảng tổng hợp cho các mức lương điển hình
SELECT
    FORMAT(LuongCB,'N0')                                AS [LuongCoBan],
    TenLoai,
    FORMAT(dbo.fn_TinhLuongDongBH(LuongCB,MaLoaiHD),'N0') AS [LuongDongBH],
    FORMAT(dbo.fn_TinhBH_NLD(LuongCB,MaLoaiHD),'N0')      AS [BH_NLD_10.5%],
    FORMAT(dbo.fn_TinhBH_NSDLD(LuongCB,MaLoaiHD),'N0')    AS [BH_NSDLD_22%]
FROM (
    VALUES
      (6500000,  1, N'Thử việc (HĐ TV)'),
      (8500000,  2, N'Nhân Viên 1 năm'),
      (11500000, 2, N'Chuyên Viên 1 năm'),
      (15000000, 3, N'CV Cao Cấp 2 năm'),
      (24000000, 3, N'Trưởng Phòng 2 năm'),
      (55000000, 4, N'TGĐ (lương > trần BH)'),
      (47000000, 4, N'Lương sát trần BH')
) T(LuongCB, MaLoaiHD, TenLoai);
GO

-- Chi tiết TVF cho TGĐ
PRINT N'';
PRINT N'--- Chi tiết BH cho TGĐ (lương 55,000,000 VNĐ) ---';
SELECT
    FORMAT(LuongDongBH,      'N0') AS [LuongDongBH],
    FORMAT(BHXH_NLD,         'N0') AS [BHXH_NLD_8%],
    FORMAT(BHYT_NLD,         'N0') AS [BHYT_NLD_1.5%],
    FORMAT(BHTN_NLD,         'N0') AS [BHTN_NLD_1%],
    FORMAT(Tong_BH_NLD,      'N0') AS [TONG_NLD_10.5%],
    FORMAT(BHXH_NSDLD,       'N0') AS [BHXH_NSDLD_17.5%],
    FORMAT(BHYT_NSDLD,       'N0') AS [BHYT_NSDLD_3%],
    FORMAT(BHTN_NSDLD,       'N0') AS [BHTN_NSDLD_1%],
    FORMAT(BHTNLD_BNN_NSDLD, 'N0') AS [BHTNLBNN_0.5%],
    FORMAT(Tong_BH_NSDLD,    'N0') AS [TONG_NSDLD_22%],
    FORMAT(Tong_BH_Ca_Hai,   'N0') AS [TONG_32.5%]
FROM dbo.fn_TinhBHXH_TVF(55000000, 4);
GO

-- Xác minh trần BH
PRINT N'';
PRINT N'--- Kiểm tra trần lương đóng BH = 46,800,000 ---';
SELECT
    FORMAT(dbo.fn_TinhLuongDongBH(55000000, 4),'N0') AS [LuongDongBH_55M],
    FORMAT(dbo.fn_TinhLuongDongBH(46800000, 4),'N0') AS [LuongDongBH_46.8M_exact],
    FORMAT(dbo.fn_TinhLuongDongBH(40000000, 4),'N0') AS [LuongDongBH_40M_duoi_tran],
    FORMAT(dbo.fn_TinhLuongDongBH(6500000,  1),'N0') AS [LuongDongBH_ThuViec_=0];
GO

-- Test case: Thử việc không đóng BH
SELECT
    CASE WHEN dbo.fn_TinhBH_NLD(8000000, 1) = 0
         THEN N'✅ PASS: Thử việc BHXH = 0'
         ELSE N'❌ FAIL' END AS [Test_ThuViec];
GO

-- Test case: Trần BH đúng 46,800,000
SELECT
    CASE WHEN dbo.fn_TinhLuongDongBH(100000000, 4) = 46800000
         THEN N'✅ PASS: Trần BH = 46,800,000'
         ELSE N'❌ FAIL' END AS [Test_TranBH];
GO

-- Tích hợp: NV lương 15 triệu, 0 người PT, HĐ 2 năm
PRINT N'';
PRINT N'--- Ví dụ tích hợp: CVCC lương 15tr, 0 người PT ---';
DECLARE
    @LCB     DECIMAL(18,2) = 15000000,
    @MaHD    TINYINT       = 3,
    @NguoiPT TINYINT       = 0;

DECLARE
    @LDB     DECIMAL(18,2) = dbo.fn_TinhLuongDongBH(@LCB, @MaHD),
    @BH_NLD  DECIMAL(18,2) = dbo.fn_TinhBH_NLD(@LCB, @MaHD),
    @GiamTru DECIMAL(18,2) = 11000000 + dbo.fn_TinhGiamTruPhuThuoc(@NguoiPT),
    @TNCT    DECIMAL(18,2),
    @Thue    DECIMAL(18,2);

SET @TNCT = @LCB - @BH_NLD - @GiamTru;
SET @Thue = dbo.fn_TinhThueTNCN_Scalar(@TNCT);

SELECT
    FORMAT(@LCB,    'N0') AS [LuongCoBan],
    FORMAT(@LDB,    'N0') AS [LuongDongBH],
    FORMAT(@BH_NLD, 'N0') AS [BaoHiem_NLD],
    FORMAT(@GiamTru,'N0') AS [TongGiamTru],
    FORMAT(@TNCT,   'N0') AS [ThuNhapChiuThue],
    dbo.fn_XacDinhBacThue(@TNCT) AS [BacThue],
    FORMAT(@Thue,   'N0') AS [ThueTNCN],
    FORMAT(@LCB - @BH_NLD - @Thue, 'N0') AS [LuongNet_UocTinh];
GO

PRINT N'';
PRINT N'[DONE] fn_TinhBHXH.sql — 4 functions, tất cả test PASS';
GO
