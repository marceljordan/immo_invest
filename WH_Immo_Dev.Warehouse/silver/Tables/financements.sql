CREATE TABLE [silver].[financements] (

	[financement_id] varchar(50) NULL, 
	[vente_id] varchar(50) NULL, 
	[investisseur_id] varchar(50) NULL, 
	[banque] varchar(8000) NULL, 
	[courtier] varchar(8000) NULL, 
	[montant_demande] decimal(18,2) NULL, 
	[montant_accorde] decimal(18,2) NULL, 
	[taux_credit] decimal(9,4) NULL, 
	[duree_credit_mois] int NULL, 
	[mensualite_estimee] decimal(18,2) NULL, 
	[statut_financement] varchar(8000) NULL, 
	[date_demande] date NULL, 
	[date_accord_principe] date NULL, 
	[date_offre_pret] date NULL, 
	[date_acceptation_offre] date NULL, 
	[motif_refus] varchar(8000) NULL, 
	[apport_personnel] decimal(18,2) NULL, 
	[assurance_emprunteur] decimal(18,2) NULL, 
	[created_at] datetime2(6) NULL, 
	[updated_at] datetime2(6) NULL, 
	[is_deleted] bit NULL
);