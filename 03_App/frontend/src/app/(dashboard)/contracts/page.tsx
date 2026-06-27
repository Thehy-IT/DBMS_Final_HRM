"use client";

import { useState, useEffect, useRef } from "react";
import { useSearchParams, useRouter } from "next/navigation";
import { Search, Plus, Upload, Download, FileSignature, Loader2, Edit2, FileMinus } from "lucide-react";
import { Button } from "@/components/ui/button";
import { cn, formatMoney, formatDate } from "@/lib/utils";
import { ContractFormDrawer } from "@/components/contracts/ContractFormDrawer";
import { useQuery } from "@tanstack/react-query";
import { contractService } from "@/services/contract.service";
import { masterDataService } from "@/services/masterData.service";
import { exportToExcel } from "@/lib/excel";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { useAuthStore } from "@/store/useAuthStore";

export default function ContractListPage() {
  const [searchTerm, setSearchTerm] = useState("");
  const [contractTypeFilter, setContractTypeFilter] = useState("");
  const [statusFilter, setStatusFilter] = useState("");
  const [isDrawerOpen, setIsDrawerOpen] = useState(false);
  const [selectedContractId, setSelectedContractId] = useState<string | null>(null);
  const [currentPage, setCurrentPage] = useState(1);
  const itemsPerPage = 50;

  const fileInputRef = useRef<HTMLInputElement>(null);
  const queryClient = useQueryClient();
  const { user } = useAuthStore();
  const isHR = user?.role === 'HR' || user?.role === 'ADMIN';

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

  const { data: contractTypesData } = useQuery({
    queryKey: ['contract-types'],
    queryFn: () => masterDataService.getContractTypes(),
  });

  const terminateMutation = useMutation({
    mutationFn: async (contractSummary: any) => {
      try {
        // Fetch full contract details first
        const fullContract = await contractService.getContractById(contractSummary.id);
        
        // Ensure data exists, handle nested data if backend returns { data: ... }
        const actualData = (fullContract as any).data || fullContract;

        return await contractService.updateContract(contractSummary.id, {
          ...actualData,
          startDate: actualData.startDate ? actualData.startDate.split('T')[0] : '',
          endDate: actualData.endDate ? actualData.endDate.split('T')[0] : '',
          status: 'T',
          // Preserve VungLuong if it exists, otherwise default to 1
          VungLuong: actualData.VungLuong || 1
        });
      } catch (err: any) {
        // If fetching fails, fallback to sending partial update
        return await contractService.updateContract(contractSummary.id, {
          id: contractSummary.id,
          status: 'T'
        });
      }
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['contracts'] });
      alert("Đã thanh lý hợp đồng!");
    },
    onError: (error: any) => {
      console.error("Lỗi thanh lý hợp đồng:", error?.response?.data || error);
      alert(`Có lỗi xảy ra khi thanh lý hợp đồng: ${error?.response?.data?.error || error?.response?.data?.message || error.message || ''}`);
    }
  });

  const contracts = data?.data || [];

  const uniqueStatuses = Array.from(new Set(contracts.map((c: any) => c.status))).filter(Boolean) as string[];
  const getStatusLabel = (s: string) => {
    switch(s) {
      case 'A': return 'Hiệu lực';
      case 'E': return 'Hết hạn';
      case 'T': return 'Đã chấm dứt';
      case 'D': return 'Nháp';
      default: return s;
    }
  };

  const filteredContracts = contracts.filter(contract => {
    if (searchTerm && !(contract.empName || '').toLowerCase().includes(searchTerm.toLowerCase()) && !contract.id.toLowerCase().includes(searchTerm.toLowerCase())) {
      return false;
    }
    if (contractTypeFilter) {
      const selectedType = contractTypesData?.find((t: any) => String(t.id) === String(contractTypeFilter) || String(t.name) === String(contractTypeFilter));
      if (String(contract.type) !== String(contractTypeFilter) && String(contract.type) !== String(selectedType?.name) && String(contract.type) !== String(selectedType?.id)) {
        return false;
      }
    }
    if (statusFilter && contract.status !== statusFilter) {
      return false;
    }
    return true;
  });

  const totalPages = Math.ceil(filteredContracts.length / itemsPerPage);
  const paginatedContracts = filteredContracts.slice((currentPage - 1) * itemsPerPage, currentPage * itemsPerPage);

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

  const handleImportClick = () => {
    fileInputRef.current?.click();
  };

  const handleFileChange = (event: React.ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    if (file) {
      alert(`Đã chọn file: ${file.name}. Hệ thống đang giả lập xử lý nhập dữ liệu hợp đồng...`);
      setTimeout(() => alert("Nhập dữ liệu hợp đồng thành công!"), 1000);
      if (fileInputRef.current) {
        fileInputRef.current.value = '';
      }
    }
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
                <Upload className="w-4 h-4 mr-2" /> Nhập file
              </Button>
            </>
          )}
          <Button variant="outline" size="sm" onClick={handleExport}>
            <Download className="w-4 h-4 mr-2" /> Xuất file
          </Button>
          {isHR && (
            <Button size="sm" onClick={() => { setSelectedContractId(null); setIsDrawerOpen(true); }}>
              <Plus className="w-4 h-4 mr-2" /> Tạo Hợp Đồng
            </Button>
          )}
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
          <select 
            className="border border-slate-300 rounded-md px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-600 bg-white"
            value={contractTypeFilter}
            onChange={(e) => setContractTypeFilter(e.target.value)}
          >
            <option value="">Tất cả loại HĐ</option>
            {contractTypesData?.map((type: any) => (
              <option key={type.id} value={type.id}>{type.name}</option>
            ))}
          </select>
          <select 
            className="border border-slate-300 rounded-md px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-600 bg-white"
            value={statusFilter}
            onChange={(e) => setStatusFilter(e.target.value)}
          >
            <option value="">Tất cả trạng thái</option>
            <option value="A">Hiệu lực</option>
            <option value="E">Hết hạn</option>
            <option value="T">Đã chấm dứt</option>
            <option value="D">Nháp</option>
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
                <tr className="bg-slate-50 border-b border-slate-200 text-sm font-medium text-slate-600 whitespace-nowrap">
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
                {paginatedContracts.map((contract) => (
                  <tr key={contract.id} className="border-b border-slate-100 hover:bg-slate-50 transition-colors whitespace-nowrap">
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
                      <div className="flex items-center gap-2">
                        <span>{formatDate(contract.startDate)}</span>
                        <span className="text-slate-400">→</span>
                        <span className={contract.endDate ? "" : "text-slate-500 italic"}>
                          {contract.endDate ? formatDate(contract.endDate) : "Không xác định"}
                        </span>
                      </div>
                    </td>
                    <td className="px-6 py-4 font-medium">{formatMoney(contract.salary)}</td>
                    <td className="px-6 py-4">
                      <span className={cn(
                        "px-2.5 py-1 rounded-full text-xs font-medium border",
                        contract.status === 'A' ? "bg-emerald-50 text-emerald-700 border-emerald-200" :
                        contract.status === 'E' ? "bg-amber-50 text-amber-700 border-amber-200" :
                        contract.status === 'T' ? "bg-red-50 text-red-700 border-red-200" :
                        "bg-slate-100 text-slate-700 border-slate-200"
                      )}>
                        {contract.status === 'A' ? "Hiệu lực" : contract.status === 'E' ? "Hết hạn" : contract.status === 'T' ? "Đã chấm dứt" : "Nháp"}
                      </span>
                    </td>
                    <td className="px-6 py-4 text-right">
                      {isHR ? (
                        <div className="flex items-center justify-end gap-2 text-slate-400">
                          <button 
                            onClick={() => { setSelectedContractId(contract.id); setIsDrawerOpen(true); }}
                            className="hover:text-indigo-600 p-1.5 rounded-md hover:bg-indigo-50 transition-colors" title="Chỉnh sửa"
                          >
                            <Edit2 className="w-4 h-4" />
                          </button>
                          <button 
                            onClick={() => {
                              if (window.confirm(`Bạn có chắc chắn muốn thanh lý hợp đồng ${contract.id} của nhân viên ${contract.empName}?`)) {
                                terminateMutation.mutate(contract);
                              }
                            }}
                            disabled={terminateMutation.isPending || contract.status === 'T'}
                            className={cn(
                              "p-1.5 rounded-md transition-colors",
                              contract.status === 'T' ? "opacity-30 cursor-not-allowed text-slate-400" : "hover:text-red-600 hover:bg-red-50 text-slate-400"
                            )}
                            title="Thanh lý hợp đồng"
                          >
                            {terminateMutation.isPending ? <Loader2 className="w-4 h-4 animate-spin" /> : <FileMinus className="w-4 h-4" />}
                          </button>
                        </div>
                      ) : (
                        <span className="text-sm text-slate-400 italic">Không có H.Động</span>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>

        {!isLoading && !error && filteredContracts.length > 0 && (
          <div className="p-4 border-t border-slate-200 flex items-center justify-between text-sm text-slate-500 bg-white">
            <div>Hiển thị {(currentPage - 1) * itemsPerPage + 1}-{Math.min(currentPage * itemsPerPage, filteredContracts.length)} của {filteredContracts.length} hợp đồng</div>
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
