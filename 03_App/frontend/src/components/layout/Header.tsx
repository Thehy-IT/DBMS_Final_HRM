"use client";

import { useAppStore } from "@/store/useAppStore";
import { Menu, Search } from "lucide-react";

export function Header() {
  const { toggleSidebar } = useAppStore();

  return (
    <header className="h-16 bg-white border-b border-slate-200 flex items-center justify-between px-4 shrink-0 shadow-sm">
      <div className="flex items-center gap-4">
        <button 
          onClick={toggleSidebar}
          className="p-2 hover:bg-slate-100 rounded-md text-slate-600 transition-colors"
        >
          <Menu className="w-5 h-5" />
        </button>
        <div className="relative hidden md:block w-64">
          <Search className="w-4 h-4 absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" />
          <input 
            type="text" 
            placeholder="Tìm kiếm nhân viên, hợp đồng..." 
            className="w-full pl-9 pr-4 py-2 bg-slate-50 border border-slate-200 rounded-md text-sm focus:outline-none focus:ring-2 focus:ring-indigo-600 focus:bg-white transition-all"
          />
        </div>
      </div>
      

    </header>
  );
}
