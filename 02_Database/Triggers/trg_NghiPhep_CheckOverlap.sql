-- ============================================================
-- FILE       : trg_NghiPhep_CheckOverlap.sql
-- PROJECT    : Hệ Thống Quản Lý Nhân Sự & Tính Lương Tự Động
-- MỤC ĐÍCH   : Ngăn chặn đơn nghỉ phép trùng lặp (Overlap)
-- BR-07      : Một nhân viên không thể có 2 đơn nghỉ APPROVED trùng ngày nhau
-- DBMS       : MySQL 8.0+
-- ============================================================

USE HRPayrollDB;

-- ── TRIGGER 1: trg_NghiPhep_CheckOverlap_Insert (BEFORE INSERT)
DROP TRIGGER IF EXISTS trg_NghiPhep_CheckOverlap_Insert;

DELIMITER $$

CREATE TRIGGER trg_NghiPhep_CheckOverlap_Insert
BEFORE INSERT ON NghiPhep
FOR EACH ROW
BEGIN
    -- Chỉ kiểm tra nếu đơn nghỉ mới ở trạng thái APPROVED ('A')
    IF NEW.TrangThai = 'A' THEN
        IF EXISTS (
            SELECT 1 FROM NghiPhep
            WHERE MaNV = NEW.MaNV
              AND TrangThai = 'A'
              AND NEW.NgayBatDau <= NgayKetThuc 
              AND NgayBatDau <= NEW.NgayKetThuc
        ) THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'trg_NghiPhep_CheckOverlap_Insert: Nhân viên đã có đơn nghỉ phép khác được duyệt trong khoảng thời gian này.';
        END IF;
    END IF;
END$$

DELIMITER ;

-- ── TRIGGER 2: trg_NghiPhep_CheckOverlap_Update (BEFORE UPDATE)
DROP TRIGGER IF EXISTS trg_NghiPhep_CheckOverlap_Update;

DELIMITER $$

CREATE TRIGGER trg_NghiPhep_CheckOverlap_Update
BEFORE UPDATE ON NghiPhep
FOR EACH ROW
BEGIN
    -- Kiểm tra nếu đơn nghỉ được chuyển sang trạng thái APPROVED ('A')
    -- Hoặc nếu đã APPROVED mà thay đổi ngày tháng
    IF NEW.TrangThai = 'A' THEN
        IF EXISTS (
            SELECT 1 FROM NghiPhep
            WHERE MaNV = NEW.MaNV
              AND TrangThai = 'A'
              AND MaNP <> OLD.MaNP -- Loại trừ chính nó
              AND NEW.NgayBatDau <= NgayKetThuc 
              AND NgayBatDau <= NEW.NgayKetThuc
        ) THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'trg_NghiPhep_CheckOverlap_Update: Thời gian nghỉ phép mới trùng với một đơn nghỉ khác đã được duyệt.';
        END IF;
    END IF;
END$$

DELIMITER ;

SELECT '[OK] trg_NghiPhep_CheckOverlap (Insert/Update)' AS Status;


-- ============================================================
-- KIỂM THỬ (TEST CASE)
-- ============================================================
/*
-- 1. Giả sử NV000001 đã có đơn nghỉ từ 2025-01-01 đến 2025-01-05 (Approved)
-- Thử chèn đơn mới trùng 1 phần (Lỗi mong đợi)
INSERT INTO NghiPhep (MaNV, MaLoaiNghi, NgayBatDau, NgayKetThuc, TrangThai)
VALUES ('NV000001', 1, '2025-01-03', '2025-01-07', 'A');

-- 2. Thử cập nhật đơn Pending thành Approved nhưng bị trùng (Lỗi mong đợi)
UPDATE NghiPhep SET TrangThai = 'A' WHERE MaNP = ...;
*/
