# PHASE 3 - USE CASE ANALYSIS

## 1. Danh sách Use Cases
- **Quản lý nhân sự**: Thêm NV mới, Cập nhật hồ sơ, Xem danh sách NV, Tra cứu hồ sơ.
- **Quản lý hợp đồng**: Tạo HĐ mới, Gia hạn HĐ, Chấm dứt HĐ.
- **Quản lý phòng ban/chức vụ**: Thêm/Sửa/Xóa danh mục.
- **Chấm công**: Nhập giờ vào/ra, Import chấm công từ máy, Sửa lỗi chấm công.
- **Nghỉ phép**: Tạo đơn nghỉ phép, Duyệt đơn nghỉ phép, Hủy đơn nghỉ phép.
- **Tính lương**: Chạy bảng lương tháng, Xem chi tiết lương, Chốt/Khóa bảng lương.
- **Phúc lợi & Khấu trừ**: Gán phúc lợi NV, Thêm khoản khấu trừ, Duyệt khấu trừ.
- **Báo cáo**: Xuất báo cáo nhân sự, quỹ lương, OT.

## 2. Use Case Diagram (Text)
```text
[Employee] 
  ├──> (Xem hồ sơ)
  ├──> (Tạo đơn nghỉ phép)
  └──> (Xem bảng lương)

[HR Staff]
  ├──> (Thêm/Sửa Nhân viên)
  ├──> (Tạo Hợp đồng)
  └──> (Quản lý Phép & Chấm công)

[Department Manager]
  ├──> (Xem NV trong phòng)
  └──> (Duyệt đơn nghỉ phép)

[Payroll Officer]
  ├──> (Xử lý Chấm công / OT)
  ├──> (Tạo Khấu trừ)
  └──> (Chạy Tính Lương)
```

## 3. User Journey (Quá trình Onboarding -> Tính lương)
1. **Onboarding**: HR Staff tạo hồ sơ NV mới -> Gán mã NV, Phòng ban, Chức vụ.
2. **Contracting**: HR Staff lập Hợp đồng thử việc -> Điền Lương CB -> System lưu Lịch sử lương (Tier 2).
3. **Daily Operations**: NV đi làm -> Hệ thống ghi nhận Chấm công (Tier 3) -> NV xin nghỉ phép -> Quản lý duyệt.
4. **Payroll Processing**: Cuối tháng, Payroll Officer tổng hợp Chấm công -> Tính Lương gộp, Khấu trừ, Thuế -> Sinh Bảng Lương (Tier 4).
5. **Review & Pay**: HR Manager duyệt Bảng lương -> Gửi email Phiếu lương cho NV -> Kế toán thanh toán.

## 4. User Flow (Xin nghỉ phép)
1. NV đăng nhập -> Vào "Đăng ký nghỉ".
2. Chọn "Loại nghỉ phép" & "Ngày bắt đầu/Kết thúc" -> Submit.
3. Trạng thái đơn = Pending.
4. Trưởng phòng nhận thông báo -> Vào "Duyệt nghỉ".
5. Xem xét -> Approve (Trạng thái = Approved) hoặc Reject (Trạng thái = Rejected).
6. Hệ thống cập nhật bảng chấm công.
