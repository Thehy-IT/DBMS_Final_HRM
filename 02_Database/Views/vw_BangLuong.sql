-- ============================================================
-- FILE       : vw_BangLuong.sql
-- PROJECT    : Hệ Thống Quản Lý Nhân Sự & Tính Lương Tự Động
-- MỤC ĐÍCH   : View tổng hợp bảng lương — nguồn dữ liệu chính
--              cho báo cáo, dashboard, xuất Excel
-- VIEWS      :
--   1. vw_BangLuong          — Chi tiết lương từng NV từng kỳ
--   2. vw_BangLuong_TongHop  — Tổng hợp quỹ lương theo PB/tháng
--   3. vw_ThueTNCN_KyQuyetToan — Quyết toán thuế TNCN theo NV
-- ============================================================

USE HRPayrollDB;
GO

-- ============================================================
-- VIEW 1: vw_BangLuong
-- Chi tiết lương đầy đủ cho từng nhân viên từng kỳ
-- JOIN: BangLuong + NhanVien + PhongBan + ChucVu + LoaiHopDong
-- ============================================================
IF OBJECT_ID('dbo.vw_BangLuong','V') IS NOT NULL
    DROP VIEW dbo.vw_BangLuong;
GO

CREATE VIEW dbo.vw_BangLuong
AS
SELECT
    -- Kỳ lương
    bl.Thang,
    bl.Nam,
    CAST(bl.Thang AS NVARCHAR) + N'/' + CAST(bl.Nam AS NVARCHAR)
                                            AS KyLuong,

    -- Thông tin nhân viên
    nv.MaNV,
    nv.HoTen,
    nv.GioiTinh,
    pb.MaPB,
    pb.TenPB                               AS PhongBan,
    cv.MaCV,
    cv.TenCV                               AS ChucVu,
    cv.HeSoLuong,
    lhd.TenLoaiHD                          AS LoaiHopDong,

    -- Ngày công
    bl.SoNgayCong                          AS NgayDiLam,
    bl.SoNgayLamChuan                      AS NgayChuan,
    CASE WHEN bl.SoNgayLamChuan > 0
         THEN CAST(bl.SoNgayCong AS DECIMAL(10,4))
              / bl.SoNgayLamChuan
         ELSE 0 END                        AS HeSoNgayCong,

    -- Thu nhập
    bl.LuongCoBan                          AS LuongTheoNgayCong,
    bl.TongPhuCap,
    bl.LuongGross,

    -- Bảo hiểm NLĐ
    bl.BHXH_NLD,
    bl.BHYT_NLD,
    bl.BHTN_NLD,
    bl.TongBaoHiem                         AS TongBH_NLD,

    -- Bảo hiểm NSDLĐ (chi phí doanh nghiệp)
    ROUND(dbo.fn_TinhBH_NSDLD(bl.LuongCoBan, hd.MaLoaiHD), 0)
                                           AS TongBH_NSDLD,

    -- Thuế TNCN
    tt.ThuNhapChiuThue,
    tt.BacThue,
    bl.ThueTNCN,

    -- Khấu trừ & thực lĩnh
    bl.TongKhauTru,
    bl.LuongNet                            AS LuongThucLinh,

    -- Chi phí tổng doanh nghiệp
    bl.LuongGross
    + ROUND(dbo.fn_TinhBH_NSDLD(bl.LuongCoBan, hd.MaLoaiHD), 0)
                                           AS ChiPhiNhanSu_DN,

    -- Trạng thái & ngày
    bl.TrangThai,
    CASE bl.TrangThai
        WHEN 'D' THEN N'Nháp'
        WHEN 'C' THEN N'Đã xác nhận'
        WHEN 'P' THEN N'Đã thanh toán'
        WHEN 'L' THEN N'Đã khóa'
        ELSE bl.TrangThai
    END                                    AS TrangThaiText,
    bl.NgayTinhLuong,
    bl.NgayXacNhan,
    bl.NgayThanhToan,
    bl.NguoiTao,
    bl.MaBL
FROM
    dbo.BangLuong       bl
    JOIN dbo.NhanVien   nv  ON bl.MaNV  = nv.MaNV
    JOIN dbo.PhongBan   pb  ON nv.MaPB  = pb.MaPB
    JOIN dbo.ChucVu     cv  ON nv.MaCV  = cv.MaCV
    LEFT JOIN dbo.HopDong hd ON nv.MaNV = hd.MaNV
                             AND hd.TrangThai = 'A'
    LEFT JOIN dbo.LoaiHopDong lhd ON hd.MaLoaiHD = lhd.MaLoaiHD
    LEFT JOIN dbo.ThueTNCN tt ON bl.MaBL = tt.MaBL;
GO

PRINT N'[OK] vw_BangLuong';
GO

-- ============================================================
-- VIEW 2: vw_BangLuong_TongHop
-- Tổng hợp quỹ lương theo Phòng Ban & kỳ lương
-- Dùng cho dashboard tài chính, so sánh tháng
-- ============================================================
IF OBJECT_ID('dbo.vw_BangLuong_TongHop','V') IS NOT NULL
    DROP VIEW dbo.vw_BangLuong_TongHop;
GO

CREATE VIEW dbo.vw_BangLuong_TongHop
AS
SELECT
    bl.Nam,
    bl.Thang,
    pb.TenPB                            AS PhongBan,
    COUNT(bl.MaBL)                      AS SoNhanVien,

    -- Tổng thu nhập
    SUM(bl.LuongGross)                  AS TongLuongGross,
    SUM(bl.TongPhuCap)                  AS TongPhuCap,

    -- Tổng bảo hiểm
    SUM(bl.TongBaoHiem)                 AS TongBH_NLD,
    SUM(ROUND(
        dbo.fn_TinhBH_NSDLD(bl.LuongCoBan, hd.MaLoaiHD), 0
    ))                                  AS TongBH_NSDLD,

    -- Tổng thuế
    SUM(bl.ThueTNCN)                    AS TongThueTNCN,

    -- Tổng khấu trừ
    SUM(bl.TongKhauTru)                 AS TongKhauTru,

    -- Tổng thực lĩnh
    SUM(bl.LuongNet)                    AS TongLuongNet,

    -- Chi phí nhân sự toàn bộ (Gross + BH NSDLĐ)
    SUM(bl.LuongGross) + SUM(ROUND(
        dbo.fn_TinhBH_NSDLD(bl.LuongCoBan, hd.MaLoaiHD), 0
    ))                                  AS TongChiPhiNhanSu,

    -- Lương bình quân
    AVG(bl.LuongNet)                    AS LuongNetTrungBinh,

    -- Tình trạng
    COUNT(CASE WHEN bl.TrangThai = 'D' THEN 1 END) AS SoNhap,
    COUNT(CASE WHEN bl.TrangThai = 'C' THEN 1 END) AS SoXacNhan,
    COUNT(CASE WHEN bl.TrangThai = 'P' THEN 1 END) AS SoThanhToan
FROM
    dbo.BangLuong       bl
    JOIN dbo.NhanVien   nv  ON bl.MaNV = nv.MaNV
    JOIN dbo.PhongBan   pb  ON nv.MaPB = pb.MaPB
    LEFT JOIN dbo.HopDong hd ON nv.MaNV = hd.MaNV
                             AND hd.TrangThai = 'A'
GROUP BY
    bl.Nam, bl.Thang, pb.TenPB;
GO

PRINT N'[OK] vw_BangLuong_TongHop';
GO

-- ============================================================
-- VIEW 3: vw_ThueTNCN_KyQuyetToan
-- Tổng hợp thuế TNCN theo nhân viên — dùng quyết toán cuối năm
-- ============================================================
IF OBJECT_ID('dbo.vw_ThueTNCN_KyQuyetToan','V') IS NOT NULL
    DROP VIEW dbo.vw_ThueTNCN_KyQuyetToan;
GO

CREATE VIEW dbo.vw_ThueTNCN_KyQuyetToan
AS
SELECT
    tt.Nam,
    nv.MaNV,
    nv.HoTen,
    nv.MaSoThue,
    pb.TenPB                            AS PhongBan,
    COUNT(tt.MaTT)                      AS SoThangTinhThue,
    SUM(tt.ThuNhapGross)                AS TongThuNhapGross,
    SUM(tt.GiamTruBanThan)              AS TongGiamTruBanThan,
    SUM(tt.GiamTruPhuThuoc)             AS TongGiamTruPhuThuoc,
    SUM(tt.ThuNhapChiuThue)             AS TongTNChiuThue,
    SUM(tt.TienThue)                    AS TongThueTNCN_NamDo,
    MAX(tt.BacThue)                     AS BacThueCaoNhat,
    AVG(tt.TienThue)                    AS ThueTB_ThangDo
FROM
    dbo.ThueTNCN tt
    JOIN dbo.NhanVien nv ON tt.MaNV = nv.MaNV
    JOIN dbo.PhongBan pb ON nv.MaPB = pb.MaPB
GROUP BY
    tt.Nam, nv.MaNV, nv.HoTen, nv.MaSoThue, pb.TenPB;
GO

PRINT N'[OK] vw_ThueTNCN_KyQuyetToan';
GO

-- ============================================================
-- KIỂM THỬ VIEWS (sau khi chạy sp_TinhLuong)
-- ============================================================
PRINT N'';
PRINT N'════════════════════════════════════════════════════════';
PRINT N'  KIỂM THỬ vw_BangLuong* (cần chạy sp_TinhLuong trước)';
PRINT N'════════════════════════════════════════════════════════';

-- Top 5 lương cao nhất
SELECT TOP 5
    KyLuong, HoTen, PhongBan, ChucVu,
    FORMAT(LuongGross,    'N0') AS Gross,
    FORMAT(TongBH_NLD,    'N0') AS BaoHiem,
    FORMAT(ThueTNCN,      'N0') AS Thue,
    FORMAT(LuongThucLinh, 'N0') AS ThucLinh,
    TrangThaiText
FROM dbo.vw_BangLuong
ORDER BY LuongThucLinh DESC;
GO

-- Tổng hợp quỹ lương
SELECT
    Nam, Thang, PhongBan,
    SoNhanVien,
    FORMAT(TongLuongGross,   'N0') AS QuyLuongGross,
    FORMAT(TongBH_NSDLD,     'N0') AS BH_DN,
    FORMAT(TongThueTNCN,     'N0') AS TongThue,
    FORMAT(TongLuongNet,     'N0') AS QuyThucLinh,
    FORMAT(TongChiPhiNhanSu, 'N0') AS ChiPhiNhanSuDN
FROM dbo.vw_BangLuong_TongHop
ORDER BY Nam, Thang, TongLuongNet DESC;
GO

PRINT N'[DONE] vw_BangLuong.sql — 3 views hoàn tất';
GO
