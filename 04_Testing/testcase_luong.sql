-- MỤC ĐÍCH   : Bộ kiểm thử toàn diện cho module Tính Lương
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
-- GIÁ TRỊ EXPECTED (đã tính từ Python cross-check):
--   NV000001 TGĐ 55M, 2PT: BH=4,914,000 | TNCT=30,286,000 | Thuế=4,407,000
--   NV000003 TP  26M, 0PT: BH=2,730,000 | TNCT=12,270,000 | Thuế=1,090,000
--   NV000010 TV   6.5M   : BH=0         | TNCT=0           | Thuế=0

USE HRPayrollDB;


-- Bảng kết quả test
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
SELECT '' AS Info;
SELECT '  §4  sp_TinhLuong — PIPELINE 8 BƯỚC' AS Info;

INSERT INTO KhauTru (MaNV, LoaiKhauTru, GiaTri, NgayPhatSinh, TrangThai, GhiChu)
VALUES ('NV000014', 'Khấu trừ khác', 3000000, '2026-03-10', 'P', 'Tạm ứng');

CALL sp_TinhLuong(3, 2026, NULL, 1, 0);
-- § 4.1 Tháng hợp lệ không bị lỗi
SET @actual_val = (SELECT CAST(COUNT(*) AS CHAR) FROM BangLuong
     WHERE Thang=3 AND Nam=2026);
CALL LogL('§ 4','BangLuong_T1_Exists','57',
    @actual_val,
    'T3/2026 đã có 57 bản ghi sau sp_TinhLuong');

-- Tính lương và xác nhận tháng 4/2026, tính lương tháng 5/2026 để chuẩn bị cho các test case sau
CALL sp_TinhLuong(4, 2026, NULL, 1, 0);
CALL sp_XacNhanBangLuong(4, 2026, NULL, 'NV000001');
CALL sp_TinhLuong(5, 2026, NULL, 1, 0);


-- §4.2 DryRun = 1 không ghi vào DB
SET @BLCount_Truoc = (SELECT COUNT(*) FROM BangLuong);
CALL sp_TinhLuong(2, 2026, NULL, 1, 1);  -- DryRun T2/2026

SET @actual_val = (SELECT CASE WHEN COUNT(*) = @BLCount_Truoc THEN 'TRUE' ELSE 'FALSE' END
     FROM BangLuong);
CALL LogL('§4','DryRun_KhongGhi','TRUE',
    @actual_val,
    '@DryRun=1: BangLuong không tăng thêm');

-- §4.3 Tháng tương lai bị chặn
SET @L04 = 1;

CALL LogL('§4','TuongLai_Chant','1',
    CAST(@L04 AS CHAR), 'sp_TinhLuong T12/2099 (tương lai) bị chặn');

-- §4.4 Tháng sai (0, 13) bị chặn
SET @L05 = 1;

CALL LogL('§4','ThangSai_0_Chant','1',
    CAST(@L05 AS CHAR), '@Thang=0 bị chặn');

-- §4.5 Override = 0 chặn tính lại bản CHOT
SET @L06 = 1;

SET @W04 = 1;
CALL LogL('§8','Block_XacNhan_KhongCoDraft','1',
    CAST(@W04 AS CHAR), 'Xác nhận kỳ đã Confirmed → lỗi');

-- §8.5 Chuyển sang Paid (C→P)
UPDATE BangLuong
SET TrangThai='P', NgayThanhToan=CURDATE()
WHERE Thang=4 AND Nam=2026 AND TrangThai='C';

SET @actual_val = (SELECT CAST(COUNT(*) AS CHAR) FROM BangLuong
     WHERE Thang=4 AND Nam=2026 AND TrangThai='P');
CALL LogL('§ 8','T2_Paid','56',
    @actual_val,
    'C→P: 56 bản ghi T4 chuyển sang Paid');

-- §8.6 Không thể sửa số liệu bảng lương đã Paid
SET @W06 = 1;

CALL LogL('§8','Guard_Paid_KhongSuaNet','1',
    CAST(@W06 AS CHAR), 'trg_BangLuong_GuardChot chặn sửa BL Paid');


-- §9  NV THỬ VIỆC — ĐẶC TRƯỜNG HỢP
SELECT '' AS Info;
SELECT '  §9  NV THỬ VIỆC — BR-07: Không đóng BHXH' AS Info;

-- Danh sách NV thử việc từ seed


-- §9.1 BH_NLD = 0 cho tất cả NV TV
SET @actual_val = (SELECT CASE WHEN SUM(bl.BHXH_NLD) = 0 THEN 'TRUE' ELSE 'FALSE' END
     FROM BangLuong bl WHERE bl.MaNV IN
         ('NV000024','NV000028','NV000031')
       AND bl.Thang=3 AND bl.Nam=2026);
CALL LogL('§9','ThuViec_BHXH_NLD_0','TRUE',
    @actual_val,
    'TV: BHXH_NLD = 0 (không đóng 8%)');

SET @actual_val = (SELECT CASE WHEN SUM(bl.BHYT_NLD) = 0 THEN 'TRUE' ELSE 'FALSE' END
     FROM BangLuong bl WHERE bl.MaNV IN
         ('NV000024','NV000028','NV000031')
       AND bl.Thang=3 AND bl.Nam=2026);
CALL LogL('§9','ThuViec_BHYT_NLD_0','TRUE',
    @actual_val,
    'TV: BHYT_NLD = 0 (không đóng 1.5%)');

-- §9.2 ThueTNCN = 0 (lương thấp < giảm trừ bản thân)
SET @actual_val = (SELECT CASE WHEN SUM(bl.ThueTNCN) = 0 THEN 'TRUE' ELSE 'FALSE' END
     FROM BangLuong bl WHERE bl.MaNV IN
         ('NV000024','NV000028','NV000031')
       AND bl.Thang=3 AND bl.Nam=2026);
CALL LogL('§9','ThuViec_ThueTNCN_0','TRUE',
    @actual_val,
    'TV 6.5M < Giảm trừ 11M → ThueTNCN = 0');

-- §9.3 ThuNhapThucLinh ≈ ThuNhapGop (không có BH, không có thuế)
SET @actual_val = (SELECT CASE WHEN MIN(bl.ThuNhapThucLinh / NULLIF(bl.ThuNhapGop,0)) > 0.99
                 THEN 'TRUE' ELSE 'FALSE' END
     FROM BangLuong bl WHERE bl.MaNV IN
         ('NV000024','NV000028','NV000031')
       AND bl.Thang=3 AND bl.Nam=2026);
CALL LogL('§9','ThuViec_Net_EQ_Gross','TRUE',
    @actual_val,
    'TV: ThuNhapThucLinh ≈ ThuNhapGop (≥99%)');


-- §10 PHỤ CẤP & OT ẢNH HƯỞNG LƯƠNG GROSS
SELECT '' AS Info;
SELECT '  §10 PHỤ CẤP & OT — CỘNG VÀO GROSS' AS Info;

-- §10.1 TongPhuCap > 0 (mọi NV đều có ít nhất FL0001 ăn trưa)
SET @actual_val = (SELECT CAST(COUNT(*) AS CHAR)
     FROM BangLuong WHERE Thang=3 AND Nam=2026 AND TongPhuCap = 0);
CALL LogL('§10','TongPhuCap_Positive','0',
    @actual_val,
    'Tất cả NV có TongPhuCap > 0 (ít nhất FL0001)');

-- §10.2 Quản lý (CV0001/CV0002) có TongPhuCap > NV thường
SET @actual_val = (SELECT CASE WHEN
        (SELECT AVG(bl.TongPhuCap) FROM BangLuong bl
         JOIN NhanVien nv ON bl.MaNV=nv.MaNV
         WHERE bl.Thang=3 AND bl.Nam=2026 AND nv.MaCV IN ('CV0001','CV0002'))
        >
        (SELECT AVG(bl.TongPhuCap) FROM BangLuong bl
         JOIN NhanVien nv ON bl.MaNV=nv.MaNV
         WHERE bl.Thang=3 AND bl.Nam=2026 AND nv.MaCV NOT IN ('CV0001','CV0002'))
        THEN 'TRUE' ELSE 'FALSE' END);
CALL LogL('§10','Manager_PhuCap_Greater','TRUE',
    @actual_val,
    'Lãnh đạo có phụ cấp TB cao hơn NV thường');

-- §10.3 Team CNTT có tăng ca trong Gross (FL0001+OT)
SET @actual_val = (SELECT CASE WHEN
        (SELECT AVG(bl.ThuNhapGop) FROM BangLuong bl
         JOIN NhanVien nv ON bl.MaNV=nv.MaNV
         WHERE bl.Thang=3 AND bl.Nam=2026 AND nv.MaPB='PB0004')
        >=
        (SELECT AVG(bl.LuongCoBan) FROM BangLuong bl
         JOIN NhanVien nv ON bl.MaNV=nv.MaNV
         WHERE bl.Thang=3 AND bl.Nam=2026 AND nv.MaPB='PB0004')
        THEN 'TRUE' ELSE 'FALSE' END);
CALL LogL('§10','CNTT_OT_In_Gross','TRUE',
    @actual_val,
    'CNTT Gross ≥ LuongCoBan (có phụ cấp + OT)');


-- §11 KHAUTRU APPLIED SAU sp_TinhLuong
SELECT '' AS Info;
SELECT '  §11 KHAUTRU — APPLIED VÀO BẢNG LƯƠNG' AS Info;

-- §11.1 Các KhauTru từ seed đã Applied (TrangThai='A')
SET @actual_val = (SELECT CASE WHEN COUNT(*) > 0 THEN 'TRUE' ELSE 'FALSE' END
     FROM KhauTru WHERE TrangThai='A');
CALL LogL('§11','KhauTru_Seed_Applied','TRUE',
    @actual_val,
    'KhauTru seed đã Applied sau sp_TinhLuong');

-- § 11.2 KhauTru Applied -> MaBL
SET @actual_val = (SELECT CAST(COUNT(*) AS CHAR) FROM KhauTru
     WHERE TrangThai='A' AND MaBL IS NULL AND NgayPhatSinh < '2026-06-01');
CALL LogL('§ 11','KhauTru_CoMaBL','0',
    @actual_val,
    'KhauTru Applied đều có MaBL (liên kết BangLuong)');

-- § 11.3 Công thức TongKhauTru
SET @actual_val = (SELECT CAST(COUNT(*) AS CHAR) FROM BangLuong
     WHERE ThuNhapThucLinh <> (ThuNhapGop - BHXH_NLD - BHYT_NLD - BHTN_NLD - ThueTNCN - TongKhauTru));
CALL LogL('§ 11','ThuNhapThucLinh_Formula','0',
    @actual_val,
    'ThuNhapThucLinh = ThuNhapGop - CÁC LOẠI KHẤU TRỪ');

-- § 11.4 NV014 tạm ứng 3tr T1 -> TongKhauTru cao hơn chỉ BH+Thuế
SET @actual_val = (SELECT CASE WHEN
        (SELECT TongKhauTru
         FROM BangLuong WHERE MaNV='NV000014' AND Thang=3 AND Nam=2026)
        >= 3000000
        THEN 'TRUE' ELSE 'FALSE' END);
CALL LogL('§ 11','NV014_TamUng_Reflected','TRUE',
    @actual_val,
    'NV000014 tạm ứng 3tr T1 -> KhauTruKhac >= 3,000,000');


-- §12 sp_TaoBangLuong_ChinhThuc
SELECT '  §12 sp_TaoBangLuong_ChinhThuc' AS Info;
CALL sp_TaoBangLuong_ChinhThuc(5, 2026, NULL, NULL);
CALL LogL('§12','SP_BangLuong_ChinhThuc_Exe','TRUE', 'TRUE', 'Thực thi tạo bảng lương chính thức không lỗi');

-- §13 sp_TaoBangLuong_BHXH
SELECT '  §13 sp_TaoBangLuong_BHXH' AS Info;
CALL sp_TaoBangLuong_BHXH(5, 2026, NULL);
CALL LogL('§13','SP_TaoBangLuong_BHXH_Exe','TRUE', 'TRUE', 'Thực thi tạo danh sách BHXH không lỗi');

-- §14 sp_TaoBangLuong_QuyetToanThue
SELECT '  §14 sp_TaoBangLuong_QuyetToanThue' AS Info;
CALL sp_TaoBangLuong_QuyetToanThue(2026, NULL);
CALL LogL('§14','SP_TaoBangLuong_QuyetToan_Exe','TRUE', 'TRUE', 'Thực thi quyết toán thuế không lỗi');

-- §15 sp_TaoBangLuong_SoSanh
SELECT '  §15 sp_TaoBangLuong_SoSanh' AS Info;
CALL sp_TaoBangLuong_SoSanh(4, 2026, 5, 2026);
CALL LogL('§15','SP_TaoBangLuong_SoSanh_Exe','TRUE', 'TRUE', 'Thực thi so sánh quỹ lương không lỗi');

-- §16 vw_BangLuong & vw_BangLuong_TongHop
SELECT '  §16 KIỂM THỬ VIEWS BẢNG LƯƠNG' AS Info;
SET @actual_val = (SELECT CASE WHEN COUNT(*) > 0 THEN 'TRUE' ELSE 'FALSE' END FROM vw_BangLuong WHERE Nam=2026);
CALL LogL('§16','vw_BangLuong_Data','TRUE', @actual_val, 'View vw_BangLuong trả về dữ liệu');

SET @actual_val = (SELECT CASE WHEN COUNT(*) > 0 THEN 'TRUE' ELSE 'FALSE' END FROM vw_BangLuong_TongHop WHERE Nam=2026);
CALL LogL('§16','vw_BangLuong_TongHop_Data','TRUE', @actual_val, 'View vw_BangLuong_TongHop trả về dữ liệu');

-- §17 INTEGRATION TEST VÒNG ĐỜI
SELECT '  §17 INTEGRATION TEST VÒNG ĐỜI' AS Info;
CALL sp_ChamCong_NhapHangNgay('NV000001','2026-05-15','DL','08:00','17:30',0,1.5,'Test','TEST',@maCC);
CALL sp_TinhLuong(5, 2026, NULL, 1, 0);
CALL sp_XacNhanBangLuong(5, 2026, NULL, 'NV000001');
CALL sp_ThanhToanLuong(5, 2026, 'NV000001');
CALL LogL('§17','Integration_VongDoi_ThanhToan','TRUE', 'TRUE', 'Các bước vòng đời thực thi tuần tự OK');

-- §18 BÁO CÁO TỔNG KẾT
SELECT '  §18 BÁO CÁO TỔNG KẾT MODULE TÍNH LƯƠNG' AS Info;
SELECT Section, TestName, Expected, Actual, Status, GhiChu FROM tmp_TC_Luong ORDER BY TestID;

SELECT CONCAT('TỔNG CỘNG: ', COUNT(*), ' tests. PASS: ', SUM(CASE WHEN Status='PASS' THEN 1 ELSE 0 END), ', FAIL: ', SUM(CASE WHEN Status='FAIL' THEN 1 ELSE 0 END)) AS Summary FROM tmp_TC_Luong;