"use client";

import React, { useState, useEffect } from 'react';
import { useSearchParams, useRouter } from 'next/navigation';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { FileSignature, Plus, Search, Edit, Trash2, Clock, Percent, Info } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { masterDataService, MasterData } from '@/services/masterData.service';
import { ContractTypeFormModal } from '@/components/contracts/ContractTypeFormModal';
import { ConfirmDeleteModal } from '@/components/ui/ConfirmDeleteModal';

export default function ContractTypesPage() {
  const queryClient = useQueryClient();
  const searchParams = useSearchParams();
  const router = useRouter();
  const [searchTerm, setSearchTerm] = useState('');
  
  // Modal states
  const [isFormOpen, setIsFormOpen] = useState(false);
  const [isDeleteOpen, setIsDeleteOpen] = useState(false);
  const [editingType, setEditingType] = useState<MasterData | null>(null);
  const [deletingType, setDeletingType] = useState<MasterData | null>(null);

  useEffect(() => {
    if (searchParams.get('action') === 'new') {
      setEditingType(null);
      setIsFormOpen(true);
      router.replace('/contract-types');
    }
  }, [searchParams, router]);

  // Fetch contract types
  const { data: typesData, isLoading } = useQuery({
    queryKey: ['contract-types'],
    queryFn: () => masterDataService.getContractTypes()
  });

  const contractTypes = typesData || [];

  // Mutations
  const createMutation = useMutation({
    mutationFn: (data: Partial<MasterData>) => masterDataService.createContractType(data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['contract-types'] });
      alert('Tạo loại hợp đồng thành công!');
      setIsFormOpen(false);
    },
    onError: (error: any) => {
      alert(error.response?.data?.error || 'Có lỗi xảy ra khi tạo loại hợp đồng');
    }
  });

  const updateMutation = useMutation({
    mutationFn: ({ id, data }: { id: string, data: Partial<MasterData> }) => masterDataService.updateContractType(id, data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['contract-types'] });
      alert('Cập nhật loại hợp đồng thành công!');
      setIsFormOpen(false);
    },
    onError: (error: any) => {
      alert(error.response?.data?.error || 'Có lỗi xảy ra khi cập nhật');
    }
  });

  const deleteMutation = useMutation({
    mutationFn: (id: string) => masterDataService.deleteContractType(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['contract-types'] });
      alert('Xóa loại hợp đồng thành công!');
      setIsDeleteOpen(false);
      setDeletingType(null);
    },
    onError: (error: any) => {
      alert(error.response?.data?.error || 'Có lỗi xảy ra khi xóa loại hợp đồng');
    }
  });

  const filteredTypes = contractTypes.filter(t => {
    const term = searchTerm.toLowerCase();
    return (t.TenLoaiHD || t.name || '').toLowerCase().includes(term);
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
            <FileSignature className="h-6 w-6 text-indigo-600" />
            Cấu hình Loại hợp đồng
          </h1>
          <p className="text-sm text-slate-500 mt-1">
            Quản lý các mẫu hợp đồng lao động, thời hạn và quy định đóng BHXH.
          </p>
        </div>
        <div className="flex items-center gap-3">
          <Button onClick={handleAdd}>
            <Plus className="h-4 w-4 mr-2" />
            Thêm loại hợp đồng mới
          </Button>
        </div>
      </div>

      <div className="bg-white rounded-xl shadow-sm border border-slate-200 p-4 mb-6 flex flex-col md:flex-row gap-4">
        <div className="relative flex-1 w-full md:max-w-md">
          <Search className="absolute left-3 top-2.5 h-4 w-4 text-slate-400" />
          <Input 
            placeholder="Tìm kiếm theo tên loại hợp đồng..." 
            className="pl-9 bg-slate-50"
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
          />
        </div>
      </div>

      {isLoading ? (
        <div className="flex justify-center items-center py-20">
          <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-indigo-600"></div>
        </div>
      ) : filteredTypes.length > 0 ? (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {filteredTypes.map((type) => (
            <div key={type.id} className="bg-white rounded-xl border border-slate-200 shadow-sm hover:shadow-md transition-shadow overflow-hidden flex flex-col group">
              <div className="p-5 border-b border-slate-100 flex items-start justify-between bg-gradient-to-r from-slate-50 to-white">
                <div>
                  <h3 className="font-bold text-lg text-slate-800 pr-4">{type.name || type.TenLoaiHD}</h3>
                </div>
                <div className="flex gap-1 opacity-0 group-hover:opacity-100 transition-opacity flex-shrink-0">
                  <button 
                    onClick={() => handleEdit(type)}
                    className="p-1.5 text-slate-400 hover:text-indigo-600 hover:bg-indigo-50 rounded transition-colors"
                    title="Chỉnh sửa"
                  >
                    <Edit className="w-4 h-4" />
                  </button>
                  <button 
                    onClick={() => handleDeleteClick(type)}
                    className="p-1.5 text-slate-400 hover:text-red-600 hover:bg-red-50 rounded transition-colors"
                    title="Xóa"
                  >
                    <Trash2 className="w-4 h-4" />
                  </button>
                </div>
              </div>
              
              <div className="p-5 space-y-4 flex-grow">
                <div className="grid grid-cols-2 gap-4">
                  <div className="bg-slate-50 rounded-lg p-3 border border-slate-100">
                    <div className="flex items-center gap-1.5 text-xs text-slate-500 mb-1 font-medium">
                      <Clock className="w-3.5 h-3.5" />
                      Thời hạn
                    </div>
                    <div className="font-semibold text-slate-800 text-sm">
                      {type.ThoiHanToiDa ? `${type.ThoiHanToiDa} tháng` : 'Vô thời hạn'}
                    </div>
                  </div>

                  <div className="bg-slate-50 rounded-lg p-3 border border-slate-100">
                    <div className="flex items-center gap-1.5 text-xs text-slate-500 mb-1 font-medium">
                      <Percent className="w-3.5 h-3.5" />
                      NLĐ đóng BHXH
                    </div>
                    <div className="font-bold text-indigo-600 text-sm">
                      {type.TiLeBHXH !== undefined ? Number(type.TiLeBHXH).toFixed(2) : '0.00'}%
                    </div>
                  </div>
                </div>

                {type.MoTa && (
                  <div className="pt-2 border-t border-slate-100">
                    <div className="flex items-start gap-2 text-sm text-slate-600">
                      <Info className="w-4 h-4 text-slate-400 mt-0.5 flex-shrink-0" />
                      <p className="line-clamp-2 italic text-xs">{type.MoTa}</p>
                    </div>
                  </div>
                )}
              </div>
            </div>
          ))}
        </div>
      ) : (
        <div className="bg-white rounded-xl border border-dashed border-slate-300 p-12 text-center">
          <FileSignature className="w-12 h-12 text-slate-300 mx-auto mb-4" />
          <h3 className="text-lg font-medium text-slate-900 mb-1">Không có dữ liệu</h3>
          <p className="text-slate-500 mb-4">Không tìm thấy loại hợp đồng nào phù hợp với tìm kiếm của bạn.</p>
          <Button onClick={handleAdd} variant="outline">Tạo loại hợp đồng mới ngay</Button>
        </div>
      )}

      <ContractTypeFormModal 
        isOpen={isFormOpen} 
        onClose={() => setIsFormOpen(false)} 
        onSubmit={handleFormSubmit} 
        initialData={editingType} 
      />

      <ConfirmDeleteModal 
        isOpen={isDeleteOpen}
        onClose={() => setIsDeleteOpen(false)}
        onConfirm={handleConfirmDelete}
        title="Xóa loại hợp đồng"
        description={`Bạn có chắc chắn muốn xóa loại hợp đồng "${deletingType?.TenLoaiHD || deletingType?.name}" không? Thao tác này chỉ thực hiện được nếu không có nhân viên nào đang ký loại hợp đồng này.`}
      />
    </div>
  );
}
