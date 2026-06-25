-- PROJECT    : Hệ Thống Quản Lý Nhân Sự & Tính Lương Tự Động
-- MỤC ĐÍCH   : Procedure tính chi tiết Bảo Hiểm Xã Hội / Y Tế / Thất Nghiệp

USE HRPayrollDB;

-- PROCEDURE: sp_TinhBHXH_ChiTiet
-- (Thay thế TVF fn_TinhBHXH_TVF của SQL Server)
-- Trả về bảng đầy đủ các thành phần BH — NLĐ và NSDLĐ

DROP PROCEDURE IF EXISTS sp_TinhBHXH_ChiTiet;

DELIMITER $$
CREATE PROCEDURE sp_TinhBHXH_ChiTiet(
    IN p_LuongCoBan  DECIMAL(18,2),
    IN p_MaLoaiHD    TINYINT
)
BEGIN
    DECLARE v_LDB           DECIMAL(18,2);
    DECLARE v_BHXH_NLD      DECIMAL(18,2) DEFAULT 0;
    DECLARE v_BHYT_NLD      DECIMAL(18,2) DEFAULT 0;
    DECLARE v_BHTN_NLD      DECIMAL(18,2) DEFAULT 0;
    DECLARE v_Tong_NLD      DECIMAL(18,2) DEFAULT 0;
    DECLARE v_BHXH_NSDLD    DECIMAL(18,2) DEFAULT 0;
    DECLARE v_BHYT_NSDLD    DECIMAL(18,2) DEFAULT 0;
    DECLARE v_BHTN_NSDLD    DECIMAL(18,2) DEFAULT 0;
    DECLARE v_BHTNLBNN      DECIMAL(18,2) DEFAULT 0;
    DECLARE v_Tong_NSDLD    DECIMAL(18,2) DEFAULT 0;
    DECLARE v_Tong_CaHai    DECIMAL(18,2) DEFAULT 0;

    SET v_LDB = fn_TinhLuongDongBH(p_LuongCoBan, p_MaLoaiHD);

    IF p_MaLoaiHD != 1 THEN
        -- NLĐ
        SET v_BHXH_NLD   = ROUND(v_LDB * 0.08,  0);
        SET v_BHYT_NLD   = ROUND(v_LDB * 0.015, 0);
        SET v_BHTN_NLD   = ROUND(v_LDB * 0.01,  0);
        SET v_Tong_NLD   = v_BHXH_NLD + v_BHYT_NLD + v_BHTN_NLD;

        -- NSDLĐ
        SET v_BHXH_NSDLD = ROUND(v_LDB * 0.175, 0);
        SET v_BHYT_NSDLD = ROUND(v_LDB * 0.03,  0);
        SET v_BHTN_NSDLD = ROUND(v_LDB * 0.01,  0);
        SET v_BHTNLBNN   = ROUND(v_LDB * 0.005, 0);
        SET v_Tong_NSDLD = v_BHXH_NSDLD + v_BHYT_NSDLD + v_BHTN_NSDLD + v_BHTNLBNN;

        SET v_Tong_CaHai = v_Tong_NLD + v_Tong_NSDLD;
    END IF;

    SELECT
        v_LDB           AS LuongDongBH,
        v_BHXH_NLD      AS BHXH_NLD,
        v_BHYT_NLD      AS BHYT_NLD,
        v_BHTN_NLD      AS BHTN_NLD,
        v_Tong_NLD      AS Tong_BH_NLD,
        v_BHXH_NSDLD    AS BHXH_NSDLD,
        v_BHYT_NSDLD    AS BHYT_NSDLD,
        v_BHTN_NSDLD    AS BHTN_NSDLD,
        v_BHTNLBNN      AS BHTNLD_BNN_NSDLD,
        v_Tong_NSDLD    AS Tong_BH_NSDLD,
        v_Tong_CaHai    AS Tong_BH_Ca_Hai;
END$$
DELIMITER ;

SELECT 'sp_TinhBHXH_ChiTiet — tạo thành công' AS Status;
