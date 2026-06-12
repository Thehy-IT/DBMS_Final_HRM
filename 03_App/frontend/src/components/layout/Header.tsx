"use client";

import { useAppStore } from "@/store/useAppStore";
import { Menu, Bell, Search } from "lucide-react";

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
            placeholder="Search employees, contracts..." 
            className="w-full pl-9 pr-4 py-2 bg-slate-50 border border-slate-200 rounded-md text-sm focus:outline-none focus:ring-2 focus:ring-indigo-600 focus:bg-white transition-all"
          />
        </div>
      </div>
      
      <div className="flex items-center gap-3">
        <button className="p-2 hover:bg-slate-100 rounded-md text-slate-600 relative transition-colors">
          <Bell className="w-5 h-5" />
          <span className="absolute top-1.5 right-1.5 w-2 h-2 bg-red-500 rounded-full border border-white"></span>
        </button>
        <div className="flex items-center gap-2 cursor-pointer p-1 hover:bg-slate-50 rounded-md border border-transparent hover:border-slate-200 transition-all">
          <div className="w-8 h-8 bg-indigo-600 text-white rounded-full flex items-center justify-center font-medium text-sm shadow-sm">
            AD
          </div>
          <span className="text-sm font-medium text-slate-700 hidden sm:block">Admin User</span>
        </div>
      </div>
    </header>
  );
}
