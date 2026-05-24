CREATE TABLE [silver].[gestion_locative] (

	[gestion_id] varchar(50) NULL, 
	[vente_id] varchar(50) NULL, 
	[lot_id] varchar(50) NULL, 
	[investisseur_id] varchar(50) NULL, 
	[programme_id] varchar(50) NULL, 
	[gestionnaire_id] varchar(50) NULL, 
	[date_debut_gestion] date NULL, 
	[date_fin_gestion] date NULL, 
	[statut_gestion] varchar(8000) NULL, 
	[loyer_mensuel_prevu] decimal(18,2) NULL, 
	[loyer_mensuel_reel] decimal(18,2) NULL, 
	[taux_occupation] decimal(9,4) NULL, 
	[vacance_locative_jours] int NULL, 
	[charges_mensuelles] decimal(18,2) NULL, 
	[incident_locatif] bit NULL, 
	[montant_impayes] decimal(18,2) NULL, 
	[rendement_reel_annuel] decimal(9,4) NULL, 
	[created_at] datetime2(6) NULL, 
	[updated_at] datetime2(6) NULL, 
	[is_active] bit NULL
);