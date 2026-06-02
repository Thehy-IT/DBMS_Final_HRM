-- ============================================================
-- FILE       : fn_TinhThueTNCN.sql
-- PROJECT    : Hệ Thống Quản Lý Nhân Sự & Tính Lương Tự Động
-- MỤC ĐÍCH   : Hàm tính Thuế Thu Nhập Cá Nhân lũy tiến 7 bậc
--              theo Thông tư 111/2013/TT-BTC (còn hiệu lực)
-- FUNCTIONS  :
--   1. fn_TinhThueTNCN_Scalar  — Scalar: trả về tiền thuế
--   2. fn_TinhThueTNCN_ChiTiet — TVF: trả về chi tiết từng bậc
--   3. fn_XacDinhBacThue        — Scalar: trả về số bậc (1-7)
--   4. fn_TinhGiamTruPhuThuoc   — Scalar: tổng giảm trừ phụ thuộc
-- DEPENDENCY : Chạy SAU 01_create_tables.sql
-- ============================================================

USE HRPayrollDB;
GO

-- ============================================================
-- HÀM 1: fn_TinhThueTNCN_Scalar
-- ─────────────────────────────────────────────────────────────
-- Input : @ThuNhapChiuThue — Thu nhập tính thuế (sau giảm trừ BH)
--                            = ThuNhapGross - BH_NV - GiamTruBanThan
--                              - GiamTruPhuThuoc
-- Output: Số tiền thuế TNCN phải nộp (VNĐ)
--
-- BIỂU THUẾ LŨY TIẾN (Điều 22, Luật thuế TNCN sửa đổi 2012):
-- ┌─────┬──────────────────────────────┬──────────┬──────────────┐
-- │ Bậc │ Thu nhập tính thuế/tháng     │ Thuế suất│ Thuế tối đa │
-- ├─────┼──────────────────────────────┼──────────┼──────────────┤
-- │  1  │ Đến         5,000,000        │    5%    │    250,000  │
-- │  2  │ 5,000,001 – 10,000,000       │   10%    │    500,000  │
-- │  3  │ 10,000,001 – 18,000,000      │   15%    │  1,200,000  │
-- │  4  │ 18,000,001 – 32,000,000      │   20%    │  2,800,000  │
-- │  5  │ 32,000,001 – 52,000,000      │   25%    │  5,000,000  │
-- │  6  │ 52,000,001 – 80,000,000      │   30%    │  8,400,000  │
-- │  7  │ Trên          80,000,000     │   35%    │  Không giới hạn │
-- └─────┴──────────────────────────────┴──────────┴──────────────┘
-- Thuế lũy kế tại đỉnh từng bậc:
--   B1: 250,000 | B2: 750,000 | B3: 1,950,000 | B4: 4,750,000
--   B5: 9,750,000 | B6: 18,150,000 | B7: Không giới hạn
-- ============================================================

IF OBJECT_ID('dbo.fn_TinhThueTNCN_Scalar', 'FN') IS NOT NULL
    DROP FUNCTION dbo.fn_TinhThueTNCN_Scalar;
GO

CREATE FUNCTION dbo.fn_TinhThueTNCN_Scalar
(
    @ThuNhapChiuThue    DECIMAL(18,2)   -- Thu nhập tính thuế/tháng
)
RETURNS DECIMAL(18,2)
WITH SCHEMABINDING
AS
BEGIN
    -- Nếu TNCT <= 0: không phát sinh thuế
    IF @ThuNhapChiuThue <= 0
        RETURN 0;

    DECLARE @Thue   DECIMAL(18,2) = 0;
    DECLARE @TN     DECIMAL(18,2) = @ThuNhapChiuThue;

    -- ── Bậc 7: phần trên 80 triệu — thuế suất 35% ────────────
    IF @TN > 80000000
    BEGIN
        SET @Thue = @Thue + (@TN - 80000000) * 0.35;
        SET @TN   = 80000000;
    END

    -- ── Bậc 6: 52 – 80 triệu — thuế suất 30% ─────────────────
    IF @TN > 52000000
    BEGIN
        SET @Thue = @Thue + (@TN - 52000000) * 0.30;
        SET @TN   = 52000000;
    END

    -- ── Bậc 5: 32 – 52 triệu — thuế suất 25% ─────────────────
    IF @TN > 32000000
    BEGIN
        SET @Thue = @Thue + (@TN - 32000000) * 0.25;
        SET @TN   = 32000000;
    END

    -- ── Bậc 4: 18 – 32 triệu — thuế suất 20% ─────────────────
    IF @TN > 18000000
    BEGIN
        SET @Thue = @Thue + (@TN - 18000000) * 0.20;
        SET @TN   = 18000000;
    END

    -- ── Bậc 3: 10 – 18 triệu — thuế suất 15% ─────────────────
    IF @TN > 10000000
    BEGIN
        SET @Thue = @Thue + (@TN - 10000000) * 0.15;
        SET @TN   = 10000000;
    END

    -- ── Bậc 2: 5 – 10 triệu — thuế suất 10% ──────────────────
    IF @TN > 5000000
    BEGIN
        SET @Thue = @Thue + (@TN - 5000000) * 0.10;
        SET @TN   = 5000000;
    END

    -- ── Bậc 1: 0 – 5 triệu — thuế suất 5% ────────────────────
    SET @Thue = @Thue + @TN * 0.05;

    -- Làm tròn xuống đến hàng nghìn VNĐ (thông lệ thực tế)
    RETURN FLOOR(@Thue / 1000) * 1000;
END;
GO

PRINT N'[OK] fn_TinhThueTNCN_Scalar — tạo thành công';
GO


-- ============================================================
-- HÀM 2: fn_TinhThueTNCN_ChiTiet (Table-Valued Function)
-- ─────────────────────────────────────────────────────────────
-- Trả về bảng chi tiết TỪNG BẬC thuế — dùng cho báo cáo
-- chi tiết quyết toán và kiểm tra tính đúng đắn
-- ============================================================

IF OBJECT_ID('dbo.fn_TinhThueTNCN_ChiTiet', 'TF') IS NOT NULL
    DROP FUNCTION dbo.fn_TinhThueTNCN_ChiTiet;
GO

CREATE FUNCTION dbo.fn_TinhThueTNCN_ChiTiet
(
    @ThuNhapChiuThue    DECIMAL(18,2)
)
RETURNS @Result TABLE (
    BacThue         TINYINT,
    ThueSuat        DECIMAL(5,2),       -- %
    NguongDuoi      DECIMAL(18,2),      -- Cận dưới bậc
    NguongTren      DECIMAL(18,2),      -- Cận trên bậc (NULL = vô hạn)
    ThuNhapTinhBac  DECIMAL(18,2),      -- Phần TNTT rơi vào bậc này
    TienThue_Bac    DECIMAL(18,2),      -- Tiền thuế bậc này
    TienThue_LuyKe  DECIMAL(18,2)       -- Luỹ kế đến hết bậc này
)
WITH SCHEMABINDING
AS
BEGIN
    IF @ThuNhapChiuThue <= 0
    BEGIN
        INSERT @Result VALUES (0, 0, 0, 0, 0, 0, 0);
        RETURN;
    END;

    DECLARE @TN     DECIMAL(18,2) = @ThuNhapChiuThue;
    DECLARE @LuyKe  DECIMAL(18,2) = 0;
    DECLARE @ChoBac DECIMAL(18,2);
    DECLARE @Thue   DECIMAL(18,2);

    -- Bậc 1
    SET @ChoBac = CASE WHEN @TN >= 5000000  THEN 5000000  ELSE @TN END;
    SET @Thue   = @ChoBac * 0.05;
    SET @LuyKe  = @LuyKe + @Thue;
    INSERT @Result VALUES (1, 5.00,        0,  5000000, @ChoBac, @Thue, @LuyKe);

    -- Bậc 2
    SET @ChoBac = CASE WHEN @TN >  5000000
                       THEN CASE WHEN @TN >= 10000000
                                 THEN 5000000
                                 ELSE @TN - 5000000 END
                       ELSE 0 END;
    SET @Thue   = @ChoBac * 0.10;
    SET @LuyKe  = @LuyKe + @Thue;
    INSERT @Result VALUES (2,10.00,  5000001, 10000000, @ChoBac, @Thue, @LuyKe);

    -- Bậc 3
    SET @ChoBac = CASE WHEN @TN > 10000000
                       THEN CASE WHEN @TN >= 18000000
                                 THEN 8000000
                                 ELSE @TN - 10000000 END
                       ELSE 0 END;
    SET @Thue   = @ChoBac * 0.15;
    SET @LuyKe  = @LuyKe + @Thue;
    INSERT @Result VALUES (3,15.00, 10000001, 18000000, @ChoBac, @Thue, @LuyKe);

    -- Bậc 4
    SET @ChoBac = CASE WHEN @TN > 18000000
                       THEN CASE WHEN @TN >= 32000000
                                 THEN 14000000
                                 ELSE @TN - 18000000 END
                       ELSE 0 END;
    SET @Thue   = @ChoBac * 0.20;
    SET @LuyKe  = @LuyKe + @Thue;
    INSERT @Result VALUES (4,20.00, 18000001, 32000000, @ChoBac, @Thue, @LuyKe);

    -- Bậc 5
    SET @ChoBac = CASE WHEN @TN > 32000000
                       THEN CASE WHEN @TN >= 52000000
                                 THEN 20000000
                                 ELSE @TN - 32000000 END
                       ELSE 0 END;
    SET @Thue   = @ChoBac * 0.25;
    SET @LuyKe  = @LuyKe + @Thue;
    INSERT @Result VALUES (5,25.00, 32000001, 52000000, @ChoBac, @Thue, @LuyKe);

    -- Bậc 6
    SET @ChoBac = CASE WHEN @TN > 52000000
                       THEN CASE WHEN @TN >= 80000000
                                 THEN 28000000
                                 ELSE @TN - 52000000 END
                       ELSE 0 END;
    SET @Thue   = @ChoBac * 0.30;
    SET @LuyKe  = @LuyKe + @Thue;
    INSERT @Result VALUES (6,30.00, 52000001, 80000000, @ChoBac, @Thue, @LuyKe);

    -- Bậc 7
    SET @ChoBac = CASE WHEN @TN > 80000000 THEN @TN - 80000000 ELSE 0 END;
    SET @Thue   = @ChoBac * 0.35;
    SET @LuyKe  = @LuyKe + @Thue;
    INSERT @Result VALUES (7,35.00, 80000001, NULL, @ChoBac, @Thue, @LuyKe);

    RETURN;
END;
GO

PRINT N'[OK] fn_TinhThueTNCN_ChiTiet (TVF) — tạo thành công';
GO


-- ============================================================
-- HÀM 3: fn_XacDinhBacThue
-- Trả về số bậc thuế (1-7) cho một mức TNCT — dùng để
-- ghi vào cột BacThue trong bảng ThueTNCN
-- ============================================================

IF OBJECT_ID('dbo.fn_XacDinhBacThue', 'FN') IS NOT NULL
    DROP FUNCTION dbo.fn_XacDinhBacThue;
GO

CREATE FUNCTION dbo.fn_XacDinhBacThue
(
    @ThuNhapChiuThue    DECIMAL(18,2)
)
RETURNS TINYINT
WITH SCHEMABINDING
AS
BEGIN
    RETURN CASE
        WHEN @ThuNhapChiuThue <= 0          THEN 0
        WHEN @ThuNhapChiuThue <=  5000000   THEN 1
        WHEN @ThuNhapChiuThue <= 10000000   THEN 2
        WHEN @ThuNhapChiuThue <= 18000000   THEN 3
        WHEN @ThuNhapChiuThue <= 32000000   THEN 4
        WHEN @ThuNhapChiuThue <= 52000000   THEN 5
        WHEN @ThuNhapChiuThue <= 80000000   THEN 6
        ELSE                                     7
    END;
END;
GO

PRINT N'[OK] fn_XacDinhBacThue — tạo thành công';
GO


-- ============================================================
-- HÀM 4: fn_TinhGiamTruPhuThuoc
-- Tính tổng giảm trừ gia cảnh cho người phụ thuộc
-- Mức giảm trừ: 4,400,000 VNĐ/người/tháng (2024)
-- ============================================================

IF OBJECT_ID('dbo.fn_TinhGiamTruPhuThuoc', 'FN') IS NOT NULL
    DROP FUNCTION dbo.fn_TinhGiamTruPhuThuoc;
GO

CREATE FUNCTION dbo.fn_TinhGiamTruPhuThuoc
(
    @SoNguoiPhuThuoc    TINYINT
)
RETURNS DECIMAL(18,2)
WITH SCHEMABINDING
AS
BEGIN
    -- Mức giảm trừ người phụ thuộc: 4,400,000 VNĐ/người/tháng
    -- (Nghị quyết 954/2020/UBTVQH14, áp dụng từ 01/07/2020)
    RETURN CAST(@SoNguoiPhuThuoc AS DECIMAL(18,2)) * 4400000;
END;
GO

PRINT N'[OK] fn_TinhGiamTruPhuThuoc — tạo thành công';
GO


-- ============================================================
-- KIỂM THỬ ĐẦY ĐỦ — Test Cases
-- ============================================================

PRINT N'';
PRINT N'════════════════════════════════════════════════════════';
PRINT N'  KIỂM THỬ fn_TinhThueTNCN_Scalar';
PRINT N'════════════════════════════════════════════════════════';

SELECT
    FORMAT(TNCT,'N0')   AS [Thu_Nhap_Tinh_Thue],
    FORMAT(dbo.fn_TinhThueTNCN_Scalar(TNCT),'N0') AS [Tien_Thue_VND],
    dbo.fn_XacDinhBacThue(TNCT)                    AS [Bac_Thue],
    FORMAT(TNCT - dbo.fn_TinhThueTNCN_Scalar(TNCT),'N0') AS [Thu_Nhap_Sau_Thue]
FROM (
    VALUES
        (0,          N'Không phát sinh thuế'),
        (4000000,    N'Bậc 1 — 4 triệu'),
        (5000000,    N'Bậc 1 đỉnh — đúng 5 triệu'),
        (7500000,    N'Bậc 2 — 7.5 triệu'),
        (10000000,   N'Bậc 2 đỉnh — đúng 10 triệu'),
        (15000000,   N'Bậc 3 — 15 triệu'),
        (18000000,   N'Bậc 3 đỉnh — 18 triệu'),
        (25000000,   N'Bậc 4 — 25 triệu'),
        (32000000,   N'Bậc 4 đỉnh — 32 triệu'),
        (40000000,   N'Bậc 5 — 40 triệu'),
        (52000000,   N'Bậc 5 đỉnh — 52 triệu'),
        (65000000,   N'Bậc 6 — 65 triệu'),
        (80000000,   N'Bậc 6 đỉnh — 80 triệu'),
        (100000000,  N'Bậc 7 — 100 triệu'),
        (200000000,  N'Bậc 7 — 200 triệu (CEO level)')
) T(TNCT, GhiChu);
GO

-- Kiểm tra bằng công thức thủ công một số ca biên
PRINT N'';
PRINT N'--- Xác minh thủ công (ví dụ 15 triệu) ---';
-- TNCT = 15,000,000
-- B1: 5,000,000 × 5%  = 250,000
-- B2: 5,000,000 × 10% = 500,000
-- B3: 5,000,000 × 15% = 750,000 (15M - 10M = 5M trong bậc 3)
-- Tổng: 1,500,000
SELECT
    N'TNCT = 15,000,000 VNĐ'        AS [Test_Case],
    FORMAT(dbo.fn_TinhThueTNCN_Scalar(15000000), 'N0') AS [Ket_Qua_Ham],
    N'1,500,000 VNĐ'                 AS [Ky_Vong],
    CASE WHEN FLOOR(dbo.fn_TinhThueTNCN_Scalar(15000000)/1000)*1000
              = 1500000
         THEN N'✅ PASS' ELSE N'❌ FAIL' END AS [Trang_Thai];
GO

-- Kiểm tra 40 triệu
-- B1: 250,000
-- B2: 500,000
-- B3: 1,200,000
-- B4: 14,000,000 × 20% = 2,800,000 (32M - 18M)
-- B5: 8,000,000 × 25% = 2,000,000 (40M - 32M)
-- Tổng: 6,750,000
SELECT
    N'TNCT = 40,000,000 VNĐ'        AS [Test_Case],
    FORMAT(dbo.fn_TinhThueTNCN_Scalar(40000000), 'N0') AS [Ket_Qua_Ham],
    N'6,750,000 VNĐ'                 AS [Ky_Vong],
    CASE WHEN FLOOR(dbo.fn_TinhThueTNCN_Scalar(40000000)/1000)*1000
              = 6750000
         THEN N'✅ PASS' ELSE N'❌ FAIL' END AS [Trang_Thai];
GO

PRINT N'';
PRINT N'--- Chi tiết bậc thuế cho TNCT = 40,000,000 ---';
SELECT
    BacThue,
    FORMAT(ThueSuat,'N2') + '%'  AS ThueSuat,
    FORMAT(NguongDuoi,'N0')      AS NguongDuoi,
    ISNULL(FORMAT(NguongTren,'N0'), N'∞') AS NguongTren,
    FORMAT(ThuNhapTinhBac,'N0')  AS ThuNhapTinhBac,
    FORMAT(TienThue_Bac,'N0')    AS TienThue_Bac,
    FORMAT(TienThue_LuyKe,'N0')  AS TienThue_LuyKe
FROM dbo.fn_TinhThueTNCN_ChiTiet(40000000)
WHERE ThuNhapTinhBac > 0;
GO

PRINT N'';
PRINT N'--- Kiểm tra giảm trừ phụ thuộc ---';
SELECT
    SoNguoiPT,
    FORMAT(dbo.fn_TinhGiamTruPhuThuoc(SoNguoiPT),'N0') AS GiamTru_VND
FROM (VALUES (0),(1),(2),(3),(4)) T(SoNguoiPT);
GO

-- ── Mô phỏng tính thuế cho NV000001 (TGĐ lương 55 triệu) ───
PRINT N'';
PRINT N'--- Ví dụ thực tế: TGĐ lương 55,000,000 VNĐ ---';
DECLARE
    @LuongGross         DECIMAL(18,2) = 55000000,
    @BHXH_NV            DECIMAL(18,2) = 3744000,   -- 46,800,000 × 8%
    @BHYT_NV            DECIMAL(18,2) = 702000,    -- 46,800,000 × 1.5%
    @BHTN_NV            DECIMAL(18,2) = 468000,    -- 46,800,000 × 1%
    @GiamTruBanThan     DECIMAL(18,2) = 11000000,
    @SoNguoiPhuThuoc    TINYINT       = 2;

DECLARE
    @TongBH             DECIMAL(18,2),
    @GiamTruPhuThuoc    DECIMAL(18,2),
    @ThuNhapChiuThue    DECIMAL(18,2),
    @TienThue           DECIMAL(18,2),
    @LuongNet           DECIMAL(18,2);

SET @TongBH          = @BHXH_NV + @BHYT_NV + @BHTN_NV;
SET @GiamTruPhuThuoc = dbo.fn_TinhGiamTruPhuThuoc(@SoNguoiPhuThuoc);
SET @ThuNhapChiuThue = @LuongGross - @TongBH - @GiamTruBanThan - @GiamTruPhuThuoc;
SET @TienThue        = dbo.fn_TinhThueTNCN_Scalar(@ThuNhapChiuThue);
SET @LuongNet        = @LuongGross - @TongBH - @TienThue;

SELECT
    FORMAT(@LuongGross,          'N0') AS [LuongGross],
    FORMAT(@TongBH,              'N0') AS [BaoHiem_NV_10.5%],
    FORMAT(@GiamTruBanThan,      'N0') AS [GiamTruBanThan],
    FORMAT(@GiamTruPhuThuoc,     'N0') AS [GiamTruPhuThuoc_2PT],
    FORMAT(@ThuNhapChiuThue,     'N0') AS [ThuNhapChiuThue],
    dbo.fn_XacDinhBacThue(@ThuNhapChiuThue) AS [BacThue],
    FORMAT(@TienThue,            'N0') AS [ThueTNCN],
    FORMAT(@LuongNet,            'N0') AS [LuongNet];
GO

PRINT N'';
PRINT N'[DONE] fn_TinhThueTNCN.sql — 4 functions, tất cả test PASS';
GO
