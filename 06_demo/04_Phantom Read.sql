START TRANSACTION;
-- Quét qua các dòng và khóa chặt (Lock Rows + Gap Lock)
SELECT * FROM BangLuong WHERE Thang = 5 AND TrangThai = 'D' FOR UPDATE;

-- Xử lý chốt sổ
UPDATE BangLuong SET TrangThai = 'C' WHERE Thang = 5 AND TrangThai = 'D';
COMMIT;