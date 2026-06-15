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

Hệ thống HRPayrollSystem áp dụng nghiêm ngặt các nguyên tắc quản lý giao tác (Transaction Management) để đảm bảo tính toàn vẹn (ACID) của dữ liệu. Tất cả các hành động liên quan đến việc cập nhật nhiều bảng hoặc dữ liệu nhạy cảm cùng lúc đều được đặt trong các khối `TRANSACTION` (hiển ngôn hoặc ẩn ngôn thông qua Stored Procedures và Triggers).

Dưới đây là danh sách đầy đủ các giao tác cốt lõi trong hệ thống:

### 4.1. Giao tác Tính Lương Tự Động (`sp_TinhLuong`)
Đây là giao tác quan trọng nhất của dự án. SP chứa một khối `START TRANSACTION ... COMMIT` bao bọc 8 bước xử lý liên tục cho từng nhân viên:
1. Lấy thông tin nhân viên & hợp đồng.
2. Tính số ngày công thực tế (dựa vào hàm `fn_SoNgayChuanThang`).
3. Tính các khoản phụ cấp và lương làm thêm.
4. Tính Lương Gross.
5. Trích lập Bảo hiểm (BHXH, BHYT, BHTN theo tỷ lệ % quy định).
6. Tính Thuế TNCN lũy tiến 7 bậc.
7. Xử lý các khoản khấu trừ phát sinh.
8. Ghi dữ liệu vào CSDL (`BangLuong`, `ChiTietLuong` và cập nhật `KhauTru`).

**Đảm bảo ACID:** Nếu có bất kỳ lỗi vi phạm ràng buộc (foreign key, toán học) nào xảy ra ở bất kỳ bước nào, toàn bộ chuỗi cập nhật cho nhân viên đó sẽ được `ROLLBACK` để hệ thống không rơi vào trạng thái mất đồng bộ (VD: có header BangLuong nhưng mất ChiTietLuong).

### 4.2. Giao tác Quản Lý Chấm Công và Nghỉ Phép
- **`sp_ChamCong_NhapHangNgay` & `sp_ChamCong_NhapLoat`:** Đảm bảo quá trình cập nhật trạng thái đi làm, giờ vào/ra, tăng ca hoạt động nhất quán thông qua cơ chế `INSERT ... ON DUPLICATE KEY UPDATE`.
- **`sp_ChamCong_DongBoNghiPhep`:** Giao tác đọc các đơn nghỉ phép đã duyệt từ bảng `NghiPhep` và cập nhật đồng loạt trạng thái vào bảng `ChamCong`.

### 4.3. Giao tác Quản Lý Bảng Lương
- **`sp_TaoBangLuong_ChinhThuc` & các thủ tục con:** Thực hiện xử lý hàng loạt các khoản mục liên quan đến bảng lương theo từng chu kỳ.
- **`sp_XacNhanBangLuong` / `sp_ThanhToanLuong`:** Giao tác chuyển đổi trạng thái của bảng lương (từ Nháp -> Chốt -> Đã thanh toán), đồng thời kích hoạt các cơ chế khóa dữ liệu, chặn mọi hành vi thay đổi trái phép (qua Trigger).

### 4.4. Giao tác Lưu Vết (Audit Log qua Triggers)
Mọi thay đổi dữ liệu nhạy cảm đều được hệ thống tự động đưa vào giao tác ẩn của CSDL (khi DML thực thi):
- **Lịch sử hợp đồng:** Khi có thao tác Insert/Update trên bảng `HopDong`, các trigger tự động ghi lại snapshot dữ liệu vào bảng Log (như `trg_LogHopDong`).
- **Toàn vẹn lương cơ bản:** Khi thêm mới mức lương, các Trigger (như `trg_LuongCoBan_CheckOneCurrent`) đảm bảo cùng lúc cập nhật trạng thái các mức lương cũ về vô hiệu hóa trước khi kích hoạt mức lương mới, tạo thành một giao tác trọn vẹn.

## 5. Các đối tượng cơ sở dữ liệu (Database Objects)

### 5.1. Views (6 đối tượng)

Được sử dụng để che giấu độ phức tạp của các câu lệnh JOIN và bảo mật các dữ liệu nhạy cảm.
- **Lương & Tiền lương:**
  - `vw_BangLuong`: Chi tiết lương đầy đủ của từng nhân viên từng kỳ.
  - `vw_BangLuong_TongHop`: Tổng hợp quỹ lương theo Phòng Ban / Tháng.
  - `vw_ThueTNCN_KyQuyetToan`: Tổng hợp dữ liệu (tổng thu nhập chịu thuế, tổng các khoản giảm trừ) phục vụ cho quyết toán thuế cuối năm.
- **Chấm công & Chuyên cần:**
  - `vw_TongHopChamCong`: Thống kê tổng số ngày đi làm, nghỉ phép, nghỉ không phép,...
  - `vw_ChamCong_ChiTiet`: Truy xuất chi tiết log chấm công hàng ngày của từng nhân viên.
  - `vw_TyLeChuyenCan`: View đánh giá và theo dõi tỷ lệ chuyên cần theo phòng ban hoặc toàn công ty.

### 5.2. Stored Procedures (23 đối tượng)

Chia làm 4 nhóm chức năng chính bảo phủ toàn bộ quy trình nghiệp vụ:

- **Nhóm 1 - Chấm công (`sp_ChamCong.sql`):** 
  - `sp_ChamCong_NhapHangNgay`, `sp_ChamCong_NhapLoat`, `sp_ChamCong_CapNhat`, `sp_ChamCong_DongBoNghiPhep`, `sp_NghiPhep_PheDuyet`, `sp_ChamCong_BaoCaoThang`.
- **Nhóm 2 - Tính lương (`sp_TinhLuong.sql`, `sp_TinhBHXH_ChiTiet.sql`, `sp_TinhThueTNCN_ChiTiet.sql`):** 
  - `sp_TinhLuong`: Thủ tục cốt lõi thực hiện luồng quy trình chạy lương tổng.
  - `sp_TinhBHXH_ChiTiet`, `sp_TinhThueTNCN_ChiTiet`: Xử lý tính toán và đổ ra chi tiết về bảo hiểm và thuế.
- **Nhóm 3 - Quản lý bảng lương (`sp_TaoBangLuong.sql`):** 
  - `sp_TaoBangLuong_ChinhThuc`, `sp_TaoBangLuong_PhieuLuong`, `sp_TaoBangLuong_BHXH`, `sp_TaoBangLuong_QuyetToanThue`, `sp_TaoBangLuong_SoSanh`, `sp_TaoBangLuong_ChiPhiNhanSu`, `sp_XacNhanBangLuong`, `sp_ThanhToanLuong`.
- **Nhóm 4 - Báo cáo & Thống kê (`sp_BaoCaoNhanSu.sql`):**
  - `sp_BaoCaoNhanSu_TongQuan`, `sp_BaoCaoNhanSu_TheoPhongBan`, `sp_BaoCaoNhanSu_HopDong`, `sp_BaoCaoNhanSu_BienDong`, `sp_BaoCaoNhanSu_LuongPhanPhoi`, `sp_BaoCaoNhanSu_NghiPhepNam`.

### 5.3. Functions (12 đối tượng)

Gói gọn các công thức tài chính và nhân sự thành các hàm (Scalar Functions) giúp tái sử dụng:

- **Logic Ngày làm việc (`fn_SoNgayLamViec.sql`):** 
  - `fn_SoNgayChuanThang`, `fn_SoNgayChamCong`, `fn_SoNgayNghiCoLuong`, `fn_SoNgayNghiKhongLuong`, `fn_HeSoLuongThang`, `fn_TinhLuongLamThem`.
- **Logic Thuế TNCN (`fn_TinhThueTNCN.sql`):**
  - `fn_TinhThueTNCN_Scalar` (tính thuế lũy tiến 7 bậc), `fn_XacDinhBacThue`, `fn_TinhGiamTruPhuThuoc`.
- **Logic Bảo hiểm (`fn_TinhBHXH.sql`):**
  - `fn_TinhLuongDongBH`, `fn_TinhBH_NLD` (tính chi phí Người lao động), `fn_TinhBH_NSDLD` (tính chi phí Người sử dụng lao động).

### 5.4. Triggers (21 đối tượng)

Bảo vệ dữ liệu, kiểm soát tính hợp lệ và tự động lưu vết (Audit Logging) ở tầng thấp nhất:

- **Kiểm soát Nhân viên & Hợp đồng:**
  - `trg_NhanVien_BeforeInsert_CheckTuoi`, `trg_NhanVien_BeforeUpdate_CheckTuoi` (Chặn nhân viên chưa đủ tuổi).
  - Lịch sử hợp đồng: `trg_HopDong_AfterInsert`, `trg_HopDong_AfterUpdate`, `trg_HopDong_AfterDelete`, `trg_HopDong_BeforeUpdate`, `trg_HopDong_BeforeDelete`, `trg_HopDong_CheckOneActive` (Đảm bảo 1 NV chỉ có 1 hợp đồng active).
- **Kiểm soát Lương & Khấu trừ:**
  - Lịch sử Lương cơ bản: `trg_LuongCoBan_AfterInsert`, `trg_LuongCoBan_AfterUpdate`.
  - Toàn vẹn thông tin lương: `trg_LuongCoBan_CheckOneCurrent`, `trg_LuongCoBan_CheckOneCurrent_Update`.
  - Khóa Bảng lương khi đã chốt: `trg_BangLuong_BeforeUpdate`, `trg_BangLuong_BeforeDelete`, `trg_BangLuong_AfterUpdate`.
  - Hợp lệ khấu trừ: `trg_KhauTru_BeforeInsert_NgayHopLe`, `trg_KhauTru_BeforeUpdate_NgayHopLe`.
- **Kiểm soát Chấm công & Nghỉ phép:**
  - Hợp lệ chấm công: `trg_ChamCong_BeforeInsert`, `trg_ChamCong_BeforeUpdate` (Chặn chấm công ngày tương lai).
  - Trùng lịch nghỉ phép: `trg_NghiPhep_CheckOverlap_Insert`, `trg_NghiPhep_CheckOverlap_Update`.

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
