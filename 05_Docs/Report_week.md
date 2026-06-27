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
  Kế toán trưởng đang mở Dashboard Báo Cáo Nhân Sự trên UI để xem tổng quỹ lương hiện hữu của toàn doanh nghiệp. Cùng thời điểm, hệ thống ngầm đang chạy Giao tác `sp_TiepNhanNhanSu` tiếp nhận 1 nhân sự cấp cao mới vào hệ thống với Lương Cơ Bản là 100 triệu. Việc `INSERT` nhân viên và Lương cơ bản đã diễn ra, nhưng khi đến phần tạo tài khoản đăng nhập thì hệ thống bị lỗi Email đã tồn tại. Giao tác `sp_TiepNhanNhanSu` bị `ROLLBACK`.
  Thảm họa xảy ra khi Dashboard của Kế toán trưởng đọc đúng lúc bản ghi 100 triệu vừa `INSERT` xong nhưng chưa `ROLLBACK`. Kết quả báo cáo báo quỹ lương tăng ảo thêm 100 triệu dù nhân viên đó chưa từng gia nhập.
* **Danh sách các cách khắc phục:**

  1. Tăng mức độ cô lập (Isolation Level) lên `READ COMMITTED`.
  2. Tăng mức độ cô lập lên `REPEATABLE READ`.
  3. Tăng mức độ cô lập lên `SERIALIZABLE`.
* **Lựa chọn cách tốt nhất & Lý do:**
  Cách tốt nhất là **`READ COMMITTED` (hoặc `REPEATABLE READ` vì InnoDB mặc định đã là REPEATABLE READ)**.
  Lý do: Để chống lại Dirty Read, chỉ cần `READ COMMITTED` là đủ. Ở mức này, giao dịch Báo cáo chỉ nhìn thấy những dữ liệu đã được `COMMIT` thành công, hoàn toàn loại bỏ được dữ liệu "rác" từ các transaction đang dở dang.
* **Chi tiết Demo kết hợp UI & CSDL:**
  **Bước 1: Tái hiện lỗi**

  - **Trên CSDL (Giả lập Job Onboarding bị treo):**
    ```sql
    START TRANSACTION;
    INSERT INTO NhanVien (MaNV, HoTen, GioiTinh, NgaySinh, CCCD, MaPB, MaCV, NgayVaoLam) 
    VALUES ('NV888888', 'Giám Đốc Mới', 'M', '1990-01-01', '012345678910', 'PB0001', 'CV0001', '2025-01-01');
    INSERT INTO LuongCoBan (MaNV, LuongCB, LuongDongBH, NgayHieuLuc) 
    VALUES ('NV888888', 100000000, 46800000, '2025-01-01');
    DO SLEEP(8); -- Giả lập đang xử lý bước tạo tài khoản gửi mail
    ROLLBACK; -- Giả lập bị lỗi cuối cùng
    ```
  - **Trên UI (Kế toán trưởng - Trong 8s Sleep):** Nhấn nút **"Xuất Báo Cáo Quỹ Lương Tổng Quan"**.
    *(Dưới DB API gọi báo cáo đang bị set cố tình lỗi: `SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED; CALL sp_BaoCaoNhanSu_TongQuan();`)*.
  - **Kết quả trên UI:** Biểu đồ hiển thị trên màn hình bị vọt lên thêm 100,000,000 đ từ `NV888888`. Sau 8s, nhân viên kia rollback biến mất, nhưng Kế toán trưởng đã xuất file Excel sai lệch.

  **Bước 2: Triển khai khắc phục**
  Bọc chuẩn API gọi báo cáo ở tầng Backend bằng mức `READ COMMITTED`:

  ```sql
  SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;
  START TRANSACTION;
  CALL sp_BaoCaoNhanSu_TongQuan();
  COMMIT;
  ```

  *(Lúc này, dù bấm nút Báo cáo trên UI vào giữa lúc Onboarding đang chạy, Biểu đồ vẫn không tính dòng 100tr đang `UNCOMMITTED`, dữ liệu hiển thị hoàn toàn chính xác).*

#### 6.3. Không đọc lại được dữ liệu (Non-repeatable Read)

* **Ngữ cảnh đặc trưng mang tính hệ thống:**
  Kế toán ấn nút "Tính lương tháng 5" trên UI, hệ thống chạy `sp_TinhLuong` là một đường ống rất dài. Giả sử tiến trình đang xử lý tính lương cho `NV000001`. Bước 2: đọc `LuongCoBan` ra (hiện là 20 triệu) để đóng làm trần tính BHXH. Máy chủ xử lý tác vụ bị nghẽn nên ngưng lại vài giây (SLEEP). Lúc này, Nhân sự HR nhấn nút "Duyệt thăng chức" trên UI, nâng lương cơ bản của `NV000001` lên 30 triệu, thực hiện `UPDATE` và `COMMIT` thành công. Tiến trình `sp_TinhLuong` tiếp tục chạy đến bước 6: Tính Thuế TNCN, nó lại thực hiện `SELECT LuongCB` và thu được 30 triệu.
  Hậu quả: Tiền BHXH (8%) bị trừ ở mức 20 triệu, nhưng Thuế TNCN (thuế suất cao) bị tính cấn trừ dựa trên thu nhập 30 triệu. Cùng 1 kỳ lương nhưng công thức đọc 2 mức lương khác nhau.
* **Danh sách các cách khắc phục:**

  1. Tăng mức độ cô lập lên `REPEATABLE READ`.
  2. Sử dụng biến cục bộ tạm thời để lưu trữ thay vì truy vấn `SELECT` lại từ bảng dữ liệu vật lý.
  3. Tăng mức độ cô lập lên `SERIALIZABLE`.
* **Lựa chọn cách tốt nhất & Lý do:**
  Cách tốt nhất là **Kết hợp dùng biến tạm trong thủ tục lưu trữ VÀ thiết lập cô lập `REPEATABLE READ`**.
  Lý do: Lưu giá trị `LuongCoBan` vào một biến cục bộ ngay từ đầu (`DECLARE v_LuongCB DECIMAL(15,2);`) vừa triệt tiêu lỗi, vừa tăng tốc độ xử lý SP vì không cần Query bảng lại.
* **Chi tiết Demo kết hợp UI & CSDL:**
  **Bước 1: Tái hiện lỗi**

  - **Trên CSDL (Kế toán chạy Tính Lương):**
    ```sql
    SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;
    START TRANSACTION;
    -- Đọc lương lần 1 để tính BHXH (ra 20tr)
    SELECT LuongCB INTO @luongCB_BHXH FROM LuongCoBan WHERE MaNV = 'NV000001' ORDER BY NgayHieuLuc DESC LIMIT 1;
    DO SLEEP(8); -- Gặp độ trễ
    -- Đọc lương lần 2 để tính Thuế TNCN (sau 8s sẽ đọc ra 30tr vì HR can thiệp)
    SELECT LuongCB INTO @luongCB_Thue FROM LuongCoBan WHERE MaNV = 'NV000001' ORDER BY NgayHieuLuc DESC LIMIT 1;
    COMMIT;
    ```
  - **Trên UI (HR - Trong 8s Sleep):** Chuyên viên HR vào form "Hợp đồng & Lương", đổi Mức lương cơ bản của NV000001 thành 30.000.000đ và bấm nút **"Cập Nhật"**.
  - **Kết quả trên UI (Kế toán):** Khi tiến trình tính lương chạy xong, Kế toán mở trang "Phiếu Lương Cá Nhân" của NV000001. Hệ thống hiển thị: *Thu nhập đóng BHXH = 20tr, nhưng Thu nhập tính Thuế TNCN = 30tr*. Công thức hiển thị trên UI sai lệch hoàn toàn.

  **Bước 2: Triển khai khắc phục**
  Sửa cấu trúc gọi lệnh trong SP `sp_TinhLuong`:

  ```sql
  -- Thay vì liên tục truy vấn SELECT bảng LuongCoBan ở mỗi bước
  DECLARE v_LuongCoBan_Current DECIMAL(15,2);
  -- Lấy snapshot một lần duy nhất tại thời điểm bắt đầu tính toán
  SELECT LuongCB INTO v_LuongCoBan_Current 
  FROM LuongCoBan WHERE MaNV = p_MaNV ORDER BY NgayHieuLuc DESC LIMIT 1;
  -- Dùng biến v_LuongCoBan_Current để tính toán chung cho cả BHXH và Thuế
  ```

#### 6.4. Bóng ma (Phantom Read)

* **Ngữ cảnh đặc trưng mang tính hệ thống:**
  Kế toán Lương cần chốt sổ toàn bộ nhân viên phòng IT. Kế toán vào màn hình UI "Chốt lương", thấy danh sách tổng là 20 người (trạng thái Draft). Kế toán bấm nút **"Chốt và Xuất Quỹ"** (hệ thống chạy ngầm `sp_ChotBangLuong`). Đột nhiên HR quyết định sa thải 1 nhân sự cấp dưới phòng IT, trên UI nhân sự bấm nút **"Thanh lý hợp đồng"**. Logic nghỉ việc lập tức sinh ra 1 bảng lương Draft dở dang cho những ngày làm việc cuối cùng. Tiến trình chốt quỹ của Kế toán chạy xong, thông báo UI trả về: "Đã chốt thành công 21 bản ghi". Bản ghi bóng ma (Phantom Row) này đã thâm nhập vào quỹ thanh toán ngoài dự toán của kế toán.
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

  **Bước 2: Triển khai khắc phục**
  Sửa mã SQL trong `sp_ChotBangLuong` để áp dụng Next-Key Locking:

  ```sql
  START TRANSACTION;
  -- Quét qua các dòng và khóa chặt (Lock Rows + Gap Lock)
  SELECT * FROM BangLuong WHERE Thang = 5 AND TrangThai = 'D' FOR UPDATE;

  -- Xử lý chốt sổ
  UPDATE BangLuong SET TrangThai = 'C' WHERE Thang = 5 AND TrangThai = 'D';
  COMMIT;
  ```

  *(Sau khi fix, nếu HR bấm "Thanh lý hợp đồng" trong lúc Kế toán đang chốt lương, UI của HR sẽ hiển thị Loading chờ cho đến khi Kế toán làm xong, bảo đảm toàn vẹn dữ liệu).*

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
  **Bước 1: Tái hiện lỗi Deadlock**

  - **Trên CSDL (Mô phỏng Giao dịch A - Thăng chức):**
    ```sql
    START TRANSACTION;
    UPDATE NhanVien SET MaCV = 'CV0002' WHERE MaNV = 'NV000001'; -- Giữ khóa NhanVien
    DO SLEEP(5); 
    UPDATE LuongCoBan SET LuongCB = 40000000 WHERE MaNV = 'NV000001'; -- Bị kẹt chờ
    COMMIT;
    ```
  - **Trên UI (Giao dịch B - Kỷ luật):** Trong thời gian 5s Sleep kia, HR khác vào màn hình Kỷ luật, bấm nút **"Xác nhận hạ lương"** cho cùng `NV000001`.
    *(Dưới DB Backend gọi API xử lý ngược: Update `LuongCoBan` trước, Update `NhanVien` sau).*
  - **Kết quả:** Ngay lập tức UI của tiến trình B báo lỗi đỏ chót: *"Hệ thống bận, Error 500: Lỗi 1213 Deadlock found"*. Transaction của tiến trình B bị văng và rollback, giao dịch A thì hoàn tất an toàn.

  **Bước 2: Triển khai khắc phục**
  Thiết lập bộ quy chuẩn "Quy tắc truy cập bảng HRPayroll":
  *(Luật: NhanVien -> HopDong -> LuongCoBan -> BangLuong)*.
  Sửa mã nguồn Backend/SP của thao tác Kỷ luật để tuân thủ luật lấy khóa này:

  ```sql
  START TRANSACTION;
  -- Dù logic kỷ luật là đánh vào tiền lương, ta vẫn phải UPDATE bảng NhanVien TRƯỚC để lấy khóa đúng trật tự.
  UPDATE NhanVien SET GhiChu = 'Bị kỷ luật' WHERE MaNV = 'NV000001'; 
  UPDATE LuongCoBan SET LuongCB = 15000000 WHERE MaNV = 'NV000001'; 
  COMMIT;
  ```

  *(Lúc này, nếu 2 người dùng ấn nút song song trên giao diện, Request sau sẽ chỉ đứng xếp hàng trật tự chờ Request trước hoàn tất ở vòng ngoài bảng NhanVien, hoàn toàn không xảy ra tình trạng khóa chéo văng lỗi).*

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
