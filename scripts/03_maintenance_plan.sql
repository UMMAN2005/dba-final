USE msdb;
GO

EXEC dbo.sp_add_job @job_name = N'WEEKLY_DB_MAINTENANCE', @enabled = 1;

EXEC dbo.sp_add_jobstep @job_name = N'WEEKLY_DB_MAINTENANCE', @step_name = N'DBCC_CHECK',
    @command = N'DBCC CHECKDB (CoreDB) WITH NO_INFOMSGS; DBCC CHECKDB (StagingDB) WITH NO_INFOMSGS;',
    @on_success_action = 3;

EXEC dbo.sp_add_jobstep @job_name = N'WEEKLY_DB_MAINTENANCE', @step_name = N'INDEX_REORG',
    @command = N'USE CoreDB; EXEC sp_MSforeachtable ''ALTER INDEX ALL ON ? REORGANIZE'';',
    @on_success_action = 3;

EXEC dbo.sp_add_jobstep @job_name = N'WEEKLY_DB_MAINTENANCE', @step_name = N'STATS_UPDATE',
    @command = N'USE CoreDB; EXEC sp_updatestats; USE StagingDB; EXEC sp_updatestats;',
    @on_success_action = 3;

EXEC dbo.sp_add_jobstep @job_name = N'WEEKLY_DB_MAINTENANCE', @step_name = N'CLEANUP',
    @command = N'EXEC msdb.dbo.sp_delete_backuphistory @oldest_date = ''2026-01-01''; EXEC msdb.dbo.sp_purge_jobhistory @oldest_date = ''2026-01-01'';';

EXEC dbo.sp_add_jobschedule @job_name = N'WEEKLY_DB_MAINTENANCE', @name = N'Sched_SAT_23', 
    @freq_type = 8, @freq_interval = 64, @freq_recurrence_factor = 1, @active_start_time = 230000;

EXEC dbo.sp_add_jobserver @job_name = N'WEEKLY_DB_MAINTENANCE', @server_name = N'(LOCAL)';
GO
