USE [master]
GO

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
    IF @owner <> 'sa'
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
