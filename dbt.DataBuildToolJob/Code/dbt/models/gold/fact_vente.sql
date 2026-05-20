/*
Fichier : models/gold/fact_vente.sql

Rôle :
- Créer la table de faits des ventes immobilières.

Grain Kimball :
- 1 ligne = 1 vente immobilière.

Actions réalisées :
- Récupère les clés dimensionnelles via LEFT JOIN.
- Récupère statut_key depuis dim_statut.
- Envoie vers UNKNOWN si une dimension est absente.

Objectif :
- Garantir des relations valides vers les dimensions Gold.
*/

{{ config(alias='fact_vente') }}

select
    {{ dbt_utils.generate_surrogate_key(['f.vente_id']) }} as vente_key,

    f.vente_id,
    f.reservation_id,

    cast(convert(char(8), f.date_signature_contrat, 112) as int) as date_signature_contrat_key,
    cast(convert(char(8), f.date_signature_acte, 112) as int) as date_signature_acte_key,
    cast(convert(char(8), f.date_livraison_prevue, 112) as int) as date_livraison_prevue_key,
    cast(convert(char(8), f.date_livraison_reelle, 112) as int) as date_livraison_reelle_key,

    coalesce(di.investisseur_key, {{ dbt_utils.generate_surrogate_key(["'__UNKNOWN__'"]) }}) as investisseur_key,
    coalesce(dp.partenaire_key, {{ dbt_utils.generate_surrogate_key(["'__UNKNOWN__'"]) }}) as partenaire_key,
    coalesce(dc.conseiller_key, {{ dbt_utils.generate_surrogate_key(["'__UNKNOWN__'"]) }}) as conseiller_key,
    coalesce(da.agence_region_key, {{ dbt_utils.generate_surrogate_key(["'__UNKNOWN__'"]) }}) as agence_region_key,
    coalesce(dpr.programme_key, {{ dbt_utils.generate_surrogate_key(["'__UNKNOWN__'"]) }}) as programme_key,
    coalesce(dl.lot_key, {{ dbt_utils.generate_surrogate_key(["'__UNKNOWN__'"]) }}) as lot_key,
    coalesce(ds.statut_key, {{ dbt_utils.generate_surrogate_key(["'VENTE'", "'__UNKNOWN__'"]) }}) as statut_key,

    f.lot_id,
    f.programme_id,
    f.investisseur_id,
    f.partenaire_id,
    f.conseiller_id,
    f.agence_id,

    f.prix_vente_ht,
    f.prix_vente_ttc,
    f.tva,
    f.frais_notaire,
    f.montant_total_operation,
    f.montant_apport,
    f.montant_credit,

    f.mode_financement,
    f.banque_financement,
    f.statut_vente,
    f.motif_echec,

    f.created_at,
    f.updated_at

from {{ ref('ventes_immobilieres') }} f

left join {{ ref('dim_investisseur') }} di
    on f.investisseur_id = di.investisseur_id

left join {{ ref('dim_partenaire') }} dp
    on f.partenaire_id = dp.partenaire_id

left join {{ ref('dim_conseiller') }} dc
    on f.conseiller_id = dc.conseiller_id

left join {{ ref('dim_agence_region') }} da
    on f.agence_id = da.agence_id

left join {{ ref('dim_programme_immobilier') }} dpr
    on f.programme_id = dpr.programme_id

left join {{ ref('dim_lot_immobilier') }} dl
    on f.lot_id = dl.lot_id

left join {{ ref('dim_statut') }} ds
    on ds.domaine_statut = 'VENTE'
   and ds.statut_value = upper(trim(f.statut_vente))

where f.is_deleted = 0