/*
Fichier : models/silver/silver_ventes_immobilieres.sql

Rôle :
- Créer la table Silver des ventes immobilières.

Entrée :
- Lit la table Bronze du Lakehouse :
  LH_Immo_Dev.dbo.src_ventes_immobilieres

Sortie :
- Crée une table dans le Warehouse :
  silver.ventes_immobilieres

Actions réalisées :
- Conversion des identifiants en varchar(50)
- Conversion des dates en date / datetime2(6)
- Conversion des prix, TVA, frais et montants de financement en decimal(18,2)
- Normalisation des statuts, modes de financement et banques
- Nettoyage des motifs d’échec
- Conversion de is_deleted en bit

Objectif :
- Obtenir une table propre pour construire la table de faits des ventes immobilières en Gold.
*/

{{ config(alias='ventes_immobilieres') }}

select
    cast(vente_id as varchar(50)) as vente_id,
    cast(reservation_id as varchar(50)) as reservation_id,
    cast(lot_id as varchar(50)) as lot_id,
    cast(programme_id as varchar(50)) as programme_id,
    cast(investisseur_id as varchar(50)) as investisseur_id,
    cast(partenaire_id as varchar(50)) as partenaire_id,
    cast(conseiller_id as varchar(50)) as conseiller_id,
    cast(agence_id as varchar(50)) as agence_id,

    try_cast(date_signature_contrat as date) as date_signature_contrat,
    try_cast(date_signature_acte as date) as date_signature_acte,
    try_cast(date_livraison_prevue as date) as date_livraison_prevue,
    try_cast(date_livraison_reelle as date) as date_livraison_reelle,

    try_cast(prix_vente_ht as decimal(18,2)) as prix_vente_ht,
    try_cast(prix_vente_ttc as decimal(18,2)) as prix_vente_ttc,
    try_cast(tva as decimal(18,2)) as tva,
    try_cast(frais_notaire as decimal(18,2)) as frais_notaire,
    try_cast(montant_total_operation as decimal(18,2)) as montant_total_operation,

    upper(trim(mode_financement)) as mode_financement,

    try_cast(montant_apport as decimal(18,2)) as montant_apport,
    try_cast(montant_credit as decimal(18,2)) as montant_credit,

    upper(trim(banque_financement)) as banque_financement,
    upper(trim(statut_vente)) as statut_vente,
    trim(motif_echec) as motif_echec,

    try_cast(created_at as datetime2(6)) as created_at,
    try_cast(updated_at as datetime2(6)) as updated_at,

    case
        when lower(trim(is_deleted)) in ('1', 'true', 'oui', 'yes') then cast(1 as bit)
        else cast(0 as bit)
    end as is_deleted

from LH_Immo_Dev.dbo.src_ventes_immobilieres