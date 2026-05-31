-- ============================================================
-- FILE       : 03_indexes.sql
-- PROJECT    : Hệ Thống Quản Lý Nhân Sự & Tính Lương Tự Động
-- MỤC ĐÍCH   : Index chiến lược cho toàn bộ query pattern:
--                §1  Covering index cho sp_TinhLuong   ← CORE
--                §2  Covering index cho sp_BaoCaoNhanSu
--                §3  Covering index cho View & báo cáo
--                §4  Covering index cho Audit & tra cứu
--                §5  Columnstore Index (analytics / BI)
--                §6  Bảo trì index (fill factor, rebuild)
--                §7  Kiểm tra DMV — phân tích index usage
-- DEPENDENCY : Chạy SAU 01_create_tables.sql + 02_constraints.sql
-- GHI CHÚ   : File KHÔNG tạo lại index đã có ở file trước.
--             Tất cả block bao bọc bởi IF NOT EXISTS.
-- ============================================================

USE HRPayrollDB;
GO

PRINT N'════════════════════════════════════════════════════════';
PRINT N'  03_indexes.sql — Xây dựng chiến lược index';
PRINT N'════════════════════════════════════════════════════════';
GO

-- ============================================================
-- §1  COVERING INDEX CHO sp_TinhLuong
-- ─────────────────────────────────────────────────────────────
-- sp_TinhLuong(@Thang TINYINT, @Nam SMALLINT) thực hiện:
--   STEP A — Lấy danh sách NV đang làm việc kỳ đó
--   STEP B — Lấy lương cơ bản hiệu lực
--   STEP C — Đếm ngày công theo trạng thái từ ChamCong
--   STEP D — Tính giờ tăng ca có hệ số
--   STEP E — Tổng hợp phụ cấp (NhanVienPhucLoi × LoaiPhucLoi)
--   STEP F — Tổng hợp khấu trừ phát sinh (KhauTru)
--   STEP G — Gọi fn_TinhThueTNCN, fn_TinhBHXH
--   STEP H — INSERT/UPDATE vào BangLuong + ChiTietLuong
-- ============================================================

-- ── §1.1  STEP A: NV active trong kỳ lương ─────────────────
-- Query pattern:
--   SELECT MaNV, MaPB, MaCV FROM NhanVien
--   WHERE TrangThai IN ('A','P') AND NgayVaoLam <= @LastDay
--   AND (NgayNghiViec IS NULL OR NgayNghiViec > @FirstDay)
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.NhanVien')
      AND name = 'IX_NhanVien_TinhLuong_Active'
)
BEGIN
    CREATE INDEX IX_NhanVien_TinhLuong_Active
        ON dbo.NhanVien (TrangThai, NgayVaoLam, NgayNghiViec)
        INCLUDE (MaPB, MaCV, HoTen, SoNguoiPhuThuoc)
        -- SoNguoiPhuThuoc dùng cho fn_TinhThueTNCN (giảm trừ phụ thuộc)
        WHERE TrangThai IN ('A', 'P');
    PRINT N'[OK] §1.1 IX_NhanVien_TinhLuong_Active';
END
GO

-- ── §1.2  STEP B: Lương cơ bản hiệu lực tại kỳ lương ──────
-- Query pattern:
--   SELECT TOP 1 LuongCB, LuongDongBH FROM LuongCoBan
--   WHERE MaNV = @MaNV AND NgayHieuLuc <= @FirstDay
--   AND (NgayHetHieuLuc IS NULL OR NgayHetHieuLuc > @LastDay)
--   ORDER BY NgayHieuLuc DESC
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.LuongCoBan')
      AND name = 'IX_LuongCoBan_TinhLuong_Lookup'
)
BEGIN
    CREATE INDEX IX_LuongCoBan_TinhLuong_Lookup
        ON dbo.LuongCoBan (MaNV, NgayHieuLuc DESC, NgayHetHieuLuc)
        INCLUDE (LuongCB, LuongDongBH, LyDo);
    PRINT N'[OK] §1.2 IX_LuongCoBan_TinhLuong_Lookup';
END
GO

-- ── §1.3  STEP C: Đếm ngày công trong tháng theo loại ──────
-- Query pattern (GROUP BY aggregate):
--   SELECT MaNV,
--          SUM(CASE WHEN TrangThai = 'DL'  THEN 1 ELSE 0 END) AS NgayDiLam,
--          SUM(CASE WHEN TrangThai = 'NP'  THEN 1 ELSE 0 END) AS NgayNghiPhep,
--          SUM(CASE WHEN TrangThai = 'KP'  THEN 1 ELSE 0 END) AS NgayKhongPhep,
--          SUM(SoGioTangCa * HeSoTangCa)                      AS TongTangCaQuyDoi
--   FROM ChamCong
--   WHERE NgayCham BETWEEN @FirstDay AND @LastDay
--   GROUP BY MaNV
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.ChamCong')
      AND name = 'IX_ChamCong_TinhLuong_Period'
)
BEGIN
    CREATE INDEX IX_ChamCong_TinhLuong_Period
        ON dbo.ChamCong (NgayCham, MaNV, TrangThai)
        INCLUDE (SoGioLam, SoGioTangCa, HeSoTangCa, GhiChu);
        -- NgayCham đứng đầu vì WHERE NgayCham BETWEEN ... là điều kiện lọc chính
    PRINT N'[OK] §1.3 IX_ChamCong_TinhLuong_Period';
END
GO

-- ── §1.4  STEP E: Phụ cấp của NV (JOIN với LoaiPhucLoi) ────
-- Query pattern:
--   SELECT nvl.MaNV, nvl.MaFL,
--          COALESCE(nvl.GiaTriOverride, lfl.GiaTri) AS GiaTri,
--          lfl.CoTinhThue
--   FROM NhanVienPhucLoi nvl JOIN LoaiPhucLoi lfl ON nvl.MaFL = lfl.MaFL
--   WHERE nvl.MaNV IN (@ListNV)
--     AND nvl.IsActive = 1
--     AND nvl.NgayApDung <= @LastDay
--     AND (nvl.NgayKetThuc IS NULL OR nvl.NgayKetThuc >= @FirstDay)
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.NhanVienPhucLoi')
      AND name = 'IX_NVPhucLoi_TinhLuong'
)
BEGIN
    CREATE INDEX IX_NVPhucLoi_TinhLuong
        ON dbo.NhanVienPhucLoi (MaNV, IsActive, NgayApDung, NgayKetThuc)
        INCLUDE (MaFL, GiaTriOverride);
    PRINT N'[OK] §1.4 IX_NVPhucLoi_TinhLuong';
END
GO

-- ── §1.5  STEP F: Khấu trừ phát sinh kỳ lương ──────────────
-- Query pattern:
--   SELECT MaNV, SUM(GiaTri) AS TongKhauTru
--   FROM KhauTru
--   WHERE Thang = @Thang AND Nam = @Nam
--     AND TrangThai = 'P'     -- Pending → chưa áp
--   GROUP BY MaNV
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.KhauTru')
      AND name = 'IX_KhauTru_TinhLuong_Ky'
)
BEGIN
    CREATE INDEX IX_KhauTru_TinhLuong_Ky
        ON dbo.KhauTru (Nam, Thang, TrangThai, MaNV)
        INCLUDE (GiaTri, LoaiKhauTru, GhiChu);
    PRINT N'[OK] §1.5 IX_KhauTru_TinhLuong_Ky';
END
GO

-- ── §1.6  STEP H: Kiểm tra BangLuong đã tồn tại chưa ──────
-- Query pattern (guard check trước INSERT):
--   IF EXISTS (SELECT 1 FROM BangLuong WHERE MaNV=@MaNV AND Thang=@T AND Nam=@N)
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.BangLuong')
      AND name = 'IX_BangLuong_TinhLuong_Check'
)
BEGIN
    CREATE INDEX IX_BangLuong_TinhLuong_Check
        ON dbo.BangLuong (Nam, Thang, MaNV, TrangThai)
        INCLUDE (MaBL, ThuNhapThucLinh, NgayTinhLuong);
    PRINT N'[OK] §1.6 IX_BangLuong_TinhLuong_Check';
END
GO

-- ── §1.7  LoaiPhucLoi: tra nhanh theo MaFL (JOIN side) ─────
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.LoaiPhucLoi')
      AND name = 'IX_LoaiPhucLoi_Active_Include'
)
BEGIN
    CREATE INDEX IX_LoaiPhucLoi_Active_Include
        ON dbo.LoaiPhucLoi (MaFL, IsActive)
        INCLUDE (TenFL, GiaTri, LoaiGiaTri, CoTinhThue);
    PRINT N'[OK] §1.7 IX_LoaiPhucLoi_Active_Include';
END
GO

-- ── §1.8  LoaiHopDong: tra nhanh TiLeBHXH ──────────────────
-- fn_TinhBHXH cần đọc TiLeBHXH theo loại hợp đồng
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.LoaiHopDong')
      AND name = 'IX_LoaiHopDong_BHXH'
)
BEGIN
    CREATE INDEX IX_LoaiHopDong_BHXH
        ON dbo.LoaiHopDong (MaLoaiHD)
        INCLUDE (TenLoaiHD, TiLeBHXH, ThoiHanToiDa);
    PRINT N'[OK] §1.8 IX_LoaiHopDong_BHXH';
END
GO


-- ============================================================
-- §2  COVERING INDEX CHO sp_BaoCaoNhanSu
-- ─────────────────────────────────────────────────────────────
-- Báo cáo: Danh sách NV theo phòng ban, thống kê nhân lực,
--          nhân viên sắp hết hạn HĐ, quỹ lương theo phòng ban
-- ============================================================

-- ── §2.1  Danh sách NV theo PhongBan + ChucVu ───────────────
-- Query pattern:
--   SELECT nv.*, pb.TenPB, cv.TenCV, cv.HeSoLuong
--   FROM NhanVien nv
--   JOIN PhongBan pb ON nv.MaPB = pb.MaPB
--   JOIN ChucVu   cv ON nv.MaCV = cv.MaCV
--   WHERE nv.TrangThai = 'A' AND nv.MaPB = @MaPB
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.NhanVien')
      AND name = 'IX_NhanVien_BaoCao_PB_CV'
)
BEGIN
    CREATE INDEX IX_NhanVien_BaoCao_PB_CV
        ON dbo.NhanVien (MaPB, TrangThai, MaCV)
        INCLUDE (HoTen, NgaySinh, GioiTinh, NgayVaoLam, SoNguoiPhuThuoc, Email);
    PRINT N'[OK] §2.1 IX_NhanVien_BaoCao_PB_CV';
END
GO

-- ── §2.2  HĐ sắp hết hạn trong N ngày tới ──────────────────
-- Query pattern:
--   SELECT * FROM HopDong WHERE TrangThai = 'A'
--   AND NgayKetThuc BETWEEN GETDATE() AND DATEADD(DAY, @N, GETDATE())
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.HopDong')
      AND name = 'IX_HopDong_SapHetHan'
)
BEGIN
    CREATE INDEX IX_HopDong_SapHetHan
        ON dbo.HopDong (TrangThai, NgayKetThuc)
        INCLUDE (MaNV, MaLoaiHD, LuongCoBan, VungLuong, NgayBatDau)
        WHERE TrangThai = 'A' AND NgayKetThuc IS NOT NULL;
    PRINT N'[OK] §2.2 IX_HopDong_SapHetHan';
END
GO

-- ── §2.3  Quỹ lương theo phòng ban: JOIN BangLuong-NhanVien ─
-- Query pattern:
--   SELECT pb.TenPB, SUM(bl.ThuNhapThucLinh) AS QuyLuong
--   FROM BangLuong bl JOIN NhanVien nv ON bl.MaNV = nv.MaNV
--   JOIN PhongBan pb ON nv.MaPB = pb.MaPB
--   WHERE bl.Thang = @T AND bl.Nam = @N AND bl.TrangThai IN ('C','P')
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.BangLuong')
      AND name = 'IX_BangLuong_BaoCao_QuyLuong'
)
BEGIN
    CREATE INDEX IX_BangLuong_BaoCao_QuyLuong
        ON dbo.BangLuong (Thang, Nam, TrangThai)
        INCLUDE (
            MaNV, LuongCoBan, TongPhuCap,
            BHXH_NLD, BHYT_NLD, BHTN_NLD,
            ThueTNCN, ThuNhapThucLinh, NgayThanhToan
        );
    PRINT N'[OK] §2.3 IX_BangLuong_BaoCao_QuyLuong';
END
GO

-- ── §2.4  Thống kê ngày nghỉ của NV trong năm ───────────────
-- Query pattern:
--   SELECT MaNV, MaLoaiNghi, SUM(SoNgayNghi)
--   FROM NghiPhep WHERE YEAR(NgayBatDau) = @Nam AND TrangThai = 'A'
--   GROUP BY MaNV, MaLoaiNghi
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.NghiPhep')
      AND name = 'IX_NghiPhep_ThongKe_Nam'
)
BEGIN
    CREATE INDEX IX_NghiPhep_ThongKe_Nam
        ON dbo.NghiPhep (TrangThai, NgayBatDau, MaNV, MaLoaiNghi)
        INCLUDE (NgayKetThuc, SoNgayNghi, LyDo)
        WHERE TrangThai = 'A';
    PRINT N'[OK] §2.4 IX_NghiPhep_ThongKe_Nam';
END
GO

-- ── §2.5  PhongBan: JOIN lookup khi hiển thị tên phòng ban ──
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.PhongBan')
      AND name = 'IX_PhongBan_Active_Include'
)
BEGIN
    CREATE INDEX IX_PhongBan_Active_Include
        ON dbo.PhongBan (IsActive, MaPB)
        INCLUDE (TenPB, DiaDiem, MaTruongPhong)
        WHERE IsActive = 1;
    PRINT N'[OK] §2.5 IX_PhongBan_Active_Include';
END
GO

-- ── §2.6  ChucVu: tra hệ số lương theo nhóm ────────────────
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.ChucVu')
      AND name = 'IX_ChucVu_HeSo_CapBac'
)
BEGIN
    CREATE INDEX IX_ChucVu_HeSo_CapBac
        ON dbo.ChucVu (IsActive, CapBac DESC)
        INCLUDE (MaCV, TenCV, HeSoLuong);
    PRINT N'[OK] §2.6 IX_ChucVu_HeSo_CapBac';
END
GO


-- ============================================================
-- §3  COVERING INDEX CHO VIEW & BÁO CÁO TỔNG HỢP
-- ─────────────────────────────────────────────────────────────
-- vw_BangLuong       — JOIN: NhanVien + BangLuong + PhongBan + ChucVu
-- vw_TongHopChamCong — GROUP BY MaNV + tháng + loại trạng thái
-- ============================================================

-- ── §3.1  vw_BangLuong: cột tra cứu MaNV trong BangLuong ───
-- Tối ưu cho ORDER BY ThuNhapThucLinh DESC (xếp hạng lương)
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.BangLuong')
      AND name = 'IX_BangLuong_View_Rank'
)
BEGIN
    CREATE INDEX IX_BangLuong_View_Rank
        ON dbo.BangLuong (Nam DESC, Thang DESC, ThuNhapThucLinh DESC)
        INCLUDE (MaNV, TrangThai, TongPhuCap, ThueTNCN, BHXH_NLD);
    PRINT N'[OK] §3.1 IX_BangLuong_View_Rank';
END
GO

-- ── §3.2  vw_TongHopChamCong: aggregate theo tháng/năm ──────
-- Query pattern:
--   SELECT MaNV, YEAR(NgayCham) Y, MONTH(NgayCham) M,
--          COUNT(CASE WHEN TrangThai='DL' THEN 1 END) DL,
--          COUNT(CASE WHEN TrangThai='NP' THEN 1 END) NP,
--          COUNT(CASE WHEN TrangThai='KP' THEN 1 END) KP,
--          SUM(SoGioTangCa) TC
--   FROM ChamCong GROUP BY MaNV, Y, M
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.ChamCong')
      AND name = 'IX_ChamCong_View_ThongKe'
)
BEGIN
    CREATE INDEX IX_ChamCong_View_ThongKe
        ON dbo.ChamCong (MaNV, NgayCham DESC, TrangThai)
        INCLUDE (SoGioLam, SoGioTangCa, HeSoTangCa);
    PRINT N'[OK] §3.2 IX_ChamCong_View_ThongKe';
END
GO

-- ── §3.3  Báo cáo thuế TNCN theo kỳ: ChiTietLuong ──────────
-- Query pattern:
--   SELECT bl.MaNV, SUM(ctl.GiaTri) tax
--   FROM ChiTietLuong ctl JOIN BangLuong bl ON ctl.MaBL = bl.MaBL
--   WHERE ctl.LoaiMuc = '-' AND ctl.TenMuc LIKE N'%Thuế%'
--     AND bl.Nam = @N AND bl.Thang = @T
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.ChiTietLuong')
      AND name = 'IX_ChiTietLuong_BaoCao_Loai'
)
BEGIN
    CREATE INDEX IX_ChiTietLuong_BaoCao_Loai
        ON dbo.ChiTietLuong (MaBL, LoaiMuc, TenMuc)
        INCLUDE (GiaTri, GhiChu);
    PRINT N'[OK] §3.3 IX_ChiTietLuong_BaoCao_Loai';
END
GO

-- ── §3.4  So sánh quỹ lương nhiều tháng (trend analysis) ────
-- Query pattern:
--   SELECT Nam, Thang, SUM(ThuNhapThucLinh) TongQuy,
--          AVG(ThuNhapThucLinh) TBLuong, COUNT(*) SoNV
--   FROM BangLuong WHERE TrangThai IN ('C','P')
--   GROUP BY Nam, Thang ORDER BY Nam, Thang
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.BangLuong')
      AND name = 'IX_BangLuong_Trend_Analysis'
)
BEGIN
    CREATE INDEX IX_BangLuong_Trend_Analysis
        ON dbo.BangLuong (Nam ASC, Thang ASC)
        INCLUDE (ThuNhapThucLinh, LuongCoBan, ThueTNCN,
                 BHXH_NLD, TrangThai, MaNV)
        WHERE TrangThai IN ('C', 'P');
    PRINT N'[OK] §3.4 IX_BangLuong_Trend_Analysis';
END
GO


-- ============================================================
-- §4  COVERING INDEX CHO AUDIT & TRA CỨU LỊCH SỬ
-- ============================================================

-- ── §4.1  Audit HopDong: tra cứu ai thay đổi gì trong ngày ─
-- Query pattern:
--   SELECT * FROM AuditLog_HopDong
--   WHERE ThoiGianThayDoi BETWEEN @Tu AND @Den
--   AND LoaiThayDoi = 'U'
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.AuditLog_HopDong')
      AND name = 'IX_AuditHD_Time_Action'
)
BEGIN
    CREATE INDEX IX_AuditHD_Time_Action
        ON dbo.AuditLog_HopDong (ThoiGianThayDoi DESC, LoaiThayDoi)
        INCLUDE (MaHD, MaNV, TenCot, GiaTriCu, GiaTriMoi, NguoiThayDoi);
    PRINT N'[OK] §4.1 IX_AuditHD_Time_Action';
END
GO

-- ── §4.2  Audit Luong: lịch sử tăng lương của 1 NV ─────────
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.AuditLog_Luong')
      AND name = 'IX_AuditLuong_NV_History'
)
BEGIN
    CREATE INDEX IX_AuditLuong_NV_History
        ON dbo.AuditLog_Luong (MaNV, ThoiGianThayDoi DESC)
        INCLUDE (TenCot, GiaTriCu, GiaTriMoi, LoaiThayDoi, NguoiThayDoi);
    PRINT N'[OK] §4.2 IX_AuditLuong_NV_History';
END
GO

-- ── §4.3  Lịch sử lương cơ bản của NV qua các năm ──────────
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.LuongCoBan')
      AND name = 'IX_LuongCoBan_History_NV'
)
BEGIN
    CREATE INDEX IX_LuongCoBan_History_NV
        ON dbo.LuongCoBan (MaNV, NgayHieuLuc DESC)
        INCLUDE (LuongCB, LuongDongBH, NgayHetHieuLuc, LyDo, NguoiDuyet);
    PRINT N'[OK] §4.3 IX_LuongCoBan_History_NV';
END
GO

-- ── §4.4  KhauTru đã áp dụng vào lương kỳ nào ──────────────
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.KhauTru')
      AND name = 'IX_KhauTru_Applied'
)
BEGIN
    CREATE INDEX IX_KhauTru_Applied
        ON dbo.KhauTru (MaNV, TrangThai, NgayPhatSinh DESC)
        INCLUDE (GiaTri, LoaiKhauTru, MaBL, GhiChu)
        WHERE TrangThai = 'A';
    PRINT N'[OK] §4.4 IX_KhauTru_Applied';
END
GO


-- ============================================================
-- §5  COLUMNSTORE INDEX — Analytics / BI / Dashboard
-- ─────────────────────────────────────────────────────────────
-- Nonclustered Columnstore cho phép analytical query nhanh
-- trên bảng lớn mà không ảnh hưởng OLTP write performance.
-- BangLuong: bảng quan trọng nhất cho dashboard tài chính.
-- ============================================================

-- ── §5.1  Columnstore trên BangLuong ────────────────────────
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.BangLuong')
      AND name = 'NCIX_CS_BangLuong_Analytics'
)
BEGIN
    CREATE NONCLUSTERED COLUMNSTORE INDEX NCIX_CS_BangLuong_Analytics
        ON dbo.BangLuong (
            MaNV, Thang, Nam, TrangThai,
            LuongCoBan, TongPhuCap,
            BHXH_NLD, BHYT_NLD, BHTN_NLD,
            ThueTNCN, TongKhauTru,
            ThuNhapThucLinh,
            SoNgayCong, SoNgayLamChuan
        );
    PRINT N'[OK] §5.1 NCIX_CS_BangLuong_Analytics';
END
GO

-- ── §5.2  Columnstore trên ChamCong ─────────────────────────
-- Dashboard: tỷ lệ chuyên cần, phân tích OT trend
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.ChamCong')
      AND name = 'NCIX_CS_ChamCong_Analytics'
)
BEGIN
    CREATE NONCLUSTERED COLUMNSTORE INDEX NCIX_CS_ChamCong_Analytics
        ON dbo.ChamCong (
            MaNV, NgayCham, TrangThai,
            SoGioLam, SoGioTangCa, HeSoTangCa
        );
    PRINT N'[OK] §5.2 NCIX_CS_ChamCong_Analytics';
END
GO


-- ============================================================
-- §6  CẤU HÌNH BẢO TRÌ INDEX
-- ─────────────────────────────────────────────────────────────
-- Ghi chú kỹ thuật về chiến lược REBUILD / REORGANIZE,
-- fill factor và thống kê — thực thi qua SQL Server Agent Job.
-- ============================================================

-- ── §6.1  Cấu hình Fill Factor cho các bảng ghi nhiều ───────
-- ChamCong / AuditLog ghi liên tục → fill factor 80% tránh page split
-- BangLuong ghi 1 lần/tháng → fill factor 95%
-- Bảng Lookup (PhongBan, ChucVu…) → fill factor 99%

-- Các lệnh dưới thực hiện thay đổi fill factor bằng cách REBUILD:
DECLARE @sql NVARCHAR(MAX) = N'';

-- Bảng ghi thường xuyên: fill factor 80
SELECT @sql += N'ALTER INDEX ALL ON dbo.' + t.name
             + N' REBUILD WITH (FILLFACTOR = 80, ONLINE = OFF);' + CHAR(10)
FROM sys.tables t
WHERE t.name IN ('ChamCong','AuditLog_HopDong','AuditLog_Luong','NghiPhep');

-- Bảng ghi theo kỳ: fill factor 90
SELECT @sql += N'ALTER INDEX ALL ON dbo.' + t.name
             + N' REBUILD WITH (FILLFACTOR = 90, ONLINE = OFF);' + CHAR(10)
FROM sys.tables t
WHERE t.name IN ('BangLuong','ChiTietLuong','KhauTru','LuongCoBan','HopDong');

-- Bảng lookup ít thay đổi: fill factor 98
SELECT @sql += N'ALTER INDEX ALL ON dbo.' + t.name
             + N' REBUILD WITH (FILLFACTOR = 98, ONLINE = OFF);' + CHAR(10)
FROM sys.tables t
WHERE t.name IN ('PhongBan','ChucVu','LoaiHopDong','LoaiNghiPhep','LoaiPhucLoi');

PRINT N'[INFO] §6.1 Script REBUILD với fill factor phù hợp:';
PRINT @sql;
-- EXEC sp_executesql @sql;   ← BỎ CHÚ THÍCH để áp dụng ngay sau khi seed data
GO

-- ── §6.2  Template Job bảo trì index hàng tuần ──────────────
-- Chạy mỗi Chủ Nhật 02:00 AM:
--   • Fragmentation < 5%  → bỏ qua
--   • Fragmentation 5–30% → REORGANIZE
--   • Fragmentation > 30% → REBUILD
PRINT N'';
PRINT N'[INFO] §6.2 Template bảo trì index tuần — lưu làm SQL Agent Job:';
PRINT N'';
PRINT N'DECLARE @IndexName  NVARCHAR(200);';
PRINT N'DECLARE @TableName  NVARCHAR(200);';
PRINT N'DECLARE @Frag       FLOAT;';
PRINT N'DECLARE @SQL        NVARCHAR(500);';
PRINT N'DECLARE cur CURSOR FOR';
PRINT N'  SELECT OBJECT_NAME(ips.object_id),';
PRINT N'         i.name,';
PRINT N'         ips.avg_fragmentation_in_percent';
PRINT N'  FROM sys.dm_db_index_physical_stats';
PRINT N'       (DB_ID(), NULL, NULL, NULL, ''LIMITED'') ips';
PRINT N'  JOIN sys.indexes i ON ips.object_id = i.object_id';
PRINT N'                     AND ips.index_id  = i.index_id';
PRINT N'  WHERE ips.avg_fragmentation_in_percent > 5';
PRINT N'    AND ips.page_count > 100;';
PRINT N'OPEN cur;';
PRINT N'FETCH NEXT FROM cur INTO @TableName, @IndexName, @Frag;';
PRINT N'WHILE @@FETCH_STATUS = 0 BEGIN';
PRINT N'  IF @Frag < 30';
PRINT N'    SET @SQL = ''ALTER INDEX ['' + @IndexName + ''] ON dbo.['' + @TableName + ''] REORGANIZE;''';
PRINT N'  ELSE';
PRINT N'    SET @SQL = ''ALTER INDEX ['' + @IndexName + ''] ON dbo.['' + @TableName + ''] REBUILD WITH (ONLINE=OFF);''';
PRINT N'  EXEC sp_executesql @SQL;';
PRINT N'  FETCH NEXT FROM cur INTO @TableName, @IndexName, @Frag;';
PRINT N'END';
PRINT N'CLOSE cur; DEALLOCATE cur;';
GO


-- ============================================================
-- §7  KIỂM TRA DMV — PHÂN TÍCH INDEX USAGE (chạy sau khi có data)
-- ─────────────────────────────────────────────────────────────
-- Sau khi seed data và chạy SP, dùng DMV để xác nhận index
-- nào được dùng, index nào bị bỏ qua → cắt index lãng phí.
-- ============================================================

PRINT N'';
PRINT N'════════════════════════════════════════════════════════';
PRINT N'  §7  TỔNG KẾT INDEX TOÀN DATABASE';
PRINT N'════════════════════════════════════════════════════════';

SELECT
    t.name                                  AS Bảng,
    i.name                                  AS TênIndex,
    i.type_desc                             AS LoạiIndex,
    CASE i.is_unique   WHEN 1 THEN 'Y' ELSE 'N' END AS Unique_,
    CASE i.has_filter  WHEN 1 THEN 'Y' ELSE 'N' END AS Filtered,
    ISNULL(i.filter_definition, '-')        AS FilterExpr,
    (   SELECT STRING_AGG(c.name + CASE ic2.is_descending_key
                WHEN 1 THEN ' DESC' ELSE '' END, ', ')
               WITHIN GROUP (ORDER BY ic2.key_ordinal)
        FROM sys.index_columns ic2
        JOIN sys.columns c ON ic2.object_id = c.object_id
                           AND ic2.column_id = c.column_id
        WHERE ic2.object_id = i.object_id
          AND ic2.index_id  = i.index_id
          AND ic2.is_included_column = 0
    )                                       AS KeyColumns,
    (   SELECT STRING_AGG(c.name, ', ')
               WITHIN GROUP (ORDER BY ic2.key_ordinal)
        FROM sys.index_columns ic2
        JOIN sys.columns c ON ic2.object_id = c.object_id
                           AND ic2.column_id = c.column_id
        WHERE ic2.object_id = i.object_id
          AND ic2.index_id  = i.index_id
          AND ic2.is_included_column = 1
    )                                       AS IncludedColumns
FROM
    sys.tables  t
    JOIN sys.indexes i ON t.object_id = i.object_id
WHERE
    t.is_ms_shipped = 0
    AND i.type       > 0
ORDER BY
    t.name, i.type_desc, i.name;
GO

-- ── §7.2  Thống kê tổng số index theo loại ──────────────────
SELECT
    i.type_desc                             AS LoạiIndex,
    COUNT(*)                                AS Số_Lượng
FROM
    sys.indexes i
    JOIN sys.tables t ON i.object_id = t.object_id
WHERE
    t.is_ms_shipped = 0 AND i.type > 0
GROUP BY i.type_desc
ORDER BY Số_Lượng DESC;
GO

PRINT N'';
PRINT N'[DONE] 03_indexes.sql hoàn tất.';
PRINT N'Chiến lược index đầy đủ cho sp_TinhLuong, báo cáo, analytics.';
PRINT N'Bước tiếp theo: DML/seed_data.sql';
GO
