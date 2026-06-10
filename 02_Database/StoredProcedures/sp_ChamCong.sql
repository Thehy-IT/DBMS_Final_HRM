/*
PROJECT    : Hệ Thống Quản Lý Nhân Sự & Tính Lương Tự Động
MỤC ĐÍCH   : Stored Procedures quản lý toàn bộ vòng đời
             chấm công: nhập liệu, cập nhật, đồng bộ,
              phê duyệt nghỉ phép và báo cáo
 PROCEDURES :
   1. sp_ChamCong_NhapHangNgay   — UPSERT 1 NV 1 ngày
   2. sp_ChamCong_NhapLoat       — Nhập hàng loạt từ bảng tạm
   3. sp_ChamCong_CapNhat        — Sửa trạng thái / giờ giấc
   4. sp_ChamCong_DongBoNghiPhep — Đồng bộ đơn đã duyệt → CC
   5. sp_NghiPhep_PheDuyet       — Duyệt / từ chối đơn nghỉ
   6. sp_ChamCong_BaoCaoThang    — Báo cáo tổng hợp kỳ lương
 DBMS       : MySQL 8.0+
*/


USE HRPayrollDB;

-- SP 1: sp_ChamCong_NhapHangNgay
-- UPSERT chấm công 1 nhân viên 1 ngày
DROP PROCEDURE IF EXISTS sp_ChamCong_NhapHangNgay;

DELIMITER $$
CREATE PROCEDURE sp_ChamCong_NhapHangNgay(
    IN  p_MaNV           VARCHAR(8),
    IN  p_NgayCham        DATE,
    IN  p_TrangThai       VARCHAR(3),     -- DL/WFH/CX/NP/OM/KP/NG
    IN  p_GioVao          TIME,
    IN  p_GioRa           TIME,
    IN  p_SoGioTangCa     DECIMAL(4,2),
    IN  p_HeSoTangCa      DECIMAL(4,2),
    IN  p_GhiChu          VARCHAR(300),
    IN  p_NguoiCapNhat    VARCHAR(100),
    OUT p_MaCC_Out        BIGINT
)
BEGIN
    DECLARE v_SoGioTangCa  DECIMAL(4,2);
    DECLARE v_HeSoTangCa   DECIMAL(4,2);

    SET v_SoGioTangCa = IFNULL(p_SoGioTangCa, 0);
    SET v_HeSoTangCa  = IFNULL(p_HeSoTangCa, 1.50);

    -- Validate: NV tồn tại & đang làm việc
    IF NOT EXISTS (
        SELECT 1 FROM NhanVien
        WHERE MaNV = p_MaNV AND TrangThai IN ('A', 'P', 'L')
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'sp_ChamCong_NhapHangNgay: NV không tồn tại hoặc đã nghỉ việc.';
    END IF;

    -- Validate: không chấm tương lai (BR-11)
    IF p_NgayCham > CURDATE() THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'sp_ChamCong_NhapHangNgay: Không được chấm công ngày tương lai.';
    END IF;

    -- Validate: trạng thái hợp lệ (BR-09)
    IF p_TrangThai NOT IN ('DL', 'WFH', 'CX', 'NP', 'OM', 'KP', 'NG') THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'sp_ChamCong_NhapHangNgay: TrangThai không hợp lệ. Dùng: DL/WFH/CX/NP/OM/KP/NG.';
    END IF;

    -- Validate: giờ vào/ra
    IF p_GioVao IS NOT NULL AND p_GioRa IS NOT NULL AND p_GioRa <= p_GioVao THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'sp_ChamCong_NhapHangNgay: GioRa phải sau GioVao.';
    END IF;

    -- Validate: hệ số tăng ca hợp lệ
    IF v_HeSoTangCa NOT IN (1.00, 1.50, 2.00, 3.00) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'sp_ChamCong_NhapHangNgay: HeSoTangCa chỉ được: 1.00/1.50/2.00/3.00.';
    END IF;

    -- UPSERT chấm công
    -- Dùng alias row syntax: INSERT ... AS new_row ON DUPLICATE KEY UPDATE col = new_row.col
    INSERT INTO ChamCong (
        MaNV, NgayCham, GioVao, GioRa,
        TrangThai, SoGioTangCa, HeSoTangCa,
        GhiChu, NguoiCapNhat
    )
    VALUES (
        p_MaNV, p_NgayCham, p_GioVao, p_GioRa,
        p_TrangThai, v_SoGioTangCa, v_HeSoTangCa,
        p_GhiChu, IFNULL(p_NguoiCapNhat, CURRENT_USER())
    ) AS cc_new
    ON DUPLICATE KEY UPDATE
        GioVao          = cc_new.GioVao,
        GioRa           = cc_new.GioRa,
        TrangThai       = cc_new.TrangThai,
        SoGioTangCa     = cc_new.SoGioTangCa,
        HeSoTangCa      = cc_new.HeSoTangCa,
        GhiChu          = cc_new.GhiChu,
        NguoiCapNhat    = cc_new.NguoiCapNhat;

    -- Trả MaCC
    IF ROW_COUNT() > 0 THEN
        SET p_MaCC_Out = LAST_INSERT_ID();
        IF p_MaCC_Out = 0 THEN
            SELECT MaCC INTO p_MaCC_Out FROM ChamCong
            WHERE MaNV = p_MaNV AND NgayCham = p_NgayCham;
        END IF;
    END IF;

    SELECT CONCAT('[OK] Chấm công ', p_MaNV, ' ngày ', p_NgayCham,
                  ' → MaCC=', IFNULL(p_MaCC_Out, 0)) AS KetQua;
END$$
DELIMITER ;

SELECT 'sp_ChamCong_NhapHangNgay' AS Status;


-- SP 2: sp_ChamCong_NhapLoat
-- Nhập hàng loạt từ temporary table
DROP PROCEDURE IF EXISTS sp_ChamCong_NhapLoat;

DELIMITER $$
CREATE PROCEDURE sp_ChamCong_NhapLoat(
    IN p_NguoiCapNhat VARCHAR(100)
)
BEGIN
    -- Caller tạo bảng tạm trước khi gọi procedure:
    -- CREATE TEMPORARY TABLE tmp_ChamCong_Input (
    --     MaNV CHAR(8), NgayCham DATE, TrangThai CHAR(3),
    --     GioVao TIME, GioRa TIME, SoGioTangCa DECIMAL(4,2),
    --     HeSoTangCa DECIMAL(4,2), GhiChu VARCHAR(300)
    -- );

    DECLARE v_SoThanhCong INT DEFAULT 0;
    DECLARE v_SoLoi       INT DEFAULT 0;
    DECLARE v_Tong        INT DEFAULT 0;

    -- Validate cơ bản
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables
                   WHERE table_schema = DATABASE()
                     AND table_name = 'tmp_ChamCong_Input') THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'sp_ChamCong_NhapLoat: Bảng tmp_ChamCong_Input chưa được tạo.';
    END IF;

    -- Đếm dòng
    SELECT COUNT(*) INTO v_Tong FROM tmp_ChamCong_Input;

    -- Kiểm tra dòng không hợp lệ
    SELECT COUNT(*) INTO v_SoLoi
    FROM tmp_ChamCong_Input ti
    WHERE ti.NgayCham > CURDATE()
       OR ti.TrangThai NOT IN ('DL','WFH','CX','NP','OM','KP','NG')
       OR NOT EXISTS (SELECT 1 FROM NhanVien WHERE MaNV = ti.MaNV AND TrangThai IN ('A','P','L'));

    -- INSERT hàng loạt (chỉ dòng hợp lệ)
    -- Dùng alias row syntax
    INSERT INTO ChamCong (
        MaNV, NgayCham, GioVao, GioRa,
        TrangThai, SoGioTangCa, HeSoTangCa,
        GhiChu, NguoiCapNhat
    )
    SELECT
        ti.MaNV, ti.NgayCham, ti.GioVao, ti.GioRa,
        ti.TrangThai,
        IFNULL(ti.SoGioTangCa, 0),
        IFNULL(ti.HeSoTangCa, 1.50),
        ti.GhiChu,
        IFNULL(p_NguoiCapNhat, CURRENT_USER())
    FROM tmp_ChamCong_Input ti
    WHERE ti.NgayCham <= CURDATE()
      AND ti.TrangThai IN ('DL','WFH','CX','NP','OM','KP','NG')
      AND EXISTS (SELECT 1 FROM NhanVien WHERE MaNV = ti.MaNV AND TrangThai IN ('A','P','L'))
    ON DUPLICATE KEY UPDATE
    TrangThai    = new.TrangThai,
    GioVao       = new.GioVao,
    GioRa        = new.GioRa,
    SoGioTangCa  = new.SoGioTangCa,
    HeSoTangCa   = new.HeSoTangCa,
    GhiChu       = new.GhiChu,
    NguoiCapNhat = new.NguoiCapNhat;
    SET v_SoThanhCong = ROW_COUNT();

    SELECT
        v_Tong          AS TongDong,
        v_SoThanhCong   AS ThanhCong,
        v_SoLoi         AS Loi;
END$$
DELIMITER ;

SELECT 'Sp_ChamCong_NhapLoat' AS Status;


-- SP 3: sp_ChamCong_CapNhat
-- Sửa trạng thái / giờ giấc của bản ghi chấm công
DROP PROCEDURE IF EXISTS sp_ChamCong_CapNhat;

DELIMITER $$
CREATE PROCEDURE sp_ChamCong_CapNhat(
    IN p_MaCC         BIGINT,
    IN p_TrangThai    VARCHAR(3),
    IN p_GioVao       TIME,
    IN p_GioRa        TIME,
    IN p_SoGioTangCa  DECIMAL(4,2),
    IN p_HeSoTangCa   DECIMAL(4,2),
    IN p_GhiChu       VARCHAR(300),
    IN p_NguoiCapNhat VARCHAR(100)
)
BEGIN
    -- Kiểm tra bản ghi tồn tại
    IF NOT EXISTS (SELECT 1 FROM ChamCong WHERE MaCC = p_MaCC) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'sp_ChamCong_CapNhat: MaCC không tồn tại.';
    END IF;

    -- Validate TrangThai
    IF p_TrangThai IS NOT NULL
       AND p_TrangThai NOT IN ('DL','WFH','CX','NP','OM','KP','NG')
    THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'sp_ChamCong_CapNhat: TrangThai không hợp lệ.';
    END IF;

    -- Validate giờ giấc
    IF p_GioVao IS NOT NULL AND p_GioRa IS NOT NULL AND p_GioRa <= p_GioVao THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'sp_ChamCong_CapNhat: GioRa phải sau GioVao.';
    END IF;

    UPDATE ChamCong
    SET
        TrangThai    = COALESCE(p_TrangThai,    TrangThai),
        GioVao       = COALESCE(p_GioVao,       GioVao),
        GioRa        = COALESCE(p_GioRa,        GioRa),
        SoGioTangCa  = COALESCE(p_SoGioTangCa,  SoGioTangCa),
        HeSoTangCa   = COALESCE(p_HeSoTangCa,   HeSoTangCa),
        GhiChu       = COALESCE(p_GhiChu,       GhiChu),
        NguoiCapNhat = IFNULL(p_NguoiCapNhat, CURRENT_USER())
    WHERE MaCC = p_MaCC;

    SELECT CONCAT('[OK] Đã cập nhật MaCC=', p_MaCC) AS KetQua;
END$$
DELIMITER ;

SELECT 'sp_ChamCong_CapNhat' AS Status;


-- SP 4: sp_ChamCong_DongBoNghiPhep
-- Đồng bộ đơn nghỉ phép đã duyệt → ChamCong
DROP PROCEDURE IF EXISTS sp_ChamCong_DongBoNghiPhep;

DELIMITER $$
CREATE PROCEDURE sp_ChamCong_DongBoNghiPhep(
    IN p_Thang TINYINT,
    IN p_Nam   SMALLINT
)
BEGIN
    DECLARE v_NgayDauThang  DATE;
    DECLARE v_NgayCuoiThang DATE;
    DECLARE v_SoDongBo      INT DEFAULT 0;

    SET v_NgayDauThang  = STR_TO_DATE(CONCAT(p_Nam, '-', LPAD(p_Thang, 2, '0'), '-01'), '%Y-%m-%d');
    SET v_NgayCuoiThang = LAST_DAY(v_NgayDauThang);

    -- Tạo bảng ngày trong tháng
    DROP TEMPORARY TABLE IF EXISTS tmp_NgayTrongThang;
    CREATE TEMPORARY TABLE tmp_NgayTrongThang (NgayLam DATE);

    -- Sinh danh sách ngày trong tháng
    SET @ngay = v_NgayDauThang;
    WHILE @ngay <= v_NgayCuoiThang DO
        INSERT INTO tmp_NgayTrongThang VALUES (@ngay);
        SET @ngay = DATE_ADD(@ngay, INTERVAL 1 DAY);
    END WHILE;

    -- Đồng bộ đơn nghỉ đã duyệt (NP) vào ChamCong
    -- LƯU Ý MySQL 8.0.46: VALUES() bị deprecated từ 8.0.20 → dùng alias row syntax
    INSERT INTO ChamCong (MaNV, NgayCham, TrangThai, GhiChu, NguoiCapNhat)
    SELECT * FROM (
    SELECT DISTINCT
        np.MaNV,
        ng.NgayLam AS NgayCham,
        CASE lnp.TenLoaiNghi
            WHEN 'Nghỉ ốm'   THEN 'OM'
            ELSE 'NP'
        END AS TrangThai,
        CONCAT('Đồng bộ từ đơn nghỉ MaNP=', np.MaNP) AS GhiChu,
        'SYS_SYNC' AS NguoiCapNhat
    FROM NghiPhep np
    JOIN tmp_NgayTrongThang ng ON ng.NgayLam BETWEEN np.NgayBatDau AND np.NgayKetThuc
    JOIN LoaiNghiPhep lnp ON np.MaLoaiNghi = lnp.MaLoaiNghi
    WHERE np.TrangThai = 'A'
      AND ng.NgayLam BETWEEN v_NgayDauThang AND v_NgayCuoiThang
      AND DAYOFWEEK(ng.NgayLam) NOT IN (1, 7)  -- Loại cuối tuần
    ) AS cc_sync
    ON DUPLICATE KEY UPDATE
        TrangThai = cc_sync.TrangThai,
        GhiChu    = cc_sync.GhiChu;

    SET v_SoDongBo = ROW_COUNT();
    DROP TEMPORARY TABLE IF EXISTS tmp_NgayTrongThang;

    SELECT CONCAT('[OK] Đồng bộ ', v_SoDongBo, ' bản ghi chấm công từ đơn nghỉ phép ',
                  p_Thang, '/', p_Nam) AS KetQua;
END$$
DELIMITER ;

SELECT 'sp_ChamCong_DongBoNghiPhep' AS Status;


-- SP 5: sp_NghiPhep_PheDuyet
-- Duyệt hoặc từ chối đơn nghỉ phép
DROP PROCEDURE IF EXISTS sp_NghiPhep_PheDuyet;

DELIMITER $$
CREATE PROCEDURE sp_NghiPhep_PheDuyet(
    IN p_MaNP       INT,
    IN p_HanhDong   CHAR(1),     -- A=Approve, R=Reject, C=Cancel
    IN p_NguoiDuyet VARCHAR(100),
    IN p_GhiChu     VARCHAR(255)
)
BEGIN
    DECLARE v_TrangThaiHienTai CHAR(1);
    DECLARE v_MaNV              CHAR(8);

    -- Lấy trạng thái hiện tại
    SELECT TrangThai, MaNV INTO v_TrangThaiHienTai, v_MaNV
    FROM NghiPhep WHERE MaNP = p_MaNP;

    IF v_TrangThaiHienTai IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'sp_NghiPhep_PheDuyet: MaNP không tồn tại.';
    END IF;

    IF v_TrangThaiHienTai NOT IN ('P') THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'sp_NghiPhep_PheDuyet: Chỉ duyệt/từ chối đơn đang PENDING.';
    END IF;

    IF p_HanhDong NOT IN ('A', 'R', 'C') THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'sp_NghiPhep_PheDuyet: HanhDong phải là A/R/C.';
    END IF;

    UPDATE NghiPhep
    SET TrangThai   = p_HanhDong,
        NguoiDuyet  = p_NguoiDuyet,
        NgayDuyet   = NOW(),
        GhiChu      = COALESCE(p_GhiChu, GhiChu)
    WHERE MaNP = p_MaNP;

    SELECT CONCAT('[OK] Đơn nghỉ MaNP=', p_MaNP, ' → ',
                  CASE p_HanhDong WHEN 'A' THEN 'ĐÃ DUYỆT'
                                  WHEN 'R' THEN 'TỪ CHỐI'
                                  ELSE 'ĐÃ HỦY' END) AS KetQua;
END$$
DELIMITER ;

SELECT 'sp_NghiPhep_PheDuyet' AS Status;


-- SP 6: sp_ChamCong_BaoCaoThang
-- Báo cáo tổng hợp chấm công tháng
DROP PROCEDURE IF EXISTS sp_ChamCong_BaoCaoThang;

DELIMITER $$
CREATE PROCEDURE sp_ChamCong_BaoCaoThang(
    IN p_Thang    TINYINT,
    IN p_Nam      SMALLINT,
    IN p_MaPB     VARCHAR(6)   -- NULL = tất cả phòng ban
)
BEGIN
    -- RS1: Tổng hợp theo nhân viên
    SELECT
        nv.MaNV,
        nv.HoTen,
        pb.TenPB                AS PhongBan,
        cv.TenCV                AS ChucVu,
        SUM(CASE WHEN cc.TrangThai = 'DL'  THEN 1 ELSE 0 END) AS NgayDiLam,
        SUM(CASE WHEN cc.TrangThai = 'WFH' THEN 1 ELSE 0 END) AS NgayWFH,
        SUM(CASE WHEN cc.TrangThai = 'CX'  THEN 1 ELSE 0 END) AS NgayCongTac,
        SUM(CASE WHEN cc.TrangThai = 'NP'  THEN 1 ELSE 0 END) AS NgayNghiPhep,
        SUM(CASE WHEN cc.TrangThai = 'OM'  THEN 1 ELSE 0 END) AS NgayNghiOm,
        SUM(CASE WHEN cc.TrangThai = 'KP'  THEN 1 ELSE 0 END) AS NgayVangKP,
        SUM(IFNULL(cc.SoGioTangCa, 0))       AS TongGioTangCa,
        fn_SoNgayChuanThang(p_Thang, p_Nam)  AS NgayChuan,
        CONCAT(ROUND(
            SUM(CASE WHEN cc.TrangThai IN ('DL','WFH','CX') THEN 1 ELSE 0 END)
            / fn_SoNgayChuanThang(p_Thang, p_Nam) * 100, 1
        ), '%')                              AS TyLeChuyenCan
    FROM ChamCong cc
    JOIN NhanVien nv ON cc.MaNV = nv.MaNV
    JOIN PhongBan pb ON nv.MaPB = pb.MaPB
    JOIN ChucVu   cv ON nv.MaCV = cv.MaCV
    WHERE MONTH(cc.NgayCham) = p_Thang
      AND YEAR(cc.NgayCham)  = p_Nam
      AND (p_MaPB IS NULL OR nv.MaPB = p_MaPB)
    GROUP BY nv.MaNV, nv.HoTen, pb.TenPB, cv.TenCV
    ORDER BY NgayVangKP DESC, TongGioTangCa DESC;

    -- RS2: Tổng hợp theo phòng ban
    SELECT
        pb.TenPB                AS PhongBan,
        COUNT(DISTINCT cc.MaNV) AS SoNhanVien,
        SUM(CASE WHEN cc.TrangThai IN ('DL','WFH','CX') THEN 1 ELSE 0 END) AS TongNgayDiLam,
        SUM(CASE WHEN cc.TrangThai = 'KP' THEN 1 ELSE 0 END) AS TongVangKP,
        SUM(IFNULL(cc.SoGioTangCa, 0)) AS TongGioTangCa,
        CONCAT(ROUND(
            SUM(CASE WHEN cc.TrangThai IN ('DL','WFH','CX') THEN 1 ELSE 0 END)
            / NULLIF(COUNT(DISTINCT cc.MaNV) * fn_SoNgayChuanThang(p_Thang, p_Nam), 0) * 100, 1
        ), '%')                AS TyLeChuyenCanTB
    FROM ChamCong cc
    JOIN NhanVien nv ON cc.MaNV = nv.MaNV
    JOIN PhongBan pb ON nv.MaPB = pb.MaPB
    WHERE MONTH(cc.NgayCham) = p_Thang
      AND YEAR(cc.NgayCham)  = p_Nam
      AND (p_MaPB IS NULL OR nv.MaPB = p_MaPB)
    GROUP BY pb.TenPB
    ORDER BY TongVangKP DESC;
END$$
DELIMITER ;

SELECT 'sp_ChamCong_BaoCaoThang' AS Status;

-- KIỂM THỬ
-- CALL sp_ChamCong_NhapHangNgay('NV000001','2025-01-15','DL','08:00','17:30',2.0,1.50,'Tăng ca',NULL,@MaCC);
-- CALL sp_ChamCong_BaoCaoThang(1, 2025, NULL);