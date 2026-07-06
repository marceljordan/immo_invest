/*
Fichier : models/silver/silver_dossiers_adv.sql

Rôle :
- Créer la table Silver des dossiers ADV, c’est-à-dire le suivi administratif des ventes.

Entrée :
- Lit la table Bronze du Lakehouse :
  LH_Immo_Dev.dbo.src_dossiers_adv

Sortie :
- Crée une table dans le Warehouse :
  silver.dossiers_adv

Actions réalisées :
- Conversion des identifiants en varchar(50)
- Conversion des dates en date / datetime2(6)
- Conversion des délais et nombres de relances en int
- Conversion des champs booléens en bit
- Nettoyage des statuts, motifs et commentaires

Objectif :
- Obtenir une table ADV propre pour suivre les délais, blocages et états des dossiers de vente.
*/

{{ config(alias='dossiers_adv') }}

select
    cast(dossier_adv_id as varchar(50)) as dossier_adv_id,
    cast(vente_id as varchar(50)) as vente_id,
    cast(reservation_id as varchar(50)) as reservation_id,
    cast(investisseur_id as varchar(50)) as investisseur_id,
    cast(lot_id as varchar(50)) as lot_id,
    cast(programme_id as varchar(50)) as programme_id,
    cast(partenaire_id as varchar(50)) as partenaire_id,
    cast(conseiller_id as varchar(50)) as conseiller_id,

    upper(trim(statut_dossier)) as statut_dossier,

    try_cast(date_ouverture_dossier as date) as date_ouverture_dossier,
    try_cast(date_reception_pieces as date) as date_reception_pieces,
    try_cast(date_validation_dossier as date) as date_validation_dossier,
    try_cast(date_envoi_notaire as date) as date_envoi_notaire,
    try_cast(date_signature_acte as date) as date_signature_acte,

    try_cast(delai_traitement_jours as int) as delai_traitement_jours,

    case
        when lower(trim(pieces_manquantes)) in ('1', 'true', 'oui', 'yes') then cast(1 as bit)
        else cast(0 as bit)
    end as pieces_manquantes,

    try_cast(nombre_relances as int) as nombre_relances,

    case
        when lower(trim(blocage_adv)) in ('1', 'true', 'oui', 'yes') then cast(1 as bit)
        else cast(0 as bit)
    end as blocage_adv,

    trim(motif_blocage) as motif_blocage,
    cast(responsable_adv_id as varchar(50)) as responsable_adv_id,
    trim(commentaire_adv) as commentaire_adv,

    try_cast(created_at as datetime2(6)) as created_at,
    try_cast(updated_at as datetime2(6)) as updated_at,

    case
        when lower(trim(is_deleted)) in ('1', 'true', 'oui', 'yes') then cast(1 as bit)
        else cast(0 as bit)
    end as is_deleted

from {{ get_lakehouse() }}.dbo.src_dossiers_adv