/*
Fichier : models/silver/silver_gestion_locative.sql

Rôle :
- Créer la table Silver de gestion locative des biens immobiliers.

Entrée :
- Lit la table Bronze du Lakehouse :
  LH_Immo_Dev.dbo.src_gestion_locative

Sortie :
- Crée une table dans le Warehouse :
  silver.gestion_locative

Actions réalisées :
- Conversion des identifiants en varchar(50)
- Conversion des dates en date / datetime2(6)
- Conversion des loyers, charges, impayés et rendements en decimal
- Conversion des durées de vacance locative en int
- Conversion des incidents et is_active en bit
- Normalisation des statuts

Objectif :
- Obtenir une table propre pour suivre la performance locative et les incidents de gestion.
*/

{{ config(alias='gestion_locative') }}

select
    cast(gestion_id as varchar(50)) as gestion_id,
    cast(vente_id as varchar(50)) as vente_id,
    cast(lot_id as varchar(50)) as lot_id,
    cast(investisseur_id as varchar(50)) as investisseur_id,
    cast(programme_id as varchar(50)) as programme_id,
    cast(gestionnaire_id as varchar(50)) as gestionnaire_id,

    try_cast(date_debut_gestion as date) as date_debut_gestion,
    try_cast(date_fin_gestion as date) as date_fin_gestion,

    upper(trim(statut_gestion)) as statut_gestion,

    try_cast(loyer_mensuel_prevu as decimal(18,2)) as loyer_mensuel_prevu,
    try_cast(loyer_mensuel_reel as decimal(18,2)) as loyer_mensuel_reel,
    try_cast(taux_occupation as decimal(9,4)) as taux_occupation,
    try_cast(vacance_locative_jours as int) as vacance_locative_jours,
    try_cast(charges_mensuelles as decimal(18,2)) as charges_mensuelles,

    case
        when lower(trim(incident_locatif)) in ('1', 'true', 'oui', 'yes') then cast(1 as bit)
        else cast(0 as bit)
    end as incident_locatif,

    try_cast(montant_impayes as decimal(18,2)) as montant_impayes,
    try_cast(rendement_reel_annuel as decimal(9,4)) as rendement_reel_annuel,

    try_cast(created_at as datetime2(6)) as created_at,
    try_cast(updated_at as datetime2(6)) as updated_at,

    case
        when lower(trim(is_active)) in ('1', 'true', 'oui', 'yes') then cast(1 as bit)
        else cast(0 as bit)
    end as is_active

from {{ get_lakehouse() }}.dbo.src_gestion_locative