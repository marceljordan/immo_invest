CREATE TABLE [gold].[dim_statut] (

	[statut_key] varchar(400) NULL, 
	[domaine_statut] varchar(16) NOT NULL, 
	[statut_value] varchar(100) NULL, 
	[categorie_statut] varchar(10) NULL, 
	[libelle_categorie] varchar(18) NULL, 
	[code_couleur] int NULL
);