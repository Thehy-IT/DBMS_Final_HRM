"use client";

import React from 'react';
import { Calculator, AlertTriangle, Coins, Percent, FileText, ChevronRight, ShieldAlert } from 'lucide-react';
import { formatMoney } from '@/lib/utils';

const TAX_BRACKETS = [
  { min: 0, max: 5000000, rate: 5 },
  { min: 5000000, max: 10000000, rate: 10 },
  { min: 10000000, max: 18000000, rate: 15 },
  { min: 18000000, max: 32000000, rate: 20 },
  { min: 32000000, max: 52000000, rate: 25 },
  { min: 52000000, max: 80000000, rate: 30 },
  { min: 80000000, max: null, rate: 35 },
];

export default function PayrollFormulasPage() {
  return (
    <div className="space-y-6 animate-in fade-in duration-300">
      <div>
        <h1 className="text-2xl font-bold text-slate-900 flex items-center gap-2">
          <Calculator className="h-6 w-6 text-indigo-600" />
          Tham số & Công thức lương
        </h1>
        <p className="text-sm text-slate-500 mt-1 max-w-3xl">
          Tài liệu tham chiếu các công thức tính toán thuế Thu Nhập Cá Nhân (TNCN) và Bảo Hiểm (BHXH, BHYT, BHTN) được lập trình nguyên khối dưới Cơ sở dữ liệu theo quy định hiện hành.
        </p>
      </div>

      <div className="bg-amber-50 border border-amber-200 rounded-lg p-4 flex gap-3 items-start">
        <ShieldAlert className="w-5 h-5 text-amber-600 flex-shrink-0 mt-0.5" />
        <div className="text-sm text-amber-800">
          <p className="font-semibold mb-1">Cấu hình tính lương tĩnh (Static SQL Functions)</p>
          <p>
            Các công thức tính Thuế lũy tiến 7 bậc và Tỷ lệ Bảo hiểm được thiết lập trực tiếp thông qua các hàm <code>fn_TinhThueTNCN_Scalar</code> và <code>fn_TinhBHXH</code> trong CSDL MySQL. Giao diện này mang tính chất tra cứu. Mọi thay đổi về luật Thuế/Bảo hiểm vui lòng yêu cầu kỹ thuật viên cập nhật Script SQL của hệ thống.
          </p>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* THUẾ TNCN */}
        <div className="bg-white rounded-xl shadow-sm border border-slate-200 overflow-hidden flex flex-col">
          <div className="bg-indigo-50 border-b border-indigo-100 p-4 flex items-center gap-3">
            <div className="bg-indigo-100 text-indigo-600 p-2 rounded-lg">
              <Coins className="w-5 h-5" />
            </div>
            <div>
              <h2 className="font-bold text-slate-800 text-lg">Thuế Thu Nhập Cá Nhân (TNCN)</h2>
              <p className="text-xs text-slate-500">Áp dụng biểu thuế lũy tiến từng phần 7 bậc</p>
            </div>
          </div>
          
          <div className="p-5 flex-grow space-y-6">
            <div>
              <h3 className="text-sm font-bold text-slate-800 uppercase tracking-wider mb-3">1. Căn cứ giảm trừ</h3>
              <div className="grid grid-cols-2 gap-4">
                <div className="bg-slate-50 p-3 rounded-lg border border-slate-100">
                  <p className="text-xs text-slate-500 mb-1">Bản thân người nộp thuế</p>
                  <p className="font-bold text-slate-800 text-base">11,000,000 <span className="text-sm font-normal">VNĐ/tháng</span></p>
                </div>
                <div className="bg-slate-50 p-3 rounded-lg border border-slate-100">
                  <p className="text-xs text-slate-500 mb-1">Người phụ thuộc</p>
                  <p className="font-bold text-slate-800 text-base">4,400,000 <span className="text-sm font-normal">VNĐ/tháng</span></p>
                </div>
              </div>
            </div>

            <div>
              <h3 className="text-sm font-bold text-slate-800 uppercase tracking-wider mb-3">2. Biểu thuế lũy tiến</h3>
              <div className="border border-slate-200 rounded-lg overflow-hidden">
                <table className="w-full text-sm text-left">
                  <thead className="bg-slate-50 text-xs text-slate-500 uppercase">
                    <tr>
                      <th className="px-4 py-3 font-medium">Bậc</th>
                      <th className="px-4 py-3 font-medium">Phần thu nhập tính thuế / tháng</th>
                      <th className="px-4 py-3 font-medium text-right">Thuế suất</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-slate-100">
                    {TAX_BRACKETS.map((bracket, idx) => (
                      <tr key={idx} className="hover:bg-slate-50">
                        <td className="px-4 py-2.5 font-medium text-slate-700">Bậc {idx + 1}</td>
                        <td className="px-4 py-2.5 text-slate-600">
                          {bracket.max === null 
                            ? `Trên ${formatMoney(bracket.min)}` 
                            : `${formatMoney(bracket.min)} - ${formatMoney(bracket.max)}`}
                        </td>
                        <td className="px-4 py-2.5 text-right font-bold text-indigo-600">
                          {bracket.rate}%
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>
          </div>
        </div>

        {/* BẢO HIỂM */}
        <div className="bg-white rounded-xl shadow-sm border border-slate-200 overflow-hidden flex flex-col">
          <div className="bg-emerald-50 border-b border-emerald-100 p-4 flex items-center gap-3">
            <div className="bg-emerald-100 text-emerald-600 p-2 rounded-lg">
              <Percent className="w-5 h-5" />
            </div>
            <div>
              <h2 className="font-bold text-slate-800 text-lg">Bảo hiểm Bắt buộc</h2>
              <p className="text-xs text-slate-500">BHXH, BHYT, BHTN theo luật hiện hành</p>
            </div>
          </div>
          
          <div className="p-5 flex-grow space-y-6">
            <div>
              <h3 className="text-sm font-bold text-slate-800 uppercase tracking-wider mb-3">1. Quy định chung</h3>
              <ul className="space-y-2 text-sm text-slate-600">
                <li className="flex items-start gap-2">
                  <ChevronRight className="w-4 h-4 text-emerald-500 flex-shrink-0 mt-0.5" />
                  <span><strong className="text-slate-800">Trần đóng bảo hiểm:</strong> Tối đa <span className="font-bold text-rose-600">46,800,000 VNĐ</span> (Bằng 20 lần mức lương cơ sở hiện hành).</span>
                </li>
                <li className="flex items-start gap-2">
                  <ChevronRight className="w-4 h-4 text-emerald-500 flex-shrink-0 mt-0.5" />
                  <span><strong className="text-slate-800">Hợp đồng thử việc:</strong> Tuyệt đối <span className="font-bold text-emerald-600">không</span> trích nộp các khoản BHXH, BHYT, BHTN (Tỷ lệ = 0%).</span>
                </li>
              </ul>
            </div>

            <div>
              <h3 className="text-sm font-bold text-slate-800 uppercase tracking-wider mb-3">2. Tỷ lệ trích nộp</h3>
              <div className="border border-slate-200 rounded-lg overflow-hidden">
                <table className="w-full text-sm text-left">
                  <thead className="bg-slate-50 text-xs text-slate-500 uppercase">
                    <tr>
                      <th className="px-4 py-3 font-medium">Loại bảo hiểm</th>
                      <th className="px-4 py-3 font-medium text-center">Doanh nghiệp đóng<br/><span className="text-[10px] font-normal lowercase">(Tính vào chi phí)</span></th>
                      <th className="px-4 py-3 font-medium text-center">Người lao động đóng<br/><span className="text-[10px] font-normal lowercase">(Khấu trừ vào lương)</span></th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-slate-100">
                    <tr className="hover:bg-slate-50">
                      <td className="px-4 py-3 font-medium text-slate-700">BHXH (Hưu trí, Tử tuất)</td>
                      <td className="px-4 py-3 text-center text-slate-600">14%</td>
                      <td className="px-4 py-3 text-center text-slate-600">8%</td>
                    </tr>
                    <tr className="hover:bg-slate-50">
                      <td className="px-4 py-3 font-medium text-slate-700">BHXH (Ốm đau, Thai sản)</td>
                      <td className="px-4 py-3 text-center text-slate-600">3%</td>
                      <td className="px-4 py-3 text-center text-slate-600">-</td>
                    </tr>
                    <tr className="hover:bg-slate-50">
                      <td className="px-4 py-3 font-medium text-slate-700">BH TNLĐ, BNN</td>
                      <td className="px-4 py-3 text-center text-slate-600">0.5%</td>
                      <td className="px-4 py-3 text-center text-slate-600">-</td>
                    </tr>
                    <tr className="hover:bg-slate-50">
                      <td className="px-4 py-3 font-medium text-slate-700">BHYT (Y tế)</td>
                      <td className="px-4 py-3 text-center text-slate-600">3%</td>
                      <td className="px-4 py-3 text-center text-slate-600">1.5%</td>
                    </tr>
                    <tr className="hover:bg-slate-50">
                      <td className="px-4 py-3 font-medium text-slate-700">BHTN (Thất nghiệp)</td>
                      <td className="px-4 py-3 text-center text-slate-600">1%</td>
                      <td className="px-4 py-3 text-center text-slate-600">1%</td>
                    </tr>
                    <tr className="bg-slate-50 font-bold border-t-2 border-slate-200">
                      <td className="px-4 py-3 text-slate-800 text-right">Tổng cộng:</td>
                      <td className="px-4 py-3 text-center text-emerald-600 text-base">21.5%</td>
                      <td className="px-4 py-3 text-center text-rose-600 text-base">10.5%</td>
                    </tr>
                  </tbody>
                </table>
              </div>
            </div>
            
            <div className="bg-slate-50 p-3 rounded-lg border border-slate-100 flex gap-3 mt-4">
              <FileText className="w-5 h-5 text-slate-400 flex-shrink-0" />
              <p className="text-xs text-slate-500 italic">
                * Tỷ lệ 22% ở Doanh nghiệp đang được áp dụng trong hàm fn_TinhBH_NSDLD bao gồm 17.5% BHXH + 3% BHYT + 1% BHTN + 0.5% BHTNLĐ.
              </p>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
