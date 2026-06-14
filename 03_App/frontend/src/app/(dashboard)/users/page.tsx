"use client";

import React, { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { UserCog, Plus, Search, Filter, Edit, Trash2, CheckCircle, XCircle, Shield, User as UserIcon } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { userService, User } from '@/services/user.service';
import { employeeService } from '@/services/employee.service';
import { UserFormModal } from '@/components/users/UserFormModal';
import { ConfirmDeleteModal } from '@/components/ui/ConfirmDeleteModal';

export default function UsersPage() {
  const queryClient = useQueryClient();
  const [searchTerm, setSearchTerm] = useState('');
  const [filterRole, setFilterRole] = useState('ALL');
  
  // Modal states
  const [isFormOpen, setIsFormOpen] = useState(false);
  const [isDeleteOpen, setIsDeleteOpen] = useState(false);
  const [editingUser, setEditingUser] = useState<User | null>(null);
  const [deletingUser, setDeletingUser] = useState<User | null>(null);

  // Fetch users
  const { data: usersResponse, isLoading } = useQuery({
    queryKey: ['users'],
    queryFn: () => userService.getUsers()
  });

  // Fetch employees for linking
  const { data: employeesResponse } = useQuery({
    queryKey: ['employees'],
    queryFn: () => employeeService.getEmployees()
  });

  const users = usersResponse?.data || [];
  const employees = employeesResponse?.data || [];

  // Mutations
  const createMutation = useMutation({
    mutationFn: (data: Partial<User> & { MatKhau: string }) => userService.createUser(data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['users'] });
      alert('Tạo tài khoản thành công!');
      setIsFormOpen(false);
    },
    onError: (error: any) => {
      alert(error.response?.data?.error || 'Có lỗi xảy ra khi tạo tài khoản');
    }
  });

  const updateMutation = useMutation({
    mutationFn: ({ id, data }: { id: number, data: Partial<User> & { MatKhau?: string } }) => userService.updateUser(id, data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['users'] });
      alert('Cập nhật tài khoản thành công!');
      setIsFormOpen(false);
    },
    onError: (error: any) => {
      alert(error.response?.data?.error || 'Có lỗi xảy ra khi cập nhật');
    }
  });

  const deleteMutation = useMutation({
    mutationFn: (id: number) => userService.deleteUser(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['users'] });
      alert('Xóa tài khoản thành công!');
      setIsDeleteOpen(false);
      setDeletingUser(null);
    },
    onError: (error: any) => {
      alert(error.response?.data?.error || 'Có lỗi xảy ra khi xóa tài khoản');
    }
  });

  const filteredUsers = users.filter(u => {
    const matchesSearch = u.TenDangNhap.toLowerCase().includes(searchTerm.toLowerCase()) || 
                          (u.HoTen && u.HoTen.toLowerCase().includes(searchTerm.toLowerCase()));
    
    const matchesRole = filterRole === 'ALL' || u.Quyen === filterRole;

    return matchesSearch && matchesRole;
  });

  const handleAdd = () => {
    setEditingUser(null);
    setIsFormOpen(true);
  };

  const handleEdit = (user: User) => {
    setEditingUser(user);
    setIsFormOpen(true);
  };

  const handleDeleteClick = (user: User) => {
    setDeletingUser(user);
    setIsDeleteOpen(true);
  };

  const handleFormSubmit = (data: Partial<User> & { MatKhau?: string }) => {
    if (editingUser) {
      updateMutation.mutate({ id: editingUser.MaTK, data });
    } else {
      createMutation.mutate(data as any);
    }
  };

  const handleConfirmDelete = () => {
    if (deletingUser) {
      deleteMutation.mutate(deletingUser.MaTK);
    }
  };

  const getRoleBadge = (role: string) => {
    switch (role) {
      case 'ADMIN': return <span className="bg-purple-100 text-purple-700 px-2 py-1 rounded text-xs font-medium">ADMIN</span>;
      case 'HR': return <span className="bg-blue-100 text-blue-700 px-2 py-1 rounded text-xs font-medium">HR</span>;
      case 'DIRECTOR': return <span className="bg-amber-100 text-amber-700 px-2 py-1 rounded text-xs font-medium">DIRECTOR</span>;
      case 'ACCOUNTANT': return <span className="bg-cyan-100 text-cyan-700 px-2 py-1 rounded text-xs font-medium">ACCOUNTANT</span>;
      default: return <span className="bg-slate-100 text-slate-700 px-2 py-1 rounded text-xs font-medium">EMPLOYEE</span>;
    }
  };

  return (
    <div className="space-y-6 animate-in fade-in duration-300">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-slate-900 flex items-center gap-2">
            <UserCog className="h-6 w-6 text-indigo-600" />
            Quản lý tài khoản
          </h1>
          <p className="text-sm text-slate-500 mt-1">
            Quản lý người dùng, phân quyền truy cập hệ thống.
          </p>
        </div>
        <div className="flex items-center gap-3">
          <Button onClick={handleAdd}>
            <Plus className="h-4 w-4 mr-2" />
            Tạo tài khoản mới
          </Button>
        </div>
      </div>

      <div className="bg-white rounded-xl shadow-sm border border-slate-200 overflow-hidden">
        <div className="p-4 border-b border-slate-200 flex flex-col md:flex-row items-center gap-4 bg-slate-50/50">
          <div className="relative flex-1 w-full md:max-w-md">
            <Search className="absolute left-3 top-2.5 h-4 w-4 text-slate-400" />
            <Input 
              placeholder="Tìm kiếm theo tên đăng nhập hoặc tên nhân viên..." 
              className="pl-9 bg-white"
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
            />
          </div>
          <div className="flex items-center gap-3 w-full md:w-auto">
            <div className="flex items-center gap-2 bg-white border border-slate-200 rounded-md px-3 h-10">
              <Shield className="h-4 w-4 text-slate-400" />
              <select 
                className="bg-transparent text-sm text-slate-700 focus:outline-none"
                value={filterRole}
                onChange={(e) => setFilterRole(e.target.value)}
              >
                <option value="ALL">Tất cả vai trò</option>
                <option value="ADMIN">Quản trị viên (ADMIN)</option>
                <option value="HR">Nhân sự (HR)</option>
                <option value="DIRECTOR">Giám đốc (DIRECTOR)</option>
                <option value="ACCOUNTANT">Kế toán (ACCOUNTANT)</option>
                <option value="EMPLOYEE">Nhân viên (EMPLOYEE)</option>
              </select>
            </div>
          </div>
        </div>

        <div className="overflow-x-auto">
          <table className="w-full text-sm text-left">
            <thead className="text-xs text-slate-500 uppercase bg-slate-50 border-b border-slate-200">
              <tr>
                <th className="px-6 py-4 font-medium">Tên Đăng Nhập</th>
                <th className="px-6 py-4 font-medium">Vai Trò</th>
                <th className="px-6 py-4 font-medium">Liên Kết Nhân Viên</th>
                <th className="px-6 py-4 font-medium">Trạng Thái</th>
                <th className="px-6 py-4 font-medium">Ngày Tạo</th>
                <th className="px-6 py-4 font-medium text-right">Thao Tác</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {isLoading ? (
                <tr>
                  <td colSpan={6} className="px-6 py-12 text-center text-slate-500">
                    <div className="flex justify-center items-center">
                       <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-indigo-600"></div>
                    </div>
                  </td>
                </tr>
              ) : filteredUsers.length > 0 ? (
                filteredUsers.map((user) => (
                  <tr key={user.MaTK} className="hover:bg-slate-50/80 transition-colors group">
                    <td className="px-6 py-4 font-medium text-slate-900">
                      {user.TenDangNhap}
                    </td>
                    <td className="px-6 py-4">
                      {getRoleBadge(user.Quyen)}
                    </td>
                    <td className="px-6 py-4">
                      {user.MaNV ? (
                        <div className="flex items-center gap-2">
                          <UserIcon className="w-4 h-4 text-slate-400" />
                          <div className="flex flex-col">
                            <span className="font-medium text-slate-700">{user.HoTen}</span>
                            <span className="text-xs text-slate-500">{user.MaNV}</span>
                          </div>
                        </div>
                      ) : (
                        <span className="text-slate-400 text-sm italic">Chưa liên kết</span>
                      )}
                    </td>
                    <td className="px-6 py-4">
                      {user.TrangThai === 'A' ? (
                        <div className="flex items-center gap-1 text-emerald-600">
                          <CheckCircle className="w-4 h-4" />
                          <span className="text-xs font-medium">Đang hoạt động</span>
                        </div>
                      ) : (
                        <div className="flex items-center gap-1 text-slate-400">
                          <XCircle className="w-4 h-4" />
                          <span className="text-xs font-medium">Đã khóa</span>
                        </div>
                      )}
                    </td>
                    <td className="px-6 py-4 text-slate-500">
                      {new Date(user.NgayTao).toLocaleDateString('vi-VN')}
                    </td>
                    <td className="px-6 py-4 text-right">
                      <div className="flex items-center justify-end gap-2 opacity-0 group-hover:opacity-100 transition-opacity">
                        <Button variant="ghost" size="icon" className="h-8 w-8 text-indigo-600 hover:text-indigo-700 hover:bg-indigo-50" onClick={() => handleEdit(user)}>
                          <Edit className="h-4 w-4" />
                        </Button>
                        <Button 
                          variant="ghost" 
                          size="icon" 
                          className="h-8 w-8 text-red-600 hover:text-red-700 hover:bg-red-50" 
                          onClick={() => handleDeleteClick(user)}
                          disabled={user.TenDangNhap === 'admin'} // Prevent deleting main admin
                          title={user.TenDangNhap === 'admin' ? "Không thể xóa tài khoản admin gốc" : "Xóa"}
                        >
                          <Trash2 className="h-4 w-4" />
                        </Button>
                      </div>
                    </td>
                  </tr>
                ))
              ) : (
                <tr>
                  <td colSpan={6} className="px-6 py-12 text-center text-slate-500">
                    Không tìm thấy dữ liệu tài khoản nào phù hợp.
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </div>

      <UserFormModal 
        isOpen={isFormOpen} 
        onClose={() => setIsFormOpen(false)} 
        onSubmit={handleFormSubmit} 
        initialData={editingUser} 
        employees={employees}
      />

      <ConfirmDeleteModal 
        isOpen={isDeleteOpen}
        onClose={() => setIsDeleteOpen(false)}
        onConfirm={handleConfirmDelete}
        title="Xóa tài khoản"
        description={`Bạn có chắc chắn muốn xóa tài khoản "${deletingUser?.TenDangNhap}" không? Nếu xóa, người này sẽ không thể đăng nhập vào hệ thống.`}
      />
    </div>
  );
}
