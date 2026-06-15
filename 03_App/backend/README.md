# Phân hệ Backend (API Server) — HRM System

Máy chủ API được xây dựng bằng Node.js và Express, chịu trách nhiệm xử lý các nghiệp vụ và tương tác trực tiếp với cơ sở dữ liệu MySQL.

---

## Yêu Cầu Cài Đặt

- Node.js (phiên bản 18.x trở lên)
- MySQL Server 8.0+
- Quản lý gói: npm
- Công cụ `mysqldump` (để thực hiện tính năng sao lưu)

---

## Cấu Trúc Mã Nguồn

Dự án hiện tại được thiết kế theo cấu trúc phẳng (flat structure) để tối ưu cho việc quản lý tập trung:

```
03_App/backend/
├── backups/          # Thư mục lưu trữ các bản sao lưu SQL
├── .env.example      # File mẫu cấu hình môi trường
├── package.json      # Danh sách dependencies và scripts
├── server.js         # Entry point: Chứa toàn bộ Logic API, Auth, và Routes
└── README.md         # Tài liệu hướng dẫn
```

---

## Hướng Dẫn Cài Đặt

### 1. Cài đặt thư viện
Tại thư mục `03_App/backend`, chạy lệnh:
```bash
npm install
```

### 2. Cấu hình môi trường
- Sao chép file `.env.example` thành file `.env`.
- Cập nhật các thông tin kết nối Database của bạn:
```env
DB_HOST=localhost
DB_USER=root
DB_PASSWORD=your_password
DB_NAME=HRPayrollDB
PORT=8080
JWT_SECRET=your_jwt_secret
```

---

## Khởi Chạy Server

### Chế độ phát triển (Auto-reload)
```bash
npm run dev
```

### Chế độ production
```bash
npm start
```

Mặc định, server sẽ chạy tại: `http://localhost:8080`

---

## Danh Sách API (v1)

Tất cả các API (ngoại trừ login) đều yêu cầu Header `Authorization: Bearer <token>`.

### 1. Xác thực & Tài khoản
- `POST /v1/auth/login`: Đăng nhập hệ thống.
- `GET /v1/users`: Danh sách tài khoản (Admin).
- `POST /v1/users`: Tạo tài khoản mới (Admin).
- `PUT /v1/users/:id`: Cập nhật tài khoản (Admin).
- `DELETE /v1/users/:id`: Xóa tài khoản (Admin).
- `GET /v1/roles/stats`: Thống kê vai trò (Admin).

### 2. Quản lý Nhân sự (HR/Admin)
- `GET /v1/employees`: Danh sách nhân viên (Phân quyền theo vai trò).
- `GET /v1/employees/:id`: Chi tiết nhân viên.
- `POST /v1/employees`: Thêm nhân viên mới (HR/Admin).
- `PUT /v1/employees/:id`: Cập nhật thông tin nhân viên (HR/Admin).

### 3. Hợp đồng & Chấm công
- `GET /v1/contracts`: Danh sách hợp đồng.
- `POST /v1/contracts`: Tạo hợp đồng mới (HR/Admin).
- `GET /v1/attendance`: Dữ liệu chấm công.
- `POST /v1/attendance`: Nhập chấm công (HR/Admin).

### 4. Lương & Nghỉ phép
- `GET /v1/payroll`: Bảng lương.
- `POST /v1/payroll/calculate`: Tính lương tháng (HR/Admin).
- `GET /v1/leaves`: Danh sách đơn nghỉ phép.
- `POST /v1/leaves`: Gửi đơn nghỉ phép mới.
- `PUT /v1/leaves/:id/approve`: Phê duyệt đơn nghỉ (HR/Admin).

### 5. Dữ liệu Danh mục (Master Data)
- `GET /v1/departments`: Phòng ban.
- `GET /v1/positions`: Chức vụ.
- `GET /v1/contract-types`: Loại hợp đồng.
- `GET /v1/benefit-types`: Loại phúc lợi.

### 6. Hệ thống & Sao lưu (Admin)
- `GET /v1/system-logs`: Nhật ký thay đổi (Audit logs).
- `GET /v1/backups`: Danh sách bản sao lưu.
- `POST /v1/backups`: Tạo bản sao lưu mới.
- `GET /v1/system/settings`: Thông tin trạng thái hệ thống.

---

## Các Công Nghệ Sử Dụng

- **Express.js**: Framework Web API (ES Modules).
- **MySQL2**: Kết nối cơ sở dữ liệu (Promise-based).
- **JWT (JSON Web Token)**: Xác thực và phân quyền.
- **Bcryptjs**: Mã hóa mật khẩu.
- **CORS**: Hỗ trợ kết nối từ Frontend.

---
*Cập nhật ngày: 15/06/2026 | HRM Development Team*
