{{ config(
    materialized = 'table',
    schema = 'gold',
    alias = 'security_user_access'
) }}

with source_data as (

    select
        cast(user_access_id as varchar(50)) as user_access_id,
        lower(ltrim(rtrim(user_email))) as user_email,
        cast(user_name as varchar(255)) as user_name,

        upper(ltrim(rtrim(role_metier))) as role_metier,
        upper(ltrim(rtrim(access_level))) as access_level,

        cast(region_id as varchar(50)) as region_id,
        cast(agence_id as varchar(50)) as agence_id,
        cast(conseiller_id as varchar(50)) as conseiller_id,
        cast(partenaire_id as varchar(50)) as partenaire_id,

        cast(can_view_commissions as bit) as can_view_commissions,
        cast(can_view_margin as bit) as can_view_margin,
        cast(can_view_personal_data as bit) as can_view_personal_data,
        cast(can_export_data as bit) as can_export_data,

        cast(start_date as date) as start_date,
        cast(end_date as date) as end_date,

        cast(is_active as bit) as is_active,
        cast(created_at as datetime2(6)) as created_at,
        cast(updated_at as datetime2(6)) as updated_at

    from {{ ref('silver_security_user_access') }}

),

standardized as (

    select
        user_access_id,

        user_email,
        user_name,

        role_metier,
        access_level,

        nullif(region_id, '') as region_id,
        nullif(agence_id, '') as agence_id,
        nullif(conseiller_id, '') as conseiller_id,
        nullif(partenaire_id, '') as partenaire_id,

        coalesce(can_view_commissions, cast(0 as bit)) as can_view_commissions,
        coalesce(can_view_margin, cast(0 as bit)) as can_view_margin,
        coalesce(can_view_personal_data, cast(0 as bit)) as can_view_personal_data,
        coalesce(can_export_data, cast(0 as bit)) as can_export_data,

        start_date,
        end_date,

        coalesce(is_active, cast(1 as bit)) as is_active,
        created_at,
        updated_at

    from source_data
    where user_email is not null
      and user_email <> ''

),

deduplicated as (

    select
        *,
        row_number() over (
            partition by
                user_email,
                role_metier,
                access_level,
                coalesce(region_id, 'NO_REGION'),
                coalesce(agence_id, 'NO_AGENCE'),
                coalesce(conseiller_id, 'NO_CONSEILLER'),
                coalesce(partenaire_id, 'NO_PARTENAIRE')
            order by
                updated_at desc,
                created_at desc,
                user_access_id
        ) as rn
    from standardized

),

final as (

    select
        {{ dbt_utils.generate_surrogate_key([
            'user_email',
            'role_metier',
            'access_level',
            'region_id',
            'agence_id',
            'conseiller_id',
            'partenaire_id'
        ]) }} as security_access_key,

        user_access_id,
        user_email,
        user_name,

        role_metier,
        access_level,

        region_id,
        agence_id,
        conseiller_id,
        partenaire_id,

        can_view_commissions,
        can_view_margin,
        can_view_personal_data,
        can_export_data,

        start_date,
        end_date,
        is_active,

        created_at,
        updated_at

    from deduplicated
    where rn = 1

)

select *
from final