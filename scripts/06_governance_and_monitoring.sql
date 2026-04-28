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
