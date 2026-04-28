USE msdb;
GO

EXEC dbo.sp_add_alert @name = N'ALERT_DEADLOCK', 
    @message_id = 0, 
    @severity = 0, 
    @enabled = 1, 
    @delay_between_responses = 60, 
    @include_event_description_in = 1, 
    @category_name = N'[Uncategorized]', 
    @performance_condition = N'SQLServer:Locks|Number of Deadlocks/sec|_Total|>|0';

EXEC dbo.sp_add_notification @alert_name = N'ALERT_DEADLOCK', @operator_name = N'DBA_Team', @notification_method = 1;
GO

EXEC dbo.sp_add_alert @name = N'ALERT_BLOCKED_PROCESS', 
    @message_id = 0, 
    @severity = 0, 
    @enabled = 1, 
    @delay_between_responses = 60, 
    @include_event_description_in = 1, 
    @category_name = N'[Uncategorized]', 
    @performance_condition = N'SQLServer:General Statistics|Processes blocked||>|0';

EXEC dbo.sp_add_notification @alert_name = N'ALERT_BLOCKED_PROCESS', @operator_name = N'DBA_Team', @notification_method = 1;
GO

IF OBJECT_ID('dbo.BACKUP_AUDIT_LOG') IS NULL
BEGIN
    CREATE TABLE dbo.BACKUP_AUDIT_LOG (
        LogID INT IDENTITY(1,1) PRIMARY KEY,
        DatabaseName SYSNAME,
        BackupType CHAR(1),
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
    INSERT INTO dbo.BACKUP_AUDIT_LOG (DatabaseName, BackupType, Status)
    SELECT 
        database_name, 
        type, 
        CASE WHEN backup_finish_date IS NOT NULL THEN 'SUCCESS' ELSE 'FAILURE' END
    FROM msdb.dbo.backupset
    WHERE backup_finish_date > DATEADD(hh, -24, GETDATE());
END
GO

EXEC dbo.sp_add_job @job_name = N'AUDIT_BACKUP_SUCCESS', @enabled = 1;
EXEC dbo.sp_add_jobstep @job_name = N'AUDIT_BACKUP_SUCCESS', @step_name = N'RunAudit',
    @command = N'EXEC msdb.dbo.SP_AUDIT_BACKUPS',
    @database_name = N'msdb';
EXEC dbo.sp_add_jobschedule @job_name = N'AUDIT_BACKUP_SUCCESS', @name = N'Daily_Audit', @freq_type = 4, @freq_interval = 1, @active_start_time = 050000;

EXEC dbo.sp_add_jobserver @job_name = N'AUDIT_BACKUP_SUCCESS', @server_name = N'(LOCAL)';
GO
