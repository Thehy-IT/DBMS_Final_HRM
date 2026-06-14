import React, { useState, useEffect } from 'react';
import { X } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { MasterData } from '@/services/masterData.service';

interface BenefitFormModalProps {
  isOpen: boolean;
  onClose: () => void;
  onSubmit: (benefit: Partial<MasterData>) => void;
  initialData?: MasterData | null;
}

export function BenefitFormModal({ isOpen, onClose, onSubmit, initialData }: BenefitFormModalProps) {
  const [formData, setFormData] = useState<Partial<MasterData>>({
    MaFL: '',
    TenFL: '',
    LoaiGiaTri: 'F',
    GiaTri: 0,
    CoTinhThue: 0,
    MoTa: '',
    IsActive: 1,
  });

  useEffect(() => {
    if (initialData) {
      setFormData({
        MaFL: initialData.MaFL || initialData.id || '',
        TenFL: initialData.TenFL || initialData.name || '',
        LoaiGiaTri: initialData.LoaiGiaTri || 'F',
        GiaTri: initialData.GiaTri !== undefined ? initialData.GiaTri : 0,
        CoTinhThue: initialData.CoTinhThue !== undefined ? initialData.CoTinhThue : 0,
        MoTa: initialData.MoTa || '',
        IsActive: initialData.IsActive !== undefined ? initialData.IsActive : 1,
      });
    } else {
      setFormData({
        MaFL: '',
        TenFL: '',
        LoaiGiaTri: 'F',
        GiaTri: 0,
        CoTinhThue: 0,
        MoTa: '',
        IsActive: 1,
      });
    }
  }, [initialData, isOpen]);

  if (!isOpen) return null;

  const handleChange = (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement | HTMLTextAreaElement>) => {
    const { name, value, type } = e.target;
    
    let parsedValue: string | number = value;
    if (type === 'number' || name === 'CoTinhThue' || name === 'IsActive') {
      parsedValue = value === '' ? 0 : Number(value);
    }

    setFormData(prev => ({ ...prev, [name]: parsedValue }));
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
            {initialData ? 'Chỉnh sửa loại phúc lợi' : 'Thêm loại phúc lợi mới'}
          </h2>
          <button 
            onClick={onClose}
            className="text-slate-400 hover:text-slate-600 transition-colors p-1 hover:bg-slate-200 rounded-full"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        <form onSubmit={handleSubmit} className="p-6 space-y-4 max-h-[80vh] overflow-y-auto">
          <div className="space-y-2">
            <label className="text-sm font-medium text-slate-700">Mã loại phúc lợi <span className="text-red-500">*</span></label>
            <Input 
              name="MaFL" 
              value={formData.MaFL || ''} 
              onChange={handleChange} 
              placeholder="VD: FL0001" 
              readOnly={!!initialData}
              className={initialData ? "bg-slate-50 text-slate-500 cursor-not-allowed" : ""}
              required 
              pattern="^FL[0-9]{4}$"
              title="Định dạng: FL theo sau bởi 4 chữ số, VD: FL0001"
            />
          </div>

          <div className="space-y-2">
            <label className="text-sm font-medium text-slate-700">Tên phúc lợi <span className="text-red-500">*</span></label>
            <Input 
              name="TenFL" 
              value={formData.TenFL || ''} 
              onChange={handleChange} 
              placeholder="VD: Phụ cấp ăn trưa" 
              required 
            />
          </div>

          <div className="grid grid-cols-2 gap-4">
            <div className="space-y-2">
              <label className="text-sm font-medium text-slate-700">Loại giá trị</label>
              <select 
                name="LoaiGiaTri" 
                value={formData.LoaiGiaTri || 'F'} 
                onChange={handleChange}
                className="flex h-10 w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-indigo-600"
              >
                <option value="F">Cố định (Fixed)</option>
                <option value="P">Phần trăm (%)</option>
              </select>
            </div>
            <div className="space-y-2">
              <label className="text-sm font-medium text-slate-700">Giá trị <span className="text-red-500">*</span></label>
              <Input 
                name="GiaTri" 
                type="number" 
                min="0"
                value={formData.GiaTri ?? 0} 
                onChange={handleChange} 
                required 
              />
            </div>
          </div>

          <div className="grid grid-cols-2 gap-4">
            <div className="space-y-2">
              <label className="text-sm font-medium text-slate-700">Tính thuế TNCN</label>
              <select 
                name="CoTinhThue" 
                value={formData.CoTinhThue ?? 0} 
                onChange={handleChange}
                className="flex h-10 w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-indigo-600"
              >
                <option value={1}>Có tính thuế</option>
                <option value={0}>Không tính thuế</option>
              </select>
            </div>
            <div className="space-y-2">
              <label className="text-sm font-medium text-slate-700">Trạng thái</label>
              <select 
                name="IsActive" 
                value={formData.IsActive ?? 1} 
                onChange={handleChange}
                className="flex h-10 w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-indigo-600"
              >
                <option value={1}>Hoạt động</option>
                <option value={0}>Đã ẩn</option>
              </select>
            </div>
          </div>

          <div className="space-y-2">
            <label className="text-sm font-medium text-slate-700">Mô tả chi tiết</label>
            <textarea 
              name="MoTa"
              value={formData.MoTa || ''}
              onChange={handleChange}
              className="w-full min-h-[80px] rounded-md border border-slate-300 bg-white px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-600 resize-none"
              placeholder="Nhập mô tả về phúc lợi..."
            />
          </div>

          <div className="pt-4 flex justify-end gap-3 border-t border-slate-100">
            <Button type="button" variant="outline" onClick={onClose}>Hủy</Button>
            <Button type="submit">{initialData ? 'Cập nhật' : 'Thêm mới'}</Button>
          </div>
        </form>
      </div>
    </div>
  );
}
