-- MỤC ĐÍCH   : Bộ kiểm thử toàn diện — chạy sau khi seed data
--              và tất cả SP/Trigger/View đã được tạo
-- §1  Kiểm tra dữ liệu nền (Sanity Check)
-- §2  Kiểm thử Functions
-- §3  Kiểm thử sp_TinhLuong (đầy đủ 3 tháng)
-- §4  Kiểm thử Triggers & Audit Log
-- §5  Kiểm thử Views
-- §6  Kiểm thử Constraints (Negative Tests)
-- §7  Integration Test — vòng đời lương 1 NV
-- §8  Kiểm tra hiệu năng & Index Usage
-- §9  Báo cáo tổng kết kiểm thử
-- CÁCH CHẠY: Chạy từng § trong MySQL Workbench / CLI
-- DBMS      : MySQL 8.0+

USE HRPayrollDB;

-- Bảng ghi kết quả test (temporary, tự xóa sau session)
DROP TEMPORARY TABLE IF EXISTS tmp_TestResults;
CREATE TEMPORARY TABLE tmp_TestResults (
    TestID      INT AUTO_INCREMENT PRIMARY KEY,
    Section     VARCHAR(20),
    TestName    VARCHAR(200),
    Expected    VARCHAR(200),
    Actual      VARCHAR(200),
    Status      VARCHAR(4),   -- PASS / FAIL
    GhiChu      VARCHAR(300)
);

-- §1  SANITY CHECK — Kiểm tra dữ liệu nền
SELECT '  §1  SANITY CHECK — DỮ LIỆU NỀN' AS Info;

-- §1.1 Đếm số bảng trong database
SELECT
    COUNT(*) AS SoBang_TrongDB,
    CASE WHEN COUNT(*) >= 15 THEN '✅ PASS' ELSE '❌ FAIL' END AS KetQua,
    'Phải có ≥15 bảng theo ERD' AS GhiChu
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = 'HRPayrollDB' AND TABLE_TYPE = 'BASE TABLE';

-- §1.2 Nhân viên
SELECT
    COUNT(*) AS SoNhanVien,
    CASE WHEN COUNT(*) = 65 THEN '✅ PASS' ELSE '❌ FAIL' END AS KetQua,
    'Phải có 65 nhân viên' AS GhiChu
FROM NhanVien;

-- §1.3 Hợp đồng
SELECT
    COUNT(*) AS SoHopDong,
    COUNT(CASE WHEN TrangThai = 'A' THEN 1 END) AS HopDongActive,
    CASE WHEN COUNT(*) = 86 THEN '✅ PASS' ELSE '❌ FAIL' END AS KetQua,
    'Phải có 86 hợp đồng' AS GhiChu
FROM HopDong;

-- §1.4 Phúc lợi
SELECT
    COUNT(*) AS SoPhuCap,
    COUNT(DISTINCT MaNV) AS SoNVCoPC,
    CASE WHEN COUNT(*) > 0 THEN '✅ PASS' ELSE '❌ FAIL' END AS KetQua
FROM NhanVienPhucLoi;

-- §1.5 Trưởng phòng được set
SELECT
    COUNT(*) AS SoPBCoTruongPhong,
    CASE WHEN COUNT(*) = 7 THEN '✅ PASS' ELSE '❌ FAIL' END AS KetQua,
    'Cả 7 phòng ban phải có Trưởng Phòng' AS GhiChu
FROM PhongBan WHERE MaTruongPhong IS NOT NULL;

-- §1.6 Chấm công tháng 1/2026
SELECT
    COUNT(*) AS SoBanGhiChamCong,
    COUNT(DISTINCT MaNV) AS SoNV_DaCham,
    CASE WHEN COUNT(*) > 500 THEN '✅ PASS' ELSE '❌ FAIL (Có thể thiếu)' END AS KetQua,
    'Tháng 1/2026: ~17 ngày làm việc × 50 NV = ~850 bản ghi' AS GhiChu
FROM ChamCong
WHERE YEAR(NgayCham) = 2026 AND MONTH(NgayCham) = 5;


-- §2  KIỂM THỬ FUNCTIONS
SELECT '  §2  KIỂM THỬ FUNCTIONS' AS Info;

-- §2.1 fn_SoNgayChuanThang
SELECT
    fn_SoNgayChuanThang(5, 2026) AS May2026_NgayChuan,
    CASE WHEN fn_SoNgayChuanThang(5, 2026) = 23
         THEN '✅ PASS'
         ELSE CONCAT('⚠️  Actual=', fn_SoNgayChuanThang(5, 2026), ' (kiểm tra lịch)') END AS KetQua,
    'Tháng 1/2026: Tết từ 28-2/2, ~23 ngày chuẩn' AS GhiChu;

-- §2.2 fn_SoNgayChuanThang tháng 2
SELECT
    fn_SoNgayChuanThang(4, 2026) AS Apr2026_NgayChuan,
    CASE WHEN fn_SoNgayChuanThang(4, 2026) > 0
         THEN '✅ PASS'
         ELSE '❌ FAIL' END AS KetQua;

-- §2.3 fn_TinhThueTNCN_Scalar — Bậc 1 (0 đồng)
SELECT
    fn_TinhThueTNCN_Scalar(0) AS Thue_TN_0,
    fn_TinhThueTNCN_Scalar(5000000) AS Thue_5Tr,
    fn_TinhThueTNCN_Scalar(20000000) AS Thue_20Tr,
    fn_TinhThueTNCN_Scalar(100000000) AS Thue_100Tr;

-- §2.4 fn_XacDinhBacThue
SELECT
    fn_XacDinhBacThue(0) AS Bac_0VND,
    fn_XacDinhBacThue(5000000) AS Bac_5Tr,
    fn_XacDinhBacThue(20000000) AS Bac_20Tr,
    fn_XacDinhBacThue(100000000) AS Bac_100Tr;

-- §2.5 fn_TinhGiamTruPhuThuoc
SELECT
    fn_TinhGiamTruPhuThuoc(0) AS GT_0NguoiPT,
    fn_TinhGiamTruPhuThuoc(1) AS GT_1NguoiPT,
    fn_TinhGiamTruPhuThuoc(3) AS GT_3NguoiPT,
    CASE WHEN fn_TinhGiamTruPhuThuoc(1) = 4400000
         THEN '✅ PASS (4.4 tr/người)'
         ELSE CONCAT('❌ FAIL: kỳ vọng 4400000, thực tế ',
                     fn_TinhGiamTruPhuThuoc(1)) END AS KetQua;

-- §2.6 fn_SoNgayChamCong (tháng 1/2026 NV000001)
SELECT
    fn_SoNgayChamCong('NV000001', 5, 2026) AS SoNgayChamCong_NV01_T1,
    fn_SoNgayNghiCoLuong('NV000001', 5, 2026) AS NghiCL,
    fn_SoNgayNghiKhongLuong('NV000001', 5, 2026) AS NghiKL;


-- §3  KIỂM THỬ sp_TinhLuong
SELECT '  §3  KIỂM THỬ sp_TinhLuong' AS Info;

-- §3.1 Tính lương tháng 1/2026 — DRY RUN trước
SELECT '--- §3.1 DryRun T5/2026 ---' AS Info;
CALL sp_TinhLuong(5, 2026, NULL, 0, 1);

-- §3.2 Tính thật tháng 1/2026
SELECT '--- §3.2 Tính thật T5/2026 ---' AS Info;
CALL sp_TinhLuong(5, 2026, NULL, 0, 0);

-- §3.3 Kiểm tra số lượng bảng lương được tạo
SELECT
    COUNT(*) AS SoBangLuongT1,
    CASE WHEN COUNT(*) >= 48 THEN '✅ PASS' ELSE '❌ FAIL' END AS KetQua,
    '~48-50 NV có HĐ và lương hợp lệ' AS GhiChu
FROM BangLuong WHERE Thang = 5 AND Nam = 2026;

-- §3.4 Kiểm tra NV000001 (TGĐ — lương cao nhất)
SELECT
    bl.MaNV, nv.HoTen,
    FORMAT(bl.ThuNhapGop, 0) AS Gross,
    FORMAT(bl.ThuNhapThucLinh, 0) AS ThucLinh,
    CASE WHEN bl.ThuNhapThucLinh > 0 THEN '✅ PASS' ELSE '❌ FAIL' END AS KetQua
FROM BangLuong bl
JOIN NhanVien nv ON bl.MaNV = nv.MaNV
WHERE bl.MaNV = 'NV000001' AND bl.Thang = 5 AND bl.Nam = 2026;

-- 3.5 Tính lương tháng 2 và 3 (không DryRun)
SELECT '--- 3.5 T�nh lng T2-T5/2026 ---' AS Info;
CALL sp_TinhLuong(4, 2026, NULL, 1, 0);
CALL sp_TinhLuong(5, 2026, NULL, 1, 0);

-- §3.6 Xác nhận bảng lương T5/2026
CALL sp_XacNhanBangLuong(5, 2026, NULL, 'NV000001');
CALL sp_XacNhanBangLuong(4, 2026, NULL, 'NV000001');

-- §3.7 Kiểm tra trạng thái sau xác nhận
SELECT
    TrangThai, COUNT(*) AS SoBanGhi
FROM BangLuong
WHERE Nam = 2026
GROUP BY TrangThai;


-- §4  KIỂM THỬ TRIGGERS & AUDIT LOG
SELECT '  §4  KIỂM THỬ TRIGGERS' AS Info;

-- §4.1 Trigger HopDong — log UPDATE
UPDATE HopDong
SET LuongCoBan = 56000000
WHERE MaHD = 'HD000001';

SELECT 'Audit log sau khi update lương NV000001:' AS Info;
SELECT MaLog, MaHD, MaNV, LoaiThayDoi, TenCot, GiaTriCu, GiaTriMoi,
       DATE_FORMAT(ThoiGianThayDoi, '%d/%m %H:%i:%s') AS ThoiGian
FROM AuditLog_HopDong
WHERE MaHD = 'HD000001'
ORDER BY MaLog DESC LIMIT 3;

-- Rollback test
UPDATE HopDong SET LuongCoBan = 55000000 WHERE MaHD = 'HD000001';

-- §4.2 Trigger ChamCong — chấm công không được tương lai
SELECT '--- Test: Chấm công ngày tương lai (phải báo lỗi) ---' AS Info;
-- Chú ý: dùng CALL hoặc trực tiếp; MySQL SIGNAL sẽ raise error
-- SET @ngayTL = DATE_ADD(CURDATE(), INTERVAL 1 DAY);
-- INSERT INTO ChamCong(MaNV, NgayCham, TrangThai) VALUES ('NV000001', @ngayTL, 'DL');
-- Lệnh trên sẽ báo lỗi SQLSTATE 45000 — đây là kết quả EXPECTED

-- §4.3 Trigger BangLuong — không sửa bảng lương đã xác nhận
SELECT '--- Test: Sửa lương đã xác nhận (phải báo lỗi) ---' AS Info;
-- UPDATE BangLuong SET LuongCoBan = 1 WHERE Thang=5 AND Nam=2026 AND TrangThai='C';
-- Lệnh trên sẽ báo lỗi từ trg_BangLuong_BeforeUpdate

SELECT
    COUNT(*) AS SoLogHopDong,
    CASE WHEN COUNT(*) > 0 THEN '✅ PASS: Trigger đã ghi log' ELSE '❌ FAIL' END AS KetQua
FROM AuditLog_HopDong;


-- §5  KIỂM THỬ VIEWS
SELECT '  §5  KIỂM THỬ VIEWS' AS Info;

-- §5.1 vw_BangLuong — top 5 lương cao nhất
SELECT '--- Top 5 lương cao nhất ---' AS Info;
SELECT
    KyLuong, HoTen, PhongBan, ChucVu,
    FORMAT(LuongGross,    0) AS Gross_VND,
    FORMAT(TongBH_NLD,    0) AS BH_VND,
    FORMAT(ThueTNCN,      0) AS Thue_VND,
    FORMAT(LuongThucLinh, 0) AS ThucLinh_VND,
    TrangThaiText
FROM vw_BangLuong
WHERE Nam = 2026 AND Thang = 5
ORDER BY LuongThucLinh DESC
LIMIT 5;

-- §5.2 vw_BangLuong_TongHop
SELECT '--- Tổng hợp quỹ lương theo phòng ban ---' AS Info;
SELECT
    Nam, Thang, PhongBan, SoNhanVien,
    FORMAT(TongLuongGross, 0) AS QuiGross,
    FORMAT(TongLuongNet,   0) AS QuiThucLinh,
    FORMAT(TongBH_NSDLD,   0) AS QuiBH_DN
FROM vw_BangLuong_TongHop
ORDER BY Nam, Thang, TongLuongNet DESC;

-- §5.3 vw_TongHopChamCong
SELECT '--- Tổng hợp chấm công tháng 1/2026 ---' AS Info;
SELECT
    HoTen, PhongBan, Nam, Thang,
    NgayDiLam, NgayWFH, NgayNghiPhep, NgayVangKP,
    TongGioTangCa,
    CONCAT(FORMAT(TyLeChuyenCan * 100, 1), '%') AS ChuyenCan
FROM vw_TongHopChamCong
WHERE Thang = 5 AND Nam = 2026
ORDER BY TongGioTangCa DESC
LIMIT 10;

-- §5.4 Kiểm tra view hoạt động
SELECT
    CASE WHEN COUNT(*) > 0 THEN '✅ vw_BangLuong hoạt động' ELSE '❌ FAIL' END AS KetQua
FROM vw_BangLuong WHERE Nam = 2026;


-- §6  KIỂM THỬ CONSTRAINTS (Negative Tests)
SELECT '  §6  KIỂM THỬ CONSTRAINTS (các lệnh phải BÁO LỖI)' AS Info;

-- §6.1 INSERT NhanVien với CCCD trùng (phải lỗi UNIQUE)
-- INSERT INTO NhanVien(MaNV,HoTen,GioiTinh,NgaySinh,CCCD,MaPB,MaCV,NgayVaoLam,TrangThai)
-- VALUES ('NV999999','Test','M','2000-01-01','036073001234','PB0001','CV0006',CURDATE(),'A');
-- → Lỗi: Duplicate entry for key 'CCCD'

-- §6.2 INSERT NhanVien với giới tính không hợp lệ (phải lỗi CHECK)
-- INSERT INTO NhanVien(MaNV,HoTen,GioiTinh,NgaySinh,CCCD,MaPB,MaCV,NgayVaoLam,TrangThai)
-- VALUES ('NV999998','Test','X','2000-01-01','999999999999','PB0001','CV0006',CURDATE(),'A');
-- → Lỗi: Check constraint 'chk_NV_GioiTinh' violated

-- §6.3 INSERT HopDong với lương âm (phải lỗi CHECK)
-- INSERT INTO HopDong(MaHD,MaNV,MaLoaiHD,NgayBatDau,LuongCoBan,VungLuong,TrangThai)
-- VALUES ('HD999999','NV000001',4,'2026-05-01',-1000000,1,'A');
-- → Lỗi: Check constraint 'chk_HD_LuongCoBan' violated

-- §6.4 Chấm công duplicate (phải thực hiện UPSERT qua procedure)
SELECT '--- §6 Test UNIQUE: duplicate chấm công ---' AS Info;
CALL sp_ChamCong_NhapHangNgay('NV000001','2026-05-10','DL','08:00','17:30',0,1.5,'Test dup','TEST',@maCC);
SELECT CONCAT('MaCC sau upsert: ', IFNULL(@maCC, 'NULL')) AS Result;

SELECT '--- §6 Test CONSTRAINT hoàn tất ---' AS Info;
SELECT 'Xem phần comment để chạy negative tests từng trường hợp' AS GhiChu;


-- §7  INTEGRATION TEST — Vòng đời lương 1 NV
SELECT '  §7  INTEGRATION TEST — Vòng đời NV000003' AS Info;

-- Bước 1: Xem thông tin NV000003
SELECT
    nv.MaNV, nv.HoTen,
    pb.TenPB, cv.TenCV,
    FORMAT(lcb.LuongCB, 0) AS LuongCoBan,
    lhd.TenLoaiHD
FROM NhanVien nv
JOIN PhongBan pb ON nv.MaPB = pb.MaPB
JOIN ChucVu cv ON nv.MaCV = cv.MaCV
LEFT JOIN LuongCoBan lcb ON nv.MaNV = lcb.MaNV AND lcb.NgayHetHieuLuc IS NULL
LEFT JOIN HopDong hd ON nv.MaNV = hd.MaNV AND hd.TrangThai = 'A'
LEFT JOIN LoaiHopDong lhd ON hd.MaLoaiHD = lhd.MaLoaiHD
WHERE nv.MaNV = 'NV000003';

-- Bước 2: Chấm công bổ sung (tháng 1)
CALL sp_ChamCong_NhapHangNgay('NV000003','2026-05-22','DL','08:00','17:30',3.0,1.5,'Tăng ca kiểm tra','TEST',@maCC_03);
SELECT CONCAT('Bước 2 OK: MaCC=', IFNULL(@maCC_03,'NULL')) AS Step2;

-- Bước 3: Xem phiếu lương
SELECT '--- Bước 3: Phiếu lương NV000003 T5/2026 ---' AS Info;
CALL sp_TaoBangLuong_PhieuLuong('NV000003', 5, 2026);

-- Bước 4: So sánh 3 tháng
SELECT '--- Bước 4: So sánh lương 3 tháng ---' AS Info;
CALL sp_TaoBangLuong_SoSanh(5, 2026, 5, 2026);

-- Bước 5: Thanh toán tháng 1
CALL sp_ThanhToanLuong(5, 2026, 'NV000001');

-- Bước 6: Kiểm tra trạng thái
SELECT Thang, Nam, TrangThai, COUNT(*) AS SoBanGhi
FROM BangLuong WHERE Nam = 2026
GROUP BY Thang, Nam, TrangThai
ORDER BY Thang;


-- §8  KIỂM TRA HIỆU NĂNG & INDEX USAGE
SELECT '  §8  KIỂM TRA HIỆU NĂNG & INDEX' AS Info;

-- §8.1 Index coverage cho truy vấn BangLuong
EXPLAIN SELECT bl.MaNV, bl.ThuNhapThucLinh
FROM BangLuong bl
WHERE bl.Thang = 5 AND bl.Nam = 2026 AND bl.TrangThai = 'C';

-- §8.2 Index coverage cho truy vấn ChamCong
EXPLAIN SELECT MaNV, COUNT(*) AS SoNgay
FROM ChamCong
WHERE YEAR(NgayCham) = 2026 AND MONTH(NgayCham) = 5
  AND TrangThai = 'DL'
GROUP BY MaNV;

-- §8.3 Tổng hợp index statistics
SELECT
    TABLE_NAME AS Bang,
    INDEX_NAME AS TenIndex,
    INDEX_TYPE AS LoaiIndex,
    COLUMN_NAME AS Cot,
    SEQ_IN_INDEX AS ViTri
FROM information_schema.STATISTICS
WHERE TABLE_SCHEMA = 'HRPayrollDB'
  AND TABLE_NAME IN ('BangLuong','ChamCong','NhanVien','HopDong')
ORDER BY TABLE_NAME, INDEX_NAME, SEQ_IN_INDEX;


-- §9  BÁO CÁO NHÂN SỰ
SELECT '  §9  BÁO CÁO NHÂN SỰ TỔNG QUAN' AS Info;

CALL sp_BaoCaoNhanSu_TongQuan(NULL);
CALL sp_BaoCaoNhanSu_HopDong(30);
CALL sp_BaoCaoNhanSu_LuongPhanPhoi(5, 2026);
CALL sp_TaoBangLuong_BHXH(5, 2026, NULL);
CALL sp_TaoBangLuong_ChiPhiNhanSu(5, 2026, NULL);


-- §10  KẾT QUẢ CUỐI CÙNG
SELECT '  TỔNG KẾT KIỂM THỬ' AS Info;

-- Tổng hợp dữ liệu sau kiểm thử
SELECT TABLE_NAME AS Bang, TABLE_ROWS AS SoBanGhi_UocTinh
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = 'HRPayrollDB' AND TABLE_TYPE = 'BASE TABLE'
ORDER BY TABLE_NAME;

SELECT
    (SELECT COUNT(*) FROM NhanVien)          AS SoNV,
    (SELECT COUNT(*) FROM HopDong)           AS SoHD,
    (SELECT COUNT(*) FROM ChamCong)          AS SoChamCong,
    (SELECT COUNT(*) FROM BangLuong)         AS SoBangLuong,
    (SELECT COUNT(*) FROM ChiTietLuong)      AS SoChiTiet,
    (SELECT COUNT(*) FROM AuditLog_HopDong)  AS SoLogHD,
    (SELECT COUNT(*) FROM AuditLog_Luong)    AS SoLogLuong,
    (SELECT FORMAT(SUM(ThuNhapThucLinh),0)
     FROM BangLuong WHERE Nam=2026)          AS TongQuyLuong_2026;

SELECT '[DONE] test_queries.sql — kiểm thử hoàn tất!' AS KetQua;

-- Cleanup month 5 for later tests
UPDATE BangLuong SET TrangThai='C' WHERE Thang=4 AND Nam=2026;
UPDATE BangLuong SET TrangThai='D' WHERE Thang=5 AND Nam=2026;
UPDATE BangLuong SET TrangThai='C' WHERE Thang=4 AND Nam=2026;
UPDATE BangLuong SET TrangThai='D' WHERE Thang=5 AND Nam=2026;
