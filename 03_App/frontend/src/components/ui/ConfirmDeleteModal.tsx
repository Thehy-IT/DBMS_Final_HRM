import React from 'react';
import { AlertTriangle } from 'lucide-react';
import { Button } from '@/components/ui/button';

interface ConfirmDeleteModalProps {
  isOpen: boolean;
  onClose: () => void;
  onConfirm: () => void;
  title: string;
  description: string;
  isSubmitting?: boolean;
}

export function ConfirmDeleteModal({ isOpen, onClose, onConfirm, title, description, isSubmitting = false }: ConfirmDeleteModalProps) {
  if (!isOpen) return null;

  const handleClose = () => {
    if (isSubmitting) return;
    onClose();
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-sm animate-in fade-in duration-200">
      <div className="fixed inset-0" onClick={handleClose}></div>
      <div className="bg-white rounded-xl shadow-xl w-full max-w-md overflow-hidden animate-in zoom-in-95 duration-200 p-6 text-center relative z-10">
        <div className="w-12 h-12 rounded-full bg-red-100 text-red-600 flex items-center justify-center mx-auto mb-4">
          <AlertTriangle className="w-6 h-6" />
        </div>
        <h3 className="text-lg font-bold text-slate-900 mb-2">{title}</h3>
        <p className="text-sm text-slate-500 mb-6">{description}</p>
        
        <div className="flex items-center justify-center gap-3">
          <Button variant="outline" onClick={handleClose} className="w-full" disabled={isSubmitting}>Hủy</Button>
          <Button variant="danger" onClick={onConfirm} className="w-full" disabled={isSubmitting}>
            {isSubmitting ? 'Đang xóa...' : 'Xác nhận xóa'}
          </Button>
        </div>
      </div>
    </div>
  );
}
