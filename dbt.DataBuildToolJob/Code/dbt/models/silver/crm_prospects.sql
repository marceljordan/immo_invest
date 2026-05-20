/*
Fichier : models/silver/silver_crm_prospects.sql

Rôle :
- Créer la table Silver des prospects.

Entrée :
- Lit la table Bronze du Lakehouse :
  LH_Immo_Dev.dbo.src_crm_prospects

Sortie :
- Crée une table dans le Warehouse :
  silver.crm_prospects

Actions réalisées :
- Conversion des identifiants en varchar(50)
- Nettoyage des informations de contact
- Conversion des revenus, patrimoine et capacité d’investissement en decimal(18,2)
- Conversion du score de qualification en int
- Normalisation des statuts, canaux et appétence au risque
- Conversion des dates en date / datetime2
- Conversion de is_deleted en bit

Objectif :
- Obtenir une table prospects propre pour analyser le tunnel prospect → investisseur.
*/

{{ config(alias='crm_prospects') }}

select
    cast(prospect_id as varchar(50)) as prospect_id,

    upper(trim(civilite)) as civilite,
    trim(nom) as nom,
    trim(prenom) as prenom,
    lower(trim(email)) as email,
    trim(telephone) as telephone,

    try_cast(date_naissance as date) as date_naissance,

    trim(ville) as ville,
    trim(code_postal) as code_postal,
    upper(trim(pays)) as pays,
    upper(trim(situation_familiale)) as situation_familiale,
    trim(profession) as profession,

    try_cast(revenu_annuel_estime as decimal(18,2)) as revenu_annuel_estime,
    try_cast(patrimoine_estime as decimal(18,2)) as patrimoine_estime,
    try_cast(capacite_investissement as decimal(18,2)) as capacite_investissement,

    trim(objectif_investissement) as objectif_investissement,
    trim(horizon_investissement) as horizon_investissement,
    upper(trim(appetence_risque)) as appetence_risque,

    trim(source_acquisition) as source_acquisition,
    trim(campagne_marketing) as campagne_marketing,
    upper(trim(canal_acquisition)) as canal_acquisition,
    upper(trim(statut_prospect)) as statut_prospect,

    try_cast(score_qualification as int) as score_qualification,

    try_cast(date_creation as datetime2(6)) as date_creation,
    trim(created_by) as created_by,
    try_cast(last_update_date as datetime2(6)) as last_update_date,
    trim(last_updated_by) as last_updated_by,

    case
        when lower(trim(is_deleted)) in ('1', 'true', 'oui', 'yes') then cast(1 as bit)
        else cast(0 as bit)
    end as is_deleted

from LH_Immo_Dev.dbo.src_crm_prospects