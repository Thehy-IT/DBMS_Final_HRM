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
-- DBMS       : MySQL 8.0.46
-- GHI CHÚ   : MySQL 8.0 hỗ trợ CHECK constraints (enforced)
--              NHƯNG: CHECK không cho phép hàm non-deterministic
--              như CURDATE(), NOW(), TIMESTAMPDIFF() → dùng TRIGGER
--              ALTER TABLE ... ADD CONSTRAINT IF NOT EXISTS
--              KHÔNG được hỗ trợ trong MySQL 8.0 → dùng stored proc
--              hoặc kiểm tra trước khi ADD
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
-- LƯU Ý: MySQL 8.0 không hỗ trợ IF NOT EXISTS cho ALTER TABLE ADD CONSTRAINT
--        → Dùng procedure để kiểm tra trước khi thêm
-- ============================================================

-- Helper procedure để add constraint an toàn (tránh lỗi nếu đã tồn tại)
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

-- ── §2.5  NhanVien.SoDienThoai
-- Kiểm tra trong MySQL với REGEXP
-- LƯU Ý: CHECK constraints trong MySQL 8.0 KHÔNG được chứa hàm non-deterministic
--        REGEXP trong CHECK là OK vì nó deterministic
CALL _AddConstraintSafe(
    'NhanVien',
    'CK_NhanVien_SDT_Format',
    'ALTER TABLE NhanVien ADD CONSTRAINT CK_NhanVien_SDT_Format CHECK (
        SoDienThoai IS NULL
        OR SoDienThoai REGEXP ''^0[0-9]{9}$''
        OR SoDienThoai REGEXP ''^\\+84[0-9]{9}$''
    )'
);

-- ── §2.6  NhanVien.MaSoThue
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


-- ============================================================
-- §3  CHECK NGHIỆP VỤ NHÂN SỰ NÂNG CAO
-- LƯU Ý QUAN TRỌNG: MySQL 8.0 KHÔNG cho phép CURDATE(), NOW(),
--   TIMESTAMPDIFF() trong CHECK constraints vì chúng non-deterministic.
--   Các validate này được chuyển sang TRIGGER để enforcement.
-- ============================================================

-- ── §3.1  NhanVien: tuổi tối thiểu 18 và tối đa 70
-- CHUYỂN SANG TRIGGER: trg_NhanVien_CheckTuoi (tạo bên dưới)
-- Lý do: CURDATE() và TIMESTAMPDIFF() là non-deterministic → không dùng trong CHECK

-- ── §3.2  HopDong: Ngày bắt đầu hợp lệ (đã có trong CREATE TABLE)

-- ── §3.3  HopDong: Ngày ký không sau ngày bắt đầu (đã có)

-- ── §3.5  NghiPhep: Số ngày nghỉ tối đa 365 (đã có trong CREATE TABLE)

-- ── §3.6  NghiPhep: Ngày duyệt phải sau hoặc bằng ngày tạo
-- NOTE: NgayDuyet là DATETIME, NgayTao là DATETIME → so sánh OK (deterministic field comparison)
CALL _AddConstraintSafe(
    'NghiPhep',
    'CK_NghiPhep_NgayDuyetHopLe',
    'ALTER TABLE NghiPhep ADD CONSTRAINT CK_NghiPhep_NgayDuyetHopLe
        CHECK (NgayDuyet IS NULL OR NgayDuyet >= NgayTao)'
);

-- ── §3.7  ChamCong: Không chấm công tương lai
-- PHẢI DÙNG TRIGGER vì CURDATE() là non-deterministic trong CHECK
-- → Đã có trong trg_ChamCong_BeforeInsert và trg_ChamCong_BeforeUpdate

-- ── §3.8  ChamCong: Giờ vào hợp lệ (05:00 – 11:00)
-- TIME literal là deterministic → OK trong CHECK
CALL _AddConstraintSafe(
    'ChamCong',
    'CK_ChamCong_GioVaoHopLe',
    'ALTER TABLE ChamCong ADD CONSTRAINT CK_ChamCong_GioVaoHopLe CHECK (
        GioVao IS NULL
        OR (GioVao >= ''05:00:00'' AND GioVao <= ''11:00:00'')
    )'
);

-- ── §3.9  ChamCong: Giờ ra hợp lệ (12:00 – 23:59)
CALL _AddConstraintSafe(
    'ChamCong',
    'CK_ChamCong_GioRaHopLe',
    'ALTER TABLE ChamCong ADD CONSTRAINT CK_ChamCong_GioRaHopLe CHECK (
        GioRa IS NULL
        OR (GioRa >= ''12:00:00'' AND GioRa <= ''23:59:00'')
    )'
);

-- ── §3.10  KhauTru: Ngày phát sinh không ở tương lai
-- PHẢI DÙNG TRIGGER vì CURDATE() là non-deterministic trong CHECK
-- → Enforce qua trigger / stored procedure nhập liệu


-- ============================================================
-- §4  CHECK TÀI CHÍNH & PHÁP LÝ
-- ============================================================

-- ── §4.2  HopDong: Lương không thấp hơn mức tối thiểu vùng
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

-- ── §4.5  BangLuong: Ngày thanh toán phải sau ngày xác nhận
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


-- ============================================================
-- TRIGGER bổ sung cho các validation không thể dùng CHECK
-- ============================================================

-- Trigger kiểm tra tuổi NhanVien (18-70) khi INSERT/UPDATE
-- (thay thế CK_NhanVien_TuoiToiDa và CK_NV_NgaySinh vì CURDATE() non-deterministic)
DROP TRIGGER IF EXISTS trg_NhanVien_BeforeInsert_CheckTuoi;
DELIMITER $$
CREATE TRIGGER trg_NhanVien_BeforeInsert_CheckTuoi
BEFORE INSERT ON NhanVien
FOR EACH ROW
BEGIN
    DECLARE v_Tuoi INT;
    SET v_Tuoi = TIMESTAMPDIFF(YEAR, NEW.NgaySinh, CURDATE());
    IF v_Tuoi < 18 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'NhanVien: Tuổi phải >= 18. Vi phạm quy định lao động.';
    END IF;
    IF v_Tuoi > 70 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'NhanVien: Tuổi không được vượt quá 70.';
    END IF;
END$$
DELIMITER ;

DROP TRIGGER IF EXISTS trg_NhanVien_BeforeUpdate_CheckTuoi;
DELIMITER $$
CREATE TRIGGER trg_NhanVien_BeforeUpdate_CheckTuoi
BEFORE UPDATE ON NhanVien
FOR EACH ROW
BEGIN
    DECLARE v_Tuoi INT;
    IF NEW.NgaySinh <> OLD.NgaySinh THEN
        SET v_Tuoi = TIMESTAMPDIFF(YEAR, NEW.NgaySinh, CURDATE());
        IF v_Tuoi < 18 THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'NhanVien: Tuổi phải >= 18. Vi phạm quy định lao động.';
        END IF;
        IF v_Tuoi > 70 THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'NhanVien: Tuổi không được vượt quá 70.';
        END IF;
    END IF;
END$$
DELIMITER ;

SELECT '[OK] Triggers kiểm tra tuổi NhanVien đã tạo' AS Status;

-- Trigger kiểm tra KhauTru.NgayPhatSinh không tương lai
DROP TRIGGER IF EXISTS trg_KhauTru_BeforeInsert_NgayHopLe;
DELIMITER $$
CREATE TRIGGER trg_KhauTru_BeforeInsert_NgayHopLe
BEFORE INSERT ON KhauTru
FOR EACH ROW
BEGIN
    IF NEW.NgayPhatSinh > CURDATE() THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'KhauTru: NgayPhatSinh không được là ngày tương lai.';
    END IF;
END$$
DELIMITER ;

DROP TRIGGER IF EXISTS trg_KhauTru_BeforeUpdate_NgayHopLe;
DELIMITER $$
CREATE TRIGGER trg_KhauTru_BeforeUpdate_NgayHopLe
BEFORE UPDATE ON KhauTru
FOR EACH ROW
BEGIN
    IF NEW.NgayPhatSinh > CURDATE() THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'KhauTru: NgayPhatSinh không được là ngày tương lai.';
    END IF;
END$$
DELIMITER ;

SELECT '[OK] Triggers kiểm tra KhauTru.NgayPhatSinh đã tạo' AS Status;

-- Dọn dẹp helper procedure
DROP PROCEDURE IF EXISTS _AddConstraintSafe;


-- ============================================================
-- §5  COMPOSITE INDEX BỔ SUNG (HIỆU NĂNG TRUY VẤN)
-- Dùng CREATE INDEX IF NOT EXISTS (hỗ trợ trong MySQL 8.0)
-- ============================================================

-- ── §5.1  ChamCong: tra cứu theo tháng/năm
-- LƯU Ý: MySQL 8.0 hỗ trợ function-based index
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
    ON BangLuong (TrangThai, Nam, Thang);

-- ── §5.5  NghiPhep: tìm đơn đang chờ duyệt
CREATE INDEX IF NOT EXISTS IX_NghiPhep_Pending
    ON NghiPhep (TrangThai, NgayTao);

-- ── §5.6  NhanVienPhucLoi: tra cứu phúc lợi đang áp dụng
CREATE INDEX IF NOT EXISTS IX_NVPhucLoi_Active
    ON NhanVienPhucLoi (MaNV, IsActive);

-- ── §5.7  AuditLog_HopDong: range query theo thời gian
CREATE INDEX IF NOT EXISTS IX_AuditHD_MaNV_Time
    ON AuditLog_HopDong (MaNV, ThoiGianThayDoi);

-- ── §5.8  AuditLog_Luong: range query theo kỳ lương
CREATE INDEX IF NOT EXISTS IX_AuditLuong_NV_ThangNam
    ON AuditLog_Luong (MaNV, Nam, Thang);

-- ── §5.9  Indexes cho sp_TinhLuong
CREATE INDEX IF NOT EXISTS IX_NhanVien_TinhLuong_Active
    ON NhanVien (TrangThai, NgayVaoLam, NgayNghiViec);

CREATE INDEX IF NOT EXISTS IX_LuongCoBan_TinhLuong_Lookup
    ON LuongCoBan (MaNV, NgayHieuLuc, NgayHetHieuLuc);

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
    ON ChucVu (IsActive, CapBac);

-- ── §5.11 Indexes cho View & Báo cáo
CREATE INDEX IF NOT EXISTS IX_BangLuong_View_Rank
    ON BangLuong (Nam, Thang, ThuNhapThucLinh);

CREATE INDEX IF NOT EXISTS IX_ChamCong_View_ThongKe
    ON ChamCong (MaNV, NgayCham, TrangThai);

CREATE INDEX IF NOT EXISTS IX_ChiTietLuong_BaoCao_Loai
    ON ChiTietLuong (MaBL, LoaiMuc, TenMuc);

CREATE INDEX IF NOT EXISTS IX_BangLuong_Trend_Analysis
    ON BangLuong (Nam, Thang, TrangThai);

-- ── §5.12 Indexes cho Audit
CREATE INDEX IF NOT EXISTS IX_AuditHD_Time_Action
    ON AuditLog_HopDong (ThoiGianThayDoi, LoaiThayDoi);

CREATE INDEX IF NOT EXISTS IX_AuditLuong_NV_History
    ON AuditLog_Luong (MaNV, ThoiGianThayDoi);

CREATE INDEX IF NOT EXISTS IX_LuongCoBan_History_NV
    ON LuongCoBan (MaNV, NgayHieuLuc);

CREATE INDEX IF NOT EXISTS IX_KhauTru_Applied
    ON KhauTru (MaNV, TrangThai, NgayPhatSinh);


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
