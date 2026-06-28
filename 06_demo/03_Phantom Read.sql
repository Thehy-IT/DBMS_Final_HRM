    -- 1. Trả lại toàn bộ bảng lương tháng hiện tại về trạng thái Draft (Chưa chốt)      
    -- (Sửa số 6 thành tháng bạn đang demo)                                              
    UPDATE BangLuong                                                                     
    SET TrangThai = 'D'                                                                  
    WHERE Thang = 6 AND Nam = 2026; 