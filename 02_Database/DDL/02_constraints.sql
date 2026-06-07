-- ============================================================
-- FILE       : 02_constraints.sql
-- PROJECT    : Hệ Thống Quản Lý Nhân Sự & Tính Lương Tự Động
-- MỤC ĐÍCH   : Bổ sung ràng buộc & index cho MySQL
--              §1  Unique Index có điều kiện (emulated trong MySQL)
--              §2  CHECK định dạng mã
--              §3  CHECK nghiệp vụ nâng cao
--              §4  CHECK tài chính & pháp lý
--              §5  Composite Index hiệu năng
--              §6  Kiểm tra & báo cáo tổng thể
-- DEPENDENCY : Chạy SAU 01_create_tables.sql
-- DBMS       : MySQL 8.0+
-- GHI CHÚ   : MySQL 8.0 hỗ trợ CHECK constraints (enforced)
--              Filtered/partial index không được hỗ trợ trực tiếp
--              → Dùng trigger để enforce business rules tương đương
-- ============================================================

USE HRPayrollDB;

SELECT '[INFO] 02_constraints.sql — bắt đầu áp dụng ràng buộc' AS Status;

-- ============================================================
-- §1  UNIQUE INDEX (thay thế Filtered Unique Index của SQL Server)
-- Ghi chú: MySQL không hỗ trợ partial/filtered index
-- Các business rule sau được enforce qua Trigger
-- ============================================================

-- ── §1.1  BR-05: Mỗi nhân viên chỉ có 1 hợp đồng đang hiệu lực
-- Được kiểm soát bởi trigger trg_HopDong_CheckOneActive (xem Triggers/)

-- ── §1.2  Mỗi nhân viên chỉ có 1 mức lương cơ bản đang áp dụng
-- Được kiểm soát bởi trigger trg_LuongCoBan_CheckOneCurrent

-- ── §1.3  BangLuong đã LOCK không được tạo lại
-- UNIQUE (MaNV, Thang, Nam) đã tạo trong 01_create_tables.sql

-- ── §1.4  Cùng nhân viên không có 2 đơn nghỉ APPROVED trùng ngày
-- Được kiểm soát bởi trigger trg_NghiPhep_CheckOverlap


-- ============================================================
-- §2  CHECK ĐỊNH DẠNG MÃ (FORMAT VALIDATION)
-- Đã được thêm trong 01_create_tables.sql bằng CHECK + REGEXP
-- Bổ sung các constraint chưa có:
-- ============================================================

-- ── §2.5  NhanVien.SoDienThoai
-- Kiểm tra trong MySQL với REGEXP
ALTER TABLE NhanVien
    ADD CONSTRAINT IF NOT EXISTS CK_NhanVien_SDT_Format
        CHECK (
            SoDienThoai IS NULL
            OR SoDienThoai REGEXP '^0[0-9]{9}$'
            OR SoDienThoai REGEXP '^\\+84[0-9]{9}$'
        );

-- ── §2.6  NhanVien.MaSoThue
ALTER TABLE NhanVien
    ADD CONSTRAINT IF NOT EXISTS CK_NhanVien_MST_Format
        CHECK (
            MaSoThue IS NULL
            OR (
                CHAR_LENGTH(MaSoThue) IN (10, 13)
                AND MaSoThue REGEXP '^[0-9-]+$'
            )
        );


-- ============================================================
-- §3  CHECK NGHIỆP VỤ NHÂN SỰ NÂNG CAO
-- ============================================================

-- ── §3.1  NhanVien: tuổi không vượt quá 70
ALTER TABLE NhanVien
    ADD CONSTRAINT IF NOT EXISTS CK_NhanVien_TuoiToiDa
        CHECK (TIMESTAMPDIFF(YEAR, NgaySinh, CURDATE()) <= 70);

-- ── §3.1b NhanVien: tuổi tối thiểu 18
ALTER TABLE NhanVien
    ADD CONSTRAINT IF NOT EXISTS CK_NV_NgaySinh
        CHECK (NgaySinh <= DATE_SUB(CURDATE(), INTERVAL 18 YEAR));

-- ── §3.2  HopDong: Ngày bắt đầu hợp lệ (đã có trong CREATE TABLE)

-- ── §3.3  HopDong: Ngày ký không sau ngày bắt đầu (đã có)

-- ── §3.5  NghiPhep: Số ngày nghỉ tối đa 365 (đã có trong CREATE TABLE)

-- ── §3.6  NghiPhep: Ngày duyệt phải sau hoặc bằng ngày tạo
ALTER TABLE NghiPhep
    ADD CONSTRAINT IF NOT EXISTS CK_NghiPhep_NgayDuyetHopLe
        CHECK (NgayDuyet IS NULL OR NgayDuyet >= NgayTao);

-- ── §3.7  ChamCong: Không chấm công tương lai
ALTER TABLE ChamCong
    ADD CONSTRAINT IF NOT EXISTS CK_ChamCong_KhongTuongLai
        CHECK (NgayCham <= CURDATE());

-- ── §3.8  ChamCong: Giờ vào hợp lệ (05:00 – 11:00)
ALTER TABLE ChamCong
    ADD CONSTRAINT IF NOT EXISTS CK_ChamCong_GioVaoHopLe
        CHECK (
            GioVao IS NULL
            OR (GioVao >= '05:00:00' AND GioVao <= '11:00:00')
        );

-- ── §3.9  ChamCong: Giờ ra hợp lệ (12:00 – 23:59)
ALTER TABLE ChamCong
    ADD CONSTRAINT IF NOT EXISTS CK_ChamCong_GioRaHopLe
        CHECK (
            GioRa IS NULL
            OR (GioRa >= '12:00:00' AND GioRa <= '23:59:00')
        );

-- ── §3.10  KhauTru: Ngày phát sinh không ở tương lai
ALTER TABLE KhauTru
    ADD CONSTRAINT IF NOT EXISTS CK_KhauTru_NgayPhatSinhHopLe
        CHECK (NgayPhatSinh <= CURDATE());


-- ============================================================
-- §4  CHECK TÀI CHÍNH & PHÁP LÝ
-- ============================================================

-- ── §4.2  HopDong: Lương không thấp hơn mức tối thiểu vùng
ALTER TABLE HopDong
    ADD CONSTRAINT IF NOT EXISTS CK_HopDong_LuongToiThieuVung
        CHECK (
            (VungLuong = 1 AND LuongCoBan >= 4960000) OR
            (VungLuong = 2 AND LuongCoBan >= 4410000) OR
            (VungLuong = 3 AND LuongCoBan >= 3860000) OR
            (VungLuong = 4 AND LuongCoBan >= 3450000)
        );

-- ── §4.5  BangLuong: Ngày thanh toán phải sau ngày xác nhận
ALTER TABLE BangLuong
    ADD CONSTRAINT IF NOT EXISTS CK_BangLuong_NgayThanhToanHopLe
        CHECK (
            NgayThanhToan IS NULL
            OR NgayXacNhan IS NULL
            OR NgayThanhToan >= DATE(NgayXacNhan)
        );


-- ============================================================
-- §5  COMPOSITE INDEX BỔ SUNG (HIỆU NĂNG TRUY VẤN)
-- ============================================================

-- ── §5.1  ChamCong: tra cứu theo tháng/năm
CREATE INDEX IF NOT EXISTS IX_ChamCong_NV_ThangNam
    ON ChamCong (MaNV, YEAR(NgayCham), MONTH(NgayCham));

-- ── §5.2  HopDong: tìm HĐ hiệu lực của NV nhanh
CREATE INDEX IF NOT EXISTS IX_HopDong_NV_Active_Include
    ON HopDong (MaNV, TrangThai);

-- ── §5.3  LuongCoBan: lookup lương hiện tại theo NV
CREATE INDEX IF NOT EXISTS IX_LuongCoBan_NV_Current_Include
    ON LuongCoBan (MaNV, NgayHetHieuLuc, NgayHieuLuc);

-- ── §5.4  BangLuong: tìm nhanh kỳ lương theo trạng thái
CREATE INDEX IF NOT EXISTS IX_BangLuong_TrangThai_Ky
    ON BangLuong (TrangThai, Nam DESC, Thang DESC);

-- ── §5.5  NghiPhep: tìm đơn đang chờ duyệt
CREATE INDEX IF NOT EXISTS IX_NghiPhep_Pending
    ON NghiPhep (TrangThai, NgayTao DESC);

-- ── §5.6  NhanVienPhucLoi: tra cứu phúc lợi đang áp dụng
CREATE INDEX IF NOT EXISTS IX_NVPhucLoi_Active
    ON NhanVienPhucLoi (MaNV, IsActive);

-- ── §5.7  AuditLog_HopDong: range query theo thời gian
CREATE INDEX IF NOT EXISTS IX_AuditHD_MaNV_Time
    ON AuditLog_HopDong (MaNV, ThoiGianThayDoi DESC);

-- ── §5.8  AuditLog_Luong: range query theo kỳ lương
CREATE INDEX IF NOT EXISTS IX_AuditLuong_NV_ThangNam
    ON AuditLog_Luong (MaNV, Nam DESC, Thang DESC);

-- ── §5.9  Indexes cho sp_TinhLuong
CREATE INDEX IF NOT EXISTS IX_NhanVien_TinhLuong_Active
    ON NhanVien (TrangThai, NgayVaoLam, NgayNghiViec);

CREATE INDEX IF NOT EXISTS IX_LuongCoBan_TinhLuong_Lookup
    ON LuongCoBan (MaNV, NgayHieuLuc DESC, NgayHetHieuLuc);

CREATE INDEX IF NOT EXISTS IX_ChamCong_TinhLuong_Period
    ON ChamCong (NgayCham, MaNV, TrangThai);

CREATE INDEX IF NOT EXISTS IX_NVPhucLoi_TinhLuong
    ON NhanVienPhucLoi (MaNV, IsActive, NgayApDung, NgayKetThuc);

CREATE INDEX IF NOT EXISTS IX_KhauTru_TinhLuong_Ky
    ON KhauTru (NgayPhatSinh, TrangThai, MaNV);

CREATE INDEX IF NOT EXISTS IX_BangLuong_TinhLuong_Check
    ON BangLuong (Nam, Thang, MaNV, TrangThai);

-- ── §5.10 Indexes cho sp_BaoCaoNhanSu
CREATE INDEX IF NOT EXISTS IX_NhanVien_BaoCao_PB_CV
    ON NhanVien (MaPB, TrangThai, MaCV);

CREATE INDEX IF NOT EXISTS IX_HopDong_SapHetHan
    ON HopDong (TrangThai, NgayKetThuc);

CREATE INDEX IF NOT EXISTS IX_BangLuong_BaoCao_QuyLuong
    ON BangLuong (Thang, Nam, TrangThai);

CREATE INDEX IF NOT EXISTS IX_NghiPhep_ThongKe_Nam
    ON NghiPhep (TrangThai, NgayBatDau, MaNV, MaLoaiNghi);

CREATE INDEX IF NOT EXISTS IX_PhongBan_Active_Include
    ON PhongBan (IsActive, MaPB);

CREATE INDEX IF NOT EXISTS IX_ChucVu_HeSo_CapBac
    ON ChucVu (IsActive, CapBac DESC);

-- ── §5.11 Indexes cho View & Báo cáo
CREATE INDEX IF NOT EXISTS IX_BangLuong_View_Rank
    ON BangLuong (Nam DESC, Thang DESC, ThuNhapThucLinh DESC);

CREATE INDEX IF NOT EXISTS IX_ChamCong_View_ThongKe
    ON ChamCong (MaNV, NgayCham DESC, TrangThai);

CREATE INDEX IF NOT EXISTS IX_ChiTietLuong_BaoCao_Loai
    ON ChiTietLuong (MaBL, LoaiMuc, TenMuc);

CREATE INDEX IF NOT EXISTS IX_BangLuong_Trend_Analysis
    ON BangLuong (Nam ASC, Thang ASC, TrangThai);

-- ── §5.12 Indexes cho Audit
CREATE INDEX IF NOT EXISTS IX_AuditHD_Time_Action
    ON AuditLog_HopDong (ThoiGianThayDoi DESC, LoaiThayDoi);

CREATE INDEX IF NOT EXISTS IX_AuditLuong_NV_History
    ON AuditLog_Luong (MaNV, ThoiGianThayDoi DESC);

CREATE INDEX IF NOT EXISTS IX_LuongCoBan_History_NV
    ON LuongCoBan (MaNV, NgayHieuLuc DESC);

CREATE INDEX IF NOT EXISTS IX_KhauTru_Applied
    ON KhauTru (MaNV, TrangThai, NgayPhatSinh DESC);


-- ============================================================
-- §6  BÁO CÁO TỔNG HỢP
-- ============================================================

-- ── 6.1  Tất cả CHECK constraints
SELECT
    TABLE_NAME       AS Bảng,
    CONSTRAINT_NAME  AS TênConstraint,
    CHECK_CLAUSE     AS ĐịnhNghĩa,
    'ENABLED'        AS TrạngThái
FROM information_schema.CHECK_CONSTRAINTS
WHERE CONSTRAINT_SCHEMA = 'HRPayrollDB'
ORDER BY TABLE_NAME, CONSTRAINT_NAME;

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

SELECT '[DONE] 02_constraints.sql hoàn tất.' AS Status;
SELECT 'Sẵn sàng cho bước tiếp: 03_indexes.sql → DML/seed_data.sql → StoredProcedures/' AS NextStep;
