/* MỤC ĐÍCH   : Bổ sung ràng buộc & index cho MySQL
              1  Unique Index có điều kiện (emulated trong MySQL)
              2  CHECK định dạng mã
              3  CHECK nghiệp vụ nâng cao
              4  CHECK tài chính & pháp lý
              5  Composite Index hiệu năng
              6  Kiểm tra & báo cáo tổng thể
 DEPENDENCY : Chạy SAU 01_create_tables.sql
 DBMS       : MySQL 8.0.46 */
USE HRPayrollDB;

SELECT '02_constraints.sql — bắt đầu áp dụng ràng buộc' AS Status;

-- 1  UNIQUE INDEX (thay thế Filtered Unique Index của SQL Server)

-- BR-05: Mỗi nhân viên chỉ có 1 hợp đồng đang hiệu lực
-- Được kiểm soát bởi trigger trg_HopDong_CheckOneActive (xem Triggers/)

-- 1.2  Mỗi nhân viên chỉ có 1 mức lương cơ bản đang áp dụng
-- Được kiểm soát bởi trigger trg_LuongCoBan_CheckOneCurrent

-- 1.3  BangLuong đã LOCK không được tạo lại
-- UNIQUE (MaNV, Thang, Nam) đã tạo trong 01_create_tables.sql

-- 1.4  Cùng nhân viên không có 2 đơn nghỉ APPROVED trùng ngày
-- Được kiểm soát bởi trigger trg_NghiPhep_CheckOverlap


-- 2  CHECK ĐỊNH DẠNG MÃ (FORMAT VALIDATION)
-- Đã được thêm trong 01_create_tables.sql bằng CHECK + REGEXP

DROP PROCEDURE IF EXISTS _AddConstraintSafe;
DELIMITER $$
CREATE PROCEDURE _AddConstraintSafe(
    IN p_Table VARCHAR(100),
    IN p_Constraint VARCHAR(100),
    IN p_DDL TEXT
)
BEGIN
    DECLARE v_Exists INT DEFAULT 0;
    SELECT COUNT(*) INTO v_Exists
    FROM information_schema.TABLE_CONSTRAINTS
    WHERE CONSTRAINT_SCHEMA = DATABASE()
      AND TABLE_NAME = p_Table
      AND CONSTRAINT_NAME = p_Constraint;
    IF v_Exists = 0 THEN
        SET @sql = p_DDL;
        PREPARE stmt FROM @sql;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;
    END IF;
END$$
DELIMITER ;

-- 2.5  NhanVien.SoDienThoai
-- Kiểm tra trong MySQL với REGEXP
CALL _AddConstraintSafe(
    'NhanVien',
    'CK_NhanVien_SDT_Format',
    'ALTER TABLE NhanVien ADD CONSTRAINT CK_NhanVien_SDT_Format CHECK (
        SoDienThoai IS NULL
        OR SoDienThoai REGEXP ''^0[0-9]{9}$''
        OR SoDienThoai REGEXP ''^\\+84[0-9]{9}$''
    )'
);

-- 2.6  NhanVien.MaSoThue
CALL _AddConstraintSafe(
    'NhanVien',
    'CK_NhanVien_MST_Format',
    'ALTER TABLE NhanVien ADD CONSTRAINT CK_NhanVien_MST_Format CHECK (
        MaSoThue IS NULL
        OR (
            CHAR_LENGTH(MaSoThue) IN (10, 13)
            AND MaSoThue REGEXP ''^[0-9-]+$''
        )
    )'
);


--  3  CHECK NGHIỆP VỤ NHÂN SỰ NÂNG CAO
-- 3.1  NhanVien: tuổi tối thiểu 18 và tối đa 70
-- CHUYỂN SANG TRIGGER: trg_NhanVien_CheckTuoi (tạo bên dưới)

-- 3.2  HopDong: Ngày bắt đầu hợp lệ (đã có trong CREATE TABLE)

-- 3.3  HopDong: Ngày ký không sau ngày bắt đầu (đã có)

-- 3.5  NghiPhep: Số ngày nghỉ tối đa 365 (đã có trong CREATE TABLE)

-- 3.6  NghiPhep: Ngày duyệt phải sau hoặc bằng ngày tạo
-- NOTE: NgayDuyet là DATETIME, NgayTao là DATETIME → so sánh OK (deterministic field comparison)
CALL _AddConstraintSafe(
    'NghiPhep',
    'CK_NghiPhep_NgayDuyetHopLe',
    'ALTER TABLE NghiPhep ADD CONSTRAINT CK_NghiPhep_NgayDuyetHopLe
        CHECK (NgayDuyet IS NULL OR NgayDuyet >= NgayTao)'
);

-- 3.7  ChamCong: Không chấm công tương lai
-- → Đã có trong trg_ChamCong_BeforeInsert và trg_ChamCong_BeforeUpdate

-- 3.8  ChamCong: Giờ vào hợp lệ (05:00 – 11:00)
-- TIME literal là deterministic → OK trong CHECK
CALL _AddConstraintSafe(
    'ChamCong',
    'CK_ChamCong_GioVaoHopLe',
    'ALTER TABLE ChamCong ADD CONSTRAINT CK_ChamCong_GioVaoHopLe CHECK (
        GioVao IS NULL
        OR (GioVao >= ''05:00:00'' AND GioVao <= ''11:00:00'')
    )'
);

-- 3.9  ChamCong: Giờ ra hợp lệ (12:00 – 23:59)
CALL _AddConstraintSafe(
    'ChamCong',
    'CK_ChamCong_GioRaHopLe',
    'ALTER TABLE ChamCong ADD CONSTRAINT CK_ChamCong_GioRaHopLe CHECK (
        GioRa IS NULL
        OR (GioRa >= ''12:00:00'' AND GioRa <= ''23:59:00'')
    )'
);

-- 3.10  KhauTru: Ngày phát sinh không ở tương lai
-- PHẢI DÙNG TRIGGER vì CURDATE() là non-deterministic trong CHECK
-- → Enforce qua trigger / stored procedure nhập liệu

 --  4  CHECK TÀI CHÍNH & PHÁP LÝ
 
-- 4.2  HopDong: Lương không thấp hơn mức tối thiểu vùng
-- Sửa lại theo mức lương tối thiểu vùng 2024 (Nghị định 74/2024/NĐ-CP)
-- Vùng 1: 4.960.000 / Vùng 2: 4.410.000 / Vùng 3: 3.860.000 / Vùng 4: 3.450.000
CALL _AddConstraintSafe(
    'HopDong',
    'CK_HopDong_LuongToiThieuVung',
    'ALTER TABLE HopDong ADD CONSTRAINT CK_HopDong_LuongToiThieuVung CHECK (
        (VungLuong = 1 AND LuongCoBan >= 4960000) OR
        (VungLuong = 2 AND LuongCoBan >= 4410000) OR
        (VungLuong = 3 AND LuongCoBan >= 3860000) OR
        (VungLuong = 4 AND LuongCoBan >= 3450000)
    )'
);

-- 4.5  BangLuong: Ngày thanh toán phải sau ngày xác nhận
-- DATE(NgayXacNhan): hàm DATE() là deterministic khi applied to column → OK trong CHECK
CALL _AddConstraintSafe(
    'BangLuong',
    'CK_BangLuong_NgayThanhToanHopLe',
    'ALTER TABLE BangLuong ADD CONSTRAINT CK_BangLuong_NgayThanhToanHopLe CHECK (
        NgayThanhToan IS NULL
        OR NgayXacNhan IS NULL
        OR NgayThanhToan >= DATE(NgayXacNhan)
    )'
);
-- Dọn dẹp helper procedure
DROP PROCEDURE IF EXISTS _AddConstraintSafe;


 --  5  COMPOSITE INDEX BỔ SUNG (HIỆU NĂNG TRUY VẤN)
-- Đã được chuyển sang 03_indexes.sql để tạo an toàn (IF NOT EXISTS)
 
 --  6  BÁO CÁO TỔNG HỢP
 -- ── 6.1  Tất cả CHECK constraints
SELECT
    tc.TABLE_NAME       AS Bảng,
    cc.CONSTRAINT_NAME  AS TênConstraint,
    cc.CHECK_CLAUSE     AS ĐịnhNghĩa,
    'ENABLED'           AS TrạngThái
FROM information_schema.CHECK_CONSTRAINTS cc
JOIN information_schema.TABLE_CONSTRAINTS tc
    ON cc.CONSTRAINT_NAME = tc.CONSTRAINT_NAME
    AND cc.CONSTRAINT_SCHEMA = tc.CONSTRAINT_SCHEMA
WHERE cc.CONSTRAINT_SCHEMA = 'HRPayrollDB'
ORDER BY tc.TABLE_NAME, cc.CONSTRAINT_NAME;

-- ── 6.2  Tất cả Indexes
SELECT
    TABLE_NAME        AS Bảng,
    INDEX_NAME        AS TênIndex,
    CASE NON_UNIQUE WHEN 0 THEN 'YES' ELSE 'NO' END AS IsUnique,
    INDEX_TYPE        AS Loại,
    COLUMN_NAME       AS CộtKey
FROM information_schema.STATISTICS
WHERE TABLE_SCHEMA = 'HRPayrollDB'
ORDER BY TABLE_NAME, INDEX_NAME, SEQ_IN_INDEX;

-- ── 6.3  FOREIGN KEY summary
SELECT
    TABLE_NAME          AS BảngCon,
    COLUMN_NAME         AS CộtCon,
    REFERENCED_TABLE_NAME  AS BảngCha,
    REFERENCED_COLUMN_NAME AS CộtCha,
    CONSTRAINT_NAME     AS TênFK
FROM information_schema.KEY_COLUMN_USAGE
WHERE TABLE_SCHEMA = 'HRPayrollDB'
  AND REFERENCED_TABLE_NAME IS NOT NULL
ORDER BY TABLE_NAME, CONSTRAINT_NAME;

SELECT '02_constraints.sql hoàn tất.' AS Status;
SELECT 'Bước tiếp: 03_indexes.sql' AS NextStep;
