# PHASE 12 - PERMISSION MATRIX

| Module / Chức năng | Hành động | Admin | HR Manager | HR Staff | Payroll Officer | Dept Manager | Employee |
|--------------------|-----------|-------|------------|----------|-----------------|--------------|----------|
| **NhanVien** (Hồ sơ) | READ | ✔ | ✔ | ✔ | ✔ | ✔ (Phòng mình)| ✔ (Cá nhân)|
| | CREATE | ✔ | ✔ | ✔ | | | |
| | UPDATE | ✔ | ✔ | ✔ | | | |
| | DELETE | ✔ | ✔ | | | | |
| | EXPORT/IMPORT | ✔ | ✔ | ✔ | | | |
| **HopDong** | READ | ✔ | ✔ | ✔ | ✔ | | |
| | CREATE/UPDATE | ✔ | ✔ | ✔ | | | |
| | DELETE | ✔ | ✔ | | | | |
| **NghiPhep** | READ | ✔ | ✔ | ✔ | ✔ | ✔ (Phòng mình)| ✔ (Cá nhân)|
| | CREATE | ✔ | ✔ | ✔ | | | ✔ |
| | APPROVE | ✔ | ✔ | | | ✔ | |
| **ChamCong** | READ | ✔ | ✔ | ✔ | ✔ | ✔ (Phòng mình)| ✔ (Cá nhân)|
| | UPDATE | ✔ | ✔ | ✔ | ✔ | | |
| | IMPORT | ✔ | ✔ | ✔ | ✔ | | |
| **BangLuong** | READ | ✔ | ✔ | | ✔ | | ✔ (Cá nhân)|
| | CREATE/RUN | ✔ | | | ✔ | | |
| | APPROVE | ✔ | ✔ | | | | |
| | EXPORT | ✔ | ✔ | | ✔ | | |
| **System** (Roles) | ALL | ✔ | | | | | |
| **Audit Log** | READ | ✔ | ✔ | | | | |

*Ghi chú: Employee chỉ có quyền tự phục vụ với dữ liệu liên kết với chính Mã NV của họ.*
