"use client";

import { useState } from "react";
import { 
  Users, 
  UserPlus, 
  FileWarning, 
  BedDouble, 
  CircleDollarSign,
  Clock,
  Loader2,
  ChevronRight
} from "lucide-react";
import { cn } from "@/lib/utils";
import { useQuery } from "@tanstack/react-query";
import { employeeService } from "@/services/employee.service";
import { contractService } from "@/services/contract.service";
import { leaveService } from "@/services/leave.service";
import { payrollService } from "@/services/payroll.service";
import { attendanceService } from "@/services/attendance.service";
import { masterDataService } from "@/services/masterData.service";
import { useAuthStore } from "@/store/useAuthStore";
import { 
  PieChart, Pie, Cell, Tooltip, Legend, ResponsiveContainer,
  BarChart, Bar, XAxis, YAxis, CartesianGrid
} from 'recharts';
import { formatMoney } from "@/lib/utils";

export default function DashboardPage() {
  const [warningPage, setWarningPage] = useState(1);
  const { data: empData, isLoading: empLoading } = useQuery({ queryKey: ['employees'], queryFn: () => employeeService.getEmployees() });
  const { data: contractData, isLoading: contractLoading } = useQuery({ queryKey: ['contracts'], queryFn: () => contractService.getContracts() });
  const { data: leaveData, isLoading: leaveLoading } = useQuery({ queryKey: ['leaves'], queryFn: () => leaveService.getLeaves() });
  const { data: payrollData, isLoading: payrollLoading } = useQuery({ queryKey: ['payroll'], queryFn: () => payrollService.getPayroll() });
  const { data: attendanceData, isLoading: attendanceLoading } = useQuery({ queryKey: ['attendance'], queryFn: () => attendanceService.getAttendance() });
  const { data: deptData, isLoading: deptLoading } = useQuery({ queryKey: ['departments'], queryFn: () => masterDataService.getDepartments() });

  const { user } = useAuthStore();
  const isEmployee = user?.role === 'EMPLOYEE';

  const isLoading = empLoading || contractLoading || leaveLoading || payrollLoading || attendanceLoading || deptLoading;

  const employees = empData?.data || [];
  const contracts = contractData?.data || [];
  const leaves = leaveData?.data || [];
  const payrolls = payrollData?.data || [];
  const attendances = attendanceData?.data || [];
  const departments = deptData || [];

  const deptMap = departments.reduce((acc: any, dept: any) => {
    acc[dept.id || dept.MaPB] = dept.name || dept.TenPB;
    return acc;
  }, {});

  // Calculate stats
  const totalEmployees = employees.length;
  const maleCount = employees.filter((emp: any) => emp.GioiTinh === 'M').length;
  const femaleCount = employees.filter((emp: any) => emp.GioiTinh === 'F').length;
  const otherCount = employees.filter((emp: any) => emp.GioiTinh === 'O').length;
  const activeContracts = contracts.filter(c => c.status === 'A').length;
  const expiringContracts = contracts.filter(c => c.status === 'E').length;
  
  const today = new Date().toISOString().split('T')[0];
  const leavesToday = leaves.filter(l => l.status === 'A' && l.startDate <= today && l.endDate >= today).length;

  const totalPayroll = payrolls.reduce((acc, curr) => acc + Number(curr.netSalary), 0);

  const stats = [
    { title: "Tổng nhân viên", value: totalEmployees.toString(), change: `${maleCount} Nam - ${femaleCount} Nữ${otherCount > 0 ? ` - ${otherCount} Khác` : ''}`, changeType: "neutral", icon: Users, color: "bg-indigo-100 text-indigo-700" },
    { title: "Hợp đồng hiệu lực", value: activeContracts.toString(), change: "Đang làm việc", changeType: "neutral", icon: UserPlus, color: "bg-emerald-100 text-emerald-700" },
    { title: "Hợp đồng sắp/đã hết hạn", value: expiringContracts.toString(), change: "Cần xử lý", changeType: "negative", icon: FileWarning, color: "bg-amber-100 text-amber-700" },
    { title: "Nghỉ phép hôm nay", value: leavesToday.toString(), change: "Đã duyệt", changeType: "neutral", icon: BedDouble, color: "bg-blue-100 text-blue-700" },
    { title: "Tổng quỹ lương", value: (totalPayroll / 1000000).toFixed(1) + "M ₫", change: "Theo bảng lương", changeType: "neutral", icon: CircleDollarSign, color: "bg-emerald-100 text-emerald-700" },

  ];

  // Chart Data Processing
  const departmentCount: Record<string, number> = {};
  employees.forEach((emp: any) => {
    const deptId = emp.MaPB;
    const deptName = deptId ? (deptMap[deptId] || deptId) : 'Chưa phân bổ';
    departmentCount[deptName] = (departmentCount[deptName] || 0) + 1;
  });
  const pieData = Object.keys(departmentCount).map(key => ({
    name: key,
    value: departmentCount[key],
    percent: totalEmployees > 0 ? departmentCount[key] / totalEmployees : 0
  }));
  const PIE_COLORS = ['#6366f1', '#10b981', '#f43f5e', '#f59e0b', '#8b5cf6', '#0ea5e9', '#ec4899', '#14b8a6'];

  const payrollByDept: Record<string, number> = {};
  payrolls.forEach((p: any) => {
    const deptId = p.dept;
    const deptName = deptId ? (deptMap[deptId] || deptId) : 'Chưa phân bổ';
    payrollByDept[deptName] = (payrollByDept[deptName] || 0) + Number(p.netSalary);
  });
  const barData = Object.keys(payrollByDept).map(key => ({
    name: key,
    amount: payrollByDept[key]
  }));

  if (isLoading) {
    return (
      <div className="flex flex-col items-center justify-center h-[50vh] text-slate-500">
        <Loader2 className="w-8 h-8 animate-spin text-indigo-600 mb-4" />
        <p>Đang tải dữ liệu tổng quan...</p>
      </div>
    );
  }

  if (isEmployee) {
    const myLeaves = leaves.filter(l => (l as any).empId === user?.empId || l.empName === user?.username || l.empName === user?.empId);
    const myAttendances = attendances.filter(a => a.empId === user?.empId);
    const myPayrolls = payrolls.filter((p: any) => p.empId === user?.empId).sort((a: any, b: any) => {
      if (a.year !== b.year) return (b.year || 0) - (a.year || 0);
      return (b.month || 0) - (a.month || 0);
    });
    const myContract = contracts.find(c => c.empId === user?.empId && c.status !== 'T');
    
    const approvedLeaves = myLeaves.filter(l => l.status === 'A').reduce((acc, curr) => acc + curr.days, 0);
    const latestPayroll = myPayrolls.length > 0 ? myPayrolls[0] : null;
    const abnormalAttendances = myAttendances.filter(a => a.status === 'OM' || a.status === 'NP' || a.status === 'KP').length;

    const empStats = [
      { title: "Nghỉ phép đã duyệt", value: `${approvedLeaves} ngày`, change: "Trong năm", changeType: "neutral", icon: BedDouble, color: "bg-blue-100 text-blue-700" },
      { title: "Chấm công bất thường", value: `${abnormalAttendances} lần`, change: "Ốm/Đi muộn/Không phép", changeType: "negative", icon: Clock, color: "bg-amber-100 text-amber-700" },
      { title: "Lương tháng gần nhất", value: latestPayroll ? formatMoney(latestPayroll.netSalary) : "0 ₫", change: latestPayroll ? `Tháng ${latestPayroll.month}` : "Chưa có", changeType: "positive", icon: CircleDollarSign, color: "bg-emerald-100 text-emerald-700" },
      { title: "Hợp đồng", value: myContract ? myContract.type : "Chưa có", change: myContract?.endDate ? `Hết hạn: ${myContract.endDate}` : "Không thời hạn", changeType: "neutral", icon: FileWarning, color: "bg-indigo-100 text-indigo-700" },
    ];

    return (
      <div className="space-y-6">
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-2xl font-bold text-slate-900">Xin chào, {user?.username}!</h1>
            <p className="text-sm text-slate-500 mt-1">Chào mừng bạn quay trở lại hệ thống HRM.</p>
          </div>
          <div className="text-sm text-slate-500">
            {new Date().toLocaleDateString('vi-VN', { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' })}
          </div>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-4 gap-6">
          {empStats.map((stat, i) => (
            <div key={i} className="bg-white rounded-xl border border-slate-200 p-6 shadow-sm flex items-center justify-between hover:shadow-md transition-shadow">
              <div>
                <p className="text-sm font-medium text-slate-500 mb-1">{stat.title}</p>
                <h3 className="text-xl font-bold text-slate-900">{stat.value}</h3>
                <p className={cn("text-xs mt-1 font-medium", 
                  stat.changeType === 'positive' ? "text-emerald-600" :
                  stat.changeType === 'negative' ? "text-amber-600" :
                  "text-slate-500"
                )}>
                  {stat.change}
                </p>
              </div>
              <div className={cn("w-12 h-12 rounded-full flex items-center justify-center shrink-0", stat.color)}>
                <stat.icon className="w-6 h-6" />
              </div>
            </div>
          ))}
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          <div className="bg-white rounded-xl border border-slate-200 shadow-sm overflow-hidden flex flex-col">
            <div className="px-6 py-4 border-b border-slate-200 bg-slate-50 flex items-center justify-between">
              <h3 className="text-lg font-semibold text-slate-800">Điểm danh gần đây</h3>
              <a href="/attendance" className="text-sm font-medium text-indigo-600 hover:text-indigo-800 transition-colors flex items-center gap-1">
                Xem chi tiết <ChevronRight className="w-4 h-4" />
              </a>
            </div>
            <div className="overflow-x-auto">
              <table className="w-full text-left border-collapse">
                <thead>
                  <tr className="border-b border-slate-200 text-sm text-slate-500">
                    <th className="px-6 py-3 font-medium">Ngày</th>
                    <th className="px-6 py-3 font-medium">Giờ vào</th>
                    <th className="px-6 py-3 font-medium">Giờ ra</th>
                    <th className="px-6 py-3 font-medium">Trạng thái</th>
                  </tr>
                </thead>
                <tbody className="text-sm">
                  {myAttendances.slice(0, 5).map((a, i) => (
                    <tr key={i} className="border-b border-slate-100 hover:bg-slate-50">
                      <td className="px-6 py-4 font-medium text-slate-900">{a.date}</td>
                      <td className="px-6 py-4 font-mono">{a.checkIn || '-'}</td>
                      <td className="px-6 py-4 font-mono">{a.checkOut || '-'}</td>
                      <td className="px-6 py-4">
                        <span className={cn("px-2.5 py-1 rounded-full text-xs font-medium border",
                          a.status === 'DL' ? "bg-emerald-50 text-emerald-700 border-emerald-200" : "bg-amber-50 text-amber-700 border-amber-200"
                        )}>
                          {a.status === 'DL' ? "Đi làm" : a.status === 'NP' ? "Nghỉ phép" : a.status === 'OM' ? "Ốm" : "Khác"}
                        </span>
                      </td>
                    </tr>
                  ))}
                  {myAttendances.length === 0 && (
                    <tr><td colSpan={4} className="px-6 py-8 text-center text-slate-500">Chưa có dữ liệu điểm danh.</td></tr>
                  )}
                </tbody>
              </table>
            </div>
          </div>

          <div className="bg-white rounded-xl border border-slate-200 shadow-sm overflow-hidden flex flex-col">
            <div className="px-6 py-4 border-b border-slate-200 bg-slate-50 flex items-center justify-between">
              <h3 className="text-lg font-semibold text-slate-800">Đơn xin nghỉ phép</h3>
              <a href="/leaves" className="text-sm font-medium text-indigo-600 hover:text-indigo-800 transition-colors flex items-center gap-1">
                Quản lý đơn <ChevronRight className="w-4 h-4" />
              </a>
            </div>
            <div className="overflow-x-auto">
              <table className="w-full text-left border-collapse">
                <thead>
                  <tr className="border-b border-slate-200 text-sm text-slate-500">
                    <th className="px-6 py-3 font-medium">Loại nghỉ</th>
                    <th className="px-6 py-3 font-medium">Thời gian</th>
                    <th className="px-6 py-3 font-medium">Trạng thái</th>
                  </tr>
                </thead>
                <tbody className="text-sm">
                  {myLeaves.slice(0, 5).map((l, i) => (
                    <tr key={i} className="border-b border-slate-100 hover:bg-slate-50">
                      <td className="px-6 py-4 font-medium text-slate-900">{l.type}</td>
                      <td className="px-6 py-4 text-slate-600">{l.startDate} - {l.endDate}</td>
                      <td className="px-6 py-4">
                        <span className={cn(
                          "px-2.5 py-1 rounded-full text-xs font-medium border",
                          l.status === 'A' ? "bg-emerald-50 text-emerald-700 border-emerald-200" :
                          l.status === 'P' ? "bg-amber-50 text-amber-700 border-amber-200" :
                          l.status === 'R' ? "bg-red-50 text-red-700 border-red-200" :
                          "bg-slate-50 text-slate-700 border-slate-200"
                        )}>
                          {l.status === 'A' ? "Đã duyệt" : l.status === 'P' ? "Chờ duyệt" : l.status === 'R' ? "Từ chối" : "Đã hủy"}
                        </span>
                      </td>
                    </tr>
                  ))}
                  {myLeaves.length === 0 && (
                    <tr><td colSpan={3} className="px-6 py-8 text-center text-slate-500">Bạn chưa có đơn nghỉ phép nào.</td></tr>
                  )}
                </tbody>
              </table>
            </div>
          </div>
        </div>
      </div>
    );
  }

  const expiringContractsList = contracts.filter(c => c.status === 'E');
  const totalWarningPages = Math.ceil(expiringContractsList.length / 10);
  const paginatedExpiringContracts = expiringContractsList.slice((warningPage - 1) * 10, warningPage * 10);

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold text-slate-900">Tổng quan hệ thống</h1>
        <div className="text-sm text-slate-500">
          Cập nhật lúc: {new Date().toLocaleTimeString('vi-VN')} {new Date().toLocaleDateString('vi-VN')}
        </div>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-6">
        {stats.map((stat, i) => (
          <div key={i} className="bg-white rounded-xl border border-slate-200 p-6 shadow-sm flex items-center justify-between hover:shadow-md transition-shadow">
            <div>
              <p className="text-sm font-medium text-slate-500 mb-1">{stat.title}</p>
              <h3 className="text-2xl font-bold text-slate-900">{stat.value}</h3>
              <p className={cn("text-xs mt-1 font-medium", 
                stat.changeType === 'positive' ? "text-emerald-600" :
                stat.changeType === 'negative' ? "text-amber-600" :
                "text-slate-500"
              )}>
                {stat.change}
              </p>
            </div>
            <div className={cn("w-12 h-12 rounded-full flex items-center justify-center", stat.color)}>
              <stat.icon className="w-6 h-6" />
            </div>
          </div>
        ))}
      </div>

      <div className="grid grid-cols-1 xl:grid-cols-2 gap-8 mb-8">
        {/* Phân bổ nhân sự Card */}
        <div className="relative overflow-hidden bg-white rounded-3xl border border-slate-100 shadow-[0_8px_30px_rgb(0,0,0,0.04)] hover:shadow-[0_8px_30px_rgb(0,0,0,0.08)] transition-all duration-500 p-7 group flex flex-col">
          <div className="absolute top-0 right-0 w-32 h-32 bg-indigo-50 rounded-bl-full -z-10 opacity-50 group-hover:scale-110 transition-transform duration-500"></div>
          
          <div className="flex items-center justify-between mb-6">
            <div>
              <h3 className="text-lg font-bold text-slate-900 flex items-center gap-2">
                <div className="w-1.5 h-6 bg-indigo-500 rounded-full"></div>
                Phân bổ nhân sự
              </h3>
              <p className="text-sm text-slate-500 mt-1 ml-3.5">Tỷ lệ nhân sự theo phòng ban</p>
            </div>
            <div className="p-2.5 bg-indigo-50 text-indigo-600 rounded-xl">
              <Users className="w-5 h-5" />
            </div>
          </div>
          
          <div style={{ width: '100%', height: 320 }} className="relative mt-4">
            {pieData.length > 0 ? (
              <ResponsiveContainer width="100%" height="100%">
                <PieChart>
                  <Pie
                    data={pieData}
                    cx="50%"
                    cy="45%"
                    innerRadius={70}
                    outerRadius={105}
                    paddingAngle={4}
                    dataKey="value"
                    stroke="none"
                    cornerRadius={6}
                  >
                    {pieData.map((entry, index) => (
                      <Cell key={`cell-${index}`} fill={PIE_COLORS[index % PIE_COLORS.length]} />
                    ))}
                  </Pie>
                  <Tooltip 
                    content={({ active, payload }) => {
                      if (active && payload && payload.length) {
                        const data = payload[0].payload;
                        return (
                          <div className="bg-white/95 backdrop-blur-md p-4 rounded-2xl shadow-[0_20px_25px_-5px_rgb(0,0,0,0.1),0_8px_10px_-6px_rgb(0,0,0,0.1)] border border-slate-100">
                            <p className="text-sm font-semibold text-slate-500 mb-1">{data.name}</p>
                            <p className="text-lg font-bold text-slate-900">{data.value} Nhân sự</p>
                            <div className="flex items-center gap-2 mt-1.5">
                              <div className="w-2 h-2 rounded-full bg-indigo-500"></div>
                              <p className="text-sm font-medium text-indigo-600">Chiếm {((data.percent || 0) * 100).toFixed(1)}% tổng số</p>
                            </div>
                          </div>
                        );
                      }
                      return null;
                    }}
                  />
                  <Legend 
                    layout="horizontal" 
                    verticalAlign="bottom" 
                    align="center"
                    iconType="circle"
                    wrapperStyle={{ fontSize: '13px', fontWeight: 500, paddingTop: '10px' }}
                  />
                </PieChart>
              </ResponsiveContainer>
            ) : (
              <div className="h-full flex flex-col items-center justify-center text-slate-400 space-y-3 bg-slate-50/50 rounded-2xl border border-dashed border-slate-200">
                <Users className="w-10 h-10 text-slate-300" />
                <span className="font-medium">Chưa có dữ liệu nhân sự</span>
              </div>
            )}
            

          </div>
        </div>
        
        {/* Chi phí lương Card */}
        <div className="relative overflow-hidden bg-white rounded-3xl border border-slate-100 shadow-[0_8px_30px_rgb(0,0,0,0.04)] hover:shadow-[0_8px_30px_rgb(0,0,0,0.08)] transition-all duration-500 p-7 group flex flex-col">
          <div className="absolute top-0 right-0 w-32 h-32 bg-emerald-50 rounded-bl-full -z-10 opacity-50 group-hover:scale-110 transition-transform duration-500"></div>
          
          <div className="flex items-center justify-between mb-6">
            <div>
              <h3 className="text-lg font-bold text-slate-900 flex items-center gap-2">
                <div className="w-1.5 h-6 bg-emerald-500 rounded-full"></div>
                Chi phí lương
              </h3>
              <p className="text-sm text-slate-500 mt-1 ml-3.5">Quỹ lương phân bổ theo phòng ban</p>
            </div>
            <div className="p-2.5 bg-emerald-50 text-emerald-600 rounded-xl">
              <CircleDollarSign className="w-5 h-5" />
            </div>
          </div>
          
          <div style={{ width: '100%', height: 320 }} className="relative mt-4">
            {barData.length > 0 ? (
              <ResponsiveContainer width="100%" height="100%">
                <BarChart
                  data={barData}
                  margin={{ top: 10, right: 10, left: 0, bottom: 0 }}
                >
                  <defs>
                    <linearGradient id="colorAmount" x1="0" y1="0" x2="0" y2="1">
                      <stop offset="5%" stopColor="#10b981" stopOpacity={0.9}/>
                      <stop offset="95%" stopColor="#10b981" stopOpacity={0.3}/>
                    </linearGradient>
                  </defs>
                  <CartesianGrid strokeDasharray="4 4" vertical={false} stroke="#f1f5f9" />
                  <XAxis 
                    dataKey="name" 
                    axisLine={false} 
                    tickLine={false} 
                    tick={{fill: '#64748b', fontSize: 13, fontWeight: 500}} 
                    dy={10}
                  />
                  <YAxis 
                    axisLine={false} 
                    tickLine={false} 
                    tick={{fill: '#94a3b8', fontSize: 12, fontWeight: 500}}
                    tickFormatter={(value) => `${(value / 1000000).toFixed(0)}M`}
                    dx={-10}
                    width={45}
                  />
                  <Tooltip 
                    contentStyle={{ borderRadius: '16px', border: 'none', boxShadow: '0 20px 25px -5px rgb(0 0 0 / 0.1), 0 8px 10px -6px rgb(0 0 0 / 0.1)', padding: '12px 20px', backgroundColor: 'rgba(255, 255, 255, 0.95)', backdropFilter: 'blur(8px)' }}
                    itemStyle={{ color: '#1e293b', fontWeight: 600, fontSize: '15px' }}
                    labelStyle={{ color: '#64748b', marginBottom: '4px', fontSize: '13px', fontWeight: 500 }}
                    formatter={(value: any) => [`${(value || 0).toLocaleString('vi-VN')} ₫`, 'Ngân sách']}
                    cursor={{fill: '#f8fafc', radius: 8}}
                  />
                  <Bar 
                    dataKey="amount" 
                    radius={[6, 6, 6, 6]} 
                    barSize={40}
                    fill="url(#colorAmount)"
                  />
                </BarChart>
              </ResponsiveContainer>
            ) : (
              <div className="h-full flex flex-col items-center justify-center text-slate-400 space-y-3 bg-slate-50/50 rounded-2xl border border-dashed border-slate-200">
                <CircleDollarSign className="w-10 h-10 text-slate-300" />
                <span className="font-medium">Chưa có dữ liệu quỹ lương</span>
              </div>
            )}
          </div>
        </div>
      </div>

      <div className="bg-white rounded-xl border border-slate-200 shadow-sm overflow-hidden">
        <div className="px-6 py-4 border-b border-slate-200 bg-slate-50">
          <h3 className="text-lg font-semibold text-slate-800">Cảnh báo: Hợp đồng sắp/đã hết hạn</h3>
        </div>
        <div className="overflow-x-auto">
          <table className="w-full text-left border-collapse">
            <thead>
              <tr className="border-b border-slate-200 text-sm text-slate-500">
                <th className="px-6 py-3 font-medium">Mã HĐ</th>
                <th className="px-6 py-3 font-medium">Họ Tên</th>
                <th className="px-6 py-3 font-medium">Loại HĐ</th>
                <th className="px-6 py-3 font-medium">Ngày Hết Hạn</th>
              </tr>
            </thead>
            <tbody className="text-sm">
              {paginatedExpiringContracts.map(contract => (
                <tr key={contract.id} className="border-b border-slate-100 hover:bg-slate-50 transition-colors">
                  <td className="px-6 py-4 font-medium text-slate-900">{contract.id}</td>
                  <td className="px-6 py-4">{contract.empName}</td>
                  <td className="px-6 py-4"><span className="px-2.5 py-1 rounded-full text-xs font-medium bg-slate-100 text-slate-700">{contract.type}</span></td>
                  <td className="px-6 py-4 text-amber-600 font-medium">{contract.endDate || 'N/A'}</td>
                </tr>
              ))}
              {expiringContractsList.length === 0 && (
                <tr>
                  <td colSpan={4} className="px-6 py-4 text-center text-slate-500">Không có hợp đồng nào sắp hết hạn.</td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
        {expiringContractsList.length > 10 && (
          <div className="p-4 border-t border-slate-200 flex items-center justify-between text-sm text-slate-500 bg-white">
            <div>Hiển thị {(warningPage - 1) * 10 + 1}-{Math.min(warningPage * 10, expiringContractsList.length)} của {expiringContractsList.length} hợp đồng</div>
            <div className="flex items-center gap-1">
              <button 
                onClick={() => setWarningPage(p => Math.max(1, p - 1))}
                disabled={warningPage === 1}
                className="px-3 py-1.5 rounded-md border border-slate-200 hover:bg-slate-50 disabled:opacity-50 transition-colors"
              >Trước</button>
              <button className="px-3 py-1.5 rounded-md bg-indigo-600 text-white font-medium shadow-sm">{warningPage}</button>
              <button 
                onClick={() => setWarningPage(p => Math.min(totalWarningPages, p + 1))}
                disabled={warningPage === totalWarningPages || totalWarningPages === 0}
                className="px-3 py-1.5 rounded-md border border-slate-200 hover:bg-slate-50 disabled:opacity-50 transition-colors"
              >Sau</button>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
