"use client";

import { useState, useEffect } from "react";
import { X, Loader2 } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { contractService, Contract } from "@/services/contract.service";
import { masterDataService } from "@/services/masterData.service";
import { employeeService } from "@/services/employee.service";

interface ContractFormDrawerProps {
  isOpen: boolean;
  onClose: () => void;
  contractId?: string | null;
}

export function ContractFormDrawer({ isOpen, onClose, contractId }: ContractFormDrawerProps) {
  const queryClient = useQueryClient();

  // Master Data & Employees
  const { data: contractTypes = [] } = useQuery({
    queryKey: ['contract-types'],
    queryFn: masterDataService.getContractTypes,
    enabled: isOpen
  });

  const { data: employeesData } = useQuery({
    queryKey: ['employees'],
    queryFn: () => employeeService.getEmployees(),
    enabled: isOpen
  });
  const employees = employeesData?.data || [];

  const [formData, setFormData] = useState<Partial<Contract>>({
    id: '',
    empId: '',
    typeId: '',
    startDate: '',
    endDate: '',
    salary: 0,
    status: 'A'
  });
  
  const [vungLuong, setVungLuong] = useState("1"); // Not in Contract interface initially, but needed for DB

  const { data: contractData, isLoading: isLoadingContract } = useQuery({
    queryKey: ['contract', contractId],
    queryFn: () => contractService.getContractById(contractId!),
    enabled: !!contractId && isOpen,
  });

  useEffect(() => {
    if (contractData) {
      setFormData({
        ...contractData,
        startDate: contractData.startDate ? contractData.startDate.split('T')[0] : '',
        endDate: contractData.endDate ? contractData.endDate.split('T')[0] : ''
      });
      // VungLuong logic could be added if interface was extended, defaulting to 1
      setVungLuong((contractData as any).VungLuong || "1");
    } else if (!contractId) {
      setFormData({
        id: '',
        empId: '',
        typeId: '',
        startDate: '',
        endDate: '',
        salary: 0,
        status: 'A'
      });
      setVungLuong("1");
    }
  }, [contractData, contractId, isOpen]);

  const mutation = useMutation({
    mutationFn: (data: Partial<Contract> & { VungLuong?: number }) => {
      return contractId 
        ? contractService.updateContract(contractId, data)
        : contractService.createContract(data);
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['contracts'] });
      onClose();
    }
  });

  const handleChange = (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement>) => {
    const { name, value } = e.target;
    setFormData(prev => ({ ...prev, [name]: value }));
  };

  const handleSubmit = () => {
    mutation.mutate({
      ...formData,
      VungLuong: parseInt(vungLuong)
    });
  };

  if (!isOpen) return null;

  return (
    <>
      <div className="fixed inset-0 bg-slate-900/40 backdrop-blur-sm z-40 transition-opacity" onClick={onClose} />
      
      <div className="fixed inset-y-0 right-0 w-full md:w-[500px] bg-white shadow-2xl z-50 flex flex-col animate-in slide-in-from-right duration-300">
        <div className="flex items-center justify-between p-6 border-b border-slate-200">
          <div>
            <h2 className="text-xl font-bold text-slate-900">{contractId ? 'Sửa Hợp Đồng' : 'Thêm Hợp Đồng'}</h2>
            <p className="text-sm text-slate-500 mt-1">Khởi tạo hợp đồng lao động mới</p>
          </div>
          <button onClick={onClose} className="p-2 hover:bg-slate-100 rounded-full text-slate-500 transition-colors">
            <X className="w-5 h-5" />
          </button>
        </div>

        <div className="flex-1 overflow-y-auto p-6 bg-slate-50/30">
          {isLoadingContract ? (
            <div className="flex justify-center items-center h-full"><Loader2 className="animate-spin text-indigo-600 w-8 h-8" /></div>
          ) : (
            <div className="space-y-5">
              <div className="space-y-1.5">
                <label className="text-sm font-medium text-slate-700">Mã Hợp Đồng <span className="text-red-500">*</span></label>
                <Input name="id" value={formData.id} onChange={handleChange} placeholder="HD00000001" disabled={!!contractId} className={contractId ? "bg-slate-100" : ""} />
              </div>

              <div className="space-y-1.5">
                <label className="text-sm font-medium text-slate-700">Nhân Viên <span className="text-red-500">*</span></label>
                <select name="empId" value={formData.empId} onChange={handleChange} className="flex h-10 w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-indigo-600">
                  <option value="">-- Chọn nhân viên --</option>
                  {employees.map((emp: any) => (
                    <option key={emp.MaNV} value={emp.MaNV}>{emp.MaNV} - {emp.HoTen}</option>
                  ))}
                </select>
              </div>

              <div className="space-y-1.5">
                <label className="text-sm font-medium text-slate-700">Loại Hợp Đồng <span className="text-red-500">*</span></label>
                <select name="typeId" value={formData.typeId} onChange={handleChange} className="flex h-10 w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-indigo-600">
                  <option value="">-- Chọn loại hợp đồng --</option>
                  {contractTypes.map((type: any) => (
                    <option key={type.id} value={type.id}>{type.name}</option>
                  ))}
                </select>
              </div>

              <div className="grid grid-cols-2 gap-5">
                <div className="space-y-1.5">
                  <label className="text-sm font-medium text-slate-700">Ngày Bắt Đầu <span className="text-red-500">*</span></label>
                  <Input type="date" name="startDate" value={formData.startDate} onChange={handleChange} />
                </div>
                <div className="space-y-1.5">
                  <label className="text-sm font-medium text-slate-700">Ngày Kết Thúc</label>
                  <Input type="date" name="endDate" value={formData.endDate || ''} onChange={handleChange} />
                </div>
              </div>

              <div className="space-y-1.5">
                <label className="text-sm font-medium text-slate-700">Lương Cơ Bản (VNĐ) <span className="text-red-500">*</span></label>
                <Input type="number" name="salary" value={formData.salary} onChange={handleChange} placeholder="Ví dụ: 10000000" />
              </div>

              <div className="space-y-1.5">
                <label className="text-sm font-medium text-slate-700">Vùng Lương <span className="text-red-500">*</span></label>
                <select value={vungLuong} onChange={(e) => setVungLuong(e.target.value)} className="flex h-10 w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-indigo-600">
                  <option value="1">Vùng 1</option>
                  <option value="2">Vùng 2</option>
                  <option value="3">Vùng 3</option>
                  <option value="4">Vùng 4</option>
                </select>
              </div>
            </div>
          )}
        </div>

        <div className="p-6 border-t border-slate-200 bg-white flex items-center justify-end gap-3 shadow-[0_-4px_6px_-1px_rgba(0,0,0,0.05)]">
          <Button variant="ghost" onClick={onClose} disabled={mutation.isPending}>Hủy</Button>
          <Button onClick={handleSubmit} disabled={mutation.isPending}>
            {mutation.isPending && <Loader2 className="w-4 h-4 mr-2 animate-spin" />}
            {contractId ? 'Cập nhật' : 'Lưu Hợp Đồng'}
          </Button>
        </div>
      </div>
    </>
  );
}
