# PHASE 6 - DASHBOARD DESIGN

## Dashboard Layout
Thiết kế theo dạng lưới (Grid layout), Responsive. Phía trên là các Cards tóm tắt, ở giữa là biểu đồ (Charts), phía dưới là các Data Tables cảnh báo.

### 1. Cards (Summary Stats)
- **Tổng nhân viên**: Hiển thị tổng số NV đang Active (TrangThai = 'A'). Có indicator tăng/giảm so với tháng trước.
- **Nhân viên mới**: Số lượng NV có NgayVaoLam trong tháng hiện tại.
- **Hợp đồng sắp hết hạn**: Số hợp đồng có NgayKetThuc trong vòng 30 ngày tới. Nhấn vào mở bảng danh sách.
- **Nghỉ phép hôm nay**: Số lượng NV đang On Leave (TrangThai = 'L' hoặc có đơn nghỉ phép duyệt ngày hôm nay).
- **Tổng quỹ lương**: Dự kiến chi phí lương tháng hiện tại (tổng ThuNhapGop của BangLuong).
- **Tổng OT**: Tổng SoGioTangCa trong tháng hiện tại.

### 2. Charts (Biểu đồ)
- **Nhân sự theo phòng ban (Pie/Doughnut Chart)**: Phân bổ NV Active theo các `PhongBan`.
- **Tăng trưởng nhân sự (Line/Bar Chart)**: Số NV vào mới vs Số NV nghỉ việc theo từng tháng trong 12 tháng qua.
- **Chi phí lương theo tháng (Area Chart)**: Biểu đồ xu hướng tổng quỹ lương đã chi trả theo thời gian.
- **Tỷ lệ nghỉ phép (Radar/Bar Chart)**: Phân bố số ngày nghỉ theo `LoaiNghiPhep` (Ốm, Phép năm, Thai sản).

### 3. Tables (Bảng danh sách nhắc việc)
- **Nhân viên mới**: Avatar, Họ Tên, Phòng Ban, Chức Vụ, Ngày vào làm. (Top 5)
- **Hợp đồng sắp hết hạn**: Mã HĐ, Họ Tên, Loại HĐ, Ngày hết hạn. (Cảnh báo màu Đỏ/Cam)
- **Đơn nghỉ chờ duyệt**: Nhân viên, Loại nghỉ, Ngày xin, Trạng thái (Pending). (Có nút Approve/Reject nhanh).
