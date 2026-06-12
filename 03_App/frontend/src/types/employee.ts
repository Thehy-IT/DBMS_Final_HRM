export interface Employee {
  MaNV: string;
  HoTen: string;
  GioiTinh: 'M' | 'F' | 'O';
  NgaySinh: string;
  CCCD: string;
  SoDienThoai?: string;
  Email?: string;
  DiaChi?: string;
  MaPB: string;
  MaCV: string;
  NgayVaoLam: string;
  MaSoThue?: string;
  SoTaiKhoanNH?: string;
  TrangThai?: string;
}

export interface PaginatedResponse<T> {
  data: T[];
  meta: {
    total: number;
    page: number;
    lastPage: number;
  };
}
