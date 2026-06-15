"use client";

import { useState, useRef } from "react";
import { Search, Calculator, CheckCircle2, Lock, Download, Printer, Loader2, Banknote, Upload, Check, FileText } from "lucide-react";
import { Button } from "@/components/ui/button";
import { cn, formatMoney } from "@/lib/utils";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { payrollService } from "@/services/payroll.service";
import { exportToExcel } from "@/lib/excel";
import { PayslipModal } from "@/components/payroll/PayslipModal";
import { masterDataService } from "@/services/masterData.service";
import { useAuthStore } from "@/store/useAuthStore";

export default function PayrollPage() {
  const [searchTerm, setSearchTerm] = useState("");
  const [month, setMonth] = useState(new Date().toISOString().slice(0, 7)); // YYYY-MM
  const [selectedPayslip, setSelectedPayslip] = useState<any>(null);
  const [department, setDepartment] = useState("");
  const [statusFilter, setStatusFilter] = useState("");
  const [currentPage, setCurrentPage] = useState(1);
  const itemsPerPage = 50;
  
  const fileInputRef = useRef<HTMLInputElement>(null);
  const queryClient = useQueryClient();
  const { user } = useAuthStore();
  const isEmployee = user?.role === 'EMPLOYEE';
  const canManagePayroll = user?.role === 'ADMIN' || user?.role === 'HR' || user?.role === 'ACCOUNTANT';

  const { data: departmentsData } = useQuery({
    queryKey: ['departments'],
    queryFn: () => masterDataService.getDepartments(),
  });

  const { data, isLoading, error } = useQuery({
    queryKey: ['payroll'],
    queryFn: () => payrollService.getPayroll(),
  });

  const calculateMutation = useMutation({
    mutationFn: () => {
      const [y, m] = month.split('-');
      return payrollService.calculatePayroll(parseInt(m), parseInt(y));
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['payroll'] });
      alert("Đã chạy lương thành công!");
    }
  });

  const confirmMutation = useMutation({
    mutationFn: () => {
      const [y, m] = month.split('-');
      return payrollService.confirmPayroll(parseInt(m), parseInt(y));
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['payroll'] });
      alert("Đã xác nhận bảng lương!");
    }
  });

  const payMutation = useMutation({
    mutationFn: () => {
      const [y, m] = month.split('-');
      return payrollService.payPayroll(parseInt(m), parseInt(y));
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['payroll'] });
      alert("Đã thanh toán lương!");
    }
  });

  const payrolls = data?.data || [];

  const deptMap = (departmentsData || []).reduce((acc: any, d: any) => {
    acc[d.id || d.MaPB] = d.name || d.TenPB;
    return acc;
  }, {});

  const uniqueStatuses = Array.from(new Set(payrolls.map((p: any) => p.status))).filter(Boolean) as string[];
  const getStatusLabel = (s: string) => {
    switch(s) {
      case 'D': return 'Nháp';
      case 'C': return 'Đã xác nhận';
      case 'L': return 'Đã chốt';
      case 'P': return 'Đã thanh toán';
      default: return s;
    }
  };

  const filteredPayrolls = payrolls.filter(record => {
    if (isEmployee && record.empId !== user?.empId) {
      return false;
    }
    if (searchTerm && !record.name.toLowerCase().includes(searchTerm.toLowerCase()) && !record.empId?.toLowerCase().includes(searchTerm.toLowerCase())) {
      return false;
    }
    const [y, m] = month.split('-');
    if (month && (record.month !== parseInt(m) || record.year !== parseInt(y))) {
      return false;
    }
    if (department) {
      const selectedDept = departmentsData?.find((d: any) => d.id === department || d.name === department);
      if (record.dept !== department && record.dept !== selectedDept?.name && record.dept !== selectedDept?.id) {
        return false;
      }
    }
    if (statusFilter && record.status !== statusFilter) {
      return false;
    }
    return true;
  });

  const totalPages = Math.ceil(filteredPayrolls.length / itemsPerPage);
  const paginatedPayrolls = filteredPayrolls.slice((currentPage - 1) * itemsPerPage, currentPage * itemsPerPage);

  const handleExport = () => {
    const exportData = filteredPayrolls.map(r => ({
      'Mã NV': r.empId,
      'Họ Tên': r.name,
      'Phòng Ban': deptMap[r.dept] || r.dept,
      'Lương CB': r.basicSalary,
      'Ngày Công': r.workingDays,
      'Tăng Ca (h)': r.otHours,
      'Phụ Cấp': r.allowance,
      'Khấu Trừ': r.deduction,
      'Thực Lãnh': r.netSalary,
      'Trạng Thái': r.status
    }));
    exportToExcel(exportData, `BangLuong_${month}`);
  };

  if (isEmployee) {
    const myPayrolls = filteredPayrolls.sort((a: any, b: any) => {
      if (a.year !== b.year) return (b.year || 0) - (a.year || 0);
      return (b.month || 0) - (a.month || 0);
    });
    const latestPayroll = myPayrolls.length > 0 ? myPayrolls[0] : null;
    const totalYearIncome = myPayrolls.reduce((acc, curr) => acc + curr.netSalary, 0);

    return (
      <div className="space-y-6 animate-in fade-in slide-in-from-bottom-4 duration-500">
        <PayslipModal 
          isOpen={!!selectedPayslip} 
          onClose={() => setSelectedPayslip(null)} 
          data={selectedPayslip} 
        />
        <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
          <div>
            <h1 className="text-2xl font-bold text-slate-900">Bảng lương cá nhân</h1>
            <p className="text-sm text-slate-500">Theo dõi thu nhập và phiếu lương hàng tháng</p>
          </div>
          <Button variant="outline" size="sm" onClick={handleExport}>
            <Download className="w-4 h-4 mr-2" /> Tải về lịch sử
          </Button>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
          <div className="bg-gradient-to-br from-indigo-500 to-indigo-700 rounded-xl p-6 shadow-md text-white flex flex-col justify-between">
            <div className="flex justify-between items-start mb-4">
              <div>
                <p className="text-indigo-100 text-sm font-medium">Thực lĩnh tháng gần nhất</p>
                <h3 className="text-3xl font-bold mt-1">{latestPayroll ? formatMoney(latestPayroll.netSalary) : '0 ₫'}</h3>
              </div>
              <div className="w-10 h-10 rounded-full bg-white/20 flex items-center justify-center backdrop-blur-sm">
                <Banknote className="w-5 h-5 text-white" />
              </div>
            </div>
            <p className="text-indigo-100 text-sm">{latestPayroll ? `Kỳ lương: ${latestPayroll.month}` : 'Chưa có dữ liệu'}</p>
          </div>

          <div className="bg-white rounded-xl border border-slate-200 p-6 shadow-sm flex flex-col justify-between">
            <div className="flex justify-between items-start mb-4">
              <div>
                <p className="text-slate-500 text-sm font-medium">Tổng thu nhập năm nay</p>
                <h3 className="text-2xl font-bold text-slate-900 mt-1">{formatMoney(totalYearIncome)}</h3>
              </div>
              <div className="w-10 h-10 rounded-full bg-emerald-50 flex items-center justify-center">
                <Calculator className="w-5 h-5 text-emerald-600" />
              </div>
            </div>
            <p className="text-slate-500 text-sm">Cộng dồn các tháng đã nhận</p>
          </div>

          <div className="bg-white rounded-xl border border-slate-200 p-6 shadow-sm flex flex-col justify-between">
            <div className="flex justify-between items-start mb-4">
              <div>
                <p className="text-slate-500 text-sm font-medium">Trạng thái lương</p>
                <h3 className="text-xl font-bold text-slate-900 mt-2">
                  {latestPayroll ? (
                    latestPayroll.status === 'Paid' ? "Đã thanh toán" :
                    latestPayroll.status === 'Confirmed' ? "Đã chốt (Chờ CK)" :
                    "Đang tính toán"
                  ) : "Không có dữ liệu"}
                </h3>
              </div>
              <div className="w-10 h-10 rounded-full bg-blue-50 flex items-center justify-center">
                <CheckCircle2 className="w-5 h-5 text-blue-600" />
              </div>
            </div>
            <p className="text-slate-500 text-sm">Tháng {latestPayroll ? latestPayroll.month : '--/--'}</p>
          </div>
        </div>

        <div className="bg-white rounded-xl border border-slate-200 shadow-sm overflow-hidden flex flex-col">
          <div className="p-4 border-b border-slate-200 flex items-center justify-end bg-slate-50/50">
            <input 
              type="month" 
              className="border border-slate-300 rounded-md px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-600 bg-white"
              value={month}
              onChange={(e) => setMonth(e.target.value)}
            />
          </div>

          <div className="overflow-x-auto min-h-[300px]">
            {isLoading ? (
              <div className="flex flex-col items-center justify-center h-[300px] text-slate-500">
                <Loader2 className="w-8 h-8 animate-spin text-indigo-600 mb-4" />
                <p>Đang tải dữ liệu...</p>
              </div>
            ) : error ? (
              <div className="flex items-center justify-center h-[300px] text-red-500">
                <p>Có lỗi xảy ra khi tải dữ liệu lương.</p>
              </div>
            ) : myPayrolls.length === 0 ? (
              <div className="flex items-center justify-center h-[300px] text-slate-500">
                <p>Bạn chưa có bảng lương nào.</p>
              </div>
            ) : (
              <table className="w-full text-left border-collapse min-w-[700px]">
                <thead>
                  <tr className="bg-slate-50 border-b border-slate-200 text-sm font-medium text-slate-600">
                    <th className="px-6 py-3">Tháng</th>
                    <th className="px-6 py-3">Lương Cơ Bản</th>
                    <th className="px-6 py-3">Ngày Công / Tăng Ca</th>
                    <th className="px-6 py-3">Thực Lĩnh</th>
                    <th className="px-6 py-3">Trạng Thái</th>
                    <th className="px-6 py-3 rounded-tr-lg text-right">Chi Tiết</th>
                  </tr>
                </thead>
                <tbody className="text-sm divide-y divide-slate-100">
                  {paginatedPayrolls.map((record) => (
                    <tr key={record.id} className="hover:bg-slate-50 transition-colors">
                      <td className="px-6 py-4 font-medium text-slate-900">{record.month}</td>
                      <td className="px-6 py-4 text-slate-600">{formatMoney(record.basicSalary)}</td>
                      <td className="px-6 py-4">
                        <div>{record.workingDays} ngày</div>
                        {record.otHours > 0 && <div className="text-xs text-indigo-600">{record.otHours}h OT</div>}
                      </td>
                      <td className="px-6 py-4 font-mono font-medium text-emerald-600 text-lg">
                        {formatMoney(record.netSalary)}
                      </td>
                      <td className="px-6 py-4">
                        <span className={cn(
                          "px-2.5 py-1 rounded-full text-xs font-medium border",
                          record.status === 'Paid' ? "bg-emerald-50 text-emerald-700 border-emerald-200" :
                          record.status === 'Confirmed' ? "bg-blue-50 text-blue-700 border-blue-200" :
                          "bg-amber-50 text-amber-700 border-amber-200"
                        )}>
                          {record.status === 'Paid' ? "Đã thanh toán" : 
                           record.status === 'Confirmed' ? "Đã chốt" : "Bản nháp"}
                        </span>
                      </td>
                      <td className="px-6 py-4 text-right">
                        <button 
                          onClick={() => { setSelectedPayslip(record); }}
                          className="text-indigo-600 hover:bg-indigo-50 px-3 py-1.5 rounded-md transition-colors text-sm font-medium inline-flex items-center gap-1 border border-indigo-100"
                        >
                          <FileText className="w-4 h-4" /> Phiếu Lương
                        </button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}
          </div>

          {!isLoading && !error && myPayrolls.length > 0 && (
            <div className="p-4 border-t border-slate-200 flex items-center justify-between text-sm text-slate-500 bg-white">
              <div>Hiển thị {(currentPage - 1) * itemsPerPage + 1}-{Math.min(currentPage * itemsPerPage, myPayrolls.length)} của {myPayrolls.length} bảng lương</div>
              <div className="flex items-center gap-1">
                <button 
                  onClick={() => setCurrentPage(p => Math.max(1, p - 1))}
                  disabled={currentPage === 1}
                  className="px-3 py-1.5 rounded-md border border-slate-200 hover:bg-slate-50 disabled:opacity-50 transition-colors"
                >Trước</button>
                <button className="px-3 py-1.5 rounded-md bg-indigo-600 text-white font-medium shadow-sm">{currentPage}</button>
                <button 
                  onClick={() => setCurrentPage(p => Math.min(Math.ceil(myPayrolls.length / itemsPerPage), p + 1))}
                  disabled={currentPage === Math.ceil(myPayrolls.length / itemsPerPage)}
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
      <PayslipModal 
        isOpen={!!selectedPayslip} 
        onClose={() => setSelectedPayslip(null)} 
        data={selectedPayslip} 
      />
      <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-slate-900">Bảng Lương Nhân Viên</h1>
          <p className="text-sm text-slate-500">Quản lý và tính toán lương hàng tháng</p>
        </div>
        <div className="flex items-center gap-2">
          {canManagePayroll && (
            <>
              <Button variant="outline" size="sm" onClick={() => calculateMutation.mutate()} disabled={!month || calculateMutation.isPending}>
                {calculateMutation.isPending ? <Loader2 className="w-4 h-4 mr-2 animate-spin" /> : <Calculator className="w-4 h-4 mr-2" />}
                Tính Lương
              </Button>
              <Button variant="outline" size="sm" className="text-emerald-600 border-emerald-200 hover:bg-emerald-50" onClick={() => confirmMutation.mutate()} disabled={!month || confirmMutation.isPending}>
                {confirmMutation.isPending ? <Loader2 className="w-4 h-4 mr-2 animate-spin" /> : <CheckCircle2 className="w-4 h-4 mr-2" />}
                Xác nhận
              </Button>
              <Button size="sm" variant="default" className="bg-indigo-600 hover:bg-indigo-700 text-white" onClick={() => payMutation.mutate()} disabled={!month || payMutation.isPending}>
                {payMutation.isPending ? <Loader2 className="w-4 h-4 mr-2 animate-spin" /> : <Banknote className="w-4 h-4 mr-2" />}
                Thanh toán
              </Button>
            </>
          )}
          <Button variant="outline" size="sm" onClick={handleExport}>
            <Download className="w-4 h-4 mr-2" /> Xuất file
          </Button>
        </div>
      </div>

      <div className="bg-white rounded-xl border border-slate-200 shadow-sm overflow-hidden flex flex-col">
        <div className="p-4 border-b border-slate-200 flex flex-col sm:flex-row gap-4 bg-slate-50/50">
          <div className="relative flex-1 max-w-[200px]">
            <input 
              type="month" 
              className="w-full px-4 py-2 border border-slate-300 rounded-md text-sm focus:outline-none focus:ring-2 focus:ring-indigo-600 bg-white"
              value={month}
              onChange={(e) => setMonth(e.target.value)}
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

        <div className="overflow-x-auto min-h-[300px]">
          {isLoading ? (
            <div className="flex flex-col items-center justify-center h-[300px] text-slate-500">
              <Loader2 className="w-8 h-8 animate-spin text-indigo-600 mb-4" />
              <p>Đang tải dữ liệu...</p>
            </div>
          ) : error ? (
             <div className="flex items-center justify-center h-[300px] text-red-500">
              <p>Có lỗi xảy ra khi tải dữ liệu bảng lương.</p>
            </div>
          ) : filteredPayrolls.length === 0 ? (
             <div className="flex items-center justify-center h-[300px] text-slate-500">
              <p>Không tìm thấy bảng lương nào.</p>
            </div>
          ) : (
            <table className="w-full text-left border-collapse min-w-[1200px]">
              <thead>
                <tr className="bg-slate-50 border-b border-slate-200 text-sm font-medium text-slate-600">
                  <th className="px-6 py-3 w-10">
                    <input type="checkbox" className="rounded border-slate-300 text-indigo-600 focus:ring-indigo-600" />
                  </th>
                  <th className="px-6 py-3">Mã NV</th>
                  <th className="px-6 py-3">Họ Tên</th>
                  <th className="px-6 py-3 text-right">Lương CB</th>
                  <th className="px-6 py-3 text-right">Công</th>
                  <th className="px-6 py-3 text-right">Tăng ca</th>
                  <th className="px-6 py-3 text-right">Phụ cấp</th>
                  <th className="px-6 py-3 text-right">Khấu trừ</th>
                  <th className="px-6 py-3 text-right">Thực lãnh</th>
                  <th className="px-6 py-3">Trạng Thái</th>
                  <th className="px-6 py-3 text-right">Hành động</th>
                </tr>
              </thead>
              <tbody className="text-sm">
                {paginatedPayrolls.map((record) => (
                  <tr key={record.id} className="border-b border-slate-100 hover:bg-slate-50 transition-colors">
                    <td className="px-6 py-4">
                      <input type="checkbox" className="rounded border-slate-300 text-indigo-600 focus:ring-indigo-600" />
                    </td>
                    <td className="px-6 py-4 font-medium text-slate-900">{record.empId}</td>
                    <td className="px-6 py-4 font-medium text-slate-900">{record.name}
                      <div className="text-xs text-slate-500 font-normal">{deptMap[record.dept] || record.dept}</div>
                    </td>
                    <td className="px-6 py-4 text-right font-medium">{formatMoney(record.basicSalary)}</td>
                    <td className="px-6 py-4 text-right">{record.workingDays}đ</td>
                    <td className="px-6 py-4 text-right">{record.otHours}h</td>
                    <td className="px-6 py-4 text-right text-emerald-600">+{formatMoney(record.allowance)}</td>
                    <td className="px-6 py-4 text-right text-red-600">-{formatMoney(record.deduction)}</td>
                    <td className="px-6 py-4 text-right font-bold text-indigo-600">{formatMoney(record.netSalary)}</td>
                    <td className="px-6 py-4">
                      <span className={cn(
                        "px-2.5 py-1 rounded-full text-xs font-medium border",
                        record.status === 'D' ? "bg-slate-100 text-slate-700 border-slate-200" :
                        record.status === 'C' ? "bg-blue-50 text-blue-700 border-blue-200" :
                        record.status === 'L' ? "bg-emerald-50 text-emerald-700 border-emerald-200" :
                        "bg-slate-100 text-slate-700 border-slate-200"
                      )}>
                        {record.status === 'D' ? "Nháp" : 
                         record.status === 'C' ? "Đã xác nhận" : 
                         record.status === 'L' ? "Đã chốt" : 
                         record.status === 'P' ? "Đã thanh toán" : record.status}
                      </span>
                    </td>
                    <td className="px-6 py-4 text-right">
                      <div className="flex items-center justify-end gap-2 text-slate-400">
                        <button 
                          onClick={() => setSelectedPayslip(record)}
                          className="hover:text-indigo-600 p-1.5 rounded-md hover:bg-indigo-50 transition-colors" 
                          title="Xem chi tiết"
                        >
                          <FileText className="w-4 h-4" />
                        </button>
                        <button 
                          onClick={() => {
                            setSelectedPayslip(record);
                            setTimeout(() => window.print(), 300);
                          }}
                          className="hover:text-indigo-600 p-1.5 rounded-md hover:bg-indigo-50 transition-colors" 
                          title="Tải PDF"
                        >
                          <Download className="w-4 h-4" />
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>

        {!isLoading && !error && filteredPayrolls.length > 0 && (
          <div className="p-4 border-t border-slate-200 flex items-center justify-between text-sm text-slate-500 bg-white">
            <div>Hiển thị {(currentPage - 1) * itemsPerPage + 1}-{Math.min(currentPage * itemsPerPage, filteredPayrolls.length)} của {filteredPayrolls.length} bảng lương</div>
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
