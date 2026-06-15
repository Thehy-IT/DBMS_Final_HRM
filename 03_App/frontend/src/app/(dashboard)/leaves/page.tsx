"use client";

import { useState, useEffect } from "react";
import { useSearchParams, useRouter } from "next/navigation";
import { Search, Plus, Check, X, Loader2 } from "lucide-react";
import { Button } from "@/components/ui/button";
import { cn, formatDate } from "@/lib/utils";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { leaveService } from "@/services/leave.service";
import { masterDataService } from "@/services/masterData.service";
import { employeeService } from "@/services/employee.service";
import { LeaveFormDrawer } from "@/components/leaves/LeaveFormDrawer";
import { useAuthStore } from "@/store/useAuthStore";

export default function LeaveRequestsPage() {
  const [searchTerm, setSearchTerm] = useState("");
  const [isDrawerOpen, setIsDrawerOpen] = useState(false);
  const [currentPage, setCurrentPage] = useState(1);
  const [statusFilter, setStatusFilter] = useState("");
  const [leaveTypeFilter, setLeaveTypeFilter] = useState("");
  const [departmentFilter, setDepartmentFilter] = useState("");
  const itemsPerPage = 50;

  const searchParams = useSearchParams();
  const router = useRouter();

  useEffect(() => {
    if (searchParams.get('action') === 'new') {
      setIsDrawerOpen(true);
      router.replace('/leaves');
    }
  }, [searchParams, router]);

  const { data, isLoading, error } = useQuery({
    queryKey: ['leaves'],
    queryFn: () => leaveService.getLeaves(),
  });

  const { data: leaveTypesData } = useQuery({
    queryKey: ['leaveTypes'],
    queryFn: () => masterDataService.getLeaveTypes(),
  });

  const { data: departmentsData } = useQuery({
    queryKey: ['departments'],
    queryFn: () => masterDataService.getDepartments(),
  });

  const { data: employeesData } = useQuery({
    queryKey: ['employees'],
    queryFn: () => employeeService.getEmployees(),
  });

  const queryClient = useQueryClient();
  const { user } = useAuthStore();
  const isEmployee = user?.role === 'EMPLOYEE';
  const isHR = user?.role === 'HR' || user?.role === 'ADMIN';

  const approveMutation = useMutation({
    mutationFn: ({ id, action }: { id: string, action: 'A' | 'R' }) => {
      return leaveService.approveLeave(id, action);
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['leaves'] });
      alert("Đã cập nhật trạng thái nghỉ phép!");
    }
  });

  const leaves = data?.data || [];

  const uniqueStatuses = Array.from(new Set(leaves.map((l: any) => l.status))).filter(Boolean) as string[];
  const getStatusLabel = (s: string) => {
    switch(s) {
      case 'P': return 'Chờ duyệt';
      case 'A': return 'Đã duyệt';
      case 'R': return 'Từ chối';
      case 'C': return 'Đã hủy';
      default: return s;
    }
  };

  const employees = employeesData?.data || [];

  const filteredLeaves = leaves.filter(record => {
    // If user is employee, only show their own leaves
    if (isEmployee) {
      const isOwnRecord = (record as any).empId === user?.empId || record.empName === user?.username || record.empName === user?.empId;
      if (!isOwnRecord) return false;
    }

    if (searchTerm) {
      const term = searchTerm.toLowerCase();
      const matchName = (record.empName || '').toLowerCase().includes(term);
      const matchEmpId = ((record as any).empId || '').toLowerCase().includes(term);
      const matchId = String(record.id).toLowerCase().includes(term);
      
      if (!matchName && !matchEmpId && !matchId) {
        return false;
      }
    }
    if (statusFilter && record.status !== statusFilter) {
      return false;
    }
    if (leaveTypeFilter) {
      const selectedType = leaveTypesData?.find((t: any) => t.id === leaveTypeFilter || t.name === leaveTypeFilter);
      if (record.type !== leaveTypeFilter && record.type !== selectedType?.name && record.type !== selectedType?.id) {
        return false;
      }
    }
    if (departmentFilter) {
      const selectedDept = departmentsData?.find((d: any) => d.id === departmentFilter || d.name === departmentFilter);
      // Fallback check if empId is provided in record
      const emp = employees.find((e: any) => e.MaNV === (record as any).empId || e.HoTen === record.empName);
      if (!emp || (emp.MaPB !== departmentFilter && emp.MaPB !== selectedDept?.name && emp.MaPB !== selectedDept?.id)) {
        return false;
      }
    }
    return true;
  });

  const totalPages = Math.ceil(filteredLeaves.length / itemsPerPage);
  const paginatedLeaves = filteredLeaves.slice((currentPage - 1) * itemsPerPage, currentPage * itemsPerPage);

  if (isEmployee) {
    const myLeaves = filteredLeaves;
    const approved = myLeaves.filter(l => l.status === 'A').reduce((acc, curr) => acc + curr.days, 0);
    const pending = myLeaves.filter(l => l.status === 'P').length;
    const rejected = myLeaves.filter(l => l.status === 'R').length;
    
    // Giả sử tổng phép năm là 12 ngày
    const remaining = Math.max(0, 12 - approved);

    return (
      <div className="space-y-6 animate-in fade-in slide-in-from-bottom-4 duration-500">
        <LeaveFormDrawer isOpen={isDrawerOpen} onClose={() => setIsDrawerOpen(false)} />
        <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
          <div>
            <h1 className="text-2xl font-bold text-slate-900">Đơn nghỉ phép cá nhân</h1>
            <p className="text-sm text-slate-500">Theo dõi và tạo mới đơn xin nghỉ phép của bạn</p>
          </div>
          <Button size="sm" onClick={() => setIsDrawerOpen(true)}>
            <Plus className="w-4 h-4 mr-2" /> Tạo Đơn Nghỉ
          </Button>
        </div>

        <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
          <div className="bg-white rounded-xl border border-slate-200 p-4 shadow-sm flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-slate-600 mb-1">Phép năm còn lại</p>
              <h3 className="text-2xl font-bold text-slate-900">{remaining} <span className="text-sm font-normal text-slate-500">ngày</span></h3>
            </div>
            <div className="w-10 h-10 rounded-full bg-slate-50 flex items-center justify-center text-slate-600">
              <Check className="w-5 h-5" />
            </div>
          </div>
          <div className="bg-white rounded-xl border border-emerald-100 p-4 shadow-sm flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-emerald-600 mb-1">Đã nghỉ (Được duyệt)</p>
              <h3 className="text-2xl font-bold text-slate-900">{approved} <span className="text-sm font-normal text-slate-500">ngày</span></h3>
            </div>
            <div className="w-10 h-10 rounded-full bg-emerald-50 flex items-center justify-center text-emerald-600">
              <Check className="w-5 h-5" />
            </div>
          </div>
          <div className="bg-white rounded-xl border border-amber-100 p-4 shadow-sm flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-amber-600 mb-1">Đang chờ duyệt</p>
              <h3 className="text-2xl font-bold text-slate-900">{pending} <span className="text-sm font-normal text-slate-500">đơn</span></h3>
            </div>
            <div className="w-10 h-10 rounded-full bg-amber-50 flex items-center justify-center text-amber-600">
              <Loader2 className="w-5 h-5" />
            </div>
          </div>
          <div className="bg-white rounded-xl border border-rose-100 p-4 shadow-sm flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-rose-600 mb-1">Bị từ chối</p>
              <h3 className="text-2xl font-bold text-slate-900">{rejected} <span className="text-sm font-normal text-slate-500">đơn</span></h3>
            </div>
            <div className="w-10 h-10 rounded-full bg-rose-50 flex items-center justify-center text-rose-600">
              <X className="w-5 h-5" />
            </div>
          </div>
        </div>

        <div className="bg-white rounded-xl border border-slate-200 shadow-sm overflow-hidden flex flex-col">
          <div className="p-4 border-b border-slate-200 flex flex-col sm:flex-row gap-4 bg-slate-50/50 justify-end">
            <select 
              className="border border-slate-300 rounded-md px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-600 bg-white"
              value={leaveTypeFilter}
              onChange={(e) => setLeaveTypeFilter(e.target.value)}
            >
              <option value="">Tất cả loại nghỉ</option>
              {leaveTypesData?.map((type: any) => (
                <option key={type.id} value={type.id}>{type.name}</option>
              ))}
            </select>
            <select 
              className="border border-slate-300 rounded-md px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-600 bg-white"
              value={statusFilter}
              onChange={(e) => setStatusFilter(e.target.value)}
            >
              <option value="">Tất cả trạng thái</option>
              <option value="P">Chờ duyệt</option>
              <option value="A">Đã duyệt</option>
              <option value="R">Từ chối</option>
              <option value="C">Đã hủy</option>
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
                <p>Có lỗi xảy ra khi tải dữ liệu nghỉ phép.</p>
              </div>
            ) : myLeaves.length === 0 ? (
              <div className="flex items-center justify-center h-[300px] text-slate-500">
                <p>Bạn chưa có đơn nghỉ phép nào.</p>
              </div>
            ) : (
              <table className="w-full text-left border-collapse min-w-[700px]">
                <thead>
                  <tr className="bg-slate-50 border-b border-slate-200 text-sm font-medium text-slate-600">
                    <th className="px-6 py-3">Mã Đơn</th>
                    <th className="px-6 py-3">Loại Nghỉ Phép</th>
                    <th className="px-6 py-3">Thời Gian</th>
                    <th className="px-6 py-3">Lý Do</th>
                    <th className="px-6 py-3">Trạng Thái</th>
                  </tr>
                </thead>
                <tbody className="text-sm">
                  {paginatedLeaves.map((record) => (
                    <tr key={record.id} className="border-b border-slate-100 hover:bg-slate-50 transition-colors">
                      <td className="px-6 py-4 font-medium text-indigo-600">{record.id}</td>
                      <td className="px-6 py-4">
                        <span className="px-2.5 py-1 rounded-full text-xs font-medium bg-slate-100 text-slate-700 border border-slate-200">
                          {record.type}
                        </span>
                      </td>
                      <td className="px-6 py-4">
                        <div>{formatDate(record.startDate)} - {formatDate(record.endDate)}</div>
                        <div className="text-slate-500 text-xs mt-0.5">({record.days} ngày)</div>
                      </td>
                      <td className="px-6 py-4 max-w-[200px] truncate" title={record.reason}>{record.reason}</td>
                      <td className="px-6 py-4">
                        <span className={cn(
                          "px-2.5 py-1 rounded-full text-xs font-medium border inline-flex items-center gap-1",
                          record.status === 'A' ? "bg-emerald-50 text-emerald-700 border-emerald-200" :
                          record.status === 'P' ? "bg-amber-50 text-amber-700 border-amber-200" :
                          record.status === 'R' ? "bg-red-50 text-red-700 border-red-200" :
                          record.status === 'C' ? "bg-slate-100 text-slate-600 border-slate-300" :
                          "bg-slate-50 text-slate-700 border-slate-200"
                        )}>
                          {record.status === 'A' ? <Check className="w-3 h-3" /> : 
                           record.status === 'P' ? <Loader2 className="w-3 h-3 animate-spin" /> : 
                           record.status === 'R' ? <X className="w-3 h-3" /> : null}
                          {getStatusLabel(record.status)}
                        </span>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}
          </div>

          {!isLoading && !error && myLeaves.length > 0 && (
            <div className="p-4 border-t border-slate-200 flex items-center justify-between text-sm text-slate-500 bg-white">
              <div>Hiển thị {(currentPage - 1) * itemsPerPage + 1}-{Math.min(currentPage * itemsPerPage, myLeaves.length)} của {myLeaves.length} đơn</div>
              <div className="flex items-center gap-1">
                <button 
                  onClick={() => setCurrentPage(p => Math.max(1, p - 1))}
                  disabled={currentPage === 1}
                  className="px-3 py-1.5 rounded-md border border-slate-200 hover:bg-slate-50 disabled:opacity-50 transition-colors"
                >Trước</button>
                <button className="px-3 py-1.5 rounded-md bg-indigo-600 text-white font-medium shadow-sm">{currentPage}</button>
                <button 
                  onClick={() => setCurrentPage(p => Math.min(totalPages, p + 1))}
                  disabled={currentPage === totalPages}
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
      <LeaveFormDrawer isOpen={isDrawerOpen} onClose={() => setIsDrawerOpen(false)} />
      <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-slate-900">Quản lý Nghỉ phép</h1>
          <p className="text-sm text-slate-500">Duyệt và theo dõi đơn xin nghỉ phép của nhân viên</p>
        </div>
        <div className="flex items-center gap-2">
          <Button size="sm" onClick={() => setIsDrawerOpen(true)}>
            <Plus className="w-4 h-4 mr-2" /> Tạo Đơn Nghỉ
          </Button>
        </div>
      </div>

      <div className="bg-white rounded-xl border border-slate-200 shadow-sm overflow-hidden flex flex-col">
        <div className="p-4 border-b border-slate-200 flex flex-col sm:flex-row gap-4 bg-slate-50/50">
          <div className="relative flex-1 max-w-md">
            <Search className="w-4 h-4 absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" />
            <input 
              type="text" 
              placeholder="Tìm theo Mã Đơn, Tên NV..." 
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
            value={leaveTypeFilter}
            onChange={(e) => setLeaveTypeFilter(e.target.value)}
          >
            <option value="">Tất cả loại nghỉ</option>
            {leaveTypesData?.map((type: any) => (
              <option key={type.id} value={type.id}>{type.name}</option>
            ))}
          </select>
          <select 
            className="border border-slate-300 rounded-md px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-600 bg-white"
            value={statusFilter}
            onChange={(e) => setStatusFilter(e.target.value)}
          >
            <option value="">Tất cả trạng thái</option>
            <option value="P">Chờ duyệt</option>
            <option value="A">Đã duyệt</option>
            <option value="R">Từ chối</option>
            <option value="C">Đã hủy</option>
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
              <p>Có lỗi xảy ra khi tải dữ liệu nghỉ phép.</p>
            </div>
          ) : filteredLeaves.length === 0 ? (
             <div className="flex items-center justify-center h-[300px] text-slate-500">
              <p>Không tìm thấy đơn nghỉ phép nào.</p>
            </div>
          ) : (
            <table className="w-full text-left border-collapse min-w-[1000px]">
              <thead>
                <tr className="bg-slate-50 border-b border-slate-200 text-sm font-medium text-slate-600">
                  <th className="px-6 py-3 w-10">
                    <input type="checkbox" className="rounded border-slate-300 text-indigo-600 focus:ring-indigo-600" />
                  </th>
                  <th className="px-6 py-3">Mã Đơn</th>
                  <th className="px-6 py-3">Nhân Viên</th>
                  <th className="px-6 py-3">Loại Nghỉ</th>
                  <th className="px-6 py-3">Thời Gian</th>
                  <th className="px-6 py-3">Lý Do</th>
                  <th className="px-6 py-3">Trạng Thái</th>
                  <th className="px-6 py-3 text-right">Hành động</th>
                </tr>
              </thead>
              <tbody className="text-sm">
                {paginatedLeaves.map((record) => (
                  <tr key={record.id} className="border-b border-slate-100 hover:bg-slate-50 transition-colors">
                    <td className="px-6 py-4">
                      <input type="checkbox" className="rounded border-slate-300 text-indigo-600 focus:ring-indigo-600" />
                    </td>
                    <td className="px-6 py-4 font-medium text-indigo-600 cursor-pointer hover:underline">{record.id}</td>
                    <td className="px-6 py-4 font-medium text-slate-900">{record.empName}</td>
                    <td className="px-6 py-4">
                      <span className="px-2.5 py-1 rounded-full text-xs font-medium bg-slate-100 text-slate-700 border border-slate-200">
                        {record.type}
                      </span>
                    </td>
                    <td className="px-6 py-4">
                      <div>{formatDate(record.startDate)} - {formatDate(record.endDate)}</div>
                      <div className="text-slate-500 text-xs mt-0.5">({record.days} ngày)</div>
                    </td>
                    <td className="px-6 py-4 max-w-[200px] truncate" title={record.reason}>{record.reason}</td>
                    <td className="px-6 py-4">
                      <span className={cn(
                        "px-2.5 py-1 rounded-full text-xs font-medium border",
                        record.status === 'P' ? "bg-amber-50 text-amber-700 border-amber-200" :
                        record.status === 'A' ? "bg-emerald-50 text-emerald-700 border-emerald-200" :
                        record.status === 'R' ? "bg-red-50 text-red-700 border-red-200" :
                        record.status === 'C' ? "bg-slate-100 text-slate-600 border-slate-300" :
                        "bg-slate-50 text-slate-700 border-slate-200"
                      )}>
                        {record.status === 'P' ? "Chờ duyệt" : 
                         record.status === 'A' ? "Đã duyệt" : 
                         record.status === 'R' ? "Từ chối" : "Đã hủy"}
                      </span>
                    </td>
                    <td className="px-6 py-4">
                      <div className="flex flex-col items-start gap-1 w-[130px]">
                        {/* Only HR/ADMIN can approve/reject leaves */}
                        {isHR && record.status === 'P' ? (
                          <>
                            <button 
                              onClick={() => approveMutation.mutate({ id: record.id, action: 'A' })}
                              disabled={approveMutation.isPending}
                              className="w-full text-left px-3 py-1.5 rounded text-sm font-medium text-emerald-600 hover:bg-emerald-50 transition-colors flex items-center justify-between"
                            >
                              Phê duyệt <Check className="w-4 h-4" />
                            </button>
                            <button 
                              onClick={() => approveMutation.mutate({ id: record.id, action: 'R' })}
                              disabled={approveMutation.isPending}
                              className="w-full text-left px-3 py-1.5 rounded text-sm font-medium text-red-600 hover:bg-red-50 transition-colors flex items-center justify-between"
                            >
                              Từ chối <X className="w-4 h-4" />
                            </button>
                          </>
                        ) : (
                          <span className="text-sm text-slate-400 italic">Không có H.Động</span>
                        )}
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>

        {!isLoading && !error && filteredLeaves.length > 0 && (
          <div className="p-4 border-t border-slate-200 flex items-center justify-between text-sm text-slate-500 bg-white">
            <div>Hiển thị {(currentPage - 1) * itemsPerPage + 1}-{Math.min(currentPage * itemsPerPage, filteredLeaves.length)} của {filteredLeaves.length} đơn nghỉ phép</div>
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
