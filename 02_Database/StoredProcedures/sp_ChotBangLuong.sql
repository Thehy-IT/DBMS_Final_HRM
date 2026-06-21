/*
PROJECT    : Hệ Thống Quản Lý Nhân Sự & Tính Lương Tự Động
MỤC ĐÍCH   : Giao tác (Transaction) Chốt và Thanh toán Bảng Lương
             Đảm bảo cập nhật trạng thái bảng lương và các khoản khấu trừ đồng thời.
DBMS       : MySQL 8.0+
*/

USE HRPayrollDB;

DROP PROCEDURE IF EXISTS sp_ChotBangLuong;

DELIMITER $$
CREATE PROCEDURE sp_ChotBangLuong(
    IN p_Thang      TINYINT,
    IN p_Nam        SMALLINT,
    IN p_NguoiDuyet VARCHAR(100)
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    -- 1. Cập nhật trạng thái Bảng Lương sang 'P' (Paid - Đã thanh toán)
    -- Áp dụng cho các bảng lương của kỳ hiện tại đang ở trạng thái Draft (D) hoặc Confirmed (C)
    UPDATE BangLuong
    SET TrangThai = 'P',
        NgayThanhToan = CURDATE(),
        NgayXacNhan = NOW()
    WHERE Thang = p_Thang AND Nam = p_Nam AND TrangThai IN ('D', 'C');

    -- 2. Cập nhật các khoản Khấu Trừ đã được tính vào kỳ lương này thành 'A' (Applied)
    -- Liên kết bảng KhauTru với BangLuong thông qua MaBL
    UPDATE KhauTru kt
    JOIN BangLuong bl ON kt.MaBL = bl.MaBL
    SET kt.TrangThai = 'A',
        kt.NguoiDuyet = p_NguoiDuyet
    WHERE bl.Thang = p_Thang AND bl.Nam = p_Nam AND kt.TrangThai = 'P';

    COMMIT;

    SELECT CONCAT('[OK] Đã chốt và thanh toán bảng lương kỳ ', p_Thang, '/', p_Nam, ' thành công.') AS KetQua;
END$$
DELIMITER ;
