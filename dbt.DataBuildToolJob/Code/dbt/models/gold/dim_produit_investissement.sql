/*
Fichier : models/gold/dim_produit_investissement.sql

Rôle :
- Créer la dimension Produit d’investissement.

Actions réalisées :
- Déduplique les produits avec row_number.
- Garde une seule ligne par produit_id.
- Génère une surrogate key produit_key.
- Ajoute une ligne UNKNOWN pour les faits sans produit valide.

Objectif :
- Garantir que dim_produit_investissement peut être utilisée côté 1 dans Power BI.
*/

{{ config(alias='dim_produit_investissement') }}

with source_dedup as (

    select
        *,
        row_number() over (
            partition by produit_id
            order by updated_at desc, created_at desc
        ) as rn
    from {{ ref('produits_investissement') }}
    where produit_id is not null

),

dimension_rows as (

    select
        {{ dbt_utils.generate_surrogate_key(['produit_id']) }} as produit_key,
        produit_id,
        nom_produit,
        famille_produit,
        type_produit,
        sous_type_produit,
        fiscalite,
        niveau_risque,
        duree_recommandee,
        rendement_cible_annuel,
        montant_minimum_investissement,
        frais_entree,
        frais_gestion_annuels,
        frais_sortie,
        societe_gestion_id,
        promoteur_id,
        statut_commercialisation,
        date_debut_commercialisation,
        date_fin_commercialisation,
        is_active,
        created_at,
        updated_at
    from source_dedup
    where rn = 1

),

unknown_row as (

    select
        {{ dbt_utils.generate_surrogate_key(["'__UNKNOWN__'"]) }} as produit_key,
        cast('__UNKNOWN__' as varchar(50)) as produit_id,
        cast('Produit inconnu' as varchar(255)) as nom_produit,
        cast('INCONNU' as varchar(50)) as famille_produit,
        cast('INCONNU' as varchar(50)) as type_produit,
        cast('INCONNU' as varchar(50)) as sous_type_produit,
        cast(null as varchar(50)) as fiscalite,
        cast(null as varchar(50)) as niveau_risque,
        cast(null as varchar(255)) as duree_recommandee,
        cast(null as decimal(9,4)) as rendement_cible_annuel,
        cast(null as decimal(18,2)) as montant_minimum_investissement,
        cast(null as decimal(9,4)) as frais_entree,
        cast(null as decimal(9,4)) as frais_gestion_annuels,
        cast(null as decimal(9,4)) as frais_sortie,
        cast(null as varchar(50)) as societe_gestion_id,
        cast(null as varchar(50)) as promoteur_id,
        cast('INCONNU' as varchar(50)) as statut_commercialisation,
        cast(null as date) as date_debut_commercialisation,
        cast(null as date) as date_fin_commercialisation,
        cast(1 as bit) as is_active,
        cast(null as datetime2(6)) as created_at,
        cast(null as datetime2(6)) as updated_at

)

select * from dimension_rows
union all
select * from unknown_row