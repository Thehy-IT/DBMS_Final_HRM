"use client";

import React from 'react';
import { useQuery } from '@tanstack/react-query';
import { ShieldCheck, Users, Briefcase, Calculator, Building2, Crown, LayoutDashboard } from 'lucide-react';
import { roleService } from '@/services/role.service';

const ROLES_DEFINITIONS = [
  {
    id: 'ADMIN',
    name: 'Quản trị viên hệ thống',
    icon: Crown,
    color: 'bg-purple-100 text-purple-700',
    borderColor: 'border-purple-200',
    description: 'Có toàn quyền truy cập hệ thống. Quản lý tài khoản, phân quyền, cấu hình dữ liệu nền tảng và xem mọi báo cáo.',
    permissions: ['Quản lý người dùng', 'Cấu hình hệ thống', 'Quản lý sao lưu', 'Xem toàn bộ báo cáo', 'Phân quyền']
  },
  {
    id: 'DIRECTOR',
    name: 'Giám đốc',
    icon: Building2,
    color: 'bg-amber-100 text-amber-700',
    borderColor: 'border-amber-200',
    description: 'Quyền xem cấp cao. Giám sát tổng thể hoạt động nhân sự, xem bảng lương và báo cáo phân tích toàn công ty.',
    permissions: ['Xem tất cả báo cáo', 'Xem bảng lương tổng', 'Xem hồ sơ nhân sự', 'Xem lịch sử hệ thống']
  },
  {
    id: 'HR',
    name: 'Nhân sự',
    icon: Briefcase,
    color: 'bg-blue-100 text-blue-700',
    borderColor: 'border-blue-200',
    description: 'Quản lý nghiệp vụ nhân sự hàng ngày. Tạo hồ sơ, xử lý hợp đồng, phúc lợi và duyệt đơn nghỉ phép.',
    permissions: ['Quản lý hồ sơ nhân sự', 'Quản lý hợp đồng', 'Quản lý phúc lợi', 'Duyệt/Từ chối nghỉ phép', 'Xem báo cáo nhân sự']
  },
  {
    id: 'EMPLOYEE',
    name: 'Nhân viên',
    icon: Users,
    color: 'bg-slate-100 text-slate-700',
    borderColor: 'border-slate-200',
    description: 'Quyền truy cập cơ bản. Xem thông tin cá nhân, chấm công, phiếu lương và nộp đơn xin nghỉ phép.',
    permissions: ['Xem phiếu lương cá nhân', 'Xem hợp đồng cá nhân', 'Chấm công', 'Xin nghỉ phép']
  }
];

export default function RolesPage() {
  const { data: statsData, isLoading } = useQuery({
    queryKey: ['rolesStats'],
    queryFn: () => roleService.getRoleStats()
  });

  const stats = statsData?.data || [];
  
  // Create a map for quick lookup
  const countMap = stats.reduce((acc, curr) => {
    acc[curr.role] = curr.count;
    return acc;
  }, {} as Record<string, number>);

  return (
    <div className="space-y-8 animate-in fade-in duration-300">
      <div>
        <h1 className="text-2xl font-bold text-slate-900 flex items-center gap-2">
          <ShieldCheck className="h-6 w-6 text-indigo-600" />
          Vai trò & Phân quyền
        </h1>
        <p className="text-sm text-slate-500 mt-1 max-w-3xl">
          Quản lý các nhóm quyền hạn trong hệ thống. Mỗi vai trò được cấp các quyền truy cập cụ thể để đảm bảo an toàn thông tin và bảo mật dữ liệu doanh nghiệp.
        </p>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-6">
        {ROLES_DEFINITIONS.map((role) => {
          const userCount = countMap[role.id] || 0;
          
          return (
            <div 
              key={role.id} 
              className={`bg-white rounded-2xl p-6 border shadow-sm hover:shadow-md transition-all group flex flex-col h-full ${role.borderColor}`}
            >
              <div className="flex justify-between items-start mb-4">
                <div className={`p-3 rounded-xl ${role.color}`}>
                  <role.icon className="h-6 w-6" />
                </div>
                <div className="text-right">
                  <div className="text-2xl font-bold text-slate-800 group-hover:text-indigo-600 transition-colors">
                    {isLoading ? '...' : userCount}
                  </div>
                  <div className="text-xs font-medium text-slate-500 uppercase tracking-wider">
                    Tài khoản
                  </div>
                </div>
              </div>
              
              <div className="mb-2">
                <h3 className="text-lg font-bold text-slate-900">{role.name}</h3>
                <span className="inline-block px-2 py-0.5 rounded text-xs font-medium bg-slate-100 text-slate-600 mt-1">
                  Mã hệ thống: {role.id}
                </span>
              </div>
              
              <p className="text-sm text-slate-600 mb-6 flex-grow">
                {role.description}
              </p>
              
              <div className="border-t border-slate-100 pt-4 mt-auto">
                <h4 className="text-xs font-semibold text-slate-900 uppercase tracking-wider mb-3">
                  Quyền hạn tiêu biểu:
                </h4>
                <ul className="space-y-2">
                  {role.permissions.map((perm, idx) => (
                    <li key={idx} className="flex items-start gap-2 text-sm text-slate-600">
                      <div className="mt-1 h-1.5 w-1.5 rounded-full bg-indigo-400 flex-shrink-0" />
                      {perm}
                    </li>
                  ))}
                </ul>
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}
