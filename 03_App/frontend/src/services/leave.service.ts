import api from '@/lib/axios';

export interface Leave {
  id: string;
  empName: string;
  type: string;
  startDate: string;
  endDate: string;
  days: number;
  reason: string;
  status: string;
}

export const leaveService = {
  getLeaves: async () => {
    const { data } = await api.get<{ data: Leave[] }>('/leaves');
    return data;
  },
  approveLeave: async (id: string, action: 'A' | 'R', NguoiDuyet?: string, GhiChu?: string) => {
    const { data } = await api.put<{ message: string }>(`/leaves/${id}/approve`, { action, NguoiDuyet, GhiChu });
    return data;
  },
  createLeave: async (data: any) => {
    const response = await api.post('/leaves', data);
    return response.data;
  }
};
