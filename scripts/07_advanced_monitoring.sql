USE [master];
GO

/* 1) PERFORMANCE TUNING: Capture and analyze blocked processes */
IF EXISTS (SELECT 1 FROM sys.server_event_sessions WHERE name = N'CaptureBlocks')
    DROP EVENT SESSION CaptureBlocks ON SERVER;
GO
CREATE EVENT SESSION CaptureBlocks ON SERVER
ADD EVENT sqlserver.blocked_process_report
ADD TARGET package0.event_file(SET filename = N'/var/opt/mssql/data/Blocks.xel')
WITH (STARTUP_STATE = ON);
GO

ALTER EVENT SESSION CaptureBlocks ON SERVER STATE = START;
GO

USE msdb;
GO

/* 2) BACKUP AUDIT LOGGING */
IF OBJECT_ID('dbo.BACKUP_AUDIT_LOG') IS NULL
BEGIN
    CREATE TABLE dbo.BACKUP_AUDIT_LOG (
        LogID INT IDENTITY(1,1) PRIMARY KEY,
        JobName SYSNAME,
        Status NVARCHAR(50),
        ExecutionDate DATETIME DEFAULT GETDATE()
    );
END
GO

IF EXISTS (SELECT * FROM sys.objects WHERE name = 'SP_AUDIT_BACKUPS') DROP PROCEDURE dbo.SP_AUDIT_BACKUPS;
GO

CREATE PROCEDURE dbo.SP_AUDIT_BACKUPS
AS
BEGIN
    INSERT INTO dbo.BACKUP_AUDIT_LOG (JobName, Status)
    SELECT 
        j.name, 
        CASE h.run_status 
            WHEN 0 THEN 'FAILURE' 
            WHEN 1 THEN 'SUCCESS' 
            WHEN 2 THEN 'RETRY' 
            WHEN 3 THEN 'CANCELED' 
            ELSE 'UNKNOWN' 
        END
    FROM msdb.dbo.sysjobhistory h
    JOIN msdb.dbo.sysjobs j ON h.job_id = j.job_id
    WHERE j.name LIKE '%Backup%' 
      AND h.step_id = 0 -- Step 0 is the overall job outcome
      AND msdb.dbo.agent_datetime(h.run_date, h.run_time) > DATEADD(hh, -24, GETDATE());
END
GO

EXEC dbo.sp_add_job @job_name = N'AUDIT_BACKUP_SUCCESS', @enabled = 1;
EXEC dbo.sp_add_jobstep @job_name = N'AUDIT_BACKUP_SUCCESS', @step_name = N'RunAudit',
    @command = N'EXEC msdb.dbo.SP_AUDIT_BACKUPS',
    @database_name = N'msdb';
EXEC dbo.sp_add_jobschedule @job_name = N'AUDIT_BACKUP_SUCCESS', @name = N'Daily_Audit', @freq_type = 4, @freq_interval = 1, @active_start_time = 050000;

EXEC dbo.sp_add_jobserver @job_name = N'AUDIT_BACKUP_SUCCESS', @server_name = N'(LOCAL)';
GO
