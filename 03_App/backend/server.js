import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import mysql from 'mysql2/promise';
import jwt from 'jsonwebtoken';
import bcrypt from 'bcryptjs';

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

// CÁC ENDPOINT API CUNG CẤP DỮ LIỆU

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
    let query = 'SELECT np.MaNP as id, nv.HoTen as empName, lnp.TenLoaiNghi as type, DATE_FORMAT(np.NgayBatDau, "%Y-%m-%d") as startDate, DATE_FORMAT(np.NgayKetThuc, "%Y-%m-%d") as endDate, np.SoNgayNghi as days, np.LyDo as reason, np.TrangThai as status FROM NghiPhep np JOIN NhanVien nv ON np.MaNV = nv.MaNV JOIN LoaiNghiPhep lnp ON np.MaLoaiNghi = lnp.MaLoaiNghi';
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
    const [rows] = await pool.query('SELECT MaPB as id, TenPB as name FROM PhongBan');
    res.json({ data: rows });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.get('/v1/positions', async (req, res) => {
  try {
    const [rows] = await pool.query('SELECT MaCV as id, TenCV as name FROM ChucVu');
    res.json({ data: rows });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.get('/v1/contract-types', async (req, res) => {
  try {
    const [rows] = await pool.query('SELECT MaLoaiHD as id, TenLoaiHD as name FROM LoaiHopDong');
    res.json({ data: rows });
  } catch (error) {
    res.status(500).json({ error: error.message });
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
    const query = `
      INSERT INTO HopDong 
      (MaHD, MaNV, MaLoaiHD, NgayBatDau, NgayKetThuc, LuongCoBan, VungLuong, TrangThai)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    `;
    await pool.query(query, [id, empId, typeId, startDate, endDate || null, salary, VungLuong || 1, status || 'A']);
    res.status(201).json({ message: 'Created successfully' });
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
  const { MaNV, HoTen, GioiTinh, NgaySinh, CCCD, SoDienThoai, Email, DiaChi, MaPB, MaCV, NgayVaoLam, MaSoThue, SoTaiKhoanNH, TrangThai } = req.body;
  try {
    const query = `
      INSERT INTO NhanVien 
      (MaNV, HoTen, GioiTinh, NgaySinh, CCCD, SoDienThoai, Email, DiaChi, MaPB, MaCV, NgayVaoLam, MaSoThue, SoTaiKhoanNH, TrangThai)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `;
    await pool.query(query, [MaNV, HoTen, GioiTinh, NgaySinh, CCCD, SoDienThoai, Email, DiaChi || null, MaPB, MaCV, NgayVaoLam, MaSoThue || null, SoTaiKhoanNH || null, TrangThai || 'A']);
    res.status(201).json({ message: 'Created successfully', data: { MaNV } });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.put('/v1/employees/:id', requireHR, async (req, res) => {
  const { HoTen, GioiTinh, NgaySinh, CCCD, SoDienThoai, Email, DiaChi, MaPB, MaCV, NgayVaoLam, MaSoThue, SoTaiKhoanNH, TrangThai } = req.body;
  try {
    const query = `
      UPDATE NhanVien 
      SET HoTen=?, GioiTinh=?, NgaySinh=?, CCCD=?, SoDienThoai=?, Email=?, DiaChi=?, MaPB=?, MaCV=?, NgayVaoLam=?, MaSoThue=?, SoTaiKhoanNH=?, TrangThai=?
      WHERE MaNV=?
    `;
    await pool.query(query, [HoTen, GioiTinh, NgaySinh, CCCD, SoDienThoai, Email, DiaChi || null, MaPB, MaCV, NgayVaoLam, MaSoThue || null, SoTaiKhoanNH || null, TrangThai || 'A', req.params.id]);
    res.json({ message: 'Updated successfully' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.listen(PORT, () => {
  console.log(`🚀 HRM Backend API is running at http://localhost:${PORT}`);
});
