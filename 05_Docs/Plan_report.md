# Kế Hoạch Phân Công Báo Cáo Dự Án HRPayrollSystem (Nhóm 4 Người)

Bản kế hoạch này phân chia nội dung báo cáo dự án Quản lý Nhân sự và Tiền lương (HRPayrollSystem) thành 4 phần chuyên biệt, đảm bảo mỗi thành viên có một khối lượng công việc cân bằng và bao quát toàn bộ các khía cạnh kỹ thuật quan trọng của cơ sở dữ liệu.

---

## 👨‍💻 Người 1: Tổng quan Dự án, Kiến trúc CSDL & Data Access (Views)

**Mục tiêu:** Cung cấp cho người nghe cái nhìn toàn cảnh về hệ thống, cấu trúc dữ liệu và cách trích xuất thông tin thông qua Views.

**Nội dung chi tiết:**

1. **Tổng quan dự án HRPayrollSystem:**
   * Bài toán đặt ra và mục tiêu của dự án (Quản lý hồ sơ nhân viên, phòng ban, chấm công, tính lương).
   * Phạm vi nghiệp vụ được giải quyết.
2. **Kiến trúc Cơ sở dữ liệu (Database Architecture):**
   * Trình bày mô hình thực thể kết hợp (ERD) hoặc Lược đồ cơ sở dữ liệu.
   * Giới thiệu các bảng (Tables) cốt lõi và ý nghĩa của chúng (Ví dụ: `Employees`, `Departments`, `Roles`, `Attendance`, `Payroll`, `Deductions`, v.v.).
   * Phân tích các mối quan hệ (Relationships) chính (1-n, n-n) và khóa ngoại (Foreign Keys).
3. **Sử dụng Views (Khung nhìn) trong báo cáo & truy xuất:**
   * Lý do sử dụng Views trong dự án (Bảo mật dữ liệu, đơn giản hóa các truy vấn phức tạp).
   * **Trình bày chi tiết các Views đã xây dựng:**
     * View hiển thị chi tiết nhân viên kèm thông tin phòng ban & chức vụ.
     * View thống kê tổng quỹ lương theo từng phòng ban.
     * View báo cáo tình trạng chuyên cần (số ngày đi làm, nghỉ phép) trong tháng.

---

## 👨‍💻 Người 2: Logic Nghiệp vụ Cốt lõi (Stored Procedures & Functions)

**Mục tiêu:** Trình bày cách hệ thống xử lý các quy trình tính toán phức tạp và các thao tác thay đổi dữ liệu hàng loạt một cách an toàn thông qua lập trình mySQL (hoặc PL/pgSQL/MySQL tùy DBMS).

**Nội dung chi tiết:**

1. **Tổng quan về SP & Functions trong dự án:**
   * Sự khác biệt giữa Stored Procedure và Function trong ngữ cảnh của HRPayrollSystem.
   * Lợi ích hiệu năng và bảo mật khi đóng gói logic nghiệp vụ vào CSDL.
2. **Trình bày chi tiết các Functions (Hàm):**
   * Hàm tính toán độc lập, ví dụ:
     * Hàm tính Thuế Thu nhập cá nhân (PIT) dựa trên bậc lương.
     * Hàm tính số ngày nghỉ phép còn lại của nhân viên.
     * Hàm tính lương thực lãnh (Net Salary) theo công thức chuẩn.
3. **Trình bày chi tiết các Stored Procedures (Thủ tục lưu trữ):**
   * Các quy trình nghiệp vụ chính, ví dụ:
     * Thủ tục `sp_CalculateMonthlyPayroll`: Xử lý tính lương cuối tháng cho toàn bộ công ty (kết hợp chấm công, thưởng, phạt, thuế, BHXH).
     * Thủ tục `sp_AddNewEmployee`: Thêm mới nhân viên với đầy đủ logic kiểm tra phụ thuộc (gán phòng ban, khởi tạo bản ghi lương cơ bản).
   * Phân tích luồng thực thi (Execution flow) và quản lý Transaction (Commit/Rollback) bên trong SP.

---

## 👨‍💻 Người 3: Tự động hóa & Đảm bảo Toàn vẹn Dữ liệu (Triggers & Constraints)

**Mục tiêu:** Giải thích cách CSDL tự bảo vệ dữ liệu khỏi các thao tác sai lệch và tự động hóa các tác vụ ngầm định bằng Triggers.

**Nội dung chi tiết:**

1. **Các Ràng buộc Toàn vẹn (Constraints):**
   * Trình bày các quy tắc Business Rules đã được ánh xạ thành Check Constraints (Ví dụ: Lương không được âm, Ngày kết thúc hợp đồng phải sau ngày bắt đầu, Độ tuổi lao động hợp lệ).
   * Unique Constraints (Ví dụ: Email, CCCD/CMND không được trùng lặp).
2. **Vai trò của Triggers (Trình kích hoạt):**
   * Phân biệt các loại Triggers (AFTER/FOR, INSTEAD OF) được sử dụng.
3. **Trình bày chi tiết các Triggers tiêu biểu:**
   * **Trigger Audit / Lịch sử (History Tracking):** Tự động ghi log mỗi khi có thao tác UPDATE/DELETE trên bảng `Employees` hoặc thay đổi mức lương (`SalaryHistory`), giúp truy xuất người thay đổi và giá trị cũ/mới.
   * **Trigger Cập nhật dữ liệu chéo:** Tự động tính toán lại tổng số nhân viên của một phòng ban khi có người mới gia nhập hoặc thuyên chuyển.
   * **Trigger Validation (Kiểm tra nghiệp vụ phức tạp):** Ngăn chặn việc xóa (DELETE) một phòng ban nếu phòng ban đó vẫn đang có nhân viên, hoặc ngăn chặn duyệt bảng công nếu phát hiện mâu thuẫn dữ liệu.

---

## 👨‍💻 Người 4: Xử lý Đồng thời (Concurrency Anomalies) & Tối ưu hóa Transactions

**Mục tiêu:** Phân tích các rủi ro khi có nhiều người dùng cùng truy cập/sửa đổi dữ liệu cùng lúc và cách hệ thống xử lý để tránh sai sót nghiêm trọng (đặc biệt liên quan đến tiền bạc).

**Nội dung chi tiết:**

1. **Khái niệm về Xử lý đồng thời trong HRPayrollSystem:**
   * Tình huống thực tế: Kế toán A đang chạy tính lương trong khi HR B lại vào sửa mức lương cơ bản của nhân viên, hoặc 2 cấp quản lý cùng duyệt đơn xin nghỉ phép của 1 người.
2. **Các hiện tượng bất thường (Concurrency Anomalies) tiềm ẩn:**
   * **Lost Update (Mất dữ liệu cập nhật):** Hai người cùng sửa thông tin một nhân viên và ghi đè lẫn nhau.
   * **Dirty Read (Đọc dữ liệu rác):** Báo cáo đọc phải dữ liệu lương đang được tính toán dở dang (chưa Commit) của một Transaction khác.
   * **Non-repeatable Read / Phantom Read:** Đang xuất báo cáo tổng lương tháng thì có bản ghi lương mới được chèn vào hệ thống.
3. **Cách khắc phục đặc trưng trong dự án:**
   * **Isolation Levels (Mức độ cô lập):**
     * Giải thích việc chọn mức `READ COMMITTED` hoặc thiết lập lên `REPEATABLE READ` / `SERIALIZABLE` cho từng thủ tục cụ thể. (VD: Thủ tục chốt quỹ lương tháng yêu cầu mức cô lập cao).
   * **Chiến lược Locking:**
     * Sử dụng **Optimistic Locking** (dùng cột `RowVersion`/`Timestamp`) cho các màn hình cập nhật thông tin nhân viên (tránh Lost Update hiệu quả, không giữ lock lâu).
     * Sử dụng **Pessimistic Locking** (`SELECT ... WITH (UPDLOCK)`) trong các giao dịch trừ/cộng tiền cần đảm bảo tính tuần tự.
   * **Demo/Kịch bản thực tế:** Mô phỏng một tình huống lỗi đồng thời (chạy 2 tab query cùng lúc trên SQL Server/MySQL) và chứng minh kết quả an toàn sau khi đã áp dụng cơ chế khóa/cô lập giao dịch.

---

## 📝 Lời khuyên khi nhóm thuyết trình

* **Tính liên kết:** Báo cáo nên có sự dẫn dắt. Người 2 (Procedures) sẽ xử lý dựa trên dữ liệu từ Người 1 (Tables/Views), Người 3 (Triggers) bảo vệ tính toàn vẹn cho dữ liệu, và Người 4 (Concurrency) đảm bảo an toàn cho các tác vụ đồng thời mà những tính năng trên gây ra.
* **Thực hành Demo:** Thay vì chỉ nói lý thuyết, mỗi thành viên nên chuẩn bị sẵn các câu lệnh SQL (Scripts) và trực tiếp chạy thử nghiệm để giảng viên/người nghe thấy trực quan (Ví dụ: Demo trigger cản hành vi xóa sai trái, hoặc Demo 2 transaction tranh chấp bị chặn).
