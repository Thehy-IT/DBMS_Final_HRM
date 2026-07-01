-- =========================================================================
-- SCRIPT RESET TRẠNG THÁI TRƯỚC KHI DEMO "NON-REPEATABLE READ"
-- =========================================================================
-- Chạy script này dưới MySQL Workbench / DBeaver để reset dữ liệu của NV000006
-- về trạng thái chuẩn trước khi thực hiện demo qua giao diện UI (hoặc bằng SQL).

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

-- 4. Xóa bảng lương nháp (Draft) Tháng 6/2026 của NV000006 để có thể ấn "Tính Lương" lại trên UI
DELETE ctl FROM ChiTietLuong ctl
INNER JOIN BangLuong bl ON ctl.MaBL = bl.MaBL
WHERE bl.MaNV = 'NV000006' AND bl.Thang = 6 AND bl.Nam = 2026 AND bl.TrangThai = 'D';

DELETE FROM BangLuong 
WHERE MaNV = 'NV000006' AND Thang = 6 AND Nam = 2026 AND TrangThai = 'D';

-- 5. Xác nhận trạng thái sau khi reset
SELECT 
    (SELECT LuongCB FROM LuongCoBan WHERE MaNV = 'NV000006' AND NgayHetHieuLuc IS NULL) AS LuongCoBan_HienTai,
    (SELECT LuongCoBan FROM HopDong WHERE MaNV = 'NV000006' AND TrangThai = 'A') AS LuongHopDong_HienTai,
    (SELECT COUNT(*) FROM BangLuong WHERE MaNV = 'NV000006' AND Thang = 6 AND Nam = 2026) AS SoBangLuong_Thang6_2026;

SELECT 'RESET THÀNH CÔNG! Bạn có thể bắt đầu demo lại từ đầu trên giao diện.' AS Status;