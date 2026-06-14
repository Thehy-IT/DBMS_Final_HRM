"use client";

import { useState, useEffect } from "react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { useAppStore } from "@/store/useAppStore";
import { useAuthStore } from "@/store/useAuthStore";
import { Menu, Clock, Plus, ChevronRight, User } from "lucide-react";
import { cn } from "@/lib/utils";

const routeNames: Record<string, string> = {
  dashboard: "Tổng quan",
  employees: "Nhân sự",
  contracts: "Hợp đồng",
  attendance: "Điểm danh",
  payroll: "Bảng lương",
  leaves: "Nghỉ phép",
  history: "Lịch sử",
  settings: "Cài đặt"
};

export function Header() {
  const { toggleSidebar } = useAppStore();
  const pathname = usePathname();
  const [currentTime, setCurrentTime] = useState<Date | null>(null);
  const [showQuickActions, setShowQuickActions] = useState(false);
  
  const { user } = useAuthStore();
  const isEmployee = user?.role === 'EMPLOYEE';
  const isHR = user?.role === 'HR' || user?.role === 'ADMIN';

  useEffect(() => {
    setCurrentTime(new Date());
    const timer = setInterval(() => setCurrentTime(new Date()), 1000);
    return () => clearInterval(timer);
  }, []);

  // Generate breadcrumbs
  const pathSegments = pathname.split('/').filter(Boolean);

  return (
    <header className="h-16 bg-white/70 backdrop-blur-lg border-b border-slate-200/50 flex items-center justify-between px-4 sticky top-0 z-40 transition-all">
      <div className="flex items-center gap-4 flex-1">
        <button 
          onClick={toggleSidebar}
          className="p-2 hover:bg-slate-100 rounded-lg text-slate-600 transition-colors focus:outline-none focus:ring-2 focus:ring-indigo-500/20"
        >
          <Menu className="w-5 h-5" />
        </button>

        {/* Breadcrumbs */}
        <div className="hidden lg:flex items-center text-sm font-medium text-slate-500">
          <Link href="/dashboard" className="hover:text-indigo-600 transition-colors">Trang chủ</Link>
          {pathSegments.map((segment, index) => {
            const href = `/${pathSegments.slice(0, index + 1).join('/')}`;
            const isLast = index === pathSegments.length - 1;
            const crumbName = routeNames[segment] || segment;

            return (
              <div key={index} className="flex items-center">
                <ChevronRight className="w-4 h-4 mx-1 text-slate-400" />
                {isLast ? (
                  <span className="capitalize text-slate-900 font-semibold">{crumbName}</span>
                ) : (
                  <Link href={href} className="capitalize hover:text-indigo-600 transition-colors">
                    {crumbName}
                  </Link>
                )}
              </div>
            );
          })}
        </div>
      </div>
      


      <div className="flex items-center gap-3 flex-1 justify-end">
        {/* System Status */}
        <div className="hidden sm:flex items-center gap-2 px-3 py-1.5 bg-emerald-50 rounded-full border border-emerald-100" title="Hệ thống trạng thái: Hoạt động tốt">
          <div className="w-2 h-2 rounded-full bg-emerald-500 animate-pulse"></div>
          <span className="text-xs font-medium text-emerald-700">Online</span>
        </div>

        {/* Real-time Clock */}
        <div className="hidden md:flex items-center gap-2 text-sm font-medium text-slate-600 px-3 py-1.5 bg-slate-100/50 rounded-full border border-slate-200/50">
          <Clock className="w-4 h-4 text-indigo-600" />
          {currentTime ? currentTime.toLocaleTimeString('vi-VN', { hour: '2-digit', minute: '2-digit', second: '2-digit' }) : '--:--:--'}
        </div>



        {/* Quick Actions */}
        <div className="relative">
          <button 
            onClick={() => setShowQuickActions(!showQuickActions)}
            onBlur={() => setTimeout(() => setShowQuickActions(false), 200)}
            className="flex items-center gap-2 px-3 py-2 bg-indigo-600 hover:bg-indigo-700 text-white rounded-full text-sm font-medium transition-all shadow-sm shadow-indigo-600/20"
          >
            <Plus className="w-4 h-4" />
            <span className="hidden sm:block">Tạo mới</span>
          </button>

          {/* Dropdown Menu */}
          {showQuickActions && (
            <div className="absolute right-0 mt-2 w-48 bg-white rounded-xl shadow-lg border border-slate-200 py-2 z-50 animate-in fade-in slide-in-from-top-2">
              <div className="px-3 py-2 text-xs font-semibold text-slate-500 uppercase tracking-wider">
                Thao tác nhanh
              </div>
              {isHR && (
                <>
                  <Link href="/employees?action=new" onClick={() => setShowQuickActions(false)} className="block w-full text-left px-4 py-2 text-sm text-slate-700 hover:bg-slate-50 hover:text-indigo-600 transition-colors">
                    Thêm Nhân Viên
                  </Link>
                  <Link href="/contracts?action=new" onClick={() => setShowQuickActions(false)} className="block w-full text-left px-4 py-2 text-sm text-slate-700 hover:bg-slate-50 hover:text-indigo-600 transition-colors">
                    Tạo Hợp Đồng
                  </Link>
                </>
              )}
              <Link href="/leaves?action=new" onClick={() => setShowQuickActions(false)} className="block w-full text-left px-4 py-2 text-sm text-slate-700 hover:bg-slate-50 hover:text-indigo-600 transition-colors">
                Tạo Đơn Nghỉ Phép
              </Link>
            </div>
          )}
        </div>

        {/* User Profile */}
        <div className="flex items-center gap-2 ml-2 pl-4 border-l border-slate-200">
          <div className="w-8 h-8 rounded-full bg-indigo-100 text-indigo-700 flex items-center justify-center font-bold">
            <User className="w-4 h-4" />
          </div>
          <div className="hidden sm:block text-right">
            <p className="text-sm font-semibold text-slate-900 leading-none">{user?.username}</p>
            <p className="text-xs text-slate-500 mt-1">{isEmployee ? 'Nhân viên' : user?.role}</p>
          </div>
        </div>
      </div>
    </header>
  );
}
