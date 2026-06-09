# 📘 HƯỚNG DẪN CHẠY DỰ ÁN — HRPayrollSystem

> **DBMS:** MySQL 8.0+
> **Công cụ:** MySQL Workbench 8.0 / MySQL Shell / DBeaver
> **Tổng file SQL:** 13 files | ~11,000+ dòng SQL | 177 test cases
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

| Thành phần | Phiên bản tối thiểu | Ghi chú |
|---|---|---|
| **MySQL Server** | 8.0+ | Bắt buộc (hỗ trợ CHECK constraints, Window Functions) |
| **MySQL Workbench** | 8.0+ | Hoặc DBeaver, HeidiSQL, DataGrip |
| **Quyền tài khoản** | `ALL PRIVILEGES` hoặc `SUPER` | Cần tạo database, trigger, set biến global |
| **Character Set** | `utf8mb4` | Hỗ trợ tiếng Việt đầy đủ |
| **Collation** | `utf8mb4_unicode_ci` | Sắp xếp tiếng Việt chuẩn |

> ⚠️ **Lưu ý:** Dự án **không** tương thích với SQL Server. Toàn bộ cú pháp đã được viết theo chuẩn MySQL 8.0+.

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
│   │   ├── 01_create_tables.sql    # Tạo database + 15 bảng
│   │   ├── 02_constraints.sql      # Ràng buộc & index bổ sung
│   │   └── 03_indexes.sql          # Index hiệu năng
│   │
│   ├── Functions/
│   │   ├── fn_TinhThueTNCN.sql     # Hàm tính thuế TNCN 7 bậc
│   │   ├── fn_TinhBHXH.sql         # Hàm tính BHXH/BHYT/BHTN
│   │   └── fn_SoNgayLamViec.sql    # Hàm tính ngày làm việc chuẩn
│   │
│   ├── Triggers/
│   │   ├── trg_LogHopDong.sql      # Trigger audit hợp đồng
│   │   ├── trg_LogLuong.sql        # Trigger audit lương + bảo vệ bảng lương chốt
│   │   └── trg_KiemTraChamCong.sql # Trigger validate chấm công
│   │
│   ├── StoredProcedures/
│   │   ├── sp_TinhLuong.sql        # SP cốt lõi: tính lương tự động
│   │   ├── sp_ChamCong.sql         # SP quản lý vòng đời chấm công
│   │   ├── sp_TaoBangLuong.sql     # SP tạo bảng lương chính thức
│   │   └── sp_BaoCaoNhanSu.sql     # SP báo cáo nhân sự đa chiều
│   │
│   ├── Views/
│   │   ├── vw_BangLuong.sql        # View tổng hợp bảng lương
│   │   └── vw_TongHopChamCong.sql  # View tổng hợp chấm công
│   │
│   └── DML/
│       ├── seed_data.sql           # Dữ liệu mẫu: 50 NV + 3 tháng CC
│       └── test_queries.sql        # 71 queries kiểm thử tổng thể
│
├── 03_App/
│   └── connection.config           # Cấu hình kết nối MySQL
│
├── 04_Testing/
│   ├── testcase_luong.sql          # 102 test cases module lương
│   └── testcase_chamcong.sql       # 75 test cases module chấm công
│
├── 05_Docs/
│   ├── BaoCaoDoAn.docx             # Báo cáo đồ án chi tiết
│   └── Slides_BaoCao.pptx          # Slide thuyết trình
│
└── HUONG_DAN_CHAY_DU_AN.md        # File này
```

---

## 3. Thứ Tự Chạy File SQL

> ⚠️ **BẮT BUỘC** chạy theo đúng thứ tự dưới đây. Sai thứ tự sẽ gây lỗi do phụ thuộc khoá ngoại và đối tượng.

```
╔══════════════════════════════════════════════════════════════════╗
║             THỨ TỰ CHẠY FILE SQL — MySQL 8.0+                   ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                  ║
║  CẤU TRÚC CƠ SỞ DỮ LIỆU                                        ║
║  ──────────────────────────────────────────────────────────────  ║
║  ✅ [1] DDL/01_create_tables.sql    Tạo DB + 15 bảng            ║
║  ✅ [2] DDL/02_constraints.sql      Ràng buộc bổ sung           ║
║  ✅ [3] DDL/03_indexes.sql          Index hiệu năng             ║
║                                                                  ║
║  FUNCTIONS (Không phụ thuộc nhau)                               ║
║  ──────────────────────────────────────────────────────────────  ║
║  ✅ [4a] Functions/fn_TinhThueTNCN.sql    Thuế TNCN 7 bậc      ║
║  ✅ [4b] Functions/fn_TinhBHXH.sql        Tính BHXH            ║
║  ✅ [4c] Functions/fn_SoNgayLamViec.sql   Ngày làm việc        ║
║                                                                  ║
║  TRIGGERS (Phụ thuộc bảng)                                      ║
║  ──────────────────────────────────────────────────────────────  ║
║  ✅ [5a] Triggers/trg_LogHopDong.sql      Audit hợp đồng       ║
║  ✅ [5b] Triggers/trg_LogLuong.sql        Audit lương          ║
║  ✅ [5c] Triggers/trg_LuongCoBan_CheckOneCurrent.sql Check lương duy nhất ║
║  ✅ [5d] Triggers/trg_KiemTraChamCong.sql Validate chấm công   ║
║  ✅ [5e] Triggers/trg_NghiPhep_CheckOverlap.sql Check trùng nghỉ phép ║
║                                                                  ║
║  STORED PROCEDURES (Phụ thuộc Functions)                        ║
║  ──────────────────────────────────────────────────────────────  ║
║  ✅ [6a] StoredProcedures/sp_TinhLuong.sql      Tính lương     ║
║  ✅ [6b] StoredProcedures/sp_ChamCong.sql        Chấm công     ║
║  ✅ [6c] StoredProcedures/sp_TaoBangLuong.sql    Bảng lương    ║
║  ✅ [6d] StoredProcedures/sp_BaoCaoNhanSu.sql    Báo cáo NS   ║
║                                                                  ║
║  VIEWS (Phụ thuộc Functions + bảng)                             ║
║  ──────────────────────────────────────────────────────────────  ║
║  ✅ [7a] Views/vw_BangLuong.sql          View bảng lương       ║
║  ✅ [7b] Views/vw_TongHopChamCong.sql    View chấm công        ║
║                                                                  ║
║  DỮ LIỆU MẪU (Phụ thuộc tất cả ở trên)                        ║
║  ──────────────────────────────────────────────────────────────  ║
║  ✅ [8]  DML/seed_data.sql         50 NV + 3 tháng CC          ║
║                                                                  ║
║  DEMO TÍNH LƯƠNG                                                 ║
║  ──────────────────────────────────────────────────────────────  ║
║  ▶  CALL sp_TinhLuong(1, 2025, NULL, 0, 0);                     ║
║  ▶  CALL sp_TinhLuong(2, 2025, NULL, 0, 0);                     ║
║  ▶  CALL sp_TinhLuong(3, 2025, NULL, 0, 0);                     ║
║                                                                  ║
║  KIỂM THỬ                                                        ║
║  ──────────────────────────────────────────────────────────────  ║
║  ✅ [9a] Testing/testcase_luong.sql     102 test cases          ║
║  ✅ [9b] Testing/testcase_chamcong.sql   75 test cases          ║
║  ✅ [10] DML/test_queries.sql           71 queries tổng thể     ║
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝
```

---

## 4. Hướng Dẫn Chi Tiết Từng Bước

### 🔧 Bước 0 — Cài Đặt Biến Global (chạy 1 lần)

Trước khi bắt đầu, đăng nhập MySQL với quyền `SUPER` và chạy:

```sql
-- Cho phép tạo Functions có DETERMINISTIC/NO SQL
SET GLOBAL log_bin_trust_function_creators = 1;

-- Kiểm tra phiên bản MySQL (phải >= 8.0)
SELECT VERSION();
-- Kết quả mong đợi: 8.0.xx
```

---

### 📁 Bước 1 — Tạo Database & Bảng

**File:** `02_Database/DDL/01_create_tables.sql`

```sql
-- Tạo database với utf8mb4
CREATE DATABASE IF NOT EXISTS HRPayrollDB
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE HRPayrollDB;

-- Chạy toàn bộ file 01_create_tables.sql
-- Kết quả: 15 bảng được tạo
```

**Kiểm tra:**
```sql
USE HRPayrollDB;
SHOW TABLES;
-- Mong đợi: 15 bảng
```

---

### 📁 Bước 2 — Ràng Buộc & Index

**File:** `02_Database/DDL/02_constraints.sql`

```sql
-- Chạy toàn bộ file 02_constraints.sql
-- File sẽ in thông báo trạng thái:
SELECT '[INFO] 02_constraints.sql - bat dau ap dung rang buoc' AS Status;
```

**File:** `02_Database/DDL/03_indexes.sql`

```sql
-- Chạy toàn bộ file 03_indexes.sql
-- Tạo các index composite cho hiệu năng truy vấn
```

---

### 📁 Bước 3 — Tạo Functions

> **Lưu ý:** MySQL yêu cầu đổi DELIMITER trước khi tạo hàm nhiều câu lệnh.

**File:** `02_Database/Functions/fn_TinhThueTNCN.sql`

Chứa 3 hàm:
- `fn_TinhThueTNCN_Scalar(p_ThuNhapChiuThue)` — Trả về tiền thuế
- `fn_XacDinhBacThue(p_ThuNhapChiuThue)` — Trả về số bậc (1–7)
- `fn_TinhGiamTruPhuThuoc(p_MaNV, p_Thang, p_Nam)` — Tổng giảm trừ phụ thuộc

**File:** `02_Database/Functions/fn_TinhBHXH.sql`

**File:** `02_Database/Functions/fn_SoNgayLamViec.sql`

```sql
-- Cú pháp tạo function trong MySQL
DELIMITER $$

CREATE FUNCTION fn_TinhThueTNCN_Scalar(
    p_ThuNhapChiuThue DECIMAL(18,2)
)
RETURNS DECIMAL(18,2)
DETERMINISTIC
NO SQL
BEGIN
    -- ... nội dung hàm ...
END$$

DELIMITER ;
```

**Kiểm tra:**
```sql
-- Kiểm tra functions đã tạo
SELECT ROUTINE_NAME, ROUTINE_TYPE
FROM INFORMATION_SCHEMA.ROUTINES
WHERE ROUTINE_SCHEMA = 'HRPayrollDB'
  AND ROUTINE_TYPE = 'FUNCTION'
ORDER BY ROUTINE_NAME;
-- Mong đợi: 3+ functions
```

---

### 📁 Bước 4 — Tạo Triggers

**File:** `02_Database/Triggers/trg_LogHopDong.sql`

Chứa các trigger audit hợp đồng (AFTER INSERT, AFTER UPDATE).

**File:** `02_Database/Triggers/trg_LogLuong.sql`

Chứa các trigger:
- `trg_LuongCoBan_AfterInsert` — Log điều chỉnh lương mới
- `trg_LuongCoBan_AfterUpdate` — Log từng cột thay đổi
- `trg_BangLuong_BeforeUpdate` — Ngăn sửa bảng lương CHỐT
- `trg_BangLuong_BeforeDelete` — Ngăn xóa bảng lương CHỐT
- `trg_BangLuong_AfterUpdate` — Log chuyển trạng thái

**File:** `02_Database/Triggers/trg_LuongCoBan_CheckOneCurrent.sql`

Chứa trigger đảm bảo nghiệp vụ:
- `trg_LuongCoBan_CheckOneCurrent` — Đảm bảo mỗi nhân viên chỉ có 1 mức lương đang áp dụng (NgayHetHieuLuc IS NULL).
**File:** `02_Database/Triggers/trg_KiemTraChamCong.sql`

```sql
-- Cú pháp trigger trong MySQL (dùng NEW/OLD thay INSERTED/DELETED)
DELIMITER $$

CREATE TRIGGER trg_LuongCoBan_AfterInsert
AFTER INSERT ON LuongCoBan
```

**File:** `02_Database/Triggers/trg_NghiPhep_CheckOverlap.sql`
- `trg_NghiPhep_CheckOverlap` — Ngăn chặn đơn nghỉ phép trùng lặp (Overlap) của cùng một nhân viên.

FOR EACH ROW
BEGIN
    -- Dùng NEW.column thay vì INSERTED.column (SQL Server)
    -- ...
END$$

DELIMITER ;
```

**Kiểm tra:**
```sql
-- Kiểm tra triggers đã tạo
SELECT TRIGGER_NAME, EVENT_MANIPULATION, EVENT_OBJECT_TABLE, ACTION_TIMING
FROM INFORMATION_SCHEMA.TRIGGERS
WHERE TRIGGER_SCHEMA = 'HRPayrollDB'
ORDER BY EVENT_OBJECT_TABLE, ACTION_TIMING;
```

---

### 📁 Bước 5 — Tạo Stored Procedures

**File:** `02_Database/StoredProcedures/sp_TinhLuong.sql`

Cú pháp gọi:
```sql
-- Tính lương tháng 3/2025 toàn bộ nhân viên
CALL sp_TinhLuong(3, 2025, NULL, 0, 0);

-- Tính lương riêng 1 nhân viên
CALL sp_TinhLuong(3, 2025, 'NV000001', 0, 0);

-- Tính lại (ghi đè bản nháp cũ)
CALL sp_TinhLuong(3, 2025, NULL, 1, 0);

-- Xem kết quả, không ghi DB (Dry Run)
CALL sp_TinhLuong(3, 2025, NULL, 0, 1);
```

**File:** `02_Database/StoredProcedures/sp_ChamCong.sql`

Chứa các SP:
- `sp_ChamCong_NhapHangNgay` — UPSERT 1 NV 1 ngày
- `sp_ChamCong_NhapLoat` — Nhập hàng loạt từ bảng tạm
- `sp_ChamCong_CapNhat` — Sửa trạng thái / giờ giấc
- `sp_ChamCong_DongBoNghiPhep` — Đồng bộ đơn đã duyệt → CC
- `sp_NghiPhep_PheDuyet` — Duyệt / từ chối đơn nghỉ
- `sp_ChamCong_BaoCaoThang` — Báo cáo tổng hợp kỳ lương

**File:** `02_Database/StoredProcedures/sp_TaoBangLuong.sql`

Chứa các SP:
- `sp_TaoBangLuong_ChinhThuc` — Bảng lương tổng hợp chính thức
- `sp_TaoBangLuong_PhieuLuong` — Phiếu lương chi tiết 1 NV
- `sp_TaoBangLuong_BHXH` — Danh sách đóng BHXH tháng
- `sp_TaoBangLuong_QuyetToanThue` — Dữ liệu quyết toán thuế TNCN
- `sp_TaoBangLuong_SoSanh` — So sánh quỹ lương nhiều kỳ
- `sp_TaoBangLuong_ChiPhiNhanSu` — Chi phí nhân sự toàn DN

**File:** `02_Database/StoredProcedures/sp_BaoCaoNhanSu.sql`

Chứa các SP:
- `sp_BaoCaoNhanSu_TongQuan` — Dashboard nhân sự tổng hợp
- `sp_BaoCaoNhanSu_TheoPhongBan` — Phân tích cơ cấu theo PB/CV
- `sp_BaoCaoNhanSu_HopDong` — Trạng thái & sắp hết hạn HĐ
- `sp_BaoCaoNhanSu_BienDong` — Tuyển mới / nghỉ việc theo kỳ
- `sp_BaoCaoNhanSu_LuongPhanPhoi` — Phân phối lương & xếp hạng
- `sp_BaoCaoNhanSu_NghiPhepNam` — Quản lý phép năm tồn dư

**Kiểm tra:**
```sql
SELECT ROUTINE_NAME, ROUTINE_TYPE
FROM INFORMATION_SCHEMA.ROUTINES
WHERE ROUTINE_SCHEMA = 'HRPayrollDB'
  AND ROUTINE_TYPE = 'PROCEDURE'
ORDER BY ROUTINE_NAME;
-- Mong đợi: 16+ stored procedures
```

---

### 📁 Bước 6 — Tạo Views

**File:** `02_Database/Views/vw_BangLuong.sql`

Chứa 3 views:
- `vw_BangLuong` — Chi tiết lương đầy đủ từng NV từng kỳ
- `vw_BangLuong_TongHop` — Tổng hợp quỹ lương theo PB/tháng
- `vw_ThueTNCN_KyQuyetToan` — Quyết toán thuế TNCN theo NV

**File:** `02_Database/Views/vw_TongHopChamCong.sql`

**Kiểm tra:**
```sql
SELECT TABLE_NAME AS ViewName
FROM INFORMATION_SCHEMA.VIEWS
WHERE TABLE_SCHEMA = 'HRPayrollDB'
ORDER BY TABLE_NAME;
-- Mong đợi: 3+ views
```

---

### 📁 Bước 7 — Nạp Dữ Liệu Mẫu

**File:** `02_Database/DML/seed_data.sql`

```sql
USE HRPayrollDB;

-- File tự động tắt kiểm tra FK tạm thời
SET FOREIGN_KEY_CHECKS = 0;

-- Dùng TRUNCATE TABLE thay vì DELETE (nhanh hơn, reset AUTO_INCREMENT)
-- Dùng START TRANSACTION ... COMMIT (thay vì BEGIN TRANSACTION của SQL Server)
-- Không cần N'' prefix (MySQL utf8mb4 hỗ trợ tiếng Việt trực tiếp)

-- Chạy toàn bộ file seed_data.sql
```

**Kiểm tra sau khi nạp:**
```sql
SELECT 'PhongBan'   AS Bang, COUNT(*) AS SoLuong FROM PhongBan   UNION ALL
SELECT 'ChucVu',             COUNT(*)             FROM ChucVu     UNION ALL
SELECT 'NhanVien',           COUNT(*)             FROM NhanVien   UNION ALL
SELECT 'HopDong',            COUNT(*)             FROM HopDong    UNION ALL
SELECT 'LuongCoBan',         COUNT(*)             FROM LuongCoBan UNION ALL
SELECT 'ChamCong',           COUNT(*)             FROM ChamCong;
-- Mong đợi: NhanVien = 50, ChamCong >= 3000
```

---

### 📁 Bước 8 — Chạy Tính Lương 3 Tháng

```sql
-- Tính lương tháng 1, 2, 3 năm 2025
CALL sp_TinhLuong(1, 2025, NULL, 0, 0);
CALL sp_TinhLuong(2, 2025, NULL, 0, 0);
CALL sp_TinhLuong(3, 2025, NULL, 0, 0);

-- Xác nhận bảng lương tháng 1 (Demo quy trình Confirmed)
CALL sp_XacNhanBangLuong(1, 2025);
```

**Kiểm tra:**
```sql
SELECT Thang, Nam, COUNT(*) AS SoNV,
       FORMAT(SUM(LuongNet), 0) AS TongNet
FROM BangLuong
WHERE Nam = 2025
GROUP BY Thang, Nam
ORDER BY Thang;
-- Mong đợi: 3 dòng, mỗi dòng ~50 NV
```

---

### 📁 Bước 9 — Chạy Kiểm Thử

**File:** `04_Testing/testcase_luong.sql` — 102 test cases

Bao gồm các nhóm test:
- §1 Sanity Check — Dữ liệu nền BangLuong 3 tháng
- §2 fn_TinhThueTNCN — 7 bậc thuế + edge cases
- §3 fn_TinhBHXH — NLĐ/NSDLĐ/Thử việc/Trần BH
- §4 sp_TinhLuong — Pipeline 8 bước, DryRun, Override
- §5 Tính đúng công thức: Lương Net = Gross - BH - Thuế - KT
- §6 ChiTietLuong — Dòng thu nhập & khấu trừ đủ/đúng
- §7 ThueTNCN bảng chi tiết — bậc thuế, TNCT
- §8 sp_XacNhanBangLuong — Workflow Draft→Confirmed
- §9 Thử việc không đóng BH — BH_NLD = 0
- §10 Phụ cấp & OT — Cộng đúng vào Gross
- §11 KhauTru phát sinh — Applied sau sp_TinhLuong
- §12 sp_TaoBangLuong_ChinhThuc
- §13 sp_TaoBangLuong_BHXH
- §14 sp_TaoBangLuong_QuyetToanThue
- §15 sp_TaoBangLuong_SoSanh

**File:** `04_Testing/testcase_chamcong.sql` — 75 test cases

**File:** `02_Database/DML/test_queries.sql` — 71 queries tổng thể

Bao gồm:
- §1 Kiểm tra dữ liệu nền (Sanity Check)
- §2 Kiểm thử Functions
- §3 Kiểm thử sp_TinhLuong (đầy đủ 3 tháng)
- §4 Kiểm thử Triggers & Audit Log
- §5 Kiểm thử Views
- §6 Kiểm thử Constraints (Negative Tests)
- §7 Integration Test — vòng đời lương 1 NV
- §8 Kiểm tra hiệu năng & Index Usage
- §9 Báo cáo tổng kết kiểm thử

---

## 5. Lệnh Demo Cho Giảng Viên

```sql
-- ══════════════════════════════════════════════════════
-- DEMO SCRIPT — Chạy tuần tự trước giảng viên
-- DBMS: MySQL 8.0+
-- ══════════════════════════════════════════════════════

USE HRPayrollDB;

-- 1. Kiểm tra cấu trúc đã tạo đủ
SELECT 'Tables' AS ObjectType, COUNT(*) AS Count
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'HRPayrollDB' AND TABLE_TYPE = 'BASE TABLE'
UNION ALL
SELECT 'Views',       COUNT(*)
FROM INFORMATION_SCHEMA.VIEWS
WHERE TABLE_SCHEMA = 'HRPayrollDB'
UNION ALL
SELECT 'Procedures',  COUNT(*)
FROM INFORMATION_SCHEMA.ROUTINES
WHERE ROUTINE_SCHEMA = 'HRPayrollDB' AND ROUTINE_TYPE = 'PROCEDURE'
UNION ALL
SELECT 'Functions',   COUNT(*)
FROM INFORMATION_SCHEMA.ROUTINES
WHERE ROUTINE_SCHEMA = 'HRPayrollDB' AND ROUTINE_TYPE = 'FUNCTION'
UNION ALL
SELECT 'Triggers',    COUNT(*)
FROM INFORMATION_SCHEMA.TRIGGERS
WHERE TRIGGER_SCHEMA = 'HRPayrollDB';
-- Mong đợi: Tables>=15 | Views>=3 | Procedures>=16 | Functions>=3 | Triggers>=10

-- 2. Demo tính lương 1 lệnh
CALL sp_TinhLuong(3, 2025, NULL, 0, 0);

-- 3. Xem kết quả top lương
SELECT nv.HoTen, pb.TenPB,
    FORMAT(bl.LuongGross, 0) AS Gross,
    FORMAT(bl.ThueTNCN, 0)   AS Thue,
    FORMAT(bl.LuongNet, 0)   AS Net
FROM BangLuong bl
JOIN NhanVien nv ON bl.MaNV = nv.MaNV
JOIN PhongBan pb ON nv.MaPB = pb.MaPB
WHERE bl.Thang = 3 AND bl.Nam = 2025
ORDER BY bl.LuongNet DESC
LIMIT 5;

-- 4. Demo trigger audit (thay đổi lương -> log tự động)
UPDATE LuongCoBan
SET NgayHetHieuLuc = '2025-03-31'
WHERE MaNV = 'NV000003' AND NgayHetHieuLuc IS NULL;

INSERT INTO LuongCoBan (MaNV, LuongCB, LuongDongBH, NgayHieuLuc, LyDo, NguoiDuyet)
VALUES ('NV000003', 28000000, 28000000, '2025-04-01', 'Tang luong KPI', 'NV000001');

-- Xem log tự động ghi
SELECT MaNV, HanhDong, TenCot, GiaTriCu, GiaTriMoi,
    TIME(NgayThayDoi) AS Gio
FROM AuditLog_Luong
ORDER BY MaLog DESC
LIMIT 3;

-- 5. Demo trigger validate (chặn dữ liệu sai)
-- Trigger sẽ báo lỗi SIGNAL nếu ngày chấm công > hôm nay
INSERT INTO ChamCong (MaNV, NgayCham, TrangThai, HeSoTangCa, NguoiCapNhat)
VALUES ('NV000001', DATE_ADD(CURDATE(), INTERVAL 5 DAY), 'DL', 1.5, 'TEST');
-- Kết quả mong đợi: ERROR - Trigger đã chặn

-- 6. Dashboard nhân sự
CALL sp_BaoCaoNhanSu_TongQuan();

-- 7. Danh sách BHXH
CALL sp_TaoBangLuong_BHXH(3, 2025);
```

---

## 6. Xử Lý Lỗi Thường Gặp

### ❌ Lỗi 1: `log_bin_trust_function_creators = 0`

**Nguyên nhân:** MySQL không cho phép tạo FUNCTION chứa câu lệnh SQL khi binlog đang bật.

**Giải pháp:**
```sql
-- Chạy với quyền SUPER/SYSTEM_VARIABLES_ADMIN
SET GLOBAL log_bin_trust_function_creators = 1;

-- Hoặc thêm vào file my.cnf / my.ini:
-- [mysqld]
-- log_bin_trust_function_creators = 1
```

---

### ❌ Lỗi 2: `ERROR 1418 - This function has none of DETERMINISTIC, NO SQL`

**Nguyên nhân:** Function thiếu khai báo `DETERMINISTIC` hoặc `NO SQL` / `READS SQL DATA`.

**Giải pháp:**
```sql
-- Đảm bảo function có khai báo:
CREATE FUNCTION fn_TenHam(...)
RETURNS ...
DETERMINISTIC    -- hoặc NOT DETERMINISTIC
NO SQL           -- hoặc READS SQL DATA nếu có SELECT
BEGIN
    -- ...
END;
```

---

### ❌ Lỗi 3: `ERROR 1215 - Cannot add foreign key constraint`

**Nguyên nhân:** Bảng cha chưa tồn tại, hoặc kiểu dữ liệu không khớp.

**Giải pháp:**
```sql
-- Kiểm tra thứ tự tạo bảng trong 01_create_tables.sql
-- Tạo Tier 0 trước, Tier 1 sau, v.v.

-- Tạm tắt kiểm tra FK (chỉ dùng khi cần thiết)
SET FOREIGN_KEY_CHECKS = 0;
-- ... chạy script ...
SET FOREIGN_KEY_CHECKS = 1;
```

---

### ❌ Lỗi 4: `ERROR 1305 - FUNCTION HRPayrollDB.fn_TinhThueTNCN_Scalar does not exist`

**Nguyên nhân:** Chạy `sp_TinhLuong` trước khi tạo Functions.

**Giải pháp:** Chạy đúng thứ tự — Functions phải trước Stored Procedures.

```sql
-- Kiểm tra Functions đã tạo chưa
SELECT ROUTINE_NAME
FROM INFORMATION_SCHEMA.ROUTINES
WHERE ROUTINE_SCHEMA = 'HRPayrollDB'
  AND ROUTINE_TYPE = 'FUNCTION'
ORDER BY ROUTINE_NAME;
```

---

### ❌ Lỗi 5: `Duplicate entry` khi chạy seed_data.sql lần 2

**Nguyên nhân:** Dữ liệu cũ vẫn còn, TRUNCATE TABLE không chạy được do FK.

**Giải pháp:**
```sql
-- Tắt FK tạm thời, xóa data cũ
SET FOREIGN_KEY_CHECKS = 0;

TRUNCATE TABLE ChiTietLuong;
TRUNCATE TABLE KhauTru;
TRUNCATE TABLE BangLuong;
TRUNCATE TABLE AuditLog_Luong;
TRUNCATE TABLE AuditLog_HopDong;
TRUNCATE TABLE ChamCong;
TRUNCATE TABLE NhanVienPhucLoi;
TRUNCATE TABLE NghiPhep;
TRUNCATE TABLE LuongCoBan;
TRUNCATE TABLE HopDong;
UPDATE PhongBan SET MaTruongPhong = NULL;
TRUNCATE TABLE NhanVien;
TRUNCATE TABLE PhongBan;
TRUNCATE TABLE ChucVu;
TRUNCATE TABLE LoaiHopDong;
TRUNCATE TABLE LoaiNghiPhep;
TRUNCATE TABLE LoaiPhucLoi;

SET FOREIGN_KEY_CHECKS = 1;

-- Sau đó chạy lại seed_data.sql
```

---

### ❌ Lỗi 6: `ERROR - Bang luong da CHOT`

**Nguyên nhân:** Đã xác nhận bảng lương (Confirmed/Paid) rồi thử tính lại.

**Giải pháp:**
```sql
-- Tính lại với p_Override = 1 (chỉ ghi đè bản Draft)
CALL sp_TinhLuong(1, 2025, NULL, 1, 0);
-- Nếu đã Confirmed/Paid thì không thể tính lại (đúng thiết kế bảo vệ)
```

---

### ❌ Lỗi 7: Test cases FAIL sau khi chạy testcase

**Nguyên nhân:** Chưa chạy `sp_TinhLuong` cho 3 kỳ trước khi test.

**Giải pháp:**
```sql
-- Đảm bảo đã tính lương 3 tháng
CALL sp_TinhLuong(1, 2025, NULL, 0, 0);
CALL sp_TinhLuong(2, 2025, NULL, 0, 0);
CALL sp_TinhLuong(3, 2025, NULL, 0, 0);
-- Rồi mới chạy testcase
```

---

### ❌ Lỗi 8: DELIMITER không được nhận trong MySQL Workbench

**Nguyên nhân:** Copy/paste thủ công bị mất context DELIMITER.

**Giải pháp:**
```
Trong MySQL Workbench:
- Đi tới Edit > Preferences > SQL Editor
- Tắt "Safe Updates" (bỏ chọn)
- Dùng File > Run SQL Script để chạy file .sql (thay vì copy/paste)
- Không nên copy/paste nguyên khối lớn qua nhiều DELIMITER
```

---

## 7. Checklist Hoàn Thành

Sau khi chạy xong, kiểm tra bằng lệnh sau:

```sql
-- CHẠY LỆNH NÀY ĐỂ XEM TỔNG KẾT
USE HRPayrollDB;

SELECT 'Tables' AS ObjectType,
    COUNT(*) AS Actual,
    15 AS Expected,
    IF(COUNT(*) >= 15, 'OK', 'THIEU') AS Status
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'HRPayrollDB' AND TABLE_TYPE = 'BASE TABLE'

UNION ALL

SELECT 'Views',
    COUNT(*), 3, IF(COUNT(*) >= 3, 'OK', 'THIEU')
FROM INFORMATION_SCHEMA.VIEWS
WHERE TABLE_SCHEMA = 'HRPayrollDB'

UNION ALL

SELECT 'Stored Procedures',
    COUNT(*), 16, IF(COUNT(*) >= 16, 'OK', 'THIEU')
FROM INFORMATION_SCHEMA.ROUTINES
WHERE ROUTINE_SCHEMA = 'HRPayrollDB' AND ROUTINE_TYPE = 'PROCEDURE'

UNION ALL

SELECT 'Functions',
    COUNT(*), 3, IF(COUNT(*) >= 3, 'OK', 'THIEU')
FROM INFORMATION_SCHEMA.ROUTINES
WHERE ROUTINE_SCHEMA = 'HRPayrollDB' AND ROUTINE_TYPE = 'FUNCTION'

UNION ALL

SELECT 'Triggers',
    COUNT(*), 10, IF(COUNT(*) >= 10, 'OK', 'THIEU')
FROM INFORMATION_SCHEMA.TRIGGERS
WHERE TRIGGER_SCHEMA = 'HRPayrollDB';

-- Kiểm tra dữ liệu
SELECT 'NhanVien'  AS Bang, COUNT(*) AS SoLuong, IF(COUNT(*) = 50,   'OK', 'KIEM TRA') AS Status FROM NhanVien   UNION ALL
SELECT 'HopDong',            COUNT(*),            IF(COUNT(*) >= 50,  'OK', 'KIEM TRA')            FROM HopDong   UNION ALL
SELECT 'ChamCong',           COUNT(*),            IF(COUNT(*) >= 3000,'OK', 'KIEM TRA')            FROM ChamCong  UNION ALL
SELECT 'BangLuong_2025',     COUNT(*),            IF(COUNT(*) >= 150, 'OK', 'KIEM TRA')            FROM BangLuong WHERE Nam = 2025;
```

| Hạng mục | Mong đợi | Câu lệnh kiểm tra |
|---|---|---|
| Tables | ≥ 15 | `SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA='HRPayrollDB' AND TABLE_TYPE='BASE TABLE'` |
| Views | ≥ 3 | `SELECT COUNT(*) FROM INFORMATION_SCHEMA.VIEWS WHERE TABLE_SCHEMA='HRPayrollDB'` |
| Stored Procedures | ≥ 16 | `SELECT COUNT(*) FROM INFORMATION_SCHEMA.ROUTINES WHERE ROUTINE_SCHEMA='HRPayrollDB' AND ROUTINE_TYPE='PROCEDURE'` |
| Functions | ≥ 3 | `SELECT COUNT(*) FROM INFORMATION_SCHEMA.ROUTINES WHERE ROUTINE_SCHEMA='HRPayrollDB' AND ROUTINE_TYPE='FUNCTION'` |
| Triggers | ≥ 10 | `SELECT COUNT(*) FROM INFORMATION_SCHEMA.TRIGGERS WHERE TRIGGER_SCHEMA='HRPayrollDB'` |
| NhanVien | 50 | `SELECT COUNT(*) FROM NhanVien` |
| ChamCong | ≥ 3000 | `SELECT COUNT(*) FROM ChamCong` |
| BangLuong 2025 | ≥ 150 | `SELECT COUNT(*) FROM BangLuong WHERE Nam=2025` |
| Test PASS | 177/177 | Chạy cả 2 file testcase |

---

## 8. Ghi Chú Quan Trọng

> 🔤 **Character Set:** Database HRPayrollDB được tạo với `utf8mb4` + `utf8mb4_unicode_ci` — đảm bảo lưu trữ tiếng Việt chuẩn, kể cả emoji và ký tự đặc biệt. **Không cần** dùng prefix `N''` trước chuỗi như trong SQL Server.

> 🛠️ **DELIMITER:** Khi tạo Functions, Stored Procedures, Triggers trong MySQL **bắt buộc** phải đổi DELIMITER trước và sau khối lệnh. Các file SQL đã có sẵn `DELIMITER $$` ... `DELIMITER ;` ở đầu và cuối.

> 📊 **MySQL Workbench:** Vào **Edit → Preferences → SQL Editor** → tắt **"Safe Updates"** để cho phép UPDATE/DELETE không có WHERE trên khóa chính. Dùng **File → Run SQL Script** để chạy file thay vì copy/paste.

> 🔑 **Quyền hạn:** Tài khoản MySQL cần quyền `ALL PRIVILEGES` hoặc tối thiểu: `CREATE`, `DROP`, `ALTER`, `INSERT`, `UPDATE`, `DELETE`, `EXECUTE`, `TRIGGER`, `CREATE ROUTINE`, `ALTER ROUTINE`, `SUPER` (cho `SET GLOBAL`).

> 🔄 **Khác biệt MySQL vs SQL Server** (đã xử lý trong dự án):
>
> | SQL Server | MySQL 8.0+ |
> |---|---|
> | `EXEC sp_...` | `CALL sp_...()` |
> | `sys.tables`, `sys.procedures` | `INFORMATION_SCHEMA.TABLES`, `INFORMATION_SCHEMA.ROUTINES` |
> | `INSERTED` / `DELETED` | `NEW` / `OLD` |
> | `RAISERROR` | `SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '...'` |
> | `ISNULL()` | `IFNULL()` |
> | `GETDATE()` | `NOW()` hoặc `CURDATE()` |
> | `DATEADD(MONTH, n, date)` | `DATE_ADD(date, INTERVAL n MONTH)` |
> | `DATEDIFF(MONTH, d1, d2)` | `TIMESTAMPDIFF(MONTH, d1, d2)` |
> | `FORMAT(n, 'N0')` | `FORMAT(n, 0)` |
> | `TOP n` | `LIMIT n` |
> | `dbo.TableName` | `TableName` (không dùng prefix schema) |
> | `GO` | không dùng (chỉ dùng `;`) |
> | `BEGIN TRANSACTION` | `START TRANSACTION` |
> | `PRINT 'msg'` | `SELECT 'msg' AS Info` |
> | `N'chuỗi tiếng Việt'` | `'chuỗi tiếng Việt'` |
> | `EOMONTH(date)` | `LAST_DAY(date)` |
> | `CONVERT(NVARCHAR, date, 103)` | `DATE_FORMAT(date, '%d/%m/%Y')` |
> | `NVARCHAR` | `VARCHAR` với `utf8mb4` |

---

*Hướng dẫn được cập nhật cho dự án **HRPayrollSystem** — Môn Hệ Quản Trị Cơ Sở Dữ Liệu — DL2301CLCA*
*DBMS: MySQL 8.0+ | Tổng: 13 files SQL | 11,000+ dòng SQL | 177 test cases*
