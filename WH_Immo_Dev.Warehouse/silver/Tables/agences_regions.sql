CREATE TABLE [silver].[agences_regions] (

	[agence_id] varchar(50) NULL, 
	[nom_agence] varchar(8000) NULL, 
	[code_agence] varchar(8000) NULL, 
	[region_id] varchar(50) NULL, 
	[nom_region] varchar(8000) NULL, 
	[directeur_region_id] varchar(50) NULL, 
	[responsable_agence_id] varchar(50) NULL, 
	[ville] varchar(8000) NULL, 
	[code_postal] varchar(8000) NULL, 
	[adresse] varchar(8000) NULL, 
	[pays] varchar(8000) NULL, 
	[zone_commerciale] varchar(8000) NULL, 
	[statut_agence] varchar(8000) NULL, 
	[date_ouverture] date NULL, 
	[date_fermeture] date NULL, 
	[created_at] datetime2(6) NULL, 
	[updated_at] datetime2(6) NULL, 
	[is_active] bit NULL
);