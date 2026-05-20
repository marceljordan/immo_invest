CREATE TABLE [silver].[reclamations_incidents] (

	[reclamation_id] varchar(50) NULL, 
	[investisseur_id] varchar(50) NULL, 
	[partenaire_id] varchar(50) NULL, 
	[operation_id] varchar(50) NULL, 
	[type_operation] varchar(8000) NULL, 
	[type_reclamation] varchar(8000) NULL, 
	[categorie_reclamation] varchar(8000) NULL, 
	[niveau_urgence] varchar(8000) NULL, 
	[statut_reclamation] varchar(8000) NULL, 
	[date_ouverture] date NULL, 
	[date_resolution] date NULL, 
	[delai_resolution_jours] int NULL, 
	[responsable_traitement_id] varchar(50) NULL, 
	[motif_reclamation] varchar(8000) NULL, 
	[resolution_apportee] varchar(8000) NULL, 
	[impact_financier_estime] decimal(18,2) NULL, 
	[created_at] datetime2(6) NULL, 
	[updated_at] datetime2(6) NULL, 
	[is_deleted] bit NULL
);