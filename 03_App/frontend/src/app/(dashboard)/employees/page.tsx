"use client";

import { useState, useEffect } from "react";
import { useSearchParams, useRouter } from "next/navigation";
import { Search, Plus, Upload, Download, MoreVertical, Edit2, Loader2 } from "lucide-react";
import { Button } from "@/components/ui/button";
import { cn } from "@/lib/utils";
import { EmployeeFormDrawer } from "@/components/employees/EmployeeFormDrawer";
import { useQuery } from "@tanstack/react-query";
import { employeeService } from "@/services/employee.service";

export default function EmployeeListPage() {
  const [searchTerm, setSearchTerm] = useState("");
  const [isDrawerOpen, setIsDrawerOpen] = useState(false);
  const [selectedEmployeeId, setSelectedEmployeeId] = useState<string | null>(null);
  
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

  const employees = data?.data || [];

  // Filter logic (basic frontend filtering for now)
  const filteredEmployees = employees.filter(emp => {
    if (searchTerm && !(emp.HoTen || '').toLowerCase().includes(searchTerm.toLowerCase()) && !emp.MaNV.toLowerCase().includes(searchTerm.toLowerCase())) {
      return false;
    }
    return true;
  });

  return (
    <div className="space-y-6">
      <EmployeeFormDrawer 
        isOpen={isDrawerOpen} 
        onClose={() => setIsDrawerOpen(false)} 
        employeeId={selectedEmployeeId}
      />

      <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-slate-900">Danh sách Nhân viên</h1>
          <p className="text-sm text-slate-500">Quản lý hồ sơ và thông tin nhân viên</p>
        </div>
        <div className="flex items-center gap-2">
          <Button variant="outline" size="sm">
            <Upload className="w-4 h-4 mr-2" /> Nhập file
          </Button>
          <Button variant="outline" size="sm">
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
          <select className="border border-slate-300 rounded-md px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-600 bg-white">
            <option value="">Tất cả phòng ban</option>
            <option value="IT">IT</option>
            <option value="HR">HR</option>
            <option value="Sales">Sales</option>
          </select>
          <select className="border border-slate-300 rounded-md px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-600 bg-white">
            <option value="">Tất cả trạng thái</option>
            <option value="A">Đang làm việc</option>
            <option value="L">Nghỉ phép</option>
            <option value="T">Nghỉ việc</option>
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
                {filteredEmployees.map((emp) => (
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
                        <button className="hover:text-slate-900 p-1.5 rounded-md hover:bg-slate-100 transition-colors" title="Thêm">
                          <MoreVertical className="w-4 h-4" />
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
            <div>Hiển thị 1-{filteredEmployees.length} của {data?.meta?.total || filteredEmployees.length} nhân viên</div>
            <div className="flex items-center gap-1">
              <button className="px-3 py-1.5 rounded-md border border-slate-200 hover:bg-slate-50 disabled:opacity-50 transition-colors" disabled={true}>Trước</button>
              <button className="px-3 py-1.5 rounded-md bg-indigo-600 text-white font-medium shadow-sm">1</button>
              <button className="px-3 py-1.5 rounded-md border border-slate-200 hover:bg-slate-50 disabled:opacity-50 transition-colors" disabled={true}>Sau</button>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
