-- ============================================================
-- FILE       : seed_data.sql
-- PROJECT    : Hệ Thống Quản Lý Nhân Sự & Tính Lương Tự Động
-- MỤC ĐÍCH   : Dữ liệu mẫu thực tế cho toàn bộ hệ thống
--   §1  Bảng danh mục (Lookup): PhongBan, ChucVu,
--       LoaiHopDong, LoaiNghiPhep, LoaiPhucLoi
--   §2  NhanVien (50 nhân viên)
--   §3  HopDong  (50 hợp đồng)
--   §4  LuongCoBan (50 mức lương hiệu lực)
--   §5  NhanVienPhucLoi (gán phúc lợi)
--   §6  ChamCong Jan–Mar 2025 (set-based, ~3,200 dòng)
--   §7  NghiPhep (đơn nghỉ phép mẫu)
--   §8  KhauTru (khấu trừ phát sinh)
--   §9  UPDATE trưởng phòng & kiểm tra tổng
-- DEPENDENCY : Chạy SAU 01_create_tables.sql
-- ============================================================
USE HRPayrollDB;
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;   -- Rollback tự động nếu có lỗi
GO

-- ============================================================
-- §1  BẢNG DANH MỤC (LOOKUP)
-- ============================================================
BEGIN TRANSACTION;

-- ── §1.1 PhongBan ────────────────────────────────────────────
DELETE FROM dbo.PhongBan;   -- Reset nếu chạy lại
INSERT INTO dbo.PhongBan (MaPB, TenPB, DiaDiem, DienThoai, Email, NgayThanhLap, IsActive)
VALUES
  ('PB0001', N'Ban Giám Đốc',               N'Tầng 10, Tòa nhà Landmark',  '02838001001', 'banlanhday@hrpayroll.vn',  '2010-03-15', 1),
  ('PB0002', N'Phòng Nhân Sự & Hành Chính', N'Tầng 5, Phòng 501',          '02838001002', 'nhansu@hrpayroll.vn',      '2010-03-15', 1),
  ('PB0003', N'Phòng Tài Chính Kế Toán',    N'Tầng 5, Phòng 502',          '02838001003', 'ketoan@hrpayroll.vn',      '2010-03-15', 1),
  ('PB0004', N'Phòng Công Nghệ Thông Tin',  N'Tầng 6, Phòng 601',          '02838001004', 'cntt@hrpayroll.vn',        '2012-01-01', 1),
  ('PB0005', N'Phòng Kinh Doanh & Marketing',N'Tầng 7, Phòng 701',         '02838001005', 'kinhdoanh@hrpayroll.vn',   '2010-03-15', 1);
PRINT N'[OK] §1.1 PhongBan — 5 phòng ban';

-- ── §1.2 ChucVu ──────────────────────────────────────────────
DELETE FROM dbo.ChucVu;
INSERT INTO dbo.ChucVu (MaCV, TenCV, HeSoLuong, CapBac, MoTa, IsActive)
VALUES
  ('CV0001', N'Tổng Giám Đốc',           8.00, 5, N'Lãnh đạo cao nhất công ty',             1),
  ('CV0002', N'Trưởng Phòng',             4.50, 4, N'Quản lý toàn bộ phòng ban',             1),
  ('CV0003', N'Phó Phòng',               3.80, 4, N'Hỗ trợ Trưởng Phòng điều hành',         1),
  ('CV0004', N'Chuyên Viên Cao Cấp',     3.00, 3, N'≥5 năm kinh nghiệm chuyên môn',         1),
  ('CV0005', N'Chuyên Viên',             2.50, 2, N'2–5 năm kinh nghiệm',                   1),
  ('CV0006', N'Nhân Viên',               2.00, 1, N'Nhân viên chính thức',                  1),
  ('CV0007', N'Nhân Viên Thử Việc',      1.50, 1, N'Đang trong thời gian thử việc 2 tháng', 1);
PRINT N'[OK] §1.2 ChucVu — 7 chức vụ';

-- ── §1.3 LoaiHopDong ─────────────────────────────────────────
SET IDENTITY_INSERT dbo.LoaiHopDong OFF;
DELETE FROM dbo.LoaiHopDong;
-- Dùng SET IDENTITY_INSERT để kiểm soát MaLoaiHD
SET IDENTITY_INSERT dbo.LoaiHopDong ON;
INSERT INTO dbo.LoaiHopDong (MaLoaiHD, TenLoaiHD, ThoiHanToiDa, TiLeBHXH, MoTa)
VALUES
  (1, N'Thử việc',            2,    0.00, N'Tối đa 2 tháng, không đóng BHXH'),
  (2, N'Xác định 1 năm',     12,    8.00, N'Hợp đồng 12 tháng, đóng BHXH đầy đủ'),
  (3, N'Xác định 2 năm',     24,    8.00, N'Hợp đồng 24 tháng, đóng BHXH đầy đủ'),
  (4, N'Không xác định thời hạn', NULL, 8.00, N'Hợp đồng vô thời hạn theo BLLĐ 2019');
SET IDENTITY_INSERT dbo.LoaiHopDong OFF;
PRINT N'[OK] §1.3 LoaiHopDong — 4 loại';

-- ── §1.4 LoaiNghiPhep ────────────────────────────────────────
DELETE FROM dbo.LoaiNghiPhep;
SET IDENTITY_INSERT dbo.LoaiNghiPhep ON;
INSERT INTO dbo.LoaiNghiPhep (MaLoaiNghi, TenLoaiNghi, CoHuongLuong, SoNgayToiDa, MoTa)
VALUES
  (1, N'Phép năm',               1,  12,   N'Tối thiểu 12 ngày/năm theo BLLĐ'),
  (2, N'Nghỉ ốm đau',           1,  30,   N'Có hưởng lương BHXH'),
  (3, N'Thai sản',               1, 180,   N'6 tháng hưởng 100% lương BH'),
  (4, N'Việc riêng không lương', 0, NULL,  N'Không hưởng lương'),
  (5, N'Nghỉ bù',                1, NULL,  N'Bù giờ làm thêm');
SET IDENTITY_INSERT dbo.LoaiNghiPhep OFF;
PRINT N'[OK] §1.4 LoaiNghiPhep — 5 loại';

-- ── §1.5 LoaiPhucLoi ─────────────────────────────────────────
DELETE FROM dbo.LoaiPhucLoi;
INSERT INTO dbo.LoaiPhucLoi (MaFL, TenFL, LoaiGiaTri, GiaTri, CoTinhThue, MoTa, IsActive)
VALUES
  ('FL0001', N'Phụ cấp ăn trưa',          'F',   730000, 0, N'≤730k/tháng miễn thuế theo TT111', 1),
  ('FL0002', N'Phụ cấp xăng xe đi lại',   'F',   500000, 0, N'Không tính thuế TNCN',             1),
  ('FL0003', N'Phụ cấp điện thoại',        'F',   300000, 0, N'Không tính thuế TNCN',             1),
  ('FL0004', N'Phụ cấp nhà ở',             'F', 1500000, 1, N'Tính vào thu nhập chịu thuế',       1),
  ('FL0005', N'Phụ cấp trách nhiệm QL',    'F', 2000000, 1, N'Dành cho cấp quản lý trở lên',      1),
  ('FL0006', N'Phụ cấp thâm niên (2%)',    'P',      2.0, 0, N'2% lương CB, miễn thuế',            1);

COMMIT TRANSACTION;
PRINT N'[OK] §1.5 LoaiPhucLoi — 6 loại phúc lợi';
PRINT N'[OK] §1  LOOKUP TABLES hoàn tất';
GO

-- ============================================================
-- §2  NHANVIEN — 50 nhân viên
-- ============================================================
BEGIN TRANSACTION;
DELETE FROM dbo.NhanVienPhucLoi;
DELETE FROM dbo.ChamCong;
DELETE FROM dbo.NghiPhep;
DELETE FROM dbo.KhauTru;
DELETE FROM dbo.ChiTietLuong;
DELETE FROM dbo.BangLuong;
DELETE FROM dbo.AuditLog_Luong;
DELETE FROM dbo.AuditLog_HopDong;
DELETE FROM dbo.LuongCoBan;
DELETE FROM dbo.HopDong;
DELETE FROM dbo.NhanVien;
-- Reset PhongBan.MaTruongPhong trước khi xoá NhanVien
UPDATE dbo.PhongBan SET MaTruongPhong = NULL;

INSERT INTO dbo.NhanVien (MaNV,HoTen,GioiTinh,NgaySinh,CCCD,DiaChi,Email,SoDienThoai,MaPB,MaCV,NgayVaoLam,TrangThai,MaSoThue,SoTaiKhoanNH,TenNganHang,NguoiTao)
VALUES('NV000001',N'Nguyễn Hoàng Minh','M','1973-07-15','036073001234',N'Q.1, TP.HCM','nguynhongminh@hrpayroll.vn','0973001234','PB0001','CV0001','2015-01-05','A','0300123456','19001000100001',N'Vietcombank','HR_ADMIN');
INSERT INTO dbo.NhanVien (MaNV,HoTen,GioiTinh,NgaySinh,CCCD,DiaChi,Email,SoDienThoai,MaPB,MaCV,NgayVaoLam,TrangThai,MaSoThue,SoTaiKhoanNH,TenNganHang,NguoiTao)
VALUES('NV000002',N'Trần Thị Lan Anh','F','1992-04-20','038092002345',N'Q.Bình Thạnh, TP.HCM','trnthlananh@hrpayroll.vn','0992002345','PB0001','CV0006','2019-03-01','A','0300234567','19001000100002',N'Techcombank','HR_ADMIN');
INSERT INTO dbo.NhanVien (MaNV,HoTen,GioiTinh,NgaySinh,CCCD,DiaChi,Email,SoDienThoai,MaPB,MaCV,NgayVaoLam,TrangThai,MaSoThue,SoTaiKhoanNH,TenNganHang,NguoiTao)
VALUES('NV000003',N'Lê Văn Đức','M','1980-09-12','036080003456',N'Q.Tân Bình, TP.HCM','lvndc@hrpayroll.vn','0980003456','PB0002','CV0002','2016-02-15','A','0300345678','19001000100003',N'BIDV','HR_ADMIN');
INSERT INTO dbo.NhanVien (MaNV,HoTen,GioiTinh,NgaySinh,CCCD,DiaChi,Email,SoDienThoai,MaPB,MaCV,NgayVaoLam,TrangThai,MaSoThue,SoTaiKhoanNH,TenNganHang,NguoiTao)
VALUES('NV000004',N'Phạm Thị Hương','F','1988-11-03','038088004567',N'Q.Phú Nhuận, TP.HCM','phmthhng@hrpayroll.vn','0988004567','PB0002','CV0005','2018-06-01','A','0300456789','19001000100004',N'Vietcombank','HR_ADMIN');
INSERT INTO dbo.NhanVien (MaNV,HoTen,GioiTinh,NgaySinh,CCCD,DiaChi,Email,SoDienThoai,MaPB,MaCV,NgayVaoLam,TrangThai,MaSoThue,SoTaiKhoanNH,TenNganHang,NguoiTao)
VALUES('NV000005',N'Võ Minh Tuấn','M','1990-02-28','036090005678',N'Q.Gò Vấp, TP.HCM','vminhtun@hrpayroll.vn','0990005678','PB0002','CV0005','2019-01-10','A','0300567890','19001000100005',N'Agribank','HR_ADMIN');
INSERT INTO dbo.NhanVien (MaNV,HoTen,GioiTinh,NgaySinh,CCCD,DiaChi,Email,SoDienThoai,MaPB,MaCV,NgayVaoLam,TrangThai,MaSoThue,SoTaiKhoanNH,TenNganHang,NguoiTao)
VALUES('NV000006',N'Nguyễn Thị Thu Hà','F','1993-08-15','038093006789',N'Q.3, TP.HCM','nguynththuh@hrpayroll.vn','0993006789','PB0002','CV0006','2020-03-02','A','0300678901','19001000100006',N'Techcombank','HR_ADMIN');
INSERT INTO dbo.NhanVien (MaNV,HoTen,GioiTinh,NgaySinh,CCCD,DiaChi,Email,SoDienThoai,MaPB,MaCV,NgayVaoLam,TrangThai,MaSoThue,SoTaiKhoanNH,TenNganHang,NguoiTao)
VALUES('NV000007',N'Đinh Văn Hùng','M','1991-04-22','036091007890',N'Q.Thủ Đức, TP.HCM','dinhvnhng@hrpayroll.vn','0991007890','PB0002','CV0006','2020-07-01','A','0300789012','19001000100007',N'BIDV','HR_ADMIN');
INSERT INTO dbo.NhanVien (MaNV,HoTen,GioiTinh,NgaySinh,CCCD,DiaChi,Email,SoDienThoai,MaPB,MaCV,NgayVaoLam,TrangThai,MaSoThue,SoTaiKhoanNH,TenNganHang,NguoiTao)
VALUES('NV000008',N'Trương Thị Ngọc','F','1994-09-10','038094008901',N'Q.7, TP.HCM','trngthngc@hrpayroll.vn','0994008901','PB0002','CV0006','2021-01-04','A','0300890123','19001000100008',N'Vietinbank','HR_ADMIN');
INSERT INTO dbo.NhanVien (MaNV,HoTen,GioiTinh,NgaySinh,CCCD,DiaChi,Email,SoDienThoai,MaPB,MaCV,NgayVaoLam,TrangThai,MaSoThue,SoTaiKhoanNH,TenNganHang,NguoiTao)
VALUES('NV000009',N'Bùi Quang Khải','M','1989-12-05','036089009012',N'Bình Dương','biquangkhi@hrpayroll.vn','0989009012','PB0002','CV0005','2018-11-01','A','0300901234','19001000100009',N'MBBank','HR_ADMIN');
INSERT INTO dbo.NhanVien (MaNV,HoTen,GioiTinh,NgaySinh,CCCD,DiaChi,Email,SoDienThoai,MaPB,MaCV,NgayVaoLam,TrangThai,MaSoThue,SoTaiKhoanNH,TenNganHang,NguoiTao)
VALUES('NV000010',N'Đỗ Thị Mai Linh','F','1999-06-18','038099010123',N'Đồng Nai','dthmailinh@hrpayroll.vn','0999010123','PB0002','CV0007','2024-11-01','P','0301012345','19001000100010',N'Vietcombank','HR_ADMIN');
INSERT INTO dbo.NhanVien (MaNV,HoTen,GioiTinh,NgaySinh,CCCD,DiaChi,Email,SoDienThoai,MaPB,MaCV,NgayVaoLam,TrangThai,MaSoThue,SoTaiKhoanNH,TenNganHang,NguoiTao)
VALUES('NV000011',N'Hoàng Thị Phương','F','1978-02-20','038078011234',N'Q.1, TP.HCM','hongthphng@hrpayroll.vn','0978011234','PB0003','CV0002','2015-07-01','A','0301123456','19001000100011',N'BIDV','HR_ADMIN');
INSERT INTO dbo.NhanVien (MaNV,HoTen,GioiTinh,NgaySinh,CCCD,DiaChi,Email,SoDienThoai,MaPB,MaCV,NgayVaoLam,TrangThai,MaSoThue,SoTaiKhoanNH,TenNganHang,NguoiTao)
VALUES('NV000012',N'Phan Văn Thắng','M','1982-05-15','036082012345',N'Q.Bình Thạnh, TP.HCM','phanvnthng@hrpayroll.vn','0982012345','PB0003','CV0003','2016-09-01','A','0301234567','19001000100012',N'Vietcombank','HR_ADMIN');
INSERT INTO dbo.NhanVien (MaNV,HoTen,GioiTinh,NgaySinh,CCCD,DiaChi,Email,SoDienThoai,MaPB,MaCV,NgayVaoLam,TrangThai,MaSoThue,SoTaiKhoanNH,TenNganHang,NguoiTao)
VALUES('NV000013',N'Lý Thị Kim Oanh','F','1986-09-25','038086013456',N'Q.Tân Bình, TP.HCM','lthkimoanh@hrpayroll.vn','0986013456','PB0003','CV0004','2017-04-03','A','0301345678','19001000100013',N'Techcombank','HR_ADMIN');
INSERT INTO dbo.NhanVien (MaNV,HoTen,GioiTinh,NgaySinh,CCCD,DiaChi,Email,SoDienThoai,MaPB,MaCV,NgayVaoLam,TrangThai,MaSoThue,SoTaiKhoanNH,TenNganHang,NguoiTao)
VALUES('NV000014',N'Ngô Đức Toàn','M','1990-11-08','036090014567',N'Q.Phú Nhuận, TP.HCM','ngdcton@hrpayroll.vn','0990014567','PB0003','CV0005','2019-05-01','A','0301456789','19001000100014',N'Agribank','HR_ADMIN');
INSERT INTO dbo.NhanVien (MaNV,HoTen,GioiTinh,NgaySinh,CCCD,DiaChi,Email,SoDienThoai,MaPB,MaCV,NgayVaoLam,TrangThai,MaSoThue,SoTaiKhoanNH,TenNganHang,NguoiTao)
VALUES('NV000015',N'Vũ Thị Thanh Xuân','F','1991-03-17','038091015678',N'Q.Gò Vấp, TP.HCM','vththanhxun@hrpayroll.vn','0991015678','PB0003','CV0005','2019-08-01','A','0301567890','19001000100015',N'BIDV','HR_ADMIN');
INSERT INTO dbo.NhanVien (MaNV,HoTen,GioiTinh,NgaySinh,CCCD,DiaChi,Email,SoDienThoai,MaPB,MaCV,NgayVaoLam,TrangThai,MaSoThue,SoTaiKhoanNH,TenNganHang,NguoiTao)
VALUES('NV000016',N'Trịnh Văn Dũng','M','1993-07-22','036093016789',N'Q.3, TP.HCM','trnhvndng@hrpayroll.vn','0993016789','PB0003','CV0006','2020-10-01','A','0301678901','19001000100016',N'Vietinbank','HR_ADMIN');
INSERT INTO dbo.NhanVien (MaNV,HoTen,GioiTinh,NgaySinh,CCCD,DiaChi,Email,SoDienThoai,MaPB,MaCV,NgayVaoLam,TrangThai,MaSoThue,SoTaiKhoanNH,TenNganHang,NguoiTao)
VALUES('NV000017',N'Hà Thị Nhung','F','1994-01-30','038094017890',N'Q.Thủ Đức, TP.HCM','hthnhung@hrpayroll.vn','0994017890','PB0003','CV0006','2021-03-01','A','0301789012','19001000100017',N'MBBank','HR_ADMIN');
INSERT INTO dbo.NhanVien (MaNV,HoTen,GioiTinh,NgaySinh,CCCD,DiaChi,Email,SoDienThoai,MaPB,MaCV,NgayVaoLam,TrangThai,MaSoThue,SoTaiKhoanNH,TenNganHang,NguoiTao)
VALUES('NV000018',N'Đặng Minh Quân','M','1995-10-05','036095018901',N'Q.7, TP.HCM','dngminhqun@hrpayroll.vn','0995018901','PB0003','CV0006','2022-01-03','A','0301890123','19001000100018',N'Vietcombank','HR_ADMIN');
INSERT INTO dbo.NhanVien (MaNV,HoTen,GioiTinh,NgaySinh,CCCD,DiaChi,Email,SoDienThoai,MaPB,MaCV,NgayVaoLam,TrangThai,MaSoThue,SoTaiKhoanNH,TenNganHang,NguoiTao)
VALUES('NV000019',N'Mai Thị Bích','F','1996-04-12','038096019012',N'Bình Dương','maithbch@hrpayroll.vn','0996019012','PB0003','CV0006','2022-06-01','A','0301901234','19001000100019',N'BIDV','HR_ADMIN');
INSERT INTO dbo.NhanVien (MaNV,HoTen,GioiTinh,NgaySinh,CCCD,DiaChi,Email,SoDienThoai,MaPB,MaCV,NgayVaoLam,TrangThai,MaSoThue,SoTaiKhoanNH,TenNganHang,NguoiTao)
VALUES('NV000020',N'Lưu Văn Sơn','M','2000-08-25','036100020123',N'Đồng Nai','luvnsn@hrpayroll.vn','0900020123','PB0003','CV0007','2024-12-02','P','0302012345','19001000100020',N'Techcombank','HR_ADMIN');
INSERT INTO dbo.NhanVien (MaNV,HoTen,GioiTinh,NgaySinh,CCCD,DiaChi,Email,SoDienThoai,MaPB,MaCV,NgayVaoLam,TrangThai,MaSoThue,SoTaiKhoanNH,TenNganHang,NguoiTao)
VALUES('NV000021',N'Phạm Anh Tuấn','M','1979-06-10','036079021234',N'Q.1, TP.HCM','phmanhtun@hrpayroll.vn','0979021234','PB0004','CV0002','2015-03-01','A','0302123456','19001000100021',N'Vietcombank','HR_ADMIN');
INSERT INTO dbo.NhanVien (MaNV,HoTen,GioiTinh,NgaySinh,CCCD,DiaChi,Email,SoDienThoai,MaPB,MaCV,NgayVaoLam,TrangThai,MaSoThue,SoTaiKhoanNH,TenNganHang,NguoiTao)
VALUES('NV000022',N'Nguyễn Thị Hồng Nhung','F','1983-03-25','038083022345',N'Q.Bình Thạnh, TP.HCM','nguynthhngnhung@hrpayroll.vn','0983022345','PB0004','CV0003','2017-01-09','A','0302234567','19001000100022',N'BIDV','HR_ADMIN');
INSERT INTO dbo.NhanVien (MaNV,HoTen,GioiTinh,NgaySinh,CCCD,DiaChi,Email,SoDienThoai,MaPB,MaCV,NgayVaoLam,TrangThai,MaSoThue,SoTaiKhoanNH,TenNganHang,NguoiTao)
VALUES('NV000023',N'Bùi Văn Long','M','1985-11-15','036085023456',N'Q.Tân Bình, TP.HCM','bivnlong@hrpayroll.vn','0985023456','PB0004','CV0004','2017-07-03','A','0302345678','19001000100023',N'Agribank','HR_ADMIN');
INSERT INTO dbo.NhanVien (MaNV,HoTen,GioiTinh,NgaySinh,CCCD,DiaChi,Email,SoDienThoai,MaPB,MaCV,NgayVaoLam,TrangThai,MaSoThue,SoTaiKhoanNH,TenNganHang,NguoiTao)
VALUES('NV000024',N'Cao Thị Liên','F','1987-07-08','038087024567',N'Q.Phú Nhuận, TP.HCM','caothlin@hrpayroll.vn','0987024567','PB0004','CV0004','2018-02-01','A','0302456789','19001000100024',N'Techcombank','HR_ADMIN');
INSERT INTO dbo.NhanVien (MaNV,HoTen,GioiTinh,NgaySinh,CCCD,DiaChi,Email,SoDienThoai,MaPB,MaCV,NgayVaoLam,TrangThai,MaSoThue,SoTaiKhoanNH,TenNganHang,NguoiTao)
VALUES('NV000025',N'Lê Minh Đạt','M','1986-09-20','036086025678',N'Q.Gò Vấp, TP.HCM','lminhdt@hrpayroll.vn','0986025678','PB0004','CV0004','2018-04-02','A','0302567890','19001000100025',N'Vietinbank','HR_ADMIN');
INSERT INTO dbo.NhanVien (MaNV,HoTen,GioiTinh,NgaySinh,CCCD,DiaChi,Email,SoDienThoai,MaPB,MaCV,NgayVaoLam,TrangThai,MaSoThue,SoTaiKhoanNH,TenNganHang,NguoiTao)
VALUES('NV000026',N'Đào Thị Phúc','F','1990-02-14','038090026789',N'Q.3, TP.HCM','dothphc@hrpayroll.vn','0990026789','PB0004','CV0005','2019-09-02','A','0302678901','19001000100026',N'MBBank','HR_ADMIN');
INSERT INTO dbo.NhanVien (MaNV,HoTen,GioiTinh,NgaySinh,CCCD,DiaChi,Email,SoDienThoai,MaPB,MaCV,NgayVaoLam,TrangThai,MaSoThue,SoTaiKhoanNH,TenNganHang,NguoiTao)
VALUES('NV000027',N'Trần Văn Khoa','M','1991-05-30','036091027890',N'Q.Thủ Đức, TP.HCM','trnvnkhoa@hrpayroll.vn','0991027890','PB0004','CV0005','2020-01-06','A','0302789012','19001000100027',N'Vietcombank','HR_ADMIN');
INSERT INTO dbo.NhanVien (MaNV,HoTen,GioiTinh,NgaySinh,CCCD,DiaChi,Email,SoDienThoai,MaPB,MaCV,NgayVaoLam,TrangThai,MaSoThue,SoTaiKhoanNH,TenNganHang,NguoiTao)
VALUES('NV000028',N'Lương Thị Diễm','F','1992-08-19','038092028901',N'Q.7, TP.HCM','lngthdim@hrpayroll.vn','0992028901','PB0004','CV0005','2020-06-01','A','0302890123','19001000100028',N'BIDV','HR_ADMIN');
INSERT INTO dbo.NhanVien (MaNV,HoTen,GioiTinh,NgaySinh,CCCD,DiaChi,Email,SoDienThoai,MaPB,MaCV,NgayVaoLam,TrangThai,MaSoThue,SoTaiKhoanNH,TenNganHang,NguoiTao)
VALUES('NV000029',N'Phan Đức Hiếu','M','1993-01-25','036093029012',N'Bình Dương','phandchiu@hrpayroll.vn','0993029012','PB0004','CV0005','2021-01-04','A','0302901234','19001000100029',N'Techcombank','HR_ADMIN');
INSERT INTO dbo.NhanVien (MaNV,HoTen,GioiTinh,NgaySinh,CCCD,DiaChi,Email,SoDienThoai,MaPB,MaCV,NgayVaoLam,TrangThai,MaSoThue,SoTaiKhoanNH,TenNganHang,NguoiTao)
VALUES('NV000030',N'Vũ Thị Lan','F','1991-11-02','038091030123',N'Đồng Nai','vthlan@hrpayroll.vn','0991030123','PB0004','CV0005','2021-04-01','A','0303012345','19001000100030',N'Agribank','HR_ADMIN');
INSERT INTO dbo.NhanVien (MaNV,HoTen,GioiTinh,NgaySinh,CCCD,DiaChi,Email,SoDienThoai,MaPB,MaCV,NgayVaoLam,TrangThai,MaSoThue,SoTaiKhoanNH,TenNganHang,NguoiTao)
VALUES('NV000031',N'Dương Văn Nhật','M','1994-04-16','036094031234',N'Q.1, TP.HCM','dngvnnht@hrpayroll.vn','0994031234','PB0004','CV0006','2021-07-01','A','0303123456','19001000100031',N'Vietcombank','HR_ADMIN');
INSERT INTO dbo.NhanVien (MaNV,HoTen,GioiTinh,NgaySinh,CCCD,DiaChi,Email,SoDienThoai,MaPB,MaCV,NgayVaoLam,TrangThai,MaSoThue,SoTaiKhoanNH,TenNganHang,NguoiTao)
VALUES('NV000032',N'Phạm Thị Thu Hà','F','1995-06-07','038095032345',N'Q.Bình Thạnh, TP.HCM','phmththuh@hrpayroll.vn','0995032345','PB0004','CV0006','2022-01-03','A','0303234567','19001000100032',N'BIDV','HR_ADMIN');
INSERT INTO dbo.NhanVien (MaNV,HoTen,GioiTinh,NgaySinh,CCCD,DiaChi,Email,SoDienThoai,MaPB,MaCV,NgayVaoLam,TrangThai,MaSoThue,SoTaiKhoanNH,TenNganHang,NguoiTao)
VALUES('NV000033',N'Hoàng Văn Tùng','M','1993-09-28','036093033456',N'Q.Tân Bình, TP.HCM','hongvntng@hrpayroll.vn','0993033456','PB0004','CV0006','2022-03-01','A','0303345678','19001000100033',N'Vietinbank','HR_ADMIN');
INSERT INTO dbo.NhanVien (MaNV,HoTen,GioiTinh,NgaySinh,CCCD,DiaChi,Email,SoDienThoai,MaPB,MaCV,NgayVaoLam,TrangThai,MaSoThue,SoTaiKhoanNH,TenNganHang,NguoiTao)
VALUES('NV000034',N'Nguyễn Thị Ánh','F','1996-12-03','038096034567',N'Q.Phú Nhuận, TP.HCM','nguynthnh@hrpayroll.vn','0996034567','PB0004','CV0006','2022-08-01','A','0303456789','19001000100034',N'MBBank','HR_ADMIN');
INSERT INTO dbo.NhanVien (MaNV,HoTen,GioiTinh,NgaySinh,CCCD,DiaChi,Email,SoDienThoai,MaPB,MaCV,NgayVaoLam,TrangThai,MaSoThue,SoTaiKhoanNH,TenNganHang,NguoiTao)
VALUES('NV000035',N'Trần Minh Hoàng','M','1994-07-18','036094035678',N'Q.Gò Vấp, TP.HCM','trnminhhong@hrpayroll.vn','0994035678','PB0004','CV0006','2023-01-03','A','0303567890','19001000100035',N'Vietcombank','HR_ADMIN');
INSERT INTO dbo.NhanVien (MaNV,HoTen,GioiTinh,NgaySinh,CCCD,DiaChi,Email,SoDienThoai,MaPB,MaCV,NgayVaoLam,TrangThai,MaSoThue,SoTaiKhoanNH,TenNganHang,NguoiTao)
VALUES('NV000036',N'Lê Thị Vy','F','1997-03-09','038097036789',N'Q.3, TP.HCM','lthvy@hrpayroll.vn','0997036789','PB0004','CV0006','2023-04-03','A','0303678901','19001000100036',N'Techcombank','HR_ADMIN');
INSERT INTO dbo.NhanVien (MaNV,HoTen,GioiTinh,NgaySinh,CCCD,DiaChi,Email,SoDienThoai,MaPB,MaCV,NgayVaoLam,TrangThai,MaSoThue,SoTaiKhoanNH,TenNganHang,NguoiTao)
VALUES('NV000037',N'Đỗ Văn Chiến','M','1995-10-21','036095037890',N'Q.Thủ Đức, TP.HCM','dvnchin@hrpayroll.vn','0995037890','PB0004','CV0006','2023-07-03','A','0303789012','19001000100037',N'BIDV','HR_ADMIN');
INSERT INTO dbo.NhanVien (MaNV,HoTen,GioiTinh,NgaySinh,CCCD,DiaChi,Email,SoDienThoai,MaPB,MaCV,NgayVaoLam,TrangThai,MaSoThue,SoTaiKhoanNH,TenNganHang,NguoiTao)
VALUES('NV000038',N'Kiều Thị Hà','F','2001-05-14','038101038901',N'Q.7, TP.HCM','kiuthh@hrpayroll.vn','0901038901','PB0004','CV0007','2024-10-01','P','0303890123','19001000100038',N'Agribank','HR_ADMIN');
INSERT INTO dbo.NhanVien (MaNV,HoTen,GioiTinh,NgaySinh,CCCD,DiaChi,Email,SoDienThoai,MaPB,MaCV,NgayVaoLam,TrangThai,MaSoThue,SoTaiKhoanNH,TenNganHang,NguoiTao)
VALUES('NV000039',N'Dương Quốc Hùng','M','1977-08-05','036077039012',N'Bình Dương','dngquchng@hrpayroll.vn','0977039012','PB0005','CV0002','2015-05-04','A','0303901234','19001000100039',N'Vietcombank','HR_ADMIN');
INSERT INTO dbo.NhanVien (MaNV,HoTen,GioiTinh,NgaySinh,CCCD,DiaChi,Email,SoDienThoai,MaPB,MaCV,NgayVaoLam,TrangThai,MaSoThue,SoTaiKhoanNH,TenNganHang,NguoiTao)
VALUES('NV000040',N'Võ Thị Quỳnh Anh','F','1984-01-20','038084040123',N'Đồng Nai','vthqunhanh@hrpayroll.vn','0984040123','PB0005','CV0003','2017-10-02','A','0304012345','19001000100040',N'BIDV','HR_ADMIN');
INSERT INTO dbo.NhanVien (MaNV,HoTen,GioiTinh,NgaySinh,CCCD,DiaChi,Email,SoDienThoai,MaPB,MaCV,NgayVaoLam,TrangThai,MaSoThue,SoTaiKhoanNH,TenNganHang,NguoiTao)
VALUES('NV000041',N'Nguyễn Văn Phú','M','1987-04-12','036087041234',N'Q.1, TP.HCM','nguynvnph@hrpayroll.vn','0987041234','PB0005','CV0004','2018-08-01','A','0304123456','19001000100041',N'Techcombank','HR_ADMIN');
INSERT INTO dbo.NhanVien (MaNV,HoTen,GioiTinh,NgaySinh,CCCD,DiaChi,Email,SoDienThoai,MaPB,MaCV,NgayVaoLam,TrangThai,MaSoThue,SoTaiKhoanNH,TenNganHang,NguoiTao)
VALUES('NV000042',N'Huỳnh Thị Kim Chi','F','1988-10-30','038088042345',N'Q.Bình Thạnh, TP.HCM','hunhthkimchi@hrpayroll.vn','0988042345','PB0005','CV0004','2019-02-01','A','0304234567','19001000100042',N'Vietinbank','HR_ADMIN');
INSERT INTO dbo.NhanVien (MaNV,HoTen,GioiTinh,NgaySinh,CCCD,DiaChi,Email,SoDienThoai,MaPB,MaCV,NgayVaoLam,TrangThai,MaSoThue,SoTaiKhoanNH,TenNganHang,NguoiTao)
VALUES('NV000043',N'Bùi Minh Châu','M','1990-06-08','036090043456',N'Q.Tân Bình, TP.HCM','biminhchu@hrpayroll.vn','0990043456','PB0005','CV0005','2019-11-04','A','0304345678','19001000100043',N'MBBank','HR_ADMIN');
INSERT INTO dbo.NhanVien (MaNV,HoTen,GioiTinh,NgaySinh,CCCD,DiaChi,Email,SoDienThoai,MaPB,MaCV,NgayVaoLam,TrangThai,MaSoThue,SoTaiKhoanNH,TenNganHang,NguoiTao)
VALUES('NV000044',N'Trịnh Thị Phương Linh','F','1991-09-15','038091044567',N'Q.Phú Nhuận, TP.HCM','trnhthphnglinh@hrpayroll.vn','0991044567','PB0005','CV0005','2020-04-06','A','0304456789','19001000100044',N'Vietcombank','HR_ADMIN');
INSERT INTO dbo.NhanVien (MaNV,HoTen,GioiTinh,NgaySinh,CCCD,DiaChi,Email,SoDienThoai,MaPB,MaCV,NgayVaoLam,TrangThai,MaSoThue,SoTaiKhoanNH,TenNganHang,NguoiTao)
VALUES('NV000045',N'Nguyễn Hoàng Nam','M','1992-02-28','036092045678',N'Q.Gò Vấp, TP.HCM','nguynhongnam@hrpayroll.vn','0992045678','PB0005','CV0005','2021-06-01','A','0304567890','19001000100045',N'BIDV','HR_ADMIN');
INSERT INTO dbo.NhanVien (MaNV,HoTen,GioiTinh,NgaySinh,CCCD,DiaChi,Email,SoDienThoai,MaPB,MaCV,NgayVaoLam,TrangThai,MaSoThue,SoTaiKhoanNH,TenNganHang,NguoiTao)
VALUES('NV000046',N'Đặng Thị Hoa','F','1994-11-17','038094046789',N'Q.3, TP.HCM','dngthhoa@hrpayroll.vn','0994046789','PB0005','CV0006','2021-10-04','A','0304678901','19001000100046',N'Techcombank','HR_ADMIN');
INSERT INTO dbo.NhanVien (MaNV,HoTen,GioiTinh,NgaySinh,CCCD,DiaChi,Email,SoDienThoai,MaPB,MaCV,NgayVaoLam,TrangThai,MaSoThue,SoTaiKhoanNH,TenNganHang,NguoiTao)
VALUES('NV000047',N'Phạm Văn Thành','M','1995-08-04','036095047890',N'Q.Thủ Đức, TP.HCM','phmvnthnh@hrpayroll.vn','0995047890','PB0005','CV0006','2022-04-04','A','0304789012','19001000100047',N'Vietinbank','HR_ADMIN');
INSERT INTO dbo.NhanVien (MaNV,HoTen,GioiTinh,NgaySinh,CCCD,DiaChi,Email,SoDienThoai,MaPB,MaCV,NgayVaoLam,TrangThai,MaSoThue,SoTaiKhoanNH,TenNganHang,NguoiTao)
VALUES('NV000048',N'Lý Thị Ái','F','1996-05-22','038096048901',N'Q.7, TP.HCM','lthi@hrpayroll.vn','0996048901','PB0005','CV0006','2022-09-01','A','0304890123','19001000100048',N'Agribank','HR_ADMIN');
INSERT INTO dbo.NhanVien (MaNV,HoTen,GioiTinh,NgaySinh,CCCD,DiaChi,Email,SoDienThoai,MaPB,MaCV,NgayVaoLam,TrangThai,MaSoThue,SoTaiKhoanNH,TenNganHang,NguoiTao)
VALUES('NV000049',N'Mai Văn Khánh','M','1997-01-09','036097049012',N'Bình Dương','maivnkhnh@hrpayroll.vn','0997049012','PB0005','CV0006','2023-03-01','A','0304901234','19001000100049',N'Vietcombank','HR_ADMIN');
INSERT INTO dbo.NhanVien (MaNV,HoTen,GioiTinh,NgaySinh,CCCD,DiaChi,Email,SoDienThoai,MaPB,MaCV,NgayVaoLam,TrangThai,MaSoThue,SoTaiKhoanNH,TenNganHang,NguoiTao)
VALUES('NV000050',N'Ngô Thị Minh Nguyệt','F','2000-07-31','038100050123',N'Đồng Nai','ngthminhnguyt@hrpayroll.vn','0900050123','PB0005','CV0007','2024-11-04','P','0305012345','19001000100050',N'BIDV','HR_ADMIN');
COMMIT TRANSACTION;
PRINT N'[OK] §2 NhanVien — 50 nhân viên';
GO

-- ============================================================
-- §3  HOPDONG — 50 hợp đồng lao động
-- ============================================================
BEGIN TRANSACTION;
INSERT INTO dbo.HopDong(MaHD,MaNV,MaLoaiHD,NgayBatDau,NgayKetThuc,LuongCoBan,VungLuong,TrangThai,NguoiKy_NLD,NguoiKy_NSDLD,NgayKy,NguoiTao)
VALUES('HD000001','NV000001',4,'2015-01-05',NULL,55000000,1,'A',N'Nguyễn Hoàng Minh',N'Nguyễn Hoàng Minh','2015-01-05','HR_ADMIN');
INSERT INTO dbo.HopDong(MaHD,MaNV,MaLoaiHD,NgayBatDau,NgayKetThuc,LuongCoBan,VungLuong,TrangThai,NguoiKy_NLD,NguoiKy_NSDLD,NgayKy,NguoiTao)
VALUES('HD000002','NV000002',2,'2019-03-01',DATEADD(MONTH,12,'2019-03-01'),8500000,1,'A',N'Trần Thị Lan Anh',N'Nguyễn Hoàng Minh','2019-03-01','HR_ADMIN');
INSERT INTO dbo.HopDong(MaHD,MaNV,MaLoaiHD,NgayBatDau,NgayKetThuc,LuongCoBan,VungLuong,TrangThai,NguoiKy_NLD,NguoiKy_NSDLD,NgayKy,NguoiTao)
VALUES('HD000003','NV000003',3,'2016-02-15',DATEADD(MONTH,24,'2016-02-15'),26000000,1,'A',N'Lê Văn Đức',N'Nguyễn Hoàng Minh','2016-02-15','HR_ADMIN');
INSERT INTO dbo.HopDong(MaHD,MaNV,MaLoaiHD,NgayBatDau,NgayKetThuc,LuongCoBan,VungLuong,TrangThai,NguoiKy_NLD,NguoiKy_NSDLD,NgayKy,NguoiTao)
VALUES('HD000004','NV000004',2,'2018-06-01',DATEADD(MONTH,12,'2018-06-01'),11500000,1,'A',N'Phạm Thị Hương',N'Nguyễn Hoàng Minh','2018-06-01','HR_ADMIN');
INSERT INTO dbo.HopDong(MaHD,MaNV,MaLoaiHD,NgayBatDau,NgayKetThuc,LuongCoBan,VungLuong,TrangThai,NguoiKy_NLD,NguoiKy_NSDLD,NgayKy,NguoiTao)
VALUES('HD000005','NV000005',2,'2019-01-10',DATEADD(MONTH,12,'2019-01-10'),11500000,1,'A',N'Võ Minh Tuấn',N'Nguyễn Hoàng Minh','2019-01-10','HR_ADMIN');
INSERT INTO dbo.HopDong(MaHD,MaNV,MaLoaiHD,NgayBatDau,NgayKetThuc,LuongCoBan,VungLuong,TrangThai,NguoiKy_NLD,NguoiKy_NSDLD,NgayKy,NguoiTao)
VALUES('HD000006','NV000006',2,'2020-03-02',DATEADD(MONTH,12,'2020-03-02'),8500000,1,'A',N'Nguyễn Thị Thu Hà',N'Nguyễn Hoàng Minh','2020-03-02','HR_ADMIN');
INSERT INTO dbo.HopDong(MaHD,MaNV,MaLoaiHD,NgayBatDau,NgayKetThuc,LuongCoBan,VungLuong,TrangThai,NguoiKy_NLD,NguoiKy_NSDLD,NgayKy,NguoiTao)
VALUES('HD000007','NV000007',2,'2020-07-01',DATEADD(MONTH,12,'2020-07-01'),8500000,1,'A',N'Đinh Văn Hùng',N'Nguyễn Hoàng Minh','2020-07-01','HR_ADMIN');
INSERT INTO dbo.HopDong(MaHD,MaNV,MaLoaiHD,NgayBatDau,NgayKetThuc,LuongCoBan,VungLuong,TrangThai,NguoiKy_NLD,NguoiKy_NSDLD,NgayKy,NguoiTao)
VALUES('HD000008','NV000008',2,'2021-01-04',DATEADD(MONTH,12,'2021-01-04'),8500000,1,'A',N'Trương Thị Ngọc',N'Nguyễn Hoàng Minh','2021-01-04','HR_ADMIN');
INSERT INTO dbo.HopDong(MaHD,MaNV,MaLoaiHD,NgayBatDau,NgayKetThuc,LuongCoBan,VungLuong,TrangThai,NguoiKy_NLD,NguoiKy_NSDLD,NgayKy,NguoiTao)
VALUES('HD000009','NV000009',2,'2018-11-01',DATEADD(MONTH,12,'2018-11-01'),11500000,1,'A',N'Bùi Quang Khải',N'Nguyễn Hoàng Minh','2018-11-01','HR_ADMIN');
INSERT INTO dbo.HopDong(MaHD,MaNV,MaLoaiHD,NgayBatDau,NgayKetThuc,LuongCoBan,VungLuong,TrangThai,NguoiKy_NLD,NguoiKy_NSDLD,NgayKy,NguoiTao)
VALUES('HD000010','NV000010',1,'2024-11-01',DATEADD(MONTH,2,'2024-11-01'),6500000,1,'A',N'Đỗ Thị Mai Linh',N'Nguyễn Hoàng Minh','2024-11-01','HR_ADMIN');
INSERT INTO dbo.HopDong(MaHD,MaNV,MaLoaiHD,NgayBatDau,NgayKetThuc,LuongCoBan,VungLuong,TrangThai,NguoiKy_NLD,NguoiKy_NSDLD,NgayKy,NguoiTao)
VALUES('HD000011','NV000011',3,'2015-07-01',DATEADD(MONTH,24,'2015-07-01'),25000000,1,'A',N'Hoàng Thị Phương',N'Nguyễn Hoàng Minh','2015-07-01','HR_ADMIN');
INSERT INTO dbo.HopDong(MaHD,MaNV,MaLoaiHD,NgayBatDau,NgayKetThuc,LuongCoBan,VungLuong,TrangThai,NguoiKy_NLD,NguoiKy_NSDLD,NgayKy,NguoiTao)
VALUES('HD000012','NV000012',3,'2016-09-01',DATEADD(MONTH,24,'2016-09-01'),20000000,1,'A',N'Phan Văn Thắng',N'Nguyễn Hoàng Minh','2016-09-01','HR_ADMIN');
INSERT INTO dbo.HopDong(MaHD,MaNV,MaLoaiHD,NgayBatDau,NgayKetThuc,LuongCoBan,VungLuong,TrangThai,NguoiKy_NLD,NguoiKy_NSDLD,NgayKy,NguoiTao)
VALUES('HD000013','NV000013',3,'2017-04-03',DATEADD(MONTH,24,'2017-04-03'),15000000,1,'A',N'Lý Thị Kim Oanh',N'Nguyễn Hoàng Minh','2017-04-03','HR_ADMIN');
INSERT INTO dbo.HopDong(MaHD,MaNV,MaLoaiHD,NgayBatDau,NgayKetThuc,LuongCoBan,VungLuong,TrangThai,NguoiKy_NLD,NguoiKy_NSDLD,NgayKy,NguoiTao)
VALUES('HD000014','NV000014',2,'2019-05-01',DATEADD(MONTH,12,'2019-05-01'),11500000,1,'A',N'Ngô Đức Toàn',N'Nguyễn Hoàng Minh','2019-05-01','HR_ADMIN');
INSERT INTO dbo.HopDong(MaHD,MaNV,MaLoaiHD,NgayBatDau,NgayKetThuc,LuongCoBan,VungLuong,TrangThai,NguoiKy_NLD,NguoiKy_NSDLD,NgayKy,NguoiTao)
VALUES('HD000015','NV000015',2,'2019-08-01',DATEADD(MONTH,12,'2019-08-01'),11500000,1,'A',N'Vũ Thị Thanh Xuân',N'Nguyễn Hoàng Minh','2019-08-01','HR_ADMIN');
INSERT INTO dbo.HopDong(MaHD,MaNV,MaLoaiHD,NgayBatDau,NgayKetThuc,LuongCoBan,VungLuong,TrangThai,NguoiKy_NLD,NguoiKy_NSDLD,NgayKy,NguoiTao)
VALUES('HD000016','NV000016',2,'2020-10-01',DATEADD(MONTH,12,'2020-10-01'),8500000,1,'A',N'Trịnh Văn Dũng',N'Nguyễn Hoàng Minh','2020-10-01','HR_ADMIN');
INSERT INTO dbo.HopDong(MaHD,MaNV,MaLoaiHD,NgayBatDau,NgayKetThuc,LuongCoBan,VungLuong,TrangThai,NguoiKy_NLD,NguoiKy_NSDLD,NgayKy,NguoiTao)
VALUES('HD000017','NV000017',2,'2021-03-01',DATEADD(MONTH,12,'2021-03-01'),8500000,1,'A',N'Hà Thị Nhung',N'Nguyễn Hoàng Minh','2021-03-01','HR_ADMIN');
INSERT INTO dbo.HopDong(MaHD,MaNV,MaLoaiHD,NgayBatDau,NgayKetThuc,LuongCoBan,VungLuong,TrangThai,NguoiKy_NLD,NguoiKy_NSDLD,NgayKy,NguoiTao)
VALUES('HD000018','NV000018',2,'2022-01-03',DATEADD(MONTH,12,'2022-01-03'),8500000,1,'A',N'Đặng Minh Quân',N'Nguyễn Hoàng Minh','2022-01-03','HR_ADMIN');
INSERT INTO dbo.HopDong(MaHD,MaNV,MaLoaiHD,NgayBatDau,NgayKetThuc,LuongCoBan,VungLuong,TrangThai,NguoiKy_NLD,NguoiKy_NSDLD,NgayKy,NguoiTao)
VALUES('HD000019','NV000019',2,'2022-06-01',DATEADD(MONTH,12,'2022-06-01'),8500000,1,'A',N'Mai Thị Bích',N'Nguyễn Hoàng Minh','2022-06-01','HR_ADMIN');
INSERT INTO dbo.HopDong(MaHD,MaNV,MaLoaiHD,NgayBatDau,NgayKetThuc,LuongCoBan,VungLuong,TrangThai,NguoiKy_NLD,NguoiKy_NSDLD,NgayKy,NguoiTao)
VALUES('HD000020','NV000020',1,'2024-12-02',DATEADD(MONTH,2,'2024-12-02'),6500000,1,'A',N'Lưu Văn Sơn',N'Nguyễn Hoàng Minh','2024-12-02','HR_ADMIN');
INSERT INTO dbo.HopDong(MaHD,MaNV,MaLoaiHD,NgayBatDau,NgayKetThuc,LuongCoBan,VungLuong,TrangThai,NguoiKy_NLD,NguoiKy_NSDLD,NgayKy,NguoiTao)
VALUES('HD000021','NV000021',3,'2015-03-01',DATEADD(MONTH,24,'2015-03-01'),28000000,1,'A',N'Phạm Anh Tuấn',N'Nguyễn Hoàng Minh','2015-03-01','HR_ADMIN');
INSERT INTO dbo.HopDong(MaHD,MaNV,MaLoaiHD,NgayBatDau,NgayKetThuc,LuongCoBan,VungLuong,TrangThai,NguoiKy_NLD,NguoiKy_NSDLD,NgayKy,NguoiTao)
VALUES('HD000022','NV000022',3,'2017-01-09',DATEADD(MONTH,24,'2017-01-09'),21000000,1,'A',N'Nguyễn Thị Hồng Nhung',N'Nguyễn Hoàng Minh','2017-01-09','HR_ADMIN');
INSERT INTO dbo.HopDong(MaHD,MaNV,MaLoaiHD,NgayBatDau,NgayKetThuc,LuongCoBan,VungLuong,TrangThai,NguoiKy_NLD,NguoiKy_NSDLD,NgayKy,NguoiTao)
VALUES('HD000023','NV000023',3,'2017-07-03',DATEADD(MONTH,24,'2017-07-03'),16000000,1,'A',N'Bùi Văn Long',N'Nguyễn Hoàng Minh','2017-07-03','HR_ADMIN');
INSERT INTO dbo.HopDong(MaHD,MaNV,MaLoaiHD,NgayBatDau,NgayKetThuc,LuongCoBan,VungLuong,TrangThai,NguoiKy_NLD,NguoiKy_NSDLD,NgayKy,NguoiTao)
VALUES('HD000024','NV000024',3,'2018-02-01',DATEADD(MONTH,24,'2018-02-01'),15500000,1,'A',N'Cao Thị Liên',N'Nguyễn Hoàng Minh','2018-02-01','HR_ADMIN');
INSERT INTO dbo.HopDong(MaHD,MaNV,MaLoaiHD,NgayBatDau,NgayKetThuc,LuongCoBan,VungLuong,TrangThai,NguoiKy_NLD,NguoiKy_NSDLD,NgayKy,NguoiTao)
VALUES('HD000025','NV000025',3,'2018-04-02',DATEADD(MONTH,24,'2018-04-02'),15000000,1,'A',N'Lê Minh Đạt',N'Nguyễn Hoàng Minh','2018-04-02','HR_ADMIN');
INSERT INTO dbo.HopDong(MaHD,MaNV,MaLoaiHD,NgayBatDau,NgayKetThuc,LuongCoBan,VungLuong,TrangThai,NguoiKy_NLD,NguoiKy_NSDLD,NgayKy,NguoiTao)
VALUES('HD000026','NV000026',2,'2019-09-02',DATEADD(MONTH,12,'2019-09-02'),11500000,1,'A',N'Đào Thị Phúc',N'Nguyễn Hoàng Minh','2019-09-02','HR_ADMIN');
INSERT INTO dbo.HopDong(MaHD,MaNV,MaLoaiHD,NgayBatDau,NgayKetThuc,LuongCoBan,VungLuong,TrangThai,NguoiKy_NLD,NguoiKy_NSDLD,NgayKy,NguoiTao)
VALUES('HD000027','NV000027',2,'2020-01-06',DATEADD(MONTH,12,'2020-01-06'),11500000,1,'A',N'Trần Văn Khoa',N'Nguyễn Hoàng Minh','2020-01-06','HR_ADMIN');
INSERT INTO dbo.HopDong(MaHD,MaNV,MaLoaiHD,NgayBatDau,NgayKetThuc,LuongCoBan,VungLuong,TrangThai,NguoiKy_NLD,NguoiKy_NSDLD,NgayKy,NguoiTao)
VALUES('HD000028','NV000028',2,'2020-06-01',DATEADD(MONTH,12,'2020-06-01'),11500000,1,'A',N'Lương Thị Diễm',N'Nguyễn Hoàng Minh','2020-06-01','HR_ADMIN');
INSERT INTO dbo.HopDong(MaHD,MaNV,MaLoaiHD,NgayBatDau,NgayKetThuc,LuongCoBan,VungLuong,TrangThai,NguoiKy_NLD,NguoiKy_NSDLD,NgayKy,NguoiTao)
VALUES('HD000029','NV000029',2,'2021-01-04',DATEADD(MONTH,12,'2021-01-04'),11500000,1,'A',N'Phan Đức Hiếu',N'Nguyễn Hoàng Minh','2021-01-04','HR_ADMIN');
INSERT INTO dbo.HopDong(MaHD,MaNV,MaLoaiHD,NgayBatDau,NgayKetThuc,LuongCoBan,VungLuong,TrangThai,NguoiKy_NLD,NguoiKy_NSDLD,NgayKy,NguoiTao)
VALUES('HD000030','NV000030',2,'2021-04-01',DATEADD(MONTH,12,'2021-04-01'),11500000,1,'A',N'Vũ Thị Lan',N'Nguyễn Hoàng Minh','2021-04-01','HR_ADMIN');
INSERT INTO dbo.HopDong(MaHD,MaNV,MaLoaiHD,NgayBatDau,NgayKetThuc,LuongCoBan,VungLuong,TrangThai,NguoiKy_NLD,NguoiKy_NSDLD,NgayKy,NguoiTao)
VALUES('HD000031','NV000031',2,'2021-07-01',DATEADD(MONTH,12,'2021-07-01'),8500000,1,'A',N'Dương Văn Nhật',N'Nguyễn Hoàng Minh','2021-07-01','HR_ADMIN');
INSERT INTO dbo.HopDong(MaHD,MaNV,MaLoaiHD,NgayBatDau,NgayKetThuc,LuongCoBan,VungLuong,TrangThai,NguoiKy_NLD,NguoiKy_NSDLD,NgayKy,NguoiTao)
VALUES('HD000032','NV000032',2,'2022-01-03',DATEADD(MONTH,12,'2022-01-03'),8500000,1,'A',N'Phạm Thị Thu Hà',N'Nguyễn Hoàng Minh','2022-01-03','HR_ADMIN');
INSERT INTO dbo.HopDong(MaHD,MaNV,MaLoaiHD,NgayBatDau,NgayKetThuc,LuongCoBan,VungLuong,TrangThai,NguoiKy_NLD,NguoiKy_NSDLD,NgayKy,NguoiTao)
VALUES('HD000033','NV000033',2,'2022-03-01',DATEADD(MONTH,12,'2022-03-01'),8500000,1,'A',N'Hoàng Văn Tùng',N'Nguyễn Hoàng Minh','2022-03-01','HR_ADMIN');
INSERT INTO dbo.HopDong(MaHD,MaNV,MaLoaiHD,NgayBatDau,NgayKetThuc,LuongCoBan,VungLuong,TrangThai,NguoiKy_NLD,NguoiKy_NSDLD,NgayKy,NguoiTao)
VALUES('HD000034','NV000034',2,'2022-08-01',DATEADD(MONTH,12,'2022-08-01'),8500000,1,'A',N'Nguyễn Thị Ánh',N'Nguyễn Hoàng Minh','2022-08-01','HR_ADMIN');
INSERT INTO dbo.HopDong(MaHD,MaNV,MaLoaiHD,NgayBatDau,NgayKetThuc,LuongCoBan,VungLuong,TrangThai,NguoiKy_NLD,NguoiKy_NSDLD,NgayKy,NguoiTao)
VALUES('HD000035','NV000035',2,'2023-01-03',DATEADD(MONTH,12,'2023-01-03'),8500000,1,'A',N'Trần Minh Hoàng',N'Nguyễn Hoàng Minh','2023-01-03','HR_ADMIN');
INSERT INTO dbo.HopDong(MaHD,MaNV,MaLoaiHD,NgayBatDau,NgayKetThuc,LuongCoBan,VungLuong,TrangThai,NguoiKy_NLD,NguoiKy_NSDLD,NgayKy,NguoiTao)
VALUES('HD000036','NV000036',2,'2023-04-03',DATEADD(MONTH,12,'2023-04-03'),8500000,1,'A',N'Lê Thị Vy',N'Nguyễn Hoàng Minh','2023-04-03','HR_ADMIN');
INSERT INTO dbo.HopDong(MaHD,MaNV,MaLoaiHD,NgayBatDau,NgayKetThuc,LuongCoBan,VungLuong,TrangThai,NguoiKy_NLD,NguoiKy_NSDLD,NgayKy,NguoiTao)
VALUES('HD000037','NV000037',2,'2023-07-03',DATEADD(MONTH,12,'2023-07-03'),8500000,1,'A',N'Đỗ Văn Chiến',N'Nguyễn Hoàng Minh','2023-07-03','HR_ADMIN');
INSERT INTO dbo.HopDong(MaHD,MaNV,MaLoaiHD,NgayBatDau,NgayKetThuc,LuongCoBan,VungLuong,TrangThai,NguoiKy_NLD,NguoiKy_NSDLD,NgayKy,NguoiTao)
VALUES('HD000038','NV000038',1,'2024-10-01',DATEADD(MONTH,2,'2024-10-01'),6500000,1,'A',N'Kiều Thị Hà',N'Nguyễn Hoàng Minh','2024-10-01','HR_ADMIN');
INSERT INTO dbo.HopDong(MaHD,MaNV,MaLoaiHD,NgayBatDau,NgayKetThuc,LuongCoBan,VungLuong,TrangThai,NguoiKy_NLD,NguoiKy_NSDLD,NgayKy,NguoiTao)
VALUES('HD000039','NV000039',3,'2015-05-04',DATEADD(MONTH,24,'2015-05-04'),27000000,1,'A',N'Dương Quốc Hùng',N'Nguyễn Hoàng Minh','2015-05-04','HR_ADMIN');
INSERT INTO dbo.HopDong(MaHD,MaNV,MaLoaiHD,NgayBatDau,NgayKetThuc,LuongCoBan,VungLuong,TrangThai,NguoiKy_NLD,NguoiKy_NSDLD,NgayKy,NguoiTao)
VALUES('HD000040','NV000040',3,'2017-10-02',DATEADD(MONTH,24,'2017-10-02'),20000000,1,'A',N'Võ Thị Quỳnh Anh',N'Nguyễn Hoàng Minh','2017-10-02','HR_ADMIN');
INSERT INTO dbo.HopDong(MaHD,MaNV,MaLoaiHD,NgayBatDau,NgayKetThuc,LuongCoBan,VungLuong,TrangThai,NguoiKy_NLD,NguoiKy_NSDLD,NgayKy,NguoiTao)
VALUES('HD000041','NV000041',3,'2018-08-01',DATEADD(MONTH,24,'2018-08-01'),16500000,1,'A',N'Nguyễn Văn Phú',N'Nguyễn Hoàng Minh','2018-08-01','HR_ADMIN');
INSERT INTO dbo.HopDong(MaHD,MaNV,MaLoaiHD,NgayBatDau,NgayKetThuc,LuongCoBan,VungLuong,TrangThai,NguoiKy_NLD,NguoiKy_NSDLD,NgayKy,NguoiTao)
VALUES('HD000042','NV000042',3,'2019-02-01',DATEADD(MONTH,24,'2019-02-01'),15000000,1,'A',N'Huỳnh Thị Kim Chi',N'Nguyễn Hoàng Minh','2019-02-01','HR_ADMIN');
INSERT INTO dbo.HopDong(MaHD,MaNV,MaLoaiHD,NgayBatDau,NgayKetThuc,LuongCoBan,VungLuong,TrangThai,NguoiKy_NLD,NguoiKy_NSDLD,NgayKy,NguoiTao)
VALUES('HD000043','NV000043',2,'2019-11-04',DATEADD(MONTH,12,'2019-11-04'),11500000,1,'A',N'Bùi Minh Châu',N'Nguyễn Hoàng Minh','2019-11-04','HR_ADMIN');
INSERT INTO dbo.HopDong(MaHD,MaNV,MaLoaiHD,NgayBatDau,NgayKetThuc,LuongCoBan,VungLuong,TrangThai,NguoiKy_NLD,NguoiKy_NSDLD,NgayKy,NguoiTao)
VALUES('HD000044','NV000044',2,'2020-04-06',DATEADD(MONTH,12,'2020-04-06'),11500000,1,'A',N'Trịnh Thị Phương Linh',N'Nguyễn Hoàng Minh','2020-04-06','HR_ADMIN');
INSERT INTO dbo.HopDong(MaHD,MaNV,MaLoaiHD,NgayBatDau,NgayKetThuc,LuongCoBan,VungLuong,TrangThai,NguoiKy_NLD,NguoiKy_NSDLD,NgayKy,NguoiTao)
VALUES('HD000045','NV000045',2,'2021-06-01',DATEADD(MONTH,12,'2021-06-01'),11500000,1,'A',N'Nguyễn Hoàng Nam',N'Nguyễn Hoàng Minh','2021-06-01','HR_ADMIN');
INSERT INTO dbo.HopDong(MaHD,MaNV,MaLoaiHD,NgayBatDau,NgayKetThuc,LuongCoBan,VungLuong,TrangThai,NguoiKy_NLD,NguoiKy_NSDLD,NgayKy,NguoiTao)
VALUES('HD000046','NV000046',2,'2021-10-04',DATEADD(MONTH,12,'2021-10-04'),8500000,1,'A',N'Đặng Thị Hoa',N'Nguyễn Hoàng Minh','2021-10-04','HR_ADMIN');
INSERT INTO dbo.HopDong(MaHD,MaNV,MaLoaiHD,NgayBatDau,NgayKetThuc,LuongCoBan,VungLuong,TrangThai,NguoiKy_NLD,NguoiKy_NSDLD,NgayKy,NguoiTao)
VALUES('HD000047','NV000047',2,'2022-04-04',DATEADD(MONTH,12,'2022-04-04'),8500000,1,'A',N'Phạm Văn Thành',N'Nguyễn Hoàng Minh','2022-04-04','HR_ADMIN');
INSERT INTO dbo.HopDong(MaHD,MaNV,MaLoaiHD,NgayBatDau,NgayKetThuc,LuongCoBan,VungLuong,TrangThai,NguoiKy_NLD,NguoiKy_NSDLD,NgayKy,NguoiTao)
VALUES('HD000048','NV000048',2,'2022-09-01',DATEADD(MONTH,12,'2022-09-01'),8500000,1,'A',N'Lý Thị Ái',N'Nguyễn Hoàng Minh','2022-09-01','HR_ADMIN');
INSERT INTO dbo.HopDong(MaHD,MaNV,MaLoaiHD,NgayBatDau,NgayKetThuc,LuongCoBan,VungLuong,TrangThai,NguoiKy_NLD,NguoiKy_NSDLD,NgayKy,NguoiTao)
VALUES('HD000049','NV000049',2,'2023-03-01',DATEADD(MONTH,12,'2023-03-01'),8500000,1,'A',N'Mai Văn Khánh',N'Nguyễn Hoàng Minh','2023-03-01','HR_ADMIN');
INSERT INTO dbo.HopDong(MaHD,MaNV,MaLoaiHD,NgayBatDau,NgayKetThuc,LuongCoBan,VungLuong,TrangThai,NguoiKy_NLD,NguoiKy_NSDLD,NgayKy,NguoiTao)
VALUES('HD000050','NV000050',1,'2024-11-04',DATEADD(MONTH,2,'2024-11-04'),6500000,1,'A',N'Ngô Thị Minh Nguyệt',N'Nguyễn Hoàng Minh','2024-11-04','HR_ADMIN');
COMMIT TRANSACTION;
PRINT N'[OK] §3 HopDong — 50 hợp đồng';
GO

-- ============================================================
-- §4  LUONGCOBAN — mức lương hiệu lực hiện tại
-- ============================================================
BEGIN TRANSACTION;
INSERT INTO dbo.LuongCoBan(MaNV,LuongCB,LuongDongBH,NgayHieuLuc,NgayHetHieuLuc,LyDo,NguoiDuyet)
VALUES('NV000001',55000000,46800000,'2015-01-05',NULL,N'Mức lương khởi điểm','HR_ADMIN');
INSERT INTO dbo.LuongCoBan(MaNV,LuongCB,LuongDongBH,NgayHieuLuc,NgayHetHieuLuc,LyDo,NguoiDuyet)
VALUES('NV000002',8500000,8500000,'2019-03-01',NULL,N'Mức lương khởi điểm','HR_ADMIN');
INSERT INTO dbo.LuongCoBan(MaNV,LuongCB,LuongDongBH,NgayHieuLuc,NgayHetHieuLuc,LyDo,NguoiDuyet)
VALUES('NV000003',26000000,26000000,'2016-02-15',NULL,N'Mức lương khởi điểm','HR_ADMIN');
INSERT INTO dbo.LuongCoBan(MaNV,LuongCB,LuongDongBH,NgayHieuLuc,NgayHetHieuLuc,LyDo,NguoiDuyet)
VALUES('NV000004',11500000,11500000,'2018-06-01',NULL,N'Mức lương khởi điểm','HR_ADMIN');
INSERT INTO dbo.LuongCoBan(MaNV,LuongCB,LuongDongBH,NgayHieuLuc,NgayHetHieuLuc,LyDo,NguoiDuyet)
VALUES('NV000005',11500000,11500000,'2019-01-10',NULL,N'Mức lương khởi điểm','HR_ADMIN');
INSERT INTO dbo.LuongCoBan(MaNV,LuongCB,LuongDongBH,NgayHieuLuc,NgayHetHieuLuc,LyDo,NguoiDuyet)
VALUES('NV000006',8500000,8500000,'2020-03-02',NULL,N'Mức lương khởi điểm','HR_ADMIN');
INSERT INTO dbo.LuongCoBan(MaNV,LuongCB,LuongDongBH,NgayHieuLuc,NgayHetHieuLuc,LyDo,NguoiDuyet)
VALUES('NV000007',8500000,8500000,'2020-07-01',NULL,N'Mức lương khởi điểm','HR_ADMIN');
INSERT INTO dbo.LuongCoBan(MaNV,LuongCB,LuongDongBH,NgayHieuLuc,NgayHetHieuLuc,LyDo,NguoiDuyet)
VALUES('NV000008',8500000,8500000,'2021-01-04',NULL,N'Mức lương khởi điểm','HR_ADMIN');
INSERT INTO dbo.LuongCoBan(MaNV,LuongCB,LuongDongBH,NgayHieuLuc,NgayHetHieuLuc,LyDo,NguoiDuyet)
VALUES('NV000009',11500000,11500000,'2018-11-01',NULL,N'Mức lương khởi điểm','HR_ADMIN');
INSERT INTO dbo.LuongCoBan(MaNV,LuongCB,LuongDongBH,NgayHieuLuc,NgayHetHieuLuc,LyDo,NguoiDuyet)
VALUES('NV000010',6500000,6500000,'2024-11-01',NULL,N'Mức lương khởi điểm','HR_ADMIN');
INSERT INTO dbo.LuongCoBan(MaNV,LuongCB,LuongDongBH,NgayHieuLuc,NgayHetHieuLuc,LyDo,NguoiDuyet)
VALUES('NV000011',25000000,25000000,'2015-07-01',NULL,N'Mức lương khởi điểm','HR_ADMIN');
INSERT INTO dbo.LuongCoBan(MaNV,LuongCB,LuongDongBH,NgayHieuLuc,NgayHetHieuLuc,LyDo,NguoiDuyet)
VALUES('NV000012',20000000,20000000,'2016-09-01',NULL,N'Mức lương khởi điểm','HR_ADMIN');
INSERT INTO dbo.LuongCoBan(MaNV,LuongCB,LuongDongBH,NgayHieuLuc,NgayHetHieuLuc,LyDo,NguoiDuyet)
VALUES('NV000013',15000000,15000000,'2017-04-03',NULL,N'Mức lương khởi điểm','HR_ADMIN');
INSERT INTO dbo.LuongCoBan(MaNV,LuongCB,LuongDongBH,NgayHieuLuc,NgayHetHieuLuc,LyDo,NguoiDuyet)
VALUES('NV000014',11500000,11500000,'2019-05-01',NULL,N'Mức lương khởi điểm','HR_ADMIN');
INSERT INTO dbo.LuongCoBan(MaNV,LuongCB,LuongDongBH,NgayHieuLuc,NgayHetHieuLuc,LyDo,NguoiDuyet)
VALUES('NV000015',11500000,11500000,'2019-08-01',NULL,N'Mức lương khởi điểm','HR_ADMIN');
INSERT INTO dbo.LuongCoBan(MaNV,LuongCB,LuongDongBH,NgayHieuLuc,NgayHetHieuLuc,LyDo,NguoiDuyet)
VALUES('NV000016',8500000,8500000,'2020-10-01',NULL,N'Mức lương khởi điểm','HR_ADMIN');
INSERT INTO dbo.LuongCoBan(MaNV,LuongCB,LuongDongBH,NgayHieuLuc,NgayHetHieuLuc,LyDo,NguoiDuyet)
VALUES('NV000017',8500000,8500000,'2021-03-01',NULL,N'Mức lương khởi điểm','HR_ADMIN');
INSERT INTO dbo.LuongCoBan(MaNV,LuongCB,LuongDongBH,NgayHieuLuc,NgayHetHieuLuc,LyDo,NguoiDuyet)
VALUES('NV000018',8500000,8500000,'2022-01-03',NULL,N'Mức lương khởi điểm','HR_ADMIN');
INSERT INTO dbo.LuongCoBan(MaNV,LuongCB,LuongDongBH,NgayHieuLuc,NgayHetHieuLuc,LyDo,NguoiDuyet)
VALUES('NV000019',8500000,8500000,'2022-06-01',NULL,N'Mức lương khởi điểm','HR_ADMIN');
INSERT INTO dbo.LuongCoBan(MaNV,LuongCB,LuongDongBH,NgayHieuLuc,NgayHetHieuLuc,LyDo,NguoiDuyet)
VALUES('NV000020',6500000,6500000,'2024-12-02',NULL,N'Mức lương khởi điểm','HR_ADMIN');
INSERT INTO dbo.LuongCoBan(MaNV,LuongCB,LuongDongBH,NgayHieuLuc,NgayHetHieuLuc,LyDo,NguoiDuyet)
VALUES('NV000021',28000000,28000000,'2015-03-01',NULL,N'Mức lương khởi điểm','HR_ADMIN');
INSERT INTO dbo.LuongCoBan(MaNV,LuongCB,LuongDongBH,NgayHieuLuc,NgayHetHieuLuc,LyDo,NguoiDuyet)
VALUES('NV000022',21000000,21000000,'2017-01-09',NULL,N'Mức lương khởi điểm','HR_ADMIN');
INSERT INTO dbo.LuongCoBan(MaNV,LuongCB,LuongDongBH,NgayHieuLuc,NgayHetHieuLuc,LyDo,NguoiDuyet)
VALUES('NV000023',16000000,16000000,'2017-07-03',NULL,N'Mức lương khởi điểm','HR_ADMIN');
INSERT INTO dbo.LuongCoBan(MaNV,LuongCB,LuongDongBH,NgayHieuLuc,NgayHetHieuLuc,LyDo,NguoiDuyet)
VALUES('NV000024',15500000,15500000,'2018-02-01',NULL,N'Mức lương khởi điểm','HR_ADMIN');
INSERT INTO dbo.LuongCoBan(MaNV,LuongCB,LuongDongBH,NgayHieuLuc,NgayHetHieuLuc,LyDo,NguoiDuyet)
VALUES('NV000025',15000000,15000000,'2018-04-02',NULL,N'Mức lương khởi điểm','HR_ADMIN');
INSERT INTO dbo.LuongCoBan(MaNV,LuongCB,LuongDongBH,NgayHieuLuc,NgayHetHieuLuc,LyDo,NguoiDuyet)
VALUES('NV000026',11500000,11500000,'2019-09-02',NULL,N'Mức lương khởi điểm','HR_ADMIN');
INSERT INTO dbo.LuongCoBan(MaNV,LuongCB,LuongDongBH,NgayHieuLuc,NgayHetHieuLuc,LyDo,NguoiDuyet)
VALUES('NV000027',11500000,11500000,'2020-01-06',NULL,N'Mức lương khởi điểm','HR_ADMIN');
INSERT INTO dbo.LuongCoBan(MaNV,LuongCB,LuongDongBH,NgayHieuLuc,NgayHetHieuLuc,LyDo,NguoiDuyet)
VALUES('NV000028',11500000,11500000,'2020-06-01',NULL,N'Mức lương khởi điểm','HR_ADMIN');
INSERT INTO dbo.LuongCoBan(MaNV,LuongCB,LuongDongBH,NgayHieuLuc,NgayHetHieuLuc,LyDo,NguoiDuyet)
VALUES('NV000029',11500000,11500000,'2021-01-04',NULL,N'Mức lương khởi điểm','HR_ADMIN');
INSERT INTO dbo.LuongCoBan(MaNV,LuongCB,LuongDongBH,NgayHieuLuc,NgayHetHieuLuc,LyDo,NguoiDuyet)
VALUES('NV000030',11500000,11500000,'2021-04-01',NULL,N'Mức lương khởi điểm','HR_ADMIN');
INSERT INTO dbo.LuongCoBan(MaNV,LuongCB,LuongDongBH,NgayHieuLuc,NgayHetHieuLuc,LyDo,NguoiDuyet)
VALUES('NV000031',8500000,8500000,'2021-07-01',NULL,N'Mức lương khởi điểm','HR_ADMIN');
INSERT INTO dbo.LuongCoBan(MaNV,LuongCB,LuongDongBH,NgayHieuLuc,NgayHetHieuLuc,LyDo,NguoiDuyet)
VALUES('NV000032',8500000,8500000,'2022-01-03',NULL,N'Mức lương khởi điểm','HR_ADMIN');
INSERT INTO dbo.LuongCoBan(MaNV,LuongCB,LuongDongBH,NgayHieuLuc,NgayHetHieuLuc,LyDo,NguoiDuyet)
VALUES('NV000033',8500000,8500000,'2022-03-01',NULL,N'Mức lương khởi điểm','HR_ADMIN');
INSERT INTO dbo.LuongCoBan(MaNV,LuongCB,LuongDongBH,NgayHieuLuc,NgayHetHieuLuc,LyDo,NguoiDuyet)
VALUES('NV000034',8500000,8500000,'2022-08-01',NULL,N'Mức lương khởi điểm','HR_ADMIN');
INSERT INTO dbo.LuongCoBan(MaNV,LuongCB,LuongDongBH,NgayHieuLuc,NgayHetHieuLuc,LyDo,NguoiDuyet)
VALUES('NV000035',8500000,8500000,'2023-01-03',NULL,N'Mức lương khởi điểm','HR_ADMIN');
INSERT INTO dbo.LuongCoBan(MaNV,LuongCB,LuongDongBH,NgayHieuLuc,NgayHetHieuLuc,LyDo,NguoiDuyet)
VALUES('NV000036',8500000,8500000,'2023-04-03',NULL,N'Mức lương khởi điểm','HR_ADMIN');
INSERT INTO dbo.LuongCoBan(MaNV,LuongCB,LuongDongBH,NgayHieuLuc,NgayHetHieuLuc,LyDo,NguoiDuyet)
VALUES('NV000037',8500000,8500000,'2023-07-03',NULL,N'Mức lương khởi điểm','HR_ADMIN');
INSERT INTO dbo.LuongCoBan(MaNV,LuongCB,LuongDongBH,NgayHieuLuc,NgayHetHieuLuc,LyDo,NguoiDuyet)
VALUES('NV000038',6500000,6500000,'2024-10-01',NULL,N'Mức lương khởi điểm','HR_ADMIN');
INSERT INTO dbo.LuongCoBan(MaNV,LuongCB,LuongDongBH,NgayHieuLuc,NgayHetHieuLuc,LyDo,NguoiDuyet)
VALUES('NV000039',27000000,27000000,'2015-05-04',NULL,N'Mức lương khởi điểm','HR_ADMIN');
INSERT INTO dbo.LuongCoBan(MaNV,LuongCB,LuongDongBH,NgayHieuLuc,NgayHetHieuLuc,LyDo,NguoiDuyet)
VALUES('NV000040',20000000,20000000,'2017-10-02',NULL,N'Mức lương khởi điểm','HR_ADMIN');
INSERT INTO dbo.LuongCoBan(MaNV,LuongCB,LuongDongBH,NgayHieuLuc,NgayHetHieuLuc,LyDo,NguoiDuyet)
VALUES('NV000041',16500000,16500000,'2018-08-01',NULL,N'Mức lương khởi điểm','HR_ADMIN');
INSERT INTO dbo.LuongCoBan(MaNV,LuongCB,LuongDongBH,NgayHieuLuc,NgayHetHieuLuc,LyDo,NguoiDuyet)
VALUES('NV000042',15000000,15000000,'2019-02-01',NULL,N'Mức lương khởi điểm','HR_ADMIN');
INSERT INTO dbo.LuongCoBan(MaNV,LuongCB,LuongDongBH,NgayHieuLuc,NgayHetHieuLuc,LyDo,NguoiDuyet)
VALUES('NV000043',11500000,11500000,'2019-11-04',NULL,N'Mức lương khởi điểm','HR_ADMIN');
INSERT INTO dbo.LuongCoBan(MaNV,LuongCB,LuongDongBH,NgayHieuLuc,NgayHetHieuLuc,LyDo,NguoiDuyet)
VALUES('NV000044',11500000,11500000,'2020-04-06',NULL,N'Mức lương khởi điểm','HR_ADMIN');
INSERT INTO dbo.LuongCoBan(MaNV,LuongCB,LuongDongBH,NgayHieuLuc,NgayHetHieuLuc,LyDo,NguoiDuyet)
VALUES('NV000045',11500000,11500000,'2021-06-01',NULL,N'Mức lương khởi điểm','HR_ADMIN');
INSERT INTO dbo.LuongCoBan(MaNV,LuongCB,LuongDongBH,NgayHieuLuc,NgayHetHieuLuc,LyDo,NguoiDuyet)
VALUES('NV000046',8500000,8500000,'2021-10-04',NULL,N'Mức lương khởi điểm','HR_ADMIN');
INSERT INTO dbo.LuongCoBan(MaNV,LuongCB,LuongDongBH,NgayHieuLuc,NgayHetHieuLuc,LyDo,NguoiDuyet)
VALUES('NV000047',8500000,8500000,'2022-04-04',NULL,N'Mức lương khởi điểm','HR_ADMIN');
INSERT INTO dbo.LuongCoBan(MaNV,LuongCB,LuongDongBH,NgayHieuLuc,NgayHetHieuLuc,LyDo,NguoiDuyet)
VALUES('NV000048',8500000,8500000,'2022-09-01',NULL,N'Mức lương khởi điểm','HR_ADMIN');
INSERT INTO dbo.LuongCoBan(MaNV,LuongCB,LuongDongBH,NgayHieuLuc,NgayHetHieuLuc,LyDo,NguoiDuyet)
VALUES('NV000049',8500000,8500000,'2023-03-01',NULL,N'Mức lương khởi điểm','HR_ADMIN');
INSERT INTO dbo.LuongCoBan(MaNV,LuongCB,LuongDongBH,NgayHieuLuc,NgayHetHieuLuc,LyDo,NguoiDuyet)
VALUES('NV000050',6500000,6500000,'2024-11-04',NULL,N'Mức lương khởi điểm','HR_ADMIN');
COMMIT TRANSACTION;
PRINT N'[OK] §4 LuongCoBan — 50 mức lương';
GO

-- ============================================================
-- §5  NHANVIENPHUCL0I — gán phúc lợi
-- ============================================================
BEGIN TRANSACTION;
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000001','FL0001','2015-01-05',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000001','FL0002','2015-01-05',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000001','FL0003','2015-01-05',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000001','FL0004','2015-01-05',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000001','FL0005','2015-01-05',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000001','FL0006','2015-01-05',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000002','FL0001','2019-03-01',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000002','FL0002','2019-03-01',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000002','FL0006','2019-03-01',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000003','FL0001','2016-02-15',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000003','FL0002','2016-02-15',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000003','FL0003','2016-02-15',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000003','FL0004','2016-02-15',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000003','FL0005','2016-02-15',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000003','FL0006','2016-02-15',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000004','FL0001','2018-06-01',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000004','FL0002','2018-06-01',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000004','FL0006','2018-06-01',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000005','FL0001','2019-01-10',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000005','FL0002','2019-01-10',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000005','FL0006','2019-01-10',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000006','FL0001','2020-03-02',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000006','FL0002','2020-03-02',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000007','FL0001','2020-07-01',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000007','FL0002','2020-07-01',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000008','FL0001','2021-01-04',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000008','FL0002','2021-01-04',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000009','FL0001','2018-11-01',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000009','FL0002','2018-11-01',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000009','FL0006','2018-11-01',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000010','FL0001','2024-11-01',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000011','FL0001','2015-07-01',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000011','FL0002','2015-07-01',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000011','FL0003','2015-07-01',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000011','FL0004','2015-07-01',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000011','FL0005','2015-07-01',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000011','FL0006','2015-07-01',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000012','FL0001','2016-09-01',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000012','FL0002','2016-09-01',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000012','FL0003','2016-09-01',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000012','FL0006','2016-09-01',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000013','FL0001','2017-04-03',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000013','FL0002','2017-04-03',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000013','FL0003','2017-04-03',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000013','FL0006','2017-04-03',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000014','FL0001','2019-05-01',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000014','FL0002','2019-05-01',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000014','FL0006','2019-05-01',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000015','FL0001','2019-08-01',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000015','FL0002','2019-08-01',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000015','FL0006','2019-08-01',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000016','FL0001','2020-10-01',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000016','FL0002','2020-10-01',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000017','FL0001','2021-03-01',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000017','FL0002','2021-03-01',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000018','FL0001','2022-01-03',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000018','FL0002','2022-01-03',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000019','FL0001','2022-06-01',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000019','FL0002','2022-06-01',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000020','FL0001','2024-12-02',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000021','FL0001','2015-03-01',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000021','FL0002','2015-03-01',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000021','FL0003','2015-03-01',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000021','FL0004','2015-03-01',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000021','FL0005','2015-03-01',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000021','FL0006','2015-03-01',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000022','FL0001','2017-01-09',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000022','FL0002','2017-01-09',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000022','FL0003','2017-01-09',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000022','FL0006','2017-01-09',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000023','FL0001','2017-07-03',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000023','FL0002','2017-07-03',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000023','FL0003','2017-07-03',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000023','FL0006','2017-07-03',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000024','FL0001','2018-02-01',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000024','FL0002','2018-02-01',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000024','FL0003','2018-02-01',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000024','FL0006','2018-02-01',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000025','FL0001','2018-04-02',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000025','FL0002','2018-04-02',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000025','FL0003','2018-04-02',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000025','FL0006','2018-04-02',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000026','FL0001','2019-09-02',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000026','FL0002','2019-09-02',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000026','FL0006','2019-09-02',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000027','FL0001','2020-01-06',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000027','FL0002','2020-01-06',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000028','FL0001','2020-06-01',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000028','FL0002','2020-06-01',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000029','FL0001','2021-01-04',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000029','FL0002','2021-01-04',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000030','FL0001','2021-04-01',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000030','FL0002','2021-04-01',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000031','FL0001','2021-07-01',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000031','FL0002','2021-07-01',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000032','FL0001','2022-01-03',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000032','FL0002','2022-01-03',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000033','FL0001','2022-03-01',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000033','FL0002','2022-03-01',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000034','FL0001','2022-08-01',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000034','FL0002','2022-08-01',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000035','FL0001','2023-01-03',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000035','FL0002','2023-01-03',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000036','FL0001','2023-04-03',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000036','FL0002','2023-04-03',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000037','FL0001','2023-07-03',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000037','FL0002','2023-07-03',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000038','FL0001','2024-10-01',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000039','FL0001','2015-05-04',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000039','FL0002','2015-05-04',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000039','FL0003','2015-05-04',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000039','FL0004','2015-05-04',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000039','FL0005','2015-05-04',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000039','FL0006','2015-05-04',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000040','FL0001','2017-10-02',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000040','FL0002','2017-10-02',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000040','FL0003','2017-10-02',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000040','FL0006','2017-10-02',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000041','FL0001','2018-08-01',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000041','FL0002','2018-08-01',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000041','FL0003','2018-08-01',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000041','FL0006','2018-08-01',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000042','FL0001','2019-02-01',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000042','FL0002','2019-02-01',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000042','FL0003','2019-02-01',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000042','FL0006','2019-02-01',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000043','FL0001','2019-11-04',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000043','FL0002','2019-11-04',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000043','FL0006','2019-11-04',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000044','FL0001','2020-04-06',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000044','FL0002','2020-04-06',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000045','FL0001','2021-06-01',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000045','FL0002','2021-06-01',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000046','FL0001','2021-10-04',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000046','FL0002','2021-10-04',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000047','FL0001','2022-04-04',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000047','FL0002','2022-04-04',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000048','FL0001','2022-09-01',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000048','FL0002','2022-09-01',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000049','FL0001','2023-03-01',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000049','FL0002','2023-03-01',1);
INSERT INTO dbo.NhanVienPhucLoi(MaNV,MaFL,NgayApDung,IsActive)VALUES('NV000050','FL0001','2024-11-04',1);
COMMIT TRANSACTION;
PRINT N'[OK] §5 NhanVienPhucLoi — phúc lợi đã gán';
GO

-- ============================================================
-- §6  CHAMCONG — Jan, Feb, Mar 2025 (set-based insert)
-- Khoảng 3,100+ bản ghi chấm công thực tế
-- ============================================================
BEGIN TRANSACTION;

-- Bước 6.1: Tạo bảng lịch làm việc Jan-Mar 2025
--   Ngày nghỉ Tết Ất Tỵ 2025:
--     Tết Dương Lịch: 01/01/2025
--     Nghỉ Tết ÂL:   27/01 – 31/01/2025 (Chính phủ quyết định)
--     Bù Tết:        03/02/2025 (thứ 2 đầu tuần)

WITH Calendar AS (
    SELECT CAST('2025-01-01' AS DATE) AS D
    UNION ALL
    SELECT DATEADD(DAY, 1, D) FROM Calendar
    WHERE D < '2025-03-31'
),
WorkDays AS (
    SELECT D
    FROM Calendar
    WHERE DATENAME(WEEKDAY, D) NOT IN ('Saturday','Sunday')
),
Holidays AS (
    SELECT CAST(d AS DATE) AS D FROM (
        VALUES ('2025-01-01'), -- Tết Dương lịch
               ('2025-01-27'), -- Nghỉ Tết ÂL
               ('2025-01-28'),
               ('2025-01-29'), -- Giao thừa Ất Tỵ
               ('2025-01-30'),
               ('2025-01-31'),
               ('2025-02-03')  -- Bù Tết
    ) AS T(d)
),
ActiveNV AS (
    SELECT MaNV FROM dbo.NhanVien WHERE TrangThai IN ('A','P','L')
)
-- Insert tất cả ngày làm việc bình thường (trừ lễ, trừ cuối tuần)
INSERT INTO dbo.ChamCong
    (MaNV, NgayCham, GioVao, GioRa, TrangThai, SoGioTangCa, HeSoTangCa, NguoiCapNhat)
SELECT
    nv.MaNV,
    wd.D,
    '08:00', '17:30',
    'DL',
    0, 1.50,
    'SYSTEM'
FROM ActiveNV nv
CROSS JOIN WorkDays wd
WHERE wd.D NOT IN (SELECT D FROM Holidays)
OPTION (MAXRECURSION 100);

-- Bước 6.2: Insert ngày lễ cho toàn bộ NV
WITH Holidays AS (
    SELECT CAST(d AS DATE) AS D FROM (
        VALUES ('2025-01-01'),('2025-01-27'),('2025-01-28'),
               ('2025-01-29'),('2025-01-30'),('2025-01-31'),('2025-02-03')
    ) AS T(d)
),
ActiveNV AS (
    SELECT MaNV FROM dbo.NhanVien WHERE TrangThai IN ('A','P','L')
)
INSERT INTO dbo.ChamCong
    (MaNV, NgayCham, GioVao, GioRa, TrangThai, SoGioTangCa, HeSoTangCa, NguoiCapNhat)
SELECT nv.MaNV, h.D, NULL, NULL, 'NG', 0, 1.50, 'SYSTEM'
FROM ActiveNV nv CROSS JOIN Holidays h
OPTION (MAXRECURSION 0);

-- Bước 6.3: Thêm tăng ca cho team CNTT & Kinh Doanh (thứ 6 cuối tháng)
UPDATE dbo.ChamCong
SET SoGioTangCa = 2.0, HeSoTangCa = 1.50
WHERE MaNV IN (
    SELECT MaNV FROM dbo.NhanVien WHERE MaPB IN ('PB0004','PB0005')
)
AND TrangThai = 'DL'
AND DATENAME(WEEKDAY, NgayCham) = 'Friday'
AND DAY(NgayCham) >= 22;

-- Bước 6.4: Một số NV nghỉ phép cụ thể (NP)
UPDATE dbo.ChamCong SET TrangThai = 'NP', GioVao = NULL, GioRa = NULL
WHERE MaNV IN ('NV000004','NV000015','NV000028','NV000043')
  AND NgayCham BETWEEN '2025-02-10' AND '2025-02-12';

UPDATE dbo.ChamCong SET TrangThai = 'NP', GioVao = NULL, GioRa = NULL
WHERE MaNV IN ('NV000006','NV000019','NV000036')
  AND NgayCham BETWEEN '2025-03-17' AND '2025-03-19';

-- Bước 6.5: Nghỉ ốm (OM)
UPDATE dbo.ChamCong SET TrangThai = 'OM', GioVao = NULL, GioRa = NULL
WHERE MaNV = 'NV000017' AND NgayCham BETWEEN '2025-02-24' AND '2025-02-26';

UPDATE dbo.ChamCong SET TrangThai = 'OM', GioVao = NULL, GioRa = NULL
WHERE MaNV = 'NV000032' AND NgayCham = '2025-03-05';

-- Bước 6.6: WFH (làm từ xa) một số ngày thứ 2 đầu tháng
UPDATE dbo.ChamCong SET TrangThai = 'WFH'
WHERE MaNV IN (SELECT MaNV FROM dbo.NhanVien WHERE MaPB = 'PB0004')
  AND NgayCham IN ('2025-01-06','2025-02-17','2025-03-03')
  AND TrangThai = 'DL';

-- Bước 6.7: Vắng không phép (KP) một số NV
UPDATE dbo.ChamCong SET TrangThai = 'KP', GioVao = NULL, GioRa = NULL
WHERE MaNV = 'NV000031' AND NgayCham = '2025-03-25';

UPDATE dbo.ChamCong SET TrangThai = 'KP', GioVao = NULL, GioRa = NULL
WHERE MaNV = 'NV000049' AND NgayCham IN ('2025-02-20','2025-02-21');

COMMIT TRANSACTION;
PRINT N'[OK] §6 ChamCong — 3 tháng Jan-Mar 2025 hoàn tất';
GO

-- ============================================================
-- §7  NGHIPHEP — đơn nghỉ phép mẫu
-- ============================================================
BEGIN TRANSACTION;
INSERT INTO dbo.NghiPhep
    (MaNV, MaLoaiNghi, NgayBatDau, NgayKetThuc, LyDo, TrangThai, NguoiDuyet, NgayDuyet)
VALUES
-- Phép năm đã duyệt
('NV000004',1,'2025-02-10','2025-02-12',N'Việc gia đình',         'A',N'Lê Văn Đức',        '2025-02-07'),
('NV000015',1,'2025-02-10','2025-02-12',N'Du lịch cùng gia đình', 'A',N'Hoàng Thị Phương',  '2025-02-07'),
('NV000028',1,'2025-02-10','2025-02-12',N'Về thăm quê',           'A',N'Phạm Anh Tuấn',     '2025-02-07'),
('NV000043',1,'2025-02-10','2025-02-12',N'Nghỉ phép kết hợp',    'A',N'Dương Quốc Hùng',   '2025-02-07'),
('NV000006',1,'2025-03-17','2025-03-19',N'Đám cưới người thân',   'A',N'Lê Văn Đức',        '2025-03-14'),
('NV000019',1,'2025-03-17','2025-03-19',N'Giải quyết việc riêng', 'A',N'Hoàng Thị Phương',  '2025-03-14'),
('NV000036',1,'2025-03-17','2025-03-19',N'Nghỉ phép định kỳ',    'A',N'Phạm Anh Tuấn',     '2025-03-14'),
-- Nghỉ ốm
('NV000017',2,'2025-02-24','2025-02-26',N'Sốt virus, có đơn bác sĩ','A',N'Hoàng Thị Phương','2025-02-24'),
('NV000032',2,'2025-03-05','2025-03-05',N'Đau đầu, sốt nhẹ',     'A',N'Phạm Anh Tuấn',     '2025-03-05'),
-- Đơn đang chờ duyệt
('NV000029',1,'2025-04-07','2025-04-09',N'Nghỉ lễ kết hợp phép', 'P', NULL, NULL),
('NV000044',4,'2025-04-14','2025-04-14',N'Việc riêng không lương','P', NULL, NULL);

COMMIT TRANSACTION;
PRINT N'[OK] §7 NghiPhep — 11 đơn nghỉ phép';
GO

-- ============================================================
-- §8  KHAUTRU — khấu trừ phát sinh
-- ============================================================
BEGIN TRANSACTION;
INSERT INTO dbo.KhauTru
    (MaNV, MaBL, LoaiKhauTru, GiaTri, NgayPhatSinh, TrangThai, GhiChu, NguoiDuyet)
VALUES
-- Tạm ứng lương tháng 1
('NV000014',NULL,'Tạm ứng',      3000000,'2025-01-15','P',N'Tạm ứng lương tháng 1/2025',N'Hoàng Thị Phương'),
('NV000026',NULL,'Tạm ứng',      2000000,'2025-01-20','P',N'Tạm ứng lương tháng 1/2025',N'Phạm Anh Tuấn'),
-- Tạm ứng tháng 2
('NV000033',NULL,'Tạm ứng',      5000000,'2025-02-05','P',N'Tạm ứng lương tháng 2/2025',N'Phạm Anh Tuấn'),
('NV000047',NULL,'Tạm ứng',      2500000,'2025-02-12','P',N'Tạm ứng lương tháng 2/2025',N'Dương Quốc Hùng'),
-- Kỷ luật (vắng không phép)
('NV000031',NULL,'Phạt vi phạm', 500000, '2025-03-25','P',N'Vắng không phép 25/3/2025', N'Phạm Anh Tuấn'),
('NV000049',NULL,'Phạt vi phạm', 1000000,'2025-02-21','P',N'Vắng không phép 20-21/2/2025',N'Dương Quốc Hùng'),
-- Bồi thường thiết bị
('NV000035',NULL,'Bồi thường',   1500000,'2025-03-10','P',N'Vỡ màn hình laptop công ty',N'Phạm Anh Tuấn');

COMMIT TRANSACTION;
PRINT N'[OK] §8 KhauTru — 7 khoản khấu trừ';
GO

-- ============================================================
-- §9  UPDATE TRƯỞNG PHÒNG & KIỂM TRA TỔNG
-- ============================================================

-- Gán trưởng phòng cho từng phòng ban
UPDATE dbo.PhongBan SET MaTruongPhong = 'NV000001' WHERE MaPB = 'PB0001';
UPDATE dbo.PhongBan SET MaTruongPhong = 'NV000003' WHERE MaPB = 'PB0002';
UPDATE dbo.PhongBan SET MaTruongPhong = 'NV000011' WHERE MaPB = 'PB0003';
UPDATE dbo.PhongBan SET MaTruongPhong = 'NV000021' WHERE MaPB = 'PB0004';
UPDATE dbo.PhongBan SET MaTruongPhong = 'NV000039' WHERE MaPB = 'PB0005';
PRINT N'[OK] §9.1 Trưởng phòng đã được gán';
GO

-- ── Kiểm tra tổng ───────────────────────────────────────────
PRINT N'';
PRINT N'════════════════════════════════════════════════════════';
PRINT N'  KIỂM TRA DỮ LIỆU SAU KHI SEED';
PRINT N'════════════════════════════════════════════════════════';

-- Tổng số bản ghi mỗi bảng
SELECT 'PhongBan'       AS Bang, COUNT(*) AS SoBanGhi FROM dbo.PhongBan     UNION ALL
SELECT 'ChucVu'                , COUNT(*)             FROM dbo.ChucVu        UNION ALL
SELECT 'LoaiHopDong'           , COUNT(*)             FROM dbo.LoaiHopDong   UNION ALL
SELECT 'LoaiNghiPhep'          , COUNT(*)             FROM dbo.LoaiNghiPhep  UNION ALL
SELECT 'LoaiPhucLoi'           , COUNT(*)             FROM dbo.LoaiPhucLoi   UNION ALL
SELECT 'NhanVien'              , COUNT(*)             FROM dbo.NhanVien      UNION ALL
SELECT 'HopDong'               , COUNT(*)             FROM dbo.HopDong       UNION ALL
SELECT 'LuongCoBan'            , COUNT(*)             FROM dbo.LuongCoBan    UNION ALL
SELECT 'NhanVienPhucLoi'       , COUNT(*)             FROM dbo.NhanVienPhucLoi UNION ALL
SELECT 'ChamCong'              , COUNT(*)             FROM dbo.ChamCong      UNION ALL
SELECT 'NghiPhep'              , COUNT(*)             FROM dbo.NghiPhep      UNION ALL
SELECT 'KhauTru'               , COUNT(*)             FROM dbo.KhauTru
ORDER BY Bang;
GO

-- Phân bổ nhân viên theo phòng ban + chức vụ
PRINT N'';
PRINT N'--- PHÂN BỔ NHÂN VIÊN THEO PHÒNG BAN ---';
SELECT
    pb.TenPB                    AS PhongBan,
    cv.TenCV                    AS ChucVu,
    COUNT(nv.MaNV)              AS SoNguoi,
    FORMAT(AVG(lcb.LuongCB),'N0') + N' VNĐ' AS LuongTrungBinh
FROM dbo.NhanVien nv
JOIN dbo.PhongBan    pb  ON nv.MaPB = pb.MaPB
JOIN dbo.ChucVu      cv  ON nv.MaCV = cv.MaCV
JOIN dbo.LuongCoBan  lcb ON nv.MaNV = lcb.MaNV
                         AND lcb.NgayHetHieuLuc IS NULL
GROUP BY pb.TenPB, cv.TenCV
ORDER BY pb.TenPB, cv.CapBac DESC;
GO

-- Thống kê chấm công 3 tháng
PRINT N'';
PRINT N'--- THỐNG KÊ CHẤM CÔNG JAN-MAR 2025 ---';
SELECT
    YEAR(NgayCham)              AS Nam,
    MONTH(NgayCham)             AS Thang,
    TrangThai,
    COUNT(*)                    AS SoBanGhi
FROM dbo.ChamCong
GROUP BY YEAR(NgayCham), MONTH(NgayCham), TrangThai
ORDER BY Nam, Thang, TrangThai;
GO

-- Tổng quỹ lương ước tính tháng 3/2025
PRINT N'';
PRINT N'--- ƯỚC TÍNH QUỸ LƯƠNG THÁNG 3/2025 ---';
SELECT
    pb.TenPB,
    COUNT(nv.MaNV)              AS SoNhanVien,
    FORMAT(SUM(lcb.LuongCB),'N0') AS TongLuongCoBan_VND,
    FORMAT(SUM(lcb.LuongCB * 0.105),'N0') AS UocTinhBH_NLD_VND
FROM dbo.NhanVien nv
JOIN dbo.PhongBan   pb  ON nv.MaPB = pb.MaPB
JOIN dbo.LuongCoBan lcb ON nv.MaNV = lcb.MaNV
                        AND lcb.NgayHetHieuLuc IS NULL
WHERE nv.TrangThai IN ('A','P')
GROUP BY pb.TenPB
ORDER BY SUM(lcb.LuongCB) DESC;
GO

PRINT N'';
PRINT N'[DONE] seed_data.sql hoàn tất.';
PRINT N'Dữ liệu sẵn sàng để chạy: sp_TinhLuong 1,2025 / sp_TinhLuong 2,2025 / sp_TinhLuong 3,2025';
GO
