/*
PROJECT    : Hệ Thống Quản Lý Nhân Sự & Tính Lương Tự Động
MỤC ĐÍCH   : Các Trình kích hoạt (Trigger) bảo vệ bảng lương ở cấp độ cơ sở dữ liệu.
             Tuyệt đối ngăn chặn sửa đổi (UPDATE) các con số hoặc XÓA (DELETE) các bảng lương đã Thanh toán / Đã khóa.
             Phục vụ tiêu chuẩn kiểm toán hệ thống ERP/Payroll.
DBMS       : MySQL 8.0+
*/

USE HRPayrollDB;

-- 1. Trigger chặn UPDATE những thay đổi trái phép trên bảng lương đã chốt
DROP TRIGGER IF EXISTS trg_BangLuong_BeforeUpdate_Protect;

DELIMITER $$
CREATE TRIGGER trg_BangLuong_BeforeUpdate_Protect
BEFORE UPDATE ON BangLuong
FOR EACH ROW
BEGIN
    -- Nếu trạng thái cũ đã là P (Paid) hoặc L (Locked)
    IF OLD.TrangThai IN ('P', 'L') THEN
        -- Chặn mọi thay đổi liên quan đến dữ liệu tài chính (lương cơ bản, ngày công, bảo hiểm, thuế, v.v...)
        IF NEW.LuongCoBan != OLD.LuongCoBan 
           OR NEW.SoNgayCong != OLD.SoNgayCong 
           OR NEW.HeSoTangCa != OLD.HeSoTangCa
           OR NEW.TongPhuCap != OLD.TongPhuCap
           OR NEW.ThuNhapGop != OLD.ThuNhapGop
           OR NEW.ThuNhapThucLinh != OLD.ThuNhapThucLinh
           OR NEW.ThueTNCN != OLD.ThueTNCN THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Khong the sua so lieu tai chinh BangLuong da Thanh Toan (P) hoac Khoa (L)!';
        END IF;
    END IF;
END$$
DELIMITER ;

-- 2. Trigger chặn DELETE tuyệt đối đối với bảng lương đã chốt
DROP TRIGGER IF EXISTS trg_BangLuong_BeforeDelete_Protect;

DELIMITER $$
CREATE TRIGGER trg_BangLuong_BeforeDelete_Protect
BEFORE DELETE ON BangLuong
FOR EACH ROW
BEGIN
    IF OLD.TrangThai IN ('P', 'L') THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Khong duoc phep xoa BangLuong da Thanh Toan (P) hoac Khoa (L)!';
    END IF;
END$$
DELIMITER ;
