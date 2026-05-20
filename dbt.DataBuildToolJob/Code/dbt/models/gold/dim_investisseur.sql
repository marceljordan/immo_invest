/*
Fichier : models/gold/dim_investisseur.sql

Rôle :
- Créer la dimension Investisseur.

Actions réalisées :
- Déduplique les investisseurs avec row_number.
- Garde une seule ligne par investisseur_id.
- Génère une surrogate key investisseur_key.
- Rattache l’investisseur aux dimensions partenaire, conseiller et agence.
- Envoie les rattachements absents vers UNKNOWN.
- Ajoute une ligne UNKNOWN pour les faits sans investisseur valide.

Objectif :
- Garantir que dim_investisseur peut être utilisée côté 1 dans Power BI.
*/

{{ config(alias='dim_investisseur') }}

with source_dedup as (

    select
        *,
        row_number() over (
            partition by investisseur_id
            order by last_update_date desc, date_creation desc
        ) as rn
    from {{ ref('crm_investisseurs') }}
    where investisseur_id is not null
      and is_deleted = 0

),

dimension_rows as (

    select
        {{ dbt_utils.generate_surrogate_key(['i.investisseur_id']) }} as investisseur_key,
        i.investisseur_id,
        i.prospect_id,
        i.civilite,
        i.nom,
        i.prenom,
        cast(concat(i.prenom, ' ', i.nom) as varchar(255)) as nom_complet,
        i.email,
        i.telephone,
        i.adresse,
        i.ville,
        i.code_postal,
        i.pays,
        i.profession,
        i.situation_familiale,
        i.revenu_annuel,
        i.patrimoine_financier,
        i.patrimoine_immobilier,
        i.profil_investisseur,
        i.objectif_principal,
        i.horizon_placement,
        i.niveau_experience,
        i.statut_kyc,
        i.statut_lcbft,
        i.date_entree_relation,
        i.partenaire_id,
        coalesce(p.partenaire_key, {{ dbt_utils.generate_surrogate_key(["'__UNKNOWN__'"]) }}) as partenaire_key,
        i.conseiller_id,
        coalesce(c.conseiller_key, {{ dbt_utils.generate_surrogate_key(["'__UNKNOWN__'"]) }}) as conseiller_key,
        i.agence_id,
        coalesce(a.agence_region_key, {{ dbt_utils.generate_surrogate_key(["'__UNKNOWN__'"]) }}) as agence_region_key,
        i.statut_client,
        i.date_creation,
        i.created_by,
        i.last_update_date,
        i.last_updated_by,
        i.is_deleted
    from source_dedup i
    left join {{ ref('dim_partenaire') }} p
        on i.partenaire_id = p.partenaire_id
    left join {{ ref('dim_conseiller') }} c
        on i.conseiller_id = c.conseiller_id
    left join {{ ref('dim_agence_region') }} a
        on i.agence_id = a.agence_id
    where i.rn = 1

),

unknown_row as (

    select
        {{ dbt_utils.generate_surrogate_key(["'__UNKNOWN__'"]) }} as investisseur_key,
        cast('__UNKNOWN__' as varchar(50)) as investisseur_id,
        cast(null as varchar(50)) as prospect_id,
        cast(null as varchar(50)) as civilite,
        cast('Investisseur inconnu' as varchar(255)) as nom,
        cast(null as varchar(255)) as prenom,
        cast('Investisseur inconnu' as varchar(255)) as nom_complet,
        cast(null as varchar(255)) as email,
        cast(null as varchar(50)) as telephone,
        cast(null as varchar(500)) as adresse,
        cast(null as varchar(255)) as ville,
        cast(null as varchar(50)) as code_postal,
        cast(null as varchar(50)) as pays,
        cast(null as varchar(255)) as profession,
        cast(null as varchar(50)) as situation_familiale,
        cast(null as decimal(18,2)) as revenu_annuel,
        cast(null as decimal(18,2)) as patrimoine_financier,
        cast(null as decimal(18,2)) as patrimoine_immobilier,
        cast('INCONNU' as varchar(50)) as profil_investisseur,
        cast(null as varchar(255)) as objectif_principal,
        cast(null as varchar(255)) as horizon_placement,
        cast(null as varchar(50)) as niveau_experience,
        cast(null as varchar(50)) as statut_kyc,
        cast(null as varchar(50)) as statut_lcbft,
        cast(null as date) as date_entree_relation,
        cast('__UNKNOWN__' as varchar(50)) as partenaire_id,
        {{ dbt_utils.generate_surrogate_key(["'__UNKNOWN__'"]) }} as partenaire_key,
        cast('__UNKNOWN__' as varchar(50)) as conseiller_id,
        {{ dbt_utils.generate_surrogate_key(["'__UNKNOWN__'"]) }} as conseiller_key,
        cast('__UNKNOWN__' as varchar(50)) as agence_id,
        {{ dbt_utils.generate_surrogate_key(["'__UNKNOWN__'"]) }} as agence_region_key,
        cast('INCONNU' as varchar(50)) as statut_client,
        cast(null as datetime2(6)) as date_creation,
        cast(null as varchar(255)) as created_by,
        cast(null as datetime2(6)) as last_update_date,
        cast(null as varchar(255)) as last_updated_by,
        cast(0 as bit) as is_deleted

)

select * from dimension_rows
union all
select * from unknown_row