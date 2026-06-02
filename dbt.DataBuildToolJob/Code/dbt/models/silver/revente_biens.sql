/*
Fichier : models/silver/silver_revente_biens.sql

Rôle :
- Créer la table Silver des reventes de biens immobiliers.

Entrée :
- Lit la table Bronze du Lakehouse :
  LH_Immo_Dev.dbo.src_revente_biens

Sortie :
- Crée une table dans le Warehouse :
  silver.revente_biens

Actions réalisées :
- Conversion des identifiants en varchar(50)
- Conversion des dates en date / datetime2(6)
- Conversion des prix et plus-values en decimal(18,2)
- Conversion du nombre de visites en int
- Normalisation des statuts et motifs de revente
- Conversion de is_deleted en bit

Objectif :
- Obtenir une table propre pour analyser les opérations de revente et la performance patrimoniale.
*/

{{ config(alias='revente_biens') }}

select
    cast(revente_id as varchar(50)) as revente_id,
    cast(vente_id as varchar(50)) as vente_id,
    cast(lot_id as varchar(50)) as lot_id,
    cast(investisseur_id as varchar(50)) as investisseur_id,
    cast(programme_id as varchar(50)) as programme_id,

    try_cast(date_demande_revente as date) as date_demande_revente,
    try_cast(date_mise_en_marche as date) as date_mise_en_marche,
    try_cast(date_revente as date) as date_revente,

    try_cast(prix_achat_initial as decimal(18,2)) as prix_achat_initial,
    try_cast(prix_revente_estime as decimal(18,2)) as prix_revente_estime,
    try_cast(prix_revente_final as decimal(18,2)) as prix_revente_final,
    try_cast(plus_value_brute as decimal(18,2)) as plus_value_brute,
    try_cast(plus_value_nette as decimal(18,2)) as plus_value_nette,

    upper(trim(statut_revente)) as statut_revente,
    trim(motif_revente) as motif_revente,
    upper(trim(mandat_revente)) as mandat_revente,

    cast(conseiller_revente_id as varchar(50)) as conseiller_revente_id,
    try_cast(nombre_visites as int) as nombre_visites,

    try_cast(created_at as datetime2(6)) as created_at,
    try_cast(updated_at as datetime2(6)) as updated_at,

    case
        when lower(trim(is_deleted)) in ('1', 'true', 'oui', 'yes') then cast(1 as bit)
        else cast(0 as bit)
    end as is_deleted

from {{ get_lakehouse() }}.dbo.src_revente_biens