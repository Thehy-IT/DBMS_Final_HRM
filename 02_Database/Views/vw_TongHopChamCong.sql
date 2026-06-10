/*
-- PROJECT    : Hệ Thống Quản Lý Nhân Sự & Tính Lương Tự Động
-- MỤC ĐÍCH   : Views tổng hợp chấm công
-- VIEWS      :
--   1. vw_TongHopChamCong        — Tổng hợp tháng theo NV
--   2. vw_ChamCong_ChiTiet       — Chi tiết từng ngày
--   3. vw_TyLeChuyenCan          — Tỷ lệ chuyên cần theo PB
-- DBMS       : MySQL 8.0+
-- GHI CHÚ   : DATENAME(WEEKDAY) → DAYNAME() trong MySQL
--              FORMAT(time, 'HH:mm') → TIME_FORMAT(time, '%H:%i')
*/

USE HRPayrollDB;

-- VIEW 1: vw_TongHopChamCong
-- Tổng hợp ngày công từng loại theo NV × Tháng × Năm
DROP VIEW IF EXISTS vw_TongHopChamCong;

CREATE VIEW vw_TongHopChamCong AS
SELECT
    nv.MaNV,
    nv.HoTen,
    pb.TenPB                                AS PhongBan,
    cv.TenCV                                AS ChucVu,

    YEAR(cc.NgayCham)                       AS Nam,
    MONTH(cc.NgayCham)                      AS Thang,

    -- Ngày công theo loại
    SUM(CASE WHEN cc.TrangThai = 'DL'  THEN 1 ELSE 0 END) AS NgayDiLam,
    SUM(CASE WHEN cc.TrangThai = 'WFH' THEN 1 ELSE 0 END) AS NgayWFH,
    SUM(CASE WHEN cc.TrangThai = 'CX'  THEN 1 ELSE 0 END) AS NgayCongTac,
    SUM(CASE WHEN cc.TrangThai = 'NP'  THEN 1 ELSE 0 END) AS NgayNghiPhep,
    SUM(CASE WHEN cc.TrangThai = 'OM'  THEN 1 ELSE 0 END) AS NgayNghiOm,
    SUM(CASE WHEN cc.TrangThai = 'KP'  THEN 1 ELSE 0 END) AS NgayVangKP,
    SUM(CASE WHEN cc.TrangThai = 'NG'  THEN 1 ELSE 0 END) AS NgayLe,

    -- Tổng ngày tính lương (đi làm + nghỉ hưởng lương)
    SUM(CASE WHEN cc.TrangThai IN ('DL','WFH','CX','NP','OM')
             THEN 1 ELSE 0 END)             AS TongNgayTinhLuong,

    -- Tổng ngày trong tháng có bản ghi
    COUNT(cc.MaCC)                          AS TongBanGhi,

    -- Tăng ca
    SUM(IFNULL(cc.SoGioTangCa, 0))         AS TongGioTangCa,
    SUM(IFNULL(cc.SoGioLam, 0))            AS TongGioLam,
    AVG(IFNULL(cc.SoGioLam, 0))            AS GioLamTB,

    -- Tỷ lệ chuyên cần (%)
    CASE WHEN fn_SoNgayChuanThang(
                MONTH(cc.NgayCham), YEAR(cc.NgayCham)) > 0
         THEN CAST(
             SUM(CASE WHEN cc.TrangThai IN ('DL','WFH','CX') THEN 1 ELSE 0 END)
             AS DECIMAL(10,4))
             / fn_SoNgayChuanThang(MONTH(cc.NgayCham), YEAR(cc.NgayCham))
         ELSE 0
    END                                     AS TyLeChuyenCan
FROM
    ChamCong    cc
    JOIN NhanVien nv ON cc.MaNV = nv.MaNV
    JOIN PhongBan pb ON nv.MaPB = pb.MaPB
    JOIN ChucVu   cv ON nv.MaCV = cv.MaCV
GROUP BY
    nv.MaNV, nv.HoTen, pb.TenPB, cv.TenCV,
    YEAR(cc.NgayCham), MONTH(cc.NgayCham);

SELECT 'vw_TongHopChamCong' AS Status;


-- VIEW 2: vw_ChamCong_ChiTiet
-- Chi tiết từng ngày — dùng cho NV tự tra cứu
DROP VIEW IF EXISTS vw_ChamCong_ChiTiet;

CREATE VIEW vw_ChamCong_ChiTiet AS
SELECT
    cc.MaCC,
    nv.MaNV,
    nv.HoTen,
    pb.TenPB                                AS PhongBan,
    cc.NgayCham,
    DAYNAME(cc.NgayCham)                    AS ThuTrongTuan,
    cc.TrangThai,
    CASE cc.TrangThai
        WHEN 'DL'  THEN 'Đi làm'
        WHEN 'WFH' THEN 'Làm từ xa'
        WHEN 'CX'  THEN 'Công tác xa'
        WHEN 'NP'  THEN 'Nghỉ phép hưởng lương'
        WHEN 'OM'  THEN 'Nghỉ ốm'
        WHEN 'KP'  THEN 'Vắng không phép'
        WHEN 'NG'  THEN 'Nghỉ lễ / Tết'
        ELSE cc.TrangThai
    END                                     AS TrangThaiText,
    TIME_FORMAT(cc.GioVao, '%H:%i')         AS GioVao,
    TIME_FORMAT(cc.GioRa,  '%H:%i')         AS GioRa,
    IFNULL(cc.SoGioLam, 0)                 AS SoGioLam,
    IFNULL(cc.SoGioTangCa, 0)              AS SoGioTangCa,
    cc.HeSoTangCa,
    cc.GhiChu,
    cc.NguoiCapNhat,
    YEAR(cc.NgayCham)                       AS Nam,
    MONTH(cc.NgayCham)                      AS Thang
FROM
    ChamCong    cc
    JOIN NhanVien nv ON cc.MaNV = nv.MaNV
    JOIN PhongBan pb ON nv.MaPB = pb.MaPB;

SELECT 'vw_ChamCong_ChiTiet' AS Status;


-- VIEW 3: vw_TyLeChuyenCan
-- Tỷ lệ chuyên cần theo phòng ban × tháng
DROP VIEW IF EXISTS vw_TyLeChuyenCan;

CREATE VIEW vw_TyLeChuyenCan AS
SELECT
    thcc.Nam,
    thcc.Thang,
    thcc.PhongBan,
    COUNT(thcc.MaNV)                        AS SoNhanVien,
    SUM(thcc.NgayDiLam + thcc.NgayWFH + thcc.NgayCongTac) AS TongNgayDiLam,
    SUM(thcc.NgayNghiPhep)                  AS TongNghiPhep,
    SUM(thcc.NgayNghiOm)                    AS TongNghiOm,
    SUM(thcc.NgayVangKP)                    AS TongVangKP,
    SUM(thcc.TongGioTangCa)                 AS TongGioTangCa,
    AVG(thcc.TyLeChuyenCan)                 AS TyLeChuyenCanTB,
    MIN(thcc.TyLeChuyenCan)                 AS TyLeThap_Nhat,
    MAX(thcc.TyLeChuyenCan)                 AS TyLeCao_Nhat,
    -- NV chuyên cần < 80%
    SUM(CASE WHEN thcc.TyLeChuyenCan < 0.8 THEN 1 ELSE 0 END)
                                            AS SoNV_TyLe_LT_80pct
FROM
    vw_TongHopChamCong thcc
GROUP BY
    thcc.Nam, thcc.Thang, thcc.PhongBan;

SELECT 'vw_TyLeChuyenCan' AS Status;


-- KIỂM THỬ VIEWS
SELECT '  KIỂM THỬ VIEWS CHẤM CÔNG' AS Status;

-- Tổng hợp chấm công tháng 1/2025 top 5 NV tăng ca nhiều nhất
SELECT
    HoTen, PhongBan, Nam, Thang,
    NgayDiLam, NgayWFH, NgayNghiPhep, NgayVangKP,
    TongGioTangCa,
    CONCAT(FORMAT(TyLeChuyenCan * 100, 1), '%') AS ChuyenCan
FROM vw_TongHopChamCong
WHERE Thang = 1 AND Nam = 2025
ORDER BY TongGioTangCa DESC
LIMIT 5;

-- Tỷ lệ chuyên cần theo phòng ban tháng 1-3/2025
SELECT
    Nam, Thang, PhongBan,
    SoNhanVien,
    TongVangKP,
    CONCAT(FORMAT(TyLeChuyenCanTB * 100, 1), '%') AS ChuyenCanTB,
    CONCAT(FORMAT(TyLeThap_Nhat  * 100, 1), '%') AS TyLeThapNhat,
    SoNV_TyLe_LT_80pct                            AS NV_Kem_Chuyen_Can
FROM vw_TyLeChuyenCan
ORDER BY Nam, Thang, PhongBan;