/*
Fichier : models/silver/silver_operations_crowdfunding.sql

Rôle :
- Créer la table Silver des opérations de crowdfunding immobilier.

Entrée :
- Lit la table Bronze du Lakehouse :
  LH_Immo_Dev.dbo.src_operations_crowdfunding

Sortie :
- Crée une table dans le Warehouse :
  silver.operations_crowdfunding

Actions réalisées :
- Conversion des identifiants en varchar(50)
- Conversion des montants, taux et intérêts en decimal
- Conversion des durées en int
- Conversion des dates en date / datetime2(6)
- Conversion des incidents de paiement en bit
- Normalisation des statuts, fiscalité, ville et région

Objectif :
- Obtenir une table propre pour analyser les investissements en crowdfunding immobilier et les remboursements.
*/

{{ config(alias='operations_crowdfunding') }}

select
    cast(operation_crowdfunding_id as varchar(50)) as operation_crowdfunding_id,
    cast(investisseur_id as varchar(50)) as investisseur_id,
    cast(partenaire_id as varchar(50)) as partenaire_id,
    cast(conseiller_id as varchar(50)) as conseiller_id,
    cast(agence_id as varchar(50)) as agence_id,
    cast(projet_id as varchar(50)) as projet_id,

    trim(nom_projet) as nom_projet,
    cast(promoteur_id as varchar(50)) as promoteur_id,
    trim(ville) as ville,
    trim(region) as region,

    try_cast(date_investissement as date) as date_investissement,
    try_cast(montant_investi as decimal(18,2)) as montant_investi,
    try_cast(taux_rendement_annuel_prevu as decimal(9,4)) as taux_rendement_annuel_prevu,
    try_cast(duree_mois as int) as duree_mois,

    upper(trim(statut_operation)) as statut_operation,

    try_cast(date_remboursement_prevue as date) as date_remboursement_prevue,
    try_cast(date_remboursement_reelle as date) as date_remboursement_reelle,
    try_cast(montant_rembourse as decimal(18,2)) as montant_rembourse,
    try_cast(interets_bruts as decimal(18,2)) as interets_bruts,

    upper(trim(fiscalite_appliquee)) as fiscalite_appliquee,

    case
        when lower(trim(incident_paiement)) in ('1', 'true', 'oui', 'yes') then cast(1 as bit)
        else cast(0 as bit)
    end as incident_paiement,

    try_cast(created_at as datetime2(6)) as created_at,
    try_cast(updated_at as datetime2(6)) as updated_at,

    case
        when lower(trim(is_deleted)) in ('1', 'true', 'oui', 'yes') then cast(1 as bit)
        else cast(0 as bit)
    end as is_deleted

from {{ get_lakehouse() }}.dbo.src_operations_crowdfunding