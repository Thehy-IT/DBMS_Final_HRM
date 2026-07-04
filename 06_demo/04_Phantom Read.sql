USE hrpayrolldb;

-- Tạm thời tắt kiểm tra khóa ngoại để xóa dữ liệu sạch sẽ
SET FOREIGN_KEY_CHECKS = 0;

-- Cập nhật trạng thái bảng lương của nhân viên phát sinh về Nháp ('D') 
-- trước khi xóa để tránh bị Trigger chặn xóa (không cho xóa bảng lương đã chốt/thanh toán)
UPDATE BangLuong 
SET TrangThai = 'D' 
WHERE MaNV > 'NV000065' OR MaNV = 'NV999999';

-- 1. Xóa sạch các thông tin của nhân viên mới phát sinh trong quá trình demo (MaNV > 'NV000065')
DELETE ctl FROM ChiTietLuong ctl
INNER JOIN BangLuong bl ON ctl.MaBL = bl.MaBL
WHERE bl.MaNV > 'NV000065';

DELETE FROM BangLuong WHERE MaNV > 'NV000065';
DELETE FROM HopDong WHERE MaNV > 'NV000065';
DELETE FROM ChamCong WHERE MaNV > 'NV000065';
DELETE FROM NghiPhep WHERE MaNV > 'NV000065';
DELETE FROM NhanVienPhucLoi WHERE MaNV > 'NV000065';
DELETE FROM KhauTru WHERE MaNV > 'NV000065';
DELETE FROM LuongCoBan WHERE MaNV > 'NV000065';
DELETE FROM NhanVien WHERE MaNV > 'NV000065';

-- 2. Xóa sạch dữ liệu của nhân viên bóng ma NV999999 (nếu có từ API demo hệ thống)
DELETE ctl FROM ChiTietLuong ctl
INNER JOIN BangLuong bl ON ctl.MaBL = bl.MaBL
WHERE bl.MaNV = 'NV999999';

DELETE FROM BangLuong WHERE MaNV = 'NV999999';
DELETE FROM HopDong WHERE MaNV = 'NV999999';
DELETE FROM LuongCoBan WHERE MaNV = 'NV999999';
DELETE FROM NhanVien WHERE MaNV = 'NV999999';

-- Bật lại kiểm tra khóa ngoại
SET FOREIGN_KEY_CHECKS = 1;

-- 3. Khôi phục toàn bộ bảng lương Tháng 6/2026 của 65 nhân sự gốc về trạng thái Chưa chốt (Draft 'D')
UPDATE BangLuong 
SET TrangThai = 'D', NgayXacNhan = NULL 
WHERE Thang = 6 AND Nam = 2026;

-- 4. Xuất thông tin kiểm tra sau khi reset
SELECT 
    (SELECT COUNT(*) FROM NhanVien) AS TongSoNhanVien_Goc,
    (SELECT COUNT(*) FROM BangLuong WHERE Thang = 6 AND Nam = 2026 AND TrangThai = 'D') AS SoBangLuongDraft_Thang6_2026;

SELECT 'RESET PHANTOM READ THÀNH CÔNG! Dữ liệu đã quay về trạng thái seed_data.sql ban đầu.' AS Status;