/*
Fichier : models/gold/fact_commission.sql

Rôle :
- Créer la table de faits des commissions.

Grain Kimball :
- 1 ligne = 1 commission calculée.

Actions réalisées :
- Récupère les clés dimensionnelles via LEFT JOIN.
- Récupère statut_key depuis dim_statut.
- Envoie vers UNKNOWN si une dimension est absente.

Objectif :
- Garantir des relations valides vers les dimensions Gold.
*/

{{ config(alias='fact_commission') }}

select
    {{ dbt_utils.generate_surrogate_key(['f.commission_id']) }} as commission_key,

    f.commission_id,
    f.operation_id,
    f.vente_id,
    f.souscription_id,
    f.operation_crowdfunding_id,

    cast(convert(char(8), f.date_calcul, 112) as int) as date_calcul_key,
    cast(convert(char(8), f.date_validation, 112) as int) as date_validation_key,
    cast(convert(char(8), f.date_paiement, 112) as int) as date_paiement_key,

    coalesce(di.investisseur_key, {{ dbt_utils.generate_surrogate_key(["'__UNKNOWN__'"]) }}) as investisseur_key,
    coalesce(dp.partenaire_key, {{ dbt_utils.generate_surrogate_key(["'__UNKNOWN__'"]) }}) as partenaire_key,
    coalesce(dc.conseiller_key, {{ dbt_utils.generate_surrogate_key(["'__UNKNOWN__'"]) }}) as conseiller_key,
    coalesce(da.agence_region_key, {{ dbt_utils.generate_surrogate_key(["'__UNKNOWN__'"]) }}) as agence_region_key,
    coalesce(dprod.produit_key, {{ dbt_utils.generate_surrogate_key(["'__UNKNOWN__'"]) }}) as produit_key,
    coalesce(dpr.programme_key, {{ dbt_utils.generate_surrogate_key(["'__UNKNOWN__'"]) }}) as programme_key,
    coalesce(ds.statut_key, {{ dbt_utils.generate_surrogate_key(["'COMMISSION'", "'__UNKNOWN__'"]) }}) as statut_key,

    f.investisseur_id,
    f.partenaire_id,
    f.conseiller_id,
    f.agence_id,
    f.produit_id,
    f.programme_id,

    f.type_operation,
    f.montant_operation,
    f.taux_commission,
    f.montant_commission_brut,
    f.montant_commission_net,
    f.part_commission_partenaire,
    f.part_commission_interne,

    f.statut_commission,
    f.mode_paiement,
    f.motif_blocage,

    f.created_at,
    f.updated_at

from {{ ref('commissions') }} f

left join {{ ref('dim_investisseur') }} di
    on f.investisseur_id = di.investisseur_id

left join {{ ref('dim_partenaire') }} dp
    on f.partenaire_id = dp.partenaire_id

left join {{ ref('dim_conseiller') }} dc
    on f.conseiller_id = dc.conseiller_id

left join {{ ref('dim_agence_region') }} da
    on f.agence_id = da.agence_id

left join {{ ref('dim_produit_investissement') }} dprod
    on f.produit_id = dprod.produit_id

left join {{ ref('dim_programme_immobilier') }} dpr
    on f.programme_id = dpr.programme_id

left join {{ ref('dim_statut') }} ds
    on ds.domaine_statut = 'COMMISSION'
   and ds.statut_value = upper(trim(f.statut_commission))

where f.is_deleted = 0