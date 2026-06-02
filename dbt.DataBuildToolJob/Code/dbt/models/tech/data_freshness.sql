-- depends_on: {{ ref('conseillers') }}
-- depends_on: {{ ref('crm_investisseurs') }}
-- depends_on: {{ ref('agences_regions') }}
-- depends_on: {{ ref('commissions') }}
-- depends_on: {{ ref('evenements_clients') }}
-- depends_on: {{ ref('dossiers_adv') }}
-- depends_on: {{ ref('financements') }}
-- depends_on: {{ ref('expertise_comptable_lmnp') }}
-- depends_on: {{ ref('gestion_locative') }}
-- depends_on: {{ ref('lots_immobiliers') }}
-- depends_on: {{ ref('objectifs_commerciaux') }}
-- depends_on: {{ ref('operations_crowdfunding') }}
-- depends_on: {{ ref('partenaires_patrimoine') }}
-- depends_on: {{ ref('produits_investissement') }}
-- depends_on: {{ ref('programmes_immobiliers') }}
-- depends_on: {{ ref('reclamations_incidents') }}
-- depends_on: {{ ref('reservations_immobilieres') }}
-- depends_on: {{ ref('revente_biens') }}
-- depends_on: {{ ref('souscriptions_pierre_papier') }}
-- depends_on: {{ ref('ventes_immobilieres') }}
-- depends_on: {{ ref('fact_vente') }}
-- depends_on: {{ ref('fact_reservation') }}
-- depends_on: {{ ref('fact_commission') }}
-- depends_on: {{ ref('fact_souscription_pierre_papier') }}
-- depends_on: {{ ref('fact_operation_crowdfunding') }}
-- depends_on: {{ ref('fact_financement') }}
-- depends_on: {{ ref('fact_dossier_adv') }}
-- depends_on: {{ ref('fact_gestion_locative') }}
-- depends_on: {{ ref('fact_objectif_commercial') }}
-- depends_on: {{ ref('fact_revente') }}
-- depends_on: {{ ref('dim_investisseur') }}
-- depends_on: {{ ref('dim_conseiller') }}
-- depends_on: {{ ref('dim_agence_region') }}
-- depends_on: {{ ref('dim_partenaire') }}
-- depends_on: {{ ref('dim_programme_immobilier') }}
-- depends_on: {{ ref('dim_lot_immobilier') }}
-- depends_on: {{ ref('dim_produit_investissement') }}

SELECT 'silver' AS table_schema, 'crm_investisseurs' AS table_name,
       MAX(CAST(last_update_date AS DATETIME2(6))) AS last_load_time,
       COUNT(*) AS row_count, CAST(GETDATE() AS DATETIME2(6)) AS checked_at
FROM {{ ref('crm_investisseurs') }}

UNION ALL SELECT 'silver', 'conseillers',
       MAX(CAST(updated_at AS DATETIME2(6))), COUNT(*), CAST(GETDATE() AS DATETIME2(6))
FROM {{ ref('conseillers') }}

UNION ALL SELECT 'silver', 'agences_regions',
       MAX(CAST(updated_at AS DATETIME2(6))), COUNT(*), CAST(GETDATE() AS DATETIME2(6))
FROM {{ ref('agences_regions') }}

UNION ALL SELECT 'silver', 'commissions',
       MAX(CAST(updated_at AS DATETIME2(6))), COUNT(*), CAST(GETDATE() AS DATETIME2(6))
FROM {{ ref('commissions') }}

UNION ALL SELECT 'silver', 'evenements_clients',
       MAX(CAST(updated_at AS DATETIME2(6))), COUNT(*), CAST(GETDATE() AS DATETIME2(6))
FROM {{ ref('evenements_clients') }}

UNION ALL SELECT 'silver', 'dossiers_adv',
       MAX(CAST(updated_at AS DATETIME2(6))), COUNT(*), CAST(GETDATE() AS DATETIME2(6))
FROM {{ ref('dossiers_adv') }}

UNION ALL SELECT 'silver', 'financements',
       MAX(CAST(updated_at AS DATETIME2(6))), COUNT(*), CAST(GETDATE() AS DATETIME2(6))
FROM {{ ref('financements') }}

UNION ALL SELECT 'silver', 'expertise_comptable_lmnp',
       MAX(CAST(updated_at AS DATETIME2(6))), COUNT(*), CAST(GETDATE() AS DATETIME2(6))
FROM {{ ref('expertise_comptable_lmnp') }}

UNION ALL SELECT 'silver', 'gestion_locative',
       MAX(CAST(updated_at AS DATETIME2(6))), COUNT(*), CAST(GETDATE() AS DATETIME2(6))
FROM {{ ref('gestion_locative') }}

UNION ALL SELECT 'silver', 'lots_immobiliers',
       MAX(CAST(updated_at AS DATETIME2(6))), COUNT(*), CAST(GETDATE() AS DATETIME2(6))
FROM {{ ref('lots_immobiliers') }}

UNION ALL SELECT 'silver', 'objectifs_commerciaux',
       MAX(CAST(updated_at AS DATETIME2(6))), COUNT(*), CAST(GETDATE() AS DATETIME2(6))
FROM {{ ref('objectifs_commerciaux') }}

UNION ALL SELECT 'silver', 'operations_crowdfunding',
       MAX(CAST(updated_at AS DATETIME2(6))), COUNT(*), CAST(GETDATE() AS DATETIME2(6))
FROM {{ ref('operations_crowdfunding') }}

UNION ALL SELECT 'silver', 'partenaires_patrimoine',
       MAX(CAST(updated_at AS DATETIME2(6))), COUNT(*), CAST(GETDATE() AS DATETIME2(6))
FROM {{ ref('partenaires_patrimoine') }}

UNION ALL SELECT 'silver', 'produits_investissement',
       MAX(CAST(updated_at AS DATETIME2(6))), COUNT(*), CAST(GETDATE() AS DATETIME2(6))
FROM {{ ref('produits_investissement') }}

UNION ALL SELECT 'silver', 'programmes_immobiliers',
       MAX(CAST(updated_at AS DATETIME2(6))), COUNT(*), CAST(GETDATE() AS DATETIME2(6))
FROM {{ ref('programmes_immobiliers') }}

UNION ALL SELECT 'silver', 'reclamations_incidents',
       MAX(CAST(updated_at AS DATETIME2(6))), COUNT(*), CAST(GETDATE() AS DATETIME2(6))
FROM {{ ref('reclamations_incidents') }}

UNION ALL SELECT 'silver', 'reservations_immobilieres',
       MAX(CAST(updated_at AS DATETIME2(6))), COUNT(*), CAST(GETDATE() AS DATETIME2(6))
FROM {{ ref('reservations_immobilieres') }}

UNION ALL SELECT 'silver', 'revente_biens',
       MAX(CAST(updated_at AS DATETIME2(6))), COUNT(*), CAST(GETDATE() AS DATETIME2(6))
FROM {{ ref('revente_biens') }}

UNION ALL SELECT 'silver', 'crm_prospects',
       MAX(CAST(last_update_date AS DATETIME2(6))), COUNT(*), CAST(GETDATE() AS DATETIME2(6))
FROM {{ ref('crm_prospects') }}

UNION ALL SELECT 'silver', 'souscriptions_pierre_papier',
       MAX(CAST(updated_at AS DATETIME2(6))), COUNT(*), CAST(GETDATE() AS DATETIME2(6))
FROM {{ ref('souscriptions_pierre_papier') }}

UNION ALL SELECT 'silver', 'ventes_immobilieres',
       MAX(CAST(updated_at AS DATETIME2(6))), COUNT(*), CAST(GETDATE() AS DATETIME2(6))
FROM {{ ref('ventes_immobilieres') }}

UNION ALL SELECT 'gold', 'fact_vente',
       MAX(CAST(updated_at AS DATETIME2(6))), COUNT(*), CAST(GETDATE() AS DATETIME2(6))
FROM {{ ref('fact_vente') }}

UNION ALL SELECT 'gold', 'fact_reservation',
       MAX(CAST(updated_at AS DATETIME2(6))), COUNT(*), CAST(GETDATE() AS DATETIME2(6))
FROM {{ ref('fact_reservation') }}

UNION ALL SELECT 'gold', 'fact_commission',
       MAX(CAST(updated_at AS DATETIME2(6))), COUNT(*), CAST(GETDATE() AS DATETIME2(6))
FROM {{ ref('fact_commission') }}

UNION ALL SELECT 'gold', 'fact_souscription_pierre_papier',
       MAX(CAST(updated_at AS DATETIME2(6))), COUNT(*), CAST(GETDATE() AS DATETIME2(6))
FROM {{ ref('fact_souscription_pierre_papier') }}

UNION ALL SELECT 'gold', 'fact_operation_crowdfunding',
       MAX(CAST(updated_at AS DATETIME2(6))), COUNT(*), CAST(GETDATE() AS DATETIME2(6))
FROM {{ ref('fact_operation_crowdfunding') }}

UNION ALL SELECT 'gold', 'fact_financement',
       MAX(CAST(updated_at AS DATETIME2(6))), COUNT(*), CAST(GETDATE() AS DATETIME2(6))
FROM {{ ref('fact_financement') }}

UNION ALL SELECT 'gold', 'fact_dossier_adv',
       MAX(CAST(updated_at AS DATETIME2(6))), COUNT(*), CAST(GETDATE() AS DATETIME2(6))
FROM {{ ref('fact_dossier_adv') }}

UNION ALL SELECT 'gold', 'fact_gestion_locative',
       MAX(CAST(updated_at AS DATETIME2(6))), COUNT(*), CAST(GETDATE() AS DATETIME2(6))
FROM {{ ref('fact_gestion_locative') }}

UNION ALL SELECT 'gold', 'fact_objectif_commercial',
       MAX(CAST(updated_at AS DATETIME2(6))), COUNT(*), CAST(GETDATE() AS DATETIME2(6))
FROM {{ ref('fact_objectif_commercial') }}

UNION ALL SELECT 'gold', 'fact_revente',
       MAX(CAST(updated_at AS DATETIME2(6))), COUNT(*), CAST(GETDATE() AS DATETIME2(6))
FROM {{ ref('fact_revente') }}

UNION ALL SELECT 'gold', 'dim_investisseur',
       MAX(CAST(last_update_date AS DATETIME2(6))), COUNT(*), CAST(GETDATE() AS DATETIME2(6))
FROM {{ ref('dim_investisseur') }}

UNION ALL SELECT 'gold', 'dim_conseiller',
       MAX(CAST(updated_at AS DATETIME2(6))), COUNT(*), CAST(GETDATE() AS DATETIME2(6))
FROM {{ ref('dim_conseiller') }}

UNION ALL SELECT 'gold', 'dim_agence_region',
       MAX(CAST(updated_at AS DATETIME2(6))), COUNT(*), CAST(GETDATE() AS DATETIME2(6))
FROM {{ ref('dim_agence_region') }}

UNION ALL SELECT 'gold', 'dim_partenaire',
       MAX(CAST(updated_at AS DATETIME2(6))), COUNT(*), CAST(GETDATE() AS DATETIME2(6))
FROM {{ ref('dim_partenaire') }}

UNION ALL SELECT 'gold', 'dim_programme_immobilier',
       MAX(CAST(updated_at AS DATETIME2(6))), COUNT(*), CAST(GETDATE() AS DATETIME2(6))
FROM {{ ref('dim_programme_immobilier') }}

UNION ALL SELECT 'gold', 'dim_lot_immobilier',
       MAX(CAST(updated_at AS DATETIME2(6))), COUNT(*), CAST(GETDATE() AS DATETIME2(6))
FROM {{ ref('dim_lot_immobilier') }}

UNION ALL SELECT 'gold', 'dim_produit_investissement',
       MAX(CAST(updated_at AS DATETIME2(6))), COUNT(*), CAST(GETDATE() AS DATETIME2(6))
FROM {{ ref('dim_produit_investissement') }}