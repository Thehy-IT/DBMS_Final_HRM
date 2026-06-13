# Tài liệu Yêu Cầu Nghiệp Vụ

# Hệ Thống Quản Lý Nhân Sự & Tính Lương Tự Động

**Hệ QTCSDL:** Microsoft SQL Server 2019+
**Phiên bản:** 1.0
**Ngày:** 2025-06-01

---

## 1. Tổng Quan Hệ Thống

Hệ thống quản lý toàn bộ vòng đời nhân viên trong doanh nghiệp vừa và nhỏ (50–500 người):
từ tuyển dụng, ký hợp đồng, chấm công hàng ngày, tính lương tự động hàng tháng,
khấu trừ bảo hiểm & thuế TNCN, đến xuất báo cáo tài chính nhân sự.

**Mục tiêu cốt lõi:**

- Tự động hoá 100% quy trình tính lương hàng tháng qua Stored Procedure
- Ghi nhận đầy đủ lịch sử thay đổi hợp đồng, lương qua Trigger (Audit Trail)
- Tuân thủ quy định Bộ Tài chính: thuế TNCN lũy tiến 7 bậc, BHXH/BHYT/BHTN

---

## 2. Danh Sách Thực Thể (Entities)

| STT | Thực thể                 | Mô tả                                   | Ghi chú                              |
| --- | -------------------------- | ----------------------------------------- | ------------------------------------- |
| 1   | **NhanVien**         | Thông tin cá nhân nhân viên          | Thực thể trung tâm                 |
| 2   | **PhongBan**         | Đơn vị tổ chức nội bộ              | Có cây phân cấp                   |
| 3   | **ChucVu**           | Vị trí công việc, hệ số lương     | Gắn với nhóm lương               |
| 4   | **HopDong**          | Hợp đồng lao động từng nhân viên  | Nhiều loại hợp đồng              |
| 5   | **LuongCoBan**       | Mức lương cơ bản theo thời kỳ      | Lịch sử thay đổi                  |
| 6   | **ChamCong**         | Bản ghi điểm danh từng ngày          | Nguồn đầu vào tính lương       |
| 7   | **PhucLoi**          | Danh mục phụ cấp & phúc lợi          | Ăn trưa, xăng xe, điện thoại... |
| 8   | **NhanVienPhucLoi**  | Gán phúc lợi cho nhân viên           | Quan hệ nhiều-nhiều                |
| 9   | **BangLuong**        | Bảng lương tổng hợp theo tháng      | Kết quả từ sp_TinhLuong            |
| 10  | **ChiTietLuong**     | Dòng chi tiết thu nhập/khấu trừ      | 1 BangLuong → N ChiTiet              |
| 11  | **KhauTru**          | Các khoản khấu trừ đặc biệt        | Tạm ứng, phạt kỷ luật...         |
| 12  | **ThueTNCN**         | Quyết toán thuế TNCN hàng tháng      | Theo biểu lũy tiến                 |
| 13  | **NghiPhep**         | Đăng ký & theo dõi nghỉ phép        | Phép năm, thai sản, ốm...         |
| 14  | **AuditLog_HopDong** | Log tự động khi thay đổi hợp đồng | Do Trigger ghi                        |
| 15  | **AuditLog_Luong**   | Log tự động khi thay đổi lương     | Do Trigger ghi                        |

---

## 3. Quy Tắc Nghiệp Vụ (Business Rules)

### 3.1 Quản lý nhân viên

- BR-01: Mã nhân viên duy nhất, định dạng `NV####` (VD: NV0001)
- BR-02: Nhân viên phải thuộc đúng 1 phòng ban và 1 chức vụ tại mọi thời điểm
- BR-03: Nhân viên không thể bị xóa nếu còn hợp đồng đang hiệu lực
- BR-04: Ngày sinh: nhân viên phải từ 18 đến 65 tuổi tại thời điểm ký hợp đồng

### 3.2 Hợp đồng lao động

- BR-05: Một nhân viên chỉ có 1 hợp đồng đang hiệu lực tại mỗi thời điểm
- BR-06: Loại hợp đồng: `THUVIEC` (2 tháng), `XACDINH_1` (1 năm), `XACDINH_2` (2 năm), `VODIDHAN`
- BR-07: Hợp đồng thử việc: lương bằng 85% lương cơ bản, không tính BHXH
- BR-08: Khi cập nhật hợp đồng → Trigger tự động ghi vào AuditLog_HopDong

### 3.3 Chấm công

- BR-09: Trạng thái chấm công: `DI_LAM`, `NGHI_PHEP`, `NGHI_BENH`, `NGHI_KHONG_PHEP`, `NGHI_LE`
- BR-10: 1 nhân viên chỉ có 1 bản ghi chấm công mỗi ngày (UNIQUE constraint)
- BR-11: Không cho phép chấm công vào ngày trong tương lai
- BR-12: Làm thêm giờ tính 150% lương/giờ (ngày thường), 200% (cuối tuần), 300% (lễ)

### 3.4 Tính lương — Công thức cốt lõi

```
Lương Gross = LuongCoBan × HeSoChucVu × (NgayDiLam / TongNgayLam)
            + TổngPhụCấp
            + LươngLàmThêm

Lương chịu BH   = min(LuongCoBan, 20 × LươngTốiThiểuVùng)
BHXH NV         = LuongChiuBH × 8%
BHYT NV         = LuongChiuBH × 1.5%
BHTN NV         = LuongChiuBH × 1%
Tổng BH NV      = BHXH + BHYT + BHTN (= 10.5%)

Giảm trừ bản thân  = 11,000,000 VNĐ/tháng
Giảm trừ phụ thuộc = 4,400,000 VNĐ/người/tháng

Thu nhập chịu thuế = Lương Gross - BH NV - Giảm trừ bản thân - Giảm trừ phụ thuộc
Thuế TNCN          = fn_TinhThueTNCN(ThuNhapChiuThue)

Lương Net  = Lương Gross - BH NV - Thuế TNCN - KhauTruKhac
```

### 3.5 Biểu thuế TNCN lũy tiến 7 bậc (Thông tư 111/2013/TT-BTC)

| Bậc | Thu nhập tính thuế/tháng (VNĐ) | Thuế suất |
| ---- | ----------------------------------- | ----------- |
| 1    | Đến 5,000,000                     | 5%          |
| 2    | 5,000,001 – 10,000,000             | 10%         |
| 3    | 10,000,001 – 18,000,000            | 15%         |
| 4    | 18,000,001 – 32,000,000            | 20%         |
| 5    | 32,000,001 – 52,000,000            | 25%         |
| 6    | 52,000,001 – 80,000,000            | 30%         |
| 7    | Trên 80,000,000                    | 35%         |

### 3.6 Báo cáo & Audit

- BR-13: Mọi thay đổi lương cơ bản phải được ghi log với OldValue, NewValue, timestamp, user
- BR-14: Bảng lương đã chốt (TrangThai = 'CHOT') không được phép sửa/xóa
- BR-15: Báo cáo lương phải có chữ ký xác nhận của HR và Giám đốc tài chính

---

## 4. Actor & Use Case

### Actor 1: HR Administrator

| Mã UC | Use Case               | Mô tả                                           | Check list |
| ------ | ---------------------- | ------------------------------------------------- | ---------- |
| UC-01  | Quản lý nhân viên  | Thêm, sửa, vô hiệu hoá hồ sơ nhân viên   | 90%        |
| UC-02  | Quản lý hợp đồng  | Ký mới, gia hạn, thanh lý hợp đồng         | 90%        |
| UC-03  | Quản lý chấm công  | Nhập bảng chấm công tháng                    |            |
| UC-04  | Quản lý phúc lợi   | Gán/xoá phụ cấp cho nhân viên               |            |
| UC-05  | Chạy tính lương    | Gọi sp_TinhLuong(@Thang, @Nam)                   |            |
| UC-06  | Duyệt & chốt lương | Chuyển trạng thái BangLuong → CHOT            |            |
| UC-07  | Xem audit log          | Tra cứu lịch sử thay đổi hợp đồng/lương |            |

### Actor 2: Nhân Viên

| Mã UC | Use Case                  | Mô tả                                     |
| ------ | ------------------------- | ------------------------------------------- |
| UC-08  | Xem bảng lương         | Xem lương net của bản thân theo tháng |
| UC-09  | Đăng ký nghỉ phép    | Gửi yêu cầu nghỉ phép                  |
| UC-10  | Xem lịch sử chấm công | Kiểm tra chấm công của tháng           |

### Actor 3: Giám Đốc / Kế Toán Trưởng

| Mã UC | Use Case                         | Mô tả                                       |
| ------ | -------------------------------- | --------------------------------------------- |
| UC-11  | Báo cáo quỹ lương           | Tổng chi phí lương theo phòng ban/tháng |
| UC-12  | Báo cáo thuế TNCN             | Tổng hợp thuế đã khấu trừ theo tháng  |
| UC-13  | Báo cáo BHXH                   | Danh sách đóng BHXH nộp cơ quan BHXH     |
| UC-14  | Phân tích biến động lương | So sánh quỹ lương các tháng             |

---

## 5. Ràng Buộc Phi Chức Năng

| Loại            | Yêu cầu                                                                        |
| ---------------- | -------------------------------------------------------------------------------- |
| Hiệu năng      | sp_TinhLuong cho 500 NV phải hoàn thành < 10 giây                            |
| Toàn vẹn       | Tất cả thao tác tính lương phải nằm trong Transaction                    |
| Bảo mật        | Phân quyền theo role: HR_ROLE, EMPLOYEE_ROLE, DIRECTOR_ROLE                    |
| Audit            | 100% thay đổi hợp đồng và lương phải được log tự động qua Trigger |
| Chuẩn pháp lý | Tuân thủ Bộ luật Lao động 2019, Thông tư 111/2013/TT-BTC                 |

---

## 6. Phạm Vi Không Bao Gồm (Out of Scope)

- Tuyển dụng và onboarding online
- Chấm công bằng vân tay / Face ID (chỉ nhập thủ công)
- Tích hợp ngân hàng để chuyển lương tự động
- Mobile app cho nhân viên
