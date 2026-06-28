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

### 6. Các Vấn Đề Đồng Thời & Hướng Dẫn Kịch Bản Demo Khắc Phục Chi Tiết (Kết hợp UI & Database)

*(Lưu ý: Kịch bản demo dưới đây là sự kết hợp thực tế giữa các thao tác trên Giao Diện Người Dùng (UI) của hệ thống Next.js và các can thiệp giả lập độ trễ bằng lệnh `DO SLEEP(seconds);` dưới MySQL để hội đồng thấy rõ cách lỗi phát sinh ở tầng ứng dụng).*

#### 6.1. Mất dữ liệu cập nhật (Lost Update)

* **Ngữ cảnh đặc trưng mang tính hệ thống:**
  Chuyên viên Nhân sự (HR) A thực hiện rà soát thông tin hồ sơ để chỉnh sửa Số Điện Thoại của nhân viên trên giao diện UI. Cùng thời điểm đó, HR B nhận được yêu cầu cập nhật Mã Số Thuế cá nhân cho cùng nhân viên này. Cả hai cùng tải form thông tin của nhân viên (Ví dụ: `NV000008`). HR A thực hiện lưu số điện thoại thành công. Tuy nhiên ngay sau đó 1 giây, HR B bấm lưu mã số thuế. Kết quả là toàn bộ thông tin của B lưu đè lên A do form UI của B gửi lên nguyên bộ dữ liệu cũ kèm mã số thuế mới, làm mất đi số điện thoại mà A vừa mới bỏ công sửa.
* **Danh sách các cách khắc phục:**

  1. **Khóa bi quan (Pessimistic Locking):** Sử dụng câu lệnh `SELECT ... FOR UPDATE` khi đọc dữ liệu để khóa bản ghi (Row-level Lock). Bất kỳ ai muốn lấy bản ghi đó để sửa đều phải chờ giao dịch hiện tại hoàn tất.
  2. **Khóa lạc quan (Optimistic Locking):** Thêm một cột `Version` (phiên bản) hoặc `LastModified` vào bảng `NhanVien`. Mỗi lần Update sẽ kiểm tra `WHERE Version = <Version_cũ>`, nếu thành công thì `Version = Version + 1`. Nếu không có dòng nào được update nghĩa là dữ liệu đã bị sửa bởi người khác, báo lỗi trên UI yêu cầu tải lại.
  3. **Cập nhật tương đối/cục bộ (Partial Update):** UI chỉ gửi lên đúng các trường cần thay đổi thay vì nguyên object. Dùng lệnh UPDATE chỉ update đúng cột cần thiết: `UPDATE NhanVien SET MaSoThue = ? WHERE MaNV = ?`.
* **Lựa chọn cách tốt nhất & Lý do:**
  Cách tốt nhất là **Cập nhật cục bộ (Partial Update) kết hợp Khóa lạc quan (Optimistic Locking)**.
  Lý do: Trong các hệ thống Web đa người dùng, dùng `SELECT ... FOR UPDATE` ở request HTTP rất nguy hiểm vì có thể khóa chết database nếu người dùng giữ trạng thái treo (Timeout). Việc kết hợp Optimistic Locking và Partial Update giúp đảm bảo vẹn toàn dữ liệu nhưng không gây khóa cơ sở dữ liệu, tối ưu hiệu suất truy cập song song rất tốt.
* **Chi tiết Demo kết hợp UI & CSDL:**
  **Bước 1: Tái hiện lỗi**

  - **Trên UI (Cửa sổ 1 - HR A) & (Cửa sổ 2 - HR B):** Cả hai đăng nhập bằng 2 tài khoản khác nhau, cùng mở trang "Chỉnh sửa hồ sơ nhân viên NV000008". Cả 2 form lúc này đều hiện *Số điện thoại cũ, Mã số thuế cũ*.
  - **Thao tác UI (HR A):** Nhập số điện thoại mới `0987654321` và ấn nút **Lưu**. Toast message hiện "Thành công".
    *(Dưới DB: `UPDATE NhanVien SET SoDienThoai = '0987654321', MaSoThue = 'OLD_TAX' WHERE MaNV = 'NV000008';`)*.
  - **Thao tác UI (HR B - Sau 2 giây):** Nhập mã số thuế mới 9999999999 (vẫn để nguyên số ĐT cũ trên form) và ấn nút **Lưu**. Toast message hiện "Thành công".
    *(Dưới DB: `UPDATE NhanVien SET SoDienThoai = 'OLD_PHONE', MaSoThue = '99999999' WHERE MaNV = 'NV000008';`)*.
  - **Kết quả trên UI:** Tải lại trang (F5). Số điện thoại hiển thị lại số cũ, công sức của HR A đã bốc hơi hoàn toàn.

  **Bước 2: Triển khai khắc phục (Bật/Tắt qua `.env`)**

  1. **Cập nhật Database Schema**:
     Thêm cột `Version` vào bảng `NhanVien` bằng câu lệnh SQL:

     ```sql
     ALTER TABLE NhanVien ADD COLUMN Version INT NOT NULL DEFAULT 1;
     ```

     *(Đã cập nhật trong file [01_create_tables.sql](file:///D:/kelangthanghocIT/UTH/DBMS_Final_HRM/02_Database/DDL/01_create_tables.sql) và chạy script `patch_db.js` thành công)*.
  2. **Cấu hình môi trường (Bật/Tắt chế độ bảo vệ chống Lost Update)**:
     Thêm biến môi trường trong file [.env](file:///D:/kelangthanghocIT/UTH/DBMS_Final_HRM/03_App/backend/.env):

     ```env
     ENABLE_OPTIMISTIC_LOCK=true
     ```

     * `true`: Kích hoạt cơ chế bảo vệ (Khóa lạc quan - Optimistic Locking).
     * `false`: Tắt chế độ bảo vệ (Tái hiện lại lỗi mất dữ liệu cập nhật - Lost Update).
  3. **Xử lý tại API Update Backend ([server.js](file:///D:/kelangthanghocIT/UTH/DBMS_Final_HRM/03_App/backend/server.js))**:
     Backend kiểm tra cấu hình `ENABLE_OPTIMISTIC_LOCK` để chạy truy vấn tương ứng.

     * Khi kích hoạt, câu lệnh UPDATE sẽ kiểm tra `Version`:

       ```sql
       UPDATE NhanVien 
       SET MaSoThue = '9999999999', Version = Version + 1
       WHERE MaNV = 'NV000008' AND Version = 1;
       ```

       Nếu kết quả `affectedRows = 0`, trả về mã **409 Conflict** kèm thông báo lỗi.
  4. **Xử lý phía Frontend (Next.js)**:
     Frontend gửi kèm thuộc tính `Version` trong API PUT và tự động bắt lỗi `409` để hiển thị cảnh báo cho người dùng.

  ---

  ### HƯỚNG DẪN DEMO CHO GIẢNG VIÊN

  Để giảng viên thấy rõ cả **lỗi mất dữ liệu** lẫn **cách khắc phục** mà bạn đã triển khai, bạn có thể thực hiện theo quy trình sau:

  #### Kịch bản 1: Tái hiện lỗi Lost Update ban đầu (Trước khi sửa)


  1. Mở file [.env](file:///D:/kelangthanghocIT/UTH/DBMS_Final_HRM/03_App/backend/.env) của Backend, đổi cấu hình thành:
     ```env
     ENABLE_OPTIMISTIC_LOCK=false
     ```
  2. Khởi động lại Server Backend để nhận cấu hình mới.
  3. Mở **2 trình duyệt** khác nhau (hoặc 1 Tab thường và 1 Tab ẩn danh) và cùng truy cập trang sửa hồ sơ của nhân viên `NV000008`. Lúc này, cả hai form đều có *Số điện thoại cũ, Mã số thuế cũ*.
  4. **Ở Tab 1 (HR A):** Nhập Số điện thoại mới và ấn **Lưu**. Hệ thống báo thành công. (Bản ghi dưới DB lúc này đã đổi Số điện thoại mới nhưng Mã số thuế vẫn là cũ).
  5. **Ở Tab 2 (HR B):** Nhập Mã số thuế mới (vẫn giữ Số điện thoại cũ ban đầu trên form của B) và ấn **Lưu**. Hệ thống báo thành công.
  6. F5 tải lại trang. Giảng viên sẽ thấy **Số điện thoại mới mà HR A vừa sửa đã biến mất** (bị ghi đè bởi giá trị cũ trên form của B). Đây chính là lỗi Lost Update.

  #### Kịch bản 2: Trình diễn tính năng Khắc phục (Khóa lạc quan)

  1. Mở file [.env](file:///D:/kelangthanghocIT/UTH/DBMS_Final_HRM/03_App/backend/.env) của Backend, đổi cấu hình thành:
     ```env
     ENABLE_OPTIMISTIC_LOCK=true
     ```
  2. Khởi động lại Server Backend.
  3. Thực hiện lại y hệt các bước từ **3 đến 5** ở Kịch bản 1.
  4. **Kết quả:** Khi HR B ở Tab 2 ấn **Lưu**, hệ thống sẽ chặn lại ngay lập tức và hiện thông báo lỗi: **"Dữ liệu đã được cập nhật bởi một người khác. Vui lòng tải lại trang!"**. Số điện thoại của HR A được bảo toàn nguyên vẹn. Giao diện được kiểm soát chặt chẽ.

#### 6.2. Đọc dữ liệu rác (Dirty Read)

* **Ngữ cảnh đặc trưng mang tính hệ thống:**
  Chuyên viên Nhân sự (HR) đang mở Dashboard Báo Cáo Nhân Sự để xem tổng số lượng nhân viên hiện tại của toàn doanh nghiệp nhằm chốt báo cáo cuối tháng. Cùng thời điểm, hệ thống ngầm đang chạy Giao tác `sp_TiepNhanNhanSu` tiếp nhận 1 nhân sự cấp cao mới vào hệ thống. Việc `INSERT` nhân viên vào bảng `NhanVien` đã diễn ra, nhưng khi đến phần tạo tài khoản đăng nhập thì hệ thống bị lỗi (ví dụ: Email đã tồn tại). Giao tác `sp_TiepNhanNhanSu` lập tức bị `ROLLBACK`.
  Thảm họa xảy ra khi Báo cáo của HR đọc đúng lúc bản ghi nhân viên vừa `INSERT` xong nhưng chưa `ROLLBACK`. Kết quả báo cáo báo tổng số nhân viên tăng ảo thêm 1 người dù nhân viên đó chưa từng gia nhập thành công.
* **Danh sách các cách khắc phục:**

  1. Tăng mức độ cô lập (Isolation Level) lên `READ COMMITTED`.
  2. Tăng mức độ cô lập lên `REPEATABLE READ`.
  3. Tăng mức độ cô lập lên `SERIALIZABLE`.
* **Lựa chọn cách tốt nhất & Lý do:**
  Cách tốt nhất là **`READ COMMITTED` (hoặc `REPEATABLE READ` vì InnoDB mặc định đã là REPEATABLE READ)**.
  Lý do: Để chống lại Dirty Read, chỉ cần `READ COMMITTED` là đủ. Ở mức này, giao dịch Báo cáo chỉ nhìn thấy những dữ liệu đã được `COMMIT` thành công, hoàn toàn loại bỏ được dữ liệu "rác" từ các transaction đang dở dang.
* **Chi tiết Demo kết hợp API & CSDL:**
  **Bước 1: Tái hiện lỗi**

  - **Trên CSDL (Giả lập Job Onboarding bị treo):**
    ```sql
    START TRANSACTION;
    INSERT INTO NhanVien (MaNV, HoTen, GioiTinh, NgaySinh, CCCD, MaPB, MaCV, NgayVaoLam) 
    VALUES ('NV888888', 'Giám Đốc Mới', 'M', '1990-01-01', '012345678910', 'PB0001', 'CV0001', '2025-01-01');
    -- Giả lập thêm các dữ liệu khác ...
    DO SLEEP(8); -- Giả lập đang xử lý bước tạo tài khoản gửi mail
    ROLLBACK; -- Giả lập bị lỗi cuối cùng
    ```
  - **Hành động của HR (Trong 8s Sleep):** Chuyên viên HR mở / tải lại (F5) trang **Tổng Quan (Dashboard)** trên giao diện UI để xem số liệu nhân sự.
    *(Dưới Backend, API lấy danh sách nhân viên đang bị cấu hình cố tình lỗi: `SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;`)*.
  - **Kết quả trả về:** Giao diện Dashboard hiển thị thẻ **Tổng nhân viên** vọt lên thêm 1 người (chính là `NV888888`). Nếu HR lấy số liệu này để nộp báo cáo, nó sẽ là một dữ liệu sai lệch hoàn toàn. Sau 8s, nhân viên kia rollback và biến mất khỏi hệ thống. Việc thẻ Tổng nhân viên bị nhảy số ảo này chính là minh chứng rõ ràng cho việc hệ thống đã đọc phải dữ liệu rác.

  **Bước 2: Triển khai khắc phục (Đã thực hiện hoàn thiện bằng Bật/Tắt qua `.env`)**

  1. **Cấu hình môi trường (Bật/Tắt chế độ Isolation Level)**:
     Thêm biến môi trường trong file [.env](file:///D:/kelangthanghocIT/UTH/DBMS_Final_HRM/03_App/backend/.env):

     ```env
     DEMO_DIRTY_READ=true
     ```

     * `true`: Thiết lập mức độ cô lập thành `READ UNCOMMITTED` (Tái hiện lỗi Dirty Read).
     * `false`: Thiết lập mức độ cô lập chuẩn `READ COMMITTED` (Khắc phục lỗi).
  2. **Xử lý tại API Backend ([server.js](file:///D:/kelangthanghocIT/UTH/DBMS_Final_HRM/03_App/backend/server.js))**:
     Hệ thống cung cấp sẵn API để phục vụ việc Demo:

     - **API Mô phỏng Giao dịch treo:** `POST /v1/demo/slow-onboarding`
       (Thực hiện `INSERT` nhân viên mới, sau đó `SLEEP(10)` rồi `ROLLBACK`).
     - **API Nhân sự (Dashboard):** `GET /v1/employees`
       (Kiểm tra biến `DEMO_DIRTY_READ` để thay đổi lệnh `SET SESSION TRANSACTION ISOLATION LEVEL` khi lấy danh sách).

  ---

  ### HƯỚNG DẪN DEMO CHO GIẢNG VIÊN

  Để giảng viên thấy rõ cả **lỗi dữ liệu rác** lẫn **cách khắc phục**, bạn có thể thao tác trực tiếp trên giao diện UI kết hợp Terminal:

  #### Kịch bản 1: Tái hiện lỗi Dirty Read ban đầu (Trước khi sửa)


  1. Mở file [.env](file:///D:/kelangthanghocIT/UTH/DBMS_Final_HRM/03_App/backend/.env) của Backend, đổi cấu hình thành:
     ```env
     DEMO_DIRTY_READ=true
     ```
  2. Khởi động lại Server Backend và mở sẵn trình duyệt ở trang Dashboard.
  3. Mở Terminal / Command Prompt hoặc Postman và gọi API giả lập giao dịch treo (Onboarding):
     ```bash
     curl.exe -X POST http://localhost:8080/v1/demo/slow-onboarding
     ```
  4. Ngay lập tức (trong vòng 10 giây trước khi lệnh curl trên chạy xong), quay lại trình duyệt và **nhấn F5 (Tải lại trang)** Dashboard.
  5. **Kết quả:** Giảng viên sẽ thấy biểu đồ và thẻ **`Tổng nhân viên`** tăng lên thêm 1 người. Việc chụp ảnh hoặc quay video khoảnh khắc này sẽ là minh chứng vật lý rõ ràng nhất cho thấy hệ thống đã cung cấp dữ liệu sai lệch cho báo cáo nhân sự.
  6. Sau 10 giây, tiến trình chậm ở bước 3 kết thúc và tự động ROLLBACK. Nếu tiếp tục F5 trình duyệt ở bước 4, số lượng nhân viên sẽ tự động sụt giảm về mốc cũ (Dirty Read). Kết quả chớp nhoáng lấy được ở bước 5 chính là bằng chứng không thể chối cãi cho việc UI đã đọc phải dữ liệu rác.

  #### Kịch bản 2: Trình diễn tính năng Khắc phục (Isolation Level)

  1. Mở file [.env](file:///D:/kelangthanghocIT/UTH/DBMS_Final_HRM/03_App/backend/.env), đổi cấu hình thành:
     ```env
     DEMO_DIRTY_READ=false
     ```
  2. Khởi động lại Server Backend.
  3. Gọi lại lệnh API giả lập ở Bước 3 của kịch bản 1.
  4. Ngay lập tức quay lại trình duyệt và **nhấn F5 (Tải lại trang)** Dashboard.
  5. **Kết quả:** Dashboard trả về số lượng nhân viên hoàn toàn chính xác (không bị tăng). Mức độ cô lập `READ COMMITTED` đã chặn luồng đọc dữ liệu khỏi việc quét qua dòng dữ liệu nhân viên đang trong trạng thái `UNCOMMITTED`. Dữ liệu hiển thị (Tổng nhân viên) trên UI không bị sai lệch dù đang có giao dịch Onboarding chạy song song.

#### 6.3. Bóng ma (Phantom Read)

* **Ngữ cảnh đặc trưng mang tính hệ thống:**
  Kế toán cần chốt sổ toàn bộ nhân viên phòng IT. Kế toán vào màn hình UI "Chốt lương", thấy danh sách tổng là 20 người (trạng thái Draft). Kế toán bấm nút **"Chốt và Xuất Quỹ"** (hệ thống chạy ngầm `sp_ChotBangLuong`). Đột nhiên HR quyết định sa thải 1 nhân sự cấp dưới phòng IT, trên UI nhân sự bấm nút **"Thanh lý hợp đồng"**. Logic nghỉ việc lập tức sinh ra 1 bảng lương Draft dở dang cho những ngày làm việc cuối cùng. Tiến trình chốt quỹ của Kế toán chạy xong, thông báo UI trả về: "Đã chốt thành công 21 bản ghi". Bản ghi bóng ma (Phantom Row) này đã thâm nhập vào quỹ thanh toán ngoài dự toán của kế toán.
* **Danh sách các cách khắc phục:**

  1. Tăng mức độ cô lập lên `SERIALIZABLE`.
  2. Sử dụng Next-Key Locking với `SELECT ... FOR UPDATE` trong mức `REPEATABLE READ` của InnoDB.
* **Lựa chọn cách tốt nhất & Lý do:**
  Cách tốt nhất là **Sử dụng Next-Key Locking (`SELECT ... FOR UPDATE`) trong `REPEATABLE READ`**.
  Lý do: Mức `SERIALIZABLE` gây khóa đọc toàn cục làm treo hệ thống. InnoDB ở mức `REPEATABLE READ` hỗ trợ Next-Key Locking, chỉ cần gọi `SELECT * FROM BangLuong WHERE TrangThai='D' FOR UPDATE`, nó sẽ khóa chặt "khoảng không gian" (gap) điều kiện này. Nút "Thanh lý hợp đồng" của HR trên UI sẽ quay vòng vòng chờ (Block) cho tới khi kế toán chốt sổ xong.
* **Chi tiết Demo kết hợp UI & CSDL:**
  **Bước 1: Tái hiện lỗi**

  - **Trên UI (Kế toán):** Thấy danh sách 20 nhân viên. Bấm nút **"Chốt Lương"**.
    *(Dưới DB hệ thống đếm số lượng: `SELECT COUNT(*) FROM BangLuong WHERE Thang = 5 AND TrangThai = 'D';`, sau đó bị `SLEEP(8)`).*
  - **Trên UI (HR - Trong 8s Sleep):** Bấm nút **"Thanh lý hợp đồng"** cho nhân viên NV000099.
    *(Dưới DB chạy: `INSERT INTO BangLuong (MaNV, Thang, Nam, LuongCoBan, TrangThai) VALUES ('NV000099', 5, 2025, 10000000, 'D'); COMMIT;`)*.
  - **Kết quả trên UI (Kế toán):** Sau khi chờ loading xong, màn hình Kế toán hiện Toast: *"Thành công: Đã chốt 21 nhân viên"*. Dư ra 1 bóng ma.

  **Bước 2: Triển khai khắc phục (Đã thực hiện hoàn thiện bằng Bật/Tắt qua `.env`)**

  1. **Cấu hình môi trường (Bật/Tắt chế độ Gap/Next-Key Locking)**:
     Thêm biến môi trường trong file [.env](file:///D:/kelangthanghocIT/UTH/DBMS_Final_HRM/03_App/backend/.env):

     ```env
     DEMO_PHANTOM_READ=true
     ```

     * `true`: Không sử dụng `FOR UPDATE` (Tái hiện lỗi Bóng Ma trong môi trường REPEATABLE READ mặc định của MySQL vì MySQL không khóa Insert mới).
     * `false`: Gắn thêm lệnh `FOR UPDATE` vào cuối câu `SELECT` đếm số lượng. Kích hoạt Next-Key Locking khóa toàn bộ khoảng trống (Gap Lock), triệt tiêu lỗi.
  2. **Xử lý tại API Backend ([server.js](file:///D:/kelangthanghocIT/UTH/DBMS_Final_HRM/03_App/backend/server.js))**:
     Hệ thống cung cấp sẵn 2 API để phục vụ việc Demo:

     - **API Mô phỏng Chốt Lương (Kế toán):** `GET /v1/demo/close-payroll`
       (Sẽ Đếm số bảng lương Draft, sau đó `SLEEP(10)` mô phỏng đang xử lý, và cuối cùng `UPDATE` toàn bộ sang trạng thái Closed. Nếu biến cấu hình là false, sẽ tự động nối thêm `FOR UPDATE` khi SELECT).
     - **API Mô phỏng Thanh lý hợp đồng (HR):** `POST /v1/demo/fire-employee`
       (Lập tức `INSERT` một nhân viên mới `NV000099` kèm 1 bảng lương Draft đang dở dang vào tháng đang chốt).

  ---

  ### HƯỚNG DẪN DEMO CHO GIẢNG VIÊN (PHANTOM READ)

  #### Kịch bản 1: Tái hiện lỗi Bóng Ma ban đầu (Trước khi sửa)


  1. Mở file [.env](file:///D:/kelangthanghocIT/UTH/DBMS_Final_HRM/03_App/backend/.env) của Backend, đổi cấu hình thành:
     ```env
     DEMO_PHANTOM_READ=true
     ```
  2. Khởi động lại Server Backend.
  3. Mở Terminal / Command Prompt hoặc Postman và gọi API giả lập Chốt lương (Kế toán):
     ```bash
     curl -X GET http://localhost:8080/v1/demo/close-payroll
     ```
  4. Ngay lập tức (trong vòng 10 giây trước khi lệnh curl trên chạy xong), mở 1 Terminal khác (đại diện cho HR) và gọi API Thanh lý Hợp đồng:
     ```bash
     curl -X POST http://localhost:8080/v1/demo/fire-employee
     ```
  5. **Kết quả:** Sau 10 giây, Terminal đầu tiên (Chốt lương) sẽ trả về kết quả lỗi: `initial_draft_count` và `actually_closed_count` bị lệch nhau đúng 1 bản ghi, kèm trạng thái: `"CẢNH BÁO: Đã xảy ra Bóng ma (Phantom Read)! Dư ra 1 bản ghi."`.
     - Lý do: Bản ghi của HR chèn vào thành công, và câu lệnh `UPDATE` ở cuối quy trình Kế toán đã vô tình quét trúng bản ghi đó và chốt luôn, biến nó thành Bóng Ma làm sai lệch tính toán ban đầu.

  #### Kịch bản 2: Trình diễn tính năng Khắc phục (Next-Key Locking)

  1. Mở file [.env](file:///D:/kelangthanghocIT/UTH/DBMS_Final_HRM/03_App/backend/.env), đổi cấu hình thành:
     ```env
     DEMO_PHANTOM_READ=false
     ```
  2. Khởi động lại Server Backend.
  3. Gọi lại lệnh API giả lập Chốt lương (Bước 3 kịch bản 1).
  4. Ngay lập tức gọi lại lệnh API Thanh lý Hợp đồng (Bước 4 kịch bản 1).
  5. **Kết quả:** Cửa sổ Terminal thứ hai (HR) sẽ bị "đứng hình" chờ đợi (Loading...) và không thể thêm bản ghi mới ngay lập tức. Sau 10 giây, Terminal đầu tiên (Chốt lương) trả về kết quả hoàn hảo: `"Tuyệt vời: Dữ liệu nhất quán, không có bóng ma lọt vào."`.
     - Lý do: Cú pháp `SELECT ... FOR UPDATE` đã yêu cầu InnoDB thiết lập Next-Key Lock (kết hợp Record Lock và Gap Lock) trên vùng dữ liệu `Thang=5, Nam=2026, TrangThai=D`. Mọi nỗ lực `INSERT` vào vùng này từ các transaction khác đều bị "Block" cho đến khi giao dịch hiện tại hoàn thành!

#### 6.4. Không đọc lại được dữ liệu (Non-repeatable Read)

* **Ngữ cảnh đặc trưng mang tính hệ thống:**
  Trong hệ thống Tính lương, hr2 vào màn hình UI **"Bảng Lương"** (`/payroll`) và bấm nút **"Tính Lương"**. Tiến trình tính lương dưới Database (`sp_TinhLuong`) bắt đầu chạy. Nó sẽ thực hiện 2 bước độc lập:

  - Lần đọc 1: Lấy mức lương cơ bản hiện tại của nhân viên (VD: 70 triệu) để tính ra mức đóng Bảo Hiểm (BHXH).
  - Lần đọc 2 (Sau một khoảng thời gian xử lý các phép toán phức tạp): Lấy lại mức lương cơ bản để tính Tổng thu nhập và Thuế TNCN.

  Ngay trong khoảng thời gian giữa 2 lần đọc đó, một chuyên viên Nhân sự (HR) quyết định **chỉnh sửa Lương cơ bản trực tiếp** dưới Database của nhân viên đó từ 70 triệu lên 80 triệu (để vượt qua cơ chế chặn sửa của Trigger).
  Hậu quả của Non-repeatable Read: Khi quá trình tính lương hoàn tất, Phiếu lương sinh ra sẽ hiển thị Lương Cơ Bản là 80 triệu (Lần đọc 2), nhưng số tiền đóng Bảo hiểm lại tính trên mức 70 triệu (Lần đọc 1). Kế toán nhìn vào bảng lương trên giao diện sẽ thấy ngay một bút toán "sai bét" rành rành (Ví dụ: 8% của 30 triệu phải là 6.4 triệu, nhưng hệ thống lại hiện 5.6 triệu).
* **Danh sách các cách khắc phục:**

  1. **Khóa bi quan (Pessimistic Locking) bằng `SELECT ... FOR UPDATE`**: Khi đọc Lương Cơ Bản ở Lần 1, ta khóa luôn bản ghi đó. HR muốn sửa lương sẽ bị treo chờ cho đến khi quá trình tính lương hoàn tất. Tuy nhiên, quá trình tính lương thường mất rất lâu, việc khóa này có thể làm tê liệt mọi thao tác liên quan đến nhân sự.
  2. **Tăng mức độ cô lập lên `REPEATABLE READ`**: Đảm bảo mọi lần `SELECT` trong cùng một giao dịch (transaction) đều đọc từ một bản ghi Snapshot nhất quán tại thời điểm bắt đầu giao dịch. Tuy nhiên có thể tốn kém bộ nhớ.
  3. **Tối ưu logic Code (Sử dụng biến cục bộ - Local Variable Snapshot)**: Thay vì đọc lại Database nhiều lần, ta chỉ đọc giá trị Lương Cơ Bản **MỘT LẦN DUY NHẤT** ở đầu Stored Procedure, gán vào một biến cục bộ (`SET v_cur_LuongCB = ...`), và dùng biến này cho toàn bộ các công thức tính toán về sau.
* **Lựa chọn cách tốt nhất & Lý do:**
  Cách tốt nhất thực tiễn là **Sử dụng biến cục bộ (Local Variable Snapshot)**.
  Lý do: Đây là giải pháp xử lý triệt để ở tầng Application/Procedure Logic. Không cần thay đổi mức độ cô lập (Isolation level), không tốn chi phí khóa (Locking) làm nghẽn hệ thống. Dữ liệu trong suốt một quá trình tính toán dài được đảm bảo tính nhất quán nội tại hoàn hảo.
* **Chi tiết Demo kết hợp UI & CSDL (Sử dụng cách Cập nhật trực tiếp):**

  **Bước 1: Tái hiện lỗi (Bất nhất dữ liệu)**

  1. Mở file [.env](file:///D:/kelangthanghocIT/UTH/DBMS_Final_HRM/03_App/backend/.env) của Backend, đổi cấu hình thành:
     ```env
     DEMO_NON_REPEATABLE_READ=true
     ```
  2. Khởi động lại Server Backend. Đảm bảo nhân viên `NV000001` đang có lương cơ bản là `70,000,000`.
  3. Mở giao diện UI (Kế toán) và công cụ MySQL Workbench (HR):
     - **Trên UI (Kế toán)**: Vào màn hình **"Bảng Lương"** (`/payroll`), chọn tháng hiện tại và ấn nút **"Tính Lương"**. Hệ thống sẽ bắt đầu xoay (Loading) do đã được giả lập thời gian trễ 15 giây.
     - **Trên MySQL Workbench (HR)**: Ngay lập tức (trong 15s đó), mở tab Query mới và chạy lệnh UPDATE trực tiếp để thay đổi lương mà không bị vướng Trigger lịch sử lương:
       ```sql
       UPDATE LuongCoBan 
       SET LuongCB = 80000000 
       WHERE MaNV = 'NV000001' AND NgayHetHieuLuc IS NULL;
       ```
  4. **Kết quả trên UI**: Sau 15 giây, quá trình tính lương trên UI hoàn tất. Kế toán tải lại trang Bảng lương hoặc xem chi tiết Phiếu lương của `NV000001`. Giảng viên sẽ thấy rõ ràng:
     - Cột **Lương Cơ Bản**: `80,000,000 ₫` (Đã nhận mức lương mới).
     - Cột **BHXH NLD (8%)**: `5,600,000 ₫` (Hệ thống tính sai, vì tính dựa trên lương 70tr cũ).
       Đây là minh chứng trực quan nhất cho thấy sự bất nhất (Non-repeatable read) trong cùng một chu trình xử lý!

  **Bước 2: Trình diễn tính năng Khắc phục (Sử dụng biến Snapshot)**

  1. Mở file [.env](file:///D:/kelangthanghocIT/UTH/DBMS_Final_HRM/03_App/backend/.env) của Backend, đổi cấu hình thành:
     ```env
     DEMO_NON_REPEATABLE_READ=false
     ```
  2. Khởi động lại Server Backend. Đổi lại Lương nhân viên `NV000001` về `70,000,000` (Bằng cách tương tự trên Workbench: `UPDATE LuongCoBan SET LuongCB = 70000000 WHERE MaNV = 'NV000001' AND NgayHetHieuLuc IS NULL;`).
  3. Thực hiện lại y hệt **Bước 3** ở trên (Kế toán bấm Tính lương trên UI -> HR chạy lệnh UPDATE lên 80tr trong Workbench).
  4. **Kết quả**: Khi xem lại bảng lương trên UI, toàn bộ mức lương, BHXH và thuế đều được tính toán nhất quán dựa trên mức lương `70,000,000` (giá trị Snapshot ở thời điểm bắt đầu tính lương). Dù lệnh UPDATE 80tr của HR thành công ở giữa quá trình, mức lương 80tr này sẽ không làm xáo trộn phép tính hiện tại mà chỉ được áp dụng vào kỳ tính lương tháng sau. Không còn lỗi bất đồng bộ!
     *(Ghi chú kỹ thuật: Ở chế độ chuẩn `false`, `sp_TinhLuong.sql` được tối ưu hoá chỉ SELECT Lương 1 lần duy nhất đầu thủ tục, xoá bỏ điểm yếu đọc 2 lần sinh ra sai lệch).*

### 7. Deadlock (Khóa chết)

* **Ngữ cảnh đặc trưng mang tính hệ thống:**
  Giao dịch A (HR trên UI bấm nút **"Thăng chức"**) gọi `sp_DieuChuyenThangChuc`: thực hiện cập nhật chức vụ trong bảng `NhanVien`, sau đó nâng mức lương trong bảng `LuongCoBan`.
  Giao dịch B (HR khác bấm nút **"Kỷ luật - Hạ bậc"**) gọi `sp_TienThuongKyLuat`: thực hiện hạ mức lương trong bảng `LuongCoBan` trước, sau đó cập nhật điểm kỷ luật ở bảng `NhanVien` sau.
  Nếu hai HR ấn nút cùng lúc trên cùng 1 nhân viên: Giao dịch A khóa `NhanVien` chờ `LuongCoBan`. Giao dịch B khóa `LuongCoBan` chờ `NhanVien`. Cả hai rơi vào trạng thái chờ nhau vô tận. MySQL sẽ "Kill" một giao dịch, khiến màn hình UI của 1 trong 2 HR văng lỗi Error 500 (Deadlock).
* **Danh sách các cách khắc phục:**

  1. Đồng nhất thứ tự lấy khóa (Consistent Lock Ordering) giữa mọi Giao tác và Stored Procedures.
  2. Tối ưu hóa các truy vấn bằng Index để thu nhỏ phạm vi quét khóa.
  3. Chia nhỏ giao dịch lớn thành các giao dịch nhỏ hơn để nhả khóa sớm.
  4. Cơ chế Deadlock Retry tại tầng Ứng Dụng (Node.js/Backend).
* **Lựa chọn cách tốt nhất & Lý do:**
  Cách tốt nhất là **Đồng nhất thứ tự lấy khóa (Consistent Lock Ordering)** từ mức thiết kế Database.
  Lý do: Đây là phương pháp phòng bệnh triệt để nhất. Nếu mọi luồng code (Stored Procedures) đều tuân thủ quy tắc lấy khóa theo thứ tự phân tầng từ bảng Master đến bảng Detail: "Luôn UPDATE `NhanVien` trước -> tới `HopDong` -> tới `LuongCoBan`", thì Deadlock chéo không bao giờ có cơ hội hình thành. Kết hợp bắt lỗi Retry ở tầng Node.js Backend để đảm bảo UX hoàn hảo cho người dùng.
* **Chi tiết Demo kết hợp UI & CSDL:**
  **Bước 1 & Bước 2: Triển khai khắc phục (Đã thực hiện hoàn thiện bằng Bật/Tắt qua `.env`)**

  1. **Cấu hình môi trường (Bật/Tắt chế độ Lấy khóa ngược chiều)**:
     Thêm biến môi trường trong file [.env](file:///D:/kelangthanghocIT/UTH/DBMS_Final_HRM/03_App/backend/.env):

     ```env
     DEMO_DEADLOCK=true
     ```

     * `true`: Tiến trình B cố tình đi ngược chuẩn, lấy khóa `LuongCoBan` trước rồi mới lấy khóa `NhanVien`, đụng độ với Tiến trình A sinh ra lỗi 1213 Deadlock.
     * `false`: Tiến trình B tuân thủ bộ chuẩn: Bắt buộc khóa `NhanVien` trước rồi mới khóa bảng con `LuongCoBan` sau.
  2. **Xử lý tại API Backend ([server.js](file:///D:/kelangthanghocIT/UTH/DBMS_Final_HRM/03_App/backend/server.js))**:
     Hệ thống cung cấp sẵn 2 API để phục vụ việc Demo va chạm khóa chéo:

     - **API Mô phỏng Thăng chức (Tiến trình A):** `POST /v1/demo/promote-employee`
       (Luôn chạy chuẩn: Lấy khóa cập nhật `NhanVien`, ngủ 5 giây, sau đó lấy khóa cập nhật `LuongCoBan`).
     - **API Mô phỏng Kỷ luật (Tiến trình B):** `POST /v1/demo/discipline-employee`
       (Dựa vào biến môi trường để quyết định thứ tự truy vấn ngược chiều hay cùng chiều với Tiến trình A).

  ---

  ### HƯỚNG DẪN DEMO CHO GIẢNG VIÊN (DEADLOCK)

  #### Kịch bản 1: Tái hiện lỗi Khóa Chết (Deadlock) ban đầu


  1. Mở file [.env](file:///D:/kelangthanghocIT/UTH/DBMS_Final_HRM/03_App/backend/.env) của Backend, đổi cấu hình thành:
     ```env
     DEMO_DEADLOCK=true
     ```
  2. Khởi động lại Server Backend.
  3. Mở Terminal / Command Prompt hoặc Postman và gọi API giả lập Thăng chức (Tiến trình A):
     ```bash
     curl -X POST http://localhost:8080/v1/demo/promote-employee
     ```
  4. Ngay lập tức (trong vòng 5 giây trước khi lệnh curl trên chạy xong), mở 1 Terminal khác và gọi API Kỷ luật (Tiến trình B):
     ```bash
     curl -X POST http://localhost:8080/v1/demo/discipline-employee
     ```
  5. **Kết quả:** MySQL phát hiện ngay sự cố khóa chéo vòng tròn. Terminal 2 (Tiến trình B) lập tức bị ngắt và văng lỗi đỏ chót: `"Lỗi 1213: Deadlock found when trying to get lock; try restarting transaction"`. Terminal 1 (Tiến trình A) thì lại chạy mượt mà thành công.

  #### Kịch bản 2: Trình diễn tính năng Khắc phục (Đồng nhất hướng lấy khóa)

  1. Mở file [.env](file:///D:/kelangthanghocIT/UTH/DBMS_Final_HRM/03_App/backend/.env), đổi cấu hình thành:
     ```env
     DEMO_DEADLOCK=false
     ```
  2. Khởi động lại Server Backend.
  3. Gọi lại lệnh API giả lập Thăng chức (Bước 3 kịch bản 1).
  4. Ngay lập tức gọi lại lệnh API Kỷ luật (Bước 4 kịch bản 1).
  5. **Kết quả:** Lần này, cửa sổ Terminal thứ hai (Tiến trình B) sẽ **đứng yên chờ đợi (Loading)** chứ không văng lỗi nữa. Sau khoảng 5 giây, Tiến trình A xong, thì Tiến trình B mới được phép chạy vào khóa bảng `NhanVien`. Cả hai đều báo thành công.
     - Lý do: Vì lúc này Tiến trình B tuân thủ luật lấy khóa "NhanVien trước, LuongCoBan sau", nên nó đã ngoan ngoãn đứng xếp hàng tại "cửa" bảng NhanVien chờ Tiến trình A làm xong toàn bộ thủ tục. Không còn khóa chéo (Deadlock) vì luồng đi của mọi transaction đều song song cùng một chiều!

---

### 8. Báo Cáo Chi Tiết Các Đối Tượng CSDL Chính (Dùng Cho Báo Cáo Tuần)

Dưới đây là chi tiết 2 đối tượng tiêu biểu cho từng loại (Giao tác, View, Store Procedure, Function, Trigger) để trình bày nhanh trong các buổi báo cáo tiến độ hàng tuần.

#### 8.1. Giao tác (Transactions)

1. **`sp_TiepNhanNhanSu` (Onboarding Transaction)**
   - **Vị trí file**: `02_Database/StoredProcedures/sp_TiepNhanNhanSu.sql`
   - **Mục đích**: Đảm bảo quy trình tiếp nhận nhân sự mới tuân thủ tính toàn vẹn dữ liệu (ACID).
   - **Chi tiết**: Giao tác bọc 4 lệnh `INSERT` liên tiếp vào các bảng: `NhanVien`, `HopDong`, `LuongCoBan`, và `TaiKhoan`. Cấu hình `DECLARE EXIT HANDLER FOR SQLEXCEPTION` sẽ bắt mọi lỗi xảy ra; nếu bất kỳ bước nào thất bại, toàn bộ tiến trình sẽ `ROLLBACK` để tránh rác dữ liệu. Nếu thành công sẽ `COMMIT`.
2. **`sp_ChotBangLuong` (Payroll Confirmation Transaction)**
   - **Vị trí file**: `02_Database/StoredProcedures/sp_ChotBangLuong.sql`
   - **Mục đích**: Chốt và thanh toán bảng lương cuối kỳ đồng bộ.
   - **Chi tiết**: Cập nhật đồng thời trạng thái bảng `BangLuong` sang 'P' (Đã thanh toán) và các khoản khấu trừ trong bảng `KhauTru` sang 'A' (Đã áp dụng). Việc đặt vào `START TRANSACTION` giúp hệ thống không gặp tình trạng bảng lương đã chốt nhưng khấu trừ vẫn treo nháp.

#### 8.2. Views (Bảng ảo)

1. **`vw_HoSoNhanVien_ChiTiet`**
   - **Vị trí file**: `02_Database/Views/vw_HoSoNhanVien_ChiTiet.sql`
   - **Mục đích**: Tối ưu hóa truy vấn hiển thị danh sách nhân sự trên giao diện Backend.
   - **Chi tiết**: View này gom dữ liệu thông qua việc `JOIN` bảng `NhanVien` với `PhongBan` và `ChucVu`. Quan trọng nhất, nó dùng `LEFT JOIN` với bảng `HopDong` và `LuongCoBan` đi kèm bộ lọc (chỉ lấy Hợp đồng trạng thái Active và Lương hiệu lực) giúp Frontend không phải gọi nhiều API.
2. **`vw_BangLuong_TongHop`**
   - **Vị trí file**: `02_Database/Views/vw_BangLuong.sql` (Từ dòng 105)
   - **Mục đích**: Cung cấp nguồn dữ liệu sạch để xuất biểu đồ và Excel báo cáo quỹ lương phòng ban.
   - **Chi tiết**: Gộp nhóm (`GROUP BY`) theo tháng, năm và tên phòng ban. Tự động dùng các hàm tính tổng (`SUM`) để trả ra: Tổng lương Gross, Bảo hiểm NSDLĐ phải đóng, Tổng thuế TNCN và Tổng chi phí nhân sự thực tế.

#### 8.3. Store Procedures (Thủ tục lưu trữ)

1. **`sp_TinhLuong`**
   - **Vị trí file**: `02_Database/StoredProcedures/sp_TinhLuong.sql`
   - **Mục đích**: Xử lý logic nghiệp vụ tính lương cốt lõi, chạy định kỳ hàng tháng.
   - **Chi tiết**: Thủ tục chạy qua một quy trình 8 bước biến Lương Gross thành Lương Net: lấy số ngày công chuẩn, cộng lương tăng ca, tính phụ cấp, tính các khoản bảo hiểm bắt buộc trừ vào lương, trừ thuế TNCN lũy tiến, và trừ các khoản khấu trừ phát sinh để ra thực lĩnh.
2. **`sp_NghiViec`**
   - **Vị trí file**: `02_Database/StoredProcedures/sp_NghiViec.sql`
   - **Mục đích**: Đóng gói quy trình thanh lý hợp đồng và cho nhân viên nghỉ việc.
   - **Chi tiết**: Tự động chuyển trạng thái của nhân viên thành "Nghỉ việc", thay đổi ngày kết thúc hợp đồng hiện tại thành ngày hiện hành, chốt và đóng lại bảng lương hiện tại, đồng thời khóa `TaiKhoan` đăng nhập để đảm bảo bảo mật.

#### 8.4. Functions (Hàm tính toán vô hướng)

1. **`fn_SoNgayChuanThang`**
   - **Vị trí file**: `02_Database/Functions/fn_SoNgayLamViec.sql` (Từ dòng 22)
   - **Mục đích**: Tự động tính số ngày làm việc chuẩn trong tháng để làm cơ sở chia lương.
   - **Chi tiết**: Hàm sử dụng vòng lặp `WHILE` duyệt từng ngày từ đầu đến cuối tháng. Tự động bỏ qua Thứ 7, Chủ Nhật (`DAYOFWEEK`) và các ngày lễ quốc gia (kiểm tra `MONTH`, `DAY` và tra cứu thêm bảng `NgayLe`) để trả về chính xác số ngày công tiêu chuẩn.
2. **`fn_TinhThueTNCN_Scalar`**
   - **Vị trí file**: `02_Database/Functions/fn_TinhThueTNCN.sql` (Từ dòng 16)
   - **Mục đích**: Tự động hóa biểu thuế lũy tiến 7 bậc của Việt Nam.
   - **Chi tiết**: Hàm nhận đầu vào là `ThuNhapChiuThue`, chạy qua các điều kiện `IF` xếp tầng từ bậc 7 (> 80 triệu, 35%) lùi dần về bậc 1 (0-5 triệu, 5%). Mỗi bậc tính xong sẽ cấn trừ dần và cộng dồn vào tổng tiền thuế.

#### 8.5. Triggers (Trình kích hoạt)

1. **`trg_NghiPhep_CheckOverlap_Insert`**
   - **Vị trí file**: `02_Database/Triggers/trg_NghiPhep_CheckOverlap.sql` (Từ dòng 11)
   - **Mục đích**: Bảo vệ tính logic của quy trình chấm công, chặn nhân viên xin nghỉ lặp ngày.
   - **Chi tiết**: Trigger kích hoạt ở sự kiện `BEFORE INSERT` trên bảng `NghiPhep`. Bằng một truy vấn `EXISTS`, nếu phát hiện nhân viên đang xin một ngày đã nằm lọt thỏm trong một đơn nghỉ phép khác đã duyệt (APPROVED), hệ thống sẽ dùng lệnh `SIGNAL SQLSTATE` chặn insert.
2. **`trg_HopDong_AfterInsert`**
   - **Vị trí file**: `02_Database/Triggers/trg_LogHopDong.sql` (Từ dòng 23)
   - **Mục đích**: Audit log (Nhật ký hệ thống) chống chối bỏ trách nhiệm.
   - **Chi tiết**: Kích hoạt tự động ngay sau khi có sự kiện `AFTER INSERT` ở bảng `HopDong`. Chuyển toàn bộ dữ liệu mới (`NEW`) thành định dạng JSON và ghi một bản sao vào bảng lịch sử `AuditLog_HopDong`.
