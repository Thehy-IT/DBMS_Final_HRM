import React, { useState, useEffect } from 'react';
import { X } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { User } from '@/services/user.service';

interface UserFormModalProps {
  isOpen: boolean;
  onClose: () => void;
  onSubmit: (user: Partial<User> & { MatKhau?: string }) => void;
  initialData?: User | null;
  employees: any[];
}

export function UserFormModal({ isOpen, onClose, onSubmit, initialData, employees }: UserFormModalProps) {
  const [formData, setFormData] = useState<Partial<User> & { MatKhau?: string }>({
    TenDangNhap: '',
    MatKhau: '',
    Quyen: 'EMPLOYEE',
    TrangThai: 'A',
    MaNV: '',
  });

  useEffect(() => {
    if (initialData) {
      setFormData({ ...initialData, MatKhau: '' });
    } else {
      setFormData({
        TenDangNhap: '',
        MatKhau: '',
        Quyen: 'EMPLOYEE',
        TrangThai: 'A',
        MaNV: '',
      });
    }
  }, [initialData, isOpen]);

  if (!isOpen) return null;

  const handleChange = (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement>) => {
    const { name, value } = e.target;
    setFormData(prev => ({ ...prev, [name]: value }));
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    onSubmit(formData);
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-sm animate-in fade-in duration-200">
      <div className="bg-white rounded-xl shadow-xl w-full max-w-lg overflow-hidden animate-in zoom-in-95 duration-200">
        <div className="flex items-center justify-between px-6 py-4 border-b border-slate-100">
          <h2 className="text-lg font-semibold text-slate-800">
            {initialData ? 'Chỉnh sửa tài khoản' : 'Tạo tài khoản mới'}
          </h2>
          <button 
            onClick={onClose}
            className="text-slate-400 hover:text-slate-600 transition-colors"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        <form onSubmit={handleSubmit} className="p-6 space-y-4">
          <div className="space-y-2">
            <label className="text-sm font-medium text-slate-700">Tên đăng nhập <span className="text-red-500">*</span></label>
            <Input 
              name="TenDangNhap" 
              value={formData.TenDangNhap || ''} 
              onChange={handleChange} 
              placeholder="VD: admin_01" 
              readOnly={!!initialData}
              className={initialData ? "bg-slate-50 text-slate-500 cursor-not-allowed" : ""}
              required 
            />
          </div>

          <div className="space-y-2">
            <label className="text-sm font-medium text-slate-700">
              Mật khẩu {initialData ? '(Bỏ trống nếu không đổi)' : <span className="text-red-500">*</span>}
            </label>
            <Input 
              name="MatKhau" 
              type="password"
              value={formData.MatKhau || ''} 
              onChange={handleChange} 
              placeholder="Nhập mật khẩu..." 
              required={!initialData} 
            />
          </div>

          <div className="grid grid-cols-2 gap-4">
            <div className="space-y-2">
              <label className="text-sm font-medium text-slate-700">Vai trò (Quyền)</label>
              <select 
                name="Quyen" 
                value={formData.Quyen || 'EMPLOYEE'} 
                onChange={handleChange}
                className="flex h-10 w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-indigo-600"
              >
                <option value="EMPLOYEE">Nhân viên (EMPLOYEE)</option>
                <option value="HR">Nhân sự (HR)</option>
                <option value="ACCOUNTANT">Kế toán (ACCOUNTANT)</option>
                <option value="DIRECTOR">Giám đốc (DIRECTOR)</option>
                <option value="ADMIN">Quản trị viên (ADMIN)</option>
              </select>
            </div>
            <div className="space-y-2">
              <label className="text-sm font-medium text-slate-700">Trạng thái</label>
              <select 
                name="TrangThai" 
                value={formData.TrangThai || 'A'} 
                onChange={handleChange}
                className="flex h-10 w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-indigo-600"
              >
                <option value="A">Hoạt động (Active)</option>
                <option value="I">Bị khóa (Inactive)</option>
              </select>
            </div>
          </div>

          <div className="space-y-2">
            <label className="text-sm font-medium text-slate-700">Liên kết nhân viên (Tùy chọn)</label>
            <select 
              name="MaNV" 
              value={formData.MaNV || ''} 
              onChange={handleChange}
              className="flex h-10 w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-indigo-600"
            >
              <option value="">-- Không liên kết --</option>
              {employees.map(emp => (
                <option key={emp.MaNV} value={emp.MaNV}>
                  {emp.MaNV} - {emp.HoTen}
                </option>
              ))}
            </select>
          </div>

          <div className="pt-4 flex justify-end gap-3 border-t border-slate-100">
            <Button type="button" variant="outline" onClick={onClose}>Hủy</Button>
            <Button type="submit">{initialData ? 'Cập nhật' : 'Tạo tài khoản'}</Button>
          </div>
        </form>
      </div>
    </div>
  );
}
