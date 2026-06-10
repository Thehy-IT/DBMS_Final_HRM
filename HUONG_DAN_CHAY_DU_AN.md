# 📘 HƯỚNG DẪN CHẠY DỰ ÁN — HRPayrollSystem

> **DBMS:** MySQL 8.0+
> **Công cụ:** MySQL Workbench 8.0 / MySQL Shell / DBeaver
> **Tổng file SQL:** 25 files | ~10,700+ dòng SQL | 177 test cases
> **Môn học:** Hệ Quản Trị Cơ Sở Dữ Liệu — DL2301CLCA

---

## 📋 Mục Lục

1. [Yêu Cầu Hệ Thống](#1-yêu-cầu-hệ-thống)
2. [Cấu Trúc Dự Án](#2-cấu-trúc-dự-án)
3. [Thứ Tự Chạy File SQL](#3-thứ-tự-chạy-file-sql)
4. [Hướng Dẫn Chi Tiết Từng Bước](#4-hướng-dẫn-chi-tiết-từng-bước)
5. [Lệnh Demo Cho Giảng Viên](#5-lệnh-demo-cho-giảng-viên)
6. [Xử Lý Lỗi Thường Gặp](#6-xử-lý-lỗi-thường-gặp)
7. [Checklist Hoàn Thành](#7-checklist-hoàn-thành)
8. [Ghi Chú Quan Trọng](#8-ghi-chú-quan-trọng)

---

## 1. Yêu Cầu Hệ Thống

| Thành phần                 | Phiên bản tối thiểu            | Ghi chú                                                  |
| ---------------------------- | ---------------------------------- | --------------------------------------------------------- |
| **MySQL Server**       | 8.0+                               | Bắt buộc (hỗ trợ CHECK constraints, Window Functions) |
| **MySQL Workbench**    | 8.0+                               | Hoặc DBeaver, HeidiSQL, DataGrip                         |
| **Quyền tài khoản** | `ALL PRIVILEGES` hoặc `SUPER` | Cần tạo database, trigger, set biến global             |
| **Character Set**      | `utf8mb4`                        | Hỗ trợ tiếng Việt đầy đủ                          |
| **Collation**          | `utf8mb4_unicode_ci`             | Sắp xếp tiếng Việt chuẩn                             |

> ⚠️ **Lưu ý:** Dự án **không** tương thích với SQL Server. Toàn bộ cú pháp cốt lõi đã được viết theo chuẩn MySQL 8.0+.

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
│   │   ├── 01_create_tables.sql    # Tạo database + 17 bảng (Tier 0-5)
│   │   ├── 02_constraints.sql      # Ràng buộc & Logic kiểm tra bổ sung
│   │   └── 03_indexes.sql          # Index composite & tối ưu hiệu năng
│   │
│   ├── Functions/ (12 functions)
│   │   ├── fn_TinhThueTNCN.sql     # Hàm tính thuế TNCN (Scalar, Bậc, Giảm trừ)
│   │   ├── fn_TinhBHXH.sql         # Hàm tính BHXH/BHYT/BHTN (Lương đóng BH, NLĐ, NSDLĐ)
│   │   └── fn_SoNgayLamViec.sql    # Hàm tính ngày làm việc, hệ số công, tăng ca
│   │
│   ├── Triggers/ (21 triggers)
│   │   ├── trg_LogHopDong.sql      # Audit log & validate trạng thái hợp đồng
│   │   ├── trg_LogLuong.sql        # Audit log lương & bảo vệ bảng lương đã chốt
│   │   ├── trg_KiemTraChamCong.sql # Validate giờ giấc & ngày công
│   │   ├── trg_NhanVien_CheckTuoi.sql # Ràng buộc độ tuổi lao động
│   │   ├── trg_LuongCoBan_CheckOneCurrent.sql # Đảm bảo 1 mức lương hiện hành
│   │   ├── trg_KhauTru_Validate.sql # Chặn khấu trừ sai ngày
│   │   └── trg_NghiPhep_CheckOverlap.sql # Chặn trùng lặp đơn nghỉ phép
│   │
│   ├── StoredProcedures/ (25 procedures)
│   │   ├── sp_TinhLuong.sql        # Pipeline 8 bước tính lương tự động
│   │   ├── sp_ChamCong.sql         # Quản lý nhập/sửa/đồng bộ chấm công
│   │   ├── sp_TaoBangLuong.sql     # Xuất bảng lương, phiếu lương, BHXH, Thuế
│   │   ├── sp_BaoCaoNhanSu.sql     # Dashboard & Phân tích nhân sự đa chiều
│   │   ├── sp_TinhBHXH_ChiTiet.sql  # Chi tiết các khoản bảo hiểm
│   │   └── sp_TinhThueTNCN_ChiTiet.sql # Chi tiết các bậc thuế TNCN
│   │
│   ├── Views/ (6 views)
│   │   ├── vw_BangLuong.sql        # View tổng hợp lương, chi phí DN
│   │   └── vw_TongHopChamCong.sql  # View tổng hợp công, tỷ lệ chuyên cần
│   │
│   └── DML/
│       ├── seed_data.sql           # Dữ liệu mẫu: 50 NV + 3 tháng chấm công
│       └── test_queries.sql        # 71 queries kiểm thử MySQL trực tiếp
│
├── 03_App/
│   └── connection.config           # Cấu hình kết nối (Placeholder)
│
├── 04_Testing/
│   ├── testcase_luong.sql          # 102 test cases (SQL Server Reference)
│   └── testcase_chamcong.sql       # 75 test cases (SQL Server Reference)
│
├── 05_Docs/
│   ├── BaoCaoDoAn.docx             # Báo cáo đồ án chi tiết
│   └── Slides_BaoCao.pptx          # Slide thuyết trình
│
└── HUONG_DAN_CHAY_DU_AN.md        # File này
```

---

## 3. Thứ Tự Chạy File SQL

> ⚠️ **BẮT BUỘC** chạy theo đúng thứ tự dưới đây để đảm bảo phụ thuộc khoá ngoại và logic nghiệp vụ.

```
╔══════════════════════════════════════════════════════════════════╗
║             THỨ TỰ CHẠY FILE SQL — MySQL 8.0+                   ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                  ║
║  CẤU TRÚC CƠ SỞ DỮ LIỆU                                        ║
║  ──────────────────────────────────────────────────────────────  ║
║  ✅ [1] DDL/01_create_tables.sql    Tạo DB + 17 bảng            ║
║  ✅ [2] DDL/02_constraints.sql      Ràng buộc & Helper SP       ║
║  ✅ [3] DDL/03_indexes.sql          Index & Tối ưu              ║
║                                                                  ║
║  HÀM NGHIỆP VỤ (Functions)                                      ║
║  ──────────────────────────────────────────────────────────────  ║
║  ✅ [4a] Functions/fn_TinhThueTNCN.sql    Thuế TNCN 7 bậc      ║
║  ✅ [4b] Functions/fn_TinhBHXH.sql        Tính Bảo Hiểm        ║
║  ✅ [4c] Functions/fn_SoNgayLamViec.sql   Logic Ngày Công      ║
║                                                                  ║
║  THỦ TỤC LƯU TRỮ (Stored Procedures)                            ║
║  ──────────────────────────────────────────────────────────────  ║
║  ✅ [5a] StoredProcedures/sp_TinhBHXH_ChiTiet.sql                ║
║  ✅ [5b] StoredProcedures/sp_TinhThueTNCN_ChiTiet.sql            ║
║  ✅ [5c] StoredProcedures/sp_TinhLuong.sql      Pipeline Lương ║
║  ✅ [5d] StoredProcedures/sp_ChamCong.sql       Quản lý Công   ║
║  ✅ [5e] StoredProcedures/sp_TaoBangLuong.sql   Xuất Báo Cáo   ║
║  ✅ [5f] StoredProcedures/sp_BaoCaoNhanSu.sql   Dashboard NS   ║
║                                                                  ║
║  RÀNG BUỘC TỰ ĐỘNG (Triggers)                                   ║
║  ──────────────────────────────────────────────────────────────  ║
║  ✅ [6a] Triggers/trg_NhanVien_CheckTuoi.sql                     ║
║  ✅ [6b] Triggers/trg_LogHopDong.sql                             ║
║  ✅ [6c] Triggers/trg_LogLuong.sql                               ║
║  ✅ [6d] Triggers/trg_LuongCoBan_CheckOneCurrent.sql             ║
║  ✅ [6e] Triggers/trg_KiemTraChamCong.sql                        ║
║  ✅ [6f] Triggers/trg_KhauTru_Validate.sql                       ║
║  ✅ [6g] Triggers/trg_NghiPhep_CheckOverlap.sql                  ║
║                                                                  ║
║  GIAO DIỆN DỮ LIỆU (Views)                                      ║
║  ──────────────────────────────────────────────────────────────  ║
║  ✅ [7a] Views/vw_BangLuong.sql          View Lương & Chi Phí  ║
║  ✅ [7b] Views/vw_TongHopChamCong.sql    View Công & Chuyên Cần║
║                                                                  ║
║  DỮ LIỆU & KIỂM THỬ                                              ║
║  ──────────────────────────────────────────────────────────────  ║
║  ✅ [8]  DML/seed_data.sql         50 NV + 3 tháng CC          ║
║  ✅ [9]  DML/test_queries.sql      71 queries MySQL chính thức ║
║                                                                  ║
║  DEMO TÍNH LƯƠNG                                                 ║
║  ──────────────────────────────────────────────────────────────  ║
║  ▶  CALL sp_TinhLuong(1, 2025, NULL, 0, 0);                     ║
║  ▶  CALL sp_TinhLuong(2, 2025, NULL, 0, 0);                     ║
║  ▶  CALL sp_TinhLuong(3, 2025, NULL, 0, 0);                     ║
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝
```

---

## 4. Hướng Dẫn Chi Tiết Từng Bước

### 🔧 Bước 0 — Cài Đặt Biến Global (chạy 1 lần)

Đăng nhập MySQL với quyền `SUPER` (hoặc root) và thực hiện:

```sql
-- Cho phép tạo Functions có DETERMINISTIC/NO SQL
SET GLOBAL log_bin_trust_function_creators = 1;

-- Kiểm tra phiên bản MySQL (Yêu cầu >= 8.0 cho CTE & Window Functions)
SELECT VERSION();
```

---

### 📁 Bước 1 — Tạo Cấu Trúc Database

**File:** `02_Database/DDL/01_create_tables.sql`

```sql
-- Tạo database và 17 bảng theo Tier phụ thuộc
-- Đảm bảo sử dụng utf8mb4 để hỗ trợ tiếng Việt
```

**Kiểm tra:**
```sql
USE HRPayrollDB;
SHOW TABLES;
-- Kết quả: 17 bảng
```

---

### 📁 Bước 2 — Ràng Buộc, Index & Hàm Nghiệp Vụ

Chạy lần lượt:
1. `02_Database/DDL/02_constraints.sql` (Check constraints, Foreign Keys)
2. `02_Database/DDL/03_indexes.sql` (Tăng tốc truy vấn B-Tree/Hash)
3. Các file trong `02_Database/Functions/` (Tổng 12 hàm)

---

### 📁 Bước 3 — Tạo Stored Procedures & Triggers

**Lưu ý:** MySQL yêu cầu đổi `DELIMITER` (thường dùng `$$`) khi tạo Procedure/Trigger.

1. Chạy toàn bộ file trong `02_Database/StoredProcedures/` (25 procedures)
2. Chạy toàn bộ file trong `02_Database/Triggers/` (21 triggers)

---

### 📁 Bước 4 — Nạp Dữ Liệu & Tính Lương

**File:** `02_Database/DML/seed_data.sql`
- Nạp 50 nhân viên mẫu, cấu hình phòng ban, chức vụ, phụ cấp.
- Nạp dữ liệu chấm công thực tế cho tháng 1, 2, 3 năm 2025.

**Tính lương:**
```sql
-- Tính lương cho quý 1 năm 2025
CALL sp_TinhLuong(1, 2025, NULL, 0, 0);
CALL sp_TinhLuong(2, 2025, NULL, 0, 0);
CALL sp_TinhLuong(3, 2025, NULL, 0, 0);
```

---

## 5. Lệnh Demo Cho Giảng Viên

```sql
USE HRPayrollDB;

-- 1. Kiểm tra trạng thái hệ thống
SELECT 
    (SELECT COUNT(*) FROM NhanVien) AS TongNV,
    (SELECT COUNT(*) FROM BangLuong WHERE Nam=2025) AS SoBanGhiLuong,
    (SELECT COUNT(*) FROM AuditLog_Luong) AS SoLogThayDoi;

-- 2. Xem Top 5 nhân viên lương cao nhất tháng 3/2025
SELECT nv.HoTen, pb.TenPB, 
       FORMAT(bl.LuongGross, 0) AS Gross, 
       FORMAT(bl.ThueTNCN, 0) AS Thue, 
       FORMAT(bl.LuongNet, 0) AS ThucLinh
FROM BangLuong bl
JOIN NhanVien nv ON bl.MaNV = nv.MaNV
JOIN PhongBan pb ON nv.MaPB = pb.MaPB
WHERE bl.Thang = 3 AND bl.Nam = 2025
ORDER BY bl.LuongNet DESC LIMIT 5;

-- 3. Demo Trigger: Chặn chấm công tương lai
INSERT INTO ChamCong (MaNV, NgayCham, TrangThai, NguoiCapNhat)
VALUES ('NV000001', DATE_ADD(CURDATE(), INTERVAL 7 DAY), 'DL', 'ADMIN');
-- Mong đợi: ERROR 45000 - Ngay cham cong khong duoc o tuong lai

-- 4. Báo cáo Dashboard nhân sự
CALL sp_BaoCaoNhanSu_TongQuan();
```

---

## 6. Xử Lý Lỗi Thường Gặp

### ❌ Lỗi: `log_bin_trust_function_creators`
**Giải pháp:** Chạy `SET GLOBAL log_bin_trust_function_creators = 1;`

### ❌ Lỗi: `ERROR 1418 - DETERMINISTIC, NO SQL`
**Nguyên nhân:** Thiếu khai báo đặc tính hàm trong MySQL.
**Giải pháp:** Tất cả file trong dự án đã được thêm `DETERMINISTIC`. Đảm bảo chạy đúng file.

### ❌ Lỗi: Chạy file SQL Server `.sql` trong MySQL
**Hiện tượng:** Lỗi cú pháp tại `GO`, `NVARCHAR`, `IDENTITY`.
**Giải pháp:** Các file trong `04_Testing/` hiện là bản tham chiếu SQL Server. Hãy sử dụng `02_Database/DML/test_queries.sql` để kiểm thử trực tiếp trên MySQL.

---

## 7. Checklist Hoàn Thành

Chạy script sau để kiểm tra mức độ hoàn thiện của database:

```sql
USE HRPayrollDB;
SELECT 'Tables' AS Type, COUNT(*) AS Actual, 17 AS Expected FROM information_schema.TABLES WHERE TABLE_SCHEMA='HRPayrollDB' AND TABLE_TYPE='BASE TABLE'
UNION ALL
SELECT 'Procedures', COUNT(*), 25 FROM information_schema.ROUTINES WHERE ROUTINE_SCHEMA='HRPayrollDB' AND ROUTINE_TYPE='PROCEDURE'
UNION ALL
SELECT 'Functions', COUNT(*), 12 FROM information_schema.ROUTINES WHERE ROUTINE_SCHEMA='HRPayrollDB' AND ROUTINE_TYPE='FUNCTION'
UNION ALL
SELECT 'Triggers', COUNT(*), 21 FROM information_schema.TRIGGERS WHERE TRIGGER_SCHEMA='HRPayrollDB'
UNION ALL
SELECT 'Views', COUNT(*), 6 FROM information_schema.VIEWS WHERE TABLE_SCHEMA='HRPayrollDB';
```

| Thành phần       | Số lượng | Trạng thái |
| ---------------- | -------- | ---------- |
| Bảng (Tables)    | 17       | Hoàn tất   |
| Hàm (Functions)  | 12       | Hoàn tất   |
| Thủ tục (Procs)  | 25       | Hoàn tất   |
| Triggers         | 21       | Hoàn tất   |
| Views            | 6        | Hoàn tất   |
| Dữ liệu mẫu      | 50 NV    | Đã nạp     |
| Test Cases       | 177      | Tham chiếu |

---

## 8. Ghi Chú Quan Trọng

> 🛡️ **Bảo mật:** Không chia sẻ file `connection.config` nếu có chứa thông tin mật khẩu thực tế.
> 
> 🔡 **Encoding:** Luôn chọn `utf8mb4` khi import dữ liệu để tránh lỗi font tiếng Việt.
> 
> 🚀 **Hiệu năng:** Các `Indexes` trong `03_indexes.sql` giúp tăng tốc tính lương từ ~5s xuống <1s cho 50 NV.

---
*Cập nhật ngày: 10/06/2026 | HRPayrollSystem Team*
