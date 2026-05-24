/*
Fichier : models/gold/dim_date.sql

Rôle :
- Créer la dimension Date du modèle Kimball.

Entrée :
- Lit les dates issues des tables Silver principales.

Sortie :
- Crée la table Gold :
  gold.dim_date

Actions réalisées :
- Centralise les dates utiles.
- Supprime les dates nulles.
- Crée une date_key au format YYYYMMDD.
- Ajoute les attributs calendaires : année, trimestre, mois, jour.

Objectif :
- Fournir une dimension date conforme pour toutes les tables de faits.
*/

{{ config(alias='dim_date') }}

with all_dates as (

    select date_reservation as full_date from {{ ref('reservations_immobilieres') }}
    union
    select date_annulation as full_date from {{ ref('reservations_immobilieres') }}
    union
    select date_expiration_reservation as full_date from {{ ref('reservations_immobilieres') }}

    union
    select date_signature_contrat as full_date from {{ ref('ventes_immobilieres') }}
    union
    select date_signature_acte as full_date from {{ ref('ventes_immobilieres') }}
    union
    select date_livraison_prevue as full_date from {{ ref('ventes_immobilieres') }}
    union
    select date_livraison_reelle as full_date from {{ ref('ventes_immobilieres') }}

    union
    select date_calcul as full_date from {{ ref('commissions') }}
    union
    select date_validation as full_date from {{ ref('commissions') }}
    union
    select date_paiement as full_date from {{ ref('commissions') }}

    union
    select datefromparts(annee, mois, 1) as full_date
    from {{ ref('objectifs_commerciaux') }}
    where annee is not null
      and mois is not null

    union
    select date_souscription as full_date from {{ ref('souscriptions_pierre_papier') }}
    union
    select date_validation as full_date from {{ ref('souscriptions_pierre_papier') }}
    union
    select date_rejet as full_date from {{ ref('souscriptions_pierre_papier') }}

    union
    select date_investissement as full_date from {{ ref('operations_crowdfunding') }}
    union
    select date_remboursement_prevue as full_date from {{ ref('operations_crowdfunding') }}
    union
    select date_remboursement_reelle as full_date from {{ ref('operations_crowdfunding') }}

    union
    select date_demande as full_date from {{ ref('financements') }}
    union
    select date_accord_principe as full_date from {{ ref('financements') }}
    union
    select date_offre_pret as full_date from {{ ref('financements') }}
    union
    select date_acceptation_offre as full_date from {{ ref('financements') }}

    union
    select date_debut_gestion as full_date from {{ ref('gestion_locative') }}
    union
    select date_fin_gestion as full_date from {{ ref('gestion_locative') }}

    union
    select date_demande_revente as full_date from {{ ref('revente_biens') }}
    union
    select date_mise_en_marche as full_date from {{ ref('revente_biens') }}
    union
    select date_revente as full_date from {{ ref('revente_biens') }}

    union
    select date_ouverture_dossier as full_date from {{ ref('dossiers_adv') }}
    union
    select date_reception_pieces as full_date from {{ ref('dossiers_adv') }}
    union
    select date_validation_dossier as full_date from {{ ref('dossiers_adv') }}
    union
    select date_envoi_notaire as full_date from {{ ref('dossiers_adv') }}
    union
    select date_signature_acte as full_date from {{ ref('dossiers_adv') }}

),

cleaned as (

    select distinct
        cast(full_date as date) as full_date
    from all_dates
    where full_date is not null

)

select
    cast(convert(char(8), full_date, 112) as int) as date_key,
    full_date,
    year(full_date) as annee,
    datepart(quarter, full_date) as trimestre,
    month(full_date) as mois,
    day(full_date) as jour,

    cast(datename(month, full_date) as varchar(30)) as nom_mois,
    cast(datename(weekday, full_date) as varchar(30)) as nom_jour,

    datepart(weekday, full_date) as numero_jour_semaine,

    (year(full_date) * 100 + month(full_date)) as annee_mois_key,
    cast(
        concat(
            year(full_date),
            '-',
            right(concat('0', month(full_date)), 2)
        ) as varchar(7)
    ) as annee_mois

from cleaned