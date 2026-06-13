"use client";

import { useState, useEffect } from "react";
import { usePathname } from "next/navigation";
import { useAppStore } from "@/store/useAppStore";
import { Menu, Search, Clock, Plus, ChevronRight } from "lucide-react";
import { cn } from "@/lib/utils";

const routeNames: Record<string, string> = {
  dashboard: "Tổng quan",
  employees: "Nhân sự",
  contracts: "Hợp đồng",
  attendance: "Điểm danh",
  payroll: "Bảng lương",
  leaves: "Nghỉ phép",
  settings: "Cài đặt"
};

export function Header() {
  const { toggleSidebar } = useAppStore();
  const pathname = usePathname();
  const [currentTime, setCurrentTime] = useState<Date | null>(null);
  const [showQuickActions, setShowQuickActions] = useState(false);

  useEffect(() => {
    setCurrentTime(new Date());
    const timer = setInterval(() => setCurrentTime(new Date()), 1000);
    return () => clearInterval(timer);
  }, []);

  // Generate breadcrumbs
  const pathSegments = pathname.split('/').filter(Boolean);
  const breadcrumbs = pathSegments.map(segment => routeNames[segment] || segment);

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
          <span className="hover:text-indigo-600 cursor-pointer transition-colors">Trang chủ</span>
          {breadcrumbs.map((crumb, index) => (
            <div key={index} className="flex items-center">
              <ChevronRight className="w-4 h-4 mx-1 text-slate-400" />
              <span className={cn(
                "capitalize",
                index === breadcrumbs.length - 1 ? "text-slate-900 font-semibold" : "hover:text-indigo-600 cursor-pointer transition-colors"
              )}>
                {crumb}
              </span>
            </div>
          ))}
        </div>
      </div>
      
      {/* Centered Search Bar */}
      <div className="flex-1 flex justify-center max-w-2xl px-4">
        <div className="relative w-full max-w-md group">
          <Search className="w-4 h-4 absolute left-4 top-1/2 -translate-y-1/2 text-slate-400 group-focus-within:text-indigo-600 transition-colors" />
          <input 
            type="text" 
            placeholder="Tìm kiếm nhân viên... (Ctrl + K)" 
            className="w-full pl-11 pr-4 py-2 bg-slate-100/50 border border-transparent rounded-full text-sm focus:outline-none focus:ring-2 focus:ring-indigo-600/20 focus:border-indigo-600/30 focus:bg-white transition-all shadow-sm hover:bg-slate-100"
          />
          <div className="absolute right-3 top-1/2 -translate-y-1/2 flex items-center gap-1">
            <kbd className="hidden sm:inline-flex items-center gap-1 rounded border border-slate-200 bg-slate-50 px-1.5 font-mono text-[10px] font-medium text-slate-500">
              <span className="text-xs">Ctrl</span>K
            </kbd>
          </div>
        </div>
      </div>

      <div className="flex items-center gap-3 flex-1 justify-end">
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
              <button className="w-full text-left px-4 py-2 text-sm text-slate-700 hover:bg-slate-50 hover:text-indigo-600 transition-colors">
                Thêm Nhân Viên
              </button>
              <button className="w-full text-left px-4 py-2 text-sm text-slate-700 hover:bg-slate-50 hover:text-indigo-600 transition-colors">
                Tạo Hợp Đồng
              </button>
              <button className="w-full text-left px-4 py-2 text-sm text-slate-700 hover:bg-slate-50 hover:text-indigo-600 transition-colors">
                Tạo Đơn Nghỉ Phép
              </button>
            </div>
          )}
        </div>
      </div>
    </header>
  );
}
