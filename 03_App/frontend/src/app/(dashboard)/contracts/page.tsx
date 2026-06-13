"use client";

import { useState, useEffect } from "react";
import { useSearchParams, useRouter } from "next/navigation";
import { Search, Plus, Upload, Download, MoreVertical, FileSignature, Loader2, Edit2 } from "lucide-react";
import { Button } from "@/components/ui/button";
import { cn, formatMoney, formatDate } from "@/lib/utils";
import { ContractFormDrawer } from "@/components/contracts/ContractFormDrawer";
import { useQuery } from "@tanstack/react-query";
import { contractService } from "@/services/contract.service";
import { exportToExcel } from "@/lib/excel";

export default function ContractListPage() {
  const [searchTerm, setSearchTerm] = useState("");
  const [isDrawerOpen, setIsDrawerOpen] = useState(false);
  const [selectedContractId, setSelectedContractId] = useState<string | null>(null);

  const searchParams = useSearchParams();
  const router = useRouter();

  useEffect(() => {
    if (searchParams.get('action') === 'new') {
      setSelectedContractId(null);
      setIsDrawerOpen(true);
      router.replace('/contracts');
    }
  }, [searchParams, router]);

  const { data, isLoading, error } = useQuery({
    queryKey: ['contracts'],
    queryFn: () => contractService.getContracts(),
  });

  const contracts = data?.data || [];

  const filteredContracts = contracts.filter(contract => {
    if (searchTerm && !(contract.empName || '').toLowerCase().includes(searchTerm.toLowerCase()) && !contract.id.toLowerCase().includes(searchTerm.toLowerCase())) {
      return false;
    }
    return true;
  });
  const handleExport = () => {
    const exportData = filteredContracts.map(r => ({
      'Mã Hợp Đồng': r.id,
      'Nhân Viên': r.empName,
      'Loại HĐ': r.type,
      'Mức Lương': r.salary,
      'Ngày Bắt Đầu': r.startDate,
      'Ngày Kết Thúc': r.endDate || 'Vô thời hạn',
      'Trạng Thái': r.status
    }));
    exportToExcel(exportData, `HopDong_List`);
  };

  return (
    <div className="space-y-6">
      <ContractFormDrawer 
        isOpen={isDrawerOpen} 
        onClose={() => setIsDrawerOpen(false)} 
        contractId={selectedContractId}
      />

      <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-slate-900">Quản lý Hợp đồng</h1>
          <p className="text-sm text-slate-500">Danh sách hợp đồng lao động của nhân viên</p>
        </div>
        <div className="flex items-center gap-2">
          <Button variant="outline" size="sm">
            <Upload className="w-4 h-4 mr-2" /> Nhập file
          </Button>
          <Button variant="outline" size="sm" onClick={handleExport}>
            <Download className="w-4 h-4 mr-2" /> Xuất file
          </Button>
          <Button size="sm" onClick={() => { setSelectedContractId(null); setIsDrawerOpen(true); }}>
            <Plus className="w-4 h-4 mr-2" /> Thêm Hợp Đồng
          </Button>
        </div>
      </div>

      <div className="bg-white rounded-xl border border-slate-200 shadow-sm overflow-hidden flex flex-col">
        <div className="p-4 border-b border-slate-200 flex flex-col sm:flex-row gap-4 bg-slate-50/50">
          <div className="relative flex-1 max-w-md">
            <Search className="w-4 h-4 absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" />
            <input 
              type="text" 
              placeholder="Tìm theo Mã HĐ, Tên Nhân Viên..." 
              className="w-full pl-9 pr-4 py-2 border border-slate-300 rounded-md text-sm focus:outline-none focus:ring-2 focus:ring-indigo-600 bg-white"
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
            />
          </div>
          <select className="border border-slate-300 rounded-md px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-600 bg-white">
            <option value="">Tất cả loại HĐ</option>
            <option value="Thử việc">Thử việc</option>
            <option value="Có thời hạn">Có thời hạn</option>
            <option value="Không thời hạn">Không thời hạn</option>
          </select>
          <select className="border border-slate-300 rounded-md px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-600 bg-white">
            <option value="">Tất cả trạng thái</option>
            <option value="A">Hiệu lực</option>
            <option value="E">Hết hạn</option>
            <option value="T">Đã chấm dứt</option>
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
              <p>Có lỗi xảy ra khi tải dữ liệu hợp đồng.</p>
            </div>
          ) : filteredContracts.length === 0 ? (
             <div className="flex items-center justify-center h-[300px] text-slate-500">
              <p>Không tìm thấy hợp đồng nào.</p>
            </div>
          ) : (
            <table className="w-full text-left border-collapse min-w-[900px]">
              <thead>
                <tr className="bg-slate-50 border-b border-slate-200 text-sm font-medium text-slate-600">
                  <th className="px-6 py-3 w-10">
                    <input type="checkbox" className="rounded border-slate-300 text-indigo-600 focus:ring-indigo-600" />
                  </th>
                  <th className="px-6 py-3">Mã HĐ</th>
                  <th className="px-6 py-3">Nhân Viên</th>
                  <th className="px-6 py-3">Loại HĐ</th>
                  <th className="px-6 py-3">Thời Hạn</th>
                  <th className="px-6 py-3">Lương Cơ Bản</th>
                  <th className="px-6 py-3">Trạng Thái</th>
                  <th className="px-6 py-3 text-right">Hành động</th>
                </tr>
              </thead>
              <tbody className="text-sm">
                {filteredContracts.map((contract) => (
                  <tr key={contract.id} className="border-b border-slate-100 hover:bg-slate-50 transition-colors">
                    <td className="px-6 py-4">
                      <input type="checkbox" className="rounded border-slate-300 text-indigo-600 focus:ring-indigo-600" />
                    </td>
                    <td className="px-6 py-4 font-medium text-indigo-600 cursor-pointer hover:underline">{contract.id}</td>
                    <td className="px-6 py-4 font-medium text-slate-900">{contract.empName}</td>
                    <td className="px-6 py-4">
                      <span className="px-2.5 py-1 rounded-full text-xs font-medium bg-slate-100 text-slate-700 border border-slate-200">
                        {contract.type}
                      </span>
                    </td>
                    <td className="px-6 py-4">
                      <div>{formatDate(contract.startDate)}</div>
                      <div className="text-slate-500 text-xs">
                        {contract.endDate ? `đến ${formatDate(contract.endDate)}` : "Không xác định"}
                      </div>
                    </td>
                    <td className="px-6 py-4 font-medium">{formatMoney(contract.salary)}</td>
                    <td className="px-6 py-4">
                      <span className={cn(
                        "px-2.5 py-1 rounded-full text-xs font-medium border",
                        contract.status === 'A' ? "bg-emerald-50 text-emerald-700 border-emerald-200" :
                        contract.status === 'E' ? "bg-amber-50 text-amber-700 border-amber-200" :
                        "bg-red-50 text-red-700 border-red-200"
                      )}>
                        {contract.status === 'A' ? "Hiệu lực" : contract.status === 'E' ? "Hết hạn" : contract.status === 'T' ? "Đã chấm dứt" : "Nháp"}
                      </span>
                    </td>
                    <td className="px-6 py-4 text-right">
                      <div className="flex items-center justify-end gap-2 text-slate-400">
                        <button 
                          onClick={() => { setSelectedContractId(contract.id); setIsDrawerOpen(true); }}
                          className="hover:text-indigo-600 p-1.5 rounded-md hover:bg-indigo-50 transition-colors" title="Chỉnh sửa"
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

        {!isLoading && !error && filteredContracts.length > 0 && (
          <div className="p-4 border-t border-slate-200 flex items-center justify-between text-sm text-slate-500 bg-white">
            <div>Hiển thị 1-{filteredContracts.length} của {filteredContracts.length} hợp đồng</div>
            <div className="flex items-center gap-1">
              <button className="px-3 py-1.5 rounded-md border border-slate-200 hover:bg-slate-50 disabled:opacity-50 transition-colors" disabled>Trước</button>
              <button className="px-3 py-1.5 rounded-md bg-indigo-600 text-white font-medium shadow-sm">1</button>
              <button className="px-3 py-1.5 rounded-md border border-slate-200 hover:bg-slate-50 disabled:opacity-50 transition-colors" disabled>Sau</button>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
