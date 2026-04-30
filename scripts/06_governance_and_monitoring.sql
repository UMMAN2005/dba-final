USE [master]
GO

IF NOT EXISTS (SELECT * FROM sys.server_principals WHERE name = 'deploy_user')
BEGIN
    CREATE LOGIN deploy_user WITH PASSWORD = 'StrongP@ssw0rd!2026';
END
GO

IF NOT EXISTS (SELECT * FROM sys.resource_governor_resource_pools WHERE name = 'ReportPool')
BEGIN
    CREATE RESOURCE POOL ReportPool
    WITH (MAX_CPU_PERCENT = 20, MAX_MEMORY_PERCENT = 20);
END
GO

IF NOT EXISTS (SELECT * FROM sys.resource_governor_workload_groups WHERE name = 'DeployGroup')
BEGIN
    CREATE WORKLOAD GROUP DeployGroup
    USING ReportPool;
END
GO

IF OBJECT_ID('dbo.RG_Classifier', 'FN') IS NOT NULL
    DROP FUNCTION dbo.RG_Classifier;
GO

CREATE FUNCTION dbo.RG_Classifier() 
RETURNS SYSNAME WITH SCHEMABINDING
AS
BEGIN
    DECLARE @CurrTime TIME = CAST(GETDATE() AS TIME);
    IF (SUSER_SNAME() = 'deploy_user' AND @CurrTime BETWEEN '00:00:00' AND '01:00:00')
        RETURN 'DeployGroup';
    
    RETURN 'default';
END;
GO

ALTER RESOURCE GOVERNOR WITH (CLASSIFIER_FUNCTION = dbo.RG_Classifier);
ALTER RESOURCE GOVERNOR RECONFIGURE;
GO

IF OBJECT_ID('master.dbo.Session_Tracking_Log', 'U') IS NULL
BEGIN
    CREATE TABLE master.dbo.Session_Tracking_Log
    (
        LogID INT IDENTITY(1,1) PRIMARY KEY,
        CaptureTime DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
        SessionID INT NOT NULL,
        LoginName SYSNAME NULL,
        HostName NVARCHAR(128) NULL,
        ProgramName NVARCHAR(256) NULL,
        DatabaseName SYSNAME NULL,
        Status NVARCHAR(60) NULL,
        WaitType NVARCHAR(120) NULL,
        BlockingSessionID INT NULL,
        CpuTimeMs INT NULL,
        LogicalReads BIGINT NULL
    );
END
GO

IF OBJECT_ID('master.dbo.SP_CAPTURE_ACTIVE_SESSIONS', 'P') IS NOT NULL
    DROP PROCEDURE master.dbo.SP_CAPTURE_ACTIVE_SESSIONS;
GO

CREATE PROCEDURE master.dbo.SP_CAPTURE_ACTIVE_SESSIONS
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO master.dbo.Session_Tracking_Log
    (
        SessionID,
        LoginName,
        HostName,
        ProgramName,
        DatabaseName,
        Status,
        WaitType,
        BlockingSessionID,
        CpuTimeMs,
        LogicalReads
    )
    SELECT
        s.session_id,
        s.login_name,
        s.host_name,
        s.program_name,
        DB_NAME(r.database_id),
        s.status,
        r.wait_type,
        r.blocking_session_id,
        r.cpu_time,
        r.logical_reads
    FROM sys.dm_exec_sessions s
    LEFT JOIN sys.dm_exec_requests r
        ON s.session_id = r.session_id
    WHERE s.is_user_process = 1;
END
GO

USE msdb;
GO

IF EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name = N'TRACK_ACTIVE_SESSIONS')
BEGIN
    EXEC msdb.dbo.sp_delete_job @job_name = N'TRACK_ACTIVE_SESSIONS';
END
GO

EXEC dbo.sp_add_job @job_name = N'TRACK_ACTIVE_SESSIONS', @enabled = 1;
EXEC dbo.sp_add_jobstep
    @job_name = N'TRACK_ACTIVE_SESSIONS',
    @step_name = N'CaptureSessions',
    @command = N'EXEC master.dbo.SP_CAPTURE_ACTIVE_SESSIONS;',
    @database_name = N'master';
EXEC dbo.sp_add_jobschedule
    @job_name = N'TRACK_ACTIVE_SESSIONS',
    @name = N'Every_Minute',
    @freq_type = 4,
    @freq_interval = 1,
    @freq_subday_type = 4,
    @freq_subday_interval = 1;
EXEC dbo.sp_add_jobserver @job_name = N'TRACK_ACTIVE_SESSIONS', @server_name = N'(LOCAL)';
GO

USE [master];
GO

IF OBJECT_ID('master.dbo.TR_RESTRICT_DEPLOY_USER_WINDOW', 'TR') IS NOT NULL
    DROP TRIGGER master.dbo.TR_RESTRICT_DEPLOY_USER_WINDOW ON ALL SERVER;
GO

CREATE TRIGGER master.dbo.TR_RESTRICT_DEPLOY_USER_WINDOW
ON ALL SERVER
FOR LOGON
AS
BEGIN
    DECLARE @login SYSNAME = ORIGINAL_LOGIN();
    DECLARE @currTime TIME = CAST(GETDATE() AS TIME);

    IF (@login = N'deploy_user' AND @currTime >= '00:00:00' AND @currTime < '01:00:00')
    BEGIN
        ROLLBACK;
    END
END;
GO

EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
EXEC sp_configure 'blocked process threshold', 5;
RECONFIGURE;
GO

IF EXISTS (SELECT * FROM sys.server_event_sessions WHERE name = 'CaptureBlocks')
    DROP EVENT SESSION CaptureBlocks ON SERVER;
GO

CREATE EVENT SESSION CaptureBlocks ON SERVER 
ADD EVENT sqlserver.blocked_process_report
ADD TARGET package0.event_file(SET filename=N'/var/opt/mssql/data/Blocks.xel')
WITH (STARTUP_STATE=ON);
GO

ALTER EVENT SESSION CaptureBlocks ON SERVER STATE = START;
GO
