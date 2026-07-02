import React, { useState, useEffect } from 'react';
import { X } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { MasterData } from '@/services/masterData.service';

interface DepartmentFormModalProps {
  isOpen: boolean;
  onClose: () => void;
  onSubmit: (dept: Partial<MasterData>) => void;
  initialData?: MasterData | null;
  employees: any[];
  isSubmitting?: boolean;
}

export function DepartmentFormModal({ isOpen, onClose, onSubmit, initialData, employees, isSubmitting = false }: DepartmentFormModalProps) {
  const [formData, setFormData] = useState<Partial<MasterData>>({
    MaPB: '',
    TenPB: '',
    DiaDiem: '',
    DienThoai: '',
    Email: '',
    MaTruongPhong: '',
    NgayThanhLap: '',
    GhiChu: '',
    IsActive: 1,
  });

  useEffect(() => {
    if (initialData) {
      setFormData({
        MaPB: initialData.MaPB || initialData.id || '',
        TenPB: initialData.TenPB || initialData.name || '',
        DiaDiem: initialData.DiaDiem || '',
        DienThoai: initialData.DienThoai || '',
        Email: initialData.Email || '',
        MaTruongPhong: initialData.MaTruongPhong || '',
        NgayThanhLap: initialData.NgayThanhLap ? new Date(initialData.NgayThanhLap).toISOString().split('T')[0] : '',
        GhiChu: initialData.GhiChu || '',
        IsActive: initialData.IsActive !== undefined ? initialData.IsActive : 1,
      });
    } else {
      setFormData({
        MaPB: '',
        TenPB: '',
        DiaDiem: '',
        DienThoai: '',
        Email: '',
        MaTruongPhong: '',
        NgayThanhLap: '',
        GhiChu: '',
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
      {/* Thêm overlay div để click bên ngoài thì đóng */}
      <div className="fixed inset-0" onClick={handleClose}></div>
      <div className="bg-white rounded-xl shadow-xl w-full max-w-2xl overflow-hidden animate-in zoom-in-95 duration-200 relative z-10">
        <div className="flex items-center justify-between px-6 py-4 border-b border-slate-100 bg-slate-50">
          <h2 className="text-lg font-bold text-slate-800">
            {initialData ? 'Chỉnh sửa phòng ban' : 'Tạo phòng ban mới'}
          </h2>
          <button 
            onClick={handleClose}
            disabled={isSubmitting}
            className={`transition-colors p-1 rounded-full ${isSubmitting ? 'text-slate-300 cursor-not-allowed' : 'text-slate-400 hover:text-slate-600 hover:bg-slate-200'}`}
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        <form onSubmit={handleSubmit} className="p-6 space-y-6 max-h-[80vh] overflow-y-auto">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div className="space-y-2">
              <label className="text-sm font-medium text-slate-700">Mã phòng ban <span className="text-red-500">*</span></label>
              <Input 
                name="MaPB" 
                value={formData.MaPB || ''} 
                onChange={handleChange} 
                placeholder="VD: PB0001" 
                readOnly={!!initialData}
                className={initialData ? "bg-slate-50 text-slate-500 cursor-not-allowed" : ""}
                required 
                pattern="^PB[0-9]{4}$"
                title="Định dạng: PB theo sau bởi 4 chữ số, VD: PB0001"
              />
            </div>

            <div className="space-y-2">
              <label className="text-sm font-medium text-slate-700">Tên phòng ban <span className="text-red-500">*</span></label>
              <Input 
                name="TenPB" 
                value={formData.TenPB || ''} 
                onChange={handleChange} 
                placeholder="VD: Phòng IT" 
                required 
              />
            </div>

            <div className="space-y-2">
              <label className="text-sm font-medium text-slate-700">Trưởng phòng</label>
              <select 
                name="MaTruongPhong" 
                value={formData.MaTruongPhong || ''} 
                onChange={handleChange}
                className="flex h-10 w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-indigo-600"
              >
                <option value="">-- Chưa bổ nhiệm --</option>
                {employees.map(emp => (
                  <option key={emp.MaNV} value={emp.MaNV}>
                    {emp.MaNV} - {emp.HoTen}
                  </option>
                ))}
              </select>
            </div>

            <div className="space-y-2">
              <label className="text-sm font-medium text-slate-700">Ngày thành lập</label>
              <Input 
                name="NgayThanhLap" 
                type="date"
                value={formData.NgayThanhLap || ''} 
                onChange={handleChange} 
              />
            </div>

            <div className="space-y-2">
              <label className="text-sm font-medium text-slate-700">Email liên hệ</label>
              <Input 
                name="Email" 
                type="email"
                value={formData.Email || ''} 
                onChange={handleChange} 
                placeholder="VD: it@company.com" 
              />
            </div>

            <div className="space-y-2">
              <label className="text-sm font-medium text-slate-700">Số điện thoại</label>
              <Input 
                name="DienThoai" 
                value={formData.DienThoai || ''} 
                onChange={handleChange} 
                placeholder="VD: 0283123456" 
              />
            </div>

            <div className="space-y-2 md:col-span-2">
              <label className="text-sm font-medium text-slate-700">Địa điểm / Văn phòng</label>
              <Input 
                name="DiaDiem" 
                value={formData.DiaDiem || ''} 
                onChange={handleChange} 
                placeholder="VD: Tầng 3, Tòa nhà A" 
              />
            </div>

            <div className="space-y-2 md:col-span-2">
              <label className="text-sm font-medium text-slate-700">Ghi chú</label>
              <textarea 
                name="GhiChu" 
                value={formData.GhiChu || ''} 
                onChange={handleChange} 
                className="flex w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-indigo-600 min-h-[80px]"
                placeholder="Thông tin thêm..."
              />
            </div>

            <div className="space-y-2 md:col-span-2">
              <label className="flex items-center gap-2 cursor-pointer">
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
