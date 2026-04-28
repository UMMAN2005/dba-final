USE msdb;
GO

EXEC dbo.sp_add_job @job_name = N'REPORT_Monthly_Archive', @enabled = 1;
EXEC dbo.sp_add_jobstep @job_name = N'REPORT_Monthly_Archive', @step_name = N'BackupStep',
    @command = N'BACKUP DATABASE [ReportDB] TO DISK = N''/var/opt/mssql/data/ReportDB_Archive.bak'' WITH INIT, COMPRESSION, STATS = 10';

EXEC dbo.sp_add_jobschedule @job_name = N'REPORT_Monthly_Archive', @name = N'Sched_Monthly_01', 
    @freq_type = 16, @freq_interval = 1, @freq_recurrence_factor = 1, @active_start_time = 020000;

EXEC dbo.sp_add_jobserver @job_name = N'REPORT_Monthly_Archive', @server_name = N'(LOCAL)';
GO
