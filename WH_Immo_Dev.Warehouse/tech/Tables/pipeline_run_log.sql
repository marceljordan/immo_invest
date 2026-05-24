CREATE TABLE [tech].[pipeline_run_log] (

	[run_id] uniqueidentifier NULL, 
	[pipeline_name] varchar(200) NULL, 
	[environment] varchar(3) NOT NULL, 
	[status] varchar(200) NULL, 
	[start_time] datetime2(6) NULL, 
	[end_time] datetime2(6) NULL, 
	[duration_seconds] bigint NULL, 
	[rows_processed] bigint NULL, 
	[error_message] varchar(4000) NULL, 
	[inserted_at] datetime2(6) NULL
);