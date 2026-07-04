# Hệ thống Quản trị Nhân sự (HRM System) - Monorepo

Chào mừng bạn đến với dự án **Hệ thống Quản trị Nhân sự (HRM)**. Dự án được cấu trúc theo dạng **Monorepo** phân tách rõ ràng giữa Frontend (Giao diện người dùng) và Backend (API Server), giúp việc quản lý, mở rộng và bảo trì trở nên dễ dàng và chuyên nghiệp.

## Tổng Quan Kiến Trúc

Dự án này bao gồm 2 phân hệ cốt lõi:

- **Frontend (`/frontend`)**: Ứng dụng Web tính/SSR hiệu năng cao, xây dựng bằng **Next.js (App Router)** và **React 19**. Thiết kế giao diện hiện đại với **Tailwind CSS v4**.
- **Backend (`/backend`)**: Máy chủ API mạnh mẽ xử lý nghiệp vụ kinh doanh (Business Logic) và giao tiếp với CSDL **MySQL**, được viết bằng **Node.js** và **Express.js**.

```text
03_App/
├── frontend/       # 💻 Web Application (Next.js, React, Tailwind CSS)
├── backend/        # ⚙️ API Server (Node.js, Express, MySQL)
└── README.md       # 📖 Tài liệu hướng dẫn cấp Root (File này)
```

---

## Hướng Dẫn Khởi Chạy Nhanh (Quick Start)

Bạn cần mở **2 cửa sổ Terminal (PowerShell/CMD)** độc lập để khởi chạy song song Backend và Frontend.

### Terminal 1: Khởi động Backend (API Server)

Backend chịu trách nhiệm cung cấp dữ liệu qua RESTful APIs.

1. Di chuyển vào thư mục backend:

   ```bash
   cd 03_App/backend
   ```
2. Cài đặt các thư viện (Dependencies):

   ```bash
   npm install
   ```
3. Cấu hình biến môi trường (`.env`):
   Sao chép file `.env.example` thành `.env` và cập nhật thông tin kết nối MySQL của bạn (nếu có).
4. Chạy server ở chế độ phát triển:

   ```bash
   npm run dev
   ```

   *Terminal sẽ thông báo Server đang chạy thành công.*

### Terminal 2: Khởi động Frontend (Web App)

Frontend gọi API từ Backend để hiển thị dữ liệu và cho phép người dùng tương tác.

1. Di chuyển vào thư mục frontend:

   ```bash
   cd 03_App/frontend
   ```
2. Cài đặt các thư viện (Dependencies):

   ```bash
   npm install
   ```
3. Chạy giao diện ở chế độ phát triển:

   ```bash
   npm run dev
   ```

   *Terminal sẽ cung cấp đường link truy cập, ví dụ: `http://localhost:3000`*

👉 Mở trình duyệt và truy cập **`http://localhost:3000`** để sử dụng hệ thống!

---

## Công Nghệ Sử Dụng (Tech Stack)

### Frontend

- **Framework Core**: Next.js 16+ (App Router), React 19
- **Giao diện & UI**: Tailwind CSS v4, Lucide React (Icons)
- **Quản lý State & API**: Zustand (Client State), TanStack React Query v5 (Server State), Axios
- **Form & Validation**: React Hook Form, Zod
- **Báo cáo & Phân tích**: Recharts (Biểu đồ), XLSX (Xuất Excel)

### Backend

- **Core Engine**: Node.js (ES Modules)
- **Framework API**: Express.js
- **Database Driver**: MySQL2 (Promise-based)
- **Bảo mật**: JWT (JSON Web Tokens) cho Authentication, Bcryptjs cho Hashing mật khẩu.
- **Tiện ích**: CORS, Dotenv

---

## Xem Chi Tiết Từng Phân Hệ

Để hiểu rõ hơn về kiến trúc thư mục, quy ước code và cách triển khai từng phần, vui lòng đọc các tài liệu tương ứng:

- ➡️ [Tài liệu chi tiết Frontend](./frontend/README.md)
- ➡️ [Tài liệu chi tiết Backend](./backend/README.md)

---

*© 2026 HRM Development Team. Built with passion.*
