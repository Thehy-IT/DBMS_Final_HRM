import React, { useState, useEffect } from 'react';
import { X } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { MasterData } from '@/services/masterData.service';

interface PositionFormModalProps {
  isOpen: boolean;
  onClose: () => void;
  onSubmit: (pos: Partial<MasterData>) => void;
  initialData?: MasterData | null;
}

export function PositionFormModal({ isOpen, onClose, onSubmit, initialData }: PositionFormModalProps) {
  const [formData, setFormData] = useState<Partial<MasterData>>({
    MaCV: '',
    TenCV: '',
    HeSoLuong: 1.00,
    MoTa: '',
    CapBac: 1,
    IsActive: 1,
  });

  useEffect(() => {
    if (initialData) {
      setFormData({
        MaCV: initialData.MaCV || initialData.id || '',
        TenCV: initialData.TenCV || initialData.name || '',
        HeSoLuong: initialData.HeSoLuong !== undefined ? initialData.HeSoLuong : 1.00,
        MoTa: initialData.MoTa || '',
        CapBac: initialData.CapBac || 1,
        IsActive: initialData.IsActive !== undefined ? initialData.IsActive : 1,
      });
    } else {
      setFormData({
        MaCV: '',
        TenCV: '',
        HeSoLuong: 1.00,
        MoTa: '',
        CapBac: 1,
        IsActive: 1,
      });
    }
  }, [initialData, isOpen]);

  if (!isOpen) return null;

  const handleChange = (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement | HTMLTextAreaElement>) => {
    const { name, value, type } = e.target;
    
    if (type === 'checkbox') {
      const checked = (e.target as HTMLInputElement).checked;
      setFormData(prev => ({ ...prev, [name]: checked ? 1 : 0 }));
    } else if (name === 'HeSoLuong' || name === 'CapBac') {
      setFormData(prev => ({ ...prev, [name]: Number(value) }));
    } else {
      setFormData(prev => ({ ...prev, [name]: value }));
    }
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    onSubmit(formData);
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-sm animate-in fade-in duration-200">
      <div className="bg-white rounded-xl shadow-xl w-full max-w-lg overflow-hidden animate-in zoom-in-95 duration-200">
        <div className="flex items-center justify-between px-6 py-4 border-b border-slate-100 bg-slate-50">
          <h2 className="text-lg font-bold text-slate-800">
            {initialData ? 'Chỉnh sửa chức vụ' : 'Thêm chức vụ mới'}
          </h2>
          <button 
            onClick={onClose}
            className="text-slate-400 hover:text-slate-600 transition-colors p-1 hover:bg-slate-200 rounded-full"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        <form onSubmit={handleSubmit} className="p-6 space-y-5 max-h-[80vh] overflow-y-auto">
          <div className="space-y-4">
            <div className="space-y-2">
              <label className="text-sm font-medium text-slate-700">Mã chức vụ <span className="text-red-500">*</span></label>
              <Input 
                name="MaCV" 
                value={formData.MaCV || ''} 
                onChange={handleChange} 
                placeholder="VD: CV0001" 
                readOnly={!!initialData}
                className={initialData ? "bg-slate-50 text-slate-500 cursor-not-allowed" : ""}
                required 
                pattern="^CV[0-9]{4}$"
                title="Định dạng: CV theo sau bởi 4 chữ số, VD: CV0001"
              />
            </div>

            <div className="space-y-2">
              <label className="text-sm font-medium text-slate-700">Tên chức vụ <span className="text-red-500">*</span></label>
              <Input 
                name="TenCV" 
                value={formData.TenCV || ''} 
                onChange={handleChange} 
                placeholder="VD: Trưởng phòng IT" 
                required 
              />
            </div>

            <div className="grid grid-cols-2 gap-4">
              <div className="space-y-2">
                <label className="text-sm font-medium text-slate-700">Cấp bậc <span className="text-red-500">*</span></label>
                <select 
                  name="CapBac" 
                  value={formData.CapBac || 1} 
                  onChange={handleChange}
                  className="flex h-10 w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-indigo-600"
                  required
                >
                  <option value={1}>Cấp 1 - Nhân viên</option>
                  <option value={2}>Cấp 2 - Chuyên viên</option>
                  <option value={3}>Cấp 3 - Trưởng/Phó phòng</option>
                  <option value={4}>Cấp 4 - Quản lý cấp cao</option>
                  <option value={5}>Cấp 5 - Giám đốc</option>
                </select>
              </div>

              <div className="space-y-2">
                <label className="text-sm font-medium text-slate-700">Hệ số lương <span className="text-red-500">*</span></label>
                <Input 
                  name="HeSoLuong" 
                  type="number"
                  step="0.01"
                  min="0.5"
                  max="10.0"
                  value={formData.HeSoLuong || ''} 
                  onChange={handleChange} 
                  required 
                />
              </div>
            </div>

            <div className="space-y-2">
              <label className="text-sm font-medium text-slate-700">Mô tả</label>
              <textarea 
                name="MoTa" 
                value={formData.MoTa || ''} 
                onChange={handleChange} 
                className="flex w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-indigo-600 min-h-[80px]"
                placeholder="Mô tả công việc và trách nhiệm..."
              />
            </div>

            <div className="space-y-2">
              <label className="flex items-center gap-2 cursor-pointer mt-2">
                <input 
                  type="checkbox" 
                  name="IsActive" 
                  checked={formData.IsActive === 1}
                  onChange={handleChange}
                  className="w-4 h-4 text-indigo-600 rounded border-slate-300 focus:ring-indigo-600"
                />
                <span className="text-sm font-medium text-slate-700">Đang hoạt động</span>
              </label>
            </div>
          </div>

          <div className="pt-6 flex justify-end gap-3 border-t border-slate-100">
            <Button type="button" variant="outline" onClick={onClose}>Hủy bỏ</Button>
            <Button type="submit">{initialData ? 'Lưu thay đổi' : 'Tạo mới'}</Button>
          </div>
        </form>
      </div>
    </div>
  );
}
