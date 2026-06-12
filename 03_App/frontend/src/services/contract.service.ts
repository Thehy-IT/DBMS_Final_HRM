import api from '@/lib/axios';

export interface Contract {
  id: string;
  empId?: string;
  empName?: string;
  typeId?: string;
  type?: string;
  startDate: string;
  endDate: string | null;
  salary: number;
  status: string;
}

export const contractService = {
  getContracts: async () => {
    const { data } = await api.get<{ data: Contract[] }>('/contracts');
    return data;
  },
  getContractById: async (id: string) => {
    const { data } = await api.get<{ data: Contract }>(`/contracts/${id}`);
    return data.data;
  },
  createContract: async (contractData: Partial<Contract>) => {
    const { data } = await api.post<{ message: string }>('/contracts', contractData);
    return data;
  },
  updateContract: async (id: string, contractData: Partial<Contract>) => {
    const { data } = await api.put<{ message: string }>(`/contracts/${id}`, contractData);
    return data;
  }
};
