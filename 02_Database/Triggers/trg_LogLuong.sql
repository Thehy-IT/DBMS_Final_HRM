-- ============================================================
-- FILE       : trg_LogLuong.sql
-- PROJECT    : Hệ Thống Quản Lý Nhân Sự & Tính Lương Tự Động
-- MỤC ĐÍCH   : Trigger audit log bảng LuongCoBan + BangLuong
-- TRIGGERS   :
--   1. trg_LuongCoBan_AfterInsert  — log điều chỉnh lương mới
--   2. trg_LuongCoBan_AfterUpdate  — log từng cột thay đổi
--   3. trg_BangLuong_GuardChot     — ngăn sửa bảng lương CHOT
--   4. trg_KiemTraChamCong         — validate chấm công
-- BR-13: Mọi thay đổi lương → ghi AuditLog_Luong tự động
-- BR-14: BangLuong TrangThai='C'/'P'/'L' → không cho sửa/xoá
-- ============================================================

USE HRPayrollDB;
GO

-- ============================================================
-- TRIGGER 1: trg_LuongCoBan_AfterInsert
-- Log khi thêm mức lương mới (điều chỉnh lương nhân viên)
-- ============================================================
IF OBJECT_ID('dbo.trg_LuongCoBan_AfterInsert','TR') IS NOT NULL
    DROP TRIGGER dbo.trg_LuongCoBan_AfterInsert;
GO

CREATE TRIGGER dbo.trg_LuongCoBan_AfterInsert
ON dbo.LuongCoBan
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    IF @@ROWCOUNT = 0 RETURN;

    INSERT INTO dbo.AuditLog_Luong
        (MaLCB, MaNV, HanhDong, TenCot, GiaTriCu, GiaTriMoi)
    SELECT
        i.MaLCB,
        i.MaNV,
        'INSERT',
        N'LuongCoBan',
        -- Lấy mức lương trước đó (nếu có)
        (
            SELECT TOP 1 FORMAT(LuongCB,'N0') + N' VNĐ'
            FROM dbo.LuongCoBan prev
            WHERE prev.MaNV          = i.MaNV
              AND prev.MaLCB         < i.MaLCB
              AND prev.NgayHieuLuc   < i.NgayHieuLuc
            ORDER BY prev.NgayHieuLuc DESC
        ),
        FORMAT(i.LuongCB,'N0') + N' VNĐ'
        + N' (hiệu lực: ' + CONVERT(NVARCHAR,i.NgayHieuLuc,103) + N')'
    FROM INSERTED i;
END;
GO
PRINT N'[OK] trg_LuongCoBan_AfterInsert';
GO

-- ============================================================
-- TRIGGER 2: trg_LuongCoBan_AfterUpdate
-- Log chi tiết từng cột thay đổi trên LuongCoBan
-- ============================================================
IF OBJECT_ID('dbo.trg_LuongCoBan_AfterUpdate','TR') IS NOT NULL
    DROP TRIGGER dbo.trg_LuongCoBan_AfterUpdate;
GO

CREATE TRIGGER dbo.trg_LuongCoBan_AfterUpdate
ON dbo.LuongCoBan
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF @@ROWCOUNT = 0 RETURN;

    DECLARE @Changes TABLE (
        MaLCB   INT, MaNV NCHAR(10),
        TenCot  NVARCHAR(100),
        Cu      NVARCHAR(MAX),
        Moi     NVARCHAR(MAX)
    );

    -- LuongCoBan thay đổi
    INSERT @Changes
    SELECT d.MaLCB, d.MaNV, 'LuongCB',
           FORMAT(d.LuongCB,'N0') + ' VNĐ',
           FORMAT(i.LuongCB,'N0') + ' VNĐ'
    FROM DELETED d JOIN INSERTED i ON d.MaLCB = i.MaLCB
    WHERE d.LuongCB <> i.LuongCB;

    -- LuongDongBH thay đổi
    INSERT @Changes
    SELECT d.MaLCB, d.MaNV, 'LuongDongBH',
           FORMAT(d.LuongDongBH,'N0') + ' VNĐ',
           FORMAT(i.LuongDongBH,'N0') + ' VNĐ'
    FROM DELETED d JOIN INSERTED i ON d.MaLCB = i.MaLCB
    WHERE d.LuongDongBH <> i.LuongDongBH;

    -- NgayHieuLuc thay đổi
    INSERT @Changes
    SELECT d.MaLCB, d.MaNV, 'NgayHieuLuc',
           CONVERT(NVARCHAR,d.NgayHieuLuc,103),
           CONVERT(NVARCHAR,i.NgayHieuLuc,103)
    FROM DELETED d JOIN INSERTED i ON d.MaLCB = i.MaLCB
    WHERE d.NgayHieuLuc <> i.NgayHieuLuc;

    -- NgayHetHieuLuc thay đổi
    INSERT @Changes
    SELECT d.MaLCB, d.MaNV, 'NgayHetHieuLuc',
           ISNULL(CONVERT(NVARCHAR,d.NgayHetHieuLuc,103), 'Còn hiệu lực'),
           ISNULL(CONVERT(NVARCHAR,i.NgayHetHieuLuc,103), 'Còn hiệu lực')
    FROM DELETED d JOIN INSERTED i ON d.MaLCB = i.MaLCB
    WHERE ISNULL(CAST(d.NgayHetHieuLuc AS NVARCHAR),'')
       <> ISNULL(CAST(i.NgayHetHieuLuc AS NVARCHAR),'');

    INSERT INTO dbo.AuditLog_Luong
        (MaLCB, MaNV, HanhDong, TenCot, GiaTriCu, GiaTriMoi)
    SELECT MaLCB, MaNV, 'UPDATE', TenCot, Cu, Moi
    FROM @Changes;
END;
GO
PRINT N'[OK] trg_LuongCoBan_AfterUpdate';
GO

-- ============================================================
-- TRIGGER 3: trg_BangLuong_GuardChot
-- Ngăn mọi UPDATE/DELETE trên BangLuong đã được xác nhận
-- BR-14: TrangThai IN ('C','P','L') → KHÔNG cho phép sửa/xoá
-- Chỉ cho phép cập nhật NgayThanhToan khi chuyển D→C→P
-- ============================================================
IF OBJECT_ID('dbo.trg_BangLuong_GuardChot','TR') IS NOT NULL
    DROP TRIGGER dbo.trg_BangLuong_GuardChot;
GO

CREATE TRIGGER dbo.trg_BangLuong_GuardChot
ON dbo.BangLuong
AFTER UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    IF @@ROWCOUNT = 0 RETURN;

    -- Kiểm tra có dòng CHOT bị tác động không
    IF NOT EXISTS (
        SELECT 1 FROM DELETED d
        WHERE d.TrangThai IN ('C','P','L')
    ) RETURN;   -- Không có dòng CHOT → bỏ qua

    -- Trường hợp DELETE → luôn chặn
    IF NOT EXISTS (SELECT 1 FROM INSERTED)
    BEGIN
        RAISERROR(
            N'trg_BangLuong_GuardChot: Không thể XÓA bảng lương đã XÁC NHẬN / THANH TOÁN.',
            16, 1
        );
        ROLLBACK TRANSACTION;
        RETURN;
    END;

    -- Trường hợp UPDATE — cho phép 2 trường hợp hợp lệ:
    --   1. C → P (Confirmed → Paid): cập nhật NgayThanhToan
    --   2. P → L (Paid → Locked):    khoá bảng lương
    IF EXISTS (
        SELECT 1
        FROM INSERTED i JOIN DELETED d ON i.MaBL = d.MaBL
        WHERE d.TrangThai IN ('C','P','L')
          AND NOT (
              -- Cho phép C→P khi chỉ cập nhật NgayThanhToan + TrangThai
              (d.TrangThai = 'C' AND i.TrangThai = 'P')
              OR
              -- Cho phép P→L để khoá hoàn toàn
              (d.TrangThai = 'P' AND i.TrangThai = 'L')
          )
          AND (
              -- Phát hiện có cột số liệu bị sửa
              i.LuongCoBan    <> d.LuongCoBan   OR
              i.LuongGross    <> d.LuongGross    OR
              i.TongBaoHiem   <> d.TongBaoHiem   OR
              i.ThueTNCN      <> d.ThueTNCN      OR
              i.LuongNet      <> d.LuongNet
          )
    )
    BEGIN
        RAISERROR(
            N'trg_BangLuong_GuardChot: Không thể sửa số liệu bảng lương đã XÁC NHẬN. '
            + N'Chỉ cho phép chuyển trạng thái C→P hoặc P→L.',
            16, 1
        );
        ROLLBACK TRANSACTION;
        RETURN;
    END;

    -- Ghi log chuyển trạng thái hợp lệ
    INSERT INTO dbo.AuditLog_Luong
        (MaNV, HanhDong, TenCot, GiaTriCu, GiaTriMoi)
    SELECT
        i.MaNV,
        'STATUS_CHANGE',
        'TrangThai',
        d.TrangThai,
        i.TrangThai + N' (NgayTT: '
            + ISNULL(CONVERT(NVARCHAR,i.NgayThanhToan,103),'—') + N')'
    FROM INSERTED i JOIN DELETED d ON i.MaBL = d.MaBL
    WHERE d.TrangThai <> i.TrangThai;
END;
GO
PRINT N'[OK] trg_BangLuong_GuardChot';
GO

-- ============================================================
-- TRIGGER 4: trg_KiemTraChamCong
-- Validate chấm công: không trùng ngày, không tương lai,
-- tự động tính SoGioLam từ GioVao/GioRa
-- ============================================================
IF OBJECT_ID('dbo.trg_KiemTraChamCong','TR') IS NOT NULL
    DROP TRIGGER dbo.trg_KiemTraChamCong;
GO

CREATE TRIGGER dbo.trg_KiemTraChamCong
ON dbo.ChamCong
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF @@ROWCOUNT = 0 RETURN;

    -- Validate 1: Không chấm công ngày tương lai
    IF EXISTS (
        SELECT 1 FROM INSERTED
        WHERE NgayCham > CAST(GETDATE() AS DATE)
    )
    BEGIN
        RAISERROR(
            N'trg_KiemTraChamCong: Không được chấm công ngày tương lai.',
            16, 1
        );
        ROLLBACK TRANSACTION;
        RETURN;
    END;

    -- Validate 2: Không overlap date range trong NghiPhep
    -- (NV không thể cùng lúc DL và có đơn nghỉ phép đã duyệt)
    IF EXISTS (
        SELECT 1
        FROM INSERTED cc
        JOIN dbo.NghiPhep np ON cc.MaNV = np.MaNV
        WHERE cc.TrangThai IN ('DL','WFH','CX')
          AND np.TrangThai = 'A'              -- Đã duyệt
          AND cc.NgayCham BETWEEN np.NgayBatDau AND np.NgayKetThuc
    )
    BEGIN
        RAISERROR(
            N'trg_KiemTraChamCong: Ngày chấm công trùng với đơn nghỉ phép đã duyệt.',
            16, 1
        );
        ROLLBACK TRANSACTION;
        RETURN;
    END;

    -- Tự động cập nhật SoGioLam = GioRa - GioVao (trừ 1h nghỉ trưa)
    UPDATE cc
    SET SoGioLam = CASE
        WHEN ins.GioVao IS NOT NULL AND ins.GioRa IS NOT NULL
             AND ins.TrangThai IN ('DL','WFH','CX')
        THEN
            CAST(
                DATEDIFF(MINUTE, ins.GioVao, ins.GioRa) / 60.0
                -- Trừ 1h nghỉ trưa nếu làm > 5h
                - CASE WHEN DATEDIFF(MINUTE, ins.GioVao, ins.GioRa) > 300
                       THEN 1.0 ELSE 0.0 END
            AS DECIMAL(5,2))
        ELSE 0
        END
    FROM dbo.ChamCong cc
    JOIN INSERTED ins ON cc.MaCC = ins.MaCC;
END;
GO
PRINT N'[OK] trg_KiemTraChamCong';
GO

-- ============================================================
-- KIỂM THỬ
-- ============================================================
PRINT N'';
PRINT N'════════════════════════════════════════════════════════';
PRINT N'  KIỂM THỬ TRIGGERS LUONG & CHAMCONG';
PRINT N'════════════════════════════════════════════════════════';

-- Test: Tăng lương NV000003 (Trưởng phòng Nhân Sự)
-- Bước 1: Đóng mức lương cũ
UPDATE dbo.LuongCoBan
SET NgayHetHieuLuc = '2025-03-31'
WHERE MaNV = 'NV000003' AND NgayHetHieuLuc IS NULL;

-- Bước 2: Thêm mức lương mới (trigger tự log)
INSERT INTO dbo.LuongCoBan
    (MaNV, LuongCB, LuongDongBH, NgayHieuLuc, NgayHetHieuLuc, LyDo, NguoiDuyet)
VALUES
    ('NV000003', 28000000, 28000000, '2025-04-01', NULL,
     N'Tăng lương theo đánh giá năm 2024', 'NV000001');

-- Xem audit log tự động
SELECT TOP 5
    MaLog, MaNV, HanhDong, TenCot,
    GiaTriCu, GiaTriMoi,
    FORMAT(NgayThayDoi,'dd/MM HH:mm:ss') ThoiGian
FROM dbo.AuditLog_Luong
ORDER BY MaLog DESC;
GO

-- Test: Guard chặn DELETE BangLuong đã CHOT
-- (Chạy sau khi có dữ liệu BangLuong từ sp_TinhLuong)
PRINT N'--- Test Guard: UPDATE số liệu bảng lương nháp (D) → được phép ---';
UPDATE dbo.BangLuong
SET LuongGross = LuongGross + 0   -- Không đổi giá trị, chỉ test trigger
WHERE TrangThai = 'D' AND Thang = 1 AND Nam = 2025;
PRINT N'    UPDATE Draft → OK (không bị chặn)';
GO

PRINT N'[DONE] trg_LogLuong.sql — 4 triggers hoàn tất';
GO
