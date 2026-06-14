import api from '@/lib/axios';

export interface User {
  MaTK: number;
  TenDangNhap: string;
  Quyen: 'ADMIN' | 'HR' | 'DIRECTOR' | 'EMPLOYEE' | 'ACCOUNTANT';
  TrangThai: 'A' | 'I'; // A = Active, I = Inactive
  NgayTao: string;
  MaNV?: string;
  HoTen?: string; // from Join
}

export const userService = {
  getUsers: async () => {
    const { data } = await api.get<{ data: User[]; meta: any }>('/users');
    return data;
  },
  createUser: async (userData: Partial<User> & { MatKhau: string }) => {
    const { data } = await api.post<{ data: User }>('/users', userData);
    return data;
  },
  updateUser: async (id: number, userData: Partial<User> & { MatKhau?: string }) => {
    const { data } = await api.put<{ message: string }>(`/users/${id}`, userData);
    return data;
  },
  deleteUser: async (id: number) => {
    const { data } = await api.delete<{ message: string }>(`/users/${id}`);
    return data;
  }
};
