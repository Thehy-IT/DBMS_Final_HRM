# 🏢 HRPayrollSystem — Hướng Dẫn Chạy End-to-End

> **Đề tài:** Hệ Thống Quản Lý Nhân Sự & Tính Lương Tự Động  
> **DBMS:** Microsoft SQL Server 2019+  
> **Thời gian setup:** ~30 phút | **Thời gian chạy demo:** ~10 phút

---

## 📋 Mục Lục

1. [Yêu cầu môi trường](#1-yêu-cầu-môi-trường)
2. [Cấu trúc thư mục dự án](#2-cấu-trúc-thư-mục-dự-án)
3. [BƯỚC 0 — Chuẩn bị môi trường](#bước-0--chuẩn-bị-môi-trường)
4. [BƯỚC 1 — Xem phân tích & ERD](#bước-1--xem-phân-tích--erd)
5. [BƯỚC 2 — Tạo Database & Cấu trúc DDL](#bước-2--tạo-database--cấu-trúc-ddl)
6. [BƯỚC 3 — Tạo Functions](#bước-3--tạo-functions)
7. [BƯỚC 4 — Tạo Triggers](#bước-4--tạo-triggers)
8. [BƯỚC 5 — Tạo Stored Procedures](#bước-5--tạo-stored-procedures)
9. [BƯỚC 6 — Tạo Views](#bước-6--tạo-views)
10. [BƯỚC 7 — Nhập dữ liệu mẫu (Seed Data)](#bước-7--nhập-dữ-liệu-mẫu-seed-data)
11. [BƯỚC 8 — Demo tính lương tự động](#bước-8--demo-tính-lương-tự-động)
12. [BƯỚC 9 — Kiểm thử toàn diện](#bước-9--kiểm-thử-toàn-diện)
13. [BƯỚC 10 — Chạy báo cáo](#bước-10--chạy-báo-cáo)
14. [Thứ tự chạy chuẩn (Quick Reference)](#thứ-tự-chạy-chuẩn-quick-reference)
15. [Lệnh Demo cho Giảng Viên](#lệnh-demo-cho-giảng-viên)
16. [Xử lý lỗi thường gặp](#xử-lý-lỗi-thường-gặp)
17. [Checklist hoàn thành](#checklist-hoàn-thành)

---

## 1. Yêu Cầu Môi Trường

### 1.1 Phần mềm bắt buộc

| Phần mềm | Phiên bản | Link tải | Ghi chú |
|---|---|---|---|
| **SQL Server** | 2019+ (Developer/Standard) | [microsoft.com/sql-server](https://www.microsoft.com/en-us/sql-server/sql-server-downloads) | Chọn Developer Edition (miễn phí) |
| **SSMS** | 19.0+ | [aka.ms/ssmsfullsetup](https://aka.ms/ssmsfullsetup) | SQL Server Management Studio |
| **draw.io Desktop** | Bất kỳ | [diagrams.net](https://get.diagrams.net) | Xem file ERD (hoặc dùng browser) |

### 1.2 Phần mềm tuỳ chọn

| Phần mềm | Mục đích |
|---|---|
| Python 3.x | Cross-check kết quả tính thuế |
| VS Code + SQL Server Extension | Editor thay thế SSMS |
| Git | Quản lý version |

### 1.3 Cấu hình SQL Server tối thiểu

```
RAM   : 4 GB (khuyến nghị 8 GB)
CPU   : 2 cores
Disk  : 5 GB trống
OS    : Windows 10/11 hoặc Windows Server 2019
Port  : 1433 (mặc định SQL Server)
```

### 1.4 Thiết lập SQL Server Authentication

M�� **SQL Server Configuration Manager** → Đảm bảo:
- SQL Server Browser: **Running**
- TCP/IP: **Enabled** (nếu kết nối remote)
- Authentication Mode: **SQL Server and Windows Authentication Mode**

---

## 2. Cấu Trúc Thư Mục Dự Án

```
HRPayrollSystem/
│
├── 📁 01_Analysis/
│   ├── requirements.md          ← Nghiệp vụ, Use Case, Business Rules
│   └── ERD_diagram.drawio       ← Sơ đồ ERD 15 thực thể
│
├── 📁 02_Database/
│   ├── 📁 DDL/
│   │   ├── 01_create_tables.sql ← [1] Tạo 15 bảng + xử lý vòng FK
│   │   ├── 02_constraints.sql   ← [2] 36 constraints bổ sung
│   │   └── 03_indexes.sql       ← [3] 24 index + 2 Columnstore
│   │
│   ├── 📁 DML/
│   │   ├── seed_data.sql        ← [8] 50 NV + 3 tháng CC + dữ liệu mẫu
│   │   └── test_queries.sql     ← [10] 71 test cases tổng thể
│   │
│   ├── 📁 Functions/
│   │   ├── fn_TinhThueTNCN.sql  ← [4a] Thuế TNCN 7 bậc + TVF + BacThue
│   │   ├── fn_TinhBHXH.sql      ← [4b] BH NLĐ 10.5% + NSDLĐ 22%
│   │   └── fn_SoNgayLamViec.sql ← [4c] Ngày công, hệ số lương, OT
│   │
│   ├── 📁 Triggers/
│   │   ├── trg_LogHopDong.sql       ← [5a] Audit HĐ + GuardChot
│   │   ├── trg_LogLuong.sql         ← [5b] Audit lương + BL GuardChot
│   │   └── trg_KiemTraChamCong.sql  ← [5c] Validate CC + AuditLog + Sync
│   │
│   ├── 📁 StoredProcedures/
│   │   ├── sp_TinhLuong.sql     ← [6a] Core: pipeline 8 bước tính lương
│   │   ├── sp_ChamCong.sql      ← [6b] Nhập CC, nghỉ phép, báo cáo CC
│   │   ├── sp_TaoBangLuong.sql  ← [6c] Bảng lương, BHXH, thuế, CPNS
│   │   └── sp_BaoCaoNhanSu.sql  ← [6d] Dashboard, HĐ, lương, phép năm
│   │
│   └── 📁 Views/
│       ├── vw_BangLuong.sql         ← [7a] Lương chi tiết + TongHop + Thuế
│       └── vw_TongHopChamCong.sql   ← [7b] CC tháng + ChiTiet + TyLeCC
│
├── 📁 03_App/                   ← (Tùy chọn: UI C#/Python/Web)
│   ├── connection.config
│   ├── screens/
│   └── reports/
│
├── 📁 04_Testing/
│   ├── testcase_luong.sql       ← [9a] 102 tests: thuế, BH, sp_TinhLuong
│   └── testcase_chamcong.sql    ← [9b] 75 tests: trigger, SP CC, views
│
└── 📁 05_Docs/
    ├── BaoCaoDoAn.docx
    ├── UserManual.pdf
    └── Slides_BaoCao.pptx
```

> ⚠️ **Quan trọng:** Số `[N]` là thứ tự chạy bắt buộc. Không được đổi thứ tự vì có dependency giữa các file.

---

## BƯỚC 0 — Chuẩn Bị Môi Trường

### 0.1 Mở SQL Server Management Studio (SSMS)

1. Nhấn **Windows** → Tìm **SSMS** → Mở
2. Hộp thoại Connect:
   ```
   Server type   : Database Engine
   Server name   : localhost  (hoặc .\SQLEXPRESS nếu dùng Express)
   Authentication: Windows Authentication
   ```
3. Nhấn **Connect** → Xác nhận kết nối thành công (thấy cây Object Explorer bên trái)

### 0.2 Kiểm tra phiên bản SQL Server

```sql
-- Chạy trong SSMS để kiểm tra phiên bản
SELECT @@VERSION;
-- Kết quả mong đợi: Microsoft SQL Server 2019 (RTM...) ...
```

### 0.3 Thiết lập giao diện SSMS

- **Tools → Options → Text Editor → Transact-SQL** → Bật Line Numbers
- **Query → SQLCMD Mode**: Tắt (trừ khi dùng lệnh SQLCMD)
- Kéo cửa sổ **Messages** tab để thấy PRINT output khi chạy

---

## BƯỚC 1 — Xem Phân Tích & ERD

### 1.1 Đọc tài liệu yêu cầu

```
M�� file: 01_Analysis/requirements.md
```

Tài liệu này định nghĩa:
- **15 thực thể** → trực tiếp thành 15 bảng SQL
- **14 Business Rules (BR-01 → BR-14)** → thành CHECK constraints và Triggers
- **Công thức tính lương** → thành logic trong sp_TinhLuong
- **Biểu thuế 7 bậc** → thành fn_TinhThueTNCN
- **3 Actor + 9 Use Case** → phân quyền hệ thống

### 1.2 Xem ERD Diagram

**Cách 1 — draw.io Desktop (khuyến nghị):**
```
1. Mở draw.io Desktop
2. File → Open → chọn 01_Analysis/ERD_diagram.drawio
3. Ctrl+Shift+H để fit toàn màn hình
```

**Cách 2 — Trình duyệt:**
```
1. Mở https://app.diagrams.net
2. File → Open from → Device
3. Chọn ERD_diagram.drawio
```

**Chú thích màu sắc ERD:**
| Màu | Loại bảng |
|---|---|
| 🔵 Xanh dương | NhanVien (trung tâm) |
| 🟢 Xanh lá | Danh mục Lookup (PhongBan, ChucVu...) |
| 🟡 Vàng | Nghiệp vụ Transaction (HopDong, BangLuong...) |
| 🟣 Tím | Junction table (NhanVienPhucLoi) |
| 🔴 Đỏ nhạt | Audit Log (AuditLog_HopDong, AuditLog_Luong) |

---

## BƯỚC 2 — Tạo Database & Cấu Trúc DDL

> ⚙️ **Thứ tự file:** `01_create_tables.sql` → `02_constraints.sql` → `03_indexes.sql`

### 2.1 Chạy file 01_create_tables.sql

```
1. SSMS → File → Open → 02_Database/DDL/01_create_tables.sql
2. Kiểm tra đầu file: USE master; (không phải USE HRPayrollDB)
3. Nhấn F5 hoặc nút Execute
```

**Kết quả mong đợi (tab Messages):**
```
Đã xoá database cũ HRPayrollDB.      ← (chỉ hiện nếu đã tồn tại)
[OK] Tạo bảng PhongBan
[OK] Tạo bảng ChucVu
...
[OK] ALTER TABLE PhongBan ADD FK MaTruongPhong  ← giải quyết vòng FK
════════════════════════════════════════════════
 HRPayrollDB — 15 bảng tạo thành công!
```

**Kiểm tra nhanh:**
```sql
USE HRPayrollDB;
SELECT COUNT(*) AS SoBang FROM sys.tables WHERE is_ms_shipped = 0;
-- Kết quả: 15
```

> ⚠️ **Lưu ý:** File này DROP và tạo lại database HRPayrollDB. Nếu muốn giữ data cũ, **không chạy lại** file này.

### 2.2 Chạy file 02_constraints.sql

```
File → Open → 02_Database/DDL/02_constraints.sql → F5
```

**Kết quả mong đợi:**
```
[OK] §1.1 UIX_HopDong_OneActive_PerNV
[OK] §1.2 UIX_LuongCoBan_OneCurrent_PerNV
...
[OK] §5.8 IX_AuditLuong_NV_ThangNam
[DONE] 02_constraints.sql hoàn tất.
```

**Kiểm tra:**
```sql
-- Đếm tổng constraints
SELECT type_desc, COUNT(*) n FROM sys.check_constraints
WHERE OBJECTPROPERTY(parent_object_id,'IsUserTable')=1
GROUP BY type_desc;
-- Kết quả: CHECK ~24 dòng
```

### 2.3 Chạy file 03_indexes.sql

```
File → Open → 02_Database/DDL/03_indexes.sql → F5
```

**Kết quả mong đợi:**
```
[OK] §1.1 IX_NhanVien_TinhLuong_Active
[OK] §1.2 IX_LuongCoBan_TinhLuong_Lookup
...
[OK] §5.2 NCIX_CS_ChamCong_Analytics
[DONE] 03_indexes.sql hoàn tất.
```

**Kiểm tra:**
```sql
SELECT COUNT(*) AS SoIndex FROM sys.indexes
WHERE OBJECTPROPERTY(object_id,'IsUserTable')=1 AND type > 0;
-- Kết quả: ~50 indexes
```

---

## BƯỚC 3 — Tạo Functions

> ⚙️ **Thứ tự:** `fn_TinhThueTNCN.sql` → `fn_TinhBHXH.sql` → `fn_SoNgayLamViec.sql`

### 3.1 Chạy fn_TinhThueTNCN.sql

```
File → Open → 02_Database/Functions/fn_TinhThueTNCN.sql → F5
```

**Kết quả:**
```
[OK] fn_TinhThueTNCN_Scalar — tạo thành công
[OK] fn_TinhThueTNCN_ChiTiet (TVF) — tạo thành công
[OK] fn_XacDinhBacThue — tạo thành công
[OK] fn_TinhGiamTruPhuThuoc — tạo thành công
```

**Tự test ngay:**
```sql
-- Test biểu thuế: TNCT = 15 triệu → phải ra 1,500,000
SELECT dbo.fn_TinhThueTNCN_Scalar(15000000) AS Thue;
-- Kết quả: 1500000 ✅

-- Test bậc thuế: 40 triệu → bậc 5
SELECT dbo.fn_XacDinhBacThue(40000000) AS Bac;
-- Kết quả: 5 ✅

-- Test giảm trừ 2 người phụ thuộc
SELECT dbo.fn_TinhGiamTruPhuThuoc(2) AS GiamTru;
-- Kết quả: 8800000 ✅
```

### 3.2 Chạy fn_TinhBHXH.sql

```
File → Open → 02_Database/Functions/fn_TinhBHXH.sql → F5
```

**Kết quả:**
```
[OK] fn_TinhLuongDongBH — tạo thành công
[OK] fn_TinhBHXH_TVF — tạo thành công
[OK] fn_TinhBH_NLD — tạo thành công
[OK] fn_TinhBH_NSDLD — tạo thành công
```

**Tự test:**
```sql
-- Lương 10 triệu: BH NLĐ = 10% + 1.5% + 1% = 10.5%
SELECT dbo.fn_TinhBH_NLD(10000000, 2) AS BH_NLD;
-- Kết quả: 1050000 ✅

-- Lương 55 triệu vượt trần 46.8M: LuongDongBH = 46,800,000
SELECT dbo.fn_TinhLuongDongBH(55000000, 4) AS LuongDongBH;
-- Kết quả: 46800000 ✅

-- Thử việc: BH = 0
SELECT dbo.fn_TinhBH_NLD(6500000, 1) AS BH_ThuViec;
-- Kết quả: 0 ✅
```

### 3.3 Chạy fn_SoNgayLamViec.sql

```
File → Open → 02_Database/Functions/fn_SoNgayLamViec.sql → F5
```

**Kết quả:**
```
[OK] fn_SoNgayChuanThang — tạo thành công
[OK] fn_SoNgayChamCong — tạo thành công
[OK] fn_SoNgayNghiCoLuong — tạo thành công
[OK] fn_SoNgayNghiKhongLuong — tạo thành công
[OK] fn_HeSoLuongThang — tạo thành công
[OK] fn_TinhLuongLamThem — tạo thành công
```

**Tự test:**
```sql
-- Số ngày chuẩn tháng 3/2025 (không lễ)
SELECT dbo.fn_SoNgayChuanThang(3, 2025) AS NgayChuan;
-- Kết quả: 20-22 ✅
```

**Kiểm tra tổng:**
```sql
SELECT COUNT(*) AS SoFunctions FROM sys.objects
WHERE type IN ('FN','TF') AND is_ms_shipped = 0;
-- Kết quả: 13 ✅
```

---

## BƯỚC 4 — Tạo Triggers

> ⚙️ **Thứ tự:** `trg_LogHopDong.sql` → `trg_LogLuong.sql` → `trg_KiemTraChamCong.sql`

### 4.1 Chạy trg_LogHopDong.sql

```
File → Open → 02_Database/Triggers/trg_LogHopDong.sql → F5
```

**Kết quả:**
```
[OK] trg_HopDong_AfterInsert
[OK] trg_HopDong_AfterUpdate
[OK] trg_HopDong_AfterDelete
[OK] trg_HopDong_GuardChot
```

### 4.2 Chạy trg_LogLuong.sql

```
File → Open → 02_Database/Triggers/trg_LogLuong.sql → F5
```

**Kết quả:**
```
[OK] trg_LuongCoBan_AfterInsert
[OK] trg_LuongCoBan_AfterUpdate
[OK] trg_BangLuong_GuardChot
[OK] trg_KiemTraChamCong   ← Phiên bản cơ bản (sẽ được thay thế)
```

### 4.3 Chạy trg_KiemTraChamCong.sql

> ⚠️ **File này DROP trigger cũ** `trg_KiemTraChamCong` từ bước 4.2 và tạo lại phiên bản đầy đủ hơn.

```
File → Open → 02_Database/Triggers/trg_KiemTraChamCong.sql → F5
```

**Kết quả:**
```
[INFO] Đã xoá trigger cũ trg_KiemTraChamCong từ trg_LogLuong.sql
[OK] Tạo bảng AuditLog_ChamCong + index
[OK] trg_ChamCong_Validate (7 validations)
[OK] trg_ChamCong_TinhSoGio (auto-calc SoGioLam + HeSoTangCa)
[OK] trg_ChamCong_GuardChot
[OK] trg_ChamCong_AuditLog
[OK] trg_NghiPhep_SyncChamCong
[OK] Trigger firing order đã được cấu hình
```

**Kiểm tra tổng:**
```sql
SELECT COUNT(*) AS SoTrigger FROM sys.triggers
WHERE parent_id > 0;
-- Kết quả: 12 ✅
```

---

## BƯỚC 5 — Tạo Stored Procedures

> ⚙️ **Thứ tự:** `sp_TinhLuong.sql` → `sp_ChamCong.sql` → `sp_TaoBangLuong.sql` → `sp_BaoCaoNhanSu.sql`

### 5.1 Chạy sp_TinhLuong.sql

```
File → Open → 02_Database/StoredProcedures/sp_TinhLuong.sql → F5
```

**Kết quả:**
```
[OK] sp_TinhLuong — tạo thành công
[OK] sp_XacNhanBangLuong — tạo thành công
```

### 5.2 Chạy sp_ChamCong.sql

```
File → Open → 02_Database/StoredProcedures/sp_ChamCong.sql → F5
```

**Kết quả:**
```
[OK] sp_ChamCong_NhapHangNgay
[OK] sp_ChamCong_NhapLoat
[OK] sp_ChamCong_CapNhat
[OK] sp_ChamCong_DongBoNghiPhep
[OK] sp_NghiPhep_PheDuyet
[OK] sp_ChamCong_BaoCaoThang
```

### 5.3 Chạy sp_TaoBangLuong.sql

```
File → Open → 02_Database/StoredProcedures/sp_TaoBangLuong.sql → F5
```

**Kết quả:**
```
[OK] sp_TaoBangLuong_ChinhThuc
[OK] sp_TaoBangLuong_PhieuLuong
[OK] sp_TaoBangLuong_BHXH
[OK] sp_TaoBangLuong_QuyetToanThue
[OK] sp_TaoBangLuong_SoSanh
[OK] sp_TaoBangLuong_ChiPhiNhanSu
```

### 5.4 Chạy sp_BaoCaoNhanSu.sql

```
File → Open → 02_Database/StoredProcedures/sp_BaoCaoNhanSu.sql → F5
```

**Kết quả:**
```
[OK] sp_BaoCaoNhanSu_TongQuan
[OK] sp_BaoCaoNhanSu_TheoPhongBan
[OK] sp_BaoCaoNhanSu_HopDong
[OK] sp_BaoCaoNhanSu_BienDong
[OK] sp_BaoCaoNhanSu_LuongPhanPhoi
[OK] sp_BaoCaoNhanSu_NghiPhepNam
```

**Kiểm tra tổng:**
```sql
SELECT COUNT(*) AS SoSP FROM sys.procedures WHERE is_ms_shipped = 0;
-- Kết quả: 20 ✅
```

---

## BƯỚC 6 — Tạo Views

> ⚙️ **Thứ tự:** `vw_BangLuong.sql` → `vw_TongHopChamCong.sql`

### 6.1 Chạy vw_BangLuong.sql

```
File → Open → 02_Database/Views/vw_BangLuong.sql → F5
```

**Kết quả:**
```
[OK] vw_BangLuong
[OK] vw_BangLuong_TongHop
[OK] vw_ThueTNCN_KyQuyetToan
```

### 6.2 Chạy vw_TongHopChamCong.sql

```
File → Open → 02_Database/Views/vw_TongHopChamCong.sql → F5
```

**Kết quả:**
```
[OK] vw_TongHopChamCong
[OK] vw_ChamCong_ChiTiet
[OK] vw_TyLeChuyenCan
```

**Kiểm tra tổng:**
```sql
SELECT COUNT(*) AS SoViews FROM sys.views WHERE is_ms_shipped = 0;
-- Kết quả: 6 ✅
```

---

## BƯỚC 7 — Nhập Dữ Liệu Mẫu (Seed Data)

```
File → Open → 02_Database/DML/seed_data.sql → F5
```

> ⏱️ **Thời gian:** ~15–30 giây (file tạo ~3.100 bản ghi ChamCong bằng set-based INSERT)

**Kết quả mong đợi:**
```
[OK] §1.1 PhongBan — 5 phòng ban
[OK] §1.2 ChucVu — 7 chức vụ
[OK] §1.3 LoaiHopDong — 4 loại
[OK] §1.4 LoaiNghiPhep — 5 loại
[OK] §1.5 LoaiPhucLoi — 6 loại phúc lợi
[OK] §2 NhanVien — 50 nhân viên
[OK] §3 HopDong — 50 hợp đồng
[OK] §4 LuongCoBan — 50 mức lương
[OK] §5 NhanVienPhucLoi — phúc lợi đã gán
[OK] §6 ChamCong — 3 tháng Jan-Mar 2025 hoàn tất
[OK] §7 NghiPhep — 11 đơn nghỉ phép
[OK] §8 KhauTru — 7 khoản khấu trừ
[OK] §9.1 Trưởng phòng đã được gán
```

**Kiểm tra nhanh sau seed:**
```sql
USE HRPayrollDB;

-- Kiểm tra bảng chính
SELECT 'NhanVien'      AS Bang, COUNT(*) N FROM dbo.NhanVien
UNION ALL
SELECT 'HopDong',       COUNT(*) FROM dbo.HopDong
UNION ALL
SELECT 'LuongCoBan',    COUNT(*) FROM dbo.LuongCoBan
UNION ALL
SELECT 'ChamCong',      COUNT(*) FROM dbo.ChamCong
UNION ALL
SELECT 'NghiPhep',      COUNT(*) FROM dbo.NghiPhep;

-- Kết quả mong đợi:
-- NhanVien   50
-- HopDong    50
-- LuongCoBan 50
-- ChamCong   ~3100+
-- NghiPhep   11
```

---

## BƯỚC 8 — Demo Tính Lương Tự Động

> 🎯 **Đây là bước quan trọng nhất — chạy 1 lệnh ra toàn bộ bảng lương 50 NV**

### 8.1 Tính lương tháng 1/2025

```sql
-- Tính lương tháng 1/2025 cho tất cả nhân viên
EXEC dbo.sp_TinhLuong 1, 2025;
```

**Kết quả tab Messages:**
```
════════════════════════════════════════════════════════
  sp_TinhLuong — Kỳ 1/2025
  Ngày chuẩn tháng: 17 ngày
════════════════════════════════════════════════════════
  ✅ NV000001 | Nguyễn Hoàng Minh        | Gross: 57,230,000 | BH: 4,914,000 | Thuế: 4,407,000 | NET: 47,909,000
  ✅ NV000002 | Trần Thị Lan Anh          | Gross:  9,230,000 | BH:   892,500 | Thuế:         0 | NET:  8,337,500
  ... (48 nhân viên tiếp theo)
════════════════════════════════════════════════════════
  KẾT QUẢ sp_TinhLuong T1/2025
  Tổng NV xử lý  : 50
  Thành công      : 50
  Lỗi / Bỏ qua   : 0
  Tổng lương NET  : XXX,XXX,XXX VNĐ
  Thời gian chạy  : XXX ms
════════════════════════════════════════════════════════
```

### 8.2 Tính lương tháng 2 và 3/2025

```sql
EXEC dbo.sp_TinhLuong 2, 2025;
EXEC dbo.sp_TinhLuong 3, 2025;
```

### 8.3 Thử DryRun (không ghi vào DB)

```sql
-- Xem trước kết quả tháng 4 mà không ghi DB
EXEC dbo.sp_TinhLuong 4, 2025, NULL, 0, 1;  -- @DryRun = 1
```

### 8.4 Xem bảng lương vừa tạo

```sql
-- Xem top 10 lương cao nhất tháng 3/2025
SELECT TOP 10
    nv.HoTen,
    pb.TenPB                    AS PhongBan,
    cv.TenCV                    AS ChucVu,
    FORMAT(bl.LuongGross,'N0')  AS Gross,
    FORMAT(bl.TongBaoHiem,'N0') AS BaoHiem,
    FORMAT(bl.ThueTNCN,'N0')    AS ThueTNCN,
    FORMAT(bl.LuongNet,'N0')    AS ThucLinh,
    bl.TrangThai
FROM dbo.BangLuong bl
JOIN dbo.NhanVien  nv ON bl.MaNV = nv.MaNV
JOIN dbo.PhongBan  pb ON nv.MaPB = pb.MaPB
JOIN dbo.ChucVu    cv ON nv.MaCV = cv.MaCV
WHERE bl.Thang = 3 AND bl.Nam = 2025
ORDER BY bl.LuongNet DESC;
```

### 8.5 Xem chi tiết lương TGĐ (NV000001)

```sql
-- Chi tiết từng khoản lương TGĐ tháng 3/2025
SELECT LoaiMuc AS [+/-], TenMuc, FORMAT(GiaTri,'N0') AS SoTien, GhiChu
FROM dbo.ChiTietLuong
WHERE MaBL = (
    SELECT MaBL FROM dbo.BangLuong
    WHERE MaNV='NV000001' AND Thang=3 AND Nam=2025
)
ORDER BY CASE LoaiMuc WHEN '+' THEN 0 ELSE 1 END;
```

### 8.6 Workflow xác nhận bảng lương

```sql
-- HR xác nhận bảng lương tháng 1/2025: Draft → Confirmed
EXEC dbo.sp_XacNhanBangLuong 1, 2025, N'Hoàng Thị Phương';

-- Kiểm tra trạng thái
SELECT TrangThai, COUNT(*) AS SoNV
FROM dbo.BangLuong WHERE Thang=1 AND Nam=2025
GROUP BY TrangThai;
-- Kết quả: C | 50
```

---

## BƯỚC 9 — Kiểm Thử Toàn Diện

### 9.1 Chạy testcase_luong.sql (102 tests)

```
File → Open → 04_Testing/testcase_luong.sql → F5
```

**Theo dõi tab Messages:** Từng test in ra `PASS` hoặc `FAIL`.

**Kết quả cuối file (§19):**
```
════════════════════════════════════════════════════════
  KẾT QUẢ TỔNG KẾT — KIỂM THỬ MODULE LƯƠNG
════════════════════════════════════════════════════════
Phần    | Tổng | ✅ PASS | ❌ FAIL | Tỷ Lệ
§1      |  8   |  8     |  0     | 100%
§2      | 10   | 10     |  0     | 100%
...
TỔNG   | 102  | 102    |  0     | 100.0%
🎉 Tất cả test PASS — Module Lương hoạt động đúng!
```

### 9.2 Chạy testcase_chamcong.sql (75 tests)

```
File → Open → 04_Testing/testcase_chamcong.sql → F5
```

**Kết quả:**
```
TỔNG   | 75   | 75     |  0     | 100.0%
🎉 Tất cả test PASS — Module Chấm Công hoạt động đúng!
```

### 9.3 Chạy test_queries.sql (71 tests tổng thể)

```
File → Open → 02_Database/DML/test_queries.sql → F5
```

---

## BƯỚC 10 — Chạy Báo Cáo

### 10.1 Dashboard nhân sự tổng quan

```sql
EXEC dbo.sp_BaoCaoNhanSu_TongQuan;
-- 5 Result Sets: KPI, nhóm tuổi, thâm niên, phân bổ PB, Turnover Rate
```

### 10.2 Bảng lương chính thức

```sql
-- Bảng lương tổng hợp T3/2025 (2 Result Sets)
EXEC dbo.sp_TaoBangLuong_ChinhThuc @Thang=3, @Nam=2025;

-- Chỉ phòng CNTT
EXEC dbo.sp_TaoBangLuong_ChinhThuc @Thang=3, @Nam=2025, @MaPB='PB0004';
```

### 10.3 Phiếu lương cá nhân TGĐ

```sql
EXEC dbo.sp_TaoBangLuong_PhieuLuong
    @MaNV='NV000001', @Thang=3, @Nam=2025;
-- 4 Result Sets: thông tin NV, chi tiết dòng, tóm tắt, bậc thuế
```

### 10.4 Danh sách đóng BHXH (mẫu D02-TS)

```sql
EXEC dbo.sp_TaoBangLuong_BHXH @Thang=1, @Nam=2025;
-- Đủ 50 NV: NLĐ 10.5% + NSDLĐ 22% từng người
```

### 10.5 Quyết toán thuế TNCN

```sql
-- Theo tháng (mẫu 05/KK-TNCN)
EXEC dbo.sp_TaoBangLuong_QuyetToanThue @Thang=3, @Nam=2025, @LoaiBaoCao='T';

-- Lũy kế cả năm 2025
EXEC dbo.sp_TaoBangLuong_QuyetToanThue @Thang=3, @Nam=2025, @LoaiBaoCao='N';
```

### 10.6 Báo cáo chấm công

```sql
-- Báo cáo CC tháng 3/2025 (3 Result Sets)
EXEC dbo.sp_ChamCong_BaoCaoThang @Thang=3, @Nam=2025;

-- Chỉ NV có vắng không phép
EXEC dbo.sp_ChamCong_BaoCaoThang @Thang=3, @Nam=2025, @ChiInVangKP=1;
```

### 10.7 Phân phối lương & Gender Pay Gap

```sql
EXEC dbo.sp_BaoCaoNhanSu_LuongPhanPhoi @Thang=3, @Nam=2025;
-- 3 RS: xếp hạng + PERCENT_RANK, Gender Pay Gap %, P10/P25/P50/P75/P90
```

### 10.8 So sánh quỹ lương 3 tháng

```sql
EXEC dbo.sp_TaoBangLuong_SoSanh
    @TuThang=1, @TuNam=2025, @DenThang=3, @DenNam=2025;
-- Hiển thị biến động T1→T2→T3 theo phòng ban + cảnh báo ±20%
```

### 10.9 Xem Views tổng hợp

```sql
-- Xem tất cả qua vw_BangLuong
SELECT * FROM dbo.vw_BangLuong
WHERE Nam=2025 AND Thang=3
ORDER BY LuongThucLinh DESC;

-- Tỷ lệ chuyên cần theo phòng ban
SELECT * FROM dbo.vw_TyLeChuyenCan
WHERE Nam=2025
ORDER BY Nam, Thang, TyLeChuyenCanTB DESC;
```

### 10.10 Xem Audit Log

```sql
-- Xem lịch sử thay đổi hợp đồng
SELECT TOP 10 MaHD, MaNV, HanhDong, TenCot,
    GiaTriCu, GiaTriMoi,
    FORMAT(NgayThayDoi,'dd/MM/yyyy HH:mm') AS ThoiGian
FROM dbo.AuditLog_HopDong
ORDER BY MaLog DESC;

-- Xem lịch sử thay đổi lương
SELECT TOP 10 MaNV, HanhDong, TenCot, GiaTriCu, GiaTriMoi,
    FORMAT(NgayThayDoi,'dd/MM/yyyy HH:mm') AS ThoiGian
FROM dbo.AuditLog_Luong
ORDER BY MaLog DESC;
```

---

## Thứ Tự Chạy Chuẩn (Quick Reference)

```
📋 CHECKLIST CHẠY TUẦN TỰ
══════════════════════════════════════════════════════════

SETUP SCHEMA (Chạy 1 lần)
─────────────────────────
□ [1] DDL/01_create_tables.sql      ← Tạo 15 bảng
□ [2] DDL/02_constraints.sql        ← 36 constraints
□ [3] DDL/03_indexes.sql            ← 24+ indexes

LOGIC TẦNG FUNCTION (Không có dependency ngoài bảng)
─────────────────────────────────────────────────────
□ [4a] Functions/fn_TinhThueTNCN.sql
□ [4b] Functions/fn_TinhBHXH.sql
□ [4c] Functions/fn_SoNgayLamViec.sql

TRIGGERS (Phụ thuộc bảng)
─────────────────────────
□ [5a] Triggers/trg_LogHopDong.sql
□ [5b] Triggers/trg_LogLuong.sql
□ [5c] Triggers/trg_KiemTraChamCong.sql   ← DROP trigger cũ, tạo lại

STORED PROCEDURES (Phụ thuộc Functions)
────────────────────────────────────────
□ [6a] StoredProcedures/sp_TinhLuong.sql
□ [6b] StoredProcedures/sp_ChamCong.sql
□ [6c] StoredProcedures/sp_TaoBangLuong.sql
□ [6d] StoredProcedures/sp_BaoCaoNhanSu.sql

VIEWS (Phụ thuộc Functions + bảng)
────────────────────────────────────
□ [7a] Views/vw_BangLuong.sql
□ [7b] Views/vw_TongHopChamCong.sql

DỮ LIỆU MẪU (Phụ thuộc tất cả ở trên)
────────────────────────────────────────
□ [8]  DML/seed_data.sql             ← 50 NV + 3 tháng CC

DEMO TÍNH LƯƠNG
────────────────
□ EXEC sp_TinhLuong 1, 2025;
□ EXEC sp_TinhLuong 2, 2025;
□ EXEC sp_TinhLuong 3, 2025;
□ EXEC sp_XacNhanBangLuong 1, 2025;

KIỂM THỬ
────────
□ [9a] Testing/testcase_luong.sql    ← 102 tests
□ [9b] Testing/testcase_chamcong.sql ← 75 tests
□ [10] DML/test_queries.sql         ← 71 tests tổng thể

══════════════════════════════════════════════════════════
```

---

## Lệnh Demo Cho Giảng Viên

```sql
-- ═══════════════════════════════════════════════════════
-- DEMO SCRIPT — Chạy tuần tự trước giảng viên
-- ═══════════════════════════════════════════════════════

USE HRPayrollDB;

-- 1. Kiểm tra cấu trúc đã tạo đủ
SELECT 'Tables'     , COUNT(*) FROM sys.tables    WHERE is_ms_shipped=0 UNION ALL
SELECT 'Views'      , COUNT(*) FROM sys.views     WHERE is_ms_shipped=0 UNION ALL
SELECT 'Procedures' , COUNT(*) FROM sys.procedures WHERE is_ms_shipped=0 UNION ALL
SELECT 'Functions'  , COUNT(*) FROM sys.objects   WHERE type IN ('FN','TF') AND is_ms_shipped=0 UNION ALL
SELECT 'Triggers'   , COUNT(*) FROM sys.triggers  WHERE parent_id > 0;
-- Mong đợi: 15 / 6 / 20 / 13 / 12

-- 2. Demo tính lương 1 lệnh
EXEC dbo.sp_TinhLuong 3, 2025;

-- 3. Xem kết quả top lương
SELECT TOP 5 nv.HoTen, pb.TenPB,
    FORMAT(bl.LuongGross,'N0') Gross,
    FORMAT(bl.ThueTNCN,'N0') Thue,
    FORMAT(bl.LuongNet,'N0') Net
FROM dbo.BangLuong bl
JOIN dbo.NhanVien nv ON bl.MaNV=nv.MaNV
JOIN dbo.PhongBan pb ON nv.MaPB=pb.MaPB
WHERE bl.Thang=3 AND bl.Nam=2025
ORDER BY bl.LuongNet DESC;

-- 4. Demo trigger audit (thay đổi lương → log tự động)
UPDATE dbo.LuongCoBan
SET NgayHetHieuLuc = '2025-03-31'
WHERE MaNV='NV000003' AND NgayHetHieuLuc IS NULL;

INSERT INTO dbo.LuongCoBan (MaNV,LuongCB,LuongDongBH,NgayHieuLuc,LyDo,NguoiDuyet)
VALUES ('NV000003',28000000,28000000,'2025-04-01',N'Tăng lương KPI','NV000001');

-- Xem log tự động ghi
SELECT TOP 3 MaNV, HanhDong, TenCot, GiaTriCu, GiaTriMoi,
    FORMAT(NgayThayDoi,'HH:mm:ss') Gio
FROM dbo.AuditLog_Luong ORDER BY MaLog DESC;

-- 5. Demo trigger validate (chặn dữ liệu sai)
BEGIN TRY
    INSERT INTO dbo.ChamCong (MaNV,NgayCham,TrangThai,HeSoTangCa,NguoiCapNhat)
    VALUES ('NV000001', DATEADD(DAY,5,GETDATE()), 'DL', 1.5, 'TEST');
    PRINT 'Không bị chặn!'; -- Không bao giờ chạy đến đây
END TRY
BEGIN CATCH
    PRINT 'Trigger đã chặn: ' + ERROR_MESSAGE();
END CATCH;

-- 6. Dashboard nhân sự
EXEC dbo.sp_BaoCaoNhanSu_TongQuan;

-- 7. Danh sách BHXH
EXEC dbo.sp_TaoBangLuong_BHXH @Thang=3, @Nam=2025;
```

---

## Xử Lý Lỗi Thường Gặp

### ❌ Lỗi 1: "Cannot drop database 'HRPayrollDB' because it is currently in use"

**Nguyên nhân:** Có query window khác đang kết nối vào HRPayrollDB.

**Giải pháp:**
```sql
-- Chạy trong cửa sổ mới
ALTER DATABASE HRPayrollDB SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
DROP DATABASE HRPayrollDB;
-- Sau đó chạy lại 01_create_tables.sql
```

---

### ❌ Lỗi 2: "The object 'fn_SoNgayChuanThang' could not be found"

**Nguyên nhân:** Chạy sp_TinhLuong trước khi tạo Functions.

**Giải pháp:** Chạy đúng thứ tự — Functions phải trước Stored Procedures.

```sql
-- Kiểm tra Functions đã tạo chưa
SELECT name FROM sys.objects
WHERE type IN ('FN','TF') AND is_ms_shipped=0
ORDER BY name;
```

---

### ❌ Lỗi 3: "Violation of UNIQUE KEY constraint 'UIX_HopDong_OneActive_PerNV'"

**Nguyên nhân:** Chạy seed_data.sql 2 lần mà không chạy lại 01_create_tables.sql.

**Giải pháp:** Seed_data.sql có DELETE ở đầu, nhưng cần chạy đúng thứ tự:
```sql
-- Xóa data cũ thủ công nếu cần
DELETE FROM dbo.NhanVienPhucLoi;
DELETE FROM dbo.ChamCong;
DELETE FROM dbo.KhauTru;
DELETE FROM dbo.ChiTietLuong;
DELETE FROM dbo.BangLuong;
DELETE FROM dbo.AuditLog_Luong;
DELETE FROM dbo.AuditLog_HopDong;
DELETE FROM dbo.LuongCoBan;
DELETE FROM dbo.HopDong;
UPDATE dbo.PhongBan SET MaTruongPhong = NULL;
DELETE FROM dbo.NhanVien;
DELETE FROM dbo.PhongBan;
-- Sau đó chạy lại seed_data.sql
```

---

### ❌ Lỗi 4: "sp_TinhLuong: Bảng lương đã CHOT"

**Nguyên nhân:** Đã xác nhận bảng lương (Confirmed) rồi thử tính lại.

**Giải pháp:**
```sql
-- Tính lại với @Override = 1 (chỉ ghi đè bản Draft)
EXEC dbo.sp_TinhLuong 1, 2025, NULL, 1;
-- Nếu đã Confirmed/Paid thì không thể tính lại (đúng thiết kế bảo vệ)
```

---

### ❌ Lỗi 5: "MAXRECURSION option conflicts with the OPTION clause"

**Nguyên nhân:** SQL Server mặc định MAXRECURSION = 100, CTE trong seed_data cần lớn hơn.

**Giải pháp:**
```sql
-- Thêm vào cuối query CTE
OPTION (MAXRECURSION 400);
-- File seed_data.sql đã có dòng này rồi
```

---

### ❌ Lỗi 6: Test cases FAIL sau khi chạy testcase

**Nguyên nhân:** Chưa chạy sp_TinhLuong cho 3 kỳ trước khi test.

**Giải pháp:**
```sql
-- Đảm bảo đã tính lương 3 tháng
EXEC dbo.sp_TinhLuong 1, 2025;
EXEC dbo.sp_TinhLuong 2, 2025;
EXEC dbo.sp_TinhLuong 3, 2025;
-- Rồi mới chạy testcase
```

---

## Checklist Hoàn Thành

Sau khi chạy xong, kiểm tra bảng sau — tất cả phải ✅:

```sql
-- CHẠY LỆNH NÀY ĐỂ XEM TỔNG KẾT
SELECT 'OBJECT COUNT' AS CheckType,
    (SELECT COUNT(*) FROM sys.tables    WHERE is_ms_shipped=0) AS Tables,
    (SELECT COUNT(*) FROM sys.views     WHERE is_ms_shipped=0) AS Views,
    (SELECT COUNT(*) FROM sys.procedures WHERE is_ms_shipped=0) AS SPs,
    (SELECT COUNT(*) FROM sys.objects   WHERE type IN('FN','TF') AND is_ms_shipped=0) AS Functions,
    (SELECT COUNT(*) FROM sys.triggers  WHERE parent_id>0) AS Triggers;

-- Kết quả mong đợi: 15 | 6 | 20 | 13 | 12

SELECT 'DATA COUNT' AS CheckType,
    (SELECT COUNT(*) FROM dbo.NhanVien) AS NhanVien,
    (SELECT COUNT(*) FROM dbo.HopDong)  AS HopDong,
    (SELECT COUNT(*) FROM dbo.ChamCong) AS ChamCong,
    (SELECT COUNT(*) FROM dbo.BangLuong WHERE Nam=2025) AS BangLuong_2025;

-- Kết quả mong đợi: 50 | 50 | 3100+ | 150
```

| Hạng mục | Mong đợi | Kiểm tra |
|---|---|---|
| Tables | 15 | `SELECT COUNT(*) FROM sys.tables WHERE is_ms_shipped=0` |
| Views | 6 | `SELECT COUNT(*) FROM sys.views WHERE is_ms_shipped=0` |
| Stored Procedures | 20 | `SELECT COUNT(*) FROM sys.procedures WHERE is_ms_shipped=0` |
| Functions | 13 | `SELECT COUNT(*) FROM sys.objects WHERE type IN ('FN','TF') AND is_ms_shipped=0` |
| Triggers | 12 | `SELECT COUNT(*) FROM sys.triggers WHERE parent_id > 0` |
| NhanVien | 50 | `SELECT COUNT(*) FROM dbo.NhanVien` |
| ChamCong | > 3000 | `SELECT COUNT(*) FROM dbo.ChamCong` |
| BangLuong 2025 | 150 | `SELECT COUNT(*) FROM dbo.BangLuong WHERE Nam=2025` |
| Test PASS | 177/177 | Chạy cả 2 file testcase |

---

## 📝 Ghi Chú Quan Trọng

> **💡 Collation:** Database HRPayrollDB được tạo với `Vietnamese_CI_AS` — đảm bảo sắp xếp tiếng Việt đúng. Nếu SQL Server instance của bạn dùng collation khác, có thể cần thêm `COLLATE Vietnamese_CI_AS` vào các cột NVARCHAR khi JOIN.

> **💡 SSMS Settings:** Vào **Tools → Options → Query Results → Results to Grid** → Tăng "Maximum Characters Retrieved" lên 65535 để xem đầy đủ nội dung cột NVARCHAR(MAX).

> **💡 Tab Messages:** Luôn xem **tab Messages** (Ctrl+M) thay vì chỉ xem tab Results để thấy PRINT output của các SP và Trigger.

> **⚠️ Quyền:** Tài khoản SQL Server cần quyền `db_owner` hoặc `sysadmin` để tạo database, trigger và set trigger order.

---

*Hướng dẫn được tạo cho dự án **HRPayrollSystem** — Môn Hệ Quản Trị Cơ Sở Dữ Liệu — DL2301CLCA*  
*DBMS: Microsoft SQL Server 2019+ | Tổng: 20 files | 11,000+ dòng SQL | 177 test cases*
