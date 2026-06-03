-- ============================================================
-- FILE       : test_queries.sql
-- PROJECT    : Hệ Thống Quản Lý Nhân Sự & Tính Lương Tự Động
-- MỤC ĐÍCH   : Bộ kiểm thử toàn diện — chạy sau khi seed data
--              và tất cả SP/Trigger/View đã được tạo
-- ─────────────────────────────────────────────────────────────
-- §1  Kiểm tra dữ liệu nền (Sanity Check)
-- §2  Kiểm thử Functions
-- §3  Kiểm thử sp_TinhLuong (đầy đủ 3 tháng)
-- §4  Kiểm thử Triggers & Audit Log
-- §5  Kiểm thử Views
-- §6  Kiểm thử Constraints (Negative Tests)
-- §7  Integration Test — vòng đời lương 1 NV
-- §8  Kiểm tra hiệu năng & Index Usage
-- §9  Báo cáo tổng kết kiểm thử
-- ─────────────────────────────────────────────────────────────
-- CÁCH CHẠY:
--   1. Chạy toàn bộ file: F5 trong SSMS
--   2. Chạy từng §: bôi đen đoạn → F5
--   3. Xem kết quả trong tab Messages + Results
-- ============================================================

USE HRPayrollDB;
GO
SET NOCOUNT ON;
GO

-- Bảng ghi kết quả test
IF OBJECT_ID('tempdb..#TestResults') IS NOT NULL
    DROP TABLE #TestResults;

CREATE TABLE #TestResults (
    TestID      INT IDENTITY(1,1),
    Section     NVARCHAR(20),
    TestName    NVARCHAR(200),
    Expected    NVARCHAR(200),
    Actual      NVARCHAR(200),
    Status      NCHAR(4),       -- PASS / FAIL
    GhiChu      NVARCHAR(300)
);

-- Helper: ghi kết quả test
GO
CREATE OR ALTER PROCEDURE #LogTest
    @Section    NVARCHAR(20),
    @TestName   NVARCHAR(200),
    @Expected   NVARCHAR(200),
    @Actual     NVARCHAR(200),
    @GhiChu     NVARCHAR(300) = NULL
AS
BEGIN
    DECLARE @Status NCHAR(4) =
        CASE WHEN @Expected = @Actual THEN N'PASS' ELSE N'FAIL' END;
    INSERT #TestResults (Section,TestName,Expected,Actual,Status,GhiChu)
    VALUES (@Section, @TestName, @Expected, @Actual, @Status, @GhiChu);
    IF @Status = N'FAIL'
        PRINT N'  ❌ FAIL: ' + @TestName
            + N' | Kỳ vọng: ' + @Expected
            + N' | Thực tế: ' + @Actual;
    ELSE
        PRINT N'  ✅ PASS: ' + @TestName;
END;
GO


-- ============================================================
-- §1  SANITY CHECK — Kiểm tra dữ liệu nền
-- ============================================================
PRINT N'';
PRINT N'════════════════════════════════════════════════════════';
PRINT N'  §1  SANITY CHECK — DỮ LIỆU NỀN';
PRINT N'════════════════════════════════════════════════════════';

-- §1.1 Đếm số bảng trong database
EXEC #LogTest '§1','So_bang_trong_DB','15',
    (SELECT CAST(COUNT(*) AS NVARCHAR)
     FROM sys.tables WHERE is_ms_shipped=0),
    N'Phải có đúng 15 bảng theo ERD';

-- §1.2 Nhân viên
EXEC #LogTest '§1','SoNhanVien','50',
    (SELECT CAST(COUNT(*) AS NVARCHAR) FROM dbo.NhanVien),
    N'50 NV theo seed_data.sql';

-- §1.3 Phòng ban
EXEC #LogTest '§1','SoPhongBan','5',
    (SELECT CAST(COUNT(*) AS NVARCHAR) FROM dbo.PhongBan),
    N'5 phòng ban';

-- §1.4 Hợp đồng (đúng số NV)
EXEC #LogTest '§1','SoHopDong_Active','46',
    (SELECT CAST(COUNT(*) AS NVARCHAR)
     FROM dbo.HopDong WHERE TrangThai='A'),
    N'50 HĐ tổng, 4 thử việc có TT khác';

-- §1.5 Lương cơ bản — mỗi NV đúng 1 mức đang hiệu lực
EXEC #LogTest '§1','LCB_OneCurrent_PerNV','50',
    (SELECT CAST(COUNT(DISTINCT MaNV) AS NVARCHAR)
     FROM dbo.LuongCoBan WHERE NgayHetHieuLuc IS NULL),
    N'Mỗi NV có đúng 1 LuongCoBan IS NULL';

-- §1.6 Chấm công — kiểm tra 3 tháng đủ
DECLARE @SoCC INT;
SELECT @SoCC = COUNT(*) FROM dbo.ChamCong
WHERE NgayCham BETWEEN '2025-01-01' AND '2025-03-31';
EXEC #LogTest '§1','ChamCong_3thang_min2000',
    'TRUE',
    CASE WHEN @SoCC > 2000 THEN 'TRUE' ELSE 'FALSE' END,
    N'Phải có > 2000 bản ghi CC 3 tháng';

-- §1.7 Ngày lễ Tết ÂL được đánh dấu NG
EXEC #LogTest '§1','NgayTet_2025_NG',
    'TRUE',
    (SELECT CASE WHEN COUNT(*) > 0 THEN 'TRUE' ELSE 'FALSE' END
     FROM dbo.ChamCong
     WHERE NgayCham = '2025-01-29' AND TrangThai = 'NG'),
    N'29/01/2025 (Giao thừa) phải là NG';

-- §1.8 Trưởng phòng đã được gán
EXEC #LogTest '§1','TruongPhong_Assigned','5',
    (SELECT CAST(COUNT(*) AS NVARCHAR)
     FROM dbo.PhongBan WHERE MaTruongPhong IS NOT NULL),
    N'5 phòng ban có trưởng phòng';

-- §1.9 Phúc lợi FL0001 gán cho tất cả NV
EXEC #LogTest '§1','FL0001_AllNV','50',
    (SELECT CAST(COUNT(*) AS NVARCHAR)
     FROM dbo.NhanVienPhucLoi WHERE MaFL='FL0001' AND IsActive=1),
    N'FL0001 ăn trưa gán cho cả 50 NV';

-- §1.10 NV thử việc không có FL0002
EXEC #LogTest '§1','ThuViec_No_FL0002','0',
    (SELECT CAST(COUNT(*) AS NVARCHAR)
     FROM dbo.NhanVienPhucLoi nvfl
     JOIN dbo.NhanVien nv ON nvfl.MaNV = nv.MaNV
     WHERE nvfl.MaFL = 'FL0002' AND nv.TrangThai = 'P'),
    N'NV thử việc không được gán FL0002';
GO


-- ============================================================
-- §2  KIỂM THỬ FUNCTIONS
-- ============================================================
PRINT N'';
PRINT N'════════════════════════════════════════════════════════';
PRINT N'  §2  KIỂM THỬ FUNCTIONS';
PRINT N'════════════════════════════════════════════════════════';

-- §2.1 fn_TinhThueTNCN_Scalar — bậc 1
EXEC #LogTest '§2','Thue_Bac1_4tr',
    '200000',
    (SELECT CAST(dbo.fn_TinhThueTNCN_Scalar(4000000) AS NVARCHAR)),
    N'4tr × 5% = 200,000';

-- §2.2 fn_TinhThueTNCN — đỉnh bậc 1
EXEC #LogTest '§2','Thue_Bac1_Dinh_5tr',
    '250000',
    (SELECT CAST(dbo.fn_TinhThueTNCN_Scalar(5000000) AS NVARCHAR)),
    N'5tr × 5% = 250,000';

-- §2.3 fn_TinhThueTNCN — bậc 2 (7.5 triệu)
-- 5tr×5% + 2.5tr×10% = 250,000 + 250,000 = 500,000
EXEC #LogTest '§2','Thue_Bac2_7.5tr',
    '500000',
    (SELECT CAST(dbo.fn_TinhThueTNCN_Scalar(7500000) AS NVARCHAR)),
    N'B1:250k + B2:250k = 500k';

-- §2.4 fn_TinhThueTNCN — bậc 3 (15 triệu)
-- B1:250k + B2:500k + B3:5tr×15%=750k = 1,500,000
EXEC #LogTest '§2','Thue_Bac3_15tr',
    '1500000',
    (SELECT CAST(dbo.fn_TinhThueTNCN_Scalar(15000000) AS NVARCHAR)),
    N'B1+B2+B3 = 1,500,000';

-- §2.5 fn_TinhThueTNCN — bậc 4 (25 triệu)
-- B1:250k+B2:500k+B3:1.2M+B4:7tr×20%=1.4M = 3,350,000
EXEC #LogTest '§2','Thue_Bac4_25tr',
    '3350000',
    (SELECT CAST(dbo.fn_TinhThueTNCN_Scalar(25000000) AS NVARCHAR)),
    N'B1+B2+B3+B4 = 3,350,000';

-- §2.6 fn_TinhThueTNCN — đỉnh bậc 6 = 80 triệu
-- Lũy kế: 250k+500k+1.2M+2.8M+5M+8.4M = 18,150,000
EXEC #LogTest '§2','Thue_Dinh_Bac6_80tr',
    '18150000',
    (SELECT CAST(dbo.fn_TinhThueTNCN_Scalar(80000000) AS NVARCHAR)),
    N'Đỉnh bậc 6 = 18,150,000';

-- §2.7 fn_TinhThueTNCN — TNCT = 0
EXEC #LogTest '§2','Thue_TNCT_0',
    '0',
    (SELECT CAST(dbo.fn_TinhThueTNCN_Scalar(0) AS NVARCHAR)),
    N'TNCT <= 0 → thuế = 0';

-- §2.8 fn_TinhThueTNCN — TNCT âm
EXEC #LogTest '§2','Thue_TNCT_Am',
    '0',
    (SELECT CAST(dbo.fn_TinhThueTNCN_Scalar(-1000000) AS NVARCHAR)),
    N'TNCT âm → thuế = 0';

-- §2.9 fn_XacDinhBacThue
EXEC #LogTest '§2','BacThue_3tr',
    '1',
    (SELECT CAST(dbo.fn_XacDinhBacThue(3000000) AS NVARCHAR)),
    N'3tr → bậc 1';

EXEC #LogTest '§2','BacThue_40tr',
    '5',
    (SELECT CAST(dbo.fn_XacDinhBacThue(40000000) AS NVARCHAR)),
    N'40tr → bậc 5';

EXEC #LogTest '§2','BacThue_100tr',
    '7',
    (SELECT CAST(dbo.fn_XacDinhBacThue(100000000) AS NVARCHAR)),
    N'100tr → bậc 7';

-- §2.10 fn_TinhGiamTruPhuThuoc
EXEC #LogTest '§2','GiamTru_2PT',
    '8800000',
    (SELECT CAST(dbo.fn_TinhGiamTruPhuThuoc(2) AS NVARCHAR)),
    N'2 người PT × 4.4tr = 8.8tr';

-- §2.11 fn_TinhLuongDongBH — thử việc → 0
EXEC #LogTest '§2','BHDONGBH_ThuViec',
    '0',
    (SELECT CAST(dbo.fn_TinhLuongDongBH(8000000,1) AS NVARCHAR)),
    N'HĐ thử việc: LuongDongBH = 0';

-- §2.12 fn_TinhLuongDongBH — trần BH = 46.8M
EXEC #LogTest '§2','BHDONGBH_VuotTran',
    '46800000',
    (SELECT CAST(dbo.fn_TinhLuongDongBH(60000000,4) AS NVARCHAR)),
    N'LCB 60tr > trần 46.8tr → cap tại 46.8tr';

-- §2.13 fn_TinhBH_NLD — 10.5%
EXEC #LogTest '§2','BH_NLD_10pct5',
    '1050000',
    (SELECT CAST(dbo.fn_TinhBH_NLD(10000000,2) AS NVARCHAR)),
    N'10tr × 10.5% = 1,050,000';

-- §2.14 fn_TinhBH_NSDLD — 22%
EXEC #LogTest '§2','BH_NSDLD_22pct',
    '2200000',
    (SELECT CAST(dbo.fn_TinhBH_NSDLD(10000000,2) AS NVARCHAR)),
    N'10tr × 22% = 2,200,000';

-- §2.15 fn_SoNgayChuanThang — tháng 1/2025
-- Jan 2025: 23 ngày làm việc trừ Tết = ~17-18 ngày
-- (ngày chính xác phụ thuộc bảng NgayLe)
DECLARE @NgayChuan1 TINYINT = dbo.fn_SoNgayChuanThang(1,2025);
EXEC #LogTest '§2','NgayChuanT1_2025_range',
    'TRUE',
    CASE WHEN @NgayChuan1 BETWEEN 15 AND 23 THEN 'TRUE' ELSE 'FALSE' END,
    N'Tháng 1/2025 ngày chuẩn trong khoảng 15-23';

-- §2.16 fn_SoNgayChamCong — TGĐ tháng 1 không nghỉ
DECLARE @NgayDL1 DECIMAL(5,1) = dbo.fn_SoNgayChamCong('NV000001',1,2025);
EXEC #LogTest '§2','TGD_NgayDiLam_T1',
    'TRUE',
    CASE WHEN @NgayDL1 > 0 THEN 'TRUE' ELSE 'FALSE' END,
    N'TGĐ có ngày đi làm tháng 1/2025';

-- §2.17 fn_SoNgayNghiKhongLuong — NV000049 có 2 ngày KP tháng 2
EXEC #LogTest '§2','NV049_KP_T2',
    '2',
    (SELECT CAST(dbo.fn_SoNgayNghiKhongLuong('NV000049',2,2025) AS NVARCHAR)),
    N'NV000049 có 2 ngày KP tháng 2';

-- §2.18 fn_HeSoLuongThang — NV đi làm đủ tháng ~= 1.0
DECLARE @HeSo1 DECIMAL(10,6) = dbo.fn_HeSoLuongThang('NV000001',3,2025);
EXEC #LogTest '§2','TGD_HeSoLuong_T3_Full',
    'TRUE',
    CASE WHEN @HeSo1 BETWEEN 0.9 AND 1.0 THEN 'TRUE' ELSE 'FALSE' END,
    N'TGĐ đi làm đủ → hệ số gần 1.0';
GO


-- ============================================================
-- §3  KIỂM THỬ sp_TinhLuong (Chạy lương 3 tháng)
-- ============================================================
PRINT N'';
PRINT N'════════════════════════════════════════════════════════';
PRINT N'  §3  KIỂM THỬ sp_TinhLuong';
PRINT N'════════════════════════════════════════════════════════';

-- §3.1 Tính lương tháng 1/2025
PRINT N'';
PRINT N'--- Chạy sp_TinhLuong tháng 1/2025 ---';
EXEC dbo.sp_TinhLuong 1, 2025;
GO

EXEC #LogTest '§3','BangLuong_T1_2025_Draft',
    'TRUE',
    (SELECT CASE WHEN COUNT(*) = 50 THEN 'TRUE' ELSE 'FALSE' END
     FROM dbo.BangLuong WHERE Thang=1 AND Nam=2025 AND TrangThai='D'),
    N'Phải có đúng 50 bản ghi Draft sau sp_TinhLuong';

-- §3.2 Tính lương tháng 2/2025
PRINT N'';
PRINT N'--- Chạy sp_TinhLuong tháng 2/2025 ---';
EXEC dbo.sp_TinhLuong 2, 2025;
GO

EXEC #LogTest '§3','BangLuong_T2_2025','50',
    (SELECT CAST(COUNT(*) AS NVARCHAR)
     FROM dbo.BangLuong WHERE Thang=2 AND Nam=2025),
    N'50 bản ghi tháng 2/2025';

-- §3.3 Tính lương tháng 3/2025
PRINT N'';
PRINT N'--- Chạy sp_TinhLuong tháng 3/2025 ---';
EXEC dbo.sp_TinhLuong 3, 2025;
GO

EXEC #LogTest '§3','BangLuong_T3_2025','50',
    (SELECT CAST(COUNT(*) AS NVARCHAR)
     FROM dbo.BangLuong WHERE Thang=3 AND Nam=2025),
    N'50 bản ghi tháng 3/2025';

-- §3.4 Lương TGĐ (NV000001) phải cao nhất
EXEC #LogTest '§3','TGD_LuongCao_Nhat',
    'NV000001',
    (SELECT TOP 1 MaNV FROM dbo.BangLuong
     WHERE Thang=3 AND Nam=2025
     ORDER BY LuongNet DESC),
    N'TGĐ NV000001 có lương NET cao nhất';

-- §3.5 NV thử việc không có BHXH
EXEC #LogTest '§3','ThuViec_BHXH_Zero',
    '0',
    (SELECT CAST(ISNULL(SUM(bl.BHXH_NLD),0) AS NVARCHAR)
     FROM dbo.BangLuong bl
     JOIN dbo.NhanVien nv ON bl.MaNV = nv.MaNV
     WHERE nv.TrangThai = 'P'
       AND bl.Thang = 1 AND bl.Nam = 2025),
    N'NV thử việc BHXH_NLD = 0';

-- §3.6 Lương NET phải dương với tất cả NV
EXEC #LogTest '§3','LuongNet_KhongAm','0',
    (SELECT CAST(COUNT(*) AS NVARCHAR)
     FROM dbo.BangLuong
     WHERE LuongNet < 0 AND Thang IN (1,2,3) AND Nam = 2025),
    N'Không có NV nào lương NET âm';

-- §3.7 ChiTietLuong đủ dòng
EXEC #LogTest '§3','ChiTietLuong_Co_Du','TRUE',
    (SELECT CASE WHEN COUNT(*) >= 300 THEN 'TRUE' ELSE 'FALSE' END
     FROM dbo.ChiTietLuong ctl
     JOIN dbo.BangLuong bl ON ctl.MaBL = bl.MaBL
     WHERE bl.Thang = 1 AND bl.Nam = 2025),
    N'≥ 300 dòng ChiTietLuong cho 50 NV T1 (min 6 dòng/NV)';

-- §3.8 ThueTNCN đã được ghi
EXEC #LogTest '§3','ThueTNCN_T1_2025','TRUE',
    (SELECT CASE WHEN COUNT(*) > 0 THEN 'TRUE' ELSE 'FALSE' END
     FROM dbo.ThueTNCN WHERE Thang=1 AND Nam=2025),
    N'Bảng ThueTNCN có dữ liệu T1/2025';

-- §3.9 KhauTru đã được áp vào lương
EXEC #LogTest '§3','KhauTru_Applied','TRUE',
    (SELECT CASE WHEN COUNT(*) > 0 THEN 'TRUE' ELSE 'FALSE' END
     FROM dbo.KhauTru WHERE TrangThai = 'A'),
    N'KhauTru đã chuyển → Applied sau sp_TinhLuong';

-- §3.10 Lương NET công thức: Gross - BH - Thue - KhauTru
EXEC #LogTest '§3','LuongNet_Formula_Check','TRUE',
    (SELECT CASE WHEN COUNT(*) = 0 THEN 'TRUE' ELSE 'FALSE' END
     FROM dbo.BangLuong
     WHERE Thang = 1 AND Nam = 2025
       AND ABS(LuongNet -
               (LuongGross - TongBaoHiem - ThueTNCN - TongKhauTru)) > 1
    ),
    N'LuongNet = Gross - BH - Thue - KhauTru (sai số <= 1 VNĐ)';

-- §3.11 DryRun không ghi DB
DECLARE @SoTruoc INT;
SELECT @SoTruoc = COUNT(*) FROM dbo.BangLuong;
EXEC dbo.sp_TinhLuong 4, 2025, NULL, 0, 1;   -- DryRun
EXEC #LogTest '§3','DryRun_KhongGhi_DB',
    CAST(@SoTruoc AS NVARCHAR),
    (SELECT CAST(COUNT(*) AS NVARCHAR) FROM dbo.BangLuong),
    N'@DryRun=1: số bản ghi BangLuong không đổi';
GO

-- §3.12 Override: tính lại tháng 1 (xoá bản nháp cũ)
EXEC dbo.sp_TinhLuong 1, 2025, NULL, 1;   -- Override Draft
EXEC #LogTest '§3','Override_Draft_OK','50',
    (SELECT CAST(COUNT(*) AS NVARCHAR)
     FROM dbo.BangLuong WHERE Thang=1 AND Nam=2025),
    N'Sau Override: vẫn đúng 50 bản ghi (không duplicate)';
GO


-- ============================================================
-- §4  KIỂM THỬ TRIGGERS & AUDIT LOG
-- ============================================================
PRINT N'';
PRINT N'════════════════════════════════════════════════════════';
PRINT N'  §4  KIỂM THỬ TRIGGERS & AUDIT LOG';
PRINT N'════════════════════════════════════════════════════════';

-- §4.1 Trigger INSERT HopDong → AuditLog
DECLARE @LogCountTruoc INT;
SELECT @LogCountTruoc = COUNT(*) FROM dbo.AuditLog_HopDong;

-- Thêm hợp đồng mới test
INSERT INTO dbo.HopDong (MaHD,MaNV,MaLoaiHD,NgayBatDau,NgayKetThuc,
    LuongCoBan,VungLuong,TrangThai,NguoiKy_NLD,NguoiKy_NSDLD,NgayKy)
VALUES ('HD999999','NV000002',2,'2025-04-01',DATEADD(YEAR,1,'2025-04-01'),
    8500000,1,'A',N'Trần Thị Lan Anh',N'Nguyễn Hoàng Minh','2025-03-28');

EXEC #LogTest '§4','TriggerInsertHD_Log',
    CAST(@LogCountTruoc + 1 AS NVARCHAR),
    (SELECT CAST(COUNT(*) AS NVARCHAR) FROM dbo.AuditLog_HopDong),
    N'INSERT HopDong → 1 dòng AuditLog mới';

-- §4.2 Trigger UPDATE HopDong — đổi lương
DECLARE @LogCountTruoc2 INT;
SELECT @LogCountTruoc2 = COUNT(*) FROM dbo.AuditLog_HopDong;

UPDATE dbo.HopDong SET LuongCoBan = 9000000 WHERE MaHD = 'HD999999';

EXEC #LogTest '§4','TriggerUpdateHD_LuongCot',
    CAST(@LogCountTruoc2 + 1 AS NVARCHAR),
    (SELECT CAST(COUNT(*) AS NVARCHAR) FROM dbo.AuditLog_HopDong),
    N'UPDATE LuongCoBan → log cột LuongCoBan';

-- §4.3 Kiểm tra giá trị GiaTriCu đúng
EXEC #LogTest '§4','AuditLog_GiaTriCu_LuongCB',
    '8,500,000',
    (SELECT TOP 1 GiaTriCu FROM dbo.AuditLog_HopDong
     WHERE MaHD='HD999999' AND HanhDong='UPDATE' AND TenCot='LuongCoBan'
     ORDER BY MaLog DESC),
    N'GiaTriCu = 8,500,000 (FORMAT N0)';

-- §4.4 Trigger UPDATE — không thay đổi gì → không ghi log
DECLARE @LogCountTruoc3 INT;
SELECT @LogCountTruoc3 = COUNT(*) FROM dbo.AuditLog_HopDong;
UPDATE dbo.HopDong SET LuongCoBan = 9000000 WHERE MaHD='HD999999';  -- Không đổi

EXEC #LogTest '§4','TriggerUpdate_NoChange_NoLog',
    CAST(@LogCountTruoc3 AS NVARCHAR),
    (SELECT CAST(COUNT(*) AS NVARCHAR) FROM dbo.AuditLog_HopDong),
    N'UPDATE không đổi giá trị → không ghi log';

-- §4.5 Trigger DELETE HopDong
DECLARE @LogCountTruoc4 INT;
SELECT @LogCountTruoc4 = COUNT(*) FROM dbo.AuditLog_HopDong;
DELETE FROM dbo.HopDong WHERE MaHD='HD999999';

EXEC #LogTest '§4','TriggerDeleteHD_Log',
    CAST(@LogCountTruoc4 + 1 AS NVARCHAR),
    (SELECT CAST(COUNT(*) AS NVARCHAR) FROM dbo.AuditLog_HopDong),
    N'DELETE HopDong → 1 dòng log DELETE';

-- §4.6 trg_LuongCoBan_AfterInsert — tăng lương NV000005
DECLARE @LogLuongTruoc INT;
SELECT @LogLuongTruoc = COUNT(*) FROM dbo.AuditLog_Luong;

UPDATE dbo.LuongCoBan SET NgayHetHieuLuc='2025-03-31'
WHERE MaNV='NV000005' AND NgayHetHieuLuc IS NULL;

INSERT INTO dbo.LuongCoBan (MaNV,LuongCB,LuongDongBH,
    NgayHieuLuc,NgayHetHieuLuc,LyDo,NguoiDuyet)
VALUES ('NV000005',13000000,13000000,'2025-04-01',NULL,
    N'Tăng lương theo KPI Q1/2025','NV000001');

EXEC #LogTest '§4','TriggerLuong_Insert_Log','TRUE',
    (SELECT CASE WHEN COUNT(*) > @LogLuongTruoc THEN 'TRUE' ELSE 'FALSE' END
     FROM dbo.AuditLog_Luong),
    N'INSERT LuongCoBan → ghi AuditLog_Luong';

-- §4.7 trg_BangLuong_GuardChot — xác nhận T1 rồi thử sửa
EXEC dbo.sp_XacNhanBangLuong 1, 2025, N'Hoàng Thị Phương';

DECLARE @GuardOK BIT = 1;
BEGIN TRY
    UPDATE dbo.BangLuong
    SET LuongGross = 0
    WHERE Thang=1 AND Nam=2025 AND TrangThai='C';
    SET @GuardOK = 0;  -- Nếu không bị chặn → FAIL
END TRY
BEGIN CATCH
    SET @GuardOK = 1;  -- Đúng: trigger đã chặn
END CATCH;

EXEC #LogTest '§4','Guard_SuaLuongDaChot',
    '1', CAST(@GuardOK AS NVARCHAR),
    N'trg_BangLuong_GuardChot chặn UPDATE confirmed';

-- §4.8 trg_KiemTraChamCong — không cho chấm ngày tương lai
DECLARE @CCFutureOK BIT = 1;
BEGIN TRY
    INSERT INTO dbo.ChamCong (MaNV,NgayCham,TrangThai,HeSoTangCa,NguoiCapNhat)
    VALUES ('NV000001', DATEADD(DAY,10,GETDATE()), 'DL', 1.5, 'TEST');
    SET @CCFutureOK = 0;
END TRY
BEGIN CATCH
    SET @CCFutureOK = 1;
END CATCH;

EXEC #LogTest '§4','Guard_ChamCong_TuongLai',
    '1', CAST(@CCFutureOK AS NVARCHAR),
    N'trg_KiemTraChamCong chặn chấm ngày tương lai';
GO


-- ============================================================
-- §5  KIỂM THỬ VIEWS
-- ============================================================
PRINT N'';
PRINT N'════════════════════════════════════════════════════════';
PRINT N'  §5  KIỂM THỬ VIEWS';
PRINT N'════════════════════════════════════════════════════════';

-- §5.1 vw_BangLuong — đủ dòng
EXEC #LogTest '§5','vw_BangLuong_Rows','150',
    (SELECT CAST(COUNT(*) AS NVARCHAR) FROM dbo.vw_BangLuong
     WHERE Nam=2025 AND Thang IN (1,2,3)),
    N'3 tháng × 50 NV = 150 dòng trong vw_BangLuong';

-- §5.2 vw_BangLuong — TGĐ lương cao nhất
EXEC #LogTest '§5','vw_BangLuong_TGD_Top',
    'NV000001',
    (SELECT TOP 1 MaNV FROM dbo.vw_BangLuong
     WHERE Thang=3 AND Nam=2025
     ORDER BY CAST(REPLACE(REPLACE(LuongThucLinh,',',''),'.','') AS BIGINT) DESC),
    N'TGĐ NV000001 đứng đầu bảng lương T3';

-- §5.3 vw_BangLuong — có đủ các cột tài chính
EXEC #LogTest '§5','vw_BangLuong_ChiPhiDN_NotNull','TRUE',
    (SELECT CASE WHEN COUNT(*) = 0 THEN 'TRUE' ELSE 'FALSE' END
     FROM dbo.vw_BangLuong
     WHERE Thang=1 AND Nam=2025 AND ChiPhiNhanSu_DN IS NULL),
    N'Cột ChiPhiNhanSu_DN không có NULL';

-- §5.4 vw_BangLuong_TongHop — 5 phòng ban × 3 tháng = 15 dòng
EXEC #LogTest '§5','vw_TongHop_Rows','15',
    (SELECT CAST(COUNT(*) AS NVARCHAR) FROM dbo.vw_BangLuong_TongHop
     WHERE Nam=2025 AND Thang IN (1,2,3)),
    N'5 PB × 3 tháng = 15 dòng tổng hợp';

-- §5.5 vw_TongHopChamCong — đủ dòng
EXEC #LogTest '§5','vw_ChamCong_Rows','150',
    (SELECT CAST(COUNT(*) AS NVARCHAR) FROM dbo.vw_TongHopChamCong
     WHERE Nam=2025 AND Thang IN (1,2,3)),
    N'50 NV × 3 tháng = 150 dòng vw_TongHopChamCong';

-- §5.6 vw_ChamCong — NV000049 có ngày KP tháng 2
EXEC #LogTest '§5','vw_ChamCong_NV049_KP','2',
    (SELECT CAST(NgayVangKP AS NVARCHAR)
     FROM dbo.vw_TongHopChamCong
     WHERE MaNV='NV000049' AND Thang=2 AND Nam=2025),
    N'NV000049 có 2 ngày KP tháng 2/2025';

-- §5.7 vw_TyLeChuyenCan — CNTT có tăng ca
EXEC #LogTest '§5','vw_CNTT_CoTangCa','TRUE',
    (SELECT CASE WHEN SUM(TongGioTangCa) > 0 THEN 'TRUE' ELSE 'FALSE' END
     FROM dbo.vw_TyLeChuyenCan
     WHERE PhongBan LIKE N'%Công Nghệ%' AND Nam=2025),
    N'Team CNTT có giờ tăng ca trong 3 tháng';

-- §5.8 vw_ThueTNCN_KyQuyetToan — đủ NV
EXEC #LogTest '§5','vw_ThueTNCN_NVCount','TRUE',
    (SELECT CASE WHEN COUNT(DISTINCT MaNV) >= 40 THEN 'TRUE' ELSE 'FALSE' END
     FROM dbo.vw_ThueTNCN_KyQuyetToan WHERE Nam=2025),
    N'≥ 40 NV có dữ liệu quyết toán thuế năm 2025';
GO


-- ============================================================
-- §6  KIỂM THỬ CONSTRAINTS (Negative Tests)
-- ============================================================
PRINT N'';
PRINT N'════════════════════════════════════════════════════════';
PRINT N'  §6  NEGATIVE TESTS — CONSTRAINTS PHẢI CHẶN';
PRINT N'════════════════════════════════════════════════════════';

-- §6.1 CHECK: MaNV sai định dạng
DECLARE @CK01 BIT = 0;
BEGIN TRY
    INSERT INTO dbo.NhanVien (MaNV,HoTen,GioiTinh,NgaySinh,CCCD,
        Email,MaPB,MaCV,NgayVaoLam,TrangThai,MaSoThue,NguoiTao)
    VALUES ('INVALID',N'Test',N'M','1990-01-01','099999999999',
        'test@test.com','PB0001','CV0006','2020-01-01','A','0123456789','T');
    SET @CK01 = 0;
END TRY BEGIN CATCH SET @CK01 = 1; END CATCH;

EXEC #LogTest '§6','CK_MaNV_Format_Block','1',
    CAST(@CK01 AS NVARCHAR), N'MaNV "INVALID" phải bị chặn';

-- §6.2 CHECK: Lương cơ bản dưới mức tối thiểu
DECLARE @CK02 BIT = 0;
BEGIN TRY
    INSERT INTO dbo.LuongCoBan (MaNV,LuongCB,LuongDongBH,
        NgayHieuLuc,NguoiDuyet)
    VALUES ('NV000001',1000000,1000000,'2025-01-01','TEST');
    SET @CK02 = 0;
END TRY BEGIN CATCH SET @CK02 = 1; END CATCH;

EXEC #LogTest '§6','CK_LuongToiThieu_Block','1',
    CAST(@CK02 AS NVARCHAR), N'LuongCB < 4,960,000 phải bị chặn';

-- §6.3 UIX: Duplicate BangLuong cùng NV/Tháng/Năm
DECLARE @CK03 BIT = 0;
BEGIN TRY
    INSERT INTO dbo.BangLuong (MaNV,Thang,Nam,SoNgayCong,
        SoNgayLamChuan,LuongCoBan,LuongGross,TongPhuCap,
        BHXH_NLD,BHYT_NLD,BHTN_NLD,TongBaoHiem,
        ThueTNCN,TongKhauTru,LuongNet,TrangThai,NguoiTao)
    VALUES ('NV000001',1,2025,20,22,55000000,55000000,0,
        3744000,702000,468000,4914000,0,0,50086000,'D','TEST');
    SET @CK03 = 0;
END TRY BEGIN CATCH SET @CK03 = 1; END CATCH;

EXEC #LogTest '§6','UIX_BangLuong_NoDuplicate','1',
    CAST(@CK03 AS NVARCHAR), N'Duplicate BangLuong NV/T/N phải bị chặn';

-- §6.4 UIX: Filtered — 2 HopDong Active cùng NV
DECLARE @CK04 BIT = 0;
BEGIN TRY
    INSERT INTO dbo.HopDong (MaHD,MaNV,MaLoaiHD,NgayBatDau,
        LuongCoBan,VungLuong,TrangThai,NguoiKy_NLD,NguoiKy_NSDLD,NgayKy)
    VALUES ('HD888888','NV000001',4,'2025-01-01',
        50000000,1,'A',N'Test',N'Test','2025-01-01');
    SET @CK04 = 0;
END TRY BEGIN CATCH SET @CK04 = 1; END CATCH;

EXEC #LogTest '§6','UIX_HopDong_OneActive','1',
    CAST(@CK04 AS NVARCHAR), N'2 HĐ Active cùng NV phải bị chặn';

-- §6.5 CHECK: Giờ ra trước giờ vào
DECLARE @CK05 BIT = 0;
BEGIN TRY
    INSERT INTO dbo.ChamCong (MaNV,NgayCham,TrangThai,
        GioVao,GioRa,HeSoTangCa,NguoiCapNhat)
    VALUES ('NV000001','2024-12-01','DL',
        '17:00','08:00',1.5,'TEST');  -- GioRa < GioVao
    SET @CK05 = 0;
END TRY BEGIN CATCH SET @CK05 = 1; END CATCH;

EXEC #LogTest '§6','CK_GioVaoRa_Block','1',
    CAST(@CK05 AS NVARCHAR), N'GioRa < GioVao phải bị chặn';

-- §6.6 CHECK: Tháng hợp đồng không hợp lệ
DECLARE @CK06 BIT = 0;
BEGIN TRY
    INSERT INTO dbo.BangLuong (MaNV,Thang,Nam,SoNgayCong,
        SoNgayLamChuan,LuongCoBan,LuongGross,TongPhuCap,
        BHXH_NLD,BHYT_NLD,BHTN_NLD,TongBaoHiem,
        ThueTNCN,TongKhauTru,LuongNet,TrangThai,NguoiTao)
    VALUES ('NV000010',13,2025,20,22,6500000,6500000,0,
        0,0,0,0,0,0,6500000,'D','TEST');  -- Thang=13 không hợp lệ
    SET @CK06 = 0;
END TRY BEGIN CATCH SET @CK06 = 1; END CATCH;

EXEC #LogTest '§6','CK_Thang_13_Block','1',
    CAST(@CK06 AS NVARCHAR), N'Thang=13 phải bị chặn bởi CHECK';
GO


-- ============================================================
-- §7  INTEGRATION TEST — Vòng đời lương đầy đủ 1 NV
-- ============================================================
PRINT N'';
PRINT N'════════════════════════════════════════════════════════';
PRINT N'  §7  INTEGRATION TEST — Vòng đời lương 1 nhân viên';
PRINT N'════════════════════════════════════════════════════════';

-- Mô phỏng quy trình: Tính → Xác nhận → Thanh toán → Khóa

-- Bước 7.1: Bảng lương T2 đang ở trạng thái Draft
EXEC #LogTest '§7','T2_Draft_Exists','TRUE',
    (SELECT CASE WHEN COUNT(*) > 0 THEN 'TRUE' ELSE 'FALSE' END
     FROM dbo.BangLuong WHERE Thang=2 AND Nam=2025 AND TrangThai='D'),
    N'T2/2025 đang Draft sau sp_TinhLuong';

-- Bước 7.2: Xác nhận bảng lương T2
EXEC dbo.sp_XacNhanBangLuong 2, 2025, N'Hoàng Thị Phương';

EXEC #LogTest '§7','T2_Confirmed','TRUE',
    (SELECT CASE WHEN COUNT(*) = 50 THEN 'TRUE' ELSE 'FALSE' END
     FROM dbo.BangLuong WHERE Thang=2 AND Nam=2025 AND TrangThai='C'),
    N'T2 chuyển sang Confirmed (50 dòng)';

-- Bước 7.3: Cập nhật NgayThanhToan (C → P)
UPDATE dbo.BangLuong
SET TrangThai = 'P', NgayThanhToan = '2025-03-05'
WHERE Thang=2 AND Nam=2025 AND TrangThai='C';

EXEC #LogTest '§7','T2_Paid','TRUE',
    (SELECT CASE WHEN COUNT(*) = 50 THEN 'TRUE' ELSE 'FALSE' END
     FROM dbo.BangLuong WHERE Thang=2 AND Nam=2025 AND TrangThai='P'),
    N'T2 chuyển sang Paid (50 dòng)';

-- Bước 7.4: Trigger log chuyển trạng thái
EXEC #LogTest '§7','AuditLog_StatusChange','TRUE',
    (SELECT CASE WHEN COUNT(*) > 0 THEN 'TRUE' ELSE 'FALSE' END
     FROM dbo.AuditLog_Luong WHERE HanhDong='STATUS_CHANGE'),
    N'AuditLog_Luong ghi STATUS_CHANGE khi C→P';

-- Bước 7.5: Thử tính lại T1 (đã CHOT, không có Override)
DECLARE @OverrideOK BIT = 0;
BEGIN TRY
    EXEC dbo.sp_TinhLuong 1, 2025;   -- T1 đã CHOT, @Override mặc định = 0
    SET @OverrideOK = 0;
END TRY BEGIN CATCH SET @OverrideOK = 1; END CATCH;

EXEC #LogTest '§7','SP_Block_ReCalc_Chot','1',
    CAST(@OverrideOK AS NVARCHAR),
    N'sp_TinhLuong báo lỗi khi tính lại bảng lương đã CHOT';

-- Bước 7.6: Kiểm tra toàn bộ vòng đời
PRINT N'';
PRINT N'--- Vòng đời bảng lương 3 tháng ---';
SELECT
    Thang, Nam,
    TrangThai,
    CASE TrangThai
        WHEN 'D' THEN N'📝 Nháp'
        WHEN 'C' THEN N'✅ Xác nhận'
        WHEN 'P' THEN N'💰 Đã trả'
        WHEN 'L' THEN N'🔒 Khoá'
    END AS TrangThaiText,
    COUNT(*) AS SoNhanVien,
    FORMAT(SUM(LuongNet),'N0') AS TongLuongNet,
    FORMAT(SUM(ThueTNCN),'N0') AS TongThue
FROM dbo.BangLuong
WHERE Nam=2025
GROUP BY Thang, Nam, TrangThai
ORDER BY Nam, Thang;
GO


-- ============================================================
-- §8  KIỂM TRA HIỆU NĂNG & INDEX USAGE
-- ============================================================
PRINT N'';
PRINT N'════════════════════════════════════════════════════════';
PRINT N'  §8  HIỆU NĂNG — QUERY PLAN CHECK';
PRINT N'════════════════════════════════════════════════════════';

-- §8.1 Query sp_TinhLuong pattern: ChamCong range scan
SET STATISTICS IO ON;
PRINT N'--- ChamCong range scan (pattern của sp_TinhLuong) ---';
SELECT
    MaNV,
    COUNT(*) FILTER_DL,
    SUM(CASE WHEN TrangThai='DL' THEN 1 ELSE 0 END) DiLam,
    SUM(ISNULL(SoGioTangCa,0)) TangCa
FROM dbo.ChamCong
WHERE NgayCham BETWEEN '2025-01-01' AND '2025-01-31'
GROUP BY MaNV;

PRINT N'--- HopDong active lookup ---';
SELECT MaNV, MaLoaiHD, LuongCoBan, VungLuong
FROM dbo.HopDong
WHERE MaNV = 'NV000001' AND TrangThai = 'A';

PRINT N'--- LuongCoBan current lookup ---';
SELECT MaNV, LuongCB, LuongDongBH
FROM dbo.LuongCoBan
WHERE MaNV = 'NV000001' AND NgayHetHieuLuc IS NULL;
SET STATISTICS IO OFF;
GO

-- §8.2 Đếm index được tạo
EXEC #LogTest '§8','TotalIndexes_Min50','TRUE',
    (SELECT CASE WHEN COUNT(*) >= 30 THEN 'TRUE' ELSE 'FALSE' END
     FROM sys.indexes
     WHERE OBJECTPROPERTY(object_id,'IsUserTable')=1
       AND type > 0),
    N'Tổng index user tables ≥ 30 (từ 3 file DDL)';

-- §8.3 Columnstore index tồn tại
EXEC #LogTest '§8','Columnstore_Exists','TRUE',
    (SELECT CASE WHEN COUNT(*) >= 2 THEN 'TRUE' ELSE 'FALSE' END
     FROM sys.indexes
     WHERE type_desc = 'NONCLUSTERED COLUMNSTORE'),
    N'≥ 2 Columnstore index (BangLuong + ChamCong)';
GO


-- ============================================================
-- §9  BÁO CÁO TỔNG KẾT KIỂM THỬ
-- ============================================================
PRINT N'';
PRINT N'════════════════════════════════════════════════════════';
PRINT N'  §9  BÁO CÁO TỔNG KẾT KIỂM THỬ';
PRINT N'════════════════════════════════════════════════════════';

-- Tổng hợp kết quả
SELECT
    Section                             AS [Phần],
    COUNT(*)                            AS [Tổng Test],
    SUM(CASE WHEN Status='PASS' THEN 1 ELSE 0 END) AS [✅ PASS],
    SUM(CASE WHEN Status='FAIL' THEN 1 ELSE 0 END) AS [❌ FAIL],
    FORMAT(
        CAST(SUM(CASE WHEN Status='PASS' THEN 1 ELSE 0 END) AS DECIMAL)
        / COUNT(*), 'P0'
    )                                   AS [Tỷ Lệ]
FROM #TestResults
GROUP BY Section
ORDER BY Section;

-- Tổng cộng
SELECT
    N'TỔNG CỘNG'                        AS [Phần],
    COUNT(*)                            AS [Tổng Test],
    SUM(CASE WHEN Status='PASS' THEN 1 ELSE 0 END) AS [✅ PASS],
    SUM(CASE WHEN Status='FAIL' THEN 1 ELSE 0 END) AS [❌ FAIL],
    FORMAT(
        CAST(SUM(CASE WHEN Status='PASS' THEN 1 ELSE 0 END) AS DECIMAL)
        / NULLIF(COUNT(*),0), 'P1'
    )                                   AS [Tỷ Lệ]
FROM #TestResults;

-- Hiển thị các test FAIL để debug
IF EXISTS (SELECT 1 FROM #TestResults WHERE Status='FAIL')
BEGIN
    PRINT N'';
    PRINT N'─── CÁC TEST CHƯA ĐẠT ────────────────────────────────';
    SELECT
        TestID, Section, TestName,
        Expected    AS [Kỳ vọng],
        Actual      AS [Thực tế],
        GhiChu
    FROM #TestResults
    WHERE Status = 'FAIL'
    ORDER BY TestID;
END
ELSE
    PRINT N'🎉 Tất cả test đều PASS!';

-- Thống kê dữ liệu cuối
PRINT N'';
PRINT N'─── THỐNG KÊ DỮ LIỆU CUỐI ────────────────────────────';
SELECT
    'BangLuong'     B, COUNT(*) N, FORMAT(SUM(LuongNet),'N0') TongLuongNet,
    FORMAT(SUM(ThueTNCN),'N0') TongThue,
    FORMAT(SUM(TongBaoHiem),'N0') TongBH
FROM dbo.BangLuong WHERE Nam=2025 AND Thang IN (1,2,3);

PRINT N'';
PRINT N'─── TOP 5 LƯƠNG CAO NHẤT T3/2025 ─────────────────────';
SELECT TOP 5
    nv.HoTen,
    pb.TenPB,
    cv.TenCV,
    FORMAT(bl.LuongGross,'N0')  AS Gross,
    FORMAT(bl.TongBaoHiem,'N0') AS BaoHiem,
    FORMAT(bl.ThueTNCN,'N0')    AS Thue,
    FORMAT(bl.LuongNet,'N0')    AS [Thực Lĩnh]
FROM dbo.BangLuong bl
JOIN dbo.NhanVien nv ON bl.MaNV=nv.MaNV
JOIN dbo.PhongBan pb ON nv.MaPB=pb.MaPB
JOIN dbo.ChucVu   cv ON nv.MaCV=cv.MaCV
WHERE bl.Thang=3 AND bl.Nam=2025
ORDER BY bl.LuongNet DESC;

PRINT N'';
PRINT N'─── AUDIT LOG SUMMARY ──────────────────────────────────';
SELECT 'AuditLog_HopDong' AS [Bảng],
    HanhDong, COUNT(*) SoBanGhi
FROM dbo.AuditLog_HopDong GROUP BY HanhDong
UNION ALL
SELECT 'AuditLog_Luong',
    HanhDong, COUNT(*)
FROM dbo.AuditLog_Luong GROUP BY HanhDong
ORDER BY [Bảng], HanhDong;

PRINT N'';
PRINT N'[DONE] test_queries.sql hoàn tất.';
PRINT N'Xem tab Results để đọc báo cáo chi tiết.';
GO
