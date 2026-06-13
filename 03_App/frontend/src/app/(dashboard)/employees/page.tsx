"use client";

import { useState, useEffect, useRef } from "react";
import { useSearchParams, useRouter } from "next/navigation";
import { Search, Plus, Upload, Download, MoreVertical, Edit2, Loader2, UserMinus } from "lucide-react";
import { Button } from "@/components/ui/button";
import { cn } from "@/lib/utils";
import { EmployeeFormDrawer } from "@/components/employees/EmployeeFormDrawer";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { employeeService } from "@/services/employee.service";
import { masterDataService } from "@/services/masterData.service";
import { exportToExcel } from "@/lib/excel";

export default function EmployeeListPage() {
  const [searchTerm, setSearchTerm] = useState("");
  const [department, setDepartment] = useState("");
  const [statusFilter, setStatusFilter] = useState("");
  const [isDrawerOpen, setIsDrawerOpen] = useState(false);
  const [selectedEmployeeId, setSelectedEmployeeId] = useState<string | null>(null);
  const [currentPage, setCurrentPage] = useState(1);
  const itemsPerPage = 50;
  
  const fileInputRef = useRef<HTMLInputElement>(null);
  const queryClient = useQueryClient();
  
  const searchParams = useSearchParams();
  const router = useRouter();

  useEffect(() => {
    if (searchParams.get('action') === 'new') {
      setSelectedEmployeeId(null);
      setIsDrawerOpen(true);
      router.replace('/employees');
    }
  }, [searchParams, router]);

  const { data, isLoading, error } = useQuery({
    queryKey: ['employees'],
    queryFn: () => employeeService.getEmployees(),
  });

  const { data: departmentsData } = useQuery({
    queryKey: ['departments'],
    queryFn: () => masterDataService.getDepartments(),
  });

  const deactivateMutation = useMutation({
    mutationFn: (emp: any) => {
      return employeeService.updateEmployee(emp.MaNV, { ...emp, TrangThai: 'T' });
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['employees'] });
      alert("Đã vô hiệu hoá hồ sơ nhân viên!");
    },
    onError: () => {
      alert("Có lỗi xảy ra khi vô hiệu hoá nhân viên.");
    }
  });

  const employees = data?.data || [];

  const uniqueStatuses = Array.from(new Set(employees.map((e: any) => e.TrangThai))).filter(Boolean) as string[];
  const getStatusLabel = (s: string) => {
    switch(s) {
      case 'A': return 'Đang làm việc';
      case 'L': return 'Nghỉ phép';
      case 'T': return 'Nghỉ việc';
      case 'P': return 'Thử việc';
      default: return s;
    }
  };

  // Filter logic
  const filteredEmployees = employees.filter(emp => {
    if (searchTerm && !(emp.HoTen || '').toLowerCase().includes(searchTerm.toLowerCase()) && !emp.MaNV.toLowerCase().includes(searchTerm.toLowerCase())) {
      return false;
    }
    
    if (department) {
      const selectedDept = departmentsData?.find((d: any) => d.id === department || d.name === department);
      if (emp.MaPB !== department && emp.MaPB !== selectedDept?.name && emp.MaPB !== selectedDept?.id) {
        return false;
      }
    }
    
    if (statusFilter && emp.TrangThai !== statusFilter) {
      return false;
    }

    return true;
  });

  const totalPages = Math.ceil(filteredEmployees.length / itemsPerPage);
  const paginatedEmployees = filteredEmployees.slice((currentPage - 1) * itemsPerPage, currentPage * itemsPerPage);

  const handleExport = () => {
    const exportData = filteredEmployees.map(emp => ({
      'Mã NV': emp.MaNV,
      'Họ Tên': emp.HoTen,
      'Phòng Ban': emp.MaPB,
      'Chức Vụ': emp.MaCV,
      'Giới Tính': emp.GioiTinh === 'M' ? 'Nam' : emp.GioiTinh === 'F' ? 'Nữ' : 'Khác',
      'Ngày Sinh': emp.NgaySinh ? new Date(emp.NgaySinh).toLocaleDateString('vi-VN') : '',
      'Ngày Vào Làm': emp.NgayVaoLam ? new Date(emp.NgayVaoLam).toLocaleDateString('vi-VN') : '',
      'Trạng Thái': emp.TrangThai === 'A' ? 'Đang làm việc' : 
                    emp.TrangThai === 'L' ? 'Nghỉ phép' : 
                    emp.TrangThai === 'T' ? 'Nghỉ việc' : 
                    emp.TrangThai === 'P' ? 'Thử việc' : emp.TrangThai
    }));
    exportToExcel(exportData, `DanhSachNhanVien`);
  };

  const handleImportClick = () => {
    fileInputRef.current?.click();
  };

  const handleFileChange = (event: React.ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    if (file) {
      alert(`Đã chọn file: ${file.name}. Hệ thống đang giả lập xử lý nhập dữ liệu...`);
      setTimeout(() => alert("Nhập dữ liệu thành công!"), 1000);
      if (fileInputRef.current) {
        fileInputRef.current.value = '';
      }
    }
  };

  return (
    <div className="space-y-6">
      <EmployeeFormDrawer 
        isOpen={isDrawerOpen} 
        onClose={() => setIsDrawerOpen(false)} 
        employeeId={selectedEmployeeId}
        employee={employees.find((e: any) => e.MaNV === selectedEmployeeId)}
      />

      <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-slate-900">Danh sách Nhân viên</h1>
          <p className="text-sm text-slate-500">Quản lý hồ sơ và thông tin nhân viên</p>
        </div>
        <div className="flex items-center gap-2">
          <input 
            type="file" 
            ref={fileInputRef} 
            className="hidden" 
            accept=".xlsx, .xls, .csv" 
            onChange={handleFileChange} 
          />
          <Button variant="outline" size="sm" onClick={handleImportClick}>
            <Upload className="w-4 h-4 mr-2" /> Nhập file
          </Button>
          <Button variant="outline" size="sm" onClick={handleExport}>
            <Download className="w-4 h-4 mr-2" /> Xuất file
          </Button>
          <Button size="sm" onClick={() => { setSelectedEmployeeId(null); setIsDrawerOpen(true); }}>
            <Plus className="w-4 h-4 mr-2" /> Thêm Nhân Viên
          </Button>
        </div>
      </div>

      <div className="bg-white rounded-xl border border-slate-200 shadow-sm overflow-hidden flex flex-col">
        {/* Filter Area */}
        <div className="p-4 border-b border-slate-200 flex flex-col sm:flex-row gap-4 bg-slate-50/50">
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
            value={department}
            onChange={(e) => setDepartment(e.target.value)}
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
            {uniqueStatuses.map(status => (
              <option key={status} value={status}>{getStatusLabel(status)}</option>
            ))}
          </select>
        </div>

        {/* Data Table */}
        <div className="overflow-x-auto min-h-[300px]">
          {isLoading ? (
            <div className="flex flex-col items-center justify-center h-[300px] text-slate-500">
              <Loader2 className="w-8 h-8 animate-spin text-indigo-600 mb-4" />
              <p>Đang tải dữ liệu...</p>
            </div>
          ) : error ? (
            <div className="flex items-center justify-center h-[300px] text-red-500">
              <p>Có lỗi xảy ra khi tải dữ liệu nhân viên.</p>
            </div>
          ) : filteredEmployees.length === 0 ? (
            <div className="flex items-center justify-center h-[300px] text-slate-500">
              <p>Không tìm thấy nhân viên nào.</p>
            </div>
          ) : (
            <table className="w-full text-left border-collapse min-w-[800px]">
              <thead>
                <tr className="bg-slate-50 border-b border-slate-200 text-sm font-medium text-slate-600">
                  <th className="px-6 py-3 w-10">
                    <input type="checkbox" className="rounded border-slate-300 text-indigo-600 focus:ring-indigo-600" />
                  </th>
                  <th className="px-6 py-3">Mã NV</th>
                  <th className="px-6 py-3">Họ Tên</th>
                  <th className="px-6 py-3">Phòng Ban</th>
                  <th className="px-6 py-3">Chức Vụ</th>
                  <th className="px-6 py-3">Ngày Vào Làm</th>
                  <th className="px-6 py-3">Trạng Thái</th>
                  <th className="px-6 py-3 text-right">Hành động</th>
                </tr>
              </thead>
              <tbody className="text-sm">
                {paginatedEmployees.map((emp) => (
                  <tr key={emp.MaNV} className="border-b border-slate-100 hover:bg-slate-50 transition-colors">
                    <td className="px-6 py-4">
                      <input type="checkbox" className="rounded border-slate-300 text-indigo-600 focus:ring-indigo-600" />
                    </td>
                    <td className="px-6 py-4 font-medium text-indigo-600 cursor-pointer hover:underline">{emp.MaNV}</td>
                    <td className="px-6 py-4 font-medium text-slate-900 flex items-center gap-3">
                      <div className="w-8 h-8 rounded-full bg-slate-200 flex items-center justify-center text-slate-600 font-medium uppercase">
                        {emp.HoTen.charAt(0)}
                      </div>
                      {emp.HoTen}
                    </td>
                    <td className="px-6 py-4">{emp.MaPB || '-'}</td>
                    <td className="px-6 py-4">{emp.MaCV || '-'}</td>
                    <td className="px-6 py-4">{emp.NgayVaoLam ? new Date(emp.NgayVaoLam).toLocaleDateString('vi-VN') : '-'}</td>
                    <td className="px-6 py-4">
                      <span className={cn(
                        "px-2.5 py-1 rounded-full text-xs font-medium border",
                        emp.TrangThai === 'A' ? "bg-emerald-50 text-emerald-700 border-emerald-200" :
                        emp.TrangThai === 'L' ? "bg-amber-50 text-amber-700 border-amber-200" :
                        emp.TrangThai === 'T' ? "bg-red-50 text-red-700 border-red-200" :
                        "bg-slate-100 text-slate-700 border-slate-200"
                      )}>
                        {emp.TrangThai === 'A' ? 'Đang làm việc' : 
                         emp.TrangThai === 'L' ? 'Nghỉ phép' : 
                         emp.TrangThai === 'T' ? 'Nghỉ việc' : 
                         emp.TrangThai === 'P' ? 'Thử việc' : emp.TrangThai}
                      </span>
                    </td>
                    <td className="px-6 py-4 text-right">
                      <div className="flex items-center justify-end gap-2 text-slate-400">
                        <button 
                          onClick={() => { setSelectedEmployeeId(emp.MaNV); setIsDrawerOpen(true); }}
                          className="hover:text-indigo-600 p-1.5 rounded-md hover:bg-indigo-50 transition-colors" 
                          title="Chỉnh sửa"
                        >
                          <Edit2 className="w-4 h-4" />
                        </button>
                        <button 
                          onClick={() => {
                            if (window.confirm(`Bạn có chắc chắn muốn vô hiệu hoá hồ sơ nhân viên ${emp.HoTen}?`)) {
                              deactivateMutation.mutate(emp);
                            }
                          }}
                          disabled={deactivateMutation.isPending || emp.TrangThai === 'T'}
                          className={cn(
                            "p-1.5 rounded-md transition-colors",
                            emp.TrangThai === 'T' ? "opacity-30 cursor-not-allowed text-slate-400" : "hover:text-red-600 hover:bg-red-50 text-slate-400"
                          )}
                          title="Vô hiệu hoá"
                        >
                          <UserMinus className="w-4 h-4" />
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>

        {/* Pagination */}
        {!isLoading && !error && filteredEmployees.length > 0 && (
          <div className="p-4 border-t border-slate-200 flex items-center justify-between text-sm text-slate-500 bg-white">
            <div>Hiển thị {(currentPage - 1) * itemsPerPage + 1}-{Math.min(currentPage * itemsPerPage, filteredEmployees.length)} của {filteredEmployees.length} nhân viên</div>
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
