# PHASE 8 & 9 - UI SPECIFICATION & CRUD DESIGN

## 1. Thiết kế Giao diện Chuẩn (Material Design 3 / Modern ERP SaaS)
- **Layout**: Sidebar bên trái (có thể collapse), Header chứa Breadcrumb, Search Box, Notifications, Avatar. Main Content ở giữa.
- **Theme**: Hỗ trợ Light Mode / Dark Mode chuyển đổi nhanh.
- **Filter Area**: Thanh Filter dạng Card mỏng phía trên Table, hỗ trợ filter nhiều tiêu chí, có nút Clear.
- **Data Table**: Bảng sử dụng TanStack Table. Cột có thể Sort/Resize/Hide. Stickey Header. Dòng chẵn/lẻ khác màu.
- **Pagination**: Phân trang server-side ở dưới cùng (Hiển thị trang 1/10, Rows per page: 10/20/50).
- **Modal & Drawer**: Thêm mới dùng Drawer (trượt từ phải sang). Sửa nhanh/Xác nhận dùng Modal.
- **Validation Form**: Hiển thị text lỗi màu đỏ dưới field ngay khi blur (React Hook Form + Zod).

## 2. CRUD Screen Design: Employee (Nhân Viên)

### 2.1. Danh sách (Employee List)
- **Controls**: Search Box (Tìm theo Tên, Mã NV, CCCD), Select (Trạng thái: Active/Inactive, Phòng ban).
- **Buttons**: [ + Add Employee ] (Primary), [ Import ] (Secondary), [ Export ] (Outline).
- **Bảng (Table)**: Avatar, Mã NV, Họ Tên, Giới Tính, Phòng Ban, Chức Vụ, Ngày Vào Làm, Trạng Thái (Badge: Xanh lá=A, Xám=T, Vàng=L). Hành động (3 chấm: Edit, Xem chi tiết, Đổi trạng thái).

### 2.2. Thêm mới / Chỉnh sửa (Employee Form - Drawer)
- **Bố cục Form**: Chia thành các tab: Thông tin chung (Mã, Tên, Giới tính, Sinh nhật), Liên hệ (Đ/c, SĐT, Email), Định danh (CCCD, MST, STK), Công việc (PB, CV, Ngày vào làm).
- **Business Rules**: Mã NV auto-generate hoặc validate format. Email & CCCD check unique. Ngày sinh phải đủ 18 tuổi.
- **Buttons**: [ Cancel ], [ Save Draft ], [ Submit ].

### 2.3. Chi tiết (Employee Detail)
- **Layout**: Trang riêng biệt. Panel trái: Tóm tắt thông tin, Avatar to. Panel phải: Tabs (Lịch sử làm việc, Lịch sử hợp đồng, Quá trình lương, Đơn nghỉ phép).
- **Nút hành động**: [ In PDF Hồ sơ ], [ Nghỉ việc ], [ Chỉnh sửa ].

### 2.4. Audit History
- Truy cập từ nút [Lịch sử] trong màn Chi tiết. Hiển thị bảng diff (Giá trị cũ -> Giá trị mới) cho các thay đổi quan trọng.
