-- MỤC ĐÍCH   : Các hàm tính ngày công — nền tảng cho sp_TinhLuong
-- FUNCTIONS  :
--   1. fn_SoNgayChuanThang  — Scalar: ngày chuẩn làm việc/tháng
--   2. fn_SoNgayChamCong    — Scalar: ngày đi làm thực tế
--   3. fn_SoNgayNghiCoLuong — Scalar: ngày nghỉ hưởng lương
--   4. fn_SoNgayNghiKhongLuong — Scalar: ngày nghỉ không lương
--   5. fn_HeSoLuongThang    — Scalar: hệ số lương theo ngày công
--   6. fn_TinhLuongLamThem  — Scalar: lương tăng ca kỳ tháng
-- DEPENDENCY : Chạy SAU fn_TinhBHXH.sql, cần seed_data.sql

USE HRPayrollDB;

-- HÀM 1: fn_SoNgayChuanThang
-- Đếm số ngày làm việc tiêu chuẩn trong tháng
-- (loại cuối tuần + ngày lễ trong bảng NgayLe)

DROP FUNCTION IF EXISTS fn_SoNgayChuanThang;

DELIMITER $$

CREATE FUNCTION fn_SoNgayChuanThang(
    p_Thang TINYINT,
    p_Nam   SMALLINT
)
RETURNS TINYINT
READS SQL DATA
DETERMINISTIC
BEGIN
    DECLARE v_NgayDauThang  DATE;
    DECLARE v_NgayCuoiThang DATE;
    DECLARE v_NgayChuan     INT DEFAULT 0;
    DECLARE v_NgayLay       DATE;

    SET v_NgayDauThang  = MAKEDATE(p_Nam, 1);
    SET v_NgayDauThang  = DATE(CONCAT(p_Nam, '-', LPAD(p_Thang, 2, '0'), '-01'));
    SET v_NgayCuoiThang = LAST_DAY(v_NgayDauThang);
    SET v_NgayLay       = v_NgayDauThang;

    -- Duyệt từng ngày trong tháng
    WHILE v_NgayLay <= v_NgayCuoiThang DO
        -- Chỉ đếm ngày thứ 2 đến thứ 6 (DAYOFWEEK: 1=Chủ nhật, 7=Thứ bảy)
        IF DAYOFWEEK(v_NgayLay) NOT IN (1, 7) THEN
            -- Loại ngày lễ cố định dương lịch
            IF NOT (
                (MONTH(v_NgayLay) = 1 AND DAY(v_NgayLay) = 1)  OR   -- Tết DL
                (MONTH(v_NgayLay) = 4 AND DAY(v_NgayLay) = 30) OR   -- Ngày giải phóng
                (MONTH(v_NgayLay) = 5 AND DAY(v_NgayLay) = 1)  OR   -- Quốc tế LĐ
                (MONTH(v_NgayLay) = 9 AND DAY(v_NgayLay) = 2)        -- Quốc khánh
            ) THEN
                -- Kiểm tra trong bảng NgayLe (Tết ÂL, Giỗ Tổ...)
                IF NOT EXISTS (
                    SELECT 1 FROM NgayLe WHERE NgayLe = v_NgayLay
                ) THEN
                    SET v_NgayChuan = v_NgayChuan + 1;
                END IF;
            END IF;
        END IF;
        SET v_NgayLay = DATE_ADD(v_NgayLay, INTERVAL 1 DAY);
    END WHILE;

    RETURN CAST(v_NgayChuan AS UNSIGNED);
END$$

DELIMITER ;

SELECT 'fn_SoNgayChuanThang — tạo thành công' AS Status;


-- HÀM 2: fn_SoNgayChamCong
-- Đếm số ngày làm việc thực tế từ bảng ChamCong

DROP FUNCTION IF EXISTS fn_SoNgayChamCong;

DELIMITER $$

CREATE FUNCTION fn_SoNgayChamCong(
    p_MaNV  VARCHAR(10),
    p_Thang TINYINT,
    p_Nam   SMALLINT
)
RETURNS DECIMAL(5,1)
READS SQL DATA
DETERMINISTIC
BEGIN
    DECLARE v_SoNgay DECIMAL(5,1) DEFAULT 0;

    SELECT COUNT(*) INTO v_SoNgay
    FROM ChamCong
    WHERE MaNV    = p_MaNV
      AND MONTH(NgayCham) = p_Thang
      AND YEAR(NgayCham)  = p_Nam
      AND TrangThai IN ('DL', 'WFH', 'CX');

    RETURN IFNULL(v_SoNgay, 0);
END$$

DELIMITER ;

SELECT 'fn_SoNgayChamCong — tạo thành công' AS Status;


-- HÀM 3: fn_SoNgayNghiCoLuong
-- Đếm ngày nghỉ HƯỞNG LƯƠNG trong tháng

DROP FUNCTION IF EXISTS fn_SoNgayNghiCoLuong;

DELIMITER $$

CREATE FUNCTION fn_SoNgayNghiCoLuong(
    p_MaNV  VARCHAR(10),
    p_Thang TINYINT,
    p_Nam   SMALLINT
)
RETURNS DECIMAL(5,1)
READS SQL DATA
DETERMINISTIC
BEGIN
    DECLARE v_SoNgay DECIMAL(5,1) DEFAULT 0;

    SELECT COUNT(*) INTO v_SoNgay
    FROM ChamCong
    WHERE MaNV    = p_MaNV
      AND MONTH(NgayCham) = p_Thang
      AND YEAR(NgayCham)  = p_Nam
      AND TrangThai IN ('NP', 'OM');

    RETURN IFNULL(v_SoNgay, 0);
END$$

DELIMITER ;

SELECT 'fn_SoNgayNghiCoLuong — tạo thành công' AS Status;

-- HÀM 4: fn_SoNgayNghiKhongLuong
-- Đếm ngày nghỉ KHÔNG hưởng lương trong tháng

DROP FUNCTION IF EXISTS fn_SoNgayNghiKhongLuong;

DELIMITER $$

CREATE FUNCTION fn_SoNgayNghiKhongLuong(
    p_MaNV  VARCHAR(10),
    p_Thang TINYINT,
    p_Nam   SMALLINT
)
RETURNS DECIMAL(5,1)
READS SQL DATA
DETERMINISTIC
BEGIN
    DECLARE v_SoNgay DECIMAL(5,1) DEFAULT 0;

    SELECT COUNT(*) INTO v_SoNgay
    FROM ChamCong
    WHERE MaNV    = p_MaNV
      AND MONTH(NgayCham) = p_Thang
      AND YEAR(NgayCham)  = p_Nam
      AND TrangThai = 'KP';

    RETURN IFNULL(v_SoNgay, 0);
END$$

DELIMITER ;

SELECT 'fn_SoNgayNghiKhongLuong — tạo thành công' AS Status;


-- HÀM 5: fn_HeSoLuongThang
-- Tính hệ số lương = (NgayDiLam + NgayNghiCoLuong) / NgayChuan

DROP FUNCTION IF EXISTS fn_HeSoLuongThang;

DELIMITER $$

CREATE FUNCTION fn_HeSoLuongThang(
    p_MaNV  VARCHAR(10),
    p_Thang TINYINT,
    p_Nam   SMALLINT
)
RETURNS DECIMAL(10,6)
READS SQL DATA
DETERMINISTIC
BEGIN
    DECLARE v_NgayDiLam  DECIMAL(5,1);
    DECLARE v_NgayNghiCL DECIMAL(5,1);
    DECLARE v_NgayChuan  TINYINT;
    DECLARE v_HeSo       DECIMAL(10,6);

    SET v_NgayDiLam  = fn_SoNgayChamCong(p_MaNV, p_Thang, p_Nam);
    SET v_NgayNghiCL = fn_SoNgayNghiCoLuong(p_MaNV, p_Thang, p_Nam);
    SET v_NgayChuan  = fn_SoNgayChuanThang(p_Thang, p_Nam);

    IF v_NgayChuan = 0 THEN
        RETURN 0;
    END IF;

    SET v_HeSo = CAST(v_NgayDiLam + v_NgayNghiCL AS DECIMAL(10,6)) / v_NgayChuan;

    RETURN CASE WHEN v_HeSo > 1.0 THEN 1.0 ELSE v_HeSo END;
END$$

DELIMITER ;

SELECT 'fn_HeSoLuongThang — tạo thành công' AS Status;

-- HÀM 6: fn_TinhLuongLamThem
-- Tính lương tăng ca trong tháng

DROP FUNCTION IF EXISTS fn_TinhLuongLamThem;

DELIMITER $$

CREATE FUNCTION fn_TinhLuongLamThem(
    p_MaNV       VARCHAR(10),
    p_Thang      TINYINT,
    p_Nam        SMALLINT,
    p_LuongCoBan DECIMAL(18,2)
)
RETURNS DECIMAL(18,2)
READS SQL DATA
DETERMINISTIC
BEGIN
    DECLARE v_NgayChuan     TINYINT;
    DECLARE v_LuongGioChuan DECIMAL(18,6);
    DECLARE v_TongLTC       DECIMAL(18,2) DEFAULT 0;

    SET v_NgayChuan = fn_SoNgayChuanThang(p_Thang, p_Nam);

    IF v_NgayChuan = 0 THEN
        RETURN 0;
    END IF;

    -- Lương 1 giờ chuẩn
    SET v_LuongGioChuan = p_LuongCoBan / v_NgayChuan / 8.0;

    -- Tổng lương tăng ca = SUM(SoGioTangCa × HeSoTangCa × LuongGio)
    SELECT IFNULL(SUM(cc.SoGioTangCa * cc.HeSoTangCa * v_LuongGioChuan), 0)
    INTO v_TongLTC
    FROM ChamCong cc
    WHERE cc.MaNV           = p_MaNV
      AND MONTH(cc.NgayCham) = p_Thang
      AND YEAR(cc.NgayCham)  = p_Nam
      AND cc.SoGioTangCa     > 0;

    RETURN IFNULL(ROUND(v_TongLTC, 0), 0);
END$$

DELIMITER ;

SELECT 'fn_TinhLuongLamThem — tạo thành công' AS Status;


-- KIỂM THỬ ĐẦY ĐỦ

SELECT '  KIỂM THỬ CÁC HÀM NGÀY CÔNG' AS Status;
-- Số ngày chuẩn Jan-May 2025
SELECT '--- Số ngày làm việc chuẩn Jan-May 2025 ---' AS Info;
SELECT
    Thang, Nam,
    fn_SoNgayChuanThang(Thang, Nam) AS NgayChuanLamViec
FROM (
    SELECT 1 AS Thang, 2025 AS Nam UNION ALL
    SELECT 2, 2025  UNION ALL
    SELECT 3, 2025  UNION ALL
    SELECT 4, 2025  UNION ALL
    SELECT 5, 2025
) T;

-- Test thực tế với dữ liệu đã seed (chạy sau seed_data.sql)
SELECT '--- Thống kê ngày công thực tế NV000001 (TGĐ) tháng 1-3/2025 ---' AS Info;
SELECT
    Ky.Thang,
    Ky.Nam,
    fn_SoNgayChuanThang(Ky.Thang, Ky.Nam)            AS NgayChuan,
    fn_SoNgayChamCong('NV000001', Ky.Thang, Ky.Nam)  AS NgayDiLam,
    fn_SoNgayNghiCoLuong('NV000001', Ky.Thang, Ky.Nam) AS NgayNghiCL,
    fn_SoNgayNghiKhongLuong('NV000001', Ky.Thang, Ky.Nam) AS NgayKhongPhep,
    fn_HeSoLuongThang('NV000001', Ky.Thang, Ky.Nam)  AS HeSoLuong
FROM (
    SELECT 1 AS Thang, 2025 AS Nam UNION ALL
    SELECT 2, 2025 UNION ALL
    SELECT 3, 2025
) Ky;

SELECT 'fn_SoNgayLamViec.sql — 6 functions hoàn tất' AS Status;
