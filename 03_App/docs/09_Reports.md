# PHASE 11 - REPORT DESIGN

Thiết kế cấu trúc cho 8 loại báo cáo chính, mỗi báo cáo đều hỗ trợ xuất ra Excel (XLSX) và PDF.

## 1. Báo cáo nhân sự (Employee Roster Report)
- **Filters**: Trạng thái (Tất cả/Active/Nghỉ việc), Phòng ban, Chức vụ, Khoảng Ngày Vào Làm.
- **Columns**: Mã NV, Họ Tên, Giới Tính, Ngày Sinh, SĐT, Phòng Ban, Chức Vụ, Ngày Vào Làm, Thâm niên.
- **Charts**: Phân bố giới tính (Pie), Phân bố theo phòng ban (Bar).

## 2. Báo cáo chấm công (Attendance Summary)
- **Filters**: Tháng/Năm, Phòng ban, Nhân viên cụ thể.
- **Columns**: Mã NV, Tên NV, Số ngày công chuẩn, Số ngày đi làm, Số ngày nghỉ phép, Số ngày nghỉ không phép.
- **Lưu ý**: Highlight các dòng có ngày không phép > 0 bằng màu đỏ.

## 3. Báo cáo nghỉ phép (Leave Balance Report)
- **Filters**: Năm, Phòng ban.
- **Columns**: Mã NV, Tên NV, Tổng phép năm, Số ngày đã nghỉ, Số ngày còn lại.

## 4. Báo cáo lương (Payroll Master Report)
- **Filters**: Kỳ lương (Tháng/Năm), Trạng thái bảng lương.
- **Columns**: Mã NV, Tên, Lương CB, Ngày công, Tổng Thu Nhập, Tổng BHXH/YT/TN, Tổng Thuế TNCN, Khấu trừ khác, Thực Lĩnh.
- **Charts**: Top 5 phòng ban có quỹ lương cao nhất. Tổng chi phí lương so với tháng trước.

## 5. Báo cáo OT (Overtime Report)
- **Filters**: Tháng/Năm, Phòng ban.
- **Columns**: Mã NV, Tên, Phòng ban, Số giờ OT ngày thường (x1.5), Số giờ OT cuối tuần (x2), Số giờ OT ngày lễ (x3), Tổng số tiền OT.

## 6. Báo cáo hợp đồng (Contract Expiry Report)
- **Filters**: Hết hạn trong vòng X ngày (30, 60, 90).
- **Columns**: Mã NV, Tên, Loại HĐ, Ngày Bắt Đầu, Ngày Kết Thúc, Số ngày còn lại. Cảnh báo gia hạn.

## 7. Báo cáo phúc lợi (Benefits Allocation)
- **Filters**: Tháng, Loại phúc lợi.
- **Columns**: Tên phúc lợi, Số lượng NV được hưởng, Tổng số tiền chi trả.

## 8. Báo cáo khấu trừ (Deductions Report)
- **Filters**: Kỳ lương, Loại khấu trừ.
- **Columns**: Mã NV, Tên, Loại khấu trừ (Tạm ứng, Phạt...), Số tiền, Ngày phát sinh, Trạng thái.
