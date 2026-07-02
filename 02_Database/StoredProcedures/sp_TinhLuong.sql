/*
PROJECT    : Hệ Thống Quản Lý Nhân Sự & Tính Lương Tự Động
MỤC ĐÍCH   : Stored Procedure cốt lõi — tính lương tự động
             toàn bộ nhân viên cho 1 kỳ lương (tháng/năm)
CÁCH GỌI:
  CALL sp_TinhLuong(3, 2025, NULL, 0, 0);  -- Tính T3/2025 tất cả NV
  CALL sp_TinhLuong(3, 2025, 'NV000001', 0, 0); -- Tính riêng 1 NV
  CALL sp_TinhLuong(3, 2025, NULL, 1, 0);  -- Tính lại (ghi đè bản nháp)
DBMS       : MySQL 8.0.46
GHI CHÚ   : - CURSOR syntax khác SQL Server
             - GOTO không hỗ trợ → dùng ITERATE/LEAVE
             - RAISERROR → SIGNAL SQLSTATE
             - DATEFROMPARTS → MAKEDATE / STR_TO_DATE
             - EOMONTH → LAST_DAY
             - TOP 1 → LIMIT 1
             - dbo. prefix không dùng trong MySQL
             - VALUES() trong ON DUPLICATE KEY UPDATE deprecated từ 8.0.20
               → dùng alias row syntax thay thế
*/


USE HRPayrollDB;

DROP PROCEDURE IF EXISTS sp_TinhLuong;

DELIMITER $$
CREATE PROCEDURE sp_TinhLuong(
    IN p_Thang          TINYINT,
    IN p_Nam            SMALLINT,
    IN p_MaNV_Filter    VARCHAR(10),  -- NULL = tất cả NV
    IN p_Override       TINYINT,      -- 1 = ghi đè bản nháp cũ
    IN p_DryRun         TINYINT       -- 1 = chỉ xem kết quả, không ghi DB
)
BEGIN
    -- Khai báo biến
    DECLARE v_NgayDauThang       DATE;
    DECLARE v_NgayCuoiThang      DATE;
    DECLARE v_NgayChuanThang     TINYINT;
    DECLARE v_SoNVXuLy           INT DEFAULT 0;
    DECLARE v_SoNVThanhCong      INT DEFAULT 0;
    DECLARE v_SoNVLoiToi         INT DEFAULT 0;
    DECLARE v_TongQuyLuong       DECIMAL(18,2) DEFAULT 0;

    -- Biến từng NV (dùng trong CURSOR)
    DECLARE v_cur_MaNV           VARCHAR(8);
    DECLARE v_cur_HoTen          VARCHAR(100);
    DECLARE v_cur_TrangThaiNV    CHAR(1);
    DECLARE v_cur_SoNguoiPT      TINYINT;

    -- Hợp đồng
    DECLARE v_cur_MaLoaiHD       TINYINT;
    DECLARE v_cur_LuongHD        DECIMAL(18,2);
    DECLARE v_cur_VungLuong      TINYINT;

    -- Lương cơ bản
    DECLARE v_cur_LuongCB        DECIMAL(18,2);
    DECLARE v_cur_LuongDongBH    DECIMAL(18,2);

    -- Ngày công
    DECLARE v_cur_NgayDiLam      DECIMAL(5,1);
    DECLARE v_cur_NgayNghiCL     DECIMAL(5,1);
    DECLARE v_cur_NgayKhongPhep  DECIMAL(5,1);
    DECLARE v_cur_HeSoLuong      DECIMAL(10,6);

    -- Lương tính toán
    DECLARE v_cur_LuongTheoNgay  DECIMAL(18,2);
    DECLARE v_cur_LuongLamThem   DECIMAL(18,2);
    DECLARE v_cur_TongPhuCap     DECIMAL(18,2);
    DECLARE v_cur_PhuCapChiuThue DECIMAL(18,2);
    DECLARE v_cur_LuongGross     DECIMAL(18,2);

    -- Bảo hiểm NLĐ
    DECLARE v_cur_BHXH_NLD       DECIMAL(18,2);
    DECLARE v_cur_BHYT_NLD       DECIMAL(18,2);
    DECLARE v_cur_BHTN_NLD       DECIMAL(18,2);
    DECLARE v_cur_TongBH_NLD     DECIMAL(18,2);

    -- Thuế TNCN
    DECLARE v_cur_GiamTruBT      DECIMAL(18,2) DEFAULT 11000000;
    DECLARE v_cur_GiamTruPT      DECIMAL(18,2);
    DECLARE v_cur_ThuNhapTT      DECIMAL(18,2);
    DECLARE v_cur_ThueTNCN       DECIMAL(18,2);
    DECLARE v_cur_BacThue        TINYINT;

    -- Khấu trừ khác
    DECLARE v_cur_TongKhauTru    DECIMAL(18,2);

    -- Kết quả
    DECLARE v_cur_LuongNet       DECIMAL(18,2);
    DECLARE v_cur_MaBL           BIGINT;

    DECLARE v_done               INT DEFAULT FALSE;

    -- BƯỚC A — VALIDATE ĐẦU VÀO
    IF p_Thang NOT BETWEEN 1 AND 12 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'sp_TinhLuong: @Thang phải từ 1 đến 12.';
    END IF;

    IF p_Nam NOT BETWEEN 2000 AND 2100 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'sp_TinhLuong: @Nam phải từ 2000 đến 2100.';
    END IF;

    SET v_NgayDauThang  = STR_TO_DATE(CONCAT(p_Nam, '-', LPAD(p_Thang, 2, '0'), '-01'), '%Y-%m-%d');
    SET v_NgayCuoiThang = LAST_DAY(v_NgayDauThang);

    IF v_NgayDauThang > CURDATE() THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'sp_TinhLuong: Không thể tính lương cho kỳ tương lai.';
    END IF;

    SET v_NgayChuanThang = fn_SoNgayChuanThang(p_Thang, p_Nam);

    -- Guard 1: Ngăn chặn tuyệt đối việc tính lại bảng lương đã Xác nhận/Thanh toán/Khóa
    IF EXISTS (
        SELECT 1 FROM BangLuong
        WHERE Thang     = p_Thang
          AND Nam       = p_Nam
          AND TrangThai IN ('C', 'P', 'L')
          AND (p_MaNV_Filter IS NULL OR MaNV = p_MaNV_Filter)
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'sp_TinhLuong: LỖI: Bảng lương đã Xác nhận (C) hoặc Thanh toán (P)/Khóa (L). Không thể tính lại!';
    END IF;

    -- Guard 2: Xóa bản nháp cũ nếu Override = 1
    IF p_Override = 1 THEN
        DELETE ctl FROM ChiTietLuong ctl
        INNER JOIN BangLuong bl ON ctl.MaBL = bl.MaBL
        WHERE bl.Thang = p_Thang AND bl.Nam = p_Nam
          AND bl.TrangThai = 'D'
          AND (p_MaNV_Filter IS NULL OR bl.MaNV = p_MaNV_Filter);

        DELETE FROM BangLuong
        WHERE Thang = p_Thang AND Nam = p_Nam AND TrangThai = 'D'
          AND (p_MaNV_Filter IS NULL OR MaNV = p_MaNV_Filter);
    ELSE
        -- Nếu Override = 0, kiểm tra xem có bản nháp chưa
        IF EXISTS (
            SELECT 1 FROM BangLuong
            WHERE Thang = p_Thang AND Nam = p_Nam AND TrangThai = 'D'
              AND (p_MaNV_Filter IS NULL OR MaNV = p_MaNV_Filter)
        ) THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'sp_TinhLuong: Đã có bản nháp. Dùng p_Override=1 để ghi đè.';
        END IF;
    END IF;

    SELECT CONCAT('sp_TinhLuong — Kỳ ', p_Thang, '/', p_Nam,
                  ' | NgayChuan: ', v_NgayChuanThang, ' ngày') AS Info;

    -- CURSOR — DANH SÁCH NHÂN VIÊN CẦN TÍNH LƯƠNG
    BEGIN
        DECLARE cur_NhanVien CURSOR FOR
            SELECT MaNV, HoTen, TrangThai, SoNguoiPhuThuoc
            FROM NhanVien
            WHERE TrangThai IN ('A', 'P')
              AND NgayVaoLam   <= v_NgayCuoiThang
              AND (NgayNghiViec IS NULL OR NgayNghiViec > v_NgayDauThang)
              AND (p_MaNV_Filter IS NULL OR MaNV = p_MaNV_Filter)
            ORDER BY MaNV;

        DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = TRUE;

        OPEN cur_NhanVien;

        nv_loop: LOOP
            FETCH cur_NhanVien INTO
                v_cur_MaNV, v_cur_HoTen, v_cur_TrangThaiNV, v_cur_SoNguoiPT;

            IF v_done THEN
                LEAVE nv_loop;
            END IF;

            SET v_SoNVXuLy     = v_SoNVXuLy + 1;
            SET v_cur_MaLoaiHD = NULL;
            SET v_cur_LuongCB  = NULL;

            -- ── C.1: Lấy Hợp Đồng đang hiệu lực
            SELECT hd.MaLoaiHD, hd.LuongCoBan, hd.VungLuong
            INTO v_cur_MaLoaiHD, v_cur_LuongHD, v_cur_VungLuong
            FROM HopDong hd
            WHERE hd.MaNV       = v_cur_MaNV
              AND hd.TrangThai  = 'A'
              AND hd.NgayBatDau <= v_NgayCuoiThang
              AND (hd.NgayKetThuc IS NULL OR hd.NgayKetThuc >= v_NgayDauThang)
            ORDER BY hd.NgayBatDau DESC
            LIMIT 1;
            
            SET v_done = FALSE;

            IF v_cur_MaLoaiHD IS NULL THEN
                SET v_SoNVLoiToi = v_SoNVLoiToi + 1;
                ITERATE nv_loop;
            END IF;

            -- ── C.2: Lấy Lương Cơ Bản hiệu lực
            SELECT lcb.LuongCB,
                   fn_TinhLuongDongBH(lcb.LuongCB, v_cur_MaLoaiHD)
            INTO v_cur_LuongCB, v_cur_LuongDongBH
            FROM LuongCoBan lcb
            WHERE lcb.MaNV        = v_cur_MaNV
              AND lcb.NgayHieuLuc <= v_NgayCuoiThang
              AND (lcb.NgayHetHieuLuc IS NULL OR lcb.NgayHetHieuLuc >= v_NgayDauThang)
            ORDER BY lcb.NgayHieuLuc DESC
            LIMIT 1;

            -- [DEMO INJECTION] MÔ PHỎNG LỖI NON-REPEATABLE READ 
            IF v_cur_MaNV = 'NV000006' THEN
                -- Tạm dừng 15 giây để HR kịp sang màn hình Hợp đồng đổi lương (chạy chậm cả khi demo lỗi và khi đã khắc phục lỗi)
                DO SLEEP(5);
                
                IF @demo_non_repeatable_read = 1 THEN
                    -- Lấy lại Lương cơ bản TỪ DATABASE một lần nữa cho các tính toán sau
                    -- (Cố tình vi phạm nguyên tắc sử dụng biến snapshot ban đầu, tạo ra Non-repeatable Read)
                    -- Đã loại bỏ ràng buộc NgayHieuLuc để demo có thể hoạt động ngay cả khi tính lương cho tháng cũ (như tháng 6)
                    SELECT lcb.LuongCB
                    INTO v_cur_LuongCB
                    FROM LuongCoBan lcb
                    WHERE lcb.MaNV = v_cur_MaNV
                    ORDER BY lcb.NgayHieuLuc DESC
                    LIMIT 1;
                END IF;
            END IF;
            -- [/DEMO INJECTION]
            
            SET v_done = FALSE;

            IF v_cur_LuongCB IS NULL THEN
                SET v_SoNVLoiToi = v_SoNVLoiToi + 1;
                ITERATE nv_loop;
            END IF;

            -- ══ BƯỚC D — NGÀY CÔNG
            SET v_cur_NgayDiLam      = fn_SoNgayChamCong(v_cur_MaNV, p_Thang, p_Nam);
            SET v_cur_NgayNghiCL     = fn_SoNgayNghiCoLuong(v_cur_MaNV, p_Thang, p_Nam);
            SET v_cur_NgayKhongPhep  = fn_SoNgayNghiKhongLuong(v_cur_MaNV, p_Thang, p_Nam);
            SET v_cur_HeSoLuong      = fn_HeSoLuongThang(v_cur_MaNV, p_Thang, p_Nam);
            SET v_cur_LuongTheoNgay  = ROUND(v_cur_LuongCB * v_cur_HeSoLuong, 0);
            SET v_cur_LuongLamThem   = fn_TinhLuongLamThem(v_cur_MaNV, p_Thang, p_Nam, v_cur_LuongCB);

            -- ══ BƯỚC E — PHỤ CẤP
            SET v_cur_TongPhuCap     = 0;
            SET v_cur_PhuCapChiuThue = 0;

            IF v_cur_NgayDiLam > 0 THEN
                SELECT
                    IFNULL(SUM(
                        ROUND(CASE lfl.LoaiGiaTri
                            WHEN 'F' THEN COALESCE(nvfl.GiaTriOverride, lfl.GiaTri)
                            WHEN 'P' THEN v_cur_LuongCB * COALESCE(nvfl.GiaTriOverride, lfl.GiaTri) / 100.0
                            ELSE 0 END * v_cur_HeSoLuong, 0)
                    ), 0),
                    IFNULL(SUM(
                        ROUND(CASE WHEN lfl.CoTinhThue = 1
                             THEN CASE lfl.LoaiGiaTri
                                    WHEN 'F' THEN COALESCE(nvfl.GiaTriOverride, lfl.GiaTri)
                                    WHEN 'P' THEN v_cur_LuongCB * COALESCE(nvfl.GiaTriOverride, lfl.GiaTri) / 100.0
                                    ELSE 0 END
                             ELSE 0 END * v_cur_HeSoLuong, 0)
                    ), 0)
                INTO v_cur_TongPhuCap, v_cur_PhuCapChiuThue
                FROM NhanVienPhucLoi nvfl
                JOIN LoaiPhucLoi     lfl  ON nvfl.MaFL = lfl.MaFL
                WHERE nvfl.MaNV     = v_cur_MaNV
                  AND nvfl.IsActive = 1
                  AND nvfl.NgayApDung  <= v_NgayCuoiThang
                  AND (nvfl.NgayKetThuc IS NULL OR nvfl.NgayKetThuc >= v_NgayDauThang)
                  AND lfl.IsActive = 1;
            END IF;

            -- ══ BƯỚC F — BẢO HIỂM & THUẾ
            -- LUẬT LĐ: Nghỉ không lương >= 14 ngày trong tháng -> Không tính đóng Bảo hiểm
            IF (v_NgayChuanThang - (v_cur_NgayDiLam + v_cur_NgayNghiCL)) >= 14 THEN
                SET v_cur_BHXH_NLD   = 0;
                SET v_cur_BHYT_NLD   = 0;
                SET v_cur_BHTN_NLD   = 0;
                SET v_cur_TongBH_NLD = 0;
            ELSE
                SET v_cur_BHXH_NLD   = ROUND(v_cur_LuongDongBH * 0.08,  0);
                SET v_cur_BHYT_NLD   = ROUND(v_cur_LuongDongBH * 0.015, 0);
                SET v_cur_BHTN_NLD   = ROUND(v_cur_LuongDongBH * 0.01,  0);
                SET v_cur_TongBH_NLD = v_cur_BHXH_NLD + v_cur_BHYT_NLD + v_cur_BHTN_NLD;
            END IF;

            SET v_cur_LuongGross = v_cur_LuongTheoNgay + v_cur_LuongLamThem + v_cur_TongPhuCap;

            SET v_cur_GiamTruPT  = fn_TinhGiamTruPhuThuoc(v_cur_SoNguoiPT);
            
            -- FIX: Thu nhập tính thuế (ThuNhapTT) chỉ được tính trên phần Phụ cấp chịu thuế, KHÔNG tính trên Tổng phụ cấp
            -- Công thức: (Lương ngày + Lương thêm + Phụ cấp chịu thuế) - Bảo hiểm - Giảm trừ
            SET v_cur_ThuNhapTT  = GREATEST(
                (v_cur_LuongTheoNgay + v_cur_LuongLamThem + v_cur_PhuCapChiuThue) 
                - v_cur_TongBH_NLD - v_cur_GiamTruBT - v_cur_GiamTruPT,
                0
            );
            SET v_cur_ThueTNCN   = fn_TinhThueTNCN_Scalar(v_cur_ThuNhapTT);
            SET v_cur_BacThue    = fn_XacDinhBacThue(v_cur_ThuNhapTT);

            -- ══ BƯỚC G — KHẤU TRỪ PHÁT SINH
            SELECT IFNULL(SUM(GiaTri), 0)
            INTO v_cur_TongKhauTru
            FROM KhauTru
            WHERE MaNV = v_cur_MaNV
              AND TrangThai = 'P'
              AND NgayPhatSinh BETWEEN v_NgayDauThang AND v_NgayCuoiThang;

            -- Lương thực lĩnh
            SET v_cur_LuongNet = v_cur_LuongGross
                                 - v_cur_TongBH_NLD
                                 - v_cur_ThueTNCN
                                 - v_cur_TongKhauTru;

            -- ══ BƯỚC H — GHI VÀO DATABASE
            IF p_DryRun = 0 THEN
                START TRANSACTION;

                -- INSERT BangLuong (header)
                -- Dùng alias row syntax: INSERT ... AS new_row ON DUPLICATE KEY UPDATE col = new_row.col
                INSERT INTO BangLuong (
                    MaNV, Thang, Nam,
                    LuongCoBan, SoNgayCong, SoNgayLamChuan,
                    HeSoTangCa, TongPhuCap, TongKhauTru,
                    BHXH_NLD, BHYT_NLD, BHTN_NLD, ThueTNCN,
                    TrangThai, NgayTinhLuong
                )
                VALUES (
                    v_cur_MaNV, p_Thang, p_Nam,
                    v_cur_LuongCB,
                    v_cur_NgayDiLam + v_cur_NgayNghiCL,
                    v_NgayChuanThang,
                    v_cur_LuongLamThem,
                    v_cur_TongPhuCap,
                    v_cur_TongKhauTru,
                    v_cur_BHXH_NLD,
                    v_cur_BHYT_NLD,
                    v_cur_BHTN_NLD,
                    v_cur_ThueTNCN,
                    'D',
                    NOW()
                ) AS bl_new
                ON DUPLICATE KEY UPDATE
                    LuongCoBan     = bl_new.LuongCoBan,
                    SoNgayCong     = bl_new.SoNgayCong,
                    HeSoTangCa     = bl_new.HeSoTangCa,
                    TongPhuCap     = bl_new.TongPhuCap,
                    TongKhauTru    = bl_new.TongKhauTru,
                    BHXH_NLD       = bl_new.BHXH_NLD,
                    BHYT_NLD       = bl_new.BHYT_NLD,
                    BHTN_NLD       = bl_new.BHTN_NLD,
                    ThueTNCN       = bl_new.ThueTNCN,
                    NgayTinhLuong  = bl_new.NgayTinhLuong;

                SET v_cur_MaBL = LAST_INSERT_ID();

                -- INSERT ChiTietLuong
                -- Lương theo ngày công
                INSERT INTO ChiTietLuong (MaBL, LoaiMuc, TenMuc, GiaTri)
                VALUES (v_cur_MaBL, '+', 'Lương theo ngày công', v_cur_LuongTheoNgay);

                -- Lương làm thêm
                IF v_cur_LuongLamThem > 0 THEN
                    INSERT INTO ChiTietLuong (MaBL, LoaiMuc, TenMuc, GiaTri)
                    VALUES (v_cur_MaBL, '+', 'Lương tăng ca', v_cur_LuongLamThem);
                END IF;

                -- Phụ cấp từng khoản
                INSERT INTO ChiTietLuong (MaBL, LoaiMuc, TenMuc, GiaTri)
                SELECT
                    v_cur_MaBL,
                    '+',
                    CONCAT('Phụ cấp: ', lfl.TenFL),
                    ROUND(CASE lfl.LoaiGiaTri
                        WHEN 'F' THEN COALESCE(nvfl.GiaTriOverride, lfl.GiaTri)
                        WHEN 'P' THEN v_cur_LuongCB * COALESCE(nvfl.GiaTriOverride, lfl.GiaTri) / 100.0
                        ELSE 0 END * v_cur_HeSoLuong, 0)
                FROM NhanVienPhucLoi nvfl
                JOIN LoaiPhucLoi lfl ON nvfl.MaFL = lfl.MaFL
                WHERE nvfl.MaNV = v_cur_MaNV
                  AND nvfl.IsActive = 1
                  AND lfl.IsActive = 1
                  AND nvfl.NgayApDung <= v_NgayCuoiThang
                  AND (nvfl.NgayKetThuc IS NULL OR nvfl.NgayKetThuc >= v_NgayDauThang);

                -- BHXH/BHYT/BHTN
                INSERT INTO ChiTietLuong (MaBL, LoaiMuc, TenMuc, GiaTri)
                VALUES
                    (v_cur_MaBL, '-', 'BHXH NLĐ (8%)',    v_cur_BHXH_NLD),
                    (v_cur_MaBL, '-', 'BHYT NLĐ (1.5%)',  v_cur_BHYT_NLD),
                    (v_cur_MaBL, '-', 'BHTN NLĐ (1%)',    v_cur_BHTN_NLD);

                -- Thuế TNCN
                IF v_cur_ThueTNCN > 0 THEN
                    INSERT INTO ChiTietLuong (MaBL, LoaiMuc, TenMuc, GiaTri)
                    VALUES (v_cur_MaBL, '-', CONCAT('Thuế TNCN (Bậc ', v_cur_BacThue, ')'), v_cur_ThueTNCN);
                END IF;

                -- Khấu trừ phát sinh
                IF v_cur_TongKhauTru > 0 THEN
                    INSERT INTO ChiTietLuong (MaBL, LoaiMuc, TenMuc, GiaTri)
                    VALUES (v_cur_MaBL, '-', 'Khấu trừ phát sinh', v_cur_TongKhauTru);

                    -- Đánh dấu đã áp dụng khấu trừ
                    UPDATE KhauTru
                    SET TrangThai = 'A', MaBL = v_cur_MaBL
                    WHERE MaNV = v_cur_MaNV
                      AND TrangThai = 'P'
                      AND NgayPhatSinh BETWEEN v_NgayDauThang AND v_NgayCuoiThang;
                END IF;

                COMMIT;
            END IF;

            SET v_TongQuyLuong  = v_TongQuyLuong + v_cur_LuongNet;
            SET v_SoNVThanhCong = v_SoNVThanhCong + 1;

        END LOOP nv_loop;

        CLOSE cur_NhanVien;
    END;

    -- ══ KẾT QUẢ
    SELECT
        CONCAT(p_Thang, '/', p_Nam)     AS KyLuong,
        v_SoNVXuLy                      AS SoNVXuLy,
        v_SoNVThanhCong                 AS SoNVThanhCong,
        v_SoNVLoiToi                    AS SoNVLoiToi,
        FORMAT(v_TongQuyLuong, 0)       AS TongQuyLuong,
        CASE WHEN p_DryRun = 1 THEN 'DRY RUN — Không ghi DB' ELSE 'Đã ghi DB' END AS TrangThai;

    -- Danh sách NV vừa tính
    SELECT
        bl.MaBL,
        bl.MaNV,
        nv.HoTen,
        pb.TenPB        AS PhongBan,
        FORMAT(bl.LuongCoBan, 0)         AS LuongCoBan,
        bl.SoNgayCong,
        FORMAT(bl.ThuNhapGop, 0)         AS LuongGross,
        FORMAT(bl.BHXH_NLD + bl.BHYT_NLD + bl.BHTN_NLD, 0) AS TongBH,
        FORMAT(bl.ThueTNCN, 0)           AS ThueTNCN,
        FORMAT(bl.ThuNhapThucLinh, 0)    AS ThucLinh,
        bl.TrangThai
    FROM BangLuong bl
    JOIN NhanVien  nv ON bl.MaNV = nv.MaNV
    JOIN PhongBan  pb ON nv.MaPB = pb.MaPB
    WHERE bl.Thang = p_Thang AND bl.Nam = p_Nam
    ORDER BY bl.ThuNhapThucLinh DESC;

END$$
DELIMITER ;

-- KIỂM THỬ (chạy sau khi có seed_data)
-- CALL sp_TinhLuong(1, 2025, NULL, 0, 1);  -- DryRun tháng 1/2025
-- CALL sp_TinhLuong(1, 2025, NULL, 0, 0);  -- Tính thật tháng 1/2025

SELECT 'sp_TinhLuong.sql hoàn tất.' AS Status;
