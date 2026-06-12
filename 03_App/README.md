# 🏢 Hệ thống Quản trị Nhân sự (HRM ERP)

Dự án được tổ chức theo mô hình **Monorepo** tách biệt rõ ràng các phân hệ, giúp bạn dễ dàng phân chia công việc, bảo trì và triển khai (Deploy) hệ thống.

## 📁 Kiến trúc Tổng quan

```text
03_App/
├── frontend/       # 💻 Giao diện người dùng (Next.js 15, React, Tailwind CSS)
├── backend/        # ⚙️ API Server & Xử lý Database (Sẵn sàng để bạn code)
├── docs/           # 📚 Toàn bộ tài liệu đặc tả, UI/UX, API Specification
└── README.md       # 📖 Hướng dẫn quản lý dự án (File này)
```

---

## ⚡ Hướng Dẫn Chạy Giao Diện Web Nhanh Gọn (Quick Start)

Để trải nghiệm ngay lập tức giao diện người dùng cùng dữ liệu giả lập (Mock Data), bạn chỉ cần mở **2 cửa sổ Terminal (Command Prompt/PowerShell)** và làm theo các bước sau:

**Terminal 1: Chạy Backend (Cung cấp API)**

```bash
cd 03_App/backend
npm install
npm start
```

*Máy chủ Backend sẽ báo: `🚀 HRM Backend API is running at http://localhost:8080`*

**Terminal 2: Chạy Frontend (Giao diện người dùng)**

```bash
cd 03_App/frontend
npm run dev
```

*Đợi một chút, sau đó mở trình duyệt và truy cập: **`http://localhost:3000`***

🎉 Vậy là xong! Bạn có thể xem Dashboard, Quản lý Nhân sự, Quản lý Hợp đồng và toàn bộ hệ thống giao diện chuẩn xác.

---

## 💻 1. Frontend (Giao diện Web)

Nằm trong thư mục `frontend/`. Đây là ứng dụng mà người dùng (Nhân sự, Admin) sẽ thao tác trực tiếp.

**Đặc điểm:**

- Cấu trúc thư mục tối ưu theo Next.js 15 App Router.
- Giao diện thiết kế bằng **Tailwind CSS v4** và Shadcn UI principles.
- Gọi API qua thư viện chuyên nghiệp **Axios** và quản lý cache bằng **TanStack Query**.

---

## ⚙️ 2. Backend (Máy chủ API)

Nằm trong thư mục `backend/`.

- Hiện tại tôi đã khởi tạo sẵn một máy chủ **Node.js (Express)** nhỏ trong này để chứa các mảng Mock Data và trả về dạng API (`GET /v1/employees`, `GET /v1/contracts`, v.v.).
- Nhờ có Backend này, Frontend đã được kiểm chứng hoạt động hoàn hảo thông qua RESTful API thay vì gắn cứng dữ liệu trên giao diện.

### 🔌 Hướng dẫn kết nối Database (SQL Server) thật

Để thay thế Mock Data bằng dữ liệu thật từ CSDL SQL Server (`DBMS_Final_HRM`), bạn làm theo các bước sau tại thư mục `backend/`:

**Bước 1: Cài đặt thư viện SQL Server**
Mở Terminal tại thư mục `backend` và chạy lệnh:

```bash
npm install mssql
```

**Bước 2: Cấu hình kết nối `.env`**
Tạo một file tên là `.env` bên trong thư mục `backend/` để lưu thông tin bảo mật CSDL:

```env
PORT=8080
DB_SERVER=localhost
DB_USER=sa
DB_PASSWORD=MatKhauCuaBan123
DB_NAME=DBMS_Final_HRM
```

**Bước 3: Viết logic lấy dữ liệu thật trong `server.js`**
Mở file `backend/server.js`, xóa các biến Mock (ví dụ `mockEmployees`) và thay API trả về dữ liệu bằng câu lệnh Query thực tế:

```javascript
import sql from 'mssql';
import dotenv from 'dotenv';
dotenv.config();

const dbConfig = {
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    server: process.env.DB_SERVER,
    database: process.env.DB_NAME,
    options: { encrypt: false, trustServerCertificate: true }
};

// Thay thế API Lấy danh sách nhân viên:
app.get('/v1/employees', async (req, res) => {
    try {
        await sql.connect(dbConfig);
        const result = await sql.query('SELECT * FROM NhanVien'); // Tên bảng trong SQL
        res.json({ data: result.recordset });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});
```

Sau khi lưu lại, khởi động lại Backend bằng lệnh `npm start`. Lúc này, mở giao diện Frontend, bạn sẽ thấy ứng dụng đã được đổ 100% dữ liệu thật từ Database thay vì dữ liệu mẫu!

---

## 📚 3. Docs (Tài liệu dự án)

Thư mục `docs/` là "linh hồn" của dự án. Tất cả cấu trúc, nghiệp vụ (Business Logic), yêu cầu màn hình và thiết kế Figma đều được lưu tại đây. Hãy đọc lại thư mục này nếu bạn cần nhớ quy tắc tính lương hay cấu trúc Database.

---

## 🚀 Hướng dẫn Triển khai (Deployment Roadmap)

Khi mang dự án này lên chạy thực tế trên Server hoặc VPS:

1. **Deploy Database**: Đẩy CSDL của bạn lên một máy chủ SQL Server.
2. **Deploy Backend**: Viết logic kết nối DB cho thư mục `backend/` và đưa lên máy chủ. Lấy đường link API (Ví dụ: `https://api.ten-du-an.com/v1`).
3. **Deploy Frontend**:
   - Vào file `frontend/src/lib/axios.ts`, đổi `baseURL` thành link API của bạn.
   - Đưa source code `frontend/` lên nền tảng đám mây như **Vercel** hoặc **Netlify** bằng vài cú click chuột.
