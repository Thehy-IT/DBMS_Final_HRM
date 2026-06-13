"use client";

import { useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { contractService } from "@/services/contract.service";
import { payrollService } from "@/services/payroll.service";
import { Search, FileText, Calculator, Loader2 } from "lucide-react";
import { cn, formatMoney, formatDate } from "@/lib/utils";

export default function HistoryPage() {
  const [activeTab, setActiveTab] = useState<'contracts' | 'payroll'>('contracts');
  const [searchTerm, setSearchTerm] = useState("");
  const [currentPage, setCurrentPage] = useState(1);
  const itemsPerPage = 50;

  const { data: contractData, isLoading: contractLoading, error: contractError } = useQuery({
    queryKey: ['contracts'],
    queryFn: () => contractService.getContracts(),
  });

  const { data: payrollData, isLoading: payrollLoading, error: payrollError } = useQuery({
    queryKey: ['payroll'],
    queryFn: () => payrollService.getPayroll(),
  });

  const contracts = contractData?.data || [];
  const payrolls = payrollData?.data || [];

  const filteredContracts = contracts.filter(c => {
    if (searchTerm && !(c.empName || '').toLowerCase().includes(searchTerm.toLowerCase()) && !(c.empId || '').toLowerCase().includes(searchTerm.toLowerCase()) && !c.id.toLowerCase().includes(searchTerm.toLowerCase())) {
      return false;
    }
    return true;
  });

  const filteredPayrolls = payrolls.filter(p => {
    if (searchTerm && !(p.empName || '').toLowerCase().includes(searchTerm.toLowerCase()) && !(p.empId || '').toLowerCase().includes(searchTerm.toLowerCase()) && !p.id.toLowerCase().includes(searchTerm.toLowerCase())) {
      return false;
    }
    return true;
  });

  const totalContractsPages = Math.ceil(filteredContracts.length / itemsPerPage);
  const paginatedContracts = filteredContracts.slice((currentPage - 1) * itemsPerPage, currentPage * itemsPerPage);

  const totalPayrollPages = Math.ceil(filteredPayrolls.length / itemsPerPage);
  const paginatedPayrolls = filteredPayrolls.slice((currentPage - 1) * itemsPerPage, currentPage * itemsPerPage);

  const totalPages = activeTab === 'contracts' ? totalContractsPages : totalPayrollPages;
  const currentTotal = activeTab === 'contracts' ? filteredContracts.length : filteredPayrolls.length;

  return (
    <div className="space-y-6 animate-in fade-in slide-in-from-bottom-4 duration-500">
      <div>
        <h1 className="text-2xl font-bold text-slate-900">Tra cứu Lịch sử</h1>
        <p className="text-sm text-slate-500 mt-1">Xem lại lịch sử thay đổi hợp đồng và bảng lương nhân viên</p>
      </div>

      <div className="bg-white rounded-xl border border-slate-200 shadow-sm overflow-hidden">
        {/* Tabs */}
        <div className="flex border-b border-slate-200 px-6 pt-2 bg-slate-50/50">
          <button
            onClick={() => { setActiveTab('contracts'); setCurrentPage(1); }}
            className={cn(
              "flex items-center gap-2 px-4 py-3 text-sm font-medium border-b-2 transition-colors",
              activeTab === 'contracts' 
                ? "border-indigo-600 text-indigo-600" 
                : "border-transparent text-slate-500 hover:text-slate-700 hover:border-slate-300"
            )}
          >
            <FileText className="w-4 h-4" />
            Lịch sử Hợp đồng
          </button>
          <button
            onClick={() => { setActiveTab('payroll'); setCurrentPage(1); }}
            className={cn(
              "flex items-center gap-2 px-4 py-3 text-sm font-medium border-b-2 transition-colors",
              activeTab === 'payroll' 
                ? "border-indigo-600 text-indigo-600" 
                : "border-transparent text-slate-500 hover:text-slate-700 hover:border-slate-300"
            )}
          >
            <Calculator className="w-4 h-4" />
            Lịch sử Bảng lương
          </button>
        </div>

        {/* Filter Area */}
        <div className="p-4 border-b border-slate-200 flex items-center gap-4">
          <div className="relative flex-1 max-w-md">
            <Search className="w-4 h-4 absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" />
            <input 
              type="text" 
              placeholder={activeTab === 'contracts' ? "Tìm theo mã HĐ, tên NV..." : "Tìm theo mã lương, tên NV..."}
              className="w-full pl-9 pr-4 py-2 border border-slate-300 rounded-md text-sm focus:outline-none focus:ring-2 focus:ring-indigo-600 bg-white shadow-sm"
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
            />
          </div>
        </div>

        {/* Content Area */}
        <div className="overflow-x-auto min-h-[300px]">
          {activeTab === 'contracts' && (
            <>
              {contractLoading ? (
                <div className="flex flex-col items-center justify-center h-[300px] text-slate-500">
                  <Loader2 className="w-8 h-8 animate-spin text-indigo-600 mb-4" />
                  <p>Đang tải dữ liệu...</p>
                </div>
              ) : contractError ? (
                <div className="flex items-center justify-center h-[300px] text-red-500">Có lỗi xảy ra khi tải dữ liệu.</div>
              ) : filteredContracts.length === 0 ? (
                <div className="flex items-center justify-center h-[300px] text-slate-500">Không tìm thấy dữ liệu lịch sử hợp đồng.</div>
              ) : (
                <table className="w-full text-left border-collapse min-w-[900px]">
                  <thead>
                    <tr className="bg-slate-50 border-b border-slate-200 text-sm font-medium text-slate-600">
                      <th className="px-6 py-3">Mã HĐ</th>
                      <th className="px-6 py-3">Nhân Viên</th>
                      <th className="px-6 py-3">Loại HĐ</th>
                      <th className="px-6 py-3">Ngày Ký</th>
                      <th className="px-6 py-3">Lương CB</th>
                      <th className="px-6 py-3">Trạng Thái</th>
                    </tr>
                  </thead>
                  <tbody className="text-sm">
                    {paginatedContracts.map((c) => (
                      <tr key={c.id} className="border-b border-slate-100 hover:bg-slate-50 transition-colors">
                        <td className="px-6 py-4 font-medium text-indigo-600">{c.id}</td>
                        <td className="px-6 py-4 font-medium text-slate-900">{c.empName}</td>
                        <td className="px-6 py-4">
                          <span className="px-2.5 py-1 rounded-full text-xs font-medium bg-slate-100 text-slate-700 border border-slate-200">
                            {c.type}
                          </span>
                        </td>
                        <td className="px-6 py-4">{formatDate(c.startDate)}</td>
                        <td className="px-6 py-4 font-medium">{formatMoney(c.salary)}</td>
                        <td className="px-6 py-4">
                          <span className={cn(
                            "px-2.5 py-1 rounded-full text-xs font-medium border",
                            c.status === 'A' ? "bg-emerald-50 text-emerald-700 border-emerald-200" :
                            c.status === 'E' ? "bg-amber-50 text-amber-700 border-amber-200" :
                            "bg-red-50 text-red-700 border-red-200"
                          )}>
                            {c.status === 'A' ? "Hiệu lực" : c.status === 'E' ? "Hết hạn" : "Đã chấm dứt"}
                          </span>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              )}
            </>
          )}

          {activeTab === 'payroll' && (
            <>
              {payrollLoading ? (
                <div className="flex flex-col items-center justify-center h-[300px] text-slate-500">
                  <Loader2 className="w-8 h-8 animate-spin text-indigo-600 mb-4" />
                  <p>Đang tải dữ liệu...</p>
                </div>
              ) : payrollError ? (
                <div className="flex items-center justify-center h-[300px] text-red-500">Có lỗi xảy ra khi tải dữ liệu.</div>
              ) : filteredPayrolls.length === 0 ? (
                <div className="flex items-center justify-center h-[300px] text-slate-500">Không tìm thấy dữ liệu lịch sử bảng lương.</div>
              ) : (
                <table className="w-full text-left border-collapse min-w-[900px]">
                  <thead>
                    <tr className="bg-slate-50 border-b border-slate-200 text-sm font-medium text-slate-600">
                      <th className="px-6 py-3">Kỳ Lương</th>
                      <th className="px-6 py-3">Nhân Viên</th>
                      <th className="px-6 py-3 text-right">Lương CB</th>
                      <th className="px-6 py-3 text-right">Thực Lãnh</th>
                      <th className="px-6 py-3">Trạng Thái</th>
                    </tr>
                  </thead>
                  <tbody className="text-sm">
                    {paginatedPayrolls.map((p) => (
                      <tr key={p.id} className="border-b border-slate-100 hover:bg-slate-50 transition-colors">
                        <td className="px-6 py-4 font-medium text-slate-900">{p.period}</td>
                        <td className="px-6 py-4 font-medium text-slate-900">{p.empName}</td>
                        <td className="px-6 py-4 text-right text-slate-500">{formatMoney(p.baseSalary)}</td>
                        <td className="px-6 py-4 text-right font-medium text-indigo-600">{formatMoney(p.netSalary)}</td>
                        <td className="px-6 py-4">
                          <span className={cn(
                            "px-2.5 py-1 rounded-full text-xs font-medium border",
                            p.status === 'P' ? "bg-emerald-50 text-emerald-700 border-emerald-200" :
                            p.status === 'A' ? "bg-blue-50 text-blue-700 border-blue-200" :
                            "bg-amber-50 text-amber-700 border-amber-200"
                          )}>
                            {p.status === 'P' ? "Đã thanh toán" : p.status === 'A' ? "Đã chốt" : "Bản nháp"}
                          </span>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              )}
            </>
          )}
        </div>
        {/* Pagination */}
        <div className="p-4 border-t border-slate-200 flex items-center justify-between text-sm text-slate-500 bg-white">
          <div>Hiển thị {currentTotal > 0 ? (currentPage - 1) * itemsPerPage + 1 : 0}-{Math.min(currentPage * itemsPerPage, currentTotal)} của {currentTotal} kết quả</div>
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
      </div>
    </div>
  );
}
