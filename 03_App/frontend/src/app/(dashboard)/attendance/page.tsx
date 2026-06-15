"use client";

import { useState } from "react";
import { Search, Plus, Upload, Download, Check, X, Calendar as CalendarIcon, Loader2, Edit2 } from "lucide-react";
import { AttendanceFormDrawer } from "@/components/attendance/AttendanceFormDrawer";
import { exportToExcel } from "@/lib/excel";
import { Button } from "@/components/ui/button";
import { cn } from "@/lib/utils";
import { useQuery } from "@tanstack/react-query";
import { attendanceService } from "@/services/attendance.service";
import { masterDataService } from "@/services/masterData.service";
import { employeeService } from "@/services/employee.service";
import { useRef } from "react";
import { useAuthStore } from "@/store/useAuthStore";

export default function AttendancePage() {
  const [searchTerm, setSearchTerm] = useState("");
  const [date, setDate] = useState("");
  const [isDrawerOpen, setIsDrawerOpen] = useState(false);
  const [selectedAttendance, setSelectedAttendance] = useState<any>(null);
  const [currentPage, setCurrentPage] = useState(1);
  const [statusFilter, setStatusFilter] = useState("");
  const [departmentFilter, setDepartmentFilter] = useState("");
  const itemsPerPage = 50;

  const fileInputRef = useRef<HTMLInputElement>(null);

  const { data: departmentsData } = useQuery({
    queryKey: ['departments'],
    queryFn: () => masterDataService.getDepartments(),
  });

  const { data: employeesData } = useQuery({
    queryKey: ['employees'],
    queryFn: () => employeeService.getEmployees(),
  });

  const { data, isLoading, error } = useQuery({
    queryKey: ['attendance'],
    queryFn: () => attendanceService.getAttendance(),
  });

  const attendances = data?.data || [];
  const employees = employeesData?.data || [];

  const { user } = useAuthStore();
  const isEmployee = user?.role === 'EMPLOYEE';
  const isHR = user?.role === 'HR' || user?.role === 'ADMIN';

  const uniqueStatuses = Array.from(new Set(attendances.map((a: any) => a.status))).filter(Boolean) as string[];
  const getStatusLabel = (s: string) => {
    switch(s) {
      case 'DL': return 'Đi làm';
      case 'NP': return 'Nghỉ phép';
      case 'OM': return 'Ốm';
      case 'CX': return 'Công tác xa';
      case 'KP': return 'Không phép';
      case 'NG': return 'Nghỉ lễ';
      case 'WFH': return 'Làm từ xa';
      default: return s;
    }
  };

  const filteredAttendances = attendances.filter(record => {
    if (isEmployee && record.empId !== user?.empId) {
      return false;
    }
    if (searchTerm && !(record.name || '').toLowerCase().includes(searchTerm.toLowerCase()) && !(record.empId || '').toLowerCase().includes(searchTerm.toLowerCase())) {
      return false;
    }
    if (date && record.date !== date) {
      return false;
    }
    if (statusFilter && record.status !== statusFilter) {
      return false;
    }
    if (departmentFilter) {
      const selectedDept = departmentsData?.find((d: any) => d.id === departmentFilter || d.name === departmentFilter);
      const emp = employees.find((e: any) => e.MaNV === record.empId);
      if (!emp || (emp.MaPB !== departmentFilter && emp.MaPB !== selectedDept?.name && emp.MaPB !== selectedDept?.id)) {
        return false;
      }
    }
    return true;
  });

  const totalPages = Math.ceil(filteredAttendances.length / itemsPerPage);
  const paginatedAttendances = filteredAttendances.slice((currentPage - 1) * itemsPerPage, currentPage * itemsPerPage);

  const handleExport = () => {
    const exportData = filteredAttendances.map(r => ({
      'Mã NV': r.empId || r.id,
      'Họ Tên': r.name,
      'Ngày': r.date,
      'Giờ Vào': r.checkIn,
      'Giờ Ra': r.checkOut,
      'Trạng Thái': r.status,
      'Ghi Chú': r.notes
    }));
    exportToExcel(exportData, `ChamCong_${date || 'TatCa'}`);
  };

  const handleImportClick = () => {
    fileInputRef.current?.click();
  };

  const handleFileChange = (event: React.ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    if (file) {
      alert(`Đã chọn file: ${file.name}. Hệ thống đang giả lập xử lý nhập dữ liệu chấm công...`);
      setTimeout(() => alert("Nhập dữ liệu chấm công thành công!"), 1000);
      if (fileInputRef.current) {
        fileInputRef.current.value = '';
      }
    }
  };

  if (isEmployee) {
    const myAttendances = filteredAttendances;
    const daysWorked = attendances.filter(a => a.empId === user?.empId && a.status === 'DL').length;
    const daysOff = attendances.filter(a => a.empId === user?.empId && a.status === 'NP').length;
    const daysSick = attendances.filter(a => a.empId === user?.empId && a.status === 'OM').length;
    const daysOther = attendances.filter(a => a.empId === user?.empId && a.status !== 'DL' && a.status !== 'NP' && a.status !== 'OM').length;

    return (
      <div className="space-y-6 animate-in fade-in slide-in-from-bottom-4 duration-500">
        <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
          <div>
            <h1 className="text-2xl font-bold text-slate-900">Điểm danh cá nhân</h1>
            <p className="text-sm text-slate-500">Xem lại lịch sử điểm danh và giờ công của bạn</p>
          </div>
          <Button variant="outline" size="sm" onClick={handleExport}>
            <Download className="w-4 h-4 mr-2" /> Tải về
          </Button>
        </div>

        <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
          <div className="bg-white rounded-xl border border-emerald-100 p-4 shadow-sm flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-emerald-600 mb-1">Đi làm (DL)</p>
              <h3 className="text-2xl font-bold text-slate-900">{daysWorked} <span className="text-sm font-normal text-slate-500">ngày</span></h3>
            </div>
            <div className="w-10 h-10 rounded-full bg-emerald-50 flex items-center justify-center text-emerald-600">
              <Check className="w-5 h-5" />
            </div>
          </div>
          <div className="bg-white rounded-xl border border-amber-100 p-4 shadow-sm flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-amber-600 mb-1">Nghỉ phép (NP)</p>
              <h3 className="text-2xl font-bold text-slate-900">{daysOff} <span className="text-sm font-normal text-slate-500">ngày</span></h3>
            </div>
            <div className="w-10 h-10 rounded-full bg-amber-50 flex items-center justify-center text-amber-600">
              <CalendarIcon className="w-5 h-5" />
            </div>
          </div>
          <div className="bg-white rounded-xl border border-rose-100 p-4 shadow-sm flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-rose-600 mb-1">Nghỉ ốm (OM)</p>
              <h3 className="text-2xl font-bold text-slate-900">{daysSick} <span className="text-sm font-normal text-slate-500">ngày</span></h3>
            </div>
            <div className="w-10 h-10 rounded-full bg-rose-50 flex items-center justify-center text-rose-600">
              <Plus className="w-5 h-5" />
            </div>
          </div>
          <div className="bg-white rounded-xl border border-slate-200 p-4 shadow-sm flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-slate-600 mb-1">Khác/Vắng</p>
              <h3 className="text-2xl font-bold text-slate-900">{daysOther} <span className="text-sm font-normal text-slate-500">ngày</span></h3>
            </div>
            <div className="w-10 h-10 rounded-full bg-slate-50 flex items-center justify-center text-slate-600">
              <X className="w-5 h-5" />
            </div>
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
            <select 
              className="border border-slate-300 rounded-md px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-600 bg-white"
              value={statusFilter}
              onChange={(e) => setStatusFilter(e.target.value)}
            >
              <option value="">Tất cả trạng thái</option>
              <option value="DL">Đi làm</option>
              <option value="WFH">Làm từ xa</option>
              <option value="CX">Công tác xa</option>
              <option value="NP">Nghỉ phép</option>
              <option value="OM">Ốm</option>
              <option value="KP">Không phép</option>
              <option value="NG">Nghỉ lễ</option>
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
            ) : myAttendances.length === 0 ? (
              <div className="flex items-center justify-center h-[300px] text-slate-500">
                <p>Không tìm thấy bản ghi chấm công nào.</p>
              </div>
            ) : (
              <table className="w-full text-left border-collapse min-w-[1000px] whitespace-nowrap">
                <thead>
                  <tr className="bg-slate-50 border-b border-slate-200 text-sm font-medium text-slate-600">
                    <th className="px-6 py-3 w-12 rounded-tl-lg">
                      <input type="checkbox" className="rounded border-slate-300 text-indigo-600 focus:ring-indigo-600" />
                    </th>
                    <th className="px-6 py-3">Ngày</th>
                    <th className="px-6 py-3">Giờ Vào</th>
                    <th className="px-6 py-3">Giờ Ra</th>
                    <th className="px-6 py-3">Trạng Thái</th>
                    <th className="px-6 py-3 rounded-tr-lg">Ghi Chú</th>
                  </tr>
                </thead>
                <tbody className="text-sm divide-y divide-slate-100">
                  {paginatedAttendances.map((record, index) => (
                    <tr key={`${record.id}-${record.date}-${index}`} className="hover:bg-slate-50 transition-colors">
                      <td className="px-6 py-4">
                        <input type="checkbox" className="rounded border-slate-300 text-indigo-600 focus:ring-indigo-600" />
                      </td>
                      <td className="px-6 py-4 font-medium text-slate-900">{record.date}</td>
                      <td className="px-6 py-4 font-mono">{record.checkIn || '-'}</td>
                      <td className="px-6 py-4 font-mono">{record.checkOut || '-'}</td>
                      <td className="px-6 py-4">
                        <span className={cn(
                          "px-2.5 py-1 rounded-full text-xs font-medium border",
                          record.status === 'DL' ? "bg-emerald-50 text-emerald-700 border-emerald-200" :
                          record.status === 'WFH' ? "bg-teal-50 text-teal-700 border-teal-200" :
                          record.status === 'CX' ? "bg-blue-50 text-blue-700 border-blue-200" :
                          record.status === 'NP' ? "bg-amber-50 text-amber-700 border-amber-200" :
                          record.status === 'OM' ? "bg-orange-50 text-orange-700 border-orange-200" :
                          record.status === 'KP' ? "bg-red-50 text-red-700 border-red-200" :
                          record.status === 'NG' ? "bg-purple-50 text-purple-700 border-purple-200" :
                          "bg-slate-50 text-slate-700 border-slate-200"
                        )}>
                          {getStatusLabel(record.status)}
                        </span>
                      </td>
                      <td className="px-6 py-4 text-slate-500 max-w-[150px] truncate" title={record.notes || ''}>
                        {record.notes || '-'}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}
          </div>

          {!isLoading && !error && myAttendances.length > 0 && (
            <div className="p-4 border-t border-slate-200 flex items-center justify-between text-sm text-slate-500 bg-white">
              <div>Hiển thị {(currentPage - 1) * itemsPerPage + 1}-{Math.min(currentPage * itemsPerPage, myAttendances.length)} của {myAttendances.length} bản ghi</div>
              <div className="flex items-center gap-1">
                <button 
                  onClick={() => setCurrentPage(p => Math.max(1, p - 1))}
                  disabled={currentPage === 1}
                  className="px-3 py-1.5 rounded-md border border-slate-200 hover:bg-slate-50 disabled:opacity-50 transition-colors"
                >Trước</button>
                <button className="px-3 py-1.5 rounded-md bg-indigo-600 text-white font-medium shadow-sm">{currentPage}</button>
                <button 
                  onClick={() => setCurrentPage(p => Math.min(Math.ceil(myAttendances.length / itemsPerPage), p + 1))}
                  disabled={currentPage === Math.ceil(myAttendances.length / itemsPerPage)}
                  className="px-3 py-1.5 rounded-md border border-slate-200 hover:bg-slate-50 disabled:opacity-50 transition-colors"
                >Sau</button>
              </div>
            </div>
          )}
        </div>
      </div>
    );
  }

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
          {isHR && (
            <>
              <input 
                type="file" 
                ref={fileInputRef} 
                className="hidden" 
                accept=".xlsx, .xls, .csv" 
                onChange={handleFileChange} 
              />
              <Button variant="outline" size="sm" onClick={handleImportClick}>
                <Upload className="w-4 h-4 mr-2" /> Import từ máy CC
              </Button>
              <Button size="sm" variant="outline">
                <Check className="w-4 h-4 mr-2" /> Duyệt Tất Cả
              </Button>
            </>
          )}
          <Button variant="outline" size="sm" onClick={handleExport}>
            <Download className="w-4 h-4 mr-2" /> Xuất file
          </Button>
          {isHR && (
            <Button size="sm" onClick={() => { setSelectedAttendance(null); setIsDrawerOpen(true); }}>
              <Plus className="w-4 h-4 mr-2" /> Thêm Chấm Công
            </Button>
          )}
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
          <select 
            className="border border-slate-300 rounded-md px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-600 bg-white"
            value={departmentFilter}
            onChange={(e) => setDepartmentFilter(e.target.value)}
          >
            <option value="">Tất cả phòng ban</option>
            {departmentsData?.map((dept: any) => (
              <option key={dept.id} value={dept.id}>{dept.name}</option>
            ))}
          </select>
          <select 
            className="border border-slate-300 rounded-md px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-600 bg-white"
            value={statusFilter}
            onChange={(e) => setStatusFilter(e.target.value)}
          >
            <option value="">Tất cả trạng thái</option>
            <option value="DL">Đi làm</option>
            <option value="WFH">Làm từ xa</option>
            <option value="CX">Công tác xa</option>
            <option value="NP">Nghỉ phép</option>
            <option value="OM">Ốm</option>
            <option value="KP">Không phép</option>
            <option value="NG">Nghỉ lễ</option>
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
            <table className="w-full text-left border-collapse min-w-[1200px] whitespace-nowrap">
              <thead>
                <tr className="bg-slate-50 border-b border-slate-200 text-sm font-medium text-slate-600">
                  <th className="px-6 py-3 w-12 rounded-tl-lg">
                    <input type="checkbox" className="rounded border-slate-300 text-indigo-600 focus:ring-indigo-600" />
                  </th>
                  <th className="px-6 py-3">Ngày</th>
                  <th className="px-6 py-3">Mã NV</th>
                  <th className="px-6 py-3">Họ Tên</th>
                  <th className="px-6 py-3">Giờ Vào</th>
                  <th className="px-6 py-3">Giờ Ra</th>
                  <th className="px-6 py-3">Trạng Thái</th>
                  <th className="px-6 py-3">Ghi Chú</th>
                  {!isEmployee && <th className="px-6 py-3 text-right rounded-tr-lg">Hành Động</th>}
                </tr>
              </thead>
              <tbody className="text-sm divide-y divide-slate-100">
                {paginatedAttendances.map((record, index) => (
                  <tr key={`${record.id}-${record.date}-${index}`} className="hover:bg-slate-50 transition-colors">
                    <td className="px-6 py-4">
                      <input type="checkbox" className="rounded border-slate-300 text-indigo-600 focus:ring-indigo-600" />
                    </td>
                    <td className="px-6 py-4 font-medium text-slate-900">{record.date}</td>
                    <td className="px-6 py-4 font-medium text-slate-900">{record.empId || record.id}</td>
                    <td className="px-6 py-4 font-medium text-slate-900">{record.name}</td>
                    <td className="px-6 py-4 font-mono">{record.checkIn || '-'}</td>
                    <td className="px-6 py-4 font-mono">{record.checkOut || '-'}</td>
                    <td className="px-6 py-4">
                      <span className={cn(
                        "px-2.5 py-1 rounded-full text-xs font-medium border",
                        record.status === 'DL' ? "bg-emerald-50 text-emerald-700 border-emerald-200" :
                        record.status === 'WFH' ? "bg-teal-50 text-teal-700 border-teal-200" :
                        record.status === 'CX' ? "bg-blue-50 text-blue-700 border-blue-200" :
                        record.status === 'NP' ? "bg-amber-50 text-amber-700 border-amber-200" :
                        record.status === 'OM' ? "bg-orange-50 text-orange-700 border-orange-200" :
                        record.status === 'KP' ? "bg-red-50 text-red-700 border-red-200" :
                        record.status === 'NG' ? "bg-purple-50 text-purple-700 border-purple-200" :
                        "bg-slate-50 text-slate-700 border-slate-200"
                      )}>
                        {getStatusLabel(record.status)}
                      </span>
                    </td>
                    <td className="px-6 py-4 text-slate-500 max-w-[150px] truncate" title={record.notes || ''}>
                      {record.notes || '-'}
                    </td>
                    {!isEmployee && (
                      <td className="px-6 py-4 text-right">
                        {isHR && (
                          <button 
                            onClick={() => { setSelectedAttendance(record); setIsDrawerOpen(true); }}
                            className="text-indigo-600 hover:bg-indigo-50 p-2 rounded-md transition-colors"
                            title="Sửa"
                          >
                            <Edit2 className="w-4 h-4" />
                          </button>
                        )}
                      </td>
                    )}
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>

        {!isLoading && !error && filteredAttendances.length > 0 && (
          <div className="p-4 border-t border-slate-200 flex items-center justify-between text-sm text-slate-500 bg-white">
            <div>Hiển thị {(currentPage - 1) * itemsPerPage + 1}-{Math.min(currentPage * itemsPerPage, filteredAttendances.length)} của {filteredAttendances.length} bản ghi chấm công</div>
            <div className="flex items-center gap-1">
              <button 
                onClick={() => setCurrentPage(p => Math.max(1, p - 1))}
                disabled={currentPage === 1}
                className="px-3 py-1.5 rounded-md border border-slate-200 hover:bg-slate-50 disabled:opacity-50 transition-colors"
              >Trước</button>
              <button className="px-3 py-1.5 rounded-md bg-indigo-600 text-white font-medium shadow-sm">{currentPage}</button>
              <button 
                onClick={() => setCurrentPage(p => Math.min(totalPages, p + 1))}
                disabled={currentPage === totalPages || totalPages === 0}
                className="px-3 py-1.5 rounded-md border border-slate-200 hover:bg-slate-50 disabled:opacity-50 transition-colors"
              >Sau</button>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
