-- ============================================================
-- FILE       : sp_BaoCaoNhanSu.sql
-- PROJECT    : Hệ Thống Quản Lý Nhân Sự & Tính Lương Tự Động
-- DBMS       : Microsoft SQL Server 2019+
-- MỤC ĐÍCH   : Bộ báo cáo nhân sự toàn diện phục vụ Ban Lãnh Đạo,
--              HR Manager và Kế Toán Trưởng
-- ─────────────────────────────────────────────────────────────
-- PROCEDURES :
--   1. sp_BaoCaoNhanSu_TongQuan        — Dashboard nhân sự tổng hợp
--   2. sp_BaoCaoNhanSu_TheoPhongBan    — Phân tích cơ cấu theo PB/CV
--   3. sp_BaoCaoNhanSu_HopDong         — Trạng thái & sắp hết hạn HĐ
--   4. sp_BaoCaoNhanSu_BienDong        — Tuyển mới / nghỉ việc theo kỳ
--   5. sp_BaoCaoNhanSu_LuongPhanPhoi   — Phân phối lương & xếp hạng
--   6. sp_BaoCaoNhanSu_NghiPhepNam     — Quản lý phép năm tồn dư
-- ─────────────────────────────────────────────────────────────
-- THỨ TỰ CHẠY: Sau seed_data.sql + sp_TinhLuong.sql
-- ============================================================

USE HRPayrollDB;
GO

-- ============================================================
-- SP 1: sp_BaoCaoNhanSu_TongQuan
-- ─────────────────────────────────────────────────────────────
-- Dashboard nhân sự tổng hợp: cơ cấu lao động, phân bổ
-- theo giới tính, độ tuổi, thâm niên, trạng thái.
-- 5 Result Sets — dùng cho màn hình Dashboard chính.
-- ============================================================
IF OBJECT_ID('dbo.sp_BaoCaoNhanSu_TongQuan','P') IS NOT NULL
    DROP PROCEDURE dbo.sp_BaoCaoNhanSu_TongQuan;
GO

CREATE PROCEDURE dbo.sp_BaoCaoNhanSu_TongQuan
    @ThoiDiem DATE = NULL   -- NULL = ngày hiện tại
AS
BEGIN
    SET NOCOUNT ON;
    IF @ThoiDiem IS NULL SET @ThoiDiem = CAST(GETDATE() AS DATE);

    PRINT N'════════════════════════════════════════════════════════';
    PRINT N'  DASHBOARD NHÂN SỰ TỔNG QUAN';
    PRINT N'  Thời điểm: ' + CONVERT(NVARCHAR,@ThoiDiem,103);
    PRINT N'════════════════════════════════════════════════════════';

    -- ── RS1: Số liệu tổng quan ────────────────────────────────
    SELECT
        COUNT(*)                            AS [Tổng Nhân Viên],
        SUM(CASE WHEN TrangThai='A' THEN 1 ELSE 0 END)
                                            AS [Đang Làm Việc],
        SUM(CASE WHEN TrangThai='P' THEN 1 ELSE 0 END)
                                            AS [Thử Việc],
        SUM(CASE WHEN TrangThai='L' THEN 1 ELSE 0 END)
                                            AS [Nghỉ Thai Sản],
        SUM(CASE WHEN TrangThai='T' THEN 1 ELSE 0 END)
                                            AS [Đã Nghỉ Việc],
        SUM(CASE WHEN GioiTinh='M'
                  AND TrangThai IN ('A','P','L') THEN 1 ELSE 0 END)
                                            AS [Nam],
        SUM(CASE WHEN GioiTinh='F'
                  AND TrangThai IN ('A','P','L') THEN 1 ELSE 0 END)
                                            AS [Nữ],
        -- Độ tuổi trung bình
        FORMAT(AVG(CAST(
            DATEDIFF(YEAR, NgaySinh, @ThoiDiem) AS DECIMAL(5,1))),'N1')
                                            AS [Tuổi TB],
        -- Thâm niên trung bình (năm)
        FORMAT(AVG(CAST(
            DATEDIFF(MONTH, NgayVaoLam, @ThoiDiem) AS DECIMAL(6,1))
            /12.0),'N1') + N' năm'          AS [Thâm Niên TB],
        -- Số NV vào làm trong 30 ngày gần nhất
        SUM(CASE WHEN NgayVaoLam
                    >= DATEADD(DAY,-30,@ThoiDiem) THEN 1 ELSE 0 END)
                                            AS [Mới Vào 30 Ngày],
        -- Số NV nghỉ việc trong 30 ngày gần nhất
        SUM(CASE WHEN NgayNghiViec
                    >= DATEADD(DAY,-30,@ThoiDiem) THEN 1 ELSE 0 END)
                                            AS [Nghỉ Việc 30 Ngày]
    FROM dbo.NhanVien;

    -- ── RS2: Cơ cấu theo nhóm tuổi ───────────────────────────
    SELECT
        CASE
            WHEN DATEDIFF(YEAR,NgaySinh,@ThoiDiem) < 25 THEN N'< 25 tuổi'
            WHEN DATEDIFF(YEAR,NgaySinh,@ThoiDiem) < 30 THEN N'25–29 tuổi'
            WHEN DATEDIFF(YEAR,NgaySinh,@ThoiDiem) < 35 THEN N'30–34 tuổi'
            WHEN DATEDIFF(YEAR,NgaySinh,@ThoiDiem) < 40 THEN N'35–39 tuổi'
            WHEN DATEDIFF(YEAR,NgaySinh,@ThoiDiem) < 50 THEN N'40–49 tuổi'
            ELSE N'≥ 50 tuổi'
        END                                 AS [Nhóm Tuổi],
        COUNT(*)                            AS [Số Lượng],
        FORMAT(COUNT(*)*100.0
            /NULLIF((SELECT COUNT(*) FROM dbo.NhanVien
                     WHERE TrangThai IN ('A','P','L')),0),'N1') + N'%'
                                            AS [Tỷ Lệ]
    FROM dbo.NhanVien
    WHERE TrangThai IN ('A','P','L')
    GROUP BY
        CASE
            WHEN DATEDIFF(YEAR,NgaySinh,@ThoiDiem) < 25 THEN N'< 25 tuổi'
            WHEN DATEDIFF(YEAR,NgaySinh,@ThoiDiem) < 30 THEN N'25–29 tuổi'
            WHEN DATEDIFF(YEAR,NgaySinh,@ThoiDiem) < 35 THEN N'30–34 tuổi'
            WHEN DATEDIFF(YEAR,NgaySinh,@ThoiDiem) < 40 THEN N'35–39 tuổi'
            WHEN DATEDIFF(YEAR,NgaySinh,@ThoiDiem) < 50 THEN N'40–49 tuổi'
            ELSE N'≥ 50 tuổi'
        END
    ORDER BY MIN(DATEDIFF(YEAR,NgaySinh,@ThoiDiem));

    -- ── RS3: Cơ cấu theo nhóm thâm niên ─────────────────────
    SELECT
        CASE
            WHEN DATEDIFF(MONTH,NgayVaoLam,@ThoiDiem) <  12
                THEN N'< 1 năm'
            WHEN DATEDIFF(MONTH,NgayVaoLam,@ThoiDiem) <  36
                THEN N'1–2 năm'
            WHEN DATEDIFF(MONTH,NgayVaoLam,@ThoiDiem) <  60
                THEN N'3–4 năm'
            WHEN DATEDIFF(MONTH,NgayVaoLam,@ThoiDiem) < 120
                THEN N'5–9 năm'
            ELSE N'≥ 10 năm'
        END                                 AS [Nhóm Thâm Niên],
        COUNT(*)                            AS [Số NV],
        SUM(CASE WHEN GioiTinh='M' THEN 1 ELSE 0 END) AS [Nam],
        SUM(CASE WHEN GioiTinh='F' THEN 1 ELSE 0 END) AS [Nữ],
        FORMAT(COUNT(*)*100.0
            /NULLIF((SELECT COUNT(*) FROM dbo.NhanVien
                     WHERE TrangThai IN ('A','P','L')),0),'N1') + N'%'
                                            AS [Tỷ Lệ]
    FROM dbo.NhanVien
    WHERE TrangThai IN ('A','P','L')
    GROUP BY
        CASE
            WHEN DATEDIFF(MONTH,NgayVaoLam,@ThoiDiem) <  12 THEN N'< 1 năm'
            WHEN DATEDIFF(MONTH,NgayVaoLam,@ThoiDiem) <  36 THEN N'1–2 năm'
            WHEN DATEDIFF(MONTH,NgayVaoLam,@ThoiDiem) <  60 THEN N'3–4 năm'
            WHEN DATEDIFF(MONTH,NgayVaoLam,@ThoiDiem) < 120 THEN N'5–9 năm'
            ELSE N'≥ 10 năm'
        END
    ORDER BY MIN(DATEDIFF(MONTH,NgayVaoLam,@ThoiDiem));

    -- ── RS4: Phân bổ theo phòng ban ──────────────────────────
    SELECT
        pb.TenPB                            AS [Phòng Ban],
        COUNT(nv.MaNV)                      AS [Tổng NV],
        SUM(CASE WHEN nv.GioiTinh='M' THEN 1 ELSE 0 END) AS [Nam],
        SUM(CASE WHEN nv.GioiTinh='F' THEN 1 ELSE 0 END) AS [Nữ],
        SUM(CASE WHEN nv.TrangThai='P' THEN 1 ELSE 0 END) AS [Thử Việc],
        FORMAT(AVG(CAST(
            DATEDIFF(YEAR,nv.NgaySinh,@ThoiDiem)
        AS DECIMAL(5,1))),'N1')             AS [Tuổi TB],
        FORMAT(AVG(CAST(
            DATEDIFF(MONTH,nv.NgayVaoLam,@ThoiDiem)
        AS DECIMAL) / 12.0),'N1') + N' năm' AS [Thâm Niên TB],
        nv2.HoTen                           AS [Trưởng Phòng]
    FROM dbo.NhanVien      nv
    JOIN dbo.PhongBan      pb  ON nv.MaPB = pb.MaPB
    LEFT JOIN dbo.NhanVien nv2 ON pb.MaTruongPhong = nv2.MaNV
    WHERE nv.TrangThai IN ('A','P','L')
    GROUP BY pb.TenPB, nv2.HoTen
    ORDER BY COUNT(nv.MaNV) DESC;

    -- ── RS5: Chỉ số KEY HR ────────────────────────────────────
    DECLARE
        @TongNV     INT,
        @NghiT30    INT,
        @VaoT30     INT;

    SELECT @TongNV  = COUNT(*) FROM dbo.NhanVien WHERE TrangThai IN('A','P','L');
    SELECT @NghiT30 = COUNT(*) FROM dbo.NhanVien
        WHERE TrangThai='T'
          AND NgayNghiViec >= DATEADD(DAY,-30,@ThoiDiem);
    SELECT @VaoT30  = COUNT(*) FROM dbo.NhanVien
        WHERE NgayVaoLam >= DATEADD(DAY,-30,@ThoiDiem);

    SELECT
        FORMAT(@TongNV,'N0')                AS [Tổng Nhân Lực],
        -- Tỷ lệ nghỉ việc (Turnover Rate) 30 ngày
        FORMAT(@NghiT30 * 100.0
            / NULLIF(@TongNV,0),'N2') + N'%'
                                            AS [Turnover Rate 30D],
        -- Tỷ lệ tuyển dụng thành công
        FORMAT(@VaoT30 * 100.0
            / NULLIF(@TongNV,0),'N2') + N'%'
                                            AS [Hiring Rate 30D],
        -- HĐ sắp hết hạn 60 ngày tới
        (SELECT COUNT(*) FROM dbo.HopDong
         WHERE TrangThai = 'A'
           AND NgayKetThuc BETWEEN @ThoiDiem
               AND DATEADD(DAY,60,@ThoiDiem))
                                            AS [HĐ Hết Hạn 60D],
        -- NV chưa có HĐ active
        (SELECT COUNT(*) FROM dbo.NhanVien nv
         WHERE TrangThai IN ('A','P','L')
           AND NOT EXISTS (
               SELECT 1 FROM dbo.HopDong hd
               WHERE hd.MaNV = nv.MaNV AND hd.TrangThai='A'))
                                            AS [NV Chưa Có HĐ Active],
        -- Tỷ lệ nam/nữ
        FORMAT(
            SUM(CASE WHEN GioiTinh='M' THEN 1.0 ELSE 0 END)
            / NULLIF(SUM(CASE WHEN GioiTinh='F' THEN 1.0 ELSE 0 END),0)
        ,'N2') + N' : 1'                    AS [Tỷ Lệ Nam/Nữ]
    FROM dbo.NhanVien WHERE TrangThai IN ('A','P','L');
END;
GO
PRINT N'[OK] sp_BaoCaoNhanSu_TongQuan';
GO


-- ============================================================
-- SP 2: sp_BaoCaoNhanSu_TheoPhongBan
-- ─────────────────────────────────────────────────────────────
-- Phân tích chi tiết cơ cấu nhân sự từng phòng ban:
-- danh sách đầy đủ, phân bổ chức vụ, lương bình quân,
-- ma trận phòng ban × chức vụ (PIVOT).
-- ============================================================
IF OBJECT_ID('dbo.sp_BaoCaoNhanSu_TheoPhongBan','P') IS NOT NULL
    DROP PROCEDURE dbo.sp_BaoCaoNhanSu_TheoPhongBan;
GO

CREATE PROCEDURE dbo.sp_BaoCaoNhanSu_TheoPhongBan
    @MaPB   NCHAR(10) = NULL,   -- NULL = tất cả
    @Thang  TINYINT   = NULL,   -- Kỳ lương để lấy lương bình quân
    @Nam    SMALLINT  = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @Thang IS NULL SET @Thang = MONTH(GETDATE());
    IF @Nam   IS NULL SET @Nam   = YEAR(GETDATE());

    -- ── RS1: Danh sách nhân viên đầy đủ theo phòng ban ───────
    SELECT
        pb.TenPB                            AS [Phòng Ban],
        cv.TenCV                            AS [Chức Vụ],
        nv.MaNV                             AS [Mã NV],
        nv.HoTen                            AS [Họ Tên],
        CASE nv.GioiTinh WHEN 'M' THEN N'Nam' ELSE N'Nữ' END
                                            AS [Giới Tính],
        FORMAT(nv.NgaySinh,'dd/MM/yyyy')    AS [Ngày Sinh],
        DATEDIFF(YEAR,nv.NgaySinh,GETDATE())AS [Tuổi],
        FORMAT(nv.NgayVaoLam,'dd/MM/yyyy')  AS [Ngày Vào Làm],
        CAST(DATEDIFF(MONTH,nv.NgayVaoLam,GETDATE())/12 AS NVARCHAR)
            + N' năm ' +
            CAST(DATEDIFF(MONTH,nv.NgayVaoLam,GETDATE())%12 AS NVARCHAR)
            + N' tháng'                     AS [Thâm Niên],
        lhd.TenLoaiHD                       AS [Loại HĐ],
        FORMAT(hd.NgayKetThuc,'dd/MM/yyyy') AS [Hết Hạn HĐ],
        CASE
            WHEN hd.NgayKetThuc IS NULL THEN N'Vô thời hạn'
            WHEN hd.NgayKetThuc < GETDATE() THEN N'⚠️ Đã hết hạn'
            WHEN DATEDIFF(DAY,GETDATE(),hd.NgayKetThuc) <= 30
                THEN N'🔴 Hết hạn ≤ 30 ngày'
            WHEN DATEDIFF(DAY,GETDATE(),hd.NgayKetThuc) <= 90
                THEN N'🟡 Hết hạn ≤ 90 ngày'
            ELSE N'✅ Còn hiệu lực'
        END                                 AS [Tình Trạng HĐ],
        FORMAT(lcb.LuongCB,'N0')            AS [Lương CB (VNĐ)],
        CASE nv.TrangThai
            WHEN 'A' THEN N'Đang làm'
            WHEN 'P' THEN N'Thử việc'
            WHEN 'L' THEN N'Thai sản'
            ELSE nv.TrangThai
        END                                 AS [Trạng Thái]
    FROM dbo.NhanVien       nv
    JOIN dbo.PhongBan       pb  ON nv.MaPB = pb.MaPB
    JOIN dbo.ChucVu         cv  ON nv.MaCV = cv.MaCV
    LEFT JOIN dbo.HopDong   hd  ON nv.MaNV = hd.MaNV
                                AND hd.TrangThai = 'A'
    LEFT JOIN dbo.LoaiHopDong lhd ON hd.MaLoaiHD = lhd.MaLoaiHD
    LEFT JOIN dbo.LuongCoBan lcb ON nv.MaNV = lcb.MaNV
                                 AND lcb.NgayHetHieuLuc IS NULL
    WHERE nv.TrangThai IN ('A','P','L')
      AND (@MaPB IS NULL OR nv.MaPB = @MaPB)
    ORDER BY pb.TenPB, cv.CapBac DESC, nv.HoTen;

    -- ── RS2: Thống kê theo phòng ban × chức vụ ───────────────
    SELECT
        pb.TenPB                            AS [Phòng Ban],
        COUNT(nv.MaNV)                      AS [Tổng NV],
        SUM(CASE WHEN cv.TenCV LIKE N'%Giám Đốc%'
                   OR cv.TenCV LIKE N'%Trưởng%'
                   OR cv.TenCV LIKE N'%Phó%'
                 THEN 1 ELSE 0 END)         AS [Quản Lý],
        SUM(CASE WHEN cv.TenCV LIKE N'%Cao Cấp%'
                   OR cv.TenCV LIKE N'%Chuyên Viên%'
                 THEN 1 ELSE 0 END)         AS [Chuyên Viên],
        SUM(CASE WHEN cv.TenCV LIKE N'%Nhân Viên%'
                 THEN 1 ELSE 0 END)         AS [Nhân Viên],
        SUM(CASE WHEN nv.TrangThai='P'
                 THEN 1 ELSE 0 END)         AS [Thử Việc],
        FORMAT(AVG(lcb.LuongCB),'N0')       AS [Lương TB],
        FORMAT(MIN(lcb.LuongCB),'N0')       AS [Lương Thấp Nhất],
        FORMAT(MAX(lcb.LuongCB),'N0')       AS [Lương Cao Nhất],
        -- Ngân sách lương theo phòng ban (từ BangLuong nếu có)
        ISNULL(FORMAT((
            SELECT SUM(bl.LuongNet)
            FROM dbo.BangLuong bl
            JOIN dbo.NhanVien nv2 ON bl.MaNV=nv2.MaNV
            WHERE nv2.MaPB=pb.MaPB
              AND bl.Thang=@Thang AND bl.Nam=@Nam
        ),'N0'), N'—')                      AS [Quỹ Lương Net Kỳ Gần]
    FROM dbo.NhanVien       nv
    JOIN dbo.PhongBan       pb  ON nv.MaPB = pb.MaPB
    JOIN dbo.ChucVu         cv  ON nv.MaCV = cv.MaCV
    LEFT JOIN dbo.LuongCoBan lcb ON nv.MaNV=lcb.MaNV
                                 AND lcb.NgayHetHieuLuc IS NULL
    WHERE nv.TrangThai IN ('A','P','L')
      AND (@MaPB IS NULL OR nv.MaPB = @MaPB)
    GROUP BY pb.TenPB, pb.MaPB
    ORDER BY COUNT(nv.MaNV) DESC;

    -- ── RS3: Ma trận PIVOT Phòng Ban × Chức Vụ ───────────────
    SELECT
        pb.TenPB                            AS [Phòng Ban],
        SUM(CASE WHEN cv.TenCV LIKE N'%Giám Đốc%'   THEN 1 ELSE 0 END)  AS [TGĐ],
        SUM(CASE WHEN cv.TenCV LIKE N'%Trưởng Phòng%' THEN 1 ELSE 0 END) AS [Trưởng PB],
        SUM(CASE WHEN cv.TenCV LIKE N'%Phó Phòng%'  THEN 1 ELSE 0 END)  AS [Phó PB],
        SUM(CASE WHEN cv.TenCV LIKE N'%Cao Cấp%'    THEN 1 ELSE 0 END)  AS [CVCC],
        SUM(CASE WHEN cv.TenCV = N'Chuyên Viên'     THEN 1 ELSE 0 END)  AS [CV],
        SUM(CASE WHEN cv.TenCV = N'Nhân Viên'       THEN 1 ELSE 0 END)  AS [NV],
        SUM(CASE WHEN cv.TenCV LIKE N'%Thử Việc%'   THEN 1 ELSE 0 END)  AS [Thử Việc],
        COUNT(nv.MaNV)                      AS [Tổng Cộng]
    FROM dbo.NhanVien  nv
    JOIN dbo.PhongBan  pb ON nv.MaPB = pb.MaPB
    JOIN dbo.ChucVu    cv ON nv.MaCV = cv.MaCV
    WHERE nv.TrangThai IN ('A','P','L')
      AND (@MaPB IS NULL OR nv.MaPB = @MaPB)
    GROUP BY pb.TenPB
    ORDER BY pb.TenPB;
END;
GO
PRINT N'[OK] sp_BaoCaoNhanSu_TheoPhongBan';
GO


-- ============================================================
-- SP 3: sp_BaoCaoNhanSu_HopDong
-- ─────────────────────────────────────────────────────────────
-- Quản lý trạng thái hợp đồng lao động:
--   • Danh sách HĐ sắp hết hạn (cảnh báo gia hạn)
--   • Phân tích loại HĐ theo phòng ban
--   • Lịch sử điều chỉnh lương NV
-- ============================================================
IF OBJECT_ID('dbo.sp_BaoCaoNhanSu_HopDong','P') IS NOT NULL
    DROP PROCEDURE dbo.sp_BaoCaoNhanSu_HopDong;
GO

CREATE PROCEDURE dbo.sp_BaoCaoNhanSu_HopDong
    @NgayXet    DATE        = NULL,
    @SoNgayCB   INT         = 60,    -- Cảnh báo trước N ngày
    @MaPB       NCHAR(10)   = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF @NgayXet IS NULL SET @NgayXet = CAST(GETDATE() AS DATE);

    PRINT N'════════════════════════════════════════════════════════';
    PRINT N'  BÁO CÁO HỢP ĐỒNG LAO ĐỘNG';
    PRINT N'  Ngày xét: ' + CONVERT(NVARCHAR,@NgayXet,103)
        + N'  |  Cảnh báo: ' + CAST(@SoNgayCB AS NVARCHAR) + N' ngày';
    PRINT N'════════════════════════════════════════════════════════';

    -- ── RS1: HĐ sắp hết hạn — cần gia hạn ───────────────────
    SELECT
        CASE
            WHEN DATEDIFF(DAY,@NgayXet,hd.NgayKetThuc) < 0
                THEN N'🚨 Đã hết hạn'
            WHEN DATEDIFF(DAY,@NgayXet,hd.NgayKetThuc) <= 15
                THEN N'🔴 Khẩn cấp ≤ 15 ngày'
            WHEN DATEDIFF(DAY,@NgayXet,hd.NgayKetThuc) <= 30
                THEN N'🟠 Gấp ≤ 30 ngày'
            ELSE N'🟡 Sắp hết ' + CAST(
                DATEDIFF(DAY,@NgayXet,hd.NgayKetThuc) AS NVARCHAR)
                + N' ngày'
        END                                 AS [Mức Độ Ưu Tiên],
        nv.MaNV                             AS [Mã NV],
        nv.HoTen                            AS [Họ Tên],
        pb.TenPB                            AS [Phòng Ban],
        cv.TenCV                            AS [Chức Vụ],
        lhd.TenLoaiHD                       AS [Loại HĐ Hiện Tại],
        FORMAT(hd.NgayBatDau,'dd/MM/yyyy')  AS [Ngày Bắt Đầu HĐ],
        FORMAT(hd.NgayKetThuc,'dd/MM/yyyy') AS [Ngày Hết Hạn],
        DATEDIFF(DAY,@NgayXet,hd.NgayKetThuc)
                                            AS [Còn Lại (Ngày)],
        FORMAT(hd.LuongCoBan,'N0')          AS [Lương HĐ (VNĐ)],
        -- Đề xuất loại HĐ tiếp theo
        CASE lhd.MaLoaiHD
            WHEN 1 THEN N'→ Ký HĐ Xác định 1 năm'
            WHEN 2 THEN N'→ Ký HĐ Xác định 2 năm'
            WHEN 3 THEN N'→ Ký HĐ Không xác định thời hạn'
            WHEN 4 THEN N'HĐ vô thời hạn — không cần gia hạn'
        END                                 AS [Đề Xuất Tiếp Theo],
        -- Đánh giá cuối (nếu có)
        CAST(DATEDIFF(MONTH,nv.NgayVaoLam,@NgayXet) AS NVARCHAR)
            + N' tháng'                     AS [Tổng Thâm Niên]
    FROM dbo.HopDong        hd
    JOIN dbo.NhanVien       nv  ON hd.MaNV = nv.MaNV
    JOIN dbo.PhongBan       pb  ON nv.MaPB = pb.MaPB
    JOIN dbo.ChucVu         cv  ON nv.MaCV = cv.MaCV
    JOIN dbo.LoaiHopDong    lhd ON hd.MaLoaiHD = lhd.MaLoaiHD
    WHERE hd.TrangThai = 'A'
      AND hd.NgayKetThuc IS NOT NULL
      AND hd.NgayKetThuc <= DATEADD(DAY,@SoNgayCB,@NgayXet)
      AND nv.TrangThai IN ('A','P')
      AND (@MaPB IS NULL OR nv.MaPB = @MaPB)
    ORDER BY hd.NgayKetThuc ASC;

    -- ── RS2: Phân loại HĐ theo phòng ban (PIVOT đơn giản) ────
    SELECT
        pb.TenPB                            AS [Phòng Ban],
        COUNT(hd.MaHD)                      AS [Tổng HĐ Active],
        SUM(CASE WHEN lhd.MaLoaiHD=1 THEN 1 ELSE 0 END) AS [Thử Việc],
        SUM(CASE WHEN lhd.MaLoaiHD=2 THEN 1 ELSE 0 END) AS [XĐ 1 Năm],
        SUM(CASE WHEN lhd.MaLoaiHD=3 THEN 1 ELSE 0 END) AS [XĐ 2 Năm],
        SUM(CASE WHEN lhd.MaLoaiHD=4 THEN 1 ELSE 0 END) AS [Vô Thời Hạn],
        SUM(CASE WHEN hd.NgayKetThuc IS NOT NULL
                  AND hd.NgayKetThuc <= DATEADD(DAY,90,@NgayXet)
                 THEN 1 ELSE 0 END)         AS [Hết Hạn Trong 90D]
    FROM dbo.HopDong        hd
    JOIN dbo.NhanVien       nv  ON hd.MaNV  = nv.MaNV
    JOIN dbo.PhongBan       pb  ON nv.MaPB  = pb.MaPB
    JOIN dbo.LoaiHopDong    lhd ON hd.MaLoaiHD = lhd.MaLoaiHD
    WHERE hd.TrangThai = 'A'
      AND nv.TrangThai IN ('A','P','L')
      AND (@MaPB IS NULL OR nv.MaPB = @MaPB)
    GROUP BY pb.TenPB
    ORDER BY pb.TenPB;

    -- ── RS3: Lịch sử điều chỉnh lương từ AuditLog ────────────
    SELECT TOP 20
        al.MaNV,
        nv.HoTen,
        pb.TenPB                            AS [Phòng Ban],
        al.TenCot                           AS [Cột Thay Đổi],
        al.GiaTriCu                         AS [Giá Trị Cũ],
        al.GiaTriMoi                        AS [Giá Trị Mới],
        FORMAT(al.NgayThayDoi,'dd/MM/yyyy HH:mm') AS [Thời Gian],
        al.NguoiThayDoi                     AS [Người Thực Hiện]
    FROM dbo.AuditLog_Luong     al
    JOIN dbo.NhanVien           nv  ON al.MaNV = nv.MaNV
    JOIN dbo.PhongBan           pb  ON nv.MaPB = pb.MaPB
    WHERE al.HanhDong IN ('INSERT','UPDATE')
      AND al.TenCot = 'LuongCB'
      AND (@MaPB IS NULL OR nv.MaPB = @MaPB)
    ORDER BY al.NgayThayDoi DESC;
END;
GO
PRINT N'[OK] sp_BaoCaoNhanSu_HopDong';
GO


-- ============================================================
-- SP 4: sp_BaoCaoNhanSu_BienDong
-- ─────────────────────────────────────────────────────────────
-- Báo cáo biến động nhân sự: tuyển mới, nghỉ việc,
-- chuyển phòng ban, thăng chức trong kỳ chỉ định.
-- ============================================================
IF OBJECT_ID('dbo.sp_BaoCaoNhanSu_BienDong','P') IS NOT NULL
    DROP PROCEDURE dbo.sp_BaoCaoNhanSu_BienDong;
GO

CREATE PROCEDURE dbo.sp_BaoCaoNhanSu_BienDong
    @TuNgay     DATE,
    @DenNgay    DATE,
    @MaPB       NCHAR(10) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    PRINT N'════════════════════════════════════════════════════════';
    PRINT N'  BÁO CÁO BIẾN ĐỘNG NHÂN SỰ';
    PRINT N'  Kỳ: ' + CONVERT(NVARCHAR,@TuNgay,103)
        + N' → ' + CONVERT(NVARCHAR,@DenNgay,103);
    PRINT N'════════════════════════════════════════════════════════';

    -- ── RS1: Nhân viên mới tuyển trong kỳ ────────────────────
    SELECT
        N'✅ TUYỂN MỚI'                     AS [Loại Biến Động],
        nv.MaNV, nv.HoTen,
        pb.TenPB                            AS [Phòng Ban],
        cv.TenCV                            AS [Chức Vụ],
        FORMAT(nv.NgayVaoLam,'dd/MM/yyyy')  AS [Ngày Vào Làm],
        lhd.TenLoaiHD                       AS [Loại HĐ],
        FORMAT(hd.LuongCoBan,'N0')          AS [Lương Khởi Điểm],
        CASE nv.TrangThai
            WHEN 'P' THEN N'Đang thử việc'
            WHEN 'A' THEN N'Đã chính thức'
            ELSE nv.TrangThai
        END                                 AS [Tình Trạng Hiện Tại]
    FROM dbo.NhanVien       nv
    JOIN dbo.PhongBan       pb  ON nv.MaPB = pb.MaPB
    JOIN dbo.ChucVu         cv  ON nv.MaCV = cv.MaCV
    LEFT JOIN dbo.HopDong   hd  ON nv.MaNV = hd.MaNV
                                AND hd.TrangThai IN ('A','E')
    LEFT JOIN dbo.LoaiHopDong lhd ON hd.MaLoaiHD = lhd.MaLoaiHD
    WHERE nv.NgayVaoLam BETWEEN @TuNgay AND @DenNgay
      AND (@MaPB IS NULL OR nv.MaPB = @MaPB)
    ORDER BY nv.NgayVaoLam, pb.TenPB;

    -- ── RS2: Nhân viên nghỉ việc trong kỳ ────────────────────
    SELECT
        N'❌ NGHỈ VIỆC'                     AS [Loại Biến Động],
        nv.MaNV, nv.HoTen,
        pb.TenPB                            AS [Phòng Ban],
        cv.TenCV                            AS [Chức Vụ],
        FORMAT(nv.NgayVaoLam,'dd/MM/yyyy')  AS [Ngày Vào Làm],
        FORMAT(nv.NgayNghiViec,'dd/MM/yyyy')AS [Ngày Nghỉ Việc],
        CAST(DATEDIFF(MONTH,nv.NgayVaoLam,
            nv.NgayNghiViec)/12 AS NVARCHAR)
            + N'n ' + CAST(DATEDIFF(MONTH,nv.NgayVaoLam,
            nv.NgayNghiViec)%12 AS NVARCHAR) + N't'
                                            AS [Thâm Niên],
        -- Lý do nghỉ từ audit log
        ISNULL((
            SELECT TOP 1 GiaTriMoi
            FROM dbo.AuditLog_HopDong
            WHERE MaNV = nv.MaNV
              AND HanhDong = 'UPDATE'
              AND TenCot = 'TrangThai'
              AND GiaTriMoi LIKE N'%T%'
            ORDER BY NgayThayDoi DESC
        ), N'—')                            AS [Ghi Chú Từ Log]
    FROM dbo.NhanVien       nv
    JOIN dbo.PhongBan       pb  ON nv.MaPB = pb.MaPB
    JOIN dbo.ChucVu         cv  ON nv.MaCV = cv.MaCV
    WHERE nv.TrangThai = 'T'
      AND nv.NgayNghiViec BETWEEN @TuNgay AND @DenNgay
      AND (@MaPB IS NULL OR nv.MaPB = @MaPB)
    ORDER BY nv.NgayNghiViec DESC;

    -- ── RS3: Tóm tắt biến động ────────────────────────────────
    SELECT
        (SELECT COUNT(*) FROM dbo.NhanVien
         WHERE NgayVaoLam BETWEEN @TuNgay AND @DenNgay
           AND (@MaPB IS NULL OR MaPB=@MaPB))   AS [Tuyển Mới],
        (SELECT COUNT(*) FROM dbo.NhanVien
         WHERE TrangThai='T'
           AND NgayNghiViec BETWEEN @TuNgay AND @DenNgay
           AND (@MaPB IS NULL OR MaPB=@MaPB))   AS [Nghỉ Việc],
        (SELECT COUNT(*) FROM dbo.NhanVien
         WHERE TrangThai IN ('A','P','L')
           AND NgayVaoLam <= @DenNgay
           AND (@MaPB IS NULL OR MaPB=@MaPB))   AS [Nhân Lực Cuối Kỳ],
        -- Net change
        (SELECT COUNT(*) FROM dbo.NhanVien
         WHERE NgayVaoLam BETWEEN @TuNgay AND @DenNgay
           AND (@MaPB IS NULL OR MaPB=@MaPB))
        - (SELECT COUNT(*) FROM dbo.NhanVien
           WHERE TrangThai='T'
             AND NgayNghiViec BETWEEN @TuNgay AND @DenNgay
             AND (@MaPB IS NULL OR MaPB=@MaPB)) AS [Thay Đổi Ròng],
        @TuNgay                                 AS [Từ Ngày],
        @DenNgay                                AS [Đến Ngày];
END;
GO
PRINT N'[OK] sp_BaoCaoNhanSu_BienDong';
GO


-- ============================================================
-- SP 5: sp_BaoCaoNhanSu_LuongPhanPhoi
-- ─────────────────────────────────────────────────────────────
-- Phân tích phân phối lương trong tổ chức:
--   • Xếp hạng lương toàn công ty
--   • Phân vị (percentile) lương theo phòng ban
--   • Phát hiện bất bình đẳng lương theo giới tính
--   • Lịch sử tăng lương của từng NV
-- ============================================================
IF OBJECT_ID('dbo.sp_BaoCaoNhanSu_LuongPhanPhoi','P') IS NOT NULL
    DROP PROCEDURE dbo.sp_BaoCaoNhanSu_LuongPhanPhoi;
GO

CREATE PROCEDURE dbo.sp_BaoCaoNhanSu_LuongPhanPhoi
    @Thang  TINYINT  = NULL,
    @Nam    SMALLINT = NULL,
    @MaPB   NCHAR(10) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF @Thang IS NULL SET @Thang = MONTH(GETDATE())-1;
    IF @Nam   IS NULL SET @Nam   = YEAR(GETDATE());

    -- ── RS1: Xếp hạng lương toàn công ty ─────────────────────
    SELECT
        RANK() OVER (ORDER BY bl.LuongNet DESC)
                                            AS [Xếp Hạng],
        nv.MaNV,
        nv.HoTen                            AS [Họ Tên],
        CASE nv.GioiTinh WHEN 'M' THEN N'Nam' ELSE N'Nữ' END
                                            AS [Giới Tính],
        pb.TenPB                            AS [Phòng Ban],
        cv.TenCV                            AS [Chức Vụ],
        FORMAT(bl.LuongCoBan,'N0')          AS [Lương NN],
        FORMAT(bl.TongPhuCap,'N0')          AS [Phụ Cấp],
        FORMAT(bl.LuongGross,'N0')          AS [Gross],
        FORMAT(bl.TongBaoHiem,'N0')         AS [BH NLĐ],
        FORMAT(bl.ThueTNCN,'N0')            AS [Thuế TNCN],
        FORMAT(bl.LuongNet,'N0')            AS [Thực Lĩnh],
        -- Percentile trong toàn công ty
        FORMAT(PERCENT_RANK() OVER (
            ORDER BY bl.LuongNet),'P0')     AS [Percentile],
        -- So với lương trung bình toàn công ty
        CASE
            WHEN bl.LuongNet > AVG(bl.LuongNet) OVER () * 1.5
                THEN N'🔺 Cao hơn ≥ 50%'
            WHEN bl.LuongNet > AVG(bl.LuongNet) OVER ()
                THEN N'⬆ Trên TB'
            WHEN bl.LuongNet < AVG(bl.LuongNet) OVER () * 0.7
                THEN N'🔻 Thấp hơn ≥ 30%'
            ELSE N'⬇ Dưới TB'
        END                                 AS [So Với TB Công Ty]
    FROM dbo.BangLuong      bl
    JOIN dbo.NhanVien       nv  ON bl.MaNV = nv.MaNV
    JOIN dbo.PhongBan       pb  ON nv.MaPB = pb.MaPB
    JOIN dbo.ChucVu         cv  ON nv.MaCV = cv.MaCV
    WHERE bl.Thang = @Thang AND bl.Nam = @Nam
      AND (@MaPB IS NULL OR nv.MaPB = @MaPB)
    ORDER BY bl.LuongNet DESC;

    -- ── RS2: Phân tích lương theo giới tính (Gender Pay Gap) ─
    SELECT
        pb.TenPB                            AS [Phòng Ban],
        FORMAT(AVG(CASE WHEN nv.GioiTinh='M'
            THEN bl.LuongNet END),'N0')     AS [Lương TB Nam],
        FORMAT(AVG(CASE WHEN nv.GioiTinh='F'
            THEN bl.LuongNet END),'N0')     AS [Lương TB Nữ],
        FORMAT(
            AVG(CASE WHEN nv.GioiTinh='M' THEN CAST(bl.LuongNet AS DECIMAL) END)
            - AVG(CASE WHEN nv.GioiTinh='F' THEN CAST(bl.LuongNet AS DECIMAL) END)
        ,'N0')                              AS [Chênh Lệch Nam-Nữ],
        FORMAT(
          (AVG(CASE WHEN nv.GioiTinh='M' THEN CAST(bl.LuongNet AS DECIMAL) END)
          - AVG(CASE WHEN nv.GioiTinh='F' THEN CAST(bl.LuongNet AS DECIMAL) END))
          / NULLIF(AVG(CASE WHEN nv.GioiTinh='M'
              THEN CAST(bl.LuongNet AS DECIMAL) END),0)
        ,'P1')                              AS [Gender Pay Gap %],
        COUNT(CASE WHEN nv.GioiTinh='M' THEN 1 END) AS [Số Nam],
        COUNT(CASE WHEN nv.GioiTinh='F' THEN 1 END) AS [Số Nữ]
    FROM dbo.BangLuong      bl
    JOIN dbo.NhanVien       nv  ON bl.MaNV = nv.MaNV
    JOIN dbo.PhongBan       pb  ON nv.MaPB = pb.MaPB
    WHERE bl.Thang=@Thang AND bl.Nam=@Nam
      AND (@MaPB IS NULL OR nv.MaPB = @MaPB)
    GROUP BY pb.TenPB
    ORDER BY pb.TenPB;

    -- ── RS3: Phân vị lương toàn công ty ──────────────────────
    SELECT
        N'P10 (thấp nhất 10%)'             AS [Phân Vị],
        FORMAT(PERCENTILE_CONT(0.10) WITHIN GROUP
            (ORDER BY bl.LuongNet) OVER (),'N0') AS [Lương Net]
    FROM dbo.BangLuong bl
    WHERE bl.Thang=@Thang AND bl.Nam=@Nam
    UNION ALL
    SELECT N'P25 (tứ phân vị 1)',
        FORMAT(PERCENTILE_CONT(0.25) WITHIN GROUP
            (ORDER BY bl.LuongNet) OVER (),'N0')
    FROM dbo.BangLuong bl WHERE bl.Thang=@Thang AND bl.Nam=@Nam
    UNION ALL
    SELECT N'P50 (Median — trung vị)',
        FORMAT(PERCENTILE_CONT(0.50) WITHIN GROUP
            (ORDER BY bl.LuongNet) OVER (),'N0')
    FROM dbo.BangLuong bl WHERE bl.Thang=@Thang AND bl.Nam=@Nam
    UNION ALL
    SELECT N'P75 (tứ phân vị 3)',
        FORMAT(PERCENTILE_CONT(0.75) WITHIN GROUP
            (ORDER BY bl.LuongNet) OVER (),'N0')
    FROM dbo.BangLuong bl WHERE bl.Thang=@Thang AND bl.Nam=@Nam
    UNION ALL
    SELECT N'P90 (cao nhất 10%)',
        FORMAT(PERCENTILE_CONT(0.90) WITHIN GROUP
            (ORDER BY bl.LuongNet) OVER (),'N0')
    FROM dbo.BangLuong bl WHERE bl.Thang=@Thang AND bl.Nam=@Nam;
END;
GO
PRINT N'[OK] sp_BaoCaoNhanSu_LuongPhanPhoi';
GO


-- ============================================================
-- SP 6: sp_BaoCaoNhanSu_NghiPhepNam
-- ─────────────────────────────────────────────────────────────
-- Quản lý phép năm: số ngày đã dùng, còn tồn dư,
-- cảnh báo NV chưa nghỉ phép, NV sắp mất phép.
-- Theo Điều 113 Bộ luật Lao động 2019:
--   NV làm đủ 12 tháng = 12 ngày phép/năm.
--   NV < 12 tháng: SoNgayPhep = ThangLamViec (tỷ lệ).
-- ============================================================
IF OBJECT_ID('dbo.sp_BaoCaoNhanSu_NghiPhepNam','P') IS NOT NULL
    DROP PROCEDURE dbo.sp_BaoCaoNhanSu_NghiPhepNam;
GO

CREATE PROCEDURE dbo.sp_BaoCaoNhanSu_NghiPhepNam
    @Nam    SMALLINT  = NULL,
    @MaPB   NCHAR(10) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF @Nam IS NULL SET @Nam = YEAR(GETDATE());

    DECLARE
        @NgayDauNam DATE = DATEFROMPARTS(@Nam,1,1),
        @NgayCuoiNam DATE = DATEFROMPARTS(@Nam,12,31);

    PRINT N'════════════════════════════════════════════════════════';
    PRINT N'  BÁO CÁO NGHỈ PHÉP NĂM ' + CAST(@Nam AS NVARCHAR);
    PRINT N'  Căn cứ: Điều 113 BLLĐ 2019';
    PRINT N'════════════════════════════════════════════════════════';

    -- ── RS1: Tình trạng phép năm từng NV ─────────────────────
    SELECT
        pb.TenPB                            AS [Phòng Ban],
        nv.MaNV,
        nv.HoTen                            AS [Họ Tên],
        FORMAT(nv.NgayVaoLam,'dd/MM/yyyy')  AS [Ngày Vào Làm],
        -- Số tháng làm việc trong năm @Nam
        CASE
            WHEN nv.NgayVaoLam > @NgayCuoiNam THEN 0
            WHEN nv.NgayVaoLam > @NgayDauNam
                THEN DATEDIFF(MONTH,nv.NgayVaoLam,@NgayCuoiNam)+1
            ELSE 12
        END                                 AS [Số Tháng Làm Trong Năm],
        -- Số ngày phép được hưởng
        CASE
            WHEN nv.NgayVaoLam > @NgayCuoiNam THEN 0
            WHEN nv.NgayVaoLam > @NgayDauNam
                THEN CAST(ROUND(
                    (DATEDIFF(MONTH,nv.NgayVaoLam,@NgayCuoiNam)+1)
                    * 12.0 / 12, 0) AS INT)
            ELSE 12
        END                                 AS [Phép Được Hưởng (Ngày)],
        -- Số ngày đã dùng (từ NghiPhep đã duyệt loại Phép Năm)
        ISNULL((
            SELECT SUM(DATEDIFF(DAY,NgayBatDau,NgayKetThuc)+1)
            FROM dbo.NghiPhep np
            WHERE np.MaNV    = nv.MaNV
              AND np.MaLoaiNghi = 1        -- Phép năm
              AND np.TrangThai  = 'A'      -- Đã duyệt
              AND YEAR(np.NgayBatDau) = @Nam
        ),0)                               AS [Đã Dùng (Ngày)],
        -- Còn lại
        CASE
            WHEN nv.NgayVaoLam > @NgayCuoiNam THEN 0
            WHEN nv.NgayVaoLam > @NgayDauNam
                THEN CAST(ROUND(
                    (DATEDIFF(MONTH,nv.NgayVaoLam,@NgayCuoiNam)+1)
                    * 12.0/12,0) AS INT)
            ELSE 12
        END - ISNULL((
            SELECT SUM(DATEDIFF(DAY,NgayBatDau,NgayKetThuc)+1)
            FROM dbo.NghiPhep np
            WHERE np.MaNV=nv.MaNV AND np.MaLoaiNghi=1
              AND np.TrangThai='A' AND YEAR(np.NgayBatDau)=@Nam
        ),0)                               AS [Còn Lại (Ngày)],
        -- Cảnh báo
        CASE
            WHEN ISNULL((
                SELECT SUM(DATEDIFF(DAY,NgayBatDau,NgayKetThuc)+1)
                FROM dbo.NghiPhep np
                WHERE np.MaNV=nv.MaNV AND np.MaLoaiNghi=1
                  AND np.TrangThai='A' AND YEAR(np.NgayBatDau)=@Nam
            ),0) = 0
                THEN N'⚠️ Chưa nghỉ phép năm nào'
            WHEN (CASE WHEN nv.NgayVaoLam>@NgayDauNam
                       THEN CAST(ROUND((DATEDIFF(MONTH,nv.NgayVaoLam,
                            @NgayCuoiNam)+1)*12.0/12,0) AS INT)
                       ELSE 12 END)
                - ISNULL((SELECT SUM(DATEDIFF(DAY,NgayBatDau,NgayKetThuc)+1)
                  FROM dbo.NghiPhep np WHERE np.MaNV=nv.MaNV
                  AND np.MaLoaiNghi=1 AND np.TrangThai='A'
                  AND YEAR(np.NgayBatDau)=@Nam),0) > 6
                THEN N'🟡 Còn nhiều phép tồn'
            ELSE N'✅ Bình thường'
        END                                AS [Cảnh Báo]
    FROM dbo.NhanVien       nv
    JOIN dbo.PhongBan       pb  ON nv.MaPB = pb.MaPB
    WHERE nv.TrangThai IN ('A','P','L')
      AND nv.NgayVaoLam <= @NgayCuoiNam
      AND (@MaPB IS NULL OR nv.MaPB = @MaPB)
    ORDER BY pb.TenPB, nv.HoTen;

    -- ── RS2: Tổng hợp theo phòng ban ──────────────────────────
    SELECT
        pb.TenPB                            AS [Phòng Ban],
        COUNT(nv.MaNV)                      AS [Số NV],
        SUM(ISNULL((
            SELECT SUM(DATEDIFF(DAY,NgayBatDau,NgayKetThuc)+1)
            FROM dbo.NghiPhep np
            WHERE np.MaNV=nv.MaNV AND np.MaLoaiNghi=1
              AND np.TrangThai='A' AND YEAR(np.NgayBatDau)=@Nam
        ),0))                              AS [Tổng Ngày Đã Dùng],
        SUM(CASE WHEN NOT EXISTS (
            SELECT 1 FROM dbo.NghiPhep np
            WHERE np.MaNV=nv.MaNV AND np.MaLoaiNghi=1
              AND np.TrangThai='A' AND YEAR(np.NgayBatDau)=@Nam
        ) THEN 1 ELSE 0 END)               AS [NV Chưa Nghỉ Phép]
    FROM dbo.NhanVien nv
    JOIN dbo.PhongBan pb ON nv.MaPB=pb.MaPB
    WHERE nv.TrangThai IN ('A','P','L')
      AND (@MaPB IS NULL OR nv.MaPB=@MaPB)
    GROUP BY pb.TenPB
    ORDER BY pb.TenPB;
END;
GO
PRINT N'[OK] sp_BaoCaoNhanSu_NghiPhepNam';
GO


-- ============================================================
-- DEMO & KIỂM THỬ TOÀN BỘ
-- ============================================================
PRINT N'';
PRINT N'════════════════════════════════════════════════════════';
PRINT N'  DEMO — sp_BaoCaoNhanSu_*';
PRINT N'════════════════════════════════════════════════════════';

PRINT N'--- 1. Dashboard tổng quan ---';
EXEC dbo.sp_BaoCaoNhanSu_TongQuan;
GO

PRINT N'--- 2. Phân tích phòng ban CNTT ---';
EXEC dbo.sp_BaoCaoNhanSu_TheoPhongBan
    @MaPB='PB0004', @Thang=3, @Nam=2025;
GO

PRINT N'--- 3. HĐ sắp hết hạn 60 ngày tới ---';
EXEC dbo.sp_BaoCaoNhanSu_HopDong @SoNgayCB=60;
GO

PRINT N'--- 4. Biến động nhân sự năm 2025 ---';
EXEC dbo.sp_BaoCaoNhanSu_BienDong
    @TuNgay='2025-01-01', @DenNgay='2025-12-31';
GO

PRINT N'--- 5. Phân phối lương tháng 3/2025 ---';
EXEC dbo.sp_BaoCaoNhanSu_LuongPhanPhoi @Thang=3, @Nam=2025;
GO

PRINT N'--- 6. Phép năm tồn dư 2025 ---';
EXEC dbo.sp_BaoCaoNhanSu_NghiPhepNam @Nam=2025;
GO

-- Tổng kết
SELECT name AS [Stored Procedure], create_date AS [Ngày Tạo]
FROM sys.procedures
WHERE name LIKE 'sp_BaoCaoNhanSu%'
ORDER BY name;
GO

PRINT N'[DONE] sp_BaoCaoNhanSu.sql — 6 stored procedures hoàn tất.';
PRINT N'';
PRINT N'Danh sách SPs:';
PRINT N'  1. sp_BaoCaoNhanSu_TongQuan      — Dashboard 5 RS: tổng quan, tuổi, thâm niên, PB, KPI';
PRINT N'  2. sp_BaoCaoNhanSu_TheoPhongBan  — Danh sách NV + ma trận PIVOT PB×CV';
PRINT N'  3. sp_BaoCaoNhanSu_HopDong       — Sắp hết hạn + lịch sử điều chỉnh lương';
PRINT N'  4. sp_BaoCaoNhanSu_BienDong      — Tuyển mới / nghỉ việc / net change';
PRINT N'  5. sp_BaoCaoNhanSu_LuongPhanPhoi — Xếp hạng + gender pay gap + percentile';
PRINT N'  6. sp_BaoCaoNhanSu_NghiPhepNam   — Phép năm tồn dư theo BLLĐ 2019';
GO
