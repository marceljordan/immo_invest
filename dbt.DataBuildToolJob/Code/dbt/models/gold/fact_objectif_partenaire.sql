/*
Fichier : models/gold/fact_objectif_partenaire.sql

Rôle :
- Objectifs commerciaux fixés au niveau partenaire.

Grain Kimball :
- 1 ligne = 1 objectif partenaire par mois et type produit.
*/

{{ config(alias='fact_objectif_partenaire') }}

select
    {{ dbt_utils.generate_surrogate_key(['f.objectif_id']) }} as objectif_key,
    f.objectif_id,

    cast(convert(char(8), datefromparts(f.annee, f.mois, 1), 112) as int) as date_objectif_key,

    coalesce(dp.partenaire_key, {{ dbt_utils.generate_surrogate_key(["'__UNKNOWN__'"]) }}) as partenaire_key,
    f.partenaire_id,

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

left join {{ ref('dim_partenaire') }} dp
    on f.partenaire_id = dp.partenaire_id

where f.is_active = 1
  and upper(trim(f.niveau_objectif)) = 'PARTENAIRE'