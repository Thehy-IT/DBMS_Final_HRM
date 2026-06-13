"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useAppStore } from "@/store/useAppStore";
import { useAuthStore } from "@/store/useAuthStore";
import { cn } from "@/lib/utils";
import { 
  LayoutDashboard, 
  Users, 
  Briefcase, 
  CalendarClock, 
  Calculator, 
  FileText, 
  Settings, 
  LogOut,
  History
} from "lucide-react";

const navItems = [
  { title: "Tổng quan", href: "/dashboard", icon: LayoutDashboard, roles: ['ADMIN', 'HR', 'EMPLOYEE'] },
  { title: "Nhân sự", href: "/employees", icon: Users, roles: ['ADMIN', 'HR'] },
  { title: "Hợp đồng", href: "/contracts", icon: FileText, roles: ['ADMIN', 'HR', 'EMPLOYEE'] },
  { title: "Điểm danh", href: "/attendance", icon: CalendarClock, roles: ['ADMIN', 'HR', 'EMPLOYEE'] },
  { title: "Bảng lương", href: "/payroll", icon: Calculator, roles: ['ADMIN', 'HR', 'EMPLOYEE'] },
  { title: "Nghỉ phép", href: "/leaves", icon: Briefcase, roles: ['ADMIN', 'HR', 'EMPLOYEE'] },
  { title: "Lịch sử", href: "/history", icon: History, roles: ['ADMIN', 'HR'] },
  { title: "Cài đặt", href: "/settings", icon: Settings, roles: ['ADMIN'] },
];

export function Sidebar() {
  const pathname = usePathname();
  const { sidebarOpen } = useAppStore();
  const { user, logout } = useAuthStore();

  return (
    <aside
      className={cn(
        "bg-slate-900 text-slate-300 h-screen transition-all duration-300 flex flex-col flex-shrink-0",
        sidebarOpen ? "w-64" : "w-20"
      )}
    >
      <div className="h-16 flex items-center justify-center border-b border-slate-800 shrink-0">
        <span className="text-white font-bold text-xl truncate px-4">
          {sidebarOpen ? "HRM ERP" : "ERP"}
        </span>
      </div>
      
      <nav className="flex-1 py-4 overflow-y-auto">
        <ul className="space-y-1 px-3">
          {navItems.filter(item => item.roles.includes(user?.role || '')).map((item) => {
            const isActive = pathname.startsWith(item.href);
            return (
              <li key={item.href}>
                <Link
                  href={item.href}
                  className={cn(
                    "flex items-center gap-3 px-3 py-2.5 rounded-md transition-colors",
                    isActive 
                      ? "bg-indigo-600 text-white" 
                      : "hover:bg-slate-800 hover:text-white"
                  )}
                  title={item.title}
                >
                  <item.icon className="w-5 h-5 flex-shrink-0" />
                  {sidebarOpen && <span className="truncate">{item.title}</span>}
                </Link>
              </li>
            );
          })}
        </ul>
      </nav>

      <div className="p-4 border-t border-slate-800 shrink-0">
        <button
          onClick={() => logout()}
          className={cn(
            "flex items-center gap-3 w-full px-3 py-2.5 rounded-md text-red-400 hover:bg-red-500/10 hover:text-red-300 transition-colors"
          )}
          title="Đăng xuất"
        >
          <LogOut className="w-5 h-5 flex-shrink-0" />
          {sidebarOpen && <span className="truncate text-sm font-medium">Đăng xuất ({user?.username})</span>}
        </button>
      </div>
    </aside>
  );
}
