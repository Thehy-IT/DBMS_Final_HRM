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
  }
};
