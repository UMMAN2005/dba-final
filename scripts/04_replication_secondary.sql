USE [master]
GO

IF EXISTS (SELECT * FROM sys.servers WHERE name = 'PRIMARY_NODE')
    EXEC master.dbo.sp_dropserver @server=N'PRIMARY_NODE', @droplogins='rdroplogins'
GO

EXEC master.dbo.sp_addlinkedserver 
    @server=N'PRIMARY_NODE', 
    @srvproduct=N'', 
    @provider=N'SQLNCLI', 
    @datasrc=N'dba_primary';

EXEC master.dbo.sp_addlinkedsrvlogin 
    @rmtsrvname=N'PRIMARY_NODE', 
    @useself=N'False', 
    @locallogin=NULL, 
    @rmtuser=N'sa', 
    @rmtpassword=N'StrongP@ssw0rd!2026';
GO

USE ReportDB;
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Employees_Sync]') AND type in (N'U'))
BEGIN
    CREATE TABLE dbo.Employees_Sync (
        EmployeeID INT PRIMARY KEY,
        FirstName NVARCHAR(50),
        LastName NVARCHAR(50),
        Email NVARCHAR(100),
        Salary DECIMAL(18, 2)
    );
END
GO

USE msdb;
GO

EXEC dbo.sp_add_job @job_name = N'MIDNIGHT_DATA_FLOW', @enabled = 1;

EXEC dbo.sp_add_jobstep @job_name = N'MIDNIGHT_DATA_FLOW', @step_name = N'TRANSFORM',
    @command = N'
    WAITFOR DELAY ''00:00:05''; 
    IF OBJECT_ID(''ReportDB.dbo.SalaryMetrics'') IS NOT NULL DROP TABLE ReportDB.dbo.SalaryMetrics;
    SELECT AVG(Salary) as AvgSalary INTO ReportDB.dbo.SalaryMetrics FROM ReportDB.dbo.Employees_Sync;
    ',
    @on_success_action = 3;

EXEC dbo.sp_add_jobstep @job_name = N'MIDNIGHT_DATA_FLOW', @step_name = N'REVERSE_SYNC',
    @command = N'
    IF OBJECT_ID(''PRIMARY_NODE.CoreDB.dbo.FinalizedReport'') IS NOT NULL DROP TABLE PRIMARY_NODE.CoreDB.dbo.FinalizedReport;
    SELECT * INTO PRIMARY_NODE.CoreDB.dbo.FinalizedReport FROM ReportDB.dbo.SalaryMetrics;
    ',
    @on_success_action = 1;

EXEC dbo.sp_add_jobschedule @job_name = N'MIDNIGHT_DATA_FLOW', @name = N'Sched_Daily_00', 
    @freq_type = 4, @freq_interval = 1, @active_start_time = 000000;

EXEC dbo.sp_add_jobserver @job_name = N'MIDNIGHT_DATA_FLOW', @server_name = N'(LOCAL)';
GO
