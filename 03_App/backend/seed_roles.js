import dotenv from 'dotenv';
import mysql from 'mysql2/promise';
import bcrypt from 'bcryptjs';

dotenv.config();

async function seed() {
  const pool = mysql.createPool({
    host: process.env.DB_HOST || 'localhost',
    user: process.env.DB_USER || 'root',
    password: process.env.DB_PASSWORD || '',
    database: process.env.DB_NAME || 'HRPayrollDB',
  });

  try {
    console.log('Seeding HR and EMPLOYEE accounts...');
    const hashed = await bcrypt.hash('123456', 10);
    
    // Lấy 2 nhân viên bất kỳ để map
    const [emps] = await pool.query('SELECT MaNV FROM NhanVien LIMIT 2');
    if (emps.length >= 2) {
      await pool.query(`
        INSERT IGNORE INTO TaiKhoan (TenDangNhap, MatKhau, Quyen, MaNV)
        VALUES ('hr', ?, 'HR', ?)
      `, [hashed, emps[0].MaNV]);

      await pool.query(`
        INSERT IGNORE INTO TaiKhoan (TenDangNhap, MatKhau, Quyen, MaNV)
        VALUES ('nhanvien', ?, 'EMPLOYEE', ?)
      `, [hashed, emps[1].MaNV]);
      console.log(`Created hr/123456 (MaNV: ${emps[0].MaNV}) and nhanvien/123456 (MaNV: ${emps[1].MaNV})`);
    } else {
      console.log('Not enough employees in NhanVien table to seed accounts.');
    }

  } catch (err) {
    console.error('Error:', err);
  } finally {
    process.exit(0);
  }
}

seed();
