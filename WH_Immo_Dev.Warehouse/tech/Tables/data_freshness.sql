CREATE TABLE [tech].[data_freshness] (

	[table_schema] varchar(10) NULL, 
	[table_name] varchar(100) NULL, 
	[max_date_donnees] datetime2(6) NULL, 
	[row_count] int NULL, 
	[checked_at] datetime2(6) NULL, 
	[checked_at_paris] datetime2(6) NULL
);