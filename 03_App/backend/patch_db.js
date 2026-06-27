import dotenv from 'dotenv';
import mysql from 'mysql2/promise';

dotenv.config();

async function run() {
  const pool = mysql.createPool({
    host: process.env.DB_HOST || 'localhost',
    user: process.env.DB_USER || 'root',
    password: process.env.DB_PASSWORD || '',
    database: process.env.DB_NAME || 'HRPayrollDB',
  });

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

    // Add Version column to NhanVien if it doesn't exist
    try {
      await pool.query(`
        ALTER TABLE NhanVien ADD COLUMN Version INT NOT NULL DEFAULT 1;
      `);
      console.log("Success: Added Version column to NhanVien table");
    } catch (columnErr) {
      if (columnErr.code === 'ER_DUP_FIELDNAME') {
        console.log("Info: Version column already exists on NhanVien table");
      } else {
        throw columnErr;
      }
    }

    // Insert some default data if empty
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
    console.log("Success: Created and seeded DanhMucKhauTru table");
  } catch (err) {
    console.error("Error:", err);
  } finally {
    process.exit(0);
  }
}
run();
