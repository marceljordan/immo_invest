/*
Fichier : models/gold/fact_revente.sql

Rôle :
- Créer la table de faits des reventes de biens.

Grain Kimball :
- 1 ligne = 1 opération de revente d'un bien immobilier.

Actions réalisées :
- Génère revente_key.
- Récupère les clés dimensionnelles via LEFT JOIN.
- conseiller_key = conseiller qui gère la revente (conseiller_revente_id),
  à défaut le conseiller de la vente d'origine.
- agence_region_key = agence de ce conseiller.
- Récupère statut_key depuis dim_statut.
- Envoie vers UNKNOWN si une dimension est absente.
- Conserve les mesures de revente.

Objectif :
- Garantir des relations valides vers investisseur, conseiller, agence,
  programme, lot, date et statut (filtrage RLS géographique).
*/

{{ config(alias='fact_revente') }}

with vente_origine as (

    select
        vente_id,
        conseiller_id
    from {{ ref('ventes_immobilieres') }}
    where is_deleted = 0

),

revente as (

    select
        f.*,
        coalesce(f.conseiller_revente_id, vo.conseiller_id) as conseiller_id
    from {{ ref('revente_biens') }} f
    left join vente_origine vo
        on f.vente_id = vo.vente_id
    where f.is_deleted = 0

)

select
    {{ dbt_utils.generate_surrogate_key(['f.revente_id']) }} as revente_key,

    f.revente_id,
    f.vente_id,

    cast(convert(char(8), f.date_demande_revente, 112) as int) as date_demande_revente_key,
    cast(convert(char(8), f.date_mise_en_marche, 112) as int) as date_mise_en_marche_key,
    cast(convert(char(8), f.date_revente, 112) as int) as date_revente_key,

    coalesce(di.investisseur_key, {{ dbt_utils.generate_surrogate_key(["'__UNKNOWN__'"]) }}) as investisseur_key,
    coalesce(dc.conseiller_key, {{ dbt_utils.generate_surrogate_key(["'__UNKNOWN__'"]) }}) as conseiller_key,
    coalesce(dc.agence_region_key, {{ dbt_utils.generate_surrogate_key(["'__UNKNOWN__'"]) }}) as agence_region_key,
    coalesce(dp.programme_key, {{ dbt_utils.generate_surrogate_key(["'__UNKNOWN__'"]) }}) as programme_key,
    coalesce(dl.lot_key, {{ dbt_utils.generate_surrogate_key(["'__UNKNOWN__'"]) }}) as lot_key,
    coalesce(ds.statut_key, {{ dbt_utils.generate_surrogate_key(["'REVENTE'", "'__UNKNOWN__'"]) }}) as statut_key,

    f.investisseur_id,
    f.programme_id,
    f.lot_id,
    f.conseiller_revente_id,
    f.conseiller_id,

    f.prix_achat_initial,
    f.prix_revente_estime,
    f.prix_revente_final,
    f.plus_value_brute,
    f.plus_value_nette,
    f.nombre_visites,

    f.statut_revente,
    f.motif_revente,
    f.mandat_revente,

    f.created_at,
    f.updated_at

from revente f

left join {{ ref('dim_investisseur') }} di
    on f.investisseur_id = di.investisseur_id

left join {{ ref('dim_conseiller') }} dc
    on f.conseiller_id = dc.conseiller_id

left join {{ ref('dim_programme_immobilier') }} dp
    on f.programme_id = dp.programme_id

left join {{ ref('dim_lot_immobilier') }} dl
    on f.lot_id = dl.lot_id

left join {{ ref('dim_statut') }} ds
    on ds.domaine_statut = 'REVENTE'
   and ds.statut_value = upper(trim(f.statut_revente))