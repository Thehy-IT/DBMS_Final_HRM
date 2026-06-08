-- ============================================================
-- FILE       : 03_indexes.sql
-- PROJECT    : Hệ Thống Quản Lý Nhân Sự & Tính Lương Tự Động
-- MỤC ĐÍCH   : Index chiến lược cho toàn bộ query pattern (MySQL)
--              §1  Covering index cho sp_TinhLuong
--              §2  Covering index cho sp_BaoCaoNhanSu
--              §3  Covering index cho View & báo cáo
--              §4  Covering index cho Audit & tra cứu
--              §5  Kiểm tra index usage (MySQL DMV equivalent)
-- DEPENDENCY : Chạy SAU 01_create_tables.sql + 02_constraints.sql
-- DBMS       : MySQL 8.0.46
-- GHI CHÚ   : MySQL KHÔNG hỗ trợ COLUMNSTORE INDEX (SQL Server only)
--              → Dùng InnoDB clustered index + covering index thay thế
--              → Cho analytics nặng, cân nhắc dùng MariaDB ColumnStore
--                hoặc kết nối với ClickHouse
--              LƯU Ý MySQL 8.0.46: CREATE INDEX IF NOT EXISTS OK
--              Index với ASC/DESC: MySQL 8.0 hỗ trợ descending index
--              nhưng INDEX trên GENERATED COLUMN cần từ khoá VIRTUAL/STORED
-- ============================================================

USE HRPayrollDB;

SELECT '[INFO] 03_indexes.sql — Xây dựng chiến lược index' AS Status;

-- ============================================================
-- §1  COVERING INDEX CHO sp_TinhLuong
-- ============================================================

-- ── §1.1  STEP A: NV active trong kỳ lương
-- Lưu ý: MySQL không hỗ trợ partial index WHERE clause
-- Index bao phủ toàn bảng, dùng TrangThai làm leading column
CREATE INDEX IF NOT EXISTS IX_NhanVien_TinhLuong_Active
    ON NhanVien (TrangThai, NgayVaoLam, NgayNghiViec);
SELECT '[OK] §1.1 IX_NhanVien_TinhLuong_Active' AS Status;

-- ── §1.2  STEP B: Lương cơ bản hiệu lực tại kỳ lương
CREATE INDEX IF NOT EXISTS IX_LuongCoBan_TinhLuong_Lookup
    ON LuongCoBan (MaNV, NgayHieuLuc, NgayHetHieuLuc);
SELECT '[OK] §1.2 IX_LuongCoBan_TinhLuong_Lookup' AS Status;

-- ── §1.3  STEP C: Đếm ngày công trong tháng theo loại
CREATE INDEX IF NOT EXISTS IX_ChamCong_TinhLuong_Period
    ON ChamCong (NgayCham, MaNV, TrangThai);
SELECT '[OK] §1.3 IX_ChamCong_TinhLuong_Period' AS Status;

-- ── §1.4  STEP E: Phụ cấp của NV
CREATE INDEX IF NOT EXISTS IX_NVPhucLoi_TinhLuong
    ON NhanVienPhucLoi (MaNV, IsActive, NgayApDung, NgayKetThuc);
SELECT '[OK] §1.4 IX_NVPhucLoi_TinhLuong' AS Status;

-- ── §1.5  STEP F: Khấu trừ phát sinh kỳ lương
-- Không có cột Nam/Thang riêng trong KhauTru → dùng NgayPhatSinh
CREATE INDEX IF NOT EXISTS IX_KhauTru_TinhLuong_Ky
    ON KhauTru (NgayPhatSinh, TrangThai, MaNV);
SELECT '[OK] §1.5 IX_KhauTru_TinhLuong_Ky' AS Status;

-- ── §1.6  STEP H: Kiểm tra BangLuong đã tồn tại chưa
CREATE INDEX IF NOT EXISTS IX_BangLuong_TinhLuong_Check
    ON BangLuong (Nam, Thang, MaNV, TrangThai);
SELECT '[OK] §1.6 IX_BangLuong_TinhLuong_Check' AS Status;

-- ── §1.7  LoaiPhucLoi: tra nhanh theo MaFL
CREATE INDEX IF NOT EXISTS IX_LoaiPhucLoi_Active_Include
    ON LoaiPhucLoi (MaFL, IsActive);
SELECT '[OK] §1.7 IX_LoaiPhucLoi_Active_Include' AS Status;

-- ── §1.8  LoaiHopDong: tra nhanh TiLeBHXH
CREATE INDEX IF NOT EXISTS IX_LoaiHopDong_BHXH
    ON LoaiHopDong (MaLoaiHD);
SELECT '[OK] §1.8 IX_LoaiHopDong_BHXH' AS Status;


-- ============================================================
-- §2  COVERING INDEX CHO sp_BaoCaoNhanSu
-- ============================================================

-- ── §2.1  Danh sách NV theo PhongBan + ChucVu
CREATE INDEX IF NOT EXISTS IX_NhanVien_BaoCao_PB_CV
    ON NhanVien (MaPB, TrangThai, MaCV);
SELECT '[OK] §2.1 IX_NhanVien_BaoCao_PB_CV' AS Status;

-- ── §2.2  HĐ sắp hết hạn trong N ngày tới
CREATE INDEX IF NOT EXISTS IX_HopDong_SapHetHan
    ON HopDong (TrangThai, NgayKetThuc);
SELECT '[OK] §2.2 IX_HopDong_SapHetHan' AS Status;

-- ── §2.3  Quỹ lương theo phòng ban: JOIN BangLuong-NhanVien
CREATE INDEX IF NOT EXISTS IX_BangLuong_BaoCao_QuyLuong
    ON BangLuong (Thang, Nam, TrangThai);
SELECT '[OK] §2.3 IX_BangLuong_BaoCao_QuyLuong' AS Status;

-- ── §2.4  Thống kê ngày nghỉ của NV trong năm
CREATE INDEX IF NOT EXISTS IX_NghiPhep_ThongKe_Nam
    ON NghiPhep (TrangThai, NgayBatDau, MaNV, MaLoaiNghi);
SELECT '[OK] §2.4 IX_NghiPhep_ThongKe_Nam' AS Status;

-- ── §2.5  PhongBan: JOIN lookup
CREATE INDEX IF NOT EXISTS IX_PhongBan_Active_Include
    ON PhongBan (IsActive, MaPB);
SELECT '[OK] §2.5 IX_PhongBan_Active_Include' AS Status;

-- ── §2.6  ChucVu: tra hệ số lương theo nhóm
-- LƯU Ý: Loại bỏ DESC trong index definition cho tương thích tối đa
--         MySQL 8.0 hỗ trợ descending index nhưng không cần thiết ở đây
CREATE INDEX IF NOT EXISTS IX_ChucVu_HeSo_CapBac
    ON ChucVu (IsActive, CapBac);
SELECT '[OK] §2.6 IX_ChucVu_HeSo_CapBac' AS Status;


-- ============================================================
-- §3  COVERING INDEX CHO VIEW & BÁO CÁO TỔNG HỢP
-- ============================================================

-- ── §3.1  vw_BangLuong: xếp hạng lương
-- LƯU Ý: MySQL 8.0 hỗ trợ descending index — giữ nguyên ASC cho ThuNhapThucLinh
--         vì GENERATED STORED COLUMN có thể index trực tiếp
CREATE INDEX IF NOT EXISTS IX_BangLuong_View_Rank
    ON BangLuong (Nam, Thang, ThuNhapThucLinh);
SELECT '[OK] §3.1 IX_BangLuong_View_Rank' AS Status;

-- ── §3.2  vw_TongHopChamCong: aggregate theo tháng/năm
CREATE INDEX IF NOT EXISTS IX_ChamCong_View_ThongKe
    ON ChamCong (MaNV, NgayCham, TrangThai);
SELECT '[OK] §3.2 IX_ChamCong_View_ThongKe' AS Status;

-- ── §3.3  Báo cáo thuế TNCN theo kỳ: ChiTietLuong
CREATE INDEX IF NOT EXISTS IX_ChiTietLuong_BaoCao_Loai
    ON ChiTietLuong (MaBL, LoaiMuc, TenMuc);
SELECT '[OK] §3.3 IX_ChiTietLuong_BaoCao_Loai' AS Status;

-- ── §3.4  So sánh quỹ lương nhiều tháng (trend analysis)
CREATE INDEX IF NOT EXISTS IX_BangLuong_Trend_Analysis
    ON BangLuong (Nam, Thang, TrangThai);
SELECT '[OK] §3.4 IX_BangLuong_Trend_Analysis' AS Status;


-- ============================================================
-- §4  COVERING INDEX CHO AUDIT & TRA CỨU LỊCH SỬ
-- ============================================================

-- ── §4.1  Audit HopDong: tra cứu ai thay đổi gì trong ngày
CREATE INDEX IF NOT EXISTS IX_AuditHD_Time_Action
    ON AuditLog_HopDong (ThoiGianThayDoi, LoaiThayDoi);
SELECT '[OK] §4.1 IX_AuditHD_Time_Action' AS Status;

-- ── §4.2  Audit Luong: lịch sử tăng lương của 1 NV
CREATE INDEX IF NOT EXISTS IX_AuditLuong_NV_History
    ON AuditLog_Luong (MaNV, ThoiGianThayDoi);
SELECT '[OK] §4.2 IX_AuditLuong_NV_History' AS Status;

-- ── §4.3  Lịch sử lương cơ bản của NV qua các năm
CREATE INDEX IF NOT EXISTS IX_LuongCoBan_History_NV
    ON LuongCoBan (MaNV, NgayHieuLuc);
SELECT '[OK] §4.3 IX_LuongCoBan_History_NV' AS Status;

-- ── §4.4  KhauTru đã áp dụng vào lương kỳ nào
CREATE INDEX IF NOT EXISTS IX_KhauTru_Applied
    ON KhauTru (MaNV, TrangThai, NgayPhatSinh);
SELECT '[OK] §4.4 IX_KhauTru_Applied' AS Status;


-- ============================================================
-- §5  KIỂM TRA INDEX USAGE (MySQL equivalent of DMV)
-- ============================================================

SELECT
    t.TABLE_NAME                             AS Bảng,
    s.INDEX_NAME                             AS TênIndex,
    s.INDEX_TYPE                             AS LoạiIndex,
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

-- ── §5.2  Thống kê tổng số index theo loại
SELECT
    INDEX_TYPE           AS LoạiIndex,
    COUNT(DISTINCT CONCAT(TABLE_NAME, '_', INDEX_NAME)) AS Số_Lượng
FROM information_schema.STATISTICS
WHERE TABLE_SCHEMA = 'HRPayrollDB'
GROUP BY INDEX_TYPE
ORDER BY Số_Lượng DESC;

SELECT '[DONE] 03_indexes.sql hoàn tất.' AS Status;
SELECT 'Chiến lược index đầy đủ cho sp_TinhLuong, báo cáo, analytics.' AS Info;
SELECT 'Bước tiếp theo: DML/seed_data.sql' AS NextStep;
