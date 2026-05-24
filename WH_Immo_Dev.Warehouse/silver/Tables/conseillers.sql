CREATE TABLE [silver].[conseillers] (

	[conseiller_id] varchar(50) NULL, 
	[matricule] varchar(8000) NULL, 
	[nom] varchar(8000) NULL, 
	[prenom] varchar(8000) NULL, 
	[email] varchar(8000) NULL, 
	[telephone] varchar(8000) NULL, 
	[poste] varchar(8000) NULL, 
	[agence_id] varchar(50) NULL, 
	[region_id] varchar(50) NULL, 
	[manager_id] varchar(50) NULL, 
	[date_arrivee] date NULL, 
	[date_depart] date NULL, 
	[statut_collaborateur] varchar(8000) NULL, 
	[specialite_produit] varchar(8000) NULL, 
	[objectif_annuel] decimal(18,2) NULL, 
	[objectif_mensuel_moyen] decimal(18,2) NULL, 
	[created_at] datetime2(6) NULL, 
	[updated_at] datetime2(6) NULL, 
	[is_active] bit NULL
);