USE msdb;
GO

EXEC dbo.sp_add_job @job_name = N'CORE_Full_Backup', @enabled = 1;
EXEC dbo.sp_add_jobstep @job_name = N'CORE_Full_Backup', @step_name = N'BackupStep',
    @command = N'BACKUP DATABASE [CoreDB] TO DISK = N''/var/opt/mssql/data/CoreDB_Full.bak'' WITH INIT, COMPRESSION, STATS = 10';
EXEC dbo.sp_add_jobschedule @job_name = N'CORE_Full_Backup', @name = N'Sched_Daily_00', @freq_type = 4, @freq_interval = 1, @active_start_time = 000000;

EXEC dbo.sp_add_job @job_name = N'CORE_Diff_Backup', @enabled = 1;
EXEC dbo.sp_add_jobstep @job_name = N'CORE_Diff_Backup', @step_name = N'BackupStep',
    @command = N'BACKUP DATABASE [CoreDB] TO DISK = N''/var/opt/mssql/data/CoreDB_Diff.bak'' WITH DIFFERENTIAL, INIT, COMPRESSION, STATS = 10';
EXEC dbo.sp_add_jobschedule @job_name = N'CORE_Diff_Backup', @name = N'Sched_6HR', @freq_type = 4, @freq_interval = 1, @active_start_time = 060000;

EXEC dbo.sp_add_job @job_name = N'CORE_Log_Backup', @enabled = 1;
EXEC dbo.sp_add_jobstep @job_name = N'CORE_Log_Backup', @step_name = N'BackupStep',
    @command = N'BACKUP LOG [CoreDB] TO DISK = N''/var/opt/mssql/data/CoreDB_Log.trn'' WITH NOINIT, COMPRESSION, STATS = 10';
EXEC dbo.sp_add_jobschedule @job_name = N'CORE_Log_Backup', @name = N'Sched_15MIN', @freq_type = 4, @freq_interval = 1, @freq_subday_type = 4, @freq_subday_interval = 15;

EXEC dbo.sp_add_job @job_name = N'STAGING_Weekly_Full', @enabled = 1;
EXEC dbo.sp_add_jobstep @job_name = N'STAGING_Weekly_Full', @step_name = N'BackupStep',
    @command = N'BACKUP DATABASE [StagingDB] TO DISK = N''/var/opt/mssql/data/StagingDB_Full.bak'' WITH INIT, COMPRESSION, STATS = 10';
EXEC dbo.sp_add_jobschedule @job_name = N'STAGING_Weekly_Full', @name = N'Sched_SUN_01', @freq_type = 8, @freq_interval = 1, @freq_recurrence_factor = 1, @active_start_time = 010000;

EXEC dbo.sp_add_job @job_name = N'STAGING_Weekly_Diff', @enabled = 1;
EXEC dbo.sp_add_jobstep @job_name = N'STAGING_Weekly_Diff', @step_name = N'BackupStep',
    @command = N'BACKUP DATABASE [StagingDB] TO DISK = N''/var/opt/mssql/data/StagingDB_Diff.bak'' WITH DIFFERENTIAL, INIT, COMPRESSION, STATS = 10';
EXEC dbo.sp_add_jobschedule @job_name = N'STAGING_Weekly_Diff', @name = N'Sched_WED_01', @freq_type = 8, @freq_interval = 8, @freq_recurrence_factor = 1, @active_start_time = 010000;

EXEC dbo.sp_add_jobserver @job_name = N'CORE_Full_Backup', @server_name = N'(LOCAL)';
EXEC dbo.sp_add_jobserver @job_name = N'CORE_Diff_Backup', @server_name = N'(LOCAL)';
EXEC dbo.sp_add_jobserver @job_name = N'CORE_Log_Backup', @server_name = N'(LOCAL)';
EXEC dbo.sp_add_jobserver @job_name = N'STAGING_Weekly_Full', @server_name = N'(LOCAL)';
EXEC dbo.sp_add_jobserver @job_name = N'STAGING_Weekly_Diff', @server_name = N'(LOCAL)';
GO
