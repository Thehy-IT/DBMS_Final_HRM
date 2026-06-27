use hrpayrolldb;
START TRANSACTION;
INSERT INTO NhanVien (MaNV, HoTen, GioiTinh, NgaySinh, CCCD, MaPB, MaCV, NgayVaoLam) 
VALUES ('NV888888', 'Giám Đốc Mới', 'M', '1990-01-01', '012345678910', 'PB0001', 'CV0001', '2025-01-01');
DO SLEEP(8); -- Giả lập đang xử lý bước tạo tài khoản gửi mail
ROLLBACK; -- Giả lập bị lỗi cuối cùng



SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;
START TRANSACTION;
CALL sp_BaoCaoNhanSu_TongQuan();
COMMIT;