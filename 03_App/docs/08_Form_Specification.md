# PHASE 10 - FORM SPECIFICATION

## Form: NhanVien (Thông tin nhân viên)

| Tên Field | Field Name (DB) | Loại dữ liệu | Control Type | Bắt buộc | Validation Rules | Placeholder/Mặc định |
|-----------|----------------|--------------|--------------|----------|-------------------|----------------------|
| Mã Nhân Viên | `MaNV` | CHAR(8) | TextBox | Có | Khớp regex `^NV[0-9]{6}$`, Unique | NV000001 (Auto gen) |
| Họ và Tên | `HoTen` | VARCHAR(100) | TextBox | Có | Max 100 char, Không rỗng | Nhập họ và tên... |
| Giới Tính | `GioiTinh` | CHAR(1) | RadioGroup | Có | In ('M', 'F') | M (Nam) |
| Ngày Sinh | `NgaySinh` | DATE | DatePicker | Có | <= Ngày hiện tại - 18 năm | Chọn ngày sinh |
| CCCD | `CCCD` | VARCHAR(12) | TextBox | Có | Exactly 12 digits, Unique | Nhập 12 số CCCD |
| Điện thoại | `SoDienThoai` | VARCHAR(15) | TextBox | Không | Regex định dạng số VN | Nhập số điện thoại |
| Email | `Email` | VARCHAR(100) | TextBox | Không | Định dạng Email, Unique | abc@company.com |
| Phòng Ban | `MaPB` | CHAR(6) | ComboBox | Có | FK tồn tại trong DB | -- Chọn phòng ban -- |
| Chức Vụ | `MaCV` | CHAR(6) | ComboBox | Có | FK tồn tại trong DB | -- Chọn chức vụ -- |
| Ngày vào làm| `NgayVaoLam` | DATE | DatePicker | Có | Hợp lệ | Today |
| MST | `MaSoThue` | VARCHAR(14) | TextBox | Không | Tối đa 14 ký tự | |
| STK Ngân Hàng| `SoTaiKhoanNH`| VARCHAR(20) | TextBox | Không | Chỉ chứa số | |

## Form: HopDong (Hợp đồng)

| Tên Field | Field Name | Loại dữ liệu | Control Type | Bắt buộc | Validation Rules |
|-----------|------------|--------------|--------------|----------|-------------------|
| Mã HĐ | `MaHD` | CHAR(10) | TextBox | Có | Regex `^HD[0-9]{8}$` |
| Loại HĐ | `MaLoaiHD` | TINYINT | Select | Có | |
| Ngày bắt đầu| `NgayBatDau` | DATE | DatePicker | Có | >= 2000-01-01 |
| Ngày kết thúc| `NgayKetThuc`| DATE | DatePicker | Không | > NgayBatDau (nếu có) |
| Lương Cơ Bản | `LuongCoBan` | DECIMAL | NumberInput | Có | > 0 |
| Vùng Lương | `VungLuong` | TINYINT | Select | Có | 1, 2, 3, 4 |
