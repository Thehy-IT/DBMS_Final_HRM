/*
MỤC ĐÍCH   : Bổ sung index tối ưu hiệu năng cho Dashboard queries và Employee list
DEPENDENCY : Chạy SAU 03_indexes.sql (dùng _CreateIndexSafe procedure)
DBMS       : MySQL 8.0+
NGÀY       : 2026-06-28
*/

USE HRPayrollDB;

SELECT '[INFO] 04_perf_indexes.sql — Index bổ sung tối ưu hiệu năng giao diện' AS Status;

-- Helper procedure tái sử dụng logic từ 03_indexes.sql
DROP PROCEDURE IF EXISTS _CreateIndexSafe;
DELIMITER $$
CREATE PROCEDURE _CreateIndexSafe(
    IN p_Schema   VARCHAR(100),
    IN p_Table    VARCHAR(100),
    IN p_Index    VARCHAR(100),
    IN p_DDL      TEXT
)
BEGIN
    DECLARE v_Exists INT DEFAULT 0;
    SELECT COUNT(*) INTO v_Exists
    FROM information_schema.STATISTICS
    WHERE TABLE_SCHEMA = p_Schema
      AND TABLE_NAME   = p_Table
      AND INDEX_NAME   = p_Index;
    IF v_Exists = 0 THEN
        SET @sql = p_DDL;
        PREPARE stmt FROM @sql;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;
        SELECT CONCAT('[OK] Tạo index: ', p_Index, ' ON ', p_Table) AS Status;
    ELSE
        SELECT CONCAT('[SKIP] Index đã tồn tại: ', p_Index, ' ON ', p_Table) AS Status;
    END IF;
END$$
DELIMITER ;

-- =============================================================================
-- NHÓM 1: Employee List Page — hỗ trợ tìm kiếm + lọc + phân trang
-- =============================================================================

-- 1.1 Search theo tên (dashboard stats + employees list search)
-- Covers: WHERE TrangThai = ? AND MaPB = ? ORDER BY MaNV
CALL _CreateIndexSafe('HRPayrollDB', 'NhanVien', 'IX_NhanVien_List_Perf',
    'CREATE INDEX IX_NhanVien_List_Perf ON NhanVien (TrangThai, MaPB, MaNV)');

-- 1.2 Full-text search theo HoTen (tìm kiếm nhân viên nhanh hơn LIKE)
-- MySQL FULLTEXT trên HoTen để WHERE HoTen LIKE '%...%' có thể dùng MATCH AGAINST
CALL _CreateIndexSafe('HRPayrollDB', 'NhanVien', 'IX_NhanVien_HoTen_FT',
    'CREATE FULLTEXT INDEX IX_NhanVien_HoTen_FT ON NhanVien (HoTen)');

-- =============================================================================
-- NHÓM 2: Dashboard — Stats và Chart aggregation
-- =============================================================================

-- 2.1 Payroll chart: GROUP BY phòng ban, lấy tổng NetSalary
-- Covers: JOIN NhanVien nv ON bl.MaNV = nv.MaNV để aggregate theo MaPB
CALL _CreateIndexSafe('HRPayrollDB', 'BangLuong', 'IX_BangLuong_Dashboard_Agg',
    'CREATE INDEX IX_BangLuong_Dashboard_Agg ON BangLuong (TrangThai, Nam, Thang, ThuNhapThucLinh, MaNV)');

-- 2.2 Leaves today filter: WHERE TrangThai = A AND NgayBatDau <= today AND NgayKetThuc >= today
-- Hiện index IX_NghiPhep_ThongKe_Nam chỉ cover (TrangThai, NgayBatDau) — thiếu NgayKetThuc
CALL _CreateIndexSafe('HRPayrollDB', 'NghiPhep', 'IX_NghiPhep_Dashboard_Today',
    'CREATE INDEX IX_NghiPhep_Dashboard_Today ON NghiPhep (TrangThai, NgayBatDau, NgayKetThuc)');

-- =============================================================================
-- NHÓM 3: Attendance — phân trang theo nhân viên và ngày
-- =============================================================================

-- 3.1 Attendance list có ORDER BY ngày giảm dần, filter theo nhân viên
-- Covers: WHERE MaNV = ? ORDER BY NgayCham DESC + WHERE ngày trong kỳ
CALL _CreateIndexSafe('HRPayrollDB', 'ChamCong', 'IX_ChamCong_List_Perf',
    'CREATE INDEX IX_ChamCong_List_Perf ON ChamCong (MaNV, NgayCham DESC, TrangThai)');

-- =============================================================================
-- Dọn dẹp helper procedure
-- =============================================================================
DROP PROCEDURE IF EXISTS _CreateIndexSafe;

-- Báo cáo kết quả
SELECT 
    TABLE_NAME AS Bang,
    INDEX_NAME AS TenIndex,
    GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX SEPARATOR ', ') AS Columns
FROM information_schema.STATISTICS
WHERE TABLE_SCHEMA = 'HRPayrollDB'
  AND INDEX_NAME LIKE 'IX_%Perf%' 
   OR (TABLE_SCHEMA = 'HRPayrollDB' AND INDEX_NAME LIKE 'IX_%Dashboard%')
   OR (TABLE_SCHEMA = 'HRPayrollDB' AND INDEX_NAME LIKE 'IX_%FT%')
GROUP BY TABLE_NAME, INDEX_NAME
ORDER BY TABLE_NAME, INDEX_NAME;

SELECT '04_perf_indexes.sql hoàn tất — 6 index bổ sung cho Dashboard + Employee List + Attendance.' AS Status;
