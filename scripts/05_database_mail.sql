USE [master]
GO

EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
EXEC sp_configure 'Database Mail XPs', 1;
RECONFIGURE;
GO

EXECUTE msdb.dbo.sysmail_add_account_sp
    @account_name = 'AlertAccount',
    @email_address = 'EMAIL',
    @display_name = 'SQL Alert System',
    @mailserver_name = 'SERVER',
    @port = 587,
    @enable_ssl = 1,
    @username = 'USERNAME',
    @password = 'PASSWORD';

EXECUTE msdb.dbo.sysmail_add_profile_sp
    @profile_name = 'AdminProfile';

EXECUTE msdb.dbo.sysmail_add_profileaccount_sp
    @profile_name = 'AdminProfile',
    @account_name = 'AlertAccount',
    @sequence_number = 1;
GO

EXEC msdb.dbo.sp_add_operator
    @name = N'DBA_Team',
    @enabled = 1,
    @email_address = N'admin1@lab.local;admin2@lab.local;admin3@lab.local';
GO

EXEC msdb.dbo.sp_send_dbmail
    @profile_name = 'AdminProfile',
    @recipients = 'admin1@lab.local',
    @body = 'System Check: Mail service initialized.',
    @subject = 'DBA Alert Test';
GO
