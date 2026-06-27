SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;
START TRANSACTION;
-- Đọc lương lần 1 để tính BHXH (ra 20tr)
SELECT LuongCB INTO @luongCB_BHXH FROM LuongCoBan WHERE MaNV = 'NV000001' ORDER BY NgayHieuLuc DESC LIMIT 1;
DO SLEEP(8); -- Gặp độ trễ
-- Đọc lương lần 2 để tính Thuế TNCN (sau 8s sẽ đọc ra 30tr vì HR can thiệp)
SELECT LuongCB INTO @luongCB_Thue FROM LuongCoBan WHERE MaNV = 'NV000001' ORDER BY NgayHieuLuc DESC LIMIT 1;
COMMIT;


-- Thay vì liên tục truy vấn SELECT bảng LuongCoBan ở mỗi bước
DECLARE v_LuongCoBan_Current DECIMAL(15,2);
-- Lấy snapshot một lần duy nhất tại thời điểm bắt đầu tính toán
SELECT LuongCB INTO v_LuongCoBan_Current 
FROM LuongCoBan WHERE MaNV = p_MaNV ORDER BY NgayHieuLuc DESC LIMIT 1;
-- Dùng biến v_LuongCoBan_Current để tính toán chung cho cả BHXH và Thuế