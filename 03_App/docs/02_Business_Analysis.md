# PHASE 2 - BUSINESS ANALYSIS

## Actors & Roles

| Actor | Mục tiêu | Quyền hạn | Chức năng được sử dụng | Mức độ truy cập |
|-------|----------|-----------|------------------------|-----------------|
| **System Administrator** | Đảm bảo hệ thống hoạt động trơn tru, bảo mật và phân quyền đúng đắn | Quản trị toàn hệ thống | Quản lý người dùng, vai trò, cấu hình hệ thống, xem Audit Log | Toàn quyền truy cập tất cả dữ liệu hệ thống |
| **HR Manager** | Quản lý chiến lược nhân sự, giám sát toàn bộ hoạt động nhân sự của công ty | Quản lý nhân sự, danh mục, duyệt các quyết định | Xem/Sửa/Xóa tất cả hồ sơ, hợp đồng, thiết lập phòng ban, chức vụ | Toàn quyền truy cập dữ liệu nhân sự |
| **HR Staff** | Vận hành các tác vụ nhân sự hàng ngày | Thao tác hồ sơ, hợp đồng, phép | Thêm/Sửa hồ sơ NV, lập hợp đồng, cập nhật danh mục, theo dõi nghỉ phép | Truy cập hồ sơ NV (trừ lương), hợp đồng |
| **Payroll Officer** | Đảm bảo tính lương chính xác, đúng hạn và tuân thủ luật | Quản lý chấm công, lương, khấu trừ, thuế | Tính lương, khóa bảng lương, xử lý khấu trừ, xuất báo cáo lương | Truy cập dữ liệu lương, chấm công, hợp đồng |
| **Department Manager** | Quản lý nhân sự trong phòng ban của mình | Theo dõi và phê duyệt cho NV phòng mình | Xem danh sách NV phòng, duyệt nghỉ phép, xem chấm công phòng | Truy cập dữ liệu NV và chấm công của phòng ban mình |
| **Employee** | Xem thông tin cá nhân, lương, thực hiện các yêu cầu tự phục vụ | Tự phục vụ (Self-service) | Xem hồ sơ, xin nghỉ phép, xem bảng lương cá nhân | Chỉ xem dữ liệu cá nhân của chính mình |
| **Director / C-Level** | Nắm bắt tình hình nhân sự, chi phí lương để ra quyết định | Xem báo cáo tổng quan chiến lược | Dashboard nâng cao, báo cáo nhân sự & quỹ lương | Xem toàn bộ báo cáo, không sửa dữ liệu |
| **Auditor** | Kiểm toán tính tuân thủ và quy trình nội bộ | Xem dữ liệu lịch sử và thay đổi | Xem Audit Log, lịch sử hợp đồng/lương, đối soát bảng lương | Read-only toàn bộ dữ liệu hệ thống |
