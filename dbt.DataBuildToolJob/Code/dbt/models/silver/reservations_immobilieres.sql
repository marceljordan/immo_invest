/*
Fichier : models/silver/silver_reservations_immobilieres.sql

Rôle :
- Créer la table Silver des réservations immobilières.

Entrée :
- Lit la table Bronze du Lakehouse :
  LH_Immo_Dev.dbo.src_reservations_immobilieres

Sortie :
- Crée une table dans le Warehouse :
  silver.reservations_immobilieres

Actions réalisées :
- Conversion des identifiants en varchar(50)
- Conversion des dates en date / datetime2(6)
- Conversion des montants, prix, remises, apports et crédits en decimal(18,2)
- Normalisation des statuts, canaux et modes de financement
- Nettoyage des motifs et commentaires
- Conversion de is_deleted en bit

Objectif :
- Obtenir une table propre pour analyser le tunnel de réservation avant vente.
*/

{{ config(alias='reservations_immobilieres') }}

select
    cast(reservation_id as varchar(50)) as reservation_id,
    cast(lot_id as varchar(50)) as lot_id,
    cast(programme_id as varchar(50)) as programme_id,
    cast(investisseur_id as varchar(50)) as investisseur_id,
    cast(partenaire_id as varchar(50)) as partenaire_id,
    cast(conseiller_id as varchar(50)) as conseiller_id,
    cast(agence_id as varchar(50)) as agence_id,

    try_cast(date_reservation as date) as date_reservation,

    try_cast(montant_reservation as decimal(18,2)) as montant_reservation,
    try_cast(prix_reserve as decimal(18,2)) as prix_reserve,
    try_cast(remise_appliquee as decimal(18,2)) as remise_appliquee,

    upper(trim(statut_reservation)) as statut_reservation,
    trim(motif_annulation) as motif_annulation,

    try_cast(date_annulation as date) as date_annulation,
    try_cast(date_expiration_reservation as date) as date_expiration_reservation,

    upper(trim(canal_reservation)) as canal_reservation,
    upper(trim(mode_financement_prevu)) as mode_financement_prevu,

    try_cast(apport_prevu as decimal(18,2)) as apport_prevu,
    try_cast(montant_credit_prevu as decimal(18,2)) as montant_credit_prevu,

    trim(commentaire_commercial) as commentaire_commercial,

    try_cast(created_at as datetime2(6)) as created_at,
    try_cast(updated_at as datetime2(6)) as updated_at,

    case
        when lower(trim(is_deleted)) in ('1', 'true', 'oui', 'yes') then cast(1 as bit)
        else cast(0 as bit)
    end as is_deleted

from {{ get_lakehouse() }}.dbo.src_reservations_immobilieres