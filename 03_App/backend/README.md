# Phân hệ Backend (API Server) — HRM System

Chào mừng đến với hệ thống API Backend của dự án Quản lý Nhân sự (HRM).
Hệ thống này được xây dựng trên nền tảng **Node.js** và **Express.js**, đóng vai trò là "bộ não" xử lý mọi nghiệp vụ cốt lõi, xác thực người dùng và giao tiếp với Cơ sở dữ liệu **MySQL**.

---

## Công Nghệ Sử Dụng (Tech Stack)

- **Runtime**: Node.js v18+ (Sử dụng ES Modules chuẩn mới `import/export`)
- **Web Framework**: Express.js
- **Cơ sở dữ liệu**: MySQL 8.0+
- **Database Driver**: `mysql2` (Hỗ trợ Promise/async-await để chống callback hell)
- **Xác thực (Authentication)**: `jsonwebtoken` (JWT) phân quyền linh hoạt
- **Bảo mật mã hóa**: `bcryptjs` để hash mật khẩu người dùng
- **Khác**: `cors` (Quản lý nguồn gốc truy cập), `dotenv` (Quản lý biến môi trường)

---

## Cấu Trúc Mã Nguồn

```text
03_App/backend/
├── backups/          # Thư mục lưu trữ tự động các file SQL dump (sao lưu)
├── .env.example      # File mẫu chứa cấu trúc các biến môi trường
├── package.json      # Danh sách dependencies & cấu hình node scripts
├── server.js         # Entry point chính - Định tuyến API, Controllers, và Database Config
└── README.md         # File tài liệu bạn đang đọc
```

*Lưu ý: Để giữ cấu trúc đơn giản (Flat Structure), toàn bộ logic, router và database schema hiện tại được tập trung chủ yếu vào `server.js` hoặc phân tách module cơ bản.*

---

## Hướng Dẫn Cài Đặt & Chạy

### Bước 1: Cài đặt thư viện

Mở terminal tại thư mục `03_App/backend` và chạy lệnh sau để tải về toàn bộ package cần thiết:

```bash
npm install
```

### Bước 2: Thiết lập Cơ sở dữ liệu & Biến môi trường

1. Đảm bảo bạn đã có **MySQL Server** đang chạy trên máy (XAMPP, Docker, hoặc MySQL cài trực tiếp).
2. Tạo một Schema (Database) trong MySQL (Ví dụ: `HRPayrollDB`).
3. Đổi tên file `.env.example` thành `.env` (hoặc tạo file `.env` mới) và cập nhật thông tin:

```env
# Cấu hình Server
PORT=8080

# Cấu hình Database MySQL
DB_HOST=localhost
DB_USER=root
DB_PASSWORD=mat_khau_cua_ban
DB_NAME=HRPayrollDB

# Cấu hình Bảo mật JWT
JWT_SECRET=mot_chuoi_bi_mat_bat_ky_sieu_kho_doan_123!@#
```

### Bước 3: Khởi chạy Server

Trong quá trình phát triển (Dev Mode) với tính năng Auto-reload (Tự khởi động lại khi có thay đổi code):

```bash
npm run dev
```

Chạy trong môi trường thực tế (Production):

```bash
npm start
```

Mặc định, server sẽ lắng nghe trên cổng `8080` (hoặc cổng được định nghĩa trong `PORT` của file `.env`).
URL API Base: `http://localhost:8080`

---

## Tổng Quan Các Endpoint API (v1)

Hệ thống API RESTful được chia thành các nhóm (modules) như sau:

| Nhóm Tính Năng           | Endpoints Nổi Bật                                                      | Yêu Cầu Auth |
| :-------------------------- | :----------------------------------------------------------------------- | :------------- |
| **Xác Thực (Auth)** | `POST /v1/auth/login` (Đăng nhập cấp Token)                        | Không         |
| **Tài Khoản**       | `GET /v1/users`, `POST /v1/users`, `DELETE /v1/users/:id`          | Có (Admin)    |
| **Nhân Sự**         | `GET /v1/employees`, `POST /v1/employees`, `PUT /v1/employees/:id` | Có            |
| **Hợp Đồng**       | `GET /v1/contracts`, `POST /v1/contracts`                            | Có            |
| **Chấm Công**       | `GET /v1/attendance`, `POST /v1/attendance`                          | Có            |
| **Tính Lương**     | `GET /v1/payroll`, `POST /v1/payroll/calculate`                      | Có            |
| **Nghỉ Phép**       | `GET /v1/leaves`, `PUT /v1/leaves/:id/approve`                       | Có            |
| **Danh Mục**         | `GET /v1/departments`, `GET /v1/positions`                           | Có            |
| **Hệ Thống**        | `GET /v1/backups`, `POST /v1/backups`                                | Có (Admin)    |

*(Tham khảo trực tiếp mã nguồn trong `server.js` hoặc Swagger Docs (nếu có) để xem cấu trúc JSON Request/Response chi tiết cho từng API).*

---

## Lưu Ý Về Sao Lưu (Backup) Database

Tính năng `POST /v1/backups` yêu cầu máy chủ/máy tính của bạn phải có sẵn lệnh `mysqldump` (thường được cài đặt cùng MySQL). Nếu API trả về lỗi không tìm thấy mysqldump, hãy đảm bảo bạn đã đưa thư mục `bin` của MySQL vào `System Environment Variables (PATH)`.
