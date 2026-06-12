# PHASE 7 - SCREEN INVENTORY

| Tên màn hình | Mục đích | URL Route | Permission | Actions |
|-------------|----------|-----------|------------|---------|
| **Dashboard** | Xem tổng quan | `/dashboard` | `DASHBOARD_VIEW` | View, Filter theo thời gian |
| **Employee List** | Quản lý danh sách NV | `/employees` | `EMPLOYEE_VIEW` | Search, Filter, Add, Edit, Export, Import |
| **Employee Detail** | Xem hồ sơ 1 NV | `/employees/[id]` | `EMPLOYEE_VIEW` | View, Edit, Print |
| **Department List**| Quản lý phòng ban | `/departments` | `DEPT_VIEW` | Add, Edit, Delete |
| **Position List** | Quản lý chức vụ | `/positions` | `POS_VIEW` | Add, Edit, Delete |
| **Contract List** | Quản lý hợp đồng | `/contracts` | `CONTRACT_VIEW`| Add, Edit, Renew, Terminate, View File |
| **Attendance** | Bảng chấm công ngày | `/attendance` | `ATTENDANCE_VIEW`| Import, Edit, Approve, Export |
| **Leave Requests**| Đơn nghỉ phép | `/leaves` | `LEAVE_VIEW` | Add, Approve, Reject, Cancel |
| **Payroll Calc** | Màn hình chạy lương | `/payroll/calc` | `PAYROLL_RUN` | Run, Recalculate, Confirm, Lock |
| **Payslip List** | Danh sách phiếu lương| `/payroll/slips` | `PAYROLL_VIEW` | View, Export PDF, Send Email |
| **Deduction List**| Khấu trừ ngoài chuẩn | `/deductions` | `DED_VIEW` | Add, Edit, Delete |
| **Benefits List** | Phúc lợi nhân viên | `/benefits` | `BENEFIT_VIEW` | Assign, Edit |
| **Audit Log** | Xem lịch sử thay đổi | `/system/audit` | `AUDIT_VIEW` | Search, Filter, View Diff |
| **User Roles** | Phân quyền | `/system/roles` | `SYS_ADMIN` | Add Role, Assign Permissions |
