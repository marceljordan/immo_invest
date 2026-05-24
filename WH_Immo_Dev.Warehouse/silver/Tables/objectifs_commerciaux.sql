CREATE TABLE [silver].[objectifs_commerciaux] (

	[objectif_id] varchar(50) NULL, 
	[annee] int NULL, 
	[mois] int NULL, 
	[periode] varchar(8000) NULL, 
	[niveau_objectif] varchar(8000) NULL, 
	[region_id] varchar(50) NULL, 
	[agence_id] varchar(50) NULL, 
	[conseiller_id] varchar(50) NULL, 
	[partenaire_id] varchar(50) NULL, 
	[famille_produit] varchar(8000) NULL, 
	[type_produit] varchar(8000) NULL, 
	[objectif_ca] decimal(18,2) NULL, 
	[objectif_nombre_ventes] int NULL, 
	[objectif_nombre_reservations] int NULL, 
	[objectif_montant_souscriptions] decimal(18,2) NULL, 
	[objectif_commissions] decimal(18,2) NULL, 
	[objectif_nouveaux_clients] int NULL, 
	[created_at] datetime2(6) NULL, 
	[updated_at] datetime2(6) NULL, 
	[is_active] bit NULL
);