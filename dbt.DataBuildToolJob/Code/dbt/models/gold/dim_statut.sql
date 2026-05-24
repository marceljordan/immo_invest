/*
Fichier : models/gold/dim_statut.sql

Rôle :
- Créer une dimension Statut transverse.

Actions réalisées :
- Centralise les statuts métier.
- Ajoute une ligne UNKNOWN par domaine de statut.
- Génère une surrogate key composite avec dbt_utils.

Objectif :
- Permettre aux facts de pointer vers une dimension statut valide,
  même si le statut source est absent ou non reconnu.
*/

{{ config(alias='dim_statut') }}

with statuts_sources as (

    select 'RESERVATION' as domaine_statut, statut_reservation as statut_value
    from {{ ref('reservations_immobilieres') }}

    union

    select 'VENTE' as domaine_statut, statut_vente as statut_value
    from {{ ref('ventes_immobilieres') }}

    union

    select 'COMMISSION' as domaine_statut, statut_commission as statut_value
    from {{ ref('commissions') }}

    union

    select 'SOUSCRIPTION' as domaine_statut, statut_souscription as statut_value
    from {{ ref('souscriptions_pierre_papier') }}

    union

    select 'CROWDFUNDING' as domaine_statut, statut_operation as statut_value
    from {{ ref('operations_crowdfunding') }}

    union

    select 'FINANCEMENT' as domaine_statut, statut_financement as statut_value
    from {{ ref('financements') }}

    union

    select 'GESTION_LOCATIVE' as domaine_statut, statut_gestion as statut_value
    from {{ ref('gestion_locative') }}

    union

    select 'REVENTE' as domaine_statut, statut_revente as statut_value
    from {{ ref('revente_biens') }}

    union

    select 'DOSSIER_ADV' as domaine_statut, statut_dossier as statut_value
    from {{ ref('dossiers_adv') }}

    union

    select 'RECLAMATION' as domaine_statut, statut_reclamation as statut_value
    from {{ ref('reclamations_incidents') }}

),

statuts_clean as (

    select distinct
        domaine_statut,
        cast(upper(trim(statut_value)) as varchar(100)) as statut_value
    from statuts_sources
    where statut_value is not null

),

unknown_rows as (

    select 'RESERVATION' as domaine_statut, cast('__UNKNOWN__' as varchar(100)) as statut_value
    union all select 'VENTE', cast('__UNKNOWN__' as varchar(100))
    union all select 'COMMISSION', cast('__UNKNOWN__' as varchar(100))
    union all select 'SOUSCRIPTION', cast('__UNKNOWN__' as varchar(100))
    union all select 'CROWDFUNDING', cast('__UNKNOWN__' as varchar(100))
    union all select 'FINANCEMENT', cast('__UNKNOWN__' as varchar(100))
    union all select 'GESTION_LOCATIVE', cast('__UNKNOWN__' as varchar(100))
    union all select 'REVENTE', cast('__UNKNOWN__' as varchar(100))
    union all select 'DOSSIER_ADV', cast('__UNKNOWN__' as varchar(100))
    union all select 'RECLAMATION', cast('__UNKNOWN__' as varchar(100))

),

final as (

    select * from statuts_clean
    union
    select * from unknown_rows

)

select
    {{ dbt_utils.generate_surrogate_key(['domaine_statut', 'statut_value']) }} as statut_key,
    domaine_statut,
    statut_value

from final