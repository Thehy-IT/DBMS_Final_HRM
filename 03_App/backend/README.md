# ⚙️ Phân hệ Backend (API Server)

Thư mục này được sử dụng để phát triển máy chủ API cung cấp dữ liệu cho ứng dụng Frontend.

## 📌 Hướng dẫn
1. Bạn có thể khởi tạo một dự án mới tại đây bằng công nghệ yêu thích của bạn:
   - **Node.js (Express/NestJS)**
   - **C# (.NET Core Web API)**
   - **Java (Spring Boot)**
   - **Python (Django/FastAPI)**

2. Code của bạn phải đảm bảo có thể đọc/ghi dữ liệu vào Database `DBMS_Final_HRM` đã được thiết kế ở các phase trước.
3. Các API Endpoints phải được thiết kế giống như trong file tài liệu [11_API_Specification.md](../docs/11_API_Specification.md) để đảm bảo tương thích 100% với Frontend.

## 🚀 Khởi tạo nhanh (Nếu dùng Node.js)
Nếu bạn chọn Node.js, bạn có thể mở Terminal tại thư mục này và gõ:
```bash
npm init -y
npm install express cors dotenv
```
Sau đó tạo file `index.js` để bắt đầu code máy chủ.
