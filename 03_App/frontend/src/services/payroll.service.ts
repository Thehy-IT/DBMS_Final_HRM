import api from '@/lib/axios';

export interface Payroll {
  id: string; // MaBL
  month?: number;
  year?: number;
  empId?: string;
  name: string;
  dept: string;
  basicSalary: number;
  workingDays: number;
  otHours: number;
  allowance: number;
  deduction: number;
  grossSalary: number;
  bhxh: number;
  bhyt: number;
  bhtn: number;
  tax: number;
  netSalary: number;
  status: string;
}

export const payrollService = {
  getPayroll: async () => {
    const { data } = await api.get<{ data: Payroll[] }>('/payroll');
    return data;
  },
  calculatePayroll: async (month: number, year: number) => {
    const { data } = await api.post<{ message: string }>('/payroll/calculate', { month, year });
    return data;
  },
  confirmPayroll: async (month: number, year: number) => {
    const { data } = await api.put<{ message: string }>('/payroll/confirm', { month, year });
    return data;
  },
  payPayroll: async (month: number, year: number) => {
    const { data } = await api.put<{ message: string }>('/payroll/pay', { month, year });
    return data;
  }
};
