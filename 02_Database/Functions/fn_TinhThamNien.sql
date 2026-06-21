/*
PROJECT    : Hệ Thống Quản Lý Nhân Sự & Tính Lương Tự Động
MỤC ĐÍCH   : Hàm vô hướng tính thâm niên làm việc của nhân viên (tính theo năm).
             Phục vụ tính số ngày phép năm bổ sung và thưởng thâm niên.
DBMS       : MySQL 8.0+
*/

USE HRPayrollDB;

DROP FUNCTION IF EXISTS fn_TinhThamNien;

DELIMITER $$
CREATE FUNCTION fn_TinhThamNien(
    p_MaNV CHAR(8),
    p_DenNgay DATE
) 
RETURNS DECIMAL(5,2)
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_NgayVaoLam DATE;
    DECLARE v_ThamNien DECIMAL(5,2) DEFAULT 0.00;

    -- Lấy ngày vào làm
    SELECT NgayVaoLam INTO v_NgayVaoLam
    FROM NhanVien
    WHERE MaNV = p_MaNV;

    -- Nếu không tìm thấy NV hoặc ngày vào làm lớn hơn ngày chốt (chưa làm việc)
    IF v_NgayVaoLam IS NULL OR v_NgayVaoLam > p_DenNgay THEN
        RETURN 0.00;
    END IF;

    -- Tính thâm niên theo số năm (lấy số ngày chênh lệch chia cho 365.25 để tương đối chính xác bù năm nhuận)
    SET v_ThamNien = ROUND(DATEDIFF(p_DenNgay, v_NgayVaoLam) / 365.25, 2);

    RETURN v_ThamNien;
END$$
DELIMITER ;
