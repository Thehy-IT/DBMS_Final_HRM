import mysql from 'mysql2/promise';
import dotenv from 'dotenv';
dotenv.config();

async function testInsert() {
  const pool = mysql.createPool({
    host: process.env.DB_HOST || 'localhost',
    user: process.env.DB_USER || 'root',
    password: process.env.DB_PASSWORD || '',
    database: process.env.DB_NAME || 'HRPayrollDB'
  });

  try {
    const query = `
      INSERT INTO NhanVien 
      (MaNV, HoTen, GioiTinh, NgaySinh, CCCD, SoDienThoai, Email, DiaChi, MaPB, MaCV, NgayVaoLam, NgayNghiViec, MaSoThue, SoTaiKhoanNH, TenNganHang, SoNguoiPhuThuoc, GhiChu, TrangThai)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `;
    
    console.log("Testing insert with empty MST...");
    await pool.query(query, [
      'NV999998', 'Test 1', 'M', '2000-01-01', '123456789012', null, null, null, 'PB0001', 'CV0001', '2023-01-01', null, null, null, null, 0, null, 'A'
    ]);
    console.log("Empty MST passed.");

    console.log("Testing insert with 14-char MST...");
    await pool.query(query, [
      'NV999999', 'Test 2', 'M', '2000-01-01', '123456789013', null, null, null, 'PB0001', 'CV0001', '2023-01-01', null, '0123456789-001', null, null, 0, null, 'A'
    ]);
    console.log("14-char MST passed.");

    // clean up
    await pool.query(`DELETE FROM NhanVien WHERE MaNV IN ('NV999998', 'NV999999')`);
    
  } catch (err) {
    console.error("Test failed:", err.message);
  }
  process.exit(0);
}

testInsert();
