/*
Fichier : models/silver/silver_financements.sql

Rôle :
- Créer la table Silver des financements associés aux ventes immobilières.

Entrée :
- Lit la table Bronze du Lakehouse :
  LH_Immo_Dev.dbo.src_financements

Sortie :
- Crée une table dans le Warehouse :
  silver.financements

Actions réalisées :
- Conversion des identifiants en varchar(50)
- Conversion des montants en decimal(18,2)
- Conversion des taux en decimal(9,4)
- Conversion des durées en int
- Conversion des dates en date / datetime2(6)
- Normalisation des statuts, banques et courtiers
- Conversion de is_deleted en bit

Objectif :
- Obtenir une table propre pour suivre l’avancement des dossiers de financement.
*/

{{ config(alias='financements') }}

select
    cast(financement_id as varchar(50)) as financement_id,
    cast(vente_id as varchar(50)) as vente_id,
    cast(investisseur_id as varchar(50)) as investisseur_id,

    upper(trim(banque)) as banque,
    trim(courtier) as courtier,

    try_cast(montant_demande as decimal(18,2)) as montant_demande,
    try_cast(montant_accorde as decimal(18,2)) as montant_accorde,
    try_cast(taux_credit as decimal(9,4)) as taux_credit,
    try_cast(duree_credit_mois as int) as duree_credit_mois,
    try_cast(mensualite_estimee as decimal(18,2)) as mensualite_estimee,

    upper(trim(statut_financement)) as statut_financement,

    try_cast(date_demande as date) as date_demande,
    try_cast(date_accord_principe as date) as date_accord_principe,
    try_cast(date_offre_pret as date) as date_offre_pret,
    try_cast(date_acceptation_offre as date) as date_acceptation_offre,

    trim(motif_refus) as motif_refus,
    try_cast(apport_personnel as decimal(18,2)) as apport_personnel,
    try_cast(assurance_emprunteur as decimal(18,2)) as assurance_emprunteur,

    try_cast(created_at as datetime2(6)) as created_at,
    try_cast(updated_at as datetime2(6)) as updated_at,

    case
        when lower(trim(is_deleted)) in ('1', 'true', 'oui', 'yes') then cast(1 as bit)
        else cast(0 as bit)
    end as is_deleted

from {{ get_lakehouse() }}.dbo.src_financements