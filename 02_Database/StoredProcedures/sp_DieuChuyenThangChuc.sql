/*
PROJECT    : Hệ Thống Quản Lý Nhân Sự & Tính Lương Tự Động
MỤC ĐÍCH   : Giao tác (Transaction) Điều chuyển / Thăng chức / Thay đổi lương
             Đảm bảo chốt lương cũ và ghi nhận mức lương mới liền mạch.
DBMS       : MySQL 8.0+
*/

USE HRPayrollDB;

DROP PROCEDURE IF EXISTS sp_DieuChuyenThangChuc;

DELIMITER $$
CREATE PROCEDURE sp_DieuChuyenThangChuc(
    IN p_MaNV           CHAR(8),
    IN p_MaPBMoi        CHAR(6),
    IN p_MaCVMoi        CHAR(6),
    IN p_LuongCoBanMoi  DECIMAL(15,2),
    IN p_LuongDongBHMoi DECIMAL(15,2),
    IN p_NgayHieuLuc    DATE,
    IN p_LyDo           VARCHAR(255)
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    -- 1. Chốt NgayHetHieuLuc của dòng mức lương cũ (là ngày hôm trước ngày hiệu lực mới)
    UPDATE LuongCoBan
    SET NgayHetHieuLuc = DATE_SUB(p_NgayHieuLuc, INTERVAL 1 DAY)
    WHERE MaNV = p_MaNV AND NgayHetHieuLuc IS NULL;

    -- 2. Insert mức lương mới
    INSERT INTO LuongCoBan (
        MaNV, LuongCB, LuongDongBH, NgayHieuLuc, LyDo
    ) VALUES (
        p_MaNV, p_LuongCoBanMoi, p_LuongDongBHMoi, p_NgayHieuLuc, p_LyDo
    );

    -- 3. Cập nhật lại Phòng ban và Chức vụ trong hồ sơ nhân viên
    UPDATE NhanVien
    SET MaPB = p_MaPBMoi, MaCV = p_MaCVMoi
    WHERE MaNV = p_MaNV;

    COMMIT;

    SELECT CONCAT('[OK] Đã điều chuyển / thăng chức nhân viên ', p_MaNV, ' sang phòng ', p_MaPBMoi, ' với chức vụ ', p_MaCVMoi) AS KetQua;
END$$
DELIMITER ;
