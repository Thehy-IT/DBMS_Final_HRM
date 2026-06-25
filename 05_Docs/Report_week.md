# BÁO CÁO DỰ ÁN MÔN HỆ QUẢN TRỊ CƠ SỞ DỮ LIỆU

## Đề tài: Hệ Thống Quản Lý Nhân Sự và Tính Lương Tự Động (HRPayrollSystem)

---

### 1. Tổng quan

Dự án **HRPayrollSystem** là một hệ thống phần mềm (bao gồm Backend Node.js và Frontend Next.js) phục vụ tự động hóa quy trình quản lý nhân sự và tính lương cho doanh nghiệp.
Đặc biệt, hệ thống được xây dựng theo kiến trúc **Database-Centric** (lấy cơ sở dữ liệu làm trung tâm). Phần lớn logic nghiệp vụ phức tạp (như tính thuế, bảo hiểm, chốt lương, kiểm tra dữ liệu) được đẩy xuống tầng CSDL MySQL dưới dạng Stored Procedures, Functions và Triggers. Việc này đảm bảo tính toàn vẹn dữ liệu tuyệt đối (ACID), hiệu suất cao và khả năng bảo trì tập trung.

### 2. Tác nhân chính

Hệ thống xoay quanh 4 tác nhân chính có phân quyền rõ rệt:

- **Nhân viên (Employee)**: Tương tác với hệ thống để xem thông tin cá nhân, kiểm tra bảng lương hàng tháng, thực hiện chấm công và xin nghỉ phép.
- **Chuyên viên Nhân sự (HR)**: Quản lý hồ sơ nhân viên, duy trì hợp đồng lao động, duyệt đơn xin nghỉ phép, theo dõi báo cáo đi làm (chuyên cần).
- **Kế toán lương (Payroll Admin)**: Khởi chạy quy trình tính lương tự động, quản lý các khoản phụ cấp/khấu trừ, xác nhận chốt bảng lương cuối tháng.
- **Quản trị viên (Admin)**: Toàn quyền cấu hình hệ thống, quản lý tài khoản, phân quyền và phục hồi dữ liệu khi cần.

### 3. Chức năng chính

- **Quản lý Hồ sơ & Hợp đồng**: Thêm, sửa, xóa (soft-delete) thông tin nhân sự; quản lý vòng đời hợp đồng, lịch sử nâng lương.
- **Quản lý Chấm công & Nghỉ phép**: Ghi nhận giờ làm việc, kiểm tra trùng lặp ngày nghỉ, tự động tính ra ngày công chuẩn làm cơ sở tính lương.
- **Tính lương tự động**: Quy trình 8 bước biến Lương Gross thành Net. Tự động tính thuế Thu nhập cá nhân (TNCN) lũy tiến 7 bậc, tự động trừ các khoản BHXH, BHYT, BHTN theo đúng quy định pháp luật.
- **Báo cáo thống kê**: Cung cấp các biểu đồ, số liệu về quỹ lương, tỷ lệ nhân sự biến động, chuyên cần trực quan.

### 4. Giao tác (Transactions)

Hệ thống sử dụng Giao tác để bọc các nghiệp vụ cập nhật nhiều bảng cùng lúc, đảm bảo nguyên tắc ACID (Atomicity, Consistency, Isolation, Durability). Quá trình này được đặt trong một transaction. Nếu lỗi xảy ra, toàn bộ sẽ `ROLLBACK`, nếu thành công trọn vẹn thì `COMMIT`.

📍 **Danh sách TOÀN BỘ các vị trí áp dụng Giao tác (`START TRANSACTION`) trong hệ thống**:

- **Bọc xử lý logic tính lương**: `02_Database/StoredProcedures/sp_TinhLuong.sql` (Dòng 275).
- **Bọc dữ liệu mẫu an toàn (Seed Data)**: `02_Database/DML/seed_data.sql` (Tại các dòng: 11, 86, 171, 263, 355, 553, 4341, 4470, 4492, 4504).
- **Tiếp nhận nhân sự mới (Onboarding)**: `02_Database/StoredProcedures/sp_TiepNhanNhanSu.sql` (Dòng 55). Bọc việc tạo Nhân viên, Hợp đồng, Lương cơ bản, Tài khoản.
- **Nghỉ việc / Thanh lý hợp đồng (Offboarding)**: `02_Database/StoredProcedures/sp_NghiViec.sql` (Dòng 26). Chốt sổ toàn bộ trạng thái và vô hiệu hóa tài khoản.
- **Điều chuyển / Thăng chức**: `02_Database/StoredProcedures/sp_DieuChuyenThangChuc.sql` (Dòng 29). Đảm bảo liền mạch lịch sử lương và chức vụ.
- **Duyệt đơn nghỉ phép liền mạch**: `02_Database/StoredProcedures/sp_ChamCong.sql` (Dòng 354, trong thủ tục `sp_NghiPhep_PheDuyet`). Tự động sinh bản ghi chấm công.
- **Chốt và thanh toán bảng lương**: `02_Database/StoredProcedures/sp_ChotBangLuong.sql` (Dòng 25). Cập nhật trạng thái lương và các khoản khấu trừ đồng thời.

---

### 5. Các mục (Đối tượng CSDL áp dụng)

Hệ thống áp dụng triệt để các đối tượng Database để xử lý nghiệp vụ. Dưới đây là liệt kê **TOÀN BỘ CHI TIẾT** danh sách và vị trí file code trong hệ thống:

#### 5.1. View (7 Views)

- **Mục đích**: Ẩn đi sự phức tạp của truy vấn JOIN nhiều bảng, cung cấp cấu trúc bảng ảo phục vụ nhanh cho việc đọc từ Backend, đồng thời bảo mật các cột nhạy cảm.
- **Danh sách chi tiết**:
  - `vw_HoSoNhanVien_ChiTiet`: 📍 `02_Database/Views/vw_HoSoNhanVien_ChiTiet.sql` (Dòng 12). Tổng hợp hồ sơ, hợp đồng và lương hiện tại.
  - `vw_BangLuong`: 📍 `02_Database/Views/vw_BangLuong.sql` (Dòng 20).
  - `vw_BangLuong_TongHop`: 📍 `02_Database/Views/vw_BangLuong.sql` (Dòng 105).
  - `vw_ThueTNCN_KyQuyetToan`: 📍 `02_Database/Views/vw_BangLuong.sql` (Dòng 157).
  - `vw_TongHopChamCong`: 📍 `02_Database/Views/vw_TongHopChamCong.sql` (Dòng 19).
  - `vw_ChamCong_ChiTiet`: 📍 `02_Database/Views/vw_TongHopChamCong.sql` (Dòng 75).
  - `vw_TyLeChuyenCan`: 📍 `02_Database/Views/vw_TongHopChamCong.sql` (Dòng 115).

#### 5.2. Store Procedures (27 Thủ tục lưu trữ)

- **Mục đích**: Đóng gói các logic xử lý dữ liệu phức tạp nhiều bước thành một lời gọi duy nhất từ Application, giảm thiểu độ trễ mạng và tăng hiệu suất.
- **Danh sách chi tiết**:
  - **Quản lý Nhân sự (Giao tác vòng đời)**:
    - `sp_TiepNhanNhanSu`: 📍 `02_Database/StoredProcedures/sp_TiepNhanNhanSu.sql` (Dòng 13).
    - `sp_NghiViec`: 📍 `02_Database/StoredProcedures/sp_NghiViec.sql` (Dòng 13).
    - `sp_DieuChuyenThangChuc`: 📍 `02_Database/StoredProcedures/sp_DieuChuyenThangChuc.sql` (Dòng 13).
  - **Báo cáo nhân sự**:
    - `sp_BaoCaoNhanSu_TongQuan`: 📍 `02_Database/StoredProcedures/sp_BaoCaoNhanSu.sql` (Dòng 25).
    - `sp_BaoCaoNhanSu_TheoPhongBan`: 📍 `02_Database/StoredProcedures/sp_BaoCaoNhanSu.sql` (Dòng 125).
    - `sp_BaoCaoNhanSu_HopDong`: 📍 `02_Database/StoredProcedures/sp_BaoCaoNhanSu.sql` (Dòng 169).
    - `sp_BaoCaoNhanSu_BienDong`: 📍 `02_Database/StoredProcedures/sp_BaoCaoNhanSu.sql` (Dòng 223).
    - `sp_BaoCaoNhanSu_LuongPhanPhoi`: 📍 `02_Database/StoredProcedures/sp_BaoCaoNhanSu.sql` (Dòng 285).
    - `sp_BaoCaoNhanSu_NghiPhepNam`: 📍 `02_Database/StoredProcedures/sp_BaoCaoNhanSu.sql` (Dòng 353).
  - **Chấm công**:
    - `sp_ChamCong_NhapHangNgay`: 📍 `02_Database/StoredProcedures/sp_ChamCong.sql` (Dòng 24).
    - `sp_ChamCong_NhapLoat`: 📍 `02_Database/StoredProcedures/sp_ChamCong.sql` (Dòng 119).
    - `sp_ChamCong_CapNhat`: 📍 `02_Database/StoredProcedures/sp_ChamCong.sql` (Dòng 195).
    - `sp_ChamCong_DongBoNghiPhep`: 📍 `02_Database/StoredProcedures/sp_ChamCong.sql` (Dòng 249).
    - `sp_NghiPhep_PheDuyet`: 📍 `02_Database/StoredProcedures/sp_ChamCong.sql` (Dòng 312).
    - `sp_ChamCong_BaoCaoThang`: 📍 `02_Database/StoredProcedures/sp_ChamCong.sql` (Dòng 404).
  - **Bảng lương**:
    - `sp_TaoBangLuong_ChinhThuc`: 📍 `02_Database/StoredProcedures/sp_TaoBangLuong.sql` (Dòng 24).
    - `sp_TaoBangLuong_PhieuLuong`: 📍 `02_Database/StoredProcedures/sp_TaoBangLuong.sql` (Dòng 119).
    - `sp_TaoBangLuong_BHXH`: 📍 `02_Database/StoredProcedures/sp_TaoBangLuong.sql` (Dòng 199).
    - `sp_TaoBangLuong_QuyetToanThue`: 📍 `02_Database/StoredProcedures/sp_TaoBangLuong.sql` (Dòng 270).
    - `sp_TaoBangLuong_SoSanh`: 📍 `02_Database/StoredProcedures/sp_TaoBangLuong.sql` (Dòng 317).
    - `sp_TaoBangLuong_ChiPhiNhanSu`: 📍 `02_Database/StoredProcedures/sp_TaoBangLuong.sql` (Dòng 355).
    - `sp_XacNhanBangLuong`: 📍 `02_Database/StoredProcedures/sp_TaoBangLuong.sql` (Dòng 417).
    - `sp_ThanhToanLuong`: 📍 `02_Database/StoredProcedures/sp_TaoBangLuong.sql` (Dòng 459).
    - `sp_ChotBangLuong`: 📍 `02_Database/StoredProcedures/sp_ChotBangLuong.sql` (Dòng 13).
  - **Tính toán Lõi**:
    - `sp_TinhBHXH_ChiTiet`: 📍 `02_Database/StoredProcedures/sp_TinhBHXH_ChiTiet.sql` (Dòng 14).
    - `sp_TinhLuong`: 📍 `02_Database/StoredProcedures/sp_TinhLuong.sql` (Dòng 27).
    - `sp_TinhThueTNCN_ChiTiet`: 📍 `02_Database/StoredProcedures/sp_TinhThueTNCN_ChiTiet.sql` (Dòng 13).

#### 5.3. Functions (13 Hàm)

- **Mục đích**: Tính toán và trả về các giá trị vô hướng (scalar), dễ dàng tái sử dụng trong các vòng lặp hoặc truy vấn SELECT.
- **Danh sách chi tiết**:
  - **Quản lý Nhân sự**:
    - `fn_TinhThamNien`: 📍 `02_Database/Functions/fn_TinhThamNien.sql` (Dòng 13).
  - **Ngày làm việc**:
    - `fn_SoNgayChuanThang`: 📍 `02_Database/Functions/fn_SoNgayLamViec.sql` (Dòng 22).
    - `fn_SoNgayChamCong`: 📍 `02_Database/Functions/fn_SoNgayLamViec.sql` (Dòng 77).
    - `fn_SoNgayNghiCoLuong`: 📍 `02_Database/Functions/fn_SoNgayLamViec.sql` (Dòng 110).
    - `fn_SoNgayNghiKhongLuong`: 📍 `02_Database/Functions/fn_SoNgayLamViec.sql` (Dòng 142).
    - `fn_HeSoLuongThang`: 📍 `02_Database/Functions/fn_SoNgayLamViec.sql` (Dòng 175).
    - `fn_TinhLuongLamThem`: 📍 `02_Database/Functions/fn_SoNgayLamViec.sql` (Dòng 213).
  - **Bảo hiểm**:
    - `fn_TinhLuongDongBH`: 📍 `02_Database/Functions/fn_TinhBHXH.sql` (Dòng 21).
    - `fn_TinhBH_NLD`: 📍 `02_Database/Functions/fn_TinhBHXH.sql` (Dòng 54).
    - `fn_TinhBH_NSDLD`: 📍 `02_Database/Functions/fn_TinhBHXH.sql` (Dòng 84).
  - **Thuế TNCN**:
    - `fn_TinhThueTNCN_Scalar`: 📍 `02_Database/Functions/fn_TinhThueTNCN.sql` (Dòng 16).
    - `fn_XacDinhBacThue`: 📍 `02_Database/Functions/fn_TinhThueTNCN.sql` (Dòng 86).
    - `fn_TinhGiamTruPhuThuoc`: 📍 `02_Database/Functions/fn_TinhThueTNCN.sql` (Dòng 116).

#### 5.4. Triggers (23 Trình kích hoạt)

- **Mục đích**: Tự động thực thi các kiểm tra (Validation) phức tạp hoặc ghi nhận lại nhật ký (Audit Trail) khi có sự kiện thay đổi dữ liệu (DML).
- **Danh sách chi tiết**:
  - **Bảo vệ Kiểm toán**:
    - `trg_BangLuong_BeforeUpdate_Protect`: 📍 `02_Database/Triggers/trg_BangLuong_Protect_DaChot.sql` (Dòng 15). Chặn sửa dữ liệu bảng lương đã thanh toán.
    - `trg_BangLuong_BeforeDelete_Protect`: 📍 `02_Database/Triggers/trg_BangLuong_Protect_DaChot.sql` (Dòng 40). Chặn xóa bảng lương đã thanh toán.
  - **Kiểm tra tuổi nhân viên**:
    - `trg_NhanVien_BeforeInsert_CheckTuoi`: 📍 `02_Database/Triggers/trg_NhanVien_CheckTuoi.sql` (Dòng 14).
    - `trg_NhanVien_BeforeUpdate_CheckTuoi`: 📍 `02_Database/Triggers/trg_NhanVien_CheckTuoi.sql` (Dòng 37).
  - **Khấu trừ hợp lệ**:
    - `trg_KhauTru_BeforeInsert_NgayHopLe`: 📍 `02_Database/Triggers/trg_KhauTru_Validate.sql` (Dòng 12).
    - `trg_KhauTru_BeforeUpdate_NgayHopLe`: 📍 `02_Database/Triggers/trg_KhauTru_Validate.sql` (Dòng 27).
  - **Chấm công**:
    - `trg_ChamCong_BeforeInsert`: 📍 `02_Database/Triggers/trg_KiemTraChamCong.sql` (Dòng 20).
    - `trg_ChamCong_BeforeUpdate`: 📍 `02_Database/Triggers/trg_KiemTraChamCong.sql` (Dòng 62).
  - **Log Hợp đồng & Bảo vệ dữ liệu**:
    - `trg_HopDong_AfterInsert`: 📍 `02_Database/Triggers/trg_LogHopDong.sql` (Dòng 23).
    - `trg_HopDong_AfterUpdate`: 📍 `02_Database/Triggers/trg_LogHopDong.sql` (Dòng 57).
    - `trg_HopDong_AfterDelete`: 📍 `02_Database/Triggers/trg_LogHopDong.sql` (Dòng 120).
    - `trg_HopDong_BeforeUpdate`: 📍 `02_Database/Triggers/trg_LogHopDong.sql` (Dòng 150).
    - `trg_HopDong_BeforeDelete`: 📍 `02_Database/Triggers/trg_LogHopDong.sql` (Dòng 174).
    - `trg_HopDong_CheckOneActive`: 📍 `02_Database/Triggers/trg_LogHopDong.sql` (Dòng 194).
  - **Log & Bảo vệ Bảng lương/Lương cơ bản**:
    - `trg_LuongCoBan_AfterInsert`: 📍 `02_Database/Triggers/trg_LogLuong.sql` (Dòng 20).
    - `trg_LuongCoBan_AfterUpdate`: 📍 `02_Database/Triggers/trg_LogLuong.sql` (Dòng 56).
    - `trg_BangLuong_BeforeUpdate`: 📍 `02_Database/Triggers/trg_LogLuong.sql` (Dòng 104).
    - `trg_BangLuong_BeforeDelete`: 📍 `02_Database/Triggers/trg_LogLuong.sql` (Dòng 139).
    - `trg_BangLuong_AfterUpdate`: 📍 `02_Database/Triggers/trg_LogLuong.sql` (Dòng 158).
    - `trg_LuongCoBan_CheckOneCurrent`: 📍 `02_Database/Triggers/trg_LuongCoBan_CheckOneCurrent.sql` (Dòng 13).
    - `trg_LuongCoBan_CheckOneCurrent_Update`: 📍 `02_Database/Triggers/trg_LuongCoBan_CheckOneCurrent.sql` (Dòng 34).
  - **Nghỉ phép (Tránh trùng lặp)**:
    - `trg_NghiPhep_CheckOverlap_Insert`: 📍 `02_Database/Triggers/trg_NghiPhep_CheckOverlap.sql` (Dòng 11).
    - `trg_NghiPhep_CheckOverlap_Update`: 📍 `02_Database/Triggers/trg_NghiPhep_CheckOverlap.sql` (Dòng 35).

---

### 6. Các vấn đề đồng thời (Concurrency Anomalies) & Cách khắc phục đặc trưng trong HRPayrollSystem

*(Khi demo, chúng ta sẽ dùng hàm `DO SLEEP(5);` trong MySQL lồng vào giữa các Stored Procedures để cố tình làm trễ giao dịch, nhằm tạo đủ thời gian kích hoạt các lỗi đồng thời mang tính đặc thù của hệ thống).*

#### 6.1. Mất dữ liệu cập nhật (Lost Update) - Cạnh tranh cập nhật phụ cấp & khấu trừ

- **Ngữ cảnh đặc trưng**: Kế toán A đang xử lý nhập "Phụ cấp dự án" (cộng 2.000.000đ) cho nhân viên X. Cùng lúc, Kế toán B nhận được báo cáo vi phạm và nhập "Khấu trừ đi trễ" (trừ 500.000đ) cũng cho nhân viên X. Cả hai cùng mở giao diện, cùng tải dữ liệu `BangLuong` hiện tại. Kế toán A lưu trước, Kế toán B lưu sau. Do B không biết cập nhật của A, hệ thống lưu đè bản ghi khiến nhân viên X bị mất oan khoản phụ cấp 2 triệu.
- **Demo bằng Sleep**:
  - Transaction 1 (TX1 - Kế toán A): `SELECT TongPhuCap FROM BangLuong...` (Lấy ra 0đ). Chờ `SLEEP(5)`.
  - Transaction 2 (TX2 - Kế toán B): `SELECT TongKhauTru FROM BangLuong...` (Lấy ra 0đ) -> Cập nhật `TongKhauTru = 500000` -> `COMMIT`.
  - TX1 thức dậy: Dựa trên dữ liệu cũ, cập nhật `TongPhuCap = 2000000` và lưu đè. Các thông tin khác (bao gồm khấu trừ 500k của TX2) bị trả về nguyên trạng.
- **Cách khắc phục**: Áp dụng Khóa bi quan (Pessimistic Locking) bằng `SELECT ... FOR UPDATE` để ép TX2 phải chờ TX1 ghi xong. Hoặc đổi logic Update thành câu lệnh Update tương đối: `UPDATE BangLuong SET TongPhuCap = TongPhuCap + 2000000`.

#### 6.2. Đọc dữ liệu rác (Dirty Read) - Hệ lụy từ Giao tác Onboarding

- **Ngữ cảnh đặc trưng**: Hệ thống đang chạy Giao tác `sp_TiepNhanNhanSu` (Onboarding) rất dài (tạo Nhân sự, Hợp đồng, Lương cơ bản, Tài khoản). Vừa tạo xong thông tin Nhân sự và Lương thì gọi SLEEP. Lúc này, Giám đốc chạy `sp_BaoCaoNhanSu_TongQuan` để xem tổng chi phí quỹ lương dự kiến và hệ thống tính gộp cả nhân viên mới này vào. Đột ngột, bước tạo Tài khoản ở cuối thủ tục Onboarding bị lỗi (ví dụ: trùng email), toàn bộ `sp_TiepNhanNhanSu` bị `ROLLBACK`. Giám đốc đang cầm trên tay báo cáo tài chính chứa quỹ lương của một người không hề tồn tại.
- **Demo bằng Sleep**:
  - (Chỉnh Isolation TX2 về `READ UNCOMMITTED`).
  - TX1 (`sp_TiepNhanNhanSu`): `INSERT NhanVien`, `INSERT LuongCoBan` = 25tr. Đang `SLEEP(5)`.
  - TX2 (`sp_BaoCaoNhanSu_TongQuan`): Đọc và Sum tổng quỹ lương -> Thấy tăng thêm 25tr.
  - TX1: Lỗi `INSERT TaiKhoan` -> Gọi `ROLLBACK`. Dữ liệu nhân viên 25tr biến mất.
- **Cách khắc phục**: Nâng mức cô lập lên `READ COMMITTED` hoặc `REPEATABLE READ` (mặc định của InnoDB). Báo cáo của Giám đốc sẽ chỉ đọc dữ liệu từ các giao dịch đã thực sự `COMMIT`.

#### 6.3. Không đọc lại được dữ liệu (Non-repeatable Read) - Sai lệch trong quy trình tính lương 8 bước

- **Ngữ cảnh đặc trưng**: Giao tác `sp_TinhLuong` đang chạy để biến Lương Gross thành Net. Ở bước 1, thủ tục lấy `LuongCoBan` là 20 triệu để làm cơ sở tính BHXH (8%). Sau đó giao dịch SLEEP. Cùng lúc, HR thực hiện `sp_DieuChuyenThangChuc` nâng mức lương của nhân viên này lên 30 triệu và `COMMIT`. Khi `sp_TinhLuong` tỉnh dậy và chạy tới bước 5 (Tính Thuế TNCN), nó đọc lại `LuongCoBan` thì bất ngờ nhận giá trị 30 triệu. **Hệ quả cực kỳ nghiêm trọng**: Thuế TNCN bị tính ở mức thu nhập 30 triệu, trong khi BHXH lại chỉ trích ở mức 20 triệu, phá vỡ hoàn toàn logic công thức tính của kỳ lương đó.
- **Demo bằng Sleep**:
  - (Chỉnh Isolation TX1 về `READ COMMITTED`).
  - TX1 (`sp_TinhLuong`): Đọc `LuongCoBan` -> 20tr. Tính BHXH. Đang `SLEEP(5)`.
  - TX2 (`sp_DieuChuyenThangChuc`): `UPDATE LuongCoBan` lên 30tr -> `COMMIT`.
  - TX1: Đọc lại `LuongCoBan` để tính Thuế TNCN -> Lấy ra 30tr (Khác với dòng đọc ở trên).
- **Cách khắc phục**: Sử dụng mức `REPEATABLE READ`. Nhờ cơ chế MVCC (Multi-Version Concurrency Control), toàn bộ các dòng SELECT trong suốt vòng đời của `sp_TinhLuong` sẽ chỉ nhìn thấy một snapshot dữ liệu duy nhất tại thời điểm bắt đầu giao dịch, bảo toàn tính nhất quán của công thức.

#### 6.4. Bóng ma (Phantom Read) - Chốt sổ thanh lý hợp đồng lọt vào giữa kỳ chốt lương

- **Ngữ cảnh đặc trưng**: Kế toán gọi `sp_ChotBangLuong` duyệt danh sách bảng lương tháng này của phòng Kỹ Thuật (trạng thái 'DRAFT') để chốt sang 'PAID' và xuất quỹ. Truy vấn đầu tiên đếm được 50 nhân viên. Đang chờ xử lý kết toán (SLEEP). Cùng lúc, HR chạy `sp_NghiViec` cho một nhân viên phòng Kỹ Thuật. Logic của thủ tục nghỉ việc sẽ tự động sinh thêm 1 bản ghi `BangLuong` trạng thái 'DRAFT' (để thanh toán những ngày làm dở dang) và `COMMIT`. Khi `sp_ChotBangLuong` tỉnh dậy và thực hiện Update chốt lương, nó cập nhật trúng 51 bản ghi. Quỹ thực chi bị lẹm 1 dòng thanh toán nghỉ việc bất ngờ ngoài dự toán ban đầu.
- **Demo bằng Sleep**:
  - TX1 (`sp_ChotBangLuong`): `SELECT COUNT(*) FROM BangLuong WHERE TrangThai = 'DRAFT';` -> Ra 50 dòng. `SLEEP(5)`.
  - TX2 (`sp_NghiViec`): Tự động `INSERT INTO BangLuong (...) VALUES (..., 'DRAFT')` -> `COMMIT`.
  - TX1: Thực thi `UPDATE BangLuong SET TrangThai = 'PAID' WHERE TrangThai = 'DRAFT';` -> Báo cáo Affected Rows là 51.
- **Cách khắc phục**: Sử dụng mức `SERIALIZABLE` hoặc dùng Next-Key Locking với `SELECT ... FOR UPDATE` trên bảng `BangLuong`. Lúc này, giao dịch `sp_NghiViec` sẽ bị block lại (không thể `INSERT` thêm dòng 'DRAFT' mới) cho đến khi `sp_ChotBangLuong` thực hiện xong.

#### 6.5. Khuyến Nghị Chiến Lược Tối Ưu Nhất Cho Hệ Thống

Dựa trên phân tích các vấn đề đồng thời mang tính đặc thù trên, chiến lược điều khiển tương tranh **tốt nhất** cho dự án HRPayrollSystem là sự kết hợp giữa **Sơ đồ Đa phiên bản (MVCC)** và **Khóa ở quy mô Bản ghi (Row-level Locking) / Kỹ thuật Xác nhận (Optimistic Locking)**.

**Lý do lựa chọn chiến lược này (Góc độ Kiến trúc sư CSDL):**

1. **Khắc phục "Nghẽn cổ chai" nhờ MVCC**: Đặc thù hệ thống là các khối tính lương và báo cáo mất rất nhiều thời gian duyệt hàng ngàn bản ghi. Trong kiến trúc MVCC, các tác vụ tính lương/báo cáo sẽ đọc một Snapshot tĩnh (phiên bản cũ) mà không chặn các chuyên viên HR cập nhật dữ liệu mới ("Người đọc không bao giờ chặn người ghi"). Điều này giúp hệ thống đạt độ tương tranh cực cao.
2. **Bảo vệ toàn vẹn logic bằng REPEATABLE READ**: Chạy các Stored Procedures tính lương ở mức độ cô lập `REPEATABLE READ` giúp dữ liệu tham chiếu để tính thuế, bảo hiểm, lương cơ bản xuyên suốt quá trình tính toán của một nhân viên được bảo đảm hoàn toàn nhất quán, chặn đứng hiện tượng Non-repeatable Read và Dirty Read.
3. **Quản lý linh hoạt xung đột cập nhật (Lost Update)**:
   - Với các Giao dịch tự động (Store Procedures) chạy ngầm có xung đột cao: Sử dụng **Bi quan (Pessimistic Locking / Strict 2PL)** qua lệnh `SELECT ... FOR UPDATE` hoặc các hàm Update cộng dồn tương đối.
   - Với thao tác nhập liệu của người dùng trên Giao diện UI: Sử dụng **Lạc quan (Optimistic Locking / Validation)** bằng cơ chế kiểm tra biến `Version` hoặc `UpdatedAt`. Cách này giúp tối ưu chi phí cấp khóa vì xác suất đụng độ trên cùng một field của cùng một hồ sơ nhân sự trong một thời điểm là rất thấp.

---

### 7. Hướng dẫn chi tiết thao tác Demo Thực Hành (Giao diện & CSDL)

Phần này cung cấp kịch bản từng bước để hội đồng và giảng viên thấy rõ các lỗi đồng thời xảy ra như thế nào từ cả góc nhìn người dùng cuối (Giao diện Frontend) và góc độ hệ thống (CSDL).

#### 7.1. Chuẩn bị môi trường Demo

- **Bước 1**: Mở trình duyệt web. Đăng nhập bằng 2 tài khoản Kế toán/HR khác nhau trên 2 cửa sổ ẩn danh (Incognito) để giả lập 2 phiên làm việc độc lập của người dùng.
- **Bước 2**: Mở MySQL Workbench (hoặc DBeaver), mở 2 tab Query Editor đại diện cho 2 tiến trình (Transaction 1 và Transaction 2).
- **Bước 3**: Để dễ quan sát lỗi, chèn tạm thời lệnh `DO SLEEP(7);` vào giữa các Stored Procedure cốt lõi (như `sp_TinhLuong`, `sp_ChotBangLuong`) để ép hệ thống "treo" vài giây, tạo khe hở thời gian cho giao dịch thứ 2 xen vào.

#### 7.2. Thao tác Demo: Lost Update (Mất dữ liệu cập nhật)

- **Ngữ cảnh**: Kế toán A và Kế toán B cùng cập nhật lương cho Nhân viên X.
- **Thao tác trên Giao diện**:
  1. Cửa sổ 1 (Kế toán A) và Cửa sổ 2 (Kế toán B) cùng mở trang "Chi tiết Bảng Lương tháng 5" của Nhân viên X. Cả 2 màn hình đều đang hiển thị: *Phụ cấp = 0đ, Khấu trừ = 0đ*.
  2. Tại Cửa sổ 1, Kế toán A nhập số tiền Phụ cấp dự án: `2.000.000đ`.
  3. Tại Cửa sổ 2, Kế toán B nhập số tiền Khấu trừ đi trễ: `500.000đ`.
  4. Kế toán A bấm nút "Lưu". Màn hình báo thành công.
  5. Kế toán B (chậm tay hơn 1-2 giây) cũng bấm nút "Lưu".
  6. **Kết quả Lỗi**: Tải lại (Refresh) trang chi tiết lương. Thông tin hiển thị chỉ còn *Khấu trừ = 500.000đ*, khoản *Phụ cấp 2.000.000đ* đã hoàn toàn biến mất (vì hệ thống của B đã ghi đè toàn bộ bản ghi cũ).
- **Thao tác Khắc phục**:
  - Mở mã nguồn Backend (API Cập nhật lương) hoặc Stored Procedure.
  - **Cách 1 (Khóa bi quan)**: Sửa câu lệnh truy vấn lấy dữ liệu thành `SELECT ... FOR UPDATE`. Lúc này khi làm lại thao tác trên, nút "Lưu" của Kế toán B sẽ bị xoay (loading) chờ cho đến khi Kế toán A lưu xong.
  - **Cách 2 (Cập nhật tương đối)**: Đổi logic Update thành `UPDATE BangLuong SET TongPhuCap = TongPhuCap + ?, TongKhauTru = TongKhauTru + ?`. Cả 2 khoản tiền sẽ được cộng dồn chính xác.

#### 7.3. Thao tác Demo: Dirty Read (Đọc dữ liệu rác)

- **Ngữ cảnh**: Giám đốc xem nhầm quỹ lương từ một nhân viên chưa được duyệt Onboarding hoàn chỉnh.
- **Thao tác trên CSDL & Giao diện**:
  1. **Trên MySQL (Tab 1)**: Đặt mức cô lập xuống thấp nhất bằng lệnh: `SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;`
  2. Khởi chạy một phần giao dịch Onboarding: `START TRANSACTION; INSERT INTO LuongCoBan (NhanVienID, LuongCoBan) VALUES (999, 25000000); DO SLEEP(8);` (Giả lập hệ thống đang tạo Tài khoản).
  3. **Trên Giao diện Giám đốc (Trình duyệt)**: Trong lúc Tab 1 đang Sleep, lập tức nhấn nút "Xuất Báo Cáo Quỹ Lương".
  4. **Kết quả Lỗi**: Biểu đồ và Excel xuất ra cho thấy tổng quỹ lương đã bị đội thêm 25.000.000đ.
  5. **Trên MySQL (Tab 1)**: Gọi lệnh `ROLLBACK;` (Giả lập quá trình Onboarding bị lỗi). Nhân viên 999 chưa từng được tạo ra, nhưng Giám đốc đã cầm báo cáo có con số 25 triệu ảo.
- **Thao tác Khắc phục**:
  - Trở lại MySQL, nâng mức cô lập lên chuẩn: `SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;` (hoặc `REPEATABLE READ`).
  - Làm lại thao tác tương tự. Lần này, khi Giám đốc nhấn xuất báo cáo trong lúc Tab 1 đang Sleep, hệ thống sẽ bỏ qua bản ghi 25 triệu chưa được COMMIT, đảm bảo dữ liệu luôn chính xác.

#### 7.4. Thao tác Demo: Non-repeatable Read & Phantom Read

- **Thao tác CSDL (Tương tự Dirty Read)**:
  - Khởi chạy một Transaction 1 có chứa `DO SLEEP(10);` (Giả lập `sp_TinhLuong` hoặc `sp_ChotBangLuong`).
  - Trong lúc TX1 đang treo, mở Transaction 2 chạy lệnh `UPDATE` (Đổi mức lương) hoặc `INSERT` (Thêm nhân viên nghỉ việc) rồi `COMMIT` ngay lập tức.
  - Khi TX1 tỉnh dậy và tiếp tục chạy lệnh SELECT hoặc UPDATE diện rộng, hội đồng sẽ thấy dữ liệu tính toán ở nửa sau của TX1 đã bị sai lệch so với nửa đầu (do tác động của TX2).
- **Thao tác Khắc phục**:
  - Sử dụng lệnh `SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;` để khắc phục Non-repeatable Read (MVCC sẽ cấp cho TX1 một bản snapshot cố định).
  - Sử dụng lệnh `SET SESSION TRANSACTION ISOLATION LEVEL SERIALIZABLE;` để khắc phục Phantom Read (TX2 khi gọi INSERT sẽ lập tức bị Block/Loading mỏi mòn chờ TX1 thực thi xong).

---

### 8. Deadlock (Khóa chết)

- **Định nghĩa**: Hai (hoặc nhiều) giao dịch đang giữ khóa tài nguyên và chờ đợi tài nguyên mà bên kia đang giữ, dẫn đến một vòng lặp chờ đợi vô tận.
- **Ngữ cảnh Demo**:
  - TX1: Bắt đầu xử lý cho Nhân viên X -> Lấy Khóa cập nhật bảng `HopDong`. Đang SLEEP.
  - TX2: Bắt đầu xử lý lương cho Nhân viên X -> Lấy Khóa cập nhật bảng `LuongCoBan`. Đang SLEEP.
  - TX1 thức dậy: Cần cập nhật bảng `LuongCoBan` -> Bị Block (Chờ TX2 nhả khóa).
  - TX2 thức dậy: Cần cập nhật bảng `HopDong` -> Bị Block (Chờ TX1 nhả khóa).
    -> **Hậu quả**: MySQL phát hiện vòng lặp deadlock và buộc phải "giết" (kill) một trong hai transaction (kèm theo thông báo lỗi `Error 1213: Deadlock found`), transaction còn lại sẽ được tiếp tục.
- **Cách khắc phục**:
  1. **Quy tắc thứ tự khóa**: Luôn yêu cầu Backend/Stored Procedures phải truy cập các bảng theo một thứ tự nhất định, ví dụ luôn cập nhật `HopDong` trước rồi mới tới `LuongCoBan` trong mọi nghiệp vụ.
  2. **Thời gian khóa cực ngắn**: Tối ưu index và cấu trúc truy vấn để khóa diễn ra nhanh nhất, giảm thời gian giao dịch.
  3. **Xử lý ứng dụng (Retry)**: Bắt lỗi Deadlock ở phía Application Node.js (try...catch) và tự động thực thi lại transaction bị hủy sau vài phần nghìn giây.

---

### 9. Báo Cáo Chi Tiết Các Đối Tượng CSDL Chính (Dùng Cho Báo Cáo Tuần)

Dưới đây là chi tiết 2 đối tượng tiêu biểu cho từng loại (Giao tác, View, Store Procedure, Function, Trigger) để trình bày nhanh trong các buổi báo cáo tiến độ hàng tuần.

#### 9.1. Giao tác (Transactions)

1. **`sp_TiepNhanNhanSu` (Onboarding Transaction)**
   - **Vị trí file**: `02_Database/StoredProcedures/sp_TiepNhanNhanSu.sql`
   - **Mục đích**: Đảm bảo quy trình tiếp nhận nhân sự mới tuân thủ tính toàn vẹn dữ liệu (ACID).
   - **Chi tiết**: Giao tác bọc 4 lệnh `INSERT` liên tiếp vào các bảng: `NhanVien`, `HopDong`, `LuongCoBan`, và `TaiKhoan`. Cấu hình `DECLARE EXIT HANDLER FOR SQLEXCEPTION` sẽ bắt mọi lỗi xảy ra; nếu bất kỳ bước nào thất bại, toàn bộ tiến trình sẽ `ROLLBACK` để tránh rác dữ liệu. Nếu thành công sẽ `COMMIT`.
2. **`sp_ChotBangLuong` (Payroll Confirmation Transaction)**
   - **Vị trí file**: `02_Database/StoredProcedures/sp_ChotBangLuong.sql`
   - **Mục đích**: Chốt và thanh toán bảng lương cuối kỳ đồng bộ.
   - **Chi tiết**: Cập nhật đồng thời trạng thái bảng `BangLuong` sang 'P' (Đã thanh toán) và các khoản khấu trừ trong bảng `KhauTru` sang 'A' (Đã áp dụng). Việc đặt vào `START TRANSACTION` giúp hệ thống không gặp tình trạng bảng lương đã chốt nhưng khấu trừ vẫn treo nháp.

#### 9.2. Views (Bảng ảo)

1. **`vw_HoSoNhanVien_ChiTiet`**
   - **Vị trí file**: `02_Database/Views/vw_HoSoNhanVien_ChiTiet.sql`
   - **Mục đích**: Tối ưu hóa truy vấn hiển thị danh sách nhân sự trên giao diện Backend.
   - **Chi tiết**: View này gom dữ liệu thông qua việc `JOIN` bảng `NhanVien` với `PhongBan` và `ChucVu`. Quan trọng nhất, nó dùng `LEFT JOIN` với bảng `HopDong` và `LuongCoBan` đi kèm bộ lọc (chỉ lấy Hợp đồng trạng thái Active và Lương hiệu lực) giúp Frontend không phải gọi nhiều API.
2. **`vw_BangLuong_TongHop`**
   - **Vị trí file**: `02_Database/Views/vw_BangLuong.sql` (Từ dòng 105)
   - **Mục đích**: Cung cấp nguồn dữ liệu sạch để xuất biểu đồ và Excel báo cáo quỹ lương phòng ban.
   - **Chi tiết**: Gộp nhóm (`GROUP BY`) theo tháng, năm và tên phòng ban. Tự động dùng các hàm tính tổng (`SUM`) để trả ra: Tổng lương Gross, Bảo hiểm NSDLĐ phải đóng, Tổng thuế TNCN và Tổng chi phí nhân sự thực tế.

#### 9.3. Store Procedures (Thủ tục lưu trữ)

1. **`sp_TinhLuong`**
   - **Vị trí file**: `02_Database/StoredProcedures/sp_TinhLuong.sql`
   - **Mục đích**: Xử lý logic nghiệp vụ tính lương cốt lõi, chạy định kỳ hàng tháng.
   - **Chi tiết**: Thủ tục chạy qua một quy trình 8 bước biến Lương Gross thành Lương Net: lấy số ngày công chuẩn, cộng lương tăng ca, tính phụ cấp, tính các khoản bảo hiểm bắt buộc trừ vào lương, trừ thuế TNCN lũy tiến, và trừ các khoản khấu trừ phát sinh để ra thực lĩnh.
2. **`sp_NghiViec`**
   - **Vị trí file**: `02_Database/StoredProcedures/sp_NghiViec.sql`
   - **Mục đích**: Đóng gói quy trình thanh lý hợp đồng và cho nhân viên nghỉ việc.
   - **Chi tiết**: Tự động chuyển trạng thái của nhân viên thành "Nghỉ việc", thay đổi ngày kết thúc hợp đồng hiện tại thành ngày hiện hành, chốt và đóng lại bảng lương hiện tại, đồng thời khóa `TaiKhoan` đăng nhập để đảm bảo bảo mật.

#### 9.4. Functions (Hàm tính toán vô hướng)

1. **`fn_SoNgayChuanThang`**
   - **Vị trí file**: `02_Database/Functions/fn_SoNgayLamViec.sql` (Từ dòng 22)
   - **Mục đích**: Tự động tính số ngày làm việc chuẩn trong tháng để làm cơ sở chia lương.
   - **Chi tiết**: Hàm sử dụng vòng lặp `WHILE` duyệt từng ngày từ đầu đến cuối tháng. Tự động bỏ qua Thứ 7, Chủ Nhật (`DAYOFWEEK`) và các ngày lễ quốc gia (kiểm tra `MONTH`, `DAY` và tra cứu thêm bảng `NgayLe`) để trả về chính xác số ngày công tiêu chuẩn.
2. **`fn_TinhThueTNCN_Scalar`**
   - **Vị trí file**: `02_Database/Functions/fn_TinhThueTNCN.sql` (Từ dòng 16)
   - **Mục đích**: Tự động hóa biểu thuế lũy tiến 7 bậc của Việt Nam.
   - **Chi tiết**: Hàm nhận đầu vào là `ThuNhapChiuThue`, chạy qua các điều kiện `IF` xếp tầng từ bậc 7 (> 80 triệu, 35%) lùi dần về bậc 1 (0-5 triệu, 5%). Mỗi bậc tính xong sẽ cấn trừ dần và cộng dồn vào tổng tiền thuế.

#### 9.5. Triggers (Trình kích hoạt)

1. **`trg_NghiPhep_CheckOverlap_Insert`**
   - **Vị trí file**: `02_Database/Triggers/trg_NghiPhep_CheckOverlap.sql` (Từ dòng 11)
   - **Mục đích**: Bảo vệ tính logic của quy trình chấm công, chặn nhân viên xin nghỉ lặp ngày.
   - **Chi tiết**: Trigger kích hoạt ở sự kiện `BEFORE INSERT` trên bảng `NghiPhep`. Bằng một truy vấn `EXISTS`, nếu phát hiện nhân viên đang xin một ngày đã nằm lọt thỏm trong một đơn nghỉ phép khác đã duyệt (APPROVED), hệ thống sẽ dùng lệnh `SIGNAL SQLSTATE` chặn insert.
2. **`trg_HopDong_AfterInsert`**
   - **Vị trí file**: `02_Database/Triggers/trg_LogHopDong.sql` (Từ dòng 23)
   - **Mục đích**: Audit log (Nhật ký hệ thống) chống chối bỏ trách nhiệm.
   - **Chi tiết**: Kích hoạt tự động ngay sau khi có sự kiện `AFTER INSERT` ở bảng `HopDong`. Chuyển toàn bộ dữ liệu mới (`NEW`) thành định dạng JSON và ghi một bản sao vào bảng lịch sử `AuditLog_HopDong`.
