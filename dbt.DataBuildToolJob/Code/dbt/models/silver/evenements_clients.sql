/*
Fichier : models/silver/silver_evenements_clients.sql

Rôle :
- Créer la table Silver des événements clients : appels, emails, rendez-vous, relances, actions commerciales.

Entrée :
- Lit la table Bronze du Lakehouse :
  LH_Immo_Dev.dbo.src_evenements_clients

Sortie :
- Crée une table dans le Warehouse :
  silver.evenements_clients

Actions réalisées :
- Conversion des identifiants en varchar(50)
- Conversion des dates en date / datetime2(6)
- Normalisation des types, canaux, statuts et priorités
- Nettoyage des commentaires
- Conversion de is_deleted en bit

Objectif :
- Obtenir une table propre pour analyser l’activité relationnelle et commerciale autour des prospects/investisseurs.
*/

{{ config(alias='evenements_clients') }}

select
    cast(evenement_id as varchar(50)) as evenement_id,
    cast(investisseur_id as varchar(50)) as investisseur_id,
    cast(prospect_id as varchar(50)) as prospect_id,
    cast(partenaire_id as varchar(50)) as partenaire_id,
    cast(conseiller_id as varchar(50)) as conseiller_id,

    upper(trim(type_evenement)) as type_evenement,
    upper(trim(canal_evenement)) as canal_evenement,
    trim(objet_evenement) as objet_evenement,

    try_cast(date_evenement as datetime2(6)) as date_evenement,

    upper(trim(statut_evenement)) as statut_evenement,
    trim(resultat_evenement) as resultat_evenement,
    trim(prochaine_action) as prochaine_action,

    try_cast(date_prochaine_action as datetime2(6)) as date_prochaine_action,

    upper(trim(priorite)) as priorite,
    trim(commentaire) as commentaire,

    try_cast(created_at as datetime2(6)) as created_at,
    trim(created_by) as created_by,
    try_cast(updated_at as datetime2(6)) as updated_at,

    case
        when lower(trim(is_deleted)) in ('1', 'true', 'oui', 'yes') then cast(1 as bit)
        else cast(0 as bit)
    end as is_deleted

from {{ get_lakehouse() }}.dbo.src_evenements_clients