USE [master]
GO

IF OBJECT_ID('dbo.SP_ENFORCE_DB_OWNERSHIP') IS NOT NULL
    DROP PROCEDURE dbo.SP_ENFORCE_DB_OWNERSHIP;
GO

CREATE PROCEDURE dbo.SP_ENFORCE_DB_OWNERSHIP
AS
BEGIN
    DECLARE @db sysname;
    DECLARE @owner sysname;
    DECLARE @msg NVARCHAR(MAX);
    DECLARE c CURSOR FOR 
        SELECT d.name, SUSER_SNAME(d.owner_sid) 
        FROM sys.databases d 
        WHERE d.database_id > 4;

    OPEN c;
    FETCH NEXT FROM c INTO @db, @owner;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        IF LOWER(ISNULL(@owner, '')) NOT IN ('sa', 'dbo')
        BEGIN
            -- 1. Self-healing correction
            EXEC('ALTER AUTHORIZATION ON DATABASE::[' + @db + '] TO [sa]');
            
            -- 2. Notify Admins
            SET @msg = 'Self-healing triggered: Database [' + @db + '] was owned by [' + @owner + ']. Ownership has been restored to [sa].';
            EXEC msdb.dbo.sp_send_dbmail
                @profile_name = 'AdminProfile',
                @recipients = 'admin1@lab.local',
                @subject = 'SECURITY ALERT: Database Ownership Corrected',
                @body = @msg;
        END
        FETCH NEXT FROM c INTO @db, @owner;
    END
    CLOSE c;
    DEALLOCATE c;
END
GO

USE msdb;
GO

IF EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name = N'ENFORCE_OWNERSHIP_JOB')
    EXEC msdb.dbo.sp_delete_job @job_name = N'ENFORCE_OWNERSHIP_JOB';
GO

EXEC dbo.sp_add_job @job_name = N'ENFORCE_OWNERSHIP_JOB', @enabled = 1;
EXEC dbo.sp_add_jobstep @job_name = N'ENFORCE_OWNERSHIP_JOB', @step_name = N'CheckOwnership',
    @command = N'EXEC master.dbo.SP_ENFORCE_DB_OWNERSHIP;',
    @database_name = N'master';
EXEC dbo.sp_add_jobschedule @job_name = N'ENFORCE_OWNERSHIP_JOB', @name = N'Daily_Check', 
    @freq_type = 4, @freq_interval = 1, @active_start_time = 020000;
EXEC dbo.sp_add_jobserver @job_name = N'ENFORCE_OWNERSHIP_JOB', @server_name = N'(LOCAL)';
GO

CREATE SERVER AUDIT SecurityAudit_Main
TO FILE ( FILEPATH = '/var/opt/mssql/data/' );
GO

ALTER SERVER AUDIT SecurityAudit_Main WITH (STATE = ON);
GO

USE CoreDB;
GO

CREATE DATABASE AUDIT SPECIFICATION HR_Access_Audit
FOR SERVER AUDIT SecurityAudit_Main
ADD (SELECT ON HR.Employees BY public)
WITH (STATE = ON);
GO

IF NOT EXISTS (SELECT * FROM sys.symmetric_keys WHERE name = '##MS_DatabaseMasterKey##')
    CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'StrongP@ssw0rd!Master';
GO

CREATE CERTIFICATE SalaryCert WITH SUBJECT = 'Encryption Cert';
GO

CREATE SYMMETRIC KEY SalaryKey
WITH ALGORITHM = AES_256
ENCRYPTION BY CERTIFICATE SalaryCert;
GO

IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('HR.Employees') AND name = 'Salary_Enc')
    ALTER TABLE HR.Employees ADD Salary_Enc VARBINARY(MAX);
GO

OPEN SYMMETRIC KEY SalaryKey DECRYPTION BY CERTIFICATE SalaryCert;
UPDATE HR.Employees SET Salary_Enc = ENCRYPTBYKEY(KEY_GUID('SalaryKey'), CAST(Salary AS NVARCHAR(50)));
CLOSE SYMMETRIC KEY SalaryKey;
GO

/* 5) TRANSPARENT DATA ENCRYPTION (TDE) */
USE [master];
GO

IF NOT EXISTS (SELECT 1 FROM sys.certificates WHERE name = 'TDE_ServerCert')
BEGIN
    CREATE CERTIFICATE TDE_ServerCert
        WITH SUBJECT = 'TDE Certificate for project databases';
END
GO

DECLARE @db SYSNAME;
DECLARE @TDESql NVARCHAR(MAX);

DECLARE db_cursor CURSOR FAST_FORWARD FOR
SELECT d.name
FROM sys.databases d
WHERE d.name IN ('CoreDB', 'StagingDB', 'ReportDB');

OPEN db_cursor;
FETCH NEXT FROM db_cursor INTO @db;

WHILE @@FETCH_STATUS = 0
BEGIN
    IF EXISTS (SELECT 1 FROM sys.databases WHERE name = @db)
    BEGIN
        SET @TDESql = N'
USE ' + QUOTENAME(@db) + N';

IF NOT EXISTS (SELECT 1 FROM sys.dm_database_encryption_keys WHERE database_id = DB_ID())
BEGIN
    CREATE DATABASE ENCRYPTION KEY
    WITH ALGORITHM = AES_256
    ENCRYPTION BY SERVER CERTIFICATE TDE_ServerCert;
END;

IF EXISTS (
    SELECT 1
    FROM sys.databases
    WHERE name = DB_NAME()
      AND is_encrypted = 0
)
BEGIN
    ALTER DATABASE ' + QUOTENAME(@db) + N' SET ENCRYPTION ON;
END;';

        EXEC sys.sp_executesql @TDESql;
    END

    FETCH NEXT FROM db_cursor INTO @db;
END

CLOSE db_cursor;
DEALLOCATE db_cursor;
GO
