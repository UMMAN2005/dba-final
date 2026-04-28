USE [master]
GO

IF EXISTS (SELECT * FROM sys.servers WHERE name = 'SECONDARY_NODE')
    EXEC master.dbo.sp_dropserver @server=N'SECONDARY_NODE', @droplogins='rdroplogins'
GO

EXEC master.dbo.sp_addlinkedserver 
    @server=N'SECONDARY_NODE', 
    @srvproduct=N'', 
    @provider=N'SQLNCLI', 
    @datasrc=N'dba_secondary';

EXEC master.dbo.sp_addlinkedsrvlogin 
    @rmtsrvname=N'SECONDARY_NODE', 
    @useself=N'False', 
    @locallogin=NULL, 
    @rmtuser=N'sa', 
    @rmtpassword=N'StrongP@ssw0rd!2026';
GO

USE msdb;
GO

EXEC dbo.sp_add_job @job_name = N'REPLICATION_30MIN_SYNC', @enabled = 1;

EXEC dbo.sp_add_jobstep @job_name = N'REPLICATION_30MIN_SYNC', @step_name = N'SyncStep',
    @command = N'
    INSERT INTO SECONDARY_NODE.ReportDB.dbo.Employees_Sync (EmployeeID, FirstName, LastName, Email, Salary)
    SELECT EmployeeID, FirstName, LastName, Email, Salary 
    FROM CoreDB.HR.Employees AS src
    WHERE NOT EXISTS (SELECT 1 FROM SECONDARY_NODE.ReportDB.dbo.Employees_Sync AS tgt WHERE tgt.EmployeeID = src.EmployeeID);
    ',
    @on_success_action = 1;

EXEC dbo.sp_add_jobschedule @job_name = N'REPLICATION_30MIN_SYNC', @name = N'Sched_30MIN', 
    @freq_type = 4, @freq_interval = 1, @freq_subday_type = 4, @freq_subday_interval = 30;

EXEC dbo.sp_add_jobserver @job_name = N'REPLICATION_30MIN_SYNC', @server_name = N'(LOCAL)';
GO
