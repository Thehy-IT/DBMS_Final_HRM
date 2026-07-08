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
  Chuyên viên Nhân sự (HR1 thực hiện rà soát thông tin hồ sơ để chỉnh sửa Số Điện Thoại của nhân viênNV000006 trên giao diện UI. Cùng thời điểm đó, HR2 nhận được yêu cầu cập nhật Mã Số Thuế cá nhân cho cùng nhân viên này. Cả hai cùng tải form thông tin của nhân viên NV000006. HR1 thực hiện lưu số điện thoại thành công. Tuy nhiên ngay sau đó 1 giây, HR2 bấm lưu mã số thuế. Kết quả là toàn bộ thông tin của HR2 lưu đè lên HR1 do form UI của HR2 gửi lên nguyên bộ dữ liệu cũ kèm mã số thuế mới, làm mất đi số điện thoại mà HR1 vừa mới bỏ công sửa.
* **Danh sách các cách khắc phục:**

  1. **Khóa bi quan (Pessimistic Locking):** Sử dụng câu lệnh `SELECT ... FOR UPDATE` khi đọc dữ liệu để khóa bản ghi (Row-level Lock). Bất kỳ ai muốn lấy bản ghi đó để sửa đều phải chờ giao dịch hiện tại hoàn tất.
  2. **Khóa lạc quan (Optimistic Locking):** Thêm một cột `Version` (phiên bản) hoặc `LastModified` vào bảng `NhanVien`. Mỗi lần Update sẽ kiểm tra `WHERE Version = <Version_cũ>`, nếu thành công thì `Version = Version + 1`. Nếu không có dòng nào được update nghĩa là dữ liệu đã bị sửa bởi người khác, báo lỗi trên UI yêu cầu tải lại.
  3. **Cập nhật tương đối/cục bộ (Partial Update):** UI chỉ gửi lên đúng các trường cần thay đổi thay vì nguyên object. Dùng lệnh UPDATE chỉ update đúng cột cần thiết: `UPDATE NhanVien SET MaSoThue = ? WHERE MaNV = ?`.
* **Lựa chọn cách tốt nhất & Lý do:**
  Cách tốt nhất là **Cập nhật cục bộ (Partial Update) kết hợp Khóa lạc quan (Optimistic Locking)**.
  Lý do: Trong các hệ thống Web đa người dùng, dùng `SELECT ... FOR UPDATE` ở request HTTP rất nguy hiểm vì có thể khóa chết database nếu người dùng giữ trạng thái treo (Timeout). Việc kết hợp Optimistic Locking và Partial Update giúp đảm bảo vẹn toàn dữ liệu nhưng không gây khóa cơ sở dữ liệu, tối ưu hiệu suất truy cập song song rất tốt.
* **Chi tiết Demo kết hợp UI & CSDL:**
  **Bước 1: Tái hiện lỗi**

  - **Trên UI (Cửa sổ 1 - HR1) & (Cửa sổ 2 - HR1):** Cả hai đăng nhập bằng 2 tài khoản khác nhau, cùng mở trang "Chỉnh sửa hồ sơ nhân viên NV000006". Cả 2 form lúc này đều hiện *Số điện thoại cũ, Mã số thuế cũ*.
  - **Thao tác UI (HR1):** Nhập số điện thoại mới `0987654321` và ấn nút **Lưu**. Toast message hiện "Thành công".
    *(Dưới DB: `UPDATE NhanVien SET SoDienThoai = '0987654321', MaSoThue = 'OLD_TAX' WHERE MaNV = 'NV000006';`)*.
  - **Thao tác UI (HR B - Sau 2 giây):** Nhập mã số thuế mới 9999999999 (vẫn để nguyên số ĐT cũ trên form) và ấn nút **Lưu**. Toast message hiện "Thành công".
    *(Dưới DB: `UPDATE NhanVien SET SoDienThoai = 'OLD_PHONE', MaSoThue = '99999999' WHERE MaNV = 'NV000006';`)*.
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
       WHERE MaNV = 'NV000006' AND Version = 1;
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
3. Mở **2 trình duyệt** khác nhau (hoặc 1 Tab thường và 1 Tab ẩn danh) và cùng truy cập trang sửa hồ sơ của nhân viên `NV000006`. Lúc này, cả hai form đều có *Số điện thoại cũ, Mã số thuế cũ*.
4. **Ở Tab 1 (HR1):** Nhập Số điện thoại mới và ấn **Lưu**. Hệ thống báo thành công. (Bản ghi dưới DB lúc này đã đổi Số điện thoại mới nhưng Mã số thuế vẫn là cũ).
5. **Ở Tab 2 (HR2):** Nhập Mã số thuế mới (vẫn giữ Số điện thoại cũ ban đầu trên form của B) và ấn **Lưu**. Hệ thống báo thành công.
6. F5 tải lại trang. Giảng viên sẽ thấy **Số điện thoại mới mà HR A vừa sửa đã biến mất** (bị ghi đè bởi giá trị cũ trên form của B). Đây chính là lỗi Lost Update.

**Kịch bản 2: Trình diễn tính năng Khắc phục (Khóa lạc quan)**

1. Mở file [.env](file:///D:/kelangthanghocIT/UTH/DBMS_Final_HRM/03_App/backend/.env) của Backend, đổi cấu hình thành:
   ```env
   ENABLE_OPTIMISTIC_LOCK=true
   ```
2. Khởi động lại Server Backend.
3. Thực hiện lại y hệt các bước từ **3 đến 5** ở Kịch bản 1.
4. **Kết quả:** Khi HR B ở Tab 2 ấn **Lưu**, hệ thống sẽ chặn lại ngay lập tức và hiện thông báo lỗi: **"Dữ liệu đã được cập nhật bởi một người khác. Vui lòng tải lại trang!"**. Số điện thoại của HR A được bảo toàn nguyên vẹn. Giao diện được kiểm soát chặt chẽ.

#### 6.2. Đọc dữ liệu rác (Dirty Read)

* **Ngữ cảnh đặc trưng mang tính hệ thống:**
  Chuyên viên HR1 đang mở Dashboard Báo Cáo Nhân Sự để xem tổng số lượng nhân viên hiện tại của toàn doanh nghiệp nhằm chốt báo cáo cuối tháng. Cùng thời điểm, hệ thống ngầm đang chạy Giao tác `sp_TiepNhanNhanSu` tiếp nhận 1 nhân sự cấp cao mới vào hệ thống. Việc `INSERT` nhân viên vào bảng `NhanVien` đã diễn ra, nhưng khi đến phần tạo tài khoản đăng nhập thì hệ thống bị lỗi (ví dụ: Email đã tồn tại). Giao tác `sp_TiepNhanNhanSu` lập tức bị `ROLLBACK`.
  Thảm họa xảy ra khi Báo cáo của HR1 đọc đúng lúc bản ghi nhân viên vừa `INSERT` xong nhưng chưa `ROLLBACK`. Kết quả báo cáo báo tổng số nhân viên tăng ảo thêm 1 người dù nhân viên đó chưa từng gia nhập thành công.
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

**Kịch bản 2: Trình diễn tính năng Khắc phục (Isolation Level)**

1. Mở file [.env](file:///D:/kelangthanghocIT/UTH/DBMS_Final_HRM/03_App/backend/.env), đổi cấu hình thành:
   ```env
   DEMO_DIRTY_READ=false
   ```
2. Khởi động lại Server Backend.
3. Gọi lại lệnh API giả lập ở Bước 3 của kịch bản 1.
4. Ngay lập tức quay lại trình duyệt và **nhấn F5 (Tải lại trang)** Dashboard.
5. **Kết quả:** Dashboard trả về số lượng nhân viên hoàn toàn chính xác (không bị tăng). Mức độ cô lập `READ COMMITTED` đã chặn luồng đọc dữ liệu khỏi việc quét qua dòng dữ liệu nhân viên đang trong trạng thái `UNCOMMITTED`. Dữ liệu hiển thị (Tổng nhân viên) trên UI không bị sai lệch dù đang có giao dịch Onboarding chạy song song.

#### 6.3. Không đọc lại được dữ liệu (Non-repeatable Read)

* **Ngữ cảnh đặc trưng mang tính hệ thống:**
  Trong hệ thống Tính lương, hr2 vào màn hình UI **"Bảng Lương"** (`/payroll`) và bấm nút **"Tính Lương"**. Tiến trình tính lương dưới Database (`sp_TinhLuong`) bắt đầu chạy. Nó sẽ thực hiện 2 bước độc lập:

  - Lần đọc 1: Lấy mức lương cơ bản hiện tại của nhân viên (VD: 25 triệu) để tính ra mức đóng Bảo Hiểm (BHXH).
  - Lần đọc 2 (Sau một khoảng thời gian xử lý các phép toán phức tạp): Lấy lại mức lương cơ bản để tính Tổng thu nhập và Thuế TNCN.

  Ngay trong khoảng thời gian giữa 2 lần đọc đó, một chuyên viên Nhân sự (HR) quyết định **chỉnh sửa Lương cơ bản trực tiếp** dưới Database của nhân viên đó từ 25 triệu lên 30 triệu (để vượt qua cơ chế chặn sửa của Trigger).
  Hậu quả của Non-repeatable Read: Khi quá trình tính lương hoàn tất, Phiếu lương sinh ra sẽ hiển thị Lương Cơ Bản là 30 triệu (Lần đọc 2), nhưng số tiền đóng Bảo hiểm lại tính trên mức 25 triệu (Lần đọc 1). Kế toán nhìn vào bảng lương trên giao diện sẽ thấy ngay một bút toán "sai bét" rành rành (Ví dụ: 8% của 30 triệu phải là 2.4 triệu, nhưng hệ thống lại hiện 2 triệu vì tính trên lương 25 triệu cũ).
* **Danh sách các cách khắc phục:**

  1. **Khóa bi quan (Pessimistic Locking) bằng `SELECT ... FOR UPDATE`**: Khi đọc Lương Cơ Bản ở Lần 1, ta khóa luôn bản ghi đó. HR muốn sửa lương sẽ bị treo chờ cho đến khi quá trình tính lương hoàn tất. Tuy nhiên, quá trình tính lương thường mất rất lâu, việc khóa này có thể làm tê liệt mọi thao tác liên quan đến nhân sự.
  2. **Tăng mức độ cô lập lên `REPEATABLE READ`**: Đảm bảo mọi lần `SELECT` trong cùng một giao dịch (transaction) đều đọc từ một bản ghi Snapshot nhất quán tại thời điểm bắt đầu giao dịch. Tuy nhiên có thể tốn kém bộ nhớ.
  3. **Tối ưu logic Code (Sử dụng biến cục bộ - Local Variable Snapshot)**: Thay vì đọc lại Database nhiều lần, ta chỉ đọc giá trị Lương Cơ Bản **MỘT LẦN DUY NHẤT** ở đầu Stored Procedure, gán vào một biến cục bộ (`SET v_cur_LuongCB = ...`), và dùng biến này cho toàn bộ các công thức tính toán về sau.
* **Lựa chọn cách tốt nhất & Lý do:**
  Cách tốt nhất thực tiễn là **Sử dụng biến cục bộ (Local Variable Snapshot)**.
  Lý do: Đây là giải pháp xử lý triệt để ở tầng Application/Procedure Logic. Không cần thay đổi mức độ cô lập (Isolation level), không tốn chi phí khóa (Locking) làm nghẽn hệ thống. Dữ liệu trong suốt một quá trình tính toán dài được đảm bảo tính nhất quán nội tại hoàn hảo.
* **Chi tiết Demo kết hợp UI (Thực hiện hoàn toàn qua Giao diện thay vì dùng SQL Workbench):**

  **Bước 1: Tái hiện lỗi (Bất nhất dữ liệu)**

  1. Mở file [.env](file:///D:/kelangthanghocIT/UTH/DBMS_Final_HRM/03_App/backend/.env) của Backend, đổi cấu hình thành `DEMO_NON_REPEATABLE_READ=true` và khởi động lại Server.
  2. Đảm bảo nhân viên `NV000006` đang có lương cơ bản mặc định là `25,000,000 ₫`.
  3. **Thao tác song song trên UI (Mở 2 Tab trình duyệt):**
     - **Tab 1 (HR1 - Tính lương)**: Vào màn hình **"Bảng Lương"** (`/payroll`). Bạn có thể chọn tháng trước đó (ví dụ tháng 6) dù thời gian hiện tại là tháng khác, rồi ấn nút **"Tính Lương"**. Hệ thống sẽ bắt đầu xoay (Loading) do đã được giả lập thời gian trễ 15 giây.
     - **Tab 2 (HR2 - Cập nhật hợp đồng)**: Ngay lập tức (trong 15s đó), vào màn hình **"Hợp đồng"**, tìm Hợp đồng của `NV000006` và thực hiện sửa đổi mức **Lương cơ bản** từ `25,000,000` thành `30,000,000` rồi Lưu lại. *(Lưu ý: Nhờ cải tiến thủ tục ở chế độ demo, hệ thống vẫn áp dụng mức thay đổi này dù bạn đang tính lương cho tháng cũ).*
  4. **Kết quả trên UI**: Sau 15 giây, quá trình tính lương ở Tab 1 hoàn tất. HR1 tải lại trang Bảng lương và bấm xem **Phiếu Lương** chi tiết của `NV000006`. Bạn sẽ thấy rõ sự sai lệch:
     - Dòng **Lương Cơ Bản hiển thị**: `30,000,000 ₫` (Đã nhận mức lương mới do bị đọc lại từ DB ở Lần 2).
     - Số tiền **Khấu trừ BHXH (8%)**: Vẫn là `2,000,000 ₫` (Hệ thống tính sai! 8% của 30 triệu đáng lẽ phải là 2.4 triệu, nhưng máy lại tính theo 25 triệu lúc ban đầu — Lần đọc 1).
       Đây là minh chứng trực quan nhất cho thấy lỗi không đọc lại được dữ liệu thực tế (Non-repeatable read) có thể demo dễ dàng 100% bằng giao diện UI!

  **Bước 2: Trình diễn tính năng Khắc phục (Sử dụng biến Snapshot)**

  1. Mở file [.env](file:///D:/kelangthanghocIT/UTH/DBMS_Final_HRM/03_App/backend/.env), đổi cấu hình về `DEMO_NON_REPEATABLE_READ=false` và khởi động lại Server. Đổi lại lương của `NV000006` về `25,000,000` trên UI Hợp đồng.
  2. Thực hiện lại y hệt thao tác ở **Bước 3** (Tab 1 bấm Tính lương -> Tab 2 đổi Hợp đồng lên 30 triệu).
  3. **Kết quả**: Khi xem lại bảng lương trên UI, toàn bộ mức lương, số tiền BHXH và các loại phụ phí đều được tính toán nhất quán dựa trên mức lương `25,000,000` (giá trị Snapshot ban đầu). Việc cập nhật hợp đồng lên 30 triệu của HR2 ở Tab 2 thành công nhưng không làm xáo trộn phép tính đang chạy, mức 30 triệu đó sẽ được áp dụng an toàn vào kỳ tính lương tháng sau. Không còn lỗi bất đồng bộ!
     *(Ghi chú kỹ thuật: Ở chế độ chuẩn `false`, `sp_TinhLuong.sql` được tối ưu hoá chỉ SELECT Lương 1 lần duy nhất đầu thủ tục, xoá bỏ điểm yếu đọc 2 lần sinh ra sai lệch).*

#### 6.4. Bóng ma (Phantom Read)

* **Ngữ cảnh đặc trưng mang tính hệ thống:**
  Kế toán cần chốt sổ quỹ lương toàn công ty trong tháng. Kế toán vào màn hình UI "Quản lý Lương", thấy danh sách tổng là N người (trạng thái Chưa chốt - Draft). Kế toán bấm nút **"Xác nhận"** (Chốt bảng lương). Đột nhiên chuyên viên nhân sự (HR) quyết định tuyển thêm 1 nhân sự mới (Onboarding). Trên giao diện Quản lý Nhân viên, HR điền thông tin và bấm **"Thêm mới"** nhân viên. Logic hệ thống lập tức tự động sinh ra 1 bảng lương Draft cho tháng đầu tiên của nhân sự mới đó. Tiến trình chốt sổ của Kế toán kết thúc, hệ thống duyệt chốt luôn cả bản ghi Draft vừa mới sinh ra kia thay vì N bản ghi gốc ban đầu. Bản ghi bóng ma (Phantom Row) này đã lọt vào quỹ thanh toán ngoài dự toán của kế toán, gây rủi ro thất thoát tài chính.
* **Danh sách các cách khắc phục:**

  1. Tăng mức độ cô lập lên `SERIALIZABLE`.
  2. Sử dụng Next-Key Locking với `SELECT ... FOR UPDATE` trong mức `REPEATABLE READ` của InnoDB.
* **Lựa chọn cách tốt nhất & Lý do:**
  Cách tốt nhất là **Sử dụng Next-Key Locking (`SELECT ... FOR UPDATE`) trong `REPEATABLE READ`**.
  Lý do: Mức `SERIALIZABLE` gây khóa đọc toàn cục làm treo hệ thống. InnoDB ở mức `REPEATABLE READ` hỗ trợ Next-Key Locking, chỉ cần gọi `SELECT * FROM BangLuong WHERE TrangThai='D' FOR UPDATE`, nó sẽ khóa chặt "khoảng không gian" (gap) điều kiện này. Thao tác **Thêm mới nhân viên** của HR trên UI sẽ quay vòng vòng chờ (Block) cho tới khi kế toán chốt sổ xong, ngăn chặn triệt để việc luồn hồ sơ mới vào lô đang duyệt.
* **Chi tiết Demo kết hợp UI & CSDL:**

  **Chuẩn bị trước mỗi lần demo:**
  Chạy file [06_demo/03_Phantom Read.sql](<file:///D:/kelangthanghocIT/UTH/DBMS_Final_HRM/06_demo/03_Phantom%20Read.sql>) trong MySQL Workbench để:

  - Đưa toàn bộ các bảng lương của tháng hiện tại về trạng thái Nháp (`D`) để Kế toán có danh sách chờ duyệt.
  - Recreate lại các trigger bảo vệ chống xóa/sửa với `MESSAGE_TEXT` an toàn (< 128 byte).

  **Bước 1: Tái hiện lỗi**

  - **Trên UI (Tab 1 - Kế toán):** Thấy danh sách bảng lương tháng hiện hành đang ở trạng thái Draft. Bấm nút **"Xác nhận"**. Nút sẽ quay loading chờ 10 giây.
    *(Dưới DB hệ thống đếm số lượng: `SELECT COUNT(*) FROM BangLuong WHERE Thang = ? AND Nam = ? AND TrangThai = 'D';`, sau đó bị `SLEEP(10)`).*
  - **Trên UI (Tab 2 - HR trong 10s Sleep):** Vào trang quản lý nhân viên, bấm **"Thêm mới"**, điền nhanh thông tin cơ bản cho nhân viên mới (Onboarding) và bấm **"Lưu"**.
    *(Dưới DB `POST /v1/employees` sau khi thêm vào bảng `NhanVien`, tự động chạy `INSERT IGNORE INTO BangLuong (...) VALUES (..., 'D')` để tạo bảng lương nháp đầu tiên cho nhân viên mới này).*
  - **Kết quả trên UI:** Sau khi Kế toán chờ đủ 10 giây, màn hình hiện Alert cảnh báo lỗi đỏ: *"LỖI BÓNG MA (Phantom Read)! Kế toán ban đầu duyệt N bản ghi, nhưng hệ thống lại chốt thành công N+1 bản ghi. Dư ra 1 bóng ma!"*.

  **Bước 2: Triển khai khắc phục (Đã thực hiện hoàn thiện bằng Bật/Tắt qua `.env`)**

  1. **Cấu hình môi trường (Bật/Tắt chế độ Gap/Next-Key Locking)**:
     Điều chỉnh biến môi trường trong file [.env](file:///D:/kelangthanghocIT/UTH/DBMS_Final_HRM/03_App/backend/.env):

     ```env
     DEMO_PHANTOM_READ=true
     ```

     * `true`: Không sử dụng `FOR UPDATE` (Tái hiện lỗi Bóng Ma trong môi trường REPEATABLE READ mặc định của MySQL vì MySQL không khóa Insert mới).
     * `false`: Kích hoạt Next-Key Locking bằng cách tự động gắn thêm lệnh `FOR UPDATE` vào cuối câu `SELECT` đếm số lượng. Khóa toàn bộ khoảng trống (Gap Lock), chặn triệt để giao dịch Insert của HR, triệt tiêu lỗi.
  2. **Xử lý tại API Backend ([server.js](file:///D:/kelangthanghocIT/UTH/DBMS_Final_HRM/03_App/backend/server.js))**:
     Hệ thống đã chèn trực tiếp logic theo dõi Bóng ma vào các luồng nghiệp vụ thực tế của Frontend:

     - **API Xác nhận bảng lương (`PUT /v1/payroll/confirm`):**
       (Đếm số bảng lương Draft hiện có, sau đó `SLEEP(10)` mô phỏng đang xử lý tổng hợp dữ liệu, và cuối cùng `UPDATE` toàn bộ sang trạng thái Closed 'C'. Nếu biến môi trường là false, hệ thống tự động nối thêm `FOR UPDATE` ở câu đếm).
     - **API Thêm nhân viên mới (`POST /v1/employees`):**
       (Khi HR thêm một nhân sự mới vào hệ thống, hệ thống lập tức `INSERT` một bảng lương Draft 'D' dở dang vào tháng hiện hành của nhân sự đó để chuẩn bị cho kỳ lương đầu tiên).

  ---

  ### HƯỚNG DẪN DEMO CHO GIẢNG VIÊN (PHANTOM READ)

  *Kịch bản này sử dụng trực tiếp các thao tác thực tế trên giao diện hệ thống (không dùng trang demo riêng) để cho thấy lỗi phát sinh như thế nào trong môi trường sản xuất thực tế.*

  #### Kịch bản 1: Tái hiện lỗi Bóng Ma ban đầu (Trước khi sửa)

1. Mở file [.env](file:///D:/kelangthanghocIT/UTH/DBMS_Final_HRM/03_App/backend/.env) của Backend, đổi cấu hình thành:
   ```env
   DEMO_PHANTOM_READ=true
   ```
2. Khởi động lại Server Backend.
3. Mở 2 Tab trình duyệt (tượng trưng cho 2 nhân sự đang làm việc đồng thời):
   - **Tab 1 (Kế toán):** Vào trang Quản lý Lương (`http://localhost:3000/payroll`), chọn tháng hiện tại (đảm bảo đang có danh sách các bảng lương ở trạng thái **Chưa chốt**).
   - **Tab 2 (HR):** Vào trang Quản lý Nhân viên (`http://localhost:3000/employees`), bấm **Thêm mới**, gõ sẵn một vài thông tin bắt buộc (VD: Họ tên, Giới tính, Phòng ban...) và để sẵn chuột ở nút **Lưu**.
4. Ở **Tab 1 (Kế toán)**, bấm nút **"Xác nhận"** (để duyệt chốt lương). Nút sẽ quay loading chờ 10 giây (do hệ thống mô phỏng độ trễ xử lý).
5. Ngay lập tức (trong vòng 10 giây đó), chuyển sang **Tab 2 (HR)** và bấm nút **"Lưu"** để hoàn tất việc thêm nhân viên mới (Onboarding).
6. **Kết quả:**
   - Màn hình HR sẽ báo thêm nhân viên thành công ngay lập tức.
   - Sau đó khi Kế toán quay xong đủ 10s, màn hình Kế toán sẽ văng ra cảnh báo Alert: `"LỖI BÓNG MA (Phantom Read)! Kế toán ban đầu duyệt X bản ghi, nhưng hệ thống lại chốt thành công X+1 bản ghi. Dư ra 1 bóng ma!"`.
   - Lý do: Khi HR nhận nhân viên mới, hệ thống tự động sinh ra 1 bảng lương Draft cho tháng đầu tiên. Câu lệnh `UPDATE` ở cuối quy trình của Kế toán đã vô tình quét trúng bản ghi Draft mới sinh đó và chốt duyệt luôn, biến nó thành Bóng Ma làm sai lệch số lượng Kế toán tính toán ban đầu, gây rủi ro thất thoát quỹ lương.

**Kịch bản 2: Trình diễn tính năng Khắc phục (Next-Key Locking)**

1. Mở file [.env](file:///D:/kelangthanghocIT/UTH/DBMS_Final_HRM/03_App/backend/.env), đổi cấu hình thành:
   ```env
   DEMO_PHANTOM_READ=false
   ```
2. Khởi động lại Server Backend.
3. Chạy lại file [03_Phantom Read.sql](<file:///D:/kelangthanghocIT/UTH/DBMS_Final_HRM/06_demo/03_Phantom%20Read.sql>) để trả lại dữ liệu về trạng thái Draft.
4. Lặp lại thao tác chuẩn bị ở Bước 3 của kịch bản 1 (Điền sẵn form Thêm nhân viên mới ở Tab HR).
5. Bấm nút **"Xác nhận"** bên Kế toán, và ngay lập tức bấm **"Lưu"** bên HR.
6. **Kết quả:**
   - Lần này, thao tác Thêm mới nhân viên của HR sẽ bị "đứng hình" chờ đợi (Loading...) và không thể lưu ngay lập tức.
   - Sau 10 giây, Kế toán chạy xong và hiện thông báo: `"Xác nhận thành công X bảng lương."` (không có lỗi). Ngay sau khi Kế toán nhận thông báo, giao dịch tạo bảng lương nháp của HR mới được nhả khóa và lưu thành công.
   - Lý do: Cú pháp `SELECT ... FOR UPDATE` đã yêu cầu InnoDB thiết lập Next-Key Lock (kết hợp Record Lock và Gap Lock) trên vùng dữ liệu `Thang=..., Nam=..., TrangThai=D`. Mọi nỗ lực `INSERT` vào vùng này từ các giao dịch khác (như thao tác tạo Draft lương của HR) đều bị "Block" cho đến khi giao dịch của Kế toán hoàn thành!

### 7. Deadlock (Khóa chết)

* **Ngữ cảnh đặc trưng mang tính hệ thống:**
  Trong thực tế, hai chuyên viên nhân sự (HR) có thể làm việc trên cùng một nhân sự tại cùng một thời điểm:

  - **Giao dịch A (HR 1 - Sửa Hồ Sơ Nhân Viên):** Trên giao diện "Quản lý nhân viên", HR 1 đang cập nhật thông tin cá nhân của `NV000006`. Quá trình lưu sẽ thực hiện cập nhật bảng `NhanVien`, sau đó thực hiện một tác vụ đồng bộ đòi hỏi cập nhật thông tin liên đới ở bảng `LuongCoBan`. (Trình tự: Khóa `NhanVien` -> Khóa `LuongCoBan`).
  - **Giao dịch B (HR 2 - Sửa Hợp Đồng / Tăng Lương):** Trên giao diện "Quản lý Hợp đồng", HR 2 đang điều chỉnh mức lương cơ bản mới cho `NV000006`. Quá trình lưu sẽ ưu tiên ghi nhận bảng `LuongCoBan` trước, sau đó hệ thống cố gắng ghi một cờ chú thích vào bảng `NhanVien`. (Trình tự: Khóa `LuongCoBan` -> Khóa `NhanVien`).
    Nếu hai HR cùng ấn nút **Lưu** cùng lúc trên cùng 1 nhân viên: Giao dịch A khóa `NhanVien` chờ `LuongCoBan`. Giao dịch B khóa `LuongCoBan` chờ `NhanVien`. Cả hai rơi vào trạng thái chờ nhau vô tận. MySQL sẽ tự động "Kill" một giao dịch (Rollback) để cứu vãn hệ thống, khiến 1 trong 2 HR nhận được thông báo lỗi 500 (Deadlock).
* **Danh sách các cách khắc phục:**

  1. Đồng nhất thứ tự lấy khóa (Consistent Lock Ordering) giữa mọi Giao tác và Stored Procedures.
  2. Tối ưu hóa các truy vấn bằng Index để thu nhỏ phạm vi quét khóa.
  3. Chia nhỏ giao dịch lớn thành các giao dịch nhỏ hơn để nhả khóa sớm.
  4. Cơ chế Deadlock Retry tại tầng Ứng Dụng (Node.js/Backend).
* **Lựa chọn cách tốt nhất & Lý do:**
  Cách tốt nhất là **Đồng nhất thứ tự lấy khóa (Consistent Lock Ordering)** từ mức thiết kế Database và luồng truy vấn Backend.
  Lý do: Đây là phương pháp phòng bệnh triệt để nhất. Nếu mọi luồng code đều tuân thủ quy tắc lấy khóa theo thứ tự phân tầng từ bảng Master đến bảng Detail: "Luôn Khóa/UPDATE `NhanVien` trước -> tới `HopDong` -> tới `LuongCoBan`", thì Deadlock chéo không bao giờ có cơ hội hình thành. Kết hợp bắt lỗi `ER_LOCK_DEADLOCK` ở tầng Node.js Backend để đảm bảo UX, báo lỗi rõ ràng nếu có bất ngờ xảy ra thay vì làm sập ứng dụng.
* **Chi tiết Demo kết hợp UI & CSDL:**
  **Bước 1 & Bước 2: Triển khai khắc phục (Đã thực hiện hoàn thiện bằng Bật/Tắt qua `.env`)**

  1. **Cấu hình môi trường (Bật/Tắt chế độ Lấy khóa ngược chiều)**:
     Thêm biến môi trường trong file [.env](file:///D:/kelangthanghocIT/UTH/DBMS_Final_HRM/03_App/backend/.env):

     ```env
     DEMO_DEADLOCK=true
     ```

     * `true`: Bật mô phỏng Deadlock. Tiến trình Sửa Hợp Đồng cố tình đi ngược chuẩn, lấy khóa `LuongCoBan` trước rồi mới lấy khóa `NhanVien`, đồng thời áp dụng `DO SLEEP(5)` để cố tình tạo độ trễ va chạm với Tiến trình Sửa Nhân Viên.
     * `false`: Tiến trình tuân thủ bộ chuẩn: Sửa Hợp đồng chỉ tập trung cập nhật `HopDong` và `LuongCoBan` đúng luồng, không sinh ra vòng lặp ngược ngạo khóa `NhanVien`.
  2. **Xử lý tại API Backend ([server.js](file:///D:/kelangthanghocIT/UTH/DBMS_Final_HRM/03_App/backend/server.js))**:
     Hệ thống xử lý trực tiếp vào 2 API vận hành thật của UI:

     - `PUT /v1/employees/:id` (Tiến trình A)
     - `PUT /v1/contracts/:id` (Tiến trình B)

  ---

  ### HƯỚNG DẪN DEMO CHO GIẢNG VIÊN (DEADLOCK) TRỰC QUAN TRÊN UI

  #### Kịch bản 1: Tái hiện lỗi Khóa Chết (Deadlock) qua tương tác người dùng

1. Mở file [.env](file:///D:/kelangthanghocIT/UTH/DBMS_Final_HRM/03_App/backend/.env) của Backend, đổi cấu hình thành:
   ```env
   DEMO_DEADLOCK=true
   ```
2. Khởi động lại Server Backend.
3. Mở **Tab 1 (Giao diện Quản lý Nhân Viên)**, bấm nút **Sửa** (Edit) nhân viên `NV000006`. Đổi ghi chú hoặc địa chỉ. Đừng bấm lưu vội.
4. Mở **Tab 2 (Giao diện Quản lý Hợp Đồng)**, tìm hợp đồng của `NV000006`, bấm **Sửa**, điền lại một con số Lương cơ bản mới bất kỳ. Đừng bấm lưu vội.
5. **Thực thi đồng thời:**
   - Mở Tab 1 (Nhân viên), bấm nút **Lưu**. (Lúc này hệ thống đã khóa thành công bảng `NhanVien` và đang sleep chờ).
   - Ngay lập tức (trong vòng dưới 5 giây), chuyển sang Tab 2 (Hợp Đồng) và bấm nút **Lưu**.
6. **Kết quả trên UI:** Cả hai tab sẽ quay xoay (loading). Hết thời gian chờ 5 giây của DB, một trong hai tab sẽ hiển thị báo lỗi Pop-up/Toast màu đỏ: `"LỖI KHÓA CHẾT (DEADLOCK)! Hai giao dịch tự khóa chéo lẫn nhau. MySQL đã phát hiện và tự động hủy giao dịch này..."`. Tab còn lại sẽ báo Thành công. Giao diện trực quan cho thấy hệ thống đã bóc tách và ngăn chặn sập server thành công!

**Kịch bản 2: Trình diễn tính năng Khắc phục (Đồng nhất hướng lấy khóa chuẩn)**

1. Mở file [.env](file:///D:/kelangthanghocIT/UTH/DBMS_Final_HRM/03_App/backend/.env), đổi cấu hình thành:
   ```env
   DEMO_DEADLOCK=false
   ```
2. Khởi động lại Server Backend.
3. Cài đặt lại **Tab 1** và **Tab 2** như bước 3, 4 ở Kịch bản 1.
4. Lặp lại thao tác ấn **Lưu** nhanh ở Tab 1 rồi sang Tab 2.
5. **Kết quả:** Lần này hệ thống Backend tuân thủ luật lấy khóa một chiều (`HopDong` -> `LuongCoBan`), không vòng ngược lại sửa `NhanVien`. Do đó, vòng lặp Deadlock bị phá vỡ. Cả hai tab sẽ đều xử lý trơn tru và hiện thông báo **"Lưu thành công"**. Không hề xảy ra tranh chấp dẫn đến bị ngắt tiến trình!

---

### 8. Lưu ý

#### 8.1. Quy định mức Lương tối thiểu vùng trong dự án

Bảng lương cơ bản tối thiểu được cấu hình bằng các ràng buộc dữ liệu (`CHECK CONSTRAINTS`) dưới Database để tránh nhập sai quy định pháp luật:

* **Vùng 1:** Lương cơ bản tối thiểu từ **`4,960,000` VNĐ** (Áp dụng các khu vực đô thị đặc biệt như TP. Hồ Chí Minh, Hà Nội...).
* **Vùng 2:** Lương cơ bản tối thiểu từ **`4,410,000` VNĐ** (Áp dụng các khu vực ngoại thành, thành phố trực thuộc tỉnh...).
* **Vùng 3:** Lương cơ bản tối thiểu từ **`3,860,000` VNĐ** (Áp dụng các khu vực thị xã, huyện...).
* **Vùng 4:** Lương cơ bản tối thiểu từ **`3,450,000` VNĐ** (Áp dụng các khu vực nông thôn, vùng sâu vùng xa...).

#### 8.2. Ý nghĩa các ký hiệu/mã trạng thái trong dự án

* **Trạng thái Nhân Viên (`NhanVien.TrangThai`):**
  * `A` (Active): Đang làm việc / Hoạt động.
  * `I` (Inactive): Nghỉ việc.
  * `P` (Probation): Thử việc.
  * `T` (Temporary): Tạm hoãn hợp đồng (Sử dụng đặc biệt trong logic mô phỏng lỗi Bóng Ma).
* **Trạng thái Hợp Đồng (`HopDong.TrangThai`):**
  * `A` (Active): Đang có hiệu lực.
  * `E` (Expired): Đã hết hiệu lực.
  * `D` (Draft): Bản nháp.
* **Trạng thái Bảng Lương (`BangLuong.TrangThai`):**
  * `D` (Draft): Bản nháp (Đang tính toán).
  * `C` (Confirmed): Đã xác nhận / Đã chốt (Chờ thanh toán).
  * `P` (Paid): Đã thanh toán thành công.
  * `L` (Locked): Đã khóa dữ liệu.
* **Mã Loại Hợp Đồng (`MaLoaiHD`):**
  * `1`: Hợp đồng thử việc (Không bắt buộc đóng các loại bảo hiểm xã hội).
  * `2`: Hợp đồng xác định thời hạn 1 năm.
  * `3`: Hợp đồng xác định thời hạn 3 năm.
  * `4`: Hợp đồng không xác định thời hạn.

#### 8.3. Biểu thuế Thu nhập cá nhân (TNCN) lũy tiến 7 bậc

Thuế TNCN đối với thu nhập từ tiền lương, tiền công được tính theo phương pháp lũy tiến từng phần (Thông tư 111/2013/TT-BTC) dựa trên Thu nhập tính thuế (TNTT):

* **Giảm trừ gia cảnh:**
  * Giảm trừ bản thân: **`11,000,000` VNĐ / tháng**.
  * Giảm trừ người phụ thuộc: **`4,400,000` VNĐ / người / tháng**.
* **Các bậc tính thuế:**
  * **Bậc 1:** Thu nhập tính thuế đến `5,000,000` VNĐ / tháng — Thuế suất **5%**.
  * **Bậc 2:** Thu nhập tính thuế trên `5,000,000` đến `10,000,000` VNĐ / tháng — Thuế suất **10%**.
  * **Bậc 3:** Thu nhập tính thuế trên `10,000,000` đến `18,000,000` VNĐ / tháng — Thuế suất **15%**.
  * **Bậc 4:** Thu nhập tính thuế trên `18,000,000` đến `32,000,000` VNĐ / tháng — Thuế suất **20%**.
  * **Bậc 5:** Thu nhập tính thuế trên `32,000,000` đến `52,000,000` VNĐ / tháng — Thuế suất **25%**.
  * **Bậc 6:** Thu nhập tính thuế trên `52,000,000` đến `80,000,000` VNĐ / tháng — Thuế suất **30%**.
  * **Bậc 7:** Thu nhập tính thuế trên `80,000,000` VNĐ / tháng — Thuế suất **35%**.
