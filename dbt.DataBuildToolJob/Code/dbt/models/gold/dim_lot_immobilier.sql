/*
Fichier : models/gold/dim_lot_immobilier.sql

Rôle :
- Créer la dimension Lot immobilier.

Actions réalisées :
- Déduplique les lots avec row_number.
- Garde une seule ligne par lot_id.
- Génère une surrogate key lot_key.
- Rattache le lot à un programme connu ou UNKNOWN.
- Ajoute une ligne UNKNOWN pour les faits sans lot valide.

Objectif :
- Garantir que dim_lot_immobilier peut être utilisée côté 1 dans Power BI.
*/

{{ config(alias='dim_lot_immobilier') }}

with source_dedup as (

    select
        *,
        row_number() over (
            partition by lot_id
            order by updated_at desc, created_at desc
        ) as rn
    from {{ ref('lots_immobiliers') }}
    where lot_id is not null

),

dimension_rows as (

    select
        {{ dbt_utils.generate_surrogate_key(['l.lot_id']) }} as lot_key,
        l.lot_id,
        l.programme_id,
        coalesce(p.programme_key, {{ dbt_utils.generate_surrogate_key(["'__UNKNOWN__'"]) }}) as programme_key,
        l.numero_lot,
        l.type_lot,
        l.typologie,
        l.surface_m2,
        l.etage,
        l.orientation,
        l.parking_inclus,
        l.prix_catalogue,
        l.prix_remise,
        l.prix_final,
        l.loyer_estime_mensuel,
        l.rentabilite_brute_estimee,
        l.statut_lot,
        l.date_disponibilite,
        l.date_reservation,
        l.date_vente,
        l.investisseur_id,
        l.partenaire_id,
        l.is_active,
        l.created_at,
        l.updated_at
    from source_dedup l
    left join {{ ref('dim_programme_immobilier') }} p
        on l.programme_id = p.programme_id
    where l.rn = 1

),

unknown_row as (

    select
        {{ dbt_utils.generate_surrogate_key(["'__UNKNOWN__'"]) }} as lot_key,
        cast('__UNKNOWN__' as varchar(50)) as lot_id,
        cast('__UNKNOWN__' as varchar(50)) as programme_id,
        {{ dbt_utils.generate_surrogate_key(["'__UNKNOWN__'"]) }} as programme_key,
        cast('Lot inconnu' as varchar(50)) as numero_lot,
        cast('INCONNU' as varchar(50)) as type_lot,
        cast('INCONNU' as varchar(50)) as typologie,
        cast(null as decimal(10,2)) as surface_m2,
        cast(null as int) as etage,
        cast(null as varchar(50)) as orientation,
        cast(0 as bit) as parking_inclus,
        cast(null as decimal(18,2)) as prix_catalogue,
        cast(null as decimal(18,2)) as prix_remise,
        cast(null as decimal(18,2)) as prix_final,
        cast(null as decimal(18,2)) as loyer_estime_mensuel,
        cast(null as decimal(9,4)) as rentabilite_brute_estimee,
        cast('INCONNU' as varchar(50)) as statut_lot,
        cast(null as date) as date_disponibilite,
        cast(null as date) as date_reservation,
        cast(null as date) as date_vente,
        cast(null as varchar(50)) as investisseur_id,
        cast(null as varchar(50)) as partenaire_id,
        cast(1 as bit) as is_active,
        cast(null as datetime2(6)) as created_at,
        cast(null as datetime2(6)) as updated_at

)

select * from dimension_rows
union all
select * from unknown_row