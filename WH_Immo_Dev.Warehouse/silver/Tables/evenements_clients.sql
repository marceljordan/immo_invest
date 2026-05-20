CREATE TABLE [silver].[evenements_clients] (

	[evenement_id] varchar(50) NULL, 
	[investisseur_id] varchar(50) NULL, 
	[prospect_id] varchar(50) NULL, 
	[partenaire_id] varchar(50) NULL, 
	[conseiller_id] varchar(50) NULL, 
	[type_evenement] varchar(8000) NULL, 
	[canal_evenement] varchar(8000) NULL, 
	[objet_evenement] varchar(8000) NULL, 
	[date_evenement] datetime2(6) NULL, 
	[statut_evenement] varchar(8000) NULL, 
	[resultat_evenement] varchar(8000) NULL, 
	[prochaine_action] varchar(8000) NULL, 
	[date_prochaine_action] datetime2(6) NULL, 
	[priorite] varchar(8000) NULL, 
	[commentaire] varchar(8000) NULL, 
	[created_at] datetime2(6) NULL, 
	[created_by] varchar(8000) NULL, 
	[updated_at] datetime2(6) NULL, 
	[is_deleted] bit NULL
);