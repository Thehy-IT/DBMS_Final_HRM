-- ============================================================
-- FILE       : 03_indexes.sql
-- PROJECT    : Hệ Thống Quản Lý Nhân Sự & Tính Lương Tự Động
-- MỤC ĐÍCH   : Kiểm tra và xác nhận chiến lược index toàn bộ dự án
-- DEPENDENCY : Chạy SAU 01_create_tables.sql + 02_constraints.sql
-- DBMS       : MySQL 8.0.46
-- GHI CHÚ   : Tất cả index đã được tạo trong 02_constraints.sql (§5).
--              File này chỉ thực hiện kiểm tra và báo cáo index.
--              KHÔNG tạo thêm index để tránh lỗi Duplicate key name.
-- ============================================================

USE HRPayrollDB;

SELECT '[INFO] 03_indexes.sql — Kiểm tra chiến lược index' AS Status;

-- §1  KIỂM TRA INDEX ĐÃ TẠO (thay thế CREATE INDEX trùng lặp)

-- Helper procedure: tạo index nếu chưa tồn tại (safe create)
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

-- ── §1.1  NhanVien — Index tính lương
CALL _CreateIndexSafe('HRPayrollDB', 'NhanVien', 'IX_NhanVien_TinhLuong_Active',
    'CREATE INDEX IX_NhanVien_TinhLuong_Active ON NhanVien (TrangThai, NgayVaoLam, NgayNghiViec)');

-- ── §1.2  LuongCoBan — Lookup lương hiệu lực
CALL _CreateIndexSafe('HRPayrollDB', 'LuongCoBan', 'IX_LuongCoBan_TinhLuong_Lookup',
    'CREATE INDEX IX_LuongCoBan_TinhLuong_Lookup ON LuongCoBan (MaNV, NgayHieuLuc, NgayHetHieuLuc)');

-- ── §1.3  ChamCong — Tính lương theo kỳ
CALL _CreateIndexSafe('HRPayrollDB', 'ChamCong', 'IX_ChamCong_TinhLuong_Period',
    'CREATE INDEX IX_ChamCong_TinhLuong_Period ON ChamCong (NgayCham, MaNV, TrangThai)');

-- ── §1.4  NhanVienPhucLoi — Phụ cấp tính lương
CALL _CreateIndexSafe('HRPayrollDB', 'NhanVienPhucLoi', 'IX_NVPhucLoi_TinhLuong',
    'CREATE INDEX IX_NVPhucLoi_TinhLuong ON NhanVienPhucLoi (MaNV, IsActive, NgayApDung, NgayKetThuc)');

-- ── §1.5  KhauTru — Khấu trừ theo kỳ
CALL _CreateIndexSafe('HRPayrollDB', 'KhauTru', 'IX_KhauTru_TinhLuong_Ky',
    'CREATE INDEX IX_KhauTru_TinhLuong_Ky ON KhauTru (NgayPhatSinh, TrangThai, MaNV)');

-- ── §1.6  BangLuong — Kiểm tra đã tồn tại
CALL _CreateIndexSafe('HRPayrollDB', 'BangLuong', 'IX_BangLuong_TinhLuong_Check',
    'CREATE INDEX IX_BangLuong_TinhLuong_Check ON BangLuong (Nam, Thang, MaNV, TrangThai)');

-- ── §1.7  LoaiPhucLoi — Tra nhanh theo MaFL
CALL _CreateIndexSafe('HRPayrollDB', 'LoaiPhucLoi', 'IX_LoaiPhucLoi_Active_Include',
    'CREATE INDEX IX_LoaiPhucLoi_Active_Include ON LoaiPhucLoi (MaFL, IsActive)');

-- ── §1.8  LoaiHopDong — Tra BHXH
CALL _CreateIndexSafe('HRPayrollDB', 'LoaiHopDong', 'IX_LoaiHopDong_BHXH',
    'CREATE INDEX IX_LoaiHopDong_BHXH ON LoaiHopDong (MaLoaiHD)');

-- ── §2.1  NhanVien — Báo cáo PB/CV
CALL _CreateIndexSafe('HRPayrollDB', 'NhanVien', 'IX_NhanVien_BaoCao_PB_CV',
    'CREATE INDEX IX_NhanVien_BaoCao_PB_CV ON NhanVien (MaPB, TrangThai, MaCV)');

-- ── §2.2  HopDong — Sắp hết hạn
CALL _CreateIndexSafe('HRPayrollDB', 'HopDong', 'IX_HopDong_SapHetHan',
    'CREATE INDEX IX_HopDong_SapHetHan ON HopDong (TrangThai, NgayKetThuc)');

-- ── §2.3  BangLuong — Quỹ lương
CALL _CreateIndexSafe('HRPayrollDB', 'BangLuong', 'IX_BangLuong_BaoCao_QuyLuong',
    'CREATE INDEX IX_BangLuong_BaoCao_QuyLuong ON BangLuong (Thang, Nam, TrangThai)');

-- ── §2.4  NghiPhep — Thống kê năm
CALL _CreateIndexSafe('HRPayrollDB', 'NghiPhep', 'IX_NghiPhep_ThongKe_Nam',
    'CREATE INDEX IX_NghiPhep_ThongKe_Nam ON NghiPhep (TrangThai, NgayBatDau, MaNV, MaLoaiNghi)');

-- ── §2.5  PhongBan — Active lookup
CALL _CreateIndexSafe('HRPayrollDB', 'PhongBan', 'IX_PhongBan_Active_Include',
    'CREATE INDEX IX_PhongBan_Active_Include ON PhongBan (IsActive, MaPB)');

-- ── §2.6  ChucVu — Hệ số cấp bậc
CALL _CreateIndexSafe('HRPayrollDB', 'ChucVu', 'IX_ChucVu_HeSo_CapBac',
    'CREATE INDEX IX_ChucVu_HeSo_CapBac ON ChucVu (IsActive, CapBac)');

-- ── §3.1  BangLuong — Xếp hạng lương
CALL _CreateIndexSafe('HRPayrollDB', 'BangLuong', 'IX_BangLuong_View_Rank',
    'CREATE INDEX IX_BangLuong_View_Rank ON BangLuong (Nam, Thang, ThuNhapThucLinh)');

-- ── §3.2  ChamCong — Thống kê view
CALL _CreateIndexSafe('HRPayrollDB', 'ChamCong', 'IX_ChamCong_View_ThongKe',
    'CREATE INDEX IX_ChamCong_View_ThongKe ON ChamCong (MaNV, NgayCham, TrangThai)');

-- ── §3.3  ChiTietLuong — Báo cáo
CALL _CreateIndexSafe('HRPayrollDB', 'ChiTietLuong', 'IX_ChiTietLuong_BaoCao_Loai',
    'CREATE INDEX IX_ChiTietLuong_BaoCao_Loai ON ChiTietLuong (MaBL, LoaiMuc, TenMuc)');

-- ── §3.4  BangLuong — Trend analysis
CALL _CreateIndexSafe('HRPayrollDB', 'BangLuong', 'IX_BangLuong_Trend_Analysis',
    'CREATE INDEX IX_BangLuong_Trend_Analysis ON BangLuong (Nam, Thang, TrangThai)');

-- ── §4.1  AuditLog_HopDong — Tra cứu theo thời gian
CALL _CreateIndexSafe('HRPayrollDB', 'AuditLog_HopDong', 'IX_AuditHD_Time_Action',
    'CREATE INDEX IX_AuditHD_Time_Action ON AuditLog_HopDong (ThoiGianThayDoi, LoaiThayDoi)');

-- ── §4.2  AuditLog_Luong — Lịch sử lương NV
CALL _CreateIndexSafe('HRPayrollDB', 'AuditLog_Luong', 'IX_AuditLuong_NV_History',
    'CREATE INDEX IX_AuditLuong_NV_History ON AuditLog_Luong (MaNV, ThoiGianThayDoi)');

-- ── §4.3  LuongCoBan — Lịch sử lương
CALL _CreateIndexSafe('HRPayrollDB', 'LuongCoBan', 'IX_LuongCoBan_History_NV',
    'CREATE INDEX IX_LuongCoBan_History_NV ON LuongCoBan (MaNV, NgayHieuLuc)');

-- ── §4.4  KhauTru — Tra cứu áp dụng
CALL _CreateIndexSafe('HRPayrollDB', 'KhauTru', 'IX_KhauTru_Applied',
    'CREATE INDEX IX_KhauTru_Applied ON KhauTru (MaNV, TrangThai, NgayPhatSinh)');

-- ── §4.5  ChamCong — Function-based index cho tháng/năm
CALL _CreateIndexSafe('HRPayrollDB', 'ChamCong', 'IX_ChamCong_NV_ThangNam',
    'CREATE INDEX IX_ChamCong_NV_ThangNam ON ChamCong (MaNV, (YEAR(NgayCham)), (MONTH(NgayCham)))');

-- ── §4.6  HopDong — Active theo NV
CALL _CreateIndexSafe('HRPayrollDB', 'HopDong', 'IX_HopDong_NV_Active_Include',
    'CREATE INDEX IX_HopDong_NV_Active_Include ON HopDong (MaNV, TrangThai)');

-- ── §4.7  LuongCoBan — Lookup current
CALL _CreateIndexSafe('HRPayrollDB', 'LuongCoBan', 'IX_LuongCoBan_NV_Current_Include',
    'CREATE INDEX IX_LuongCoBan_NV_Current_Include ON LuongCoBan (MaNV, NgayHetHieuLuc, NgayHieuLuc)');

-- ── §4.8  BangLuong — Trạng thái + kỳ
CALL _CreateIndexSafe('HRPayrollDB', 'BangLuong', 'IX_BangLuong_TrangThai_Ky',
    'CREATE INDEX IX_BangLuong_TrangThai_Ky ON BangLuong (TrangThai, Nam, Thang)');

-- ── §4.9  NghiPhep — Pending
CALL _CreateIndexSafe('HRPayrollDB', 'NghiPhep', 'IX_NghiPhep_Pending',
    'CREATE INDEX IX_NghiPhep_Pending ON NghiPhep (TrangThai, NgayTao)');

-- ── §4.10  NhanVienPhucLoi — Active
CALL _CreateIndexSafe('HRPayrollDB', 'NhanVienPhucLoi', 'IX_NVPhucLoi_Active',
    'CREATE INDEX IX_NVPhucLoi_Active ON NhanVienPhucLoi (MaNV, IsActive)');

-- ── §4.11  AuditLog_HopDong — Composite time
CALL _CreateIndexSafe('HRPayrollDB', 'AuditLog_HopDong', 'IX_AuditHD_MaNV_Time',
    'CREATE INDEX IX_AuditHD_MaNV_Time ON AuditLog_HopDong (MaNV, ThoiGianThayDoi)');

-- ── §4.12  AuditLog_Luong — Kỳ lương NV
CALL _CreateIndexSafe('HRPayrollDB', 'AuditLog_Luong', 'IX_AuditLuong_NV_ThangNam',
    'CREATE INDEX IX_AuditLuong_NV_ThangNam ON AuditLog_Luong (MaNV, Nam, Thang)');

-- ── §4.13  NhanVien — Tính lương Active full
CALL _CreateIndexSafe('HRPayrollDB', 'NhanVien', 'IX_NhanVien_TinhLuong_Active',
    'CREATE INDEX IX_NhanVien_TinhLuong_Active ON NhanVien (TrangThai, NgayVaoLam, NgayNghiViec)');

-- Dọn dẹp
DROP PROCEDURE IF EXISTS _CreateIndexSafe;

-- §5  BÁO CÁO INDEX USAGE (MySQL equivalent of DMV)

SELECT
    t.TABLE_NAME                             AS Bang,
    s.INDEX_NAME                             AS TenIndex,
    s.INDEX_TYPE                             AS LoaiIndex,
    CASE s.NON_UNIQUE WHEN 0 THEN 'Y' ELSE 'N' END AS Unique_,
    GROUP_CONCAT(s.COLUMN_NAME
        ORDER BY s.SEQ_IN_INDEX
        SEPARATOR ', ')                      AS KeyColumns
FROM
    information_schema.TABLES t
    JOIN information_schema.STATISTICS s
        ON t.TABLE_SCHEMA = s.TABLE_SCHEMA
        AND t.TABLE_NAME  = s.TABLE_NAME
WHERE
    t.TABLE_SCHEMA = 'HRPayrollDB'
    AND t.TABLE_TYPE = 'BASE TABLE'
GROUP BY
    t.TABLE_NAME, s.INDEX_NAME, s.INDEX_TYPE, s.NON_UNIQUE
ORDER BY
    t.TABLE_NAME, s.INDEX_NAME;

-- Thống kê tổng số index theo loại
SELECT
    INDEX_TYPE           AS LoaiIndex,
    COUNT(DISTINCT CONCAT(TABLE_NAME, '_', INDEX_NAME)) AS So_Luong
FROM information_schema.STATISTICS
WHERE TABLE_SCHEMA = 'HRPayrollDB'
GROUP BY INDEX_TYPE
ORDER BY So_Luong DESC;

SELECT '[DONE] 03_indexes.sql hoàn tất.' AS Status;
SELECT 'Tất cả index được tạo an toàn (IF NOT EXISTS logic via _CreateIndexSafe).' AS Info;