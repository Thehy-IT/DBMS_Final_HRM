-- PROJECT    : Hệ Thống Quản Lý Nhân Sự & Tính Lương Tự Động
-- MỤC ĐÍCH   : Procedure tính chi tiết Thuế Thu Nhập Cá Nhân lũy tiến 7 bậc

USE HRPayrollDB;

-- PROCEDURE: sp_TinhThueTNCN_ChiTiet
-- (Thay thế TVF trong SQL Server — MySQL dùng procedure + temp table)

DROP PROCEDURE IF EXISTS sp_TinhThueTNCN_ChiTiet;

DELIMITER $$
CREATE PROCEDURE sp_TinhThueTNCN_ChiTiet(
    IN p_ThuNhapChiuThue DECIMAL(18,2)
)
BEGIN
    DECLARE v_TN    DECIMAL(18,2);
    DECLARE v_LuyKe DECIMAL(18,2) DEFAULT 0;
    DECLARE v_ChoBac DECIMAL(18,2);
    DECLARE v_Thue   DECIMAL(18,2);

    -- Kết quả trả về dưới dạng resultset
    DROP TEMPORARY TABLE IF EXISTS tmp_ChiTietThue;
    CREATE TEMPORARY TABLE tmp_ChiTietThue (
        BacThue         TINYINT,
        ThueSuat        DECIMAL(5,2),
        NguongDuoi      DECIMAL(18,2),
        NguongTren      DECIMAL(18,2),
        ThuNhapTinhBac  DECIMAL(18,2),
        TienThue_Bac    DECIMAL(18,2),
        TienThue_LuyKe  DECIMAL(18,2)
    );

    IF p_ThuNhapChiuThue <= 0 THEN
        INSERT INTO tmp_ChiTietThue VALUES (0, 0, 0, 0, 0, 0, 0);
    ELSE
        SET v_TN = p_ThuNhapChiuThue;

        -- Bậc 1
        SET v_ChoBac = CASE WHEN v_TN >= 5000000 THEN 5000000 ELSE v_TN END;
        SET v_Thue   = v_ChoBac * 0.05;
        SET v_LuyKe  = v_LuyKe + v_Thue;
        INSERT INTO tmp_ChiTietThue VALUES (1, 5.00, 0, 5000000, v_ChoBac, v_Thue, v_LuyKe);

        -- Bậc 2
        SET v_ChoBac = CASE
            WHEN v_TN > 5000000 THEN LEAST(v_TN, 10000000) - 5000000
            ELSE 0 END;
        SET v_Thue = v_ChoBac * 0.10;
        SET v_LuyKe = v_LuyKe + v_Thue;
        INSERT INTO tmp_ChiTietThue VALUES (2, 10.00, 5000001, 10000000, v_ChoBac, v_Thue, v_LuyKe);

        -- Bậc 3
        SET v_ChoBac = CASE
            WHEN v_TN > 10000000 THEN LEAST(v_TN, 18000000) - 10000000
            ELSE 0 END;
        SET v_Thue = v_ChoBac * 0.15;
        SET v_LuyKe = v_LuyKe + v_Thue;
        INSERT INTO tmp_ChiTietThue VALUES (3, 15.00, 10000001, 18000000, v_ChoBac, v_Thue, v_LuyKe);

        -- Bậc 4
        SET v_ChoBac = CASE
            WHEN v_TN > 18000000 THEN LEAST(v_TN, 32000000) - 18000000
            ELSE 0 END;
        SET v_Thue = v_ChoBac * 0.20;
        SET v_LuyKe = v_LuyKe + v_Thue;
        INSERT INTO tmp_ChiTietThue VALUES (4, 20.00, 18000001, 32000000, v_ChoBac, v_Thue, v_LuyKe);

        -- Bậc 5
        SET v_ChoBac = CASE
            WHEN v_TN > 32000000 THEN LEAST(v_TN, 52000000) - 32000000
            ELSE 0 END;
        SET v_Thue = v_ChoBac * 0.25;
        SET v_LuyKe = v_LuyKe + v_Thue;
        INSERT INTO tmp_ChiTietThue VALUES (5, 25.00, 32000001, 52000000, v_ChoBac, v_Thue, v_LuyKe);

        -- Bậc 6
        SET v_ChoBac = CASE
            WHEN v_TN > 52000000 THEN LEAST(v_TN, 80000000) - 52000000
            ELSE 0 END;
        SET v_Thue = v_ChoBac * 0.30;
        SET v_LuyKe = v_LuyKe + v_Thue;
        INSERT INTO tmp_ChiTietThue VALUES (6, 30.00, 52000001, 80000000, v_ChoBac, v_Thue, v_LuyKe);

        -- Bậc 7
        SET v_ChoBac = CASE
            WHEN v_TN > 80000000 THEN v_TN - 80000000
            ELSE 0 END;
        SET v_Thue = v_ChoBac * 0.35;
        SET v_LuyKe = v_LuyKe + v_Thue;
        INSERT INTO tmp_ChiTietThue VALUES (7, 35.00, 80000001, NULL, v_ChoBac, v_Thue, v_LuyKe);
    END IF;

    SELECT * FROM tmp_ChiTietThue;
    DROP TEMPORARY TABLE IF EXISTS tmp_ChiTietThue;
END$$
DELIMITER ;

SELECT 'sp_TinhThueTNCN_ChiTiet — tạo thành công' AS Status;
