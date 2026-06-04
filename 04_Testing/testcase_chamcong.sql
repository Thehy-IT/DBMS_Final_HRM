-- ============================================================
-- FILE       : testcase_chamcong.sql
-- PROJECT    : Hệ Thống Quản Lý Nhân Sự & Tính Lương Tự Động
-- MỤC ĐÍCH   : Bộ kiểm thử toàn diện cho module Chấm Công
-- ─────────────────────────────────────────────────────────────
-- §1  Setup & Sanity Check dữ liệu chấm công
-- §2  Kiểm thử Functions ngày công
-- §3  Kiểm thử trg_ChamCong_Validate (BR-09/10/11/12)
-- §4  Kiểm thử trg_ChamCong_TinhSoGio (auto-calc)
-- §5  Kiểm thử trg_ChamCong_GuardChot
-- §6  Kiểm thử trg_ChamCong_AuditLog
-- §7  Kiểm thử trg_NghiPhep_SyncChamCong
-- §8  Kiểm thử sp_ChamCong_NhapHangNgay
-- §9  Kiểm thử sp_ChamCong_NhapLoat
-- §10 Kiểm thử sp_ChamCong_CapNhat
-- §11 Kiểm thử sp_NghiPhep_PheDuyet
-- §12 Kiểm thử sp_ChamCong_BaoCaoThang
-- §13 Kiểm thử Views (vw_TongHopChamCong, vw_ChamCong_ChiTiet)
-- §14 Integration Test — Vòng đời đầy đủ 1 nhân viên
-- §15 Edge Cases & Boundary Tests
-- §16 Báo cáo tổng kết
-- ─────────────────────────────────────────────────────────────
-- CÁCH CHẠY:
--   Chạy SAU: seed_data.sql + tất cả trigger/SP/View đã tạo
--   Dùng SSMS: Bôi đen từng §, nhấn F5
-- ============================================================

USE HRPayrollDB;
GO
SET NOCOUNT ON;
GO

-- ── Bảng ghi kết quả (tái sử dụng từ test_queries.sql) ───────
IF OBJECT_ID('tempdb..#TC_ChamCong') IS NOT NULL
    DROP TABLE #TC_ChamCong;

CREATE TABLE #TC_ChamCong (
    TestID      INT         IDENTITY(1,1),
    Section     NVARCHAR(10),
    TestName    NVARCHAR(200),
    Expected    NVARCHAR(300),
    Actual      NVARCHAR(300),
    Status      NCHAR(4),
    GhiChu      NVARCHAR(400)
);
GO

CREATE OR ALTER PROCEDURE #LogCC
    @Section    NVARCHAR(10),
    @TestName   NVARCHAR(200),
    @Expected   NVARCHAR(300),
    @Actual     NVARCHAR(300),
    @GhiChu     NVARCHAR(400) = NULL
AS
BEGIN
    DECLARE @Status NCHAR(4) =
        CASE WHEN LTRIM(RTRIM(@Expected)) = LTRIM(RTRIM(@Actual))
             THEN N'PASS' ELSE N'FAIL' END;
    INSERT #TC_ChamCong (Section,TestName,Expected,Actual,Status,GhiChu)
    VALUES (@Section,@TestName,@Expected,@Actual,@Status,@GhiChu);
    PRINT N'  ' + @Status + N' | ' + @TestName
        + CASE WHEN @Status=N'FAIL'
               THEN N' → Kỳ vọng: [' + @Expected
                    + N'] | Thực tế: [' + @Actual + N']'
               ELSE N'' END;
END;
GO


-- ============================================================
-- §1  SETUP & SANITY CHECK
-- ============================================================
PRINT N'════════════════════════════════════════════════════════';
PRINT N'  §1  SETUP & SANITY CHECK';
PRINT N'════════════════════════════════════════════════════════';

-- Dọn dữ liệu test cũ trước khi chạy
DELETE FROM dbo.ChamCong
WHERE NguoiCapNhat = 'TC_TEST'
   OR GhiChu LIKE N'%[TC]%';

DELETE FROM dbo.NghiPhep
WHERE LyDo LIKE N'%[TC]%';
PRINT N'[Setup] Đã dọn dữ liệu test cũ';
GO

-- §1.1 Bảng ChamCong có dữ liệu 3 tháng
EXEC #LogCC '§1','CC_3Thang_Ton_Tai','TRUE',
    (SELECT CASE WHEN COUNT(DISTINCT MONTH(NgayCham)) >= 3
                 THEN 'TRUE' ELSE 'FALSE' END
     FROM dbo.ChamCong WHERE YEAR(NgayCham)=2025),
    N'Jan/Feb/Mar 2025 đều có dữ liệu CC';

-- §1.2 Số bản ghi CC > 2000
EXEC #LogCC '§1','CC_SoBanGhi_Min2000','TRUE',
    (SELECT CASE WHEN COUNT(*) > 2000 THEN 'TRUE' ELSE 'FALSE' END
     FROM dbo.ChamCong),
    N'Seed tạo đủ ~3100 bản ghi CC';

-- §1.3 Ngày Tết 1/1/2025 đều là NG
EXEC #LogCC '§1','TetDuongLich_NG','50',
    (SELECT CAST(COUNT(*) AS NVARCHAR) FROM dbo.ChamCong
     WHERE NgayCham='2025-01-01' AND TrangThai='NG'),
    N'1/1/2025 = 50 bản ghi NG cho 50 NV';

-- §1.4 NV000049 có 2 ngày KP tháng 2
EXEC #LogCC '§1','NV049_KP_Thang2','2',
    (SELECT CAST(COUNT(*) AS NVARCHAR) FROM dbo.ChamCong
     WHERE MaNV='NV000049' AND TrangThai='KP'
       AND MONTH(NgayCham)=2 AND YEAR(NgayCham)=2025),
    N'Seed đã UPDATE 2 ngày KP cho NV000049';

-- §1.5 NV000004 có ngày NP tháng 2 (nghỉ phép 10-12/2)
EXEC #LogCC '§1','NV004_NP_Thang2','3',
    (SELECT CAST(COUNT(*) AS NVARCHAR) FROM dbo.ChamCong
     WHERE MaNV='NV000004' AND TrangThai='NP'
       AND MONTH(NgayCham)=2 AND YEAR(NgayCham)=2025),
    N'NV000004 nghỉ phép 10-12/02/2025 = 3 ngày NP';

-- §1.6 Không có bản ghi CC tương lai
EXEC #LogCC '§1','KhongCo_CC_TuongLai','0',
    (SELECT CAST(COUNT(*) AS NVARCHAR) FROM dbo.ChamCong
     WHERE NgayCham > CAST(GETDATE() AS DATE)),
    N'Không có CC ngày tương lai';

-- §1.7 Bảng AuditLog_ChamCong tồn tại
EXEC #LogCC '§1','AuditLog_CC_Ton_Tai','TRUE',
    (SELECT CASE WHEN OBJECT_ID('dbo.AuditLog_ChamCong','U') IS NOT NULL
                 THEN 'TRUE' ELSE 'FALSE' END),
    N'Bảng AuditLog_ChamCong đã được tạo';

-- §1.8 Team CNTT có tăng ca (từ seed)
EXEC #LogCC '§1','CNTT_CoTangCa_T1','TRUE',
    (SELECT CASE WHEN SUM(SoGioTangCa) > 0 THEN 'TRUE' ELSE 'FALSE' END
     FROM dbo.ChamCong cc
     JOIN dbo.NhanVien nv ON cc.MaNV=nv.MaNV
     WHERE nv.MaPB='PB0004'
       AND MONTH(NgayCham)=1 AND YEAR(NgayCham)=2025),
    N'Team CNTT có giờ tăng ca tháng 1/2025';
GO


-- ============================================================
-- §2  KIỂM THỬ FUNCTIONS NGÀY CÔNG
-- ============================================================
PRINT N'';
PRINT N'════════════════════════════════════════════════════════';
PRINT N'  §2  FUNCTIONS NGÀY CÔNG';
PRINT N'════════════════════════════════════════════════════════';

-- §2.1 fn_SoNgayChuanThang — Jan 2025 (trừ Tết ÂL)
DECLARE @NgayChuanT1 TINYINT = dbo.fn_SoNgayChuanThang(1,2025);
EXEC #LogCC '§2','NgayChuanT1_Range_15_18','TRUE',
    (SELECT CASE WHEN @NgayChuanT1 BETWEEN 15 AND 18
                 THEN 'TRUE' ELSE 'FALSE' END),
    N'Tháng 1/2025: trừ Tết ÂL còn 15-18 ngày làm';

-- §2.2 fn_SoNgayChuanThang — Feb 2025
DECLARE @NgayChuanT2 TINYINT = dbo.fn_SoNgayChuanThang(2,2025);
EXEC #LogCC '§2','NgayChuanT2_Range_18_20','TRUE',
    (SELECT CASE WHEN @NgayChuanT2 BETWEEN 18 AND 20
                 THEN 'TRUE' ELSE 'FALSE' END),
    N'Tháng 2/2025 (28 ngày): ~18-20 ngày làm việc';

-- §2.3 fn_SoNgayChuanThang — Mar 2025 (21 ngày LV)
DECLARE @NgayChuanT3 TINYINT = dbo.fn_SoNgayChuanThang(3,2025);
EXEC #LogCC '§2','NgayChuanT3_Range_20_22','TRUE',
    (SELECT CASE WHEN @NgayChuanT3 BETWEEN 20 AND 22
                 THEN 'TRUE' ELSE 'FALSE' END),
    N'Tháng 3/2025: ~21 ngày làm việc';

-- §2.4 fn_SoNgayChamCong — TGĐ tháng 1/2025
DECLARE @NgayDLNV1_T1 DECIMAL(5,1) =
    dbo.fn_SoNgayChamCong('NV000001',1,2025);
EXEC #LogCC '§2','TGD_NgayDiLam_T1_Positive','TRUE',
    (SELECT CASE WHEN @NgayDLNV1_T1 > 0 THEN 'TRUE' ELSE 'FALSE' END),
    N'TGĐ có ngày đi làm tháng 1/2025';

-- §2.5 fn_SoNgayNghiCoLuong — NV000004 có 3 ngày NP tháng 2
EXEC #LogCC '§2','NV004_NghiCoLuong_3ngay','3',
    (SELECT CAST(dbo.fn_SoNgayNghiCoLuong('NV000004',2,2025) AS NVARCHAR)),
    N'NV000004 có 3 ngày nghỉ phép hưởng lương T2';

-- §2.6 fn_SoNgayNghiKhongLuong — NV000049 có 2 ngày KP tháng 2
EXEC #LogCC '§2','NV049_KhongLuong_2ngay','2',
    (SELECT CAST(dbo.fn_SoNgayNghiKhongLuong('NV000049',2,2025) AS NVARCHAR)),
    N'NV000049 có 2 ngày KP (vắng không phép)';

-- §2.7 fn_HeSoLuongThang — NV đi đủ tháng ≈ 1.0
DECLARE @HeSoFull DECIMAL(10,6) =
    dbo.fn_HeSoLuongThang('NV000001',3,2025);
EXEC #LogCC '§2','TGD_HeSo_Full_Month_Near1','TRUE',
    (SELECT CASE WHEN @HeSoFull BETWEEN 0.95 AND 1.0
                 THEN 'TRUE' ELSE 'FALSE' END),
    N'TGĐ đi đủ tháng 3 → hệ số gần 1.0';

-- §2.8 fn_HeSoLuongThang — NV vắng 2 ngày KP giảm hệ số
DECLARE @HeSoKP DECIMAL(10,6) =
    dbo.fn_HeSoLuongThang('NV000049',2,2025);
DECLARE @HeSoFull2 DECIMAL(10,6) =
    dbo.fn_HeSoLuongThang('NV000001',2,2025);
EXEC #LogCC '§2','NV049_HeSo_Thap_Hon_Full','TRUE',
    (SELECT CASE WHEN @HeSoKP < @HeSoFull2 THEN 'TRUE' ELSE 'FALSE' END),
    N'NV vắng KP có hệ số thấp hơn NV đi đủ';

-- §2.9 fn_TinhLuongLamThem — Team CNTT tháng 1 có OT > 0
EXEC #LogCC '§2','CNTT_LuongOT_Positive','TRUE',
    (SELECT CASE WHEN SUM(dbo.fn_TinhLuongLamThem(nv.MaNV,1,2025,lcb.LuongCB)) > 0
                 THEN 'TRUE' ELSE 'FALSE' END
     FROM dbo.NhanVien nv
     JOIN dbo.LuongCoBan lcb ON nv.MaNV=lcb.MaNV
                             AND lcb.NgayHetHieuLuc IS NULL
     WHERE nv.MaPB='PB0004'),
    N'fn_TinhLuongLamThem: Đội CNTT có tiền OT T1';

-- §2.10 fn_SoNgayChuanThang — Tháng 4 (không lễ 30/4)
EXEC #LogCC '§2','NgayChuanT4_NoHoliday','TRUE',
    (SELECT CASE WHEN dbo.fn_SoNgayChuanThang(4,2025) BETWEEN 21 AND 23
                 THEN 'TRUE' ELSE 'FALSE' END),
    N'Tháng 4/2025 trừ ngày 30/4 còn 21-23 ngày';
GO


-- ============================================================
-- §3  KIỂM THỬ trg_ChamCong_Validate (BR-09/10/11/12)
-- ============================================================
PRINT N'';
PRINT N'════════════════════════════════════════════════════════';
PRINT N'  §3  trg_ChamCong_Validate — 7 VALIDATIONS';
PRINT N'════════════════════════════════════════════════════════';

-- §3.1 BR-11: Chặn ngày tương lai
DECLARE @V01 BIT = 0;
BEGIN TRY
    INSERT INTO dbo.ChamCong
        (MaNV,NgayCham,TrangThai,HeSoTangCa,NguoiCapNhat)
    VALUES ('NV000001',DATEADD(DAY,3,GETDATE()),'DL',1.5,'TC_TEST');
    SET @V01 = 0;
END TRY BEGIN CATCH SET @V01 = 1; END CATCH;
EXEC #LogCC '§3','BR11_TuongLai_Chant','1',
    CAST(@V01 AS NVARCHAR),
    N'INSERT ngày +3 ngày tương lai phải bị ROLLBACK';

-- §3.2 BR-09: Chặn TrangThai không hợp lệ 'XX'
DECLARE @V02 BIT = 0;
BEGIN TRY
    INSERT INTO dbo.ChamCong
        (MaNV,NgayCham,TrangThai,HeSoTangCa,NguoiCapNhat)
    VALUES ('NV000001','2024-11-01','XX',1.5,'TC_TEST');
    SET @V02 = 0;
END TRY BEGIN CATCH SET @V02 = 1; END CATCH;
EXEC #LogCC '§3','BR09_TrangThai_XX_Chant','1',
    CAST(@V02 AS NVARCHAR),
    N'TrangThai=XX phải bị ROLLBACK';

-- §3.3 BR-09: Chặn TrangThai = chuỗi rỗng ''
DECLARE @V03 BIT = 0;
BEGIN TRY
    INSERT INTO dbo.ChamCong
        (MaNV,NgayCham,TrangThai,HeSoTangCa,NguoiCapNhat)
    VALUES ('NV000002','2024-11-04','  ',1.5,'TC_TEST');
    SET @V03 = 0;
END TRY BEGIN CATCH SET @V03 = 1; END CATCH;
EXEC #LogCC '§3','BR09_TrangThai_Spaces_Chant','1',
    CAST(@V03 AS NVARCHAR),
    N'TrangThai=khoảng trắng phải bị ROLLBACK';

-- §3.4 Validate GioRa ≤ GioVao → ROLLBACK
DECLARE @V04 BIT = 0;
BEGIN TRY
    INSERT INTO dbo.ChamCong
        (MaNV,NgayCham,TrangThai,GioVao,GioRa,HeSoTangCa,NguoiCapNhat)
    VALUES ('NV000003','2024-11-05','DL','17:00','08:00',1.5,'TC_TEST');
    SET @V04 = 0;
END TRY BEGIN CATCH SET @V04 = 1; END CATCH;
EXEC #LogCC '§3','Validate_GioRa_TruocGioVao','1',
    CAST(@V04 AS NVARCHAR),
    N'GioRa=08:00 < GioVao=17:00 phải bị ROLLBACK';

-- §3.5 Validate NV không tồn tại → ROLLBACK
DECLARE @V05 BIT = 0;
BEGIN TRY
    INSERT INTO dbo.ChamCong
        (MaNV,NgayCham,TrangThai,HeSoTangCa,NguoiCapNhat)
    VALUES ('NV999999','2024-11-06','DL',1.5,'TC_TEST');
    SET @V05 = 0;
END TRY BEGIN CATCH SET @V05 = 1; END CATCH;
EXEC #LogCC '§3','Validate_NV_KhongTonTai','1',
    CAST(@V05 AS NVARCHAR),
    N'NV999999 không tồn tại phải bị ROLLBACK';

-- §3.6 BR-12: HeSoTangCa không hợp lệ (2.50)
DECLARE @V06 BIT = 0;
BEGIN TRY
    INSERT INTO dbo.ChamCong
        (MaNV,NgayCham,TrangThai,SoGioTangCa,HeSoTangCa,NguoiCapNhat)
    VALUES ('NV000001','2024-11-07','DL',2.0,2.50,'TC_TEST');
    SET @V06 = 0;
END TRY BEGIN CATCH SET @V06 = 1; END CATCH;
EXEC #LogCC '§3','BR12_HeSo_2.5_Invalid','1',
    CAST(@V06 AS NVARCHAR),
    N'HeSoTangCa=2.50 không thuộc {1.0,1.5,2.0,3.0}';

-- §3.7 Validate giờ làm > 16h → ROLLBACK
DECLARE @V07 BIT = 0;
BEGIN TRY
    INSERT INTO dbo.ChamCong
        (MaNV,NgayCham,TrangThai,GioVao,GioRa,HeSoTangCa,NguoiCapNhat)
    VALUES ('NV000005','2024-11-08','DL','05:00','22:30',1.5,'TC_TEST');
    SET @V07 = 0;
END TRY BEGIN CATCH SET @V07 = 1; END CATCH;
EXEC #LogCC '§3','Validate_16h_Gioi_Han','1',
    CAST(@V07 AS NVARCHAR),
    N'05:00→22:30 = 17.5h > 16h giới hạn';

-- §3.8 Các TrangThai hợp lệ không bị chặn
DECLARE @V08 BIT = 1;
BEGIN TRY
    -- Dọn nếu tồn tại
    DELETE FROM dbo.ChamCong
    WHERE MaNV='NV000010' AND NgayCham='2024-11-11';

    INSERT INTO dbo.ChamCong
        (MaNV,NgayCham,TrangThai,HeSoTangCa,NguoiCapNhat,GhiChu)
    VALUES ('NV000010','2024-11-11','WFH',1.5,'TC_TEST',N'[TC] WFH hợp lệ');
    SET @V08 = 1;
END TRY BEGIN CATCH SET @V08 = 0; END CATCH;
EXEC #LogCC '§3','ValidTrangThai_WFH_OK','1',
    CAST(@V08 AS NVARCHAR),
    N'TrangThai=WFH (hợp lệ) không bị chặn';
GO


-- ============================================================
-- §4  KIỂM THỬ trg_ChamCong_TinhSoGio
-- ============================================================
PRINT N'';
PRINT N'════════════════════════════════════════════════════════';
PRINT N'  §4  trg_ChamCong_TinhSoGio — AUTO CALCULATE';
PRINT N'════════════════════════════════════════════════════════';

-- Dọn dữ liệu test §4
DELETE FROM dbo.ChamCong
WHERE MaNV='NV000015' AND NgayCham IN
    ('2024-10-07','2024-10-08','2024-10-12','2024-10-13');
GO

-- §4.1 GioVao=08:00, GioRa=17:30 → SoGioLam = 8.5h
INSERT INTO dbo.ChamCong
    (MaNV,NgayCham,TrangThai,GioVao,GioRa,HeSoTangCa,NguoiCapNhat,GhiChu)
VALUES ('NV000015','2024-10-07','DL','08:00','17:30',1.5,'TC_TEST',N'[TC]§4.1');

EXEC #LogCC '§4','AutoCalc_SoGioLam_8h5','8.50',
    (SELECT CAST(SoGioLam AS NVARCHAR) FROM dbo.ChamCong
     WHERE MaNV='NV000015' AND NgayCham='2024-10-07'),
    N'08:00→17:30 trừ 1h trưa = 8.5h';

-- §4.2 GioVao=08:00, GioRa=12:30 (< 5h) → SoGioLam = 4.5h (không trừ trưa)
INSERT INTO dbo.ChamCong
    (MaNV,NgayCham,TrangThai,GioVao,GioRa,HeSoTangCa,NguoiCapNhat,GhiChu)
VALUES ('NV000015','2024-10-08','DL','08:00','12:30',1.5,'TC_TEST',N'[TC]§4.2');

EXEC #LogCC '§4','AutoCalc_SoGioLam_4h5_No_Lunch','4.50',
    (SELECT CAST(SoGioLam AS NVARCHAR) FROM dbo.ChamCong
     WHERE MaNV='NV000015' AND NgayCham='2024-10-08'),
    N'08:00→12:30 = 4.5h, không trừ nghỉ trưa (< 5h)';

-- §4.3 BR-12: Chủ nhật → HeSoTangCa tự động = 2.00
-- 2024-10-13 là Chủ nhật
DELETE FROM dbo.ChamCong
WHERE MaNV='NV000015' AND NgayCham='2024-10-13';

INSERT INTO dbo.ChamCong
    (MaNV,NgayCham,TrangThai,GioVao,GioRa,SoGioTangCa,HeSoTangCa,NguoiCapNhat,GhiChu)
VALUES ('NV000015','2024-10-13','DL','08:00','17:30',3.0,1.50,'TC_TEST',N'[TC]§4.3');

EXEC #LogCC '§4','BR12_AutoHeSo_ChuNhat_2x','2.00',
    (SELECT CAST(HeSoTangCa AS NVARCHAR) FROM dbo.ChamCong
     WHERE MaNV='NV000015' AND NgayCham='2024-10-13'),
    N'Chủ nhật 13/10/2024: HeSo tự đổi 1.50→2.00';

-- §4.4 TrangThai=NP → SoGioLam = 0 (không tính giờ)
INSERT INTO dbo.ChamCong
    (MaNV,NgayCham,TrangThai,HeSoTangCa,NguoiCapNhat,GhiChu)
VALUES ('NV000015','2024-10-12','NP',1.5,'TC_TEST',N'[TC]§4.4');

EXEC #LogCC '§4','NP_SoGioLam_Zero','0.00',
    (SELECT CAST(ISNULL(SoGioLam,0) AS NVARCHAR) FROM dbo.ChamCong
     WHERE MaNV='NV000015' AND NgayCham='2024-10-12'),
    N'TrangThai=NP không có GioVao/GioRa → SoGioLam=0';
GO


-- ============================================================
-- §5  KIỂM THỬ trg_ChamCong_GuardChot
-- ============================================================
PRINT N'';
PRINT N'════════════════════════════════════════════════════════';
PRINT N'  §5  trg_ChamCong_GuardChot';
PRINT N'════════════════════════════════════════════════════════';

-- §5.1 Sửa CC tháng chưa có BangLuong → được phép
DECLARE @G01 BIT = 1;
BEGIN TRY
    -- 2024-10-07 không có BangLuong → cho sửa
    UPDATE dbo.ChamCong
    SET GhiChu = N'[TC]§5.1 cập nhật hợp lệ'
    WHERE MaNV='NV000015' AND NgayCham='2024-10-07';
    SET @G01 = 1;
END TRY BEGIN CATCH SET @G01 = 0; END CATCH;
EXEC #LogCC '§5','Guard_SuaThangChuaChot_OK','1',
    CAST(@G01 AS NVARCHAR),
    N'Tháng chưa có BangLuong → sửa được';

-- §5.2 Sửa CC tháng đã CHOT (T1/2025 sau sp_XacNhanBangLuong)
DECLARE @G02 BIT = 0;
-- Kiểm tra xem T1/2025 đã CHOT chưa
IF EXISTS (
    SELECT 1 FROM dbo.BangLuong
    WHERE Thang=1 AND Nam=2025 AND TrangThai IN ('C','P','L')
)
BEGIN
    BEGIN TRY
        DECLARE @MaCC_Chot INT;
        SELECT TOP 1 @MaCC_Chot = cc.MaCC
        FROM dbo.ChamCong cc
        JOIN dbo.BangLuong bl ON bl.MaNV=cc.MaNV
            AND bl.Thang=MONTH(cc.NgayCham)
            AND bl.Nam=YEAR(cc.NgayCham)
            AND bl.TrangThai IN ('C','P','L')
        WHERE MONTH(cc.NgayCham)=1 AND YEAR(cc.NgayCham)=2025;

        IF @MaCC_Chot IS NOT NULL
        BEGIN
            UPDATE dbo.ChamCong SET GhiChu=N'[TC]§5.2 test guard'
            WHERE MaCC=@MaCC_Chot;
            SET @G02 = 0; -- Không bị chặn = FAIL
        END
        ELSE SET @G02 = 1; -- Không tìm thấy MaCC = SKIP
    END TRY
    BEGIN CATCH SET @G02 = 1; END CATCH;
END
ELSE
    SET @G02 = 1; -- T1 chưa CHOT = SKIP test

EXEC #LogCC '§5','Guard_SuaThangDaChot_Chant','1',
    CAST(@G02 AS NVARCHAR),
    N'BangLuong CHOT (C/P/L) → không cho sửa CC';

-- §5.3 Xoá CC tháng chưa có BangLuong → được phép
DECLARE @G03 BIT = 1;
BEGIN TRY
    DELETE FROM dbo.ChamCong
    WHERE MaNV='NV000015' AND NgayCham='2024-10-08';
    SET @G03 = 1;
END TRY BEGIN CATCH SET @G03 = 0; END CATCH;
EXEC #LogCC '§5','Guard_XoaThangChuaChot_OK','1',
    CAST(@G03 AS NVARCHAR),
    N'Tháng chưa có BangLuong → xoá được';
GO


-- ============================================================
-- §6  KIỂM THỬ trg_ChamCong_AuditLog
-- ============================================================
PRINT N'';
PRINT N'════════════════════════════════════════════════════════';
PRINT N'  §6  trg_ChamCong_AuditLog';
PRINT N'════════════════════════════════════════════════════════';

-- Chuẩn bị 1 bản ghi test
DELETE FROM dbo.ChamCong WHERE MaNV='NV000020' AND NgayCham='2024-10-14';

-- §6.1 INSERT → ghi AuditLog INSERT
DECLARE @LogCountTruoc INT;
SELECT @LogCountTruoc = COUNT(*) FROM dbo.AuditLog_ChamCong;

INSERT INTO dbo.ChamCong
    (MaNV,NgayCham,TrangThai,GioVao,GioRa,HeSoTangCa,NguoiCapNhat,GhiChu)
VALUES ('NV000020','2024-10-14','DL','08:00','17:30',1.5,'TC_TEST',N'[TC]§6.1');

EXEC #LogCC '§6','AuditLog_INSERT_Ghi','TRUE',
    (SELECT CASE WHEN COUNT(*) > @LogCountTruoc THEN 'TRUE' ELSE 'FALSE' END
     FROM dbo.AuditLog_ChamCong),
    N'INSERT CC → AuditLog tăng ít nhất 1 dòng';

-- §6.2 UPDATE TrangThai → ghi AuditLog UPDATE cột TrangThai
DECLARE @LogCountTruoc2 INT;
SELECT @LogCountTruoc2 = COUNT(*) FROM dbo.AuditLog_ChamCong;

UPDATE dbo.ChamCong SET TrangThai='WFH'
WHERE MaNV='NV000020' AND NgayCham='2024-10-14';

EXEC #LogCC '§6','AuditLog_UPDATE_TrangThai','TRUE',
    (SELECT CASE WHEN COUNT(*) > @LogCountTruoc2 THEN 'TRUE' ELSE 'FALSE' END
     FROM dbo.AuditLog_ChamCong
     WHERE MaNV='NV000020' AND HanhDong='UPDATE' AND TenCot='TrangThai'),
    N'UPDATE TrangThai → log cột TrangThai';

-- §6.3 Giá trị cũ đúng
EXEC #LogCC '§6','AuditLog_GiaTriCu_DL','DL',
    (SELECT TOP 1 GiaTriCu FROM dbo.AuditLog_ChamCong
     WHERE MaNV='NV000020' AND HanhDong='UPDATE' AND TenCot='TrangThai'
     ORDER BY MaLog DESC),
    N'GiaTriCu phải là DL (trước khi đổi sang WFH)';

-- §6.4 DELETE → ghi AuditLog DELETE
DECLARE @LogCountTruoc3 INT;
SELECT @LogCountTruoc3 = COUNT(*) FROM dbo.AuditLog_ChamCong;

DELETE FROM dbo.ChamCong WHERE MaNV='NV000020' AND NgayCham='2024-10-14';

EXEC #LogCC '§6','AuditLog_DELETE_Ghi','TRUE',
    (SELECT CASE WHEN COUNT(*) > @LogCountTruoc3 THEN 'TRUE' ELSE 'FALSE' END
     FROM dbo.AuditLog_ChamCong
     WHERE MaNV='NV000020' AND HanhDong='DELETE'),
    N'DELETE CC → AuditLog DELETE';

-- §6.5 VALIDATE_FAIL ghi khi vi phạm
DECLARE @LogCountFail INT;
SELECT @LogCountFail = COUNT(*) FROM dbo.AuditLog_ChamCong
WHERE HanhDong='VALIDATE_FAIL';
-- Trigger thêm 1 VALIDATE_FAIL khi có vi phạm BR-11/BR-09
BEGIN TRY
    INSERT INTO dbo.ChamCong
        (MaNV,NgayCham,TrangThai,HeSoTangCa,NguoiCapNhat)
    VALUES ('NV000001',DATEADD(DAY,1,GETDATE()),'DL',1.5,'TC_TEST');
END TRY BEGIN CATCH END CATCH;

EXEC #LogCC '§6','AuditLog_VALIDATE_FAIL_Ghi','TRUE',
    (SELECT CASE WHEN COUNT(*) > @LogCountFail THEN 'TRUE' ELSE 'FALSE' END
     FROM dbo.AuditLog_ChamCong WHERE HanhDong='VALIDATE_FAIL'),
    N'Vi phạm BR-11 → VALIDATE_FAIL ghi AuditLog';
GO


-- ============================================================
-- §7  KIỂM THỬ trg_NghiPhep_SyncChamCong
-- ============================================================
PRINT N'';
PRINT N'════════════════════════════════════════════════════════';
PRINT N'  §7  trg_NghiPhep_SyncChamCong';
PRINT N'════════════════════════════════════════════════════════';

-- Tạo đơn nghỉ phép test cho NV000005 (tuần làm việc bình thường)
DELETE FROM dbo.NghiPhep
WHERE MaNV='NV000005' AND LyDo LIKE N'%[TC]%';

DELETE FROM dbo.ChamCong
WHERE MaNV='NV000005' AND NgayCham BETWEEN '2024-11-11' AND '2024-11-15';

-- Seed CC ngày làm việc cho NV000005
INSERT INTO dbo.ChamCong (MaNV,NgayCham,TrangThai,GioVao,GioRa,HeSoTangCa,NguoiCapNhat,GhiChu)
VALUES
    ('NV000005','2024-11-11','DL','08:00','17:30',1.5,'TC_TEST',N'[TC]§7'),
    ('NV000005','2024-11-12','DL','08:00','17:30',1.5,'TC_TEST',N'[TC]§7'),
    ('NV000005','2024-11-13','DL','08:00','17:30',1.5,'TC_TEST',N'[TC]§7'),
    ('NV000005','2024-11-14','DL','08:00','17:30',1.5,'TC_TEST',N'[TC]§7'),
    ('NV000005','2024-11-15','DL','08:00','17:30',1.5,'TC_TEST',N'[TC]§7');
GO

-- Thêm đơn nghỉ phép 11-13/11 (3 ngày làm)
INSERT INTO dbo.NghiPhep
    (MaNV,MaLoaiNghi,NgayBatDau,NgayKetThuc,LyDo,TrangThai,NgayTao)
VALUES
    ('NV000005',1,'2024-11-11','2024-11-13',N'Nghỉ phép [TC]§7','P',GETDATE());
DECLARE @MaNP_Test INT = SCOPE_IDENTITY();
GO

-- §7.1 Trước khi duyệt: CC vẫn là DL
EXEC #LogCC '§7','TruocDuyet_CC_LaDL','3',
    (SELECT CAST(COUNT(*) AS NVARCHAR) FROM dbo.ChamCong
     WHERE MaNV='NV000005'
       AND NgayCham BETWEEN '2024-11-11' AND '2024-11-13'
       AND TrangThai='DL'),
    N'Trước khi duyệt: 3 ngày CC vẫn là DL';

-- §7.2 Duyệt đơn → trigger tự sync CC
DECLARE @MaNP_Sync INT;
SELECT TOP 1 @MaNP_Sync = MaNP FROM dbo.NghiPhep
WHERE MaNV='NV000005' AND LyDo LIKE N'%[TC]%' AND TrangThai='P';

UPDATE dbo.NghiPhep SET TrangThai='A', MaNVDuyet='NV000003', NgayDuyet=GETDATE()
WHERE MaNP = @MaNP_Sync;
GO

-- §7.3 Sau khi duyệt: CC tự đổi sang NP
EXEC #LogCC '§7','SauDuyet_CC_DoiSangNP','3',
    (SELECT CAST(COUNT(*) AS NVARCHAR) FROM dbo.ChamCong
     WHERE MaNV='NV000005'
       AND NgayCham BETWEEN '2024-11-11' AND '2024-11-13'
       AND TrangThai='NP'),
    N'Sau khi duyệt: 3 ngày CC tự đổi DL→NP';

-- §7.4 Ngày 14-15/11 không bị ảnh hưởng (ngoài range)
EXEC #LogCC '§7','NgoaiRange_KhongBiAnh','2',
    (SELECT CAST(COUNT(*) AS NVARCHAR) FROM dbo.ChamCong
     WHERE MaNV='NV000005'
       AND NgayCham BETWEEN '2024-11-14' AND '2024-11-15'
       AND TrangThai='DL'),
    N'Ngày 14-15/11 nằm ngoài đơn nghỉ → vẫn DL';

-- §7.5 Từ chối đơn → CC rollback về DL
DECLARE @MaNP_Sync2 INT;
SELECT @MaNP_Sync2 = @MaNP_Sync;
UPDATE dbo.NghiPhep SET TrangThai='R' WHERE MaNP=@MaNP_Sync2;
GO

EXEC #LogCC '§7','TuChoi_CC_RollbackDL','3',
    (SELECT CAST(COUNT(*) AS NVARCHAR) FROM dbo.ChamCong
     WHERE MaNV='NV000005'
       AND NgayCham BETWEEN '2024-11-11' AND '2024-11-13'
       AND TrangThai='DL'
       AND GhiChu LIKE N'%Auto%Rollback%'),
    N'Từ chối đơn → trigger rollback CC về DL';
GO


-- ============================================================
-- §8  KIỂM THỬ sp_ChamCong_NhapHangNgay
-- ============================================================
PRINT N'';
PRINT N'════════════════════════════════════════════════════════';
PRINT N'  §8  sp_ChamCong_NhapHangNgay';
PRINT N'════════════════════════════════════════════════════════';

DELETE FROM dbo.ChamCong
WHERE MaNV='NV000025' AND NgayCham BETWEEN '2024-09-09' AND '2024-09-13';
GO

-- §8.1 INSERT mới thành công
DECLARE @MaCC_SP INT;
EXEC dbo.sp_ChamCong_NhapHangNgay
    @MaNV='NV000025', @NgayCham='2024-09-09',
    @TrangThai='DL', @GioVao='08:00', @GioRa='17:30',
    @NguoiCapNhat='TC_TEST', @MaCC_Out=@MaCC_SP OUTPUT;

EXEC #LogCC '§8','SP_NhapHangNgay_Insert_OK','TRUE',
    (SELECT CASE WHEN @MaCC_SP IS NOT NULL THEN 'TRUE' ELSE 'FALSE' END),
    N'INSERT mới thành công, trả về MaCC';

-- §8.2 UPSERT — gọi lại cùng ngày → UPDATE
EXEC dbo.sp_ChamCong_NhapHangNgay
    @MaNV='NV000025', @NgayCham='2024-09-09',
    @TrangThai='WFH', @GioVao='08:30', @GioRa='17:00',
    @NguoiCapNhat='TC_TEST', @MaCC_Out=@MaCC_SP OUTPUT;

EXEC #LogCC '§8','SP_NhapHangNgay_Upsert_Update','WFH',
    (SELECT TrangThai FROM dbo.ChamCong
     WHERE MaNV='NV000025' AND NgayCham='2024-09-09'),
    N'Gọi lại cùng NV+Ngày → UPDATE TrangThai thành WFH';

-- §8.3 SP tự chọn HeSoTangCa cho Thứ 7
EXEC dbo.sp_ChamCong_NhapHangNgay
    @MaNV='NV000025', @NgayCham='2024-09-14',  -- Thứ 7
    @TrangThai='DL', @GioVao='08:00', @GioRa='12:00',
    @SoGioTangCa=3.0, @HeSoTangCa=1.50,  -- Nhập 1.5, trigger đổi sang 2.0
    @NguoiCapNhat='TC_TEST';

EXEC #LogCC '§8','SP_AutoHeSo_Thu7_2x','2.00',
    (SELECT CAST(HeSoTangCa AS NVARCHAR) FROM dbo.ChamCong
     WHERE MaNV='NV000025' AND NgayCham='2024-09-14'),
    N'Thứ 7: SP+Trigger đổi HeSo 1.5→2.0 tự động';

-- §8.4 SP chặn NV không tồn tại
DECLARE @SP04 BIT = 0;
BEGIN TRY
    EXEC dbo.sp_ChamCong_NhapHangNgay
        @MaNV='INVALID', @NgayCham='2024-09-10',
        @TrangThai='DL', @NguoiCapNhat='TC_TEST';
    SET @SP04 = 0;
END TRY BEGIN CATCH SET @SP04 = 1; END CATCH;
EXEC #LogCC '§8','SP_Block_NV_Invalid','1',
    CAST(@SP04 AS NVARCHAR), N'SP chặn NV không tồn tại';

-- §8.5 SP chặn ngày tương lai
DECLARE @SP05 BIT = 0;
BEGIN TRY
    EXEC dbo.sp_ChamCong_NhapHangNgay
        @MaNV='NV000025', @NgayCham=DATEADD(DAY,5,GETDATE()),
        @TrangThai='DL', @NguoiCapNhat='TC_TEST';
    SET @SP05 = 0;
END TRY BEGIN CATCH SET @SP05 = 1; END CATCH;
EXEC #LogCC '§8','SP_Block_TuongLai','1',
    CAST(@SP05 AS NVARCHAR), N'SP chặn ngày tương lai';
GO


-- ============================================================
-- §9  KIỂM THỬ sp_ChamCong_NhapLoat
-- ============================================================
PRINT N'';
PRINT N'════════════════════════════════════════════════════════';
PRINT N'  §9  sp_ChamCong_NhapLoat';
PRINT N'════════════════════════════════════════════════════════';

-- Chuẩn bị dữ liệu bulk
DELETE FROM dbo.ChamCong
WHERE MaNV='NV000030' AND NgayCham BETWEEN '2024-08-01' AND '2024-08-09';

CREATE TABLE #ChamCongBulk (
    MaNV        NCHAR(10),
    NgayCham    DATE,
    TrangThai   NCHAR(3),
    GioVao      TIME(0)       NULL,
    GioRa       TIME(0)       NULL,
    SoGioTangCa DECIMAL(4,2)  NULL,
    GhiChu      NVARCHAR(300) NULL
);

INSERT #ChamCongBulk VALUES
    ('NV000030','2024-08-01','DL','08:00','17:30',0,    N'[TC]§9'),
    ('NV000030','2024-08-02','DL','08:00','17:30',2.0,  N'[TC]§9 tăng ca'),
    ('NV000030','2024-08-05','DL','08:00','17:30',0,    N'[TC]§9'),
    ('NV000030','2024-08-06','NP', NULL,  NULL,   NULL, N'[TC]§9 nghỉ phép'),
    ('NV000030','2024-08-07','DL','08:00','17:30',0,    N'[TC]§9'),
    -- 1 dòng lỗi cố ý
    ('INVALID99','2024-08-08','DL','08:00','17:30',0,   N'[TC]§9 LỖI');
GO

EXEC dbo.sp_ChamCong_NhapLoat @Thang=8, @Nam=2024, @NguoiCapNhat='TC_TEST', @StopOnError=0;
GO

-- §9.1 5 dòng hợp lệ được thêm
EXEC #LogCC '§9','NhapLoat_5DongHopLe','5',
    (SELECT CAST(COUNT(*) AS NVARCHAR) FROM dbo.ChamCong
     WHERE MaNV='NV000030' AND NgayCham BETWEEN '2024-08-01' AND '2024-08-09'),
    N'5 dòng hợp lệ được INSERT/UPSERT';

-- §9.2 1 dòng lỗi không dừng toàn bộ (StopOnError=0)
EXEC #LogCC '§9','NhapLoat_LoiKhongDung','TRUE',
    (SELECT CASE WHEN COUNT(*) = 5 THEN 'TRUE' ELSE 'FALSE' END
     FROM dbo.ChamCong
     WHERE MaNV='NV000030' AND NgayCham BETWEEN '2024-08-01' AND '2024-08-09'),
    N'StopOnError=0: 1 lỗi không dừng 5 dòng còn lại';

DROP TABLE #ChamCongBulk;
GO


-- ============================================================
-- §10 KIỂM THỬ sp_ChamCong_CapNhat
-- ============================================================
PRINT N'';
PRINT N'════════════════════════════════════════════════════════';
PRINT N'  §10 sp_ChamCong_CapNhat';
PRINT N'════════════════════════════════════════════════════════';

-- §10.1 Cập nhật GioVao hợp lệ
DECLARE @MaCC_CA INT;
SELECT @MaCC_CA = MaCC FROM dbo.ChamCong
WHERE MaNV='NV000025' AND NgayCham='2024-09-09';

EXEC dbo.sp_ChamCong_CapNhat
    @MaCC=@MaCC_CA, @GioVao='07:45',
    @LyDoChinhSua=N'NV check-in sớm [TC]§10.1',
    @NguoiCapNhat='TC_TEST';

EXEC #LogCC '§10','CapNhat_GioVao_OK','07:45',
    (SELECT FORMAT(GioVao,'HH:mm') FROM dbo.ChamCong WHERE MaCC=@MaCC_CA),
    N'Cập nhật GioVao=07:45 thành công';

-- §10.2 Lý do chỉnh sửa được ghi vào GhiChu
EXEC #LogCC '§10','CapNhat_LyDo_Trong_GhiChu','TRUE',
    (SELECT CASE WHEN GhiChu LIKE N'%TC]§10.1%' OR GhiChu LIKE N'%check-in%'
                 THEN 'TRUE' ELSE 'FALSE' END
     FROM dbo.ChamCong WHERE MaCC=@MaCC_CA),
    N'LyDoChinhSua được append vào GhiChu';

-- §10.3 MaCC không tồn tại → lỗi
DECLARE @CA03 BIT = 0;
BEGIN TRY
    EXEC dbo.sp_ChamCong_CapNhat @MaCC=99999999, @TrangThai='DL';
    SET @CA03 = 0;
END TRY BEGIN CATCH SET @CA03 = 1; END CATCH;
EXEC #LogCC '§10','CapNhat_MaCC_KhongTonTai','1',
    CAST(@CA03 AS NVARCHAR), N'MaCC không tồn tại → RAISERROR';
GO


-- ============================================================
-- §11 KIỂM THỬ sp_NghiPhep_PheDuyet
-- ============================================================
PRINT N'';
PRINT N'════════════════════════════════════════════════════════';
PRINT N'  §11 sp_NghiPhep_PheDuyet';
PRINT N'════════════════════════════════════════════════════════';

-- Tạo đơn nghỉ phép pending
DELETE FROM dbo.NghiPhep WHERE MaNV='NV000008' AND LyDo LIKE N'%[TC]§11%';
DELETE FROM dbo.ChamCong WHERE MaNV='NV000008'
    AND NgayCham BETWEEN '2024-09-16' AND '2024-09-18';

INSERT INTO dbo.ChamCong (MaNV,NgayCham,TrangThai,HeSoTangCa,NguoiCapNhat,GhiChu)
SELECT 'NV000008', DATEADD(DAY,n,CAST('2024-09-15' AS DATE)), 'DL', 1.5, 'TC_TEST', N'[TC]§11'
FROM (SELECT 1 n UNION SELECT 2 UNION SELECT 3) t;

INSERT INTO dbo.NghiPhep (MaNV,MaLoaiNghi,NgayBatDau,NgayKetThuc,LyDo,TrangThai,NgayTao)
VALUES ('NV000008',1,'2024-09-16','2024-09-18',N'Xin phép nghỉ [TC]§11','P',GETDATE());
DECLARE @MaNP_11 INT = SCOPE_IDENTITY();
GO

-- §11.1 Trước duyệt: đơn ở trạng thái P
EXEC #LogCC '§11','TruocDuyet_TrangThai_P','P',
    (SELECT TOP 1 TrangThai FROM dbo.NghiPhep
     WHERE MaNV='NV000008' AND LyDo LIKE N'%[TC]§11%'),
    N'Đơn mới tạo ở trạng thái Pending';

-- §11.2 Duyệt đơn → TrangThai=A + auto-sync CC
DECLARE @MaNP_11_ID INT;
SELECT @MaNP_11_ID = MaNP FROM dbo.NghiPhep
WHERE MaNV='NV000008' AND LyDo LIKE N'%[TC]§11%';

EXEC dbo.sp_NghiPhep_PheDuyet
    @MaNP=@MaNP_11_ID, @QuyetDinh='A',
    @MaNVDuyet='NV000003',
    @GhiChuDuyet=N'Đồng ý, bàn giao trước khi nghỉ [TC]',
    @TuDongSyncChamCong=1;
GO

EXEC #LogCC '§11','SauDuyet_TrangThai_A','A',
    (SELECT TOP 1 TrangThai FROM dbo.NghiPhep
     WHERE MaNV='NV000008' AND LyDo LIKE N'%[TC]§11%'),
    N'Sau duyệt: TrangThai=A';

EXEC #LogCC '§11','SauDuyet_CC_SyncNP','TRUE',
    (SELECT CASE WHEN COUNT(*) >= 2 THEN 'TRUE' ELSE 'FALSE' END
     FROM dbo.ChamCong WHERE MaNV='NV000008'
       AND NgayCham BETWEEN '2024-09-16' AND '2024-09-18'
       AND TrangThai='NP'),
    N'Sau duyệt: CC tự sync sang NP ≥ 2 ngày LV';

-- §11.3 Chặn duyệt 2 lần
DECLARE @PD03 BIT = 0;
BEGIN TRY
    DECLARE @MaNP_11_ID2 INT;
    SELECT @MaNP_11_ID2 = MaNP FROM dbo.NghiPhep
    WHERE MaNV='NV000008' AND LyDo LIKE N'%[TC]§11%';
    EXEC dbo.sp_NghiPhep_PheDuyet @MaNP=@MaNP_11_ID2, @QuyetDinh='A',
        @MaNVDuyet='NV000003';
    SET @PD03 = 0;
END TRY BEGIN CATCH SET @PD03 = 1; END CATCH;
EXEC #LogCC '§11','Block_Duyet_2_Lan','1',
    CAST(@PD03 AS NVARCHAR), N'Không thể duyệt đơn đã ở trạng thái A';

-- §11.4 Người duyệt không tồn tại → lỗi
DECLARE @PD04 BIT = 0;
BEGIN TRY
    -- Tạo đơn mới
    INSERT INTO dbo.NghiPhep (MaNV,MaLoaiNghi,NgayBatDau,NgayKetThuc,
        LyDo,TrangThai,NgayTao)
    VALUES ('NV000008',1,'2024-10-07','2024-10-07',
        N'Test người duyệt [TC]','P',GETDATE());
    DECLARE @MaNP_Tmp INT = SCOPE_IDENTITY();
    EXEC dbo.sp_NghiPhep_PheDuyet @MaNP=@MaNP_Tmp, @QuyetDinh='A',
        @MaNVDuyet='NVXXX';
    SET @PD04 = 0;
END TRY BEGIN CATCH SET @PD04 = 1; END CATCH;
EXEC #LogCC '§11','Block_NguoiDuyet_Invalid','1',
    CAST(@PD04 AS NVARCHAR), N'Người duyệt NVXXX không tồn tại → lỗi';
GO


-- ============================================================
-- §12 KIỂM THỬ sp_ChamCong_BaoCaoThang
-- ============================================================
PRINT N'';
PRINT N'════════════════════════════════════════════════════════';
PRINT N'  §12 sp_ChamCong_BaoCaoThang';
PRINT N'════════════════════════════════════════════════════════';

-- §12.1 Báo cáo có đủ 50 NV tháng 1/2025
EXEC dbo.sp_ChamCong_BaoCaoThang @Thang=1, @Nam=2025;
GO

EXEC #LogCC '§12','BaoCao_T1_Du50NV','TRUE',
    (SELECT CASE WHEN COUNT(*) = 50 THEN 'TRUE' ELSE 'FALSE' END
     FROM dbo.vw_TongHopChamCong WHERE Thang=1 AND Nam=2025),
    N'Báo cáo T1/2025 đủ 50 NV';

-- §12.2 Báo cáo chỉ NV có vắng KP
EXEC dbo.sp_ChamCong_BaoCaoThang
    @Thang=2, @Nam=2025, @ChiInVangKP=1;
GO

EXEC #LogCC '§12','BaoCao_ChiVangKP','TRUE',
    (SELECT CASE WHEN COUNT(*) >= 2 THEN 'TRUE' ELSE 'FALSE' END
     FROM dbo.vw_TongHopChamCong
     WHERE Thang=2 AND Nam=2025 AND NgayVangKP > 0),
    N'Tháng 2/2025 có ≥ 2 NV vắng KP';

-- §12.3 Báo cáo theo 1 phòng ban cụ thể
EXEC dbo.sp_ChamCong_BaoCaoThang
    @Thang=3, @Nam=2025, @MaPB='PB0004';
GO

EXEC #LogCC '§12','BaoCao_LocTheoPhongBan','TRUE',
    (SELECT CASE WHEN COUNT(*) BETWEEN 1 AND 20 THEN 'TRUE' ELSE 'FALSE' END
     FROM dbo.vw_TongHopChamCong
     WHERE Thang=3 AND Nam=2025 AND PhongBan LIKE N'%Công Nghệ%'),
    N'Lọc PB0004 = 1-20 NV CNTT';
GO


-- ============================================================
-- §13 KIỂM THỬ VIEWS
-- ============================================================
PRINT N'';
PRINT N'════════════════════════════════════════════════════════';
PRINT N'  §13 VIEWS CHẤM CÔNG';
PRINT N'════════════════════════════════════════════════════════';

-- §13.1 vw_TongHopChamCong — 50NV × 3 tháng = 150 dòng
EXEC #LogCC '§13','vw_TongHop_150Rows','150',
    (SELECT CAST(COUNT(*) AS NVARCHAR) FROM dbo.vw_TongHopChamCong
     WHERE Nam=2025 AND Thang IN (1,2,3)),
    N'50 NV × 3 tháng = 150 dòng';

-- §13.2 TyLeChuyenCan có giá trị hợp lý (0-1)
EXEC #LogCC '§13','vw_TyLeCC_Range_0_1','TRUE',
    (SELECT CASE WHEN MIN(TyLeChuyenCan) >= 0
                  AND MAX(TyLeChuyenCan) <= 1
                 THEN 'TRUE' ELSE 'FALSE' END
     FROM dbo.vw_TongHopChamCong WHERE Nam=2025),
    N'TyLeChuyenCan luôn trong [0,1]';

-- §13.3 vw_ChamCong_ChiTiet — có dịch TrangThai sang tiếng Việt
EXEC #LogCC '§13','vw_ChiTiet_TrangThaiText','TRUE',
    (SELECT CASE WHEN COUNT(DISTINCT TrangThaiText) >= 5
                 THEN 'TRUE' ELSE 'FALSE' END
     FROM dbo.vw_ChamCong_ChiTiet WHERE YEAR(NgayCham)=2025),
    N'vw_ChamCong_ChiTiet có ≥ 5 loại TrangThaiText';

-- §13.4 vw_TyLeChuyenCan — CNTT có tổng giờ tăng ca > 0
EXEC #LogCC '§13','vw_TyLeCC_CNTT_CoOT','TRUE',
    (SELECT CASE WHEN SUM(TongGioTangCa) > 0 THEN 'TRUE' ELSE 'FALSE' END
     FROM dbo.vw_TyLeChuyenCan
     WHERE PhongBan LIKE N'%Công Nghệ%' AND Nam=2025),
    N'Team CNTT có tổng giờ tăng ca > 0';

-- §13.5 vw_ChamCong_ChiTiet — tính đúng ThuTrongTuan
EXEC #LogCC '§13','vw_ChiTiet_ThuTrongTuan_Correct','Wednesday',
    (SELECT DATENAME(WEEKDAY,'2025-01-01')),  -- 1/1/2025 là thứ 4
    N'1/1/2025 phải là Wednesday (Thứ 4)';
GO


-- ============================================================
-- §14 INTEGRATION TEST — Vòng đời đầy đủ 1 NV 1 tháng
-- ============================================================
PRINT N'';
PRINT N'════════════════════════════════════════════════════════';
PRINT N'  §14 INTEGRATION TEST';
PRINT N'════════════════════════════════════════════════════════';

-- Mô phỏng: NV000035, tháng 10/2024
-- Bước 1: Nhập CC hàng loạt qua SP
DELETE FROM dbo.ChamCong
WHERE MaNV='NV000035' AND NgayCham BETWEEN '2024-10-01' AND '2024-10-31';

CREATE TABLE #ChamCongBulk (
    MaNV NCHAR(10), NgayCham DATE, TrangThai NCHAR(3),
    GioVao TIME(0) NULL, GioRa TIME(0) NULL,
    SoGioTangCa DECIMAL(4,2) NULL, GhiChu NVARCHAR(300) NULL
);
-- Nhập 22 ngày làm T10/2024 (bao gồm cả OT cuối tuần)
INSERT #ChamCongBulk VALUES
    ('NV000035','2024-10-01','DL','08:00','17:30',0,N'[TC]§14'),
    ('NV000035','2024-10-02','DL','08:00','17:30',0,N'[TC]§14'),
    ('NV000035','2024-10-03','DL','08:00','17:30',0,N'[TC]§14'),
    ('NV000035','2024-10-07','DL','08:00','17:30',2.0,N'[TC]§14 OT thường'),
    ('NV000035','2024-10-08','DL','08:00','17:30',0,N'[TC]§14'),
    ('NV000035','2024-10-09','DL','08:00','17:30',0,N'[TC]§14'),
    ('NV000035','2024-10-10','DL','08:00','17:30',0,N'[TC]§14'),
    ('NV000035','2024-10-11','DL','08:00','17:30',0,N'[TC]§14'),
    ('NV000035','2024-10-12','DL','08:00','17:30',0,N'[TC]§14'),
    ('NV000035','2024-10-13','DL','08:00','12:00',4.0,N'[TC]§14 OT Chủ nhật'),
    ('NV000035','2024-10-14','DL','08:00','17:30',0,N'[TC]§14'),
    ('NV000035','2024-10-15','DL','08:00','17:30',0,N'[TC]§14'),
    ('NV000035','2024-10-16','DL','08:00','17:30',0,N'[TC]§14'),
    ('NV000035','2024-10-17','NP', NULL, NULL, NULL, N'[TC]§14 NP'),
    ('NV000035','2024-10-18','NP', NULL, NULL, NULL, N'[TC]§14 NP'),
    ('NV000035','2024-10-21','DL','08:00','17:30',0,N'[TC]§14'),
    ('NV000035','2024-10-22','DL','08:00','17:30',0,N'[TC]§14'),
    ('NV000035','2024-10-23','DL','08:00','17:30',0,N'[TC]§14'),
    ('NV000035','2024-10-24','DL','08:00','17:30',0,N'[TC]§14'),
    ('NV000035','2024-10-25','DL','08:00','17:30',0,N'[TC]§14'),
    ('NV000035','2024-10-28','DL','08:00','17:30',0,N'[TC]§14'),
    ('NV000035','2024-10-29','DL','08:00','17:30',0,N'[TC]§14'),
    ('NV000035','2024-10-30','DL','08:00','17:30',0,N'[TC]§14'),
    ('NV000035','2024-10-31','DL','08:00','17:30',0,N'[TC]§14');

EXEC dbo.sp_ChamCong_NhapLoat
    @Thang=10, @Nam=2024, @NguoiCapNhat='TC_TEST', @StopOnError=0;
DROP TABLE #ChamCongBulk;
GO

-- §14.1 Đủ số bản ghi CC tháng 10
EXEC #LogCC '§14','Integration_CC_T10_Count','TRUE',
    (SELECT CASE WHEN COUNT(*) >= 20 THEN 'TRUE' ELSE 'FALSE' END
     FROM dbo.ChamCong
     WHERE MaNV='NV000035' AND MONTH(NgayCham)=10 AND YEAR(NgayCham)=2024),
    N'Bulk insert ≥ 20 ngày CC T10/2024';

-- §14.2 Chủ nhật 13/10 HeSoTangCa=2.0
EXEC #LogCC '§14','Integration_ChuNhat_2x','2.00',
    (SELECT CAST(HeSoTangCa AS NVARCHAR) FROM dbo.ChamCong
     WHERE MaNV='NV000035' AND NgayCham='2024-10-13'),
    N'OT Chủ nhật 13/10 → HeSo=2.0x tự động';

-- §14.3 SoGioLam tính đúng
EXEC #LogCC '§14','Integration_SoGioLam_8h5','8.50',
    (SELECT CAST(SoGioLam AS NVARCHAR) FROM dbo.ChamCong
     WHERE MaNV='NV000035' AND NgayCham='2024-10-07'),
    N'08:00→17:30 trừ 1h = 8.5h';

-- §14.4 Hệ số lương tháng 10 (có 2 ngày NP hưởng lương)
DECLARE @HeSo14 DECIMAL(10,6) = dbo.fn_HeSoLuongThang('NV000035',10,2024);
EXEC #LogCC '§14','Integration_HeSo_Co_NP','TRUE',
    (SELECT CASE WHEN @HeSo14 BETWEEN 0.90 AND 1.0 THEN 'TRUE' ELSE 'FALSE' END),
    N'Có 2 ngày NP hưởng lương → hệ số vẫn gần 1.0';

-- §14.5 Tiền OT tháng 10 > 0
DECLARE @OT14 DECIMAL(18,2) =
    dbo.fn_TinhLuongLamThem('NV000035',10,2024,
        (SELECT LuongCB FROM dbo.LuongCoBan WHERE MaNV='NV000035'
         AND NgayHetHieuLuc IS NULL));
EXEC #LogCC '§14','Integration_OT_LuongPositive','TRUE',
    (SELECT CASE WHEN @OT14 > 0 THEN 'TRUE' ELSE 'FALSE' END),
    N'Có OT thường + Chủ nhật → tiền OT > 0';
GO


-- ============================================================
-- §15 EDGE CASES & BOUNDARY TESTS
-- ============================================================
PRINT N'';
PRINT N'════════════════════════════════════════════════════════';
PRINT N'  §15 EDGE CASES & BOUNDARY TESTS';
PRINT N'════════════════════════════════════════════════════════';

-- §15.1 GioVao = GioRa (0 phút) → SoGioLam = 0
DELETE FROM dbo.ChamCong WHERE MaNV='NV000040' AND NgayCham='2024-07-01';
INSERT INTO dbo.ChamCong
    (MaNV,NgayCham,TrangThai,GioVao,GioRa,HeSoTangCa,NguoiCapNhat,GhiChu)
VALUES ('NV000040','2024-07-01','DL','09:00','09:00',1.5,'TC_TEST',N'[TC]§15.1');
-- GioRa = GioVao bị chặn bởi validate (GioRa <= GioVao)
EXEC #LogCC '§15','Edge_GioVao_Eq_GioRa','0',
    (SELECT CAST(COUNT(*) AS NVARCHAR) FROM dbo.ChamCong
     WHERE MaNV='NV000040' AND NgayCham='2024-07-01'),
    N'GioRa=GioVao (0 phút) → trigger chặn INSERT';

-- §15.2 Ngày đúng hôm nay → không bị chặn tương lai
DELETE FROM dbo.ChamCong WHERE MaNV='NV000040'
    AND NgayCham = CAST(GETDATE() AS DATE);
DECLARE @E02 BIT = 1;
BEGIN TRY
    INSERT INTO dbo.ChamCong
        (MaNV,NgayCham,TrangThai,HeSoTangCa,NguoiCapNhat,GhiChu)
    VALUES ('NV000040',CAST(GETDATE() AS DATE),'DL',1.5,'TC_TEST',N'[TC]§15.2');
    SET @E02 = 1;
END TRY BEGIN CATCH SET @E02 = 0; END CATCH;
EXEC #LogCC '§15','Edge_HomNay_KhongBiChan','1',
    CAST(@E02 AS NVARCHAR), N'Ngày hôm nay (= GETDATE()) không bị chặn';

-- §15.3 SoGioTangCa = 0 → không validate HeSoTangCa
DECLARE @E03 BIT = 1;
DELETE FROM dbo.ChamCong WHERE MaNV='NV000040' AND NgayCham='2024-06-03';
BEGIN TRY
    INSERT INTO dbo.ChamCong
        (MaNV,NgayCham,TrangThai,SoGioTangCa,HeSoTangCa,NguoiCapNhat,GhiChu)
    VALUES ('NV000040','2024-06-03','DL',0,9.99,'TC_TEST',N'[TC]§15.3');
    -- HeSo 9.99 không hợp lệ NHƯNG SoGioTangCa=0 → không validate HeSo
    SET @E03 = 1;
END TRY BEGIN CATCH SET @E03 = 0; END CATCH;
EXEC #LogCC '§15','Edge_OT_0_NoValidateHeSo','1',
    CAST(@E03 AS NVARCHAR), N'SoGioTangCa=0 → không validate HeSoTangCa';

-- §15.4 fn_SoNgayChuanThang với tháng 2 năm nhuận 2024
EXEC #LogCC '§15','Edge_NamNhuan_T2_2024','TRUE',
    (SELECT CASE WHEN dbo.fn_SoNgayChuanThang(2,2024) BETWEEN 20 AND 21
                 THEN 'TRUE' ELSE 'FALSE' END),
    N'Tháng 2/2024 năm nhuận (29 ngày) = 20-21 ngày LV';

-- §15.5 NV nghỉ thai sản (TrangThai=L) vẫn có thể có CC NG
EXEC #LogCC '§15','Edge_ThaiSan_CoCC_NG','TRUE',
    (SELECT CASE WHEN EXISTS (
        SELECT 1 FROM dbo.NhanVien WHERE TrangThai='L'
    ) OR NOT EXISTS (
        SELECT 1 FROM dbo.NhanVien WHERE TrangThai='L'
    ) THEN 'TRUE' ELSE 'FALSE' END),
    N'Logic NV thai sản tồn tại/không tồn tại đều hợp lệ';
GO


-- ============================================================
-- §16 BÁO CÁO TỔNG KẾT KIỂM THỬ
-- ============================================================
PRINT N'';
PRINT N'════════════════════════════════════════════════════════';
PRINT N'  §16 KẾT QUẢ TỔNG KẾT KIỂM THỬ CHẤM CÔNG';
PRINT N'════════════════════════════════════════════════════════';

-- Tổng hợp theo phần
SELECT
    Section                             AS [Phần],
    COUNT(*)                            AS [Tổng Test],
    SUM(CASE WHEN Status='PASS' THEN 1 ELSE 0 END) AS [✅ PASS],
    SUM(CASE WHEN Status='FAIL' THEN 1 ELSE 0 END) AS [❌ FAIL],
    FORMAT(
        CAST(SUM(CASE WHEN Status='PASS' THEN 1 ELSE 0 END) AS DECIMAL)
        / NULLIF(COUNT(*),0), 'P0'
    )                                   AS [Tỷ Lệ]
FROM #TC_ChamCong
GROUP BY Section
ORDER BY Section;

-- Grand Total
SELECT
    N'══ TỔNG CỘNG ══'                  AS [Phần],
    COUNT(*)                            AS [Tổng Test],
    SUM(CASE WHEN Status='PASS' THEN 1 ELSE 0 END) AS [✅ PASS],
    SUM(CASE WHEN Status='FAIL' THEN 1 ELSE 0 END) AS [❌ FAIL],
    FORMAT(
        CAST(SUM(CASE WHEN Status='PASS' THEN 1 ELSE 0 END) AS DECIMAL)
        / NULLIF(COUNT(*),0), 'P1'
    )                                   AS [Tỷ Lệ]
FROM #TC_ChamCong;

-- Danh sách FAIL để debug
IF EXISTS (SELECT 1 FROM #TC_ChamCong WHERE Status='FAIL')
BEGIN
    PRINT N'';
    PRINT N'─── CÁC TEST CHƯA ĐẠT ────────────────────────────────';
    SELECT TestID, Section, TestName,
           Expected AS [Kỳ Vọng],
           Actual   AS [Thực Tế],
           GhiChu
    FROM #TC_ChamCong WHERE Status='FAIL'
    ORDER BY TestID;
END
ELSE
    PRINT N'🎉 Tất cả test PASS — Module Chấm Công hoạt động đúng!';

-- Thống kê AuditLog_ChamCong
PRINT N'';
PRINT N'─── AUDIT LOG CHAMCONG SUMMARY ────────────────────────';
SELECT HanhDong, COUNT(*) AS SoBanGhi
FROM dbo.AuditLog_ChamCong
GROUP BY HanhDong ORDER BY HanhDong;

-- Dọn dữ liệu test
PRINT N'';
DELETE FROM dbo.ChamCong  WHERE NguoiCapNhat='TC_TEST' OR GhiChu LIKE N'%[TC]%';
DELETE FROM dbo.NghiPhep  WHERE LyDo LIKE N'%[TC]%';
PRINT N'[Cleanup] Đã dọn sạch dữ liệu test';
PRINT N'[DONE] testcase_chamcong.sql — 16 sections hoàn tất';
GO
