-- ============================================================
--  HRPayrollSystem | 02_Database/DDL/01_create_tables.sql
--  Hệ thống Quản lý Nhân sự & Tính lương tự động
--  DBMS  : SQL Server 2019+
--  Author: HRPayroll Team
--  Phiên : v1.0
--
--  THỨ TỰ TẠO BẢNG (phụ thuộc FK):
--    Tier 0 — Không phụ thuộc  : PhongBan, ChucVu, LoaiHopDong
--                                LoaiNghiPhep, LoaiPhucLoi
--    Tier 1 — Phụ thuộc Tier 0 : NhanVien
--    Tier 2 — Phụ thuộc Tier 1 : HopDong, LuongCoBan, NghiPhep
--                                NhanVienPhucLoi
--    Tier 3 — Phụ thuộc Tier 1 : ChamCong
--    Tier 4 — Tính toán         : BangLuong → ChiTietLuong, KhauTru
--    Tier 5 — Audit             : AuditLog_HopDong, AuditLog_Luong
-- ============================================================

USE master;
GO

-- ── Tạo database nếu chưa tồn tại ──────────────────────────
IF NOT EXISTS (
    SELECT name FROM sys.databases WHERE name = N'HRPayrollDB'
)
BEGIN
    CREATE DATABASE HRPayrollDB
        COLLATE Vietnamese_CI_AS;          -- hỗ trợ tiếng Việt có dấu
    PRINT N'[OK] Database HRPayrollDB đã được tạo.';
END
ELSE
    PRINT N'[SKIP] Database HRPayrollDB đã tồn tại.';
GO

USE HRPayrollDB;
GO

-- ============================================================
--  TIER 0 — Danh mục độc lập (lookup / master data)
-- ============================================================

-- ── 1. PhongBan ──────────────────────────────────────────────
IF OBJECT_ID('dbo.PhongBan', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.PhongBan (
        MaPB            CHAR(6)         NOT NULL,   -- VD: PB0001
        TenPB           NVARCHAR(100)   NOT NULL,
        DiaDiem         NVARCHAR(150)   NULL,
        DienThoai       VARCHAR(20)     NULL,
        Email           VARCHAR(100)    NULL,
        MaTruongPhong   CHAR(8)         NULL,       -- FK → NhanVien (set sau)
        NgayThanhLap    DATE            NULL,
        GhiChu          NVARCHAR(255)   NULL,
        IsActive        BIT             NOT NULL    DEFAULT 1,
        NgayTao         DATETIME2(0)    NOT NULL    DEFAULT SYSDATETIME(),
        NgayCapNhat     DATETIME2(0)    NOT NULL    DEFAULT SYSDATETIME(),

        CONSTRAINT PK_PhongBan          PRIMARY KEY (MaPB),
        CONSTRAINT UQ_PhongBan_TenPB    UNIQUE      (TenPB),
        CONSTRAINT CK_PhongBan_Email    CHECK (Email LIKE '%@%.%' OR Email IS NULL)
    );
    PRINT N'[OK] Tạo bảng PhongBan';
END
GO

-- ── 2. ChucVu ────────────────────────────────────────────────
IF OBJECT_ID('dbo.ChucVu', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.ChucVu (
        MaCV            CHAR(6)         NOT NULL,   -- VD: CV0001
        TenCV           NVARCHAR(100)   NOT NULL,
        HeSoLuong       DECIMAL(5,2)    NOT NULL    DEFAULT 1.00,
        MoTa            NVARCHAR(500)   NULL,
        CapBac          TINYINT         NOT NULL    DEFAULT 1,  -- 1=Nhân viên … 5=Giám đốc
        IsActive        BIT             NOT NULL    DEFAULT 1,
        NgayTao         DATETIME2(0)    NOT NULL    DEFAULT SYSDATETIME(),

        CONSTRAINT PK_ChucVu            PRIMARY KEY (MaCV),
        CONSTRAINT UQ_ChucVu_TenCV      UNIQUE      (TenCV),
        CONSTRAINT CK_ChucVu_HeSo       CHECK (HeSoLuong BETWEEN 0.50 AND 10.00),
        CONSTRAINT CK_ChucVu_CapBac     CHECK (CapBac BETWEEN 1 AND 5)
    );
    PRINT N'[OK] Tạo bảng ChucVu';
END
GO

-- ── 3. LoaiHopDong ───────────────────────────────────────────
IF OBJECT_ID('dbo.LoaiHopDong', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.LoaiHopDong (
        MaLoaiHD        TINYINT         NOT NULL    IDENTITY(1,1),
        TenLoaiHD       NVARCHAR(100)   NOT NULL,   -- VD: Thử việc, Chính thức, Thời vụ
        ThoiHanToiDa    SMALLINT        NULL,        -- Số tháng, NULL = không giới hạn
        TiLeBHXH        DECIMAL(5,2)    NOT NULL    DEFAULT 8.00,  -- % NLĐ đóng
        MoTa            NVARCHAR(255)   NULL,

        CONSTRAINT PK_LoaiHopDong       PRIMARY KEY (MaLoaiHD),
        CONSTRAINT UQ_LoaiHopDong_Ten   UNIQUE      (TenLoaiHD),
        CONSTRAINT CK_LHD_TiLeBHXH     CHECK (TiLeBHXH BETWEEN 0 AND 20)
    );
    PRINT N'[OK] Tạo bảng LoaiHopDong';
END
GO

-- ── 4. LoaiNghiPhep ──────────────────────────────────────────
IF OBJECT_ID('dbo.LoaiNghiPhep', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.LoaiNghiPhep (
        MaLoaiNghi      TINYINT         NOT NULL    IDENTITY(1,1),
        TenLoaiNghi     NVARCHAR(100)   NOT NULL,   -- Phép năm, Ốm, Thai sản, Không lương
        CoHuongLuong    BIT             NOT NULL    DEFAULT 1,
        SoNgayToiDa     SMALLINT        NULL,        -- Giới hạn năm, NULL = không giới hạn
        MoTa            NVARCHAR(255)   NULL,

        CONSTRAINT PK_LoaiNghiPhep      PRIMARY KEY (MaLoaiNghi),
        CONSTRAINT UQ_LoaiNghiPhep_Ten  UNIQUE      (TenLoaiNghi)
    );
    PRINT N'[OK] Tạo bảng LoaiNghiPhep';
END
GO

-- ── 5. LoaiPhucLoi ───────────────────────────────────────────
IF OBJECT_ID('dbo.LoaiPhucLoi', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.LoaiPhucLoi (
        MaFL            CHAR(6)         NOT NULL,   -- VD: FL0001
        TenFL           NVARCHAR(100)   NOT NULL,   -- Ăn trưa, Xăng xe, Điện thoại…
        LoaiGiaTri      CHAR(1)         NOT NULL    DEFAULT 'F', -- F=Cố định, P=Phần trăm
        GiaTri          DECIMAL(15,2)   NOT NULL    DEFAULT 0,
        CoTinhThue      BIT             NOT NULL    DEFAULT 0,   -- Có chịu thuế TNCN không
        MoTa            NVARCHAR(255)   NULL,
        IsActive        BIT             NOT NULL    DEFAULT 1,

        CONSTRAINT PK_LoaiPhucLoi       PRIMARY KEY (MaFL),
        CONSTRAINT UQ_LoaiPhucLoi_Ten   UNIQUE      (TenFL),
        CONSTRAINT CK_LoaiFL_LoaiGT     CHECK (LoaiGiaTri IN ('F', 'P')),
        CONSTRAINT CK_LoaiFL_GiaTri     CHECK (GiaTri >= 0)
    );
    PRINT N'[OK] Tạo bảng LoaiPhucLoi';
END
GO


-- ============================================================
--  TIER 1 — NhanVien (bảng trung tâm)
-- ============================================================

IF OBJECT_ID('dbo.NhanVien', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.NhanVien (
        MaNV            CHAR(8)         NOT NULL,   -- VD: NV000001
        HoTen           NVARCHAR(100)   NOT NULL,
        GioiTinh        CHAR(1)         NOT NULL,   -- M / F
        NgaySinh        DATE            NOT NULL,
        CCCD            VARCHAR(12)     NOT NULL,   -- Căn cước công dân 12 số
        DiaChi          NVARCHAR(300)   NULL,
        Email           VARCHAR(100)    NULL,
        SoDienThoai     VARCHAR(15)     NULL,
        MaPB            CHAR(6)         NOT NULL,   -- FK → PhongBan
        MaCV            CHAR(6)         NOT NULL,   -- FK → ChucVu
        NgayVaoLam      DATE            NOT NULL,
        NgayNghiViec    DATE            NULL,        -- NULL = đang làm việc
        TrangThai       CHAR(1)         NOT NULL    DEFAULT 'A',
        --   A=Active, L=On Leave, T=Terminated, P=Probation
        MaSoThue        VARCHAR(14)     NULL,        -- MST cá nhân
        SoTaiKhoanNH    VARCHAR(20)     NULL,        -- Số tài khoản ngân hàng
        TenNganHang     NVARCHAR(100)   NULL,
        GhiChu          NVARCHAR(500)   NULL,
        NgayTao         DATETIME2(0)    NOT NULL    DEFAULT SYSDATETIME(),
        NgayCapNhat     DATETIME2(0)    NOT NULL    DEFAULT SYSDATETIME(),
        NguoiTao        NVARCHAR(100)   NOT NULL    DEFAULT SYSTEM_USER,

        CONSTRAINT PK_NhanVien          PRIMARY KEY (MaNV),
        CONSTRAINT UQ_NhanVien_CCCD     UNIQUE      (CCCD),
        CONSTRAINT UQ_NhanVien_Email    UNIQUE      (Email),
        CONSTRAINT FK_NV_PhongBan       FOREIGN KEY (MaPB)   REFERENCES dbo.PhongBan(MaPB),
        CONSTRAINT FK_NV_ChucVu         FOREIGN KEY (MaCV)   REFERENCES dbo.ChucVu(MaCV),
        CONSTRAINT CK_NV_GioiTinh       CHECK (GioiTinh IN ('M', 'F')),
        CONSTRAINT CK_NV_TrangThai      CHECK (TrangThai IN ('A', 'L', 'T', 'P')),
        CONSTRAINT CK_NV_NgaySinh       CHECK (NgaySinh <= DATEADD(YEAR, -18, GETDATE())),
        CONSTRAINT CK_NV_NgayNghiViec   CHECK (NgayNghiViec IS NULL
                                            OR NgayNghiViec > NgayVaoLam),
        CONSTRAINT CK_NV_CCCD           CHECK (LEN(CCCD) = 12
                                            AND CCCD NOT LIKE '%[^0-9]%'),
        CONSTRAINT CK_NV_MaNV_Format    CHECK (MaNV LIKE 'NV[0-9][0-9][0-9][0-9][0-9][0-9]')
    );
    -- Index thường dùng khi tìm kiếm nhân viên
    CREATE INDEX IX_NhanVien_PB     ON dbo.NhanVien (MaPB);
    CREATE INDEX IX_NhanVien_CV     ON dbo.NhanVien (MaCV);
    CREATE INDEX IX_NhanVien_Ten    ON dbo.NhanVien (HoTen);
    CREATE INDEX IX_NhanVien_TT     ON dbo.NhanVien (TrangThai) WHERE TrangThai = 'A';
    PRINT N'[OK] Tạo bảng NhanVien';
END
GO

-- Sau khi có NhanVien, thêm FK ngược cho PhongBan.MaTruongPhong
IF NOT EXISTS (
    SELECT 1 FROM sys.foreign_keys
    WHERE name = 'FK_PhongBan_TruongPhong'
)
BEGIN
    ALTER TABLE dbo.PhongBan
        ADD CONSTRAINT FK_PhongBan_TruongPhong
            FOREIGN KEY (MaTruongPhong) REFERENCES dbo.NhanVien(MaNV);
    PRINT N'[OK] Thêm FK PhongBan.MaTruongPhong → NhanVien';
END
GO


-- ============================================================
--  TIER 2 — Hợp đồng & Lương cơ bản
-- ============================================================

-- ── 6. HopDong ───────────────────────────────────────────────
IF OBJECT_ID('dbo.HopDong', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.HopDong (
        MaHD            CHAR(10)        NOT NULL,   -- VD: HD00000001
        MaNV            CHAR(8)         NOT NULL,   -- FK → NhanVien
        MaLoaiHD        TINYINT         NOT NULL,   -- FK → LoaiHopDong
        NgayBatDau      DATE            NOT NULL,
        NgayKetThuc     DATE            NULL,        -- NULL = không xác định
        LuongCoBan      DECIMAL(15,2)   NOT NULL,   -- Lương ghi trên HĐ
        VungLuong       TINYINT         NOT NULL    DEFAULT 1,
        --  Vùng 1=5.590.000 / 2=4.960.000 / 3=4.340.000 / 4=3.900.000 (2024)
        FileDinhKem     NVARCHAR(300)   NULL,        -- Đường dẫn file scan HĐ
        TrangThai       CHAR(1)         NOT NULL    DEFAULT 'A',
        --  A=Active, E=Expired, T=Terminated, D=Draft
        NguoiKy_NLD    NVARCHAR(100)   NULL,        -- Người lao động
        NguoiKy_NSDLD  NVARCHAR(100)   NULL,        -- Đại diện công ty
        NgayKy          DATE            NULL,
        GhiChu          NVARCHAR(500)   NULL,
        NgayTao         DATETIME2(0)    NOT NULL    DEFAULT SYSDATETIME(),
        NgayCapNhat     DATETIME2(0)    NOT NULL    DEFAULT SYSDATETIME(),
        NguoiTao        NVARCHAR(100)   NOT NULL    DEFAULT SYSTEM_USER,

        CONSTRAINT PK_HopDong           PRIMARY KEY (MaHD),
        CONSTRAINT FK_HD_NhanVien        FOREIGN KEY (MaNV)      REFERENCES dbo.NhanVien(MaNV),
        CONSTRAINT FK_HD_LoaiHopDong     FOREIGN KEY (MaLoaiHD)  REFERENCES dbo.LoaiHopDong(MaLoaiHD),
        CONSTRAINT CK_HD_LuongCoBan      CHECK (LuongCoBan > 0),
        CONSTRAINT CK_HD_VungLuong       CHECK (VungLuong BETWEEN 1 AND 4),
        CONSTRAINT CK_HD_TrangThai       CHECK (TrangThai IN ('A', 'E', 'T', 'D')),
        CONSTRAINT CK_HD_NgayKetThuc     CHECK (NgayKetThuc IS NULL
                                             OR NgayKetThuc > NgayBatDau)
    );
    CREATE INDEX IX_HopDong_NV      ON dbo.HopDong (MaNV);
    CREATE INDEX IX_HopDong_TT      ON dbo.HopDong (TrangThai) WHERE TrangThai = 'A';
    PRINT N'[OK] Tạo bảng HopDong';
END
GO

-- ── 7. LuongCoBan (lịch sử thay đổi lương) ──────────────────
IF OBJECT_ID('dbo.LuongCoBan', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.LuongCoBan (
        MaLCB           INT             NOT NULL    IDENTITY(1,1),
        MaNV            CHAR(8)         NOT NULL,   -- FK → NhanVien
        LuongCB         DECIMAL(15,2)   NOT NULL,
        LuongDongBH     DECIMAL(15,2)   NOT NULL,   -- Lương đóng BHXH (≤ 20 lần lương CS)
        NgayHieuLuc     DATE            NOT NULL,
        NgayHetHieuLuc  DATE            NULL,
        LyDo            NVARCHAR(255)   NULL,        -- Tăng lương định kỳ / thăng chức...
        NguoiDuyet      NVARCHAR(100)   NULL,
        NgayTao         DATETIME2(0)    NOT NULL    DEFAULT SYSDATETIME(),

        CONSTRAINT PK_LuongCoBan        PRIMARY KEY (MaLCB),
        CONSTRAINT FK_LCB_NhanVien       FOREIGN KEY (MaNV) REFERENCES dbo.NhanVien(MaNV),
        CONSTRAINT CK_LCB_LuongCB        CHECK (LuongCB > 0),
        CONSTRAINT CK_LCB_DongBH         CHECK (LuongDongBH > 0
                                            AND LuongDongBH <= LuongCB),
        CONSTRAINT CK_LCB_NgayHH         CHECK (NgayHetHieuLuc IS NULL
                                            OR NgayHetHieuLuc > NgayHieuLuc)
    );
    CREATE INDEX IX_LuongCoBan_NV   ON dbo.LuongCoBan (MaNV, NgayHieuLuc DESC);
    PRINT N'[OK] Tạo bảng LuongCoBan';
END
GO

-- ── 8. NghiPhep ──────────────────────────────────────────────
IF OBJECT_ID('dbo.NghiPhep', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.NghiPhep (
        MaNP            INT             NOT NULL    IDENTITY(1,1),
        MaNV            CHAR(8)         NOT NULL,   -- FK → NhanVien
        MaLoaiNghi      TINYINT         NOT NULL,   -- FK → LoaiNghiPhep
        NgayBatDau      DATE            NOT NULL,
        NgayKetThuc     DATE            NOT NULL,
        SoNgayNghi      AS DATEDIFF(DAY, NgayBatDau, NgayKetThuc) + 1 PERSISTED,
        LyDo            NVARCHAR(500)   NULL,
        TrangThai       CHAR(1)         NOT NULL    DEFAULT 'P',
        --  P=Pending, A=Approved, R=Rejected, C=Cancelled
        NguoiDuyet      NVARCHAR(100)   NULL,
        NgayDuyet       DATETIME2(0)    NULL,
        GhiChu          NVARCHAR(255)   NULL,
        NgayTao         DATETIME2(0)    NOT NULL    DEFAULT SYSDATETIME(),

        CONSTRAINT PK_NghiPhep          PRIMARY KEY (MaNP),
        CONSTRAINT FK_NP_NhanVien        FOREIGN KEY (MaNV)         REFERENCES dbo.NhanVien(MaNV),
        CONSTRAINT FK_NP_LoaiNghiPhep    FOREIGN KEY (MaLoaiNghi)   REFERENCES dbo.LoaiNghiPhep(MaLoaiNghi),
        CONSTRAINT CK_NP_NgayKT          CHECK (NgayKetThuc >= NgayBatDau),
        CONSTRAINT CK_NP_TrangThai       CHECK (TrangThai IN ('P', 'A', 'R', 'C'))
    );
    CREATE INDEX IX_NghiPhep_NV     ON dbo.NghiPhep (MaNV, NgayBatDau);
    PRINT N'[OK] Tạo bảng NghiPhep';
END
GO

-- ── 9. NhanVienPhucLoi ───────────────────────────────────────
IF OBJECT_ID('dbo.NhanVienPhucLoi', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.NhanVienPhucLoi (
        MaNV            CHAR(8)         NOT NULL,
        MaFL            CHAR(6)         NOT NULL,
        GiaTriOverride  DECIMAL(15,2)   NULL,  -- Ghi đè nếu riêng cho NV này
        NgayApDung      DATE            NOT NULL,
        NgayKetThuc     DATE            NULL,
        IsActive        BIT             NOT NULL    DEFAULT 1,
        GhiChu          NVARCHAR(255)   NULL,

        CONSTRAINT PK_NVPhucLoi         PRIMARY KEY (MaNV, MaFL, NgayApDung),
        CONSTRAINT FK_NVL_NhanVien       FOREIGN KEY (MaNV) REFERENCES dbo.NhanVien(MaNV),
        CONSTRAINT FK_NVL_LoaiPhucLoi    FOREIGN KEY (MaFL) REFERENCES dbo.LoaiPhucLoi(MaFL),
        CONSTRAINT CK_NVL_GiaTri         CHECK (GiaTriOverride IS NULL
                                            OR GiaTriOverride >= 0)
    );
    PRINT N'[OK] Tạo bảng NhanVienPhucLoi';
END
GO


-- ============================================================
--  TIER 3 — Chấm công
-- ============================================================

-- ── 10. ChamCong ─────────────────────────────────────────────
IF OBJECT_ID('dbo.ChamCong', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.ChamCong (
        MaCC            BIGINT          NOT NULL    IDENTITY(1,1),
        MaNV            CHAR(8)         NOT NULL,   -- FK → NhanVien
        NgayCham        DATE            NOT NULL,
        GioVao          TIME(0)         NULL,
        GioRa           TIME(0)         NULL,
        TrangThai       CHAR(2)         NOT NULL,
        --  DL=Đi làm, NP=Nghỉ phép, OM=Ốm, CX=Công tác xa,
        --  KP=Không phép, NG=Nghỉ lễ, WFH=Làm từ xa
        SoGioLam        AS CASE
                             WHEN GioVao IS NOT NULL AND GioRa IS NOT NULL
                             THEN CAST(DATEDIFF(MINUTE, GioVao, GioRa) / 60.0
                                       AS DECIMAL(5,2))
                             ELSE 0
                           END PERSISTED,
        SoGioTangCa     DECIMAL(5,2)    NOT NULL    DEFAULT 0,
        HeSoTangCa      DECIMAL(4,2)    NOT NULL    DEFAULT 1.50,
        --  1.5x ngày thường / 2.0x cuối tuần / 3.0x lễ
        GhiChu          NVARCHAR(255)   NULL,
        NguoiCapNhat    NVARCHAR(100)   NULL,
        NgayTao         DATETIME2(0)    NOT NULL    DEFAULT SYSDATETIME(),
        NgayCapNhat     DATETIME2(0)    NOT NULL    DEFAULT SYSDATETIME(),

        CONSTRAINT PK_ChamCong          PRIMARY KEY (MaCC),
        CONSTRAINT FK_CC_NhanVien        FOREIGN KEY (MaNV) REFERENCES dbo.NhanVien(MaNV),
        CONSTRAINT UQ_ChamCong_NV_Ngay   UNIQUE (MaNV, NgayCham),    -- 1 NV 1 ngày 1 bản ghi
        CONSTRAINT CK_CC_TrangThai       CHECK (TrangThai IN (
                                            'DL', 'NP', 'OM', 'CX', 'KP', 'NG', 'WFH')),
        CONSTRAINT CK_CC_GioVaoRa        CHECK (GioVao IS NULL
                                            OR GioRa IS NULL
                                            OR GioRa > GioVao),
        CONSTRAINT CK_CC_TangCa          CHECK (SoGioTangCa >= 0 AND SoGioTangCa <= 12),
        CONSTRAINT CK_CC_HeSoTC          CHECK (HeSoTangCa IN (1.00, 1.50, 2.00, 3.00))
    );
    CREATE INDEX IX_ChamCong_NV_Ngay ON dbo.ChamCong (MaNV, NgayCham);
    CREATE INDEX IX_ChamCong_Ngay    ON dbo.ChamCong (NgayCham);
    PRINT N'[OK] Tạo bảng ChamCong';
END
GO


-- ============================================================
--  TIER 4 — Bảng lương & Chi tiết
-- ============================================================

-- ── 11. BangLuong (header — mỗi NV mỗi tháng 1 dòng) ────────
IF OBJECT_ID('dbo.BangLuong', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.BangLuong (
        MaBL            BIGINT          NOT NULL    IDENTITY(1,1),
        MaNV            CHAR(8)         NOT NULL,   -- FK → NhanVien
        Thang           TINYINT         NOT NULL,
        Nam             SMALLINT        NOT NULL,
        LuongCoBan      DECIMAL(15,2)   NOT NULL,   -- Snapshot lương CB tháng đó
        SoNgayCong      DECIMAL(5,2)    NOT NULL    DEFAULT 0,
        SoNgayLamChuan  DECIMAL(5,2)    NOT NULL    DEFAULT 26,   -- Ngày công chuẩn tháng
        HeSoTangCa      DECIMAL(15,2)   NOT NULL    DEFAULT 0,
        TongPhuCap      DECIMAL(15,2)   NOT NULL    DEFAULT 0,
        TongKhauTru     DECIMAL(15,2)   NOT NULL    DEFAULT 0,
        ThuNhapGop      AS (LuongCoBan * (SoNgayCong / NULLIF(SoNgayLamChuan,0))
                            + HeSoTangCa + TongPhuCap) PERSISTED,
        -- Các khoản khấu trừ chi tiết
        BHXH_NLD        DECIMAL(15,2)   NOT NULL    DEFAULT 0,   --  8%
        BHYT_NLD        DECIMAL(15,2)   NOT NULL    DEFAULT 0,   --  1.5%
        BHTN_NLD        DECIMAL(15,2)   NOT NULL    DEFAULT 0,   --  1%
        ThueTNCN        DECIMAL(15,2)   NOT NULL    DEFAULT 0,
        ThuNhapThucLinh AS (LuongCoBan * (SoNgayCong / NULLIF(SoNgayLamChuan,0))
                            + HeSoTangCa + TongPhuCap
                            - BHXH_NLD - BHYT_NLD - BHTN_NLD
                            - ThueTNCN - TongKhauTru) PERSISTED,
        TrangThai       CHAR(1)         NOT NULL    DEFAULT 'D',
        --  D=Draft, C=Confirmed, P=Paid, L=Locked
        NgayTinhLuong   DATETIME2(0)    NULL,
        NgayXacNhan     DATETIME2(0)    NULL,
        NgayThanhToan   DATE            NULL,
        NguoiTao        NVARCHAR(100)   NOT NULL    DEFAULT SYSTEM_USER,
        NgayTao         DATETIME2(0)    NOT NULL    DEFAULT SYSDATETIME(),
        NgayCapNhat     DATETIME2(0)    NOT NULL    DEFAULT SYSDATETIME(),

        CONSTRAINT PK_BangLuong             PRIMARY KEY (MaBL),
        CONSTRAINT FK_BL_NhanVien            FOREIGN KEY (MaNV) REFERENCES dbo.NhanVien(MaNV),
        CONSTRAINT UQ_BangLuong_NV_Ky        UNIQUE (MaNV, Thang, Nam),
        CONSTRAINT CK_BL_Thang               CHECK (Thang BETWEEN 1 AND 12),
        CONSTRAINT CK_BL_Nam                 CHECK (Nam  BETWEEN 2000 AND 2099),
        CONSTRAINT CK_BL_TrangThai           CHECK (TrangThai IN ('D', 'C', 'P', 'L')),
        CONSTRAINT CK_BL_SoNgayCong          CHECK (SoNgayCong >= 0 AND SoNgayCong <= 31),
        CONSTRAINT CK_BL_SoNgayChuan         CHECK (SoNgayLamChuan BETWEEN 20 AND 31)
    );
    CREATE INDEX IX_BangLuong_NV        ON dbo.BangLuong (MaNV, Nam DESC, Thang DESC);
    CREATE INDEX IX_BangLuong_KyLuong   ON dbo.BangLuong (Nam, Thang);
    PRINT N'[OK] Tạo bảng BangLuong';
END
GO

-- ── 12. ChiTietLuong (dòng item của bảng lương) ──────────────
IF OBJECT_ID('dbo.ChiTietLuong', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.ChiTietLuong (
        MaCTL           BIGINT          NOT NULL    IDENTITY(1,1),
        MaBL            BIGINT          NOT NULL,   -- FK → BangLuong
        LoaiMuc         CHAR(1)         NOT NULL,   -- '+' = Khoản cộng / '-' = Khoản trừ
        TenMuc          NVARCHAR(150)   NOT NULL,
        --  VD: Lương cơ bản, Phụ cấp ăn trưa, BHXH NLĐ, Thuế TNCN…
        GiaTri          DECIMAL(15,2)   NOT NULL,
        GhiChu          NVARCHAR(255)   NULL,

        CONSTRAINT PK_ChiTietLuong      PRIMARY KEY (MaCTL),
        CONSTRAINT FK_CTL_BangLuong      FOREIGN KEY (MaBL) REFERENCES dbo.BangLuong(MaBL)
                                            ON DELETE CASCADE,
        CONSTRAINT CK_CTL_LoaiMuc        CHECK (LoaiMuc IN ('+', '-')),
        CONSTRAINT CK_CTL_GiaTri         CHECK (GiaTri >= 0)
    );
    CREATE INDEX IX_ChiTietLuong_BL  ON dbo.ChiTietLuong (MaBL);
    PRINT N'[OK] Tạo bảng ChiTietLuong';
END
GO

-- ── 13. KhauTru (khấu trừ phát sinh ngoài chuẩn) ────────────
IF OBJECT_ID('dbo.KhauTru', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.KhauTru (
        MaKT            INT             NOT NULL    IDENTITY(1,1),
        MaNV            CHAR(8)         NOT NULL,
        MaBL            BIGINT          NULL,        -- Gắn vào kỳ lương cụ thể
        LoaiKhauTru     NVARCHAR(100)   NOT NULL,   -- Tạm ứng, Phạt vi phạm, Truy thu...
        GiaTri          DECIMAL(15,2)   NOT NULL,
        NgayPhatSinh    DATE            NOT NULL    DEFAULT CAST(GETDATE() AS DATE),
        TrangThai       CHAR(1)         NOT NULL    DEFAULT 'P',  -- P=Pending, A=Applied
        GhiChu          NVARCHAR(500)   NULL,
        NguoiDuyet      NVARCHAR(100)   NULL,
        NgayTao         DATETIME2(0)    NOT NULL    DEFAULT SYSDATETIME(),

        CONSTRAINT PK_KhauTru           PRIMARY KEY (MaKT),
        CONSTRAINT FK_KT_NhanVien        FOREIGN KEY (MaNV) REFERENCES dbo.NhanVien(MaNV),
        CONSTRAINT FK_KT_BangLuong       FOREIGN KEY (MaBL) REFERENCES dbo.BangLuong(MaBL),
        CONSTRAINT CK_KT_GiaTri          CHECK (GiaTri > 0),
        CONSTRAINT CK_KT_TrangThai       CHECK (TrangThai IN ('P', 'A', 'C'))
    );
    PRINT N'[OK] Tạo bảng KhauTru';
END
GO


-- ============================================================
--  TIER 5 — Audit Log (tự động điền bởi Trigger)
-- ============================================================

-- ── 14. AuditLog_HopDong ─────────────────────────────────────
IF OBJECT_ID('dbo.AuditLog_HopDong', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.AuditLog_HopDong (
        MaLog           BIGINT          NOT NULL    IDENTITY(1,1),
        MaHD            CHAR(10)        NOT NULL,
        MaNV            CHAR(8)         NOT NULL,
        LoaiThayDoi     CHAR(1)         NOT NULL,   -- I=Insert, U=Update, D=Delete
        TenCot          NVARCHAR(100)   NULL,
        GiaTriCu        NVARCHAR(MAX)   NULL,
        GiaTriMoi       NVARCHAR(MAX)   NULL,
        NguoiThayDoi    NVARCHAR(100)   NOT NULL    DEFAULT SYSTEM_USER,
        ThoiGianThayDoi DATETIME2(3)    NOT NULL    DEFAULT SYSDATETIME(),
        HostName        NVARCHAR(100)   NULL        DEFAULT HOST_NAME(),
        AppName         NVARCHAR(200)   NULL        DEFAULT APP_NAME(),

        CONSTRAINT PK_AuditLog_HD   PRIMARY KEY (MaLog)
    );
    CREATE INDEX IX_AuditHD_MaHD    ON dbo.AuditLog_HopDong (MaHD);
    CREATE INDEX IX_AuditHD_MaNV    ON dbo.AuditLog_HopDong (MaNV);
    CREATE INDEX IX_AuditHD_Tgian   ON dbo.AuditLog_HopDong (ThoiGianThayDoi DESC);
    PRINT N'[OK] Tạo bảng AuditLog_HopDong';
END
GO

-- ── 15. AuditLog_Luong ───────────────────────────────────────
IF OBJECT_ID('dbo.AuditLog_Luong', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.AuditLog_Luong (
        MaLog           BIGINT          NOT NULL    IDENTITY(1,1),
        MaBL            BIGINT          NULL,
        MaNV            CHAR(8)         NOT NULL,
        Thang           TINYINT         NULL,
        Nam             SMALLINT        NULL,
        LoaiThayDoi     CHAR(1)         NOT NULL,   -- I / U / D
        TenCot          NVARCHAR(100)   NULL,
        GiaTriCu        NVARCHAR(MAX)   NULL,
        GiaTriMoi       NVARCHAR(MAX)   NULL,
        NguoiThayDoi    NVARCHAR(100)   NOT NULL    DEFAULT SYSTEM_USER,
        ThoiGianThayDoi DATETIME2(3)    NOT NULL    DEFAULT SYSDATETIME(),
        HostName        NVARCHAR(100)   NULL        DEFAULT HOST_NAME(),

        CONSTRAINT PK_AuditLog_Luong    PRIMARY KEY (MaLog)
    );
    CREATE INDEX IX_AuditLuong_NV   ON dbo.AuditLog_Luong (MaNV);
    CREATE INDEX IX_AuditLuong_Ky   ON dbo.AuditLog_Luong (Nam, Thang);
    PRINT N'[OK] Tạo bảng AuditLog_Luong';
END
GO


-- ============================================================
--  XÁC NHẬN TOÀN BỘ ĐÃ TẠO THÀNH CÔNG
-- ============================================================
PRINT N'';
PRINT N'════════════════════════════════════════════════════';
PRINT N'  Kiểm tra tổng số bảng trong HRPayrollDB:';
PRINT N'════════════════════════════════════════════════════';

SELECT
    t.name              AS TenBang,
    s.name              AS Schema_,
    p.rows              AS SoBanGhi,
    CAST(
        (SUM(a.total_pages) * 8) / 1024.0
    AS DECIMAL(10,2))   AS DungLuong_KB
FROM
    sys.tables              t
    INNER JOIN sys.schemas  s ON t.schema_id  = s.schema_id
    INNER JOIN sys.indexes  i ON t.object_id  = i.object_id
    INNER JOIN sys.partitions p ON i.object_id= p.object_id
                               AND i.index_id = p.index_id
    INNER JOIN sys.allocation_units a ON p.partition_id = a.container_id
WHERE
    t.is_ms_shipped = 0
    AND i.object_id > 255
GROUP BY
    t.name, s.name, p.rows
ORDER BY
    t.name;

PRINT N'';
PRINT N'[DONE] 01_create_tables.sql — 15 bảng tạo thành công.';
GO
