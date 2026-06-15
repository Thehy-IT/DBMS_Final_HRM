"use client";

import React, { useState, useEffect } from 'react';
import { useSearchParams, useRouter } from 'next/navigation';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { Building2, Plus, Search, Edit, Trash2, MapPin, Mail, Phone, Users as UsersIcon } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { masterDataService, MasterData } from '@/services/masterData.service';
import { employeeService } from '@/services/employee.service';
import { DepartmentFormModal } from '@/components/departments/DepartmentFormModal';
import { ConfirmDeleteModal } from '@/components/ui/ConfirmDeleteModal';

export default function DepartmentsPage() {
  const queryClient = useQueryClient();
  const searchParams = useSearchParams();
  const router = useRouter();
  const [searchTerm, setSearchTerm] = useState('');
  
  // Modal states
  const [isFormOpen, setIsFormOpen] = useState(false);
  const [isDeleteOpen, setIsDeleteOpen] = useState(false);
  const [editingDept, setEditingDept] = useState<MasterData | null>(null);
  const [deletingDept, setDeletingDept] = useState<MasterData | null>(null);

  useEffect(() => {
    if (searchParams.get('action') === 'new') {
      setEditingDept(null);
      setIsFormOpen(true);
      router.replace('/departments');
    }
  }, [searchParams, router]);

  // Fetch departments
  const { data: deptsData, isLoading } = useQuery({
    queryKey: ['departments'],
    queryFn: () => masterDataService.getDepartments()
  });

  // Fetch employees for "Trưởng phòng" dropdown
  const { data: employeesData } = useQuery({
    queryKey: ['employees'],
    queryFn: () => employeeService.getEmployees()
  });

  const departments = deptsData || [];
  const employees = employeesData?.data || [];

  // Mutations
  const createMutation = useMutation({
    mutationFn: (data: Partial<MasterData>) => masterDataService.createDepartment(data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['departments'] });
      alert('Tạo phòng ban thành công!');
      setIsFormOpen(false);
    },
    onError: (error: any) => {
      alert(error.response?.data?.error || 'Có lỗi xảy ra khi tạo phòng ban');
    }
  });

  const updateMutation = useMutation({
    mutationFn: ({ id, data }: { id: string, data: Partial<MasterData> }) => masterDataService.updateDepartment(id, data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['departments'] });
      alert('Cập nhật phòng ban thành công!');
      setIsFormOpen(false);
    },
    onError: (error: any) => {
      alert(error.response?.data?.error || 'Có lỗi xảy ra khi cập nhật');
    }
  });

  const deleteMutation = useMutation({
    mutationFn: (id: string) => masterDataService.deleteDepartment(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['departments'] });
      alert('Xóa phòng ban thành công!');
      setIsDeleteOpen(false);
      setDeletingDept(null);
    },
    onError: (error: any) => {
      alert(error.response?.data?.error || 'Có lỗi xảy ra khi xóa phòng ban');
    }
  });

  const filteredDepts = departments.filter(d => {
    const term = searchTerm.toLowerCase();
    return (d.TenPB || d.name || '').toLowerCase().includes(term) || 
           (d.MaPB || d.id || '').toLowerCase().includes(term);
  });

  const handleAdd = () => {
    setEditingDept(null);
    setIsFormOpen(true);
  };

  const handleEdit = (dept: MasterData) => {
    setEditingDept(dept);
    setIsFormOpen(true);
  };

  const handleDeleteClick = (dept: MasterData) => {
    setDeletingDept(dept);
    setIsDeleteOpen(true);
  };

  const handleFormSubmit = (data: Partial<MasterData>) => {
    if (editingDept) {
      updateMutation.mutate({ id: editingDept.id, data });
    } else {
      createMutation.mutate(data);
    }
  };

  const handleConfirmDelete = () => {
    if (deletingDept) {
      deleteMutation.mutate(deletingDept.id);
    }
  };

  const getEmpName = (empId: string) => {
    const emp = employees.find(e => e.MaNV === empId);
    return emp ? emp.HoTen : empId;
  };

  return (
    <div className="space-y-6 animate-in fade-in duration-300">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-slate-900 flex items-center gap-2">
            <Building2 className="h-6 w-6 text-indigo-600" />
            Cấu hình Phòng ban
          </h1>
          <p className="text-sm text-slate-500 mt-1">
            Quản lý cơ cấu tổ chức và các phòng ban trong công ty.
          </p>
        </div>
        <div className="flex items-center gap-3">
          <Button onClick={handleAdd}>
            <Plus className="h-4 w-4 mr-2" />
            Thêm phòng ban mới
          </Button>
        </div>
      </div>

      <div className="bg-white rounded-xl shadow-sm border border-slate-200 p-4 mb-6 flex flex-col md:flex-row gap-4">
        <div className="relative flex-1 w-full md:max-w-md">
          <Search className="absolute left-3 top-2.5 h-4 w-4 text-slate-400" />
          <Input 
            placeholder="Tìm kiếm theo mã hoặc tên phòng ban..." 
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
      ) : filteredDepts.length > 0 ? (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {filteredDepts.map((dept) => (
            <div key={dept.id} className="bg-white rounded-xl border border-slate-200 shadow-sm hover:shadow-md transition-shadow overflow-hidden flex flex-col">
              <div className="p-5 border-b border-slate-100 flex items-start justify-between bg-slate-50/50">
                <div>
                  <div className="flex items-center gap-2 mb-1">
                    <h3 className="font-bold text-lg text-slate-800">{dept.name || dept.TenPB}</h3>
                    {dept.IsActive === 0 && (
                      <span className="px-2 py-0.5 bg-slate-200 text-slate-600 text-[10px] uppercase font-bold rounded">Ngừng HĐ</span>
                    )}
                  </div>
                  <span className="inline-block px-2 py-1 bg-indigo-100 text-indigo-700 text-xs font-semibold rounded">
                    Mã: {dept.id || dept.MaPB}
                  </span>
                </div>
                <div className="flex gap-1">
                  <button 
                    onClick={() => handleEdit(dept)}
                    className="p-1.5 text-slate-400 hover:text-indigo-600 hover:bg-indigo-50 rounded transition-colors"
                    title="Chỉnh sửa"
                  >
                    <Edit className="w-4 h-4" />
                  </button>
                  <button 
                    onClick={() => handleDeleteClick(dept)}
                    className="p-1.5 text-slate-400 hover:text-red-600 hover:bg-red-50 rounded transition-colors"
                    title="Xóa"
                  >
                    <Trash2 className="w-4 h-4" />
                  </button>
                </div>
              </div>
              
              <div className="p-5 space-y-3 flex-grow">
                {dept.MaTruongPhong ? (
                  <div className="flex items-center gap-3 text-sm">
                    <div className="w-8 h-8 rounded-full bg-indigo-100 text-indigo-600 flex items-center justify-center font-bold">
                      <UsersIcon className="w-4 h-4" />
                    </div>
                    <div>
                      <p className="text-xs text-slate-500">Trưởng phòng</p>
                      <p className="font-medium text-slate-800">{getEmpName(dept.MaTruongPhong)}</p>
                    </div>
                  </div>
                ) : (
                  <div className="flex items-center gap-3 text-sm opacity-60">
                    <div className="w-8 h-8 rounded-full bg-slate-100 text-slate-400 flex items-center justify-center font-bold">
                      <UsersIcon className="w-4 h-4" />
                    </div>
                    <div>
                      <p className="text-xs text-slate-500">Trưởng phòng</p>
                      <p className="font-medium text-slate-600 italic">Chưa bổ nhiệm</p>
                    </div>
                  </div>
                )}
                
                <div className="pt-2 space-y-2">
                  {dept.DiaDiem && (
                    <div className="flex items-start gap-2 text-sm text-slate-600">
                      <MapPin className="w-4 h-4 text-slate-400 mt-0.5" />
                      <span>{dept.DiaDiem}</span>
                    </div>
                  )}
                  {dept.Email && (
                    <div className="flex items-start gap-2 text-sm text-slate-600">
                      <Mail className="w-4 h-4 text-slate-400 mt-0.5" />
                      <span>{dept.Email}</span>
                    </div>
                  )}
                  {dept.DienThoai && (
                    <div className="flex items-start gap-2 text-sm text-slate-600">
                      <Phone className="w-4 h-4 text-slate-400 mt-0.5" />
                      <span>{dept.DienThoai}</span>
                    </div>
                  )}
                </div>
              </div>
            </div>
          ))}
        </div>
      ) : (
        <div className="bg-white rounded-xl border border-dashed border-slate-300 p-12 text-center">
          <Building2 className="w-12 h-12 text-slate-300 mx-auto mb-4" />
          <h3 className="text-lg font-medium text-slate-900 mb-1">Không có dữ liệu</h3>
          <p className="text-slate-500 mb-4">Không tìm thấy phòng ban nào phù hợp với tìm kiếm của bạn.</p>
          <Button onClick={handleAdd} variant="outline">Tạo phòng ban mới ngay</Button>
        </div>
      )}

      <DepartmentFormModal 
        isOpen={isFormOpen} 
        onClose={() => setIsFormOpen(false)} 
        onSubmit={handleFormSubmit} 
        initialData={editingDept} 
        employees={employees}
      />

      <ConfirmDeleteModal 
        isOpen={isDeleteOpen}
        onClose={() => setIsDeleteOpen(false)}
        onConfirm={handleConfirmDelete}
        title="Xóa phòng ban"
        description={`Bạn có chắc chắn muốn xóa phòng ban "${deletingDept?.TenPB || deletingDept?.name}" không? Thao tác này không thể hoàn tác và chỉ thực hiện được nếu phòng ban chưa có nhân viên nào.`}
      />
    </div>
  );
}
