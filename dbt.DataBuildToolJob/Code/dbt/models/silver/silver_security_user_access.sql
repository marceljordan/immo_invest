/*
Fichier : models/silver/silver_security_user_access.sql

Rôle :
- Créer la table Silver de sécurité utilisateur pour gérer les accès métier.

Entrée :
- Lit la table Bronze du Lakehouse :
  LH_Immo_Dev.dbo.src_security_user_access

Sortie :
- Crée une table dans le Warehouse :
  silver.security_user_access

Actions réalisées :
- Conversion des identifiants en varchar(50)
- Nettoyage des emails et noms utilisateurs
- Normalisation des rôles et niveaux d’accès
- Conversion des droits booléens en bit
- Conversion des dates en date / datetime2(6)
- Conversion de is_active en bit

Objectif :
- Obtenir une table propre pour préparer la logique RLS/OLS dans le modèle sémantique Power BI.
*/

{{ config(alias='security_user_access') }}

select
    cast(user_access_id as varchar(50)) as user_access_id,

    lower(trim(user_email)) as user_email,
    trim(user_name) as user_name,

    upper(trim(role_metier)) as role_metier,
    upper(trim(access_level)) as access_level,

    cast(region_id as varchar(50)) as region_id,
    cast(agence_id as varchar(50)) as agence_id,
    cast(conseiller_id as varchar(50)) as conseiller_id,
    cast(partenaire_id as varchar(50)) as partenaire_id,

    case
        when lower(trim(can_view_commissions)) in ('1', 'true', 'oui', 'yes') then cast(1 as bit)
        else cast(0 as bit)
    end as can_view_commissions,

    case
        when lower(trim(can_view_margin)) in ('1', 'true', 'oui', 'yes') then cast(1 as bit)
        else cast(0 as bit)
    end as can_view_margin,

    case
        when lower(trim(can_view_personal_data)) in ('1', 'true', 'oui', 'yes') then cast(1 as bit)
        else cast(0 as bit)
    end as can_view_personal_data,

    case
        when lower(trim(can_export_data)) in ('1', 'true', 'oui', 'yes') then cast(1 as bit)
        else cast(0 as bit)
    end as can_export_data,

    try_cast(start_date as date) as start_date,
    try_cast(end_date as date) as end_date,

    case
        when lower(trim(is_active)) in ('1', 'true', 'oui', 'yes') then cast(1 as bit)
        else cast(0 as bit)
    end as is_active,

    try_cast(created_at as datetime2(6)) as created_at,
    try_cast(updated_at as datetime2(6)) as updated_at

from LH_Immo_Dev.dbo.src_security_user_access