IF NOT EXISTS (SELECT * FROM sys.databases WHERE name = 'CoreDB')
BEGIN
    CREATE DATABASE CoreDB;
END
GO

ALTER DATABASE CoreDB SET RECOVERY FULL;
GO

IF NOT EXISTS (SELECT * FROM sys.databases WHERE name = 'StagingDB')
BEGIN
    CREATE DATABASE StagingDB;
END
GO

ALTER DATABASE StagingDB SET RECOVERY SIMPLE;
GO

USE CoreDB;
GO

IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'HR')
BEGIN
    EXEC('CREATE SCHEMA HR');
END
GO

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[HR].[Employees]') AND type in (N'U'))
BEGIN
    CREATE TABLE HR.Employees (
        EmployeeID INT PRIMARY KEY IDENTITY(1,1),
        FirstName NVARCHAR(50),
        LastName NVARCHAR(50),
        Email NVARCHAR(100),
        Salary DECIMAL(18, 2),
        HireDate DATE DEFAULT GETDATE()
    );
END
GO

EXEC sys.sp_addextendedproperty 
    @name = N'Tier', 
    @value = N'Hot';
GO

USE StagingDB;
GO
EXEC sys.sp_addextendedproperty 
    @name = N'Tier', 
    @value = N'Cold';
GO
