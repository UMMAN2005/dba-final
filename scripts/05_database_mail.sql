USE [master]
GO

EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
EXEC sp_configure 'Database Mail XPs', 1;
RECONFIGURE;
GO

EXECUTE msdb.dbo.sysmail_add_account_sp
    @account_name = 'AlertAccount',
    @email_address = 'sendinblue.brevo@gmail.com',
    @display_name = 'SQL Alert System',
    @mailserver_name = 'smtp-relay.brevo.com',
    @port = 587,
    @enable_ssl = 1,
    @username = 'sendinblue.brevo@gmail.com',
    @password = 'xsmtpsib-e5206e95ff33ccf54c8619284d2d248d623c8bf7ebb989336bad4c444e3610db-9yOiajME4chGJSkz'; 

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
