-- ============================================================
-- FILE       : testcase_luong.sql
-- PROJECT    : Hệ Thống Quản Lý Nhân Sự & Tính Lương Tự Động
-- MỤC ĐÍCH   : Bộ kiểm thử toàn diện cho module Tính Lương
-- ─────────────────────────────────────────────────────────────
-- §1   Sanity Check  — Dữ liệu nền BangLuong 3 tháng
-- §2   fn_TinhThueTNCN — 7 bậc thuế + edge cases
-- §3   fn_TinhBHXH     — NLĐ/NSDLĐ/Thử việc/Trần BH
-- §4   sp_TinhLuong    — Pipeline 8 bước, DryRun, Override
-- §5   Tính đúng công thức  — Lương Net = Gross - BH - Thuế - KT
-- §6   ChiTietLuong    — Dòng thu nhập & khấu trừ đủ/đúng
-- §7   ThueTNCN bảng chi tiết — bậc thuế, TNCT
-- §8   sp_XacNhanBangLuong — Workflow Draft→Confirmed
-- §9   Thử việc không đóng BH — BH_NLD = 0
-- §10  Phụ cấp & OT   — Cộng đúng vào Gross
-- §11  KhauTru phát sinh — Applied sau sp_TinhLuong
-- §12  sp_TaoBangLuong_ChinhThuc — Bảng lương chính thức
-- §13  sp_TaoBangLuong_BHXH     — Danh sách đóng BH
-- §14  sp_TaoBangLuong_QuyetToanThue — Quyết toán thuế
-- §15  sp_TaoBangLuong_SoSanh   — Trend quỹ lương
-- §16  vw_BangLuong & vw_BangLuong_TongHop
-- §17  Integration — Vòng đời đầy đủ 1 kỳ lương
-- §18  Edge Cases & Boundary
-- §19  Báo cáo tổng kết
-- ─────────────────────────────────────────────────────────────
-- GIÁ TRỊ EXPECTED (đã tính từ Python cross-check):
--   NV000001 TGĐ 55M, 2PT: BH=4,914,000 | TNCT=30,286,000 | Thuế=4,407,000
--   NV000003 TP  26M, 0PT: BH=2,730,000 | TNCT=12,270,000 | Thuế=1,090,000
--   NV000010 TV   6.5M   : BH=0         | TNCT=0           | Thuế=0
-- ============================================================

USE HRPayrollDB;


-- ── Bảng kết quả test ────────────────────────────────────────
DROP TEMPORARY TABLE IF EXISTS tmp_TC_Luong;

CREATE TEMPORARY TABLE tmp_TC_Luong (
    TestID      INT         AUTO_INCREMENT PRIMARY KEY,
    Section     VARCHAR(10),
    TestName    VARCHAR(200),
    Expected    VARCHAR(300),
    Actual      VARCHAR(300),
    Status      CHAR(4),
    GhiChu      VARCHAR(400)
);


DROP PROCEDURE IF EXISTS LogL;
DELIMITER $$
CREATE PROCEDURE LogL(
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
    INSERT INTO tmp_TC_Luong (Section,TestName,Expected,Actual,Status,GhiChu)
    VALUES (p_Section, p_TestName, p_Expected, p_Actual, v_Status, p_GhiChu); 
END $$
DELIMITER ;

    
    -- §4  KIỂM THỬ sp_TinhLuong
-- ============================================================
SELECT '' AS Info;
SELECT '════════════════════════════════════════════════════════' AS Info;
SELECT '  §4  sp_TinhLuong — PIPELINE 8 BƯỚC' AS Info;
SELECT '════════════════════════════════════════════════════════' AS Info;

-- §4.1 Tháng hợp lệ không bị lỗi
SET @actual_val = (SELECT CAST(COUNT(*) AS CHAR) FROM BangLuong
     WHERE Thang=1 AND Nam=2025);
CALL LogL('§4','BangLuong_T1_Exists','50',
    @actual_val,
    'T1/2025 đã có 50 bản ghi sau sp_TinhLuong');

-- §4.2 DryRun = 1 không ghi vào DB
SET @BLCount_Truoc = NULL;
SELECT @BLCount_Truoc = COUNT(*) FROM BangLuong;
CALL sp_TinhLuong(4, 2025, NULL, 0, 1);  -- DryRun T4/2025

SET @actual_val = (SELECT CASE WHEN COUNT(*) = @BLCount_Truoc THEN 'TRUE' ELSE 'FALSE' END
     FROM BangLuong);
CALL LogL('§4','DryRun_KhongGhi','TRUE',
    @actual_val,
    '@DryRun=1: BangLuong không tăng thêm');

-- §4.3 Tháng tương lai bị chặn
SET @L04 = 0;

CALL LogL('§4','TuongLai_Chant','1',
    CAST(@L04 AS CHAR), 'sp_TinhLuong T12/2099 (tương lai) bị chặn');

-- §4.4 Tháng sai (0, 13) bị chặn
SET @L05 = 0;

CALL LogL('§4','ThangSai_0_Chant','1',
    CAST(@L05 AS CHAR), '@Thang=0 bị chặn');

-- §4.5 Override = 0 chặn tính lại bản CHOT
SET @L06 = 0;

CALL LogL('§8','Block_XacNhan_KhongCoDraft','1',
    CAST(@W04 AS CHAR), 'Xác nhận kỳ đã Confirmed → lỗi');

-- §8.5 Chuyển sang Paid (C→P)
UPDATE BangLuong
SET TrangThai='P', NgayThanhToan='2025-03-10'
WHERE Thang=2 AND Nam=2025 AND TrangThai='C';

SET @actual_val = (SELECT CAST(COUNT(*) AS CHAR) FROM BangLuong
     WHERE Thang=2 AND Nam=2025 AND TrangThai='P');
CALL LogL('§8','T2_Paid','50',
    @actual_val,
    'C→P: 50 bản ghi T2 chuyển sang Paid');

-- §8.6 Không thể sửa số liệu bảng lương đã Paid
SET @W06 = 0;

CALL LogL('§8','Guard_Paid_KhongSuaNet','1',
    CAST(@W06 AS CHAR), 'trg_BangLuong_GuardChot chặn sửa BL Paid');


-- ============================================================
-- §9  NV THỬ VIỆC — ĐẶC TRƯỜNG HỢP
-- ============================================================
SELECT '' AS Info;
SELECT '════════════════════════════════════════════════════════' AS Info;
SELECT '  §9  NV THỬ VIỆC — BR-07: Không đóng BHXH' AS Info;
SELECT '════════════════════════════════════════════════════════' AS Info;

-- Danh sách NV thử việc từ seed


-- §9.1 BH_NLD = 0 cho tất cả NV TV
SET @actual_val = (SELECT CASE WHEN SUM(bl.BHXH_NLD) = 0 THEN 'TRUE' ELSE 'FALSE' END
     FROM BangLuong bl WHERE bl.MaNV IN
         ('NV000010','NV000020','NV000038','NV000050')
       AND bl.Thang=1 AND bl.Nam=2025);
CALL LogL('§9','ThuViec_BHXH_NLD_0','TRUE',
    @actual_val,
    'TV: BHXH_NLD = 0 (không đóng 8%)');

SET @actual_val = (SELECT CASE WHEN SUM(bl.BHYT_NLD) = 0 THEN 'TRUE' ELSE 'FALSE' END
     FROM BangLuong bl WHERE bl.MaNV IN
         ('NV000010','NV000020','NV000038','NV000050')
       AND bl.Thang=1 AND bl.Nam=2025);
CALL LogL('§9','ThuViec_BHYT_NLD_0','TRUE',
    @actual_val,
    'TV: BHYT_NLD = 0 (không đóng 1.5%)');

-- §9.2 ThueTNCN = 0 (lương thấp < giảm trừ bản thân)
SET @actual_val = (SELECT CASE WHEN SUM(bl.ThueTNCN) = 0 THEN 'TRUE' ELSE 'FALSE' END
     FROM BangLuong bl WHERE bl.MaNV IN
         ('NV000010','NV000020','NV000038','NV000050')
       AND bl.Thang=1 AND bl.Nam=2025);
CALL LogL('§9','ThuViec_ThueTNCN_0','TRUE',
    @actual_val,
    'TV 6.5M < Giảm trừ 11M → ThueTNCN = 0');

-- §9.3 ThuNhapThucLinh ≈ ThuNhapGop (không có BH, không có thuế)
SET @actual_val = (SELECT CASE WHEN MIN(bl.ThuNhapThucLinh / NULLIF(bl.ThuNhapGop,0)) > 0.99
                 THEN 'TRUE' ELSE 'FALSE' END
     FROM BangLuong bl WHERE bl.MaNV IN
         ('NV000010','NV000020','NV000038','NV000050')
       AND bl.Thang=1 AND bl.Nam=2025);
CALL LogL('§9','ThuViec_Net_EQ_Gross','TRUE',
    @actual_val,
    'TV: ThuNhapThucLinh ≈ ThuNhapGop (≥99%)');


-- ============================================================
-- §10 PHỤ CẤP & OT ẢNH HƯỞNG LƯƠNG GROSS
-- ============================================================
SELECT '' AS Info;
SELECT '════════════════════════════════════════════════════════' AS Info;
SELECT '  §10 PHỤ CẤP & OT — CỘNG VÀO GROSS' AS Info;
SELECT '════════════════════════════════════════════════════════' AS Info;

-- §10.1 TongPhuCap > 0 (mọi NV đều có ít nhất FL0001 ăn trưa)
SET @actual_val = (SELECT CAST(COUNT(*) AS CHAR)
     FROM BangLuong WHERE Thang=1 AND Nam=2025 AND TongPhuCap = 0);
CALL LogL('§10','TongPhuCap_Positive','0',
    @actual_val,
    'Tất cả NV có TongPhuCap > 0 (ít nhất FL0001)');

-- §10.2 Quản lý (CV0001/CV0002) có TongPhuCap > NV thường
SET @actual_val = (SELECT CASE WHEN
        (SELECT AVG(bl.TongPhuCap) FROM BangLuong bl
         JOIN NhanVien nv ON bl.MaNV=nv.MaNV
         WHERE bl.Thang=1 AND bl.Nam=2025 AND nv.MaCV IN ('CV0001','CV0002'))
        >
        (SELECT AVG(bl.TongPhuCap) FROM BangLuong bl
         JOIN NhanVien nv ON bl.MaNV=nv.MaNV
         WHERE bl.Thang=1 AND bl.Nam=2025 AND nv.MaCV NOT IN ('CV0001','CV0002'))
        THEN 'TRUE' ELSE 'FALSE' END);
CALL LogL('§10','Manager_PhuCap_Greater','TRUE',
    @actual_val,
    'Lãnh đạo có phụ cấp TB cao hơn NV thường');

-- §10.3 Team CNTT có tăng ca trong Gross (FL0001+OT)
SET @actual_val = (SELECT CASE WHEN
        (SELECT AVG(bl.ThuNhapGop) FROM BangLuong bl
         JOIN NhanVien nv ON bl.MaNV=nv.MaNV
         WHERE bl.Thang=1 AND bl.Nam=2025 AND nv.MaPB='PB0004')
        >=
        (SELECT AVG(bl.LuongCoBan) FROM BangLuong bl
         JOIN NhanVien nv ON bl.MaNV=nv.MaNV
         WHERE bl.Thang=1 AND bl.Nam=2025 AND nv.MaPB='PB0004')
        THEN 'TRUE' ELSE 'FALSE' END);
CALL LogL('§10','CNTT_OT_In_Gross','TRUE',
    @actual_val,
    'CNTT Gross ≥ LuongCoBan (có phụ cấp + OT)');


-- ============================================================
-- §11 KHAUTRU APPLIED SAU sp_TinhLuong
-- ============================================================
SELECT '' AS Info;
SELECT '════════════════════════════════════════════════════════' AS Info;
SELECT '  §11 KHAUTRU — APPLIED VÀO BẢNG LƯƠNG' AS Info;
SELECT '════════════════════════════════════════════════════════' AS Info;

-- §11.1 Các KhauTru từ seed đã Applied (TrangThai='A')
SET @actual_val = (SELECT CASE WHEN COUNT(*) > 0 THEN 'TRUE' ELSE 'FALSE' END
     FROM KhauTru WHERE TrangThai='A');
CALL LogL('§11','KhauTru_Seed_Applied','TRUE',
    @actual_val,
    'KhauTru seed đã Applied sau sp_TinhLuong');

-- §11.2 KhauTru Applied có MaBL liên kết
SET @actual_val = (SELECT CAST(COUNT(*) AS CHAR)
     FROM KhauTru WHERE TrangThai='A' AND MaBL IS NULL);
CALL LogL('§11','KhauTru_CoMaBL','0',
    @actual_val,
    'KhauTru Applied đều có MaBL (liên kết BangLuong)');

-- §11.3 TongKhauTru trong BangLuong = BH + Thuế + KhauTruKhac
SET @actual_val = (SELECT CAST(COUNT(*) AS CHAR)
     FROM BangLuong bl
     WHERE Thang IN (1,2,3) AND Nam=2025
       AND TongKhauTru < (BHXH_NLD + BHYT_NLD + BHTN_NLD) + ThueTNCN);
CALL LogL('§11','TongKhauTru_Formula','0',
    @actual_val,
    'TongKhauTru ≥ (BHXH_NLD + BHYT_NLD + BHTN_NLD) + ThueTNCN');

-- §11.4 NV014 tạm ứng 3tr → TongKhauTru cao hơn chỉ BH+Thuế
SET @actual_val = (SELECT CASE WHEN
        (SELECT TongKhauTru - (BHXH_NLD + BHYT_NLD + BHTN_NLD) - ThueTNCN
         FROM BangLuong WHERE MaNV='NV000014' AND Thang=1 AND Nam=2025)
        >= 3000000
        THEN 'TRUE' ELSE 'FALSE' END);
CALL LogL('§11','NV014_TamUng_Reflected','TRUE',
    @actual_val,
    'NV000014 tạm ứng 3tr T1 → KhauTruKhac ≥ 3,000,000');


-- ============================================================
-- §12 sp_TaoBangLuong_ChinhThuc

SELECT * FROM tmp_TC_Luong;
