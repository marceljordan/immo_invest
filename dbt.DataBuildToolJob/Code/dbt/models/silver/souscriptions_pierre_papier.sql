/*
Fichier : models/silver/silver_souscriptions_pierre_papier.sql

Rôle :
- Créer la table Silver des souscriptions en pierre-papier : SCPI / OPCI / autres supports assimilés.

Entrée :
- Lit la table Bronze du Lakehouse :
  LH_Immo_Dev.dbo.src_souscriptions_pierre_papier

Sortie :
- Crée une table dans le Warehouse :
  silver.souscriptions_pierre_papier

Actions réalisées :
- Conversion des identifiants en varchar(50)
- Conversion des dates en date / datetime2(6)
- Conversion des montants, prix de part, frais et rendements en decimal
- Conversion du nombre de parts en decimal(18,4)
- Normalisation des types de support, statuts et modes de paiement
- Nettoyage des motifs de rejet
- Conversion de is_deleted en bit

Objectif :
- Obtenir une table propre pour analyser les souscriptions financières de type SCPI / OPCI.
*/

{{ config(alias='souscriptions_pierre_papier') }}

select
    cast(souscription_id as varchar(50)) as souscription_id,
    cast(investisseur_id as varchar(50)) as investisseur_id,
    cast(partenaire_id as varchar(50)) as partenaire_id,
    cast(conseiller_id as varchar(50)) as conseiller_id,
    cast(agence_id as varchar(50)) as agence_id,
    cast(produit_id as varchar(50)) as produit_id,
    cast(societe_gestion_id as varchar(50)) as societe_gestion_id,

    upper(trim(type_support)) as type_support,
    trim(nom_support) as nom_support,

    try_cast(date_souscription as date) as date_souscription,

    try_cast(montant_souscrit as decimal(18,2)) as montant_souscrit,
    try_cast(nombre_parts as decimal(18,4)) as nombre_parts,
    try_cast(prix_part as decimal(18,2)) as prix_part,
    try_cast(frais_souscription as decimal(18,2)) as frais_souscription,

    trim(duree_recommandee) as duree_recommandee,
    try_cast(rendement_previsionnel as decimal(9,4)) as rendement_previsionnel,

    upper(trim(statut_souscription)) as statut_souscription,

    try_cast(date_validation as date) as date_validation,
    try_cast(date_rejet as date) as date_rejet,

    trim(motif_rejet) as motif_rejet,
    upper(trim(mode_paiement)) as mode_paiement,

    try_cast(created_at as datetime2(6)) as created_at,
    try_cast(updated_at as datetime2(6)) as updated_at,

    case
        when lower(trim(is_deleted)) in ('1', 'true', 'oui', 'yes') then cast(1 as bit)
        else cast(0 as bit)
    end as is_deleted

from {{ get_lakehouse() }}.dbo.src_souscriptions_pierre_papier