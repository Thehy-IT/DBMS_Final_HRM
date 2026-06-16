# HRM (Hệ thống Quản lý Nhân sự) - Frontend

Đây là ứng dụng frontend cho Đồ án cuối kỳ môn Cơ sở Dữ liệu (Hệ thống HRM), được xây dựng bằng [Next.js](https://nextjs.org) và React.

## Công nghệ sử dụng

- **Framework:** [Next.js](https://nextjs.org/) (App Router)
- **Styling:** [Tailwind CSS](https://tailwindcss.com/)
- **Quản lý State:** [Zustand](https://zustand-demo.pmnd.rs/)
- **Gọi API (Data Fetching):** [Axios](https://axios-http.com/) & [TanStack React Query](https://tanstack.com/query/v5)
- **Form & Validation:** [React Hook Form](https://react-hook-form.com/) & [Zod](https://zod.dev/)
- **Biểu đồ:** [Recharts](https://recharts.org/)
- **Icon:** [Lucide React](https://lucide.dev/)

## Hướng dẫn cài đặt

### Yêu cầu hệ thống

Đảm bảo rằng bạn đã cài đặt Node.js trên máy tính.

### Cài đặt

1. Clone repository và di chuyển vào thư mục frontend:
   ```bash
   cd 03_App/frontend
   ```
2. Cài đặt các thư viện (dependencies):
   ```bash
   npm install
   # hoặc
   yarn install
   # hoặc
   pnpm install
   ```

### Khởi chạy môi trường phát triển (Development Server)

Khởi chạy ứng dụng:

```bash
npm run dev
# hoặc
yarn dev
# hoặc
pnpm dev
```

Mở [http://localhost:3000](http://localhost:3000) trên trình duyệt để xem kết quả.

## Cấu trúc thư mục

- `src/app/`: Các trang (pages) và layouts sử dụng Next.js App Router.
- `src/components/`: Các React components có thể tái sử dụng.
- `public/`: Chứa các tài nguyên tĩnh như hình ảnh, fonts,...

## Các câu lệnh (Scripts)

- `npm run dev`: Chạy server phát triển (development server).
- `npm run build`: Build ứng dụng tối ưu cho môi trường production.
- `npm run start`: Chạy ứng dụng ở môi trường production sau khi build.
- `npm run lint`: Chạy ESLint để kiểm tra và sửa lỗi code.
