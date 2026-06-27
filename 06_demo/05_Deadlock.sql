START TRANSACTION;
UPDATE NhanVien SET MaCV = 'CV0002' WHERE MaNV = 'NV000001'; -- Giữ khóa NhanVien
DO SLEEP(5); 
UPDATE LuongCoBan SET LuongCB = 40000000 WHERE MaNV = 'NV000001'; -- Bị kẹt chờ
COMMIT;




START TRANSACTION;
-- Dù logic kỷ luật là đánh vào tiền lương, ta vẫn phải UPDATE bảng NhanVien TRƯỚC để lấy khóa đúng trật tự.
UPDATE NhanVien SET GhiChu = 'Bị kỷ luật' WHERE MaNV = 'NV000001'; 
UPDATE LuongCoBan SET LuongCB = 15000000 WHERE MaNV = 'NV000001'; 
COMMIT;