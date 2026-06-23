/*
PROJECT    : Hệ Thống Quản Lý Nhân Sự & Tính Lương Tự Động
MỤC ĐÍCH   : Giao tác (Transaction) tiếp nhận nhân sự mới
             Đảm bảo tạo đầy đủ Nhân viên, Hợp đồng, Lương và Tài khoản.
DBMS       : MySQL 8.0+
*/

USE HRPayrollDB;

DROP PROCEDURE IF EXISTS sp_TiepNhanNhanSu;

DELIMITER $$
CREATE PROCEDURE sp_TiepNhanNhanSu(
    -- 1. Thông tin NhanVien
    IN p_MaNV           CHAR(8),
    IN p_HoTen          VARCHAR(100),
    IN p_GioiTinh       CHAR(1),
    IN p_NgaySinh       DATE,
    IN p_CCCD           VARCHAR(12),
    IN p_DiaChi         VARCHAR(300),
    IN p_Email          VARCHAR(100),
    IN p_SoDienThoai    VARCHAR(15),
    IN p_MaPB           CHAR(6),
    IN p_MaCV           CHAR(6),
    IN p_NgayVaoLam     DATE,
    
    -- 2. Thông tin HopDong
    IN p_MaHD           CHAR(10),
    IN p_MaLoaiHD       TINYINT,
    IN p_NgayKetThucHD  DATE,        -- Có thể NULL nếu hợp đồng vô thời hạn
    IN p_VungLuong      TINYINT,
    
    -- 3. Thông tin LuongCoBan
    IN p_LuongCoBan     DECIMAL(15,2),
    IN p_LuongDongBH    DECIMAL(15,2),
    
    -- 4. Thông tin TaiKhoan
    IN p_MatKhau        VARCHAR(255) -- Mật khẩu đã được mã hóa (hashed) từ ứng dụng
)
BEGIN
    DECLARE v_TenDangNhap VARCHAR(50);
    
    -- Khai báo Handler: Bắt mọi lỗi (SQLEXCEPTION) để tự động ROLLBACK
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        -- Hủy bỏ tất cả thao tác nếu có lỗi
        ROLLBACK;
        -- Báo lỗi ra ngoài
        RESIGNAL;
    END;

    -- ==========================================
    -- BẮT ĐẦU GIAO TÁC
    -- ==========================================
    START TRANSACTION;

    -- Bước 1: Tạo nhân viên
    INSERT INTO NhanVien (
        MaNV, HoTen, GioiTinh, NgaySinh, CCCD, DiaChi, Email, SoDienThoai,
        MaPB, MaCV, NgayVaoLam, TrangThai
    ) VALUES (
        p_MaNV, p_HoTen, p_GioiTinh, p_NgaySinh, p_CCCD, p_DiaChi, p_Email, p_SoDienThoai,
        p_MaPB, p_MaCV, p_NgayVaoLam, 'A' -- Active
    );

    -- Bước 2: Tạo hợp đồng đầu tiên
    INSERT INTO HopDong (
        MaHD, MaNV, MaLoaiHD, NgayBatDau, NgayKetThuc, LuongCoBan, VungLuong, TrangThai
    ) VALUES (
        p_MaHD, p_MaNV, p_MaLoaiHD, p_NgayVaoLam, p_NgayKetThucHD, p_LuongCoBan, p_VungLuong, 'A'
    );

    -- Bước 3: Thiết lập lương cơ bản ban đầu
    INSERT INTO LuongCoBan (
        MaNV, LuongCB, LuongDongBH, NgayHieuLuc, LyDo
    ) VALUES (
        p_MaNV, p_LuongCoBan, p_LuongDongBH, p_NgayVaoLam, 'Lương khởi điểm theo hợp đồng đầu tiên'
    );

    -- Bước 4: Khởi tạo tài khoản hệ thống (Tên đăng nhập mặc định là MaNV)
    SET v_TenDangNhap = p_MaNV;
    INSERT INTO TaiKhoan (
        TenDangNhap, MatKhau, Quyen, MaNV, TrangThai
    ) VALUES (
        v_TenDangNhap, p_MatKhau, 'EMPLOYEE', p_MaNV, 'A'
    );

    COMMIT;
    
    -- Trả về kết quả thành công
    SELECT CONCAT('Tiếp nhận nhân sự ', p_HoTen, ' (', p_MaNV, ') thành công. Đã tạo đầy đủ HĐ, Lương và Tài khoản.') AS KetQua;
END$$
DELIMITER ;
