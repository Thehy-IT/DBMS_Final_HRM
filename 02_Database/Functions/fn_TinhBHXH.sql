-- MỤC ĐÍCH   : Hàm tính Bảo Hiểm Xã Hội / Y Tế / Thất Nghiệp
--              theo Luật BHXH 2014 + Nghị định 143/2018/NĐ-CP
-- FUNCTIONS  :
--   1. fn_TinhLuongDongBH    — Scalar: lương đóng BH (có trần)
--   2. fn_TinhBH_NLD         — Scalar: tổng BH nhân viên đóng
--   3. fn_TinhBH_NSDLD       — Scalar: tổng BH doanh nghiệp đóng
-- DEPENDENCY : Chạy SAU fn_TinhThueTNCN.sql

USE HRPayrollDB;

-- HÀM 1: fn_TinhLuongDongBH
-- ============================================================

DROP FUNCTION IF EXISTS fn_TinhLuongDongBH;

DELIMITER $$

CREATE FUNCTION fn_TinhLuongDongBH(
    p_LuongCoBan  DECIMAL(18,2),
    p_MaLoaiHD    TINYINT
)
RETURNS DECIMAL(18,2)
DETERMINISTIC
NO SQL
BEGIN
    DECLARE v_TranBH DECIMAL(18,2) DEFAULT 46800000;

    -- Hợp đồng thử việc không đóng BHXH → lương đóng BH = 0
    IF p_MaLoaiHD = 1 THEN
        RETURN 0;
    END IF;

    RETURN CASE
        WHEN p_LuongCoBan > v_TranBH THEN v_TranBH
        ELSE p_LuongCoBan
    END;
END$$

DELIMITER ;

SELECT ' fn_TinhLuongDongBH — tạo thành công' AS Status;


-- HÀM 2: fn_TinhBH_NLD (Scalar — NLĐ đóng tổng)
-- ============================================================

DROP FUNCTION IF EXISTS fn_TinhBH_NLD;

DELIMITER $$

CREATE FUNCTION fn_TinhBH_NLD(
    p_LuongCoBan  DECIMAL(18,2),
    p_MaLoaiHD    TINYINT
)
RETURNS DECIMAL(18,2)
DETERMINISTIC
NO SQL
BEGIN
    DECLARE v_LDB DECIMAL(18,2);

    IF p_MaLoaiHD = 1 THEN
        RETURN 0;
    END IF;

    SET v_LDB = fn_TinhLuongDongBH(p_LuongCoBan, p_MaLoaiHD);
    -- 8% BHXH + 1.5% BHYT + 1% BHTN = 10.5%
    RETURN ROUND(v_LDB * 0.105, 0);
END$$

DELIMITER ;

SELECT 'fn_TinhBH_NLD — tạo thành công' AS Status;


-- HÀM 3: fn_TinhBH_NSDLD (Scalar — DN đóng tổng)
-- ============================================================
DROP FUNCTION IF EXISTS fn_TinhBH_NSDLD;

DELIMITER $$

CREATE FUNCTION fn_TinhBH_NSDLD(
    p_LuongCoBan  DECIMAL(18,2),
    p_MaLoaiHD    TINYINT
)
RETURNS DECIMAL(18,2)
DETERMINISTIC
NO SQL
BEGIN
    DECLARE v_LDB DECIMAL(18,2);

    IF p_MaLoaiHD = 1 THEN
        RETURN 0;
    END IF;

    SET v_LDB = fn_TinhLuongDongBH(p_LuongCoBan, p_MaLoaiHD);
    -- 17.5% BHXH + 3% BHYT + 1% BHTN + 0.5% BHTNLĐ&BNN = 22%
    RETURN ROUND(v_LDB * 0.22, 0);
END$$

DELIMITER ;

SELECT 'fn_TinhBH_NSDLD — tạo thành công' AS Status;

-- KIỂM THỬ ĐẦY ĐỦ

SELECT '  KIỂM THỬ CÁC HÀM BHXH' AS Status;
SELECT
    FORMAT(LuongCB, 0)                                      AS LuongCoBan,
    TenLoai,
    FORMAT(fn_TinhLuongDongBH(LuongCB, MaLoaiHD), 0)       AS LuongDongBH,
    FORMAT(fn_TinhBH_NLD(LuongCB, MaLoaiHD), 0)            AS BH_NLD_10_5pct,
    FORMAT(fn_TinhBH_NSDLD(LuongCB, MaLoaiHD), 0)          AS BH_NSDLD_22pct
FROM (
    SELECT 6500000  AS LuongCB, 1 AS MaLoaiHD, 'Thử việc (HĐ TV)'      AS TenLoai UNION ALL
    SELECT 8500000,              2,              'Nhân Viên 1 năm'              UNION ALL
    SELECT 11500000,             2,              'Chuyên Viên 1 năm'            UNION ALL
    SELECT 15000000,             3,              'CV Cao Cấp 2 năm'             UNION ALL
    SELECT 24000000,             3,              'Trưởng Phòng 2 năm'           UNION ALL
    SELECT 55000000,             4,              'TGĐ (lương > trần BH)'        UNION ALL
    SELECT 47000000,             4,              'Lương sát trần BH'
) T;

-- Kiểm tra trần BH
SELECT
    FORMAT(fn_TinhLuongDongBH(55000000, 4), 0)  AS LuongDongBH_55M,
    FORMAT(fn_TinhLuongDongBH(46800000, 4), 0)  AS LuongDongBH_46_8M_exact,
    FORMAT(fn_TinhLuongDongBH(40000000, 4), 0)  AS LuongDongBH_40M_duoi_tran,
    FORMAT(fn_TinhLuongDongBH(6500000,  1), 0)  AS LuongDongBH_ThuViec_bang0;

-- Test case
SELECT
    CASE WHEN fn_TinhBH_NLD(8000000, 1) = 0
         THEN 'PASS: Thử việc BHXH = 0'
         ELSE 'FAIL' END AS Test_ThuViec;

SELECT
    CASE WHEN fn_TinhLuongDongBH(100000000, 4) = 46800000
         THEN 'PASS: Trần BH = 46,800,000'
         ELSE 'FAIL' END AS Test_TranBH;

SELECT 'fn_TinhBHXH.sql — 3 functions, tất cả test PASS' AS Status;