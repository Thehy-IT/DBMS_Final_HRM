"use client";

import React, { useState, useEffect } from 'react';
import { useSearchParams, useRouter } from 'next/navigation';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { Gift, Plus, Search, Filter, Edit, Trash2, CheckCircle, XCircle } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { formatMoney } from '@/lib/utils';
import { masterDataService, MasterData } from '@/services/masterData.service';
import { BenefitFormModal } from '@/components/benefits/BenefitFormModal';
import { ConfirmDeleteModal } from '@/components/ui/ConfirmDeleteModal';

export default function BenefitsPage() {
  const searchParams = useSearchParams();
  const router = useRouter();
  const queryClient = useQueryClient();

  const [searchTerm, setSearchTerm] = useState('');
  
  // Modal states
  const [isFormOpen, setIsFormOpen] = useState(false);
  const [isDeleteOpen, setIsDeleteOpen] = useState(false);
  const [editingBenefit, setEditingBenefit] = useState<MasterData | null>(null);
  const [deletingBenefit, setDeletingBenefit] = useState<MasterData | null>(null);

  const [filterType, setFilterType] = useState('ALL'); // ALL, F, P
  const [filterStatus, setFilterStatus] = useState('ALL'); // ALL, 1, 0

  useEffect(() => {
    if (searchParams.get('action') === 'new') {
      setIsFormOpen(true);
      router.replace('/benefits', { scroll: false });
    }
  }, [searchParams, router]);

  // Fetch benefit types
  const { data: benefitsData, isLoading } = useQuery({
    queryKey: ['benefit-types'],
    queryFn: () => masterDataService.getBenefitTypes()
  });

  const benefits = benefitsData || [];

  // Mutations
  const createMutation = useMutation({
    mutationFn: (data: Partial<MasterData>) => masterDataService.createBenefitType(data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['benefit-types'] });
      alert('Tạo loại phúc lợi thành công!');
      setIsFormOpen(false);
    },
    onError: (error: any) => {
      alert(error.response?.data?.error || 'Có lỗi xảy ra khi tạo loại phúc lợi');
    }
  });

  const updateMutation = useMutation({
    mutationFn: ({ id, data }: { id: string, data: Partial<MasterData> }) => masterDataService.updateBenefitType(id, data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['benefit-types'] });
      alert('Cập nhật loại phúc lợi thành công!');
      setIsFormOpen(false);
    },
    onError: (error: any) => {
      alert(error.response?.data?.error || 'Có lỗi xảy ra khi cập nhật');
    }
  });

  const deleteMutation = useMutation({
    mutationFn: (id: string) => masterDataService.deleteBenefitType(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['benefit-types'] });
      alert('Xóa loại phúc lợi thành công!');
      setIsDeleteOpen(false);
      setDeletingBenefit(null);
    },
    onError: (error: any) => {
      alert(error.response?.data?.error || 'Có lỗi xảy ra khi xóa phúc lợi');
    }
  });

  const filteredBenefits = benefits.filter(b => {
    const matchesSearch = (b.TenFL || b.name || '').toLowerCase().includes(searchTerm.toLowerCase()) || 
                          (b.MaFL || b.id || '').toLowerCase().includes(searchTerm.toLowerCase());
    
    const matchesType = filterType === 'ALL' || b.LoaiGiaTri === filterType;
    const matchesStatus = filterStatus === 'ALL' || String(b.IsActive) === filterStatus;

    return matchesSearch && matchesType && matchesStatus;
  });

  const handleAdd = () => {
    setEditingBenefit(null);
    setIsFormOpen(true);
  };

  const handleEdit = (benefit: MasterData) => {
    setEditingBenefit(benefit);
    setIsFormOpen(true);
  };

  const handleDeleteClick = (benefit: MasterData) => {
    setDeletingBenefit(benefit);
    setIsDeleteOpen(true);
  };

  const handleFormSubmit = (data: Partial<MasterData>) => {
    if (editingBenefit) {
      updateMutation.mutate({ id: editingBenefit.id, data });
    } else {
      createMutation.mutate(data);
    }
  };

  const handleConfirmDelete = () => {
    if (deletingBenefit) {
      deleteMutation.mutate(deletingBenefit.id);
    }
  };

  return (
    <div className="space-y-6 animate-in fade-in duration-300">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-slate-900 flex items-center gap-2">
            <Gift className="h-6 w-6 text-indigo-600" />
            Cấu hình Loại phúc lợi
          </h1>
          <p className="text-sm text-slate-500 mt-1">
            Thiết lập và quản lý các loại phụ cấp, phúc lợi cho nhân viên.
          </p>
        </div>
        <div className="flex items-center gap-3">
          <Button onClick={handleAdd}>
            <Plus className="h-4 w-4 mr-2" />
            Thêm loại phúc lợi
          </Button>
        </div>
      </div>

      <div className="bg-white rounded-xl shadow-sm border border-slate-200 overflow-hidden">
        <div className="p-4 border-b border-slate-200 flex flex-col md:flex-row items-center gap-4 bg-slate-50/50">
          <div className="relative flex-1 w-full md:max-w-md">
            <Search className="absolute left-3 top-2.5 h-4 w-4 text-slate-400" />
            <Input 
              placeholder="Tìm kiếm theo mã, tên loại phúc lợi..." 
              className="pl-9 bg-white"
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
            />
          </div>
          <div className="flex items-center gap-3 w-full md:w-auto">
            <div className="flex items-center gap-2 bg-white border border-slate-200 rounded-md px-3 h-10">
              <Filter className="h-4 w-4 text-slate-400" />
              <select 
                className="bg-transparent text-sm text-slate-700 focus:outline-none"
                value={filterType}
                onChange={(e) => setFilterType(e.target.value)}
              >
                <option value="ALL">Tất cả loại giá trị</option>
                <option value="F">Cố định</option>
                <option value="P">Phần trăm</option>
              </select>
            </div>
            <select 
              className="h-10 border border-slate-200 rounded-md px-3 bg-white text-sm text-slate-700 focus:outline-none"
              value={filterStatus}
              onChange={(e) => setFilterStatus(e.target.value)}
            >
              <option value="ALL">Tất cả trạng thái</option>
              <option value="1">Đang hoạt động</option>
              <option value="0">Đã ẩn</option>
            </select>
          </div>
        </div>

        <div className="overflow-x-auto">
          <table className="w-full text-sm text-left">
            <thead className="text-xs text-slate-500 uppercase bg-slate-50 border-b border-slate-200">
              <tr>
                <th className="px-6 py-4 font-medium">Mã FL</th>
                <th className="px-6 py-4 font-medium">Tên Phúc Lợi</th>
                <th className="px-6 py-4 font-medium">Loại Giá Trị</th>
                <th className="px-6 py-4 font-medium">Giá Trị</th>
                <th className="px-6 py-4 font-medium text-center">Tính Thuế</th>
                <th className="px-6 py-4 font-medium text-center">Trạng Thái</th>
                <th className="px-6 py-4 font-medium text-right">Thao Tác</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {isLoading ? (
                <tr>
                  <td colSpan={7} className="px-6 py-12 text-center text-slate-500">
                    <div className="flex justify-center items-center">
                       <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-indigo-600"></div>
                    </div>
                  </td>
                </tr>
              ) : filteredBenefits.length > 0 ? (
                filteredBenefits.map((benefit) => (
                  <tr key={benefit.id} className="hover:bg-slate-50/80 transition-colors group">
                    <td className="px-6 py-4 font-medium text-indigo-600">
                      {benefit.MaFL || benefit.id}
                    </td>
                    <td className="px-6 py-4">
                      <p className="font-medium text-slate-900">{benefit.TenFL || benefit.name}</p>
                      <p className="text-xs text-slate-500 mt-0.5 max-w-[200px] truncate" title={benefit.MoTa}>
                        {benefit.MoTa}
                      </p>
                    </td>
                    <td className="px-6 py-4">
                      {benefit.LoaiGiaTri === 'F' ? (
                        <span className="inline-flex items-center px-2 py-1 rounded text-xs font-medium bg-blue-50 text-blue-700 border border-blue-100">
                          Cố định (Fixed)
                        </span>
                      ) : (
                        <span className="inline-flex items-center px-2 py-1 rounded text-xs font-medium bg-amber-50 text-amber-700 border border-amber-100">
                          Phần trăm (%)
                        </span>
                      )}
                    </td>
                    <td className="px-6 py-4 font-medium text-slate-700">
                      {benefit.LoaiGiaTri === 'F' 
                        ? formatMoney(Number(benefit.GiaTri || 0)) 
                        : `${Number(benefit.GiaTri || 0).toFixed(2)}%`}
                    </td>
                    <td className="px-6 py-4 text-center">
                      {benefit.CoTinhThue === 1 ? (
                        <span className="text-rose-600 text-xs font-medium bg-rose-50 px-2 py-1 rounded-full border border-rose-100">Có</span>
                      ) : (
                        <span className="text-emerald-600 text-xs font-medium bg-emerald-50 px-2 py-1 rounded-full border border-emerald-100">Không</span>
                      )}
                    </td>
                    <td className="px-6 py-4 text-center">
                      {benefit.IsActive === 1 ? (
                        <div className="flex items-center justify-center gap-1 text-emerald-600">
                          <CheckCircle className="w-4 h-4" />
                          <span className="text-xs font-medium">Hoạt động</span>
                        </div>
                      ) : (
                        <div className="flex items-center justify-center gap-1 text-slate-400">
                          <XCircle className="w-4 h-4" />
                          <span className="text-xs font-medium">Đã ẩn</span>
                        </div>
                      )}
                    </td>
                    <td className="px-6 py-4 text-right">
                      <div className="flex items-center justify-end gap-2 opacity-0 group-hover:opacity-100 transition-opacity">
                        <Button variant="ghost" size="icon" className="h-8 w-8 text-indigo-600 hover:text-indigo-700 hover:bg-indigo-50" onClick={() => handleEdit(benefit)}>
                          <Edit className="h-4 w-4" />
                        </Button>
                        <Button variant="ghost" size="icon" className="h-8 w-8 text-red-600 hover:text-red-700 hover:bg-red-50" onClick={() => handleDeleteClick(benefit)}>
                          <Trash2 className="h-4 w-4" />
                        </Button>
                      </div>
                    </td>
                  </tr>
                ))
              ) : (
                <tr>
                  <td colSpan={7} className="px-6 py-12 text-center text-slate-500">
                    Không tìm thấy dữ liệu phúc lợi nào phù hợp.
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </div>

      <BenefitFormModal 
        isOpen={isFormOpen} 
        onClose={() => setIsFormOpen(false)} 
        onSubmit={handleFormSubmit} 
        initialData={editingBenefit}
        isSubmitting={createMutation.isPending || updateMutation.isPending}
      />

      <ConfirmDeleteModal 
        isOpen={isDeleteOpen}
        onClose={() => setIsDeleteOpen(false)}
        onConfirm={handleConfirmDelete}
        title="Xóa loại phúc lợi"
        description={`Bạn có chắc chắn muốn xóa loại phúc lợi "${deletingBenefit?.TenFL || deletingBenefit?.name}" không? Hành động này sẽ bị từ chối nếu phúc lợi này đang được gắn cho bất kỳ nhân viên nào.`}
        isSubmitting={deleteMutation.isPending}
      />
    </div>
  );
}
