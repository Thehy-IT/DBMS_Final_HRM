# BÁO CÁO TIẾN ĐỘ THEO TUẦN & PHÂN TÍCH CHUYÊN SÂU HỆ THỐNG

**Dự án:** HRPayrollSystem — Hệ Thống Quản Lý Nhân Sự & Tính Lương Tự Động
**Cơ sở dữ liệu:** MySQL 8.0+

---

## 1. Tổng quan

Dự án HRPayrollSystem được xây dựng nhằm giải quyết bài toán quản lý hồ sơ nhân sự, hợp đồng, chấm công và tính lương tự động cho các doanh nghiệp quy mô vừa và nhỏ (50-500 nhân sự).
Hệ thống áp dụng mạnh mẽ kiến trúc **Database-Centric**, tức là toàn bộ logic tính toán phức tạp (như tính thuế TNCN lũy tiến 7 bậc, BHXH, lương gross-to-net) và các quy tắc kiểm tra (validation) đều được đẩy xuống lớp CSDL. Việc này đảm bảo tính toàn vẹn dữ liệu tuyệt đối (ACID), hiệu năng tối đa ngay tại nguồn dữ liệu và khả năng Audit Trail chặt chẽ mà không phụ thuộc vào lớp ứng dụng (App Layer).

## 2. Tác nhân chính

Hệ thống phục vụ các tác nhân (actors) chính sau:

- **HR_ADMIN (Nhân viên Nhân sự / Admin):** Cập nhật hồ sơ nhân viên, tạo hợp đồng mới, nhập liệu chấm công, phê duyệt hoặc từ chối đơn nghỉ phép.
- **HR_MANAGER / KẾ TOÁN (Quản lý / Kế toán):** Kích hoạt các Stored Procedure để tính lương tự động cuối tháng, xác nhận bảng lương, khóa bảng lương và xuất các báo cáo tài chính/nhân sự.
- **Hệ thống (System / Triggers):** Tự động giám sát dữ liệu, ghi log lịch sử (Audit Log), chặn các thao tác sai nghiệp vụ (chấm công tương lai, xóa bảng lương đã chốt).
- **Nhân viên (Employees):** Xem phiếu lương cá nhân, theo dõi chấm công và nộp đơn nghỉ phép.

## 3. Chức năng chính

- **Quản lý danh mục & Hồ sơ nhân sự:** Quản lý cơ cấu phòng ban, chức vụ, nhân viên, gia cảnh (người phụ thuộc) và mã số thuế.
- **Quản lý Hợp đồng & Lương cơ bản:** Theo dõi vòng đời hợp đồng, mức lương đóng bảo hiểm (tuân thủ giới hạn 20 lần mức lương tối thiểu vùng).
- **Chấm công & Nghỉ phép:** Ghi nhận giờ ra/vào, xử lý logic tăng ca (OT), phân loại ngày nghỉ (có lương, không lương, ốm đau, thai sản).
- **Tính lương tự động (Payroll):** Tính Gross-to-Net hoàn chỉnh, trích lập thuế TNCN lũy tiến, bảo hiểm NLĐ và bảo hiểm phần NSDLĐ.
- **Báo cáo thống kê:** Biểu đồ tỷ lệ chuyên cần, phân phối quỹ lương, quyết toán thuế cuối năm.

## 4. Giao tác (Transactions)

Tất cả các hành động liên quan đến việc cập nhật nhiều bảng cùng lúc đều được đặt trong các `TRANSACTION`.
*Đặc tả cụ thể trong dự án:* SP `sp_TinhLuong` chứa một Transaction bao bọc 8 bước xử lý: Xác thực -> Lấy danh sách NV -> Tính ngày công -> Tính Gross -> Tính Bảo hiểm -> Tính Thuế -> Ghi Chi tiết lương -> Chốt. Nếu có bất kỳ lỗi toán học hay vi phạm khóa ngoại nào ở bước 6, toàn bộ dữ liệu của bước 1-5 sẽ được `ROLLBACK` để bảo vệ hệ thống khỏi tình trạng "nửa vời".

## 5. Các đối tượng cơ sở dữ liệu (Database Objects)

### 5.1. Views (6 đối tượng)

Được sử dụng để che giấu độ phức tạp của các câu lệnh JOIN và bảo mật các dữ liệu nhạy cảm.

- `vw_BangLuong`: Chi tiết lương đầy đủ của từng nhân viên từng kỳ.
- `vw_BangLuong_TongHop`: Tổng hợp quỹ lương theo Phòng Ban / Tháng.
- `vw_ThueTNCN_KyQuyetToan`: View đặc tả số liệu tổng thu nhập chịu thuế, tổng các khoản giảm trừ để quyết toán cuối năm.
- `vw_TongHopChamCong` & `vw_ChamCong_ChiTiet`: Tổng hợp số ngày đi làm, nghỉ phép, WFH và tỷ lệ chuyên cần.

### 5.2. Stored Procedures (21 đối tượng)

Chia làm 4 nhóm chức năng chính (Lương, Bảng lương, Chấm công, Báo cáo).

- **Nổi bật:** `sp_TinhLuong` (quy trình cốt lõi tự động tính lương toàn công ty), `sp_ChamCong_DongBoNghiPhep` (đồng bộ đơn từ duyệt vào bảng chấm công), `sp_BaoCaoNhanSu_BienDong` (phân tích biến động nhân sự tuyển mới/nghỉ việc).

### 5.3. Functions (12 đối tượng)

Gói gọn các công thức tài chính và nhân sự thành các hàm Scalar Functions.

- **Nổi bật:** `fn_TinhThueTNCN_Scalar` (chạy logic IF-ELSE tính lũy tiến 7 bậc), `fn_SoNgayChuanThang` (loại trừ ngày nghỉ theo tháng/năm), `fn_TinhBH_NSDLD` (tính chi phí doanh nghiệp phải chịu).

### 5.4. Triggers (21 đối tượng)

Bảo vệ dữ liệu ở tầng thấp nhất.

- **Audit Logs:** `trg_HopDong_AfterInsert/Update` (Lưu lịch sử mọi thay đổi hợp đồng).
- **Business Validations:** `trg_ChamCong_BeforeInsert` (Chặn chấm công ngày tương lai), `trg_NghiPhep_CheckOverlap_Insert` (Chặn trùng ngày nghỉ).
- **Enforcements:** `trg_BangLuong_BeforeUpdate/Delete` (Không cho phép bất kì ai can thiệp vào dữ liệu bảng lương khi TrangThai đã được CHỐT).

---

## 6. Kịch bản phát sinh đồng thời và cách khắc phục khi Demo

Trong môi trường thực tế với nhiều HR hoạt động, các vấn đề về tương tranh (Concurrency Anomalies) bắt buộc phải xử lý:

### 6.1. Mất dữ liệu cập nhật (Lost Update)

- **Kịch bản Demo:** Hai chuyên viên nhân sự (HR1 và HR2) cùng truy xuất bảng `ChamCong` của nhân viên A vào ngày 15/03. HR1 cập nhật "Số giờ tăng ca = 2", trong khi HR2 không biết nên cũng nhấn Save để cập nhật "Trạng thái = WFH". Lưu sau sẽ đè lưu trước, thao tác của HR1 bị mất.
- **Khắc phục:** Sử dụng kỹ thuật Pessimistic Locking (`SELECT ... FOR UPDATE`) trong Procedure cập nhật chấm công. Dòng dữ liệu sẽ bị khóa đối với HR2 cho đến khi HR1 hoàn thành transaction.

### 6.2. Đọc dữ liệu rác (Dirty Read)

- **Kịch bản Demo:** Quản lý đang chạy SP `sp_TinhLuong`. Bảng `ChiTietLuong` đang được Insert dữ liệu nhưng chưa `COMMIT`. Đúng lúc này Giám đốc mở Dashboard lấy dữ liệu từ `vw_BangLuong_TongHop`. Nếu đọc phải dữ liệu chưa commit, Giám đốc sẽ thấy báo cáo quỹ lương bị sai lệch.
- **Khắc phục:** MySQL InnoDB được thiết lập Mức độ cô lập (Isolation Level) mặc định tối thiểu là `READ COMMITTED` (thường dùng `REPEATABLE READ`). Ở chế độ này, Giám đốc chỉ đọc được version dữ liệu đã commit trước đó, hoàn toàn tránh được Dirty Read.

### 6.3. Không đọc lại được dữ liệu (Non-repeatable Read)

- **Kịch bản Demo:** Kế toán mở transaction, `SELECT` xem `LuongCoBan` của nhân viên B để chuẩn bị đối soát. Cùng lúc đó, HR_ADMIN thực hiện tăng lương cho nhân viên B và `COMMIT`. Nếu kế toán chạy lại `SELECT` lần 2 trong cùng một giao tác, mức lương sẽ bị thay đổi so với lần 1.
- **Khắc phục:** Giữ Isolation Level của MySQL ở mức `REPEATABLE READ`. InnoDB cung cấp cơ chế MVCC (Multi-Version Concurrency Control) giúp tạo ra một snapshot của dữ liệu cho kế toán. Mọi lệnh đọc trong giao tác của kế toán đều nhất quán, bất chấp HR_ADMIN đã cập nhật.

### 6.4. Bóng ma (Phantom)

- **Kịch bản Demo:** Kế toán đang thực hiện chốt sổ lương, chạy `SUM()` để tính tổng chi phí nhân sự của toàn bộ Phòng Kế toán. Trong khi transaction đang mở, một HR_ADMIN thêm một hợp đồng mới cho một nhân viên kế toán vừa vào làm. Nếu kế toán `SUM()` lại, tổng chi phí đột ngột tăng lên (xuất hiện dòng dữ liệu bóng ma).
- **Khắc phục:** Đối với các giao dịch tài chính chốt sổ, set Isolation Level thành `SERIALIZABLE` trước khi thực hiện báo cáo, hoặc dùng Next-Key Lock của InnoDB để khóa các khoảng (gaps) không cho phép `INSERT` thêm dòng mới thỏa mãn điều kiện `WHERE`.

## 7. Deadlock (Khóa bế tắc)

- **Kịch bản Demo:**
  1. Transaction A (Xác nhận bảng lương): Chạy `sp_XacNhanBangLuong`, khóa bảng `BangLuong`, chuẩn bị khóa bảng `NhanVien` để gửi thông báo.
  2. Transaction B (Đồng bộ thôi việc): Chạy `sp_CapNhatNhanVien`, khóa bảng `NhanVien`, chuẩn bị khóa bảng `BangLuong` để hủy các phiếu lương đang nháp.
  3. Xảy ra chu trình chờ vô tận (Circular Wait). MySQL sẽ phát hiện và kill một trong hai Transaction, báo lỗi *Deadlock found*.
- **Cách khắc phục:**
  1. **Quy chuẩn thứ tự Locking:** Đảm bảo mọi Procedure trong hệ thống đều truy xuất và khóa các bảng theo một thứ tự duy nhất (VD: luôn tác động `NhanVien` -> `HopDong` -> `BangLuong`).
  2. Rút ngắn thời gian chạy của Transaction (không để tác vụ chờ người dùng nhập liệu).
  3. Bổ sung cơ chế `TRY...CATCH` (hoặc kiểm tra Exception) ở tầng App Code để tự động bắt mã lỗi `1213` (Deadlock) và thực hiện lại giao dịch (Retry).
