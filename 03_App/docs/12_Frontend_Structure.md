# PHASE 14 - FRONTEND GENERATION (STRUCTURE)

Cấu trúc dự án NextJS 15 (App Router), sử dụng TypeScript, TailwindCSS, Shadcn UI.

## Folder Structure
```text
/src
 ├── app/                  # Next.js App Router (Pages & Layouts)
 │   ├── (auth)/           # Route group cho login/forgot password
 │   │   └── login/page.tsx
 │   ├── (dashboard)/      # Route group chính có Layout bảo vệ
 │   │   ├── dashboard/page.tsx
 │   │   ├── employees/    # Module nhân viên
 │   │   │   ├── page.tsx  # Danh sách (List)
 │   │   │   └── [id]/page.tsx # Chi tiết (Detail)
 │   │   ├── payroll/      # Module tính lương
 │   │   └── layout.tsx    # Chứa Sidebar & Header
 ├── components/           # UI Components
 │   ├── ui/               # Shadcn UI (Button, Input, Table, Modal)
 │   ├── layout/           # Sidebar, Navbar, Breadcrumbs
 │   └── shared/           # Data Table chung, Filter chung
 ├── lib/                  # Tiện ích chung
 │   ├── utils.ts          # tailwind merge, formatting date/money
 │   └── axios.ts          # Cấu hình API Client & Interceptors
 ├── hooks/                # Custom React Hooks
 │   ├── useAuth.ts        # Quản lý session
 │   └── useQuery.ts       # React Query / SWR hooks
 ├── services/             # API Layer (Giao tiếp Backend)
 │   ├── employee.service.ts
 │   └── payroll.service.ts
 ├── store/                # Global State (Zustand)
 │   └── useAppStore.ts
 └── types/                # TypeScript Interfaces / Zod Schemas
     ├── employee.ts
     └── payroll.ts
```

## Công nghệ sử dụng
- **Data Fetching**: TanStack Query (React Query)
- **Form & Validation**: React Hook Form kết hợp `zod` schema để validate dữ liệu đầu vào.
- **Table**: TanStack Table (xử lý sort, filter, pagination client/server side).
- **State Management**: Zustand cho Global State nhẹ (Sidebar toggle, User Profile cached).
