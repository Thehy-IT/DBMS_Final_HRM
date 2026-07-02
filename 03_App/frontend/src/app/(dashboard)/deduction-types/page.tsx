"use client";

import React, { useState, useEffect } from 'react';
import { useSearchParams, useRouter } from 'next/navigation';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { Receipt, Plus, Search, Edit, Trash2, CheckCircle, XCircle } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { masterDataService, MasterData } from '@/services/masterData.service';
import { ConfirmDeleteModal } from '@/components/ui/ConfirmDeleteModal';

function DeductionTypeFormModal({ isOpen, onClose, onSubmit, initialData, isSubmitting = false }: { isOpen: boolean, onClose: () => void, onSubmit: (data: any) => void, initialData: any, isSubmitting?: boolean }) {
  const [formData, setFormData] = useState<Partial<MasterData>>({
    MaLKT: '',
    TenLKT: '',
    MoTa: '',
    IsActive: 1
  });

  useEffect(() => {
    if (initialData) {
      setFormData(initialData);
    } else {
      setFormData({
        MaLKT: '',
        TenLKT: '',
        MoTa: '',
        IsActive: 1
      });
    }
  }, [initialData, isOpen]);

  if (!isOpen) return null;

  const handleClose = () => {
    if (isSubmitting) return;
    onClose();
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4">
      <div className="fixed inset-0" onClick={handleClose}></div>
      <div className="bg-white rounded-xl shadow-lg w-full max-w-md overflow-hidden flex flex-col relative z-10">
        <div className="px-6 py-4 border-b border-slate-200">
          <h2 className="text-xl font-bold text-slate-900">
            {initialData ? 'Cập nhật Loại Khấu Trừ' : 'Thêm mới Loại Khấu Trừ'}
          </h2>
        </div>
        <div className="p-6 space-y-4 flex-1 overflow-y-auto">
          <div>
            <label className="text-sm font-semibold text-slate-700 mb-1 block">Mã loại (*)</label>
            <Input 
              disabled={!!initialData}
              placeholder="VD: KT0001" 
              value={formData.MaLKT || ''} 
              onChange={(e) => setFormData({...formData, MaLKT: e.target.value})} 
            />
          </div>
          <div>
            <label className="text-sm font-semibold text-slate-700 mb-1 block">Tên loại khấu trừ (*)</label>
            <Input 
              placeholder="VD: Phạt đi trễ..." 
              value={formData.TenLKT || ''} 
              onChange={(e) => setFormData({...formData, TenLKT: e.target.value})} 
            />
          </div>
          <div>
            <label className="text-sm font-semibold text-slate-700 mb-1 block">Mô tả chi tiết</label>
            <Input 
              placeholder="Giải thích..." 
              value={formData.MoTa || formData.GhiChu || ''} 
              onChange={(e) => setFormData({...formData, MoTa: e.target.value})} 
            />
          </div>
          <div className="flex items-center gap-2 mt-4">
            <input 
              type="checkbox" 
              id="isActive" 
              checked={formData.IsActive === 1}
              onChange={(e) => setFormData({...formData, IsActive: e.target.checked ? 1 : 0})}
              className="w-4 h-4 text-rose-600 rounded border-slate-300 focus:ring-rose-500"
            />
            <label htmlFor="isActive" className="text-sm font-medium text-slate-700 cursor-pointer">
              Đang hoạt động (Áp dụng được)
            </label>
          </div>
        </div>
        <div className="px-6 py-4 bg-slate-50 border-t border-slate-200 flex justify-end gap-3">
          <Button variant="outline" onClick={handleClose} disabled={isSubmitting}>Hủy Bỏ</Button>
          <Button className="bg-rose-600 hover:bg-rose-700" onClick={() => onSubmit(formData)} disabled={isSubmitting}>
            {isSubmitting ? (initialData ? 'Đang cập nhật...' : 'Đang tạo...') : (initialData ? 'Cập nhật' : 'Tạo mới')}
          </Button>
        </div>
      </div>
    </div>
  );
}

export default function DeductionTypesPage() {
  const searchParams = useSearchParams();
  const router = useRouter();
  const queryClient = useQueryClient();

  const [searchTerm, setSearchTerm] = useState('');
  
  // Modal states
  const [isFormOpen, setIsFormOpen] = useState(false);
  const [isDeleteOpen, setIsDeleteOpen] = useState(false);
  const [editingType, setEditingType] = useState<MasterData | null>(null);
  const [deletingType, setDeletingType] = useState<MasterData | null>(null);

  const [filterStatus, setFilterStatus] = useState('ALL'); // ALL, 1, 0

  useEffect(() => {
    if (searchParams.get('action') === 'new') {
      setIsFormOpen(true);
      router.replace('/deduction-types', { scroll: false });
    }
  }, [searchParams, router]);

  // Fetch data
  const { data: typesData, isLoading } = useQuery({
    queryKey: ['deduction-types'],
    queryFn: () => masterDataService.getDeductionTypes()
  });

  const types = typesData || [];

  // Mutations
  const createMutation = useMutation({
    mutationFn: (data: Partial<MasterData>) => masterDataService.createDeductionType(data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['deduction-types'] });
      alert('Tạo loại khấu trừ thành công!');
      setIsFormOpen(false);
    },
    onError: (error: any) => {
      alert(error.response?.data?.error || 'Có lỗi xảy ra khi tạo');
    }
  });

  const updateMutation = useMutation({
    mutationFn: ({ id, data }: { id: string, data: Partial<MasterData> }) => masterDataService.updateDeductionType(id, data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['deduction-types'] });
      alert('Cập nhật loại khấu trừ thành công!');
      setIsFormOpen(false);
    },
    onError: (error: any) => {
      alert(error.response?.data?.error || 'Có lỗi xảy ra khi cập nhật');
    }
  });

  const deleteMutation = useMutation({
    mutationFn: (id: string) => masterDataService.deleteDeductionType(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['deduction-types'] });
      alert('Xóa loại khấu trừ thành công!');
      setIsDeleteOpen(false);
      setDeletingType(null);
    },
    onError: (error: any) => {
      alert(error.response?.data?.error || 'Có lỗi xảy ra khi xóa');
    }
  });

  const filteredTypes = types.filter(t => {
    const matchesSearch = (t.TenLKT || t.name || '').toLowerCase().includes(searchTerm.toLowerCase()) || 
                          (t.MaLKT || t.id || '').toLowerCase().includes(searchTerm.toLowerCase());
    const matchesStatus = filterStatus === 'ALL' || String(t.IsActive) === filterStatus;

    return matchesSearch && matchesStatus;
  });

  const handleAdd = () => {
    setEditingType(null);
    setIsFormOpen(true);
  };

  const handleEdit = (type: MasterData) => {
    setEditingType(type);
    setIsFormOpen(true);
  };

  const handleDeleteClick = (type: MasterData) => {
    setDeletingType(type);
    setIsDeleteOpen(true);
  };

  const handleFormSubmit = (data: Partial<MasterData>) => {
    if (!data.MaLKT || !data.TenLKT) {
      alert("Vui lòng điền đầy đủ Mã loại và Tên loại!");
      return;
    }
    if (editingType) {
      updateMutation.mutate({ id: editingType.id, data });
    } else {
      createMutation.mutate(data);
    }
  };

  const handleConfirmDelete = () => {
    if (deletingType) {
      deleteMutation.mutate(deletingType.id);
    }
  };

  return (
    <div className="space-y-6 animate-in fade-in duration-300">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-slate-900 flex items-center gap-2">
            <Receipt className="h-6 w-6 text-rose-600" />
            Cấu hình Loại khấu trừ
          </h1>
          <p className="text-sm text-slate-500 mt-1">
            Thiết lập các danh mục phạt vi phạm, truy thu, tạm ứng...
          </p>
        </div>
        <div className="flex items-center gap-3">
          <Button onClick={handleAdd} className="bg-rose-600 hover:bg-rose-700">
            <Plus className="h-4 w-4 mr-2" />
            Thêm loại khấu trừ
          </Button>
        </div>
      </div>

      <div className="bg-white rounded-xl shadow-sm border border-slate-200 overflow-hidden">
        <div className="p-4 border-b border-slate-200 flex flex-col md:flex-row items-center gap-4 bg-slate-50/50">
          <div className="relative flex-1 w-full md:max-w-md">
            <Search className="absolute left-3 top-2.5 h-4 w-4 text-slate-400" />
            <Input 
              placeholder="Tìm kiếm theo mã, tên..." 
              className="pl-9 bg-white"
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
            />
          </div>
          <div className="flex items-center gap-3 w-full md:w-auto">
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
                <th className="px-6 py-4 font-medium w-32">Mã LKT</th>
                <th className="px-6 py-4 font-medium">Tên Khấu Trừ</th>
                <th className="px-6 py-4 font-medium text-center w-32">Trạng Thái</th>
                <th className="px-6 py-4 font-medium text-right w-32">Thao Tác</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {isLoading ? (
                <tr>
                  <td colSpan={4} className="px-6 py-12 text-center text-slate-500">
                    <div className="flex justify-center items-center">
                       <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-rose-600"></div>
                    </div>
                  </td>
                </tr>
              ) : filteredTypes.length > 0 ? (
                filteredTypes.map((type) => (
                  <tr key={type.id} className="hover:bg-slate-50/80 transition-colors group">
                    <td className="px-6 py-4 font-medium text-rose-600">
                      {type.MaLKT || type.id}
                    </td>
                    <td className="px-6 py-4">
                      <p className="font-medium text-slate-900">{type.TenLKT || type.name}</p>
                      <p className="text-xs text-slate-500 mt-0.5 max-w-sm truncate" title={type.MoTa}>
                        {type.MoTa}
                      </p>
                    </td>
                    <td className="px-6 py-4 text-center">
                      {type.IsActive === 1 ? (
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
                        <Button variant="ghost" size="icon" className="h-8 w-8 text-rose-600 hover:text-rose-700 hover:bg-rose-50" onClick={() => handleEdit(type)}>
                          <Edit className="h-4 w-4" />
                        </Button>
                        <Button variant="ghost" size="icon" className="h-8 w-8 text-red-600 hover:text-red-700 hover:bg-red-50" onClick={() => handleDeleteClick(type)}>
                          <Trash2 className="h-4 w-4" />
                        </Button>
                      </div>
                    </td>
                  </tr>
                ))
              ) : (
                <tr>
                  <td colSpan={4} className="px-6 py-12 text-center text-slate-500">
                    Không tìm thấy dữ liệu nào phù hợp.
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </div>

      <DeductionTypeFormModal 
        isOpen={isFormOpen} 
        onClose={() => setIsFormOpen(false)} 
        onSubmit={handleFormSubmit} 
        initialData={editingType}
        isSubmitting={createMutation.isPending || updateMutation.isPending}
      />

      <ConfirmDeleteModal 
        isOpen={isDeleteOpen}
        onClose={() => setIsDeleteOpen(false)}
        onConfirm={handleConfirmDelete}
        title="Xóa danh mục khấu trừ"
        description={`Bạn có chắc chắn muốn xóa loại khấu trừ "${deletingType?.TenLKT || deletingType?.name}" không? Hành động này sẽ bị từ chối nếu nó đang được áp dụng cho bất kỳ nhân viên nào.`}
        isSubmitting={deleteMutation.isPending}
      />
    </div>
  );
}
