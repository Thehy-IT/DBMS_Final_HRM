"use client";

import React, { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { Plus, Trash2, Gift, TrendingDown, Loader2, Wallet, Receipt, Calendar, ArrowRight } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { formatMoney } from '@/lib/utils';
import { employeeService } from '@/services/employee.service';
import { masterDataService } from '@/services/masterData.service';

export function EmployeeBenefitsTab({ employeeId }: { employeeId: string | null | undefined }) {
  const queryClient = useQueryClient();

  const [showBenefitForm, setShowBenefitForm] = useState(false);
  const [showDeductForm, setShowDeductForm] = useState(false);

  // Fetch data
  const { data: benefits = [], isLoading: loadingB } = useQuery({
    queryKey: ['employee-benefits', employeeId],
    queryFn: () => employeeService.getEmployeeBenefits(employeeId!),
    enabled: !!employeeId
  });

  const { data: deductions = [], isLoading: loadingD } = useQuery({
    queryKey: ['employee-deductions', employeeId],
    queryFn: () => employeeService.getEmployeeDeductions(employeeId!),
    enabled: !!employeeId
  });

  const { data: benefitTypes = [] } = useQuery({
    queryKey: ['benefit-types'],
    queryFn: masterDataService.getBenefitTypes
  });

  const { data: deductionTypes = [] } = useQuery({
    queryKey: ['deduction-types'],
    queryFn: masterDataService.getDeductionTypes
  });

  // State
  const [newBenefit, setNewBenefit] = useState({ MaFL: '', GiaTriOverride: '', NgayApDung: '', GhiChu: '' });
  const [newDeduct, setNewDeduct] = useState({ LoaiKhauTru: '', GiaTri: '', NgayPhatSinh: '', GhiChu: '' });

  // Mutations
  const addBenefitMutation = useMutation({
    mutationFn: (data: any) => employeeService.addEmployeeBenefit({ ...data, MaNV: employeeId }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['employee-benefits', employeeId] });
      setNewBenefit({ MaFL: '', GiaTriOverride: '', NgayApDung: '', GhiChu: '' });
      setShowBenefitForm(false);
    }
  });

  const removeBenefitMutation = useMutation({
    mutationFn: ({ maFL, ngayApDung }: any) => employeeService.removeEmployeeBenefit(employeeId!, maFL, ngayApDung),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['employee-benefits', employeeId] })
  });

  const addDeductMutation = useMutation({
    mutationFn: (data: any) => employeeService.addEmployeeDeduction({ ...data, MaNV: employeeId }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['employee-deductions', employeeId] });
      setNewDeduct({ LoaiKhauTru: '', GiaTri: '', NgayPhatSinh: '', GhiChu: '' });
      setShowDeductForm(false);
    }
  });

  const removeDeductMutation = useMutation({
    mutationFn: (id: string) => employeeService.removeEmployeeDeduction(id),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['employee-deductions', employeeId] })
  });

  if (!employeeId) {
    return (
      <div className="flex flex-col items-center justify-center h-[300px] text-slate-400 bg-slate-50/50 rounded-2xl border-2 border-dashed border-slate-200">
        <div className="w-16 h-16 bg-white rounded-full flex items-center justify-center shadow-sm mb-4">
          <Wallet className="w-8 h-8 text-indigo-300" />
        </div>
        <p className="text-sm font-medium text-slate-600">Hồ sơ nhân viên chưa được lưu</p>
        <p className="text-xs text-slate-400 mt-1 max-w-[250px] text-center">
          Vui lòng hoàn tất và lưu thông tin chung trước khi gán phúc lợi hoặc khấu trừ.
        </p>
      </div>
    );
  }

  const handleAddBenefit = () => {
    if (!newBenefit.MaFL || !newBenefit.NgayApDung) {
      alert('Vui lòng chọn Loại phúc lợi và Ngày áp dụng');
      return;
    }
    addBenefitMutation.mutate(newBenefit);
  };

  const handleAddDeduct = () => {
    if (!newDeduct.LoaiKhauTru || !newDeduct.GiaTri) {
      alert('Vui lòng nhập Loại khấu trừ và Số tiền');
      return;
    }
    addDeductMutation.mutate(newDeduct);
  };

  const actualBenefits = benefits?.data || benefits;
  const actualDeductions = deductions?.data || deductions;

  // Summaries
  const totalFixedBenefits = actualBenefits.reduce((acc: number, b: any) => {
    if (b.LoaiGiaTri === 'F' || b.GiaTriOverride) {
      return acc + Number(b.GiaTriOverride || b.GiaTriGoc);
    }
    return acc;
  }, 0);

  const totalDeductions = actualDeductions.reduce((acc: number, d: any) => acc + Number(d.GiaTri), 0);

  return (
    <div className="space-y-6 animate-in fade-in slide-in-from-bottom-4 duration-500">
      
      {/* SUMMARY DASHBOARD */}
      <div className="grid grid-cols-2 gap-4">
        <div className="bg-gradient-to-br from-indigo-500 to-indigo-600 rounded-2xl p-5 text-white shadow-lg shadow-indigo-200">
          <div className="flex items-center justify-between mb-4">
            <h4 className="text-indigo-100 text-sm font-medium">Tổng Phúc Lợi Cố Định</h4>
            <div className="bg-white/20 p-2 rounded-lg backdrop-blur-sm">
              <Gift className="w-5 h-5 text-white" />
            </div>
          </div>
          <div className="text-3xl font-bold tracking-tight">
            +{formatMoney(totalFixedBenefits)}
          </div>
          <p className="text-indigo-200 text-xs mt-1">Đang áp dụng: {actualBenefits.length} khoản</p>
        </div>

        <div className="bg-gradient-to-br from-rose-500 to-rose-600 rounded-2xl p-5 text-white shadow-lg shadow-rose-200">
          <div className="flex items-center justify-between mb-4">
            <h4 className="text-rose-100 text-sm font-medium">Tổng Khấu Trừ</h4>
            <div className="bg-white/20 p-2 rounded-lg backdrop-blur-sm">
              <TrendingDown className="w-5 h-5 text-white" />
            </div>
          </div>
          <div className="text-3xl font-bold tracking-tight">
            -{formatMoney(totalDeductions)}
          </div>
          <p className="text-rose-200 text-xs mt-1">Đã ghi nhận: {actualDeductions.length} khoản</p>
        </div>
      </div>

      {/* SECTION: PHÚC LỢI */}
      <div className="bg-white rounded-2xl shadow-sm border border-slate-200 overflow-hidden">
        <div className="p-5 border-b border-slate-100 flex items-center justify-between bg-slate-50/50">
          <div className="flex items-center gap-3">
            <div className="bg-indigo-100 p-2 rounded-lg">
              <Gift className="w-5 h-5 text-indigo-600" />
            </div>
            <div>
              <h3 className="font-semibold text-slate-800">Danh Sách Phúc Lợi</h3>
              <p className="text-xs text-slate-500">Các khoản phụ cấp hàng tháng</p>
            </div>
          </div>
          {!showBenefitForm && (
            <Button 
              size="sm" 
              className="bg-indigo-600 hover:bg-indigo-700 shadow-sm"
              onClick={() => setShowBenefitForm(true)}
            >
              <Plus className="w-4 h-4 mr-1"/> Thêm Phúc Lợi
            </Button>
          )}
        </div>
        
        {/* Add Form (Inline Collapse) */}
        {showBenefitForm && (
          <div className="p-5 bg-indigo-50/50 border-b border-indigo-100 animate-in slide-in-from-top-2 duration-300">
            <div className="grid grid-cols-12 gap-4 items-end">
              <div className="col-span-12 md:col-span-4">
                <label className="text-xs text-slate-700 font-semibold mb-1.5 block">Loại Phúc Lợi</label>
                <select 
                  className="w-full h-10 rounded-lg border border-slate-300 px-3 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500/50 focus:border-indigo-500 transition-shadow bg-white"
                  value={newBenefit.MaFL}
                  onChange={(e) => setNewBenefit({ ...newBenefit, MaFL: e.target.value })}
                >
                  <option value="">-- Chọn danh mục --</option>
                  {benefitTypes.filter((b: any) => b.IsActive).map((b: any) => (
                    <option key={b.id || b.MaFL} value={b.id || b.MaFL}>
                      {b.name || b.TenFL} ({b.LoaiGiaTri === 'F' ? formatMoney(b.GiaTri) : b.GiaTri + '%'})
                    </option>
                  ))}
                </select>
              </div>
              <div className="col-span-12 md:col-span-3">
                <label className="text-xs text-slate-700 font-semibold mb-1.5 block">Tiền Ghi Đè (Tuỳ chọn)</label>
                <Input 
                  placeholder="Bỏ trống nếu lấy chuẩn" 
                  className="h-10 text-sm rounded-lg" 
                  value={newBenefit.GiaTriOverride}
                  onChange={(e) => setNewBenefit({ ...newBenefit, GiaTriOverride: e.target.value })}
                />
              </div>
              <div className="col-span-12 md:col-span-4">
                <label className="text-xs text-slate-700 font-semibold mb-1.5 block">Ngày Áp Dụng</label>
                <Input 
                  type="date" 
                  className="h-10 text-sm rounded-lg" 
                  value={newBenefit.NgayApDung}
                  onChange={(e) => setNewBenefit({ ...newBenefit, NgayApDung: e.target.value })}
                />
              </div>
            </div>
            <div className="flex justify-end gap-3 mt-5">
              <Button variant="outline" className="h-10 rounded-lg" onClick={() => setShowBenefitForm(false)}>
                Hủy Bỏ
              </Button>
              <Button className="h-10 bg-indigo-600 hover:bg-indigo-700 rounded-lg shadow-md" onClick={handleAddBenefit} disabled={addBenefitMutation.isPending}>
                {addBenefitMutation.isPending ? <Loader2 className="w-4 h-4 animate-spin mr-2" /> : null} Lưu lại
              </Button>
            </div>
          </div>
        )}

        {/* List */}
        <div className="p-5">
          {loadingB ? (
            <div className="flex justify-center py-8"><Loader2 className="w-6 h-6 animate-spin text-indigo-500" /></div>
          ) : actualBenefits.length === 0 ? (
            <div className="text-center py-8 text-slate-500 flex flex-col items-center">
              <Gift className="w-10 h-10 text-slate-200 mb-2" />
              <p className="text-sm">Chưa có phúc lợi nào được gán.</p>
            </div>
          ) : (
            <div className="flex flex-col gap-3">
              {actualBenefits.map((b: any, idx: number) => (
                <div key={idx} className="group relative flex items-center p-4 border border-slate-200 rounded-xl hover:border-indigo-300 hover:shadow-md transition-all bg-white">
                  <div className="w-10 h-10 rounded-full bg-indigo-50 flex items-center justify-center mr-4 text-indigo-600 shrink-0">
                    <Gift className="w-5 h-5" />
                  </div>
                  <div className="flex-1 min-w-0">
                    <h4 className="font-semibold text-slate-900 truncate">{b.TenFL}</h4>
                    <div className="flex items-center gap-2 text-xs text-slate-500 mt-1">
                      <Calendar className="w-3 h-3" />
                      <span>Từ {new Date(b.NgayApDung).toLocaleDateString('vi-VN')}</span>
                    </div>
                  </div>
                  <div className="text-right ml-4 mr-8">
                    <p className="font-bold text-indigo-600">
                      {b.GiaTriOverride ? formatMoney(b.GiaTriOverride) : (b.LoaiGiaTri === 'F' ? formatMoney(b.GiaTriGoc) : b.GiaTriGoc + '%')}
                    </p>
                    {b.GiaTriOverride && <p className="text-[10px] text-slate-400 bg-slate-100 px-1.5 py-0.5 rounded inline-block mt-0.5">Ghi đè</p>}
                  </div>
                  
                  {/* Delete Overlay Button */}
                  <button 
                    onClick={() => removeBenefitMutation.mutate({ maFL: b.MaFL, ngayApDung: b.NgayApDung.split('T')[0] })}
                    className="absolute right-3 top-1/2 -translate-y-1/2 w-8 h-8 rounded-full bg-red-50 text-red-500 flex items-center justify-center opacity-0 group-hover:opacity-100 transition-opacity hover:bg-red-100"
                    title="Xóa phúc lợi"
                  >
                    <Trash2 className="w-4 h-4" />
                  </button>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>

      {/* SECTION: KHẤU TRỪ */}
      <div className="bg-white rounded-2xl shadow-sm border border-slate-200 overflow-hidden">
        <div className="p-5 border-b border-slate-100 flex items-center justify-between bg-slate-50/50">
          <div className="flex items-center gap-3">
            <div className="bg-rose-100 p-2 rounded-lg">
              <TrendingDown className="w-5 h-5 text-rose-600" />
            </div>
            <div>
              <h3 className="font-semibold text-slate-800">Khoản Khấu Trừ</h3>
              <p className="text-xs text-slate-500">Phạt, tạm ứng, bồi thường</p>
            </div>
          </div>
          {!showDeductForm && (
            <Button 
              size="sm" 
              className="bg-rose-600 hover:bg-rose-700 shadow-sm"
              onClick={() => setShowDeductForm(true)}
            >
              <Plus className="w-4 h-4 mr-1"/> Thêm Khấu Trừ
            </Button>
          )}
        </div>
        
        {/* Add Form */}
        {showDeductForm && (
          <div className="p-5 bg-rose-50/50 border-b border-rose-100 animate-in slide-in-from-top-2 duration-300">
            <div className="grid grid-cols-12 gap-4 items-end">
              <div className="col-span-12 md:col-span-6">
                <label className="text-xs text-slate-700 font-semibold mb-1.5 block">Loại khấu trừ (*)</label>
                <select 
                  className="w-full h-10 border border-slate-200 rounded-lg px-3 text-sm focus:border-rose-500 focus:ring-1 focus:ring-rose-500 bg-slate-50 hover:bg-white transition-colors"
                  value={newDeduct.LoaiKhauTru}
                  onChange={(e) => setNewDeduct({ ...newDeduct, LoaiKhauTru: e.target.value })}
                >
                  <option value="">-- Chọn loại khấu trừ --</option>
                  {deductionTypes.map((dt: any) => (
                    <option key={dt.MaLKT} value={dt.TenLKT}>{dt.TenLKT}</option>
                  ))}
                </select>
              </div>
              <div className="col-span-12 md:col-span-6">
                <label className="text-xs text-slate-700 font-semibold mb-1.5 block">Số tiền (VNĐ) <span className="text-red-500">*</span></label>
                <Input 
                  type="number"
                  placeholder="VD: 500000" 
                  className="h-10 text-sm rounded-lg font-medium text-rose-600" 
                  value={newDeduct.GiaTri}
                  onChange={(e) => setNewDeduct({ ...newDeduct, GiaTri: e.target.value })}
                />
              </div>
            </div>
            <div className="flex justify-end gap-3 mt-5">
              <Button variant="outline" className="h-10 rounded-lg border-rose-200 text-rose-700 hover:bg-rose-100 hover:text-rose-800" onClick={() => setShowDeductForm(false)}>
                Hủy Bỏ
              </Button>
              <Button className="h-10 bg-rose-600 hover:bg-rose-700 rounded-lg shadow-md" onClick={handleAddDeduct} disabled={addDeductMutation.isPending}>
                {addDeductMutation.isPending ? <Loader2 className="w-4 h-4 animate-spin mr-2" /> : null} Tạo Khoản Trừ
              </Button>
            </div>
          </div>
        )}

        {/* List */}
        <div className="p-5">
          {loadingD ? (
            <div className="flex justify-center py-8"><Loader2 className="w-6 h-6 animate-spin text-rose-500" /></div>
          ) : actualDeductions.length === 0 ? (
            <div className="text-center py-8 text-slate-500 flex flex-col items-center">
              <Receipt className="w-10 h-10 text-slate-200 mb-2" />
              <p className="text-sm">Không có khoản khấu trừ nào.</p>
            </div>
          ) : (
            <div className="flex flex-col gap-3">
              {actualDeductions.map((d: any) => (
                <div key={d.MaKT} className="group relative flex items-center p-4 border border-slate-200 rounded-xl hover:border-rose-300 hover:shadow-md transition-all bg-white">
                  <div className="w-10 h-10 rounded-full bg-rose-50 flex items-center justify-center mr-4 text-rose-600 shrink-0">
                    <TrendingDown className="w-5 h-5" />
                  </div>
                  <div className="flex-1 min-w-0">
                    <h4 className="font-semibold text-slate-900 truncate">{d.LoaiKhauTru}</h4>
                    <div className="flex items-center gap-2 text-xs text-slate-500 mt-1">
                      <Calendar className="w-3 h-3" />
                      <span>Phát sinh: {new Date(d.NgayPhatSinh).toLocaleDateString('vi-VN')}</span>
                    </div>
                  </div>
                  <div className="text-right ml-4 mr-8">
                    <p className="font-bold text-rose-600">-{formatMoney(d.GiaTri)}</p>
                    {d.TrangThai === 'P' 
                      ? <span className="text-[10px] uppercase tracking-wider font-semibold text-amber-600 bg-amber-50 px-2 py-0.5 rounded-full border border-amber-200 mt-1 inline-block">Chờ duyệt</span> 
                      : <span className="text-[10px] uppercase tracking-wider font-semibold text-emerald-600 bg-emerald-50 px-2 py-0.5 rounded-full border border-emerald-200 mt-1 inline-block">Đã áp dụng</span>
                    }
                  </div>
                  
                  {/* Delete Overlay Button */}
                  <button 
                    onClick={() => removeDeductMutation.mutate(d.MaKT)}
                    className="absolute right-3 top-1/2 -translate-y-1/2 w-8 h-8 rounded-full bg-red-50 text-red-500 flex items-center justify-center opacity-0 group-hover:opacity-100 transition-opacity hover:bg-red-100"
                    title="Xóa khấu trừ"
                  >
                    <Trash2 className="w-4 h-4" />
                  </button>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
