import api from '@/lib/axios';

export interface MasterData {
  id: string;
  name: string;
}

export const masterDataService = {
  getDepartments: async () => {
    const { data } = await api.get<{ data: MasterData[] }>('/departments');
    return data.data;
  },
  getPositions: async () => {
    const { data } = await api.get<{ data: MasterData[] }>('/positions');
    return data.data;
  },
  getContractTypes: async () => {
    const { data } = await api.get<{ data: MasterData[] }>('/contract-types');
    return data.data;
  },
  getLeaveTypes: async () => {
    const { data } = await api.get<{ data: MasterData[] }>('/leave-types');
    return data.data;
  }
};
