"use client";

import React from 'react';
import { useQuery } from '@tanstack/react-query';
import { Settings, Server, Database, Users, Shield, Cpu, Clock, HardDrive, Key, Power } from 'lucide-react';
import { masterDataService } from '@/services/masterData.service';

const formatBytes = (bytes: number, decimals = 2) => {
  if (!+bytes) return '0 Bytes';
  const k = 1024;
  const dm = decimals < 0 ? 0 : decimals;
  const sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB'];
  const i = Math.floor(Math.random() * Math.log(bytes) / Math.log(k));
  return `${parseFloat((bytes / Math.pow(k, i)).toFixed(dm))} ${sizes[i]}`;
};

const formatUptime = (seconds: number) => {
  const d = Math.floor(seconds / (3600*24));
  const h = Math.floor(seconds % (3600*24) / 3600);
  const m = Math.floor(seconds % 3600 / 60);
  
  const dDisplay = d > 0 ? d + " ngày, " : "";
  const hDisplay = h > 0 ? h + " giờ, " : "";
  const mDisplay = m > 0 ? m + " phút" : "1 phút";
  return dDisplay + hDisplay + mDisplay;
};

export default function SettingsPage() {
  const { data: settings, isLoading } = useQuery({
    queryKey: ['system-settings'],
    queryFn: () => masterDataService.getSystemSettings()
  });

  return (
    <div className="space-y-6 animate-in fade-in duration-300">
      <div>
        <h1 className="text-2xl font-bold text-slate-900 flex items-center gap-2">
          <Settings className="h-6 w-6 text-indigo-600" />
          Cài đặt Hệ thống
        </h1>
        <p className="text-sm text-slate-500 mt-1 max-w-2xl">
          Thông tin hệ thống, tài nguyên lưu trữ và giám sát các cấu hình lõi (Environment & Database) của dự án.
        </p>
      </div>

      {isLoading ? (
        <div className="flex justify-center items-center py-20">
          <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-indigo-600"></div>
        </div>
      ) : settings ? (
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          
          {/* DATABASE SETTINGS */}
          <div className="bg-white rounded-xl shadow-sm border border-slate-200 overflow-hidden flex flex-col">
            <div className="bg-blue-50 border-b border-blue-100 p-4 flex items-center gap-3">
              <div className="bg-blue-100 text-blue-600 p-2 rounded-lg">
                <Database className="w-5 h-5" />
              </div>
              <div>
                <h2 className="font-bold text-slate-800 text-lg">Cơ Sở Dữ Liệu</h2>
                <p className="text-xs text-slate-500">Thông tin kết nối & Dữ liệu lưu trữ</p>
              </div>
            </div>
            
            <div className="p-5 flex-grow space-y-4">
              <div className="grid grid-cols-2 gap-4">
                <div className="bg-slate-50 p-3 rounded-lg border border-slate-100">
                  <div className="flex items-center gap-1.5 text-xs text-slate-500 mb-1 font-medium">
                    <Database className="w-3.5 h-3.5" /> Database Name
                  </div>
                  <div className="font-semibold text-slate-800 font-mono text-sm">{settings.database.name}</div>
                </div>
                
                <div className="bg-slate-50 p-3 rounded-lg border border-slate-100">
                  <div className="flex items-center gap-1.5 text-xs text-slate-500 mb-1 font-medium">
                    <Server className="w-3.5 h-3.5" /> Host
                  </div>
                  <div className="font-semibold text-slate-800 font-mono text-sm">{settings.database.host}</div>
                </div>

                <div className="bg-slate-50 p-3 rounded-lg border border-slate-100">
                  <div className="flex items-center gap-1.5 text-xs text-slate-500 mb-1 font-medium">
                    <Power className="w-3.5 h-3.5" /> Trạng Thái
                  </div>
                  <div className="font-semibold text-emerald-600 text-sm flex items-center gap-1.5">
                    <span className="w-2 h-2 rounded-full bg-emerald-500 animate-pulse"></span>
                    {settings.database.status}
                  </div>
                </div>

                <div className="bg-slate-50 p-3 rounded-lg border border-slate-100">
                  <div className="flex items-center gap-1.5 text-xs text-slate-500 mb-1 font-medium">
                    <HardDrive className="w-3.5 h-3.5" /> Dung lượng lưu trữ
                  </div>
                  <div className="font-semibold text-indigo-600 text-sm">
                    {settings.database.sizeMB} MB
                  </div>
                </div>
              </div>

              <div className="mt-4 pt-4 border-t border-slate-100 grid grid-cols-2 gap-4">
                <div className="flex items-center justify-between p-3 bg-indigo-50 border border-indigo-100 rounded-lg">
                  <div className="flex items-center gap-2 text-indigo-900">
                    <Users className="w-4 h-4 text-indigo-600" />
                    <span className="text-sm font-medium">Tổng Nhân Sự</span>
                  </div>
                  <span className="font-bold text-lg text-indigo-700">{settings.stats.totalEmployees}</span>
                </div>
                
                <div className="flex items-center justify-between p-3 bg-emerald-50 border border-emerald-100 rounded-lg">
                  <div className="flex items-center gap-2 text-emerald-900">
                    <Shield className="w-4 h-4 text-emerald-600" />
                    <span className="text-sm font-medium">Tài Khoản</span>
                  </div>
                  <span className="font-bold text-lg text-emerald-700">{settings.stats.totalUsers}</span>
                </div>
              </div>
            </div>
          </div>

          {/* SYSTEM INFO */}
          <div className="bg-white rounded-xl shadow-sm border border-slate-200 overflow-hidden flex flex-col">
            <div className="bg-slate-50 border-b border-slate-100 p-4 flex items-center gap-3">
              <div className="bg-slate-200 text-slate-600 p-2 rounded-lg">
                <Server className="w-5 h-5" />
              </div>
              <div>
                <h2 className="font-bold text-slate-800 text-lg">Thông Tin Máy Chủ (Backend)</h2>
                <p className="text-xs text-slate-500">Môi trường NodeJS & Tài nguyên xử lý</p>
              </div>
            </div>
            
            <div className="p-5 flex-grow space-y-4">
              <div className="space-y-3">
                <div className="flex items-center justify-between border-b border-slate-100 pb-3">
                  <div className="flex items-center gap-2 text-sm text-slate-600">
                    <Cpu className="w-4 h-4" /> Node Version
                  </div>
                  <span className="font-mono text-sm font-medium text-slate-800">{settings.system.nodeVersion}</span>
                </div>
                
                <div className="flex items-center justify-between border-b border-slate-100 pb-3">
                  <div className="flex items-center gap-2 text-sm text-slate-600">
                    <Server className="w-4 h-4" /> Platform / OS
                  </div>
                  <span className="font-mono text-sm font-medium text-slate-800">{settings.system.platform}</span>
                </div>

                <div className="flex items-center justify-between border-b border-slate-100 pb-3">
                  <div className="flex items-center gap-2 text-sm text-slate-600">
                    <HardDrive className="w-4 h-4" /> RAM Đang Dùng (Heap)
                  </div>
                  <span className="font-mono text-sm font-medium text-indigo-600">{formatBytes(settings.system.memoryUsage)}</span>
                </div>

                <div className="flex items-center justify-between border-b border-slate-100 pb-3">
                  <div className="flex items-center gap-2 text-sm text-slate-600">
                    <Clock className="w-4 h-4" /> Server Uptime
                  </div>
                  <span className="font-medium text-sm text-emerald-600">{formatUptime(settings.system.uptime)}</span>
                </div>
              </div>

              <div className="mt-6 bg-slate-50 p-4 rounded-lg border border-slate-200 flex items-start gap-3">
                <Key className="w-5 h-5 text-slate-400 mt-0.5 flex-shrink-0" />
                <div>
                  <h4 className="text-sm font-medium text-slate-800">Biến môi trường (.env)</h4>
                  <p className="text-xs text-slate-500 mt-1">
                    Cấu hình Port, Token Secret, kết nối Database được bảo mật chặt chẽ ở phía Server. 
                    Mọi thao tác thay đổi cần được thực hiện trực tiếp trên source code.
                  </p>
                </div>
              </div>
            </div>
          </div>

        </div>
      ) : null}
    </div>
  );
}
