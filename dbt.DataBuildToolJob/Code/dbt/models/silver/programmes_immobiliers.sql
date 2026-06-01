/*
Fichier : models/silver/silver_programmes_immobiliers.sql

Rôle :
- Créer la table Silver des programmes immobiliers.

Entrée :
- Lit la table Bronze du Lakehouse :
  LH_Immo_Dev.dbo.src_programmes_immobiliers

Sortie :
- Crée une table dans le Warehouse :
  silver.programmes_immobiliers

Actions réalisées :
- Conversion des identifiants en varchar(50)
- Nettoyage des libellés programme, ville, région, adresse
- Conversion des coordonnées géographiques en decimal
- Conversion des dates en date / datetime2(6)
- Conversion des volumes, prix, rentabilités et notes en types numériques
- Normalisation des statuts, types d’actifs, segments et dispositifs fiscaux
- Conversion de is_active en bit

Objectif :
- Obtenir une table propre des programmes immobiliers pour construire la dimension programme et analyser l’offre immobilière.
*/

{{ config(alias='programmes_immobiliers') }}

select
    cast(programme_id as varchar(50)) as programme_id,
    trim(nom_programme) as nom_programme,
    upper(trim(type_programme)) as type_programme,
    cast(promoteur_id as varchar(50)) as promoteur_id,

    trim(ville) as ville,
    trim(code_postal) as code_postal,
    trim(region) as region,
    trim(adresse) as adresse,

    try_cast(latitude as decimal(10,6)) as latitude,
    try_cast(longitude as decimal(10,6)) as longitude,

    upper(trim(type_actif)) as type_actif,
    upper(trim(segment_marche)) as segment_marche,
    upper(trim(statut_programme)) as statut_programme,

    try_cast(date_lancement_commercial as date) as date_lancement_commercial,
    try_cast(date_livraison_prevue as date) as date_livraison_prevue,
    try_cast(date_livraison_reelle as date) as date_livraison_reelle,

    try_cast(nombre_lots_total as int) as nombre_lots_total,
    try_cast(nombre_lots_disponibles as int) as nombre_lots_disponibles,
    try_cast(prix_moyen_m2 as decimal(18,2)) as prix_moyen_m2,
    try_cast(rentabilite_cible as decimal(9,4)) as rentabilite_cible,

    upper(trim(zone_fiscale)) as zone_fiscale,
    upper(trim(dispositif_fiscal)) as dispositif_fiscal,
    upper(trim(label_energetique)) as label_energetique,

    try_cast(note_programme as decimal(5,2)) as note_programme,

    try_cast(created_at as datetime2(6)) as created_at,
    try_cast(updated_at as datetime2(6)) as updated_at,

    case
        when lower(trim(is_active)) in ('1', 'true', 'oui', 'yes') then cast(1 as bit)
        else cast(0 as bit)
    end as is_active

from {{ get_lakehouse() }}.dbo.src_programmes_immobiliers