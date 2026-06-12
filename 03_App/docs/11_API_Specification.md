# PHASE 13 - API SPECIFICATION

API base URL: `https://api.hrsystem.com/v1`
Authentication: Bearer Token (JWT) trong header `Authorization`.

## 1. Module NhanVien (Employees)

### Lấy danh sách nhân viên
- **Endpoint**: `GET /employees`
- **Query Params**: `page`, `limit`, `search`, `department`, `status`
- **Response**: `200 OK`
```json
{
  "data": [ { "MaNV": "NV000001", "HoTen": "Nguyen Van A", ... } ],
  "meta": { "total": 150, "page": 1, "lastPage": 15 }
}
```

### Tạo mới nhân viên
- **Endpoint**: `POST /employees`
- **Request Body**: JSON object chứa các trường bắt buộc (`HoTen`, `GioiTinh`, `NgaySinh`, `CCCD`, `MaPB`, `MaCV`, `NgayVaoLam`).
- **Validation**: Regex CCCD 12 số, tuổi >= 18.
- **Response**: `201 Created` kèm theo data nhân viên vừa tạo (chứa `MaNV` sinh tự động).
- **Error Codes**: `400 Bad Request` (Validation Failed), `409 Conflict` (Duplicate CCCD/Email).

## 2. Module ChamCong (Attendance)

### Import dữ liệu từ máy chấm công
- **Endpoint**: `POST /attendance/import`
- **Request Type**: `multipart/form-data` (File Excel/CSV)
- **Response**: `200 OK`
```json
{
  "message": "Imported successfully",
  "totalRecords": 120,
  "errors": []
}
```

## 3. Module BangLuong (Payroll)

### Chạy tính lương tháng
- **Endpoint**: `POST /payroll/calculate`
- **Request Body**: `{ "month": 6, "year": 2026 }`
- **Response**: `200 OK` (Báo cáo số lượng bản ghi tạo thành công)
- **Error**: `403 Forbidden` (Chỉ Payroll Officer/Admin), `409 Conflict` (Bảng lương tháng này đã bị Locked).
