CREATE TABLE [gold].[security_user_access] (

	[security_access_key] varchar(400) NULL, 
	[user_access_id] varchar(50) NULL, 
	[user_email] varchar(8000) NULL, 
	[user_name] varchar(255) NULL, 
	[role_metier] varchar(8000) NULL, 
	[access_level] varchar(8000) NULL, 
	[region_id] varchar(50) NULL, 
	[agence_id] varchar(50) NULL, 
	[conseiller_id] varchar(50) NULL, 
	[partenaire_id] varchar(50) NULL, 
	[can_view_commissions] bit NULL, 
	[can_view_margin] bit NULL, 
	[can_view_personal_data] bit NULL, 
	[can_export_data] bit NULL, 
	[start_date] date NULL, 
	[end_date] date NULL, 
	[is_active] bit NULL, 
	[created_at] datetime2(6) NULL, 
	[updated_at] datetime2(6) NULL
);