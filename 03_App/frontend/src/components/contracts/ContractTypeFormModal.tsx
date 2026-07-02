import React, { useState, useEffect } from 'react';
import { X } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { MasterData } from '@/services/masterData.service';

interface ContractTypeFormModalProps {
  isOpen: boolean;
  onClose: () => void;
  onSubmit: (type: Partial<MasterData>) => void;
  initialData?: MasterData | null;
  isSubmitting?: boolean;
}

export function ContractTypeFormModal({ isOpen, onClose, onSubmit, initialData, isSubmitting = false }: ContractTypeFormModalProps) {
  const [formData, setFormData] = useState<Partial<MasterData>>({
    TenLoaiHD: '',
    ThoiHanToiDa: undefined,
    TiLeBHXH: 8.00,
    MoTa: '',
  });

  useEffect(() => {
    if (initialData) {
      setFormData({
        TenLoaiHD: initialData.TenLoaiHD || initialData.name || '',
        ThoiHanToiDa: initialData.ThoiHanToiDa,
        TiLeBHXH: initialData.TiLeBHXH !== undefined ? initialData.TiLeBHXH : 8.00,
        MoTa: initialData.MoTa || '',
      });
    } else {
      setFormData({
        TenLoaiHD: '',
        ThoiHanToiDa: undefined,
        TiLeBHXH: 8.00,
        MoTa: '',
      });
    }
  }, [initialData, isOpen]);

  if (!isOpen) return null;

  const handleChange = (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement | HTMLTextAreaElement>) => {
    const { name, value } = e.target;
    
    if (name === 'ThoiHanToiDa') {
      setFormData(prev => ({ ...prev, [name]: value === '' ? undefined : Number(value) }));
    } else if (name === 'TiLeBHXH') {
      setFormData(prev => ({ ...prev, [name]: Number(value) }));
    } else {
      setFormData(prev => ({ ...prev, [name]: value }));
    }
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    onSubmit(formData);
  };

  const handleClose = () => {
    if (isSubmitting) return;
    onClose();
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-sm animate-in fade-in duration-200">
      <div className="fixed inset-0" onClick={handleClose}></div>
      <div className="bg-white rounded-xl shadow-xl w-full max-w-lg overflow-hidden animate-in zoom-in-95 duration-200 relative z-10">
        <div className="flex items-center justify-between px-6 py-4 border-b border-slate-100 bg-slate-50">
          <h2 className="text-lg font-bold text-slate-800">
            {initialData ? 'Chỉnh sửa loại hợp đồng' : 'Thêm loại hợp đồng mới'}
          </h2>
          <button 
            onClick={handleClose}
            disabled={isSubmitting}
            className={`transition-colors p-1 rounded-full ${isSubmitting ? 'text-slate-300 cursor-not-allowed' : 'text-slate-400 hover:text-slate-600 hover:bg-slate-200'}`}
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        <form onSubmit={handleSubmit} className="p-6 space-y-5 max-h-[80vh] overflow-y-auto">
          <div className="space-y-4">
            <div className="space-y-2">
              <label className="text-sm font-medium text-slate-700">Tên loại hợp đồng <span className="text-red-500">*</span></label>
              <Input 
                name="TenLoaiHD" 
                value={formData.TenLoaiHD || ''} 
                onChange={handleChange} 
                placeholder="VD: Hợp đồng có thời hạn 1 năm" 
                required 
              />
            </div>

            <div className="grid grid-cols-2 gap-4">
              <div className="space-y-2">
                <label className="text-sm font-medium text-slate-700">Thời hạn tối đa (tháng)</label>
                <Input 
                  name="ThoiHanToiDa" 
                  type="number"
                  min="1"
                  max="120"
                  value={formData.ThoiHanToiDa || ''} 
                  onChange={handleChange} 
                  placeholder="Để trống nếu vô thời hạn"
                />
              </div>

              <div className="space-y-2">
                <label className="text-sm font-medium text-slate-700">Tỷ lệ BHXH NLĐ đóng (%) <span className="text-red-500">*</span></label>
                <Input 
                  name="TiLeBHXH" 
                  type="number"
                  step="0.01"
                  min="0"
                  max="20"
                  value={formData.TiLeBHXH !== undefined ? formData.TiLeBHXH : ''} 
                  onChange={handleChange} 
                  required 
                />
              </div>
            </div>

            <div className="space-y-2">
              <label className="text-sm font-medium text-slate-700">Mô tả chi tiết</label>
              <textarea 
                name="MoTa" 
                value={formData.MoTa || ''} 
                onChange={handleChange} 
                className="flex w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-indigo-600 min-h-[80px]"
                placeholder="Quy định và các điều khoản cơ bản..."
              />
            </div>
          </div>

          <div className="pt-6 flex justify-end gap-3 border-t border-slate-100">
            <Button type="button" variant="outline" onClick={handleClose} disabled={isSubmitting}>Hủy bỏ</Button>
            <Button type="submit" disabled={isSubmitting}>
              {isSubmitting ? (initialData ? 'Đang cập nhật...' : 'Đang tạo...') : (initialData ? 'Lưu thay đổi' : 'Tạo mới')}
            </Button>
          </div>
        </form>
      </div>
    </div>
  );
}
