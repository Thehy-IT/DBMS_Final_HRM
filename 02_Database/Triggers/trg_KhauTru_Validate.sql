-- ============================================================
-- FILE       : trg_KhauTru_Validate.sql
-- PROJECT    : Hệ Thống Quản Lý Nhân Sự & Tính Lương Tự Động
-- MỤC ĐÍCH   : Validate nghiệp vụ cho bảng KhauTru
-- BR-10      : Ngày phát sinh không được ở tương lai
-- DBMS       : MySQL 8.0+
-- ============================================================

USE HRPayrollDB;

-- ── TRIGGER 1: trg_KhauTru_BeforeInsert_NgayHopLe
DROP TRIGGER IF EXISTS trg_KhauTru_BeforeInsert_NgayHopLe;

DELIMITER $$

CREATE TRIGGER trg_KhauTru_BeforeInsert_NgayHopLe
BEFORE INSERT ON KhauTru
FOR EACH ROW
BEGIN
    IF NEW.NgayPhatSinh > CURDATE() THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'trg_KhauTru_BeforeInsert_NgayHopLe: Ngày phát sinh không được là ngày tương lai.';
    END IF;
END$$

DELIMITER ;

-- ── TRIGGER 2: trg_KhauTru_BeforeUpdate_NgayHopLe
DROP TRIGGER IF EXISTS trg_KhauTru_BeforeUpdate_NgayHopLe;

DELIMITER $$

CREATE TRIGGER trg_KhauTru_BeforeUpdate_NgayHopLe
BEFORE UPDATE ON KhauTru
FOR EACH ROW
BEGIN
    IF NEW.NgayPhatSinh > CURDATE() THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'trg_KhauTru_BeforeUpdate_NgayHopLe: Ngày phát sinh không được là ngày tương lai.';
    END IF;
END$$

DELIMITER ;

SELECT '[OK] trg_KhauTru_Validate (Insert/Update)' AS Status;
