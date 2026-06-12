Bạn là một Senior Frontend Engineer chuyên về UI/UX hiện đại với Next.js 15
(App Router), Tailwind CSS v4 và Shadcn UI. Nhiệm vụ của bạn là xây dựng
giao diện (frontend) cho hệ thống Quản lý Nhân sự & Tính lương tự động (HRM/Payroll).
Hệ thống này đã có sẵn backend hoàn chỉnh với kiến trúc Database-Centric trên MySQL 8.0+
(chứa toàn bộ business logic qua Stored Procedures, Triggers, Views). Mục tiêu của bạn 
là biến nó thành một sản phẩm SaaS chuyên nghiệp, hiện đại, độc đáo, có chiều sâu về 
animation và trải nghiệm người dùng (UX), đồng thời tích hợp mượt mà với CSDL hiện có.

=== 1. ĐỊNH HƯỚNG THIẾT KẾ (DESIGN DIRECTION) ===

- Phong cách: "Modern Enterprise SaaS" — kết hợp giữa minimalism,
  hiệu ứng kính trong suốt hiện đại (modern glassmorphism) với backdrop-blur rõ nét,
  và bento-grid layout (giống Linear, Vercel Dashboard, Notion, Arc Browser).
- Bảng màu: hệ màu chính là Indigo/Violet (#6366F1 - #8B5CF6) làm primary,
  kết hợp với nền trung tính (slate/zinc) cho light mode và near-black
  (#0A0A0F) cho dark mode. Có thêm accent màu Emerald cho trạng thái
  "thành công/đã thanh toán" và Amber/Rose cho cảnh báo/lỗi.
- Hỗ trợ Dark Mode / Light Mode chuyển đổi mượt bằng next-themes,
  có animation transition giữa 2 mode (fade hoặc circular reveal).
- Typography: dùng font Inter hoặc Geist (next/font), phân cấp rõ ràng
  giữa heading, label, số liệu (số liệu lương nên dùng font
  tabular-nums để các số thẳng cột).
- Bo góc lớn (rounded-2xl/3xl), shadow nhẹ nhiều lớp (layered soft shadow),
  border mờ (border-white/10 ở dark mode). Đặc biệt nhấn mạnh hiệu ứng
  kính trong suốt (glassmorphism) cho các thành phần nổi như Sidebar, Topbar, 
  Card, Modal, và Dropdown với nền bán trong suốt kết hợp backdrop-blur.

=== 2. HIỆU ỨNG & ANIMATION (dùng Framer Motion / Motion One) ===

- Page transition: fade + slide nhẹ (8px) khi chuyển route.
- Sidebar: thu/giãn (collapse) với animation width mượt, icon xoay khi hover.
- Card/Widget: hiệu ứng "stagger fade-in" khi load dashboard (mỗi card
  xuất hiện lệch nhau ~50-100ms).
- Số liệu (lương, tổng nhân sự, KPI): dùng "count-up animation" — số tăng
  dần từ 0 đến giá trị thật khi card xuất hiện.
- Hover trên các thẻ KPI/Card: nâng nhẹ (translateY -2px) + đổ bóng tăng
  + viền sáng gradient (border-glow) chạy quanh card.
- Biểu đồ (chart): dùng Recharts hoặc Tremor, có animation vẽ dần đường/cột,
  tooltip custom mượt với glassmorphism background (backdrop-blur).
- Skeleton loading: thay loading spinner bằng skeleton shimmer
  (Shadcn Skeleton + gradient animation) cho mọi bảng dữ liệu khi
  TanStack Query đang fetch.
- Toast/Notification: dùng Sonner, animation slide-in từ góc phải,
  có progress bar tự đóng.
- Empty state & Error state: minh hoạ bằng illustration SVG đơn giản
  (không dùng ảnh nặng), kèm CTA rõ ràng.
- Micro-interaction: nút bấm có hiệu ứng "ripple" hoặc scale nhẹ khi click
  (active:scale-95), input focus có ring gradient.

=== 3. CẤU TRÚC & CÁC TRANG CẦN NÂNG CẤP ===

A. Layout tổng (app/layout.tsx + components/layout/):

- Sidebar trái: thu gọn được, có nhóm menu (Dashboard, Nhân sự,
  Chấm công, Hợp đồng, Tính lương, Báo cáo, Cài đặt).
- Topbar: search command palette (Cmd+K) dùng cmdk, avatar user
  với dropdown (Shadcn DropdownMenu), nút chuyển theme,
  thông báo (Sheet/Drawer trượt từ phải).
- Breadcrumb động theo route.

B. Trang Dashboard (app/dashboard/):

- Bento grid layout:
  - Hàng 1: 4 KPI card (Tổng nhân sự, Tổng quỹ lương tháng,
    Số hợp đồng sắp hết hạn, Tỷ lệ chấm công hôm nay) — mỗi card
    có icon, số liệu count-up, % tăng/giảm so với tháng trước
    (Lấy dữ liệu từ `sp_BaoCaoNhanSu_TongQuan`, `vw_BangLuong_TongHop`, `sp_BaoCaoNhanSu_HopDong`, `vw_TyLeChuyenCan`).
  - Hàng 2: Biểu đồ "Chi phí lương theo phòng ban" (bar chart - từ `vw_BangLuong_TongHop`)
    + Biểu đồ "Biến động nhân sự" (line/area chart theo 12 tháng - từ `sp_BaoCaoNhanSu_BienDong`).
  - Hàng 3: Bảng "Hoạt động gần đây" (timeline dạng feed lấy từ các bảng `AuditLog_HopDong`, `AuditLog_Luong`) 
    + Widget "Sinh nhật & sự kiện trong tháng" (từ bảng `NhanVien`, `NgayLe`).

C. Trang Quản lý Nhân sự (app/employees/):

- Bảng dữ liệu dùng TanStack Table + Shadcn Table: có sort, filter
  theo phòng ban/trạng thái, phân trang, search realtime (debounce) (Dữ liệu từ bảng `NhanVien`, `PhongBan`, `ChucVu`).
- Mỗi dòng có avatar, badge trạng thái (Đang làm/Tạm nghỉ/Đã nghỉ)
  với màu sắc tương ứng.
- Click vào nhân viên mở Sheet/Drawer trượt từ phải hiển thị
  hồ sơ chi tiết theo dạng Tab (Thông tin chung, Hợp đồng,
  Lịch sử lương, Chấm công) — KHÔNG chuyển trang, giữ context (Truy xuất qua bảng `HopDong`, view `vw_BangLuong`, view `vw_ChamCong_ChiTiet`).
- Nút thêm/sửa dùng Dialog (modal) với form Shadcn Form
  + react-hook-form + zod validation, có animation transition
    giữa các step (Thực thi INSERT/UPDATE trực tiếp vào MySQL, các logic validate phức tạp đã có Trigger lo, frontend tập trung validate cơ bản UI).

D. Trang Tính lương (app/payroll/):

- Giao diện dạng "wizard" / stepper trực quan (Chọn kỳ lương →
  Xem trước bảng lương → Xác nhận → Thanh toán → Xuất file). Ở mỗi bước gọi các Stored Procedures tương ứng: `sp_TinhLuong`, `sp_XacNhanBangLuong`, `sp_ThanhToanLuong`.
- Bảng lương: highlight các cột (lương gross, phụ cấp, BHXH, thuế TNCN, lương net)
  dựa trên view `vw_BangLuong` và `vw_BangLuong_TongHop` bằng màu nền
  nhạt khác nhau, có thể click vào số để xem breakdown chi tiết.
- Trạng thái thanh toán: badge động (Draft - vàng,
  Confirmed - xanh, Paid - tím) với icon animation
  (checkmark vẽ dần khi chuyển trạng thái thành công, đồng bộ với DB).
- Nút "Xuất Excel/PDF" có loading state dạng progress
  (giả lập % xử lý) trước khi tải file.

E. Trang Chấm công (app/attendance/):

- Lịch dạng calendar heatmap (giống GitHub contributions)
  thể hiện mật độ đi làm/đi muộn theo ngày (Lấy dữ liệu từ view `vw_TongHopChamCong` và `vw_TyLeChuyenCan`).
- Cho phép xem theo từng nhân viên: timeline chấm công trong ngày
  (giờ vào/ra) dạng horizontal bar trên thanh thời gian 24h (Lấy dữ liệu từ `vw_ChamCong_ChiTiet` và dùng `sp_ChamCong_NhapHangNgay` để cập nhật).

=== 4. RESPONSIVE & ACCESSIBILITY ===

- Mobile: sidebar chuyển thành bottom navigation hoặc drawer overlay,
  bảng dữ liệu chuyển thành dạng card list trên màn hình nhỏ.
- Đảm bảo contrast đạt chuẩn WCAG AA, tất cả icon-only button có
  aria-label, focus-visible rõ ràng cho keyboard navigation.

=== 5. YÊU CẦU KỸ THUẬT ===

- Tái sử dụng tối đa component Shadcn UI có sẵn (Card, Table, Dialog,
  Sheet, Tabs, Badge, Skeleton, DropdownMenu, Command, Sonner...),
  chỉ custom thêm class Tailwind và biến thể (variants) khi cần.
- Tách riêng các animation variant của Framer Motion vào file
  lib/animations.ts để tái sử dụng xuyên suốt project.
- Tương tác với Database-Centric Backend: Viết Next.js API Routes (hoặc Server Actions) kết nối với MySQL. Dùng TanStack Query ở client để gọi API này. Lưu ý quan trọng: KHÔNG cần tính toán logic nghiệp vụ (thuế, BHXH, ngày công) ở frontend vì tất cả đã được xử lý tự động bởi MySQL Stored Procedures (VD: `CALL sp_TinhLuong`), Functions và Triggers. Việc của frontend chỉ là truyền đúng tham số và hiển thị data lấy từ Views/Tables.
- Viết code TypeScript, có comment ngắn giải thích các phần animation
  phức tạp.

Hãy bắt đầu bằng việc đề xuất bảng màu (design tokens trong globals.css
dùng Tailwind v4 @theme), sau đó triển khai layout tổng (Sidebar + Topbar),
rồi mới đến từng trang theo thứ tự: Dashboard → Nhân sự → Tính lương → Chấm công.
