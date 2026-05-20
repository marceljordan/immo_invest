CREATE TABLE [silver].[revente_biens] (

	[revente_id] varchar(50) NULL, 
	[vente_id] varchar(50) NULL, 
	[lot_id] varchar(50) NULL, 
	[investisseur_id] varchar(50) NULL, 
	[programme_id] varchar(50) NULL, 
	[date_demande_revente] date NULL, 
	[date_mise_en_marche] date NULL, 
	[date_revente] date NULL, 
	[prix_achat_initial] decimal(18,2) NULL, 
	[prix_revente_estime] decimal(18,2) NULL, 
	[prix_revente_final] decimal(18,2) NULL, 
	[plus_value_brute] decimal(18,2) NULL, 
	[plus_value_nette] decimal(18,2) NULL, 
	[statut_revente] varchar(8000) NULL, 
	[motif_revente] varchar(8000) NULL, 
	[mandat_revente] varchar(8000) NULL, 
	[conseiller_revente_id] varchar(50) NULL, 
	[nombre_visites] int NULL, 
	[created_at] datetime2(6) NULL, 
	[updated_at] datetime2(6) NULL, 
	[is_deleted] bit NULL
);