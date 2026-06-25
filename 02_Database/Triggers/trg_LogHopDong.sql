-- MỤC ĐÍCH   : Trigger tự động ghi AUDIT LOG mọi thay đổi
--              trên bảng HopDong (INSERT / UPDATE / DELETE)
-- TRIGGERS   :
--   1. trg_HopDong_AfterInsert   — log hợp đồng mới
--   2. trg_HopDong_AfterUpdate   — log từng cột bị thay đổi
--   3. trg_HopDong_AfterDelete   — log hợp đồng bị xoá
--   4. trg_HopDong_BeforeUpdate  — PREVENT sửa HĐ đã LOCK (thay INSTEAD OF)
--   5. trg_HopDong_CheckOneActive — 1 NV chỉ có 1 HĐ Active
-- DBMS       : MySQL 8.0+
-- GHI CHÚ   : MySQL không hỗ trợ AFTER INSERT/UPDATE/DELETE trên
--              cùng bảng trong 1 trigger statement (phải tách)
--              Không có INSTEAD OF → dùng BEFORE trigger để SIGNAL

USE HRPayrollDB;

-- TRIGGER 1: trg_HopDong_AfterInsert
-- ============================================================
DROP TRIGGER IF EXISTS trg_HopDong_AfterInsert;

DELIMITER $$

CREATE TRIGGER trg_HopDong_AfterInsert
AFTER INSERT ON HopDong
FOR EACH ROW
BEGIN
    INSERT INTO AuditLog_HopDong
        (MaHD, MaNV, LoaiThayDoi, TenCot, GiaTriCu, GiaTriMoi)
    VALUES (
        NEW.MaHD,
        NEW.MaNV,
        'INSERT',
        '[FULL_RECORD]',
        NULL,
        CONCAT(
            '{"MaLoaiHD":"', NEW.MaLoaiHD, '",',
            '"NgayBatDau":"', DATE_FORMAT(NEW.NgayBatDau, '%Y-%m-%d'), '",',
            '"NgayKetThuc":"', IFNULL(DATE_FORMAT(NEW.NgayKetThuc, '%Y-%m-%d'), 'NULL'), '",',
            '"LuongCoBan":', NEW.LuongCoBan, ',',
            '"VungLuong":', NEW.VungLuong, ',',
            '"TrangThai":"', NEW.TrangThai, '"}'
        )
    );
END$$

DELIMITER ;

SELECT 'trg_HopDong_AfterInsert' AS Status;


-- TRIGGER 2: trg_HopDong_AfterUpdate
-- Ghi log chi tiết từng cột bị thay đổi

DROP TRIGGER IF EXISTS trg_HopDong_AfterUpdate;

DELIMITER $$
CREATE TRIGGER trg_HopDong_AfterUpdate
AFTER UPDATE ON HopDong
FOR EACH ROW
BEGIN
    -- Cột: MaLoaiHD
    IF OLD.MaLoaiHD <> NEW.MaLoaiHD THEN
        INSERT INTO AuditLog_HopDong (MaHD, MaNV, LoaiThayDoi, TenCot, GiaTriCu, GiaTriMoi)
        VALUES (NEW.MaHD, NEW.MaNV, 'UPDATE', 'MaLoaiHD',
                CAST(OLD.MaLoaiHD AS CHAR), CAST(NEW.MaLoaiHD AS CHAR));
    END IF;

    -- Cột: NgayBatDau
    IF IFNULL(OLD.NgayBatDau, '') <> IFNULL(NEW.NgayBatDau, '') THEN
        INSERT INTO AuditLog_HopDong (MaHD, MaNV, LoaiThayDoi, TenCot, GiaTriCu, GiaTriMoi)
        VALUES (NEW.MaHD, NEW.MaNV, 'UPDATE', 'NgayBatDau',
                DATE_FORMAT(OLD.NgayBatDau, '%Y-%m-%d'),
                DATE_FORMAT(NEW.NgayBatDau, '%Y-%m-%d'));
    END IF;

    -- Cột: NgayKetThuc
    IF IFNULL(CAST(OLD.NgayKetThuc AS CHAR), '') <> IFNULL(CAST(NEW.NgayKetThuc AS CHAR), '') THEN
        INSERT INTO AuditLog_HopDong (MaHD, MaNV, LoaiThayDoi, TenCot, GiaTriCu, GiaTriMoi)
        VALUES (NEW.MaHD, NEW.MaNV, 'UPDATE', 'NgayKetThuc',
                IFNULL(DATE_FORMAT(OLD.NgayKetThuc, '%Y-%m-%d'), 'NULL'),
                IFNULL(DATE_FORMAT(NEW.NgayKetThuc, '%Y-%m-%d'), 'NULL'));
    END IF;

    -- Cột: LuongCoBan
    IF OLD.LuongCoBan <> NEW.LuongCoBan THEN
        INSERT INTO AuditLog_HopDong (MaHD, MaNV, LoaiThayDoi, TenCot, GiaTriCu, GiaTriMoi)
        VALUES (NEW.MaHD, NEW.MaNV, 'UPDATE', 'LuongCoBan',
                FORMAT(OLD.LuongCoBan, 0), FORMAT(NEW.LuongCoBan, 0));
    END IF;

    -- Cột: VungLuong
    IF OLD.VungLuong <> NEW.VungLuong THEN
        INSERT INTO AuditLog_HopDong (MaHD, MaNV, LoaiThayDoi, TenCot, GiaTriCu, GiaTriMoi)
        VALUES (NEW.MaHD, NEW.MaNV, 'UPDATE', 'VungLuong',
                CAST(OLD.VungLuong AS CHAR), CAST(NEW.VungLuong AS CHAR));
    END IF;

    -- Cột: TrangThai
    IF OLD.TrangThai <> NEW.TrangThai THEN
        INSERT INTO AuditLog_HopDong (MaHD, MaNV, LoaiThayDoi, TenCot, GiaTriCu, GiaTriMoi)
        VALUES (NEW.MaHD, NEW.MaNV, 'UPDATE', 'TrangThai',
                OLD.TrangThai, NEW.TrangThai);
    END IF;

    -- Cột: NguoiKy_NLD
    IF IFNULL(OLD.NguoiKy_NLD, '') <> IFNULL(NEW.NguoiKy_NLD, '') THEN
        INSERT INTO AuditLog_HopDong (MaHD, MaNV, LoaiThayDoi, TenCot, GiaTriCu, GiaTriMoi)
        VALUES (NEW.MaHD, NEW.MaNV, 'UPDATE', 'NguoiKy_NLD',
                OLD.NguoiKy_NLD, NEW.NguoiKy_NLD);
    END IF;
END$$
DELIMITER ;

SELECT 'trg_HopDong_AfterUpdate' AS Status;

-- TRIGGER 3: trg_HopDong_AfterDelete
DROP TRIGGER IF EXISTS trg_HopDong_AfterDelete;

DELIMITER $$
CREATE TRIGGER trg_HopDong_AfterDelete
AFTER DELETE ON HopDong
FOR EACH ROW
BEGIN
    INSERT INTO AuditLog_HopDong
        (MaHD, MaNV, LoaiThayDoi, TenCot, GiaTriCu, GiaTriMoi)
    VALUES (
        OLD.MaHD,
        OLD.MaNV,
        'DELETE',
        '[FULL_RECORD]',
        CONCAT(
            '{"MaLoaiHD":"', OLD.MaLoaiHD, '",',
            '"NgayBatDau":"', DATE_FORMAT(OLD.NgayBatDau, '%Y-%m-%d'), '",',
            '"LuongCoBan":', OLD.LuongCoBan, ',',
            '"TrangThai":"', OLD.TrangThai, '"}'
        ),
        NULL
    );
END$$
DELIMITER ;

SELECT 'trg_HopDong_AfterDelete' AS Status;


-- TRIGGER 4: trg_HopDong_BeforeUpdate (Guard chống sửa HĐ LOCK)
-- Thay thế INSTEAD OF trong SQL Server
DROP TRIGGER IF EXISTS trg_HopDong_BeforeUpdate;

DELIMITER $$
CREATE TRIGGER trg_HopDong_BeforeUpdate
BEFORE UPDATE ON HopDong
FOR EACH ROW
BEGIN
    -- Kiểm tra nếu HĐ đang ở trạng thái LOCK
    IF OLD.TrangThai = 'L' THEN
        -- Chỉ cho phép thay đổi TrangThai (unlock), không cho sửa nội dung
        IF NEW.LuongCoBan <> OLD.LuongCoBan OR
           NEW.NgayBatDau  <> OLD.NgayBatDau OR
           NEW.MaLoaiHD    <> OLD.MaLoaiHD
        THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'trg_HopDong_BeforeUpdate: Hợp đồng KHÓA — chỉ được phép thay đổi TrangThai, không sửa nội dung.';
        END IF;
    END IF;
END$$
DELIMITER ;

SELECT 'trg_HopDong_BeforeUpdate (Guard)' AS Status;

-- TRIGGER 5: trg_HopDong_BeforeDelete (Guard chống xóa HĐ LOCK)
DROP TRIGGER IF EXISTS trg_HopDong_BeforeDelete;

DELIMITER $$
CREATE TRIGGER trg_HopDong_BeforeDelete
BEFORE DELETE ON HopDong
FOR EACH ROW
BEGIN
    IF OLD.TrangThai = 'L' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'trg_HopDong_BeforeDelete: Không thể XÓA hợp đồng đã KHÓA (TrangThai=L).';
    END IF;
END$$
DELIMITER ;

SELECT 'trg_HopDong_BeforeDelete (Guard)' AS Status;


-- TRIGGER 6: trg_HopDong_CheckOneActive
-- Đảm bảo mỗi NV chỉ có 1 HĐ đang hiệu lực (Active)
-- Thay thế Filtered Unique Index của SQL Server
DROP TRIGGER IF EXISTS trg_HopDong_CheckOneActive;

DELIMITER $$
CREATE TRIGGER trg_HopDong_CheckOneActive
BEFORE INSERT ON HopDong
FOR EACH ROW
BEGIN
    IF NEW.TrangThai = 'A' THEN
        IF EXISTS (
            SELECT 1 FROM HopDong
            WHERE MaNV = NEW.MaNV
              AND TrangThai = 'A'
        ) THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'trg_HopDong_CheckOneActive: Nhân viên đã có hợp đồng đang hiệu lực. Vui lòng đóng HĐ cũ trước.';
        END IF;
    END IF;
END$$
DELIMITER ;

SELECT 'trg_HopDong_CheckOneActive' AS Status;


-- KIỂM THỬ TRIGGERS
SELECT '  KIỂM THỬ trg_HopDong_*' AS Status;

-- Test: UPDATE lương hợp đồng NV000002
UPDATE HopDong
SET LuongCoBan = 9000000
WHERE MaHD = 'HD000002' AND TrangThai = 'A';

-- Xem log được ghi tự động
SELECT
    MaLog, MaHD, MaNV, LoaiThayDoi, TenCot, GiaTriCu, GiaTriMoi,
    DATE_FORMAT(ThoiGianThayDoi, '%d/%m/%Y %H:%i:%s') AS ThoiGian,
    NguoiThayDoi
FROM AuditLog_HopDong
ORDER BY MaLog DESC
LIMIT 5;

-- Rollback test change
UPDATE HopDong SET LuongCoBan = 8500000 WHERE MaHD = 'HD000002';

SELECT 'trg_LogHopDong.sql — 6 triggers hoàn tất' AS Status;
