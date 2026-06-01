/*
Fichier : models/silver/silver_crm_investisseurs.sql

Rôle :
- Créer la table Silver des investisseurs.

Entrée :
- Lit la table Bronze du Lakehouse :
  LH_Immo_Dev.dbo.src_crm_investisseurs

Sortie :
- Crée une table dans le Warehouse :
  silver.crm_investisseurs

Actions réalisées :
- Conversion des identifiants en varchar(50)
- Nettoyage des informations de contact
- Conversion des revenus et patrimoines en decimal(18,2)
- Normalisation des profils, statuts KYC / LCB-FT et statuts client
- Conversion des dates en date / datetime2
- Conversion de is_deleted en bit

Objectif :
- Obtenir une table investisseurs propre pour créer la dimension investisseur en Gold.
*/

{{ config(alias='crm_investisseurs') }}

select
    cast(investisseur_id as varchar(50)) as investisseur_id,
    cast(prospect_id as varchar(50)) as prospect_id,

    upper(trim(civilite)) as civilite,
    trim(nom) as nom,
    trim(prenom) as prenom,
    lower(trim(email)) as email,
    trim(telephone) as telephone,
    trim(adresse) as adresse,
    trim(ville) as ville,
    trim(code_postal) as code_postal,
    upper(trim(pays)) as pays,
    trim(profession) as profession,
    upper(trim(situation_familiale)) as situation_familiale,

    try_cast(revenu_annuel as decimal(18,2)) as revenu_annuel,
    try_cast(patrimoine_financier as decimal(18,2)) as patrimoine_financier,
    try_cast(patrimoine_immobilier as decimal(18,2)) as patrimoine_immobilier,

    upper(trim(profil_investisseur)) as profil_investisseur,
    trim(objectif_principal) as objectif_principal,
    trim(horizon_placement) as horizon_placement,
    upper(trim(niveau_experience)) as niveau_experience,
    upper(trim(statut_kyc)) as statut_kyc,
    upper(trim(statut_lcbft)) as statut_lcbft,

    try_cast(date_entree_relation as date) as date_entree_relation,

    cast(partenaire_id as varchar(50)) as partenaire_id,
    cast(conseiller_id as varchar(50)) as conseiller_id,
    cast(agence_id as varchar(50)) as agence_id,

    upper(trim(statut_client)) as statut_client,

    try_cast(date_creation as datetime2(6)) as date_creation,
    trim(created_by) as created_by,
    try_cast(last_update_date as datetime2(6)) as last_update_date,
    trim(last_updated_by) as last_updated_by,

    case
        when lower(trim(is_deleted)) in ('1', 'true', 'oui', 'yes') then cast(1 as bit)
        else cast(0 as bit)
    end as is_deleted

from {{ get_lakehouse() }}.dbo.src_crm_investisseurs