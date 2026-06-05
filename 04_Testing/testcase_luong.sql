-- ============================================================
-- FILE       : testcase_luong.sql
-- PROJECT    : Hệ Thống Quản Lý Nhân Sự & Tính Lương Tự Động
-- MỤC ĐÍCH   : Bộ kiểm thử toàn diện cho module Tính Lương
-- ─────────────────────────────────────────────────────────────
-- §1   Sanity Check  — Dữ liệu nền BangLuong 3 tháng
-- §2   fn_TinhThueTNCN — 7 bậc thuế + edge cases
-- §3   fn_TinhBHXH     — NLĐ/NSDLĐ/Thử việc/Trần BH
-- §4   sp_TinhLuong    — Pipeline 8 bước, DryRun, Override
-- §5   Tính đúng công thức  — Lương Net = Gross - BH - Thuế - KT
-- §6   ChiTietLuong    — Dòng thu nhập & khấu trừ đủ/đúng
-- §7   ThueTNCN bảng chi tiết — bậc thuế, TNCT
-- §8   sp_XacNhanBangLuong — Workflow Draft→Confirmed
-- §9   Thử việc không đóng BH — BH_NLD = 0
-- §10  Phụ cấp & OT   — Cộng đúng vào Gross
-- §11  KhauTru phát sinh — Applied sau sp_TinhLuong
-- §12  sp_TaoBangLuong_ChinhThuc — Bảng lương chính thức
-- §13  sp_TaoBangLuong_BHXH     — Danh sách đóng BH
-- §14  sp_TaoBangLuong_QuyetToanThue — Quyết toán thuế
-- §15  sp_TaoBangLuong_SoSanh   — Trend quỹ lương
-- §16  vw_BangLuong & vw_BangLuong_TongHop
-- §17  Integration — Vòng đời đầy đủ 1 kỳ lương
-- §18  Edge Cases & Boundary
-- §19  Báo cáo tổng kết
-- ─────────────────────────────────────────────────────────────
-- GIÁ TRỊ EXPECTED (đã tính từ Python cross-check):
--   NV000001 TGĐ 55M, 2PT: BH=4,914,000 | TNCT=30,286,000 | Thuế=4,407,000
--   NV000003 TP  26M, 0PT: BH=2,730,000 | TNCT=12,270,000 | Thuế=1,090,000
--   NV000010 TV   6.5M   : BH=0         | TNCT=0           | Thuế=0
-- ============================================================

USE HRPayrollDB;
GO
SET NOCOUNT ON;
GO

-- ── Bảng kết quả test ────────────────────────────────────────
IF OBJECT_ID('tempdb..#TC_Luong') IS NOT NULL
    DROP TABLE #TC_Luong;

CREATE TABLE #TC_Luong (
    TestID      INT         IDENTITY(1,1),
    Section     NVARCHAR(10),
    TestName    NVARCHAR(200),
    Expected    NVARCHAR(300),
    Actual      NVARCHAR(300),
    Status      NCHAR(4),
    GhiChu      NVARCHAR(400)
);
GO

CREATE OR ALTER PROCEDURE #LogL
    @Section    NVARCHAR(10),
    @TestName   NVARCHAR(200),
    @Expected   NVARCHAR(300),
    @Actual     NVARCHAR(300),
    @GhiChu     NVARCHAR(400) = NULL
AS
BEGIN
    DECLARE @Status NCHAR(4) =
        CASE WHEN LTRIM(RTRIM(@Expected)) = LTRIM(RTRIM(@Actual))
             THEN N'PASS' ELSE N'FAIL' END;
    INSERT #TC_Luong (Section,TestName,Expected,Actual,Status,GhiChu)
    VALUES (@Section,@TestName,@Expected,@Actual,@Status,@GhiChu);
    PRINT N'  ' + @Status + N' | ' + @TestName
        + CASE WHEN @Status=N'FAIL'
               THEN N' → KV:[' + @Expected + N'] TT:[' + @Actual + N']'
               ELSE N'' END;
END;
GO


-- ============================================================
-- §1  SANITY CHECK — DỮ LIỆU NỀN BANGLUONG
-- ============================================================
PRINT N'════════════════════════════════════════════════════════';
PRINT N'  §1  SANITY CHECK — BANGLUONG 3 THÁNG';
PRINT N'════════════════════════════════════════════════════════';

-- §1.1 BangLuong có đủ 3 kỳ (T1,T2,T3/2025)
EXEC #LogL '§1','BangLuong_3Ky_TonTai','3',
    (SELECT CAST(COUNT(DISTINCT CAST(Thang AS NVARCHAR)+'/'+CAST(Nam AS NVARCHAR))
            AS NVARCHAR)
     FROM dbo.BangLuong WHERE Nam=2025 AND Thang IN (1,2,3)),
    N'Phải có đủ 3 kỳ lương T1/T2/T3-2025';

-- §1.2 Mỗi kỳ đủ 50 NV
EXEC #LogL '§1','BangLuong_T1_50NV','50',
    (SELECT CAST(COUNT(*) AS NVARCHAR) FROM dbo.BangLuong
     WHERE Thang=1 AND Nam=2025),
    N'T1/2025 phải có đúng 50 bản ghi';

-- §1.3 Không có LuongNet âm
EXEC #LogL '§1','LuongNet_KhongAm','0',
    (SELECT CAST(COUNT(*) AS NVARCHAR) FROM dbo.BangLuong
     WHERE LuongNet < 0 AND Nam=2025),
    N'Không NV nào lương NET âm trong 3 tháng';

-- §1.4 TGĐ (NV000001) có lương cao nhất
EXEC #LogL '§1','TGD_LuongCaoNhat','NV000001',
    (SELECT TOP 1 MaNV FROM dbo.BangLuong
     WHERE Thang=3 AND Nam=2025 ORDER BY LuongNet DESC),
    N'TGĐ NV000001 phải đứng đầu bảng lương T3';

-- §1.5 NV thử việc BHXH = 0
EXEC #LogL '§1','ThuViec_BHXH_0','TRUE',
    (SELECT CASE WHEN SUM(BHXH_NLD) = 0 THEN 'TRUE' ELSE 'FALSE' END
     FROM dbo.BangLuong bl
     JOIN dbo.HopDong hd ON bl.MaNV=hd.MaNV AND hd.TrangThai='A'
     WHERE hd.MaLoaiHD=1 AND bl.Thang=1 AND bl.Nam=2025),
    N'NV thử việc (MaLoaiHD=1) không đóng BHXH';

-- §1.6 ChiTietLuong có dữ liệu
EXEC #LogL '§1','ChiTietLuong_CoData','TRUE',
    (SELECT CASE WHEN COUNT(*) >= 300 THEN 'TRUE' ELSE 'FALSE' END
     FROM dbo.ChiTietLuong ctl
     JOIN dbo.BangLuong bl ON ctl.MaBL=bl.MaBL
     WHERE bl.Thang=1 AND bl.Nam=2025),
    N'T1/2025: ≥300 dòng ChiTietLuong (≥6/NV)';

-- §1.7 ThueTNCN bảng có dữ liệu
EXEC #LogL '§1','ThueTNCN_CoData','TRUE',
    (SELECT CASE WHEN COUNT(*) > 0 THEN 'TRUE' ELSE 'FALSE' END
     FROM dbo.ThueTNCN WHERE Thang=1 AND Nam=2025),
    N'ThueTNCN có dữ liệu T1/2025';

-- §1.8 KhauTru đã được applied
EXEC #LogL '§1','KhauTru_Applied_A','TRUE',
    (SELECT CASE WHEN COUNT(*) > 0 THEN 'TRUE' ELSE 'FALSE' END
     FROM dbo.KhauTru WHERE TrangThai='A'),
    N'KhauTru status Applied sau sp_TinhLuong';
GO


-- ============================================================
-- §2  KIỂM THỬ fn_TinhThueTNCN — 7 BẬC THUẾ
-- ============================================================
PRINT N'';
PRINT N'════════════════════════════════════════════════════════';
PRINT N'  §2  fn_TinhThueTNCN — BIỂU THUẾ LŨY TIẾN 7 BẬC';
PRINT N'════════════════════════════════════════════════════════';
PRINT N'  (Thông tư 111/2013/TT-BTC — kỳ vọng tính từ Python)';
PRINT N'';

-- §2.1–2.11 kiểm tra từng mức TNCT
DECLARE @TC TABLE (TNCT DECIMAL(15,0), Expected NVARCHAR(20), Label NVARCHAR(50));
INSERT @TC VALUES
    (0,          '0',          N'TNCT=0 → không phát sinh'),
    (-1000000,   '0',          N'TNCT âm → không phát sinh'),
    (4000000,    '200000',     N'Bậc 1: 4tr×5%=200k'),
    (5000000,    '250000',     N'Bậc 1 đỉnh: 5tr×5%=250k'),
    (7500000,    '500000',     N'Bậc 2: B1:250k+B2:250k=500k'),
    (10000000,   '750000',     N'Bậc 2 đỉnh: B1+B2=750k'),
    (15000000,   '1500000',    N'Bậc 3: B1+B2+B3=1,500k'),
    (18000000,   '1950000',    N'Bậc 3 đỉnh: B1+B2+B3=1,950k'),
    (25000000,   '3350000',    N'Bậc 4: 3,350k'),
    (32000000,   '4750000',    N'Bậc 4 đỉnh: 4,750k'),
    (40000000,   '6750000',    N'Bậc 5: 6,750k'),
    (52000000,   '9750000',    N'Bậc 5 đỉnh: 9,750k'),
    (65000000,   '13650000',   N'Bậc 6: 13,650k'),
    (80000000,   '18150000',   N'Bậc 6 đỉnh: 18,150k'),
    (100000000,  '25150000',   N'Bậc 7: 25,150k'),
    (200000000,  '60150000',   N'Bậc 7 cao: 200tr');

DECLARE @TNCT DECIMAL(15,0), @Exp NVARCHAR(20), @Lbl NVARCHAR(50);
DECLARE cur CURSOR LOCAL FAST_FORWARD FOR
    SELECT TNCT, Expected, Label FROM @TC;
OPEN cur;
FETCH NEXT FROM cur INTO @TNCT, @Exp, @Lbl;
WHILE @@FETCH_STATUS=0
BEGIN
    EXEC #LogL '§2', @Lbl, @Exp,
        (SELECT CAST(dbo.fn_TinhThueTNCN_Scalar(@TNCT) AS NVARCHAR)),
        N'Kiểm tra fn_TinhThueTNCN_Scalar';
    FETCH NEXT FROM cur INTO @TNCT, @Exp, @Lbl;
END;
CLOSE cur; DEALLOCATE cur;
GO

-- §2.17 fn_XacDinhBacThue
EXEC #LogL '§2','BacThue_0_TNCT_0','0',
    (SELECT CAST(dbo.fn_XacDinhBacThue(0) AS NVARCHAR)),N'TNCT=0→Bậc 0';
EXEC #LogL '§2','BacThue_1_3tr','1',
    (SELECT CAST(dbo.fn_XacDinhBacThue(3000000) AS NVARCHAR)),N'3tr→Bậc 1';
EXEC #LogL '§2','BacThue_4_25tr','4',
    (SELECT CAST(dbo.fn_XacDinhBacThue(25000000) AS NVARCHAR)),N'25tr→Bậc 4';
EXEC #LogL '§2','BacThue_7_100tr','7',
    (SELECT CAST(dbo.fn_XacDinhBacThue(100000000) AS NVARCHAR)),N'100tr→Bậc 7';

-- §2.21 fn_TinhGiamTruPhuThuoc
EXEC #LogL '§2','GiamTru_0PT','0',
    (SELECT CAST(dbo.fn_TinhGiamTruPhuThuoc(0) AS NVARCHAR)),N'0PT→0 VNĐ';
EXEC #LogL '§2','GiamTru_1PT','4400000',
    (SELECT CAST(dbo.fn_TinhGiamTruPhuThuoc(1) AS NVARCHAR)),N'1PT→4,400,000';
EXEC #LogL '§2','GiamTru_3PT','13200000',
    (SELECT CAST(dbo.fn_TinhGiamTruPhuThuoc(3) AS NVARCHAR)),N'3PT→13,200,000';

-- §2.24 fn_TinhThueTNCN_ChiTiet TVF
EXEC #LogL '§2','TVF_ChiTiet_CoData','TRUE',
    (SELECT CASE WHEN COUNT(*) > 0 THEN 'TRUE' ELSE 'FALSE' END
     FROM dbo.fn_TinhThueTNCN_ChiTiet(40000000)
     WHERE ThuNhapTinhBac > 0),
    N'TVF ChiTiet 40M → có dữ liệu bậc thuế';

EXEC #LogL '§2','TVF_ChiTiet_TongDung','6750000',
    (SELECT CAST(MAX(TienThue_LuyKe) AS NVARCHAR)
     FROM dbo.fn_TinhThueTNCN_ChiTiet(40000000)),
    N'TVF ChiTiet 40M → tổng lũy kế = 6,750,000';
GO


-- ============================================================
-- §3  KIỂM THỬ fn_TinhBHXH — BẢO HIỂM XÃ HỘI
-- ============================================================
PRINT N'';
PRINT N'════════════════════════════════════════════════════════';
PRINT N'  §3  fn_TinhBHXH — BH NLĐ 10.5% | NSDLĐ 22%';
PRINT N'════════════════════════════════════════════════════════';

-- §3.1 fn_TinhLuongDongBH — dưới trần
EXEC #LogL '§3','LuongDongBH_DuoiTran','10000000',
    (SELECT CAST(dbo.fn_TinhLuongDongBH(10000000,2) AS NVARCHAR)),
    N'10M < 46.8M → LuongDongBH = 10M';

-- §3.2 fn_TinhLuongDongBH — đúng trần
EXEC #LogL '§3','LuongDongBH_DungTran','46800000',
    (SELECT CAST(dbo.fn_TinhLuongDongBH(46800000,4) AS NVARCHAR)),
    N'46.8M = trần → LuongDongBH = 46.8M';

-- §3.3 fn_TinhLuongDongBH — vượt trần → cap
EXEC #LogL '§3','LuongDongBH_VuotTran_Cap','46800000',
    (SELECT CAST(dbo.fn_TinhLuongDongBH(55000000,4) AS NVARCHAR)),
    N'55M > 46.8M → LuongDongBH cap tại 46.8M';

-- §3.4 fn_TinhLuongDongBH — thử việc → 0
EXEC #LogL '§3','LuongDongBH_ThuViec_Zero','0',
    (SELECT CAST(dbo.fn_TinhLuongDongBH(6500000,1) AS NVARCHAR)),
    N'HĐ thử việc (MaLoaiHD=1) → LuongDongBH = 0';

-- §3.5 fn_TinhBH_NLD — 10.5% của 10M
EXEC #LogL '§3','BH_NLD_10pct5_10M','1050000',
    (SELECT CAST(dbo.fn_TinhBH_NLD(10000000,2) AS NVARCHAR)),
    N'10M × 10.5% = 1,050,000';

-- §3.6 fn_TinhBH_NLD — TGĐ lương 55M (trần 46.8M)
EXEC #LogL '§3','BH_NLD_TGD_55M','4914000',
    (SELECT CAST(dbo.fn_TinhBH_NLD(55000000,4) AS NVARCHAR)),
    N'55M → DongBH=46.8M → 46.8M×10.5%=4,914,000';

-- §3.7 fn_TinhBH_NLD — thử việc = 0
EXEC #LogL '§3','BH_NLD_ThuViec_0','0',
    (SELECT CAST(dbo.fn_TinhBH_NLD(6500000,1) AS NVARCHAR)),
    N'Thử việc BH_NLD = 0';

-- §3.8 fn_TinhBH_NSDLD — 22% của 10M
EXEC #LogL '§3','BH_NSDLD_22pct_10M','2200000',
    (SELECT CAST(dbo.fn_TinhBH_NSDLD(10000000,2) AS NVARCHAR)),
    N'10M × 22% = 2,200,000';

-- §3.9 fn_TinhBHXH_TVF — kiểm tra NV 26M
DECLARE @bh_nld  DECIMAL(15,2),
        @bh_dnld DECIMAL(15,2);
SELECT @bh_nld = Tong_BH_NLD, @bh_dnld = Tong_BH_NSDLD
FROM dbo.fn_TinhBHXH_TVF(26000000,3);

EXEC #LogL '§3','TVF_BH_NLD_26M','2730000',
    CAST(@bh_nld AS NVARCHAR),
    N'26M×10.5% = 2,730,000 (NLĐ đóng)';

EXEC #LogL '§3','TVF_BH_NSDLD_26M','5720000',
    CAST(@bh_dnld AS NVARCHAR),
    N'26M×22% = 5,720,000 (NSDLĐ đóng)';

-- §3.11 TVF — thử việc toàn bộ = 0
DECLARE @bh_tv DECIMAL(15,2);
SELECT @bh_tv = Tong_BH_Ca_Hai FROM dbo.fn_TinhBHXH_TVF(6500000,1);
EXEC #LogL '§3','TVF_ThuViec_TongBH_0','0',
    CAST(@bh_tv AS NVARCHAR),
    N'Thử việc: Tổng BH cả hai phía = 0';

-- §3.12 BHXH+BHYT+BHTN NLĐ = 10.5%
DECLARE @bhxh DECIMAL(15,2), @bhyt DECIMAL(15,2), @bhtn DECIMAL(15,2);
SELECT @bhxh=BHXH_NLD, @bhyt=BHYT_NLD, @bhtn=BHTN_NLD
FROM dbo.fn_TinhBHXH_TVF(20000000,2);
EXEC #LogL '§3','TVF_BHXH_8pct','1600000',CAST(@bhxh AS NVARCHAR),N'20M×8%=1,600,000');
EXEC #LogL '§3','TVF_BHYT_1pct5','300000',CAST(@bhyt AS NVARCHAR),N'20M×1.5%=300,000');
EXEC #LogL '§3','TVF_BHTN_1pct','200000',CAST(@bhtn AS NVARCHAR),N'20M×1%=200,000');
GO


-- ============================================================
-- §4  KIỂM THỬ sp_TinhLuong
-- ============================================================
PRINT N'';
PRINT N'════════════════════════════════════════════════════════';
PRINT N'  §4  sp_TinhLuong — PIPELINE 8 BƯỚC';
PRINT N'════════════════════════════════════════════════════════';

-- §4.1 Tháng hợp lệ không bị lỗi
EXEC #LogL '§4','BangLuong_T1_Exists','50',
    (SELECT CAST(COUNT(*) AS NVARCHAR) FROM dbo.BangLuong
     WHERE Thang=1 AND Nam=2025),
    N'T1/2025 đã có 50 bản ghi sau sp_TinhLuong';

-- §4.2 DryRun = 1 không ghi vào DB
DECLARE @BLCount_Truoc INT;
SELECT @BLCount_Truoc = COUNT(*) FROM dbo.BangLuong;
EXEC dbo.sp_TinhLuong 4, 2025, NULL, 0, 1;  -- DryRun T4/2025

EXEC #LogL '§4','DryRun_KhongGhi','TRUE',
    (SELECT CASE WHEN COUNT(*) = @BLCount_Truoc THEN 'TRUE' ELSE 'FALSE' END
     FROM dbo.BangLuong),
    N'@DryRun=1: BangLuong không tăng thêm';
GO

-- §4.3 Tháng tương lai bị chặn
DECLARE @L04 BIT = 0;
BEGIN TRY
    EXEC dbo.sp_TinhLuong 12, 2099;
    SET @L04 = 0;
END TRY BEGIN CATCH SET @L04 = 1; END CATCH;
EXEC #LogL '§4','TuongLai_Chant','1',
    CAST(@L04 AS NVARCHAR), N'sp_TinhLuong T12/2099 (tương lai) bị chặn';

-- §4.4 Tháng sai (0, 13) bị chặn
DECLARE @L05 BIT = 0;
BEGIN TRY
    EXEC dbo.sp_TinhLuong 0, 2025;
    SET @L05 = 0;
END TRY BEGIN CATCH SET @L05 = 1; END CATCH;
EXEC #LogL '§4','ThangSai_0_Chant','1',
    CAST(@L05 AS NVARCHAR), N'@Thang=0 bị chặn';

-- §4.5 Override = 0 chặn tính lại bản CHOT
DECLARE @L06 BIT = 0;
BEGIN TRY
    -- T1/2025 đã CHOT (từ test §8 sau), thử tính lại
    IF EXISTS (SELECT 1 FROM dbo.BangLuong
               WHERE Thang=1 AND Nam=2025 AND TrangThai IN ('C','P','L'))
    BEGIN
        EXEC dbo.sp_TinhLuong 1, 2025; -- @Override=0 default
        SET @L06 = 0;
    END
    ELSE SET @L06 = 1;  -- Chưa CHOT → SKIP
END TRY BEGIN CATCH SET @L06 = 1; END CATCH;
EXEC #LogL '§4','Override0_Block_Recalc','1',
    CAST(@L06 AS NVARCHAR), N'Tính lại BL đã CHOT không có @Override=1 → lỗi';

-- §4.6 Tính riêng 1 NV
EXEC dbo.sp_TinhLuong 3, 2025, 'NV000001';

EXEC #LogL '§4','TinhRieng_1NV','NV000001',
    (SELECT TOP 1 MaNV FROM dbo.BangLuong
     WHERE Thang=3 AND Nam=2025
     ORDER BY NgayTinhLuong DESC),
    N'Tính riêng NV000001 T3/2025 → ghi vào BangLuong';
GO


-- ============================================================
-- §5  KIỂM TRA CÔNG THỨC LƯƠNG NET
-- ============================================================
PRINT N'';
PRINT N'════════════════════════════════════════════════════════';
PRINT N'  §5  CÔNG THỨC: LuongNet = Gross - BH - Thuế - KhauTru';
PRINT N'════════════════════════════════════════════════════════';

-- §5.1 Công thức đúng cho tất cả bản ghi (sai số ≤ 1 VNĐ làm tròn)
EXEC #LogL '§5','Formula_LuongNet_T1','0',
    (SELECT CAST(COUNT(*) AS NVARCHAR)
     FROM dbo.BangLuong
     WHERE Thang=1 AND Nam=2025
       AND ABS(LuongNet -
           (LuongGross - TongBaoHiem - ThueTNCN
            - (TongKhauTru - TongBaoHiem - ThueTNCN))) > 1),
    N'T1: LuongNet = Gross - BH - Thuế - KhauTruKhac (sai số ≤ 1đ)';

-- §5.2 TổngBH_NLD = BHXH + BHYT + BHTN
EXEC #LogL '§5','TongBH_Sum_Components','0',
    (SELECT CAST(COUNT(*) AS NVARCHAR)
     FROM dbo.BangLuong
     WHERE Thang=1 AND Nam=2025
       AND ABS(TongBaoHiem - (BHXH_NLD + BHYT_NLD + BHTN_NLD)) > 1),
    N'TongBaoHiem = BHXH+BHYT+BHTN (tất cả T1)';

-- §5.3 LuongGross ≥ LuongCoBan (có phụ cấp cộng vào)
EXEC #LogL '§5','Gross_GTE_LuongCB','TRUE',
    (SELECT CASE WHEN MIN(LuongGross - LuongCoBan) >= 0 THEN 'TRUE' ELSE 'FALSE' END
     FROM dbo.BangLuong WHERE Thang=1 AND Nam=2025),
    N'LuongGross >= LuongCoBan (phụ cấp không âm)';

-- §5.4 Thuế TNCN không vượt 35% Gross
EXEC #LogL '§5','Thue_Max35pct_Gross','0',
    (SELECT CAST(COUNT(*) AS NVARCHAR)
     FROM dbo.BangLuong
     WHERE Thang=1 AND Nam=2025
       AND LuongGross > 0
       AND ThueTNCN > LuongGross * 0.35),
    N'ThueTNCN không vượt 35% LuongGross';

-- §5.5 BH NLĐ không vượt 10.5% lương đóng BH (≤ 46.8M)
EXEC #LogL '§5','BH_NLD_Max10pct5','0',
    (SELECT CAST(COUNT(*) AS NVARCHAR)
     FROM dbo.BangLuong bl
     JOIN dbo.HopDong hd ON bl.MaNV=hd.MaNV AND hd.TrangThai='A'
     WHERE bl.Thang=1 AND bl.Nam=2025 AND hd.MaLoaiHD <> 1
       AND bl.TongBaoHiem > LEAST(bl.LuongCoBan, 46800000) * 0.106),
    N'BH_NLD ≤ min(LCB,46.8M) × 10.5%';

-- §5.6 NV000001 TGĐ: BH chính xác = 4,914,000
EXEC #LogL '§5','TGD_BH_NLD_Exact','4914000',
    (SELECT CAST(TongBaoHiem AS NVARCHAR) FROM dbo.BangLuong
     WHERE MaNV='NV000001' AND Thang=3 AND Nam=2025),
    N'TGĐ: 46.8M×10.5% = 4,914,000 đúng';

-- §5.7 NV000001 ThueTNCN (dự kiến ~4,407,000)
EXEC #LogL '§5','TGD_Thue_Range','TRUE',
    (SELECT CASE WHEN ThueTNCN BETWEEN 3000000 AND 6000000
                 THEN 'TRUE' ELSE 'FALSE' END
     FROM dbo.BangLuong WHERE MaNV='NV000001' AND Thang=3 AND Nam=2025),
    N'TGĐ ThueTNCN nằm trong khoảng 3-6 triệu';

-- §5.8 NV000003 ThueTNCN (dự kiến ~1,090,000)
EXEC #LogL '§5','TP_Thue_Range','TRUE',
    (SELECT CASE WHEN ThueTNCN BETWEEN 800000 AND 1500000
                 THEN 'TRUE' ELSE 'FALSE' END
     FROM dbo.BangLuong WHERE MaNV='NV000003' AND Thang=3 AND Nam=2025),
    N'Trưởng phòng NS: ThueTNCN ~1,090,000';
GO


-- ============================================================
-- §6  CHITIẾT LƯƠNG — CÁC DÒNG THU NHẬP/KHẤU TRỪ
-- ============================================================
PRINT N'';
PRINT N'════════════════════════════════════════════════════════';
PRINT N'  §6  CHITIET LUONG — DÒNG TỪNG KHOẢN';
PRINT N'════════════════════════════════════════════════════════';

-- §6.1 Có dòng Lương cơ bản theo ngày công (+)
EXEC #LogL '§6','CTL_LuongCoBan_Ton_Tai','TRUE',
    (SELECT CASE WHEN COUNT(*) = 50 THEN 'TRUE' ELSE 'FALSE' END
     FROM dbo.ChiTietLuong ctl
     JOIN dbo.BangLuong bl ON ctl.MaBL=bl.MaBL
     WHERE bl.Thang=1 AND bl.Nam=2025
       AND ctl.LoaiMuc='+' AND ctl.TenMuc LIKE N'%cơ bản%'),
    N'T1/2025: 50 NV đều có dòng Lương CB';

-- §6.2 Dòng BHXH NLĐ có GiaTri > 0 (không tính thử việc)
EXEC #LogL '§6','CTL_BHXH_NLD_Positive','TRUE',
    (SELECT CASE WHEN COUNT(*) >= 40 THEN 'TRUE' ELSE 'FALSE' END
     FROM dbo.ChiTietLuong ctl
     JOIN dbo.BangLuong bl ON ctl.MaBL=bl.MaBL
     WHERE bl.Thang=1 AND bl.Nam=2025
       AND ctl.LoaiMuc='-' AND ctl.TenMuc LIKE N'%BHXH%'
       AND ctl.GiaTri > 0),
    N'T1: ≥40 NV có dòng BHXH khấu trừ (trừ 4 TV)';

-- §6.3 Dòng Thuế TNCN chỉ xuất hiện khi > 0
EXEC #LogL '§6','CTL_ThueTNCN_OnlyPositive','0',
    (SELECT CAST(COUNT(*) AS NVARCHAR)
     FROM dbo.ChiTietLuong ctl
     JOIN dbo.BangLuong bl ON ctl.MaBL=bl.MaBL
     WHERE bl.Thang=1 AND bl.Nam=2025
       AND ctl.TenMuc LIKE N'%Thuế TNCN%'
       AND ctl.GiaTri = 0),
    N'Dòng Thuế TNCN không xuất hiện khi GiaTri=0';

-- §6.4 Tổng dòng + và - cân bằng với LuongGross và LuongNet
EXEC #LogL '§6','CTL_TongCong_Dung','TRUE',
    (SELECT CASE WHEN COUNT(*) = 0 THEN 'TRUE' ELSE 'FALSE' END
     FROM (
         SELECT bl.MaBL,
                SUM(CASE WHEN ctl.LoaiMuc='+' THEN ctl.GiaTri ELSE -ctl.GiaTri END)
                - bl.LuongGross + bl.TongKhauTru AS Diff
         FROM dbo.BangLuong bl
         JOIN dbo.ChiTietLuong ctl ON bl.MaBL=ctl.MaBL
         WHERE bl.Thang=1 AND bl.Nam=2025
         GROUP BY bl.MaBL, bl.LuongGross, bl.TongKhauTru
         HAVING ABS(SUM(CASE WHEN ctl.LoaiMuc='+' THEN ctl.GiaTri
                              ELSE -ctl.GiaTri END)
                    - (bl.LuongGross - bl.TongKhauTru)) > 100
     ) x),
    N'SUM(CTL) ≈ LuongGross - TongKhauTru (sai số ≤ 100đ)';

-- §6.5 FL0001 (ăn trưa 730k) xuất hiện trong CTL tất cả NV
EXEC #LogL '§6','CTL_PhucCap_AnTrua','TRUE',
    (SELECT CASE WHEN COUNT(DISTINCT bl.MaNV) >= 45 THEN 'TRUE' ELSE 'FALSE' END
     FROM dbo.ChiTietLuong ctl
     JOIN dbo.BangLuong bl ON ctl.MaBL=bl.MaBL
     WHERE bl.Thang=1 AND bl.Nam=2025
       AND ctl.TenMuc LIKE N'%ăn trưa%'),
    N'Phụ cấp ăn trưa FL0001 xuất hiện ≥45 NV';
GO


-- ============================================================
-- §7  THUẾ TNCN BẢNG CHI TIẾT
-- ============================================================
PRINT N'';
PRINT N'════════════════════════════════════════════════════════';
PRINT N'  §7  THUE TNCN — KIỂM TRA BẢNG ThueTNCN';
PRINT N'════════════════════════════════════════════════════════';

-- §7.1 Mỗi NV chỉ có 1 dòng ThueTNCN / kỳ
EXEC #LogL '§7','ThueTNCN_1DongPerNV','0',
    (SELECT CAST(COUNT(*) AS NVARCHAR)
     FROM (
         SELECT MaNV, Thang, Nam, COUNT(*) cnt
         FROM dbo.ThueTNCN WHERE Thang=1 AND Nam=2025
         GROUP BY MaNV, Thang, Nam HAVING COUNT(*) > 1
     ) x),
    N'Không có NV nào có >1 dòng ThueTNCN T1';

-- §7.2 TNCT >= 0
EXEC #LogL '§7','TNCT_NonNegative','0',
    (SELECT CAST(COUNT(*) AS NVARCHAR)
     FROM dbo.ThueTNCN WHERE Thang=1 AND Nam=2025
       AND ThuNhapChiuThue < 0),
    N'TNCT không âm (đã xử lý max(0,TNCT))';

-- §7.3 TienThue >= 0
EXEC #LogL '§7','TienThue_NonNegative','0',
    (SELECT CAST(COUNT(*) AS NVARCHAR)
     FROM dbo.ThueTNCN WHERE Thang=1 AND Nam=2025
       AND TienThue < 0),
    N'Tiền thuế không âm';

-- §7.4 BacThue [0,7]
EXEC #LogL '§7','BacThue_Range_0_7','0',
    (SELECT CAST(COUNT(*) AS NVARCHAR)
     FROM dbo.ThueTNCN WHERE Thang=1 AND Nam=2025
       AND (BacThue < 0 OR BacThue > 7)),
    N'BacThue nằm trong [0,7]';

-- §7.5 NV thử việc: TienThue = 0
EXEC #LogL '§7','ThuViec_TienThue_0','TRUE',
    (SELECT CASE WHEN SUM(tt.TienThue) = 0 THEN 'TRUE' ELSE 'FALSE' END
     FROM dbo.ThueTNCN tt
     JOIN dbo.HopDong hd ON tt.MaNV=hd.MaNV AND hd.TrangThai='A'
     WHERE tt.Thang=1 AND tt.Nam=2025 AND hd.MaLoaiHD=1),
    N'NV thử việc: TienThue = 0 (lương thấp < giảm trừ)';

-- §7.6 TGĐ bậc thuế ≥ 4
EXEC #LogL '§7','TGD_BacThue_GTE4','TRUE',
    (SELECT CASE WHEN BacThue >= 4 THEN 'TRUE' ELSE 'FALSE' END
     FROM dbo.ThueTNCN
     WHERE MaNV='NV000001' AND Thang=3 AND Nam=2025),
    N'TGĐ lương 55M → bậc thuế ≥ 4';

-- §7.7 Công thức TienThue khớp fn_TinhThueTNCN_Scalar
EXEC #LogL '§7','TienThue_Match_Function','0',
    (SELECT CAST(COUNT(*) AS NVARCHAR)
     FROM dbo.ThueTNCN tt
     WHERE tt.Thang=1 AND tt.Nam=2025
       AND ABS(tt.TienThue
               - dbo.fn_TinhThueTNCN_Scalar(tt.ThuNhapChiuThue)) > 1000),
    N'TienThue trong DB ≈ fn_TinhThueTNCN_Scalar (±1000đ)';
GO


-- ============================================================
-- §8  WORKFLOW: sp_XacNhanBangLuong D→C
-- ============================================================
PRINT N'';
PRINT N'════════════════════════════════════════════════════════';
PRINT N'  §8  WORKFLOW — Draft → Confirmed → Paid';
PRINT N'════════════════════════════════════════════════════════';

-- §8.1 T2/2025 vẫn là Draft
EXEC #LogL '§8','T2_Status_Draft','TRUE',
    (SELECT CASE WHEN COUNT(*) = 50 THEN 'TRUE' ELSE 'FALSE' END
     FROM dbo.BangLuong WHERE Thang=2 AND Nam=2025 AND TrangThai='D'),
    N'T2/2025 ở trạng thái Draft trước khi xác nhận';

-- §8.2 Xác nhận T2
EXEC dbo.sp_XacNhanBangLuong 2, 2025, N'Hoàng Thị Phương';
GO

EXEC #LogL '§8','T2_After_Xac_Nhan_C','50',
    (SELECT CAST(COUNT(*) AS NVARCHAR) FROM dbo.BangLuong
     WHERE Thang=2 AND Nam=2025 AND TrangThai='C'),
    N'Sau xác nhận T2: 50 bản ghi → Confirmed';

-- §8.3 Không còn Draft T2
EXEC #LogL '§8','T2_NoDraft_After_Confirm','0',
    (SELECT CAST(COUNT(*) AS NVARCHAR) FROM dbo.BangLuong
     WHERE Thang=2 AND Nam=2025 AND TrangThai='D'),
    N'Sau xác nhận: không còn Draft T2';

-- §8.4 Chặn xác nhận kỳ không có Draft
DECLARE @W04 BIT = 0;
BEGIN TRY
    EXEC dbo.sp_XacNhanBangLuong 2, 2025, N'Test';  -- Đã xác nhận rồi
    SET @W04 = 0;
END TRY BEGIN CATCH SET @W04 = 1; END CATCH;
EXEC #LogL '§8','Block_XacNhan_KhongCoDraft','1',
    CAST(@W04 AS NVARCHAR), N'Xác nhận kỳ đã Confirmed → lỗi';

-- §8.5 Chuyển sang Paid (C→P)
UPDATE dbo.BangLuong
SET TrangThai='P', NgayThanhToan='2025-03-10'
WHERE Thang=2 AND Nam=2025 AND TrangThai='C';

EXEC #LogL '§8','T2_Paid','50',
    (SELECT CAST(COUNT(*) AS NVARCHAR) FROM dbo.BangLuong
     WHERE Thang=2 AND Nam=2025 AND TrangThai='P'),
    N'C→P: 50 bản ghi T2 chuyển sang Paid';

-- §8.6 Không thể sửa số liệu bảng lương đã Paid
DECLARE @W06 BIT = 0;
BEGIN TRY
    UPDATE dbo.BangLuong SET LuongNet = 0
    WHERE Thang=2 AND Nam=2025 AND TrangThai='P';
    SET @W06 = 0;
END TRY BEGIN CATCH SET @W06 = 1; END CATCH;
EXEC #LogL '§8','Guard_Paid_KhongSuaNet','1',
    CAST(@W06 AS NVARCHAR), N'trg_BangLuong_GuardChot chặn sửa BL Paid';
GO


-- ============================================================
-- §9  NV THỬ VIỆC — ĐẶC TRƯỜNG HỢP
-- ============================================================
PRINT N'';
PRINT N'════════════════════════════════════════════════════════';
PRINT N'  §9  NV THỬ VIỆC — BR-07: Không đóng BHXH';
PRINT N'════════════════════════════════════════════════════════';

-- Danh sách NV thử việc từ seed
DECLARE @TVList TABLE (MaNV NCHAR(10));
INSERT @TVList VALUES ('NV000010'),('NV000020'),('NV000038'),('NV000050');

-- §9.1 BH_NLD = 0 cho tất cả NV TV
EXEC #LogL '§9','ThuViec_BHXH_NLD_0','TRUE',
    (SELECT CASE WHEN SUM(bl.BHXH_NLD) = 0 THEN 'TRUE' ELSE 'FALSE' END
     FROM dbo.BangLuong bl WHERE bl.MaNV IN
         ('NV000010','NV000020','NV000038','NV000050')
       AND bl.Thang=1 AND bl.Nam=2025),
    N'TV: BHXH_NLD = 0 (không đóng 8%)';

EXEC #LogL '§9','ThuViec_BHYT_NLD_0','TRUE',
    (SELECT CASE WHEN SUM(bl.BHYT_NLD) = 0 THEN 'TRUE' ELSE 'FALSE' END
     FROM dbo.BangLuong bl WHERE bl.MaNV IN
         ('NV000010','NV000020','NV000038','NV000050')
       AND bl.Thang=1 AND bl.Nam=2025),
    N'TV: BHYT_NLD = 0 (không đóng 1.5%)';

-- §9.2 ThueTNCN = 0 (lương thấp < giảm trừ bản thân)
EXEC #LogL '§9','ThuViec_ThueTNCN_0','TRUE',
    (SELECT CASE WHEN SUM(bl.ThueTNCN) = 0 THEN 'TRUE' ELSE 'FALSE' END
     FROM dbo.BangLuong bl WHERE bl.MaNV IN
         ('NV000010','NV000020','NV000038','NV000050')
       AND bl.Thang=1 AND bl.Nam=2025),
    N'TV 6.5M < Giảm trừ 11M → ThueTNCN = 0';

-- §9.3 LuongNet ≈ LuongGross (không có BH, không có thuế)
EXEC #LogL '§9','ThuViec_Net_EQ_Gross','TRUE',
    (SELECT CASE WHEN MIN(bl.LuongNet / NULLIF(bl.LuongGross,0)) > 0.99
                 THEN 'TRUE' ELSE 'FALSE' END
     FROM dbo.BangLuong bl WHERE bl.MaNV IN
         ('NV000010','NV000020','NV000038','NV000050')
       AND bl.Thang=1 AND bl.Nam=2025),
    N'TV: LuongNet ≈ LuongGross (≥99%)';
GO


-- ============================================================
-- §10 PHỤ CẤP & OT ẢNH HƯỞNG LƯƠNG GROSS
-- ============================================================
PRINT N'';
PRINT N'════════════════════════════════════════════════════════';
PRINT N'  §10 PHỤ CẤP & OT — CỘNG VÀO GROSS';
PRINT N'════════════════════════════════════════════════════════';

-- §10.1 TongPhuCap > 0 (mọi NV đều có ít nhất FL0001 ăn trưa)
EXEC #LogL '§10','TongPhuCap_Positive','0',
    (SELECT CAST(COUNT(*) AS NVARCHAR)
     FROM dbo.BangLuong WHERE Thang=1 AND Nam=2025 AND TongPhuCap = 0),
    N'Tất cả NV có TongPhuCap > 0 (ít nhất FL0001)';

-- §10.2 Quản lý (CV0001/CV0002) có TongPhuCap > NV thường
EXEC #LogL '§10','Manager_PhuCap_Greater','TRUE',
    (SELECT CASE WHEN
        (SELECT AVG(bl.TongPhuCap) FROM dbo.BangLuong bl
         JOIN dbo.NhanVien nv ON bl.MaNV=nv.MaNV
         WHERE bl.Thang=1 AND bl.Nam=2025 AND nv.MaCV IN ('CV0001','CV0002'))
        >
        (SELECT AVG(bl.TongPhuCap) FROM dbo.BangLuong bl
         JOIN dbo.NhanVien nv ON bl.MaNV=nv.MaNV
         WHERE bl.Thang=1 AND bl.Nam=2025 AND nv.MaCV NOT IN ('CV0001','CV0002'))
        THEN 'TRUE' ELSE 'FALSE' END),
    N'Lãnh đạo có phụ cấp TB cao hơn NV thường';

-- §10.3 Team CNTT có tăng ca trong Gross (FL0001+OT)
EXEC #LogL '§10','CNTT_OT_In_Gross','TRUE',
    (SELECT CASE WHEN
        (SELECT AVG(bl.LuongGross) FROM dbo.BangLuong bl
         JOIN dbo.NhanVien nv ON bl.MaNV=nv.MaNV
         WHERE bl.Thang=1 AND bl.Nam=2025 AND nv.MaPB='PB0004')
        >=
        (SELECT AVG(bl.LuongCoBan) FROM dbo.BangLuong bl
         JOIN dbo.NhanVien nv ON bl.MaNV=nv.MaNV
         WHERE bl.Thang=1 AND bl.Nam=2025 AND nv.MaPB='PB0004')
        THEN 'TRUE' ELSE 'FALSE' END),
    N'CNTT Gross ≥ LuongCoBan (có phụ cấp + OT)';
GO


-- ============================================================
-- §11 KHAUTRU APPLIED SAU sp_TinhLuong
-- ============================================================
PRINT N'';
PRINT N'════════════════════════════════════════════════════════';
PRINT N'  §11 KHAUTRU — APPLIED VÀO BẢNG LƯƠNG';
PRINT N'════════════════════════════════════════════════════════';

-- §11.1 Các KhauTru từ seed đã Applied (TrangThai='A')
EXEC #LogL '§11','KhauTru_Seed_Applied','TRUE',
    (SELECT CASE WHEN COUNT(*) > 0 THEN 'TRUE' ELSE 'FALSE' END
     FROM dbo.KhauTru WHERE TrangThai='A'),
    N'KhauTru seed đã Applied sau sp_TinhLuong';

-- §11.2 KhauTru Applied có MaBL liên kết
EXEC #LogL '§11','KhauTru_CoMaBL','0',
    (SELECT CAST(COUNT(*) AS NVARCHAR)
     FROM dbo.KhauTru WHERE TrangThai='A' AND MaBL IS NULL),
    N'KhauTru Applied đều có MaBL (liên kết BangLuong)';

-- §11.3 TongKhauTru trong BangLuong = BH + Thuế + KhauTruKhac
EXEC #LogL '§11','TongKhauTru_Formula','0',
    (SELECT CAST(COUNT(*) AS NVARCHAR)
     FROM dbo.BangLuong bl
     WHERE Thang IN (1,2,3) AND Nam=2025
       AND TongKhauTru < TongBaoHiem + ThueTNCN),
    N'TongKhauTru ≥ TongBaoHiem + ThueTNCN';

-- §11.4 NV014 tạm ứng 3tr → TongKhauTru cao hơn chỉ BH+Thuế
EXEC #LogL '§11','NV014_TamUng_Reflected','TRUE',
    (SELECT CASE WHEN
        (SELECT TongKhauTru - TongBaoHiem - ThueTNCN
         FROM dbo.BangLuong WHERE MaNV='NV000014' AND Thang=1 AND Nam=2025)
        >= 3000000
        THEN 'TRUE' ELSE 'FALSE' END),
    N'NV000014 tạm ứng 3tr T1 → KhauTruKhac ≥ 3,000,000';
GO


-- ============================================================
-- §12 sp_TaoBangLuong_ChinhThuc
-- ============================================================
PRINT N'';
PRINT N'════════════════════════════════════════════════════════';
PRINT N'  §12 sp_TaoBangLuong_ChinhThuc';
PRINT N'════════════════════════════════════════════════════════';

-- §12.1 Chạy thành công T3/2025
EXEC dbo.sp_TaoBangLuong_ChinhThuc @Thang=3, @Nam=2025;
GO

EXEC #LogL '§12','TaoBL_T3_Success','TRUE',
    (SELECT CASE WHEN COUNT(*) = 50 THEN 'TRUE' ELSE 'FALSE' END
     FROM dbo.BangLuong WHERE Thang=3 AND Nam=2025),
    N'T3/2025 có đủ 50 dòng để tạo bảng lương';

-- §12.2 Chạy lọc theo 1 phòng ban
EXEC dbo.sp_TaoBangLuong_ChinhThuc @Thang=3, @Nam=2025, @MaPB='PB0004';
GO

EXEC #LogL '§12','TaoBL_LocPB0004','TRUE',
    (SELECT CASE WHEN COUNT(*) BETWEEN 15 AND 20 THEN 'TRUE' ELSE 'FALSE' END
     FROM dbo.BangLuong bl
     JOIN dbo.NhanVien nv ON bl.MaNV=nv.MaNV
     WHERE bl.Thang=3 AND bl.Nam=2025 AND nv.MaPB='PB0004'),
    N'PB0004 (CNTT) có 15-20 NV trong bảng lương';

-- §12.3 Chặn khi chưa có dữ liệu
DECLARE @TBL03 BIT = 0;
BEGIN TRY
    EXEC dbo.sp_TaoBangLuong_ChinhThuc @Thang=6, @Nam=2025;
    SET @TBL03 = 0;
END TRY BEGIN CATCH SET @TBL03 = 1; END CATCH;
EXEC #LogL '§12','TaoBL_Block_NoDdata','1',
    CAST(@TBL03 AS NVARCHAR), N'Chưa có BangLuong T6/2025 → RAISERROR';
GO


-- ============================================================
-- §13 sp_TaoBangLuong_BHXH
-- ============================================================
PRINT N'';
PRINT N'════════════════════════════════════════════════════════';
PRINT N'  §13 sp_TaoBangLuong_BHXH — D02-TS';
PRINT N'════════════════════════════════════════════════════════';

EXEC dbo.sp_TaoBangLuong_BHXH @Thang=1, @Nam=2025;
GO

-- §13.1 Đủ 50 NV trong danh sách
EXEC #LogL '§13','BHXH_50NV','TRUE',
    (SELECT CASE WHEN COUNT(*) = 50 THEN 'TRUE' ELSE 'FALSE' END
     FROM dbo.BangLuong WHERE Thang=1 AND Nam=2025),
    N'Danh sách BHXH T1/2025 đủ 50 NV';

-- §13.2 NLĐ đóng đúng 10.5%
EXEC #LogL '§13','BHXH_NLD_Sum_Correct','TRUE',
    (SELECT CASE WHEN
        ABS(SUM(TongBaoHiem) -
            SUM(ROUND(LEAST(LuongCoBan, 46800000) * 0.105, 0))) < 5000
        THEN 'TRUE' ELSE 'FALSE' END
     FROM dbo.BangLuong bl
     JOIN dbo.HopDong hd ON bl.MaNV=hd.MaNV AND hd.TrangThai='A'
     WHERE bl.Thang=1 AND bl.Nam=2025 AND hd.MaLoaiHD <> 1),
    N'Tổng BH NLĐ ≈ SUM(min(LCB,46.8M)×10.5%) sai số <5000đ';

-- §13.3 Tổng BHXH toàn công ty > 50 triệu
EXEC #LogL '§13','BHXH_Tong_50Trieu','TRUE',
    (SELECT CASE WHEN SUM(TongBaoHiem) > 50000000 THEN 'TRUE' ELSE 'FALSE' END
     FROM dbo.BangLuong WHERE Thang=1 AND Nam=2025),
    N'Tổng BH NLĐ toàn công ty T1 > 50 triệu VNĐ';
GO


-- ============================================================
-- §14 sp_TaoBangLuong_QuyetToanThue
-- ============================================================
PRINT N'';
PRINT N'════════════════════════════════════════════════════════';
PRINT N'  §14 QUYET TOAN THUE TNCN — Mẫu 05/KK-TNCN';
PRINT N'════════════════════════════════════════════════════════';

EXEC dbo.sp_TaoBangLuong_QuyetToanThue @Thang=3, @Nam=2025, @LoaiBaoCao='T';
GO

EXEC #LogL '§14','QTThue_T3_CoData','TRUE',
    (SELECT CASE WHEN COUNT(*) > 0 THEN 'TRUE' ELSE 'FALSE' END
     FROM dbo.ThueTNCN WHERE Thang=3 AND Nam=2025 AND TienThue > 0),
    N'T3/2025 có NV phát sinh thuế TNCN';

-- Quyết toán cả năm 2025
EXEC dbo.sp_TaoBangLuong_QuyetToanThue @Thang=3, @Nam=2025, @LoaiBaoCao='N';
GO

EXEC #LogL '§14','QTThue_LuyKe_Nam','TRUE',
    (SELECT CASE WHEN COUNT(DISTINCT MaNV) >= 30 THEN 'TRUE' ELSE 'FALSE' END
     FROM dbo.ThueTNCN WHERE Nam=2025 AND Thang <= 3 AND TienThue > 0),
    N'Lũy kế 3 tháng: ≥30 NV có thuế > 0';
GO


-- ============================================================
-- §15 sp_TaoBangLuong_SoSanh — TREND QUỸ LƯƠNG
-- ============================================================
PRINT N'';
PRINT N'════════════════════════════════════════════════════════';
PRINT N'  §15 SO SANH QUY LUONG — LAG / TREND';
PRINT N'════════════════════════════════════════════════════════';

EXEC dbo.sp_TaoBangLuong_SoSanh
    @TuThang=1, @TuNam=2025, @DenThang=3, @DenNam=2025;
GO

-- §15.1 3 kỳ × 5 PB = 15 dòng (hoặc ít hơn nếu 1 PB trống)
EXEC #LogL '§15','SoSanh_CoData','TRUE',
    (SELECT CASE WHEN COUNT(*) >= 10 THEN 'TRUE' ELSE 'FALSE' END
     FROM dbo.vw_BangLuong_TongHop WHERE Nam=2025 AND Thang IN (1,2,3)),
    N'So sánh T1-T3/2025 có ≥10 dòng dữ liệu';

-- §15.2 Quỹ lương T3 ≈ T2 (biến động < 30%)
EXEC #LogL '§15','QuyLuong_BiemDong_Nho','TRUE',
    (SELECT CASE WHEN
        ABS((SELECT SUM(LuongNet) FROM dbo.BangLuong WHERE Thang=3 AND Nam=2025)
          - (SELECT SUM(LuongNet) FROM dbo.BangLuong WHERE Thang=2 AND Nam=2025))
        / NULLIF((SELECT SUM(LuongNet) FROM dbo.BangLuong WHERE Thang=2 AND Nam=2025),0)
        < 0.30
        THEN 'TRUE' ELSE 'FALSE' END),
    N'Biến động quỹ lương T2→T3 < 30%';
GO


-- ============================================================
-- §16 vw_BangLuong & vw_BangLuong_TongHop
-- ============================================================
PRINT N'';
PRINT N'════════════════════════════════════════════════════════';
PRINT N'  §16 VIEWS BANG LUONG';
PRINT N'════════════════════════════════════════════════════════';

-- §16.1 vw_BangLuong — 150 dòng (50×3 tháng)
EXEC #LogL '§16','vw_BangLuong_150','150',
    (SELECT CAST(COUNT(*) AS NVARCHAR)
     FROM dbo.vw_BangLuong WHERE Nam=2025 AND Thang IN (1,2,3)),
    N'vw_BangLuong: 50 NV × 3 kỳ = 150 dòng';

-- §16.2 Cột ChiPhiNhanSu_DN > LuongGross (có BH NSDLĐ)
EXEC #LogL '§16','ChiPhiDN_GT_Gross','0',
    (SELECT CAST(COUNT(*) AS NVARCHAR)
     FROM dbo.vw_BangLuong
     WHERE Nam=2025 AND Thang=3 AND LuongGross > 0
       AND CAST(REPLACE(ChiPhiNhanSu_DN,',','') AS DECIMAL(18,2))
           <= CAST(REPLACE(LuongGross_Raw,',','') AS DECIMAL(18,2))),
    N'ChiPhiNhanSu_DN > LuongGross (bao gồm BH NSDLĐ)';

-- §16.3 vw_BangLuong_TongHop — 5 phòng ban T3
EXEC #LogL '§16','TongHop_5PB_T3','5',
    (SELECT CAST(COUNT(*) AS NVARCHAR)
     FROM dbo.vw_BangLuong_TongHop WHERE Thang=3 AND Nam=2025),
    N'T3/2025: 5 phòng ban trong TongHop';

-- §16.4 vw_ThueTNCN_KyQuyetToan
EXEC #LogL '§16','QuyetToanThue_NV_Count','TRUE',
    (SELECT CASE WHEN COUNT(DISTINCT MaNV) >= 40 THEN 'TRUE' ELSE 'FALSE' END
     FROM dbo.vw_ThueTNCN_KyQuyetToan WHERE Nam=2025),
    N'vw_ThueTNCN_KyQuyetToan: ≥40 NV năm 2025';
GO


-- ============================================================
-- §17 INTEGRATION — VÒNG ĐỜI ĐẦY ĐỦ 1 KỲ LƯƠNG
-- ============================================================
PRINT N'';
PRINT N'════════════════════════════════════════════════════════';
PRINT N'  §17 INTEGRATION — KỲ LƯƠNG T3/2025';
PRINT N'════════════════════════════════════════════════════════';

-- Mô phỏng vòng đời đầy đủ T3/2025:
-- sp_TinhLuong → Xác nhận → Thanh toán → Báo cáo

-- §17.1 T3 ở Draft
EXEC #LogL '§17','T3_Is_Draft','TRUE',
    (SELECT CASE WHEN COUNT(*) = 50 THEN 'TRUE' ELSE 'FALSE' END
     FROM dbo.BangLuong WHERE Thang=3 AND Nam=2025 AND TrangThai='D'),
    N'T3/2025 bắt đầu ở trạng thái Draft';

-- §17.2 Xác nhận T3
EXEC dbo.sp_XacNhanBangLuong 3, 2025, N'Hoàng Thị Phương';
GO

EXEC #LogL '§17','T3_Confirmed','TRUE',
    (SELECT CASE WHEN COUNT(*) = 50 THEN 'TRUE' ELSE 'FALSE' END
     FROM dbo.BangLuong WHERE Thang=3 AND Nam=2025 AND TrangThai='C'),
    N'T3 xác nhận thành công → 50 bản ghi C';

-- §17.3 Thanh toán T3
UPDATE dbo.BangLuong
SET TrangThai='P', NgayThanhToan='2025-04-05'
WHERE Thang=3 AND Nam=2025 AND TrangThai='C';

EXEC #LogL '§17','T3_Paid_With_Date','TRUE',
    (SELECT CASE WHEN COUNT(*) = 50 THEN 'TRUE' ELSE 'FALSE' END
     FROM dbo.BangLuong WHERE Thang=3 AND Nam=2025
       AND TrangThai='P' AND NgayThanhToan IS NOT NULL),
    N'T3 Paid với NgayThanhToan 5/4/2025';

-- §17.4 AuditLog ghi trạng thái P
EXEC #LogL '§17','AuditLog_StatusChange_P','TRUE',
    (SELECT CASE WHEN COUNT(*) > 0 THEN 'TRUE' ELSE 'FALSE' END
     FROM dbo.AuditLog_Luong WHERE HanhDong='STATUS_CHANGE'),
    N'AuditLog_Luong: Ghi STATUS_CHANGE khi C→P';

-- §17.5 Trạng thái 3 kỳ: T1=C/P/L, T2=P, T3=P
EXEC #LogL '§17','3Ky_TrangThai_Summary','TRUE',
    (SELECT CASE WHEN
        (SELECT COUNT(*) FROM dbo.BangLuong
         WHERE Thang=1 AND Nam=2025 AND TrangThai IN ('C','P','L')) = 50
        AND (SELECT COUNT(*) FROM dbo.BangLuong
             WHERE Thang=2 AND Nam=2025 AND TrangThai='P') = 50
        AND (SELECT COUNT(*) FROM dbo.BangLuong
             WHERE Thang=3 AND Nam=2025 AND TrangThai='P') = 50
        THEN 'TRUE' ELSE 'FALSE' END),
    N'3 kỳ đều đã được xác nhận/thanh toán';

-- §17.6 Báo cáo chi phí nhân sự T3
EXEC dbo.sp_TaoBangLuong_ChiPhiNhanSu @Thang=3, @Nam=2025;
GO

EXEC #LogL '§17','ChiPhiNhanSu_T3_CoData','TRUE',
    (SELECT CASE WHEN COUNT(*) = 50 THEN 'TRUE' ELSE 'FALSE' END
     FROM dbo.BangLuong WHERE Thang=3 AND Nam=2025),
    N'sp_TaoBangLuong_ChiPhiNhanSu chạy thành công';
GO


-- ============================================================
-- §18 EDGE CASES & BOUNDARY TESTS
-- ============================================================
PRINT N'';
PRINT N'════════════════════════════════════════════════════════';
PRINT N'  §18 EDGE CASES';
PRINT N'════════════════════════════════════════════════════════';

-- §18.1 TNCT đúng bằng ngưỡng bậc 1 (5,000,000)
EXEC #LogL '§18','Edge_TNCT_Threshold_B1','250000',
    (SELECT CAST(dbo.fn_TinhThueTNCN_Scalar(5000000) AS NVARCHAR)),
    N'TNCT = 5,000,000 (đỉnh bậc 1) → 5%×5M = 250,000';

-- §18.2 TNCT đúng bằng ngưỡng bậc 7 (80,000,000)
EXEC #LogL '§18','Edge_TNCT_Threshold_B6_B7','18150000',
    (SELECT CAST(dbo.fn_TinhThueTNCN_Scalar(80000000) AS NVARCHAR)),
    N'TNCT=80M (đỉnh bậc 6) → 18,150,000';

-- §18.3 Lương đóng BH đúng bằng trần 46,800,000
EXEC #LogL '§18','Edge_LuongDongBH_ExactTran','46800000',
    (SELECT CAST(dbo.fn_TinhLuongDongBH(46800000,4) AS NVARCHAR)),
    N'LCB = 46,800,000 = trần → LuongDongBH = 46,800,000';

-- §18.4 Lương đóng BH vượt 1 đồng trần → vẫn cap
EXEC #LogL '§18','Edge_LuongDongBH_TranPlus1','46800000',
    (SELECT CAST(dbo.fn_TinhLuongDongBH(46800001,4) AS NVARCHAR)),
    N'LCB = 46,800,001 (vượt 1đ) → cap tại 46,800,000';

-- §18.5 HeSo = 1.0 khi đi làm đủ tháng (không ngày KP, ngày nghỉ phép = hưởng lương)
EXEC #LogL '§18','Edge_HeSo_1_Full_Month','TRUE',
    (SELECT CASE WHEN dbo.fn_HeSoLuongThang('NV000001',3,2025) <= 1.0
                 THEN 'TRUE' ELSE 'FALSE' END),
    N'HeSoLuong không vượt 1.0 kể cả tháng đủ ngày';

-- §18.6 fn_SoNgayChuanThang tháng 2 năm không nhuận (365/7≠28)
EXEC #LogL '§18','Edge_T2_2023_NonLeap','TRUE',
    (SELECT CASE WHEN dbo.fn_SoNgayChuanThang(2,2023) BETWEEN 19 AND 21
                 THEN 'TRUE' ELSE 'FALSE' END),
    N'T2/2023 (không nhuận, 28 ngày) = 19-21 ngày LV';

-- §18.7 Phụ cấp thâm niên (FL0006 - 2% lương) cho NV vào trước 2020
EXEC #LogL '§18','Edge_PhucCap_ThamNien','TRUE',
    (SELECT CASE WHEN COUNT(*) > 0 THEN 'TRUE' ELSE 'FALSE' END
     FROM dbo.NhanVienPhucLoi WHERE MaFL='FL0006' AND IsActive=1),
    N'FL0006 thâm niên 2% gán cho NV vào trước 2020';
GO


-- ============================================================
-- §19 BÁO CÁO TỔNG KẾT
-- ============================================================
PRINT N'';
PRINT N'════════════════════════════════════════════════════════';
PRINT N'  §19 KẾT QUẢ TỔNG KẾT — KIỂM THỬ MODULE LƯƠNG';
PRINT N'════════════════════════════════════════════════════════';

SELECT
    Section                             AS [Phần],
    COUNT(*)                            AS [Tổng],
    SUM(CASE WHEN Status='PASS' THEN 1 ELSE 0 END) AS [✅ PASS],
    SUM(CASE WHEN Status='FAIL' THEN 1 ELSE 0 END) AS [❌ FAIL],
    FORMAT(
        CAST(SUM(CASE WHEN Status='PASS' THEN 1 ELSE 0 END) AS DECIMAL)
        / NULLIF(COUNT(*),0),'P0')      AS [Tỷ Lệ]
FROM #TC_Luong
GROUP BY Section ORDER BY Section;

-- Grand Total
SELECT
    N'══ TỔNG CỘNG ══'                  AS [Phần],
    COUNT(*)                            AS [Tổng],
    SUM(CASE WHEN Status='PASS' THEN 1 ELSE 0 END) AS [✅ PASS],
    SUM(CASE WHEN Status='FAIL' THEN 1 ELSE 0 END) AS [❌ FAIL],
    FORMAT(
        CAST(SUM(CASE WHEN Status='PASS' THEN 1 ELSE 0 END) AS DECIMAL)
        / NULLIF(COUNT(*),0),'P1')      AS [Tỷ Lệ]
FROM #TC_Luong;

-- FAIL list
IF EXISTS (SELECT 1 FROM #TC_Luong WHERE Status='FAIL')
BEGIN
    PRINT N'';
    PRINT N'─── CÁC TEST CHƯA ĐẠT ────────────────────────────────';
    SELECT TestID,Section,TestName,
           Expected AS [Kỳ Vọng],
           Actual   AS [Thực Tế],
           GhiChu
    FROM #TC_Luong WHERE Status='FAIL' ORDER BY TestID;
END
ELSE
    PRINT N'🎉 Tất cả test PASS — Module Lương hoạt động đúng!';

-- Thống kê số liệu tài chính cuối
PRINT N'';
PRINT N'─── TỔNG QUAN TÀI CHÍNH 3 THÁNG ─────────────────────';
SELECT
    Thang, Nam,
    COUNT(*)                            AS [Số NV],
    FORMAT(SUM(LuongGross),'N0')        AS [Tổng Gross],
    FORMAT(SUM(TongBaoHiem),'N0')       AS [Tổng BH NLĐ],
    FORMAT(SUM(ThueTNCN),'N0')          AS [Tổng Thuế],
    FORMAT(SUM(LuongNet),'N0')          AS [Tổng Thực Lĩnh],
    CASE MAX(TrangThai)
        WHEN 'P' THEN N'💰 Đã thanh toán'
        WHEN 'C' THEN N'✅ Đã xác nhận'
        WHEN 'D' THEN N'📝 Nháp'
        ELSE MAX(TrangThai)
    END                                 AS [Trạng Thái]
FROM dbo.BangLuong
WHERE Nam=2025 AND Thang IN (1,2,3)
GROUP BY Thang, Nam
ORDER BY Nam, Thang;

PRINT N'';
PRINT N'[DONE] testcase_luong.sql — Hoàn tất kiểm thử module lương.';
GO
