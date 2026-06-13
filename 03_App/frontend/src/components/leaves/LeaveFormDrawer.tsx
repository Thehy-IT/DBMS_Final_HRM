import { useState, useEffect } from "react";
import { X, Save, Loader2 } from "lucide-react";
import { Button } from "@/components/ui/button";
import { cn } from "@/lib/utils";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { leaveService } from "@/services/leave.service";
import { masterDataService } from "@/services/masterData.service";

interface LeaveFormDrawerProps {
  isOpen: boolean;
  onClose: () => void;
}

export function LeaveFormDrawer({ isOpen, onClose }: LeaveFormDrawerProps) {
  const [MaNV, setMaNV] = useState("");
  const [MaLoaiNghi, setMaLoaiNghi] = useState("");
  const [NgayBatDau, setNgayBatDau] = useState("");
  const [NgayKetThuc, setNgayKetThuc] = useState("");
  const [LyDo, setLyDo] = useState("");

  const queryClient = useQueryClient();

  const { data: leaveTypesData } = useQuery({
    queryKey: ['leaveTypes'],
    queryFn: () => masterDataService.getLeaveTypes(),
  });

  const leaveTypes = leaveTypesData || [];

  const mutation = useMutation({
    mutationFn: async (data: any) => {
      return leaveService.createLeave(data);
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['leaves'] });
      onClose();
      setMaNV("");
      setMaLoaiNghi("");
      setNgayBatDau("");
      setNgayKetThuc("");
      setLyDo("");
      alert("Tạo đơn nghỉ phép thành công!");
    },
    onError: (error: any) => {
      console.error("Lỗi tạo đơn:", error?.response?.data || error);
      alert("Lỗi: " + (error?.response?.data?.error || error?.response?.data?.message || error.message));
    }
  });

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    mutation.mutate({ MaNV, MaLoaiNghi, NgayBatDau, NgayKetThuc, LyDo });
  };

  return (
    <>
      {isOpen && (
        <div className="fixed inset-0 bg-slate-900/50 z-40 transition-opacity" onClick={onClose} />
      )}

      <div
        className={cn(
          "fixed inset-y-0 right-0 w-full sm:w-[450px] bg-white shadow-2xl z-50 transform transition-transform duration-300 ease-in-out flex flex-col",
          isOpen ? "translate-x-0" : "translate-x-full"
        )}
      >
        <div className="flex items-center justify-between px-6 py-4 border-b border-slate-200">
          <h2 className="text-lg font-semibold text-slate-800">Tạo Đơn Nghỉ Phép</h2>
          <button onClick={onClose} className="p-2 text-slate-400 hover:text-slate-600 rounded-full hover:bg-slate-100 transition-colors">
            <X className="w-5 h-5" />
          </button>
        </div>

        <div className="flex-1 overflow-y-auto p-6">
          <form id="leave-form" onSubmit={handleSubmit} className="space-y-5">
            <div>
              <label className="block text-sm font-medium text-slate-700 mb-1">Mã Nhân Viên *</label>
              <input 
                type="text" required 
                value={MaNV} onChange={e => setMaNV(e.target.value)}
                className="w-full px-3 py-2 border border-slate-300 rounded-md focus:outline-none focus:ring-2 focus:ring-indigo-600"
                placeholder="VD: NV0001"
              />
            </div>

            <div>
              <label className="block text-sm font-medium text-slate-700 mb-1">Loại Nghỉ Phép *</label>
              <select required value={MaLoaiNghi} onChange={e => setMaLoaiNghi(e.target.value)} className="w-full px-3 py-2 border border-slate-300 rounded-md focus:outline-none focus:ring-2 focus:ring-indigo-600 bg-white">
                <option value="">Chọn loại nghỉ phép</option>
                {leaveTypes.map(t => (
                  <option key={t.id} value={t.id}>{t.name}</option>
                ))}
              </select>
            </div>

            <div className="grid grid-cols-2 gap-4">
              <div>
                <label className="block text-sm font-medium text-slate-700 mb-1">Ngày Bắt Đầu *</label>
                <input 
                  type="date" required
                  value={NgayBatDau} onChange={e => setNgayBatDau(e.target.value)}
                  className="w-full px-3 py-2 border border-slate-300 rounded-md focus:outline-none focus:ring-2 focus:ring-indigo-600"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-slate-700 mb-1">Ngày Kết Thúc *</label>
                <input 
                  type="date" required
                  value={NgayKetThuc} onChange={e => setNgayKetThuc(e.target.value)}
                  className="w-full px-3 py-2 border border-slate-300 rounded-md focus:outline-none focus:ring-2 focus:ring-indigo-600"
                />
              </div>
            </div>

            <div>
              <label className="block text-sm font-medium text-slate-700 mb-1">Lý Do Nghỉ</label>
              <textarea 
                value={LyDo} onChange={e => setLyDo(e.target.value)}
                className="w-full px-3 py-2 border border-slate-300 rounded-md focus:outline-none focus:ring-2 focus:ring-indigo-600"
                rows={3}
              />
            </div>
          </form>
        </div>

        <div className="p-6 border-t border-slate-200 bg-slate-50 flex justify-end gap-3">
          <Button type="button" variant="outline" onClick={onClose}>Hủy bỏ</Button>
          <Button type="submit" form="leave-form" disabled={mutation.isPending}>
            {mutation.isPending ? <Loader2 className="w-4 h-4 mr-2 animate-spin" /> : <Save className="w-4 h-4 mr-2" />}
            Lưu lại
          </Button>
        </div>
      </div>
    </>
  );
}
