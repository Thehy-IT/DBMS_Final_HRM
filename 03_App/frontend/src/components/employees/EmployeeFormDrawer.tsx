"use client";

import { useState, useEffect } from "react";
import { X, Loader2 } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { cn } from "@/lib/utils";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { masterDataService } from "@/services/masterData.service";
import { employeeService } from "@/services/employee.service";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import * as z from "zod";

const employeeSchema = z.object({
  MaNV: z.string().optional(),
  HoTen: z.string().min(2, "Họ tên quá ngắn").max(100, "Họ tên quá dài"),
  GioiTinh: z.enum(["M", "F", "O"]),
  NgaySinh: z.string().min(1, "Vui lòng chọn ngày sinh"),
  CCCD: z.string().length(12, "CCCD phải gồm đúng 12 số").regex(/^\d+$/, "CCCD chỉ chứa chữ số"),
  SoDienThoai: z.string().regex(/^(0|\+84)[3|5|7|8|9][0-9]{8}$/, "Số điện thoại không hợp lệ"),
  Email: z.string().email("Email không hợp lệ").optional().or(z.literal('')),
  DiaChi: z.string().optional(),
  MaPB: z.string().min(1, "Vui lòng chọn phòng ban"),
  MaCV: z.string().min(1, "Vui lòng chọn chức vụ"),
  NgayVaoLam: z.string().min(1, "Vui lòng chọn ngày vào làm"),
  MaSoThue: z.string().optional().or(z.literal(''))
    .refine(val => !val || ((val.length === 10 || val.length === 13 || val.length === 14) && /^[0-9-]+$/.test(val)), 
      "MST phải có 10, 13 hoặc 14 ký tự (chỉ gồm số và dấu gạch ngang)"),
  SoTaiKhoanNH: z.string().optional(),
  TenNganHang: z.string().optional(),
  SoNguoiPhuThuoc: z.coerce.number().min(0, "Không được nhỏ hơn 0").default(0),
  GhiChu: z.string().optional(),
  NgayNghiViec: z.string().optional().or(z.literal('')),
  TrangThai: z.string()
});

type EmployeeFormValues = z.infer<typeof employeeSchema>;

interface EmployeeFormDrawerProps {
  isOpen: boolean;
  onClose: () => void;
  employeeId?: string | null;
  employee?: any | null;
}

export function EmployeeFormDrawer({ isOpen, onClose, employeeId, employee }: EmployeeFormDrawerProps) {
  const [activeTab, setActiveTab] = useState("general");
  const queryClient = useQueryClient();

  const tabs = [
    { id: "general", label: "Thông tin chung" },
    { id: "contact", label: "Liên hệ" },
    { id: "identity", label: "Định danh" },
    { id: "work", label: "Công việc" },
  ];

  const { data: departments = [] } = useQuery({ queryKey: ['departments'], queryFn: masterDataService.getDepartments, enabled: isOpen });
  const { data: positions = [] } = useQuery({ queryKey: ['positions'], queryFn: masterDataService.getPositions, enabled: isOpen });

  const { register, handleSubmit, reset, formState: { errors } } = useForm<EmployeeFormValues>({
    resolver: zodResolver(employeeSchema),
    defaultValues: {
      MaNV: '', HoTen: '', GioiTinh: 'M', NgaySinh: '', CCCD: '', SoDienThoai: '', Email: '',
      DiaChi: '', MaPB: '', MaCV: '', NgayVaoLam: '', MaSoThue: '', SoTaiKhoanNH: '',
      TenNganHang: '', SoNguoiPhuThuoc: 0, GhiChu: '', NgayNghiViec: '', TrangThai: 'A'
    }
  });

  const { data: employeeData, isLoading: isLoadingEmployee } = useQuery({
    queryKey: ['employee', employeeId],
    queryFn: () => employeeService.getEmployeeById(employeeId!),
    enabled: !!employeeId && isOpen,
  });

  useEffect(() => {
    const actualData = employee || ((employeeData as any)?.data || employeeData);

    if (actualData) {
      reset({
        ...actualData,
        NgaySinh: actualData.NgaySinh ? actualData.NgaySinh.split('T')[0] : '',
        NgayVaoLam: actualData.NgayVaoLam ? actualData.NgayVaoLam.split('T')[0] : '',
        Email: actualData.Email || '',
        DiaChi: actualData.DiaChi || '',
        MaSoThue: actualData.MaSoThue || '',
        SoTaiKhoanNH: actualData.SoTaiKhoanNH || '',
        TenNganHang: actualData.TenNganHang || '',
        SoNguoiPhuThuoc: actualData.SoNguoiPhuThuoc || 0,
        GhiChu: actualData.GhiChu || '',
        NgayNghiViec: actualData.NgayNghiViec ? actualData.NgayNghiViec.split('T')[0] : '',
      });
    } else if (!employeeId && isOpen) {
      reset({
        MaNV: '', HoTen: '', GioiTinh: 'M', NgaySinh: '', CCCD: '', SoDienThoai: '', Email: '',
        DiaChi: '', MaPB: '', MaCV: '', NgayVaoLam: '', MaSoThue: '', SoTaiKhoanNH: '',
        TenNganHang: '', SoNguoiPhuThuoc: 0, GhiChu: '', NgayNghiViec: '', TrangThai: 'A'
      });
    }
  }, [employeeData, employeeId, isOpen, reset]);

  const mutation = useMutation({
    mutationFn: (data: EmployeeFormValues) => {
      return employeeId 
        ? employeeService.updateEmployee(employeeId, data)
        : employeeService.createEmployee(data);
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['employees'] });
      onClose();
      alert("Lưu thông tin nhân viên thành công!");
    },
    onError: (error: any) => {
      alert("Lỗi: " + (error.response?.data?.error || error.message));
    }
  });

  const onSubmit = (data: EmployeeFormValues) => {
    mutation.mutate(data);
  };

  if (!isOpen) return null;

  return (
    <>
      <div className="fixed inset-0 bg-slate-900/40 backdrop-blur-sm z-40 transition-opacity" onClick={onClose} />
      <div className="fixed inset-y-0 right-0 w-full md:w-[600px] bg-white shadow-2xl z-50 flex flex-col animate-in slide-in-from-right duration-300">
        <div className="flex items-center justify-between p-6 border-b border-slate-200">
          <div>
            <h2 className="text-xl font-bold text-slate-900">{employeeId ? 'Sửa Nhân Viên' : 'Thêm Nhân Viên Mới'}</h2>
            <p className="text-sm text-slate-500 mt-1">Nhập thông tin hồ sơ nhân viên</p>
          </div>
          <button onClick={onClose} className="p-2 hover:bg-slate-100 rounded-full text-slate-500 transition-colors">
            <X className="w-5 h-5" />
          </button>
        </div>

        <div className="flex border-b border-slate-200 px-6 pt-2">
          {tabs.map((tab) => (
            <button
              key={tab.id}
              onClick={() => setActiveTab(tab.id)}
              type="button"
              className={cn(
                "px-4 py-3 text-sm font-medium border-b-2 transition-colors",
                activeTab === tab.id 
                  ? "border-indigo-600 text-indigo-600" 
                  : "border-transparent text-slate-500 hover:text-slate-700 hover:border-slate-300"
              )}
            >
              {tab.label}
              {/* Show error indicator dot if this tab has errors */}
              {tab.id === 'general' && (errors.MaNV || errors.HoTen || errors.NgaySinh) && <span className="ml-1 text-red-500 text-xs font-bold">•</span>}
              {tab.id === 'contact' && (errors.SoDienThoai || errors.Email) && <span className="ml-1 text-red-500 text-xs font-bold">•</span>}
              {tab.id === 'identity' && (errors.CCCD) && <span className="ml-1 text-red-500 text-xs font-bold">•</span>}
              {tab.id === 'work' && (errors.MaPB || errors.MaCV || errors.NgayVaoLam) && <span className="ml-1 text-red-500 text-xs font-bold">•</span>}
            </button>
          ))}
        </div>

        <div className="flex-1 overflow-y-auto p-6 bg-slate-50/30">
          {isLoadingEmployee ? (
            <div className="flex justify-center items-center h-full"><Loader2 className="animate-spin text-indigo-600 w-8 h-8" /></div>
          ) : (
            <form id="employee-form" onSubmit={handleSubmit(onSubmit)}>
              <div className={cn("space-y-5", activeTab !== "general" && "hidden")}>
                <div className="grid grid-cols-2 gap-5">
                  <div className="space-y-1.5">
                    <label className="text-sm font-medium text-slate-700">Mã Nhân Viên</label>
                    <Input {...register("MaNV")} placeholder="Tự động tạo (NV000...)" disabled={true} className="bg-slate-100" />
                  </div>
                  <div className="space-y-1.5">
                    <label className="text-sm font-medium text-slate-700">Họ và Tên <span className="text-red-500">*</span></label>
                    <Input {...register("HoTen")} placeholder="Nhập họ và tên..." error={!!errors.HoTen} />
                    {errors.HoTen && <p className="text-xs text-red-500">{errors.HoTen.message}</p>}
                  </div>
                </div>

                <div className="grid grid-cols-2 gap-5">
                  <div className="space-y-1.5">
                    <label className="text-sm font-medium text-slate-700">Giới Tính <span className="text-red-500">*</span></label>
                    <select {...register("GioiTinh")} className={cn("w-full flex h-10 rounded-md border bg-white px-3 py-2 text-sm ring-offset-white file:border-0 file:bg-transparent file:text-sm file:font-medium placeholder:text-slate-500 focus-visible:outline-none focus-visible:ring-2 disabled:cursor-not-allowed disabled:opacity-50", errors.GioiTinh ? "border-red-500 focus-visible:ring-red-500" : "border-slate-200 focus-visible:ring-indigo-600")}>
                      <option value="M">Nam</option>
                      <option value="F">Nữ</option>
                      <option value="O">Khác</option>
                    </select>
                    {errors.GioiTinh && <p className="text-xs text-red-500">{errors.GioiTinh.message}</p>}
                  </div>
                  <div className="space-y-1.5">
                    <label className="text-sm font-medium text-slate-700">Ngày Sinh <span className="text-red-500">*</span></label>
                    <Input type="date" {...register("NgaySinh")} error={!!errors.NgaySinh} />
                    {errors.NgaySinh && <p className="text-xs text-red-500">{errors.NgaySinh.message}</p>}
                  </div>
                  <div className="space-y-1.5">
                    <label className="text-sm font-medium text-slate-700">Số Người Phụ Thuộc</label>
                    <Input type="number" {...register("SoNguoiPhuThuoc")} placeholder="0" error={!!errors.SoNguoiPhuThuoc} />
                    {errors.SoNguoiPhuThuoc && <p className="text-xs text-red-500">{errors.SoNguoiPhuThuoc.message}</p>}
                  </div>
                </div>
                
                <div className="space-y-1.5">
                  <label className="text-sm font-medium text-slate-700">Trạng Thái</label>
                  <select {...register("TrangThai")} className={cn("w-full flex h-10 rounded-md border bg-white px-3 py-2 text-sm ring-offset-white file:border-0 file:bg-transparent file:text-sm file:font-medium placeholder:text-slate-500 focus-visible:outline-none focus-visible:ring-2 disabled:cursor-not-allowed disabled:opacity-50", errors.TrangThai ? "border-red-500 focus-visible:ring-red-500" : "border-slate-200 focus-visible:ring-indigo-600")}>
                    <option value="A">Đang làm việc</option>
                    <option value="I">Nghỉ việc</option>
                    <option value="S">Đình chỉ</option>
                  </select>
                  {errors.TrangThai && <p className="text-xs text-red-500">{errors.TrangThai.message}</p>}
                </div>
              </div>

              <div className={cn("space-y-5", activeTab !== "contact" && "hidden")}>
                <div className="grid grid-cols-2 gap-5">
                  <div className="space-y-1.5">
                    <label className="text-sm font-medium text-slate-700">Số Điện Thoại <span className="text-red-500">*</span></label>
                    <Input {...register("SoDienThoai")} placeholder="09xx..." error={!!errors.SoDienThoai} />
                    {errors.SoDienThoai && <p className="text-xs text-red-500">{errors.SoDienThoai.message}</p>}
                  </div>
                  <div className="space-y-1.5">
                    <label className="text-sm font-medium text-slate-700">Email</label>
                    <Input type="email" {...register("Email")} placeholder="nguyenvana@gmail.com" error={!!errors.Email} />
                    {errors.Email && <p className="text-xs text-red-500">{errors.Email.message}</p>}
                  </div>
                </div>
                <div className="space-y-1.5">
                  <label className="text-sm font-medium text-slate-700">Địa Chỉ Hiện Tại</label>
                  <Input {...register("DiaChi")} placeholder="Số nhà, đường, quận/huyện, tỉnh/TP..." />
                  {errors.DiaChi && <p className="text-xs text-red-500">{errors.DiaChi.message}</p>}
                </div>
              </div>

              <div className={cn("space-y-5", activeTab !== "identity" && "hidden")}>
                <div className="space-y-1.5">
                  <label className="text-sm font-medium text-slate-700">Căn Cước Công Dân <span className="text-red-500">*</span></label>
                  <Input {...register("CCCD")} placeholder="12 chữ số..." error={!!errors.CCCD} />
                  {errors.CCCD && <p className="text-xs text-red-500">{errors.CCCD.message}</p>}
                </div>
                <div className="grid grid-cols-2 gap-5">
                  <div className="space-y-1.5">
                    <label className="text-sm font-medium text-slate-700">Mã Số Thuế (TNCN)</label>
                    <Input {...register("MaSoThue")} placeholder="Nhập MST..." error={!!errors.MaSoThue} />
                    {errors.MaSoThue && <p className="text-xs text-red-500">{errors.MaSoThue.message}</p>}
                  </div>
                  <div className="space-y-1.5">
                    <label className="text-sm font-medium text-slate-700">Số Tài Khoản Ngân Hàng</label>
                    <Input {...register("SoTaiKhoanNH")} placeholder="VD: 1903..." />
                  </div>
                  <div className="space-y-1.5">
                    <label className="text-sm font-medium text-slate-700">Tên Ngân Hàng</label>
                    <Input {...register("TenNganHang")} placeholder="VD: Techcombank, Vietcombank..." />
                  </div>
                </div>
              </div>

              <div className={cn("space-y-5", activeTab !== "work" && "hidden")}>
                <div className="grid grid-cols-2 gap-5">
                  <div className="space-y-1.5">
                    <label className="text-sm font-medium text-slate-700">Phòng Ban <span className="text-red-500">*</span></label>
                    <select {...register("MaPB")} className={cn("w-full flex h-10 rounded-md border bg-white px-3 py-2 text-sm ring-offset-white file:border-0 file:bg-transparent file:text-sm file:font-medium placeholder:text-slate-500 focus-visible:outline-none focus-visible:ring-2 disabled:cursor-not-allowed disabled:opacity-50", errors.MaPB ? "border-red-500 focus-visible:ring-red-500" : "border-slate-200 focus-visible:ring-indigo-600")}>
                      <option value="">-- Chọn phòng ban --</option>
                      {departments.map((dept: any) => (
                        <option key={dept.id} value={dept.id}>{dept.name}</option>
                      ))}
                    </select>
                    {errors.MaPB && <p className="text-xs text-red-500">{errors.MaPB.message}</p>}
                  </div>
                  <div className="space-y-1.5">
                    <label className="text-sm font-medium text-slate-700">Chức Vụ <span className="text-red-500">*</span></label>
                    <select {...register("MaCV")} className={cn("w-full flex h-10 rounded-md border bg-white px-3 py-2 text-sm ring-offset-white file:border-0 file:bg-transparent file:text-sm file:font-medium placeholder:text-slate-500 focus-visible:outline-none focus-visible:ring-2 disabled:cursor-not-allowed disabled:opacity-50", errors.MaCV ? "border-red-500 focus-visible:ring-red-500" : "border-slate-200 focus-visible:ring-indigo-600")}>
                      <option value="">-- Chọn chức vụ --</option>
                      {positions.map((pos: any) => (
                        <option key={pos.id} value={pos.id}>{pos.name}</option>
                      ))}
                    </select>
                    {errors.MaCV && <p className="text-xs text-red-500">{errors.MaCV.message}</p>}
                  </div>
                </div>
                <div className="grid grid-cols-2 gap-5">
                  <div className="space-y-1.5">
                    <label className="text-sm font-medium text-slate-700">Ngày Vào Làm <span className="text-red-500">*</span></label>
                    <Input type="date" {...register("NgayVaoLam")} error={!!errors.NgayVaoLam} />
                    {errors.NgayVaoLam && <p className="text-xs text-red-500">{errors.NgayVaoLam.message}</p>}
                  </div>
                  <div className="space-y-1.5">
                    <label className="text-sm font-medium text-slate-700">Ngày Nghỉ Việc</label>
                    <Input type="date" {...register("NgayNghiViec")} />
                  </div>
                </div>
                <div className="space-y-1.5">
                  <label className="text-sm font-medium text-slate-700">Ghi Chú</label>
                  <textarea {...register("GhiChu")} className="w-full flex min-h-[80px] rounded-md border border-slate-200 bg-white px-3 py-2 text-sm placeholder:text-slate-500 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-indigo-600 disabled:cursor-not-allowed disabled:opacity-50" placeholder="Ghi chú thêm về nhân viên này..." />
                </div>
              </div>
            </form>
          )}
        </div>

        <div className="p-6 border-t border-slate-200 bg-slate-50 flex justify-end gap-3">
          <Button variant="outline" onClick={onClose} type="button">Hủy bỏ</Button>
          <Button type="submit" form="employee-form" disabled={mutation.isPending || isLoadingEmployee} className="bg-indigo-600 hover:bg-indigo-700">
            {mutation.isPending ? <Loader2 className="w-4 h-4 mr-2 animate-spin" /> : null}
            {employeeId ? 'Cập nhật' : 'Lưu nhân viên'}
          </Button>
        </div>
      </div>
    </>
  );
}
