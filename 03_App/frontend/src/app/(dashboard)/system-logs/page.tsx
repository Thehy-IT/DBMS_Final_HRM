"use client";

import React, { useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { Activity, Search, Filter, Calendar, Clock, Database, User, FileText } from 'lucide-react';
import { Input } from '@/components/ui/input';
import { masterDataService } from '@/services/masterData.service';

export default function SystemLogsPage() {
  const [searchTerm, setSearchTerm] = useState('');
  const [filterModule, setFilterModule] = useState('ALL');
  const [filterAction, setFilterAction] = useState('ALL');

  const { data: logs, isLoading } = useQuery({
    queryKey: ['system-logs'],
    queryFn: () => masterDataService.getSystemLogs()
  });

  const allLogs = logs || [];

  const filteredLogs = allLogs.filter(log => {
    const matchesSearch = (log.empId?.toLowerCase().includes(searchTerm.toLowerCase()) || 
                           log.changedBy?.toLowerCase().includes(searchTerm.toLowerCase()) ||
                           log.columnName?.toLowerCase().includes(searchTerm.toLowerCase()));
    
    const matchesModule = filterModule === 'ALL' || log.module === filterModule;
    const matchesAction = filterAction === 'ALL' || log.actionType === filterAction;

    return matchesSearch && matchesModule && matchesAction;
  });

  const getActionColor = (action: string) => {
    switch (action) {
      case 'INSERT': return 'bg-emerald-100 text-emerald-700 border-emerald-200';
      case 'UPDATE': return 'bg-blue-100 text-blue-700 border-blue-200';
      case 'DELETE': return 'bg-rose-100 text-rose-700 border-rose-200';
      default: return 'bg-slate-100 text-slate-700 border-slate-200';
    }
  };

  const getActionLabel = (action: string) => {
    switch (action) {
      case 'INSERT': return 'Thêm mới';
      case 'UPDATE': return 'Cập nhật';
      case 'DELETE': return 'Xóa';
      default: return action;
    }
  };

  return (
    <div className="space-y-6 animate-in fade-in duration-300 h-[calc(100vh-100px)] flex flex-col">
      <div>
        <h1 className="text-2xl font-bold text-slate-900 flex items-center gap-2">
          <Activity className="h-6 w-6 text-indigo-600" />
          Nhật ký hệ thống (Audit Logs)
        </h1>
        <p className="text-sm text-slate-500 mt-1 max-w-3xl">
          Theo dõi chi tiết các thao tác thêm, sửa, xóa dữ liệu nhạy cảm (Hợp đồng, Bảng lương). Dữ liệu được ghi nhận tự động bằng Trigger ở cấp độ Database.
        </p>
      </div>

      <div className="bg-white rounded-xl shadow-sm border border-slate-200 p-4 flex flex-col md:flex-row items-center gap-4 flex-shrink-0">
        <div className="relative flex-1 w-full md:max-w-md">
          <Search className="absolute left-3 top-2.5 h-4 w-4 text-slate-400" />
          <Input 
            placeholder="Tìm kiếm theo mã NV, người thay đổi, tên cột..." 
            className="pl-9 bg-slate-50"
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
          />
        </div>
        
        <div className="flex items-center gap-3 w-full md:w-auto">
          <div className="flex items-center gap-2 bg-white border border-slate-200 rounded-md px-3 h-10">
            <Database className="h-4 w-4 text-slate-400" />
            <select 
              className="bg-transparent text-sm text-slate-700 focus:outline-none cursor-pointer"
              value={filterModule}
              onChange={(e) => setFilterModule(e.target.value)}
            >
              <option value="ALL">Tất cả Module</option>
              <option value="Hợp đồng">Hợp đồng</option>
              <option value="Bảng Lương">Bảng Lương</option>
            </select>
          </div>
          <div className="flex items-center gap-2 bg-white border border-slate-200 rounded-md px-3 h-10">
            <Filter className="h-4 w-4 text-slate-400" />
            <select 
              className="bg-transparent text-sm text-slate-700 focus:outline-none cursor-pointer"
              value={filterAction}
              onChange={(e) => setFilterAction(e.target.value)}
            >
              <option value="ALL">Tất cả hành động</option>
              <option value="INSERT">Thêm mới (INSERT)</option>
              <option value="UPDATE">Cập nhật (UPDATE)</option>
              <option value="DELETE">Xóa (DELETE)</option>
            </select>
          </div>
        </div>
      </div>

      <div className="bg-white rounded-xl shadow-sm border border-slate-200 flex-grow overflow-hidden flex flex-col">
        <div className="overflow-x-auto flex-grow">
          <table className="w-full text-sm text-left">
            <thead className="text-xs text-slate-500 uppercase bg-slate-50 border-b border-slate-200 sticky top-0 z-10">
              <tr>
                <th className="px-6 py-4 font-medium">Thời gian</th>
                <th className="px-6 py-4 font-medium">Người thao tác</th>
                <th className="px-6 py-4 font-medium">Module / Đối tượng</th>
                <th className="px-6 py-4 font-medium">Hành động</th>
                <th className="px-6 py-4 font-medium">Chi tiết thay đổi</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {isLoading ? (
                <tr>
                  <td colSpan={5} className="px-6 py-12 text-center">
                    <div className="flex justify-center items-center">
                       <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-indigo-600"></div>
                    </div>
                  </td>
                </tr>
              ) : filteredLogs.length > 0 ? (
                filteredLogs.map((log, index) => (
                  <tr key={`${log.module}-${log.id}-${index}`} className="hover:bg-slate-50 transition-colors">
                    <td className="px-6 py-4 whitespace-nowrap">
                      <div className="flex items-center gap-2 text-slate-700">
                        <Clock className="w-4 h-4 text-slate-400" />
                        <span className="font-medium">
                          {new Date(log.changedAt).toLocaleString('vi-VN')}
                        </span>
                      </div>
                    </td>
                    <td className="px-6 py-4">
                      <div className="flex items-center gap-2">
                        <div className="bg-slate-100 p-1.5 rounded-full text-slate-500">
                          <User className="w-4 h-4" />
                        </div>
                        <div>
                          <p className="font-medium text-slate-900">{log.changedBy}</p>
                          <p className="text-xs text-slate-500">{log.hostName || 'Unknown host'}</p>
                        </div>
                      </div>
                    </td>
                    <td className="px-6 py-4">
                      <div className="flex flex-col">
                        <span className="font-medium text-indigo-700">{log.module}</span>
                        <span className="text-xs text-slate-500">Mã NV: {log.empId}</span>
                      </div>
                    </td>
                    <td className="px-6 py-4">
                      <span className={`inline-flex items-center px-2.5 py-1 rounded-full text-xs font-semibold border ${getActionColor(log.actionType)}`}>
                        {getActionLabel(log.actionType)}
                      </span>
                    </td>
                    <td className="px-6 py-4">
                      <div className="space-y-1 max-w-sm">
                        {log.columnName && (
                          <div className="text-xs bg-slate-100 text-slate-700 px-2 py-1 rounded inline-block font-mono">
                            Cột: {log.columnName}
                          </div>
                        )}
                        {log.actionType === 'UPDATE' ? (
                          <div className="text-xs border border-slate-200 rounded p-2 bg-slate-50">
                            <div className="text-rose-600 line-through mb-1 break-all truncate">
                              Cũ: {log.oldValue || 'NULL'}
                            </div>
                            <div className="text-emerald-600 font-medium break-all truncate">
                              Mới: {log.newValue || 'NULL'}
                            </div>
                          </div>
                        ) : log.actionType === 'INSERT' ? (
                          <div className="text-xs border border-emerald-100 bg-emerald-50 text-emerald-700 rounded p-2 break-all truncate">
                            Dữ liệu mới: {log.newValue || '...'}
                          </div>
                        ) : (
                          <div className="text-xs border border-rose-100 bg-rose-50 text-rose-700 rounded p-2 break-all truncate">
                            Dữ liệu xóa: {log.oldValue || '...'}
                          </div>
                        )}
                      </div>
                    </td>
                  </tr>
                ))
              ) : (
                <tr>
                  <td colSpan={5} className="px-6 py-12 text-center text-slate-500">
                    <div className="flex flex-col items-center">
                      <FileText className="w-12 h-12 text-slate-300 mb-3" />
                      <p>Không có nhật ký nào phù hợp với bộ lọc tìm kiếm.</p>
                    </div>
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
        
        {!isLoading && filteredLogs.length > 0 && (
          <div className="border-t border-slate-200 p-4 bg-slate-50 text-xs text-slate-500 flex justify-between">
            <span>Hiển thị {filteredLogs.length} bản ghi gần nhất.</span>
            <span>Logs được lưu vĩnh viễn trên Server Database.</span>
          </div>
        )}
      </div>
    </div>
  );
}
