CREATE TABLE [tech].[data_freshness] (

	[table_schema] varchar(6) NOT NULL, 
	[table_name] varchar(31) NOT NULL, 
	[last_load_time] datetime2(6) NULL, 
	[row_count] int NULL, 
	[checked_at] datetime2(6) NULL
);