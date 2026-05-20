/*
Fichier : models/gold/fact_objectif_commercial.sql

Rôle :
- Créer la table de faits des objectifs commerciaux.

Grain Kimball :
- 1 ligne = 1 objectif par période, niveau d’objectif, entité commerciale et type produit.

Actions réalisées :
- Génère objectif_key.
- Génère date_objectif_key.
- Récupère agence_region_key, conseiller_key et partenaire_key via LEFT JOIN.
- Envoie vers UNKNOWN si une dimension est absente.
- Rétablit produit_objectif_key pour conserver le schéma attendu par le semantic model.
- Conserve les mesures d’objectifs commerciaux.

Objectif :
- Comparer les objectifs commerciaux avec le réalisé des ventes, réservations, souscriptions et commissions.
*/

{{ config(alias='fact_objectif_commercial') }}

select
    {{ dbt_utils.generate_surrogate_key(['f.objectif_id']) }} as objectif_key,

    f.objectif_id,

    cast(convert(char(8), datefromparts(f.annee, f.mois, 1), 112) as int) as date_objectif_key,

    coalesce(da.agence_region_key, {{ dbt_utils.generate_surrogate_key(["'__UNKNOWN__'"]) }}) as agence_region_key,
    coalesce(dc.conseiller_key, {{ dbt_utils.generate_surrogate_key(["'__UNKNOWN__'"]) }}) as conseiller_key,
    coalesce(dp.partenaire_key, {{ dbt_utils.generate_surrogate_key(["'__UNKNOWN__'"]) }}) as partenaire_key,

    {{ dbt_utils.generate_surrogate_key(['f.famille_produit', 'f.type_produit']) }} as produit_objectif_key,

    f.region_id,
    f.agence_id,
    f.conseiller_id,
    f.partenaire_id,

    f.annee,
    f.mois,
    f.periode,
    f.niveau_objectif,
    f.famille_produit,
    f.type_produit,

    f.objectif_ca,
    f.objectif_nombre_ventes,
    f.objectif_nombre_reservations,
    f.objectif_montant_souscriptions,
    f.objectif_commissions,
    f.objectif_nouveaux_clients,

    f.created_at,
    f.updated_at

from {{ ref('objectifs_commerciaux') }} f

left join {{ ref('dim_agence_region') }} da
    on f.agence_id = da.agence_id

left join {{ ref('dim_conseiller') }} dc
    on f.conseiller_id = dc.conseiller_id

left join {{ ref('dim_partenaire') }} dp
    on f.partenaire_id = dp.partenaire_id

where f.is_active = 1