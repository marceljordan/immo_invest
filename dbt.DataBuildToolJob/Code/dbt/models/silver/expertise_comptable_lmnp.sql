/*
Fichier : models/silver/silver_expertise_comptable_lmnp.sql

Rôle :
- Créer la table Silver des dossiers d’expertise comptable LMNP.

Entrée :
- Lit la table Bronze du Lakehouse :
  LH_Immo_Dev.dbo.src_expertise_comptable_lmnp

Sortie :
- Crée une table dans le Warehouse :
  silver.expertise_comptable_lmnp

Actions réalisées :
- Conversion des identifiants en varchar(50)
- Conversion de l’année fiscale en int
- Conversion des dates en date / datetime2(6)
- Conversion des montants fiscaux en decimal(18,2)
- Conversion des nombres de relances en int
- Conversion de pieces_manquantes et is_deleted en bit
- Normalisation des statuts et régimes fiscaux

Objectif :
- Obtenir une table propre pour suivre les dossiers comptables LMNP et les indicateurs fiscaux associés.
*/

{{ config(alias='expertise_comptable_lmnp') }}

select
    cast(dossier_comptable_id as varchar(50)) as dossier_comptable_id,
    cast(investisseur_id as varchar(50)) as investisseur_id,
    cast(vente_id as varchar(50)) as vente_id,
    cast(lot_id as varchar(50)) as lot_id,
    cast(programme_id as varchar(50)) as programme_id,

    try_cast(annee_fiscale as int) as annee_fiscale,
    upper(trim(regime_fiscal)) as regime_fiscal,
    upper(trim(statut_dossier_comptable)) as statut_dossier_comptable,

    try_cast(date_ouverture as date) as date_ouverture,
    try_cast(date_reception_documents as date) as date_reception_documents,
    try_cast(date_declaration as date) as date_declaration,

    try_cast(recettes_locatives as decimal(18,2)) as recettes_locatives,
    try_cast(charges_deductibles as decimal(18,2)) as charges_deductibles,
    try_cast(amortissements as decimal(18,2)) as amortissements,
    try_cast(resultat_fiscal as decimal(18,2)) as resultat_fiscal,
    try_cast(impot_estime as decimal(18,2)) as impot_estime,

    cast(comptable_id as varchar(50)) as comptable_id,
    try_cast(nombre_relances as int) as nombre_relances,

    case
        when lower(trim(pieces_manquantes)) in ('1', 'true', 'oui', 'yes') then cast(1 as bit)
        else cast(0 as bit)
    end as pieces_manquantes,

    try_cast(created_at as datetime2(6)) as created_at,
    try_cast(updated_at as datetime2(6)) as updated_at,

    case
        when lower(trim(is_deleted)) in ('1', 'true', 'oui', 'yes') then cast(1 as bit)
        else cast(0 as bit)
    end as is_deleted

from LH_Immo_Dev.dbo.src_expertise_comptable_lmnp