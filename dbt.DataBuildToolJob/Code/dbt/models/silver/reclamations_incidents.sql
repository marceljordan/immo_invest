/*
Fichier : models/silver/silver_reclamations_incidents.sql

Rôle :
- Créer la table Silver des réclamations et incidents clients.

Entrée :
- Lit la table Bronze du Lakehouse :
  LH_Immo_Dev.dbo.src_reclamations_incidents

Sortie :
- Crée une table dans le Warehouse :
  silver.reclamations_incidents

Actions réalisées :
- Conversion des identifiants en varchar(50)
- Conversion des dates en date / datetime2(6)
- Conversion des délais et impacts financiers en types numériques
- Normalisation des types, catégories, urgences et statuts
- Nettoyage des motifs et résolutions
- Conversion de is_deleted en bit

Objectif :
- Obtenir une table propre pour suivre les réclamations, incidents, délais de résolution et impacts financiers.
*/

{{ config(alias='reclamations_incidents') }}

select
    cast(reclamation_id as varchar(50)) as reclamation_id,
    cast(investisseur_id as varchar(50)) as investisseur_id,
    cast(partenaire_id as varchar(50)) as partenaire_id,
    cast(operation_id as varchar(50)) as operation_id,

    upper(trim(type_operation)) as type_operation,
    upper(trim(type_reclamation)) as type_reclamation,
    upper(trim(categorie_reclamation)) as categorie_reclamation,
    upper(trim(niveau_urgence)) as niveau_urgence,
    upper(trim(statut_reclamation)) as statut_reclamation,

    try_cast(date_ouverture as date) as date_ouverture,
    try_cast(date_resolution as date) as date_resolution,
    try_cast(delai_resolution_jours as int) as delai_resolution_jours,

    cast(responsable_traitement_id as varchar(50)) as responsable_traitement_id,

    trim(motif_reclamation) as motif_reclamation,
    trim(resolution_apportee) as resolution_apportee,

    try_cast(impact_financier_estime as decimal(18,2)) as impact_financier_estime,

    try_cast(created_at as datetime2(6)) as created_at,
    try_cast(updated_at as datetime2(6)) as updated_at,

    case
        when lower(trim(is_deleted)) in ('1', 'true', 'oui', 'yes') then cast(1 as bit)
        else cast(0 as bit)
    end as is_deleted

from LH_Immo_Dev.dbo.src_reclamations_incidents