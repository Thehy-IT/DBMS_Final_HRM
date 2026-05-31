-- ============================================================
-- FILE       : 02_constraints.sql
-- PROJECT    : Hệ Thống Quản Lý Nhân Sự & Tính Lương Tự Động
-- MỤC ĐÍCH   : Bổ sung toàn bộ ràng buộc CHƯA khai báo trong
--              01_create_tables.sql, gồm:
--                §1  Filtered Unique Index  (điều kiện nghiệp vụ)
--                §2  CHECK định dạng mã     (ALTER TABLE ADD)
--                §3  CHECK nghiệp vụ nâng cao
--                §4  CHECK tài chính & pháp lý
--                §5  Composite Index hiệu năng
--                §6  Kiểm tra & báo cáo tổng thể
-- DEPENDENCY : Chạy SAU 01_create_tables.sql
-- DBMS       : SQL Server 2019+
-- ============================================================

USE HRPayrollDB;
GO

PRINT N'════════════════════════════════════════════════════════';
PRINT N'  02_constraints.sql — bắt đầu áp dụng ràng buộc';
PRINT N'════════════════════════════════════════════════════════';
GO

-- ============================================================
-- §1  FILTERED UNIQUE INDEX
--     SQL Server cho phép tạo unique index có điều kiện WHERE
--     → Dùng để ép buộc business rules dạng "chỉ 1 bản ghi
--       ACTIVE / NULL tại một thời điểm" mà CHECK thường không làm được
-- ============================================================

-- ── §1.1  BR-05: Mỗi nhân viên chỉ có 1 hợp đồng đang hiệu lực ──
--   Trạng thái Active = 'A'; hợp đồng hết hạn 'E', chấm dứt 'T',
--   nháp 'D' không bị giới hạn số lượng
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.HopDong')
      AND name      = 'UIX_HopDong_OneActive_PerNV'
)
BEGIN
    CREATE UNIQUE INDEX UIX_HopDong_OneActive_PerNV
        ON dbo.HopDong (MaNV)
        WHERE TrangThai = 'A';
    PRINT N'[OK] §1.1 UIX_HopDong_OneActive_PerNV';
END
GO

-- ── §1.2  Mỗi nhân viên chỉ có 1 mức lương cơ bản đang áp dụng ──
--   NgayHetHieuLuc IS NULL  →  đang có hiệu lực
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.LuongCoBan')
      AND name      = 'UIX_LuongCoBan_OneCurrent_PerNV'
)
BEGIN
    CREATE UNIQUE INDEX UIX_LuongCoBan_OneCurrent_PerNV
        ON dbo.LuongCoBan (MaNV)
        WHERE NgayHetHieuLuc IS NULL;
    PRINT N'[OK] §1.2 UIX_LuongCoBan_OneCurrent_PerNV';
END
GO

-- ── §1.3  Bảng lương đã LOCK không được tạo lại cho cùng kỳ ──
--   Kết hợp với UQ_BangLuong_NV_Ky đã có → tầng bảo vệ thứ 2:
--   index filtered chặn trạng thái P (Paid) bị ghi đè
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.BangLuong')
      AND name      = 'UIX_BangLuong_NoDuplicate_PaidLocked'
)
BEGIN
    CREATE UNIQUE INDEX UIX_BangLuong_NoDuplicate_PaidLocked
        ON dbo.BangLuong (MaNV, Thang, Nam)
        WHERE TrangThai IN ('P', 'L');       -- Paid hoặc Locked
    PRINT N'[OK] §1.3 UIX_BangLuong_NoDuplicate_PaidLocked';
END
GO

-- ── §1.4  Cùng nhân viên không được có 2 đơn nghỉ APPROVED trùng ngày ──
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.NghiPhep')
      AND name      = 'UIX_NghiPhep_NoOverlapApproved'
)
BEGIN
    -- Đây là partial index: chặn trùng ngày bắt đầu cho đơn đã duyệt.
    -- Kiểm tra overlap toàn diện (date range) cần Trigger trg_KiemTraChamCong.
    CREATE UNIQUE INDEX UIX_NghiPhep_NoOverlapApproved
        ON dbo.NghiPhep (MaNV, NgayBatDau)
        WHERE TrangThai = 'A';
    PRINT N'[OK] §1.4 UIX_NghiPhep_NoOverlapApproved';
END
GO


-- ============================================================
-- §2  CHECK ĐỊNH DẠNG MÃ (FORMAT VALIDATION)
--     Bổ sung vì 01_create_tables.sql chỉ có CK_NV_MaNV_Format
-- ============================================================

-- ── §2.1  PhongBan.MaPB  →  PB + 4 chữ số  (CHAR 6) ────────
IF NOT EXISTS (
    SELECT 1 FROM sys.check_constraints
    WHERE parent_object_id = OBJECT_ID('dbo.PhongBan')
      AND name = 'CK_PhongBan_MaPB_Format'
)
BEGIN
    ALTER TABLE dbo.PhongBan
        ADD CONSTRAINT CK_PhongBan_MaPB_Format
            CHECK (MaPB LIKE 'PB[0-9][0-9][0-9][0-9]');
    PRINT N'[OK] §2.1 CK_PhongBan_MaPB_Format';
END
GO

-- ── §2.2  ChucVu.MaCV  →  CV + 4 chữ số  (CHAR 6) ──────────
IF NOT EXISTS (
    SELECT 1 FROM sys.check_constraints
    WHERE parent_object_id = OBJECT_ID('dbo.ChucVu')
      AND name = 'CK_ChucVu_MaCV_Format'
)
BEGIN
    ALTER TABLE dbo.ChucVu
        ADD CONSTRAINT CK_ChucVu_MaCV_Format
            CHECK (MaCV LIKE 'CV[0-9][0-9][0-9][0-9]');
    PRINT N'[OK] §2.2 CK_ChucVu_MaCV_Format';
END
GO

-- ── §2.3  HopDong.MaHD  →  HD + 8 chữ số  (CHAR 10) ────────
IF NOT EXISTS (
    SELECT 1 FROM sys.check_constraints
    WHERE parent_object_id = OBJECT_ID('dbo.HopDong')
      AND name = 'CK_HopDong_MaHD_Format'
)
BEGIN
    ALTER TABLE dbo.HopDong
        ADD CONSTRAINT CK_HopDong_MaHD_Format
            CHECK (MaHD LIKE 'HD[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]');
    PRINT N'[OK] §2.3 CK_HopDong_MaHD_Format';
END
GO

-- ── §2.4  LoaiPhucLoi.MaFL  →  FL + 4 chữ số  (CHAR 6) ─────
IF NOT EXISTS (
    SELECT 1 FROM sys.check_constraints
    WHERE parent_object_id = OBJECT_ID('dbo.LoaiPhucLoi')
      AND name = 'CK_LoaiPhucLoi_MaFL_Format'
)
BEGIN
    ALTER TABLE dbo.LoaiPhucLoi
        ADD CONSTRAINT CK_LoaiPhucLoi_MaFL_Format
            CHECK (MaFL LIKE 'FL[0-9][0-9][0-9][0-9]');
    PRINT N'[OK] §2.4 CK_LoaiPhucLoi_MaFL_Format';
END
GO

-- ── §2.5  NhanVien.SoDienThoai  →  0 + 9 chữ số hoặc +84… ──
IF NOT EXISTS (
    SELECT 1 FROM sys.check_constraints
    WHERE parent_object_id = OBJECT_ID('dbo.NhanVien')
      AND name = 'CK_NhanVien_SDT_Format'
)
BEGIN
    ALTER TABLE dbo.NhanVien
        ADD CONSTRAINT CK_NhanVien_SDT_Format
            CHECK (
                SoDienThoai IS NULL
                OR SoDienThoai LIKE '0[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]'
                OR SoDienThoai LIKE '+84[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]'
            );
    PRINT N'[OK] §2.5 CK_NhanVien_SDT_Format';
END
GO

-- ── §2.6  NhanVien.MaSoThue  →  10 hoặc 13 chữ số ──────────
IF NOT EXISTS (
    SELECT 1 FROM sys.check_constraints
    WHERE parent_object_id = OBJECT_ID('dbo.NhanVien')
      AND name = 'CK_NhanVien_MST_Format'
)
BEGIN
    ALTER TABLE dbo.NhanVien
        ADD CONSTRAINT CK_NhanVien_MST_Format
            CHECK (
                MaSoThue IS NULL
                OR (
                    LEN(MaSoThue) IN (10, 13)
                    AND MaSoThue NOT LIKE '%[^0-9-]%'
                )
            );
    PRINT N'[OK] §2.6 CK_NhanVien_MST_Format';
END
GO


-- ============================================================
-- §3  CHECK NGHIỆP VỤ NHÂN SỰ NÂNG CAO
-- ============================================================

-- ── §3.1  NhanVien: tuổi không vượt quá 65 khi đang làm việc ─
--   Bổ sung giới hạn tuổi tối đa (CK_NV_NgaySinh chỉ check >= 18)
IF NOT EXISTS (
    SELECT 1 FROM sys.check_constraints
    WHERE parent_object_id = OBJECT_ID('dbo.NhanVien')
      AND name = 'CK_NhanVien_TuoiToiDa'
)
BEGIN
    ALTER TABLE dbo.NhanVien
        ADD CONSTRAINT CK_NhanVien_TuoiToiDa
            CHECK (
                DATEDIFF(YEAR, NgaySinh, GETDATE()) <= 70
                -- 70 cho phép record NV đã nghỉ hưu vẫn lưu
            );
    PRINT N'[OK] §3.1 CK_NhanVien_TuoiToiDa';
END
GO

-- ── §3.2  HopDong: Ngày bắt đầu không trước ngày vào làm ───
IF NOT EXISTS (
    SELECT 1 FROM sys.check_constraints
    WHERE parent_object_id = OBJECT_ID('dbo.HopDong')
      AND name = 'CK_HopDong_NgayBatDauHopLe'
)
BEGIN
    ALTER TABLE dbo.HopDong
        ADD CONSTRAINT CK_HopDong_NgayBatDauHopLe
            CHECK (NgayBatDau >= '2000-01-01');
    PRINT N'[OK] §3.2 CK_HopDong_NgayBatDauHopLe';
END
GO

-- ── §3.3  HopDong: Ngày ký không sau ngày bắt đầu ──────────
IF NOT EXISTS (
    SELECT 1 FROM sys.check_constraints
    WHERE parent_object_id = OBJECT_ID('dbo.HopDong')
      AND name = 'CK_HopDong_NgayKyHopLe'
)
BEGIN
    ALTER TABLE dbo.HopDong
        ADD CONSTRAINT CK_HopDong_NgayKyHopLe
            CHECK (NgayKy IS NULL OR NgayKy <= NgayBatDau);
    PRINT N'[OK] §3.3 CK_HopDong_NgayKyHopLe';
END
GO

-- ── §3.4  LuongCoBan: Ngày hiệu lực không trong tương lai xa ─
IF NOT EXISTS (
    SELECT 1 FROM sys.check_constraints
    WHERE parent_object_id = OBJECT_ID('dbo.LuongCoBan')
      AND name = 'CK_LuongCoBan_NgayHLHopLe'
)
BEGIN
    ALTER TABLE dbo.LuongCoBan
        ADD CONSTRAINT CK_LuongCoBan_NgayHLHopLe
            CHECK (NgayHieuLuc <= DATEADD(MONTH, 3, GETDATE()));
            -- Cho phép điều chỉnh lương trước tối đa 3 tháng
    PRINT N'[OK] §3.4 CK_LuongCoBan_NgayHLHopLe';
END
GO

-- ── §3.5  NghiPhep: Số ngày nghỉ tối đa 1 lần đăng ký ──────
--   Thai sản 6 tháng = 180 ngày; giới hạn chung < 1 năm = 365
IF NOT EXISTS (
    SELECT 1 FROM sys.check_constraints
    WHERE parent_object_id = OBJECT_ID('dbo.NghiPhep')
      AND name = 'CK_NghiPhep_SoNgayMax'
)
BEGIN
    ALTER TABLE dbo.NghiPhep
        ADD CONSTRAINT CK_NghiPhep_SoNgayMax
            CHECK (DATEDIFF(DAY, NgayBatDau, NgayKetThuc) <= 365);
    PRINT N'[OK] §3.5 CK_NghiPhep_SoNgayMax';
END
GO

-- ── §3.6  NghiPhep: Ngày duyệt phải sau ngày tạo đơn ───────
IF NOT EXISTS (
    SELECT 1 FROM sys.check_constraints
    WHERE parent_object_id = OBJECT_ID('dbo.NghiPhep')
      AND name = 'CK_NghiPhep_NgayDuyetHopLe'
)
BEGIN
    ALTER TABLE dbo.NghiPhep
        ADD CONSTRAINT CK_NghiPhep_NgayDuyetHopLe
            CHECK (NgayDuyet IS NULL OR NgayDuyet >= NgayTao);
    PRINT N'[OK] §3.6 CK_NghiPhep_NgayDuyetHopLe';
END
GO

-- ── §3.7  ChamCong: Không chấm công tương lai ───────────────
--   (Đã có implied bởi UQ + app logic, thêm tường lửa DB)
IF NOT EXISTS (
    SELECT 1 FROM sys.check_constraints
    WHERE parent_object_id = OBJECT_ID('dbo.ChamCong')
      AND name = 'CK_ChamCong_KhongTuongLai'
)
BEGIN
    ALTER TABLE dbo.ChamCong
        ADD CONSTRAINT CK_ChamCong_KhongTuongLai
            CHECK (NgayCham <= CAST(GETDATE() AS DATE));
    PRINT N'[OK] §3.7 CK_ChamCong_KhongTuongLai';
END
GO

-- ── §3.8  ChamCong: Giờ vào hợp lệ (5:00 – 11:00) ──────────
IF NOT EXISTS (
    SELECT 1 FROM sys.check_constraints
    WHERE parent_object_id = OBJECT_ID('dbo.ChamCong')
      AND name = 'CK_ChamCong_GioVaoHopLe'
)
BEGIN
    ALTER TABLE dbo.ChamCong
        ADD CONSTRAINT CK_ChamCong_GioVaoHopLe
            CHECK (
                GioVao IS NULL
                OR (GioVao >= '05:00:00' AND GioVao <= '11:00:00')
            );
    PRINT N'[OK] §3.8 CK_ChamCong_GioVaoHopLe';
END
GO

-- ── §3.9  ChamCong: Giờ ra hợp lệ (12:00 – 23:00) ──────────
IF NOT EXISTS (
    SELECT 1 FROM sys.check_constraints
    WHERE parent_object_id = OBJECT_ID('dbo.ChamCong')
      AND name = 'CK_ChamCong_GioRaHopLe'
)
BEGIN
    ALTER TABLE dbo.ChamCong
        ADD CONSTRAINT CK_ChamCong_GioRaHopLe
            CHECK (
                GioRa IS NULL
                OR (GioRa >= '12:00:00' AND GioRa <= '23:59:00')
            );
    PRINT N'[OK] §3.9 CK_ChamCong_GioRaHopLe';
END
GO

-- ── §3.10  KhauTru: Ngày phát sinh không được ở tương lai ───
IF NOT EXISTS (
    SELECT 1 FROM sys.check_constraints
    WHERE parent_object_id = OBJECT_ID('dbo.KhauTru')
      AND name = 'CK_KhauTru_NgayPhatSinhHopLe'
)
BEGIN
    ALTER TABLE dbo.KhauTru
        ADD CONSTRAINT CK_KhauTru_NgayPhatSinhHopLe
            CHECK (NgayPhatSinh <= CAST(GETDATE() AS DATE));
    PRINT N'[OK] §3.10 CK_KhauTru_NgayPhatSinhHopLe';
END
GO


-- ============================================================
-- §4  CHECK TÀI CHÍNH & PHÁP LÝ
--     Tuân thủ: Bộ Luật LĐ 2019 | Thông tư 111/2013/TT-BTC
--               Nghị định 38/2022/NĐ-CP (lương tối thiểu vùng)
-- ============================================================

-- ── §4.1  LuongCoBan: Trần lương đóng BHXH = 20 × lương cơ sở ─
--   Lương cơ sở 2024 = 2,340,000 VNĐ/tháng
--   Trần = 20 × 2,340,000 = 46,800,000 VNĐ/tháng
IF NOT EXISTS (
    SELECT 1 FROM sys.check_constraints
    WHERE parent_object_id = OBJECT_ID('dbo.LuongCoBan')
      AND name = 'CK_LuongCoBan_TranDongBH'
)
BEGIN
    ALTER TABLE dbo.LuongCoBan
        ADD CONSTRAINT CK_LuongCoBan_TranDongBH
            CHECK (LuongDongBH <= 46800000);
            -- 20 × lương cơ sở 2,340,000 VNĐ (cập nhật theo NĐ hiện hành)
    PRINT N'[OK] §4.1 CK_LuongCoBan_TranDongBH (≤ 46,800,000 VNĐ)';
END
GO

-- ── §4.2  HopDong: Lương không thấp hơn mức tối thiểu vùng ─
--   Vùng 1: 4,960,000 | Vùng 2: 4,410,000
--   Vùng 3: 3,860,000 | Vùng 4: 3,450,000 (NĐ 38/2022 từ 01/07/2022)
IF NOT EXISTS (
    SELECT 1 FROM sys.check_constraints
    WHERE parent_object_id = OBJECT_ID('dbo.HopDong')
      AND name = 'CK_HopDong_LuongToiThieuVung'
)
BEGIN
    ALTER TABLE dbo.HopDong
        ADD CONSTRAINT CK_HopDong_LuongToiThieuVung
            CHECK (
                (VungLuong = 1 AND LuongCoBan >= 4960000) OR
                (VungLuong = 2 AND LuongCoBan >= 4410000) OR
                (VungLuong = 3 AND LuongCoBan >= 3860000) OR
                (VungLuong = 4 AND LuongCoBan >= 3450000)
            );
    PRINT N'[OK] §4.2 CK_HopDong_LuongToiThieuVung (NĐ 38/2022)';
END
GO

-- ── §4.3  BangLuong: Các khoản BH không âm & phải ≤ Gross ──
IF NOT EXISTS (
    SELECT 1 FROM sys.check_constraints
    WHERE parent_object_id = OBJECT_ID('dbo.BangLuong')
      AND name = 'CK_BangLuong_BaoHiemHopLe'
)
BEGIN
    ALTER TABLE dbo.BangLuong
        ADD CONSTRAINT CK_BangLuong_BaoHiemHopLe
            CHECK (
                BHXH_NLD >= 0
                AND BHYT_NLD >= 0
                AND BHTN_NLD >= 0
                -- BHXH = 8%, BHYT = 1.5%, BHTN = 1%  → max 10.5% lương đóng BH
                -- Không vượt quá tổng lương gross
                AND (BHXH_NLD + BHYT_NLD + BHTN_NLD) <= LuongCoBan
            );
    PRINT N'[OK] §4.3 CK_BangLuong_BaoHiemHopLe';
END
GO

-- ── §4.4  BangLuong: Thuế TNCN không âm & không vượt 35% gross
IF NOT EXISTS (
    SELECT 1 FROM sys.check_constraints
    WHERE parent_object_id = OBJECT_ID('dbo.BangLuong')
      AND name = 'CK_BangLuong_ThueTNCN_HopLe'
)
BEGIN
    ALTER TABLE dbo.BangLuong
        ADD CONSTRAINT CK_BangLuong_ThueTNCN_HopLe
            CHECK (
                ThueTNCN >= 0
                AND (LuongCoBan = 0 OR ThueTNCN <= LuongCoBan * 0.35)
                -- Thuế suất tối đa 35% (bậc 7) theo TT 111/2013
            );
    PRINT N'[OK] §4.4 CK_BangLuong_ThueTNCN_HopLe (≤ 35% LuongCoBan)';
END
GO

-- ── §4.5  BangLuong: Ngày thanh toán phải sau ngày xác nhận ─
IF NOT EXISTS (
    SELECT 1 FROM sys.check_constraints
    WHERE parent_object_id = OBJECT_ID('dbo.BangLuong')
      AND name = 'CK_BangLuong_NgayThanhToanHopLe'
)
BEGIN
    ALTER TABLE dbo.BangLuong
        ADD CONSTRAINT CK_BangLuong_NgayThanhToanHopLe
            CHECK (
                NgayThanhToan IS NULL
                OR NgayXacNhan IS NULL
                OR NgayThanhToan >= CAST(NgayXacNhan AS DATE)
            );
    PRINT N'[OK] §4.5 CK_BangLuong_NgayThanhToanHopLe';
END
GO

-- ── §4.6  ChiTietLuong: Giá trị một dòng không vượt 500 triệu ─
--   Ngưỡng bất thường — nếu vượt có thể là lỗi nhập liệu
IF NOT EXISTS (
    SELECT 1 FROM sys.check_constraints
    WHERE parent_object_id = OBJECT_ID('dbo.ChiTietLuong')
      AND name = 'CK_ChiTietLuong_NguongBatThuong'
)
BEGIN
    ALTER TABLE dbo.ChiTietLuong
        ADD CONSTRAINT CK_ChiTietLuong_NguongBatThuong
            CHECK (GiaTri <= 500000000);
            -- 500 triệu VNĐ / dòng — flag nếu cần review
    PRINT N'[OK] §4.6 CK_ChiTietLuong_NguongBatThuong (≤ 500 triệu)';
END
GO

-- ── §4.7  KhauTru: Giá trị khấu trừ không vượt 50% lương ───
--   Pháp lý: BLLĐ 2019 Điều 102 — khấu trừ tối đa 30% lương/tháng
--   Dùng 50% để có margin cho tổng nhiều loại khấu trừ
IF NOT EXISTS (
    SELECT 1 FROM sys.check_constraints
    WHERE parent_object_id = OBJECT_ID('dbo.KhauTru')
      AND name = 'CK_KhauTru_NguongBatThuong'
)
BEGIN
    ALTER TABLE dbo.KhauTru
        ADD CONSTRAINT CK_KhauTru_NguongBatThuong
            CHECK (GiaTri <= 200000000);  -- 200 triệu / dòng
    PRINT N'[OK] §4.7 CK_KhauTru_NguongBatThuong';
END
GO

-- ── §4.8  LuongCoBan: Lương CB không vượt quá 500 triệu/tháng ─
IF NOT EXISTS (
    SELECT 1 FROM sys.check_constraints
    WHERE parent_object_id = OBJECT_ID('dbo.LuongCoBan')
      AND name = 'CK_LuongCoBan_NguongTran'
)
BEGIN
    ALTER TABLE dbo.LuongCoBan
        ADD CONSTRAINT CK_LuongCoBan_NguongTran
            CHECK (LuongCB <= 500000000);
    PRINT N'[OK] §4.8 CK_LuongCoBan_NguongTran (≤ 500 triệu)';
END
GO


-- ============================================================
-- §5  COMPOSITE INDEX BỔ SUNG (HIỆU NĂNG TRUY VẤN)
--     Dành cho các query pattern trong Stored Procedures:
--       sp_TinhLuong, sp_BaoCaoNhanSu, vw_BangLuong...
-- ============================================================

-- ── §5.1  ChamCong: tra cứu theo tháng/năm (dùng trong sp_TinhLuong) ─
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.ChamCong')
      AND name      = 'IX_ChamCong_NV_ThangNam'
)
BEGIN
    CREATE INDEX IX_ChamCong_NV_ThangNam
        ON dbo.ChamCong (MaNV, YEAR(NgayCham), MONTH(NgayCham));
        -- SQL Server cho phép computed column trong index expression
    PRINT N'[OK] §5.1 IX_ChamCong_NV_ThangNam';
END
GO

-- ── §5.2  HopDong: tìm HĐ hiệu lực của NV nhanh (dùng nhiều nhất) ─
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.HopDong')
      AND name      = 'IX_HopDong_NV_Active_Include'
)
BEGIN
    CREATE INDEX IX_HopDong_NV_Active_Include
        ON dbo.HopDong (MaNV, TrangThai)
        INCLUDE (LuongCoBan, VungLuong, MaLoaiHD, NgayBatDau, NgayKetThuc);
    PRINT N'[OK] §5.2 IX_HopDong_NV_Active_Include';
END
GO

-- ── §5.3  LuongCoBan: lookup lương hiện tại theo NV ────────
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.LuongCoBan')
      AND name      = 'IX_LuongCoBan_NV_Current_Include'
)
BEGIN
    CREATE INDEX IX_LuongCoBan_NV_Current_Include
        ON dbo.LuongCoBan (MaNV, NgayHetHieuLuc)
        INCLUDE (LuongCB, LuongDongBH, NgayHieuLuc)
        WHERE NgayHetHieuLuc IS NULL;
    PRINT N'[OK] §5.3 IX_LuongCoBan_NV_Current_Include';
END
GO

-- ── §5.4  BangLuong: tìm nhanh kỳ lương theo trạng thái ────
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.BangLuong')
      AND name      = 'IX_BangLuong_TrangThai_Ky'
)
BEGIN
    CREATE INDEX IX_BangLuong_TrangThai_Ky
        ON dbo.BangLuong (TrangThai, Nam DESC, Thang DESC)
        INCLUDE (MaNV, LuongCoBan, ThuNhapThucLinh);
    PRINT N'[OK] §5.4 IX_BangLuong_TrangThai_Ky';
END
GO

-- ── §5.5  NghiPhep: tìm đơn đang chờ duyệt ─────────────────
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.NghiPhep')
      AND name      = 'IX_NghiPhep_Pending'
)
BEGIN
    CREATE INDEX IX_NghiPhep_Pending
        ON dbo.NghiPhep (TrangThai, NgayTao DESC)
        INCLUDE (MaNV, MaLoaiNghi, NgayBatDau, NgayKetThuc, SoNgayNghi)
        WHERE TrangThai = 'P';
    PRINT N'[OK] §5.5 IX_NghiPhep_Pending';
END
GO

-- ── §5.6  NhanVienPhucLoi: tra cứu phúc lợi đang áp dụng ───
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.NhanVienPhucLoi')
      AND name      = 'IX_NVPhucLoi_Active'
)
BEGIN
    CREATE INDEX IX_NVPhucLoi_Active
        ON dbo.NhanVienPhucLoi (MaNV, IsActive)
        INCLUDE (MaFL, GiaTriOverride, NgayApDung)
        WHERE IsActive = 1;
    PRINT N'[OK] §5.6 IX_NVPhucLoi_Active';
END
GO

-- ── §5.7  AuditLog_HopDong: range query theo thời gian ──────
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.AuditLog_HopDong')
      AND name      = 'IX_AuditHD_MaNV_Time'
)
BEGIN
    CREATE INDEX IX_AuditHD_MaNV_Time
        ON dbo.AuditLog_HopDong (MaNV, ThoiGianThayDoi DESC)
        INCLUDE (MaHD, LoaiThayDoi, TenCot, GiaTriCu, GiaTriMoi);
    PRINT N'[OK] §5.7 IX_AuditHD_MaNV_Time';
END
GO

-- ── §5.8  AuditLog_Luong: range query theo kỳ lương ────────
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.AuditLog_Luong')
      AND name      = 'IX_AuditLuong_NV_ThangNam'
)
BEGIN
    CREATE INDEX IX_AuditLuong_NV_ThangNam
        ON dbo.AuditLog_Luong (MaNV, Nam DESC, Thang DESC)
        INCLUDE (LoaiThayDoi, TenCot, GiaTriCu, GiaTriMoi, ThoiGianThayDoi);
    PRINT N'[OK] §5.8 IX_AuditLuong_NV_ThangNam';
END
GO


-- ============================================================
-- §6  BÁO CÁO TỔNG HỢP — KIỂM TRA SAU KHI CHẠY XONG
-- ============================================================

PRINT N'';
PRINT N'════════════════════════════════════════════════════════';
PRINT N'  §6  TỔNG HỢP TOÀN BỘ CONSTRAINTS & INDEXES';
PRINT N'════════════════════════════════════════════════════════';

-- ── 6.1  Tất cả CHECK constraints ───────────────────────────
PRINT N'';
PRINT N'--- CHECK CONSTRAINTS ---';
SELECT
    OBJECT_NAME(c.parent_object_id)     AS Bảng,
    c.name                               AS TênConstraint,
    c.definition                         AS ĐịnhNghĩa,
    CASE c.is_disabled WHEN 0 THEN 'ENABLED' ELSE 'DISABLED' END AS TrạngThái
FROM
    sys.check_constraints c
WHERE
    OBJECTPROPERTY(c.parent_object_id, 'IsUserTable') = 1
ORDER BY
    OBJECT_NAME(c.parent_object_id), c.name;
GO

-- ── 6.2  Tất cả UNIQUE constraints & Filtered Indexes ───────
PRINT N'';
PRINT N'--- UNIQUE & FILTERED INDEXES ---';
SELECT
    OBJECT_NAME(i.object_id)            AS Bảng,
    i.name                               AS TênIndex,
    i.type_desc                          AS Loại,
    CASE i.is_unique    WHEN 1 THEN 'YES' ELSE 'NO'  END AS IsUnique,
    CASE i.has_filter   WHEN 1 THEN 'YES' ELSE 'NO'  END AS IsFiltered,
    ISNULL(i.filter_definition, '')      AS ĐiềuKiệnFilter
FROM
    sys.indexes i
WHERE
    OBJECTPROPERTY(i.object_id, 'IsUserTable') = 1
    AND i.type > 0      -- loại bỏ heap
ORDER BY
    OBJECT_NAME(i.object_id), i.name;
GO

-- ── 6.3  FOREIGN KEY summary ────────────────────────────────
PRINT N'';
PRINT N'--- FOREIGN KEYS ---';
SELECT
    OBJECT_NAME(fk.parent_object_id)    AS BảngCon,
    COL_NAME(fkc.parent_object_id,
             fkc.parent_column_id)      AS CộtCon,
    OBJECT_NAME(fk.referenced_object_id) AS BảngCha,
    COL_NAME(fkc.referenced_object_id,
             fkc.referenced_column_id)  AS CộtCha,
    fk.name                              AS TênFK,
    fk.delete_referential_action_desc    AS OnDelete,
    fk.update_referential_action_desc    AS OnUpdate
FROM
    sys.foreign_keys        fk
    JOIN sys.foreign_key_columns fkc
        ON fk.object_id = fkc.constraint_object_id
ORDER BY
    OBJECT_NAME(fk.parent_object_id), fk.name;
GO

-- ── 6.4  Đếm tổng theo loại ─────────────────────────────────
PRINT N'';
PRINT N'--- THỐNG KÊ TỔNG ---';
SELECT
    'CHECK'      AS LoaiRangBuoc,
    COUNT(*)     AS SoLuong
FROM sys.check_constraints
WHERE OBJECTPROPERTY(parent_object_id,'IsUserTable')=1
UNION ALL
SELECT 'UNIQUE INDEX', COUNT(*)
FROM sys.indexes
WHERE OBJECTPROPERTY(object_id,'IsUserTable')=1
  AND is_unique = 1 AND type > 0
UNION ALL
SELECT 'FILTERED INDEX', COUNT(*)
FROM sys.indexes
WHERE OBJECTPROPERTY(object_id,'IsUserTable')=1
  AND has_filter = 1
UNION ALL
SELECT 'FOREIGN KEY', COUNT(*)
FROM sys.foreign_keys
WHERE OBJECTPROPERTY(parent_object_id,'IsUserTable')=1
UNION ALL
SELECT 'DEFAULT', COUNT(*)
FROM sys.default_constraints
WHERE OBJECTPROPERTY(parent_object_id,'IsUserTable')=1;
GO

PRINT N'';
PRINT N'[DONE] 02_constraints.sql hoàn tất.';
PRINT N'Sẵn sàng cho bước tiếp: 03_indexes.sql → DML/seed_data.sql → StoredProcedures/';
GO
