CREATE TABLE [gold].[dq_vente_rejets] (

	[vente_id] varchar(50) NULL, 
	[statut_vente] varchar(8000) NULL, 
	[date_signature_contrat] date NULL, 
	[date_signature_acte] date NULL, 
	[date_livraison_reelle] date NULL, 
	[prix_vente_ttc] decimal(18,2) NULL, 
	[rm1_contrat_futur] int NOT NULL, 
	[rm2_contrat_apres_acte] int NOT NULL, 
	[rm3_acte_futur] int NOT NULL, 
	[rm4_livraison_future] int NOT NULL, 
	[date_controle] date NULL
);