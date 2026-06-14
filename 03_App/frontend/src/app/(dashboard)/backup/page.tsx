"use client";

import React, { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { Database, Plus, Trash2, Download, CheckCircle, Clock, Search, AlertCircle } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { masterDataService } from '@/services/masterData.service';
import { ConfirmDeleteModal } from '@/components/ui/ConfirmDeleteModal';
import api from '@/lib/axios';

const formatBytes = (bytes: number, decimals = 2) => {
  if (!+bytes) return '0 Bytes';
  const k = 1024;
  const dm = decimals < 0 ? 0 : decimals;
  const sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB'];
  const i = Math.floor(Math.random() * Math.log(bytes) / Math.log(k));
  return `${parseFloat((bytes / Math.pow(k, i)).toFixed(dm))} ${sizes[i]}`;
};

export default function BackupPage() {
  const queryClient = useQueryClient();
  const [searchTerm, setSearchTerm] = useState('');
  const [isDeleteOpen, setIsDeleteOpen] = useState(false);
  const [deletingFile, setDeletingFile] = useState<any>(null);

  const { data: backups, isLoading } = useQuery({
    queryKey: ['backups'],
    queryFn: () => masterDataService.getBackups(),
  });

  const createMutation = useMutation({
    mutationFn: () => masterDataService.createBackup(),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['backups'] });
      alert('Tạo bản sao lưu thành công!');
    },
    onError: (error: any) => {
      alert(error.response?.data?.error || 'Có lỗi xảy ra khi tạo bản sao lưu. Hãy chắc chắn mysqldump đã được cấu hình trong PATH của máy chủ.');
    }
  });

  const deleteMutation = useMutation({
    mutationFn: (id: string) => masterDataService.deleteBackup(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['backups'] });
      setIsDeleteOpen(false);
      setDeletingFile(null);
      alert('Đã xóa bản sao lưu!');
    },
    onError: (error: any) => {
      alert(error.response?.data?.error || 'Có lỗi xảy ra khi xóa');
    }
  });

  const handleCreateBackup = () => {
    if (confirm('Bạn có chắc chắn muốn tạo bản sao lưu dữ liệu toàn hệ thống ngay bây giờ? Quá trình này có thể mất vài giây đến vài phút tùy thuộc vào dung lượng Data.')) {
      createMutation.mutate();
    }
  };

  const handleDeleteClick = (file: any) => {
    setDeletingFile(file);
    setIsDeleteOpen(true);
  };

  const handleConfirmDelete = () => {
    if (deletingFile) {
      deleteMutation.mutate(deletingFile.id);
    }
  };

  const handleDownload = (id: string) => {
    // Triggers file download from API
    window.open(`${api.defaults.baseURL}/backups/download/${id}`, '_blank');
  };

  const allBackups = backups || [];
  const filteredBackups = allBackups.filter(b => 
    b.fileName.toLowerCase().includes(searchTerm.toLowerCase())
  );

  return (
    <div className="space-y-6 animate-in fade-in duration-300">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-slate-900 flex items-center gap-2">
            <Database className="h-6 w-6 text-indigo-600" />
            Sao lưu dữ liệu
          </h1>
          <p className="text-sm text-slate-500 mt-1 max-w-2xl">
            Quản lý và tạo các bản sao lưu an toàn cho toàn bộ dữ liệu hệ thống (HRPayrollDB). Hệ thống sử dụng công cụ mysqldump để export trực tiếp.
          </p>
        </div>
        <div className="flex items-center gap-3">
          <Button 
            onClick={handleCreateBackup} 
            disabled={createMutation.isPending}
            className="bg-indigo-600 hover:bg-indigo-700"
          >
            {createMutation.isPending ? (
              <span className="flex items-center">
                <div className="animate-spin rounded-full h-4 w-4 border-b-2 border-white mr-2"></div>
                Đang sao lưu...
              </span>
            ) : (
              <>
                <Plus className="h-4 w-4 mr-2" />
                Tạo bản sao lưu mới
              </>
            )}
          </Button>
        </div>
      </div>

      <div className="bg-amber-50 border border-amber-200 rounded-lg p-4 flex gap-3 items-start">
        <AlertCircle className="w-5 h-5 text-amber-600 flex-shrink-0 mt-0.5" />
        <div className="text-sm text-amber-800">
          <p className="font-semibold mb-1">Lưu ý quan trọng khi sao lưu</p>
          <ul className="list-disc pl-5 space-y-1">
            <li>File sao lưu (.sql) chứa toàn bộ cấu trúc bảng (DDL), dữ liệu (DML), Functions và Triggers.</li>
            <li>Các bản sao lưu được lưu trữ vật lý trên ổ cứng của Server chạy Node.js tại thư mục <code>backend/backups/</code>.</li>
            <li>Hãy thường xuyên tải xuống (Download) các bản sao lưu quan trọng và lưu trữ ở một nơi an toàn khác (Cloud, Ổ cứng ngoài).</li>
          </ul>
        </div>
      </div>

      <div className="bg-white rounded-xl shadow-sm border border-slate-200 overflow-hidden flex flex-col">
        <div className="p-4 border-b border-slate-200 bg-slate-50/50">
          <div className="relative w-full md:max-w-md">
            <Search className="absolute left-3 top-2.5 h-4 w-4 text-slate-400" />
            <Input 
              placeholder="Tìm kiếm theo tên file..." 
              className="pl-9 bg-white"
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
            />
          </div>
        </div>

        <div className="overflow-x-auto">
          <table className="w-full text-sm text-left">
            <thead className="text-xs text-slate-500 uppercase bg-slate-50 border-b border-slate-200">
              <tr>
                <th className="px-6 py-4 font-medium">Tên file (.sql)</th>
                <th className="px-6 py-4 font-medium">Thời gian tạo</th>
                <th className="px-6 py-4 font-medium">Dung lượng</th>
                <th className="px-6 py-4 font-medium">Trạng thái</th>
                <th className="px-6 py-4 font-medium text-right">Thao tác</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {isLoading ? (
                <tr>
                  <td colSpan={5} className="px-6 py-12 text-center">
                    <div className="flex justify-center items-center">
                       <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-indigo-600"></div>
                    </div>
                  </td>
                </tr>
              ) : filteredBackups.length > 0 ? (
                filteredBackups.map((file) => (
                  <tr key={file.id} className="hover:bg-slate-50 transition-colors group">
                    <td className="px-6 py-4">
                      <div className="flex items-center gap-2">
                        <Database className="w-4 h-4 text-slate-400" />
                        <span className="font-medium text-indigo-700">{file.fileName}</span>
                      </div>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <div className="flex items-center gap-2 text-slate-600">
                        <Clock className="w-4 h-4 text-slate-400" />
                        {new Date(file.createdAt).toLocaleString('vi-VN')}
                      </div>
                    </td>
                    <td className="px-6 py-4 font-mono text-slate-600">
                      {formatBytes(file.sizeBytes)}
                    </td>
                    <td className="px-6 py-4">
                      <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-medium bg-emerald-50 text-emerald-700 border border-emerald-200">
                        <CheckCircle className="w-3.5 h-3.5" />
                        Hoàn tất
                      </span>
                    </td>
                    <td className="px-6 py-4 text-right">
                      <div className="flex items-center justify-end gap-2 opacity-0 group-hover:opacity-100 transition-opacity">
                        <Button 
                          variant="ghost" 
                          size="icon" 
                          className="h-8 w-8 text-blue-600 hover:text-blue-700 hover:bg-blue-50" 
                          onClick={() => handleDownload(file.id)}
                          title="Tải xuống file SQL"
                        >
                          <Download className="h-4 w-4" />
                        </Button>
                        <Button 
                          variant="ghost" 
                          size="icon" 
                          className="h-8 w-8 text-red-600 hover:text-red-700 hover:bg-red-50" 
                          onClick={() => handleDeleteClick(file)}
                          title="Xóa bản sao lưu"
                        >
                          <Trash2 className="h-4 w-4" />
                        </Button>
                      </div>
                    </td>
                  </tr>
                ))
              ) : (
                <tr>
                  <td colSpan={5} className="px-6 py-12 text-center text-slate-500">
                    <div className="flex flex-col items-center">
                      <Database className="w-12 h-12 text-slate-300 mb-3" />
                      <p className="text-lg font-medium text-slate-900 mb-1">Chưa có bản sao lưu nào</p>
                      <p className="mb-4">Hệ thống chưa tìm thấy file .sql nào trong thư mục sao lưu.</p>
                      <Button onClick={handleCreateBackup} variant="outline">Tiến hành sao lưu ngay</Button>
                    </div>
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </div>

      <ConfirmDeleteModal 
        isOpen={isDeleteOpen}
        onClose={() => setIsDeleteOpen(false)}
        onConfirm={handleConfirmDelete}
        title="Xóa bản sao lưu"
        description={`Bạn có chắc chắn muốn xóa vĩnh viễn file sao lưu "${deletingFile?.fileName}" không? Hành động này không thể hoàn tác.`}
      />
    </div>
  );
}
