import api from '@/lib/axios';

export interface MasterData {
  id: string; // Alias for MaPB
  name: string; // Alias for TenPB
  MaPB?: string;
  TenPB?: string;
  DiaDiem?: string;
  DienThoai?: string;
  Email?: string;
  MaTruongPhong?: string;
  NgayThanhLap?: string;
  GhiChu?: string;
  IsActive?: number;
  MaCV?: string;
  TenCV?: string;
  HeSoLuong?: number;
  MoTa?: string;
  CapBac?: number;
  MaLoaiHD?: number;
  TenLoaiHD?: string;
  ThoiHanToiDa?: number;
  TiLeBHXH?: number;
  MaFL?: string;
  TenFL?: string;
  LoaiGiaTri?: string;
  GiaTri?: number;
  CoTinhThue?: number;
}

export const masterDataService = {
  getDepartments: async () => {
    const { data } = await api.get<{ data: MasterData[] }>('/departments');
    return data.data;
  },
  createDepartment: async (deptData: any) => {
    const { data } = await api.post('/departments', deptData);
    return data;
  },
  updateDepartment: async (id: string, deptData: any) => {
    const { data } = await api.put(`/departments/${id}`, deptData);
    return data;
  },
  deleteDepartment: async (id: string) => {
    const { data } = await api.delete(`/departments/${id}`);
    return data;
  },
  getPositions: async () => {
    const { data } = await api.get<{ data: MasterData[] }>('/positions');
    return data.data;
  },
  createPosition: async (posData: any) => {
    const { data } = await api.post('/positions', posData);
    return data;
  },
  updatePosition: async (id: string, posData: any) => {
    const { data } = await api.put(`/positions/${id}`, posData);
    return data;
  },
  deletePosition: async (id: string) => {
    const { data } = await api.delete(`/positions/${id}`);
    return data;
  },
  getContractTypes: async () => {
    const { data } = await api.get<{ data: MasterData[] }>('/contract-types');
    return data.data;
  },
  createContractType: async (contractData: any) => {
    const { data } = await api.post('/contract-types', contractData);
    return data;
  },
  updateContractType: async (id: string, contractData: any) => {
    const { data } = await api.put(`/contract-types/${id}`, contractData);
    return data;
  },
  deleteContractType: async (id: string) => {
    const { data } = await api.delete(`/contract-types/${id}`);
    return data;
  },
  getBenefitTypes: async () => {
    const { data } = await api.get<{ data: MasterData[] }>('/benefit-types');
    return data.data;
  },
  createBenefitType: async (benefitData: any) => {
    const { data } = await api.post('/benefit-types', benefitData);
    return data;
  },
  updateBenefitType: async (id: string, benefitData: any) => {
    const { data } = await api.put(`/benefit-types/${id}`, benefitData);
    return data;
  },
  deleteBenefitType: async (id: string) => {
    const { data } = await api.delete(`/benefit-types/${id}`);
    return data;
  },
  getLeaveTypes: async () => {
    const { data } = await api.get<{ data: MasterData[] }>('/leave-types');
    return data.data;
  },
  getSystemLogs: async () => {
    const { data } = await api.get<{ data: any[] }>('/system-logs');
    return data.data;
  },
  getBackups: async () => {
    const { data } = await api.get<{ data: any[] }>('/backups');
    return data.data;
  },
  createBackup: async () => {
    const { data } = await api.post('/backups');
    return data;
  },
  deleteBackup: async (id: string) => {
    const { data } = await api.delete(`/backups/${id}`);
    return data;
  },
  getSystemSettings: async () => {
    const { data } = await api.get<{ data: any }>('/system/settings');
    return data.data;
  }
};
