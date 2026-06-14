"use client";

import React, { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { Briefcase, Plus, Search, Edit, Trash2, Award, Info } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { masterDataService, MasterData } from '@/services/masterData.service';
import { PositionFormModal } from '@/components/positions/PositionFormModal';
import { ConfirmDeleteModal } from '@/components/ui/ConfirmDeleteModal';

export default function PositionsPage() {
  const queryClient = useQueryClient();
  const [searchTerm, setSearchTerm] = useState('');
  
  // Modal states
  const [isFormOpen, setIsFormOpen] = useState(false);
  const [isDeleteOpen, setIsDeleteOpen] = useState(false);
  const [editingPos, setEditingPos] = useState<MasterData | null>(null);
  const [deletingPos, setDeletingPos] = useState<MasterData | null>(null);

  // Fetch positions
  const { data: positionsData, isLoading } = useQuery({
    queryKey: ['positions'],
    queryFn: () => masterDataService.getPositions()
  });

  const positions = positionsData || [];

  // Mutations
  const createMutation = useMutation({
    mutationFn: (data: Partial<MasterData>) => masterDataService.createPosition(data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['positions'] });
      alert('Tạo chức vụ thành công!');
      setIsFormOpen(false);
    },
    onError: (error: any) => {
      alert(error.response?.data?.error || 'Có lỗi xảy ra khi tạo chức vụ');
    }
  });

  const updateMutation = useMutation({
    mutationFn: ({ id, data }: { id: string, data: Partial<MasterData> }) => masterDataService.updatePosition(id, data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['positions'] });
      alert('Cập nhật chức vụ thành công!');
      setIsFormOpen(false);
    },
    onError: (error: any) => {
      alert(error.response?.data?.error || 'Có lỗi xảy ra khi cập nhật');
    }
  });

  const deleteMutation = useMutation({
    mutationFn: (id: string) => masterDataService.deletePosition(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['positions'] });
      alert('Xóa chức vụ thành công!');
      setIsDeleteOpen(false);
      setDeletingPos(null);
    },
    onError: (error: any) => {
      alert(error.response?.data?.error || 'Có lỗi xảy ra khi xóa chức vụ');
    }
  });

  const filteredPositions = positions.filter(p => {
    const term = searchTerm.toLowerCase();
    return (p.TenCV || p.name || '').toLowerCase().includes(term) || 
           (p.MaCV || p.id || '').toLowerCase().includes(term);
  });

  const handleAdd = () => {
    setEditingPos(null);
    setIsFormOpen(true);
  };

  const handleEdit = (pos: MasterData) => {
    setEditingPos(pos);
    setIsFormOpen(true);
  };

  const handleDeleteClick = (pos: MasterData) => {
    setDeletingPos(pos);
    setIsDeleteOpen(true);
  };

  const handleFormSubmit = (data: Partial<MasterData>) => {
    if (editingPos) {
      updateMutation.mutate({ id: editingPos.id, data });
    } else {
      createMutation.mutate(data);
    }
  };

  const handleConfirmDelete = () => {
    if (deletingPos) {
      deleteMutation.mutate(deletingPos.id);
    }
  };

  const getLevelLabel = (level: number | undefined) => {
    switch (level) {
      case 5: return "Cấp 5 - Giám đốc";
      case 4: return "Cấp 4 - Quản lý cấp cao";
      case 3: return "Cấp 3 - Trưởng/Phó phòng";
      case 2: return "Cấp 2 - Chuyên viên";
      case 1: 
      default: return "Cấp 1 - Nhân viên";
    }
  };

  return (
    <div className="space-y-6 animate-in fade-in duration-300">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-slate-900 flex items-center gap-2">
            <Briefcase className="h-6 w-6 text-indigo-600" />
            Cấu hình Chức vụ
          </h1>
          <p className="text-sm text-slate-500 mt-1">
            Quản lý danh sách chức danh, cấp bậc và hệ số lương cơ bản.
          </p>
        </div>
        <div className="flex items-center gap-3">
          <Button onClick={handleAdd}>
            <Plus className="h-4 w-4 mr-2" />
            Thêm chức vụ mới
          </Button>
        </div>
      </div>

      <div className="bg-white rounded-xl shadow-sm border border-slate-200 p-4 mb-6 flex flex-col md:flex-row gap-4">
        <div className="relative flex-1 w-full md:max-w-md">
          <Search className="absolute left-3 top-2.5 h-4 w-4 text-slate-400" />
          <Input 
            placeholder="Tìm kiếm theo mã hoặc tên chức vụ..." 
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
      ) : filteredPositions.length > 0 ? (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {filteredPositions.map((pos) => (
            <div key={pos.id} className="bg-white rounded-xl border border-slate-200 shadow-sm hover:shadow-md transition-shadow overflow-hidden flex flex-col relative group">
              <div className="absolute top-0 right-0 w-24 h-24 bg-gradient-to-br from-indigo-50/50 to-transparent -mr-8 -mt-8 rounded-full z-0 pointer-events-none group-hover:scale-110 transition-transform"></div>
              
              <div className="p-5 border-b border-slate-100 flex items-start justify-between bg-white z-10 relative">
                <div>
                  <div className="flex items-center gap-2 mb-1">
                    <h3 className="font-bold text-lg text-slate-800">{pos.name || pos.TenCV}</h3>
                  </div>
                  <div className="flex items-center gap-2">
                    <span className="inline-block px-2 py-0.5 bg-slate-100 text-slate-700 text-xs font-semibold rounded font-mono">
                      {pos.id || pos.MaCV}
                    </span>
                    {pos.IsActive === 0 && (
                      <span className="px-2 py-0.5 bg-red-100 text-red-700 text-[10px] uppercase font-bold rounded">Đã khóa</span>
                    )}
                  </div>
                </div>
                <div className="flex gap-1 opacity-0 group-hover:opacity-100 transition-opacity">
                  <button 
                    onClick={() => handleEdit(pos)}
                    className="p-1.5 text-slate-400 hover:text-indigo-600 hover:bg-indigo-50 rounded transition-colors"
                    title="Chỉnh sửa"
                  >
                    <Edit className="w-4 h-4" />
                  </button>
                  <button 
                    onClick={() => handleDeleteClick(pos)}
                    className="p-1.5 text-slate-400 hover:text-red-600 hover:bg-red-50 rounded transition-colors"
                    title="Xóa"
                  >
                    <Trash2 className="w-4 h-4" />
                  </button>
                </div>
              </div>
              
              <div className="p-5 space-y-4 flex-grow z-10 relative bg-slate-50/30">
                <div className="flex items-center justify-between border-b border-slate-100 pb-3">
                  <div className="flex items-center gap-2 text-sm text-slate-600">
                    <Award className="w-4 h-4 text-amber-500" />
                    <span>Cấp bậc:</span>
                  </div>
                  <span className="font-semibold text-slate-800 text-sm">{getLevelLabel(pos.CapBac)}</span>
                </div>
                
                <div className="flex items-center justify-between border-b border-slate-100 pb-3">
                  <div className="flex items-center gap-2 text-sm text-slate-600">
                    <div className="w-4 h-4 rounded-full bg-emerald-100 text-emerald-600 flex items-center justify-center font-bold text-[10px]">
                      x
                    </div>
                    <span>Hệ số lương:</span>
                  </div>
                  <span className="font-bold text-emerald-600">{Number(pos.HeSoLuong).toFixed(2)}</span>
                </div>

                {pos.MoTa && (
                  <div className="pt-1">
                    <div className="flex items-start gap-2 text-sm text-slate-600">
                      <Info className="w-4 h-4 text-slate-400 mt-0.5 flex-shrink-0" />
                      <p className="line-clamp-2 italic text-xs">{pos.MoTa}</p>
                    </div>
                  </div>
                )}
              </div>
            </div>
          ))}
        </div>
      ) : (
        <div className="bg-white rounded-xl border border-dashed border-slate-300 p-12 text-center">
          <Briefcase className="w-12 h-12 text-slate-300 mx-auto mb-4" />
          <h3 className="text-lg font-medium text-slate-900 mb-1">Không có dữ liệu</h3>
          <p className="text-slate-500 mb-4">Không tìm thấy chức vụ nào phù hợp với tìm kiếm của bạn.</p>
          <Button onClick={handleAdd} variant="outline">Tạo chức vụ mới ngay</Button>
        </div>
      )}

      <PositionFormModal 
        isOpen={isFormOpen} 
        onClose={() => setIsFormOpen(false)} 
        onSubmit={handleFormSubmit} 
        initialData={editingPos} 
      />

      <ConfirmDeleteModal 
        isOpen={isDeleteOpen}
        onClose={() => setIsDeleteOpen(false)}
        onConfirm={handleConfirmDelete}
        title="Xóa chức vụ"
        description={`Bạn có chắc chắn muốn xóa chức vụ "${deletingPos?.TenCV || deletingPos?.name}" không? Thao tác này chỉ thực hiện được nếu không có nhân viên nào đang giữ chức vụ này.`}
      />
    </div>
  );
}
