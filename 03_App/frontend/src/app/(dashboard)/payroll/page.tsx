"use client";

import { useState } from "react";
import { Search, Calculator, CheckCircle2, Lock, Download, Printer, Loader2, Banknote } from "lucide-react";
import { Button } from "@/components/ui/button";
import { cn, formatMoney } from "@/lib/utils";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { payrollService } from "@/services/payroll.service";
import { exportToExcel } from "@/lib/excel";

export default function PayrollPage() {
  const [searchTerm, setSearchTerm] = useState("");
  const [month, setMonth] = useState(new Date().toISOString().slice(0, 7)); // YYYY-MM
  const queryClient = useQueryClient();

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

  const filteredPayrolls = payrolls.filter(record => {
    if (searchTerm && !record.name.toLowerCase().includes(searchTerm.toLowerCase()) && !record.empId?.toLowerCase().includes(searchTerm.toLowerCase())) {
      return false;
    }
    const [y, m] = month.split('-');
    if (month && (record.month !== parseInt(m) || record.year !== parseInt(y))) {
      return false;
    }
    return true;
  });

  const handleExport = () => {
    const exportData = filteredPayrolls.map(r => ({
      'Mã NV': r.empId,
      'Họ Tên': r.name,
      'Phòng Ban': r.dept,
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

  return (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-slate-900">Tính Lương (Payroll)</h1>
          <p className="text-sm text-slate-500">Chạy bảng lương tháng và xuất phiếu lương</p>
        </div>
        <div className="flex items-center gap-2">
          <Button variant="outline" size="sm" onClick={() => calculateMutation.mutate()} disabled={!month || calculateMutation.isPending}>
            {calculateMutation.isPending ? <Loader2 className="w-4 h-4 mr-2 animate-spin" /> : <Calculator className="w-4 h-4 mr-2" />}
            Chạy Lương
          </Button>
          <Button variant="outline" size="sm" className="text-emerald-600 border-emerald-200 hover:bg-emerald-50" onClick={() => confirmMutation.mutate()} disabled={!month || confirmMutation.isPending}>
            {confirmMutation.isPending ? <Loader2 className="w-4 h-4 mr-2 animate-spin" /> : <CheckCircle2 className="w-4 h-4 mr-2" />}
            Xác nhận
          </Button>
          <Button size="sm" variant="default" className="bg-indigo-600 hover:bg-indigo-700 text-white" onClick={() => payMutation.mutate()} disabled={!month || payMutation.isPending}>
            {payMutation.isPending ? <Loader2 className="w-4 h-4 mr-2 animate-spin" /> : <Banknote className="w-4 h-4 mr-2" />}
            Thanh toán
          </Button>
          <Button variant="outline" size="sm" onClick={handleExport}>
            <Download className="w-4 h-4 mr-2" /> Export
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
          <select className="border border-slate-300 rounded-md px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-600 bg-white">
            <option value="">Tất cả phòng ban</option>
            <option value="IT">IT</option>
            <option value="HR">HR</option>
            <option value="Sales">Sales</option>
          </select>
          <select className="border border-slate-300 rounded-md px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-600 bg-white">
            <option value="">Tất cả trạng thái</option>
            <option value="D">Nháp</option>
            <option value="C">Đã xác nhận</option>
            <option value="L">Đã chốt</option>
            <option value="P">Đã thanh toán</option>
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
                {filteredPayrolls.map((record) => (
                  <tr key={record.id} className="border-b border-slate-100 hover:bg-slate-50 transition-colors">
                    <td className="px-6 py-4">
                      <input type="checkbox" className="rounded border-slate-300 text-indigo-600 focus:ring-indigo-600" />
                    </td>
                    <td className="px-6 py-4 font-medium text-slate-900">{record.id}</td>
                    <td className="px-6 py-4 font-medium text-slate-900">{record.name}
                      <div className="text-xs text-slate-500 font-normal">{record.dept}</div>
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
                        <button className="hover:text-indigo-600 p-1.5 rounded-md hover:bg-indigo-50 transition-colors" title="Xem chi tiết">
                          <Printer className="w-4 h-4" />
                        </button>
                        <button className="hover:text-indigo-600 p-1.5 rounded-md hover:bg-indigo-50 transition-colors" title="Tải PDF">
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
      </div>
    </div>
  );
}
