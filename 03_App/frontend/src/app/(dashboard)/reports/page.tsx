"use client";

import { useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { payrollService } from "@/services/payroll.service";
import { masterDataService } from "@/services/masterData.service";
import { employeeService } from "@/services/employee.service";
import { 
  BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip as RechartsTooltip, Legend, ResponsiveContainer,
  LineChart, Line, AreaChart, Area, ComposedChart
} from 'recharts';
import { 
  TrendingUp, 
  Wallet, 
  Building2, 
  ShieldCheck, 
  FileSpreadsheet, 
  Download, 
  Loader2,
  CalendarDays
} from "lucide-react";
import { Button } from "@/components/ui/button";
import { formatMoney, cn } from "@/lib/utils";
import { exportToExcel } from "@/lib/excel";

export default function ReportsPage() {
  const [activeTab, setActiveTab] = useState<'fund' | 'tax' | 'insurance' | 'trend'>('fund');
  const [selectedMonth, setSelectedMonth] = useState<string>("");

  const { data: payrollData, isLoading: payrollLoading } = useQuery({ 
    queryKey: ['payroll'], 
    queryFn: () => payrollService.getPayroll() 
  });
  
  const { data: deptData } = useQuery({ 
    queryKey: ['departments'], 
    queryFn: () => masterDataService.getDepartments() 
  });

  const { data: empData } = useQuery({ 
    queryKey: ['employees'], 
    queryFn: () => employeeService.getEmployees() 
  });

  const isLoading = payrollLoading;
  const payrolls = payrollData?.data || [];
  const departments = Array.isArray(deptData) ? deptData : (deptData as any)?.data || [];
  const employees = Array.isArray(empData) ? empData : (empData as any)?.data || [];

  // Get unique months from payrolls
  const availableMonths = Array.from(new Set(payrolls.map(p => p.month))).sort().reverse();
  const currentMonth = selectedMonth || (availableMonths.length > 0 ? availableMonths[0] : "");

  // --- UC-11: Báo cáo quỹ lương theo phòng ban ---
  const payrollByDept = payrolls.filter(p => String(p.month) === String(currentMonth)).reduce((acc: any, curr) => {
    const dept = curr.dept || 'Chưa phân bổ';
    if (!acc[dept]) acc[dept] = 0;
    // Tổng chi phí = Lương gộp + Các khoản bảo hiểm doanh nghiệp đóng (ước tính 21.5% lương đóng BH)
    const bhxh = Number(curr.bhxh) || 0;
    const luongDongBH = bhxh > 0 ? (bhxh / 0.08) : 0;
    const bhxhCty = luongDongBH * 0.215;
    
    acc[dept] += (Number(curr.grossSalary) || 0) + bhxhCty; 
    return acc;
  }, {});

  const fundData = Object.keys(payrollByDept).map(dept => ({
    name: dept,
    'Chi phí lương': payrollByDept[dept]
  })).sort((a, b) => b['Chi phí lương'] - a['Chi phí lương']);

  // --- UC-12: Báo cáo thuế TNCN ---
  const taxByMonth = payrolls.reduce((acc: any, curr) => {
    const m = curr.month || 'Unknown';
    if (!acc[m]) acc[m] = 0;
    acc[m] += (Number(curr.tax) || 0);
    return acc;
  }, {});

  const taxData = Object.keys(taxByMonth).sort().map(month => ({
    month,
    'Thuế TNCN': taxByMonth[month]
  }));

  const currentMonthTax = payrolls.filter(p => String(p.month) === String(currentMonth)).map(p => ({
    empId: p.empId,
    name: p.name,
    dept: p.dept,
    income: Number(p.grossSalary) || 0,
    tax: Number(p.tax) || 0
  })).filter(p => p.tax > 0).sort((a, b) => b.tax - a.tax);

  // --- UC-13: Báo cáo BHXH ---
  const insuranceList = payrolls.filter(p => String(p.month) === String(currentMonth)).map(p => {
    const bhxh = Number(p.bhxh) || 0;
    const bhyt = Number(p.bhyt) || 0;
    const bhtn = Number(p.bhtn) || 0;
    const nldDong = bhxh + bhyt + bhtn;
    
    // Tạm tính chi phí cty: BHXH(17.5%) + BHYT(3%) + BHTN(1%) = 21.5%
    const luongDongBH = bhxh > 0 ? (bhxh / 0.08) : 0;
    const ctyDong = luongDongBH * 0.215;

    return {
      empId: p.empId,
      name: p.name,
      dept: p.dept,
      basicSalary: Number(p.basicSalary) || 0,
      nldDong,
      ctyDong,
      total: nldDong + ctyDong
    };
  }).filter(p => p.total > 0);

  const totalNldDong = insuranceList.reduce((sum, item) => sum + item.nldDong, 0);
  const totalCtyDong = insuranceList.reduce((sum, item) => sum + item.ctyDong, 0);

  // --- UC-14: Phân tích biến động lương ---
  const trendByMonth = payrolls.reduce((acc: any, curr) => {
    const m = curr.month || 'Unknown';
    if (!acc[m]) acc[m] = { month: m, basic: 0, allowance: 0, overtime: 0, total: 0 };
    const b = Number(curr.basicSalary) || 0;
    const a = Number(curr.allowance) || 0;
    const total = Number(curr.grossSalary) || 0;
    const o = Math.max(0, total - b - a); // Tính tổng overtime + các khoản khác
    
    acc[m].basic += b;
    acc[m].allowance += a;
    acc[m].overtime += o;
    acc[m].total += total;
    return acc;
  }, {});

  const trendData = Object.values(trendByMonth).sort((a: any, b: any) => String(a.month || '').localeCompare(String(b.month || '')));

  // Handle Exports
  const handleExport = () => {
    if (activeTab === 'fund') {
      exportToExcel(fundData.map(d => ({ 'Phòng Ban': d.name, 'Tổng Chi Phí': d['Chi phí lương'] })), `QuyLuong_${currentMonth}`);
    } else if (activeTab === 'tax') {
      exportToExcel(currentMonthTax.map(d => ({ 'Mã NV': d.empId, 'Họ Tên': d.name, 'Phòng Ban': d.dept, 'Tổng Thu Nhập': d.income, 'Thuế TNCN Đã Khấu Trừ': d.tax })), `ThueTNCN_${currentMonth}`);
    } else if (activeTab === 'insurance') {
      exportToExcel(insuranceList.map(d => ({ 'Mã NV': d.empId, 'Họ Tên': d.name, 'Lương Cơ Sở': d.basicSalary, 'NLĐ Đóng (8%)': d.nldDong, 'Công Ty Đóng (21.5%)': d.ctyDong, 'Tổng Phải Nộp': d.total })), `BaoHiemXaHoi_${currentMonth}`);
    } else {
      exportToExcel(trendData.map((d: any) => ({ 'Tháng': d.month, 'Lương Cơ Bản': d.basic, 'Phụ Cấp': d.allowance, 'Tăng Ca': d.overtime, 'Tổng Quỹ Lương': d.total })), `BienDongLuong_All`);
    }
  };

  if (isLoading) {
    return (
      <div className="flex flex-col items-center justify-center h-[50vh] text-slate-500">
        <Loader2 className="w-8 h-8 animate-spin text-indigo-600 mb-4" />
        <p>Đang tải dữ liệu báo cáo...</p>
      </div>
    );
  }

  const tabs = [
    { id: 'fund', label: 'UC-11: Quỹ Lương', icon: Wallet },
    { id: 'tax', label: 'UC-12: Thuế TNCN', icon: FileSpreadsheet },
    { id: 'insurance', label: 'UC-13: BHXH', icon: ShieldCheck },
    { id: 'trend', label: 'UC-14: Biến Động', icon: TrendingUp },
  ];

  return (
    <div className="space-y-6 animate-in fade-in slide-in-from-bottom-4 duration-500">
      <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-slate-900">Báo Cáo & Phân Tích Dành Cho Giám Đốc</h1>
          <p className="text-sm text-slate-500">Trung tâm phân tích dữ liệu tài chính nhân sự (Dành riêng cho Director)</p>
        </div>
        <div className="flex items-center gap-3">
          <div className="relative">
            <CalendarDays className="w-4 h-4 absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" />
            <select 
              className="pl-9 pr-8 py-2 border border-slate-300 rounded-md text-sm focus:outline-none focus:ring-2 focus:ring-indigo-600 bg-white font-medium"
              value={selectedMonth}
              onChange={(e) => setSelectedMonth(e.target.value)}
            >
              <option value="">Chọn tháng báo cáo...</option>
              {availableMonths.map(m => <option key={m} value={m}>Tháng {m}</option>)}
            </select>
          </div>
          <Button onClick={handleExport} className="bg-emerald-600 hover:bg-emerald-700 text-white shadow-sm">
            <Download className="w-4 h-4 mr-2" /> Xuất Báo Cáo
          </Button>
        </div>
      </div>

      {/* Tabs */}
      <div className="flex overflow-x-auto gap-2 pb-2 scrollbar-hide">
        {tabs.map(tab => (
          <button
            key={tab.id}
            onClick={() => setActiveTab(tab.id as any)}
            className={cn(
              "flex items-center gap-2 px-4 py-2.5 rounded-lg text-sm font-medium transition-all whitespace-nowrap",
              activeTab === tab.id 
                ? "bg-indigo-600 text-white shadow-md shadow-indigo-200" 
                : "bg-white text-slate-600 hover:bg-slate-50 border border-slate-200"
            )}
          >
            <tab.icon className="w-4 h-4" />
            {tab.label}
          </button>
        ))}
      </div>

      {/* Content Area */}
      <div className="bg-white rounded-xl border border-slate-200 shadow-sm p-6 min-h-[500px]">
        
        {/* UC-11: Quỹ lương */}
        {activeTab === 'fund' && (
          <div className="space-y-6">
            <div className="flex justify-between items-end">
              <div>
                <h3 className="text-lg font-semibold text-slate-800">Cơ Cấu Quỹ Lương Theo Phòng Ban</h3>
                <p className="text-sm text-slate-500">Tháng {currentMonth || '--/--'}</p>
              </div>
              <div className="text-right">
                <p className="text-sm font-medium text-slate-500">Tổng quỹ lương</p>
                <p className="text-2xl font-bold text-indigo-700">
                  {formatMoney(fundData.reduce((sum, d) => sum + d['Chi phí lương'], 0))}
                </p>
              </div>
            </div>
            
            <div className="h-[400px] w-full mt-8">
              {fundData.length > 0 ? (
                <ResponsiveContainer width="100%" height="100%">
                  <BarChart data={fundData} layout="vertical" margin={{ top: 5, right: 30, left: 100, bottom: 5 }}>
                    <CartesianGrid strokeDasharray="3 3" horizontal={true} vertical={false} stroke="#e2e8f0" />
                    <XAxis type="number" tickFormatter={(val) => `${(val / 1000000).toFixed(0)}M`} textAnchor="end" />
                    <YAxis dataKey="name" type="category" axisLine={false} tickLine={false} fontWeight={500} />
                    <RechartsTooltip 
                      formatter={(val: any) => [formatMoney(val), 'Chi phí lương']}
                      cursor={{fill: '#f8fafc'}}
                    />
                    <Bar dataKey="Chi phí lương" fill="#6366f1" radius={[0, 4, 4, 0]} barSize={32} />
                  </BarChart>
                </ResponsiveContainer>
              ) : (
                <div className="h-full flex items-center justify-center text-slate-400">Không có dữ liệu cho tháng này</div>
              )}
            </div>
          </div>
        )}

        {/* UC-12: Thuế TNCN */}
        {activeTab === 'tax' && (
          <div className="space-y-8">
            <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
              <div>
                <h3 className="text-lg font-semibold text-slate-800 mb-1">Xu Hướng Thuế TNCN (Các Tháng)</h3>
                <p className="text-sm text-slate-500 mb-6">Tổng hợp tiền thuế đã khấu trừ của toàn bộ nhân viên qua các tháng.</p>
                <div className="h-[250px] w-full">
                  <ResponsiveContainer width="100%" height="100%">
                    <AreaChart data={taxData} margin={{ top: 10, right: 10, left: 0, bottom: 0 }}>
                      <defs>
                        <linearGradient id="colorTax" x1="0" y1="0" x2="0" y2="1">
                          <stop offset="5%" stopColor="#f43f5e" stopOpacity={0.3}/>
                          <stop offset="95%" stopColor="#f43f5e" stopOpacity={0}/>
                        </linearGradient>
                      </defs>
                      <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="#f1f5f9" />
                      <XAxis dataKey="month" axisLine={false} tickLine={false} tick={{fontSize: 12}} />
                      <YAxis tickFormatter={(val) => `${(val / 1000000).toFixed(1)}M`} axisLine={false} tickLine={false} tick={{fontSize: 12}} />
                      <RechartsTooltip formatter={(val: any) => [formatMoney(val), 'Thuế TNCN']} />
                      <Area type="monotone" dataKey="Thuế TNCN" stroke="#f43f5e" strokeWidth={3} fillOpacity={1} fill="url(#colorTax)" />
                    </AreaChart>
                  </ResponsiveContainer>
                </div>
              </div>
              
              <div>
                <div className="flex justify-between items-end mb-6">
                  <div>
                    <h3 className="text-lg font-semibold text-slate-800 mb-1">Chi Tiết Khấu Trừ Thuế</h3>
                    <p className="text-sm text-slate-500">Tháng {currentMonth}</p>
                  </div>
                  <div className="text-right">
                    <p className="text-sm font-medium text-slate-500">Tổng thuế tháng này</p>
                    <p className="text-xl font-bold text-rose-600">
                      {formatMoney(currentMonthTax.reduce((sum, d) => sum + d.tax, 0))}
                    </p>
                  </div>
                </div>
                
                <div className="overflow-y-auto max-h-[250px] border border-slate-200 rounded-lg">
                  <table className="w-full text-left text-sm">
                    <thead className="bg-slate-50 sticky top-0">
                      <tr>
                        <th className="px-4 py-3 font-medium text-slate-600">Nhân Viên</th>
                        <th className="px-4 py-3 font-medium text-slate-600 text-right">Thu Nhập (Gross)</th>
                        <th className="px-4 py-3 font-medium text-slate-600 text-right">Thuế Khấu Trừ</th>
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-slate-100">
                      {currentMonthTax.slice(0, 10).map((t, i) => (
                        <tr key={i} className="hover:bg-slate-50">
                          <td className="px-4 py-3">
                            <p className="font-medium text-slate-900">{t.name}</p>
                            <p className="text-xs text-slate-500">{t.dept}</p>
                          </td>
                          <td className="px-4 py-3 text-right text-slate-600">{formatMoney(t.income)}</td>
                          <td className="px-4 py-3 text-right font-medium text-rose-600">{formatMoney(t.tax)}</td>
                        </tr>
                      ))}
                      {currentMonthTax.length === 0 && (
                        <tr><td colSpan={3} className="px-4 py-8 text-center text-slate-500">Không có dữ liệu thuế</td></tr>
                      )}
                    </tbody>
                  </table>
                </div>
                {currentMonthTax.length > 10 && <p className="text-xs text-center text-slate-500 mt-2">*Chỉ hiển thị top 10 nhân viên đóng thuế cao nhất</p>}
              </div>
            </div>
          </div>
        )}

        {/* UC-13: BHXH */}
        {activeTab === 'insurance' && (
          <div className="space-y-6">
            <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-6">
              <div className="bg-slate-50 rounded-xl p-5 border border-slate-200">
                <p className="text-sm font-medium text-slate-500 mb-1">NLĐ Trích Đóng (8%)</p>
                <h3 className="text-2xl font-bold text-slate-800">{formatMoney(totalNldDong)}</h3>
              </div>
              <div className="bg-indigo-50 rounded-xl p-5 border border-indigo-100">
                <p className="text-sm font-medium text-indigo-600 mb-1">Công Ty Đóng (21.5%)</p>
                <h3 className="text-2xl font-bold text-indigo-900">{formatMoney(totalCtyDong)}</h3>
              </div>
              <div className="bg-emerald-50 rounded-xl p-5 border border-emerald-100">
                <p className="text-sm font-medium text-emerald-600 mb-1">Tổng Tiền Nộp BHXH</p>
                <h3 className="text-2xl font-bold text-emerald-700">{formatMoney(totalNldDong + totalCtyDong)}</h3>
              </div>
            </div>

            <div className="flex justify-between items-center mb-4">
              <h3 className="text-lg font-semibold text-slate-800">Danh Sách Tham Gia BHXH Tháng {currentMonth}</h3>
            </div>

            <div className="overflow-x-auto border border-slate-200 rounded-lg">
              <table className="w-full text-left text-sm whitespace-nowrap">
                <thead className="bg-slate-100">
                  <tr>
                    <th className="px-4 py-3 font-medium text-slate-600">Mã NV</th>
                    <th className="px-4 py-3 font-medium text-slate-600">Họ Tên</th>
                    <th className="px-4 py-3 font-medium text-slate-600 text-right">Lương Cơ Sở</th>
                    <th className="px-4 py-3 font-medium text-slate-600 text-right">NLĐ Trừ Lương</th>
                    <th className="px-4 py-3 font-medium text-slate-600 text-right">Cty Chịu Phí</th>
                    <th className="px-4 py-3 font-medium text-slate-600 text-right">Tổng Đóng</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-100">
                  {insuranceList.map((item, i) => (
                    <tr key={i} className="hover:bg-slate-50">
                      <td className="px-4 py-3 font-medium text-slate-900">{item.empId}</td>
                      <td className="px-4 py-3">{item.name}</td>
                      <td className="px-4 py-3 text-right">{formatMoney(item.basicSalary)}</td>
                      <td className="px-4 py-3 text-right text-slate-600">{formatMoney(item.nldDong)}</td>
                      <td className="px-4 py-3 text-right text-indigo-600 font-medium">{formatMoney(item.ctyDong)}</td>
                      <td className="px-4 py-3 text-right text-emerald-600 font-bold">{formatMoney(item.total)}</td>
                    </tr>
                  ))}
                  {insuranceList.length === 0 && (
                    <tr><td colSpan={6} className="px-4 py-8 text-center text-slate-500">Không có danh sách BHXH cho tháng này</td></tr>
                  )}
                </tbody>
              </table>
            </div>
          </div>
        )}

        {/* UC-14: Biến động lương */}
        {activeTab === 'trend' && (
          <div className="space-y-6">
            <div className="flex justify-between items-end mb-6">
              <div>
                <h3 className="text-lg font-semibold text-slate-800">Biến Động Quỹ Lương Theo Thời Gian</h3>
                <p className="text-sm text-slate-500">Phân tích xu hướng tăng/giảm các thành phần lương (Cơ bản, Phụ cấp, Tăng ca)</p>
              </div>
            </div>

            <div className="h-[400px] w-full">
              <ResponsiveContainer width="100%" height="100%">
                <ComposedChart data={trendData} margin={{ top: 20, right: 20, bottom: 20, left: 20 }}>
                  <CartesianGrid stroke="#f5f5f5" strokeDasharray="3 3" vertical={false} />
                  <XAxis dataKey="month" tick={{fontSize: 12}} tickMargin={10} />
                  <YAxis tickFormatter={(val) => `${(val / 1000000).toFixed(0)}M`} tick={{fontSize: 12}} />
                  <RechartsTooltip formatter={(val: any) => formatMoney(val)} />
                  <Legend verticalAlign="top" height={36} />
                  
                  <Bar dataKey="basic" name="Lương Cơ Bản" stackId="a" fill="#3b82f6" barSize={40} />
                  <Bar dataKey="allowance" name="Phụ Cấp" stackId="a" fill="#8b5cf6" />
                  <Bar dataKey="overtime" name="Chi Phí Tăng Ca" stackId="a" fill="#f59e0b" radius={[4, 4, 0, 0]} />
                  
                  <Line type="monotone" dataKey="total" name="Tổng Quỹ Lương" stroke="#ef4444" strokeWidth={3} dot={{r: 4, fill: '#ef4444'}} />
                </ComposedChart>
              </ResponsiveContainer>
            </div>
          </div>
        )}

      </div>
    </div>
  );
}
