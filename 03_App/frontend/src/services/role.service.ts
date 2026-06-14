import api from '@/lib/axios';

export interface RoleStat {
  role: string;
  count: number;
}

export const roleService = {
  getRoleStats: async () => {
    const { data } = await api.get<{ data: RoleStat[] }>('/roles/stats');
    return data;
  }
};
