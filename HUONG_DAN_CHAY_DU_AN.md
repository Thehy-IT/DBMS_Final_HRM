# HƯỚNG DẪN CHẠY DỰ ÁN — HRPayrollSystem

DBMS: MySQL 8.0+
Công cụ: MySQL Workbench 8.0 / MySQL Shell / DBeaver
Tổng file SQL: 25 files | ~10,700+ dòng SQL | 177 test cases
Môn học: Hệ Quản Trị Cơ Sở Dữ Liệu — DL2301CLCA

---

## Mục Lục

1. [Yêu Cầu Hệ Thống](#1-yêu-cầu-hệ-thống)
2. [Cấu Trúc Dự Án](#2-cấu-trúc-dự-án)
3. [Thứ Tự Chạy File SQL](#3-thứ-tự-chạy-file-sql)
4. [Hướng Dẫn Chi Tiết Từng Bước](#4-hướng-dẫn-chi-tiết-từng-bước)
5. [Hướng Dẫn Chạy Giao Diện & API](#5-hướng-dẫn-chạy-giao-diện--api)
6. [Lệnh Demo Cho Giảng Viên](#6-lệnh-demo-cho-giảng-viên)
7. [Xử Lý Lỗi Thường Gặp](#7-xử-lý-lỗi-thường-gặp)
8. [Checklist Hoàn Thành](#8-checklist-hoàn-thành)
9. [Ghi Chú Quan Trọng](#9-ghi-chú-quan-trọng)

---

## 1. Yêu Cầu Hệ Thống

| Thành phần | Phiên bản tối thiểu | Ghi chú |
| --- | --- | --- |
| MySQL Server | 8.0+ | Bắt buộc (hỗ trợ CHECK constraints, Window Functions) |
| MySQL Workbench | 8.0+ | Hoặc DBeaver, HeidiSQL, DataGrip |
| Quyền tài khoản | ALL PRIVILEGES hoặc SUPER | Cần tạo database, trigger, set biến global |
| Character Set | utf8mb4 | Hỗ trợ tiếng Việt đầy đủ |
| Collation | utf8mb4_unicode_ci | Sắp xếp tiếng Việt chuẩn |

Lưu ý: Dự án không tương thích với SQL Server. Toàn bộ cú pháp cốt lõi đã được viết theo chuẩn MySQL 8.0+.

---

## 2. Cấu Trúc Dự Án

```
DBMS_Final_HRM/
├── 01_Analysis/
│   ├── ERD_diagram.drawio          # Sơ đồ ERD (mở bằng draw.io)
│   └── requirements.md             # Yêu cầu hệ thống
│
├── 02_Database/
│   ├── DDL/
│   │   ├── 01_create_tables.sql    # Tạo database + 17 bảng
│   │   ├── 02_constraints.sql      # Ràng buộc & Logic kiểm tra bổ sung
│   │   └── 03_indexes.sql          # Index composite & tối ưu hiệu năng
│   ├── Functions/                  # 12 functions nghiệp vụ
│   ├── Triggers/                   # 21 triggers kiểm soát dữ liệu
│   ├── StoredProcedures/           # 25 procedures tính toán lương/báo cáo
│   ├── Views/                      # 6 views tổng hợp dữ liệu
│   └── DML/
│       ├── seed_data.sql           # Dữ liệu mẫu: 50 NV + 3 tháng chấm công
│       └── test_queries.sql        # 71 queries kiểm thử MySQL
│
├── 03_App/
│   ├── backend/                    # API Server (Node.js/Express)
│   │   ├── .env                    # Cấu hình kết nối DB
│   │   └── server.js               # Điểm chạy server
│   └── frontend/                   # Giao diện người dùng (Next.js)
│       └── src/                    # Mã nguồn giao diện
│
├── 04_Testing/
│   ├── testcase_luong.sql          # Test cases lương
│   └── testcase_chamcong.sql       # Test cases chấm công
│
├── 05_Docs/
│   ├── BaoCaoDoAn.docx             # Báo cáo đồ án chi tiết
│   └── Slides_BaoCao.pptx          # Slide thuyết trình
│
└── HUONG_DAN_CHAY_DU_AN.md        # File hướng dẫn này
```

---

## 3. Thứ Tự Chạy File SQL

Bắt buộc chạy theo đúng thứ tự dưới đây để đảm bảo phụ thuộc khoá ngoại và logic nghiệp vụ.

1. DDL/01_create_tables.sql (Tạo DB + 17 bảng)
2. DDL/02_constraints.sql (Ràng buộc & Helper SP)
3. DDL/03_indexes.sql (Index & Tối ưu)
4. Functions/ (Chạy tất cả các file trong thư mục này)
5. StoredProcedures/ (Chạy tất cả các file trong thư mục này)
6. Triggers/ (Chạy tất cả các file trong thư mục này)
7. Views/ (Chạy tất cả các file trong thư mục này)
8. DML/seed_data.sql (Nạp dữ liệu mẫu)
9. DML/test_queries.sql (Kiểm thử truy vấn)

---

## 4. Hướng Dẫn Chi Tiết Từng Bước

### Bước 0 — Cài Đặt Biến Global (chạy 1 lần)
Đăng nhập MySQL với quyền SUPER và thực hiện:
```sql
SET GLOBAL log_bin_trust_function_creators = 1;
SELECT VERSION(); -- Yêu cầu >= 8.0
```

### Bước 1 — Tạo Cấu Trúc Database
File: `02_Database/DDL/01_create_tables.sql`
Kiểm tra: `USE HRPayrollDB; SHOW TABLES;` (Kết quả: 17 bảng)

### Bước 2 — Ràng Buộc, Index & Hàm Nghiệp Vụ
Chạy lần lượt:
1. `02_Database/DDL/02_constraints.sql`
2. `02_Database/DDL/03_indexes.sql`
3. Các file trong `02_Database/Functions/`

### Bước 3 — Tạo Stored Procedures & Triggers
Lưu ý: MySQL yêu cầu đổi DELIMITER (thường dùng $$) khi tạo Procedure/Trigger.
1. Chạy các file trong `02_Database/StoredProcedures/`
2. Chạy các file trong `02_Database/Triggers/`

### Bước 4 — Nạp Dữ Liệu & Tính Lương
File: `02_Database/DML/seed_data.sql`
Tính lương cho quý 1 năm 2025:
```sql
CALL sp_TinhLuong(1, 2025, NULL, 0, 0);
CALL sp_TinhLuong(2, 2025, NULL, 0, 0);
CALL sp_TinhLuong(3, 2025, NULL, 0, 0);
```

---

## 5. Hướng Dẫn Chạy Giao Diện & API

Để khởi chạy toàn bộ hệ thống (Frontend + Backend) kết nối với cơ sở dữ liệu thật:

### Bước 1: Chuẩn bị Cơ sở dữ liệu
1. Đảm bảo MySQL Server đang chạy.
2. Đã hoàn tất các bước nạp Database phía trên.
3. Mở file `03_App/backend/.env` và cập nhật `DB_PASSWORD` (mặc định để trống).

### Bước 2: Khởi động Backend (API Server)
Mở một terminal mới:
```bash
cd 03_App/backend
npm install
npm run dev
```
Khi thấy thông báo `HRM Backend API is running at http://localhost:8080`, API đã sẵn sàng.

### Bước 3: Khởi động Frontend (Next.js App)
Mở thêm một terminal thứ 2:
```bash
cd 03_App/frontend
npm install
npm run dev
```
Truy cập trình duyệt: http://localhost:3000

---

## 6. Lệnh Demo Cho Giảng Viên

```sql
USE HRPayrollDB;

-- 1. Kiểm tra trạng thái hệ thống
SELECT 
    (SELECT COUNT(*) FROM NhanVien) AS TongNV,
    (SELECT COUNT(*) FROM BangLuong WHERE Nam=2025) AS SoBanGhiLuong;

-- 2. Xem Top 5 nhân viên lương cao nhất tháng 3/2025
SELECT nv.HoTen, pb.TenPB, 
       FORMAT(bl.LuongNet, 0) AS ThucLinh
FROM BangLuong bl
JOIN NhanVien nv ON bl.MaNV = nv.MaNV
JOIN PhongBan pb ON nv.MaPB = pb.MaPB
WHERE bl.Thang = 3 AND bl.Nam = 2025
ORDER BY bl.LuongNet DESC LIMIT 5;

-- 3. Demo Trigger: Chặn chấm công tương lai
INSERT INTO ChamCong (MaNV, NgayCham, TrangThai, NguoiCapNhat)
VALUES ('NV000001', DATE_ADD(CURDATE(), INTERVAL 7 DAY), 'DL', 'ADMIN');

-- 4. Báo cáo Dashboard nhân sự
CALL sp_BaoCaoNhanSu_TongQuan();
```

---

## 7. Xử Lý Lỗi Thường Gặp

- Lỗi log_bin_trust_function_creators: Chạy `SET GLOBAL log_bin_trust_function_creators = 1;`
- Lỗi DETERMINISTIC: Đảm bảo sử dụng các file trong thư mục 02_Database vì đã được tối ưu cho MySQL.
- Lỗi kết nối Database: Kiểm tra thông tin trong file `.env` ở thư mục backend.

---

## 8. Checklist Hoàn Thành

| Thành phần | Số lượng | Trạng thái |
| --- | --- | --- |
| Bảng (Tables) | 17 | Hoàn tất |
| Hàm (Functions) | 12 | Hoàn tất |
| Thủ tục (Procs) | 25 | Hoàn tất |
| Triggers | 21 | Hoàn tất |
| Views | 6 | Hoàn tất |
| Dữ liệu mẫu | 50 NV | Đã nạp |

---

## 9. Ghi Chú Quan Trọng

- Bảo mật: Không chia sẻ file .env chứa mật khẩu thực tế.
- Encoding: Luôn sử dụng utf8mb4 để hiển thị tiếng Việt chính xác.
- Hiệu năng: Các Index giúp tối ưu tốc độ tính toán cho tập dữ liệu lớn.

---
Cập nhật ngày: 15/06/2026 | HRPayrollSystem Team
