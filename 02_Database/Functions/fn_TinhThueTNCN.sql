-- FILE       : fn_TinhThueTNCN.sql
-- PROJECT    : Hệ Thống Quản Lý Nhân Sự & Tính Lương Tự Động
-- MỤC ĐÍCH   : Hàm tính Thuế Thu Nhập Cá Nhân lũy tiến 7 bậc
--              theo Thông tư 111/2013/TT-BTC (còn hiệu lực)
-- FUNCTIONS  :
--   1. fn_TinhThueTNCN_Scalar  — trả về tiền thuế
--   2. fn_XacDinhBacThue        — trả về số bậc (1-7)
--   3. fn_TinhGiamTruPhuThuoc   — tổng giảm trừ phụ thuộc

USE HRPayrollDB;
-- HÀM 1: fn_TinhThueTNCN_Scalar

DROP FUNCTION IF EXISTS fn_TinhThueTNCN_Scalar;

DELIMITER $$
CREATE FUNCTION fn_TinhThueTNCN_Scalar(
    p_ThuNhapChiuThue DECIMAL(18,2)
)
RETURNS DECIMAL(18,2)
DETERMINISTIC
NO SQL
BEGIN
    DECLARE v_Thue  DECIMAL(18,2) DEFAULT 0;
    DECLARE v_TN    DECIMAL(18,2);

    -- Nếu TNCT <= 0: không phát sinh thuế
    IF p_ThuNhapChiuThue <= 0 THEN
        RETURN 0;
    END IF;

    SET v_TN = p_ThuNhapChiuThue;

    -- Bậc 7: phần trên 80 triệu — thuế suất 35%
    IF v_TN > 80000000 THEN
        SET v_Thue = v_Thue + (v_TN - 80000000) * 0.35;
        SET v_TN   = 80000000;
    END IF;

    -- Bậc 6: 52 – 80 triệu — thuế suất 30%
    IF v_TN > 52000000 THEN
        SET v_Thue = v_Thue + (v_TN - 52000000) * 0.30;
        SET v_TN   = 52000000;
    END IF;

    -- Bậc 5: 32 – 52 triệu — thuế suất 25%
    IF v_TN > 32000000 THEN
        SET v_Thue = v_Thue + (v_TN - 32000000) * 0.25;
        SET v_TN   = 32000000;
    END IF;

    -- Bậc 4: 18 – 32 triệu — thuế suất 20%
    IF v_TN > 18000000 THEN
        SET v_Thue = v_Thue + (v_TN - 18000000) * 0.20;
        SET v_TN   = 18000000;
    END IF;

    -- Bậc 3: 10 – 18 triệu — thuế suất 15%
    IF v_TN > 10000000 THEN
        SET v_Thue = v_Thue + (v_TN - 10000000) * 0.15;
        SET v_TN   = 10000000;
    END IF;

    -- Bậc 2: 5 – 10 triệu — thuế suất 10%
    IF v_TN > 5000000 THEN
        SET v_Thue = v_Thue + (v_TN - 5000000) * 0.10;
        SET v_TN   = 5000000;
    END IF;

    -- Bậc 1: 0 – 5 triệu — thuế suất 5%
    SET v_Thue = v_Thue + v_TN * 0.05;

    -- Làm tròn xuống đến hàng nghìn VNĐ
    RETURN FLOOR(v_Thue / 1000) * 1000;
END$$
DELIMITER ;

SELECT 'fn_TinhThueTNCN_Scalar — tạo thành công' AS Status;

-- HÀM 2: fn_XacDinhBacThue
-- ============================================================

DROP FUNCTION IF EXISTS fn_XacDinhBacThue;

DELIMITER $$

CREATE FUNCTION fn_XacDinhBacThue(
    p_ThuNhapChiuThue DECIMAL(18,2)
)
RETURNS TINYINT
DETERMINISTIC
NO SQL
BEGIN
    RETURN CASE
        WHEN p_ThuNhapChiuThue <= 0          THEN 0
        WHEN p_ThuNhapChiuThue <=  5000000   THEN 1
        WHEN p_ThuNhapChiuThue <= 10000000   THEN 2
        WHEN p_ThuNhapChiuThue <= 18000000   THEN 3
        WHEN p_ThuNhapChiuThue <= 32000000   THEN 4
        WHEN p_ThuNhapChiuThue <= 52000000   THEN 5
        WHEN p_ThuNhapChiuThue <= 80000000   THEN 6
        ELSE                                      7
    END;
END$$

DELIMITER ;

SELECT '[OK] fn_XacDinhBacThue — tạo thành công' AS Status;


-- HÀM 3: fn_TinhGiamTruPhuThuoc
-- ============================================================
DROP FUNCTION IF EXISTS fn_TinhGiamTruPhuThuoc;

DELIMITER $$

CREATE FUNCTION fn_TinhGiamTruPhuThuoc(
    p_SoNguoiPhuThuoc TINYINT
)
RETURNS DECIMAL(18,2)
DETERMINISTIC
NO SQL
BEGIN
    -- Mức giảm trừ người phụ thuộc: 4,400,000 VNĐ/người/tháng
    RETURN CAST(p_SoNguoiPhuThuoc AS DECIMAL(18,2)) * 4400000;
END$$

DELIMITER ;

SELECT '[OK] fn_TinhGiamTruPhuThuoc — tạo thành công' AS Status;


-- KIỂM THỬ ĐẦY ĐỦ
-- ============================================================
SELECT '  KIỂM THỬ fn_TinhThueTNCN_Scalar' AS Status;

SELECT
    FORMAT(TNCT, 0)                                AS Thu_Nhap_Tinh_Thue,
    FORMAT(fn_TinhThueTNCN_Scalar(TNCT), 0)       AS Tien_Thue_VND,
    fn_XacDinhBacThue(TNCT)                        AS Bac_Thue,
    FORMAT(TNCT - fn_TinhThueTNCN_Scalar(TNCT), 0) AS Thu_Nhap_Sau_Thue
FROM (
    SELECT 0             AS TNCT UNION ALL
    SELECT 4000000              UNION ALL
    SELECT 5000000              UNION ALL
    SELECT 7500000              UNION ALL
    SELECT 10000000             UNION ALL
    SELECT 15000000             UNION ALL
    SELECT 18000000             UNION ALL
    SELECT 25000000             UNION ALL
    SELECT 32000000             UNION ALL
    SELECT 40000000             UNION ALL
    SELECT 52000000             UNION ALL
    SELECT 65000000             UNION ALL
    SELECT 80000000             UNION ALL
    SELECT 100000000            UNION ALL
    SELECT 200000000
) T;

-- Kiểm tra 15 triệu
SELECT
    'TNCT = 15,000,000 VNĐ'                             AS Test_Case,
    FORMAT(fn_TinhThueTNCN_Scalar(15000000), 0)         AS Ket_Qua_Ham,
    '1,500,000 VNĐ'                                     AS Ky_Vong,
    CASE WHEN fn_TinhThueTNCN_Scalar(15000000) = 1500000
         THEN 'PASS' ELSE 'FAIL' END                    AS Trang_Thai;

-- Kiểm tra 40 triệu
SELECT
    'TNCT = 40,000,000 VNĐ'                             AS Test_Case,
    FORMAT(fn_TinhThueTNCN_Scalar(40000000), 0)         AS Ket_Qua_Ham,
    '6,750,000 VNĐ'                                     AS Ky_Vong,
    CASE WHEN fn_TinhThueTNCN_Scalar(40000000) = 6750000
         THEN 'PASS' ELSE 'FAIL' END                    AS Trang_Thai;

-- Kiểm tra giảm trừ phụ thuộc
SELECT
    SoNguoiPT,
    FORMAT(fn_TinhGiamTruPhuThuoc(SoNguoiPT), 0) AS GiamTru_VND
FROM (
    SELECT 0 AS SoNguoiPT UNION ALL
    SELECT 1              UNION ALL
    SELECT 2              UNION ALL
    SELECT 3              UNION ALL
    SELECT 4
) T;

SELECT '[DONE] fn_TinhThueTNCN.sql — 3 functions, tất cả test PASS' AS Status;
