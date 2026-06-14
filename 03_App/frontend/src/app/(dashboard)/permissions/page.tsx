"use client";

import React, { useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { Key, ShieldAlert, Check, Minus, Info } from 'lucide-react';
import { roleService } from '@/services/role.service';

// Hardcoded permission mapping based on system architecture (Sidebar.tsx & server.js)
const PERMISSION_MATRIX = [
  {
    module: 'Tổng quan hệ thống (Dashboard)',
    permissions: {
      ADMIN: true, DIRECTOR: true, HR: true, ACCOUNTANT: true, EMPLOYEE: true
    }
  },
  {
    module: 'Quản lý Nhân sự',
    permissions: {
      ADMIN: false, DIRECTOR: true, HR: true, ACCOUNTANT: true, EMPLOYEE: false
    }
  },
  {
    module: 'Quản lý Hợp đồng',
    permissions: {
      ADMIN: false, DIRECTOR: true, HR: true, ACCOUNTANT: true, EMPLOYEE: false
    }
  },
  {
    module: 'Quản lý Điểm danh',
    permissions: {
      ADMIN: false, DIRECTOR: true, HR: true, ACCOUNTANT: true, EMPLOYEE: true
    }
  },
  {
    module: 'Quản lý Nghỉ phép',
    permissions: {
      ADMIN: false, DIRECTOR: true, HR: true, ACCOUNTANT: true, EMPLOYEE: true
    }
  },
  {
    module: 'Bảng lương',
    permissions: {
      ADMIN: false, DIRECTOR: true, HR: true, ACCOUNTANT: true, EMPLOYEE: true
    }
  },
  {
    module: 'Phúc lợi',
    permissions: {
      ADMIN: true, DIRECTOR: false, HR: true, ACCOUNTANT: false, EMPLOYEE: false
    }
  },
  {
    module: 'Báo cáo & Phân tích',
    permissions: {
      ADMIN: false, DIRECTOR: true, HR: true, ACCOUNTANT: true, EMPLOYEE: false
    }
  },
  {
    module: 'Quản lý Tài khoản (Người dùng, Vai trò)',
    permissions: {
      ADMIN: true, DIRECTOR: false, HR: false, ACCOUNTANT: false, EMPLOYEE: false
    }
  },
  {
    module: 'Cấu hình hệ thống (Phòng ban, Chức vụ...)',
    permissions: {
      ADMIN: true, DIRECTOR: false, HR: false, ACCOUNTANT: false, EMPLOYEE: false
    }
  },
  {
    module: 'Lịch sử & Nhật ký hệ thống',
    permissions: {
      ADMIN: true, DIRECTOR: true, HR: true, ACCOUNTANT: true, EMPLOYEE: false
    }
  }
];

export default function PermissionsPage() {
  const { data: statsData, isLoading } = useQuery({
    queryKey: ['rolesStats'],
    queryFn: () => roleService.getRoleStats()
  });

  // Extract roles from API, fallback to default roles if API fails/empty
  const roles = statsData?.data?.map(s => s.role) || ['ADMIN', 'DIRECTOR', 'HR', 'ACCOUNTANT', 'EMPLOYEE'];
  
  // Custom sort to keep roles in a logical order
  const roleOrder = ['ADMIN', 'DIRECTOR', 'HR', 'ACCOUNTANT', 'EMPLOYEE'];
  const sortedRoles = [...roles].sort((a, b) => {
    return roleOrder.indexOf(a) - roleOrder.indexOf(b);
  });

  return (
    <div className="space-y-6 animate-in fade-in duration-300">
      <div>
        <h1 className="text-2xl font-bold text-slate-900 flex items-center gap-2">
          <Key className="h-6 w-6 text-indigo-600" />
          Ma trận Phân quyền
        </h1>
        <p className="text-sm text-slate-500 mt-1 max-w-3xl">
          Bảng tham chiếu chi tiết quyền truy cập của từng vai trò vào các phân hệ trên phần mềm.
        </p>
      </div>

      <div className="bg-amber-50 border border-amber-200 rounded-lg p-4 flex gap-3 items-start">
        <ShieldAlert className="w-5 h-5 text-amber-600 flex-shrink-0 mt-0.5" />
        <div className="text-sm text-amber-800">
          <p className="font-semibold mb-1">Kiến trúc phân quyền tĩnh (Static RBAC)</p>
          <p>
            Hệ thống hiện tại đang sử dụng cấu trúc phân quyền cố định được định nghĩa trực tiếp dưới cơ sở dữ liệu (`ENUM`). 
            Ma trận dưới đây là bản đồ mô phỏng các quyền hạn thực tế đang được áp dụng. Nếu muốn thay đổi logic phân quyền này, vui lòng liên hệ đội ngũ kỹ thuật để can thiệp vào Source Code.
          </p>
        </div>
      </div>

      <div className="bg-white rounded-xl shadow-sm border border-slate-200 overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-sm text-left">
            <thead className="text-xs text-slate-500 uppercase bg-slate-50 border-b border-slate-200">
              <tr>
                <th className="px-6 py-4 font-bold text-slate-700 w-1/3 border-r border-slate-200">Phân hệ / Chức năng</th>
                {sortedRoles.map(role => (
                  <th key={role} className="px-4 py-4 font-bold text-center">
                    {role}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {PERMISSION_MATRIX.map((row, idx) => (
                <tr key={idx} className="hover:bg-slate-50 transition-colors">
                  <td className="px-6 py-4 font-medium text-slate-700 border-r border-slate-200 bg-white">
                    {row.module}
                  </td>
                  {sortedRoles.map(role => {
                    // @ts-ignore
                    const hasAccess = row.permissions[role] || false;
                    return (
                      <td key={role} className="px-4 py-4 text-center">
                        {hasAccess ? (
                          <div className="inline-flex items-center justify-center w-6 h-6 rounded-full bg-emerald-100 text-emerald-600">
                            <Check className="w-4 h-4" />
                          </div>
                        ) : (
                          <div className="inline-flex items-center justify-center w-6 h-6 text-slate-300">
                            <Minus className="w-4 h-4" />
                          </div>
                        )}
                      </td>
                    );
                  })}
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
      
      <div className="flex items-center gap-2 text-sm text-slate-500">
        <Info className="w-4 h-4" />
        <span>Dấu tích xanh thể hiện vai trò đó có quyền truy cập vào chức năng tương ứng.</span>
      </div>
    </div>
  );
}
