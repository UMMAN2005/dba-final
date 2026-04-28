IF NOT EXISTS (SELECT * FROM sys.databases WHERE name = 'ReportDB')
BEGIN
    CREATE DATABASE ReportDB;
END
GO

ALTER DATABASE ReportDB SET RECOVERY SIMPLE;
GO

USE ReportDB;
GO
EXEC sys.sp_addextendedproperty 
    @name = N'Tier', 
    @value = N'Archive';
GO
