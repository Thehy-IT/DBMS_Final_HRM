# PHASE 1 - DATABASE ANALYSIS

## 1. Các thực thể (Entities) & 3. Khóa chính
| Tên Bảng | Ý nghĩa | Khóa chính |
|----------|---------|------------|
| PhongBan | Phòng ban trong công ty | MaPB |
| ChucVu | Chức vụ, vị trí công việc | MaCV |
| LoaiHopDong | Các loại hợp đồng lao động | MaLoaiHD |
| LoaiNghiPhep | Các loại nghỉ phép | MaLoaiNghi |
| LoaiPhucLoi | Danh mục phúc lợi | MaFL |
| NgayLe | Ngày lễ, Tết nghỉ làm | NgayLe |
| NhanVien | Thông tin cá nhân nhân viên | MaNV |
| HopDong | Hợp đồng lao động của nhân viên | MaHD |
| LuongCoBan | Lịch sử lương cơ bản của nhân viên | MaLCB |
| NghiPhep | Thông tin đơn xin nghỉ phép | MaNP |
| NhanVienPhucLoi | Phúc lợi được áp dụng cho từng nhân viên | MaNV, MaFL, NgayApDung |
| ChamCong | Bảng ghi nhận chấm công hằng ngày | MaCC |
| BangLuong | Bảng lương tổng hợp mỗi tháng | MaBL |
| ChiTietLuong | Chi tiết các khoản cộng/trừ trong tháng | MaCTL |
| KhauTru | Các khoản khấu trừ ngoài chuẩn (phạt, tạm ứng) | MaKT |
| AuditLog_HopDong | Lịch sử thay đổi hợp đồng | MaLog |
| AuditLog_Luong | Lịch sử thay đổi lương | MaLog |

## 2. Các quan hệ (Relationships) & 4. Khóa ngoại
| Bảng gốc | Khóa ngoại | Bảng tham chiếu | Loại quan hệ |
|----------|------------|-----------------|--------------|
| NhanVien | MaPB | PhongBan | N-1 |
| NhanVien | MaCV | ChucVu | N-1 |
| PhongBan | MaTruongPhong | NhanVien | 1-1 |
| HopDong | MaNV | NhanVien | N-1 |
| HopDong | MaLoaiHD | LoaiHopDong | N-1 |
| LuongCoBan | MaNV | NhanVien | N-1 |
| NghiPhep | MaNV | NhanVien | N-1 |
| NghiPhep | MaLoaiNghi | LoaiNghiPhep | N-1 |
| NhanVienPhucLoi | MaNV | NhanVien | N-1 |
| NhanVienPhucLoi | MaFL | LoaiPhucLoi | N-1 |
| ChamCong | MaNV | NhanVien | N-1 |
| BangLuong | MaNV | NhanVien | N-1 |
| ChiTietLuong | MaBL | BangLuong | N-1 |
| KhauTru | MaNV | NhanVien | N-1 |
| KhauTru | MaBL | BangLuong | N-1 |

## 5. Business Rules & 10. Các ràng buộc nghiệp vụ
1. **Ràng buộc định dạng**: Mã NV `NVxxxxxx`, Hợp đồng `HDxxxxxxxx`, Căn cước công dân `12 số`, Email unique.
2. **Lương & Hợp đồng**: Lương cơ bản > 0, Lương đóng BHXH <= Lương CB và không quá mức trần (46.800.000). Ngày kết thúc hợp đồng phải sau ngày bắt đầu.
3. **Chấm công**: Hệ số tăng ca chỉ nằm trong [1.00, 1.50, 2.00, 3.00], giờ tăng ca tối đa 12h/ngày.
4. **Bảo hiểm & Thuế**: Tổng bảo hiểm (BHXH + BHYT + BHTN) <= Lương CB. Thuế TNCN không vượt quá 35% lương CB.

## 6. Data Flow
- **Tuyển dụng/Gia nhập**: Sinh `NhanVien` -> Gán `PhongBan`, `ChucVu`.
- **Hợp đồng & Lương**: Tạo `HopDong` -> Thiết lập `LuongCoBan` -> Gán `NhanVienPhucLoi`.
- **Hàng ngày**: `ChamCong` (Giờ vào, ra) -> Duyệt `NghiPhep`.
- **Cuối tháng**: Tổng hợp `ChamCong`, `NghiPhep`, `KhauTru`, `NhanVienPhucLoi` -> Chạy `BangLuong` -> Sinh `ChiTietLuong`.

## 7. Nghiệp vụ suy ra từ schema & 9. Các module nghiệp vụ
- **Quản lý danh mục**: Thiết lập cơ cấu tổ chức (Phòng ban, Chức vụ), loại HĐ, phép, phúc lợi.
- **Quản lý hồ sơ nhân sự**: Lưu trữ thông tin NV, lịch sử lương.
- **Quản lý Time & Attendance**: Xử lý chấm công, ngày lễ, phép năm.
- **Quản lý Payroll**: Tự động hóa tính lương gross/net, thuế, BHXH, phụ cấp.
- **Auditing**: Theo dõi mọi thay đổi liên quan đến hợp đồng và lương.

## 8. ERD (Mô tả)
Mô hình sao với trung tâm là `NhanVien`. Các danh mục (Phòng ban, Chức vụ) bao quanh nhân viên. Các luồng nghiệp vụ động (Hợp đồng, Lương cơ bản, Chấm công, Phép, Phúc lợi) được gắn dưới NhanVien với mối quan hệ 1-N. Cuối cùng đổ dồn về `BangLuong` tổng hợp.
