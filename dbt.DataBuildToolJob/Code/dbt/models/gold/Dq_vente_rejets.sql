/*
Fichier : models/gold/dq_vente_rejets.sql

Rôle :
- Lister les ventes de la source absentes de fact_vente (écartées par les règles métier).
- Indiquer quelle(s) règle(s) chaque vente viole.

Grain :
- 1 ligne = 1 vente rejetée.

Principe :
- Les lignes rejetées = source - fact_vente (anti-jointure). Le périmètre est donc
  toujours exactement celui écarté par fact_vente, même si ses règles évoluent.
- Les colonnes rm1..rm4 expliquent le rejet. Si une vente rejetée n'a aucune règle
  à 1, c'est que les règles de fact_vente et de ce modèle ne sont plus alignées.
*/

{{ config(alias='dq_vente_rejets') }}

with ventes as (

    select
        f.*,
        upper(trim(f.statut_vente)) as statut_vente_norm,
        cast(getdate() as date)     as date_controle
    from {{ ref('ventes_immobilieres') }} f
    where f.is_deleted = 0

)

select
    v.vente_id,
    v.statut_vente,
    v.date_signature_contrat,
    v.date_signature_acte,
    v.date_livraison_reelle,
    v.prix_vente_ttc,

    case when v.date_signature_contrat > v.date_controle
         then 1 else 0 end as rm1_contrat_futur,

    case when v.date_signature_contrat > v.date_signature_acte
         then 1 else 0 end as rm2_contrat_apres_acte,

    case when v.statut_vente_norm in ('ACTEE', 'LIVREE')
          and v.date_signature_acte > v.date_controle
         then 1 else 0 end as rm3_acte_futur,

    case when v.statut_vente_norm = 'LIVREE'
          and v.date_livraison_reelle > v.date_controle
         then 1 else 0 end as rm4_livraison_future,

    v.date_controle

from ventes v
where not exists (
    select 1
    from {{ ref('fact_vente') }} fv
    where fv.vente_id = v.vente_id
)