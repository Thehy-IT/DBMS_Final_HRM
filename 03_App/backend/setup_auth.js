import dotenv from 'dotenv';
import mysql from 'mysql2/promise';
import bcrypt from 'bcryptjs';

dotenv.config();

async function setupAuth() {
  const pool = mysql.createPool({
    host: process.env.DB_HOST || 'localhost',
    user: process.env.DB_USER || 'root',
    password: process.env.DB_PASSWORD || '',
    database: process.env.DB_NAME || 'HRPayrollDB',
  });

  try {
    console.log('Creating TaiKhoan table...');
    await pool.query(`
      CREATE TABLE IF NOT EXISTS TaiKhoan (
        MaTK INT AUTO_INCREMENT PRIMARY KEY,
        TenDangNhap VARCHAR(50) NOT NULL UNIQUE,
        MatKhau VARCHAR(255) NOT NULL,
        Quyen ENUM('ADMIN', 'HR', 'EMPLOYEE') DEFAULT 'EMPLOYEE',
        MaNV CHAR(8) NULL,
        TrangThai CHAR(1) DEFAULT 'A',
        FOREIGN KEY (MaNV) REFERENCES NhanVien(MaNV)
      );
    `);

    console.log('Creating default Admin account...');
    const hashedPassword = await bcrypt.hash('admin123', 10);
    await pool.query(`
      INSERT IGNORE INTO TaiKhoan (TenDangNhap, MatKhau, Quyen)
      VALUES ('admin', ?, 'ADMIN')
    `, [hashedPassword]);

    console.log('Setup Auth Complete!');
  } catch (err) {
    console.error('Error:', err);
  } finally {
    process.exit(0);
  }
}

setupAuth();
