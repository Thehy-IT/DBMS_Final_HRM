ALTER TABLE NhanVien ADD COLUMN Version INT NOT NULL DEFAULT 1;

-- Backend nhận version = 1 từ UI gửi lên
UPDATE NhanVien 
SET MaSoThue = '9999999999', Version = Version + 1
WHERE MaNV = 'NV000008' AND Version = 1;