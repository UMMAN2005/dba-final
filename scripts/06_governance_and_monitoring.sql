USE [master];
GO

/* 1) DEPLOY USER + RESOURCE GOVERNOR (workload limiting) */
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'deploy_user')
    CREATE LOGIN deploy_user WITH PASSWORD = 'StrongP@ssw0rd!2026';
GO

-- Using CAP_CPU_PERCENT to enforce a hard limit (SQL 2012+)
IF NOT EXISTS (SELECT 1 FROM sys.resource_governor_resource_pools WHERE name = N'ReportPool')
    CREATE RESOURCE POOL ReportPool WITH (
        MAX_CPU_PERCENT = 20, 
        CAP_CPU_PERCENT = 20, 
        MAX_MEMORY_PERCENT = 20
    );
ELSE
    ALTER RESOURCE POOL ReportPool WITH (
        MAX_CPU_PERCENT = 20, 
        CAP_CPU_PERCENT = 20, 
        MAX_MEMORY_PERCENT = 20
    );
GO

IF NOT EXISTS (SELECT 1 FROM sys.resource_governor_workload_groups WHERE name = N'DeployGroup')
    CREATE WORKLOAD GROUP DeployGroup USING ReportPool;
GO

IF OBJECT_ID(N'dbo.RG_Classifier', N'FN') IS NOT NULL
    DROP FUNCTION dbo.RG_Classifier;
GO

CREATE FUNCTION dbo.RG_Classifier()
RETURNS SYSNAME WITH SCHEMABINDING
AS
BEGIN
    DECLARE @CurrTime TIME = CAST(GETDATE() AS TIME);

    -- Redirect deploy_user to ReportPool during the midnight hour
    IF SUSER_SNAME() = N'deploy_user'
       AND @CurrTime >= '00:00:00' AND @CurrTime < '01:00:00'
        RETURN N'DeployGroup';

    RETURN N'default';
END;
GO

ALTER RESOURCE GOVERNOR WITH (CLASSIFIER_FUNCTION = dbo.RG_Classifier);
ALTER RESOURCE GOVERNOR RECONFIGURE;
GO

/* 2) RESTRICT deploy_user ONLY ON ReportDB (00:00-01:00) */
IF DB_ID(N'ReportDB') IS NOT NULL
BEGIN
    EXEC(N'USE ReportDB;
          IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N''deploy_user'')
              CREATE USER deploy_user FOR LOGIN deploy_user;');
END
GO

USE [master];
GO

IF OBJECT_ID(N'SP_RESTRICT_REPORTDB_DEPLOY_USER', N'P') IS NOT NULL
    DROP PROCEDURE SP_RESTRICT_REPORTDB_DEPLOY_USER;
GO

CREATE PROCEDURE SP_RESTRICT_REPORTDB_DEPLOY_USER
AS
BEGIN
    SET NOCOUNT ON;
    IF DB_ID(N'ReportDB') IS NULL RETURN;

    EXEC(N'USE ReportDB; DENY CONNECT TO deploy_user;');

    -- Kill existing connections for the restricted user
    DECLARE @KillCmd NVARCHAR(MAX) = N'';
    SELECT @KillCmd += N'KILL ' + CAST(spid AS NVARCHAR(10)) + N';'
    FROM master.dbo.sysprocesses
    WHERE loginame = N'deploy_user' AND DB_NAME(dbid) = N'ReportDB' AND spid <> @@SPID;

    IF LEN(@KillCmd) > 0 EXEC(@KillCmd);
END;
GO

IF OBJECT_ID(N'SP_ALLOW_REPORTDB_DEPLOY_USER', N'P') IS NOT NULL
    DROP PROCEDURE SP_ALLOW_REPORTDB_DEPLOY_USER;
GO

CREATE PROCEDURE SP_ALLOW_REPORTDB_DEPLOY_USER
AS
BEGIN
    SET NOCOUNT ON;
    IF DB_ID(N'ReportDB') IS NULL RETURN;
    EXEC(N'USE ReportDB; GRANT CONNECT TO deploy_user;');
END;
GO

USE [msdb];
GO

IF EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name = N'RESTRICT_DEPLOY_USER_REPORTDB')
    EXEC msdb.dbo.sp_delete_job @job_name = N'RESTRICT_DEPLOY_USER_REPORTDB';
GO
EXEC msdb.dbo.sp_add_job @job_name = N'RESTRICT_DEPLOY_USER_REPORTDB', @enabled = 1;
EXEC msdb.dbo.sp_add_jobstep @job_name = N'RESTRICT_DEPLOY_USER_REPORTDB', @step_name = N'DenyConnect', @command = N'EXEC master.dbo.SP_RESTRICT_REPORTDB_DEPLOY_USER;';
EXEC msdb.dbo.sp_add_jobschedule @job_name = N'RESTRICT_DEPLOY_USER_REPORTDB', @name = N'At_00_00', @freq_type = 4, @freq_interval = 1, @active_start_time = 000000;
EXEC msdb.dbo.sp_add_jobserver @job_name = N'RESTRICT_DEPLOY_USER_REPORTDB', @server_name = N'(LOCAL)';
GO

IF EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name = N'ALLOW_DEPLOY_USER_REPORTDB')
    EXEC msdb.dbo.sp_delete_job @job_name = N'ALLOW_DEPLOY_USER_REPORTDB';
GO
EXEC msdb.dbo.sp_add_job @job_name = N'ALLOW_DEPLOY_USER_REPORTDB', @enabled = 1;
EXEC msdb.dbo.sp_add_jobstep @job_name = N'ALLOW_DEPLOY_USER_REPORTDB', @step_name = N'GrantConnect', @command = N'EXEC master.dbo.SP_ALLOW_REPORTDB_DEPLOY_USER;';
EXEC msdb.dbo.sp_add_jobschedule @job_name = N'ALLOW_DEPLOY_USER_REPORTDB', @name = N'At_01_00', @freq_type = 4, @freq_interval = 1, @active_start_time = 010000;
EXEC msdb.dbo.sp_add_jobserver @job_name = N'ALLOW_DEPLOY_USER_REPORTDB', @server_name = N'(LOCAL)';
GO

/* 3) INCIDENT TRACKING: deadlocks (real-time capture) */
USE [master];
GO
EXEC sp_configure 'show advanced options', 1; RECONFIGURE;
EXEC sp_configure 'blocked process threshold', 5; RECONFIGURE;
GO

IF EXISTS (SELECT 1 FROM sys.server_event_sessions WHERE name = N'CaptureDeadlocks')
    DROP EVENT SESSION CaptureDeadlocks ON SERVER;
GO
CREATE EVENT SESSION CaptureDeadlocks ON SERVER
ADD EVENT sqlserver.xml_deadlock_report
ADD TARGET package0.event_file(SET filename = N'/var/opt/mssql/data/Deadlocks.xel')
WITH (STARTUP_STATE = ON);
GO

ALTER EVENT SESSION CaptureDeadlocks ON SERVER STATE = START;
GO

/* 4) EMAIL ALERTS TO ADMIN OPERATOR (DBA_Team) */
USE [msdb];
GO

-- Alert for Deadlocks (Error 1205 is more reliable than performance counters)
IF EXISTS (SELECT 1 FROM msdb.dbo.sysalerts WHERE name = N'ALERT_DEADLOCK')
    EXEC msdb.dbo.sp_delete_alert @name = N'ALERT_DEADLOCK';
GO
EXEC msdb.dbo.sp_add_alert
    @name = N'ALERT_DEADLOCK',
    @message_id = 1205, @enabled = 1,
    @delay_between_responses = 60, @include_event_description_in = 1;
GO

-- Alert for Blocked Processes (Performance condition)
IF EXISTS (SELECT 1 FROM msdb.dbo.sysalerts WHERE name = N'ALERT_BLOCKED_PROCESS')
    EXEC msdb.dbo.sp_delete_alert @name = N'ALERT_BLOCKED_PROCESS';
GO
EXEC msdb.dbo.sp_add_alert
    @name = N'ALERT_BLOCKED_PROCESS',
    @message_id = 0, @severity = 0, @enabled = 1,
    @delay_between_responses = 60, @include_event_description_in = 1,
    @performance_condition = N'SQLServer:General Statistics|Processes blocked||>|0';
GO

-- Notifications (Requires DBA_Team operator from script 05)
IF EXISTS (SELECT 1 FROM msdb.dbo.sysoperators WHERE name = N'DBA_Team')
BEGIN
    EXEC msdb.dbo.sp_add_notification @alert_name = N'ALERT_DEADLOCK', @operator_name = N'DBA_Team', @notification_method = 1;
    EXEC msdb.dbo.sp_add_notification @alert_name = N'ALERT_BLOCKED_PROCESS', @operator_name = N'DBA_Team', @notification_method = 1;
END
GO
