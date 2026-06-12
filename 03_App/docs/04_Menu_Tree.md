# PHASE 4 & 5 - MENU DESIGN & ARCHITECTURE

## MENU ERP HOÀN CHỈNH

**Dashboard**
- Dashboard Tổng quan

**Quản Lý Nhân Sự**
- Nhân Viên
- Phòng Ban
- Chức Vụ
- Hợp Đồng

**Chấm Công**
- Chấm Công
- Ca Làm
- Ngày Lễ

**Nghỉ Phép**
- Đăng Ký Nghỉ
- Duyệt Nghỉ
- Loại Nghỉ

**Lương**
- Tính Lương
- Bảng Lương
- Chi Tiết Lương
- Khấu Trừ

**Phúc Lợi**
- Loại Phúc Lợi
- Phúc Lợi Nhân Viên

**Báo Cáo**
- Nhân Sự
- Chấm Công
- Nghỉ Phép
- Lương

**Hệ Thống**
- Người Dùng
- Vai Trò
- Audit Log
- Cấu Hình

## SYSTEM ARCHITECTURE
- **Frontend**: NextJS 15 (React 19), TailwindCSS, Shadcn UI
- **Backend**: NodeJS + Express (RESTful API)
- **Database**: MySQL 8.0+
- **Auth**: JWT & RBAC (Role-Based Access Control)
- **Cache**: Redis (cho báo cáo & session)
- **Storage**: AWS S3 hoặc MinIO (lưu file scan hợp đồng)
