"use client";

import { X, Printer, Download } from "lucide-react";
import { formatMoney } from "@/lib/utils";

interface PayslipModalProps {
  isOpen: boolean;
  onClose: () => void;
  data: any;
}

export function PayslipModal({ isOpen, onClose, data }: PayslipModalProps) {
  if (!isOpen || !data) return null;

  const handlePrint = () => {
    window.print();
  };

  const handleDownload = () => {
    // html2canvas (thư viện đằng sau html2pdf) không hỗ trợ hệ màu oklch/lab của Tailwind V4
    // Do đó chúng ta phải dùng chức năng In (Save to PDF) mặc định của trình duyệt
    window.print();
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 sm:p-0">
      <div className="fixed inset-0 bg-black/50 backdrop-blur-sm" onClick={onClose} />
      
      <div className="relative bg-white rounded-xl shadow-2xl w-full max-w-2xl max-h-[90vh] overflow-y-auto animate-in zoom-in-95 duration-200">
        {/* Header - Not printed */}
        <div className="flex items-center justify-between p-4 border-b border-slate-200 sticky top-0 bg-white z-10 print:hidden">
          <h2 className="text-lg font-bold text-slate-900">Chi tiết phiếu lương</h2>
          <div className="flex items-center gap-2">
            <button onClick={handlePrint} className="p-2 hover:bg-slate-100 rounded-md text-slate-600 transition-colors" title="In phiếu">
              <Printer className="w-5 h-5" />
            </button>
            <button onClick={handleDownload} className="p-2 hover:bg-slate-100 rounded-md text-slate-600 transition-colors" title="Lưu PDF">
              <Download className="w-5 h-5" />
            </button>
            <button onClick={onClose} className="p-2 hover:bg-red-50 rounded-md text-slate-400 hover:text-red-500 transition-colors">
              <X className="w-5 h-5" />
            </button>
          </div>
        </div>

        {/* Payslip Content - Printed area */}
        <div className="p-8 print:p-0" id="payslip-content">
          <div className="text-center mb-8">
            <h1 className="text-2xl font-bold text-slate-900 uppercase tracking-wider">PHIẾU LƯƠNG NHÂN VIÊN</h1>
            <p className="text-slate-500 mt-1">Kỳ lương: {data.month}/{data.year}</p>
          </div>

          <div className="grid grid-cols-2 gap-6 mb-8 bg-slate-50 p-4 rounded-lg border border-slate-100">
            <div className="space-y-2">
              <p className="text-sm"><span className="text-slate-500 font-medium w-24 inline-block">Mã NV:</span> <span className="font-semibold">{data.empId}</span></p>
              <p className="text-sm"><span className="text-slate-500 font-medium w-24 inline-block">Họ Tên:</span> <span className="font-semibold uppercase">{data.name}</span></p>
              <p className="text-sm"><span className="text-slate-500 font-medium w-24 inline-block">Phòng ban:</span> <span className="font-semibold">{data.dept}</span></p>
            </div>
            <div className="space-y-2">
              <p className="text-sm"><span className="text-slate-500 font-medium w-24 inline-block">Ngày in:</span> <span>{new Date().toLocaleDateString('vi-VN')}</span></p>
              <p className="text-sm"><span className="text-slate-500 font-medium w-24 inline-block">Lương CB:</span> <span className="font-semibold text-indigo-600">{formatMoney(data.basicSalary)}</span></p>
            </div>
          </div>

          <div className="border rounded-lg overflow-hidden">
            <table className="w-full text-sm text-left">
              <thead className="bg-slate-50 border-b">
                <tr>
                  <th className="px-4 py-3 font-semibold text-slate-700">Diễn giải</th>
                  <th className="px-4 py-3 font-semibold text-slate-700 text-right">Số lượng/Hệ số</th>
                  <th className="px-4 py-3 font-semibold text-slate-700 text-right">Thành tiền</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100">
                <tr>
                  <td className="px-4 py-3 text-slate-600">1. Lương ngày công</td>
                  <td className="px-4 py-3 text-right text-slate-600">{data.workingDays} ngày</td>
                  <td className="px-4 py-3 text-right font-medium">{formatMoney(data.basicSalary)}</td>
                </tr>
                <tr>
                  <td className="px-4 py-3 text-slate-600">2. Lương tăng ca (OT)</td>
                  <td className="px-4 py-3 text-right text-slate-600">{data.otHours || 0} giờ</td>
                  <td className="px-4 py-3 text-right font-medium">{formatMoney(0)}</td>
                </tr>
                <tr>
                  <td className="px-4 py-3 text-slate-600">3. Phụ cấp</td>
                  <td className="px-4 py-3 text-right text-slate-600">-</td>
                  <td className="px-4 py-3 text-right font-medium text-emerald-600">+{formatMoney(data.allowance)}</td>
                </tr>
                <tr>
                  <td className="px-4 py-3 text-slate-600">4. Khấu trừ (BHXH, Thuế...)</td>
                  <td className="px-4 py-3 text-right text-slate-600">-</td>
                  <td className="px-4 py-3 text-right font-medium text-red-600">-{formatMoney(data.deduction)}</td>
                </tr>
              </tbody>
              <tfoot className="bg-slate-50 border-t border-slate-200">
                <tr>
                  <td colSpan={2} className="px-4 py-4 font-bold text-slate-900 text-right uppercase">Tổng Thực Lãnh:</td>
                  <td className="px-4 py-4 font-bold text-indigo-700 text-right text-lg">{formatMoney(data.netSalary)}</td>
                </tr>
              </tfoot>
            </table>
          </div>
          
          <div className="mt-12 grid grid-cols-2 gap-8 text-center pb-8">
            <div>
              <p className="font-semibold text-slate-900 mb-16">Người lập phiếu</p>
              <p className="text-sm text-slate-500">(Ký và ghi rõ họ tên)</p>
            </div>
            <div>
              <p className="font-semibold text-slate-900 mb-16">Người nhận</p>
              <p className="text-sm text-slate-500">(Ký và ghi rõ họ tên)</p>
            </div>
          </div>
        </div>
      </div>

      {/* Global styles for printing to hide everything except the modal content */}
      <style dangerouslySetInnerHTML={{__html: `
        @media print {
          body * {
            visibility: hidden;
          }
          #payslip-content, #payslip-content * {
            visibility: visible;
          }
          #payslip-content {
            position: absolute;
            left: 0;
            top: 0;
            width: 100%;
            padding: 0 !important;
            margin: 0 !important;
          }
          @page {
             margin: 1cm;
          }
        }
      `}} />
    </div>
  );
}
