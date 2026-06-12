# Hướng Dẫn Chạy Dự Án HRPayroll (Giao diện & API)

Để khởi chạy toàn bộ hệ thống (Frontend + Backend) kết nối với cơ sở dữ liệu thật, bạn thực hiện theo các bước ngắn gọn sau:

## Bước 1: Chuẩn bị Cơ sở dữ liệu (MySQL)

1. Đảm bảo MySQL Server đang chạy (XAMPP, MySQL Workbench,...).
2. Kiểm tra xem bạn đã tạo database `HRPayrollDB` và nạp dữ liệu từ thư mục `02_Database` chưa (Xem `HUONG_DAN_CHAY_DU_AN.md` để biết chi tiết).
3. Mở file `03_App/backend/.env` và cập nhật `DB_PASSWORD` nếu MySQL của bạn có cài mật khẩu (mặc định để trống).

---

## Bước 2: Khởi động Backend (API Server)

Mở một terminal (Command Prompt / PowerShell / VSCode Terminal) mới:

```bash
cd 03_App/backend
npm install
npm run dev
```

> **Lưu ý**: Khi thấy dòng chữ `🚀 HRM Backend API is running at http://localhost:8080`, tức là API đã sẵn sàng phục vụ. Đừng tắt terminal này.

---

## Bước 3: Khởi động Frontend (Next.js App)

Mở thêm một terminal **thứ 2**:

```bash
cd 03_App/frontend
npm install
npm run dev
```

> **Lưu ý**: Chờ vài giây để Next.js biên dịch, sau đó mở trình duyệt và truy cập: **[http://localhost:3000](http://localhost:3000)**

🎉 **Xong!** Bây giờ bạn đã có thể thao tác trực tiếp trên giao diện và dữ liệu sẽ được đọc/ghi thật vào MySQL.
