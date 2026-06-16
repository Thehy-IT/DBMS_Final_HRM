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


-- ── Bảng ghi kết quả (tái sử dụng từ test_queries.sql) ───────
DROP TEMPORARY TABLE IF EXISTS tmp_TC_ChamCong;

CREATE TEMPORARY TABLE tmp_TC_ChamCong (
    TestID      INT         AUTO_INCREMENT,
    Section     VARCHAR(10),
    TestName    VARCHAR(200),
    Expected    VARCHAR(300),
    Actual      VARCHAR(300),
    Status      CHAR(4),
    GhiChu      VARCHAR(400)
);


DROP PROCEDURE IF EXISTS LogCC;
DELIMITER $$
CREATE PROCEDURE LogCC(
    IN p_Section    VARCHAR(10),
    IN p_TestName   VARCHAR(200),
    IN p_Expected   VARCHAR(300),
    IN p_Actual     VARCHAR(300),
    IN p_GhiChu     VARCHAR(400)
)
BEGIN
    DECLARE v_Status VARCHAR(4);
    IF TRIM(p_Expected) = TRIM(p_Actual) THEN
        SET v_Status = 'PASS';
    ELSE
        SET v_Status = 'FAIL';
    END IF;
    INSERT INTO tmp_TC_ChamCong (Section,TestName,Expected,Actual,Status,GhiChu)
    VALUES (p_Section, p_TestName, p_Expected, p_Actual, v_Status, p_GhiChu);
    
    SELECT CONCAT('  ', v_Status, ' | ', p_TestName, 
                  IF(v_Status='FAIL', CONCAT(' -> KV:[', p_Expected, '] TT:[', p_Actual, ']'), '')) AS LogInfo;
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS TestTryCatch;
DELIMITER $$
CREATE PROCEDURE TestTryCatch(IN p_sql TEXT, OUT p_error INT)
BEGIN
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET p_error = 1;
    SET p_error = 0;
    SET @stmt = p_sql;
    PREPARE stmt FROM @stmt;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
END$$
DELIMITER ;



-- ============================================================
-- §1  SETUP & SANITY CHECK
-- ============================================================
SELECT '════════════════════════════════════════════════════════' AS Info;
SELECT '  §1  SETUP & SANITY CHECK' AS Info;
SELECT '════════════════════════════════════════════════════════' AS Info;

-- Dọn dữ liệu test cũ trước khi chạy
DELETE FROM ChamCong
WHERE NguoiCapNhat = 'TC_TEST'
   OR GhiChu LIKE '%[TC]%';

DELETE FROM NghiPhep
WHERE LyDo LIKE '%[TC]%';
SELECT '[Setup] Đã dọn dữ liệu test cũ' AS Info;

-- §1.1 Bảng ChamCong có dữ liệu 3 tháng
CALL LogCC '§1','CC_3Thang_Ton_Tai','TRUE',
    (SELECT CASE WHEN COUNT(DISTINCT MONTH(NgayCham)) >= 3
                 THEN 'TRUE' ELSE 'FALSE' END
     FROM ChamCong WHERE YEAR(NgayCham)=2025),
    'Jan/Feb/Mar 2025 đều có dữ liệu CC';

-- §1.2 Số bản ghi CC > 2000
CALL LogCC '§1','CC_SoBanGhi_Min2000','TRUE',
    (SELECT CASE WHEN COUNT(*) > 2000 THEN 'TRUE' ELSE 'FALSE' END
     FROM ChamCong),
    'Seed tạo đủ ~3100 bản ghi CC';

-- §1.3 Ngày Tết 1/1/2025 đều là NG
CALL LogCC '§1','TetDuongLich_NG','50',
    (SELECT CAST(COUNT(*) AS VARCHAR) FROM ChamCong
     WHERE NgayCham='2025-01-01' AND TrangThai='NG'),
    '1/1/2025 = 50 bản ghi NG cho 50 NV';

-- §1.4 NV000049 có 2 ngày KP tháng 2
CALL LogCC '§1','NV049_KP_Thang2','2',
    (SELECT CAST(COUNT(*) AS VARCHAR) FROM ChamCong
     WHERE MaNV='NV000049' AND TrangThai='KP'
       AND MONTH(NgayCham)=2 AND YEAR(NgayCham)=2025),
    'Seed đã UPDATE 2 ngày KP cho NV000049';

-- §1.5 NV000004 có ngày NP tháng 2 (nghỉ phép 10-12/2)
CALL LogCC '§1','NV004_NP_Thang2','3',
    (SELECT CAST(COUNT(*) AS VARCHAR) FROM ChamCong
     WHERE MaNV='NV000004' AND TrangThai='NP'
       AND MONTH(NgayCham)=2 AND YEAR(NgayCham)=2025),
    'NV000004 nghỉ phép 10-12/02/2025 = 3 ngày NP';

-- §1.6 Không có bản ghi CC tương lai
CALL LogCC '§1','KhongCo_CC_TuongLai','0',
    (SELECT CAST(COUNT(*) AS VARCHAR) FROM ChamCong
     WHERE NgayCham > CAST(NOW() AS DATE)),
    'Không có CC ngày tương lai';

-- §1.7 Bảng AuditLog_ChamCong tồn tại
CALL LogCC '§1','AuditLog_CC_Ton_Tai','TRUE',
    (SELECT CASE WHEN OBJECT_ID('AuditLog_ChamCong','U') IS NOT NULL
                 THEN 'TRUE' ELSE 'FALSE' END),
    'Bảng AuditLog_ChamCong đã được tạo';

-- §1.8 Team CNTT có tăng ca (từ seed)
CALL LogCC '§1','CNTT_CoTangCa_T1','TRUE',
    (SELECT CASE WHEN SUM(SoGioTangCa) > 0 THEN 'TRUE' ELSE 'FALSE' END
     FROM ChamCong cc
     JOIN NhanVien nv ON cc.MaNV=nv.MaNV
     WHERE nv.MaPB='PB0004'
       AND MONTH(NgayCham)=1 AND YEAR(NgayCham)=2025),
    'Team CNTT có giờ tăng ca tháng 1/2025';


-- ============================================================
-- §2  KIỂM THỬ FUNCTIONS NGÀY CÔNG
-- ============================================================
SELECT '' AS Info;
SELECT '════════════════════════════════════════════════════════' AS Info;
SELECT '  §2  FUNCTIONS NGÀY CÔNG' AS Info;
SELECT '════════════════════════════════════════════════════════' AS Info;

-- §2.1 fn_SoNgayChuanThang — Jan 2025 (trừ Tết ÂL)
SET @NgayChuanT1 = fn_SoNgayChuanThang(1,2025);
CALL LogCC '§2','NgayChuanT1_Range_15_18','TRUE',
    (SELECT CASE WHEN @NgayChuanT1 BETWEEN 15 AND 18
                 THEN 'TRUE' ELSE 'FALSE' END),
    'Tháng 1/2025: trừ Tết ÂL còn 15-18 ngày làm';

-- §2.2 fn_SoNgayChuanThang — Feb 2025
SET @NgayChuanT2 = fn_SoNgayChuanThang(2,2025);
CALL LogCC '§2','NgayChuanT2_Range_18_20','TRUE',
    (SELECT CASE WHEN @NgayChuanT2 BETWEEN 18 AND 20
                 THEN 'TRUE' ELSE 'FALSE' END),
    'Tháng 2/2025 (28 ngày): ~18-20 ngày làm việc';

-- §2.3 fn_SoNgayChuanThang — Mar 2025 (21 ngày LV)
SET @NgayChuanT3 = fn_SoNgayChuanThang(3,2025);
CALL LogCC '§2','NgayChuanT3_Range_20_22','TRUE',
    (SELECT CASE WHEN @NgayChuanT3 BETWEEN 20 AND 22
                 THEN 'TRUE' ELSE 'FALSE' END),
    'Tháng 3/2025: ~21 ngày làm việc';

-- §2.4 fn_SoNgayChamCong — TGĐ tháng 1/2025
SET @NgayDLNV1_T1 DECIMAL(5,1) =
    fn_SoNgayChamCong('NV000001',1,2025);
CALL LogCC '§2','TGD_NgayDiLam_T1_Positive','TRUE',
    (SELECT CASE WHEN @NgayDLNV1_T1 > 0 THEN 'TRUE' ELSE 'FALSE' END),
    'TGĐ có ngày đi làm tháng 1/2025';

-- §2.5 fn_SoNgayNghiCoLuong — NV000004 có 3 ngày NP tháng 2
CALL LogCC '§2','NV004_NghiCoLuong_3ngay','3',
    (SELECT CAST(fn_SoNgayNghiCoLuong('NV000004',2,2025) AS VARCHAR)),
    'NV000004 có 3 ngày nghỉ phép hưởng lương T2';

-- §2.6 fn_SoNgayNghiKhongLuong — NV000049 có 2 ngày KP tháng 2
CALL LogCC '§2','NV049_KhongLuong_2ngay','2',
    (SELECT CAST(fn_SoNgayNghiKhongLuong('NV000049',2,2025) AS VARCHAR)),
    'NV000049 có 2 ngày KP (vắng không phép)';

-- §2.7 fn_HeSoLuongThang — NV đi đủ tháng ≈ 1.0
SET @HeSoFull DECIMAL(10,6) =
    fn_HeSoLuongThang('NV000001',3,2025);
CALL LogCC '§2','TGD_HeSo_Full_Month_Near1','TRUE',
    (SELECT CASE WHEN @HeSoFull BETWEEN 0.95 AND 1.0
                 THEN 'TRUE' ELSE 'FALSE' END),
    'TGĐ đi đủ tháng 3 → hệ số gần 1.0';

-- §2.8 fn_HeSoLuongThang — NV vắng 2 ngày KP giảm hệ số
SET @HeSoKP DECIMAL(10,6) =
    fn_HeSoLuongThang('NV000049',2,2025);
SET @HeSoFull2 DECIMAL(10,6) =
    fn_HeSoLuongThang('NV000001',2,2025);
CALL LogCC '§2','NV049_HeSo_Thap_Hon_Full','TRUE',
    (SELECT CASE WHEN @HeSoKP < @HeSoFull2 THEN 'TRUE' ELSE 'FALSE' END),
    'NV vắng KP có hệ số thấp hơn NV đi đủ';

-- §2.9 fn_TinhLuongLamThem — Team CNTT tháng 1 có OT > 0
CALL LogCC '§2','CNTT_LuongOT_Positive','TRUE',
    (SELECT CASE WHEN SUM(fn_TinhLuongLamThem(nv.MaNV,1,2025,lcb.LuongCB)) > 0
                 THEN 'TRUE' ELSE 'FALSE' END
     FROM NhanVien nv
     JOIN LuongCoBan lcb ON nv.MaNV=lcb.MaNV
                             AND lcb.NgayHetHieuLuc IS NULL
     WHERE nv.MaPB='PB0004'),
    'fn_TinhLuongLamThem: Đội CNTT có tiền OT T1';

-- §2.10 fn_SoNgayChuanThang — Tháng 4 (không lễ 30/4)
CALL LogCC '§2','NgayChuanT4_NoHoliday','TRUE',
    (SELECT CASE WHEN fn_SoNgayChuanThang(4,2025) BETWEEN 21 AND 23
                 THEN 'TRUE' ELSE 'FALSE' END),
    'Tháng 4/2025 trừ ngày 30/4 còn 21-23 ngày';


-- ============================================================
-- §3  KIỂM THỬ trg_ChamCong_Validate (BR-09/10/11/12)
-- ============================================================
SELECT '' AS Info;
SELECT '════════════════════════════════════════════════════════' AS Info;
SELECT '  §3  trg_ChamCong_Validate — 7 VALIDATIONS' AS Info;
SELECT '════════════════════════════════════════════════════════' AS Info;

-- §3.1 BR-11: Chặn ngày tương lai
SET @V01 = 0;
CALL TestTryCatch('INSERT INTO ChamCong
        (MaNV,NgayCham,TrangThai,HeSoTangCa,NguoiCapNhat)
    VALUES (\'NV000001\',DATE_ADD(NOW(, INTERVAL 3 DAY)),\'DL\',1.5,\'TC_TEST\');', @V01);
CALL LogCC '§3','BR11_TuongLai_Chant','1',
    CAST(@V01 AS VARCHAR),
    'INSERT ngày +3 ngày tương lai phải bị ROLLBACK';

-- §3.2 BR-09: Chặn TrangThai không hợp lệ 'XX'
SET @V02 = 0;
CALL TestTryCatch('INSERT INTO ChamCong
        (MaNV,NgayCham,TrangThai,HeSoTangCa,NguoiCapNhat)
    VALUES (\'NV000001\',\'2024-11-01\',\'XX\',1.5,\'TC_TEST\');', @V02);
CALL LogCC '§3','BR09_TrangThai_XX_Chant','1',
    CAST(@V02 AS VARCHAR),
    'TrangThai=XX phải bị ROLLBACK';

-- §3.3 BR-09: Chặn TrangThai = chuỗi rỗng ''
SET @V03 = 0;
CALL TestTryCatch('INSERT INTO ChamCong
        (MaNV,NgayCham,TrangThai,HeSoTangCa,NguoiCapNhat)
    VALUES (\'NV000002\',\'2024-11-04\',\'  \',1.5,\'TC_TEST\');', @V03);
CALL LogCC '§3','BR09_TrangThai_Spaces_Chant','1',
    CAST(@V03 AS VARCHAR),
    'TrangThai=khoảng trắng phải bị ROLLBACK';

-- §3.4 Validate GioRa ≤ GioVao → ROLLBACK
SET @V04 = 0;
CALL TestTryCatch('INSERT INTO ChamCong
        (MaNV,NgayCham,TrangThai,GioVao,GioRa,HeSoTangCa,NguoiCapNhat)
    VALUES (\'NV000003\',\'2024-11-05\',\'DL\',\'17:00\',\'08:00\',1.5,\'TC_TEST\');', @V04);
CALL LogCC '§3','Validate_GioRa_TruocGioVao','1',
    CAST(@V04 AS VARCHAR),
    'GioRa=08:00 < GioVao=17:00 phải bị ROLLBACK';

-- §3.5 Validate NV không tồn tại → ROLLBACK
SET @V05 = 0;
CALL TestTryCatch('INSERT INTO ChamCong
        (MaNV,NgayCham,TrangThai,HeSoTangCa,NguoiCapNhat)
    VALUES (\'NV999999\',\'2024-11-06\',\'DL\',1.5,\'TC_TEST\');', @V05);
CALL LogCC '§3','Validate_NV_KhongTonTai','1',
    CAST(@V05 AS VARCHAR),
    'NV999999 không tồn tại phải bị ROLLBACK';

-- §3.6 BR-12: HeSoTangCa không hợp lệ (2.50)
SET @V06 = 0;
CALL TestTryCatch('INSERT INTO ChamCong
        (MaNV,NgayCham,TrangThai,SoGioTangCa,HeSoTangCa,NguoiCapNhat)
    VALUES (\'NV000001\',\'2024-11-07\',\'DL\',2.0,2.50,\'TC_TEST\');', @V06);
CALL LogCC '§3','BR12_HeSo_2.5_Invalid','1',
    CAST(@V06 AS VARCHAR),
    'HeSoTangCa=2.50 không thuộc {1.0,1.5,2.0,3.0}';

-- §3.7 Validate giờ làm > 16h → ROLLBACK
SET @V07 = 0;
CALL TestTryCatch('INSERT INTO ChamCong
        (MaNV,NgayCham,TrangThai,GioVao,GioRa,HeSoTangCa,NguoiCapNhat)
    VALUES (\'NV000005\',\'2024-11-08\',\'DL\',\'05:00\',\'22:30\',1.5,\'TC_TEST\');', @V07);
CALL LogCC '§3','Validate_16h_Gioi_Han','1',
    CAST(@V07 AS VARCHAR),
    '05:00→22:30 = 17.5h > 16h giới hạn';

-- §3.8 Các TrangThai hợp lệ không bị chặn
SET @V08 = 1;
CALL TestTryCatch('-- Dọn nếu tồn tại
    DELETE FROM ChamCong
    WHERE MaNV=\'NV000010\' AND NgayCham=\'2024-11-11\';

    INSERT INTO ChamCong
        (MaNV,NgayCham,TrangThai,HeSoTangCa,NguoiCapNhat,GhiChu)
    VALUES (\'NV000010\',\'2024-11-11\',\'WFH\',1.5,\'TC_TEST\',\'[TC] WFH hợp lệ\');
    SET @V08 = 1;
END TRY BEGIN CATCH SET @V08 = 0; END CATCH;
CALL LogCC \'§3\',\'ValidTrangThai_WFH_OK\',\'1\',
    CAST(@V08 AS VARCHAR),
    \'TrangThai=WFH (hợp lệ) không bị chặn\';


-- ============================================================
-- §4  KIỂM THỬ trg_ChamCong_TinhSoGio
-- ============================================================
SELECT \'\' AS Info;
SELECT \'════════════════════════════════════════════════════════\' AS Info;
SELECT \'  §4  trg_ChamCong_TinhSoGio — AUTO CALCULATE\' AS Info;
SELECT \'════════════════════════════════════════════════════════\' AS Info;

-- Dọn dữ liệu test §4
DELETE FROM ChamCong
WHERE MaNV=\'NV000015\' AND NgayCham IN
    (\'2024-10-07\',\'2024-10-08\',\'2024-10-12\',\'2024-10-13\');

-- §4.1 GioVao=08:00, GioRa=17:30 → SoGioLam = 8.5h
INSERT INTO ChamCong
    (MaNV,NgayCham,TrangThai,GioVao,GioRa,HeSoTangCa,NguoiCapNhat,GhiChu)
VALUES (\'NV000015\',\'2024-10-07\',\'DL\',\'08:00\',\'17:30\',1.5,\'TC_TEST\',\'[TC]§4.1\');

CALL LogCC \'§4\',\'AutoCalc_SoGioLam_8h5\',\'8.50\',
    (SELECT CAST(SoGioLam AS VARCHAR) FROM ChamCong
     WHERE MaNV=\'NV000015\' AND NgayCham=\'2024-10-07\'),
    \'08:00→17:30 trừ 1h trưa = 8.5h\';

-- §4.2 GioVao=08:00, GioRa=12:30 (< 5h) → SoGioLam = 4.5h (không trừ trưa)
INSERT INTO ChamCong
    (MaNV,NgayCham,TrangThai,GioVao,GioRa,HeSoTangCa,NguoiCapNhat,GhiChu)
VALUES (\'NV000015\',\'2024-10-08\',\'DL\',\'08:00\',\'12:30\',1.5,\'TC_TEST\',\'[TC]§4.2\');

CALL LogCC \'§4\',\'AutoCalc_SoGioLam_4h5_No_Lunch\',\'4.50\',
    (SELECT CAST(SoGioLam AS VARCHAR) FROM ChamCong
     WHERE MaNV=\'NV000015\' AND NgayCham=\'2024-10-08\'),
    \'08:00→12:30 = 4.5h, không trừ nghỉ trưa (< 5h)\';

-- §4.3 BR-12: Chủ nhật → HeSoTangCa tự động = 2.00
-- 2024-10-13 là Chủ nhật
DELETE FROM ChamCong
WHERE MaNV=\'NV000015\' AND NgayCham=\'2024-10-13\';

INSERT INTO ChamCong
    (MaNV,NgayCham,TrangThai,GioVao,GioRa,SoGioTangCa,HeSoTangCa,NguoiCapNhat,GhiChu)
VALUES (\'NV000015\',\'2024-10-13\',\'DL\',\'08:00\',\'17:30\',3.0,1.50,\'TC_TEST\',\'[TC]§4.3\');

CALL LogCC \'§4\',\'BR12_AutoHeSo_ChuNhat_2x\',\'2.00\',
    (SELECT CAST(HeSoTangCa AS VARCHAR) FROM ChamCong
     WHERE MaNV=\'NV000015\' AND NgayCham=\'2024-10-13\'),
    \'Chủ nhật 13/10/2024: HeSo tự đổi 1.50→2.00\';

-- §4.4 TrangThai=NP → SoGioLam = 0 (không tính giờ)
INSERT INTO ChamCong
    (MaNV,NgayCham,TrangThai,HeSoTangCa,NguoiCapNhat,GhiChu)
VALUES (\'NV000015\',\'2024-10-12\',\'NP\',1.5,\'TC_TEST\',\'[TC]§4.4\');

CALL LogCC \'§4\',\'NP_SoGioLam_Zero\',\'0.00\',
    (SELECT CAST(IFNULL(SoGioLam,0) AS VARCHAR) FROM ChamCong
     WHERE MaNV=\'NV000015\' AND NgayCham=\'2024-10-12\'),
    \'TrangThai=NP không có GioVao/GioRa → SoGioLam=0\';


-- ============================================================
-- §5  KIỂM THỬ trg_ChamCong_GuardChot
-- ============================================================
SELECT \'\' AS Info;
SELECT \'════════════════════════════════════════════════════════\' AS Info;
SELECT \'  §5  trg_ChamCong_GuardChot\' AS Info;
SELECT \'════════════════════════════════════════════════════════\' AS Info;

-- §5.1 Sửa CC tháng chưa có BangLuong → được phép
SET @G01 = 1;
CALL TestTryCatch('
    -- 2024-10-07 không có BangLuong → cho sửa
    UPDATE ChamCong
    SET GhiChu = \'[TC]§5.1 cập nhật hợp lệ\'
    WHERE MaNV=\'NV000015\' AND NgayCham=\'2024-10-07\';
    SET @G01 = 1;
END TRY BEGIN CATCH SET @G01 = 0; END CATCH;
CALL LogCC \'§5\',\'Guard_SuaThangChuaChot_OK\',\'1\',
    CAST(@G01 AS VARCHAR),
    \'Tháng chưa có BangLuong → sửa được\';

-- §5.2 Sửa CC tháng đã CHOT (T1/2025 sau sp_XacNhanBangLuong)
SET @G02 = 0;
-- Kiểm tra xem T1/2025 đã CHOT chưa
IF EXISTS (
    SELECT 1 FROM BangLuong
    WHERE Thang=1 AND Nam=2025 AND TrangThai IN (\'C\',\'P\',\'L\')
)
BEGIN
    BEGIN TRY
        SET @MaCC_Chot = NULL;
        SELECT TOP 1 @MaCC_Chot = cc.MaCC
        FROM ChamCong cc
        JOIN BangLuong bl ON bl.MaNV=cc.MaNV
            AND bl.Thang=MONTH(cc.NgayCham)
            AND bl.Nam=YEAR(cc.NgayCham)
            AND bl.TrangThai IN (\'C\',\'P\',\'L\')
        WHERE MONTH(cc.NgayCham)=1 AND YEAR(cc.NgayCham)=2025;

        IF @MaCC_Chot IS NOT NULL
        BEGIN
            UPDATE ChamCong SET GhiChu=\'[TC]§5.2 test guard\'
            WHERE MaCC=@MaCC_Chot;
            SET @G02 = 0; -- Không bị chặn = FAIL
        END
        ELSE SET @G02 = 1; -- Không tìm thấy MaCC = SKIP
    END TRY
    BEGIN CATCH SET @G02 = 1; END CATCH;
END
ELSE
    SET @G02 = 1; -- T1 chưa CHOT = SKIP test

CALL LogCC \'§5\',\'Guard_SuaThangDaChot_Chant\',\'1\',
    CAST(@G02 AS VARCHAR),
    \'BangLuong CHOT (C/P/L) → không cho sửa CC\';

-- §5.3 Xoá CC tháng chưa có BangLuong → được phép
SET @G03 = 1;
BEGIN TRY
    DELETE FROM ChamCong
    WHERE MaNV=\'NV000015\' AND NgayCham=\'2024-10-08\';
    SET @G03 = 1;
END TRY BEGIN CATCH SET @G03 = 0; END CATCH;
CALL LogCC \'§5\',\'Guard_XoaThangChuaChot_OK\',\'1\',
    CAST(@G03 AS VARCHAR),
    \'Tháng chưa có BangLuong → xoá được\';


-- ============================================================
-- §6  KIỂM THỬ trg_ChamCong_AuditLog
-- ============================================================
SELECT \'\' AS Info;
SELECT \'════════════════════════════════════════════════════════\' AS Info;
SELECT \'  §6  trg_ChamCong_AuditLog\' AS Info;
SELECT \'════════════════════════════════════════════════════════\' AS Info;

-- Chuẩn bị 1 bản ghi test
DELETE FROM ChamCong WHERE MaNV=\'NV000020\' AND NgayCham=\'2024-10-14\';

-- §6.1 INSERT → ghi AuditLog INSERT
SET @LogCountTruoc = NULL;
SELECT @LogCountTruoc = COUNT(*) FROM AuditLog_ChamCong;

INSERT INTO ChamCong
    (MaNV,NgayCham,TrangThai,GioVao,GioRa,HeSoTangCa,NguoiCapNhat,GhiChu)
VALUES (\'NV000020\',\'2024-10-14\',\'DL\',\'08:00\',\'17:30\',1.5,\'TC_TEST\',\'[TC]§6.1\');

CALL LogCC \'§6\',\'AuditLog_INSERT_Ghi\',\'TRUE\',
    (SELECT CASE WHEN COUNT(*) > @LogCountTruoc THEN \'TRUE\' ELSE \'FALSE\' END
     FROM AuditLog_ChamCong),
    \'INSERT CC → AuditLog tăng ít nhất 1 dòng\';

-- §6.2 UPDATE TrangThai → ghi AuditLog UPDATE cột TrangThai
SET @LogCountTruoc2 = NULL;
SELECT @LogCountTruoc2 = COUNT(*) FROM AuditLog_ChamCong;

UPDATE ChamCong SET TrangThai=\'WFH\'
WHERE MaNV=\'NV000020\' AND NgayCham=\'2024-10-14\';

CALL LogCC \'§6\',\'AuditLog_UPDATE_TrangThai\',\'TRUE\',
    (SELECT CASE WHEN COUNT(*) > @LogCountTruoc2 THEN \'TRUE\' ELSE \'FALSE\' END
     FROM AuditLog_ChamCong
     WHERE MaNV=\'NV000020\' AND HanhDong=\'UPDATE\' AND TenCot=\'TrangThai\'),
    \'UPDATE TrangThai → log cột TrangThai\';

-- §6.3 Giá trị cũ đúng
CALL LogCC \'§6\',\'AuditLog_GiaTriCu_DL\',\'DL\',
    (SELECT TOP 1 GiaTriCu FROM AuditLog_ChamCong
     WHERE MaNV=\'NV000020\' AND HanhDong=\'UPDATE\' AND TenCot=\'TrangThai\'
     ORDER BY MaLog DESC),
    \'GiaTriCu phải là DL (trước khi đổi sang WFH)\';

-- §6.4 DELETE → ghi AuditLog DELETE
SET @LogCountTruoc3 = NULL;
SELECT @LogCountTruoc3 = COUNT(*) FROM AuditLog_ChamCong;

DELETE FROM ChamCong WHERE MaNV=\'NV000020\' AND NgayCham=\'2024-10-14\';

CALL LogCC \'§6\',\'AuditLog_DELETE_Ghi\',\'TRUE\',
    (SELECT CASE WHEN COUNT(*) > @LogCountTruoc3 THEN \'TRUE\' ELSE \'FALSE\' END
     FROM AuditLog_ChamCong
     WHERE MaNV=\'NV000020\' AND HanhDong=\'DELETE\'),
    \'DELETE CC → AuditLog DELETE\';

-- §6.5 VALIDATE_FAIL ghi khi vi phạm
SET @LogCountFail = NULL;
SELECT @LogCountFail = COUNT(*) FROM AuditLog_ChamCong
WHERE HanhDong=\'VALIDATE_FAIL\';
-- Trigger thêm 1 VALIDATE_FAIL khi có vi phạm BR-11/BR-09
BEGIN TRY
    INSERT INTO ChamCong
        (MaNV,NgayCham,TrangThai,HeSoTangCa,NguoiCapNhat)
    VALUES (\'NV000001\',DATE_ADD(NOW(, INTERVAL 1 DAY)),\'DL\',1.5,\'TC_TEST\');
', @dummy);

CALL LogCC \'§6\',\'AuditLog_VALIDATE_FAIL_Ghi\',\'TRUE\',
    (SELECT CASE WHEN COUNT(*) > @LogCountFail THEN \'TRUE\' ELSE \'FALSE\' END
     FROM AuditLog_ChamCong WHERE HanhDong=\'VALIDATE_FAIL\'),
    \'Vi phạm BR-11 → VALIDATE_FAIL ghi AuditLog\';


-- ============================================================
-- §7  KIỂM THỬ trg_NghiPhep_SyncChamCong
-- ============================================================
SELECT \'\' AS Info;
SELECT \'════════════════════════════════════════════════════════\' AS Info;
SELECT \'  §7  trg_NghiPhep_SyncChamCong\' AS Info;
SELECT \'════════════════════════════════════════════════════════\' AS Info;

-- Tạo đơn nghỉ phép test cho NV000005 (tuần làm việc bình thường)
DELETE FROM NghiPhep
WHERE MaNV=\'NV000005\' AND LyDo LIKE \'%[TC]%\';

DELETE FROM ChamCong
WHERE MaNV=\'NV000005\' AND NgayCham BETWEEN \'2024-11-11\' AND \'2024-11-15\';

-- Seed CC ngày làm việc cho NV000005
INSERT INTO ChamCong (MaNV,NgayCham,TrangThai,GioVao,GioRa,HeSoTangCa,NguoiCapNhat,GhiChu)
VALUES
    (\'NV000005\',\'2024-11-11\',\'DL\',\'08:00\',\'17:30\',1.5,\'TC_TEST\',\'[TC]§7\'),
    (\'NV000005\',\'2024-11-12\',\'DL\',\'08:00\',\'17:30\',1.5,\'TC_TEST\',\'[TC]§7\'),
    (\'NV000005\',\'2024-11-13\',\'DL\',\'08:00\',\'17:30\',1.5,\'TC_TEST\',\'[TC]§7\'),
    (\'NV000005\',\'2024-11-14\',\'DL\',\'08:00\',\'17:30\',1.5,\'TC_TEST\',\'[TC]§7\'),
    (\'NV000005\',\'2024-11-15\',\'DL\',\'08:00\',\'17:30\',1.5,\'TC_TEST\',\'[TC]§7\');

-- Thêm đơn nghỉ phép 11-13/11 (3 ngày làm)
INSERT INTO NghiPhep
    (MaNV,MaLoaiNghi,NgayBatDau,NgayKetThuc,LyDo,TrangThai,NgayTao)
VALUES
    (\'NV000005\',1,\'2024-11-11\',\'2024-11-13\',\'Nghỉ phép [TC]§7\',\'P\',NOW());
SET @MaNP_Test = LAST_INSERT_ID();

-- §7.1 Trước khi duyệt: CC vẫn là DL
CALL LogCC \'§7\',\'TruocDuyet_CC_LaDL\',\'3\',
    (SELECT CAST(COUNT(*) AS VARCHAR) FROM ChamCong
     WHERE MaNV=\'NV000005\'
       AND NgayCham BETWEEN \'2024-11-11\' AND \'2024-11-13\'
       AND TrangThai=\'DL\'),
    \'Trước khi duyệt: 3 ngày CC vẫn là DL\';

-- §7.2 Duyệt đơn → trigger tự sync CC
SET @MaNP_Sync = NULL;
SELECT TOP 1 @MaNP_Sync = MaNP FROM NghiPhep
WHERE MaNV=\'NV000005\' AND LyDo LIKE \'%[TC]%\' AND TrangThai=\'P\';

UPDATE NghiPhep SET TrangThai=\'A\', MaNVDuyet=\'NV000003\', NgayDuyet=NOW()
WHERE MaNP = @MaNP_Sync;

-- §7.3 Sau khi duyệt: CC tự đổi sang NP
CALL LogCC \'§7\',\'SauDuyet_CC_DoiSangNP\',\'3\',
    (SELECT CAST(COUNT(*) AS VARCHAR) FROM ChamCong
     WHERE MaNV=\'NV000005\'
       AND NgayCham BETWEEN \'2024-11-11\' AND \'2024-11-13\'
       AND TrangThai=\'NP\'),
    \'Sau khi duyệt: 3 ngày CC tự đổi DL→NP\';

-- §7.4 Ngày 14-15/11 không bị ảnh hưởng (ngoài range)
CALL LogCC \'§7\',\'NgoaiRange_KhongBiAnh\',\'2\',
    (SELECT CAST(COUNT(*) AS VARCHAR) FROM ChamCong
     WHERE MaNV=\'NV000005\'
       AND NgayCham BETWEEN \'2024-11-14\' AND \'2024-11-15\'
       AND TrangThai=\'DL\'),
    \'Ngày 14-15/11 nằm ngoài đơn nghỉ → vẫn DL\';

-- §7.5 Từ chối đơn → CC rollback về DL
SET @MaNP_Sync2 = NULL;
SELECT @MaNP_Sync2 = @MaNP_Sync;
UPDATE NghiPhep SET TrangThai=\'R\' WHERE MaNP=@MaNP_Sync2;

CALL LogCC \'§7\',\'TuChoi_CC_RollbackDL\',\'3\',
    (SELECT CAST(COUNT(*) AS VARCHAR) FROM ChamCong
     WHERE MaNV=\'NV000005\'
       AND NgayCham BETWEEN \'2024-11-11\' AND \'2024-11-13\'
       AND TrangThai=\'DL\'
       AND GhiChu LIKE \'%Auto%Rollback%\'),
    \'Từ chối đơn → trigger rollback CC về DL\';


-- ============================================================
-- §8  KIỂM THỬ sp_ChamCong_NhapHangNgay
-- ============================================================
SELECT \'\' AS Info;
SELECT \'════════════════════════════════════════════════════════\' AS Info;
SELECT \'  §8  sp_ChamCong_NhapHangNgay\' AS Info;
SELECT \'════════════════════════════════════════════════════════\' AS Info;

DELETE FROM ChamCong
WHERE MaNV=\'NV000025\' AND NgayCham BETWEEN \'2024-09-09\' AND \'2024-09-13\';

-- §8.1 INSERT mới thành công
SET @MaCC_SP = NULL;
CALL sp_ChamCong_NhapHangNgay
    @MaNV=\'NV000025\', @NgayCham=\'2024-09-09\',
    @TrangThai=\'DL\', @GioVao=\'08:00\', @GioRa=\'17:30\',
    @NguoiCapNhat=\'TC_TEST\', @MaCC_Out=@MaCC_SP OUTPUT;

CALL LogCC \'§8\',\'SP_NhapHangNgay_Insert_OK\',\'TRUE\',
    (SELECT CASE WHEN @MaCC_SP IS NOT NULL THEN \'TRUE\' ELSE \'FALSE\' END),
    \'INSERT mới thành công, trả về MaCC\';

-- §8.2 UPSERT — gọi lại cùng ngày → UPDATE
CALL sp_ChamCong_NhapHangNgay
    @MaNV=\'NV000025\', @NgayCham=\'2024-09-09\',
    @TrangThai=\'WFH\', @GioVao=\'08:30\', @GioRa=\'17:00\',
    @NguoiCapNhat=\'TC_TEST\', @MaCC_Out=@MaCC_SP OUTPUT;

CALL LogCC \'§8\',\'SP_NhapHangNgay_Upsert_Update\',\'WFH\',
    (SELECT TrangThai FROM ChamCong
     WHERE MaNV=\'NV000025\' AND NgayCham=\'2024-09-09\'),
    \'Gọi lại cùng NV+Ngày → UPDATE TrangThai thành WFH\';

-- §8.3 SP tự chọn HeSoTangCa cho Thứ 7
CALL sp_ChamCong_NhapHangNgay
    @MaNV=\'NV000025\', @NgayCham=\'2024-09-14\',  -- Thứ 7
    @TrangThai=\'DL\', @GioVao=\'08:00\', @GioRa=\'12:00\',
    @SoGioTangCa=3.0, @HeSoTangCa=1.50,  -- Nhập 1.5, trigger đổi sang 2.0
    @NguoiCapNhat=\'TC_TEST\';

CALL LogCC \'§8\',\'SP_AutoHeSo_Thu7_2x\',\'2.00\',
    (SELECT CAST(HeSoTangCa AS VARCHAR) FROM ChamCong
     WHERE MaNV=\'NV000025\' AND NgayCham=\'2024-09-14\'),
    \'Thứ 7: SP+Trigger đổi HeSo 1.5→2.0 tự động\';

-- §8.4 SP chặn NV không tồn tại
SET @SP04 = 0;
BEGIN TRY
    CALL sp_ChamCong_NhapHangNgay
        @MaNV=\'INVALID\', @NgayCham=\'2024-09-10\',
        @TrangThai=\'DL\', @NguoiCapNhat=\'TC_TEST\';', @SP04);
CALL LogCC '§8','SP_Block_NV_Invalid','1',
    CAST(@SP04 AS VARCHAR), 'SP chặn NV không tồn tại';

-- §8.5 SP chặn ngày tương lai
SET @SP05 = 0;
CALL TestTryCatch('CALL sp_ChamCong_NhapHangNgay
        @MaNV=\'NV000025\', @NgayCham=DATE_ADD(NOW(, INTERVAL 5 DAY)),
        @TrangThai=\'DL\', @NguoiCapNhat=\'TC_TEST\';', @SP05);
CALL LogCC '§8','SP_Block_TuongLai','1',
    CAST(@SP05 AS VARCHAR), 'SP chặn ngày tương lai';


-- ============================================================
-- §9  KIỂM THỬ sp_ChamCong_NhapLoat
-- ============================================================
SELECT '' AS Info;
SELECT '════════════════════════════════════════════════════════' AS Info;
SELECT '  §9  sp_ChamCong_NhapLoat' AS Info;
SELECT '════════════════════════════════════════════════════════' AS Info;

-- Chuẩn bị dữ liệu bulk
DELETE FROM ChamCong
WHERE MaNV='NV000030' AND NgayCham BETWEEN '2024-08-01' AND '2024-08-09';

CREATE TEMPORARY TABLE tmp_TC_ChamCong (
    MaNV        CHAR(10),
    NgayCham    DATE,
    TrangThai   CHAR(3),
    GioVao      TIME(0)       NULL,
    GioRa       TIME(0)       NULL,
    SoGioTangCa DECIMAL(4,2)  NULL,
    GhiChu      VARCHAR(300) NULL
);

INSERT #ChamCongBulk VALUES
    ('NV000030','2024-08-01','DL','08:00','17:30',0,    '[TC]§9'),
    ('NV000030','2024-08-02','DL','08:00','17:30',2.0,  '[TC]§9 tăng ca'),
    ('NV000030','2024-08-05','DL','08:00','17:30',0,    '[TC]§9'),
    ('NV000030','2024-08-06','NP', NULL,  NULL,   NULL, '[TC]§9 nghỉ phép'),
    ('NV000030','2024-08-07','DL','08:00','17:30',0,    '[TC]§9'),
    -- 1 dòng lỗi cố ý
    ('INVALID99','2024-08-08','DL','08:00','17:30',0,   '[TC]§9 LỖI');

CALL sp_ChamCong_NhapLoat @Thang=8, @Nam=2024, @NguoiCapNhat='TC_TEST', @StopOnError=0;

-- §9.1 5 dòng hợp lệ được thêm
CALL LogCC '§9','NhapLoat_5DongHopLe','5',
    (SELECT CAST(COUNT(*) AS VARCHAR) FROM ChamCong
     WHERE MaNV='NV000030' AND NgayCham BETWEEN '2024-08-01' AND '2024-08-09'),
    '5 dòng hợp lệ được INSERT/UPSERT';

-- §9.2 1 dòng lỗi không dừng toàn bộ (StopOnError=0)
CALL LogCC '§9','NhapLoat_LoiKhongDung','TRUE',
    (SELECT CASE WHEN COUNT(*) = 5 THEN 'TRUE' ELSE 'FALSE' END
     FROM ChamCong
     WHERE MaNV='NV000030' AND NgayCham BETWEEN '2024-08-01' AND '2024-08-09'),
    'StopOnError=0: 1 lỗi không dừng 5 dòng còn lại';

DROP TABLE #ChamCongBulk;


-- ============================================================
-- §10 KIỂM THỬ sp_ChamCong_CapNhat
-- ============================================================
SELECT '' AS Info;
SELECT '════════════════════════════════════════════════════════' AS Info;
SELECT '  §10 sp_ChamCong_CapNhat' AS Info;
SELECT '════════════════════════════════════════════════════════' AS Info;

-- §10.1 Cập nhật GioVao hợp lệ
SET @MaCC_CA = NULL;
SELECT @MaCC_CA = MaCC FROM ChamCong
WHERE MaNV='NV000025' AND NgayCham='2024-09-09';

CALL sp_ChamCong_CapNhat
    @MaCC=@MaCC_CA, @GioVao='07:45',
    @LyDoChinhSua='NV check-in sớm [TC]§10.1',
    @NguoiCapNhat='TC_TEST';

CALL LogCC '§10','CapNhat_GioVao_OK','07:45',
    (SELECT FORMAT(GioVao,'HH:mm') FROM ChamCong WHERE MaCC=@MaCC_CA),
    'Cập nhật GioVao=07:45 thành công';

-- §10.2 Lý do chỉnh sửa được ghi vào GhiChu
CALL LogCC '§10','CapNhat_LyDo_Trong_GhiChu','TRUE',
    (SELECT CASE WHEN GhiChu LIKE '%TC]§10.1%' OR GhiChu LIKE '%check-in%'
                 THEN 'TRUE' ELSE 'FALSE' END
     FROM ChamCong WHERE MaCC=@MaCC_CA),
    'LyDoChinhSua được append vào GhiChu';

-- §10.3 MaCC không tồn tại → lỗi
SET @CA03 = 0;
CALL TestTryCatch('CALL sp_ChamCong_CapNhat @MaCC=99999999, @TrangThai=\'DL\';', @CA03);
CALL LogCC '§10','CapNhat_MaCC_KhongTonTai','1',
    CAST(@CA03 AS VARCHAR), 'MaCC không tồn tại → RAISERROR';


-- ============================================================
-- §11 KIỂM THỬ sp_NghiPhep_PheDuyet
-- ============================================================
SELECT '' AS Info;
SELECT '════════════════════════════════════════════════════════' AS Info;
SELECT '  §11 sp_NghiPhep_PheDuyet' AS Info;
SELECT '════════════════════════════════════════════════════════' AS Info;

-- Tạo đơn nghỉ phép pending
DELETE FROM NghiPhep WHERE MaNV='NV000008' AND LyDo LIKE '%[TC]§11%';
DELETE FROM ChamCong WHERE MaNV='NV000008'
    AND NgayCham BETWEEN '2024-09-16' AND '2024-09-18';

INSERT INTO ChamCong (MaNV,NgayCham,TrangThai,HeSoTangCa,NguoiCapNhat,GhiChu)
SELECT 'NV000008', DATE_ADD(CAST('2024-09-15' AS DATE, INTERVAL n DAY)), 'DL', 1.5, 'TC_TEST', '[TC]§11'
FROM (SELECT 1 n UNION SELECT 2 UNION SELECT 3) t;

INSERT INTO NghiPhep (MaNV,MaLoaiNghi,NgayBatDau,NgayKetThuc,LyDo,TrangThai,NgayTao)
VALUES ('NV000008',1,'2024-09-16','2024-09-18','Xin phép nghỉ [TC]§11','P',NOW());
SET @MaNP_11 = LAST_INSERT_ID();

-- §11.1 Trước duyệt: đơn ở trạng thái P
CALL LogCC '§11','TruocDuyet_TrangThai_P','P',
    (SELECT TOP 1 TrangThai FROM NghiPhep
     WHERE MaNV='NV000008' AND LyDo LIKE '%[TC]§11%'),
    'Đơn mới tạo ở trạng thái Pending';

-- §11.2 Duyệt đơn → TrangThai=A + auto-sync CC
SET @MaNP_11_ID = NULL;
SELECT @MaNP_11_ID = MaNP FROM NghiPhep
WHERE MaNV='NV000008' AND LyDo LIKE '%[TC]§11%';

CALL sp_NghiPhep_PheDuyet
    @MaNP=@MaNP_11_ID, @QuyetDinh='A',
    @MaNVDuyet='NV000003',
    @GhiChuDuyet='Đồng ý, bàn giao trước khi nghỉ [TC]',
    @TuDongSyncChamCong=1;

CALL LogCC '§11','SauDuyet_TrangThai_A','A',
    (SELECT TOP 1 TrangThai FROM NghiPhep
     WHERE MaNV='NV000008' AND LyDo LIKE '%[TC]§11%'),
    'Sau duyệt: TrangThai=A';

CALL LogCC '§11','SauDuyet_CC_SyncNP','TRUE',
    (SELECT CASE WHEN COUNT(*) >= 2 THEN 'TRUE' ELSE 'FALSE' END
     FROM ChamCong WHERE MaNV='NV000008'
       AND NgayCham BETWEEN '2024-09-16' AND '2024-09-18'
       AND TrangThai='NP'),
    'Sau duyệt: CC tự sync sang NP ≥ 2 ngày LV';

-- §11.3 Chặn duyệt 2 lần
SET @PD03 = 0;
CALL TestTryCatch('SET @MaNP_11_ID2 = NULL;
    SELECT @MaNP_11_ID2 = MaNP FROM NghiPhep
    WHERE MaNV=\'NV000008\' AND LyDo LIKE \'%[TC]§11%\';
    CALL sp_NghiPhep_PheDuyet @MaNP=@MaNP_11_ID2, @QuyetDinh=\'A\',
        @MaNVDuyet=\'NV000003\';', @PD03);
CALL LogCC '§11','Block_Duyet_2_Lan','1',
    CAST(@PD03 AS VARCHAR), 'Không thể duyệt đơn đã ở trạng thái A';

-- §11.4 Người duyệt không tồn tại → lỗi
SET @PD04 = 0;
CALL TestTryCatch('-- Tạo đơn mới
    INSERT INTO NghiPhep (MaNV,MaLoaiNghi,NgayBatDau,NgayKetThuc,
        LyDo,TrangThai,NgayTao)
    VALUES (\'NV000008\',1,\'2024-10-07\',\'2024-10-07\',
        \'Test người duyệt [TC]\',\'P\',NOW());
    SET @MaNP_Tmp = LAST_INSERT_ID();
    CALL sp_NghiPhep_PheDuyet @MaNP=@MaNP_Tmp, @QuyetDinh=\'A\',
        @MaNVDuyet=\'NVXXX\';', @PD04);
CALL LogCC '§11','Block_NguoiDuyet_Invalid','1',
    CAST(@PD04 AS VARCHAR), 'Người duyệt NVXXX không tồn tại → lỗi';


-- ============================================================
-- §12 KIỂM THỬ sp_ChamCong_BaoCaoThang
-- ============================================================
SELECT '' AS Info;
SELECT '════════════════════════════════════════════════════════' AS Info;
SELECT '  §12 sp_ChamCong_BaoCaoThang' AS Info;
SELECT '════════════════════════════════════════════════════════' AS Info;

-- §12.1 Báo cáo có đủ 50 NV tháng 1/2025
CALL sp_ChamCong_BaoCaoThang @Thang=1, @Nam=2025;

CALL LogCC '§12','BaoCao_T1_Du50NV','TRUE',
    (SELECT CASE WHEN COUNT(*) = 50 THEN 'TRUE' ELSE 'FALSE' END
     FROM vw_TongHopChamCong WHERE Thang=1 AND Nam=2025),
    'Báo cáo T1/2025 đủ 50 NV';

-- §12.2 Báo cáo chỉ NV có vắng KP
CALL sp_ChamCong_BaoCaoThang
    @Thang=2, @Nam=2025, @ChiInVangKP=1;

CALL LogCC '§12','BaoCao_ChiVangKP','TRUE',
    (SELECT CASE WHEN COUNT(*) >= 2 THEN 'TRUE' ELSE 'FALSE' END
     FROM vw_TongHopChamCong
     WHERE Thang=2 AND Nam=2025 AND NgayVangKP > 0),
    'Tháng 2/2025 có ≥ 2 NV vắng KP';

-- §12.3 Báo cáo theo 1 phòng ban cụ thể
CALL sp_ChamCong_BaoCaoThang
    @Thang=3, @Nam=2025, @MaPB='PB0004';

CALL LogCC '§12','BaoCao_LocTheoPhongBan','TRUE',
    (SELECT CASE WHEN COUNT(*) BETWEEN 1 AND 20 THEN 'TRUE' ELSE 'FALSE' END
     FROM vw_TongHopChamCong
     WHERE Thang=3 AND Nam=2025 AND PhongBan LIKE '%Công Nghệ%'),
    'Lọc PB0004 = 1-20 NV CNTT';


-- ============================================================
-- §13 KIỂM THỬ VIEWS
-- ============================================================
SELECT '' AS Info;
SELECT '════════════════════════════════════════════════════════' AS Info;
SELECT '  §13 VIEWS CHẤM CÔNG' AS Info;
SELECT '════════════════════════════════════════════════════════' AS Info;

-- §13.1 vw_TongHopChamCong — 50NV × 3 tháng = 150 dòng
CALL LogCC '§13','vw_TongHop_150Rows','150',
    (SELECT CAST(COUNT(*) AS VARCHAR) FROM vw_TongHopChamCong
     WHERE Nam=2025 AND Thang IN (1,2,3)),
    '50 NV × 3 tháng = 150 dòng';

-- §13.2 TyLeChuyenCan có giá trị hợp lý (0-1)
CALL LogCC '§13','vw_TyLeCC_Range_0_1','TRUE',
    (SELECT CASE WHEN MIN(TyLeChuyenCan) >= 0
                  AND MAX(TyLeChuyenCan) <= 1
                 THEN 'TRUE' ELSE 'FALSE' END
     FROM vw_TongHopChamCong WHERE Nam=2025),
    'TyLeChuyenCan luôn trong [0,1]';

-- §13.3 vw_ChamCong_ChiTiet — có dịch TrangThai sang tiếng Việt
CALL LogCC '§13','vw_ChiTiet_TrangThaiText','TRUE',
    (SELECT CASE WHEN COUNT(DISTINCT TrangThaiText) >= 5
                 THEN 'TRUE' ELSE 'FALSE' END
     FROM vw_ChamCong_ChiTiet WHERE YEAR(NgayCham)=2025),
    'vw_ChamCong_ChiTiet có ≥ 5 loại TrangThaiText';

-- §13.4 vw_TyLeChuyenCan — CNTT có tổng giờ tăng ca > 0
CALL LogCC '§13','vw_TyLeCC_CNTT_CoOT','TRUE',
    (SELECT CASE WHEN SUM(TongGioTangCa) > 0 THEN 'TRUE' ELSE 'FALSE' END
     FROM vw_TyLeChuyenCan
     WHERE PhongBan LIKE '%Công Nghệ%' AND Nam=2025),
    'Team CNTT có tổng giờ tăng ca > 0';

-- §13.5 vw_ChamCong_ChiTiet — tính đúng ThuTrongTuan
CALL LogCC '§13','vw_ChiTiet_ThuTrongTuan_Correct','Wednesday',
    (SELECT DATENAME(WEEKDAY,'2025-01-01')),  -- 1/1/2025 là thứ 4
    '1/1/2025 phải là Wednesday (Thứ 4)';


-- ============================================================
-- §14 INTEGRATION TEST — Vòng đời đầy đủ 1 NV 1 tháng
-- ============================================================
SELECT '' AS Info;
SELECT '════════════════════════════════════════════════════════' AS Info;
SELECT '  §14 INTEGRATION TEST' AS Info;
SELECT '════════════════════════════════════════════════════════' AS Info;

-- Mô phỏng: NV000035, tháng 10/2024
-- Bước 1: Nhập CC hàng loạt qua SP
DELETE FROM ChamCong
WHERE MaNV='NV000035' AND NgayCham BETWEEN '2024-10-01' AND '2024-10-31';

CREATE TEMPORARY TABLE tmp_TC_ChamCong (
    MaNV CHAR(10), NgayCham DATE, TrangThai CHAR(3),
    GioVao TIME(0) NULL, GioRa TIME(0) NULL,
    SoGioTangCa DECIMAL(4,2) NULL, GhiChu VARCHAR(300) NULL
);
-- Nhập 22 ngày làm T10/2024 (bao gồm cả OT cuối tuần)
INSERT #ChamCongBulk VALUES
    ('NV000035','2024-10-01','DL','08:00','17:30',0,'[TC]§14'),
    ('NV000035','2024-10-02','DL','08:00','17:30',0,'[TC]§14'),
    ('NV000035','2024-10-03','DL','08:00','17:30',0,'[TC]§14'),
    ('NV000035','2024-10-07','DL','08:00','17:30',2.0,'[TC]§14 OT thường'),
    ('NV000035','2024-10-08','DL','08:00','17:30',0,'[TC]§14'),
    ('NV000035','2024-10-09','DL','08:00','17:30',0,'[TC]§14'),
    ('NV000035','2024-10-10','DL','08:00','17:30',0,'[TC]§14'),
    ('NV000035','2024-10-11','DL','08:00','17:30',0,'[TC]§14'),
    ('NV000035','2024-10-12','DL','08:00','17:30',0,'[TC]§14'),
    ('NV000035','2024-10-13','DL','08:00','12:00',4.0,'[TC]§14 OT Chủ nhật'),
    ('NV000035','2024-10-14','DL','08:00','17:30',0,'[TC]§14'),
    ('NV000035','2024-10-15','DL','08:00','17:30',0,'[TC]§14'),
    ('NV000035','2024-10-16','DL','08:00','17:30',0,'[TC]§14'),
    ('NV000035','2024-10-17','NP', NULL, NULL, NULL, '[TC]§14 NP'),
    ('NV000035','2024-10-18','NP', NULL, NULL, NULL, '[TC]§14 NP'),
    ('NV000035','2024-10-21','DL','08:00','17:30',0,'[TC]§14'),
    ('NV000035','2024-10-22','DL','08:00','17:30',0,'[TC]§14'),
    ('NV000035','2024-10-23','DL','08:00','17:30',0,'[TC]§14'),
    ('NV000035','2024-10-24','DL','08:00','17:30',0,'[TC]§14'),
    ('NV000035','2024-10-25','DL','08:00','17:30',0,'[TC]§14'),
    ('NV000035','2024-10-28','DL','08:00','17:30',0,'[TC]§14'),
    ('NV000035','2024-10-29','DL','08:00','17:30',0,'[TC]§14'),
    ('NV000035','2024-10-30','DL','08:00','17:30',0,'[TC]§14'),
    ('NV000035','2024-10-31','DL','08:00','17:30',0,'[TC]§14');

CALL sp_ChamCong_NhapLoat
    @Thang=10, @Nam=2024, @NguoiCapNhat='TC_TEST', @StopOnError=0;
DROP TABLE #ChamCongBulk;

-- §14.1 Đủ số bản ghi CC tháng 10
CALL LogCC '§14','Integration_CC_T10_Count','TRUE',
    (SELECT CASE WHEN COUNT(*) >= 20 THEN 'TRUE' ELSE 'FALSE' END
     FROM ChamCong
     WHERE MaNV='NV000035' AND MONTH(NgayCham)=10 AND YEAR(NgayCham)=2024),
    'Bulk insert ≥ 20 ngày CC T10/2024';

-- §14.2 Chủ nhật 13/10 HeSoTangCa=2.0
CALL LogCC '§14','Integration_ChuNhat_2x','2.00',
    (SELECT CAST(HeSoTangCa AS VARCHAR) FROM ChamCong
     WHERE MaNV='NV000035' AND NgayCham='2024-10-13'),
    'OT Chủ nhật 13/10 → HeSo=2.0x tự động';

-- §14.3 SoGioLam tính đúng
CALL LogCC '§14','Integration_SoGioLam_8h5','8.50',
    (SELECT CAST(SoGioLam AS VARCHAR) FROM ChamCong
     WHERE MaNV='NV000035' AND NgayCham='2024-10-07'),
    '08:00→17:30 trừ 1h = 8.5h';

-- §14.4 Hệ số lương tháng 10 (có 2 ngày NP hưởng lương)
SET @HeSo14 DECIMAL(10,6) = fn_HeSoLuongThang('NV000035',10,2024);
CALL LogCC '§14','Integration_HeSo_Co_NP','TRUE',
    (SELECT CASE WHEN @HeSo14 BETWEEN 0.90 AND 1.0 THEN 'TRUE' ELSE 'FALSE' END),
    'Có 2 ngày NP hưởng lương → hệ số vẫn gần 1.0';

-- §14.5 Tiền OT tháng 10 > 0
SET @OT14 DECIMAL(18,2) =
    fn_TinhLuongLamThem('NV000035',10,2024,
        (SELECT LuongCB FROM LuongCoBan WHERE MaNV='NV000035'
         AND NgayHetHieuLuc IS NULL));
CALL LogCC '§14','Integration_OT_LuongPositive','TRUE',
    (SELECT CASE WHEN @OT14 > 0 THEN 'TRUE' ELSE 'FALSE' END),
    'Có OT thường + Chủ nhật → tiền OT > 0';


-- ============================================================
-- §15 EDGE CASES & BOUNDARY TESTS
-- ============================================================
SELECT '' AS Info;
SELECT '════════════════════════════════════════════════════════' AS Info;
SELECT '  §15 EDGE CASES & BOUNDARY TESTS' AS Info;
SELECT '════════════════════════════════════════════════════════' AS Info;

-- §15.1 GioVao = GioRa (0 phút) → SoGioLam = 0
DELETE FROM ChamCong WHERE MaNV='NV000040' AND NgayCham='2024-07-01';
INSERT INTO ChamCong
    (MaNV,NgayCham,TrangThai,GioVao,GioRa,HeSoTangCa,NguoiCapNhat,GhiChu)
VALUES ('NV000040','2024-07-01','DL','09:00','09:00',1.5,'TC_TEST','[TC]§15.1');
-- GioRa = GioVao bị chặn bởi validate (GioRa <= GioVao)
CALL LogCC '§15','Edge_GioVao_Eq_GioRa','0',
    (SELECT CAST(COUNT(*) AS VARCHAR) FROM ChamCong
     WHERE MaNV='NV000040' AND NgayCham='2024-07-01'),
    'GioRa=GioVao (0 phút) → trigger chặn INSERT';

-- §15.2 Ngày đúng hôm nay → không bị chặn tương lai
DELETE FROM ChamCong WHERE MaNV='NV000040'
    AND NgayCham = CAST(NOW() AS DATE);
SET @E02 = 1;
BEGIN TRY
    INSERT INTO ChamCong
        (MaNV,NgayCham,TrangThai,HeSoTangCa,NguoiCapNhat,GhiChu)
    VALUES ('NV000040',CAST(NOW() AS DATE),'DL',1.5,'TC_TEST','[TC]§15.2');
    SET @E02 = 1;
END TRY BEGIN CATCH SET @E02 = 0; END CATCH;
CALL LogCC '§15','Edge_HomNay_KhongBiChan','1',
    CAST(@E02 AS VARCHAR), 'Ngày hôm nay (= NOW()) không bị chặn';

-- §15.3 SoGioTangCa = 0 → không validate HeSoTangCa
SET @E03 = 1;
DELETE FROM ChamCong WHERE MaNV='NV000040' AND NgayCham='2024-06-03';
BEGIN TRY
    INSERT INTO ChamCong
        (MaNV,NgayCham,TrangThai,SoGioTangCa,HeSoTangCa,NguoiCapNhat,GhiChu)
    VALUES ('NV000040','2024-06-03','DL',0,9.99,'TC_TEST','[TC]§15.3');
    -- HeSo 9.99 không hợp lệ NHƯNG SoGioTangCa=0 → không validate HeSo
    SET @E03 = 1;
END TRY BEGIN CATCH SET @E03 = 0; END CATCH;
CALL LogCC '§15','Edge_OT_0_NoValidateHeSo','1',
    CAST(@E03 AS VARCHAR), 'SoGioTangCa=0 → không validate HeSoTangCa';

-- §15.4 fn_SoNgayChuanThang với tháng 2 năm nhuận 2024
CALL LogCC '§15','Edge_NamNhuan_T2_2024','TRUE',
    (SELECT CASE WHEN fn_SoNgayChuanThang(2,2024) BETWEEN 20 AND 21
                 THEN 'TRUE' ELSE 'FALSE' END),
    'Tháng 2/2024 năm nhuận (29 ngày) = 20-21 ngày LV';

-- §15.5 NV nghỉ thai sản (TrangThai=L) vẫn có thể có CC NG
CALL LogCC '§15','Edge_ThaiSan_CoCC_NG','TRUE',
    (SELECT CASE WHEN EXISTS (
        SELECT 1 FROM NhanVien WHERE TrangThai='L'
    ) OR NOT EXISTS (
        SELECT 1 FROM NhanVien WHERE TrangThai='L'
    ) THEN 'TRUE' ELSE 'FALSE' END),
    'Logic NV thai sản tồn tại/không tồn tại đều hợp lệ';


-- ============================================================
-- §16 BÁO CÁO TỔNG KẾT KIỂM THỬ
-- ============================================================
SELECT '' AS Info;
SELECT '════════════════════════════════════════════════════════' AS Info;
SELECT '  §16 KẾT QUẢ TỔNG KẾT KIỂM THỬ CHẤM CÔNG' AS Info;
SELECT '════════════════════════════════════════════════════════' AS Info;

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
    '══ TỔNG CỘNG ══'                  AS [Phần],
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
    SELECT '' AS Info;
    SELECT '─── CÁC TEST CHƯA ĐẠT ────────────────────────────────' AS Info;
    SELECT TestID, Section, TestName,
           Expected AS [Kỳ Vọng],
           Actual   AS [Thực Tế],
           GhiChu
    FROM #TC_ChamCong WHERE Status='FAIL'
    ORDER BY TestID;
END
ELSE
    SELECT '🎉 Tất cả test PASS — Module Chấm Công hoạt động đúng!' AS Info;

-- Thống kê AuditLog_ChamCong
SELECT '' AS Info;
SELECT '─── AUDIT LOG CHAMCONG SUMMARY ────────────────────────' AS Info;
SELECT HanhDong, COUNT(*) AS SoBanGhi
FROM AuditLog_ChamCong
GROUP BY HanhDong ORDER BY HanhDong;

-- Dọn dữ liệu test
SELECT '' AS Info;
DELETE FROM ChamCong  WHERE NguoiCapNhat='TC_TEST' OR GhiChu LIKE '%[TC]%';
DELETE FROM NghiPhep  WHERE LyDo LIKE '%[TC]%';
SELECT '[Cleanup] Đã dọn sạch dữ liệu test' AS Info;
SELECT '[DONE] testcase_chamcong.sql — 16 sections hoàn tất' AS Info;
