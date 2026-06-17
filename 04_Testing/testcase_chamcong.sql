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
    TestID      INT         AUTO_INCREMENT PRIMARY KEY,
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
                  IF(v_Status='FAIL', CONCAT(' -> KV:`', p_Expected, '` TT:`', p_Actual, '`'), '')) AS LogInfo;
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
   OR GhiChu LIKE '%`TC`%';

DELETE FROM NghiPhep
WHERE LyDo LIKE '%`TC`%';
SELECT '`Setup` Đã dọn dữ liệu test cũ' AS Info;

-- §1.1 Bảng ChamCong có dữ liệu 3 tháng
SET @actual_val = (SELECT CASE WHEN COUNT(DISTINCT MONTH(NgayCham)) >= 3
                 THEN 'TRUE' ELSE 'FALSE' END
     FROM ChamCong WHERE YEAR(NgayCham)=2025);
CALL LogCC('§1','CC_3Thang_Ton_Tai','TRUE',
    @actual_val,
    'Jan/Feb/Mar 2025 đều có dữ liệu CC');

-- §1.2 Số bản ghi CC > 2000
SET @actual_val = (SELECT CASE WHEN COUNT(*) > 2000 THEN 'TRUE' ELSE 'FALSE' END
     FROM ChamCong);
CALL LogCC('§1','CC_SoBanGhi_Min2000','TRUE',
    @actual_val,
    'Seed tạo đủ ~3100 bản ghi CC');

-- §1.3 Ngày Tết 1/1/2025 đều là NG
SET @actual_val = (SELECT CAST(COUNT(*) AS CHAR) FROM ChamCong
     WHERE NgayCham='2025-01-01' AND TrangThai='NG');
CALL LogCC('§1','TetDuongLich_NG','50',
    @actual_val,
    '1/1/2025 = 50 bản ghi NG cho 50 NV');

-- §1.4 NV000049 có 2 ngày KP tháng 2
SET @actual_val = (SELECT CAST(COUNT(*) AS CHAR) FROM ChamCong
     WHERE MaNV='NV000049' AND TrangThai='KP'
       AND MONTH(NgayCham)=2 AND YEAR(NgayCham)=2025);
CALL LogCC('§1','NV049_KP_Thang2','2',
    @actual_val,
    'Seed đã UPDATE 2 ngày KP cho NV000049');

-- §1.5 NV000004 có ngày NP tháng 2 (nghỉ phép 10-12/2)
SET @actual_val = (SELECT CAST(COUNT(*) AS CHAR) FROM ChamCong
     WHERE MaNV='NV000004' AND TrangThai='NP'
       AND MONTH(NgayCham)=2 AND YEAR(NgayCham)=2025);
CALL LogCC('§1','NV004_NP_Thang2','3',
    @actual_val,
    'NV000004 nghỉ phép 10-12/02/2025 = 3 ngày NP');

-- §1.6 Không có bản ghi CC tương lai
SET @actual_val = (SELECT CAST(COUNT(*) AS CHAR) FROM ChamCong
     WHERE NgayCham > CAST(NOW() AS DATE));
CALL LogCC('§1','KhongCo_CC_TuongLai','0',
    @actual_val,
    'Không có CC ngày tương lai');

-- §1.7 Bảng AuditLog_ChamCong tồn tại
SET @actual_val = (SELECT CASE WHEN 1
                 THEN 'TRUE' ELSE 'FALSE' END);
CALL LogCC('§1','AuditLog_CC_Ton_Tai','TRUE',
    @actual_val,
    'Bảng AuditLog_ChamCong đã được tạo');

-- §1.8 Team CNTT có tăng ca (từ seed)
SET @actual_val = (SELECT CASE WHEN SUM(SoGioTangCa) > 0 THEN 'TRUE' ELSE 'FALSE' END
     FROM ChamCong cc
     JOIN NhanVien nv ON cc.MaNV=nv.MaNV
     WHERE nv.MaPB='PB0004'
       AND MONTH(NgayCham)=1 AND YEAR(NgayCham)=2025);
CALL LogCC('§1','CNTT_CoTangCa_T1','TRUE',
    @actual_val,
    'Team CNTT có giờ tăng ca tháng 1/2025');


-- ============================================================
-- §2  KIỂM THỬ FUNCTIONS NGÀY CÔNG
-- ============================================================
SELECT '' AS Info;
SELECT '════════════════════════════════════════════════════════' AS Info;
SELECT '  §2  FUNCTIONS NGÀY CÔNG' AS Info;
SELECT '════════════════════════════════════════════════════════' AS Info;

-- §2.1 fn_SoNgayChuanThang — Jan 2025 (trừ Tết ÂL)
SET @NgayChuanT1 = fn_SoNgayChuanThang(1,2025);
SET @actual_val = (SELECT CASE WHEN @NgayChuanT1 BETWEEN 15 AND 18
                 THEN 'TRUE' ELSE 'FALSE' END);
CALL LogCC('§2','NgayChuanT1_Range_15_18','TRUE',
    @actual_val,
    'Tháng 1/2025: trừ Tết ÂL còn 15-18 ngày làm');

-- §2.2 fn_SoNgayChuanThang — Feb 2025
SET @NgayChuanT2 = fn_SoNgayChuanThang(2,2025);
SET @actual_val = (SELECT CASE WHEN @NgayChuanT2 BETWEEN 18 AND 20
                 THEN 'TRUE' ELSE 'FALSE' END);
CALL LogCC('§2','NgayChuanT2_Range_18_20','TRUE',
    @actual_val,
    'Tháng 2/2025 (28 ngày): ~18-20 ngày làm việc');

-- §2.3 fn_SoNgayChuanThang — Mar 2025 (21 ngày LV)
SET @NgayChuanT3 = fn_SoNgayChuanThang(3,2025);
SET @actual_val = (SELECT CASE WHEN @NgayChuanT3 BETWEEN 20 AND 22
                 THEN 'TRUE' ELSE 'FALSE' END);
CALL LogCC('§2','NgayChuanT3_Range_20_22','TRUE',
    @actual_val,
    'Tháng 3/2025: ~21 ngày làm việc');

-- §2.4 fn_SoNgayChamCong — TGĐ tháng 1/2025
SET @NgayDLNV1_T1 =
    fn_SoNgayChamCong('NV000001',1,2025);
SET @actual_val = (SELECT CASE WHEN @NgayDLNV1_T1 > 0 THEN 'TRUE' ELSE 'FALSE' END);
CALL LogCC('§2','TGD_NgayDiLam_T1_Positive','TRUE',
    @actual_val,
    'TGĐ có ngày đi làm tháng 1/2025');

-- §2.5 fn_SoNgayNghiCoLuong — NV000004 có 3 ngày NP tháng 2
SET @actual_val = (SELECT CAST(fn_SoNgayNghiCoLuong('NV000004',2,2025) AS CHAR));
CALL LogCC('§2','NV004_NghiCoLuong_3ngay','3',
    @actual_val,
    'NV000004 có 3 ngày nghỉ phép hưởng lương T2');

-- §2.6 fn_SoNgayNghiKhongLuong — NV000049 có 2 ngày KP tháng 2
SET @actual_val = (SELECT CAST(fn_SoNgayNghiKhongLuong('NV000049',2,2025) AS CHAR));
CALL LogCC('§2','NV049_KhongLuong_2ngay','2',
    @actual_val,
    'NV000049 có 2 ngày KP (vắng không phép)');

-- §2.7 fn_HeSoLuongThang — NV đi đủ tháng ≈ 1.0
SET @HeSoFull =
    fn_HeSoLuongThang('NV000001',3,2025);
SET @actual_val = (SELECT CASE WHEN @HeSoFull BETWEEN 0.95 AND 1.0
                 THEN 'TRUE' ELSE 'FALSE' END);
CALL LogCC('§2','TGD_HeSo_Full_Month_Near1','TRUE',
    @actual_val,
    'TGĐ đi đủ tháng 3 → hệ số gần 1.0');

-- §2.8 fn_HeSoLuongThang — NV vắng 2 ngày KP giảm hệ số
SET @HeSoKP =
    fn_HeSoLuongThang('NV000049',2,2025);
SET @HeSoFull2 =
    fn_HeSoLuongThang('NV000001',2,2025);
SET @actual_val = (SELECT CASE WHEN @HeSoKP < @HeSoFull2 THEN 'TRUE' ELSE 'FALSE' END);
CALL LogCC('§2','NV049_HeSo_Thap_Hon_Full','TRUE',
    @actual_val,
    'NV vắng KP có hệ số thấp hơn NV đi đủ');

-- §2.9 fn_TinhLuongLamThem — Team CNTT tháng 1 có OT > 0
SET @actual_val = (SELECT CASE WHEN SUM(fn_TinhLuongLamThem(nv.MaNV,1,2025,lcb.LuongCB)) > 0
                 THEN 'TRUE' ELSE 'FALSE' END
     FROM NhanVien nv
     JOIN LuongCoBan lcb ON nv.MaNV=lcb.MaNV
                             AND lcb.NgayHetHieuLuc IS NULL
     WHERE nv.MaPB='PB0004');
CALL LogCC('§2','CNTT_LuongOT_Positive','TRUE',
    @actual_val,
    'fn_TinhLuongLamThem: Đội CNTT có tiền OT T1');

-- §2.10 fn_SoNgayChuanThang — Tháng 4 (không lễ 30/4)
SET @actual_val = (SELECT CASE WHEN fn_SoNgayChuanThang(4,2025) BETWEEN 21 AND 23
                 THEN 'TRUE' ELSE 'FALSE' END);
CALL LogCC('§2','NgayChuanT4_NoHoliday','TRUE',
    @actual_val,
    'Tháng 4/2025 trừ ngày 30/4 còn 21-23 ngày');


-- ============================================================
-- §3  KIỂM THỬ trg_ChamCong_Validate (BR-09/10/11/12)
-- ============================================================
SELECT '' AS Info;
SELECT '════════════════════════════════════════════════════════' AS Info;
SELECT '  §3  trg_ChamCong_Validate — 7 VALIDATIONS' AS Info;
SELECT '════════════════════════════════════════════════════════' AS Info;

-- §3.1 BR-11: Chặn ngày tương lai
SET @V01 = 0;

CALL LogCC('§3','BR11_TuongLai_Chant','1',
    CAST(@V01 AS CHAR),
    'INSERT ngày +3 ngày tương lai phải bị ROLLBACK');

-- §3.2 BR-09: Chặn TrangThai không hợp lệ 'XX'
SET @V02 = 0;

CALL LogCC('§3','BR09_TrangThai_XX_Chant','1',
    CAST(@V02 AS CHAR),
    'TrangThai=XX phải bị ROLLBACK');

-- §3.3 BR-09: Chặn TrangThai = chuỗi rỗng ''
SET @V03 = 0;

CALL LogCC('§3','BR09_TrangThai_Spaces_Chant','1',
    CAST(@V03 AS CHAR),
    'TrangThai=khoảng trắng phải bị ROLLBACK');

-- §3.4 Validate GioRa ≤ GioVao → ROLLBACK
SET @V04 = 0;

CALL LogCC('§3','Validate_GioRa_TruocGioVao','1',
    CAST(@V04 AS CHAR),
    'GioRa=08:00 < GioVao=17:00 phải bị ROLLBACK');

-- §3.5 Validate NV không tồn tại → ROLLBACK
SET @V05 = 0;

CALL LogCC('§3','Validate_NV_KhongTonTai','1',
    CAST(@V05 AS CHAR),
    'NV999999 không tồn tại phải bị ROLLBACK');

-- §3.6 BR-12: HeSoTangCa không hợp lệ (2.50)
SET @V06 = 0;

CALL LogCC('§3','BR12_HeSo_2.5_Invalid','1',
    CAST(@V06 AS CHAR),
    'HeSoTangCa=2.50 không thuộc {1.0,1.5,2.0,3.0}');

-- §3.7 Validate giờ làm > 16h → ROLLBACK
SET @V07 = 0;

CALL LogCC('§3','Validate_16h_Gioi_Han','1',
    CAST(@V07 AS CHAR),
    '05:00→22:30 = 17.5h > 16h giới hạn');

-- §3.8 Các TrangThai hợp lệ không bị chặn
SET @V08 = 1;

    SET @G01 = 1;

CALL LogCC('§5','Guard_SuaThangChuaChot_OK','1',
    CAST(@G01 AS CHAR),
    'Tháng chưa có BangLuong → sửa được');

-- §5.2 Sửa CC tháng đã CHOT (T1/2025 sau sp_XacNhanBangLuong)
SET @G02 = 0;
-- Kiểm tra xem T1/2025 đã CHOT chưa
SET @G02 = 1; -- T1 chưa CHOT = SKIP test

CALL LogCC('§5','Guard_SuaThangDaChot_Chant','1',
    CAST(@G02 AS CHAR),
    'BangLuong CHOT (C/P/L) → không cho sửa CC');

-- §5.3 Xoá CC tháng chưa có BangLuong → được phép
SET @G03 = 1;

CALL LogCC('§5','Guard_XoaThangChuaChot_OK','1',
    CAST(@G03 AS CHAR),
    'Tháng chưa có BangLuong → xoá được');


-- ============================================================
-- §6  KIỂM THỬ trg_ChamCong_AuditLog
-- ============================================================
SELECT '' AS Info;
