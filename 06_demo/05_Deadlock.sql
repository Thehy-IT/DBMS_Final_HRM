/*
  KỊCH BẢN DEMO DEADLOCK (KHÓA CHẾT)
  (Phù hợp với kịch bản trong Report_week.md - Mục 7)
  
  Mô phỏng hai luồng xử lý đồng thời từ 2 chuyên viên HR (Giao dịch A và B)
  thao tác trên cùng một nhân sự (NV000006) nhưng lấy khóa (lock) theo 
  trình tự ngược nhau, dẫn đến hiện tượng Deadlock.
*/

-- =========================================================================
-- 1. GIAO DỊCH A (HR 1 - Sửa Hồ Sơ Nhân Viên NV000006 trên UI)
-- Trình tự lấy khóa: NhanVien -> LuongCoBan
-- (Mở Cửa sổ/Tab 1 trong MySQL Workbench. Chạy khối này NGAY LẬP TỨC 
-- sau khi Tab 2 đã được chạy và đang trong giai đoạn SLEEP 5 giây)
-- =========================================================================
START TRANSACTION;
-- Bước A1: Cập nhật thông tin cá nhân (Lấy và giữ khóa dòng trên bảng NhanVien)
UPDATE NhanVien SET SoDienThoai = '0999999999' WHERE MaNV = 'NV000006'; 


-- Bước A2: Đồng bộ thông tin liên đới (Cố gắng lấy khóa dòng trên bảng LuongCoBan)
-- -> Sẽ bị kẹt chờ nếu Giao dịch B đã lấy khóa LuongCoBan trước
UPDATE LuongCoBan SET LyDo = 'Cập nhật từ hồ sơ' WHERE MaNV = 'NV000006' AND NgayHetHieuLuc IS NULL;
COMMIT;


-- =========================================================================
-- 2. GIAO DỊCH B (HR 2 - Sửa Hợp Đồng / Tăng Lương NV000006 trên UI)
-- Trình tự lấy khóa NGƯỢC CHIỀU: LuongCoBan -> NhanVien
-- (Mở Cửa sổ/Tab 2 trong MySQL Workbench. Bôi đen và CHẠY KHỐI NÀY TRƯỚC,
-- nó sẽ bắt đầu SLEEP 5 giây. Ngay lập tức quay lại Tab 1 và chạy Tab 1)
-- =========================================================================
START TRANSACTION;
-- Bước B1: Điều chỉnh mức lương cơ bản (Lấy và giữ khóa dòng trên bảng LuongCoBan)
UPDATE LuongCoBan SET LuongCB = 30000000 WHERE MaNV = 'NV000006' AND NgayHetHieuLuc IS NULL; 

-- Giả lập hệ thống tốn 5 giây xử lý, tạo cửa sổ thời gian (window) để Giao dịch A xen vào
DO SLEEP(5); 


-- Bước B2: Ghi nhận cờ chú thích (Cố gắng lấy khóa dòng trên bảng NhanVien)
-- -> Sinh ra DEADLOCK do NhanVien đang bị khóa bởi Giao dịch A, 
-- và Giao dịch A lại đang chờ LuongCoBan từ Giao dịch B. MySQL sẽ tự động hủy 1 giao dịch.
UPDATE NhanVien SET GhiChu = 'Đã thay đổi lương' WHERE MaNV = 'NV000006'; 
COMMIT;


-- =========================================================================
-- =========================================================================
-- 3. SCRIPT RESET DỮ LIỆU
-- (Khôi phục toàn bộ dữ liệu mẫu gốc cho bảng NhanVien, HopDong, LuongCoBan 
--  để có thể thực hiện demo lại nhiều lần hoặc demo cho bất kỳ nhân viên nào khác)
-- =========================================================================
SET FOREIGN_KEY_CHECKS = 0;

TRUNCATE TABLE LuongCoBan;
TRUNCATE TABLE HopDong;
TRUNCATE TABLE NhanVien;

INSERT INTO NhanVien (MaNV,HoTen,GioiTinh,NgaySinh,CCCD,DiaChi,Email,SoDienThoai,MaPB,MaCV,NgayVaoLam,TrangThai,MaSoThue,SoTaiKhoanNH,TenNganHang,NguoiTao) VALUES
('NV000001','Huỳnh Thế Hy','M','1989-07-22','026896033115','Gò Vấp, TP.HCM','nam.pq@hrpayroll.vn','0971367643','PB0001','CV0001','2015-01-05','A','0319736572','190110002396','TPBank','HR_ADMIN'),
('NV000002','Phạm Công Quang','M','1993-10-02','098934106298','Q.10, TP.HCM','quang.pc@hrpayroll.vn','0935708194','PB0002','CV0002','2016-02-21','A','0374988034','190396889215','Sacombank','HR_ADMIN'),
('NV000003','Vũ Thu Thủy','F','1992-02-05','080924475523','Q.10, TP.HCM','thuy.vt@hrpayroll.vn','0988703005','PB0003','CV0002','2017-05-16','A','0341272553','190452788129','MBBank','HR_ADMIN'),
('NV000004','Vũ Đức Phúc','M','1988-01-01','088886919270','Thủ Đức, TP.HCM','phuc.vd@hrpayroll.vn','0942287985','PB0004','CV0002','2016-10-12','A','0335140847','190813363254','Techcombank','HR_ADMIN'),
('NV000005','Võ Đức Hiếu','M','1988-10-27','040885067770','Đồng Nai','hieu.vd@hrpayroll.vn','0916813620','PB0005','CV0002','2019-10-17','A','0340289135','190784987769','BIDV','HR_ADMIN'),
('NV000006','Bùi Ngọc Hùng','M','1985-12-19','020859401909','Q.1, TP.HCM','hung.bn@hrpayroll.vn','0956420476','PB0006','CV0002','2019-04-24','A','0323111164','190569319938','BIDV','HR_ADMIN'),
('NV000007','Hoàng Thu Diệp','F','1986-10-16','011863753418','Gò Vấp, TP.HCM','diep.ht@hrpayroll.vn','0969069144','PB0007','CV0002','2016-03-06','A','0338595818','190774395804','MBBank','HR_ADMIN'),
('NV000008','Đặng Đức Kiên','M','1989-01-01','099897569981','Q.1, TP.HCM','kien.dd@hrpayroll.vn','0986166246','PB0002','CV0003','2022-05-17','A','0334438599','190746809909','Agribank','HR_ADMIN'),
('NV000009','Huỳnh Mai Anh','F','1997-04-25','026974543184','Đồng Nai','anh.hm@hrpayroll.vn','0912941149','PB0005','CV0004','2022-01-21','A','0332680748','190232244172','Agribank','HR_ADMIN'),
('NV000010','Lê Công Lộc','M','1988-12-16','064882743602','Đồng Nai','loc.lc@hrpayroll.vn','0937592422','PB0003','CV0005','2023-11-16','A','0368416623','190794239754','Techcombank','HR_ADMIN'),
('NV000011','Đặng Hồng Đào','F','1986-09-20','042865196677','Thủ Đức, TP.HCM','dao.dh@hrpayroll.vn','0969427400','PB0007','CV0006','2020-11-27','A','0385587210','190619293644','BIDV','HR_ADMIN'),
('NV000012','Vũ Quang Đức','M','1987-10-03','059874185480','Bình Dương','duc.vq@hrpayroll.vn','0980339453','PB0003','CV0004','2019-07-29','A','0384016756','190265497448','Sacombank','HR_ADMIN'),
('NV000013','Hồ Thị Hằng','F','1995-10-17','094953518087','Q.7, TP.HCM','hang.ht@hrpayroll.vn','0931759927','PB0005','CV0003','2022-05-21','A','0334007090','190925875822','Vietcombank','HR_ADMIN'),
('NV000014','Vũ Diễm Hường','F','1991-10-07','083917156735','Q.1, TP.HCM','huong.vd@hrpayroll.vn','0914491176','PB0007','CV0003','2019-09-13','A','0386255745','190618905205','Agribank','HR_ADMIN'),
('NV000015','Dương Kim Nhi','F','1998-06-25','038985951988','Q.7, TP.HCM','nhi.dk@hrpayroll.vn','0991018650','PB0002','CV0005','2022-06-20','A','0395630804','190756623287','MBBank','HR_ADMIN'),
('NV000016','Lê Đức Phong','M','1990-06-28','055903693705','Q.10, TP.HCM','phong.ld@hrpayroll.vn','0977194013','PB0005','CV0004','2021-09-16','T','0377767769','190712285553','Techcombank','HR_ADMIN'),
('NV000017','Nguyễn Xuân Lộc','M','1986-04-09','046863881880','Q.1, TP.HCM','loc.nx@hrpayroll.vn','0982091897','PB0007','CV0004','2019-04-22','T','0323245372','190329797269','ACB','HR_ADMIN'),
('NV000018','Đỗ Thanh Kiên','M','1992-12-10','023924034134','Thủ Đức, TP.HCM','kien.dt@hrpayroll.vn','0957623448','PB0005','CV0004','2021-01-17','A','0366920644','190330074958','ACB','HR_ADMIN'),
('NV000019','Võ Minh Trung','M','1994-03-08','065944466272','Q.10, TP.HCM','trung.vm@hrpayroll.vn','0990541748','PB0004','CV0005','2022-12-08','A','0347979220','190880296841','BIDV','HR_ADMIN'),
('NV000020','Phan Hoàng Thịnh','M','1986-01-04','041868946752','Bình Thạnh, TP.HCM','thinh.ph@hrpayroll.vn','0955811204','PB0005','CV0006','2020-05-16','A','0377783003','190283890958','Techcombank','HR_ADMIN'),
('NV000021','Bùi Văn Thành','M','1997-06-21','020971425670','Thủ Đức, TP.HCM','thanh.bv@hrpayroll.vn','0940283277','PB0005','CV0005','2022-08-03','A','0319991216','190368418452','BIDV','HR_ADMIN'),
('NV000022','Vũ Đức Phong','M','1987-10-03','047872119776','Bình Dương','phong.vd@hrpayroll.vn','0939159454','PB0006','CV0005','2019-04-25','A','0365200819','190918041802','ACB','HR_ADMIN'),
('NV000023','Phạm Ngọc Phúc','M','1989-04-10','028899725065','Đồng Nai','phuc.pn@hrpayroll.vn','0986758128','PB0007','CV0003','2020-07-02','A','0314260842','190237290086','TPBank','HR_ADMIN'),
('NV000024','Hồ Công Quân','M','1992-09-20','014928768806','Bình Dương','quan.hc@hrpayroll.vn','0992912825','PB0003','CV0007','2024-11-10','P','0317717080','190481977286','Vietcombank','HR_ADMIN'),
('NV000025','Vũ Ngọc Hồng','F','1995-01-02','036951287807','Đồng Nai','hong.vn@hrpayroll.vn','0958640295','PB0006','CV0005','2022-08-09','A','0373609317','190243444042','Techcombank','HR_ADMIN'),
('NV000026','Hồ Thu Ngọc','F','1995-09-22','030958338380','Q.3, TP.HCM','ngoc.ht@hrpayroll.vn','0941000202','PB0003','CV0004','2022-02-23','A','0326955763','190641441883','Techcombank','HR_ADMIN'),
('NV000027','Nguyễn Thu Nhi','F','1986-04-23','094863376209','Bình Dương','nhi.nt@hrpayroll.vn','0957941821','PB0006','CV0005','2021-03-28','A','0314147955','190362387930','Sacombank','HR_ADMIN'),
('NV000028','Trần Văn Lâm','M','1994-11-08','058941303581','Bình Dương','lam.tv@hrpayroll.vn','0984154752','PB0003','CV0007','2024-12-03','P','0316998168','190515672079','VPBank','HR_ADMIN'),
('NV000029','Phan Xuân Công','M','1990-11-18','011905125747','Thủ Đức, TP.HCM','cong.px@hrpayroll.vn','0928371007','PB0007','CV0003','2022-07-09','A','0339556025','190823001513','BIDV','HR_ADMIN'),
('NV000030','Bùi Hồng Yến','F','1997-10-28','056979662755','Thủ Đức, TP.HCM','yen.bh@hrpayroll.vn','0911902027','PB0007','CV0006','2021-02-27','A','0365885406','190999491426','Vietcombank','HR_ADMIN'),
('NV000031','Bùi Xuân Việt','M','1994-07-20','038947777424','Bình Dương','viet.bx@hrpayroll.vn','0976415389','PB0005','CV0007','2024-12-10','P','0348424310','190987059388','TPBank','HR_ADMIN'),
('NV000032','Bùi Diễm Quyên','F','1996-10-21','052962125910','Q.3, TP.HCM','quyen.bd@hrpayroll.vn','0920140494','PB0006','CV0006','2022-01-04','A','0384932501','190938150211','Techcombank','HR_ADMIN'),
('NV000033','Võ Xuân Quốc','M','1993-12-08','042936983783','Q.1, TP.HCM','quoc.vx@hrpayroll.vn','0921152602','PB0007','CV0006','2021-06-09','A','0323573570','190865680590','TPBank','HR_ADMIN'),
('NV000034','Hồ Thị Hà','F','1999-11-03','041995331630','Bình Thạnh, TP.HCM','ha.ht@hrpayroll.vn','0966752704','PB0005','CV0003','2023-01-13','A','0337498028','190801514571','Vietinbank','HR_ADMIN'),
('NV000035','Đặng Bích Nhung','F','1993-06-26','040939901166','Bình Thạnh, TP.HCM','nhung.db@hrpayroll.vn','0910937251','PB0005','CV0006','2019-08-06','A','0347775463','190909920336','MBBank','HR_ADMIN'),
('NV000036','Lý Bích Yến','F','1984-01-25','046847107490','Gò Vấp, TP.HCM','yen.lb@hrpayroll.vn','0921866994','PB0007','CV0006','2019-11-10','A','0371237842','190981235165','TPBank','HR_ADMIN'),
('NV000037','Phạm Quang Phong','M','1995-08-09','040954866952','Bình Thạnh, TP.HCM','phong.pq@hrpayroll.vn','0939586634','PB0007','CV0004','2021-12-22','A','0384170836','190479622962','BIDV','HR_ADMIN'),
('NV000038','Lê Thị Trâm','F','1998-04-09','031987557612','Q.3, TP.HCM','tram.lt@hrpayroll.vn','0975815017','PB0005','CV0005','2020-01-14','T','0345880464','190737126357','Vietinbank','HR_ADMIN'),
('NV000039','Lê Thanh Phúc','M','1995-02-03','069955361777','Đồng Nai','phuc.lt@hrpayroll.vn','0931125070','PB0003','CV0003','2019-06-11','A','0322901033','190633022104','Sacombank','HR_ADMIN'),
('NV000040','Phạm Quang Quang','M','1994-07-13','094949705125','Bình Dương','quang.pq@hrpayroll.vn','0946918544','PB0006','CV0005','2022-04-07','T','0399002424','190316411521','MBBank','HR_ADMIN'),
('NV000041','Đỗ Bích Uyên','F','1984-12-05','041849219381','Bình Thạnh, TP.HCM','uyen.db@hrpayroll.vn','0975620860','PB0003','CV0006','2019-12-05','A','0368713655','190152541869','Vietinbank','HR_ADMIN'),
('NV000042','Lê Hoàng Thắng','M','1994-07-30','045945875471','Đồng Nai','thang.lh@hrpayroll.vn','0978851029','PB0005','CV0006','2020-03-09','A','0377808988','190124150584','BIDV','HR_ADMIN'),
('NV000043','Huỳnh Bích Mai','F','1994-02-25','069942327930','Q.1, TP.HCM','mai.hb@hrpayroll.vn','0972311256','PB0006','CV0005','2022-08-23','A','0337503499','190276386655','Techcombank','HR_ADMIN'),
('NV000044','Bùi Quang Đức','M','1995-01-03','051956703075','Q.1, TP.HCM','duc.bq@hrpayroll.vn','0974495536','PB0005','CV0006','2020-05-22','A','0380033053','190319141328','VPBank','HR_ADMIN'),
('NV000045','Trần Xuân Anh','M','1990-02-19','095907144552','Q.3, TP.HCM','anh.tx@hrpayroll.vn','0970097492','PB0002','CV0005','2020-04-16','A','0329881959','190736457654','Vietcombank','HR_ADMIN'),
('NV000046','Hồ Văn Sơn','M','1997-02-06','070972318795','Q.1, TP.HCM','son.hv@hrpayroll.vn','0966704595','PB0002','CV0003','2020-04-13','A','0340476715','190993915858','Sacombank','HR_ADMIN'),
('NV000047','Lý Thị Thảo','F','1988-01-08','057884265640','Thủ Đức, TP.HCM','thao.lt@hrpayroll.vn','0967699732','PB0002','CV0006','2019-05-03','T','0383582824','190317220219','Vietinbank','HR_ADMIN'),
('NV000048','Hồ Diễm Thủy','F','1992-11-14','061923672704','Bình Dương','thuy.hd@hrpayroll.vn','0962132081','PB0006','CV0005','2023-01-21','A','0312070527','190666886808','BIDV','HR_ADMIN'),
('NV000049','Bùi Văn Lộc','M','1996-11-20','054961185458','Bình Dương','loc.bv@hrpayroll.vn','0919781591','PB0003','CV0006','2020-01-25','A','0338523490','190507466706','Agribank','HR_ADMIN'),
('NV000050','Đỗ Thu Hà','F','1998-02-10','057988493277','Đồng Nai','ha.dt@hrpayroll.vn','0922398776','PB0002','CV0006','2021-04-21','A','0347695226','190441810296','MBBank','HR_ADMIN'),
('NV000051','Võ Ngọc Nghĩa','M','2000-09-26','009603874563','Q.10, TP.HCM','nghia.vn@hrpayroll.vn','0929609766','PB0007','CV0006','2022-08-16','A','0316408122','190737073551','Agribank','HR_ADMIN'),
('NV000052','Phạm Công Việt','M','1989-01-21','015895573659','Đồng Nai','viet.pc@hrpayroll.vn','0987027101','PB0002','CV0005','2023-10-31','A','0340125106','190856314186','MBBank','HR_ADMIN'),
('NV000053','Lý Thanh Phương','F','1991-06-05','079915841463','Gò Vấp, TP.HCM','phuong.lt@hrpayroll.vn','0953712070','PB0003','CV0004','2019-10-15','A','0390166601','190339269763','Sacombank','HR_ADMIN'),
('NV000054','Trần Mai Quyên','F','1991-05-14','098911060293','Q.7, TP.HCM','quyen.tm@hrpayroll.vn','0986459518','PB0003','CV0004','2019-06-04','A','0333237546','190642944334','ACB','HR_ADMIN'),
('NV000055','Võ Minh Phong','M','1984-07-26','065848409099','Q.1, TP.HCM','phong.vm@hrpayroll.vn','0929900441','PB0007','CV0006','2019-04-14','A','0322816522','190162878521','ACB','HR_ADMIN'),
('NV000056','Huỳnh Thanh Hoa','F','1991-12-22','024914726746','Q.7, TP.HCM','hoa.ht@hrpayroll.vn','0987562721','PB0002','CV0007','2024-10-22','P','0348729652','190681784788','Vietinbank','HR_ADMIN'),
('NV000057','Đỗ Thanh Việt','M','1987-04-29','025873119391','Bình Thạnh, TP.HCM','viet.dt@hrpayroll.vn','0946167085','PB0005','CV0005','2019-05-01','A','0322142123','190273615782','Sacombank','HR_ADMIN'),
('NV000058','Vũ Hồng Nhi','F','1989-08-08','014896661654','Q.10, TP.HCM','nhi.vh@hrpayroll.vn','0914899615','PB0005','CV0003','2023-05-25','A','0343283131','190576963669','Vietinbank','HR_ADMIN'),
('NV000059','Hoàng Thanh An','F','1996-11-13','093963538924','Đồng Nai','an.ht@hrpayroll.vn','0917464009','PB0004','CV0005','2023-05-24','A','0334515063','190350753341','Agribank','HR_ADMIN'),
('NV000060','Ngô Hoàng Hiếu','M','1992-08-04','016926819361','Bình Dương','hieu.nh@hrpayroll.vn','0980673593','PB0003','CV0004','2019-04-30','A','0386783494','190166398450','Agribank','HR_ADMIN'),
('NV000061','Võ Thanh Anh','M','1989-08-10','091892110878','Bình Dương','anh.vt@hrpayroll.vn','0991524118','PB0006','CV0005','2020-09-03','T','0390044318','190620540297','Sacombank','HR_ADMIN'),
('NV000062','Võ Quang Huy','M','1994-05-18','024944518935','Thủ Đức, TP.HCM','huy.vq@hrpayroll.vn','0958664468','PB0002','CV0007','2024-10-24','P','0391791329','190390234350','ACB','HR_ADMIN'),
('NV000063','Hoàng Thanh Hùng','M','1991-07-27','046915049416','Q.1, TP.HCM','hung.ht@hrpayroll.vn','0937015665','PB0005','CV0003','2021-04-06','A','0330342394','190556074388','Agribank','HR_ADMIN'),
('NV000064','Võ Đức Khoa','M','1994-12-26','047946779292','Q.10, TP.HCM','khoa.vd@hrpayroll.vn','0964419851','PB0005','CV0004','2022-06-22','A','0335669800','190741934318','Techcombank','HR_ADMIN'),
('NV000065','Vũ Kim Hường','F','1993-08-16','015932392414','Gò Vấp, TP.HCM','huong.vk@hrpayroll.vn','0963562697','PB0005','CV0006','2020-10-09','A','0329314149','190576912483','VPBank','HR_ADMIN');

COMMIT;
SET SQL_SAFE_UPDATES = 1;

SELECT '§2 NhanVien hoàn tất' AS Info;

START TRANSACTION;
INSERT INTO HopDong(MaHD,MaNV,MaLoaiHD,NgayBatDau,NgayKetThuc,LuongCoBan,VungLuong,TrangThai,NguoiKy_NLD,NguoiKy_NSDLD,NgayKy,NguoiTao) VALUES
('HD00000001','NV000001',4,'2015-01-05',NULL,70000000,1,'A','Huỳnh Thế Hy','Nguyễn Hoàng Minh','2015-01-05','HR_ADMIN'),
('HD00000002','NV000002',4,'2016-02-21',NULL,35000000,1,'A','Phạm Công Quang','Nguyễn Hoàng Minh','2016-02-21','HR_ADMIN'),
('HD00000003','NV000003',2,'2017-05-16','2018-05-16',28000000,1,'E','Vũ Thu Thủy','Nguyễn Hoàng Minh','2017-05-16','HR_ADMIN'),
('HD00000004','NV000003',4,'2018-05-17',NULL,35000000,1,'A','Vũ Thu Thủy','Nguyễn Hoàng Minh','2018-05-17','HR_ADMIN'),
('HD00000005','NV000004',4,'2016-10-12',NULL,35000000,1,'A','Vũ Đức Phúc','Nguyễn Hoàng Minh','2016-10-12','HR_ADMIN'),
('HD00000006','NV000005',2,'2019-10-17','2020-10-16',20000000,1,'E','Võ Đức Hiếu','Nguyễn Hoàng Minh','2019-10-17','HR_ADMIN'),
('HD00000007','NV000005',4,'2020-10-17',NULL,25000000,1,'A','Võ Đức Hiếu','Nguyễn Hoàng Minh','2020-10-17','HR_ADMIN'),
('HD00000008','NV000006',2,'2019-04-24','2020-04-23',20000000,1,'E','Bùi Ngọc Hùng','Nguyễn Hoàng Minh','2019-04-24','HR_ADMIN'),
('HD00000009','NV000006',4,'2020-04-24',NULL,25000000,1,'A','Bùi Ngọc Hùng','Nguyễn Hoàng Minh','2020-04-24','HR_ADMIN'),
('HD00000010','NV000007',4,'2016-03-06',NULL,30000000,1,'A','Hoàng Thu Diệp','Nguyễn Hoàng Minh','2016-03-06','HR_ADMIN'),
('HD00000011','NV000008',3,'2022-05-17',NULL,22000000,1,'A','Đặng Đức Kiên','Nguyễn Hoàng Minh','2022-05-17','HR_ADMIN'),
('HD00000012','NV000009',3,'2022-01-21',NULL,18000000,1,'A','Huỳnh Mai Anh','Nguyễn Hoàng Minh','2022-01-21','HR_ADMIN'),
('HD00000013','NV000010',3,'2023-11-16',NULL,14000000,1,'A','Lê Công Lộc','Nguyễn Hoàng Minh','2023-11-16','HR_ADMIN'),
('HD00000014','NV000011',3,'2020-11-27',NULL,8000000,1,'A','Đặng Hồng Đào','Nguyễn Hoàng Minh','2020-11-27','HR_ADMIN'),
('HD00000015','NV000012',2,'2019-07-29','2020-07-28',12800000,1,'E','Vũ Quang Đức','Nguyễn Hoàng Minh','2019-07-29','HR_ADMIN'),
('HD00000016','NV000012',4,'2020-07-29',NULL,16000000,1,'A','Vũ Quang Đức','Nguyễn Hoàng Minh','2020-07-29','HR_ADMIN'),
('HD00000017','NV000013',3,'2022-05-21',NULL,20000000,1,'A','Hồ Thị Hằng','Nguyễn Hoàng Minh','2022-05-21','HR_ADMIN'),
('HD00000018','NV000014',3,'2019-09-13',NULL,18000000,1,'A','Vũ Diễm Hường','Nguyễn Hoàng Minh','2019-09-13','HR_ADMIN'),
('HD00000019','NV000015',3,'2022-06-20',NULL,14000000,1,'A','Dương Kim Nhi','Nguyễn Hoàng Minh','2022-06-20','HR_ADMIN'),
('HD00000020','NV000016',2,'2021-09-16','2024-07-01',14000000,1,'E','Lê Đức Phong','Nguyễn Hoàng Minh','2021-09-16','HR_ADMIN'),
('HD00000021','NV000017',2,'2019-04-22','2022-06-17',18000000,1,'E','Nguyễn Xuân Lộc','Nguyễn Hoàng Minh','2019-04-22','HR_ADMIN'),
('HD00000022','NV000018',2,'2021-01-17','2022-01-17',11200000,1,'E','Đỗ Thanh Kiên','Nguyễn Hoàng Minh','2021-01-17','HR_ADMIN'),
('HD00000023','NV000018',4,'2022-01-18',NULL,14000000,1,'A','Đỗ Thanh Kiên','Nguyễn Hoàng Minh','2022-01-18','HR_ADMIN'),
('HD00000024','NV000019',3,'2022-12-08',NULL,12000000,1,'A','Võ Minh Trung','Nguyễn Hoàng Minh','2022-12-08','HR_ADMIN'),
('HD00000025','NV000020',2,'2020-05-16','2021-05-16',6400000,1,'E','Phan Hoàng Thịnh','Nguyễn Hoàng Minh','2020-05-16','HR_ADMIN'),
('HD00000026','NV000020',4,'2021-05-17',NULL,8000000,1,'A','Phan Hoàng Thịnh','Nguyễn Hoàng Minh','2021-05-17','HR_ADMIN'),
('HD00000027','NV000021',3,'2022-08-03',NULL,10000000,1,'A','Bùi Văn Thành','Nguyễn Hoàng Minh','2022-08-03','HR_ADMIN'),
('HD00000028','NV000022',3,'2019-04-25',NULL,10000000,1,'A','Vũ Đức Phong','Nguyễn Hoàng Minh','2019-04-25','HR_ADMIN'),
('HD00000029','NV000023',2,'2020-07-02','2021-07-02',14400000,1,'E','Phạm Ngọc Phúc','Nguyễn Hoàng Minh','2020-07-02','HR_ADMIN'),
('HD00000030','NV000023',4,'2021-07-03',NULL,18000000,1,'A','Phạm Ngọc Phúc','Nguyễn Hoàng Minh','2021-07-03','HR_ADMIN'),
('HD00000031','NV000024',1,'2024-11-10','2026-03-09',5000000,1,'A','Hồ Công Quân','Nguyễn Hoàng Minh','2024-11-10','HR_ADMIN'),
('HD00000032','NV000025',3,'2022-08-09',NULL,10000000,1,'A','Vũ Ngọc Hồng','Nguyễn Hoàng Minh','2022-08-09','HR_ADMIN'),
('HD00000033','NV000026',3,'2022-02-23',NULL,18000000,1,'A','Hồ Thu Ngọc','Nguyễn Hoàng Minh','2022-02-23','HR_ADMIN'),
('HD00000034','NV000027',3,'2021-03-28',NULL,14000000,1,'A','Nguyễn Thu Nhi','Nguyễn Hoàng Minh','2021-03-28','HR_ADMIN'),
('HD00000035','NV000028',1,'2024-12-03','2026-04-01',5000000,1,'A','Trần Văn Lâm','Nguyễn Hoàng Minh','2024-12-03','HR_ADMIN'),
('HD00000036','NV000029',3,'2022-07-09',NULL,20000000,1,'A','Phan Xuân Công','Nguyễn Hoàng Minh','2022-07-09','HR_ADMIN'),
('HD00000037','NV000030',2,'2021-02-27','2022-02-27',5600000,1,'E','Bùi Hồng Yến','Nguyễn Hoàng Minh','2021-02-27','HR_ADMIN'),
('HD00000038','NV000030',4,'2022-02-28',NULL,7000000,1,'A','Bùi Hồng Yến','Nguyễn Hoàng Minh','2022-02-28','HR_ADMIN'),
('HD00000039','NV000031',1,'2024-12-10','2026-04-08',5000000,1,'A','Bùi Xuân Việt','Nguyễn Hoàng Minh','2024-12-10','HR_ADMIN'),
('HD00000040','NV000032',3,'2022-01-04',NULL,9000000,1,'A','Bùi Diễm Quyên','Nguyễn Hoàng Minh','2022-01-04','HR_ADMIN'),
('HD00000041','NV000033',3,'2021-06-09',NULL,7000000,1,'A','Võ Xuân Quốc','Nguyễn Hoàng Minh','2021-06-09','HR_ADMIN'),
('HD00000042','NV000034',3,'2023-01-13',NULL,20000000,1,'A','Hồ Thị Hà','Nguyễn Hoàng Minh','2023-01-13','HR_ADMIN'),
('HD00000043','NV000035',2,'2019-08-06','2020-08-05',5600000,1,'E','Đặng Bích Nhung','Nguyễn Hoàng Minh','2019-08-06','HR_ADMIN'),
('HD00000044','NV000035',4,'2020-08-06',NULL,7000000,1,'A','Đặng Bích Nhung','Nguyễn Hoàng Minh','2020-08-06','HR_ADMIN'),
('HD00000045','NV000036',2,'2019-11-10','2020-11-09',7200000,1,'E','Lý Bích Yến','Nguyễn Hoàng Minh','2019-11-10','HR_ADMIN'),
('HD00000046','NV000036',4,'2020-11-10',NULL,9000000,1,'A','Lý Bích Yến','Nguyễn Hoàng Minh','2020-11-10','HR_ADMIN'),
('HD00000047','NV000037',2,'2021-12-22','2022-12-22',11200000,1,'E','Phạm Quang Phong','Nguyễn Hoàng Minh','2021-12-22','HR_ADMIN'),
('HD00000048','NV000037',4,'2022-12-23',NULL,14000000,1,'A','Phạm Quang Phong','Nguyễn Hoàng Minh','2022-12-23','HR_ADMIN'),
('HD00000049','NV000038',2,'2020-01-14','2023-06-24',14000000,1,'E','Lê Thị Trâm','Nguyễn Hoàng Minh','2020-01-14','HR_ADMIN'),
('HD00000050','NV000039',3,'2019-06-11',NULL,18000000,1,'A','Lê Thanh Phúc','Nguyễn Hoàng Minh','2019-06-11','HR_ADMIN'),
('HD00000051','NV000040',2,'2022-04-07','2023-11-06',10000000,1,'E','Phạm Quang Quang','Nguyễn Hoàng Minh','2022-04-07','HR_ADMIN'),
('HD00000052','NV000041',2,'2019-12-05','2020-12-04',5600000,1,'E','Đỗ Bích Uyên','Nguyễn Hoàng Minh','2019-12-05','HR_ADMIN'),
('HD00000053','NV000041',4,'2020-12-05',NULL,7000000,1,'A','Đỗ Bích Uyên','Nguyễn Hoàng Minh','2020-12-05','HR_ADMIN'),
('HD00000054','NV000042',2,'2020-03-09','2021-03-09',7200000,1,'E','Lê Hoàng Thắng','Nguyễn Hoàng Minh','2020-03-09','HR_ADMIN'),
('HD00000055','NV000042',4,'2021-03-10',NULL,9000000,1,'A','Lê Hoàng Thắng','Nguyễn Hoàng Minh','2021-03-10','HR_ADMIN'),
('HD00000056','NV000043',3,'2022-08-23',NULL,10000000,1,'A','Huỳnh Bích Mai','Nguyễn Hoàng Minh','2022-08-23','HR_ADMIN'),
('HD00000057','NV000044',3,'2020-05-22',NULL,9000000,1,'A','Bùi Quang Đức','Nguyễn Hoàng Minh','2020-05-22','HR_ADMIN'),
('HD00000058','NV000045',2,'2020-04-16','2021-04-16',11200000,1,'E','Trần Xuân Anh','Nguyễn Hoàng Minh','2020-04-16','HR_ADMIN'),
('HD00000059','NV000045',4,'2021-04-17',NULL,14000000,1,'A','Trần Xuân Anh','Nguyễn Hoàng Minh','2021-04-17','HR_ADMIN'),
('HD00000060','NV000046',3,'2020-04-13',NULL,22000000,1,'A','Hồ Văn Sơn','Nguyễn Hoàng Minh','2020-04-13','HR_ADMIN'),
('HD00000061','NV000047',2,'2019-05-03','2020-08-13',9000000,1,'E','Lý Thị Thảo','Nguyễn Hoàng Minh','2019-05-03','HR_ADMIN'),
('HD00000062','NV000048',3,'2023-01-21',NULL,14000000,1,'A','Hồ Diễm Thủy','Nguyễn Hoàng Minh','2023-01-21','HR_ADMIN'),
('HD00000063','NV000049',2,'2020-01-25','2021-01-24',6400000,1,'E','Bùi Văn Lộc','Nguyễn Hoàng Minh','2020-01-25','HR_ADMIN'),
('HD00000064','NV000049',4,'2021-01-25',NULL,8000000,1,'A','Bùi Văn Lộc','Nguyễn Hoàng Minh','2021-01-25','HR_ADMIN'),
('HD00000065','NV000050',2,'2021-04-21','2022-04-21',5600000,1,'E','Đỗ Thu Hà','Nguyễn Hoàng Minh','2021-04-21','HR_ADMIN'),
('HD00000066','NV000050',4,'2022-04-22',NULL,7000000,1,'A','Đỗ Thu Hà','Nguyễn Hoàng Minh','2022-04-22','HR_ADMIN'),
('HD00000067','NV000051',3,'2022-08-16',NULL,9000000,1,'A','Võ Ngọc Nghĩa','Nguyễn Hoàng Minh','2022-08-16','HR_ADMIN'),
('HD00000068','NV000052',3,'2023-10-31',NULL,10000000,1,'A','Phạm Công Việt','Nguyễn Hoàng Minh','2023-10-31','HR_ADMIN'),
('HD00000069','NV000053',2,'2019-10-15','2020-10-14',12800000,1,'E','Lý Thanh Phương','Nguyễn Hoàng Minh','2019-10-15','HR_ADMIN'),
('HD00000070','NV000053',4,'2020-10-15',NULL,16000000,1,'A','Lý Thanh Phương','Nguyễn Hoàng Minh','2020-10-15','HR_ADMIN'),
('HD00000071','NV000054',3,'2019-06-04',NULL,16000000,1,'A','Trần Mai Quyên','Nguyễn Hoàng Minh','2019-06-04','HR_ADMIN'),
('HD00000072','NV000055',2,'2019-04-14','2020-04-13',5600000,1,'E','Võ Minh Phong','Nguyễn Hoàng Minh','2019-04-14','HR_ADMIN'),
('HD00000073','NV000055',4,'2020-04-14',NULL,7000000,1,'A','Võ Minh Phong','Nguyễn Hoàng Minh','2020-04-14','HR_ADMIN'),
('HD00000074','NV000056',1,'2024-10-22','2024-12-21',5000000,1,'A','Huỳnh Thanh Hoa','Nguyễn Hoàng Minh','2024-10-22','HR_ADMIN'),
('HD00000075','NV000057',2,'2019-05-01','2020-04-30',8000000,1,'E','Đỗ Thanh Việt','Nguyễn Hoàng Minh','2019-05-01','HR_ADMIN'),
('HD00000076','NV000057',4,'2020-05-01',NULL,10000000,1,'A','Đỗ Thanh Việt','Nguyễn Hoàng Minh','2020-05-01','HR_ADMIN'),
('HD00000077','NV000058',3,'2023-05-25',NULL,20000000,1,'A','Vũ Hồng Nhi','Nguyễn Hoàng Minh','2023-05-25','HR_ADMIN'),
('HD00000078','NV000059',3,'2023-05-24',NULL,10000000,1,'A','Hoàng Thanh An','Nguyễn Hoàng Minh','2023-05-24','HR_ADMIN'),
('HD00000079','NV000060',2,'2019-04-30','2020-04-29',11200000,1,'E','Ngô Hoàng Hiếu','Nguyễn Hoàng Minh','2019-04-30','HR_ADMIN'),
('HD00000080','NV000060',4,'2020-04-30',NULL,14000000,1,'A','Ngô Hoàng Hiếu','Nguyễn Hoàng Minh','2020-04-30','HR_ADMIN'),
('HD00000081','NV000061',2,'2020-09-03','2021-12-03',12000000,1,'E','Võ Thanh Anh','Nguyễn Hoàng Minh','2020-09-03','HR_ADMIN'),
('HD00000082','NV000062',1,'2024-10-24','2024-12-23',5000000,1,'A','Võ Quang Huy','Nguyễn Hoàng Minh','2024-10-24','HR_ADMIN'),
('HD00000083','NV000063',2,'2021-04-06','2022-04-06',17600000,1,'E','Hoàng Thanh Hùng','Nguyễn Hoàng Minh','2021-04-06','HR_ADMIN'),
('HD00000084','NV000063',4,'2022-04-07',NULL,22000000,1,'A','Hoàng Thanh Hùng','Nguyễn Hoàng Minh','2022-04-07','HR_ADMIN'),
('HD00000085','NV000064',3,'2022-06-22',NULL,16000000,1,'A','Võ Đức Khoa','Nguyễn Hoàng Minh','2022-06-22','HR_ADMIN'),
('HD00000086','NV000065',3,'2020-10-09',NULL,7000000,1,'A','Vũ Kim Hường','Nguyễn Hoàng Minh','2020-10-09','HR_ADMIN');

COMMIT;
SELECT '§3 HopDong hoàn tất' AS Info;

START TRANSACTION;
INSERT INTO LuongCoBan(MaNV,LuongCB,LuongDongBH,NgayHieuLuc,NgayHetHieuLuc,LyDo,NguoiDuyet) VALUES
('NV000001',70000000,46800000,'2015-01-05',NULL,'Mức lương khởi điểm','HR_ADMIN'),
('NV000002',35000000,35000000,'2016-02-21',NULL,'Mức lương khởi điểm','HR_ADMIN'),
('NV000003',28000000,28000000,'2017-05-16','2018-05-16','Lương hợp đồng 1 năm','HR_ADMIN'),
('NV000003',35000000,35000000,'2018-05-17',NULL,'Tăng lương định kỳ','HR_ADMIN'),
('NV000004',35000000,35000000,'2016-10-12',NULL,'Mức lương khởi điểm','HR_ADMIN'),
('NV000005',20000000,20000000,'2019-10-17','2020-10-16','Lương hợp đồng 1 năm','HR_ADMIN'),
('NV000005',25000000,25000000,'2020-10-17',NULL,'Tăng lương định kỳ','HR_ADMIN'),
('NV000006',20000000,20000000,'2019-04-24','2020-04-23','Lương hợp đồng 1 năm','HR_ADMIN'),
('NV000006',25000000,25000000,'2020-04-24',NULL,'Tăng lương định kỳ','HR_ADMIN'),
('NV000007',30000000,30000000,'2016-03-06',NULL,'Mức lương khởi điểm','HR_ADMIN'),
('NV000008',22000000,22000000,'2022-05-17',NULL,'Mức lương khởi điểm','HR_ADMIN'),
('NV000009',18000000,18000000,'2022-01-21',NULL,'Mức lương khởi điểm','HR_ADMIN'),
('NV000010',14000000,14000000,'2023-11-16',NULL,'Mức lương khởi điểm','HR_ADMIN'),
('NV000011',8000000,8000000,'2020-11-27',NULL,'Mức lương khởi điểm','HR_ADMIN'),
('NV000012',12800000,12800000,'2019-07-29','2020-07-28','Lương hợp đồng 1 năm','HR_ADMIN'),
('NV000012',16000000,16000000,'2020-07-29',NULL,'Tăng lương định kỳ','HR_ADMIN'),
('NV000013',20000000,20000000,'2022-05-21',NULL,'Mức lương khởi điểm','HR_ADMIN'),
('NV000014',18000000,18000000,'2019-09-13',NULL,'Mức lương khởi điểm','HR_ADMIN'),
('NV000015',14000000,14000000,'2022-06-20',NULL,'Mức lương khởi điểm','HR_ADMIN'),
('NV000016',14000000,14000000,'2021-09-16','2024-07-01','Mức lương khởi điểm','HR_ADMIN'),
('NV000017',18000000,18000000,'2019-04-22','2022-06-17','Mức lương khởi điểm','HR_ADMIN'),
('NV000018',11200000,11200000,'2021-01-17','2022-01-17','Lương hợp đồng 1 năm','HR_ADMIN'),
('NV000018',14000000,14000000,'2022-01-18',NULL,'Tăng lương định kỳ','HR_ADMIN'),
('NV000019',12000000,12000000,'2022-12-08',NULL,'Mức lương khởi điểm','HR_ADMIN'),
('NV000020',6400000,6400000,'2020-05-16','2021-05-16','Lương hợp đồng 1 năm','HR_ADMIN'),
('NV000020',8000000,8000000,'2021-05-17',NULL,'Tăng lương định kỳ','HR_ADMIN'),
('NV000021',10000000,10000000,'2022-08-03',NULL,'Mức lương khởi điểm','HR_ADMIN'),
('NV000022',10000000,10000000,'2019-04-25',NULL,'Mức lương khởi điểm','HR_ADMIN'),
('NV000023',14400000,14400000,'2020-07-02','2021-07-02','Lương hợp đồng 1 năm','HR_ADMIN'),
('NV000023',18000000,18000000,'2021-07-03',NULL,'Tăng lương định kỳ','HR_ADMIN'),
('NV000024',5000000,5000000,'2024-11-10',NULL,'Lương thử việc','HR_ADMIN'),
('NV000025',10000000,10000000,'2022-08-09',NULL,'Mức lương khởi điểm','HR_ADMIN'),
('NV000026',18000000,18000000,'2022-02-23',NULL,'Mức lương khởi điểm','HR_ADMIN'),
('NV000027',14000000,14000000,'2021-03-28',NULL,'Mức lương khởi điểm','HR_ADMIN'),
('NV000028',5000000,5000000,'2024-12-03',NULL,'Lương thử việc','HR_ADMIN'),
('NV000029',20000000,20000000,'2022-07-09',NULL,'Mức lương khởi điểm','HR_ADMIN'),
('NV000030',5600000,5600000,'2021-02-27','2022-02-27','Lương hợp đồng 1 năm','HR_ADMIN'),
('NV000030',7000000,7000000,'2022-02-28',NULL,'Tăng lương định kỳ','HR_ADMIN'),
('NV000031',5000000,5000000,'2024-12-10',NULL,'Lương thử việc','HR_ADMIN'),
('NV000032',9000000,9000000,'2022-01-04',NULL,'Mức lương khởi điểm','HR_ADMIN'),
('NV000033',7000000,7000000,'2021-06-09',NULL,'Mức lương khởi điểm','HR_ADMIN'),
('NV000034',20000000,20000000,'2023-01-13',NULL,'Mức lương khởi điểm','HR_ADMIN'),
('NV000035',5600000,5600000,'2019-08-06','2020-08-05','Lương hợp đồng 1 năm','HR_ADMIN'),
('NV000035',7000000,7000000,'2020-08-06',NULL,'Tăng lương định kỳ','HR_ADMIN'),
('NV000036',7200000,7200000,'2019-11-10','2020-11-09','Lương hợp đồng 1 năm','HR_ADMIN'),
('NV000036',9000000,9000000,'2020-11-10',NULL,'Tăng lương định kỳ','HR_ADMIN'),
('NV000037',11200000,11200000,'2021-12-22','2022-12-22','Lương hợp đồng 1 năm','HR_ADMIN'),
('NV000037',14000000,14000000,'2022-12-23',NULL,'Tăng lương định kỳ','HR_ADMIN'),
('NV000038',14000000,14000000,'2020-01-14','2023-06-24','Mức lương khởi điểm','HR_ADMIN'),
('NV000039',18000000,18000000,'2019-06-11',NULL,'Mức lương khởi điểm','HR_ADMIN'),
('NV000040',10000000,10000000,'2022-04-07','2023-11-06','Mức lương khởi điểm','HR_ADMIN'),
('NV000041',5600000,5600000,'2019-12-05','2020-12-04','Lương hợp đồng 1 năm','HR_ADMIN'),
('NV000041',7000000,7000000,'2020-12-05',NULL,'Tăng lương định kỳ','HR_ADMIN'),
('NV000042',7200000,7200000,'2020-03-09','2021-03-09','Lương hợp đồng 1 năm','HR_ADMIN'),
('NV000042',9000000,9000000,'2021-03-10',NULL,'Tăng lương định kỳ','HR_ADMIN'),
('NV000043',10000000,10000000,'2022-08-23',NULL,'Mức lương khởi điểm','HR_ADMIN'),
('NV000044',9000000,9000000,'2020-05-22',NULL,'Mức lương khởi điểm','HR_ADMIN'),
('NV000045',11200000,11200000,'2020-04-16','2021-04-16','Lương hợp đồng 1 năm','HR_ADMIN'),
('NV000045',14000000,14000000,'2021-04-17',NULL,'Tăng lương định kỳ','HR_ADMIN'),
('NV000046',22000000,22000000,'2020-04-13',NULL,'Mức lương khởi điểm','HR_ADMIN'),
('NV000047',9000000,9000000,'2019-05-03','2020-08-13','Mức lương khởi điểm','HR_ADMIN'),
('NV000048',14000000,14000000,'2023-01-21',NULL,'Mức lương khởi điểm','HR_ADMIN'),
('NV000049',6400000,6400000,'2020-01-25','2021-01-24','Lương hợp đồng 1 năm','HR_ADMIN'),
('NV000049',8000000,8000000,'2021-01-25',NULL,'Tăng lương định kỳ','HR_ADMIN'),
('NV000050',5600000,5600000,'2021-04-21','2022-04-21','Lương hợp đồng 1 năm','HR_ADMIN'),
('NV000050',7000000,7000000,'2022-04-22',NULL,'Tăng lương định kỳ','HR_ADMIN'),
('NV000051',9000000,9000000,'2022-08-16',NULL,'Mức lương khởi điểm','HR_ADMIN'),
('NV000052',10000000,10000000,'2023-10-31',NULL,'Mức lương khởi điểm','HR_ADMIN'),
('NV000053',12800000,12800000,'2019-10-15','2020-10-14','Lương hợp đồng 1 năm','HR_ADMIN'),
('NV000053',16000000,16000000,'2020-10-15',NULL,'Tăng lương định kỳ','HR_ADMIN'),
('NV000054',16000000,16000000,'2019-06-04',NULL,'Mức lương khởi điểm','HR_ADMIN'),
('NV000055',5600000,5600000,'2019-04-14','2020-04-13','Lương hợp đồng 1 năm','HR_ADMIN'),
('NV000055',7000000,7000000,'2020-04-14',NULL,'Tăng lương định kỳ','HR_ADMIN'),
('NV000056',5000000,5000000,'2024-10-22',NULL,'Lương thử việc','HR_ADMIN'),
('NV000057',8000000,8000000,'2019-05-01','2020-04-30','Lương hợp đồng 1 năm','HR_ADMIN'),
('NV000057',10000000,10000000,'2020-05-01',NULL,'Tăng lương định kỳ','HR_ADMIN'),
('NV000058',20000000,20000000,'2023-05-25',NULL,'Mức lương khởi điểm','HR_ADMIN'),
('NV000059',10000000,10000000,'2023-05-24',NULL,'Mức lương khởi điểm','HR_ADMIN'),
('NV000060',11200000,11200000,'2019-04-30','2020-04-29','Lương hợp đồng 1 năm','HR_ADMIN'),
('NV000060',14000000,14000000,'2020-04-30',NULL,'Tăng lương định kỳ','HR_ADMIN'),
('NV000061',12000000,12000000,'2020-09-03','2021-12-03','Mức lương khởi điểm','HR_ADMIN'),
('NV000062',5000000,5000000,'2024-10-24',NULL,'Lương thử việc','HR_ADMIN'),
('NV000063',17600000,17600000,'2021-04-06','2022-04-06','Lương hợp đồng 1 năm','HR_ADMIN'),
('NV000063',22000000,22000000,'2022-04-07',NULL,'Tăng lương định kỳ','HR_ADMIN'),
('NV000064',16000000,16000000,'2022-06-22',NULL,'Mức lương khởi điểm','HR_ADMIN'),
('NV000065',7000000,7000000,'2020-10-09',NULL,'Mức lương khởi điểm','HR_ADMIN');

COMMIT;

SET FOREIGN_KEY_CHECKS = 1;
