CREATE TABLE [tech].[data_quality_log] (

	[checked_at] datetime2(6) NULL, 
	[table_schema] varchar(4) NOT NULL, 
	[table_name] varchar(31) NOT NULL, 
	[column_name] varchar(23) NOT NULL, 
	[check_type] varchar(15) NOT NULL, 
	[records_checked] int NULL, 
	[records_failed] int NULL, 
	[pass_rate] decimal(5,2) NULL, 
	[status] varchar(4) NOT NULL
);