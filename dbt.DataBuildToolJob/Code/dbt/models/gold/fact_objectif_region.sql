/*
Fichier : models/gold/fact_objectif_region.sql

Rôle :
- Objectifs commerciaux fixés au niveau région.

Grain Kimball :
- 1 ligne = 1 objectif région par mois et type produit.
*/

{{ config(alias='fact_objectif_region') }}

select
    {{ dbt_utils.generate_surrogate_key(['f.objectif_id']) }} as objectif_key,
    f.objectif_id,

    cast(convert(char(8), datefromparts(f.annee, f.mois, 1), 112) as int) as date_objectif_key,

    coalesce(dr.region_key, {{ dbt_utils.generate_surrogate_key(["'__UNKNOWN__'"]) }}) as region_key,
    f.region_id,

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

left join {{ ref('dim_region') }} dr
    on f.region_id = dr.region_id

where f.is_active = 1
  and upper(trim(f.niveau_objectif)) = 'REGION'