USE hrpayrolldb;

UPDATE LuongCoBan 
SET LuongCB = 80000000 
WHERE MaNV = 'NV000001' AND NgayHetHieuLuc IS NULL;