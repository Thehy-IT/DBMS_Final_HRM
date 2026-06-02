-- ============================================================
-- FILE       : trg_LogHopDong.sql
-- PROJECT    : Hệ Thống Quản Lý Nhân Sự & Tính Lương Tự Động
-- MỤC ĐÍCH   : Trigger tự động ghi AUDIT LOG mọi thay đổi
--              trên bảng HopDong (INSERT / UPDATE / DELETE)
-- ─────────────────────────────────────────────────────────────
-- TRIGGERS   :
--   1. trg_HopDong_AfterInsert  — log hợp đồng mới
--   2. trg_HopDong_AfterUpdate  — log từng cột bị thay đổi
--   3. trg_HopDong_AfterDelete  — log hợp đồng bị xoá
--   4. trg_HopDong_GuardChot    — PREVENT sửa HĐ đã CHOT
-- BR-08: Mọi UPDATE/DELETE trên HopDong → ghi AuditLog_HopDong
-- BR-14: Hợp đồng TrangThai='L' (Locked) không cho sửa/xóa
-- ============================================================

USE HRPayrollDB;
GO

-- ============================================================
-- TRIGGER 1: trg_HopDong_AfterInsert
-- Ghi log khi thêm hợp đồng mới
-- ============================================================
IF OBJECT_ID('dbo.trg_HopDong_AfterInsert','TR') IS NOT NULL
    DROP TRIGGER dbo.trg_HopDong_AfterInsert;
GO

CREATE TRIGGER dbo.trg_HopDong_AfterInsert
ON dbo.HopDong
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    -- Không log nếu không có dòng nào
    IF @@ROWCOUNT = 0 RETURN;

    INSERT INTO dbo.AuditLog_HopDong
        (MaHD, MaNV, HanhDong, TenCot, GiaTriCu, GiaTriMoi)
    SELECT
        i.MaHD,
        i.MaNV,
        'INSERT',
        N'[FULL_RECORD]',
        NULL,
        -- Nối toàn bộ giá trị thành 1 chuỗi JSON-like
        N'{'
        + N'"MaLoaiHD":"'      + CAST(i.MaLoaiHD AS NVARCHAR)    + N'",'
        + N'"NgayBatDau":"'    + CONVERT(NVARCHAR,i.NgayBatDau,23)+ N'",'
        + N'"NgayKetThuc":"'
            + ISNULL(CONVERT(NVARCHAR,i.NgayKetThuc,23),N'NULL')  + N'",'
        + N'"LuongCoBan":'     + CAST(i.LuongCoBan AS NVARCHAR)   + N','
        + N'"VungLuong":'      + CAST(i.VungLuong  AS NVARCHAR)   + N','
        + N'"TrangThai":"'     + i.TrangThai + N'"'
        + N'}'
    FROM INSERTED i;
END;
GO
PRINT N'[OK] trg_HopDong_AfterInsert';
GO

-- ============================================================
-- TRIGGER 2: trg_HopDong_AfterUpdate
-- Ghi log chi tiết TỪNG CỘT bị thay đổi
-- Kỹ thuật: so sánh INSERTED vs DELETED column-by-column
-- ============================================================
IF OBJECT_ID('dbo.trg_HopDong_AfterUpdate','TR') IS NOT NULL
    DROP TRIGGER dbo.trg_HopDong_AfterUpdate;
GO

CREATE TRIGGER dbo.trg_HopDong_AfterUpdate
ON dbo.HopDong
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF @@ROWCOUNT = 0 RETURN;

    -- Bảng tạm để gom các cột thay đổi
    DECLARE @Changes TABLE (
        MaHD        NCHAR(10),
        MaNV        NCHAR(10),
        TenCot      NVARCHAR(100),
        GiaTriCu    NVARCHAR(MAX),
        GiaTriMoi   NVARCHAR(MAX)
    );

    -- ── Cột: MaLoaiHD ────────────────────────────────────────
    INSERT @Changes
    SELECT d.MaHD, d.MaNV, 'MaLoaiHD',
           CAST(d.MaLoaiHD AS NVARCHAR),
           CAST(i.MaLoaiHD AS NVARCHAR)
    FROM DELETED d JOIN INSERTED i ON d.MaHD = i.MaHD
    WHERE d.MaLoaiHD <> i.MaLoaiHD;

    -- ── Cột: NgayBatDau ───────────────────────────────────────
    INSERT @Changes
    SELECT d.MaHD, d.MaNV, 'NgayBatDau',
           CONVERT(NVARCHAR,d.NgayBatDau,23),
           CONVERT(NVARCHAR,i.NgayBatDau,23)
    FROM DELETED d JOIN INSERTED i ON d.MaHD = i.MaHD
    WHERE ISNULL(d.NgayBatDau,'') <> ISNULL(i.NgayBatDau,'');

    -- ── Cột: NgayKetThuc ──────────────────────────────────────
    INSERT @Changes
    SELECT d.MaHD, d.MaNV, 'NgayKetThuc',
           ISNULL(CONVERT(NVARCHAR,d.NgayKetThuc,23), 'NULL'),
           ISNULL(CONVERT(NVARCHAR,i.NgayKetThuc,23), 'NULL')
    FROM DELETED d JOIN INSERTED i ON d.MaHD = i.MaHD
    WHERE ISNULL(CAST(d.NgayKetThuc AS NVARCHAR),'')
       <> ISNULL(CAST(i.NgayKetThuc AS NVARCHAR),'');

    -- ── Cột: LuongCoBan ───────────────────────────────────────
    INSERT @Changes
    SELECT d.MaHD, d.MaNV, 'LuongCoBan',
           FORMAT(d.LuongCoBan,'N0'),
           FORMAT(i.LuongCoBan,'N0')
    FROM DELETED d JOIN INSERTED i ON d.MaHD = i.MaHD
    WHERE d.LuongCoBan <> i.LuongCoBan;

    -- ── Cột: VungLuong ────────────────────────────────────────
    INSERT @Changes
    SELECT d.MaHD, d.MaNV, 'VungLuong',
           CAST(d.VungLuong AS NVARCHAR),
           CAST(i.VungLuong AS NVARCHAR)
    FROM DELETED d JOIN INSERTED i ON d.MaHD = i.MaHD
    WHERE d.VungLuong <> i.VungLuong;

    -- ── Cột: TrangThai ────────────────────────────────────────
    INSERT @Changes
    SELECT d.MaHD, d.MaNV, 'TrangThai',
           d.TrangThai, i.TrangThai
    FROM DELETED d JOIN INSERTED i ON d.MaHD = i.MaHD
    WHERE d.TrangThai <> i.TrangThai;

    -- ── Cột: NguoiKy_NLD ──────────────────────────────────────
    INSERT @Changes
    SELECT d.MaHD, d.MaNV, 'NguoiKy_NLD',
           d.NguoiKy_NLD, i.NguoiKy_NLD
    FROM DELETED d JOIN INSERTED i ON d.MaHD = i.MaHD
    WHERE ISNULL(d.NguoiKy_NLD,'') <> ISNULL(i.NguoiKy_NLD,'');

    -- Ghi vào AuditLog từ bảng tạm
    INSERT INTO dbo.AuditLog_HopDong
        (MaHD, MaNV, HanhDong, TenCot, GiaTriCu, GiaTriMoi)
    SELECT MaHD, MaNV, 'UPDATE', TenCot, GiaTriCu, GiaTriMoi
    FROM @Changes;

    -- Không có thay đổi thực sự → không ghi log
    -- (UPDATE không thay đổi giá trị nào cũng kích hoạt trigger)
END;
GO
PRINT N'[OK] trg_HopDong_AfterUpdate';
GO

-- ============================================================
-- TRIGGER 3: trg_HopDong_AfterDelete
-- Ghi log khi xoá hợp đồng
-- ============================================================
IF OBJECT_ID('dbo.trg_HopDong_AfterDelete','TR') IS NOT NULL
    DROP TRIGGER dbo.trg_HopDong_AfterDelete;
GO

CREATE TRIGGER dbo.trg_HopDong_AfterDelete
ON dbo.HopDong
AFTER DELETE
AS
BEGIN
    SET NOCOUNT ON;
    IF @@ROWCOUNT = 0 RETURN;

    INSERT INTO dbo.AuditLog_HopDong
        (MaHD, MaNV, HanhDong, TenCot, GiaTriCu, GiaTriMoi)
    SELECT
        d.MaHD, d.MaNV,
        'DELETE',
        N'[FULL_RECORD]',
        N'{'
        + N'"MaLoaiHD":"'   + CAST(d.MaLoaiHD AS NVARCHAR)    + N'",'
        + N'"NgayBatDau":"' + CONVERT(NVARCHAR,d.NgayBatDau,23)+ N'",'
        + N'"LuongCoBan":' + CAST(d.LuongCoBan AS NVARCHAR)   + N','
        + N'"TrangThai":"'  + d.TrangThai + N'"'
        + N'}',
        NULL
    FROM DELETED d;
END;
GO
PRINT N'[OK] trg_HopDong_AfterDelete';
GO

-- ============================================================
-- TRIGGER 4: trg_HopDong_GuardChot
-- INSTEAD OF: Ngăn sửa/xoá hợp đồng đã LOCK (TrangThai='L')
-- BR-14: Hợp đồng Locked không được phép sửa/xóa
-- ============================================================
IF OBJECT_ID('dbo.trg_HopDong_GuardChot','TR') IS NOT NULL
    DROP TRIGGER dbo.trg_HopDong_GuardChot;
GO

CREATE TRIGGER dbo.trg_HopDong_GuardChot
ON dbo.HopDong
AFTER UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    IF @@ROWCOUNT = 0 RETURN;

    -- Kiểm tra nếu có hợp đồng LOCKED bị tác động
    IF EXISTS (
        SELECT 1 FROM DELETED d
        WHERE d.TrangThai = 'L'   -- Locked
    )
    BEGIN
        -- Kiểm tra xem đây là DELETE hay UPDATE sang trạng thái khác
        IF NOT EXISTS (SELECT 1 FROM INSERTED)
        BEGIN
            -- Đây là DELETE → chặn
            RAISERROR(
                N'trg_HopDong_GuardChot: Không thể XÓA hợp đồng đã KHÓA (TrangThai=L).',
                16, 1
            );
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        -- Đây là UPDATE — chỉ cho phép unlock
        IF EXISTS (
            SELECT 1 FROM INSERTED i
            JOIN DELETED d ON i.MaHD = d.MaHD
            WHERE d.TrangThai = 'L'
              AND i.TrangThai <> 'L'   -- Đang cố mở khóa
              AND i.LuongCoBan <> d.LuongCoBan  -- Đồng thời sửa lương
        )
        BEGIN
            RAISERROR(
                N'trg_HopDong_GuardChot: Hợp đồng KHÓA — chỉ được phép thay đổi TrangThai, không sửa nội dung.',
                16, 1
            );
            ROLLBACK TRANSACTION;
            RETURN;
        END;
    END;
END;
GO
PRINT N'[OK] trg_HopDong_GuardChot';
GO

-- ============================================================
-- KIỂM THỬ TRIGGERS
-- ============================================================
PRINT N'';
PRINT N'════════════════════════════════════════════════════════';
PRINT N'  KIỂM THỬ trg_HopDong_*';
PRINT N'════════════════════════════════════════════════════════';

-- Test: UPDATE lương hợp đồng NV000002
UPDATE dbo.HopDong
SET LuongCoBan = 9000000
WHERE MaHD = 'HD000002' AND TrangThai = 'A';

-- Xem log được ghi tự động
SELECT TOP 5
    MaLog,
    MaHD, MaNV,
    HanhDong,
    TenCot,
    GiaTriCu,
    GiaTriMoi,
    FORMAT(NgayThayDoi,'dd/MM/yyyy HH:mm:ss') AS ThoiGian,
    NguoiThayDoi
FROM dbo.AuditLog_HopDong
ORDER BY MaLog DESC;
GO

-- Rollback test change
UPDATE dbo.HopDong
SET LuongCoBan = 8500000
WHERE MaHD = 'HD000002';
GO

PRINT N'[DONE] trg_LogHopDong.sql — 4 triggers hoàn tất';
GO
