/*
Fichier : models/silver/silver_agences_regions.sql

Rôle :
- Créer la table Silver des agences et régions.

Entrée :
- Lit la table Bronze du Lakehouse :
  {{ get_lakehouse() }}.dbo.src_agences_regions

Sortie :
- Crée une table dans le Warehouse :
  silver.agences_regions

Actions réalisées :
- Conversion des identifiants en varchar(50)
- Nettoyage des libellés texte avec trim / upper
- Conversion des dates en date
- Conversion de is_active en bit

Objectif :
- Obtenir un référentiel agence/région propre pour les dimensions Gold.
*/

{{ config(alias='agences_regions') }}

select
    cast(agence_id as varchar(50)) as agence_id,
    trim(nom_agence) as nom_agence,
    upper(trim(code_agence)) as code_agence,
    cast(region_id as varchar(50)) as region_id,
    trim(nom_region) as nom_region,
    cast(directeur_region_id as varchar(50)) as directeur_region_id,
    cast(responsable_agence_id as varchar(50)) as responsable_agence_id,
    trim(ville) as ville,
    trim(code_postal) as code_postal,
    trim(adresse) as adresse,
    upper(trim(pays)) as pays,
    trim(zone_commerciale) as zone_commerciale,
    upper(trim(statut_agence)) as statut_agence,

    try_cast(date_ouverture as date) as date_ouverture,
    try_cast(date_fermeture as date) as date_fermeture,
    try_cast(created_at as datetime2(6))as created_at,
    try_cast(updated_at as datetime2(6)) as updated_at,

    case
        when lower(trim(is_active)) in ('1', 'true', 'oui', 'yes') then cast(1 as bit)
        else cast(0 as bit)
    end as is_active

from {{ get_lakehouse() }}.dbo.src_agences_regions