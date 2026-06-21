/*
PROJECT    : Hệ Thống Quản Lý Nhân Sự & Tính Lương Tự Động
MỤC ĐÍCH   : View tổng hợp Hồ sơ nhân viên chi tiết. Kết nối NhanVien với PhongBan, ChucVu, HopDong (đang hiệu lực) và LuongCoBan (đang hiệu lực).
             Phục vụ tối ưu truy vấn cho Backend ở màn hình Danh sách nhân viên.
DBMS       : MySQL 8.0+
*/

USE HRPayrollDB;

DROP VIEW IF EXISTS vw_HoSoNhanVien_ChiTiet;

CREATE VIEW vw_HoSoNhanVien_ChiTiet AS
SELECT 
    nv.MaNV,
    nv.HoTen,
    nv.GioiTinh,
    nv.NgaySinh,
    nv.Email,
    nv.SoDienThoai,
    nv.TrangThai AS TrangThaiNhanVien,
    pb.TenPB AS PhongBan,
    cv.TenCV AS ChucVu,
    nv.NgayVaoLam,
    hd.MaHD AS HopDongHienTai,
    lhd.TenLoaiHD AS LoaiHopDong,
    hd.NgayKetThuc AS NgayHetHanHD,
    lcb.LuongCB AS LuongCoBanHienTai,
    lcb.LuongDongBH AS LuongBaoHiemHienTai
FROM NhanVien nv
JOIN PhongBan pb ON nv.MaPB = pb.MaPB
JOIN ChucVu cv ON nv.MaCV = cv.MaCV
LEFT JOIN HopDong hd ON nv.MaNV = hd.MaNV AND hd.TrangThai = 'A'
LEFT JOIN LoaiHopDong lhd ON hd.MaLoaiHD = lhd.MaLoaiHD
LEFT JOIN LuongCoBan lcb ON nv.MaNV = lcb.MaNV AND lcb.NgayHetHieuLuc IS NULL;
