-- ============================================================
-- FILE       : vw_TongHopChamCong.sql
-- PROJECT    : Hệ Thống Quản Lý Nhân Sự & Tính Lương Tự Động
-- MỤC ĐÍCH   : Views tổng hợp chấm công — nguồn dữ liệu
--              cho dashboard chuyên cần & báo cáo HR
-- VIEWS      :
--   1. vw_TongHopChamCong        — Tổng hợp tháng theo NV
--   2. vw_ChamCong_ChiTiet       — Chi tiết từng ngày
--   3. vw_TyLeChuyenCan          — Tỷ lệ chuyên cần theo PB
-- ============================================================

USE HRPayrollDB;
GO

-- ============================================================
-- VIEW 1: vw_TongHopChamCong
-- Tổng hợp ngày công từng loại theo NV × Tháng × Năm
-- Nguồn đầu vào trực tiếp cho sp_TinhLuong
-- ============================================================
IF OBJECT_ID('dbo.vw_TongHopChamCong','V') IS NOT NULL
    DROP VIEW dbo.vw_TongHopChamCong;
GO

CREATE VIEW dbo.vw_TongHopChamCong
AS
SELECT
    nv.MaNV,
    nv.HoTen,
    pb.TenPB                            AS PhongBan,
    cv.TenCV                            AS ChucVu,

    YEAR(cc.NgayCham)                   AS Nam,
    MONTH(cc.NgayCham)                  AS Thang,

    -- Ngày công theo loại
    COUNT(CASE WHEN cc.TrangThai = 'DL'  THEN 1 END) AS NgayDiLam,
    COUNT(CASE WHEN cc.TrangThai = 'WFH' THEN 1 END) AS NgayWFH,
    COUNT(CASE WHEN cc.TrangThai = 'CX'  THEN 1 END) AS NgayCongTac,
    COUNT(CASE WHEN cc.TrangThai = 'NP'  THEN 1 END) AS NgayNghiPhep,
    COUNT(CASE WHEN cc.TrangThai = 'OM'  THEN 1 END) AS NgayNghiOm,
    COUNT(CASE WHEN cc.TrangThai = 'KP'  THEN 1 END) AS NgayVangKP,
    COUNT(CASE WHEN cc.TrangThai = 'NG'  THEN 1 END) AS NgayLe,

    -- Tổng ngày tính lương (đi làm + nghỉ hưởng lương)
    COUNT(CASE WHEN cc.TrangThai IN ('DL','WFH','CX','NP','OM')
               THEN 1 END)              AS TongNgayTinhLuong,

    -- Tổng ngày trong tháng có bản ghi
    COUNT(cc.MaCC)                      AS TongBanGhi,

    -- Tăng ca
    SUM(ISNULL(cc.SoGioTangCa, 0))      AS TongGioTangCa,
    SUM(ISNULL(cc.SoGioLam, 0))         AS TongGioLam,
    AVG(ISNULL(cc.SoGioLam, 0))         AS GioLamTB,

    -- Tỷ lệ chuyên cần (%)
    CASE WHEN dbo.fn_SoNgayChuanThang(
                MONTH(cc.NgayCham),YEAR(cc.NgayCham)) > 0
         THEN CAST(
             COUNT(CASE WHEN cc.TrangThai IN ('DL','WFH','CX') THEN 1 END)
             AS DECIMAL(10,4))
             / dbo.fn_SoNgayChuanThang(
                 MONTH(cc.NgayCham),YEAR(cc.NgayCham))
         ELSE 0
    END                                 AS TyLeChuyenCan
FROM
    dbo.ChamCong    cc
    JOIN dbo.NhanVien nv ON cc.MaNV = nv.MaNV
    JOIN dbo.PhongBan pb ON nv.MaPB = pb.MaPB
    JOIN dbo.ChucVu   cv ON nv.MaCV = cv.MaCV
GROUP BY
    nv.MaNV, nv.HoTen, pb.TenPB, cv.TenCV,
    YEAR(cc.NgayCham), MONTH(cc.NgayCham);
GO

PRINT N'[OK] vw_TongHopChamCong';
GO

-- ============================================================
-- VIEW 2: vw_ChamCong_ChiTiet
-- Chi tiết từng ngày — dùng cho NV tự tra cứu
-- ============================================================
IF OBJECT_ID('dbo.vw_ChamCong_ChiTiet','V') IS NOT NULL
    DROP VIEW dbo.vw_ChamCong_ChiTiet;
GO

CREATE VIEW dbo.vw_ChamCong_ChiTiet
AS
SELECT
    cc.MaCC,
    nv.MaNV,
    nv.HoTen,
    pb.TenPB                            AS PhongBan,
    cc.NgayCham,
    DATENAME(WEEKDAY, cc.NgayCham)      AS ThuTrongTuan,
    cc.TrangThai,
    CASE cc.TrangThai
        WHEN 'DL'  THEN N'Đi làm'
        WHEN 'WFH' THEN N'Làm từ xa'
        WHEN 'CX'  THEN N'Công tác xa'
        WHEN 'NP'  THEN N'Nghỉ phép hưởng lương'
        WHEN 'OM'  THEN N'Nghỉ ốm'
        WHEN 'KP'  THEN N'Vắng không phép'
        WHEN 'NG'  THEN N'Nghỉ lễ / Tết'
        ELSE cc.TrangThai
    END                                 AS TrangThaiText,
    FORMAT(cc.GioVao,'HH:mm')           AS GioVao,
    FORMAT(cc.GioRa, 'HH:mm')           AS GioRa,
    ISNULL(cc.SoGioLam, 0)              AS SoGioLam,
    ISNULL(cc.SoGioTangCa, 0)           AS SoGioTangCa,
    cc.HeSoTangCa,
    cc.GhiChu,
    cc.NguoiCapNhat,
    YEAR(cc.NgayCham)                   AS Nam,
    MONTH(cc.NgayCham)                  AS Thang
FROM
    dbo.ChamCong    cc
    JOIN dbo.NhanVien nv ON cc.MaNV = nv.MaNV
    JOIN dbo.PhongBan pb ON nv.MaPB = pb.MaPB;
GO

PRINT N'[OK] vw_ChamCong_ChiTiet';
GO

-- ============================================================
-- VIEW 3: vw_TyLeChuyenCan
-- Tỷ lệ chuyên cần theo phòng ban × tháng
-- Dùng cho dashboard HR và KPI bộ phận
-- ============================================================
IF OBJECT_ID('dbo.vw_TyLeChuyenCan','V') IS NOT NULL
    DROP VIEW dbo.vw_TyLeChuyenCan;
GO

CREATE VIEW dbo.vw_TyLeChuyenCan
AS
SELECT
    thcc.Nam,
    thcc.Thang,
    thcc.PhongBan,
    COUNT(thcc.MaNV)                    AS SoNhanVien,
    SUM(thcc.NgayDiLam + thcc.NgayWFH + thcc.NgayCongTac) AS TongNgayDiLam,
    SUM(thcc.NgayNghiPhep)              AS TongNghiPhep,
    SUM(thcc.NgayNghiOm)                AS TongNghiOm,
    SUM(thcc.NgayVangKP)                AS TongVangKP,
    SUM(thcc.TongGioTangCa)             AS TongGioTangCa,
    AVG(thcc.TyLeChuyenCan)             AS TyLeChuyenCanTB,
    MIN(thcc.TyLeChuyenCan)             AS TyLeThap_Nhat,
    MAX(thcc.TyLeChuyenCan)             AS TyLeCao_Nhat,
    -- NV chuyên cần < 80%
    COUNT(CASE WHEN thcc.TyLeChuyenCan < 0.8 THEN 1 END)
                                        AS SoNV_TyLe_LT_80pct
FROM
    dbo.vw_TongHopChamCong thcc
GROUP BY
    thcc.Nam, thcc.Thang, thcc.PhongBan;
GO

PRINT N'[OK] vw_TyLeChuyenCan';
GO

-- ============================================================
-- KIỂM THỬ VIEWS
-- ============================================================
PRINT N'';
PRINT N'════════════════════════════════════════════════════════';
PRINT N'  KIỂM THỬ VIEWS CHẤM CÔNG';
PRINT N'════════════════════════════════════════════════════════';

-- Tổng hợp chấm công tháng 1/2025 top 5 NV tăng ca nhiều nhất
SELECT TOP 5
    HoTen, PhongBan, Nam, Thang,
    NgayDiLam, NgayWFH, NgayNghiPhep, NgayVangKP,
    TongGioTangCa,
    FORMAT(TyLeChuyenCan,'P1') AS ChuyenCan
FROM dbo.vw_TongHopChamCong
WHERE Thang = 1 AND Nam = 2025
ORDER BY TongGioTangCa DESC;
GO

-- Tỷ lệ chuyên cần theo phòng ban tháng 1-3/2025
SELECT
    Nam, Thang, PhongBan,
    SoNhanVien,
    TongVangKP,
    FORMAT(TyLeChuyenCanTB, 'P1')  AS ChuyenCanTB,
    FORMAT(TyLeThap_Nhat,   'P1')  AS TyLeThapNhat,
    SoNV_TyLe_LT_80pct             AS NV_Kem_Chuyen_Can
FROM dbo.vw_TyLeChuyenCan
ORDER BY Nam, Thang, PhongBan;
GO

-- Cá nhân NV000049 - người vắng không phép
SELECT
    HoTen, PhongBan, Thang, Nam,
    NgayDiLam, NgayVangKP,
    FORMAT(TyLeChuyenCan,'P1') ChuyenCan
FROM dbo.vw_TongHopChamCong
WHERE MaNV = 'NV000049'
ORDER BY Nam, Thang;
GO

PRINT N'[DONE] vw_TongHopChamCong.sql — 3 views hoàn tất';
GO
