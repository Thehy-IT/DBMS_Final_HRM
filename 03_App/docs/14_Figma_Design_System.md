# PHASE 16 - FIGMA DESIGN SYSTEM SPECIFICATION

Hệ thống thiết kế theo phong cách hiện đại, phẳng, tập trung vào dữ liệu và dễ thao tác (Enterprise-grade).

## 1. Typography
- **Font Family**: `Inter` hoặc `Roboto`.
- **Heading 1**: 24px, Bold, Gray-900 (Page Titles).
- **Heading 2**: 18px, SemiBold, Gray-800 (Card Titles).
- **Body**: 14px, Regular, Gray-700 (Dữ liệu bảng, Text thông thường).
- **Caption**: 12px, Regular, Gray-500 (Ghi chú, Helper text).

## 2. Color Palette
- **Primary Brand**: Indigo `bg-indigo-600` (#4F46E5) - Dùng cho nút Primary, Focus ring, Active menu.
- **Secondary**: Slate `bg-slate-100` tới `bg-slate-900` - Dùng cho màu nền, viền và văn bản.
- **Background**:
  - Light mode: Nền `bg-slate-50`, Card `bg-white`.
  - Dark mode: Nền `bg-slate-950`, Card `bg-slate-900`.
- **Status Colors** (Rất quan trọng trong ERP):
  - **Success (Active, Approved)**: Green `text-emerald-700`, `bg-emerald-50`.
  - **Warning (Leave, Pending, Expiring)**: Amber `text-amber-700`, `bg-amber-50`.
  - **Danger (Terminated, Rejected, Error)**: Red `text-red-700`, `bg-red-50`.
  - **Info (Draft)**: Blue `text-blue-700`, `bg-blue-50`.

## 3. Spacing & Border Radius
- **Padding/Margin cơ bản**: 16px (p-4), 24px (p-6).
- **Border Radius**: Card và Modal dùng `rounded-xl` (12px), Nút và Input dùng `rounded-md` (6px).

## 4. Components UI
- **Buttons**:
  - *Primary*: Nền Indigo, chữ trắng. Hover: Indigo-700.
  - *Secondary/Outline*: Viền xám, nền trong suốt hoặc xám nhạt. Chữ xám đậm.
  - *Danger*: Nền Đỏ.
- **Inputs**: Viền xám nhạt, border tròn nhẹ. Khi focus viền Indigo, có ring mờ. Có icon báo lỗi đỏ khi invalid.
- **Cards**: Nền trắng (hoặc đen nhạt), viền border mỏng 1px màu slate-200. Shadow-sm.
- **Table**: Header background màu xám rất nhạt (slate-50). Dòng chẵn lẻ không đổi màu mà sử dụng viền gạch dưới (border-b) mỏng giữa các dòng. Hàng được hover sẽ highlight xám nhạt.
- **Badges**: Pill-shape (`rounded-full`), padding dọc nhỏ, ngang vừa phải. Hiển thị Status.
