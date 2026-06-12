"use client";

import { useState, useEffect } from "react";
import { X, Loader2 } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { attendanceService, Attendance } from "@/services/attendance.service";
import { employeeService } from "@/services/employee.service";

interface AttendanceFormDrawerProps {
  isOpen: boolean;
  onClose: () => void;
  attendanceData?: Attendance | null;
}

export function AttendanceFormDrawer({ isOpen, onClose, attendanceData }: AttendanceFormDrawerProps) {
  const queryClient = useQueryClient();

  const { data: employeesData } = useQuery({
    queryKey: ['employees'],
    queryFn: () => employeeService.getEmployees(),
    enabled: isOpen
  });
  const employees = employeesData?.data || [];

  const [formData, setFormData] = useState<Partial<Attendance>>({
    id: '',
    empId: '',
    date: new Date().toISOString().split('T')[0],
    checkIn: '',
    checkOut: '',
    status: 'DL',
    notes: ''
  });

  useEffect(() => {
    if (attendanceData) {
      setFormData({
        ...attendanceData,
      });
    } else {
      setFormData({
        id: '',
        empId: '',
        date: new Date().toISOString().split('T')[0],
        checkIn: '',
        checkOut: '',
        status: 'DL',
        notes: ''
      });
    }
  }, [attendanceData, isOpen]);

  const mutation = useMutation({
    mutationFn: async (data: Partial<Attendance>): Promise<any> => {
      // Create and Update use the same stored procedure logic through API
      // If it exists, update, else create.
      const payload = {
        MaNV: data.empId,
        NgayCham: data.date,
        TrangThai: data.status,
        GioVao: data.checkIn || null,
        GioRa: data.checkOut || null,
        GhiChu: data.notes
      };

      if (data.id) {
        return attendanceService.updateAttendance(data.id, payload);
      }
      return attendanceService.createAttendance(payload);
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['attendance'] });
      onClose();
    }
  });

  const handleChange = (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement | HTMLTextAreaElement>) => {
    const { name, value } = e.target;
    setFormData(prev => ({ ...prev, [name]: value }));
  };

  const handleSubmit = () => {
    mutation.mutate(formData);
  };

  if (!isOpen) return null;

  return (
    <>
      <div className="fixed inset-0 bg-slate-900/40 backdrop-blur-sm z-40 transition-opacity" onClick={onClose} />
      
      <div className="fixed inset-y-0 right-0 w-full md:w-[450px] bg-white shadow-2xl z-50 flex flex-col animate-in slide-in-from-right duration-300">
        <div className="flex items-center justify-between p-6 border-b border-slate-200">
          <div>
            <h2 className="text-xl font-bold text-slate-900">{attendanceData ? 'Sửa Chấm Công' : 'Thêm Chấm Công'}</h2>
            <p className="text-sm text-slate-500 mt-1">Cập nhật giờ vào/ra của nhân viên</p>
          </div>
          <button onClick={onClose} className="p-2 hover:bg-slate-100 rounded-full text-slate-500 transition-colors">
            <X className="w-5 h-5" />
          </button>
        </div>

        <div className="flex-1 overflow-y-auto p-6 bg-slate-50/30">
          <div className="space-y-5">
            <div className="space-y-1.5">
              <label className="text-sm font-medium text-slate-700">Nhân Viên <span className="text-red-500">*</span></label>
              <select name="empId" value={formData.empId} onChange={handleChange} disabled={!!attendanceData} className="flex h-10 w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-indigo-600 disabled:bg-slate-100">
                <option value="">-- Chọn nhân viên --</option>
                {employees.map((emp: any) => (
                  <option key={emp.MaNV} value={emp.MaNV}>{emp.MaNV} - {emp.HoTen}</option>
                ))}
              </select>
            </div>

            <div className="space-y-1.5">
              <label className="text-sm font-medium text-slate-700">Ngày Chấm <span className="text-red-500">*</span></label>
              <Input type="date" name="date" value={formData.date} onChange={handleChange} disabled={!!attendanceData} className={attendanceData ? "bg-slate-100" : ""} />
            </div>

            <div className="grid grid-cols-2 gap-5">
              <div className="space-y-1.5">
                <label className="text-sm font-medium text-slate-700">Giờ Vào</label>
                <Input type="time" name="checkIn" value={formData.checkIn || ''} onChange={handleChange} />
              </div>
              <div className="space-y-1.5">
                <label className="text-sm font-medium text-slate-700">Giờ Ra</label>
                <Input type="time" name="checkOut" value={formData.checkOut || ''} onChange={handleChange} />
              </div>
            </div>

            <div className="space-y-1.5">
              <label className="text-sm font-medium text-slate-700">Trạng Thái <span className="text-red-500">*</span></label>
              <select name="status" value={formData.status} onChange={handleChange} className="flex h-10 w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-indigo-600">
                <option value="DL">Đi làm</option>
                <option value="WFH">Làm từ xa</option>
                <option value="CX">Công tác xa</option>
                <option value="NP">Nghỉ phép</option>
                <option value="OM">Ốm</option>
                <option value="KP">Không phép</option>
                <option value="NG">Nghỉ lễ</option>
              </select>
            </div>

            <div className="space-y-1.5">
              <label className="text-sm font-medium text-slate-700">Ghi Chú</label>
              <textarea 
                name="notes" 
                value={formData.notes || ''} 
                onChange={handleChange} 
                rows={3}
                className="flex w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-indigo-600"
                placeholder="Nhập ghi chú..."
              />
            </div>
          </div>
        </div>

        <div className="p-6 border-t border-slate-200 bg-white flex items-center justify-end gap-3 shadow-[0_-4px_6px_-1px_rgba(0,0,0,0.05)]">
          <Button variant="ghost" onClick={onClose} disabled={mutation.isPending}>Hủy</Button>
          <Button onClick={handleSubmit} disabled={mutation.isPending}>
            {mutation.isPending && <Loader2 className="w-4 h-4 mr-2 animate-spin" />}
            {attendanceData ? 'Cập nhật' : 'Thêm Chấm Công'}
          </Button>
        </div>
      </div>
    </>
  );
}
