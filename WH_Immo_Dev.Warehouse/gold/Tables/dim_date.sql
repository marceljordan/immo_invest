CREATE TABLE [gold].[dim_date] (

	[date_key] int NULL, 
	[full_date] date NULL, 
	[annee] int NULL, 
	[trimestre] int NULL, 
	[mois] int NULL, 
	[jour] int NULL, 
	[nom_mois] varchar(30) NULL, 
	[nom_jour] varchar(30) NULL, 
	[numero_jour_semaine] int NULL, 
	[annee_mois_key] int NULL, 
	[annee_mois] varchar(7) NULL
);