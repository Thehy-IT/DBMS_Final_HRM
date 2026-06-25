-- MỤC ĐÍCH   : Đảm bảo mỗi nhân viên chỉ có 1 mức lương đang áp dụng
-- BR-06      : Mỗi nhân viên chỉ có 1 dòng LuongCoBan có NgayHetHieuLuc IS NULL
-- DBMS       : MySQL 8.0+

USE HRPayrollDB;

-- ── TRIGGER 1: trg_LuongCoBan_CheckOneCurrent (BEFORE INSERT)
DROP TRIGGER IF EXISTS trg_LuongCoBan_CheckOneCurrent;

DELIMITER $$
CREATE TRIGGER trg_LuongCoBan_CheckOneCurrent
BEFORE INSERT ON LuongCoBan
FOR EACH ROW
BEGIN
    -- Chỉ kiểm tra nếu dòng mới chèn vào là dòng đang áp dụng (NgayHetHieuLuc IS NULL)
    IF NEW.NgayHetHieuLuc IS NULL THEN
        IF EXISTS (
            SELECT 1 FROM LuongCoBan
            WHERE MaNV = NEW.MaNV
              AND NgayHetHieuLuc IS NULL
        ) THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'trg_LuongCoBan_CheckOneCurrent: Nhân viên đã có mức lương đang áp dụng. Vui lòng đóng mức lương cũ trước (set NgayHetHieuLuc).';
        END IF;
    END IF;
END$$
DELIMITER ;

-- ── TRIGGER 2: trg_LuongCoBan_CheckOneCurrent_Update (BEFORE UPDATE)
DROP TRIGGER IF EXISTS trg_LuongCoBan_CheckOneCurrent_Update;
DELIMITER $$
CREATE TRIGGER trg_LuongCoBan_CheckOneCurrent_Update
BEFORE UPDATE ON LuongCoBan
FOR EACH ROW
BEGIN
    -- Chỉ kiểm tra nếu đang sửa một dòng từ "đã đóng" thành "đang áp dụng"
    IF NEW.NgayHetHieuLuc IS NULL AND OLD.NgayHetHieuLuc IS NOT NULL THEN
        IF EXISTS (
            SELECT 1 FROM LuongCoBan
            WHERE MaNV = NEW.MaNV
              AND NgayHetHieuLuc IS NULL
              AND MaLCB <> OLD.MaLCB
        ) THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'trg_LuongCoBan_CheckOneCurrent_Update: Nhân viên đã có mức lương đang áp dụng khác. Không thể chuyển trạng thái dòng này thành đang áp dụng.';
        END IF;
    END IF;
END$$
DELIMITER ;

SELECT 'trg_LuongCoBan_CheckOneCurrent (Insert/Update)' AS Status;

-- KIỂM THỬ (TEST CASE)
/*
-- 1. Thử chèn thêm lương mới cho NV đã có lương đang áp dụng (Lỗi mong đợi)
INSERT INTO LuongCoBan (MaNV, LuongCB, LuongDongBH, NgayHieuLuc, NgayHetHieuLuc)
VALUES ('NV000001', 50000000, 40000000, '2025-06-01', NULL);

-- 2. Thử update một dòng cũ thành NULL (Lỗi mong đợi)
-- Giả sử MaLCB = 1 đã đóng
UPDATE LuongCoBan SET NgayHetHieuLuc = NULL WHERE MaLCB = 1;
*/
