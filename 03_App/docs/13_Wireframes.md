# PHASE 15 - UI WIREFRAME (ASCII)

## Màn hình Dashboard

```text
+--------------------------------------------------------------------------+
| [Logo ERP]   | Search employees, contracts...        [🔔] [User Avatar]|
|--------------+-----------------------------------------------------------|
| D  Dashboard |  Dashboard Overview                                       |
| A            |                                                           |
| S  Employees |  +---------------+ +---------------+ +---------------+  |
| H            |  | Total Emps    | | New Hires     | | Leaves Today  |  |
| B  Contracts |  | 152           | | +5 this mo.   | | 3             |  |
| O            |  +---------------+ +---------------+ +---------------+  |
| A  Attendance|                                                           |
| R            |  [ Chart: Employees by Dept ]   [ Chart: Payroll Cost ]   |
| D  Payroll   |  |                          |   |                     |   |
|              |  |        ( O )             |   |        / \          |   |
| M  Leaves    |  |                          |   |   / \ /   \         |   |
| E            |  +--------------------------+   +---------------------+   |
| N  Reports   |                                                           |
| U            |  Recent Expiring Contracts                                |
|              |  ID       Name       Type     Expires      Action         |
|    Settings  |  HD001    Nguyen A   Trial    In 5 days    [Renew]        |
|              |  HD002    Tran B     Term     In 10 days   [Renew]        |
+--------------------------------------------------------------------------+
```

## Màn hình Danh sách Nhân Viên (Employee List)

```text
+--------------------------------------------------------------------------+
| [Logo ERP]   |                                       [🔔] [User Avatar]|
|--------------+-----------------------------------------------------------|
| D  Dashboard |  Employees > List                                         |
| A            |                                                           |
| S  Employees |  +------------------------------------------------------+ |
| H            |  | [🔍 Search by name/ID...]  [Filter: All Dept]        | |
| B  Contracts |  +------------------------------------------------------+ |
| O            |                           [Import] [Export] [+ Add Emp]   |
| A  Attendance|  -------------------------------------------------------  |
| R            |  [x] ID       Name         Dept       Status   Actions    |
| D  Payroll   |  -------------------------------------------------------  |
|              |  [ ] NV0001   Nguyen A     IT         [Active] [Edit][⋮]  |
| M  Leaves    |  [ ] NV0002   Tran B       HR         [Active] [Edit][⋮]  |
| E            |  [ ] NV0003   Le C         Sales      [Leave]  [Edit][⋮]  |
| N  Reports   |  -------------------------------------------------------  |
| U            |  Rows: 10/page                          < Prev 1 2 Next > |
+--------------------------------------------------------------------------+
```
