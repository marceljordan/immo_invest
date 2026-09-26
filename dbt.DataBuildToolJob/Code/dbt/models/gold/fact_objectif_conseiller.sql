/*
Fichier : models/gold/fact_objectif_conseiller.sql

Rôle :
- Objectifs commerciaux fixés au niveau conseiller.

Grain Kimball :
- 1 ligne = 1 objectif conseiller par mois et type produit.

Note :
- agence_region_key est conservée pour permettre le filtre par agence/région
  et la RLS géographique.
*/

{{ config(alias='fact_objectif_conseiller') }}

select
    {{ dbt_utils.generate_surrogate_key(['f.objectif_id']) }} as objectif_key,
    f.objectif_id,

    cast(convert(char(8), datefromparts(f.annee, f.mois, 1), 112) as int) as date_objectif_key,

    coalesce(dc.conseiller_key, {{ dbt_utils.generate_surrogate_key(["'__UNKNOWN__'"]) }}) as conseiller_key,
    coalesce(da.agence_region_key, {{ dbt_utils.generate_surrogate_key(["'__UNKNOWN__'"]) }}) as agence_region_key,
    f.conseiller_id,
    f.agence_id,

    f.annee,
    f.mois,
    f.periode,
    f.famille_produit,
    f.type_produit,

    f.objectif_ca,
    f.objectif_nombre_ventes,
    f.objectif_nombre_reservations,
    f.objectif_montant_souscriptions,
    f.objectif_commissions,
    f.objectif_nouveaux_clients,

    f.created_at,
    f.updated_at

from {{ ref('objectifs_commerciaux') }} f

left join {{ ref('dim_conseiller') }} dc
    on f.conseiller_id = dc.conseiller_id

left join {{ ref('dim_agence_region') }} da
    on f.agence_id = da.agence_id

where f.is_active = 1
  and upper(trim(f.niveau_objectif)) = 'CONSEILLER'