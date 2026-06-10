/*
PROJECT    : Hệ Thống Quản Lý Nhân Sự & Tính Lương Tự Động
MỤC ĐÍCH   : Bộ báo cáo nhân sự toàn diện phục vụ Ban Lãnh Đạo,
             HR Manager và Kế Toán Trưởng
PROCEDURES :
  1. sp_BaoCaoNhanSu_TongQuan        — Dashboard nhân sự tổng hợp
  2. sp_BaoCaoNhanSu_TheoPhongBan    — Phân tích cơ cấu theo PB/CV
  3. sp_BaoCaoNhanSu_HopDong         — Trạng thái & sắp hết hạn HĐ
  4. sp_BaoCaoNhanSu_BienDong        — Tuyển mới / nghỉ việc theo kỳ
  5. sp_BaoCaoNhanSu_LuongPhanPhoi   — Phân phối lương & xếp hạng
  6. sp_BaoCaoNhanSu_NghiPhepNam     — Quản lý phép năm tồn dư
DBMS       : MySQL 8.0+
GHI CHÚ   : DATEDIFF(YEAR/MONTH) → TIMESTAMPDIFF(YEAR/MONTH)
             DATEADD → DATE_ADD / DATE_SUB
             ISNULL → IFNULL
             FORMAT(n,'N0') → FORMAT(n, 0)
             CONVERT(NVARCHAR, date, 103) → DATE_FORMAT(date,'%d/%m/%Y')
*/
USE HRPayrollDB;

-- SP 1: sp_BaoCaoNhanSu_TongQuan
DROP PROCEDURE IF EXISTS sp_BaoCaoNhanSu_TongQuan;

DELIMITER $$
CREATE PROCEDURE sp_BaoCaoNhanSu_TongQuan(
    IN p_ThoiDiem DATE
)
BEGIN
    IF p_ThoiDiem IS NULL THEN
        SET p_ThoiDiem = CURDATE();
    END IF;

    -- RS1: Số liệu tổng quan
    SELECT
        COUNT(*)                                        AS TongNhanVien,
        SUM(CASE WHEN TrangThai = 'A' THEN 1 ELSE 0 END) AS DangLamViec,
        SUM(CASE WHEN TrangThai = 'P' THEN 1 ELSE 0 END) AS ThuViec,
        SUM(CASE WHEN TrangThai = 'L' THEN 1 ELSE 0 END) AS NghiThaiSan,
        SUM(CASE WHEN TrangThai = 'T' THEN 1 ELSE 0 END) AS DaNghiViec,
        SUM(CASE WHEN GioiTinh = 'M'
                  AND TrangThai IN ('A','P','L') THEN 1 ELSE 0 END) AS Nam,
        SUM(CASE WHEN GioiTinh = 'F'
                  AND TrangThai IN ('A','P','L') THEN 1 ELSE 0 END) AS Nu,
        FORMAT(AVG(CAST(
            TIMESTAMPDIFF(YEAR, NgaySinh, p_ThoiDiem) AS DECIMAL(5,1))), 1)
                                                        AS TuoiTB,
        CONCAT(FORMAT(AVG(CAST(
            TIMESTAMPDIFF(MONTH, NgayVaoLam, p_ThoiDiem) AS DECIMAL(6,1))
            / 12.0), 1), ' năm')                        AS ThamNienTB,
        SUM(CASE WHEN NgayVaoLam >= DATE_SUB(p_ThoiDiem, INTERVAL 30 DAY)
                 THEN 1 ELSE 0 END)                     AS MoiVao30Ngay,
        SUM(CASE WHEN NgayNghiViec >= DATE_SUB(p_ThoiDiem, INTERVAL 30 DAY)
                 THEN 1 ELSE 0 END)                     AS NghiViec30Ngay
    FROM NhanVien;

    -- RS2: Cơ cấu theo nhóm tuổi
    SELECT
        CASE
            WHEN TIMESTAMPDIFF(YEAR, NgaySinh, p_ThoiDiem) < 25 THEN 'Dưới 25'
            WHEN TIMESTAMPDIFF(YEAR, NgaySinh, p_ThoiDiem) < 30 THEN '25 – 29'
            WHEN TIMESTAMPDIFF(YEAR, NgaySinh, p_ThoiDiem) < 35 THEN '30 – 34'
            WHEN TIMESTAMPDIFF(YEAR, NgaySinh, p_ThoiDiem) < 40 THEN '35 – 39'
            WHEN TIMESTAMPDIFF(YEAR, NgaySinh, p_ThoiDiem) < 50 THEN '40 – 49'
            ELSE '50+'
        END                                             AS NhomTuoi,
        COUNT(*)                                        AS SoNhanVien,
        SUM(CASE WHEN GioiTinh = 'M' THEN 1 ELSE 0 END) AS Nam,
        SUM(CASE WHEN GioiTinh = 'F' THEN 1 ELSE 0 END) AS Nu
    FROM NhanVien
    WHERE TrangThai IN ('A','P','L')
    GROUP BY NhomTuoi
    ORDER BY NhomTuoi;

    -- RS3: Cơ cấu theo thâm niên
    SELECT
        CASE
            WHEN TIMESTAMPDIFF(YEAR, NgayVaoLam, p_ThoiDiem) < 1   THEN 'Dưới 1 năm'
            WHEN TIMESTAMPDIFF(YEAR, NgayVaoLam, p_ThoiDiem) < 3   THEN '1 – 2 năm'
            WHEN TIMESTAMPDIFF(YEAR, NgayVaoLam, p_ThoiDiem) < 5   THEN '3 – 4 năm'
            WHEN TIMESTAMPDIFF(YEAR, NgayVaoLam, p_ThoiDiem) < 10  THEN '5 – 9 năm'
            ELSE '10+ năm'
        END                                             AS NhomThamNien,
        COUNT(*)                                        AS SoNhanVien
    FROM NhanVien
    WHERE TrangThai IN ('A','P','L')
    GROUP BY NhomThamNien
    ORDER BY NhomThamNien;

    -- RS4: Phân bổ theo phòng ban
    SELECT
        pb.TenPB                                        AS PhongBan,
        COUNT(nv.MaNV)                                  AS SoNhanVien,
        SUM(CASE WHEN nv.GioiTinh = 'M' THEN 1 ELSE 0 END) AS Nam,
        SUM(CASE WHEN nv.GioiTinh = 'F' THEN 1 ELSE 0 END) AS Nu,
        FORMAT(AVG(CAST(
            TIMESTAMPDIFF(YEAR, nv.NgaySinh, p_ThoiDiem) AS DECIMAL(5,1))), 1) AS TuoiTB
    FROM NhanVien nv
    JOIN PhongBan pb ON nv.MaPB = pb.MaPB
    WHERE nv.TrangThai IN ('A','P','L')
    GROUP BY pb.TenPB
    ORDER BY SoNhanVien DESC;

    -- RS5: Phân bổ theo chức vụ
    SELECT
        cv.TenCV                                        AS ChucVu,
        cv.CapBac,
        FORMAT(cv.HeSoLuong, 2)                         AS HeSoLuong,
        COUNT(nv.MaNV)                                  AS SoNhanVien
    FROM NhanVien nv
    JOIN ChucVu   cv ON nv.MaCV = cv.MaCV
    WHERE nv.TrangThai IN ('A','P','L')
    GROUP BY cv.TenCV, cv.CapBac, cv.HeSoLuong
    ORDER BY cv.CapBac DESC;
END$$

DELIMITER ;

SELECT 'sp_BaoCaoNhanSu_TongQuan' AS Status;


-- SP 2: sp_BaoCaoNhanSu_TheoPhongBan
DROP PROCEDURE IF EXISTS sp_BaoCaoNhanSu_TheoPhongBan;

DELIMITER $$
CREATE PROCEDURE sp_BaoCaoNhanSu_TheoPhongBan(
    IN p_MaPB     VARCHAR(6),   -- NULL = tất cả
    IN p_ThoiDiem DATE
)
BEGIN
    IF p_ThoiDiem IS NULL THEN SET p_ThoiDiem = CURDATE(); END IF;

    SELECT
        pb.TenPB                                        AS PhongBan,
        nv.MaNV,
        nv.HoTen,
        CASE nv.GioiTinh WHEN 'M' THEN 'Nam' ELSE 'Nữ' END AS GioiTinh,
        TIMESTAMPDIFF(YEAR, nv.NgaySinh, p_ThoiDiem)   AS Tuoi,
        DATE_FORMAT(nv.NgayVaoLam, '%d/%m/%Y')          AS NgayVaoLam,
        CONCAT(TIMESTAMPDIFF(YEAR, nv.NgayVaoLam, p_ThoiDiem),
               ' năm')                                  AS ThamNien,
        cv.TenCV                                        AS ChucVu,
        cv.CapBac,
        lhd.TenLoaiHD                                   AS LoaiHopDong,
        CASE nv.TrangThai
            WHEN 'A' THEN 'Đang làm việc'
            WHEN 'P' THEN 'Thử việc'
            WHEN 'L' THEN 'Nghỉ thai sản'
            ELSE 'Khác'
        END                                             AS TrangThaiNV
    FROM NhanVien nv
    JOIN PhongBan    pb  ON nv.MaPB = pb.MaPB
    JOIN ChucVu      cv  ON nv.MaCV = cv.MaCV
    LEFT JOIN HopDong hd  ON nv.MaNV = hd.MaNV AND hd.TrangThai = 'A'
    LEFT JOIN LoaiHopDong lhd ON hd.MaLoaiHD = lhd.MaLoaiHD
    WHERE nv.TrangThai IN ('A','P','L')
      AND (p_MaPB IS NULL OR nv.MaPB = p_MaPB)
    ORDER BY pb.TenPB, cv.CapBac DESC, nv.HoTen;
END$$

DELIMITER ;

SELECT 'sp_BaoCaoNhanSu_TheoPhongBan' AS Status;


-- SP 3: sp_BaoCaoNhanSu_HopDong
DROP PROCEDURE IF EXISTS sp_BaoCaoNhanSu_HopDong;

DELIMITER $$
CREATE PROCEDURE sp_BaoCaoNhanSu_HopDong(
    IN p_SoNgayCanhBao INT   -- HĐ hết hạn trong N ngày tới
)
BEGIN
    IF p_SoNgayCanhBao IS NULL THEN SET p_SoNgayCanhBao = 30; END IF;

    -- RS1: Thống kê trạng thái HĐ
    SELECT
        lhd.TenLoaiHD                               AS LoaiHopDong,
        SUM(CASE WHEN hd.TrangThai = 'A' THEN 1 ELSE 0 END) AS DangHieuLuc,
        SUM(CASE WHEN hd.TrangThai = 'D' THEN 1 ELSE 0 END) AS NhapLieu,
        SUM(CASE WHEN hd.TrangThai = 'E' THEN 1 ELSE 0 END) AS DaHetHan,
        SUM(CASE WHEN hd.TrangThai = 'T' THEN 1 ELSE 0 END) AS DaChamDut,
        COUNT(*)                                    AS Tong
    FROM HopDong hd
    JOIN LoaiHopDong lhd ON hd.MaLoaiHD = lhd.MaLoaiHD
    GROUP BY lhd.TenLoaiHD
    ORDER BY Tong DESC;

    -- RS2: HĐ sắp hết hạn
    SELECT
        nv.MaNV,
        nv.HoTen,
        pb.TenPB                                    AS PhongBan,
        lhd.TenLoaiHD                               AS LoaiHopDong,
        DATE_FORMAT(hd.NgayBatDau, '%d/%m/%Y')      AS NgayBatDau,
        DATE_FORMAT(hd.NgayKetThuc, '%d/%m/%Y')     AS NgayKetThuc,
        DATEDIFF(hd.NgayKetThuc, CURDATE())         AS ConLaiNgay,
        FORMAT(hd.LuongCoBan, 0)                    AS LuongCoBan,
        CASE
            WHEN DATEDIFF(hd.NgayKetThuc, CURDATE()) < 0   THEN 'Đã hết hạn'
            WHEN DATEDIFF(hd.NgayKetThuc, CURDATE()) < 7   THEN 'Hết hạn trong 7 ngày'
            WHEN DATEDIFF(hd.NgayKetThuc, CURDATE()) < 14  THEN 'Hết hạn trong 14 ngày'
            WHEN DATEDIFF(hd.NgayKetThuc, CURDATE()) < 30  THEN 'Hết hạn trong 30 ngày'
            ELSE 'Còn hạn'
        END                                         AS CanhBao
    FROM HopDong hd
    JOIN NhanVien    nv  ON hd.MaNV = nv.MaNV
    JOIN PhongBan    pb  ON nv.MaPB = pb.MaPB
    JOIN LoaiHopDong lhd ON hd.MaLoaiHD = lhd.MaLoaiHD
    WHERE hd.TrangThai = 'A'
      AND hd.NgayKetThuc IS NOT NULL
      AND hd.NgayKetThuc <= DATE_ADD(CURDATE(), INTERVAL p_SoNgayCanhBao DAY)
    ORDER BY hd.NgayKetThuc ASC;
END$$
DELIMITER ;

SELECT 'sp_BaoCaoNhanSu_HopDong' AS Status;


-- SP 4: sp_BaoCaoNhanSu_BienDong
DROP PROCEDURE IF EXISTS sp_BaoCaoNhanSu_BienDong;

DELIMITER $$
CREATE PROCEDURE sp_BaoCaoNhanSu_BienDong(
    IN p_TuNgay DATE,
    IN p_DenNgay DATE
)
BEGIN
    -- LƯU Ý MySQL 8.0.46: DATE_FORMAT() trả về VARCHAR, không phải DATE
    -- Dùng MAKEDATE() hoặc DATE() để đảm bảo kiểu dữ liệu DATE chính xác
    IF p_TuNgay IS NULL THEN SET p_TuNgay  = MAKEDATE(YEAR(CURDATE()), 1); END IF;
    IF p_DenNgay IS NULL THEN SET p_DenNgay = CURDATE(); END IF;

    -- RS1: Nhân viên mới vào
    SELECT
        'Tuyển mới'                                 AS LoaiBienDong,
        nv.MaNV, nv.HoTen,
        DATE_FORMAT(nv.NgayVaoLam, '%d/%m/%Y')      AS NgayBienDong,
        pb.TenPB                                    AS PhongBan,
        cv.TenCV                                    AS ChucVu,
        lhd.TenLoaiHD                               AS LoaiHopDong
    FROM NhanVien nv
    JOIN PhongBan    pb  ON nv.MaPB = pb.MaPB
    JOIN ChucVu      cv  ON nv.MaCV = cv.MaCV
    LEFT JOIN HopDong hd  ON nv.MaNV = hd.MaNV AND hd.TrangThai IN ('A','E')
    LEFT JOIN LoaiHopDong lhd ON hd.MaLoaiHD = lhd.MaLoaiHD
    WHERE nv.NgayVaoLam BETWEEN p_TuNgay AND p_DenNgay
    ORDER BY nv.NgayVaoLam;

    -- RS2: Nhân viên nghỉ việc
    SELECT
        'Nghỉ việc'                                 AS LoaiBienDong,
        nv.MaNV, nv.HoTen,
        DATE_FORMAT(nv.NgayNghiViec, '%d/%m/%Y')    AS NgayBienDong,
        pb.TenPB                                    AS PhongBan,
        cv.TenCV                                    AS ChucVu,
        CONCAT(
            TIMESTAMPDIFF(YEAR, nv.NgayVaoLam, nv.NgayNghiViec),
            ' năm'
        )                                           AS ThamNienKhiNghi
    FROM NhanVien nv
    JOIN PhongBan pb ON nv.MaPB = pb.MaPB
    JOIN ChucVu   cv ON nv.MaCV = cv.MaCV
    WHERE nv.TrangThai = 'T'
      AND nv.NgayNghiViec BETWEEN p_TuNgay AND p_DenNgay
    ORDER BY nv.NgayNghiViec;

    -- RS3: Thống kê biến động tổng hợp
    SELECT
        (SELECT COUNT(*) FROM NhanVien
         WHERE NgayVaoLam BETWEEN p_TuNgay AND p_DenNgay)          AS TuyenMoi,
        (SELECT COUNT(*) FROM NhanVien
         WHERE TrangThai = 'T'
           AND NgayNghiViec BETWEEN p_TuNgay AND p_DenNgay)        AS NghiViec,
        (SELECT COUNT(*) FROM NhanVien WHERE TrangThai IN ('A','P','L')) AS TongHienTai;
END$$
DELIMITER ;

SELECT 'sp_BaoCaoNhanSu_BienDong' AS Status;


-- SP 5: sp_BaoCaoNhanSu_LuongPhanPhoi
DROP PROCEDURE IF EXISTS sp_BaoCaoNhanSu_LuongPhanPhoi;

DELIMITER $$
CREATE PROCEDURE sp_BaoCaoNhanSu_LuongPhanPhoi(
    IN p_Thang TINYINT,
    IN p_Nam   SMALLINT
)
BEGIN
    IF p_Thang IS NULL THEN SET p_Thang = MONTH(CURDATE()); END IF;
    IF p_Nam IS NULL   THEN SET p_Nam   = YEAR(CURDATE());  END IF;

    -- RS1: Xếp hạng lương cá nhân
    SELECT
        RANK() OVER (ORDER BY bl.ThuNhapThucLinh DESC) AS XepHang,
        nv.MaNV, nv.HoTen,
        pb.TenPB                                    AS PhongBan,
        cv.TenCV                                    AS ChucVu,
        FORMAT(bl.LuongCoBan, 0)                    AS LuongCoBan,
        FORMAT(bl.ThuNhapGop, 0)                    AS LuongGross,
        FORMAT(bl.BHXH_NLD + bl.BHYT_NLD + bl.BHTN_NLD, 0) AS TongBH,
        FORMAT(bl.ThueTNCN, 0)                      AS ThueTNCN,
        FORMAT(bl.ThuNhapThucLinh, 0)               AS ThucLinh,
        bl.TrangThai
    FROM BangLuong bl
    JOIN NhanVien  nv ON bl.MaNV = nv.MaNV
    JOIN PhongBan  pb ON nv.MaPB = pb.MaPB
    JOIN ChucVu    cv ON nv.MaCV = cv.MaCV
    WHERE bl.Thang = p_Thang AND bl.Nam = p_Nam
    ORDER BY bl.ThuNhapThucLinh DESC;

    -- RS2: Phân phối theo khoảng lương
    SELECT
        CASE
            WHEN bl.ThuNhapThucLinh < 10000000  THEN 'Dưới 10 tr'
            WHEN bl.ThuNhapThucLinh < 15000000  THEN '10 – 15 tr'
            WHEN bl.ThuNhapThucLinh < 20000000  THEN '15 – 20 tr'
            WHEN bl.ThuNhapThucLinh < 30000000  THEN '20 – 30 tr'
            WHEN bl.ThuNhapThucLinh < 50000000  THEN '30 – 50 tr'
            ELSE '50 tr+'
        END                                         AS KhoangLuong,
        COUNT(*)                                    AS SoNhanVien,
        FORMAT(MIN(bl.ThuNhapThucLinh), 0)          AS LuongThap,
        FORMAT(MAX(bl.ThuNhapThucLinh), 0)          AS LuongCao,
        FORMAT(AVG(bl.ThuNhapThucLinh), 0)          AS LuongTB
    FROM BangLuong bl
    WHERE bl.Thang = p_Thang AND bl.Nam = p_Nam
    GROUP BY KhoangLuong
    ORDER BY MIN(bl.ThuNhapThucLinh);

    -- RS3: Tổng hợp toàn công ty
    SELECT
        COUNT(*)                                    AS SoNhanVien,
        FORMAT(SUM(bl.ThuNhapGop), 0)              AS TongQuiLuongGross,
        FORMAT(SUM(bl.ThuNhapThucLinh), 0)         AS TongThucLinh,
        FORMAT(AVG(bl.ThuNhapThucLinh), 0)         AS LuongNetTrungBinh,
        FORMAT(MAX(bl.ThuNhapThucLinh), 0)         AS LuongCaoNhat,
        FORMAT(MIN(bl.ThuNhapThucLinh), 0)         AS LuongThapNhat,
        FORMAT(SUM(bl.ThueTNCN), 0)                AS TongThueTNCN,
        FORMAT(SUM(bl.BHXH_NLD + bl.BHYT_NLD + bl.BHTN_NLD), 0) AS TongBH_NLD
    FROM BangLuong bl
    WHERE bl.Thang = p_Thang AND bl.Nam = p_Nam;
END$$
DELIMITER ;

SELECT 'sp_BaoCaoNhanSu_LuongPhanPhoi' AS Status;


-- SP 6: sp_BaoCaoNhanSu_NghiPhepNam
DROP PROCEDURE IF EXISTS sp_BaoCaoNhanSu_NghiPhepNam;

DELIMITER $$
CREATE PROCEDURE sp_BaoCaoNhanSu_NghiPhepNam(
    IN p_Nam      SMALLINT,
    IN p_MaPB     VARCHAR(6)
)
BEGIN
    DECLARE v_PhepTieuChuan INT DEFAULT 12; -- 12 ngày phép năm

    IF p_Nam IS NULL THEN SET p_Nam = YEAR(CURDATE()); END IF;

    SELECT
        nv.MaNV,
        nv.HoTen,
        pb.TenPB                                    AS PhongBan,
        v_PhepTieuChuan                             AS PhepTieuChuan,
        -- LƯU Ý MySQL 8.0.46: CONCAT(p_Nam, '-12-31') trả về VARCHAR
        -- Dùng DATE(CONCAT(...)) hoặc MAKEDATE() để đảm bảo kiểu DATE
        IFNULL(SUM(CASE WHEN lnp.TenLoaiNghi LIKE '%năm%'
                        AND np.TrangThai = 'A'
                    THEN DATEDIFF(
                        CASE WHEN np.NgayKetThuc > DATE(CONCAT(p_Nam, '-12-31'))
                             THEN DATE(CONCAT(p_Nam, '-12-31'))
                             ELSE np.NgayKetThuc END,
                        CASE WHEN np.NgayBatDau < DATE(CONCAT(p_Nam, '-01-01'))
                             THEN DATE(CONCAT(p_Nam, '-01-01'))
                             ELSE np.NgayBatDau END
                    ) + 1
                    ELSE 0 END), 0)                 AS PhepDaNghi,
        v_PhepTieuChuan
        - IFNULL(SUM(CASE WHEN lnp.TenLoaiNghi LIKE '%năm%'
                          AND np.TrangThai = 'A'
                      THEN DATEDIFF(
                            CASE WHEN np.NgayKetThuc > DATE(CONCAT(p_Nam, '-12-31'))
                                 THEN DATE(CONCAT(p_Nam, '-12-31'))
                                 ELSE np.NgayKetThuc END,
                            CASE WHEN np.NgayBatDau < DATE(CONCAT(p_Nam, '-01-01'))
                                 THEN DATE(CONCAT(p_Nam, '-01-01'))
                                 ELSE np.NgayBatDau END
                          ) + 1
                      ELSE 0 END), 0)               AS PhepConLai,
        IFNULL(SUM(CASE WHEN np.TrangThai = 'P'
                    THEN np.SoNgayNghi ELSE 0 END), 0) AS PhepDangCho
    FROM NhanVien nv
    JOIN PhongBan pb ON nv.MaPB = pb.MaPB
    LEFT JOIN NghiPhep    np  ON nv.MaNV = np.MaNV
                             AND YEAR(np.NgayBatDau) = p_Nam
    LEFT JOIN LoaiNghiPhep lnp ON np.MaLoaiNghi = lnp.MaLoaiNghi
    WHERE nv.TrangThai IN ('A','P','L')
      AND (p_MaPB IS NULL OR nv.MaPB = p_MaPB)
    GROUP BY nv.MaNV, nv.HoTen, pb.TenPB
    ORDER BY PhepConLai ASC, pb.TenPB;
END$$
DELIMITER ;

SELECT 'sp_BaoCaoNhanSu_NghiPhepNam' AS Status;

-- KIỂM THỬ
-- CALL sp_BaoCaoNhanSu_TongQuan(NULL);
-- CALL sp_BaoCaoNhanSu_HopDong(30);
-- CALL sp_BaoCaoNhanSu_LuongPhanPhoi(1, 2025);