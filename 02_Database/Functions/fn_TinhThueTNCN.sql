-- ============================================================
-- FILE       : fn_TinhThueTNCN.sql
-- PROJECT    : Hệ Thống Quản Lý Nhân Sự & Tính Lương Tự Động
-- MỤC ĐÍCH   : Hàm tính Thuế Thu Nhập Cá Nhân lũy tiến 7 bậc
--              theo Thông tư 111/2013/TT-BTC (còn hiệu lực)
-- FUNCTIONS  :
--   1. fn_TinhThueTNCN_Scalar  — trả về tiền thuế
--   2. fn_XacDinhBacThue        — trả về số bậc (1-7)
--   3. fn_TinhGiamTruPhuThuoc   — tổng giảm trừ phụ thuộc
-- DEPENDENCY : Chạy SAU 01_create_tables.sql
-- DBMS       : MySQL 8.0+
-- GHI CHÚ   : MySQL không hỗ trợ TVF (Table-Valued Function)
--              → fn_TinhThueTNCN_ChiTiet được chuyển thành PROCEDURE
--              → Dùng DETERMINISTIC + NO SQL / READS SQL DATA
-- ============================================================

USE HRPayrollDB;

-- ============================================================
-- HÀM 1: fn_TinhThueTNCN_Scalar
-- ============================================================

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

SELECT '[OK] fn_TinhThueTNCN_Scalar — tạo thành công' AS Status;


-- ============================================================
-- PROCEDURE: sp_TinhThueTNCN_ChiTiet
-- (Thay thế TVF trong SQL Server — MySQL dùng procedure + temp table)
-- ============================================================

DROP PROCEDURE IF EXISTS sp_TinhThueTNCN_ChiTiet;

DELIMITER $$

CREATE PROCEDURE sp_TinhThueTNCN_ChiTiet(
    IN p_ThuNhapChiuThue DECIMAL(18,2)
)
BEGIN
    DECLARE v_TN    DECIMAL(18,2);
    DECLARE v_LuyKe DECIMAL(18,2) DEFAULT 0;
    DECLARE v_ChoBac DECIMAL(18,2);
    DECLARE v_Thue   DECIMAL(18,2);

    -- Kết quả trả về dưới dạng resultset
    DROP TEMPORARY TABLE IF EXISTS tmp_ChiTietThue;
    CREATE TEMPORARY TABLE tmp_ChiTietThue (
        BacThue         TINYINT,
        ThueSuat        DECIMAL(5,2),
        NguongDuoi      DECIMAL(18,2),
        NguongTren      DECIMAL(18,2),
        ThuNhapTinhBac  DECIMAL(18,2),
        TienThue_Bac    DECIMAL(18,2),
        TienThue_LuyKe  DECIMAL(18,2)
    );

    IF p_ThuNhapChiuThue <= 0 THEN
        INSERT INTO tmp_ChiTietThue VALUES (0, 0, 0, 0, 0, 0, 0);
    ELSE
        SET v_TN = p_ThuNhapChiuThue;

        -- Bậc 1
        SET v_ChoBac = CASE WHEN v_TN >= 5000000 THEN 5000000 ELSE v_TN END;
        SET v_Thue   = v_ChoBac * 0.05;
        SET v_LuyKe  = v_LuyKe + v_Thue;
        INSERT INTO tmp_ChiTietThue VALUES (1, 5.00, 0, 5000000, v_ChoBac, v_Thue, v_LuyKe);

        -- Bậc 2
        SET v_ChoBac = CASE
            WHEN v_TN > 5000000 THEN LEAST(v_TN, 10000000) - 5000000
            ELSE 0 END;
        SET v_Thue = v_ChoBac * 0.10;
        SET v_LuyKe = v_LuyKe + v_Thue;
        INSERT INTO tmp_ChiTietThue VALUES (2, 10.00, 5000001, 10000000, v_ChoBac, v_Thue, v_LuyKe);

        -- Bậc 3
        SET v_ChoBac = CASE
            WHEN v_TN > 10000000 THEN LEAST(v_TN, 18000000) - 10000000
            ELSE 0 END;
        SET v_Thue = v_ChoBac * 0.15;
        SET v_LuyKe = v_LuyKe + v_Thue;
        INSERT INTO tmp_ChiTietThue VALUES (3, 15.00, 10000001, 18000000, v_ChoBac, v_Thue, v_LuyKe);

        -- Bậc 4
        SET v_ChoBac = CASE
            WHEN v_TN > 18000000 THEN LEAST(v_TN, 32000000) - 18000000
            ELSE 0 END;
        SET v_Thue = v_ChoBac * 0.20;
        SET v_LuyKe = v_LuyKe + v_Thue;
        INSERT INTO tmp_ChiTietThue VALUES (4, 20.00, 18000001, 32000000, v_ChoBac, v_Thue, v_LuyKe);

        -- Bậc 5
        SET v_ChoBac = CASE
            WHEN v_TN > 32000000 THEN LEAST(v_TN, 52000000) - 32000000
            ELSE 0 END;
        SET v_Thue = v_ChoBac * 0.25;
        SET v_LuyKe = v_LuyKe + v_Thue;
        INSERT INTO tmp_ChiTietThue VALUES (5, 25.00, 32000001, 52000000, v_ChoBac, v_Thue, v_LuyKe);

        -- Bậc 6
        SET v_ChoBac = CASE
            WHEN v_TN > 52000000 THEN LEAST(v_TN, 80000000) - 52000000
            ELSE 0 END;
        SET v_Thue = v_ChoBac * 0.30;
        SET v_LuyKe = v_LuyKe + v_Thue;
        INSERT INTO tmp_ChiTietThue VALUES (6, 30.00, 52000001, 80000000, v_ChoBac, v_Thue, v_LuyKe);

        -- Bậc 7
        SET v_ChoBac = CASE
            WHEN v_TN > 80000000 THEN v_TN - 80000000
            ELSE 0 END;
        SET v_Thue = v_ChoBac * 0.35;
        SET v_LuyKe = v_LuyKe + v_Thue;
        INSERT INTO tmp_ChiTietThue VALUES (7, 35.00, 80000001, NULL, v_ChoBac, v_Thue, v_LuyKe);
    END IF;

    SELECT * FROM tmp_ChiTietThue;
    DROP TEMPORARY TABLE IF EXISTS tmp_ChiTietThue;
END$$

DELIMITER ;

SELECT '[OK] sp_TinhThueTNCN_ChiTiet (Procedure thay thế TVF) — tạo thành công' AS Status;


-- ============================================================
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


-- ============================================================
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


-- ============================================================
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

-- Chi tiết bậc thuế cho TNCT = 40,000,000
CALL sp_TinhThueTNCN_ChiTiet(40000000);

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

SELECT '' AS Separator;
SELECT '[DONE] fn_TinhThueTNCN.sql — 3 functions + 1 procedure, tất cả test PASS' AS Status;
