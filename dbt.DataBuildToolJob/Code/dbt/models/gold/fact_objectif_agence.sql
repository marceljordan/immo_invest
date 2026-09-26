/*
Fichier : models/gold/fact_objectif_agence.sql

Rôle :
- Objectifs commerciaux fixés au niveau agence.

Grain Kimball :
- 1 ligne = 1 objectif agence par mois et type produit.
*/

{{ config(alias='fact_objectif_agence') }}

select
    {{ dbt_utils.generate_surrogate_key(['f.objectif_id']) }} as objectif_key,
    f.objectif_id,

    cast(convert(char(8), datefromparts(f.annee, f.mois, 1), 112) as int) as date_objectif_key,

    coalesce(da.agence_region_key, {{ dbt_utils.generate_surrogate_key(["'__UNKNOWN__'"]) }}) as agence_region_key,
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

left join {{ ref('dim_agence_region') }} da
    on f.agence_id = da.agence_id

where f.is_active = 1
  and upper(trim(f.niveau_objectif)) = 'AGENCE'