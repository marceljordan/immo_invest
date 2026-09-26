/*
Fichier : models/gold/fact_vente.sql

Rôle :
- Créer la table de faits des ventes immobilières.

Grain Kimball :
- 1 ligne = 1 vente immobilière conforme aux règles métier.

Règles métier (ventes exclues si une règle est violée) :
- RM1 : pas de contrat signé dans le futur.
- RM2 : contrat signé avant (ou le jour de) l'acte.
- RM3 : une vente ACTEE ou LIVREE a un acte déjà passé.
- RM4 : une vente LIVREE a une livraison réelle déjà passée.
Une date manquante (NULL) ne provoque pas d'exclusion.

Actions réalisées :
- Applique les règles métier.
- Récupère les clés dimensionnelles via LEFT JOIN.
- Récupère statut_key depuis dim_statut.
- Envoie vers UNKNOWN si une dimension est absente.
- Expose is_vente_valide (0 = ECHEC / ANNULEE / ABANDONNE) pour les mesures.
*/

{{ config(alias='fact_vente') }}

with ventes as (

    select
        f.*,
        upper(trim(f.statut_vente)) as statut_vente_norm,
        cast(getdate() as date)     as date_controle
    from {{ ref('ventes_immobilieres') }} f
    where f.is_deleted = 0

),

ventes_conformes as (

    select v.*
    from ventes v
    where not (
           -- RM1 : contrat dans le futur
           coalesce(case when v.date_signature_contrat > v.date_controle then 1 end, 0) = 1
           -- RM2 : contrat après l'acte
        or coalesce(case when v.date_signature_contrat > v.date_signature_acte then 1 end, 0) = 1
           -- RM3 : actée ou livrée avec un acte futur
        or coalesce(case when v.statut_vente_norm in ('ACTEE', 'LIVREE')
                          and v.date_signature_acte > v.date_controle then 1 end, 0) = 1
           -- RM4 : livrée avec une livraison future
        or coalesce(case when v.statut_vente_norm = 'LIVREE'
                          and v.date_livraison_reelle > v.date_controle then 1 end, 0) = 1
    )

)

select
    {{ dbt_utils.generate_surrogate_key(['f.vente_id']) }} as vente_key,

    f.vente_id,
    f.reservation_id,

    cast(convert(char(8), f.date_signature_contrat, 112) as int) as date_signature_contrat_key,
    cast(convert(char(8), f.date_signature_acte, 112) as int) as date_signature_acte_key,
    cast(convert(char(8), f.date_livraison_prevue, 112) as int) as date_livraison_prevue_key,
    cast(convert(char(8), f.date_livraison_reelle, 112) as int) as date_livraison_reelle_key,

    coalesce(di.investisseur_key, {{ dbt_utils.generate_surrogate_key(["'__UNKNOWN__'"]) }}) as investisseur_key,
    coalesce(dp.partenaire_key, {{ dbt_utils.generate_surrogate_key(["'__UNKNOWN__'"]) }}) as partenaire_key,
    coalesce(dc.conseiller_key, {{ dbt_utils.generate_surrogate_key(["'__UNKNOWN__'"]) }}) as conseiller_key,
    coalesce(da.agence_region_key, {{ dbt_utils.generate_surrogate_key(["'__UNKNOWN__'"]) }}) as agence_region_key,
    coalesce(dpr.programme_key, {{ dbt_utils.generate_surrogate_key(["'__UNKNOWN__'"]) }}) as programme_key,
    coalesce(dl.lot_key, {{ dbt_utils.generate_surrogate_key(["'__UNKNOWN__'"]) }}) as lot_key,
    coalesce(ds.statut_key, {{ dbt_utils.generate_surrogate_key(["'VENTE'", "'__UNKNOWN__'"]) }}) as statut_key,

    f.lot_id,
    f.programme_id,
    f.investisseur_id,
    f.partenaire_id,
    f.conseiller_id,
    f.agence_id,

    f.prix_vente_ht,
    f.prix_vente_ttc,
    f.tva,
    f.frais_notaire,
    f.montant_total_operation,
    f.montant_apport,
    f.montant_credit,

    f.mode_financement,
    f.banque_financement,
    f.statut_vente,
    f.motif_echec,
    case when f.statut_vente_norm in ('ECHEC', 'ANNULEE', 'ABANDONNE')
         then 0 else 1 end as is_vente_valide,

    f.created_at,
    f.updated_at

from ventes_conformes f

left join {{ ref('dim_investisseur') }} di
    on f.investisseur_id = di.investisseur_id

left join {{ ref('dim_partenaire') }} dp
    on f.partenaire_id = dp.partenaire_id

left join {{ ref('dim_conseiller') }} dc
    on f.conseiller_id = dc.conseiller_id

left join {{ ref('dim_agence_region') }} da
    on f.agence_id = da.agence_id

left join {{ ref('dim_programme_immobilier') }} dpr
    on f.programme_id = dpr.programme_id

left join {{ ref('dim_lot_immobilier') }} dl
    on f.lot_id = dl.lot_id

left join {{ ref('dim_statut') }} ds
    on ds.domaine_statut = 'VENTE'
   and ds.statut_value = f.statut_vente_norm