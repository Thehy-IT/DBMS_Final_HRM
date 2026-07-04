-- MỤC ĐÍCH   : Trigger audit log bảng LuongCoBan + BangLuong
-- TRIGGERS   :
--   1. trg_LuongCoBan_AfterInsert  — log điều chỉnh lương mới
--   2. trg_LuongCoBan_AfterUpdate  — log từng cột thay đổi
--   3. trg_BangLuong_BeforeUpdate  — ngăn sửa bảng lương CHOT
--   4. trg_BangLuong_BeforeDelete  — ngăn xóa bảng lương CHOT
--   5. trg_BangLuong_AfterUpdate   — log chuyển trạng thái
-- DBMS       : MySQL 8.0+
-- GHI CHÚ   : Không có INSERTED/DELETED virtual table trong MySQL
--              Dùng NEW và OLD thay thế

USE HRPayrollDB;

-- TRIGGER 1: trg_LuongCoBan_AfterInsert
DROP TRIGGER IF EXISTS trg_LuongCoBan_AfterInsert;

DELIMITER $$
CREATE TRIGGER trg_LuongCoBan_AfterInsert
AFTER INSERT ON LuongCoBan
FOR EACH ROW
BEGIN
    DECLARE v_LuongCu VARCHAR(100);

    -- Lấy mức lương trước đó (nếu có)
    SELECT CONCAT(FORMAT(LuongCB, 0), ' VNĐ')
    INTO v_LuongCu
    FROM LuongCoBan prev
    WHERE prev.MaNV        = NEW.MaNV
      AND prev.MaLCB        < NEW.MaLCB
      AND prev.NgayHieuLuc  < NEW.NgayHieuLuc
    ORDER BY prev.NgayHieuLuc DESC
    LIMIT 1;

    INSERT INTO AuditLog_Luong
        (MaNV, LoaiThayDoi, TenCot, GiaTriCu, GiaTriMoi)
    VALUES (
        NEW.MaNV,
        'INSERT',
        'LuongCoBan',
        v_LuongCu,
        CONCAT(FORMAT(NEW.LuongCB, 0), ' VNĐ (hiệu lực: ',
               DATE_FORMAT(NEW.NgayHieuLuc, '%d/%m/%Y'), ')')
    );
END$$
DELIMITER ;

SELECT 'trg_LuongCoBan_AfterInsert' AS Status;


-- TRIGGER 2: trg_LuongCoBan_AfterUpdate
DROP TRIGGER IF EXISTS trg_LuongCoBan_AfterUpdate;

DELIMITER $$
CREATE TRIGGER trg_LuongCoBan_AfterUpdate
AFTER UPDATE ON LuongCoBan
FOR EACH ROW
BEGIN
    -- LuongCoBan thay đổi
    IF OLD.LuongCB <> NEW.LuongCB THEN
        INSERT INTO AuditLog_Luong (MaNV, LoaiThayDoi, TenCot, GiaTriCu, GiaTriMoi)
        VALUES (NEW.MaNV, 'UPDATE', 'LuongCB',
                CONCAT(FORMAT(OLD.LuongCB, 0), ' VNĐ'),
                CONCAT(FORMAT(NEW.LuongCB, 0), ' VNĐ'));
    END IF;

    -- LuongDongBH thay đổi
    IF OLD.LuongDongBH <> NEW.LuongDongBH THEN
        INSERT INTO AuditLog_Luong (MaNV, LoaiThayDoi, TenCot, GiaTriCu, GiaTriMoi)
        VALUES (NEW.MaNV, 'UPDATE', 'LuongDongBH',
                CONCAT(FORMAT(OLD.LuongDongBH, 0), ' VNĐ'),
                CONCAT(FORMAT(NEW.LuongDongBH, 0), ' VNĐ'));
    END IF;

    -- NgayHieuLuc thay đổi
    IF OLD.NgayHieuLuc <> NEW.NgayHieuLuc THEN
        INSERT INTO AuditLog_Luong (MaNV, LoaiThayDoi, TenCot, GiaTriCu, GiaTriMoi)
        VALUES (NEW.MaNV, 'UPDATE', 'NgayHieuLuc',
                DATE_FORMAT(OLD.NgayHieuLuc, '%d/%m/%Y'),
                DATE_FORMAT(NEW.NgayHieuLuc, '%d/%m/%Y'));
    END IF;

    -- NgayHetHieuLuc thay đổi
    IF IFNULL(CAST(OLD.NgayHetHieuLuc AS CHAR), '') <>
       IFNULL(CAST(NEW.NgayHetHieuLuc AS CHAR), '')
    THEN
        INSERT INTO AuditLog_Luong (MaNV, LoaiThayDoi, TenCot, GiaTriCu, GiaTriMoi)
        VALUES (NEW.MaNV, 'UPDATE', 'NgayHetHieuLuc',
                IFNULL(DATE_FORMAT(OLD.NgayHetHieuLuc, '%d/%m/%Y'), 'Còn hiệu lực'),
                IFNULL(DATE_FORMAT(NEW.NgayHetHieuLuc, '%d/%m/%Y'), 'Còn hiệu lực'));
    END IF;
END$$
DELIMITER ;

SELECT 'trg_LuongCoBan_AfterUpdate' AS Status;


-- TRIGGER 3: trg_BangLuong_BeforeUpdate
-- Ngăn sửa bảng lương đã xác nhận / thanh toán
DROP TRIGGER IF EXISTS trg_BangLuong_BeforeUpdate;

DELIMITER $$
CREATE TRIGGER trg_BangLuong_BeforeUpdate
BEFORE UPDATE ON BangLuong
FOR EACH ROW
BEGIN
    -- Kiểm tra có dòng CHOT bị tác động không
    IF OLD.TrangThai IN ('C', 'P', 'L') THEN
        -- Cho phép C→P và P→L (chuyển trạng thái)
        -- Chặn nếu đang cố sửa số liệu
        IF NOT (
            (OLD.TrangThai = 'C' AND NEW.TrangThai = 'P') OR
            (OLD.TrangThai = 'P' AND NEW.TrangThai = 'L')
        ) AND (
            NEW.LuongCoBan   <> OLD.LuongCoBan   OR
            NEW.TongPhuCap   <> OLD.TongPhuCap   OR
            NEW.BHXH_NLD     <> OLD.BHXH_NLD     OR
            NEW.ThueTNCN     <> OLD.ThueTNCN      OR
            NEW.TongKhauTru  <> OLD.TongKhauTru
        ) THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Khong the sua so lieu BangLuong da XAC NHAN. Chi cho phep C->P hoac P->L.';
        END IF;
    END IF;
END$$
DELIMITER ;

SELECT 'trg_BangLuong_BeforeUpdate (Guard)' AS Status;


-- ============================================================
-- TRIGGER 4: trg_BangLuong_BeforeDelete
-- Ngăn xóa bảng lương đã xác nhận
-- ============================================================
DROP TRIGGER IF EXISTS trg_BangLuong_BeforeDelete;

DELIMITER $$
CREATE TRIGGER trg_BangLuong_BeforeDelete
BEFORE DELETE ON BangLuong
FOR EACH ROW
BEGIN
    IF OLD.TrangThai IN ('C', 'P', 'L') THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'trg_BangLuong_BeforeDelete: Không thể XÓA bảng lương đã XÁC NHẬN / THANH TOÁN.';
    END IF;
END$$
DELIMITER ;

SELECT 'trg_BangLuong_BeforeDelete (Guard)' AS Status;


-- TRIGGER 5: trg_BangLuong_AfterUpdate
-- Log chuyển trạng thái hợp lệ (C→P hoặc P→L)
DROP TRIGGER IF EXISTS trg_BangLuong_AfterUpdate;

DELIMITER $$
CREATE TRIGGER trg_BangLuong_AfterUpdate
AFTER UPDATE ON BangLuong
FOR EACH ROW
BEGIN
    -- Log chuyển trạng thái
    IF OLD.TrangThai <> NEW.TrangThai THEN
        INSERT INTO AuditLog_Luong
            (MaBL, MaNV, Thang, Nam, LoaiThayDoi, TenCot, GiaTriCu, GiaTriMoi)
        VALUES (
            NEW.MaBL,
            NEW.MaNV,
            NEW.Thang,
            NEW.Nam,
            'STATUS_CHANGE',
            'TrangThai',
            OLD.TrangThai,
            CONCAT(NEW.TrangThai, ' (NgayTT: ',
                   IFNULL(DATE_FORMAT(NEW.NgayThanhToan, '%d/%m/%Y'), '—'), ')')
        );
    END IF;
END$$
DELIMITER ;

SELECT 'trg_BangLuong_AfterUpdate (Audit)' AS Status;


SELECT '[DONE] trg_LogLuong.sql — 5 triggers hoàn tất' AS Status;
