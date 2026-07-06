/*
Fichier : models/silver/silver_commissions.sql

Rôle :
- Créer la table Silver des commissions.

Entrée :
- Lit la table Bronze du Lakehouse :
  {{ get_lakehouse() }}.dbo.src_commissions

Sortie :
- Crée une table dans le Warehouse :
  silver.commissions

Actions réalisées :
- Conversion des identifiants en varchar(50)
- Conversion des montants en decimal(18,2)
- Conversion des taux en decimal(9,4)
- Conversion des dates en date / datetime2
- Normalisation des statuts et modes de paiement
- Conversion de is_deleted en bit

Objectif :
- Obtenir une table de commissions propre et exploitable pour les faits Gold.
*/

{{ config(alias='commissions') }}

select
    cast(commission_id as varchar(50)) as commission_id,
    upper(trim(type_operation)) as type_operation,
    cast(operation_id as varchar(50)) as operation_id,
    cast(vente_id as varchar(50)) as vente_id,
    cast(souscription_id as varchar(50)) as souscription_id,
    cast(operation_crowdfunding_id as varchar(50)) as operation_crowdfunding_id,
    cast(investisseur_id as varchar(50)) as investisseur_id,
    cast(partenaire_id as varchar(50)) as partenaire_id,
    cast(conseiller_id as varchar(50)) as conseiller_id,
    cast(agence_id as varchar(50)) as agence_id,
    cast(produit_id as varchar(50)) as produit_id,
    cast(programme_id as varchar(50)) as programme_id,

    try_cast(montant_operation as decimal(18,2)) as montant_operation,
    try_cast(taux_commission as decimal(9,4)) as taux_commission,
    try_cast(montant_commission_brut as decimal(18,2)) as montant_commission_brut,
    try_cast(montant_commission_net as decimal(18,2)) as montant_commission_net,
    try_cast(part_commission_partenaire as decimal(18,2)) as part_commission_partenaire,
    try_cast(part_commission_interne as decimal(18,2)) as part_commission_interne,

    upper(trim(statut_commission)) as statut_commission,
    try_cast(date_calcul as date) as date_calcul,
    try_cast(date_validation as date) as date_validation,
    try_cast(date_paiement as date) as date_paiement,
    upper(trim(mode_paiement)) as mode_paiement,
    trim(motif_blocage) as motif_blocage,

    try_cast(created_at as datetime2(6)) as created_at,
    try_cast(updated_at as datetime2(6)) as updated_at,

    case
        when lower(trim(is_deleted)) in ('1', 'true', 'oui', 'yes') then cast(1 as bit)
        else cast(0 as bit)
    end as is_deleted

from {{ get_lakehouse() }}.dbo.src_commissions