import api from '@/lib/axios';
import { Employee, PaginatedResponse } from '@/types/employee';

export const employeeService = {
  getEmployees: async (params?: { page?: number; limit?: number; search?: string; department?: string; status?: string }) => {
    const { data } = await api.get<PaginatedResponse<Employee>>('/employees', { params });
    return data;
  },

  getEmployeeById: async (id: string) => {
    const { data } = await api.get<Employee>(`/employees/${id}`);
    return data;
  },

  createEmployee: async (employeeData: Partial<Employee>) => {
    const { data } = await api.post<Employee>('/employees', employeeData);
    return data;
  },

  updateEmployee: async (id: string, employeeData: Partial<Employee>) => {
    const { data } = await api.put<Employee>(`/employees/${id}`, employeeData);
    return data;
  },

  // --- Benefits ---
  getEmployeeBenefits: async (empId: string) => {
    const { data } = await api.get(`/employee-benefits/${empId}`);
    return data;
  },
  addEmployeeBenefit: async (benefitData: any) => {
    const { data } = await api.post('/employee-benefits', benefitData);
    return data;
  },
  removeEmployeeBenefit: async (empId: string, maFL: string, ngayApDung: string) => {
    const { data } = await api.delete(`/employee-benefits/${empId}/${maFL}/${ngayApDung}`);
    return data;
  },

  // --- Deductions ---
  getEmployeeDeductions: async (empId: string) => {
    const { data } = await api.get(`/deductions/${empId}`);
    return data;
  },
  addEmployeeDeduction: async (deductionData: any) => {
    const { data } = await api.post('/deductions', deductionData);
    return data;
  },
  removeEmployeeDeduction: async (id: string) => {
    const { data } = await api.delete(`/deductions/${id}`);
    return data;
  }
};
