/*
Fichier : models/gold/fact_souscription_pierre_papier.sql

Rôle :
- Créer la table de faits des souscriptions pierre-papier.

Grain Kimball :
- 1 ligne = 1 souscription.

Actions réalisées :
- Récupère les clés dimensionnelles via LEFT JOIN.
- Récupère statut_key depuis dim_statut.
- Envoie vers UNKNOWN si une dimension est absente.

Objectif :
- Garantir des relations valides vers les dimensions Gold.
*/

{{ config(alias='fact_souscription_pierre_papier') }}

select
    {{ dbt_utils.generate_surrogate_key(['f.souscription_id']) }} as souscription_key,

    f.souscription_id,

    cast(convert(char(8), f.date_souscription, 112) as int) as date_souscription_key,
    cast(convert(char(8), f.date_validation, 112) as int) as date_validation_key,
    cast(convert(char(8), f.date_rejet, 112) as int) as date_rejet_key,

    coalesce(di.investisseur_key, {{ dbt_utils.generate_surrogate_key(["'__UNKNOWN__'"]) }}) as investisseur_key,
    coalesce(dp.partenaire_key, {{ dbt_utils.generate_surrogate_key(["'__UNKNOWN__'"]) }}) as partenaire_key,
    coalesce(dc.conseiller_key, {{ dbt_utils.generate_surrogate_key(["'__UNKNOWN__'"]) }}) as conseiller_key,
    coalesce(da.agence_region_key, {{ dbt_utils.generate_surrogate_key(["'__UNKNOWN__'"]) }}) as agence_region_key,
    coalesce(dprod.produit_key, {{ dbt_utils.generate_surrogate_key(["'__UNKNOWN__'"]) }}) as produit_key,
    coalesce(ds.statut_key, {{ dbt_utils.generate_surrogate_key(["'SOUSCRIPTION'", "'__UNKNOWN__'"]) }}) as statut_key,

    f.investisseur_id,
    f.partenaire_id,
    f.conseiller_id,
    f.agence_id,
    f.produit_id,
    f.societe_gestion_id,

    f.type_support,
    f.nom_support,

    f.montant_souscrit,
    f.nombre_parts,
    f.prix_part,
    f.frais_souscription,
    f.rendement_previsionnel,

    f.duree_recommandee,
    f.statut_souscription,
    f.motif_rejet,
    f.mode_paiement,

    f.created_at,
    f.updated_at

from {{ ref('souscriptions_pierre_papier') }} f

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

left join {{ ref('dim_statut') }} ds
    on ds.domaine_statut = 'SOUSCRIPTION'
   and ds.statut_value = upper(trim(f.statut_souscription))

where f.is_deleted = 0