-- ============================================================
-- FILE       : seed_data.sql
-- PROJECT    : Hệ Thống Quản Lý Nhân Sự & Tính Lương Tự Động
-- MỤC ĐÍCH   : Dữ liệu mẫu thực tế cho toàn bộ hệ thống
-- DBMS       : MySQL 8.0+
-- GHI CHÚ   : - Loại bỏ N'' prefix (không cần trong MySQL utf8mb4)
--              - GO → không dùng (MySQL dùng ; thay thế)
--              - BEGIN TRANSACTION → START TRANSACTION
--              - IDENTITY_INSERT → không cần (dùng AUTO_INCREMENT)
--              - DATEADD(MONTH,n,date) → DATE_ADD(date, INTERVAL n MONTH)
--              - dbo. prefix → không dùng
--              - SET NOCOUNT ON → không cần
--              - PRINT → SELECT 'message' AS Info
-- ============================================================

USE HRPayrollDB;

-- Tắt safe update mode và kiểm tra FK tạm thời
SET FOREIGN_KEY_CHECKS = 0;

-- ============================================================
-- §1  BẢNG DANH MỤC (LOOKUP)
-- ============================================================
START TRANSACTION;

-- ── §1.1 PhongBan
TRUNCATE TABLE PhongBan;
INSERT INTO PhongBan (MaPB, TenPB, DiaDiem, DienThoai, Email, NgayThanhLap, IsActive) VALUES
  ('PB0001', 'Ban Giám Đốc',               'Tầng 10, Tòa nhà Landmark',  '02838001001', 'banlanhday@hrpayroll.vn',  '2010-03-15', 1),
  ('PB0002', 'Phòng Nhân Sự & Hành Chính', 'Tầng 5, Phòng 501',          '02838001002', 'nhansu@hrpayroll.vn',      '2010-03-15', 1),
  ('PB0003', 'Phòng Tài Chính Kế Toán',    'Tầng 5, Phòng 502',          '02838001003', 'ketoan@hrpayroll.vn',      '2010-03-15', 1),
  ('PB0004', 'Phòng Công Nghệ Thông Tin',  'Tầng 6, Phòng 601',          '02838001004', 'cntt@hrpayroll.vn',        '2012-01-01', 1),
  ('PB0005', 'Phòng Kinh Doanh & Marketing','Tầng 7, Phòng 701',         '02838001005', 'kinhdoanh@hrpayroll.vn',   '2010-03-15', 1);

-- ── §1.2 ChucVu
TRUNCATE TABLE ChucVu;
INSERT INTO ChucVu (MaCV, TenCV, HeSoLuong, CapBac, MoTa, IsActive) VALUES
  ('CV0001', 'Tổng Giám Đốc',           8.00, 5, 'Lãnh đạo cao nhất công ty',             1),
  ('CV0002', 'Trưởng Phòng',             4.50, 4, 'Quản lý toàn bộ phòng ban',             1),
  ('CV0003', 'Phó Phòng',               3.80, 4, 'Hỗ trợ Trưởng Phòng điều hành',         1),
  ('CV0004', 'Chuyên Viên Cao Cấp',     3.00, 3, '≥5 năm kinh nghiệm chuyên môn',         1),
  ('CV0005', 'Chuyên Viên',             2.50, 2, '2–5 năm kinh nghiệm',                   1),
  ('CV0006', 'Nhân Viên',               2.00, 1, 'Nhân viên chính thức',                  1),
  ('CV0007', 'Nhân Viên Thử Việc',      1.50, 1, 'Đang trong thời gian thử việc 2 tháng', 1);

-- ── §1.3 LoaiHopDong (chèn ID thủ công)
TRUNCATE TABLE LoaiHopDong;
INSERT INTO LoaiHopDong (MaLoaiHD, TenLoaiHD, ThoiHanToiDa, TiLeBHXH, MoTa) VALUES
  (1, 'Thử việc',               2,    0.00, 'Tối đa 2 tháng, không đóng BHXH'),
  (2, 'Xác định 1 năm',        12,    8.00, 'Hợp đồng 12 tháng, đóng BHXH đầy đủ'),
  (3, 'Xác định 2 năm',        24,    8.00, 'Hợp đồng 24 tháng, đóng BHXH đầy đủ'),
  (4, 'Không xác định thời hạn',NULL, 8.00, 'Hợp đồng vô thời hạn theo BLLĐ 2019');

-- ── §1.4 LoaiNghiPhep
TRUNCATE TABLE LoaiNghiPhep;
INSERT INTO LoaiNghiPhep (MaLoaiNghi, TenLoaiNghi, CoHuongLuong, SoNgayToiDa, MoTa) VALUES
  (1, 'Phép năm',               1,  12,   'Tối thiểu 12 ngày/năm theo BLLĐ'),
  (2, 'Nghỉ ốm đau',           1,  30,   'Có hưởng lương BHXH'),
  (3, 'Thai sản',               1, 180,   '6 tháng hưởng 100% lương BH'),
  (4, 'Việc riêng không lương', 0, NULL,  'Không hưởng lương'),
  (5, 'Nghỉ bù',                1, NULL,  'Bù giờ làm thêm');

-- ── §1.5 LoaiPhucLoi
TRUNCATE TABLE LoaiPhucLoi;
INSERT INTO LoaiPhucLoi (MaFL, TenFL, LoaiGiaTri, GiaTri, CoTinhThue, MoTa, IsActive) VALUES
  ('FL0001', 'Phụ cấp ăn trưa',          'F',   730000, 0, '≤730k/tháng miễn thuế theo TT111', 1),
  ('FL0002', 'Phụ cấp xăng xe đi lại',   'F',   500000, 0, 'Không tính thuế TNCN',             1),
  ('FL0003', 'Phụ cấp điện thoại',        'F',   300000, 0, 'Không tính thuế TNCN',             1),
  ('FL0004', 'Phụ cấp nhà ở',             'F', 1500000, 1, 'Tính vào thu nhập chịu thuế',       1),
  ('FL0005', 'Phụ cấp trách nhiệm QL',    'F', 2000000, 1, 'Dành cho cấp quản lý trở lên',      1),
  ('FL0006', 'Phụ cấp thâm niên (2%)',    'P',      2.0, 0, '2% lương CB, miễn thuế',            1);

-- ── §1.6 NgayLe (ngày lễ âm lịch và dương lịch 2024-2025)
TRUNCATE TABLE NgayLe;
INSERT INTO NgayLe (NgayLe, TenNgayLe) VALUES
  ('2025-01-01', 'Tết Dương Lịch 2025'),
  ('2025-01-28', 'Tết Nguyên Đán (30 Tết) 2025'),
  ('2025-01-29', 'Tết Nguyên Đán (Mồng 1) 2025'),
  ('2025-01-30', 'Tết Nguyên Đán (Mồng 2) 2025'),
  ('2025-01-31', 'Tết Nguyên Đán (Mồng 3) 2025'),
  ('2025-02-01', 'Tết Nguyên Đán (Mồng 4) 2025'),
  ('2025-02-02', 'Tết Nguyên Đán (Mồng 5) 2025'),
  ('2025-04-07', 'Giỗ Tổ Hùng Vương 2025'),
  ('2025-04-30', 'Ngày Giải Phóng Miền Nam'),
  ('2025-05-01', 'Quốc Tế Lao Động'),
  ('2025-09-02', 'Quốc Khánh'),
  ('2024-01-01', 'Tết Dương Lịch 2024'),
  ('2024-02-08', 'Tết Nguyên Đán (30 Tết) 2024'),
  ('2024-02-09', 'Tết Nguyên Đán (Mồng 1) 2024'),
  ('2024-02-10', 'Tết Nguyên Đán (Mồng 2) 2024'),
  ('2024-02-11', 'Tết Nguyên Đán (Mồng 3) 2024'),
  ('2024-02-12', 'Tết Nguyên Đán (Mồng 4) 2024'),
  ('2024-02-13', 'Tết Nguyên Đán (Mồng 5) 2024'),
  ('2024-04-18', 'Giỗ Tổ Hùng Vương 2024'),
  ('2024-04-30', 'Ngày Giải Phóng Miền Nam 2024'),
  ('2024-05-01', 'Quốc Tế Lao Động 2024'),
  ('2024-09-02', 'Quốc Khánh 2024');

COMMIT;
SELECT '[OK] §1 LOOKUP TABLES hoàn tất' AS Info;

-- ============================================================
-- §2  NHANVIEN — 50 nhân viên
-- ============================================================
-- Reset dữ liệu phụ thuộc theo đúng thứ tự FK
START TRANSACTION;

-- Phải xóa theo thứ tự FK ngược
DELETE FROM AuditLog_Luong;
DELETE FROM AuditLog_HopDong;
DELETE FROM ChiTietLuong;
DELETE FROM KhauTru;
DELETE FROM BangLuong;
DELETE FROM ChamCong;
DELETE FROM NghiPhep;
DELETE FROM NhanVienPhucLoi;
DELETE FROM LuongCoBan;
DELETE FROM HopDong;
UPDATE PhongBan SET MaTruongPhong = NULL;  -- Xóa FK vòng
DELETE FROM NhanVien;

INSERT INTO NhanVien (MaNV,HoTen,GioiTinh,NgaySinh,CCCD,DiaChi,Email,SoDienThoai,MaPB,MaCV,NgayVaoLam,TrangThai,MaSoThue,SoTaiKhoanNH,TenNganHang,NguoiTao) VALUES
('NV000001','Nguyễn Hoàng Minh','M','1973-07-15','036073001234','Q.1, TP.HCM','nguynhongminh@hrpayroll.vn','0973001234','PB0001','CV0001','2015-01-05','A','0300123456','19001000100001','Vietcombank','HR_ADMIN'),
('NV000002','Trần Thị Lan Anh','F','1992-04-20','038092002345','Q.Bình Thạnh, TP.HCM','trnthlananh@hrpayroll.vn','0992002345','PB0001','CV0006','2019-03-01','A','0300234567','19001000100002','Techcombank','HR_ADMIN'),
('NV000003','Lê Văn Đức','M','1980-09-12','036080003456','Q.Tân Bình, TP.HCM','lvndc@hrpayroll.vn','0980003456','PB0002','CV0002','2016-02-15','A','0300345678','19001000100003','BIDV','HR_ADMIN'),
('NV000004','Phạm Thị Hương','F','1988-11-03','038088004567','Q.Phú Nhuận, TP.HCM','phmthhng@hrpayroll.vn','0988004567','PB0002','CV0005','2018-06-01','A','0300456789','19001000100004','Vietcombank','HR_ADMIN'),
('NV000005','Võ Minh Tuấn','M','1990-02-28','036090005678','Q.Gò Vấp, TP.HCM','vminhtun@hrpayroll.vn','0990005678','PB0002','CV0005','2019-01-10','A','0300567890','19001000100005','Agribank','HR_ADMIN'),
('NV000006','Nguyễn Thị Thu Hà','F','1993-08-15','038093006789','Q.3, TP.HCM','nguynththuh@hrpayroll.vn','0993006789','PB0002','CV0006','2020-03-02','A','0300678901','19001000100006','Techcombank','HR_ADMIN'),
('NV000007','Đinh Văn Hùng','M','1991-04-22','036091007890','Q.Thủ Đức, TP.HCM','dinhvnhng@hrpayroll.vn','0991007890','PB0002','CV0006','2020-07-01','A','0300789012','19001000100007','BIDV','HR_ADMIN'),
('NV000008','Trương Thị Ngọc','F','1994-09-10','038094008901','Q.7, TP.HCM','trngthngc@hrpayroll.vn','0994008901','PB0002','CV0006','2021-01-04','A','0300890123','19001000100008','Vietinbank','HR_ADMIN'),
('NV000009','Bùi Quang Khải','M','1989-12-05','036089009012','Bình Dương','biquangkhi@hrpayroll.vn','0989009012','PB0002','CV0005','2018-11-01','A','0300901234','19001000100009','MBBank','HR_ADMIN'),
('NV000010','Đỗ Thị Mai Linh','F','1999-06-18','038099010123','Đồng Nai','dthmailinh@hrpayroll.vn','0999010123','PB0002','CV0007','2024-11-01','P','0301012345','19001000100010','Vietcombank','HR_ADMIN'),
('NV000011','Hoàng Thị Phương','F','1978-02-20','038078011234','Q.1, TP.HCM','hongthphng@hrpayroll.vn','0978011234','PB0003','CV0002','2015-07-01','A','0301123456','19001000100011','BIDV','HR_ADMIN'),
('NV000012','Phan Văn Thắng','M','1982-05-15','036082012345','Q.Bình Thạnh, TP.HCM','phanvnthng@hrpayroll.vn','0982012345','PB0003','CV0003','2016-09-01','A','0301234567','19001000100012','Vietcombank','HR_ADMIN'),
('NV000013','Lý Thị Kim Oanh','F','1986-09-25','038086013456','Q.Tân Bình, TP.HCM','lthkimoanh@hrpayroll.vn','0986013456','PB0003','CV0004','2017-04-03','A','0301345678','19001000100013','Techcombank','HR_ADMIN'),
('NV000014','Ngô Đức Toàn','M','1990-11-08','036090014567','Q.Phú Nhuận, TP.HCM','ngdcton@hrpayroll.vn','0990014567','PB0003','CV0005','2019-05-01','A','0301456789','19001000100014','Agribank','HR_ADMIN'),
('NV000015','Vũ Thị Thanh Xuân','F','1991-03-17','038091015678','Q.Gò Vấp, TP.HCM','vththanhxun@hrpayroll.vn','0991015678','PB0003','CV0005','2019-08-01','A','0301567890','19001000100015','BIDV','HR_ADMIN'),
('NV000016','Trịnh Văn Dũng','M','1993-07-22','036093016789','Q.3, TP.HCM','trnhvndng@hrpayroll.vn','0993016789','PB0003','CV0006','2020-10-01','A','0301678901','19001000100016','Vietinbank','HR_ADMIN'),
('NV000017','Hà Thị Nhung','F','1994-01-30','038094017890','Q.Thủ Đức, TP.HCM','hthnhung@hrpayroll.vn','0994017890','PB0003','CV0006','2021-03-01','A','0301789012','19001000100017','MBBank','HR_ADMIN'),
('NV000018','Đặng Minh Quân','M','1995-10-05','036095018901','Q.7, TP.HCM','dngminhqun@hrpayroll.vn','0995018901','PB0003','CV0006','2022-01-03','A','0301890123','19001000100018','Vietcombank','HR_ADMIN'),
('NV000019','Mai Thị Bích','F','1996-04-12','038096019012','Bình Dương','maithbch@hrpayroll.vn','0996019012','PB0003','CV0006','2022-06-01','A','0301901234','19001000100019','BIDV','HR_ADMIN'),
('NV000020','Lưu Văn Sơn','M','2000-08-25','036100020123','Đồng Nai','luvnsn@hrpayroll.vn','0900020123','PB0003','CV0007','2024-12-02','P','0302012345','19001000100020','Techcombank','HR_ADMIN'),
('NV000021','Phạm Anh Tuấn','M','1979-06-10','036079021234','Q.1, TP.HCM','phmanhtun@hrpayroll.vn','0979021234','PB0004','CV0002','2015-03-01','A','0302123456','19001000100021','Vietcombank','HR_ADMIN'),
('NV000022','Nguyễn Thị Hồng Nhung','F','1983-03-25','038083022345','Q.Bình Thạnh, TP.HCM','nguynthhngnhung@hrpayroll.vn','0983022345','PB0004','CV0003','2017-01-09','A','0302234567','19001000100022','BIDV','HR_ADMIN'),
('NV000023','Bùi Văn Long','M','1985-11-15','036085023456','Q.Tân Bình, TP.HCM','bivnlong@hrpayroll.vn','0985023456','PB0004','CV0004','2017-07-03','A','0302345678','19001000100023','Agribank','HR_ADMIN'),
('NV000024','Cao Thị Liên','F','1987-07-08','038087024567','Q.Phú Nhuận, TP.HCM','caothlin@hrpayroll.vn','0987024567','PB0004','CV0004','2018-02-01','A','0302456789','19001000100024','Techcombank','HR_ADMIN'),
('NV000025','Lê Minh Đạt','M','1986-09-20','036086025678','Q.Gò Vấp, TP.HCM','lminhdt@hrpayroll.vn','0986025678','PB0004','CV0004','2018-04-02','A','0302567890','19001000100025','Vietinbank','HR_ADMIN'),
('NV000026','Đào Thị Phúc','F','1990-02-14','038090026789','Q.3, TP.HCM','dothphc@hrpayroll.vn','0990026789','PB0004','CV0005','2019-09-02','A','0302678901','19001000100026','MBBank','HR_ADMIN'),
('NV000027','Trần Văn Khoa','M','1991-05-30','036091027890','Q.Thủ Đức, TP.HCM','trnvnkhoa@hrpayroll.vn','0991027890','PB0004','CV0005','2020-01-06','A','0302789012','19001000100027','Vietcombank','HR_ADMIN'),
('NV000028','Lương Thị Diễm','F','1992-08-19','038092028901','Q.7, TP.HCM','lngthdim@hrpayroll.vn','0992028901','PB0004','CV0005','2020-06-01','A','0302890123','19001000100028','BIDV','HR_ADMIN'),
('NV000029','Phan Đức Hiếu','M','1993-01-25','036093029012','Bình Dương','phandchiu@hrpayroll.vn','0993029012','PB0004','CV0005','2021-01-04','A','0302901234','19001000100029','Techcombank','HR_ADMIN'),
('NV000030','Vũ Thị Lan','F','1991-11-02','038091030123','Đồng Nai','vthlan@hrpayroll.vn','0991030123','PB0004','CV0005','2021-04-01','A','0303012345','19001000100030','Agribank','HR_ADMIN'),
('NV000031','Dương Văn Nhật','M','1994-04-16','036094031234','Q.1, TP.HCM','dngvnnht@hrpayroll.vn','0994031234','PB0004','CV0006','2021-07-01','A','0303123456','19001000100031','Vietcombank','HR_ADMIN'),
('NV000032','Phạm Thị Thu Hà','F','1995-06-07','038095032345','Q.Bình Thạnh, TP.HCM','phmththuh@hrpayroll.vn','0995032345','PB0004','CV0006','2022-01-03','A','0303234567','19001000100032','BIDV','HR_ADMIN'),
('NV000033','Hoàng Văn Tùng','M','1993-09-28','036093033456','Q.Tân Bình, TP.HCM','hongvntng@hrpayroll.vn','0993033456','PB0004','CV0006','2022-03-01','A','0303345678','19001000100033','Vietinbank','HR_ADMIN'),
('NV000034','Nguyễn Thị Ánh','F','1996-12-03','038096034567','Q.Phú Nhuận, TP.HCM','nguynthnh@hrpayroll.vn','0996034567','PB0004','CV0006','2022-08-01','A','0303456789','19001000100034','MBBank','HR_ADMIN'),
('NV000035','Trần Minh Hoàng','M','1994-07-18','036094035678','Q.Gò Vấp, TP.HCM','trnminhhong@hrpayroll.vn','0994035678','PB0004','CV0006','2023-01-03','A','0303567890','19001000100035','Vietcombank','HR_ADMIN'),
('NV000036','Lê Thị Vy','F','1997-03-09','038097036789','Q.3, TP.HCM','lthvy@hrpayroll.vn','0997036789','PB0004','CV0006','2023-04-03','A','0303678901','19001000100036','Techcombank','HR_ADMIN'),
('NV000037','Đỗ Văn Chiến','M','1995-10-21','036095037890','Q.Thủ Đức, TP.HCM','dvnchin@hrpayroll.vn','0995037890','PB0004','CV0006','2023-07-03','A','0303789012','19001000100037','BIDV','HR_ADMIN'),
('NV000038','Kiều Thị Hà','F','2001-05-14','038101038901','Q.7, TP.HCM','kiuthh@hrpayroll.vn','0901038901','PB0004','CV0007','2024-10-01','P','0303890123','19001000100038','Agribank','HR_ADMIN'),
('NV000039','Dương Quốc Hùng','M','1977-08-05','036077039012','Bình Dương','dngquchng@hrpayroll.vn','0977039012','PB0005','CV0002','2015-05-04','A','0303901234','19001000100039','Vietcombank','HR_ADMIN'),
('NV000040','Võ Thị Quỳnh Anh','F','1984-01-20','038084040123','Đồng Nai','vthqunhanh@hrpayroll.vn','0984040123','PB0005','CV0003','2017-10-02','A','0304012345','19001000100040','BIDV','HR_ADMIN'),
('NV000041','Nguyễn Văn Phú','M','1987-04-12','036087041234','Q.1, TP.HCM','nguynvnph@hrpayroll.vn','0987041234','PB0005','CV0004','2018-08-01','A','0304123456','19001000100041','Techcombank','HR_ADMIN'),
('NV000042','Huỳnh Thị Kim Chi','F','1988-10-30','038088042345','Q.Bình Thạnh, TP.HCM','hunhthkimchi@hrpayroll.vn','0988042345','PB0005','CV0004','2019-02-01','A','0304234567','19001000100042','Vietinbank','HR_ADMIN'),
('NV000043','Bùi Minh Châu','M','1990-06-08','036090043456','Q.Tân Bình, TP.HCM','biminhchu@hrpayroll.vn','0990043456','PB0005','CV0005','2019-11-04','A','0304345678','19001000100043','MBBank','HR_ADMIN'),
('NV000044','Trịnh Thị Phương Linh','F','1991-09-15','038091044567','Q.Phú Nhuận, TP.HCM','trnhthphnglinh@hrpayroll.vn','0991044567','PB0005','CV0005','2020-04-06','A','0304456789','19001000100044','Vietcombank','HR_ADMIN'),
('NV000045','Nguyễn Hoàng Nam','M','1992-02-28','036092045678','Q.Gò Vấp, TP.HCM','nguynhongnam@hrpayroll.vn','0992045678','PB0005','CV0005','2021-06-01','A','0304567890','19001000100045','BIDV','HR_ADMIN'),
('NV000046','Đặng Thị Hoa','F','1994-11-17','038094046789','Q.3, TP.HCM','dngthhoa@hrpayroll.vn','0994046789','PB0005','CV0006','2021-10-04','A','0304678901','19001000100046','Techcombank','HR_ADMIN'),
('NV000047','Phạm Văn Thành','M','1995-08-04','036095047890','Q.Thủ Đức, TP.HCM','phmvnthnh@hrpayroll.vn','0995047890','PB0005','CV0006','2022-04-04','A','0304789012','19001000100047','Vietinbank','HR_ADMIN'),
('NV000048','Lý Thị Ái','F','1996-05-22','038096048901','Q.7, TP.HCM','lthi@hrpayroll.vn','0996048901','PB0005','CV0006','2022-09-01','A','0304890123','19001000100048','Agribank','HR_ADMIN'),
('NV000049','Mai Văn Khánh','M','1997-01-09','036097049012','Bình Dương','maivnkhnh@hrpayroll.vn','0997049012','PB0005','CV0006','2023-03-01','A','0304901234','19001000100049','Vietcombank','HR_ADMIN'),
('NV000050','Ngô Thị Minh Nguyệt','F','2000-07-31','038100050123','Đồng Nai','ngthminhnguyt@hrpayroll.vn','0900050123','PB0005','CV0007','2024-11-04','P','0305012345','19001000100050','BIDV','HR_ADMIN');

COMMIT;
SELECT '[OK] §2 NhanVien — 50 nhân viên' AS Info;

-- ============================================================
-- §3  HOPDONG — 50 hợp đồng lao động
-- ============================================================
START TRANSACTION;

INSERT INTO HopDong(MaHD,MaNV,MaLoaiHD,NgayBatDau,NgayKetThuc,LuongCoBan,VungLuong,TrangThai,NguoiKy_NLD,NguoiKy_NSDLD,NgayKy,NguoiTao) VALUES
('HD000001','NV000001',4,'2015-01-05',NULL,55000000,1,'A','Nguyễn Hoàng Minh','Nguyễn Hoàng Minh','2015-01-05','HR_ADMIN'),
('HD000002','NV000002',2,'2019-03-01',DATE_ADD('2019-03-01',INTERVAL 12 MONTH),8500000,1,'A','Trần Thị Lan Anh','Nguyễn Hoàng Minh','2019-03-01','HR_ADMIN'),
('HD000003','NV000003',3,'2016-02-15',DATE_ADD('2016-02-15',INTERVAL 24 MONTH),26000000,1,'A','Lê Văn Đức','Nguyễn Hoàng Minh','2016-02-15','HR_ADMIN'),
('HD000004','NV000004',2,'2018-06-01',DATE_ADD('2018-06-01',INTERVAL 12 MONTH),11500000,1,'A','Phạm Thị Hương','Nguyễn Hoàng Minh','2018-06-01','HR_ADMIN'),
('HD000005','NV000005',2,'2019-01-10',DATE_ADD('2019-01-10',INTERVAL 12 MONTH),11500000,1,'A','Võ Minh Tuấn','Nguyễn Hoàng Minh','2019-01-10','HR_ADMIN'),
('HD000006','NV000006',2,'2020-03-02',DATE_ADD('2020-03-02',INTERVAL 12 MONTH),8500000,1,'A','Nguyễn Thị Thu Hà','Nguyễn Hoàng Minh','2020-03-02','HR_ADMIN'),
('HD000007','NV000007',2,'2020-07-01',DATE_ADD('2020-07-01',INTERVAL 12 MONTH),8500000,1,'A','Đinh Văn Hùng','Nguyễn Hoàng Minh','2020-07-01','HR_ADMIN'),
('HD000008','NV000008',2,'2021-01-04',DATE_ADD('2021-01-04',INTERVAL 12 MONTH),8500000,1,'A','Trương Thị Ngọc','Nguyễn Hoàng Minh','2021-01-04','HR_ADMIN'),
('HD000009','NV000009',2,'2018-11-01',DATE_ADD('2018-11-01',INTERVAL 12 MONTH),11500000,1,'A','Bùi Quang Khải','Nguyễn Hoàng Minh','2018-11-01','HR_ADMIN'),
('HD000010','NV000010',1,'2024-11-01',DATE_ADD('2024-11-01',INTERVAL 2 MONTH),6500000,1,'A','Đỗ Thị Mai Linh','Nguyễn Hoàng Minh','2024-11-01','HR_ADMIN'),
('HD000011','NV000011',3,'2015-07-01',DATE_ADD('2015-07-01',INTERVAL 24 MONTH),25000000,1,'A','Hoàng Thị Phương','Nguyễn Hoàng Minh','2015-07-01','HR_ADMIN'),
('HD000012','NV000012',3,'2016-09-01',DATE_ADD('2016-09-01',INTERVAL 24 MONTH),20000000,1,'A','Phan Văn Thắng','Nguyễn Hoàng Minh','2016-09-01','HR_ADMIN'),
('HD000013','NV000013',3,'2017-04-03',DATE_ADD('2017-04-03',INTERVAL 24 MONTH),15000000,1,'A','Lý Thị Kim Oanh','Nguyễn Hoàng Minh','2017-04-03','HR_ADMIN'),
('HD000014','NV000014',2,'2019-05-01',DATE_ADD('2019-05-01',INTERVAL 12 MONTH),11500000,1,'A','Ngô Đức Toàn','Nguyễn Hoàng Minh','2019-05-01','HR_ADMIN'),
('HD000015','NV000015',2,'2019-08-01',DATE_ADD('2019-08-01',INTERVAL 12 MONTH),11500000,1,'A','Vũ Thị Thanh Xuân','Nguyễn Hoàng Minh','2019-08-01','HR_ADMIN'),
('HD000016','NV000016',2,'2020-10-01',DATE_ADD('2020-10-01',INTERVAL 12 MONTH),8500000,1,'A','Trịnh Văn Dũng','Nguyễn Hoàng Minh','2020-10-01','HR_ADMIN'),
('HD000017','NV000017',2,'2021-03-01',DATE_ADD('2021-03-01',INTERVAL 12 MONTH),8500000,1,'A','Hà Thị Nhung','Nguyễn Hoàng Minh','2021-03-01','HR_ADMIN'),
('HD000018','NV000018',2,'2022-01-03',DATE_ADD('2022-01-03',INTERVAL 12 MONTH),8500000,1,'A','Đặng Minh Quân','Nguyễn Hoàng Minh','2022-01-03','HR_ADMIN'),
('HD000019','NV000019',2,'2022-06-01',DATE_ADD('2022-06-01',INTERVAL 12 MONTH),8500000,1,'A','Mai Thị Bích','Nguyễn Hoàng Minh','2022-06-01','HR_ADMIN'),
('HD000020','NV000020',1,'2024-12-02',DATE_ADD('2024-12-02',INTERVAL 2 MONTH),6500000,1,'A','Lưu Văn Sơn','Nguyễn Hoàng Minh','2024-12-02','HR_ADMIN'),
('HD000021','NV000021',3,'2015-03-01',DATE_ADD('2015-03-01',INTERVAL 24 MONTH),28000000,1,'A','Phạm Anh Tuấn','Nguyễn Hoàng Minh','2015-03-01','HR_ADMIN'),
('HD000022','NV000022',3,'2017-01-09',DATE_ADD('2017-01-09',INTERVAL 24 MONTH),21000000,1,'A','Nguyễn Thị Hồng Nhung','Nguyễn Hoàng Minh','2017-01-09','HR_ADMIN'),
('HD000023','NV000023',3,'2017-07-03',DATE_ADD('2017-07-03',INTERVAL 24 MONTH),16000000,1,'A','Bùi Văn Long','Nguyễn Hoàng Minh','2017-07-03','HR_ADMIN'),
('HD000024','NV000024',3,'2018-02-01',DATE_ADD('2018-02-01',INTERVAL 24 MONTH),15500000,1,'A','Cao Thị Liên','Nguyễn Hoàng Minh','2018-02-01','HR_ADMIN'),
('HD000025','NV000025',3,'2018-04-02',DATE_ADD('2018-04-02',INTERVAL 24 MONTH),15000000,1,'A','Lê Minh Đạt','Nguyễn Hoàng Minh','2018-04-02','HR_ADMIN'),
('HD000026','NV000026',2,'2019-09-02',DATE_ADD('2019-09-02',INTERVAL 12 MONTH),11500000,1,'A','Đào Thị Phúc','Nguyễn Hoàng Minh','2019-09-02','HR_ADMIN'),
('HD000027','NV000027',2,'2020-01-06',DATE_ADD('2020-01-06',INTERVAL 12 MONTH),11500000,1,'A','Trần Văn Khoa','Nguyễn Hoàng Minh','2020-01-06','HR_ADMIN'),
('HD000028','NV000028',2,'2020-06-01',DATE_ADD('2020-06-01',INTERVAL 12 MONTH),11500000,1,'A','Lương Thị Diễm','Nguyễn Hoàng Minh','2020-06-01','HR_ADMIN'),
('HD000029','NV000029',2,'2021-01-04',DATE_ADD('2021-01-04',INTERVAL 12 MONTH),11500000,1,'A','Phan Đức Hiếu','Nguyễn Hoàng Minh','2021-01-04','HR_ADMIN'),
('HD000030','NV000030',2,'2021-04-01',DATE_ADD('2021-04-01',INTERVAL 12 MONTH),11500000,1,'A','Vũ Thị Lan','Nguyễn Hoàng Minh','2021-04-01','HR_ADMIN'),
('HD000031','NV000031',2,'2021-07-01',DATE_ADD('2021-07-01',INTERVAL 12 MONTH),8500000,1,'A','Dương Văn Nhật','Nguyễn Hoàng Minh','2021-07-01','HR_ADMIN'),
('HD000032','NV000032',2,'2022-01-03',DATE_ADD('2022-01-03',INTERVAL 12 MONTH),8500000,1,'A','Phạm Thị Thu Hà','Nguyễn Hoàng Minh','2022-01-03','HR_ADMIN'),
('HD000033','NV000033',2,'2022-03-01',DATE_ADD('2022-03-01',INTERVAL 12 MONTH),8500000,1,'A','Hoàng Văn Tùng','Nguyễn Hoàng Minh','2022-03-01','HR_ADMIN'),
('HD000034','NV000034',2,'2022-08-01',DATE_ADD('2022-08-01',INTERVAL 12 MONTH),8500000,1,'A','Nguyễn Thị Ánh','Nguyễn Hoàng Minh','2022-08-01','HR_ADMIN'),
('HD000035','NV000035',2,'2023-01-03',DATE_ADD('2023-01-03',INTERVAL 12 MONTH),8500000,1,'A','Trần Minh Hoàng','Nguyễn Hoàng Minh','2023-01-03','HR_ADMIN'),
('HD000036','NV000036',2,'2023-04-03',DATE_ADD('2023-04-03',INTERVAL 12 MONTH),8500000,1,'A','Lê Thị Vy','Nguyễn Hoàng Minh','2023-04-03','HR_ADMIN'),
('HD000037','NV000037',2,'2023-07-03',DATE_ADD('2023-07-03',INTERVAL 12 MONTH),8500000,1,'A','Đỗ Văn Chiến','Nguyễn Hoàng Minh','2023-07-03','HR_ADMIN'),
('HD000038','NV000038',1,'2024-10-01',DATE_ADD('2024-10-01',INTERVAL 2 MONTH),6500000,1,'A','Kiều Thị Hà','Nguyễn Hoàng Minh','2024-10-01','HR_ADMIN'),
('HD000039','NV000039',3,'2015-05-04',DATE_ADD('2015-05-04',INTERVAL 24 MONTH),27000000,1,'A','Dương Quốc Hùng','Nguyễn Hoàng Minh','2015-05-04','HR_ADMIN'),
('HD000040','NV000040',3,'2017-10-02',DATE_ADD('2017-10-02',INTERVAL 24 MONTH),20000000,1,'A','Võ Thị Quỳnh Anh','Nguyễn Hoàng Minh','2017-10-02','HR_ADMIN'),
('HD000041','NV000041',3,'2018-08-01',DATE_ADD('2018-08-01',INTERVAL 24 MONTH),16500000,1,'A','Nguyễn Văn Phú','Nguyễn Hoàng Minh','2018-08-01','HR_ADMIN'),
('HD000042','NV000042',3,'2019-02-01',DATE_ADD('2019-02-01',INTERVAL 24 MONTH),15000000,1,'A','Huỳnh Thị Kim Chi','Nguyễn Hoàng Minh','2019-02-01','HR_ADMIN'),
('HD000043','NV000043',2,'2019-11-04',DATE_ADD('2019-11-04',INTERVAL 12 MONTH),11500000,1,'A','Bùi Minh Châu','Nguyễn Hoàng Minh','2019-11-04','HR_ADMIN'),
('HD000044','NV000044',2,'2020-04-06',DATE_ADD('2020-04-06',INTERVAL 12 MONTH),11500000,1,'A','Trịnh Thị Phương Linh','Nguyễn Hoàng Minh','2020-04-06','HR_ADMIN'),
('HD000045','NV000045',2,'2021-06-01',DATE_ADD('2021-06-01',INTERVAL 12 MONTH),11500000,1,'A','Nguyễn Hoàng Nam','Nguyễn Hoàng Minh','2021-06-01','HR_ADMIN'),
('HD000046','NV000046',2,'2021-10-04',DATE_ADD('2021-10-04',INTERVAL 12 MONTH),8500000,1,'A','Đặng Thị Hoa','Nguyễn Hoàng Minh','2021-10-04','HR_ADMIN'),
('HD000047','NV000047',2,'2022-04-04',DATE_ADD('2022-04-04',INTERVAL 12 MONTH),8500000,1,'A','Phạm Văn Thành','Nguyễn Hoàng Minh','2022-04-04','HR_ADMIN'),
('HD000048','NV000048',2,'2022-09-01',DATE_ADD('2022-09-01',INTERVAL 12 MONTH),8500000,1,'A','Lý Thị Ái','Nguyễn Hoàng Minh','2022-09-01','HR_ADMIN'),
('HD000049','NV000049',2,'2023-03-01',DATE_ADD('2023-03-01',INTERVAL 12 MONTH),8500000,1,'A','Mai Văn Khánh','Nguyễn Hoàng Minh','2023-03-01','HR_ADMIN'),
('HD000050','NV000050',1,'2024-11-04',DATE_ADD('2024-11-04',INTERVAL 2 MONTH),6500000,1,'A','Ngô Thị Minh Nguyệt','Nguyễn Hoàng Minh','2024-11-04','HR_ADMIN');

COMMIT;
SELECT '[OK] §3 HopDong — 50 hợp đồng' AS Info;

-- ============================================================
-- §4  LUONGCOBAN — mức lương hiệu lực hiện tại
-- ============================================================
START TRANSACTION;

INSERT INTO LuongCoBan(MaNV,LuongCB,LuongDongBH,NgayHieuLuc,NgayHetHieuLuc,LyDo,NguoiDuyet) VALUES
('NV000001',55000000,46800000,'2015-01-05',NULL,'Mức lương khởi điểm','HR_ADMIN'),
('NV000002',8500000,8500000,'2019-03-01',NULL,'Mức lương khởi điểm','HR_ADMIN'),
('NV000003',26000000,26000000,'2016-02-15',NULL,'Mức lương khởi điểm','HR_ADMIN'),
('NV000004',11500000,11500000,'2018-06-01',NULL,'Mức lương khởi điểm','HR_ADMIN'),
('NV000005',11500000,11500000,'2019-01-10',NULL,'Mức lương khởi điểm','HR_ADMIN'),
('NV000006',8500000,8500000,'2020-03-02',NULL,'Mức lương khởi điểm','HR_ADMIN'),
('NV000007',8500000,8500000,'2020-07-01',NULL,'Mức lương khởi điểm','HR_ADMIN'),
('NV000008',8500000,8500000,'2021-01-04',NULL,'Mức lương khởi điểm','HR_ADMIN'),
('NV000009',11500000,11500000,'2018-11-01',NULL,'Mức lương khởi điểm','HR_ADMIN'),
('NV000010',6500000,6500000,'2024-11-01',NULL,'Mức lương khởi điểm','HR_ADMIN'),
('NV000011',25000000,25000000,'2015-07-01',NULL,'Mức lương khởi điểm','HR_ADMIN'),
('NV000012',20000000,20000000,'2016-09-01',NULL,'Mức lương khởi điểm','HR_ADMIN'),
('NV000013',15000000,15000000,'2017-04-03',NULL,'Mức lương khởi điểm','HR_ADMIN'),
('NV000014',11500000,11500000,'2019-05-01',NULL,'Mức lương khởi điểm','HR_ADMIN'),
('NV000015',11500000,11500000,'2019-08-01',NULL,'Mức lương khởi điểm','HR_ADMIN'),
('NV000016',8500000,8500000,'2020-10-01',NULL,'Mức lương khởi điểm','HR_ADMIN'),
('NV000017',8500000,8500000,'2021-03-01',NULL,'Mức lương khởi điểm','HR_ADMIN'),
('NV000018',8500000,8500000,'2022-01-03',NULL,'Mức lương khởi điểm','HR_ADMIN'),
('NV000019',8500000,8500000,'2022-06-01',NULL,'Mức lương khởi điểm','HR_ADMIN'),
('NV000020',6500000,6500000,'2024-12-02',NULL,'Mức lương khởi điểm','HR_ADMIN'),
('NV000021',28000000,28000000,'2015-03-01',NULL,'Mức lương khởi điểm','HR_ADMIN'),
('NV000022',21000000,21000000,'2017-01-09',NULL,'Mức lương khởi điểm','HR_ADMIN'),
('NV000023',16000000,16000000,'2017-07-03',NULL,'Mức lương khởi điểm','HR_ADMIN'),
('NV000024',15500000,15500000,'2018-02-01',NULL,'Mức lương khởi điểm','HR_ADMIN'),
('NV000025',15000000,15000000,'2018-04-02',NULL,'Mức lương khởi điểm','HR_ADMIN'),
('NV000026',11500000,11500000,'2019-09-02',NULL,'Mức lương khởi điểm','HR_ADMIN'),
('NV000027',11500000,11500000,'2020-01-06',NULL,'Mức lương khởi điểm','HR_ADMIN'),
('NV000028',11500000,11500000,'2020-06-01',NULL,'Mức lương khởi điểm','HR_ADMIN'),
('NV000029',11500000,11500000,'2021-01-04',NULL,'Mức lương khởi điểm','HR_ADMIN'),
('NV000030',11500000,11500000,'2021-04-01',NULL,'Mức lương khởi điểm','HR_ADMIN'),
('NV000031',8500000,8500000,'2021-07-01',NULL,'Mức lương khởi điểm','HR_ADMIN'),
('NV000032',8500000,8500000,'2022-01-03',NULL,'Mức lương khởi điểm','HR_ADMIN'),
('NV000033',8500000,8500000,'2022-03-01',NULL,'Mức lương khởi điểm','HR_ADMIN'),
('NV000034',8500000,8500000,'2022-08-01',NULL,'Mức lương khởi điểm','HR_ADMIN'),
('NV000035',8500000,8500000,'2023-01-03',NULL,'Mức lương khởi điểm','HR_ADMIN'),
('NV000036',8500000,8500000,'2023-04-03',NULL,'Mức lương khởi điểm','HR_ADMIN'),
('NV000037',8500000,8500000,'2023-07-03',NULL,'Mức lương khởi điểm','HR_ADMIN'),
('NV000038',6500000,6500000,'2024-10-01',NULL,'Mức lương khởi điểm','HR_ADMIN'),
('NV000039',27000000,27000000,'2015-05-04',NULL,'Mức lương khởi điểm','HR_ADMIN'),
('NV000040',20000000,20000000,'2017-10-02',NULL,'Mức lương khởi điểm','HR_ADMIN'),
('NV000041',16500000,16500000,'2018-08-01',NULL,'Mức lương khởi điểm','HR_ADMIN'),
('NV000042',15000000,15000000,'2019-02-01',NULL,'Mức lương khởi điểm','HR_ADMIN'),
('NV000043',11500000,11500000,'2019-11-04',NULL,'Mức lương khởi điểm','HR_ADMIN'),
('NV000044',11500000,11500000,'2020-04-06',NULL,'Mức lương khởi điểm','HR_ADMIN'),
('NV000045',11500000,11500000,'2021-06-01',NULL,'Mức lương khởi điểm','HR_ADMIN'),
('NV000046',8500000,8500000,'2021-10-04',NULL,'Mức lương khởi điểm','HR_ADMIN'),
('NV000047',8500000,8500000,'2022-04-04',NULL,'Mức lương khởi điểm','HR_ADMIN'),
('NV000048',8500000,8500000,'2022-09-01',NULL,'Mức lương khởi điểm','HR_ADMIN'),
('NV000049',8500000,8500000,'2023-03-01',NULL,'Mức lương khởi điểm','HR_ADMIN'),
('NV000050',6500000,6500000,'2024-11-04',NULL,'Mức lương khởi điểm','HR_ADMIN');

COMMIT;
SELECT '[OK] §4 LuongCoBan — 50 mức lương' AS Info;

-- ============================================================
-- §5  NHANVIENPHUCL0I — gán phúc lợi
-- ============================================================
START TRANSACTION;

INSERT INTO NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive) VALUES
-- NV000001 (TGĐ): đủ 6 loại phúc lợi
('NV000001','FL0001','2015-01-05',1),('NV000001','FL0002','2015-01-05',1),
('NV000001','FL0003','2015-01-05',1),('NV000001','FL0004','2015-01-05',1),
('NV000001','FL0005','2015-01-05',1),('NV000001','FL0006','2015-01-05',1),
-- NV000002
('NV000002','FL0001','2019-03-01',1),('NV000002','FL0002','2019-03-01',1),('NV000002','FL0006','2019-03-01',1),
-- NV000003 (Trưởng Phòng NS)
('NV000003','FL0001','2016-02-15',1),('NV000003','FL0002','2016-02-15',1),
('NV000003','FL0003','2016-02-15',1),('NV000003','FL0004','2016-02-15',1),
('NV000003','FL0005','2016-02-15',1),('NV000003','FL0006','2016-02-15',1),
-- NV000004-009 (Nhân viên Phòng NS)
('NV000004','FL0001','2018-06-01',1),('NV000004','FL0002','2018-06-01',1),('NV000004','FL0006','2018-06-01',1),
('NV000005','FL0001','2019-01-10',1),('NV000005','FL0002','2019-01-10',1),('NV000005','FL0006','2019-01-10',1),
('NV000006','FL0001','2020-03-02',1),('NV000006','FL0002','2020-03-02',1),
('NV000007','FL0001','2020-07-01',1),('NV000007','FL0002','2020-07-01',1),
('NV000008','FL0001','2021-01-04',1),('NV000008','FL0002','2021-01-04',1),
('NV000009','FL0001','2018-11-01',1),('NV000009','FL0002','2018-11-01',1),('NV000009','FL0006','2018-11-01',1),
-- NV000011 (Trưởng Phòng TC-KT)
('NV000011','FL0001','2015-07-01',1),('NV000011','FL0002','2015-07-01',1),
('NV000011','FL0003','2015-07-01',1),('NV000011','FL0005','2015-07-01',1),('NV000011','FL0006','2015-07-01',1),
-- NV000012-019
('NV000012','FL0001','2016-09-01',1),('NV000012','FL0002','2016-09-01',1),('NV000012','FL0006','2016-09-01',1),
('NV000013','FL0001','2017-04-03',1),('NV000013','FL0002','2017-04-03',1),('NV000013','FL0006','2017-04-03',1),
('NV000014','FL0001','2019-05-01',1),('NV000014','FL0002','2019-05-01',1),
('NV000015','FL0001','2019-08-01',1),('NV000015','FL0002','2019-08-01',1),
('NV000016','FL0001','2020-10-01',1),('NV000016','FL0002','2020-10-01',1),
('NV000017','FL0001','2021-03-01',1),('NV000017','FL0002','2021-03-01',1),
('NV000018','FL0001','2022-01-03',1),('NV000018','FL0002','2022-01-03',1),
('NV000019','FL0001','2022-06-01',1),('NV000019','FL0002','2022-06-01',1),
-- NV000021 (TP CNTT)
('NV000021','FL0001','2015-03-01',1),('NV000021','FL0002','2015-03-01',1),
('NV000021','FL0003','2015-03-01',1),('NV000021','FL0005','2015-03-01',1),('NV000021','FL0006','2015-03-01',1),
-- NV000022-037
('NV000022','FL0001','2017-01-09',1),('NV000022','FL0002','2017-01-09',1),('NV000022','FL0006','2017-01-09',1),
('NV000023','FL0001','2017-07-03',1),('NV000023','FL0002','2017-07-03',1),('NV000023','FL0006','2017-07-03',1),
('NV000024','FL0001','2018-02-01',1),('NV000024','FL0002','2018-02-01',1),('NV000024','FL0006','2018-02-01',1),
('NV000025','FL0001','2018-04-02',1),('NV000025','FL0002','2018-04-02',1),('NV000025','FL0006','2018-04-02',1),
('NV000026','FL0001','2019-09-02',1),('NV000026','FL0002','2019-09-02',1),
('NV000027','FL0001','2020-01-06',1),('NV000027','FL0002','2020-01-06',1),
('NV000028','FL0001','2020-06-01',1),('NV000028','FL0002','2020-06-01',1),
('NV000029','FL0001','2021-01-04',1),('NV000029','FL0002','2021-01-04',1),
('NV000030','FL0001','2021-04-01',1),('NV000030','FL0002','2021-04-01',1),
('NV000031','FL0001','2021-07-01',1),('NV000031','FL0002','2021-07-01',1),
('NV000032','FL0001','2022-01-03',1),('NV000032','FL0002','2022-01-03',1),
('NV000033','FL0001','2022-03-01',1),('NV000033','FL0002','2022-03-01',1),
('NV000034','FL0001','2022-08-01',1),('NV000034','FL0002','2022-08-01',1),
('NV000035','FL0001','2023-01-03',1),('NV000035','FL0002','2023-01-03',1),
('NV000036','FL0001','2023-04-03',1),('NV000036','FL0002','2023-04-03',1),
('NV000037','FL0001','2023-07-03',1),('NV000037','FL0002','2023-07-03',1),
-- NV000039 (TP KD)
('NV000039','FL0001','2015-05-04',1),('NV000039','FL0002','2015-05-04',1),
('NV000039','FL0003','2015-05-04',1),('NV000039','FL0005','2015-05-04',1),('NV000039','FL0006','2015-05-04',1),
-- NV000040-050
('NV000040','FL0001','2017-10-02',1),('NV000040','FL0002','2017-10-02',1),('NV000040','FL0006','2017-10-02',1),
('NV000041','FL0001','2018-08-01',1),('NV000041','FL0002','2018-08-01',1),('NV000041','FL0006','2018-08-01',1),
('NV000042','FL0001','2019-02-01',1),('NV000042','FL0002','2019-02-01',1),('NV000042','FL0006','2019-02-01',1),
('NV000043','FL0001','2019-11-04',1),('NV000043','FL0002','2019-11-04',1),
('NV000044','FL0001','2020-04-06',1),('NV000044','FL0002','2020-04-06',1),
('NV000045','FL0001','2021-06-01',1),('NV000045','FL0002','2021-06-01',1),
('NV000046','FL0001','2021-10-04',1),('NV000046','FL0002','2021-10-04',1),
('NV000047','FL0001','2022-04-04',1),('NV000047','FL0002','2022-04-04',1),
('NV000048','FL0001','2022-09-01',1),('NV000048','FL0002','2022-09-01',1),
('NV000049','FL0001','2023-03-01',1),('NV000049','FL0002','2023-03-01',1);

COMMIT;
SELECT '[OK] §5 NhanVienPhucLoi hoàn tất' AS Info;

-- ============================================================
-- §6  CHAMCONG — Tháng 1-3/2025 (set-based)
-- ============================================================
START TRANSACTION;

-- Tạo bảng tạm ngày trong tháng để generate chấm công
-- Tháng 1/2025 (1-31)
INSERT INTO ChamCong (MaNV, NgayCham, TrangThai, GioVao, GioRa, SoGioTangCa, HeSoTangCa, NguoiCapNhat)
SELECT
    nv.MaNV,
    ngay.NgayCham,
    CASE
        WHEN DAYOFWEEK(ngay.NgayCham) IN (1,7) THEN NULL      -- Cuối tuần: không insert
        WHEN EXISTS(SELECT 1 FROM NgayLe nl WHERE nl.NgayLe = ngay.NgayCham) THEN 'NG'
        -- NV000049: hay vắng mặt (1 ngày/tháng)
        WHEN nv.MaNV = 'NV000049' AND DAY(ngay.NgayCham) = 15 THEN 'KP'
        -- Ngẫu nhiên một số NV nghỉ phép
        WHEN nv.MaNV IN ('NV000003','NV000011','NV000021') AND DAY(ngay.NgayCham) IN (20,21) THEN 'NP'
        WHEN nv.MaNV IN ('NV000005','NV000013') AND DAY(ngay.NgayCham) = 22 THEN 'OM'
        -- Còn lại: đi làm
        ELSE 'DL'
    END AS TrangThai,
    CASE
        WHEN DAYOFWEEK(ngay.NgayCham) IN (1,7) THEN NULL
        WHEN EXISTS(SELECT 1 FROM NgayLe nl WHERE nl.NgayLe = ngay.NgayCham) THEN NULL
        ELSE '08:00:00'
    END AS GioVao,
    CASE
        WHEN DAYOFWEEK(ngay.NgayCham) IN (1,7) THEN NULL
        WHEN EXISTS(SELECT 1 FROM NgayLe nl WHERE nl.NgayLe = ngay.NgayCham) THEN NULL
        -- Tăng ca cho 1 số NV
        WHEN nv.MaNV IN ('NV000023','NV000025','NV000027') AND DAY(ngay.NgayCham) IN (10,20,30) THEN '19:30:00'
        ELSE '17:30:00'
    END AS GioRa,
    CASE
        WHEN nv.MaNV IN ('NV000023','NV000025','NV000027') AND DAY(ngay.NgayCham) IN (10,20,30) THEN 2.0
        ELSE 0
    END AS SoGioTangCa,
    CASE
        WHEN nv.MaNV IN ('NV000023','NV000025','NV000027') AND DAY(ngay.NgayCham) IN (10,20,30) THEN 1.50
        ELSE 1.50
    END AS HeSoTangCa,
    'SEED_DATA' AS NguoiCapNhat
FROM (
    SELECT '2025-01-02' AS NgayCham UNION ALL SELECT '2025-01-03' UNION ALL SELECT '2025-01-06'
    UNION ALL SELECT '2025-01-07' UNION ALL SELECT '2025-01-08' UNION ALL SELECT '2025-01-09'
    UNION ALL SELECT '2025-01-10' UNION ALL SELECT '2025-01-13' UNION ALL SELECT '2025-01-14'
    UNION ALL SELECT '2025-01-15' UNION ALL SELECT '2025-01-16' UNION ALL SELECT '2025-01-17'
    UNION ALL SELECT '2025-01-20' UNION ALL SELECT '2025-01-21' UNION ALL SELECT '2025-01-22'
    UNION ALL SELECT '2025-01-23' UNION ALL SELECT '2025-01-24'
    -- Tết từ 28/1 - 2/2/2025 là ngày lễ
    UNION ALL SELECT '2025-02-03' UNION ALL SELECT '2025-02-04' UNION ALL SELECT '2025-02-05'
    UNION ALL SELECT '2025-02-06' UNION ALL SELECT '2025-02-07' UNION ALL SELECT '2025-02-10'
    UNION ALL SELECT '2025-02-11' UNION ALL SELECT '2025-02-12' UNION ALL SELECT '2025-02-13'
    UNION ALL SELECT '2025-02-14' UNION ALL SELECT '2025-02-17' UNION ALL SELECT '2025-02-18'
    UNION ALL SELECT '2025-02-19' UNION ALL SELECT '2025-02-20' UNION ALL SELECT '2025-02-21'
    UNION ALL SELECT '2025-02-24' UNION ALL SELECT '2025-02-25' UNION ALL SELECT '2025-02-26'
    UNION ALL SELECT '2025-02-27' UNION ALL SELECT '2025-02-28'
    UNION ALL SELECT '2025-03-03' UNION ALL SELECT '2025-03-04' UNION ALL SELECT '2025-03-05'
    UNION ALL SELECT '2025-03-06' UNION ALL SELECT '2025-03-07' UNION ALL SELECT '2025-03-10'
    UNION ALL SELECT '2025-03-11' UNION ALL SELECT '2025-03-12' UNION ALL SELECT '2025-03-13'
    UNION ALL SELECT '2025-03-14' UNION ALL SELECT '2025-03-17' UNION ALL SELECT '2025-03-18'
    UNION ALL SELECT '2025-03-19' UNION ALL SELECT '2025-03-20' UNION ALL SELECT '2025-03-21'
    UNION ALL SELECT '2025-03-24' UNION ALL SELECT '2025-03-25' UNION ALL SELECT '2025-03-26'
    UNION ALL SELECT '2025-03-27' UNION ALL SELECT '2025-03-28' UNION ALL SELECT '2025-03-31'
) ngay
CROSS JOIN NhanVien nv
WHERE nv.TrangThai IN ('A','P')
  AND DAYOFWEEK(ngay.NgayCham) NOT IN (1,7)  -- Chỉ insert ngày làm việc
ON DUPLICATE KEY UPDATE TrangThai = VALUES(TrangThai);

COMMIT;
SELECT '[OK] §6 ChamCong — tháng 1-3/2025' AS Info;

-- ============================================================
-- §7  NGHIPHEP — đơn nghỉ phép mẫu
-- ============================================================
START TRANSACTION;

INSERT INTO NghiPhep(MaNV, MaLoaiNghi, NgayBatDau, NgayKetThuc, LyDo, TrangThai, NguoiDuyet, NgayDuyet) VALUES
('NV000003', 1, '2025-01-20', '2025-01-21', 'Phép năm theo kế hoạch', 'A', 'NV000001', '2025-01-15 09:00:00'),
('NV000011', 1, '2025-01-20', '2025-01-21', 'Phép năm theo kế hoạch', 'A', 'NV000001', '2025-01-15 09:00:00'),
('NV000021', 1, '2025-01-20', '2025-01-21', 'Phép năm theo kế hoạch', 'A', 'NV000001', '2025-01-15 09:00:00'),
('NV000005', 2, '2025-01-22', '2025-01-22', 'Ốm đau - có giấy bác sĩ',  'A', 'NV000003', '2025-01-22 08:30:00'),
('NV000013', 2, '2025-01-22', '2025-01-22', 'Ốm đau - có giấy bác sĩ',  'A', 'NV000011', '2025-01-22 08:30:00'),
('NV000039', 1, '2025-02-17', '2025-02-18', 'Phép năm Q1/2025',          'A', 'NV000001', '2025-02-10 10:00:00'),
('NV000041', 1, '2025-03-10', '2025-03-11', 'Công việc gia đình',        'A', 'NV000039', '2025-03-05 11:00:00'),
('NV000049', 1, '2025-03-20', '2025-03-20', 'Phép năm theo kế hoạch',   'P', NULL, NULL);

COMMIT;
SELECT '[OK] §7 NghiPhep — đơn mẫu' AS Info;

-- ============================================================
-- §8  KHAUTRU — khấu trừ phát sinh
-- ============================================================
START TRANSACTION;

INSERT INTO KhauTru(MaNV, LoaiKhauTru, GiaTri, NgayPhatSinh, TrangThai, GhiChu, NguoiDuyet) VALUES
('NV000049', 'Phạt vi phạm nội quy',      500000, '2025-01-31', 'P', 'Đi muộn >3 lần tháng 1/2025', 'NV000003'),
('NV000002', 'Tạm ứng lương tháng 1',   2000000, '2025-01-15', 'P', 'Tạm ứng chi phí y tế', 'NV000001'),
('NV000014', 'Truy thu thiếu hụt tháng 12', 300000, '2025-01-31', 'P', 'Chênh lệch tính lương tháng 12/2024', 'NV000011');

COMMIT;
SELECT '[OK] §8 KhauTru — phát sinh mẫu' AS Info;

-- ============================================================
-- §9  UPDATE TRƯỞNG PHÒNG & KIỂM TRA
-- ============================================================
START TRANSACTION;

UPDATE PhongBan SET MaTruongPhong = 'NV000001' WHERE MaPB = 'PB0001';
UPDATE PhongBan SET MaTruongPhong = 'NV000003' WHERE MaPB = 'PB0002';
UPDATE PhongBan SET MaTruongPhong = 'NV000011' WHERE MaPB = 'PB0003';
UPDATE PhongBan SET MaTruongPhong = 'NV000021' WHERE MaPB = 'PB0004';
UPDATE PhongBan SET MaTruongPhong = 'NV000039' WHERE MaPB = 'PB0005';

COMMIT;

-- Re-enable FK checks
SET FOREIGN_KEY_CHECKS = 1;

-- Kiểm tra tổng hợp
SELECT 'KIỂM TRA TỔNG HỢP DỮ LIỆU' AS Info;
SELECT TABLE_NAME AS Bang, TABLE_ROWS AS SoBanGhi_UocTinh
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = 'HRPayrollDB'
  AND TABLE_TYPE = 'BASE TABLE'
ORDER BY TABLE_NAME;

SELECT CONCAT('[DONE] seed_data.sql hoàn tất. ',
              COUNT(*), ' nhân viên, sẵn sàng chạy sp_TinhLuong') AS KetQua
FROM NhanVien WHERE TrangThai IN ('A','P');
