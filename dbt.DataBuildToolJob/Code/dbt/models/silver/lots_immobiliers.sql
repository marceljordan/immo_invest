/*
Fichier : models/silver/silver_lots_immobiliers.sql

Rôle :
- Créer la table Silver des lots immobiliers.

Entrée :
- Lit la table Bronze du Lakehouse :
  LH_Immo_Dev.dbo.src_lots_immobiliers

Sortie :
- Crée une table dans le Warehouse :
  silver.lots_immobiliers

Actions réalisées :
- Conversion des identifiants en varchar(50)
- Conversion des surfaces, prix, loyers et rentabilités en decimal
- Conversion des dates en date / datetime2(6)
- Conversion des champs booléens en bit
- Normalisation des statuts, types de lots, typologies et orientations

Objectif :
- Obtenir une table propre des lots pour construire les dimensions et analyser disponibilité, réservation et vente.
*/

{{ config(alias='lots_immobiliers') }}

select
    cast(lot_id as varchar(50)) as lot_id,
    cast(programme_id as varchar(50)) as programme_id,
    upper(trim(numero_lot)) as numero_lot,

    upper(trim(type_lot)) as type_lot,
    upper(trim(typologie)) as typologie,

    try_cast(surface_m2 as decimal(10,2)) as surface_m2,
    try_cast(etage as int) as etage,
    upper(trim(orientation)) as orientation,

    case
        when lower(trim(parking_inclus)) in ('1', 'true', 'oui', 'yes') then cast(1 as bit)
        else cast(0 as bit)
    end as parking_inclus,

    try_cast(prix_catalogue as decimal(18,2)) as prix_catalogue,
    try_cast(prix_remise as decimal(18,2)) as prix_remise,
    try_cast(prix_final as decimal(18,2)) as prix_final,
    try_cast(loyer_estime_mensuel as decimal(18,2)) as loyer_estime_mensuel,
    try_cast(rentabilite_brute_estimee as decimal(9,4)) as rentabilite_brute_estimee,

    upper(trim(statut_lot)) as statut_lot,

    try_cast(date_disponibilite as date) as date_disponibilite,
    try_cast(date_reservation as date) as date_reservation,
    try_cast(date_vente as date) as date_vente,

    cast(investisseur_id as varchar(50)) as investisseur_id,
    cast(partenaire_id as varchar(50)) as partenaire_id,

    try_cast(created_at as datetime2(6)) as created_at,
    try_cast(updated_at as datetime2(6)) as updated_at,

    case
        when lower(trim(is_active)) in ('1', 'true', 'oui', 'yes') then cast(1 as bit)
        else cast(0 as bit)
    end as is_active

from {{ get_lakehouse() }}.dbo.src_lots_immobiliers