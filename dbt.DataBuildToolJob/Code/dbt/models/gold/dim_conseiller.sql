/*
Fichier : models/gold/dim_conseiller.sql

Rôle :
- Créer la dimension Conseiller commercial.

Actions réalisées :
- Déduplique les conseillers avec row_number.
- Garde une seule ligne par conseiller_id.
- Génère une surrogate key conseiller_key.
- Rattache le conseiller à une agence connue ou UNKNOWN.
- Ajoute une ligne UNKNOWN pour les faits sans conseiller valide.

Objectif :
- Garantir que dim_conseiller peut être utilisée côté 1 dans Power BI.
*/

{{ config(alias='dim_conseiller') }}

with source_dedup as (

    select
        *,
        row_number() over (
            partition by conseiller_id
            order by updated_at desc, created_at desc
        ) as rn
    from {{ ref('conseillers') }}
    where conseiller_id is not null

),

dimension_rows as (

    select
        {{ dbt_utils.generate_surrogate_key(['c.conseiller_id']) }} as conseiller_key,
        c.conseiller_id,
        c.matricule,
        c.nom,
        c.prenom,
        cast(concat(c.prenom, ' ', c.nom) as varchar(255)) as nom_complet,
        c.email,
        c.telephone,
        c.poste,
        c.agence_id,
        coalesce(a.agence_region_key, {{ dbt_utils.generate_surrogate_key(["'__UNKNOWN__'"]) }}) as agence_region_key,
        c.region_id,
        c.manager_id,
        c.date_arrivee,
        c.date_depart,
        c.statut_collaborateur,
        c.specialite_produit,
        c.objectif_annuel,
        c.objectif_mensuel_moyen,
        c.is_active,
        c.created_at,
        c.updated_at
    from source_dedup c
    left join {{ ref('dim_agence_region') }} a
        on c.agence_id = a.agence_id
    where c.rn = 1

),

unknown_row as (

    select
        {{ dbt_utils.generate_surrogate_key(["'__UNKNOWN__'"]) }} as conseiller_key,
        cast('__UNKNOWN__' as varchar(50)) as conseiller_id,
        cast(null as varchar(50)) as matricule,
        cast('Conseiller inconnu' as varchar(255)) as nom,
        cast(null as varchar(255)) as prenom,
        cast('Conseiller inconnu' as varchar(255)) as nom_complet,
        cast(null as varchar(255)) as email,
        cast(null as varchar(50)) as telephone,
        cast(null as varchar(255)) as poste,
        cast('__UNKNOWN__' as varchar(50)) as agence_id,
        {{ dbt_utils.generate_surrogate_key(["'__UNKNOWN__'"]) }} as agence_region_key,
        cast('__UNKNOWN__' as varchar(50)) as region_id,
        cast(null as varchar(50)) as manager_id,
        cast(null as date) as date_arrivee,
        cast(null as date) as date_depart,
        cast('INCONNU' as varchar(50)) as statut_collaborateur,
        cast(null as varchar(255)) as specialite_produit,
        cast(null as decimal(18,2)) as objectif_annuel,
        cast(null as decimal(18,2)) as objectif_mensuel_moyen,
        cast(1 as bit) as is_active,
        cast(null as datetime2(6)) as created_at,
        cast(null as datetime2(6)) as updated_at

)

select * from dimension_rows
union all
select * from unknown_row