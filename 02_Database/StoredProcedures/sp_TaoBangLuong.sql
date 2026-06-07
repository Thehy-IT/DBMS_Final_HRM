-- ============================================================
-- FILE       : sp_TaoBangLuong.sql
-- PROJECT    : Hệ Thống Quản Lý Nhân Sự & Tính Lương Tự Động
-- MỤC ĐÍCH   : Tạo đầy đủ các bảng lương chính thức, phiếu lương
--              và báo cáo pháp lý theo chuẩn doanh nghiệp Việt Nam
-- PROCEDURES :
--   1. sp_TaoBangLuong_ChinhThuc     — Bảng lương tổng hợp đầy đủ
--   2. sp_TaoBangLuong_PhieuLuong    — Phiếu lương chi tiết 1 NV
--   3. sp_TaoBangLuong_BHXH          — Danh sách đóng BHXH tháng
--   4. sp_TaoBangLuong_QuyetToanThue — Dữ liệu quyết toán thuế TNCN
--   5. sp_TaoBangLuong_SoSanh        — So sánh quỹ lương nhiều kỳ
--   6. sp_TaoBangLuong_ChiPhiNhanSu  — Chi phí nhân sự toàn DN
-- DBMS       : MySQL 8.0+
-- THỨ TỰ CHẠY:
--   sp_TinhLuong → sp_XacNhanBangLuong → sp_TaoBangLuong_*
-- ============================================================

USE HRPayrollDB;

-- ============================================================
-- SP 1: sp_TaoBangLuong_ChinhThuc
-- Bảng lương tổng hợp chính thức một kỳ (RS1: Chi tiết, RS2: Tổng hợp PB)
-- ============================================================
DROP PROCEDURE IF EXISTS sp_TaoBangLuong_ChinhThuc;

DELIMITER $$

CREATE PROCEDURE sp_TaoBangLuong_ChinhThuc(
    IN p_Thang    TINYINT,
    IN p_Nam      SMALLINT,
    IN p_MaPB     VARCHAR(6),    -- NULL = tất cả PB
    IN p_TrangThai CHAR(1)       -- NULL = tất cả trạng thái
)
BEGIN
    DECLARE v_TenKy VARCHAR(50);

    -- Kiểm tra tồn tại dữ liệu
    IF NOT EXISTS (
        SELECT 1 FROM BangLuong WHERE Thang = p_Thang AND Nam = p_Nam
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'sp_TaoBangLuong_ChinhThuc: Chưa có dữ liệu bảng lương. Vui lòng chạy sp_TinhLuong trước.';
    END IF;

    SET v_TenKy = CONCAT('Tháng ', p_Thang, '/', p_Nam);

    -- RS1: Chi tiết từng nhân viên
    SELECT
        v_TenKy                                             AS KyLuong,
        pb.TenPB                                            AS PhongBan,
        RANK() OVER (PARTITION BY nv.MaPB ORDER BY bl.ThuNhapThucLinh DESC) AS SoThuTuTrongPB,
        nv.MaNV,
        nv.HoTen,
        cv.TenCV                                            AS ChucVu,
        lhd.TenLoaiHD                                       AS LoaiHopDong,
        bl.SoNgayCong,
        bl.SoNgayLamChuan                                   AS NgayChuan,
        FORMAT(bl.LuongCoBan,     0)                        AS LuongTheoNgayCong,
        FORMAT(bl.HeSoTangCa,     0)                        AS LuongTangCa,
        FORMAT(bl.TongPhuCap,     0)                        AS TongPhuCap,
        FORMAT(bl.ThuNhapGop,     0)                        AS LuongGross,
        FORMAT(bl.BHXH_NLD,       0)                        AS BHXH_8pct,
        FORMAT(bl.BHYT_NLD,       0)                        AS BHYT_1dot5pct,
        FORMAT(bl.BHTN_NLD,       0)                        AS BHTN_1pct,
        FORMAT(bl.BHXH_NLD + bl.BHYT_NLD + bl.BHTN_NLD, 0) AS TongBH_NLD,
        FORMAT(11000000,           0)                        AS GiamTruBanThan,
        FORMAT(fn_TinhGiamTruPhuThuoc(nv.SoNguoiPhuThuoc), 0) AS GiamTruPhuThuoc,
        FORMAT(bl.ThueTNCN,        0)                        AS ThueTNCN,
        FORMAT(bl.TongKhauTru,     0)                        AS KhauTruKhac,
        FORMAT(bl.TongKhauTru,     0)                        AS TongKhauTru,
        FORMAT(bl.ThuNhapThucLinh, 0)                        AS ThucLinh,
        CASE bl.TrangThai
            WHEN 'D' THEN 'Nháp'
            WHEN 'C' THEN 'Đã xác nhận'
            WHEN 'P' THEN 'Đã thanh toán'
            WHEN 'L' THEN 'Đã khóa'
            ELSE bl.TrangThai
        END                                                 AS TrangThai
    FROM BangLuong bl
    JOIN NhanVien     nv  ON bl.MaNV = nv.MaNV
    JOIN PhongBan     pb  ON nv.MaPB = pb.MaPB
    JOIN ChucVu       cv  ON nv.MaCV = cv.MaCV
    LEFT JOIN HopDong hd  ON nv.MaNV = hd.MaNV AND hd.TrangThai = 'A'
    LEFT JOIN LoaiHopDong lhd ON hd.MaLoaiHD = lhd.MaLoaiHD
    WHERE bl.Thang = p_Thang
      AND bl.Nam   = p_Nam
      AND (p_MaPB IS NULL OR nv.MaPB = p_MaPB)
      AND (p_TrangThai IS NULL OR bl.TrangThai = p_TrangThai)
    ORDER BY pb.TenPB, bl.ThuNhapThucLinh DESC;

    -- RS2: Tổng hợp theo phòng ban + grand total
    SELECT
        COALESCE(pb.TenPB, '=== TỔNG CÔNG TY ===')        AS PhongBan,
        COUNT(bl.MaBL)                                      AS SoNhanVien,
        FORMAT(SUM(bl.LuongCoBan),    0)                    AS TongLuongCB,
        FORMAT(SUM(bl.TongPhuCap),    0)                    AS TongPhuCap,
        FORMAT(SUM(bl.ThuNhapGop),    0)                    AS TongGross,
        FORMAT(SUM(bl.BHXH_NLD + bl.BHYT_NLD + bl.BHTN_NLD), 0) AS TongBH_NLD,
        FORMAT(SUM(bl.ThueTNCN),      0)                    AS TongThueTNCN,
        FORMAT(SUM(bl.TongKhauTru),   0)                    AS TongKhauTru,
        FORMAT(SUM(bl.ThuNhapThucLinh), 0)                  AS TongThucLinh,
        FORMAT(AVG(bl.ThuNhapThucLinh), 0)                  AS LuongNetTrungBinh
    FROM BangLuong bl
    JOIN NhanVien nv ON bl.MaNV = nv.MaNV
    JOIN PhongBan pb ON nv.MaPB = pb.MaPB
    WHERE bl.Thang = p_Thang
      AND bl.Nam   = p_Nam
      AND (p_MaPB IS NULL OR nv.MaPB = p_MaPB)
      AND (p_TrangThai IS NULL OR bl.TrangThai = p_TrangThai)
    GROUP BY pb.TenPB WITH ROLLUP
    ORDER BY pb.TenPB IS NULL, pb.TenPB;
END$$

DELIMITER ;

SELECT '[OK] sp_TaoBangLuong_ChinhThuc' AS Status;


-- ============================================================
-- SP 2: sp_TaoBangLuong_PhieuLuong
-- Phiếu lương chi tiết từng nhân viên
-- ============================================================
DROP PROCEDURE IF EXISTS sp_TaoBangLuong_PhieuLuong;

DELIMITER $$

CREATE PROCEDURE sp_TaoBangLuong_PhieuLuong(
    IN p_MaNV     VARCHAR(8),
    IN p_Thang    TINYINT,
    IN p_Nam      SMALLINT
)
BEGIN
    DECLARE v_MaBL BIGINT;

    SELECT MaBL INTO v_MaBL
    FROM BangLuong WHERE MaNV = p_MaNV AND Thang = p_Thang AND Nam = p_Nam
    LIMIT 1;

    IF v_MaBL IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'sp_TaoBangLuong_PhieuLuong: Không tìm thấy bảng lương cho NV và kỳ này.';
    END IF;

    -- RS1: Thông tin nhân viên
    SELECT
        nv.MaNV,
        nv.HoTen,
        nv.Email,
        nv.SoDienThoai,
        nv.MaSoThue,
        nv.SoTaiKhoanNH,
        nv.TenNganHang,
        pb.TenPB          AS PhongBan,
        cv.TenCV          AS ChucVu,
        DATE_FORMAT(nv.NgayVaoLam, '%d/%m/%Y') AS NgayVaoLam,
        CONCAT('Tháng ', p_Thang, '/', p_Nam)  AS KyLuong,
        lhd.TenLoaiHD     AS LoaiHopDong
    FROM NhanVien nv
    JOIN PhongBan    pb  ON nv.MaPB = pb.MaPB
    JOIN ChucVu      cv  ON nv.MaCV = cv.MaCV
    LEFT JOIN HopDong hd  ON nv.MaNV = hd.MaNV AND hd.TrangThai = 'A'
    LEFT JOIN LoaiHopDong lhd ON hd.MaLoaiHD = lhd.MaLoaiHD
    WHERE nv.MaNV = p_MaNV;

    -- RS2: Bảng lương tổng hợp
    SELECT
        bl.SoNgayCong,
        bl.SoNgayLamChuan,
        FORMAT(bl.LuongCoBan,      0) AS LuongTheoNgayCong,
        FORMAT(bl.HeSoTangCa,      0) AS ThuNhapTangCa,
        FORMAT(bl.TongPhuCap,      0) AS TongPhuCap,
        FORMAT(bl.ThuNhapGop,      0) AS LuongGross,
        FORMAT(bl.BHXH_NLD,        0) AS BHXH_8pct,
        FORMAT(bl.BHYT_NLD,        0) AS BHYT_1dot5pct,
        FORMAT(bl.BHTN_NLD,        0) AS BHTN_1pct,
        FORMAT(11000000,            0) AS GiamTruBanThan,
        FORMAT(fn_TinhGiamTruPhuThuoc(nv.SoNguoiPhuThuoc), 0) AS GiamTruPhuThuoc,
        FORMAT(bl.ThueTNCN,        0) AS ThueTNCN,
        FORMAT(bl.TongKhauTru,     0) AS KhauTruKhac,
        FORMAT(bl.ThuNhapThucLinh, 0) AS ThucLinh,
        DATE_FORMAT(bl.NgayTinhLuong, '%d/%m/%Y %H:%i') AS NgayTinhLuong,
        bl.TrangThai,
        bl.NguoiTao
    FROM BangLuong bl
    JOIN NhanVien nv ON bl.MaNV = nv.MaNV
    WHERE bl.MaBL = v_MaBL;

    -- RS3: Chi tiết từng khoản thu nhập/khấu trừ
    SELECT
        LoaiMuc,
        TenMuc,
        FORMAT(GiaTri, 0) AS GiaTri_VND
    FROM ChiTietLuong
    WHERE MaBL = v_MaBL
    ORDER BY FIELD(LoaiMuc, '+', '-');
END$$

DELIMITER ;

SELECT '[OK] sp_TaoBangLuong_PhieuLuong' AS Status;


-- ============================================================
-- SP 3: sp_TaoBangLuong_BHXH
-- Danh sách đóng BHXH/BHYT/BHTN tháng
-- ============================================================
DROP PROCEDURE IF EXISTS sp_TaoBangLuong_BHXH;

DELIMITER $$

CREATE PROCEDURE sp_TaoBangLuong_BHXH(
    IN p_Thang TINYINT,
    IN p_Nam   SMALLINT,
    IN p_MaPB  VARCHAR(6)
)
BEGIN
    -- RS1: Chi tiết đóng BHXH từng NV
    SELECT
        CONCAT(p_Thang, '/', p_Nam)                         AS KyBHXH,
        pb.TenPB,
        nv.MaNV,
        nv.HoTen,
        lhd.TenLoaiHD                                       AS LoaiHopDong,
        FORMAT(lcb.LuongDongBH, 0)                          AS LuongDongBH,
        -- NLĐ đóng
        FORMAT(ROUND(lcb.LuongDongBH * 0.08,  0), 0)        AS BHXH_NLD_8pct,
        FORMAT(ROUND(lcb.LuongDongBH * 0.015, 0), 0)        AS BHYT_NLD_1dot5pct,
        FORMAT(ROUND(lcb.LuongDongBH * 0.01,  0), 0)        AS BHTN_NLD_1pct,
        FORMAT(ROUND(lcb.LuongDongBH * 0.105, 0), 0)        AS TongNLD_10dot5pct,
        -- NSDLĐ đóng
        FORMAT(ROUND(lcb.LuongDongBH * 0.175, 0), 0)        AS BHXH_NSDLD_17dot5pct,
        FORMAT(ROUND(lcb.LuongDongBH * 0.03,  0), 0)        AS BHYT_NSDLD_3pct,
        FORMAT(ROUND(lcb.LuongDongBH * 0.01,  0), 0)        AS BHTN_NSDLD_1pct,
        FORMAT(ROUND(lcb.LuongDongBH * 0.005, 0), 0)        AS BHTNTLD_0dot5pct,
        FORMAT(ROUND(lcb.LuongDongBH * 0.22,  0), 0)        AS TongNSDLD_22pct,
        -- Tổng
        FORMAT(ROUND(lcb.LuongDongBH * 0.325, 0), 0)        AS TongPhiBH_32dot5pct
    FROM NhanVien nv
    JOIN PhongBan    pb  ON nv.MaPB = pb.MaPB
    LEFT JOIN HopDong hd  ON nv.MaNV = hd.MaNV AND hd.TrangThai = 'A'
    LEFT JOIN LoaiHopDong lhd ON hd.MaLoaiHD = lhd.MaLoaiHD
    LEFT JOIN LuongCoBan lcb ON nv.MaNV = lcb.MaNV
        AND lcb.NgayHieuLuc <= LAST_DAY(STR_TO_DATE(CONCAT(p_Nam, '-', LPAD(p_Thang,2,'0'), '-01'), '%Y-%m-%d'))
        AND (lcb.NgayHetHieuLuc IS NULL
             OR lcb.NgayHetHieuLuc >= STR_TO_DATE(CONCAT(p_Nam, '-', LPAD(p_Thang,2,'0'), '-01'), '%Y-%m-%d'))
    WHERE nv.TrangThai IN ('A','P')
      AND (p_MaPB IS NULL OR nv.MaPB = p_MaPB)
      AND IFNULL(lhd.TiLeBHXH, 0) > 0  -- Chỉ loại HĐ đóng BHXH
    ORDER BY pb.TenPB, nv.HoTen;

    -- RS2: Tổng hợp BHXH theo phòng ban
    SELECT
        pb.TenPB,
        COUNT(nv.MaNV)                                      AS SoNhanVien,
        FORMAT(SUM(ROUND(lcb.LuongDongBH * 0.105, 0)), 0)  AS TongNLD_10dot5pct,
        FORMAT(SUM(ROUND(lcb.LuongDongBH * 0.22,  0)), 0)  AS TongNSDLD_22pct,
        FORMAT(SUM(ROUND(lcb.LuongDongBH * 0.325, 0)), 0)  AS TongPhiBH
    FROM NhanVien nv
    JOIN PhongBan    pb  ON nv.MaPB = pb.MaPB
    LEFT JOIN HopDong hd  ON nv.MaNV = hd.MaNV AND hd.TrangThai = 'A'
    LEFT JOIN LoaiHopDong lhd ON hd.MaLoaiHD = lhd.MaLoaiHD
    LEFT JOIN LuongCoBan lcb ON nv.MaNV = lcb.MaNV
        AND lcb.NgayHieuLuc <= LAST_DAY(STR_TO_DATE(CONCAT(p_Nam, '-', LPAD(p_Thang,2,'0'), '-01'), '%Y-%m-%d'))
        AND (lcb.NgayHetHieuLuc IS NULL
             OR lcb.NgayHetHieuLuc >= STR_TO_DATE(CONCAT(p_Nam, '-', LPAD(p_Thang,2,'0'), '-01'), '%Y-%m-%d'))
    WHERE nv.TrangThai IN ('A','P')
      AND (p_MaPB IS NULL OR nv.MaPB = p_MaPB)
      AND IFNULL(lhd.TiLeBHXH, 0) > 0
    GROUP BY pb.TenPB WITH ROLLUP
    ORDER BY pb.TenPB IS NULL, pb.TenPB;
END$$

DELIMITER ;

SELECT '[OK] sp_TaoBangLuong_BHXH' AS Status;


-- ============================================================
-- SP 4: sp_TaoBangLuong_QuyetToanThue
-- Dữ liệu quyết toán thuế TNCN cuối năm
-- ============================================================
DROP PROCEDURE IF EXISTS sp_TaoBangLuong_QuyetToanThue;

DELIMITER $$

CREATE PROCEDURE sp_TaoBangLuong_QuyetToanThue(
    IN p_Nam   SMALLINT,
    IN p_MaNV  VARCHAR(8)   -- NULL = tất cả
)
BEGIN
    IF p_Nam IS NULL THEN SET p_Nam = YEAR(CURDATE()) - 1; END IF;

    SELECT
        nv.MaNV,
        nv.HoTen,
        nv.MaSoThue,
        pb.TenPB                                            AS PhongBan,
        p_Nam                                               AS Nam,
        COUNT(bl.MaBL)                                      AS SoThangLamViec,
        FORMAT(SUM(bl.ThuNhapGop), 0)                       AS TongThuNhapGross,
        FORMAT(SUM(bl.BHXH_NLD + bl.BHYT_NLD + bl.BHTN_NLD), 0) AS TongKhauTruBH,
        FORMAT(COUNT(bl.MaBL) * 11000000, 0)                AS TongGiamTruBanThan,
        FORMAT(SUM(fn_TinhGiamTruPhuThuoc(nv.SoNguoiPhuThuoc)), 0) AS TongGiamTruPT,
        FORMAT(
            GREATEST(
                SUM(bl.ThuNhapGop)
                - SUM(bl.BHXH_NLD + bl.BHYT_NLD + bl.BHTN_NLD)
                - COUNT(bl.MaBL) * 11000000
                - SUM(fn_TinhGiamTruPhuThuoc(nv.SoNguoiPhuThuoc)), 0
            ), 0
        )                                                   AS TongTNChiuThue,
        FORMAT(SUM(bl.ThueTNCN), 0)                         AS TongThueTNCN_DaDong,
        nv.SoNguoiPhuThuoc
    FROM BangLuong bl
    JOIN NhanVien nv ON bl.MaNV = nv.MaNV
    JOIN PhongBan pb ON nv.MaPB = pb.MaPB
    WHERE bl.Nam = p_Nam
      AND bl.TrangThai IN ('C','P','L')
      AND (p_MaNV IS NULL OR bl.MaNV = p_MaNV)
    GROUP BY nv.MaNV, nv.HoTen, nv.MaSoThue, pb.TenPB, nv.SoNguoiPhuThuoc
    ORDER BY SUM(bl.ThueTNCN) DESC;
END$$

DELIMITER ;

SELECT '[OK] sp_TaoBangLuong_QuyetToanThue' AS Status;


-- ============================================================
-- SP 5: sp_TaoBangLuong_SoSanh
-- So sánh quỹ lương giữa các kỳ
-- ============================================================
DROP PROCEDURE IF EXISTS sp_TaoBangLuong_SoSanh;

DELIMITER $$

CREATE PROCEDURE sp_TaoBangLuong_SoSanh(
    IN p_TuThang  TINYINT,
    IN p_TuNam    SMALLINT,
    IN p_DenThang TINYINT,
    IN p_DenNam   SMALLINT
)
BEGIN
    SELECT
        CONCAT(bl.Thang, '/', bl.Nam)                       AS KyLuong,
        bl.Nam,
        bl.Thang,
        COUNT(DISTINCT bl.MaNV)                             AS SoNhanVien,
        FORMAT(SUM(bl.ThuNhapGop), 0)                       AS TongGross,
        FORMAT(SUM(bl.ThuNhapThucLinh), 0)                  AS TongThucLinh,
        FORMAT(AVG(bl.ThuNhapThucLinh), 0)                  AS LuongNetTrungBinh,
        FORMAT(SUM(bl.ThueTNCN), 0)                         AS TongThueTNCN,
        FORMAT(SUM(bl.BHXH_NLD + bl.BHYT_NLD + bl.BHTN_NLD), 0) AS TongBH_NLD,
        FORMAT(SUM(bl.TongPhuCap), 0)                       AS TongPhuCap,
        FORMAT(SUM(bl.TongKhauTru), 0)                      AS TongKhauTru,
        SUM(CASE WHEN bl.TrangThai = 'D' THEN 1 ELSE 0 END) AS SoNhap,
        SUM(CASE WHEN bl.TrangThai = 'C' THEN 1 ELSE 0 END) AS SoXacNhan,
        SUM(CASE WHEN bl.TrangThai = 'P' THEN 1 ELSE 0 END) AS SoThanhToan
    FROM BangLuong bl
    WHERE (bl.Nam * 100 + bl.Thang) BETWEEN (p_TuNam * 100 + p_TuThang)
                                        AND  (p_DenNam * 100 + p_DenThang)
    GROUP BY bl.Nam, bl.Thang
    ORDER BY bl.Nam, bl.Thang;
END$$

DELIMITER ;

SELECT '[OK] sp_TaoBangLuong_SoSanh' AS Status;


-- ============================================================
-- SP 6: sp_TaoBangLuong_ChiPhiNhanSu
-- Chi phí nhân sự toàn bộ doanh nghiệp (bao gồm BH NSDLĐ)
-- ============================================================
DROP PROCEDURE IF EXISTS sp_TaoBangLuong_ChiPhiNhanSu;

DELIMITER $$

CREATE PROCEDURE sp_TaoBangLuong_ChiPhiNhanSu(
    IN p_Thang    TINYINT,
    IN p_Nam      SMALLINT,
    IN p_MaPB     VARCHAR(6)
)
BEGIN
    -- RS1: Chi phí theo từng NV
    SELECT
        pb.TenPB                                            AS PhongBan,
        nv.MaNV,
        nv.HoTen,
        cv.TenCV                                            AS ChucVu,
        FORMAT(bl.ThuNhapGop, 0)                            AS LuongGross,
        FORMAT(ROUND(fn_TinhBH_NSDLD(bl.LuongCoBan, hd.MaLoaiHD), 0), 0) AS BH_NSDLD,
        FORMAT(
            bl.ThuNhapGop +
            ROUND(fn_TinhBH_NSDLD(bl.LuongCoBan, hd.MaLoaiHD), 0), 0
        )                                                   AS TongChiPhiNhanSu,
        FORMAT(bl.ThuNhapThucLinh, 0)                       AS ThucLinh_NLD
    FROM BangLuong bl
    JOIN NhanVien  nv  ON bl.MaNV = nv.MaNV
    JOIN PhongBan  pb  ON nv.MaPB = pb.MaPB
    JOIN ChucVu    cv  ON nv.MaCV = cv.MaCV
    LEFT JOIN HopDong hd  ON nv.MaNV = hd.MaNV AND hd.TrangThai = 'A'
    WHERE bl.Thang = p_Thang
      AND bl.Nam   = p_Nam
      AND (p_MaPB IS NULL OR nv.MaPB = p_MaPB)
    ORDER BY pb.TenPB, bl.ThuNhapGop DESC;

    -- RS2: Tổng hợp chi phí nhân sự theo PB
    SELECT
        COALESCE(pb.TenPB, '=== TOÀN CÔNG TY ===')         AS PhongBan,
        COUNT(bl.MaBL)                                      AS SoNhanVien,
        FORMAT(SUM(bl.ThuNhapGop), 0)                       AS TongGross,
        FORMAT(SUM(ROUND(fn_TinhBH_NSDLD(bl.LuongCoBan, hd.MaLoaiHD), 0)), 0) AS TongBH_NSDLD,
        FORMAT(
            SUM(bl.ThuNhapGop) +
            SUM(ROUND(fn_TinhBH_NSDLD(bl.LuongCoBan, hd.MaLoaiHD), 0)), 0
        )                                                   AS TongChiPhiNhanSu,
        FORMAT(AVG(
            bl.ThuNhapGop +
            ROUND(fn_TinhBH_NSDLD(bl.LuongCoBan, hd.MaLoaiHD), 0)), 0
        )                                                   AS ChiPhiTrungBinh_NV
    FROM BangLuong bl
    JOIN NhanVien  nv  ON bl.MaNV = nv.MaNV
    JOIN PhongBan  pb  ON nv.MaPB = pb.MaPB
    LEFT JOIN HopDong hd  ON nv.MaNV = hd.MaNV AND hd.TrangThai = 'A'
    WHERE bl.Thang = p_Thang
      AND bl.Nam   = p_Nam
      AND (p_MaPB IS NULL OR nv.MaPB = p_MaPB)
    GROUP BY pb.TenPB WITH ROLLUP
    ORDER BY pb.TenPB IS NULL, pb.TenPB;
END$$

DELIMITER ;

SELECT '[OK] sp_TaoBangLuong_ChiPhiNhanSu' AS Status;


-- ============================================================
-- THÊM: sp_XacNhanBangLuong — Xác nhận bảng lương (D→C)
-- ============================================================
DROP PROCEDURE IF EXISTS sp_XacNhanBangLuong;

DELIMITER $$

CREATE PROCEDURE sp_XacNhanBangLuong(
    IN p_Thang          TINYINT,
    IN p_Nam            SMALLINT,
    IN p_MaNV_Filter    VARCHAR(8),
    IN p_NguoiXacNhan   VARCHAR(100)
)
BEGIN
    DECLARE v_SoXacNhan INT DEFAULT 0;

    -- Validate: Chỉ xác nhận bản nháp
    IF NOT EXISTS (
        SELECT 1 FROM BangLuong
        WHERE Thang = p_Thang AND Nam = p_Nam
          AND TrangThai = 'D'
          AND (p_MaNV_Filter IS NULL OR MaNV = p_MaNV_Filter)
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'sp_XacNhanBangLuong: Không có bản nháp để xác nhận.';
    END IF;

    UPDATE BangLuong
    SET TrangThai   = 'C',
        NgayXacNhan = NOW(),
        NguoiTao    = COALESCE(p_NguoiXacNhan, CURRENT_USER())
    WHERE Thang     = p_Thang
      AND Nam       = p_Nam
      AND TrangThai = 'D'
      AND (p_MaNV_Filter IS NULL OR MaNV = p_MaNV_Filter);

    SET v_SoXacNhan = ROW_COUNT();

    SELECT CONCAT('[OK] Đã xác nhận ', v_SoXacNhan, ' bảng lương T', p_Thang, '/', p_Nam) AS KetQua;
END$$

DELIMITER ;

SELECT '[OK] sp_XacNhanBangLuong' AS Status;


-- ============================================================
-- THÊM: sp_ThanhToanLuong — Đánh dấu đã thanh toán (C→P)
-- ============================================================
DROP PROCEDURE IF EXISTS sp_ThanhToanLuong;

DELIMITER $$

CREATE PROCEDURE sp_ThanhToanLuong(
    IN p_Thang          TINYINT,
    IN p_Nam            SMALLINT,
    IN p_NguoiThanhToan VARCHAR(100)
)
BEGIN
    DECLARE v_SoThanhToan INT DEFAULT 0;

    UPDATE BangLuong
    SET TrangThai      = 'P',
        NgayThanhToan  = NOW()
    WHERE Thang        = p_Thang
      AND Nam          = p_Nam
      AND TrangThai    = 'C';

    SET v_SoThanhToan = ROW_COUNT();

    SELECT CONCAT('[OK] Đã thanh toán ', v_SoThanhToan, ' bảng lương T', p_Thang, '/', p_Nam) AS KetQua;
END$$

DELIMITER ;

SELECT '[OK] sp_ThanhToanLuong' AS Status;

-- ============================================================
-- KIỂM THỬ (sau khi có dữ liệu)
-- ============================================================
-- CALL sp_TinhLuong(1, 2025, NULL, 0, 0);
-- CALL sp_XacNhanBangLuong(1, 2025, NULL, 'NV000001');
-- CALL sp_TaoBangLuong_ChinhThuc(1, 2025, NULL, 'C');
-- CALL sp_TaoBangLuong_PhieuLuong('NV000001', 1, 2025);
-- CALL sp_TaoBangLuong_BHXH(1, 2025, NULL);
-- CALL sp_TaoBangLuong_SoSanh(1, 2025, 3, 2025);

SELECT '[DONE] sp_TaoBangLuong.sql — 8 procedures hoàn tất.' AS Status;
