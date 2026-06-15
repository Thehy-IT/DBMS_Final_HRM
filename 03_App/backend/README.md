# Phân hệ Backend (API Server) — HRM System

Máy chủ API được xây dựng bằng Node.js và Express, chịu trách nhiệm xử lý các nghiệp vụ và tương tác trực tiếp với cơ sở dữ liệu MySQL.

---

## Yêu Cầu Cài Đặt

- Node.js (phiên bản 18.x trở lên)
- MySQL Server 8.0+
- Quản lý gói: npm

---

## Cấu Trúc Mã Nguồn

```
backend/
├── src/
│   ├── config/       # Cấu hình kết nối Database (mysql2)
│   ├── controllers/  # Xử lý logic nghiệp vụ cho từng thực thể
│   ├── middlewares/  # Các bộ lọc (Auth, Error handling)
│   └── routes/       # Định nghĩa các đầu cuối API (Endpoints)
├── .env.example      # File mẫu cấu hình môi trường
├── server.js         # File khởi tạo và chạy máy chủ
└── package.json      # Danh sách dependencies và scripts
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

## Các Công Nghệ Sử Dụng

- **Express.js**: Framework chính cho Web API.
- **MySQL2**: Thư viện kết nối và thực thi SQL.
- **JWT (JSON Web Token)**: Xác thực và phân quyền người dùng.
- **Bcryptjs**: Mã hóa mật khẩu bảo mật.
- **CORS**: Cho phép ứng dụng Frontend truy cập tài nguyên.

---
*Cập nhật ngày: 15/06/2026 | HRM Development Team*
