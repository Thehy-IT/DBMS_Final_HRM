-- FILE       : trg_NhanVien_CheckTuoi.sql
-- PROJECT    : Hệ Thống Quản Lý Nhân Sự & Tính Lương Tự Động
-- MỤC ĐÍCH   : Kiểm soát độ tuổi lao động (18 - 70 tuổi)
-- DBMS       : MySQL 8.0+
-- GHI CHÚ   : Phải dùng Trigger vì CHECK CONSTRAINT trong MySQL
--              không hỗ trợ hàm CURDATE() (non-deterministic)

USE HRPayrollDB;

-- ── TRIGGER 1: trg_NhanVien_BeforeInsert_CheckTuoi
DROP TRIGGER IF EXISTS trg_NhanVien_BeforeInsert_CheckTuoi;

DELIMITER $$
CREATE TRIGGER trg_NhanVien_BeforeInsert_CheckTuoi
BEFORE INSERT ON NhanVien
FOR EACH ROW
BEGIN
    DECLARE v_Tuoi INT;
    SET v_Tuoi = TIMESTAMPDIFF(YEAR, NEW.NgaySinh, CURDATE());
    
    IF v_Tuoi < 18 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'trg_NhanVien_BeforeInsert_CheckTuoi: Nhân viên phải từ 18 tuổi trở lên.';
    END IF;
    
    IF v_Tuoi > 70 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'trg_NhanVien_BeforeInsert_CheckTuoi: Nhân viên không được quá 70 tuổi.';
    END IF;
END$$
DELIMITER ;

-- ── TRIGGER 2: trg_NhanVien_BeforeUpdate_CheckTuoi
DROP TRIGGER IF EXISTS trg_NhanVien_BeforeUpdate_CheckTuoi;

DELIMITER $$
CREATE TRIGGER trg_NhanVien_BeforeUpdate_CheckTuoi
BEFORE UPDATE ON NhanVien
FOR EACH ROW
BEGIN
    DECLARE v_Tuoi INT;
    -- Chỉ kiểm tra nếu ngày sinh bị thay đổi
    IF NEW.NgaySinh <> OLD.NgaySinh THEN
        SET v_Tuoi = TIMESTAMPDIFF(YEAR, NEW.NgaySinh, CURDATE());
        
        IF v_Tuoi < 18 THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'trg_NhanVien_BeforeUpdate_CheckTuoi: Tuổi cập nhật phải từ 18 trở lên.';
        END IF;
        
        IF v_Tuoi > 70 THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'trg_NhanVien_BeforeUpdate_CheckTuoi: Tuổi cập nhật không được quá 70.';
        END IF;
    END IF;
END$$
DELIMITER ;

SELECT 'trg_NhanVien_CheckTuoi (Insert/Update)' AS Status;
