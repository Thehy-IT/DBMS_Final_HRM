# Phân hệ Frontend (Web Application) — HRM System

Đây là ứng dụng giao diện người dùng cho Hệ thống Quản trị Nhân sự (HRM ERP).
Dự án được xây dựng dựa trên hệ sinh thái hiện đại, hiệu năng cao với **Next.js (App Router)** và **React 19**, mang lại trải nghiệm người dùng mượt mà, phản hồi siêu tốc và thiết kế thẩm mỹ chuyên nghiệp.

---

## Công Nghệ Sử Dụng (Tech Stack)

Frontend HRM được cấu thành từ những công cụ mạnh mẽ và tiên tiến nhất ở thời điểm hiện tại:

### Core Framework

- **Next.js 16+**: Framework React cấp doanh nghiệp, sử dụng kiến trúc App Router tiên tiến để tối ưu hóa SSR/SSG và Server Components.
- **React 19**: Phiên bản mới nhất với các APIs đột phá, giúp tối ưu quản lý trạng thái và rendering.

### Giao Diện & Trải Nghiệm (UI/UX)

- **Tailwind CSS v4**: Utility-first CSS framework với engine siêu nhanh cho phép thiết kế mọi Layout mà không rời khỏi file JS/TS.
- **Lucide React**: Thư viện Icon sắc nét, hiện đại, nhẹ và linh hoạt.
- **clsx** & **tailwind-merge**: Tiện ích tối ưu hóa việc kết hợp và gán class động một cách an toàn.

### Gọi Dữ Liệu & Quản Lý Trạng Thái (Data Fetching & State)

- **Axios**: HTTP Client mạnh mẽ để giao tiếp với Backend REST API.
- **TanStack React Query v5**: Thư viện quản lý "Server State" đỉnh cao – tự động cache, đồng bộ, re-fetch dữ liệu ở chế độ nền.
- **Zustand**: Quản lý "Client State" (Global State) siêu nhẹ, không cần boilerplate phức tạp như Redux.

### Form & Validation

- **React Hook Form**: Quản lý trạng thái form tối ưu, giảm thiểu re-render, cực kỳ phù hợp cho các Form nhập liệu lớn (ví dụ: Form thêm nhân viên, tính lương).
- **Zod**: Khai báo và Validate Schema dữ liệu (TypeScript-first), kết hợp hoàn hảo cùng React Hook Form để chặn lỗi trước khi gửi dữ liệu lên Server.

### Tính Năng Chuyên Sâu

- **Recharts**: Dựng biểu đồ thống kê tương tác (Dashboard, Phân tích nhân sự).
- **XLSX (SheetJS)**: Hỗ trợ chức năng Export dữ liệu bảng lương, danh sách nhân viên ra file Excel siêu mượt ở phía client.

---

## Cấu Trúc Thư Mục Cốt Lõi

```text
03_App/frontend/
├── public/               # Tài nguyên tĩnh (Hình ảnh mẫu, SVG, Favicon)
├── src/
│   ├── app/              # (App Router) Định tuyến trang web (Routes, Layouts, Pages)
│   ├── components/       # Các Component UI tái sử dụng (Button, Table, Modal...)
│   └── lib/              # Tiện ích toàn cục (Cấu hình Axios, hàm helper format số tiền...)
├── next.config.mjs       # File cấu hình lõi của Next.js
├── tailwind.config.ts    # (Nếu có) Cấu hình theme/color cho Tailwind CSS
└── package.json          # Quản lý dependencies và script chạy
```

---

## Hướng Dẫn Cài Đặt & Chạy (Development)

### Bước 1: Cài đặt Dependencies

Mở terminal và di chuyển vào thư mục `frontend`:

```bash
cd 03_App/frontend
```

Sau đó, chạy lệnh để cài đặt các package:

```bash
npm install
```

### Bước 2: Chạy Ứng Dụng (Chế Độ Phát Triển)

```bash
npm run dev
```

Next.js sẽ khởi chạy Development Server, tự động biên dịch và áp dụng Fast Refresh mỗi khi bạn lưu file.
👉 Truy cập trên trình duyệt: **`http://localhost:3000`**

### Các Script Mở Rộng Khác

- `npm run build`: Build ứng dụng, tối ưu hóa toàn bộ file JS/CSS/Images để chuẩn bị đưa lên môi trường thật (Production).
- `npm run start`: Khởi chạy ứng dụng bằng bộ Build đã tạo ở lệnh trên. Phù hợp khi Deploy lên VPS hoặc Server thật.
- `npm run lint`: Chạy trình kiểm tra tĩnh mã nguồn (ESLint) để tìm ra các lỗi syntax và cảnh báo best practice.

---

## Kết Nối Với Backend

Mặc định, ứng dụng Frontend sẽ gọi API thông qua instance của Axios (thường nằm tại thư mục `src/lib/` hoặc tương tự).
Nếu Backend Server của bạn đang chạy ở một cổng khác ngoài cổng `8080`, hoặc bạn muốn deploy lên môi trường public, hãy cập nhật `baseURL` trong file cấu hình Axios để trỏ đến đúng domain/IP của Backend.
