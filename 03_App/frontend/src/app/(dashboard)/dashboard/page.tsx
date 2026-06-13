"use client";

import { 
  Users, 
  UserPlus, 
  FileWarning, 
  BedDouble, 
  CircleDollarSign,
  Clock,
  Loader2
} from "lucide-react";
import { cn } from "@/lib/utils";
import { useQuery } from "@tanstack/react-query";
import { employeeService } from "@/services/employee.service";
import { contractService } from "@/services/contract.service";
import { leaveService } from "@/services/leave.service";
import { payrollService } from "@/services/payroll.service";
import { 
  PieChart, Pie, Cell, Tooltip, Legend, ResponsiveContainer,
  BarChart, Bar, XAxis, YAxis, CartesianGrid
} from 'recharts';

export default function DashboardPage() {
  const { data: empData, isLoading: empLoading } = useQuery({ queryKey: ['employees'], queryFn: () => employeeService.getEmployees() });
  const { data: contractData, isLoading: contractLoading } = useQuery({ queryKey: ['contracts'], queryFn: () => contractService.getContracts() });
  const { data: leaveData, isLoading: leaveLoading } = useQuery({ queryKey: ['leaves'], queryFn: () => leaveService.getLeaves() });
  const { data: payrollData, isLoading: payrollLoading } = useQuery({ queryKey: ['payroll'], queryFn: () => payrollService.getPayroll() });

  const isLoading = empLoading || contractLoading || leaveLoading || payrollLoading;

  const employees = empData?.data || [];
  const contracts = contractData?.data || [];
  const leaves = leaveData?.data || [];
  const payrolls = payrollData?.data || [];

  // Calculate stats
  const totalEmployees = employees.length;
  const activeContracts = contracts.filter(c => c.status === 'A').length;
  const expiringContracts = contracts.filter(c => c.status === 'E').length;
  
  const today = new Date().toISOString().split('T')[0];
  const leavesToday = leaves.filter(l => l.status === 'A' && l.startDate <= today && l.endDate >= today).length;

  const totalPayroll = payrolls.reduce((acc, curr) => acc + Number(curr.netSalary), 0);

  const stats = [
    { title: "Tổng nhân viên", value: totalEmployees.toString(), change: "Tất cả", changeType: "positive", icon: Users, color: "bg-indigo-100 text-indigo-700" },
    { title: "Hợp đồng hiệu lực", value: activeContracts.toString(), change: "Đang làm việc", changeType: "neutral", icon: UserPlus, color: "bg-emerald-100 text-emerald-700" },
    { title: "Hợp đồng sắp/đã hết hạn", value: expiringContracts.toString(), change: "Cần xử lý", changeType: "negative", icon: FileWarning, color: "bg-amber-100 text-amber-700" },
    { title: "Nghỉ phép hôm nay", value: leavesToday.toString(), change: "Đã duyệt", changeType: "neutral", icon: BedDouble, color: "bg-blue-100 text-blue-700" },
    { title: "Tổng quỹ lương", value: (totalPayroll / 1000000).toFixed(1) + "M ₫", change: "Theo bảng lương", changeType: "neutral", icon: CircleDollarSign, color: "bg-emerald-100 text-emerald-700" },
    { title: "Hệ thống trạng thái", value: "Online", change: "Hoạt động tốt", changeType: "positive", icon: Clock, color: "bg-purple-100 text-purple-700" },
  ];

  // Chart Data Processing
  const departmentCount: Record<string, number> = {};
  employees.forEach(emp => {
    const dept = emp.MaPB || 'Chưa phân bổ';
    departmentCount[dept] = (departmentCount[dept] || 0) + 1;
  });
  const pieData = Object.keys(departmentCount).map(key => ({
    name: key,
    value: departmentCount[key]
  }));
  const PIE_COLORS = ['#4f46e5', '#10b981', '#f59e0b', '#ef4444', '#8b5cf6', '#06b6d4', '#64748b'];

  const payrollByDept: Record<string, number> = {};
  payrolls.forEach(p => {
    const dept = p.dept || 'Chưa phân bổ';
    payrollByDept[dept] = (payrollByDept[dept] || 0) + Number(p.netSalary);
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

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <div className="bg-white rounded-xl border border-slate-200 shadow-sm p-6">
          <h3 className="text-lg font-semibold text-slate-800 mb-4">Phân bổ nhân sự theo phòng ban</h3>
          <div className="h-72 w-full">
            {pieData.length > 0 ? (
              <ResponsiveContainer width="100%" height="100%">
                <PieChart>
                  <Pie
                    data={pieData}
                    cx="50%"
                    cy="50%"
                    innerRadius={60}
                    outerRadius={100}
                    paddingAngle={5}
                    dataKey="value"
                  >
                    {pieData.map((entry, index) => (
                      <Cell key={`cell-${index}`} fill={PIE_COLORS[index % PIE_COLORS.length]} />
                    ))}
                  </Pie>
                  <Tooltip />
                  <Legend />
                </PieChart>
              </ResponsiveContainer>
            ) : (
              <div className="h-full flex items-center justify-center text-slate-400">Không có dữ liệu nhân sự</div>
            )}
          </div>
        </div>
        
        <div className="bg-white rounded-xl border border-slate-200 shadow-sm p-6">
          <h3 className="text-lg font-semibold text-slate-800 mb-4">Chi phí lương theo phòng ban</h3>
          <div className="h-72 w-full">
            {barData.length > 0 ? (
              <ResponsiveContainer width="100%" height="100%">
                <BarChart
                  data={barData}
                  margin={{ top: 20, right: 30, left: 20, bottom: 5 }}
                >
                  <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="#e2e8f0" />
                  <XAxis dataKey="name" axisLine={false} tickLine={false} tick={{fill: '#64748b'}} />
                  <YAxis 
                    axisLine={false} 
                    tickLine={false} 
                    tick={{fill: '#64748b'}}
                    tickFormatter={(value) => `${(value / 1000000).toFixed(0)}M`}
                  />
                  <Tooltip 
                    formatter={(value: any) => [`${(value || 0).toLocaleString('vi-VN')} ₫`, 'Chi phí']}
                    cursor={{fill: '#f1f5f9'}}
                  />
                  <Bar dataKey="amount" fill="#4f46e5" radius={[4, 4, 0, 0]} barSize={40} />
                </BarChart>
              </ResponsiveContainer>
            ) : (
              <div className="h-full flex items-center justify-center text-slate-400">Không có dữ liệu chi phí lương</div>
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
                <th className="px-6 py-3 font-medium text-right">Hành động</th>
              </tr>
            </thead>
            <tbody className="text-sm">
              {contracts.filter(c => c.status === 'E').map(contract => (
                <tr key={contract.id} className="border-b border-slate-100 hover:bg-slate-50 transition-colors">
                  <td className="px-6 py-4 font-medium text-slate-900">{contract.id}</td>
                  <td className="px-6 py-4">{contract.empName}</td>
                  <td className="px-6 py-4"><span className="px-2.5 py-1 rounded-full text-xs font-medium bg-slate-100 text-slate-700">{contract.type}</span></td>
                  <td className="px-6 py-4 text-amber-600 font-medium">{contract.endDate || 'N/A'}</td>
                  <td className="px-6 py-4 text-right">
                    <button className="text-indigo-600 hover:text-indigo-800 font-medium">Gia hạn</button>
                  </td>
                </tr>
              ))}
              {contracts.filter(c => c.status === 'E').length === 0 && (
                <tr>
                  <td colSpan={5} className="px-6 py-4 text-center text-slate-500">Không có hợp đồng nào sắp hết hạn.</td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}
