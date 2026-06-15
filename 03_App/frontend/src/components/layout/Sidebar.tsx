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
  History,
  TrendingUp,
  Gift,
  UserCog,
  ShieldCheck,
  Key,
  Building2,
  FileSignature,
  Database
} from "lucide-react";

const navGroups = [
  {
    label: "",
    items: [
      { title: "Tổng quan hệ thống", href: "/dashboard", icon: LayoutDashboard, roles: ['ADMIN', 'HR', 'EMPLOYEE', 'DIRECTOR', 'ACCOUNTANT'] },
    ]
  },
  {
    label: "Quản lý nhân sự",
    items: [
      { title: "Nhân sự", href: "/employees", icon: Users, roles: ['HR', 'DIRECTOR', 'ACCOUNTANT'] },
      { title: "Hợp đồng", href: "/contracts", icon: FileText, roles: ['HR', 'DIRECTOR', 'ACCOUNTANT'] },
      { title: "Điểm danh", href: "/attendance", icon: CalendarClock, roles: ['HR', 'EMPLOYEE', 'DIRECTOR', 'ACCOUNTANT'] },
      { title: "Nghỉ phép", href: "/leaves", icon: Briefcase, roles: ['HR', 'EMPLOYEE', 'DIRECTOR', 'ACCOUNTANT'] },
    ]
  },
  {
    label: "Lương & Báo cáo",
    items: [
      { title: "Bảng lương", href: "/payroll", icon: Calculator, roles: ['HR', 'EMPLOYEE', 'DIRECTOR', 'ACCOUNTANT'] },
      { title: "Báo cáo & Phân tích", href: "/reports", icon: TrendingUp, roles: ['HR', 'DIRECTOR', 'ACCOUNTANT'] },
    ]
  },
  {
    label: "Quản lý tài khoản",
    items: [
      { title: "Người dùng", href: "/users", icon: UserCog, roles: ['ADMIN'] },
      { title: "Vai trò", href: "/roles", icon: ShieldCheck, roles: ['ADMIN'] },
      { title: "Phân quyền", href: "/permissions", icon: Key, roles: ['ADMIN'] },
    ]
  },
  {
    label: "Cấu hình hệ thống",
    items: [
      { title: "Phòng ban", href: "/departments", icon: Building2, roles: ['ADMIN'] },
      { title: "Chức vụ", href: "/positions", icon: Briefcase, roles: ['ADMIN'] },
      { title: "Loại hợp đồng", href: "/contract-types", icon: FileSignature, roles: ['ADMIN'] },
      { title: "Loại phúc lợi", href: "/benefits", icon: Gift, roles: ['HR'] },
      { title: "Công thức lương", href: "/payroll-formulas", icon: Calculator, roles: ['ADMIN'] },
    ]
  },
  {
    label: "Hệ thống",
    items: [
      { title: "Nhật ký hệ thống", href: "/history", icon: History, roles: ['ADMIN', 'HR', 'DIRECTOR', 'ACCOUNTANT'] },
      { title: "Sao lưu dữ liệu", href: "/backup", icon: Database, roles: ['ADMIN'] },
      { title: "Cài đặt", href: "/settings", icon: Settings, roles: ['ADMIN'] },
    ]
  }
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
      
      <nav className="flex-1 py-4 overflow-y-auto sidebar-scrollbar">
        <div className="space-y-6 px-3">
          {navGroups.map((group, index) => {
            // Filter items in the group that the user has permission to see
            const visibleItems = group.items.filter(item => item.roles.includes(user?.role || ''));
            
            if (visibleItems.length === 0) return null;

            return (
              <div key={index} className="space-y-1">
                {sidebarOpen && group.label && (
                  <h3 className="px-3 text-xs font-semibold text-slate-500 uppercase tracking-wider mb-2">
                    {group.label}
                  </h3>
                )}
                <ul className="space-y-1">
                  {visibleItems.map((item) => {
                    const isActive = pathname.startsWith(item.href);
                    return (
                      <li key={item.href}>
                        <Link
                          href={item.href}
                          className={cn(
                            "relative flex items-center gap-3 px-3 py-2.5 rounded-lg transition-all duration-300 group",
                            isActive 
                              ? "bg-indigo-500/15 text-indigo-400 font-semibold" 
                              : "text-slate-400 hover:bg-slate-800/60 hover:text-slate-100"
                          )}
                        >
                          {isActive && (
                            <div className="absolute left-0 top-1/2 -translate-y-1/2 w-1 h-6 bg-indigo-500 rounded-r-full shadow-[0_0_8px_rgba(99,102,241,0.6)]" />
                          )}
                          <item.icon className={cn("w-5 h-5 flex-shrink-0 transition-transform duration-300 group-hover:scale-110 group-active:scale-95", isActive && "text-indigo-400")} />
                          {sidebarOpen && <span className="truncate">{item.title}</span>}
                          
                          {/* Modern Floating Tooltip for Collapsed State */}
                          {!sidebarOpen && (
                            <div className="absolute left-full ml-3 px-2.5 py-1.5 bg-slate-800 text-white text-xs font-semibold rounded-md opacity-0 invisible group-hover:opacity-100 group-hover:visible transition-all duration-200 translate-x-[-10px] group-hover:translate-x-0 whitespace-nowrap z-50 pointer-events-none shadow-xl border border-slate-700">
                              {item.title}
                            </div>
                          )}
                        </Link>
                      </li>
                    );
                  })}
                </ul>
              </div>
            );
          })}
        </div>
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
          {sidebarOpen && <span className="truncate text-sm font-medium">Đăng xuất</span>}
        </button>
      </div>
    </aside>
  );
}
