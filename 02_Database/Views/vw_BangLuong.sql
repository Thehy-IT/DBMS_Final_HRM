/*
PROJECT    : Hệ Thống Quản Lý Nhân Sự & Tính Lương Tự Động
MỤC ĐÍCH   : View tổng hợp bảng lương — nguồn dữ liệu chính
             cho báo cáo, dashboard, xuất Excel
VIEWS      :
  1. vw_BangLuong          — Chi tiết lương từng NV từng kỳ
  2. vw_BangLuong_TongHop  — Tổng hợp quỹ lương theo PB/tháng
  3. vw_ThueTNCN_KyQuyetToan — Quyết toán thuế TNCN theo NV
DBMS       : MySQL 8.0+
GHI CHÚ   : Loại bỏ JOIN tới bảng ThueTNCN (không tồn tại)
             Tính ThuNhapChiuThue trực tiếp trong view
             Thay SYSTEM_USER() bằng CURRENT_USER()
*/
USE HRPayrollDB;

-- VIEW 1: vw_BangLuong
-- Chi tiết lương đầy đủ cho từng nhân viên từng kỳ
DROP VIEW IF EXISTS vw_BangLuong;

CREATE VIEW vw_BangLuong AS
SELECT
    -- Kỳ lương
    bl.Thang,
    bl.Nam,
    CONCAT(bl.Thang, '/', bl.Nam)                  AS KyLuong,

    -- Thông tin nhân viên
    nv.MaNV,
    nv.HoTen,
    nv.GioiTinh,
    pb.MaPB,
    pb.TenPB                                        AS PhongBan,
    cv.MaCV,
    cv.TenCV                                        AS ChucVu,
    cv.HeSoLuong,
    lhd.TenLoaiHD                                   AS LoaiHopDong,

    -- Ngày công
    bl.SoNgayCong                                   AS NgayDiLam,
    bl.SoNgayLamChuan                               AS NgayChuan,
    CASE WHEN bl.SoNgayLamChuan > 0
         THEN CAST(bl.SoNgayCong AS DECIMAL(10,4)) / bl.SoNgayLamChuan
         ELSE 0 END                                 AS HeSoNgayCong,

    -- Thu nhập
    bl.LuongCoBan                                   AS LuongTheoNgayCong,
    bl.TongPhuCap,
    bl.ThuNhapGop                                   AS LuongGross,

    -- Bảo hiểm NLĐ
    bl.BHXH_NLD,
    bl.BHYT_NLD,
    bl.BHTN_NLD,
    (bl.BHXH_NLD + bl.BHYT_NLD + bl.BHTN_NLD)     AS TongBH_NLD,

    -- Bảo hiểm NSDLĐ (chi phí doanh nghiệp)
    ROUND(fn_TinhBH_NSDLD(bl.LuongCoBan, hd.MaLoaiHD), 0) AS TongBH_NSDLD,

    -- Thuế TNCN
    bl.ThueTNCN,
    fn_XacDinhBacThue(
        bl.ThuNhapGop
        - bl.BHXH_NLD - bl.BHYT_NLD - bl.BHTN_NLD
        - 11000000
        - fn_TinhGiamTruPhuThuoc(nv.SoNguoiPhuThuoc)
    )                                               AS BacThue,

    -- Khấu trừ & thực lĩnh
    bl.TongKhauTru,
    bl.ThuNhapThucLinh                              AS LuongThucLinh,

    -- Chi phí tổng doanh nghiệp
    bl.ThuNhapGop
    + ROUND(fn_TinhBH_NSDLD(bl.LuongCoBan, hd.MaLoaiHD), 0) AS ChiPhiNhanSu_DN,

    -- Trạng thái & ngày
    bl.TrangThai,
    CASE bl.TrangThai
        WHEN 'D' THEN 'Nháp'
        WHEN 'C' THEN 'Đã xác nhận'
        WHEN 'P' THEN 'Đã thanh toán'
        WHEN 'L' THEN 'Đã khóa'
        ELSE bl.TrangThai
    END                                             AS TrangThaiText,
    bl.NgayTinhLuong,
    bl.NgayXacNhan,
    bl.NgayThanhToan,
    bl.NguoiTao,
    bl.MaBL
FROM
    BangLuong       bl
    JOIN NhanVien   nv  ON bl.MaNV  = nv.MaNV
    JOIN PhongBan   pb  ON nv.MaPB  = pb.MaPB
    JOIN ChucVu     cv  ON nv.MaCV  = cv.MaCV
    LEFT JOIN HopDong hd  ON nv.MaNV = hd.MaNV AND hd.TrangThai = 'A'
    LEFT JOIN LoaiHopDong lhd ON hd.MaLoaiHD = lhd.MaLoaiHD;

SELECT 'vw_BangLuong' AS Status;


-- VIEW 2: vw_BangLuong_TongHop
-- Tổng hợp quỹ lương theo Phòng Ban & kỳ lương
DROP VIEW IF EXISTS vw_BangLuong_TongHop;

CREATE VIEW vw_BangLuong_TongHop AS
SELECT
    bl.Nam,
    bl.Thang,
    pb.TenPB                                    AS PhongBan,
    COUNT(bl.MaBL)                              AS SoNhanVien,

    -- Tổng thu nhập
    SUM(bl.ThuNhapGop)                          AS TongLuongGross,
    SUM(bl.TongPhuCap)                          AS TongPhuCap,

    -- Tổng bảo hiểm
    SUM(bl.BHXH_NLD + bl.BHYT_NLD + bl.BHTN_NLD) AS TongBH_NLD,
    SUM(ROUND(fn_TinhBH_NSDLD(bl.LuongCoBan, hd.MaLoaiHD), 0)) AS TongBH_NSDLD,

    -- Tổng thuế
    SUM(bl.ThueTNCN)                            AS TongThueTNCN,

    -- Tổng khấu trừ
    SUM(bl.TongKhauTru)                         AS TongKhauTru,

    -- Tổng thực lĩnh
    SUM(bl.ThuNhapThucLinh)                     AS TongLuongNet,

    -- Chi phí nhân sự toàn bộ (Gross + BH NSDLĐ)
    SUM(bl.ThuNhapGop) + SUM(ROUND(
        fn_TinhBH_NSDLD(bl.LuongCoBan, hd.MaLoaiHD), 0
    ))                                          AS TongChiPhiNhanSu,

    -- Lương bình quân
    AVG(bl.ThuNhapThucLinh)                     AS LuongNetTrungBinh,

    -- Tình trạng
    SUM(CASE WHEN bl.TrangThai = 'D' THEN 1 ELSE 0 END) AS SoNhap,
    SUM(CASE WHEN bl.TrangThai = 'C' THEN 1 ELSE 0 END) AS SoXacNhan,
    SUM(CASE WHEN bl.TrangThai = 'P' THEN 1 ELSE 0 END) AS SoThanhToan
FROM
    BangLuong       bl
    JOIN NhanVien   nv  ON bl.MaNV = nv.MaNV
    JOIN PhongBan   pb  ON nv.MaPB = pb.MaPB
    LEFT JOIN HopDong hd  ON nv.MaNV = hd.MaNV AND hd.TrangThai = 'A'
GROUP BY
    bl.Nam, bl.Thang, pb.TenPB;

SELECT 'vw_BangLuong_TongHop' AS Status;


-- VIEW 3: vw_ThueTNCN_KyQuyetToan
-- Tổng hợp thuế TNCN theo nhân viên — dùng quyết toán cuối năm
-- (Tính trực tiếp từ BangLuong thay vì bảng ThueTNCN riêng)
DROP VIEW IF EXISTS vw_ThueTNCN_KyQuyetToan;

CREATE VIEW vw_ThueTNCN_KyQuyetToan AS
SELECT
    bl.Nam,
    nv.MaNV,
    nv.HoTen,
    nv.MaSoThue,
    pb.TenPB                                    AS PhongBan,
    COUNT(bl.MaBL)                              AS SoThangTinhThue,
    SUM(bl.ThuNhapGop)                          AS TongThuNhapGross,
    SUM(11000000)                               AS TongGiamTruBanThan, -- 11 tr/tháng
    SUM(fn_TinhGiamTruPhuThuoc(nv.SoNguoiPhuThuoc)) AS TongGiamTruPhuThuoc,
    SUM(
        bl.ThuNhapGop
        - bl.BHXH_NLD - bl.BHYT_NLD - bl.BHTN_NLD
        - 11000000
        - fn_TinhGiamTruPhuThuoc(nv.SoNguoiPhuThuoc)
    )                                           AS TongTNChiuThue,
    SUM(bl.ThueTNCN)                            AS TongThueTNCN_NamDo,
    MAX(fn_XacDinhBacThue(
        bl.ThuNhapGop
        - bl.BHXH_NLD - bl.BHYT_NLD - bl.BHTN_NLD
        - 11000000
        - fn_TinhGiamTruPhuThuoc(nv.SoNguoiPhuThuoc)
    ))                                          AS BacThueCaoNhat,
    AVG(bl.ThueTNCN)                            AS ThueTB_ThangDo
FROM
    BangLuong bl
    JOIN NhanVien nv ON bl.MaNV = nv.MaNV
    JOIN PhongBan pb ON nv.MaPB = pb.MaPB
WHERE bl.TrangThai IN ('C', 'P', 'L')
GROUP BY
    bl.Nam, nv.MaNV, nv.HoTen, nv.MaSoThue, pb.TenPB;

SELECT 'vw_ThueTNCN_KyQuyetToan' AS Status;


-- KIỂM THỬ VIEWS (sau khi chạy sp_TinhLuong)
SELECT '  KIỂM THỬ vw_BangLuong* (cần chạy sp_TinhLuong trước)' AS Status;

-- Top 5 lương cao nhất
SELECT
    KyLuong, HoTen, PhongBan, ChucVu,
    FORMAT(LuongGross,    0) AS Gross,
    FORMAT(TongBH_NLD,    0) AS BaoHiem,
    FORMAT(ThueTNCN,      0) AS Thue,
    FORMAT(LuongThucLinh, 0) AS ThucLinh,
    TrangThaiText
FROM vw_BangLuong
ORDER BY LuongThucLinh DESC
LIMIT 5;

-- Tổng hợp quỹ lương
SELECT
    Nam, Thang, PhongBan,
    SoNhanVien,
    FORMAT(TongLuongGross,   0) AS QuyLuongGross,
    FORMAT(TongBH_NSDLD,     0) AS BH_DN,
    FORMAT(TongThueTNCN,     0) AS TongThue,
    FORMAT(TongLuongNet,     0) AS QuyThucLinh,
    FORMAT(TongChiPhiNhanSu, 0) AS ChiPhiNhanSuDN
FROM vw_BangLuong_TongHop
ORDER BY Nam, Thang, TongLuongNet DESC;