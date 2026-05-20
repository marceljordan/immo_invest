/*
Fichier : models/gold/dim_partenaire.sql

Rôle :
- Créer la dimension Partenaire professionnel du patrimoine.

Actions réalisées :
- Déduplique les partenaires avec row_number.
- Garde une seule ligne par partenaire_id.
- Génère une surrogate key partenaire_key.
- Ajoute une ligne UNKNOWN pour les faits sans partenaire valide.

Objectif :
- Garantir que dim_partenaire peut être utilisée côté 1 dans Power BI.
*/

{{ config(alias='dim_partenaire') }}

with source_dedup as (

    select
        *,
        row_number() over (
            partition by partenaire_id
            order by updated_at desc, created_at desc
        ) as rn
    from {{ ref('partenaires_patrimoine') }}
    where partenaire_id is not null

),

dimension_rows as (

    select
        {{ dbt_utils.generate_surrogate_key(['partenaire_id']) }} as partenaire_key,
        partenaire_id,
        raison_sociale,
        siret,
        type_partenaire,
        statut_partenaire,
        nom_contact_principal,
        prenom_contact_principal,
        cast(concat(prenom_contact_principal, ' ', nom_contact_principal) as varchar(255)) as contact_principal,
        email_contact,
        telephone_contact,
        adresse,
        ville,
        code_postal,
        region,
        pays,
        date_signature_convention,
        niveau_partenaire,
        segment_partenaire,
        nombre_clients_actifs,
        encours_total_apporte,
        commission_rate_default,
        manager_interne_id,
        conseiller_referent_id,
        statut_convention,
        date_derniere_activite,
        is_active,
        created_at,
        updated_at
    from source_dedup
    where rn = 1

),

unknown_row as (

    select
        {{ dbt_utils.generate_surrogate_key(["'__UNKNOWN__'"]) }} as partenaire_key,
        cast('__UNKNOWN__' as varchar(50)) as partenaire_id,
        cast('Partenaire inconnu' as varchar(255)) as raison_sociale,
        cast(null as varchar(50)) as siret,
        cast('INCONNU' as varchar(50)) as type_partenaire,
        cast('INCONNU' as varchar(50)) as statut_partenaire,
        cast(null as varchar(255)) as nom_contact_principal,
        cast(null as varchar(255)) as prenom_contact_principal,
        cast(null as varchar(255)) as contact_principal,
        cast(null as varchar(255)) as email_contact,
        cast(null as varchar(50)) as telephone_contact,
        cast(null as varchar(500)) as adresse,
        cast(null as varchar(255)) as ville,
        cast(null as varchar(50)) as code_postal,
        cast(null as varchar(255)) as region,
        cast(null as varchar(50)) as pays,
        cast(null as date) as date_signature_convention,
        cast('INCONNU' as varchar(50)) as niveau_partenaire,
        cast('INCONNU' as varchar(50)) as segment_partenaire,
        cast(null as int) as nombre_clients_actifs,
        cast(null as decimal(18,2)) as encours_total_apporte,
        cast(null as decimal(9,4)) as commission_rate_default,
        cast(null as varchar(50)) as manager_interne_id,
        cast(null as varchar(50)) as conseiller_referent_id,
        cast('INCONNU' as varchar(50)) as statut_convention,
        cast(null as date) as date_derniere_activite,
        cast(1 as bit) as is_active,
        cast(null as datetime2(6)) as created_at,
        cast(null as datetime2(6)) as updated_at

)

select * from dimension_rows
union all
select * from unknown_row