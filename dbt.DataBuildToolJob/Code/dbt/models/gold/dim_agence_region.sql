/*
Fichier : models/gold/dim_agence_region.sql

Rôle :
- Créer la dimension Agence / Région.

Actions réalisées :
- Déduplique les agences avec row_number.
- Garde une seule ligne par agence_id.
- Génère une surrogate key agence_region_key.
- Ajoute une ligne UNKNOWN pour les faits sans agence valide.

Objectif :
- Garantir que dim_agence_region peut être utilisée côté 1 dans Power BI.
*/

{{ config(alias='dim_agence_region') }}

with source_dedup as (

    select
        *,
        row_number() over (
            partition by agence_id
            order by updated_at desc, created_at desc
        ) as rn
    from {{ ref('agences_regions') }}
    where agence_id is not null

),

dimension_rows as (

    select
        {{ dbt_utils.generate_surrogate_key(['agence_id']) }} as agence_region_key,
        agence_id,
        nom_agence,
        code_agence,
        region_id,
        nom_region,
        directeur_region_id,
        responsable_agence_id,
        ville,
        code_postal,
        adresse,
        pays,
        zone_commerciale,
        statut_agence,
        date_ouverture,
        date_fermeture,
        is_active,
        created_at,
        updated_at
    from source_dedup
    where rn = 1

),

unknown_row as (

    select
        {{ dbt_utils.generate_surrogate_key(["'__UNKNOWN__'"]) }} as agence_region_key,
        cast('__UNKNOWN__' as varchar(50)) as agence_id,
        cast('Agence inconnue' as varchar(255)) as nom_agence,
        cast('__UNKNOWN__' as varchar(50)) as code_agence,
        cast('__UNKNOWN__' as varchar(50)) as region_id,
        cast('Region inconnue' as varchar(255)) as nom_region,
        cast(null as varchar(50)) as directeur_region_id,
        cast(null as varchar(50)) as responsable_agence_id,
        cast(null as varchar(255)) as ville,
        cast(null as varchar(50)) as code_postal,
        cast(null as varchar(500)) as adresse,
        cast(null as varchar(50)) as pays,
        cast(null as varchar(255)) as zone_commerciale,
        cast('INCONNU' as varchar(50)) as statut_agence,
        cast(null as date) as date_ouverture,
        cast(null as date) as date_fermeture,
        cast(1 as bit) as is_active,
        cast(null as datetime2(6)) as created_at,
        cast(null as datetime2(6)) as updated_at

)

select * from dimension_rows
union all
select * from unknown_row