
USE hrpayrolldb;

-- 1. Xóa mức lương mới phát sinh của NV000006 trong quá trình demo (nếu có)
DELETE FROM LuongCoBan 
WHERE MaNV = 'NV000006' AND NgayHieuLuc >= '2026-07-01';

-- 2. Khôi phục lại mức lương cũ 25,000,000 làm mức lương hiện tại (xóa ngày hết hiệu lực)
UPDATE LuongCoBan 
SET NgayHetHieuLuc = NULL, NguoiDuyet = 'HR_ADMIN'
WHERE MaNV = 'NV000006' AND LuongCB = 25000000;

-- 3. Khôi phục lại lương cơ bản trong Hợp đồng của NV000006 về mức 25,000,000
UPDATE HopDong 
SET LuongCoBan = 25000000 
WHERE MaNV = 'NV000006' AND TrangThai = 'A';


SELECT 'RESET THÀNH CÔNG! Bạn có thể bắt đầu demo lại từ đầu trên giao diện.' AS Status;