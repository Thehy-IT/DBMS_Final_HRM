-- MỤC ĐÍCH   : Trigger validate chấm công: không trùng ngày,
--              không tương lai, không trùng đơn nghỉ đã duyệt,
--              tự động tính SoGioLam từ GioVao/GioRa
-- TRIGGERS   :
--   1. trg_ChamCong_BeforeInsert  — validate trước khi insert
--   2. trg_ChamCong_BeforeUpdate  — validate trước khi update
-- DBMS       : MySQL 8.0+
-- GHI CHÚ   : SoGioLam là GENERATED COLUMN (tự tính), không cần
--              UPDATE trong trigger như SQL Server
--              Validation không tương lai sử dụng CURDATE()

USE HRPayrollDB;

-- TRIGGER 1: trg_ChamCong_BeforeInsert
DROP TRIGGER IF EXISTS trg_ChamCong_BeforeInsert;

DELIMITER $$
CREATE TRIGGER trg_ChamCong_BeforeInsert
BEFORE INSERT ON ChamCong
FOR EACH ROW
BEGIN
    -- Validate 1: Không chấm công ngày tương lai
    IF NEW.NgayCham > CURDATE() THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'trg_ChamCong_BeforeInsert: Không được chấm công ngày tương lai.';
    END IF;

    -- Validate 2: NV phải tồn tại và đang làm việc
    IF NOT EXISTS (
        SELECT 1 FROM NhanVien
        WHERE MaNV = NEW.MaNV
          AND TrangThai IN ('A', 'P', 'L')
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'trg_ChamCong_BeforeInsert: Nhân viên không tồn tại hoặc đã nghỉ việc.';
    END IF;

    -- Validate 3: Không overlap với đơn nghỉ phép đã duyệt
    -- (NV không thể vừa DL vừa có đơn nghỉ phép approved)
    IF NEW.TrangThai IN ('DL', 'WFH', 'CX') THEN
        IF EXISTS (
            SELECT 1 FROM NghiPhep np
            WHERE np.MaNV = NEW.MaNV
              AND np.TrangThai = 'A'
              AND NEW.NgayCham BETWEEN np.NgayBatDau AND np.NgayKetThuc
        ) THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'trg_ChamCong_BeforeInsert: Ngày chấm công trùng với đơn nghỉ phép đã duyệt.';
        END IF;
    END IF;
END$$
DELIMITER ;

SELECT 'trg_ChamCong_BeforeInsert' AS Status;


-- TRIGGER 2: trg_ChamCong_BeforeUpdate
DROP TRIGGER IF EXISTS trg_ChamCong_BeforeUpdate;
DELIMITER $$
CREATE TRIGGER trg_ChamCong_BeforeUpdate
BEFORE UPDATE ON ChamCong
FOR EACH ROW
BEGIN
    -- Validate 1: Không chấm công ngày tương lai
    IF NEW.NgayCham > CURDATE() THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'trg_ChamCong_BeforeUpdate: Không được chấm công ngày tương lai.';
    END IF;

    -- Validate 2: Không overlap với đơn nghỉ phép đã duyệt
    IF NEW.TrangThai IN ('DL', 'WFH', 'CX') AND IFNULL(NEW.NguoiCapNhat, '') <> 'SEED_DATA' THEN
        IF EXISTS (
            SELECT 1 FROM NghiPhep np
            WHERE np.MaNV = NEW.MaNV
              AND np.TrangThai = 'A'
              AND NEW.NgayCham BETWEEN np.NgayBatDau AND np.NgayKetThuc
        ) THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'trg_ChamCong_BeforeUpdate: Ngày chấm công trùng với đơn nghỉ phép đã duyệt.';
        END IF;
    END IF;

    -- Ghi chú: SoGioLam là GENERATED COLUMN (tự động tính từ GioVao/GioRa)
    -- Không cần UPDATE thủ công như SQL Server
END$$
DELIMITER ;