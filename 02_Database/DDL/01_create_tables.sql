--  Hệ thống Quản lý Nhân sự & Tính lương tự động
--  DBMS  : MySQL 8.0+
--  Author: HRPayroll Team
--  Phiên : v2.0 (Converted from SQL Server)
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
-- Tạo database nếu chưa tồn tại
CREATE DATABASE IF NOT EXISTS HRPayrollDB
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE HRPayrollDB;

--  TIER 0 — Danh mục độc lập (lookup / master data)

-- ── 1. PhongBan ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS PhongBan (
    MaPB            CHAR(6)         NOT NULL,          -- VD: PB0001
    TenPB           VARCHAR(100)    NOT NULL,
    DiaDiem         VARCHAR(150)    NULL,
    DienThoai       VARCHAR(20)     NULL,
    Email           VARCHAR(100)    NULL,
    MaTruongPhong   CHAR(8)         NULL,              -- FK → NhanVien (set sau)
    NgayThanhLap    DATE            NULL,
    GhiChu          VARCHAR(255)    NULL,
    IsActive        TINYINT      NOT NULL DEFAULT 1,
    NgayTao         DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    NgayCapNhat     DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (MaPB),
    UNIQUE KEY UQ_PhongBan_TenPB (TenPB),
    -- CHECK Email sẽ được enforce bằng trigger (MySQL 8.0+ hỗ trợ CHECK nhưng hạn chế)
    CONSTRAINT CK_PhongBan_MaPB_Format CHECK (MaPB REGEXP '^PB[0-9]{4}$')
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ── 2. ChucVu ────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS ChucVu (
    MaCV            CHAR(6)         NOT NULL,          -- VD: CV0001
    TenCV           VARCHAR(100)    NOT NULL,
    HeSoLuong       DECIMAL(5,2)    NOT NULL DEFAULT 1.00,
    MoTa            VARCHAR(500)    NULL,
    CapBac          TINYINT         NOT NULL DEFAULT 1, -- 1=Nhân viên … 5=Giám đốc
    IsActive        TINYINT      NOT NULL DEFAULT 1,
    NgayTao         DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (MaCV),
    UNIQUE KEY UQ_ChucVu_TenCV (TenCV),
    CONSTRAINT CK_ChucVu_HeSo   CHECK (HeSoLuong BETWEEN 0.50 AND 10.00),
    CONSTRAINT CK_ChucVu_CapBac CHECK (CapBac BETWEEN 1 AND 5),
    CONSTRAINT CK_ChucVu_MaCV_Format CHECK (MaCV REGEXP '^CV[0-9]{4}$')
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ── 3. LoaiHopDong ───────────────────────────────────────────
CREATE TABLE IF NOT EXISTS LoaiHopDong (
    MaLoaiHD        TINYINT         NOT NULL AUTO_INCREMENT,
    TenLoaiHD       VARCHAR(100)    NOT NULL,          -- VD: Thử việc, Chính thức, Thời vụ
    ThoiHanToiDa    SMALLINT        NULL,              -- Số tháng, NULL = không giới hạn
    TiLeBHXH        DECIMAL(5,2)    NOT NULL DEFAULT 8.00, -- % NLĐ đóng
    MoTa            VARCHAR(255)    NULL,

    PRIMARY KEY (MaLoaiHD),
    UNIQUE KEY UQ_LoaiHopDong_Ten (TenLoaiHD),
    CONSTRAINT CK_LHD_TiLeBHXH   CHECK (TiLeBHXH BETWEEN 0 AND 20)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ── 4. LoaiNghiPhep ──────────────────────────────────────────
CREATE TABLE IF NOT EXISTS LoaiNghiPhep (
    MaLoaiNghi      TINYINT         NOT NULL AUTO_INCREMENT,
    TenLoaiNghi     VARCHAR(100)    NOT NULL, -- Phép năm, Ốm, Thai sản, Không lương
    CoHuongLuong    TINYINT      NOT NULL DEFAULT 1,
    SoNgayToiDa     SMALLINT        NULL,     -- Giới hạn năm, NULL = không giới hạn
    MoTa            VARCHAR(255)    NULL,

    PRIMARY KEY (MaLoaiNghi),
    UNIQUE KEY UQ_LoaiNghiPhep_Ten (TenLoaiNghi)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ── 5. LoaiPhucLoi ───────────────────────────────────────────
CREATE TABLE IF NOT EXISTS LoaiPhucLoi (
    MaFL            CHAR(6)         NOT NULL,          -- VD: FL0001
    TenFL           VARCHAR(100)    NOT NULL,          -- Ăn trưa, Xăng xe, Điện thoại…
    LoaiGiaTri      CHAR(1)         NOT NULL DEFAULT 'F', -- F=Cố định, P=Phần trăm
    GiaTri          DECIMAL(15,2)   NOT NULL DEFAULT 0,
    CoTinhThue      TINYINT      NOT NULL DEFAULT 0, -- Có chịu thuế TNCN không
    MoTa            VARCHAR(255)    NULL,
    IsActive        TINYINT      NOT NULL DEFAULT 1,

    PRIMARY KEY (MaFL),
    UNIQUE KEY UQ_LoaiPhucLoi_Ten (TenFL),
    CONSTRAINT CK_LoaiFL_LoaiGT  CHECK (LoaiGiaTri IN ('F', 'P')),
    CONSTRAINT CK_LoaiFL_GiaTri  CHECK (GiaTri >= 0),
    CONSTRAINT CK_LoaiPhucLoi_MaFL_Format CHECK (MaFL REGEXP '^FL[0-9]{4}$')
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ── 6. NgayLe (bảng phụ cho hàm tính ngày chuẩn) ────────────
CREATE TABLE IF NOT EXISTS NgayLe (
    NgayLe          DATE            NOT NULL,
    TenNgayLe       VARCHAR(100)    NULL,
    GhiChu          VARCHAR(255)    NULL,

    PRIMARY KEY (NgayLe)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


--  TIER 1 — NhanVien (bảng trung tâm)

CREATE TABLE IF NOT EXISTS NhanVien (
    MaNV            CHAR(8)         NOT NULL,          -- VD: NV000001
    HoTen           VARCHAR(100)    NOT NULL,
    GioiTinh        CHAR(1)         NOT NULL,          -- M / F
    NgaySinh        DATE            NOT NULL,
    CCCD            VARCHAR(12)     NOT NULL,          -- Căn cước công dân 12 số
    DiaChi          VARCHAR(300)    NULL,
    Email           VARCHAR(100)    NULL,
    SoDienThoai     VARCHAR(15)     NULL,
    MaPB            CHAR(6)         NOT NULL,          -- FK → PhongBan
    MaCV            CHAR(6)         NOT NULL,          -- FK → ChucVu
    NgayVaoLam      DATE            NOT NULL,
    NgayNghiViec    DATE            NULL,              -- NULL = đang làm việc
    TrangThai       CHAR(1)         NOT NULL DEFAULT 'A',
    --   A=Active, L=On Leave, T=Terminated, P=Probation
    MaSoThue        VARCHAR(14)     NULL,              -- MST cá nhân
    SoTaiKhoanNH    VARCHAR(20)     NULL,              -- Số tài khoản ngân hàng
    TenNganHang     VARCHAR(100)    NULL,
    SoNguoiPhuThuoc TINYINT         NOT NULL DEFAULT 0,
    GhiChu          VARCHAR(500)    NULL,
    NgayTao         DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    NgayCapNhat     DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    NguoiTao        VARCHAR(100)    NOT NULL DEFAULT (CURRENT_USER()),

    PRIMARY KEY (MaNV),
    UNIQUE KEY UQ_NhanVien_CCCD  (CCCD),
    UNIQUE KEY UQ_NhanVien_Email (Email),
    CONSTRAINT FK_NV_PhongBan    FOREIGN KEY (MaPB) REFERENCES PhongBan(MaPB),
    CONSTRAINT FK_NV_ChucVu      FOREIGN KEY (MaCV) REFERENCES ChucVu(MaCV),
    CONSTRAINT CK_NV_GioiTinh   CHECK (GioiTinh IN ('M', 'F')),
    CONSTRAINT CK_NV_TrangThai  CHECK (TrangThai IN ('A', 'L', 'T', 'P')),
    CONSTRAINT CK_NV_CCCD       CHECK (CHAR_LENGTH(CCCD) = 12 AND CCCD REGEXP '^[0-9]+$'),
    CONSTRAINT CK_NV_MaNV_Format CHECK (MaNV REGEXP '^NV[0-9]{6}$')
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Index thường dùng khi tìm kiếm nhân viên
CREATE INDEX IX_NhanVien_PB  ON NhanVien (MaPB);
CREATE INDEX IX_NhanVien_CV  ON NhanVien (MaCV);
CREATE INDEX IX_NhanVien_Ten ON NhanVien (HoTen);
CREATE INDEX IX_NhanVien_TT  ON NhanVien (TrangThai);

-- Sau khi có NhanVien, thêm FK ngược cho PhongBan.MaTruongPhong
ALTER TABLE PhongBan
    ADD CONSTRAINT FK_PhongBan_TruongPhong
        FOREIGN KEY (MaTruongPhong) REFERENCES NhanVien(MaNV);


--  TIER 2 — Hợp đồng & Lương cơ bản

-- ── 7. HopDong ───────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS HopDong (
    MaHD            CHAR(10)        NOT NULL,          -- VD: HD00000001
    MaNV            CHAR(8)         NOT NULL,          -- FK → NhanVien
    MaLoaiHD        TINYINT         NOT NULL,          -- FK → LoaiHopDong
    NgayBatDau      DATE            NOT NULL,
    NgayKetThuc     DATE            NULL,              -- NULL = không xác định
    LuongCoBan      DECIMAL(15,2)   NOT NULL,         -- Lương ghi trên HĐ
    VungLuong       TINYINT         NOT NULL DEFAULT 1,
    --  Vùng 1=5.590.000 / 2=4.960.000 / 3=4.340.000 / 4=3.900.000 (2024)
    FileDinhKem     VARCHAR(300)    NULL,              -- Đường dẫn file scan HĐ
    TrangThai       CHAR(1)         NOT NULL DEFAULT 'A',
    --  A=Active, E=Expired, T=Terminated, D=Draft
    NguoiKy_NLD    VARCHAR(100)    NULL,              -- Người lao động
    NguoiKy_NSDLD  VARCHAR(100)    NULL,              -- Đại diện công ty
    NgayKy          DATE            NULL,
    GhiChu          VARCHAR(500)    NULL,
    NgayTao         DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    NgayCapNhat     DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    NguoiTao        VARCHAR(100)    NOT NULL DEFAULT (CURRENT_USER()),

    PRIMARY KEY (MaHD),
    CONSTRAINT FK_HD_NhanVien    FOREIGN KEY (MaNV)     REFERENCES NhanVien(MaNV),
    CONSTRAINT FK_HD_LoaiHopDong FOREIGN KEY (MaLoaiHD) REFERENCES LoaiHopDong(MaLoaiHD),
    CONSTRAINT CK_HD_LuongCoBan  CHECK (LuongCoBan > 0),
    CONSTRAINT CK_HD_VungLuong   CHECK (VungLuong BETWEEN 1 AND 4),
    CONSTRAINT CK_HD_TrangThai   CHECK (TrangThai IN ('A', 'E', 'T', 'D')),
    CONSTRAINT CK_HD_NgayKetThuc CHECK (NgayKetThuc IS NULL OR NgayKetThuc > NgayBatDau),
    CONSTRAINT CK_HopDong_MaHD_Format CHECK (MaHD REGEXP '^HD[0-9]{8}$'),
    CONSTRAINT CK_HopDong_NgayBatDauHopLe CHECK (NgayBatDau >= '2000-01-01'),
    CONSTRAINT CK_HopDong_NgayKyHopLe CHECK (NgayKy IS NULL OR NgayKy <= NgayBatDau)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
CREATE INDEX IX_HopDong_NV ON HopDong (MaNV);
CREATE INDEX IX_HopDong_TT ON HopDong (TrangThai);
-- Filtered unique index cho 1 hợp đồng active/NV — thực hiện qua trigger trong MySQL


-- ── 8. LuongCoBan (lịch sử thay đổi lương) ──────────────────
CREATE TABLE IF NOT EXISTS LuongCoBan (
    MaLCB           INT             NOT NULL AUTO_INCREMENT,
    MaNV            CHAR(8)         NOT NULL,          -- FK → NhanVien
    LuongCB         DECIMAL(15,2)   NOT NULL,
    LuongDongBH     DECIMAL(15,2)   NOT NULL,         -- Lương đóng BHXH (≤ 20 lần lương CS)
    NgayHieuLuc     DATE            NOT NULL,
    NgayHetHieuLuc  DATE            NULL,
    LyDo            VARCHAR(255)    NULL,              -- Tăng lương định kỳ / thăng chức...
    NguoiDuyet      VARCHAR(100)    NULL,
    NgayTao         DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (MaLCB),
    CONSTRAINT FK_LCB_NhanVien FOREIGN KEY (MaNV) REFERENCES NhanVien(MaNV),
    CONSTRAINT CK_LCB_LuongCB  CHECK (LuongCB > 0),
    CONSTRAINT CK_LCB_DongBH   CHECK (LuongDongBH > 0 AND LuongDongBH <= LuongCB),
    CONSTRAINT CK_LCB_NgayHH   CHECK (NgayHetHieuLuc IS NULL OR NgayHetHieuLuc > NgayHieuLuc),
    CONSTRAINT CK_LuongCoBan_TranDongBH CHECK (LuongDongBH <= 46800000),
    CONSTRAINT CK_LuongCoBan_NguongTran CHECK (LuongCB <= 500000000)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE INDEX IX_LuongCoBan_NV ON LuongCoBan (MaNV, NgayHieuLuc DESC);


-- ── 9. NghiPhep ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS NghiPhep (
    MaNP            INT             NOT NULL AUTO_INCREMENT,
    MaNV            CHAR(8)         NOT NULL,          -- FK → NhanVien
    MaLoaiNghi      TINYINT         NOT NULL,          -- FK → LoaiNghiPhep
    NgayBatDau      DATE            NOT NULL,
    NgayKetThuc     DATE            NOT NULL,
    -- SoNgayNghi: MySQL không hỗ trợ computed column dạng SQL Server
    -- Sử dụng GENERATED COLUMN thay thế
    SoNgayNghi      INT             AS (DATEDIFF(NgayKetThuc, NgayBatDau) + 1) STORED,
    LyDo            VARCHAR(500)    NULL,
    TrangThai       CHAR(1)         NOT NULL DEFAULT 'P',
    --  P=Pending, A=Approved, R=Rejected, C=Cancelled
    NguoiDuyet      VARCHAR(100)    NULL,
    NgayDuyet       DATETIME        NULL,
    GhiChu          VARCHAR(255)    NULL,
    NgayTao         DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (MaNP),
    CONSTRAINT FK_NP_NhanVien     FOREIGN KEY (MaNV)       REFERENCES NhanVien(MaNV),
    CONSTRAINT FK_NP_LoaiNghiPhep FOREIGN KEY (MaLoaiNghi) REFERENCES LoaiNghiPhep(MaLoaiNghi),
    CONSTRAINT CK_NP_NgayKT       CHECK (NgayKetThuc >= NgayBatDau),
    CONSTRAINT CK_NP_TrangThai    CHECK (TrangThai IN ('P', 'A', 'R', 'C')),
    CONSTRAINT CK_NghiPhep_SoNgayMax CHECK (DATEDIFF(NgayKetThuc, NgayBatDau) <= 365)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE INDEX IX_NghiPhep_NV ON NghiPhep (MaNV, NgayBatDau);


-- ── 10. NhanVienPhucLoi ───────────────────────────────────────
CREATE TABLE IF NOT EXISTS NhanVienPhucLoi (
    MaNV            CHAR(8)         NOT NULL,
    MaFL            CHAR(6)         NOT NULL,
    GiaTriOverride  DECIMAL(15,2)   NULL,  -- Ghi đè nếu riêng cho NV này
    NgayApDung      DATE            NOT NULL,
    NgayKetThuc     DATE            NULL,
    IsActive        TINYINT      NOT NULL DEFAULT 1,
    GhiChu          VARCHAR(255)    NULL,

    PRIMARY KEY (MaNV, MaFL, NgayApDung),
    CONSTRAINT FK_NVL_NhanVien    FOREIGN KEY (MaNV) REFERENCES NhanVien(MaNV),
    CONSTRAINT FK_NVL_LoaiPhucLoi FOREIGN KEY (MaFL) REFERENCES LoaiPhucLoi(MaFL),
    CONSTRAINT CK_NVL_GiaTri      CHECK (GiaTriOverride IS NULL OR GiaTriOverride >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


--  TIER 3 — Chấm công

-- ── 11. ChamCong ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS ChamCong (
    MaCC            BIGINT          NOT NULL AUTO_INCREMENT,
    MaNV            CHAR(8)         NOT NULL,          -- FK → NhanVien
    NgayCham        DATE            NOT NULL,
    GioVao          TIME            NULL,
    GioRa           TIME            NULL,
    TrangThai       CHAR(3)         NOT NULL,
    --  DL=Đi làm, NP=Nghỉ phép, OM=Ốm, CX=Công tác xa,
    --  KP=Không phép, NG=Nghỉ lễ, WFH=Làm từ xa
    -- SoGioLam: GENERATED COLUMN thay cho computed column SQL Server
    SoGioLam        DECIMAL(5,2)    AS (
                        CASE
                            WHEN GioVao IS NOT NULL AND GioRa IS NOT NULL
                            THEN ROUND(TIMESTAMPDIFF(MINUTE, GioVao, GioRa) / 60.0, 2)
                            ELSE 0
                        END
                    ) STORED,
    SoGioTangCa     DECIMAL(5,2)    NOT NULL DEFAULT 0,
    HeSoTangCa      DECIMAL(4,2)    NOT NULL DEFAULT 1.50,
    --  1.5x ngày thường / 2.0x cuối tuần / 3.0x lễ
    GhiChu          VARCHAR(255)    NULL,
    NguoiCapNhat    VARCHAR(100)    NULL,
    NgayTao         DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    NgayCapNhat     DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (MaCC),
    CONSTRAINT FK_CC_NhanVien      FOREIGN KEY (MaNV) REFERENCES NhanVien(MaNV),
    UNIQUE KEY UQ_ChamCong_NV_Ngay (MaNV, NgayCham),     -- 1 NV 1 ngày 1 bản ghi
    CONSTRAINT CK_CC_TrangThai     CHECK (TrangThai IN ('DL', 'NP', 'OM', 'CX', 'KP', 'NG', 'WFH')),
    CONSTRAINT CK_CC_GioVaoRa      CHECK (GioVao IS NULL OR GioRa IS NULL OR GioRa > GioVao),
    CONSTRAINT CK_CC_TangCa        CHECK (SoGioTangCa >= 0 AND SoGioTangCa <= 12),
    CONSTRAINT CK_CC_HeSoTC        CHECK (HeSoTangCa IN (1.00, 1.50, 2.00, 3.00))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE INDEX IX_ChamCong_NV_Ngay ON ChamCong (MaNV, NgayCham);
CREATE INDEX IX_ChamCong_Ngay    ON ChamCong (NgayCham);


--  TIER 4 — Bảng lương & Chi tiết

-- ── 12. BangLuong (header — mỗi NV mỗi tháng 1 dòng) ────────
CREATE TABLE IF NOT EXISTS BangLuong (
    MaBL            BIGINT          NOT NULL AUTO_INCREMENT,
    MaNV            CHAR(8)         NOT NULL,          -- FK → NhanVien
    Thang           TINYINT         NOT NULL,
    Nam             SMALLINT        NOT NULL,
    LuongCoBan      DECIMAL(15,2)   NOT NULL,         -- Snapshot lương CB tháng đó
    SoNgayCong      DECIMAL(5,2)    NOT NULL DEFAULT 0,
    SoNgayLamChuan  DECIMAL(5,2)    NOT NULL DEFAULT 26, -- Ngày công chuẩn tháng
    HeSoTangCa      DECIMAL(15,2)   NOT NULL DEFAULT 0,
    TongPhuCap      DECIMAL(15,2)   NOT NULL DEFAULT 0,
    TongKhauTru     DECIMAL(15,2)   NOT NULL DEFAULT 0,
    -- ThuNhapGop: GENERATED COLUMN thay cho computed column SQL Server
    ThuNhapGop      DECIMAL(15,2)   AS (
                        LuongCoBan * (SoNgayCong / NULLIF(SoNgayLamChuan, 0))
                        + HeSoTangCa + TongPhuCap
                    ) STORED,
    -- Các khoản khấu trừ chi tiết
    BHXH_NLD        DECIMAL(15,2)   NOT NULL DEFAULT 0, --  8%
    BHYT_NLD        DECIMAL(15,2)   NOT NULL DEFAULT 0, --  1.5%
    BHTN_NLD        DECIMAL(15,2)   NOT NULL DEFAULT 0, --  1%
    ThueTNCN        DECIMAL(15,2)   NOT NULL DEFAULT 0,
    ThuNhapThucLinh DECIMAL(15,2)   AS (
                        LuongCoBan * (SoNgayCong / NULLIF(SoNgayLamChuan, 0))
                        + HeSoTangCa + TongPhuCap
                        - BHXH_NLD - BHYT_NLD - BHTN_NLD
                        - ThueTNCN - TongKhauTru
                    ) STORED,
    TrangThai       CHAR(1)         NOT NULL DEFAULT 'D',
    --  D=Draft, C=Confirmed, P=Paid, L=Locked
    NgayTinhLuong   DATETIME        NULL,
    NgayXacNhan     DATETIME        NULL,
    NgayThanhToan   DATE            NULL,
    NguoiTao        VARCHAR(100)    NOT NULL DEFAULT (CURRENT_USER()),
    NgayTao         DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    NgayCapNhat     DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (MaBL),
    CONSTRAINT FK_BL_NhanVien       FOREIGN KEY (MaNV) REFERENCES NhanVien(MaNV),
    UNIQUE KEY UQ_BangLuong_NV_Ky   (MaNV, Thang, Nam),
    CONSTRAINT CK_BL_Thang          CHECK (Thang BETWEEN 1 AND 12),
    CONSTRAINT CK_BL_Nam            CHECK (Nam   BETWEEN 2000 AND 2099),
    CONSTRAINT CK_BL_TrangThai      CHECK (TrangThai IN ('D', 'C', 'P', 'L')),
    CONSTRAINT CK_BL_SoNgayCong     CHECK (SoNgayCong >= 0 AND SoNgayCong <= 31),
    CONSTRAINT CK_BL_SoNgayChuan    CHECK (SoNgayLamChuan BETWEEN 20 AND 31),
    CONSTRAINT CK_BangLuong_BaoHiemHopLe CHECK (
        BHXH_NLD >= 0 AND BHYT_NLD >= 0 AND BHTN_NLD >= 0
        AND (BHXH_NLD + BHYT_NLD + BHTN_NLD) <= LuongCoBan
    ),
    CONSTRAINT CK_BangLuong_ThueTNCN_HopLe CHECK (
        ThueTNCN >= 0
        AND (LuongCoBan = 0 OR ThueTNCN <= LuongCoBan * 0.35)
    )
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE INDEX IX_BangLuong_NV      ON BangLuong (MaNV, Nam DESC, Thang DESC);
CREATE INDEX IX_BangLuong_KyLuong ON BangLuong (Nam, Thang);


-- ── 13. ChiTietLuong (dòng item của bảng lương) ──────────────
CREATE TABLE IF NOT EXISTS ChiTietLuong (
    MaCTL           BIGINT          NOT NULL AUTO_INCREMENT,
    MaBL            BIGINT          NOT NULL,          -- FK → BangLuong
    LoaiMuc         CHAR(1)         NOT NULL,          -- '+' = Khoản cộng / '-' = Khoản trừ
    TenMuc          VARCHAR(150)    NOT NULL,
    --  VD: Lương cơ bản, Phụ cấp ăn trưa, BHXH NLĐ, Thuế TNCN…
    GiaTri          DECIMAL(15,2)   NOT NULL,
    GhiChu          VARCHAR(255)    NULL,

    PRIMARY KEY (MaCTL),
    CONSTRAINT FK_CTL_BangLuong FOREIGN KEY (MaBL) REFERENCES BangLuong(MaBL)
                                    ON DELETE CASCADE,
    CONSTRAINT CK_CTL_LoaiMuc   CHECK (LoaiMuc IN ('+', '-')),
    CONSTRAINT CK_CTL_GiaTri    CHECK (GiaTri >= 0),
    CONSTRAINT CK_ChiTietLuong_NguongBatThuong CHECK (GiaTri <= 500000000)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE INDEX IX_ChiTietLuong_BL ON ChiTietLuong (MaBL);


-- ── 14. KhauTru (khấu trừ phát sinh ngoài chuẩn) ────────────
CREATE TABLE IF NOT EXISTS KhauTru (
    MaKT            INT             NOT NULL AUTO_INCREMENT,
    MaNV            CHAR(8)         NOT NULL,
    MaBL            BIGINT          NULL,              -- Gắn vào kỳ lương cụ thể
    LoaiKhauTru     VARCHAR(100)    NOT NULL,         -- Tạm ứng, Phạt vi phạm, Truy thu...
    GiaTri          DECIMAL(15,2)   NOT NULL,
    NgayPhatSinh    DATE            NOT NULL DEFAULT (CURDATE()),
    TrangThai       CHAR(1)         NOT NULL DEFAULT 'P',  -- P=Pending, A=Applied
    GhiChu          VARCHAR(500)    NULL,
    NguoiDuyet      VARCHAR(100)    NULL,
    NgayTao         DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (MaKT),
    CONSTRAINT FK_KT_NhanVien   FOREIGN KEY (MaNV) REFERENCES NhanVien(MaNV),
    CONSTRAINT FK_KT_BangLuong  FOREIGN KEY (MaBL) REFERENCES BangLuong(MaBL),
    CONSTRAINT CK_KT_GiaTri     CHECK (GiaTri > 0),
    CONSTRAINT CK_KT_TrangThai  CHECK (TrangThai IN ('P', 'A', 'C')),
    CONSTRAINT CK_KhauTru_NguongBatThuong CHECK (GiaTri <= 200000000)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


--  TIER 5 — Audit Log (tự động điền bởi Trigger)

-- ── 15. AuditLog_HopDong ─────────────────────────────────────
CREATE TABLE IF NOT EXISTS AuditLog_HopDong (
    MaLog           BIGINT          NOT NULL AUTO_INCREMENT,
    MaHD            CHAR(10)        NOT NULL,
    MaNV            CHAR(8)         NOT NULL,
    LoaiThayDoi     VARCHAR(10)     NOT NULL,          -- INSERT, UPDATE, DELETE
    TenCot          VARCHAR(100)    NULL,
    GiaTriCu        TEXT            NULL,
    GiaTriMoi       TEXT            NULL,
    NguoiThayDoi    VARCHAR(100)    NOT NULL DEFAULT (CURRENT_USER()),
    ThoiGianThayDoi DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    HostName        VARCHAR(100)    NULL,

    PRIMARY KEY (MaLog),
    INDEX IX_AuditHD_MaHD  (MaHD),
    INDEX IX_AuditHD_MaNV  (MaNV),
    INDEX IX_AuditHD_Tgian (ThoiGianThayDoi DESC)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ── 16. AuditLog_Luong ───────────────────────────────────────
CREATE TABLE IF NOT EXISTS AuditLog_Luong (
    MaLog           BIGINT          NOT NULL AUTO_INCREMENT,
    MaBL            BIGINT          NULL,
    MaNV            CHAR(8)         NOT NULL,
    Thang           TINYINT         NULL,
    Nam             SMALLINT        NULL,
    LoaiThayDoi     VARCHAR(15)     NOT NULL,          -- INSERT, UPDATE, DELETE, STATUS_CHANGE
    TenCot          VARCHAR(100)    NULL,
    GiaTriCu        TEXT            NULL,
    GiaTriMoi       TEXT            NULL,
    NguoiThayDoi    VARCHAR(100)    NOT NULL DEFAULT (CURRENT_USER()),
    ThoiGianThayDoi DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    HostName        VARCHAR(100)    NULL,

    PRIMARY KEY (MaLog),
    INDEX IX_AuditLuong_NV  (MaNV),
    INDEX IX_AuditLuong_Ky  (Nam, Thang)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
-- ── 17. TaiKhoan ───────────────────────────────────────
CREATE TABLE IF NOT EXISTS TaiKhoan (
    MaTK            INT             NOT NULL AUTO_INCREMENT,
    TenDangNhap     VARCHAR(50)     NOT NULL,
    MatKhau         VARCHAR(255)    NOT NULL,
    Quyen           ENUM('ADMIN', 'HR', 'DIRECTOR', 'EMPLOYEE') NOT NULL DEFAULT 'EMPLOYEE',
    MaNV            CHAR(8)         NULL,
    TrangThai       CHAR(1)         NOT NULL DEFAULT 'A',
    NgayTao         DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (MaTK),
    UNIQUE KEY UQ_TaiKhoan_TenDangNhap (TenDangNhap),
    CONSTRAINT FK_TK_NhanVien FOREIGN KEY (MaNV) REFERENCES NhanVien(MaNV)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--  XÁC NHẬN TOÀN BỘ ĐÃ TẠO THÀNH CÔNG
SELECT
    TABLE_NAME      AS TenBang,
    TABLE_ROWS      AS SoBanGhi_UocTinh,
    ROUND((DATA_LENGTH + INDEX_LENGTH) / 1024, 2) AS DungLuong_KB
FROM
    information_schema.TABLES
WHERE
    TABLE_SCHEMA = 'HRPayrollDB'
ORDER BY
    TABLE_NAME;

SELECT CONCAT('[DONE] 01_create_tables.sql — ', COUNT(*), ' bảng đã tạo thành công.') AS KetQua
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = 'HRPayrollDB';
