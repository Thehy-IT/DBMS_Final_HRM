"use client";

import { useState } from "react";
import { Search, Plus, Upload, Download, Check, X, Calendar as CalendarIcon, Loader2, Edit2 } from "lucide-react";
import { AttendanceFormDrawer } from "@/components/attendance/AttendanceFormDrawer";
import { exportToExcel } from "@/lib/excel";
import { Button } from "@/components/ui/button";
import { cn } from "@/lib/utils";
import { useQuery } from "@tanstack/react-query";
import { attendanceService } from "@/services/attendance.service";

export default function AttendancePage() {
  const [searchTerm, setSearchTerm] = useState("");
  const [date, setDate] = useState("");
  const [isDrawerOpen, setIsDrawerOpen] = useState(false);
  const [selectedAttendance, setSelectedAttendance] = useState<any>(null);

  const { data, isLoading, error } = useQuery({
    queryKey: ['attendance'],
    queryFn: () => attendanceService.getAttendance(),
  });

  const attendances = data?.data || [];

  const filteredAttendances = attendances.filter(record => {
    if (searchTerm && !(record.name || '').toLowerCase().includes(searchTerm.toLowerCase()) && !record.id.toLowerCase().includes(searchTerm.toLowerCase())) {
      return false;
    }
    if (date && record.date !== date) {
      return false;
    }
    return true;
  });

  const handleExport = () => {
    const exportData = filteredAttendances.map(r => ({
      'Mã NV': r.id,
      'Họ Tên': r.name,
      'Ngày': r.date,
      'Giờ Vào': r.checkIn,
      'Giờ Ra': r.checkOut,
      'Trạng Thái': r.status,
      'Ghi Chú': r.notes
    }));
    exportToExcel(exportData, `ChamCong_${date || 'TatCa'}`);
  };

  return (
    <div className="space-y-6">
      <AttendanceFormDrawer 
        isOpen={isDrawerOpen} 
        onClose={() => setIsDrawerOpen(false)} 
        attendanceData={selectedAttendance}
      />
      <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-slate-900">Chấm Công Hàng Ngày</h1>
          <p className="text-sm text-slate-500">Quản lý và duyệt giờ vào/ra của nhân viên</p>
        </div>
        <div className="flex items-center gap-2">
          <Button variant="outline" size="sm">
            <Upload className="w-4 h-4 mr-2" /> Import từ máy CC
          </Button>
          <Button variant="outline" size="sm" onClick={handleExport}>
            <Download className="w-4 h-4 mr-2" /> Export
          </Button>
          <Button size="sm" variant="outline">
            <Check className="w-4 h-4 mr-2" /> Duyệt Tất Cả
          </Button>
          <Button size="sm" onClick={() => { setSelectedAttendance(null); setIsDrawerOpen(true); }}>
            <Plus className="w-4 h-4 mr-2" /> Thêm Chấm Công
          </Button>
        </div>
      </div>

      <div className="bg-white rounded-xl border border-slate-200 shadow-sm overflow-hidden flex flex-col">
        <div className="p-4 border-b border-slate-200 flex flex-col sm:flex-row gap-4 bg-slate-50/50">
          <div className="relative flex-1 max-w-[200px]">
            <CalendarIcon className="w-4 h-4 absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" />
            <input 
              type="date" 
              className="w-full pl-9 pr-4 py-2 border border-slate-300 rounded-md text-sm focus:outline-none focus:ring-2 focus:ring-indigo-600 bg-white"
              value={date}
              onChange={(e) => setDate(e.target.value)}
            />
          </div>
          <div className="relative flex-1 max-w-md">
            <Search className="w-4 h-4 absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" />
            <input 
              type="text" 
              placeholder="Tìm theo Mã NV, Tên..." 
              className="w-full pl-9 pr-4 py-2 border border-slate-300 rounded-md text-sm focus:outline-none focus:ring-2 focus:ring-indigo-600 bg-white"
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
            />
          </div>
          <select className="border border-slate-300 rounded-md px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-600 bg-white">
            <option value="">Tất cả trạng thái</option>
            <option value="DL">Đi làm</option>
            <option value="NP">Nghỉ phép</option>
            <option value="OM">Ốm</option>
            <option value="KP">Không phép</option>
          </select>
        </div>

        <div className="overflow-x-auto min-h-[300px]">
          {isLoading ? (
            <div className="flex flex-col items-center justify-center h-[300px] text-slate-500">
              <Loader2 className="w-8 h-8 animate-spin text-indigo-600 mb-4" />
              <p>Đang tải dữ liệu...</p>
            </div>
          ) : error ? (
             <div className="flex items-center justify-center h-[300px] text-red-500">
              <p>Có lỗi xảy ra khi tải dữ liệu chấm công.</p>
            </div>
          ) : filteredAttendances.length === 0 ? (
             <div className="flex items-center justify-center h-[300px] text-slate-500">
              <p>Không tìm thấy bản ghi chấm công nào.</p>
            </div>
          ) : (
            <table className="w-full text-left border-collapse min-w-[900px]">
              <thead>
                <tr className="bg-slate-50 border-b border-slate-200 text-sm font-medium text-slate-600">
                  <th className="px-6 py-3 w-10">
                    <input type="checkbox" className="rounded border-slate-300 text-indigo-600 focus:ring-indigo-600" />
                  </th>
                  <th className="px-6 py-3">Ngày</th>
                  <th className="px-6 py-3">Mã NV</th>
                  <th className="px-6 py-3">Họ Tên</th>
                  <th className="px-6 py-3">Giờ Vào</th>
                  <th className="px-6 py-3">Giờ Ra</th>
                  <th className="px-6 py-3">Trạng Thái</th>
                  <th className="px-6 py-3">Ghi Chú</th>
                  <th className="px-6 py-3 text-right">Hành động</th>
                </tr>
              </thead>
              <tbody className="text-sm">
                {filteredAttendances.map((record, index) => (
                  <tr key={`${record.id}-${record.date}-${index}`} className="border-b border-slate-100 hover:bg-slate-50 transition-colors">
                    <td className="px-6 py-4">
                      <input type="checkbox" className="rounded border-slate-300 text-indigo-600 focus:ring-indigo-600" />
                    </td>
                    <td className="px-6 py-4 font-medium text-slate-900">{record.date}</td>
                    <td className="px-6 py-4 font-medium text-slate-900">{record.id}</td>
                    <td className="px-6 py-4 font-medium text-slate-900">{record.name}</td>
                    <td className="px-6 py-4 font-mono">{record.checkIn || '-'}</td>
                    <td className="px-6 py-4 font-mono">{record.checkOut || '-'}</td>
                    <td className="px-6 py-4">
                      <span className={cn(
                        "px-2.5 py-1 rounded-full text-xs font-medium border",
                        record.status === 'DL' ? "bg-emerald-50 text-emerald-700 border-emerald-200" :
                        record.status === 'NP' ? "bg-blue-50 text-blue-700 border-blue-200" :
                        record.status === 'OM' ? "bg-amber-50 text-amber-700 border-amber-200" :
                        "bg-red-50 text-red-700 border-red-200"
                      )}>
                        {record.status === 'DL' ? "Đi làm" : 
                         record.status === 'NP' ? "Nghỉ phép" : 
                         record.status === 'OM' ? "Ốm" : 
                         record.status === 'KP' ? "Không phép" : record.status}
                      </span>
                    </td>
                    <td className="px-6 py-4 text-slate-500">{record.notes}</td>
                    <td className="px-6 py-4 text-right">
                      <div className="flex items-center justify-end gap-2 text-slate-400">
                        <button 
                          onClick={() => { setSelectedAttendance(record); setIsDrawerOpen(true); }}
                          className="hover:text-indigo-600 p-1.5 rounded-md hover:bg-indigo-50 transition-colors" title="Chỉnh sửa"
                        >
                          <Edit2 className="w-4 h-4" />
                        </button>
                        <button className="hover:text-emerald-600 p-1.5 rounded-md hover:bg-emerald-50 transition-colors" title="Duyệt">
                          <Check className="w-4 h-4" />
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>
      </div>
    </div>
  );
}
