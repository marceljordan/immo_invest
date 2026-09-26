/*
Fichier : models/gold/fact_gestion_locative.sql

Rôle :
- Créer la table de faits de gestion locative.

Grain Kimball :
- 1 ligne = 1 dossier de gestion locative pour un lot vendu.

Actions réalisées :
- Génère gestion_locative_key.
- Récupère les clés dimensionnelles via LEFT JOIN.
- Récupère conseiller_key et agence_region_key depuis la vente d'origine
  (source ventes_immobilieres, pas fact_vente).
- Récupère statut_key depuis dim_statut.
- Envoie vers UNKNOWN si une dimension est absente.
- Conserve les mesures locatives.

Objectif :
- Garantir des relations valides vers investisseur, conseiller, agence,
  programme, lot, date et statut (filtrage RLS géographique).
*/

{{ config(alias='fact_gestion_locative') }}

with vente_origine as (

    select
        vente_id,
        conseiller_id,
        agence_id
    from {{ ref('ventes_immobilieres') }}
    where is_deleted = 0

)

select
    {{ dbt_utils.generate_surrogate_key(['f.gestion_id']) }} as gestion_locative_key,

    f.gestion_id,
    f.vente_id,

    cast(convert(char(8), f.date_debut_gestion, 112) as int) as date_debut_gestion_key,
    cast(convert(char(8), f.date_fin_gestion, 112) as int) as date_fin_gestion_key,

    coalesce(di.investisseur_key, {{ dbt_utils.generate_surrogate_key(["'__UNKNOWN__'"]) }}) as investisseur_key,
    coalesce(dc.conseiller_key, {{ dbt_utils.generate_surrogate_key(["'__UNKNOWN__'"]) }}) as conseiller_key,
    coalesce(da.agence_region_key, {{ dbt_utils.generate_surrogate_key(["'__UNKNOWN__'"]) }}) as agence_region_key,
    coalesce(dp.programme_key, {{ dbt_utils.generate_surrogate_key(["'__UNKNOWN__'"]) }}) as programme_key,
    coalesce(dl.lot_key, {{ dbt_utils.generate_surrogate_key(["'__UNKNOWN__'"]) }}) as lot_key,
    coalesce(ds.statut_key, {{ dbt_utils.generate_surrogate_key(["'GESTION_LOCATIVE'", "'__UNKNOWN__'"]) }}) as statut_key,

    f.investisseur_id,
    vo.conseiller_id,
    vo.agence_id,
    f.programme_id,
    f.lot_id,
    f.gestionnaire_id,

    f.loyer_mensuel_prevu,
    f.loyer_mensuel_reel,
    f.taux_occupation,
    f.vacance_locative_jours,
    f.charges_mensuelles,
    f.incident_locatif,
    f.montant_impayes,
    f.rendement_reel_annuel,

    f.statut_gestion,
    f.is_active,
    f.created_at,
    f.updated_at

from {{ ref('gestion_locative') }} f

left join vente_origine vo
    on f.vente_id = vo.vente_id

left join {{ ref('dim_investisseur') }} di
    on f.investisseur_id = di.investisseur_id

left join {{ ref('dim_conseiller') }} dc
    on vo.conseiller_id = dc.conseiller_id

left join {{ ref('dim_agence_region') }} da
    on vo.agence_id = da.agence_id

left join {{ ref('dim_programme_immobilier') }} dp
    on f.programme_id = dp.programme_id

left join {{ ref('dim_lot_immobilier') }} dl
    on f.lot_id = dl.lot_id

left join {{ ref('dim_statut') }} ds
    on ds.domaine_statut = 'GESTION_LOCATIVE'
   and ds.statut_value = upper(trim(f.statut_gestion))

where f.is_active = 1