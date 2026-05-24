/*
Fichier : models/silver/silver_partenaires_patrimoine.sql

Rôle :
- Créer la table Silver des partenaires professionnels du patrimoine.

Entrée :
- Lit la table Bronze du Lakehouse :
  LH_Immo_Dev.dbo.src_partenaires_patrimoine

Sortie :
- Crée une table dans le Warehouse :
  silver.partenaires_patrimoine

Actions réalisées :
- Conversion des identifiants en varchar(50)
- Nettoyage des informations société, contact et adresse
- Conversion des dates en date / datetime2(6)
- Conversion des volumes et encours en int / decimal
- Conversion du taux de commission par défaut en decimal(9,4)
- Conversion de is_active en bit

Objectif :
- Obtenir une table propre des partenaires pour analyser la distribution via professionnels du patrimoine.
*/

{{ config(alias='partenaires_patrimoine') }}

select
    cast(partenaire_id as varchar(50)) as partenaire_id,

    trim(raison_sociale) as raison_sociale,
    trim(siret) as siret,
    upper(trim(type_partenaire)) as type_partenaire,
    upper(trim(statut_partenaire)) as statut_partenaire,

    trim(nom_contact_principal) as nom_contact_principal,
    trim(prenom_contact_principal) as prenom_contact_principal,
    lower(trim(email_contact)) as email_contact,
    trim(telephone_contact) as telephone_contact,

    trim(adresse) as adresse,
    trim(ville) as ville,
    trim(code_postal) as code_postal,
    trim(region) as region,
    upper(trim(pays)) as pays,

    try_cast(date_signature_convention as date) as date_signature_convention,

    upper(trim(niveau_partenaire)) as niveau_partenaire,
    upper(trim(segment_partenaire)) as segment_partenaire,

    try_cast(nombre_clients_actifs as int) as nombre_clients_actifs,
    try_cast(encours_total_apporte as decimal(18,2)) as encours_total_apporte,
    try_cast(commission_rate_default as decimal(9,4)) as commission_rate_default,

    cast(manager_interne_id as varchar(50)) as manager_interne_id,
    cast(conseiller_referent_id as varchar(50)) as conseiller_referent_id,

    upper(trim(statut_convention)) as statut_convention,
    try_cast(date_derniere_activite as date) as date_derniere_activite,

    try_cast(created_at as datetime2(6)) as created_at,
    try_cast(updated_at as datetime2(6)) as updated_at,

    case
        when lower(trim(is_active)) in ('1', 'true', 'oui', 'yes') then cast(1 as bit)
        else cast(0 as bit)
    end as is_active

from LH_Immo_Dev.dbo.src_partenaires_patrimoine