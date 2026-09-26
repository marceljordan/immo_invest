/*
Fichier : models/gold/dim_region.sql

Rôle :
- Dimension réduite (shrunken rollup, Kimball) au grain de la région.
- Permet de rattacher les faits au grain région (objectifs région),
  qui ne peuvent pas pointer vers dim_agence_region (grain agence).

Grain :
- 1 ligne = 1 région + 1 ligne UNKNOWN.

Conformité :
- region_id et nom_region proviennent de dim_agence_region : mêmes valeurs,
  mêmes libellés. Dans le modèle sémantique, dim_region filtre dim_agence_region
  via region_id.
*/

{{ config(alias='dim_region') }}

with regions as (

    select
        region_id,
        max(nom_region) as nom_region
    from {{ ref('dim_agence_region') }}
    where region_id is not null
      and region_id <> '__UNKNOWN__'
    group by region_id

)

select
    {{ dbt_utils.generate_surrogate_key(['region_id']) }} as region_key,
    region_id,
    nom_region
from regions

union all

select
    {{ dbt_utils.generate_surrogate_key(["'__UNKNOWN__'"]) }} as region_key,
    '__UNKNOWN__' as region_id,
    'Inconnue'    as nom_region