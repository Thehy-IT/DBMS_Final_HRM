import express from 'express';
import cors from 'cors';
import compression from 'compression';
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

// ── Performance: Gzip compression cho tất cả responses
app.use(compression());
app.use(cors());
app.use(express.json({ limit: '1mb' }));

// Tắt header X-Powered-By để giảm bandwidth và ẩn thông tin server
app.disable('x-powered-by');

// Database connection pool
// connectionLimit tăng lên 25 để đủ chỗ cho cả traffic thực + demo SLEEP
const pool = mysql.createPool({
    host: process.env.DB_HOST || 'localhost',
    user: process.env.DB_USER || 'root',
    password: process.env.DB_PASSWORD || '',
    database: process.env.DB_NAME || 'HRPayrollDB',
    waitForConnections: true,
    connectionLimit: 25,      // tăng từ 10 → 25 (đủ cho demo + load thực)
    queueLimit: 50,           // max request xếp hàng chờ connection
    connectTimeout: 10000,    // 10s connection timeout
    enableKeepAlive: true,
    keepAliveInitialDelay: 0
});

const JWT_SECRET = process.env.JWT_SECRET || 'hrpayroll_super_secret_key';

// Setup table DanhMucKhauTru tự động nếu chưa có
(async () => {
  try {
    await pool.query(`
      CREATE TABLE IF NOT EXISTS DanhMucKhauTru (
          MaLKT CHAR(6) NOT NULL,
          TenLKT VARCHAR(100) NOT NULL,
          Mota VARCHAR(255) NULL,
          IsActive TINYINT NOT NULL DEFAULT 1,
          PRIMARY KEY (MaLKT),
          UNIQUE KEY UQ_DanhMucKhauTru_Ten (TenLKT)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    `);
    const [rows] = await pool.query('SELECT COUNT(*) as cnt FROM DanhMucKhauTru');
    if (rows[0].cnt === 0) {
      await pool.query(`
        INSERT INTO DanhMucKhauTru (MaLKT, TenLKT, Mota) VALUES 
        ('KT0001', 'Phạt đi trễ', 'Đi làm muộn so với quy định'),
        ('KT0002', 'Làm hỏng thiết bị', 'Đền bù thiệt hại tài sản công ty'),
        ('KT0003', 'Tạm ứng', 'Khấu trừ tiền đã ứng trước'),
        ('KT0004', 'Vi phạm nội quy', 'Phạt vi phạm các quy định khác')
      `);
    }
  } catch (err) {
    console.error("Auto DB Setup Error:", err.message);
  }
})();

// Middleware Authentication
export const authenticateToken = (req, res, next) => {
  // Cho phép truy cập công khai vào các API Demo (bỏ qua check Token)
  if (req.originalUrl.includes('/v1/demo') || req.originalUrl.includes('/v1/reports/general')) {
    return next();
  }
  
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
// Hỗ trợ pagination: ?page=1&limit=50&search=...
// Khi không có ?page, trả toàn bộ (dùng cho Dashboard stats)
app.get('/v1/employees', async (req, res) => {
    let connection;
    try {
        connection = await pool.getConnection();
        const isDirtyReadDemo = process.env.DEMO_DIRTY_READ === 'true';
        if (isDirtyReadDemo) {
            await connection.query('SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;');
        } else {
            await connection.query('SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;');
        }

        const hasPagination = req.query.page !== undefined;
        const page = Math.max(1, parseInt(req.query.page) || 1);
        const limit = Math.min(parseInt(req.query.limit) || 50, 500);
        const offset = (page - 1) * limit;
        const search = req.query.search?.trim();
        const deptFilter = req.query.department;
        const statusFilter = req.query.status;

        let where = [];
        let params = [];

        if (req.user.role === 'EMPLOYEE') {
            where.push('MaNV = ?');
            params.push(req.user.empId);
        } else {
            if (search) {
                where.push('(HoTen LIKE ? OR MaNV LIKE ? OR Email LIKE ?)');
                const s = `%${search}%`;
                params.push(s, s, s);
            }
            if (deptFilter) { where.push('MaPB = ?'); params.push(deptFilter); }
            if (statusFilter) { where.push('TrangThai = ?'); params.push(statusFilter); }
        }

        const whereClause = where.length > 0 ? ' WHERE ' + where.join(' AND ') : '';
        let query = 'SELECT * FROM NhanVien' + whereClause + ' ORDER BY MaNV';

        let total = null;
        if (hasPagination) {
            const [countRows] = await connection.query(
                'SELECT COUNT(*) as cnt FROM NhanVien' + whereClause, params
            );
            total = countRows[0].cnt;
            query += ` LIMIT ${limit} OFFSET ${offset}`;
        }

        const [rows] = await connection.query(query, params);
        const lastPage = total !== null ? Math.ceil(total / limit) : 1;
        res.json({ data: rows, meta: { total: total ?? rows.length, page, lastPage } });
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: err.message });
    } finally {
        if (connection) connection.release();
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
// Hỗ trợ pagination: ?page=1&limit=50&from=2026-05-01&to=2026-05-31
app.get('/v1/attendance', async (req, res) => {
  try {
    const hasPagination = req.query.page !== undefined;
    const page = Math.max(1, parseInt(req.query.page) || 1);
    const limit = Math.min(parseInt(req.query.limit) || 100, 500);
    const offset = (page - 1) * limit;

    const baseSelect = `SELECT cc.MaCC as id, cc.MaNV as empId, nv.HoTen as name,
      DATE_FORMAT(cc.NgayCham, "%Y-%m-%d") as date,
      cc.GioVao as checkIn, cc.GioRa as checkOut, cc.TrangThai as status, cc.GhiChu as notes
      FROM ChamCong cc JOIN NhanVien nv ON cc.MaNV = nv.MaNV`;

    let where = [];
    let params = [];

    if (req.user.role === 'EMPLOYEE') {
      where.push('cc.MaNV = ?'); params.push(req.user.empId);
    }
    if (req.query.empId) { where.push('cc.MaNV = ?'); params.push(req.query.empId); }
    if (req.query.from)  { where.push('cc.NgayCham >= ?'); params.push(req.query.from); }
    if (req.query.to)    { where.push('cc.NgayCham <= ?'); params.push(req.query.to); }
    if (req.query.status){ where.push('cc.TrangThai = ?'); params.push(req.query.status); }

    const whereClause = where.length > 0 ? ' WHERE ' + where.join(' AND ') : '';
    let query = baseSelect + whereClause + ' ORDER BY cc.NgayCham DESC, cc.MaNV';

    let total = null;
    if (hasPagination) {
      const [cnt] = await pool.query('SELECT COUNT(*) as cnt FROM ChamCong cc JOIN NhanVien nv ON cc.MaNV = nv.MaNV' + whereClause, params);
      total = cnt[0].cnt;
      query += ` LIMIT ${limit} OFFSET ${offset}`;
    }

    const [rows] = await pool.query(query, params);
    res.json({ data: rows, meta: { total: total ?? rows.length, page, lastPage: total !== null ? Math.ceil(total / limit) : 1 } });
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
// Hỗ trợ pagination: ?page=1&limit=50&month=5&year=2026
app.get('/v1/payroll', async (req, res) => {
  try {
    const hasPagination = req.query.page !== undefined;
    const page = Math.max(1, parseInt(req.query.page) || 1);
    const limit = Math.min(parseInt(req.query.limit) || 50, 500);
    const offset = (page - 1) * limit;

    const baseSelect = `SELECT bl.MaBL as id, bl.Thang as month, bl.Nam as year, bl.MaNV as empId,
      nv.HoTen as name, pb.TenPB as dept, bl.LuongCoBan as basicSalary,
      bl.SoNgayCong as workingDays, bl.HeSoTangCa as otHours, bl.TongPhuCap as allowance,
      bl.TongKhauTru as deduction, bl.ThuNhapGop as grossSalary, bl.BHXH_NLD as bhxh,
      bl.BHYT_NLD as bhyt, bl.BHTN_NLD as bhtn, bl.ThueTNCN as tax,
      bl.ThuNhapThucLinh as netSalary, bl.TrangThai as status
      FROM BangLuong bl
      JOIN NhanVien nv ON bl.MaNV = nv.MaNV
      JOIN PhongBan pb ON nv.MaPB = pb.MaPB`;

    let where = [];
    let params = [];

    if (req.user.role === 'EMPLOYEE') {
      where.push('bl.MaNV = ?');
      params.push(req.user.empId);
    }
    if (req.query.month) { where.push('bl.Thang = ?'); params.push(req.query.month); }
    if (req.query.year)  { where.push('bl.Nam = ?');   params.push(req.query.year); }
    if (req.query.status){ where.push('bl.TrangThai = ?'); params.push(req.query.status); }

    const whereClause = where.length > 0 ? ' WHERE ' + where.join(' AND ') : '';
    let query = baseSelect + whereClause + ' ORDER BY bl.Nam DESC, bl.Thang DESC, nv.HoTen';

    let total = null;
    if (hasPagination) {
      const [cnt] = await pool.query('SELECT COUNT(*) as cnt FROM BangLuong bl JOIN NhanVien nv ON bl.MaNV = nv.MaNV' + whereClause, params);
      total = cnt[0].cnt;
      query += ` LIMIT ${limit} OFFSET ${offset}`;
    }

    const [rows] = await pool.query(query, params);
    res.json({ data: rows, meta: { total: total ?? rows.length, page, lastPage: total !== null ? Math.ceil(total / limit) : 1 } });
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'Internal Server Error' });
  }
});

app.post('/v1/payroll/calculate', requireHR, async (req, res) => {
  const { month, year } = req.body;
  const isNonRepeatableReadDemo = process.env.DEMO_NON_REPEATABLE_READ === 'true';
  const connection = await pool.getConnection();
  
  try {
    if (isNonRepeatableReadDemo) {
        await connection.query('SET @demo_non_repeatable_read = 1;');
        // Bắt buộc hạ mức cô lập xuống READ COMMITTED để Non-repeatable Read có thể xảy ra
        await connection.query('SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;');
    } else {
        await connection.query('SET @demo_non_repeatable_read = 0;');
        // Sử dụng mức mặc định (REPEATABLE READ) hoặc vẫn giữ READ COMMITTED
        // vì sp_TinhLuong chuẩn đã tự snapshot qua biến nên không bị lỗi dù ở READ COMMITTED.
    }

    await connection.query(`CALL sp_TinhLuong(?, ?, NULL, 1, 0)`, [month, year]);
    res.json({ message: 'Tính lương hoàn tất' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  } finally {
    // Reset để không ảnh hưởng connection pool
    await connection.query('SET @demo_non_repeatable_read = 0;');
    connection.release();
  }
});

app.put('/v1/payroll/confirm', requireHR, async (req, res) => {
  const { month, year } = req.body;
  const isPhantomReadDemo = process.env.DEMO_PHANTOM_READ === 'true';
  const connection = await pool.getConnection();

  try {
    // Luôn đưa về REPEATABLE READ để tái hiện lỗi đúng bản chất
    await connection.query('SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;');
    await connection.query('START TRANSACTION;');

    // 1. Đếm số lượng bảng lương nháp hiện tại
    let countQuery = "SELECT COUNT(*) as count FROM BangLuong WHERE Thang = ? AND Nam = ? AND TrangThai = 'D'";
    if (!isPhantomReadDemo) {
      countQuery += " FOR UPDATE"; // Khắc phục bằng Next-Key Lock
    }
    const [rows] = await connection.query(countQuery, [month, year]);
    const initialCount = rows[0].count;

    // Giả lập hệ thống đang chạy chốt sổ báo cáo mất 10 giây
    await connection.query('DO SLEEP(10);');

    // 2. Chốt toàn bộ
    const [updateResult] = await connection.query(
      `UPDATE BangLuong SET TrangThai = 'C', NgayXacNhan = NOW() WHERE Thang = ? AND Nam = ? AND TrangThai = 'D'`,
      [month, year]
    );

    await connection.query('COMMIT;');

    const affectedRows = updateResult.affectedRows;
    if (affectedRows > initialCount) {
      res.status(409).json({ 
        error: `LỖI BÓNG MA (Phantom Read)! Kế toán ban đầu duyệt ${initialCount} bản ghi, nhưng hệ thống lại chốt thành công ${affectedRows} bản ghi. Dư ra ${affectedRows - initialCount} bóng ma!`,
        phantom_read: true
      });
    } else {
      res.json({ message: `Xác nhận thành công ${affectedRows} bảng lương.` });
    }
  } catch (err) {
    await connection.query('ROLLBACK;');
    res.status(500).json({ error: err.message });
  } finally {
    connection.release();
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
// Cache-Control: private, max-age=300 — master data ít thay đổi, cache 5 phút phía client
app.get('/v1/departments', async (req, res) => {
  try {
    const [rows] = await pool.query(`
      SELECT 
        MaPB as id, 
        TenPB as name, 
        pb.* 
      FROM PhongBan pb
    `);
    res.set('Cache-Control', 'private, max-age=300');
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
    res.set('Cache-Control', 'private, max-age=300');
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
    res.set('Cache-Control', 'private, max-age=300');
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
    res.set('Cache-Control', 'private, max-age=300');
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
    const [empBenefits] = await pool.query('SELECT 1 FROM NhanVienPhucLoi WHERE MaFL = ? LIMIT 1', [req.params.id]);
    if (empBenefits.length > 0) {
      return res.status(400).json({ error: 'Không thể xóa phúc lợi đang được áp dụng cho nhân viên' });
    }
    
    await pool.query('DELETE FROM LoaiPhucLoi WHERE MaFL=?', [req.params.id]);
    res.json({ message: 'Xóa thành công' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// --- Deduction Types (Loại Khấu Trừ) ---
app.get('/v1/deduction-types', async (req, res) => {
  try {
    const [rows] = await pool.query(`
      SELECT 
        MaLKT as id, 
        TenLKT as name, 
        dk.* 
      FROM DanhMucKhauTru dk
    `);
    res.json({ data: rows });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.post('/v1/deduction-types', requireAdmin, async (req, res) => {
  const { MaLKT, TenLKT, Mota, IsActive } = req.body;
  try {
    await pool.query(
      'INSERT INTO DanhMucKhauTru (MaLKT, TenLKT, Mota, IsActive) VALUES (?, ?, ?, ?)',
      [MaLKT, TenLKT, Mota || null, IsActive !== undefined ? IsActive : 1]
    );
    res.status(201).json({ message: 'Tạo loại khấu trừ thành công' });
  } catch (err) {
    if (err.code === 'ER_DUP_ENTRY') {
      return res.status(400).json({ error: 'Mã hoặc tên loại khấu trừ đã tồn tại' });
    }
    res.status(500).json({ error: err.message });
  }
});

app.put('/v1/deduction-types/:id', requireAdmin, async (req, res) => {
  const { TenLKT, Mota, IsActive } = req.body;
  try {
    await pool.query(
      'UPDATE DanhMucKhauTru SET TenLKT=?, Mota=?, IsActive=? WHERE MaLKT=?',
      [TenLKT, Mota || null, IsActive !== undefined ? IsActive : 1, req.params.id]
    );
    res.json({ message: 'Cập nhật loại khấu trừ thành công' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.delete('/v1/deduction-types/:id', requireAdmin, async (req, res) => {
  try {
    // Không cho xóa nếu đã được dùng (trong KhauTru, LoaiKhauTru là text lưu TenLKT)
    const [empDeductions] = await pool.query('SELECT 1 FROM KhauTru WHERE LoaiKhauTru = (SELECT TenLKT FROM DanhMucKhauTru WHERE MaLKT = ?) LIMIT 1', [req.params.id]);
    if (empDeductions.length > 0) {
      return res.status(400).json({ error: 'Không thể xóa loại khấu trừ đã từng được áp dụng' });
    }
    await pool.query('DELETE FROM DanhMucKhauTru WHERE MaLKT=?', [req.params.id]);
    res.json({ message: 'Xóa thành công' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// --- Helper: Recalculate Payroll ---
// QUAN TRỌNG: Hàm này là FIRE-AND-FORGET — KHÔNG await để tránh block response.
// Gọi bằng: recalculatePayrollIfPossible(empId).catch(...) — trả response ngay.
function recalculatePayrollIfPossible(empId) {
  if (!empId) return Promise.resolve();
  const date = new Date();
  const month = date.getMonth() + 1;
  const year = date.getFullYear();
  return pool.query(`CALL sp_TinhLuong(?, ?, ?, 1, 0)`, [month, year, empId])
    .catch(err => console.log(`[Async Recalc] NV ${empId}: ${err.message}`));
}

// --- Employee Benefits ---
app.get('/v1/employee-benefits/:empId', requireHR, async (req, res) => {
  try {
    const [rows] = await pool.query(`
      SELECT nvpl.*, fl.TenFL, fl.LoaiGiaTri, fl.GiaTri as GiaTriGoc
      FROM NhanVienPhucLoi nvpl
      JOIN LoaiPhucLoi fl ON nvpl.MaFL = fl.MaFL
      WHERE nvpl.MaNV = ?
      ORDER BY nvpl.NgayApDung DESC
    `, [req.params.empId]);
    res.json({ data: rows });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/v1/employee-benefits', requireHR, async (req, res) => {
  const { MaNV, MaFL, GiaTriOverride, NgayApDung, NgayKetThuc, GhiChu } = req.body;
  try {
    await pool.query(
      'INSERT INTO NhanVienPhucLoi (MaNV, MaFL, GiaTriOverride, NgayApDung, NgayKetThuc, GhiChu) VALUES (?, ?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE GiaTriOverride=?, NgayKetThuc=?, GhiChu=?, IsActive=1',
      [MaNV, MaFL, GiaTriOverride || null, NgayApDung, NgayKetThuc || null, GhiChu || null, GiaTriOverride || null, NgayKetThuc || null, GhiChu || null]
    );
    // Fire-and-forget: tính lại lương nền, không block response
    recalculatePayrollIfPossible(MaNV);
    res.json({ message: 'Lưu phúc lợi thành công' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.delete('/v1/employee-benefits/:empId/:maFL/:ngayApDung', requireHR, async (req, res) => {
  try {
    await pool.query('DELETE FROM NhanVienPhucLoi WHERE MaNV=? AND MaFL=? AND NgayApDung=?', 
      [req.params.empId, req.params.maFL, req.params.ngayApDung]);
    // Fire-and-forget: tính lại lương nền, không block response
    recalculatePayrollIfPossible(req.params.empId);
    res.json({ message: 'Xóa thành công' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// --- Deductions ---
app.get('/v1/deductions/:empId', requireHR, async (req, res) => {
  try {
    const [rows] = await pool.query('SELECT * FROM KhauTru WHERE MaNV = ? ORDER BY NgayPhatSinh DESC', [req.params.empId]);
    res.json({ data: rows });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/v1/deductions', requireHR, async (req, res) => {
  const { MaNV, LoaiKhauTru, GiaTri, NgayPhatSinh, GhiChu } = req.body;
  try {
    await pool.query(
      'INSERT INTO KhauTru (MaNV, LoaiKhauTru, GiaTri, NgayPhatSinh, GhiChu, NguoiDuyet) VALUES (?, ?, ?, ?, ?, ?)',
      [MaNV, LoaiKhauTru, GiaTri, NgayPhatSinh || new Date(), GhiChu || null, req.user.username]
    );
    // Fire-and-forget: không block response
    recalculatePayrollIfPossible(MaNV);
    res.json({ message: 'Thêm khấu trừ thành công' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.delete('/v1/deductions/:id', requireHR, async (req, res) => {
  try {
    // Lấy MaNV trước khi xóa để tính lại lương
    const [rows] = await pool.query('SELECT MaNV FROM KhauTru WHERE MaKT=?', [req.params.id]);
    const empId = rows[0]?.MaNV;
    
    await pool.query('DELETE FROM KhauTru WHERE MaKT=?', [req.params.id]);
    
    // Fire-and-forget: không block response
    if (empId) recalculatePayrollIfPossible(empId);
    res.json({ message: 'Xóa thành công' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.get('/v1/leave-types', async (req, res) => {
  try {
    const [rows] = await pool.query('SELECT MaLoaiNghi as id, TenLoaiNghi as name FROM LoaiNghiPhep');
    res.set('Cache-Control', 'private, max-age=300');
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
  const isDeadlockDemo = process.env.DEMO_DEADLOCK === 'true';
  const connection = await pool.getConnection();
  try {
    await connection.beginTransaction();

    if (isDeadlockDemo) {
      // [MÔ PHỎNG LỖI ĐỒNG THỜI - KHÓA CHẾT / DEADLOCK]
      // Tiến trình B: Khóa LuongCoBan -> Ngủ 5s -> Khóa NhanVien
      
      // 1. Khóa LuongCoBan (bằng cách UPDATE bản ghi hiện tại để tránh lỗi Trigger)
      await connection.query(`
        UPDATE LuongCoBan 
        SET NguoiDuyet = 'HR - Đang sửa hợp đồng'
        WHERE MaNV = ? AND NgayHetHieuLuc IS NULL
      `, [empId]);
      
      // Ngủ 5 giây đợi Tiến trình A khóa NhanVien
      await connection.query('DO SLEEP(5);');

      // 2. Khóa NhanVien (Gây Deadlock vì A đang giữ khóa NhanVien và đòi khóa LuongCoBan)
      await connection.query("UPDATE NhanVien SET GhiChu = 'Cập nhật hợp đồng mới' WHERE MaNV = ?", [empId]);

      // 3. Cập nhật Hợp đồng
      const query = `
        UPDATE HopDong 
        SET MaNV=?, MaLoaiHD=?, NgayBatDau=?, NgayKetThuc=?, LuongCoBan=?, VungLuong=?, TrangThai=?
        WHERE MaHD=?
      `;
      await connection.query(query, [empId, typeId, startDate, endDate || null, salary, VungLuong || 1, status || 'A', req.params.id]);

    } else {
      // Lấy lương cơ bản hiện tại của Hợp đồng
      const [oldContract] = await connection.query('SELECT LuongCoBan FROM HopDong WHERE MaHD=?', [req.params.id]);
      
      // Cập nhật Hợp đồng (Khóa HopDong)
      const query = `
        UPDATE HopDong 
        SET MaNV=?, MaLoaiHD=?, NgayBatDau=?, NgayKetThuc=?, LuongCoBan=?, VungLuong=?, TrangThai=?
        WHERE MaHD=?
      `;
      await connection.query(query, [empId, typeId, startDate, endDate || null, salary, VungLuong || 1, status || 'A', req.params.id]);

      // Nếu lương thay đổi, cập nhật luôn vào bảng LuongCoBan để đồng bộ (Khóa LuongCoBan)
      if (oldContract.length > 0 && oldContract[0].LuongCoBan != salary) {
        // Đóng mức lương cũ
        await connection.query(`UPDATE LuongCoBan SET NgayHetHieuLuc = CURDATE() - INTERVAL 1 DAY WHERE MaNV = ? AND NgayHetHieuLuc IS NULL`, [empId]);
        // Thêm mức lương mới
        await connection.query(`
          INSERT INTO LuongCoBan (MaNV, LuongCB, LuongDongBH, NgayHieuLuc, LyDo, NguoiDuyet) 
          VALUES (?, ?, ?, CURDATE(), 'Cập nhật từ Hợp Đồng', 'HR')
        `, [empId, salary, Math.min(salary, 46800000)]);
      }
    }

    await connection.commit();
    res.json({ message: 'Updated successfully' });
  } catch (err) {
    await connection.rollback();
    if (err.code === 'ER_LOCK_DEADLOCK') {
      return res.status(500).json({ error: 'LỖI KHÓA CHẾT (DEADLOCK)! Hai giao dịch tự khóa chéo lẫn nhau. MySQL đã phát hiện và tự động hủy giao dịch này (Rollback) để hệ thống không bị treo cứng.' });
    }
    res.status(500).json({ error: err.message });
  } finally {
    connection.release();
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
  const { HoTen, GioiTinh, NgaySinh, CCCD, SoDienThoai, Email, DiaChi, MaPB, MaCV, NgayVaoLam, NgayNghiViec, MaSoThue, SoTaiKhoanNH, TenNganHang, SoNguoiPhuThuoc, GhiChu, TrangThai, Version } = req.body;
  const isDeadlockDemo = process.env.DEMO_DEADLOCK === 'true';
  const connection = await pool.getConnection();
  try {
    await connection.beginTransaction();

    const sanitizedMaSoThue = MaSoThue ? MaSoThue.trim() : null;
    const finalMaSoThue = sanitizedMaSoThue === '' ? null : sanitizedMaSoThue;

    // Check toggle from environment variable
    const enableOptimisticLock = process.env.ENABLE_OPTIMISTIC_LOCK === 'true';

    let query;
    let queryParams;

    if (enableOptimisticLock) {
      query = `
        UPDATE NhanVien 
        SET HoTen=?, GioiTinh=?, NgaySinh=?, CCCD=?, SoDienThoai=?, Email=?, DiaChi=?, MaPB=?, MaCV=?, NgayVaoLam=?, NgayNghiViec=?, MaSoThue=?, SoTaiKhoanNH=?, TenNganHang=?, SoNguoiPhuThuoc=?, GhiChu=?, TrangThai=?, Version = Version + 1
        WHERE MaNV=? AND Version=?
      `;
      queryParams = [
        HoTen, GioiTinh, NgaySinh, CCCD, SoDienThoai, Email, DiaChi || null, 
        MaPB, MaCV, NgayVaoLam, NgayNghiViec || null, finalMaSoThue, 
        SoTaiKhoanNH || null, TenNganHang || null, SoNguoiPhuThuoc || 0, 
        GhiChu || null, TrangThai || 'A', 
        req.params.id, Version || 1
      ];
    } else {
      query = `
        UPDATE NhanVien 
        SET HoTen=?, GioiTinh=?, NgaySinh=?, CCCD=?, SoDienThoai=?, Email=?, DiaChi=?, MaPB=?, MaCV=?, NgayVaoLam=?, NgayNghiViec=?, MaSoThue=?, SoTaiKhoanNH=?, TenNganHang=?, SoNguoiPhuThuoc=?, GhiChu=?, TrangThai=?
        WHERE MaNV=?
      `;
      queryParams = [
        HoTen, GioiTinh, NgaySinh, CCCD, SoDienThoai, Email, DiaChi || null, 
        MaPB, MaCV, NgayVaoLam, NgayNghiViec || null, finalMaSoThue, 
        SoTaiKhoanNH || null, TenNganHang || null, SoNguoiPhuThuoc || 0, 
        GhiChu || null, TrangThai || 'A', 
        req.params.id
      ];
    }

    // Tiến trình A: Khóa NhanVien
    const [result] = await connection.query(query, queryParams);
    
    if (enableOptimisticLock && result.affectedRows === 0) {
      await connection.rollback();
      connection.release();
      return res.status(409).json({ error: 'Dữ liệu đã được cập nhật bởi một người khác. Vui lòng tải lại trang!' });
    }

    // [MÔ PHỎNG LỖI ĐỒNG THỜI - KHÓA CHẾT / DEADLOCK]
    if (isDeadlockDemo) {
      // Tiến trình A: Ngủ 5s -> Khóa LuongCoBan
      await connection.query('DO SLEEP(5);');
      
      // Khóa LuongCoBan (Gây Deadlock vì B đang giữ khóa LuongCoBan và đòi khóa NhanVien)
      await connection.query("UPDATE LuongCoBan SET LyDo = 'Cập nhật do thay đổi thông tin' WHERE MaNV = ? AND NgayHetHieuLuc IS NULL", [req.params.id]);
    }
    
    // [PHẦN MÔ PHỎNG LỖI ĐỒNG THỜI - BÓNG MA] 
    if (TrangThai === 'T') {
      try {
        const [drafts] = await connection.query(`SELECT Thang, Nam FROM BangLuong WHERE TrangThai = 'D' ORDER BY Nam DESC, Thang DESC LIMIT 1`);
        if (drafts.length > 0) {
          const targetMonth = drafts[0].Thang;
          const targetYear = drafts[0].Nam;
          
          const [emp] = await connection.query(`SELECT GioiTinh, NgaySinh, MaPB, MaCV FROM NhanVien WHERE MaNV = ?`, [req.params.id]);
          if (emp.length > 0) {
            const ghostId = 'NV999999';
            await connection.query(`
              INSERT IGNORE INTO NhanVien (MaNV, HoTen, GioiTinh, NgaySinh, CCCD, SoDienThoai, Email, DiaChi, MaPB, MaCV, NgayVaoLam, TrangThai) 
              VALUES (?, 'Nhân viên Bóng Ma', ?, ?, '000000000000', '0000000000', 'ghost@test.com', 'Dia Chi', ?, ?, '2020-01-01', 'T')
            `, [ghostId, emp[0].GioiTinh, emp[0].NgaySinh, emp[0].MaPB, emp[0].MaCV]);
            
            await connection.query(`DELETE FROM BangLuong WHERE MaNV = ? AND Thang = ? AND Nam = ?`, [ghostId, targetMonth, targetYear]);
            
            await connection.query(`
              INSERT INTO BangLuong (MaNV, Thang, Nam, LuongCoBan, SoNgayCong, TrangThai) 
              VALUES (?, ?, ?, 10000000, 10, 'D')
            `, [ghostId, targetMonth, targetYear]);
          }
        }
      } catch (e) {
        console.error("Lỗi khi giả lập Bóng Ma:", e);
      }
    }

    await connection.commit();
    res.json({ message: 'Updated successfully' });
  } catch (err) {
    await connection.rollback();
    if (err.code === 'ER_LOCK_DEADLOCK') {
      return res.status(500).json({ error: 'LỖI KHÓA CHẾT (DEADLOCK)! Hai giao dịch tự khóa chéo lẫn nhau. MySQL đã phát hiện và tự động hủy giao dịch này (Rollback) để hệ thống không bị treo cứng.' });
    }
    res.status(500).json({ error: err.message });
  } finally {
    connection.release();
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

// --- DEMO API DIRTY READ ---
app.get('/v1/reports/general', async (req, res) => {
  const isDirtyReadDemo = process.env.DEMO_DIRTY_READ === 'true';
  const connection = await pool.getConnection();
  try {
    if (isDirtyReadDemo) {
      await connection.query('SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;');
    } else {
      await connection.query('SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;');
    }
    await connection.query('START TRANSACTION;');
    const [rows] = await connection.query('CALL sp_BaoCaoNhanSu_TongQuan(NULL);');
    await connection.query('COMMIT;');
    
    // The result from stored procedure is an array of arrays (first element is result set)
    res.json({ data: rows[0] });
  } catch (error) {
    await connection.query('ROLLBACK;');
    res.status(500).json({ error: error.message });
  } finally {
    connection.release();
  }
});

app.all('/v1/demo/slow-onboarding', async (req, res) => {
  const connection = await pool.getConnection();
  try {
    await connection.query('START TRANSACTION;');
    
    // Check if employee already exists to avoid duplicate errors on retry
    const [existing] = await connection.query("SELECT MaNV FROM NhanVien WHERE MaNV = 'NV888888'");
    if (existing.length === 0) {
      await connection.query(`
        INSERT INTO NhanVien (MaNV, HoTen, GioiTinh, NgaySinh, CCCD, MaPB, MaCV, NgayVaoLam, Version) 
        VALUES ('NV888888', 'Giám Đốc Mới', 'M', '1990-01-01', '012345678910', 'PB0001', 'CV0001', '2025-01-01', 1)
      `);
    }

    // Sleep for 10 seconds to allow the user to make a dirty read
    await connection.query('DO SLEEP(10);');
    
    // Simulate error -> Rollback
    await connection.query('ROLLBACK;');
    
    res.json({ message: 'Simulated slow onboarding completed and rolled back successfully.' });
  } catch (error) {
    await connection.query('ROLLBACK;');
    res.status(500).json({ error: error.message });
  } finally {
    connection.release();
  }
});




// --- DEMO API PHANTOM READ ---
app.get('/v1/demo/close-payroll', async (req, res) => {
  const isPhantomReadDemo = process.env.DEMO_PHANTOM_READ === 'true';
  const connection = await pool.getConnection();
  try {
    // REPEATABLE READ allows Phantom Reads if we don't use FOR UPDATE
    await connection.query('SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;');
    await connection.query('START TRANSACTION;');
    
    // Bước 1: Đếm số lượng bảng lương Draft
    let countQuery = "SELECT COUNT(*) as count FROM BangLuong WHERE Thang = 5 AND Nam = 2026 AND TrangThai = 'D'";
    if (!isPhantomReadDemo) {
      countQuery += " FOR UPDATE"; // Next-Key Locking
    }
    
    const [rows] = await connection.query(countQuery);
    const initialCount = rows[0].count;

    // Kế toán đang lúi húi kiểm tra chứng từ (Sleep 10s)
    await connection.query('DO SLEEP(10);');

    // Bước 2: Chốt sổ (Chuyển D -> C)
    const [updateResult] = await connection.query(`
      UPDATE BangLuong 
      SET TrangThai = 'C' 
      WHERE Thang = 5 AND Nam = 2026 AND TrangThai = 'D'
    `);
    
    const affectedRows = updateResult.affectedRows;
    
    await connection.query('COMMIT;');

    // Dọn dẹp dữ liệu để test lại dễ dàng
    await pool.query("UPDATE BangLuong SET TrangThai = 'D' WHERE Thang = 5 AND Nam = 2026 AND TrangThai = 'C'");
    await pool.query("DELETE FROM BangLuong WHERE MaNV = 'NV000099' AND Thang = 5 AND Nam = 2026");

    res.json({
      locking_strategy: isPhantomReadDemo ? 'Không dùng FOR UPDATE' : 'Sử dụng SELECT ... FOR UPDATE',
      initial_draft_count: initialCount,
      actually_closed_count: affectedRows,
      status: affectedRows > initialCount 
        ? 'CẢNH BÁO: Đã xảy ra Bóng ma (Phantom Read)! Dư ra ' + (affectedRows - initialCount) + ' bản ghi.' 
        : 'Tuyệt vời: Dữ liệu nhất quán, không có bóng ma lọt vào.'
    });
  } catch (error) {
    await connection.query('ROLLBACK;');
    res.status(500).json({ error: error.message });
  } finally {
    connection.release();
  }
});

app.post('/v1/demo/fire-employee', async (req, res) => {
  const connection = await pool.getConnection();
  try {
    await connection.query('START TRANSACTION;');
    // Đảm bảo tạo mới nhân viên NV000099 nếu chưa có trong DB (để không vi phạm FK_BL_NhanVien)
    await connection.query(`INSERT IGNORE INTO NhanVien (MaNV, HoTen, GioiTinh, NgaySinh, CCCD, MaPB, MaCV, NgayVaoLam, Version) VALUES ('NV000099', 'Bóng Ma', 'M', '1990-01-01', '999999999999', 'PB0001', 'CV0001', '2020-01-01', 1)`);

    // Chèn dòng lương Draft cho nhân viên vừa nghỉ
    await connection.query(`
      INSERT INTO BangLuong (MaNV, Thang, Nam, LuongCoBan, SoNgayCong, TrangThai) 
      VALUES ('NV000099', 5, 2026, 10000000, 10, 'D')
      ON DUPLICATE KEY UPDATE TrangThai = 'D'
    `);
    await connection.query('COMMIT;');
    res.json({ message: 'HR generated final draft payroll for fired employee successfully.' });
  } catch (error) {
    await connection.query('ROLLBACK;');
    res.status(500).json({ error: error.message });
  } finally {
    connection.release();
  }
});

// --- DEMO API DEADLOCK ---
app.post('/v1/demo/promote-employee', async (req, res) => {
  const connection = await pool.getConnection();
  try {
    await connection.query('START TRANSACTION;');
    
    // Bước 1: Khóa bảng NhanVien
    await connection.query("UPDATE NhanVien SET MaCV = 'CV0002' WHERE MaNV = 'NV000001'");
    
    // Ngủ 5 giây để chờ Giao dịch B khóa bảng LuongCoBan
    await connection.query('DO SLEEP(5);');
    
    // Bước 2: Khóa bảng LuongCoBan
    await connection.query("UPDATE LuongCoBan SET LuongCB = 50000000 WHERE MaNV = 'NV000001'");
    
    await connection.query('COMMIT;');
    res.json({ message: 'Tiến trình A (Thăng chức) chạy xong: Cập nhật NhanVien -> LuongCoBan thành công.' });
  } catch (error) {
    await connection.query('ROLLBACK;');
    res.status(500).json({ error: error.message, tiến_trình: 'A' });
  } finally {
    connection.release();
  }
});

app.post('/v1/demo/discipline-employee', async (req, res) => {
  const isDeadlockDemo = process.env.DEMO_DEADLOCK === 'true';
  const connection = await pool.getConnection();
  try {
    await connection.query('START TRANSACTION;');
    
    if (isDeadlockDemo) {
      // ❌ SAI THỨ TỰ LẤY KHÓA (Gây Deadlock với Tiến trình A)
      // Bước 1: Khóa LuongCoBan trước
      await connection.query("UPDATE LuongCoBan SET LuongCB = 10000000 WHERE MaNV = 'NV000001'");
      await connection.query('DO SLEEP(5);');
      // Bước 2: Cố gắng khóa NhanVien (Bị T1 chặn -> T1 lại chờ T2 nhả LuongCoBan -> DEADLOCK)
      await connection.query("UPDATE NhanVien SET MaCV = 'CV0001' WHERE MaNV = 'NV000001'");
    } else {
      // ✅ ĐÚNG THỨ TỰ LẤY KHÓA (Cùng chiều với Tiến trình A: NhanVien -> LuongCoBan)
      await connection.query("UPDATE NhanVien SET MaCV = 'CV0001' WHERE MaNV = 'NV000001'");
      await connection.query('DO SLEEP(5);');
      await connection.query("UPDATE LuongCoBan SET LuongCB = 10000000 WHERE MaNV = 'NV000001'");
    }
    
    await connection.query('COMMIT;');
    res.json({ 
      message: 'Tiến trình B (Kỷ luật) chạy xong.',
      locking_order: isDeadlockDemo ? 'NGƯỢC CHIỀU (LuongCoBan -> NhanVien)' : 'CÙNG CHIỀU (NhanVien -> LuongCoBan)'
    });
  } catch (error) {
    await connection.query('ROLLBACK;');
    res.status(500).json({ error: error.message, tiến_trình: 'B' });
  } finally {
    connection.release();
  }
});

app.listen(PORT, () => {
  console.log(`🚀 HRM Backend API is running at http://localhost:${PORT}`);
});
