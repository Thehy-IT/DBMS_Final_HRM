import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import mysql from 'mysql2/promise';
import jwt from 'jsonwebtoken';
import bcrypt from 'bcryptjs';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { exec } from 'child_process';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

dotenv.config();

const app = express();
const PORT = process.env.PORT || 8080;

app.use(cors());
app.use(express.json());

// Database connection pool
const pool = mysql.createPool({
    host: process.env.DB_HOST || 'localhost',
    user: process.env.DB_USER || 'root',
    password: process.env.DB_PASSWORD || '',
    database: process.env.DB_NAME || 'HRPayrollDB',
    waitForConnections: true,
    connectionLimit: 10,
    queueLimit: 0
});

const JWT_SECRET = process.env.JWT_SECRET || 'hrpayroll_super_secret_key';

// Middleware Authentication
export const authenticateToken = (req, res, next) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];
  if (!token) return res.status(401).json({ error: 'Truy cập bị từ chối' });
  jwt.verify(token, JWT_SECRET, (err, user) => {
    if (err) return res.status(403).json({ error: 'Token không hợp lệ' });
    req.user = user;
    next();
  });
};

app.post('/v1/auth/login', async (req, res) => {
  const { username, password } = req.body;
  try {
    const [users] = await pool.query('SELECT * FROM TaiKhoan WHERE TenDangNhap = ? AND TrangThai = \'A\'', [username]);
    if (users.length === 0) return res.status(401).json({ error: 'Tài khoản không tồn tại' });
    const user = users[0];
    const validPassword = await bcrypt.compare(password, user.MatKhau);
    if (!validPassword) return res.status(401).json({ error: 'Sai mật khẩu' });
    const token = jwt.sign({ id: user.MaTK, username: user.TenDangNhap, role: user.Quyen, empId: user.MaNV }, JWT_SECRET, { expiresIn: '8h' });
    res.json({ token, user: { username: user.TenDangNhap, role: user.Quyen, empId: user.MaNV } });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.use('/v1', authenticateToken);

// Middleware Authorize for HR/ADMIN only operations
const requireHR = (req, res, next) => {
  if (req.user.role === 'EMPLOYEE') return res.status(403).json({ error: 'Không có quyền truy cập' });
  next();
};

const requireAdmin = (req, res, next) => {
  if (req.user.role !== 'ADMIN') return res.status(403).json({ error: 'Chỉ ADMIN mới có quyền truy cập' });
  next();
};

// CÁC ENDPOINT API CUNG CẤP DỮ LIỆU

// --- 0. Quản lý Tài khoản (Users) ---
app.get('/v1/users', requireAdmin, async (req, res) => {
  try {
    const [rows] = await pool.query(`
      SELECT t.MaTK, t.TenDangNhap, t.Quyen, t.TrangThai, t.NgayTao, t.MaNV, nv.HoTen 
      FROM TaiKhoan t 
      LEFT JOIN NhanVien nv ON t.MaNV = nv.MaNV
      ORDER BY t.NgayTao DESC
    `);
    res.json({ data: rows, meta: { total: rows.length } });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/v1/users', requireAdmin, async (req, res) => {
  const { TenDangNhap, MatKhau, Quyen, MaNV, TrangThai } = req.body;
  try {
    const hashedPassword = await bcrypt.hash(MatKhau, 10);
    const [result] = await pool.query(
      'INSERT INTO TaiKhoan (TenDangNhap, MatKhau, Quyen, MaNV, TrangThai) VALUES (?, ?, ?, ?, ?)',
      [TenDangNhap, hashedPassword, Quyen, MaNV || null, TrangThai || 'A']
    );
    res.status(201).json({ data: { MaTK: result.insertId, TenDangNhap, Quyen, MaNV, TrangThai } });
  } catch (err) {
    if (err.code === 'ER_DUP_ENTRY') {
      return res.status(400).json({ error: 'Tên đăng nhập đã tồn tại' });
    }
    res.status(500).json({ error: err.message });
  }
});

app.put('/v1/users/:id', requireAdmin, async (req, res) => {
  const { Quyen, MaNV, TrangThai, MatKhau } = req.body;
  try {
    let query = 'UPDATE TaiKhoan SET Quyen=?, MaNV=?, TrangThai=? WHERE MaTK=?';
    let params = [Quyen, MaNV || null, TrangThai, req.params.id];
    
    if (MatKhau) {
      const hashedPassword = await bcrypt.hash(MatKhau, 10);
      query = 'UPDATE TaiKhoan SET Quyen=?, MaNV=?, TrangThai=?, MatKhau=? WHERE MaTK=?';
      params = [Quyen, MaNV || null, TrangThai, hashedPassword, req.params.id];
    }
    
    await pool.query(query, params);
    res.json({ message: 'Cập nhật thành công' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.delete('/v1/users/:id', requireAdmin, async (req, res) => {
  try {
    await pool.query('DELETE FROM TaiKhoan WHERE MaTK=?', [req.params.id]);
    res.json({ message: 'Xóa thành công' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// --- 0.1 Vai trò (Roles) ---
app.get('/v1/roles/stats', requireAdmin, async (req, res) => {
  try {
    const [rows] = await pool.query(`
      SELECT Quyen AS role, COUNT(*) AS count
      FROM TaiKhoan
      GROUP BY Quyen
    `);
    res.json({ data: rows });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// 1. Lấy danh sách nhân viên
app.get('/v1/employees', async (req, res) => {
    try {
        let query = 'SELECT * FROM NhanVien';
        let params = [];
        if (req.user.role === 'EMPLOYEE') {
          query += ' WHERE MaNV = ?';
          params.push(req.user.empId);
        }
        const [rows] = await pool.query(query, params);
        res.json({ data: rows, meta: { total: rows.length, page: 1, lastPage: 1 } });
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: err.message });
    }
});

// 2. Lấy danh sách hợp đồng
app.get('/v1/contracts', async (req, res) => {
  try {
    let query = 'SELECT hd.MaHD as id, nv.HoTen as empName, lhd.TenLoaiHD as type, DATE_FORMAT(hd.NgayBatDau, "%Y-%m-%d") as startDate, DATE_FORMAT(hd.NgayKetThuc, "%Y-%m-%d") as endDate, hd.LuongCoBan as salary, hd.TrangThai as status FROM HopDong hd JOIN NhanVien nv ON hd.MaNV = nv.MaNV JOIN LoaiHopDong lhd ON hd.MaLoaiHD = lhd.MaLoaiHD';
    let params = [];
    if (req.user.role === 'EMPLOYEE') {
      query += ' WHERE hd.MaNV = ?';
      params.push(req.user.empId);
    }
    const [rows] = await pool.query(query, params);
    res.json({ data: rows });
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'Internal Server Error' });
  }
});

// 3. Lấy danh sách chấm công
app.get('/v1/attendance', async (req, res) => {
  try {
    let query = 'SELECT cc.MaCC as id, cc.MaNV as empId, nv.HoTen as name, DATE_FORMAT(cc.NgayCham, "%Y-%m-%d") as date, cc.GioVao as checkIn, cc.GioRa as checkOut, cc.TrangThai as status, cc.GhiChu as notes FROM ChamCong cc JOIN NhanVien nv ON cc.MaNV = nv.MaNV';
    let params = [];
    if (req.user.role === 'EMPLOYEE') {
      query += ' WHERE cc.MaNV = ?';
      params.push(req.user.empId);
    }
    const [rows] = await pool.query(query, params);
    res.json({ data: rows });
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'Internal Server Error' });
  }
});

app.post('/v1/attendance', requireHR, async (req, res) => {
  const { MaNV, NgayCham, TrangThai, GioVao, GioRa, SoGioTangCa, HeSoTangCa, GhiChu, NguoiCapNhat } = req.body;
  try {
    const connection = await pool.getConnection();
    try {
      await connection.query('SET @maCC = 0');
      await connection.query(
        `CALL sp_ChamCong_NhapHangNgay(?, ?, ?, ?, ?, ?, ?, ?, ?, @maCC)`,
        [MaNV, NgayCham, TrangThai, GioVao || null, GioRa || null, SoGioTangCa || 0, HeSoTangCa || 1.5, GhiChu || null, NguoiCapNhat || 'System']
      );
      const [rows] = await connection.query('SELECT @maCC as maCC');
      res.status(201).json({ message: 'Created/Updated successfully', id: rows[0].maCC });
    } finally {
      connection.release();
    }
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.put('/v1/attendance/:id', requireHR, async (req, res) => {
  const { TrangThai, GioVao, GioRa, SoGioTangCa, HeSoTangCa, GhiChu, NguoiCapNhat } = req.body;
  try {
    await pool.query(
      `CALL sp_ChamCong_CapNhat(?, ?, ?, ?, ?, ?, ?, ?)`,
      [req.params.id, TrangThai, GioVao || null, GioRa || null, SoGioTangCa || null, HeSoTangCa || null, GhiChu || null, NguoiCapNhat || 'System']
    );
    res.json({ message: 'Updated successfully' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// 4. Lấy danh sách bảng lương
app.get('/v1/payroll', async (req, res) => {
  try {
    let query = 'SELECT bl.MaBL as id, bl.Thang as month, bl.Nam as year, bl.MaNV as empId, nv.HoTen as name, pb.TenPB as dept, bl.LuongCoBan as basicSalary, bl.SoNgayCong as workingDays, bl.HeSoTangCa as otHours, bl.TongPhuCap as allowance, bl.TongKhauTru as deduction, bl.ThuNhapThucLinh as netSalary, bl.TrangThai as status FROM BangLuong bl JOIN NhanVien nv ON bl.MaNV = nv.MaNV JOIN PhongBan pb ON nv.MaPB = pb.MaPB';
    let params = [];
    if (req.user.role === 'EMPLOYEE') {
      query += ' WHERE bl.MaNV = ?';
      params.push(req.user.empId);
    }
    const [rows] = await pool.query(query, params);
    res.json({ data: rows });
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'Internal Server Error' });
  }
});

app.post('/v1/payroll/calculate', requireHR, async (req, res) => {
  const { month, year } = req.body;
  try {
    await pool.query(`CALL sp_TinhLuong(?, ?, NULL, 1, 0)`, [month, year]);
    res.json({ message: 'Tính lương hoàn tất' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.put('/v1/payroll/confirm', requireHR, async (req, res) => {
  const { month, year } = req.body;
  try {
    await pool.query(
      `UPDATE BangLuong SET TrangThai = 'C', NgayXacNhan = NOW() WHERE Thang = ? AND Nam = ? AND TrangThai = 'D'`,
      [month, year]
    );
    res.json({ message: 'Xác nhận bảng lương thành công' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.put('/v1/payroll/pay', requireHR, async (req, res) => {
  const { month, year } = req.body;
  try {
    await pool.query(
      `UPDATE BangLuong SET TrangThai = 'P', NgayThanhToan = CURDATE() WHERE Thang = ? AND Nam = ? AND TrangThai = 'C'`,
      [month, year]
    );
    res.json({ message: 'Thanh toán bảng lương thành công' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// 5. Lấy danh sách đơn xin nghỉ phép
app.get('/v1/leaves', async (req, res) => {
    try {
      let query = 'SELECT np.MaNP as id, nv.MaNV as empId, nv.HoTen as empName, lnp.TenLoaiNghi as type, DATE_FORMAT(np.NgayBatDau, "%Y-%m-%d") as startDate, DATE_FORMAT(np.NgayKetThuc, "%Y-%m-%d") as endDate, np.SoNgayNghi as days, np.LyDo as reason, np.TrangThai as status FROM NghiPhep np JOIN NhanVien nv ON np.MaNV = nv.MaNV JOIN LoaiNghiPhep lnp ON np.MaLoaiNghi = lnp.MaLoaiNghi';
    let params = [];
    if (req.user.role === 'EMPLOYEE') {
      query += ' WHERE np.MaNV = ?';
      params.push(req.user.empId);
    }
    const [rows] = await pool.query(query, params);
    res.json({ data: rows });
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'Internal Server Error' });
  }
});

app.post('/v1/leaves', async (req, res) => {
  const { MaNV, MaLoaiNghi, NgayBatDau, NgayKetThuc, LyDo } = req.body;
  if (req.user.role === 'EMPLOYEE' && req.user.empId !== MaNV) return res.status(403).json({ error: 'Không thể xin nghỉ cho người khác' });
  try {
    const [result] = await pool.query(
      `INSERT INTO NghiPhep (MaNV, MaLoaiNghi, NgayBatDau, NgayKetThuc, LyDo, TrangThai) VALUES (?, ?, ?, ?, ?, 'P')`,
      [MaNV, MaLoaiNghi, NgayBatDau, NgayKetThuc, LyDo || null]
    );
    res.status(201).json({ message: 'Tạo đơn nghỉ phép thành công', id: result.insertId });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.put('/v1/leaves/:id/approve', requireHR, async (req, res) => {
  const { action, NguoiDuyet, GhiChu } = req.body;
  try {
    await pool.query(
      `CALL sp_NghiPhep_PheDuyet(?, ?, ?, ?)`,
      [req.params.id, action, NguoiDuyet || 'System', GhiChu || null]
    );
    res.json({ message: 'Cập nhật trạng thái nghỉ phép thành công' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// --- MASTER DATA API ---
app.get('/v1/departments', async (req, res) => {
  try {
    const [rows] = await pool.query(`
      SELECT 
        MaPB as id, 
        TenPB as name, 
        pb.* 
      FROM PhongBan pb
    `);
    res.json({ data: rows });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.post('/v1/departments', requireAdmin, async (req, res) => {
  const { MaPB, TenPB, DiaDiem, DienThoai, Email, MaTruongPhong, NgayThanhLap, GhiChu, IsActive } = req.body;
  try {
    await pool.query(
      'INSERT INTO PhongBan (MaPB, TenPB, DiaDiem, DienThoai, Email, MaTruongPhong, NgayThanhLap, GhiChu, IsActive) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [MaPB, TenPB, DiaDiem || null, DienThoai || null, Email || null, MaTruongPhong || null, NgayThanhLap || null, GhiChu || null, IsActive !== undefined ? IsActive : 1]
    );
    res.status(201).json({ message: 'Tạo phòng ban thành công' });
  } catch (err) {
    if (err.code === 'ER_DUP_ENTRY') {
      return res.status(400).json({ error: 'Mã phòng ban hoặc Tên phòng ban đã tồn tại' });
    }
    res.status(500).json({ error: err.message });
  }
});

app.put('/v1/departments/:id', requireAdmin, async (req, res) => {
  const { TenPB, DiaDiem, DienThoai, Email, MaTruongPhong, NgayThanhLap, GhiChu, IsActive } = req.body;
  try {
    await pool.query(
      'UPDATE PhongBan SET TenPB=?, DiaDiem=?, DienThoai=?, Email=?, MaTruongPhong=?, NgayThanhLap=?, GhiChu=?, IsActive=? WHERE MaPB=?',
      [TenPB, DiaDiem || null, DienThoai || null, Email || null, MaTruongPhong || null, NgayThanhLap || null, GhiChu || null, IsActive !== undefined ? IsActive : 1, req.params.id]
    );
    res.json({ message: 'Cập nhật phòng ban thành công' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.delete('/v1/departments/:id', requireAdmin, async (req, res) => {
  try {
    // Check if there are employees in this department
    const [emps] = await pool.query('SELECT 1 FROM NhanVien WHERE MaPB = ? LIMIT 1', [req.params.id]);
    if (emps.length > 0) {
      return res.status(400).json({ error: 'Không thể xóa phòng ban đang có nhân viên' });
    }
    
    await pool.query('DELETE FROM PhongBan WHERE MaPB=?', [req.params.id]);
    res.json({ message: 'Xóa thành công' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.get('/v1/positions', async (req, res) => {
  try {
    const [rows] = await pool.query(`
      SELECT 
        MaCV as id, 
        TenCV as name, 
        cv.* 
      FROM ChucVu cv
    `);
    res.json({ data: rows });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.post('/v1/positions', requireAdmin, async (req, res) => {
  const { MaCV, TenCV, HeSoLuong, MoTa, CapBac, IsActive } = req.body;
  try {
    await pool.query(
      'INSERT INTO ChucVu (MaCV, TenCV, HeSoLuong, MoTa, CapBac, IsActive) VALUES (?, ?, ?, ?, ?, ?)',
      [MaCV, TenCV, HeSoLuong || 1.00, MoTa || null, CapBac || 1, IsActive !== undefined ? IsActive : 1]
    );
    res.status(201).json({ message: 'Tạo chức vụ thành công' });
  } catch (err) {
    if (err.code === 'ER_DUP_ENTRY') {
      return res.status(400).json({ error: 'Mã chức vụ hoặc Tên chức vụ đã tồn tại' });
    }
    res.status(500).json({ error: err.message });
  }
});

app.put('/v1/positions/:id', requireAdmin, async (req, res) => {
  const { TenCV, HeSoLuong, MoTa, CapBac, IsActive } = req.body;
  try {
    await pool.query(
      'UPDATE ChucVu SET TenCV=?, HeSoLuong=?, MoTa=?, CapBac=?, IsActive=? WHERE MaCV=?',
      [TenCV, HeSoLuong || 1.00, MoTa || null, CapBac || 1, IsActive !== undefined ? IsActive : 1, req.params.id]
    );
    res.json({ message: 'Cập nhật chức vụ thành công' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.delete('/v1/positions/:id', requireAdmin, async (req, res) => {
  try {
    // Check if there are employees with this position
    const [emps] = await pool.query('SELECT 1 FROM NhanVien WHERE MaCV = ? LIMIT 1', [req.params.id]);
    if (emps.length > 0) {
      return res.status(400).json({ error: 'Không thể xóa chức vụ đang có nhân viên đảm nhận' });
    }
    
    await pool.query('DELETE FROM ChucVu WHERE MaCV=?', [req.params.id]);
    res.json({ message: 'Xóa thành công' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.get('/v1/contract-types', async (req, res) => {
  try {
    const [rows] = await pool.query(`
      SELECT 
        MaLoaiHD as id, 
        TenLoaiHD as name, 
        hd.* 
      FROM LoaiHopDong hd
    `);
    res.json({ data: rows });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.post('/v1/contract-types', requireAdmin, async (req, res) => {
  const { TenLoaiHD, ThoiHanToiDa, TiLeBHXH, MoTa } = req.body;
  try {
    await pool.query(
      'INSERT INTO LoaiHopDong (TenLoaiHD, ThoiHanToiDa, TiLeBHXH, MoTa) VALUES (?, ?, ?, ?)',
      [TenLoaiHD, ThoiHanToiDa || null, TiLeBHXH !== undefined ? TiLeBHXH : 8.00, MoTa || null]
    );
    res.status(201).json({ message: 'Tạo loại hợp đồng thành công' });
  } catch (err) {
    if (err.code === 'ER_DUP_ENTRY') {
      return res.status(400).json({ error: 'Tên loại hợp đồng đã tồn tại' });
    }
    res.status(500).json({ error: err.message });
  }
});

app.put('/v1/contract-types/:id', requireAdmin, async (req, res) => {
  const { TenLoaiHD, ThoiHanToiDa, TiLeBHXH, MoTa } = req.body;
  try {
    await pool.query(
      'UPDATE LoaiHopDong SET TenLoaiHD=?, ThoiHanToiDa=?, TiLeBHXH=?, MoTa=? WHERE MaLoaiHD=?',
      [TenLoaiHD, ThoiHanToiDa || null, TiLeBHXH !== undefined ? TiLeBHXH : 8.00, MoTa || null, req.params.id]
    );
    res.json({ message: 'Cập nhật loại hợp đồng thành công' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.delete('/v1/contract-types/:id', requireAdmin, async (req, res) => {
  try {
    // Check if there are contracts with this type
    const [contracts] = await pool.query('SELECT 1 FROM HopDongLaoDong WHERE MaLoaiHD = ? LIMIT 1', [req.params.id]);
    if (contracts.length > 0) {
      return res.status(400).json({ error: 'Không thể xóa loại hợp đồng đang được sử dụng cho nhân viên' });
    }
    
    await pool.query('DELETE FROM LoaiHopDong WHERE MaLoaiHD=?', [req.params.id]);
    res.json({ message: 'Xóa thành công' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.get('/v1/benefit-types', async (req, res) => {
  try {
    const [rows] = await pool.query(`
      SELECT 
        MaFL as id, 
        TenFL as name, 
        fl.* 
      FROM LoaiPhucLoi fl
    `);
    res.json({ data: rows });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.post('/v1/benefit-types', requireAdmin, async (req, res) => {
  const { MaFL, TenFL, LoaiGiaTri, GiaTri, CoTinhThue, MoTa, IsActive } = req.body;
  try {
    await pool.query(
      'INSERT INTO LoaiPhucLoi (MaFL, TenFL, LoaiGiaTri, GiaTri, CoTinhThue, MoTa, IsActive) VALUES (?, ?, ?, ?, ?, ?, ?)',
      [MaFL, TenFL, LoaiGiaTri || 'F', GiaTri || 0, CoTinhThue !== undefined ? CoTinhThue : 0, MoTa || null, IsActive !== undefined ? IsActive : 1]
    );
    res.status(201).json({ message: 'Tạo loại phúc lợi thành công' });
  } catch (err) {
    if (err.code === 'ER_DUP_ENTRY') {
      return res.status(400).json({ error: 'Mã hoặc tên loại phúc lợi đã tồn tại' });
    }
    res.status(500).json({ error: err.message });
  }
});

app.put('/v1/benefit-types/:id', requireAdmin, async (req, res) => {
  const { TenFL, LoaiGiaTri, GiaTri, CoTinhThue, MoTa, IsActive } = req.body;
  try {
    await pool.query(
      'UPDATE LoaiPhucLoi SET TenFL=?, LoaiGiaTri=?, GiaTri=?, CoTinhThue=?, MoTa=?, IsActive=? WHERE MaFL=?',
      [TenFL, LoaiGiaTri || 'F', GiaTri || 0, CoTinhThue !== undefined ? CoTinhThue : 0, MoTa || null, IsActive !== undefined ? IsActive : 1, req.params.id]
    );
    res.json({ message: 'Cập nhật loại phúc lợi thành công' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.delete('/v1/benefit-types/:id', requireAdmin, async (req, res) => {
  try {
    // Check if there are employees linked to this benefit
    const [empBenefits] = await pool.query('SELECT 1 FROM NhanVien_PhucLoi WHERE MaFL = ? LIMIT 1', [req.params.id]);
    if (empBenefits.length > 0) {
      return res.status(400).json({ error: 'Không thể xóa phúc lợi đang được áp dụng cho nhân viên' });
    }
    
    await pool.query('DELETE FROM LoaiPhucLoi WHERE MaFL=?', [req.params.id]);
    res.json({ message: 'Xóa thành công' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.get('/v1/leave-types', async (req, res) => {
  try {
    const [rows] = await pool.query('SELECT MaLoaiNghi as id, TenLoaiNghi as name FROM LoaiNghiPhep');
    res.json({ data: rows });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// --- CONTRACT CRUD API ---
app.get('/v1/contracts/:id', async (req, res) => {
  try {
    const [rows] = await pool.query(`
      SELECT hd.MaHD as id, hd.MaNV as empId, nv.HoTen as empName, hd.MaLoaiHD as typeId, lhd.TenLoaiHD as type, 
             DATE_FORMAT(hd.NgayBatDau, "%Y-%m-%d") as startDate, DATE_FORMAT(hd.NgayKetThuc, "%Y-%m-%d") as endDate, 
             hd.LuongCoBan as salary, hd.TrangThai as status, hd.VungLuong 
      FROM HopDong hd 
      JOIN NhanVien nv ON hd.MaNV = nv.MaNV 
      JOIN LoaiHopDong lhd ON hd.MaLoaiHD = lhd.MaLoaiHD 
      WHERE hd.MaHD = ?
    `, [req.params.id]);
    if (rows.length === 0) return res.status(404).json({ error: 'Not found' });
    res.json({ data: rows[0] });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/v1/contracts', requireHR, async (req, res) => {
  const { id, empId, typeId, startDate, endDate, salary, status, VungLuong } = req.body;
  try {
    let MaHD = id;
    if (!MaHD) {
      const [rows] = await pool.query('SELECT MaHD FROM HopDong ORDER BY MaHD DESC LIMIT 1');
      MaHD = 'HD00000001';
      if (rows.length > 0) {
        const lastMaHD = rows[0].MaHD;
        const numPart = parseInt(lastMaHD.substring(2), 10);
        const nextNum = numPart + 1;
        MaHD = `HD${nextNum.toString().padStart(8, '0')}`;
      }
    }

    const query = `
      INSERT INTO HopDong 
      (MaHD, MaNV, MaLoaiHD, NgayBatDau, NgayKetThuc, LuongCoBan, VungLuong, TrangThai)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    `;
    await pool.query(query, [MaHD, empId, typeId, startDate, endDate || null, salary, VungLuong || 1, status || 'A']);
    res.status(201).json({ message: 'Created successfully', data: { id: MaHD } });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.put('/v1/contracts/:id', requireHR, async (req, res) => {
  const { empId, typeId, startDate, endDate, salary, status, VungLuong } = req.body;
  try {
    const query = `
      UPDATE HopDong 
      SET MaNV=?, MaLoaiHD=?, NgayBatDau=?, NgayKetThuc=?, LuongCoBan=?, VungLuong=?, TrangThai=?
      WHERE MaHD=?
    `;
    await pool.query(query, [empId, typeId, startDate, endDate || null, salary, VungLuong || 1, status || 'A', req.params.id]);
    res.json({ message: 'Updated successfully' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// --- EMPLOYEE CRUD API ---
app.get('/v1/employees/:id', async (req, res) => {
  try {
    const [rows] = await pool.query('SELECT * FROM NhanVien WHERE MaNV = ?', [req.params.id]);
    if (rows.length === 0) return res.status(404).json({ error: 'Not found' });
    res.json({ data: rows[0] });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/v1/employees', requireHR, async (req, res) => {
  const { HoTen, GioiTinh, NgaySinh, CCCD, SoDienThoai, Email, DiaChi, MaPB, MaCV, NgayVaoLam, NgayNghiViec, MaSoThue, SoTaiKhoanNH, TenNganHang, SoNguoiPhuThuoc, GhiChu, TrangThai } = req.body;
  try {
    // Auto-generate MaNV
    const [rows] = await pool.query('SELECT MaNV FROM NhanVien ORDER BY MaNV DESC LIMIT 1');
    let MaNV = 'NV000001';
    if (rows.length > 0) {
      const lastMaNV = rows[0].MaNV;
      const numPart = parseInt(lastMaNV.substring(2), 10);
      const nextNum = numPart + 1;
      MaNV = `NV${nextNum.toString().padStart(6, '0')}`;
    }

    const sanitizedMaSoThue = MaSoThue ? MaSoThue.trim() : null;
    const finalMaSoThue = sanitizedMaSoThue === '' ? null : sanitizedMaSoThue;

    const query = `
      INSERT INTO NhanVien 
      (MaNV, HoTen, GioiTinh, NgaySinh, CCCD, SoDienThoai, Email, DiaChi, MaPB, MaCV, NgayVaoLam, NgayNghiViec, MaSoThue, SoTaiKhoanNH, TenNganHang, SoNguoiPhuThuoc, GhiChu, TrangThai)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `;
    await pool.query(query, [MaNV, HoTen, GioiTinh, NgaySinh, CCCD, SoDienThoai, Email, DiaChi || null, MaPB, MaCV, NgayVaoLam, NgayNghiViec || null, finalMaSoThue, SoTaiKhoanNH || null, TenNganHang || null, SoNguoiPhuThuoc || 0, GhiChu || null, TrangThai || 'A']);
    res.status(201).json({ message: 'Created successfully', data: { MaNV } });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.put('/v1/employees/:id', requireHR, async (req, res) => {
  const { HoTen, GioiTinh, NgaySinh, CCCD, SoDienThoai, Email, DiaChi, MaPB, MaCV, NgayVaoLam, NgayNghiViec, MaSoThue, SoTaiKhoanNH, TenNganHang, SoNguoiPhuThuoc, GhiChu, TrangThai } = req.body;
  try {
    const sanitizedMaSoThue = MaSoThue ? MaSoThue.trim() : null;
    const finalMaSoThue = sanitizedMaSoThue === '' ? null : sanitizedMaSoThue;

    const query = `
      UPDATE NhanVien 
      SET HoTen=?, GioiTinh=?, NgaySinh=?, CCCD=?, SoDienThoai=?, Email=?, DiaChi=?, MaPB=?, MaCV=?, NgayVaoLam=?, NgayNghiViec=?, MaSoThue=?, SoTaiKhoanNH=?, TenNganHang=?, SoNguoiPhuThuoc=?, GhiChu=?, TrangThai=?
      WHERE MaNV=?
    `;
    await pool.query(query, [HoTen, GioiTinh, NgaySinh, CCCD, SoDienThoai, Email, DiaChi || null, MaPB, MaCV, NgayVaoLam, NgayNghiViec || null, finalMaSoThue, SoTaiKhoanNH || null, TenNganHang || null, SoNguoiPhuThuoc || 0, GhiChu || null, TrangThai || 'A', req.params.id]);
    res.json({ message: 'Updated successfully' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// System Logs (Audit)
app.get('/v1/system-logs', requireAdmin, async (req, res) => {
  try {
    const [rows] = await pool.query(`
      SELECT 
        MaLog as id,
        'Hợp đồng' as module,
        MaNV as empId,
        LoaiThayDoi as actionType,
        TenCot as columnName,
        GiaTriCu as oldValue,
        GiaTriMoi as newValue,
        NguoiThayDoi as changedBy,
        ThoiGianThayDoi as changedAt,
        HostName as hostName
      FROM AuditLog_HopDong
      UNION ALL
      SELECT 
        MaLog as id,
        'Bảng Lương' as module,
        MaNV as empId,
        LoaiThayDoi as actionType,
        TenCot as columnName,
        GiaTriCu as oldValue,
        GiaTriMoi as newValue,
        NguoiThayDoi as changedBy,
        ThoiGianThayDoi as changedAt,
        HostName as hostName
      FROM AuditLog_Luong
      ORDER BY changedAt DESC
      LIMIT 1000
    `);
    res.json({ data: rows });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// --- BACKUP API ---

const BACKUP_DIR = path.join(__dirname, 'backups');
if (!fs.existsSync(BACKUP_DIR)) {
  fs.mkdirSync(BACKUP_DIR);
}

app.get('/v1/backups', requireAdmin, (req, res) => {
  try {
    const files = fs.readdirSync(BACKUP_DIR)
      .filter(f => f.endsWith('.sql'))
      .map(f => {
        const stats = fs.statSync(path.join(BACKUP_DIR, f));
        return {
          id: f,
          fileName: f,
          createdAt: stats.birthtime,
          sizeBytes: stats.size,
          status: 'COMPLETED'
        };
      })
      .sort((a, b) => b.createdAt - a.createdAt);
    res.json({ data: files });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.post('/v1/backups', requireAdmin, (req, res) => {
  const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
  const fileName = `HRPayrollDB_backup_${timestamp}.sql`;
  const filePath = path.join(BACKUP_DIR, fileName);
  
  const dbUser = process.env.DB_USER || 'root';
  const dbPass = process.env.DB_PASSWORD || '';
  const dbName = process.env.DB_NAME || 'HRPayrollDB';
  const dbHost = process.env.DB_HOST || 'localhost';

  // Chú ý: Cần có mysqldump trong biến môi trường PATH
  const cmd = `mysqldump -h ${dbHost} -u ${dbUser} ${dbPass ? `-p${dbPass}` : ''} --routines --events ${dbName} > "${filePath}"`;
  
  exec(cmd, (error, stdout, stderr) => {
    if (error) {
      console.error(`Backup error: ${error.message}`);
      return res.status(500).json({ error: 'Không thể tạo bản sao lưu. Hãy chắc chắn mysqldump đã được cài đặt.' });
    }
    
    const stats = fs.statSync(filePath);
    res.status(201).json({ 
      message: 'Tạo bản sao lưu thành công',
      data: {
        id: fileName,
        fileName,
        createdAt: stats.birthtime,
        sizeBytes: stats.size,
        status: 'COMPLETED'
      }
    });
  });
});

app.delete('/v1/backups/:id', requireAdmin, (req, res) => {
  try {
    const filePath = path.join(BACKUP_DIR, req.params.id);
    if (fs.existsSync(filePath)) {
      fs.unlinkSync(filePath);
      res.json({ message: 'Đã xóa bản sao lưu' });
    } else {
      res.status(404).json({ error: 'Không tìm thấy file sao lưu' });
    }
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.get('/v1/backups/download/:id', (req, res) => {
  const filePath = path.join(BACKUP_DIR, req.params.id);
  if (fs.existsSync(filePath)) {
    res.download(filePath);
  } else {
    res.status(404).send('File not found');
  }
});

app.get('/v1/system/settings', requireAdmin, async (req, res) => {
  try {
    const [dbSize] = await pool.query(`
      SELECT table_schema "DB_Name",
      ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) "DB_Size_MB" 
      FROM information_schema.tables 
      WHERE table_schema = 'HRPayrollDB'
      GROUP BY table_schema;
    `);

    const [userCount] = await pool.query('SELECT COUNT(*) as count FROM TaiKhoan');
    const [empCount] = await pool.query('SELECT COUNT(*) as count FROM NhanVien');

    res.json({
      data: {
        system: {
          nodeVersion: process.version,
          platform: process.platform,
          memoryUsage: process.memoryUsage().heapUsed,
          uptime: process.uptime()
        },
        database: {
          name: process.env.DB_NAME || 'HRPayrollDB',
          host: process.env.DB_HOST || 'localhost',
          sizeMB: dbSize.length > 0 ? dbSize[0].DB_Size_MB : 0,
          status: 'Connected'
        },
        stats: {
          totalUsers: userCount[0].count,
          totalEmployees: empCount[0].count
        }
      }
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.listen(PORT, () => {
  console.log(`🚀 HRM Backend API is running at http://localhost:${PORT}`);
});
