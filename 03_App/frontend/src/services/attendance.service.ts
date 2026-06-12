import api from '@/lib/axios';

export interface Attendance {
  id: string; // MaCC
  empId?: string; // MaNV
  name?: string;
  date: string;
  checkIn: string | null;
  checkOut: string | null;
  status: string;
  notes: string | null;
}

export const attendanceService = {
  getAttendance: async () => {
    const { data } = await api.get<{ data: Attendance[] }>('/attendance');
    return data;
  },
  createAttendance: async (attendanceData: any) => {
    const { data } = await api.post<{ id: string }>('/attendance', attendanceData);
    return data;
  },
  updateAttendance: async (id: string, attendanceData: any) => {
    const { data } = await api.put<{ message: string }>(`/attendance/${id}`, attendanceData);
    return data;
  }
};
