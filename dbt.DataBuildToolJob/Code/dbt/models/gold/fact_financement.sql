/*
Fichier : models/gold/fact_financement.sql

Rôle :
- Créer la table de faits des financements.

Grain Kimball :
- 1 ligne = 1 dossier de financement (avec ou sans vente).

Actions réalisées :
- Génère financement_key.
- Récupère investisseur_key via LEFT JOIN.
- Récupère conseiller_key et agence_region_key :
    1. depuis la vente d'origine (source ventes_immobilieres, pas fact_vente :
       un financement lié à une vente écartée par les règles métier garde
       son rattachement commercial) ;
    2. à défaut (financement en cours ou refusé, donc sans vente),
       depuis l'investisseur.
- Récupère statut_key depuis dim_statut.
- Envoie vers UNKNOWN si une dimension est absente.
- Conserve les mesures de financement.

Objectif :
- Garantir des relations valides vers dim_investisseur, dim_conseiller,
  dim_agence_region, dim_date et dim_statut (filtrage RLS géographique).
*/

{{ config(alias='fact_financement') }}

with vente_origine as (

    select
        vente_id,
        conseiller_id,
        agence_id
    from {{ ref('ventes_immobilieres') }}
    where is_deleted = 0

),

investisseur_origine as (

    select
        investisseur_id,
        conseiller_id,
        agence_id
    from {{ ref('crm_investisseurs') }}
    where is_deleted = 0

),

financements as (

    select
        f.*,
        coalesce(vo.conseiller_id, io.conseiller_id) as conseiller_id_rattache,
        coalesce(vo.agence_id, io.agence_id)         as agence_id_rattache
    from {{ ref('financements') }} f
    left join vente_origine vo
        on f.vente_id = vo.vente_id
    left join investisseur_origine io
        on f.investisseur_id = io.investisseur_id
    where f.is_deleted = 0

)

select
    {{ dbt_utils.generate_surrogate_key(['f.financement_id']) }} as financement_key,

    f.financement_id,
    f.vente_id,

    cast(convert(char(8), f.date_demande, 112) as int) as date_demande_key,
    cast(convert(char(8), f.date_accord_principe, 112) as int) as date_accord_principe_key,
    cast(convert(char(8), f.date_offre_pret, 112) as int) as date_offre_pret_key,
    cast(convert(char(8), f.date_acceptation_offre, 112) as int) as date_acceptation_offre_key,

    coalesce(di.investisseur_key, {{ dbt_utils.generate_surrogate_key(["'__UNKNOWN__'"]) }}) as investisseur_key,
    coalesce(dc.conseiller_key, {{ dbt_utils.generate_surrogate_key(["'__UNKNOWN__'"]) }}) as conseiller_key,
    coalesce(da.agence_region_key, {{ dbt_utils.generate_surrogate_key(["'__UNKNOWN__'"]) }}) as agence_region_key,
    coalesce(ds.statut_key, {{ dbt_utils.generate_surrogate_key(["'FINANCEMENT'", "'__UNKNOWN__'"]) }}) as statut_key,

    f.investisseur_id,
    f.conseiller_id_rattache as conseiller_id,
    f.agence_id_rattache     as agence_id,

    f.banque,
    f.courtier,

    f.montant_demande,
    f.montant_accorde,
    f.taux_credit,
    f.duree_credit_mois,
    f.mensualite_estimee,
    f.apport_personnel,
    f.assurance_emprunteur,

    f.statut_financement,
    f.motif_refus,

    f.created_at,
    f.updated_at

from financements f

left join {{ ref('dim_investisseur') }} di
    on f.investisseur_id = di.investisseur_id

left join {{ ref('dim_conseiller') }} dc
    on f.conseiller_id_rattache = dc.conseiller_id

left join {{ ref('dim_agence_region') }} da
    on f.agence_id_rattache = da.agence_id

left join {{ ref('dim_statut') }} ds
    on ds.domaine_statut = 'FINANCEMENT'
   and ds.statut_value = upper(trim(f.statut_financement))