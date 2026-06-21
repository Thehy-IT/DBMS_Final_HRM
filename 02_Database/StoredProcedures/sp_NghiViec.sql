/*
PROJECT    : Hệ Thống Quản Lý Nhân Sự & Tính Lương Tự Động
MỤC ĐÍCH   : Giao tác (Transaction) xử lý nhân viên nghỉ việc/chấm dứt HĐ
             Đảm bảo chốt toàn bộ trạng thái Nhân viên, HĐ, Lương, Phúc lợi và Tài khoản.
DBMS       : MySQL 8.0+
*/

USE HRPayrollDB;

DROP PROCEDURE IF EXISTS sp_NghiViec;

DELIMITER $$
CREATE PROCEDURE sp_NghiViec(
    IN p_MaNV         CHAR(8),
    IN p_NgayNghiViec DATE,
    IN p_LyDo         VARCHAR(255)
)
BEGIN
    -- Khai báo Handler bắt lỗi để Rollback
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    -- 1. Cập nhật bảng NhanVien
    UPDATE NhanVien
    SET TrangThai = 'T', NgayNghiViec = p_NgayNghiViec
    WHERE MaNV = p_MaNV;

    -- 2. Đóng tất cả Hợp đồng đang Active
    UPDATE HopDong
    SET TrangThai = 'T', NgayKetThuc = p_NgayNghiViec, GhiChu = CONCAT(IFNULL(GhiChu, ''), ' | Nghỉ việc: ', p_LyDo)
    WHERE MaNV = p_MaNV AND TrangThai = 'A';

    -- 3. Chốt quá trình Lương cơ bản
    UPDATE LuongCoBan
    SET NgayHetHieuLuc = p_NgayNghiViec
    WHERE MaNV = p_MaNV AND NgayHetHieuLuc IS NULL;

    -- 4. Vô hiệu hóa Tài khoản
    UPDATE TaiKhoan
    SET TrangThai = 'I' -- Inactive
    WHERE MaNV = p_MaNV;

    -- 5. Kết thúc các Phúc lợi đang được hưởng
    UPDATE NhanVienPhucLoi
    SET NgayKetThuc = p_NgayNghiViec, IsActive = 0
    WHERE MaNV = p_MaNV AND IsActive = 1;

    COMMIT;

    SELECT CONCAT('[OK] Đã xử lý nghỉ việc cho nhân viên ', p_MaNV, ' thành công (chốt HĐ, Lương, Tài khoản).') AS KetQua;
END$$
DELIMITER ;
