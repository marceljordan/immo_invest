/*
Fichier : models/gold/fact_reservation.sql

Rôle :
- Créer la table de faits des réservations immobilières.

Grain Kimball :
- 1 ligne = 1 réservation immobilière.

Actions réalisées :
- Récupère les clés dimensionnelles via LEFT JOIN.
- Récupère statut_key depuis dim_statut.
- Envoie vers UNKNOWN si une dimension est absente.

Objectif :
- Garantir des relations valides vers les dimensions Gold.
*/

{{ config(alias='fact_reservation') }}

select
    {{ dbt_utils.generate_surrogate_key(['f.reservation_id']) }} as reservation_key,

    f.reservation_id,

    cast(convert(char(8), f.date_reservation, 112) as int) as date_reservation_key,
    cast(convert(char(8), f.date_annulation, 112) as int) as date_annulation_key,
    cast(convert(char(8), f.date_expiration_reservation, 112) as int) as date_expiration_reservation_key,

    coalesce(di.investisseur_key, {{ dbt_utils.generate_surrogate_key(["'__UNKNOWN__'"]) }}) as investisseur_key,
    coalesce(dp.partenaire_key, {{ dbt_utils.generate_surrogate_key(["'__UNKNOWN__'"]) }}) as partenaire_key,
    coalesce(dc.conseiller_key, {{ dbt_utils.generate_surrogate_key(["'__UNKNOWN__'"]) }}) as conseiller_key,
    coalesce(da.agence_region_key, {{ dbt_utils.generate_surrogate_key(["'__UNKNOWN__'"]) }}) as agence_region_key,
    coalesce(dpr.programme_key, {{ dbt_utils.generate_surrogate_key(["'__UNKNOWN__'"]) }}) as programme_key,
    coalesce(dl.lot_key, {{ dbt_utils.generate_surrogate_key(["'__UNKNOWN__'"]) }}) as lot_key,
    coalesce(ds.statut_key, {{ dbt_utils.generate_surrogate_key(["'RESERVATION'", "'__UNKNOWN__'"]) }}) as statut_key,

    f.lot_id,
    f.programme_id,
    f.investisseur_id,
    f.partenaire_id,
    f.conseiller_id,
    f.agence_id,

    f.montant_reservation,
    f.prix_reserve,
    f.remise_appliquee,
    f.apport_prevu,
    f.montant_credit_prevu,

    f.canal_reservation,
    f.mode_financement_prevu,
    f.statut_reservation,
    f.motif_annulation,

    f.created_at,
    f.updated_at

from {{ ref('reservations_immobilieres') }} f

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
    on ds.domaine_statut = 'RESERVATION'
   and ds.statut_value = upper(trim(f.statut_reservation))

where f.is_deleted = 0