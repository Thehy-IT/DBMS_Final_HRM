"use client";

import { useState } from "react";
import { Search, Plus, Check, X, Loader2 } from "lucide-react";
import { Button } from "@/components/ui/button";
import { cn, formatDate } from "@/lib/utils";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { leaveService } from "@/services/leave.service";
import { LeaveFormDrawer } from "@/components/leaves/LeaveFormDrawer";

export default function LeaveRequestsPage() {
  const [searchTerm, setSearchTerm] = useState("");
  const [isDrawerOpen, setIsDrawerOpen] = useState(false);

  const { data, isLoading, error } = useQuery({
    queryKey: ['leaves'],
    queryFn: () => leaveService.getLeaves(),
  });

  const queryClient = useQueryClient();

  const approveMutation = useMutation({
    mutationFn: ({ id, action }: { id: string, action: 'A' | 'R' }) => {
      return leaveService.approveLeave(id, action);
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['leaves'] });
      alert("Đã cập nhật trạng thái nghỉ phép!");
    }
  });

  const leaves = data?.data || [];

  const filteredLeaves = leaves.filter(record => {
    if (searchTerm && !(record.empName || '').toLowerCase().includes(searchTerm.toLowerCase()) && !record.id.toLowerCase().includes(searchTerm.toLowerCase())) {
      return false;
    }
    return true;
  });

  return (
    <div className="space-y-6">
      <LeaveFormDrawer isOpen={isDrawerOpen} onClose={() => setIsDrawerOpen(false)} />
      <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-slate-900">Quản lý Nghỉ phép</h1>
          <p className="text-sm text-slate-500">Duyệt và theo dõi đơn xin nghỉ phép của nhân viên</p>
        </div>
        <div className="flex items-center gap-2">
          <Button size="sm" onClick={() => setIsDrawerOpen(true)}>
            <Plus className="w-4 h-4 mr-2" /> Tạo Đơn Nghỉ
          </Button>
        </div>
      </div>

      <div className="bg-white rounded-xl border border-slate-200 shadow-sm overflow-hidden flex flex-col">
        <div className="p-4 border-b border-slate-200 flex flex-col sm:flex-row gap-4 bg-slate-50/50">
          <div className="relative flex-1 max-w-md">
            <Search className="w-4 h-4 absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" />
            <input 
              type="text" 
              placeholder="Tìm theo Mã Đơn, Tên NV..." 
              className="w-full pl-9 pr-4 py-2 border border-slate-300 rounded-md text-sm focus:outline-none focus:ring-2 focus:ring-indigo-600 bg-white"
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
            />
          </div>
          <select className="border border-slate-300 rounded-md px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-600 bg-white">
            <option value="">Tất cả loại nghỉ</option>
            <option value="Phép năm">Phép năm</option>
            <option value="Nghỉ ốm">Nghỉ ốm</option>
            <option value="Việc riêng">Việc riêng</option>
          </select>
          <select className="border border-slate-300 rounded-md px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-600 bg-white">
            <option value="">Tất cả trạng thái</option>
            <option value="P">Chờ duyệt</option>
            <option value="A">Đã duyệt</option>
            <option value="R">Từ chối</option>
            <option value="C">Đã hủy</option>
          </select>
        </div>

        <div className="overflow-x-auto min-h-[300px]">
          {isLoading ? (
            <div className="flex flex-col items-center justify-center h-[300px] text-slate-500">
              <Loader2 className="w-8 h-8 animate-spin text-indigo-600 mb-4" />
              <p>Đang tải dữ liệu...</p>
            </div>
          ) : error ? (
             <div className="flex items-center justify-center h-[300px] text-red-500">
              <p>Có lỗi xảy ra khi tải dữ liệu nghỉ phép.</p>
            </div>
          ) : filteredLeaves.length === 0 ? (
             <div className="flex items-center justify-center h-[300px] text-slate-500">
              <p>Không tìm thấy đơn nghỉ phép nào.</p>
            </div>
          ) : (
            <table className="w-full text-left border-collapse min-w-[1000px]">
              <thead>
                <tr className="bg-slate-50 border-b border-slate-200 text-sm font-medium text-slate-600">
                  <th className="px-6 py-3 w-10">
                    <input type="checkbox" className="rounded border-slate-300 text-indigo-600 focus:ring-indigo-600" />
                  </th>
                  <th className="px-6 py-3">Mã Đơn</th>
                  <th className="px-6 py-3">Nhân Viên</th>
                  <th className="px-6 py-3">Loại Nghỉ</th>
                  <th className="px-6 py-3">Thời Gian</th>
                  <th className="px-6 py-3">Lý Do</th>
                  <th className="px-6 py-3">Trạng Thái</th>
                  <th className="px-6 py-3 text-right">Hành động</th>
                </tr>
              </thead>
              <tbody className="text-sm">
                {filteredLeaves.map((record) => (
                  <tr key={record.id} className="border-b border-slate-100 hover:bg-slate-50 transition-colors">
                    <td className="px-6 py-4">
                      <input type="checkbox" className="rounded border-slate-300 text-indigo-600 focus:ring-indigo-600" />
                    </td>
                    <td className="px-6 py-4 font-medium text-indigo-600 cursor-pointer hover:underline">{record.id}</td>
                    <td className="px-6 py-4 font-medium text-slate-900">{record.empName}</td>
                    <td className="px-6 py-4">
                      <span className="px-2.5 py-1 rounded-full text-xs font-medium bg-slate-100 text-slate-700 border border-slate-200">
                        {record.type}
                      </span>
                    </td>
                    <td className="px-6 py-4">
                      <div>{formatDate(record.startDate)} - {formatDate(record.endDate)}</div>
                      <div className="text-slate-500 text-xs mt-0.5">({record.days} ngày)</div>
                    </td>
                    <td className="px-6 py-4 max-w-[200px] truncate" title={record.reason}>{record.reason}</td>
                    <td className="px-6 py-4">
                      <span className={cn(
                        "px-2.5 py-1 rounded-full text-xs font-medium border",
                        record.status === 'P' ? "bg-amber-50 text-amber-700 border-amber-200" :
                        record.status === 'A' ? "bg-emerald-50 text-emerald-700 border-emerald-200" :
                        "bg-red-50 text-red-700 border-red-200"
                      )}>
                        {record.status === 'P' ? "Chờ duyệt" : 
                         record.status === 'A' ? "Đã duyệt" : 
                         record.status === 'R' ? "Từ chối" : "Đã hủy"}
                      </span>
                    </td>
                    <td className="px-6 py-4 text-right">
                      {record.status === 'P' ? (
                        <div className="flex items-center justify-end gap-2 text-slate-400">
                          <button 
                            className="hover:text-emerald-600 p-1.5 rounded-md hover:bg-emerald-50 transition-colors" title="Duyệt"
                            onClick={() => approveMutation.mutate({ id: record.id, action: 'A' })}
                            disabled={approveMutation.isPending}
                          >
                            <Check className="w-4 h-4" />
                          </button>
                          <button 
                            className="hover:text-red-600 p-1.5 rounded-md hover:bg-red-50 transition-colors" title="Từ chối"
                            onClick={() => approveMutation.mutate({ id: record.id, action: 'R' })}
                            disabled={approveMutation.isPending}
                          >
                            <X className="w-4 h-4" />
                          </button>
                        </div>
                      ) : (
                        <span className="text-slate-400">-</span>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>
      </div>
    </div>
  );
}
