/*
Fichier : models/gold/dim_programme_immobilier.sql

Rôle :
- Créer la dimension Programme immobilier.

Actions réalisées :
- Déduplique les programmes avec row_number.
- Garde une seule ligne par programme_id.
- Génère une surrogate key programme_key.
- Ajoute une ligne UNKNOWN pour les faits sans programme valide.

Objectif :
- Garantir que dim_programme_immobilier peut être utilisée côté 1 dans Power BI.
*/

{{ config(alias='dim_programme_immobilier') }}

with source_dedup as (

    select
        *,
        row_number() over (
            partition by programme_id
            order by updated_at desc, created_at desc
        ) as rn
    from {{ ref('programmes_immobiliers') }}
    where programme_id is not null

),

dimension_rows as (

    select
        {{ dbt_utils.generate_surrogate_key(['programme_id']) }} as programme_key,
        programme_id,
        nom_programme,
        type_programme,
        promoteur_id,
        ville,
        code_postal,
        region,
        adresse,
        latitude,
        longitude,
        type_actif,
        segment_marche,
        statut_programme,
        date_lancement_commercial,
        date_livraison_prevue,
        date_livraison_reelle,
        nombre_lots_total,
        nombre_lots_disponibles,
        prix_moyen_m2,
        rentabilite_cible,
        zone_fiscale,
        dispositif_fiscal,
        label_energetique,
        note_programme,
        is_active,
        created_at,
        updated_at
    from source_dedup
    where rn = 1

),

unknown_row as (

    select
        {{ dbt_utils.generate_surrogate_key(["'__UNKNOWN__'"]) }} as programme_key,
        cast('__UNKNOWN__' as varchar(50)) as programme_id,
        cast('Programme inconnu' as varchar(255)) as nom_programme,
        cast('INCONNU' as varchar(50)) as type_programme,
        cast(null as varchar(50)) as promoteur_id,
        cast(null as varchar(255)) as ville,
        cast(null as varchar(50)) as code_postal,
        cast(null as varchar(255)) as region,
        cast(null as varchar(500)) as adresse,
        cast(null as decimal(10,6)) as latitude,
        cast(null as decimal(10,6)) as longitude,
        cast('INCONNU' as varchar(50)) as type_actif,
        cast('INCONNU' as varchar(50)) as segment_marche,
        cast('INCONNU' as varchar(50)) as statut_programme,
        cast(null as date) as date_lancement_commercial,
        cast(null as date) as date_livraison_prevue,
        cast(null as date) as date_livraison_reelle,
        cast(null as int) as nombre_lots_total,
        cast(null as int) as nombre_lots_disponibles,
        cast(null as decimal(18,2)) as prix_moyen_m2,
        cast(null as decimal(9,4)) as rentabilite_cible,
        cast(null as varchar(50)) as zone_fiscale,
        cast(null as varchar(50)) as dispositif_fiscal,
        cast(null as varchar(50)) as label_energetique,
        cast(null as decimal(5,2)) as note_programme,
        cast(1 as bit) as is_active,
        cast(null as datetime2(6)) as created_at,
        cast(null as datetime2(6)) as updated_at

)

select * from dimension_rows
union all
select * from unknown_row