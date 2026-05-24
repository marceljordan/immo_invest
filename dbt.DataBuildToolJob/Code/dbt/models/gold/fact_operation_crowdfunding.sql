/*
Fichier : models/gold/fact_operation_crowdfunding.sql

Rôle :
- Créer la table de faits des opérations de crowdfunding immobilier.

Grain Kimball :
- 1 ligne = 1 investissement crowdfunding réalisé par un investisseur.

Actions réalisées :
- Génère crowdfunding_key.
- Récupère les clés dimensionnelles via LEFT JOIN.
- Récupère statut_key depuis dim_statut.
- Envoie vers UNKNOWN si une dimension est absente.
- Conserve les mesures d’investissement, rendement, remboursement et intérêts.

Objectif :
- Garantir des relations valides vers investisseur, partenaire, conseiller, agence, date et statut.
*/

{{ config(alias='fact_operation_crowdfunding') }}

select
    {{ dbt_utils.generate_surrogate_key(['f.operation_crowdfunding_id']) }} as crowdfunding_key,

    f.operation_crowdfunding_id,
    f.projet_id,

    cast(convert(char(8), f.date_investissement, 112) as int) as date_investissement_key,
    cast(convert(char(8), f.date_remboursement_prevue, 112) as int) as date_remboursement_prevue_key,
    cast(convert(char(8), f.date_remboursement_reelle, 112) as int) as date_remboursement_reelle_key,

    coalesce(di.investisseur_key, {{ dbt_utils.generate_surrogate_key(["'__UNKNOWN__'"]) }}) as investisseur_key,
    coalesce(dp.partenaire_key, {{ dbt_utils.generate_surrogate_key(["'__UNKNOWN__'"]) }}) as partenaire_key,
    coalesce(dc.conseiller_key, {{ dbt_utils.generate_surrogate_key(["'__UNKNOWN__'"]) }}) as conseiller_key,
    coalesce(da.agence_region_key, {{ dbt_utils.generate_surrogate_key(["'__UNKNOWN__'"]) }}) as agence_region_key,
    coalesce(ds.statut_key, {{ dbt_utils.generate_surrogate_key(["'CROWDFUNDING'", "'__UNKNOWN__'"]) }}) as statut_key,

    f.investisseur_id,
    f.partenaire_id,
    f.conseiller_id,
    f.agence_id,
    f.promoteur_id,

    f.nom_projet,
    f.ville,
    f.region,

    f.montant_investi,
    f.taux_rendement_annuel_prevu,
    f.duree_mois,
    f.montant_rembourse,
    f.interets_bruts,

    f.fiscalite_appliquee,
    f.incident_paiement,
    f.statut_operation,

    f.created_at,
    f.updated_at

from {{ ref('operations_crowdfunding') }} f

left join {{ ref('dim_investisseur') }} di
    on f.investisseur_id = di.investisseur_id

left join {{ ref('dim_partenaire') }} dp
    on f.partenaire_id = dp.partenaire_id

left join {{ ref('dim_conseiller') }} dc
    on f.conseiller_id = dc.conseiller_id

left join {{ ref('dim_agence_region') }} da
    on f.agence_id = da.agence_id

left join {{ ref('dim_statut') }} ds
    on ds.domaine_statut = 'CROWDFUNDING'
   and ds.statut_value = upper(trim(f.statut_operation))

where f.is_deleted = 0