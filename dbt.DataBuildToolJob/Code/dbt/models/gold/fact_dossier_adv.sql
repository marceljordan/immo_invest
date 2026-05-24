/*
Fichier : models/gold/fact_dossier_adv.sql

Rôle :
- Créer la table de faits des dossiers ADV.

Grain Kimball :
- 1 ligne = 1 dossier d’administration des ventes.

Actions réalisées :
- Génère dossier_adv_key.
- Récupère les clés dimensionnelles via LEFT JOIN.
- Récupère statut_key depuis dim_statut.
- Envoie vers UNKNOWN si une dimension est absente.
- Conserve les mesures de suivi ADV.

Objectif :
- Garantir des relations valides vers investisseur, partenaire, conseiller,
  programme, lot, date et statut.
*/

{{ config(alias='fact_dossier_adv') }}

select
    {{ dbt_utils.generate_surrogate_key(['f.dossier_adv_id']) }} as dossier_adv_key,

    f.dossier_adv_id,
    f.vente_id,
    f.reservation_id,

    cast(convert(char(8), f.date_ouverture_dossier, 112) as int) as date_ouverture_dossier_key,
    cast(convert(char(8), f.date_reception_pieces, 112) as int) as date_reception_pieces_key,
    cast(convert(char(8), f.date_validation_dossier, 112) as int) as date_validation_dossier_key,
    cast(convert(char(8), f.date_envoi_notaire, 112) as int) as date_envoi_notaire_key,
    cast(convert(char(8), f.date_signature_acte, 112) as int) as date_signature_acte_key,

    coalesce(di.investisseur_key, {{ dbt_utils.generate_surrogate_key(["'__UNKNOWN__'"]) }}) as investisseur_key,
    coalesce(dp.partenaire_key, {{ dbt_utils.generate_surrogate_key(["'__UNKNOWN__'"]) }}) as partenaire_key,
    coalesce(dc.conseiller_key, {{ dbt_utils.generate_surrogate_key(["'__UNKNOWN__'"]) }}) as conseiller_key,
    coalesce(dpr.programme_key, {{ dbt_utils.generate_surrogate_key(["'__UNKNOWN__'"]) }}) as programme_key,
    coalesce(dl.lot_key, {{ dbt_utils.generate_surrogate_key(["'__UNKNOWN__'"]) }}) as lot_key,
    coalesce(ds.statut_key, {{ dbt_utils.generate_surrogate_key(["'DOSSIER_ADV'", "'__UNKNOWN__'"]) }}) as statut_key,

    f.investisseur_id,
    f.partenaire_id,
    f.conseiller_id,
    f.programme_id,
    f.lot_id,
    f.responsable_adv_id,

    f.statut_dossier,
    f.delai_traitement_jours,
    f.pieces_manquantes,
    f.nombre_relances,
    f.blocage_adv,
    f.motif_blocage,
    f.commentaire_adv,

    f.created_at,
    f.updated_at

from {{ ref('dossiers_adv') }} f

left join {{ ref('dim_investisseur') }} di
    on f.investisseur_id = di.investisseur_id

left join {{ ref('dim_partenaire') }} dp
    on f.partenaire_id = dp.partenaire_id

left join {{ ref('dim_conseiller') }} dc
    on f.conseiller_id = dc.conseiller_id

left join {{ ref('dim_programme_immobilier') }} dpr
    on f.programme_id = dpr.programme_id

left join {{ ref('dim_lot_immobilier') }} dl
    on f.lot_id = dl.lot_id

left join {{ ref('dim_statut') }} ds
    on ds.domaine_statut = 'DOSSIER_ADV'
   and ds.statut_value = upper(trim(f.statut_dossier))

where f.is_deleted = 0