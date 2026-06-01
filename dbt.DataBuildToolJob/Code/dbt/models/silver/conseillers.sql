/*
Fichier : models/silver/silver_conseillers.sql

Rôle :
- Créer la table Silver des conseillers commerciaux.

Entrée :
- Lit la table Bronze du Lakehouse :
  {{ get_lakehouse() }}.dbo.src_conseillers

Sortie :
- Crée une table dans le Warehouse :
  silver.conseillers

Actions réalisées :
- Conversion des identifiants en varchar(50)
- Nettoyage des noms, emails, téléphones et postes
- Conversion des objectifs en decimal(18,2)
- Conversion des dates en date / datetime2
- Conversion de is_active en bit

Objectif :
- Obtenir un référentiel conseiller propre pour les dimensions Gold et les analyses commerciales.
*/

{{ config(alias='conseillers') }}

select
    cast(conseiller_id as varchar(50)) as conseiller_id,
    upper(trim(matricule)) as matricule,
    trim(nom) as nom,
    trim(prenom) as prenom,
    lower(trim(email)) as email,
    trim(telephone) as telephone,
    trim(poste) as poste,
    cast(agence_id as varchar(50)) as agence_id,
    cast(region_id as varchar(50)) as region_id,
    cast(manager_id as varchar(50)) as manager_id,

    try_cast(date_arrivee as date) as date_arrivee,
    try_cast(date_depart as date) as date_depart,

    upper(trim(statut_collaborateur)) as statut_collaborateur,
    trim(specialite_produit) as specialite_produit,

    try_cast(objectif_annuel as decimal(18,2)) as objectif_annuel,
    try_cast(objectif_mensuel_moyen as decimal(18,2)) as objectif_mensuel_moyen,

    try_cast(created_at as datetime2(6)) as created_at,
    try_cast(updated_at as datetime2(6)) as updated_at,

    case
        when lower(trim(is_active)) in ('1', 'true', 'oui', 'yes') then cast(1 as bit)
        else cast(0 as bit)
    end as is_active

from {{ get_lakehouse() }}.dbo.src_conseillers