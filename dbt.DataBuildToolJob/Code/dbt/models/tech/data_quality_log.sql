WITH checks AS (

    SELECT CAST(GETDATE() AS DATETIME2(6)) AS checked_at, 'gold' AS table_schema, 'fact_vente' AS table_name,
           'vente_id' AS column_name, 'null_check' AS check_type,
           COUNT(*) AS records_checked,
           SUM(CASE WHEN vente_id IS NULL THEN 1 ELSE 0 END) AS records_failed
    FROM {{ ref('fact_vente') }}

    UNION ALL

    SELECT CAST(GETDATE() AS DATETIME2(6)), 'gold', 'fact_reservation', 'reservation_id', 'null_check',
           COUNT(*), SUM(CASE WHEN reservation_id IS NULL THEN 1 ELSE 0 END)
    FROM {{ ref('fact_reservation') }}

    UNION ALL

    SELECT CAST(GETDATE() AS DATETIME2(6)), 'gold', 'fact_commission', 'commission_id', 'null_check',
           COUNT(*), SUM(CASE WHEN commission_id IS NULL THEN 1 ELSE 0 END)
    FROM {{ ref('fact_commission') }}

    UNION ALL

    SELECT CAST(GETDATE() AS DATETIME2(6)), 'gold', 'fact_souscription_pierre_papier', 'souscription_id', 'null_check',
           COUNT(*), SUM(CASE WHEN souscription_id IS NULL THEN 1 ELSE 0 END)
    FROM {{ ref('fact_souscription_pierre_papier') }}

    UNION ALL

    SELECT CAST(GETDATE() AS DATETIME2(6)), 'gold', 'dim_investisseur', 'investisseur_id', 'null_check',
           COUNT(*), SUM(CASE WHEN investisseur_id IS NULL THEN 1 ELSE 0 END)
    FROM {{ ref('dim_investisseur') }}

    UNION ALL

    SELECT CAST(GETDATE() AS DATETIME2(6)), 'gold', 'dim_conseiller', 'conseiller_id', 'null_check',
           COUNT(*), SUM(CASE WHEN conseiller_id IS NULL THEN 1 ELSE 0 END)
    FROM {{ ref('dim_conseiller') }}

    UNION ALL

    SELECT CAST(GETDATE() AS DATETIME2(6)), 'gold', 'dim_programme_immobilier', 'programme_id', 'null_check',
           COUNT(*), SUM(CASE WHEN programme_id IS NULL THEN 1 ELSE 0 END)
    FROM {{ ref('dim_programme_immobilier') }}

    UNION ALL

    SELECT CAST(GETDATE() AS DATETIME2(6)), 'gold', 'fact_vente', 'prix_vente_ttc', 'range_check',
           COUNT(*), SUM(CASE WHEN prix_vente_ttc < 0 THEN 1 ELSE 0 END)
    FROM {{ ref('fact_vente') }}

    UNION ALL

    SELECT CAST(GETDATE() AS DATETIME2(6)), 'gold', 'fact_commission', 'montant_commission_brut', 'range_check',
           COUNT(*), SUM(CASE WHEN montant_commission_brut < 0 THEN 1 ELSE 0 END)
    FROM {{ ref('fact_commission') }}

    UNION ALL

    SELECT CAST(GETDATE() AS DATETIME2(6)), 'gold', 'fact_souscription_pierre_papier', 'montant_souscrit', 'range_check',
           COUNT(*), SUM(CASE WHEN montant_souscrit < 0 THEN 1 ELSE 0 END)
    FROM {{ ref('fact_souscription_pierre_papier') }}

    UNION ALL

    SELECT CAST(GETDATE() AS DATETIME2(6)), 'gold', 'fact_vente', 'vente_id', 'duplicate_check',
           COUNT(*), COUNT(*) - COUNT(DISTINCT vente_id)
    FROM {{ ref('fact_vente') }}

    UNION ALL

    SELECT CAST(GETDATE() AS DATETIME2(6)), 'gold', 'dim_investisseur', 'investisseur_id', 'duplicate_check',
           COUNT(*), COUNT(*) - COUNT(DISTINCT investisseur_id)
    FROM {{ ref('dim_investisseur') }}

    UNION ALL

    SELECT CAST(GETDATE() AS DATETIME2(6)), 'gold', 'dim_conseiller', 'conseiller_id', 'duplicate_check',
           COUNT(*), COUNT(*) - COUNT(DISTINCT conseiller_id)
    FROM {{ ref('dim_conseiller') }}

)

SELECT
    checked_at,
    table_schema,
    table_name,
    column_name,
    check_type,
    records_checked,
    records_failed,
    CASE
        WHEN records_checked = 0 THEN CAST(0.00 AS DECIMAL(5,2))
        ELSE CAST(ROUND(100.0 * (records_checked - records_failed) / records_checked, 2) AS DECIMAL(5,2))
    END AS pass_rate,
    CASE
        WHEN records_failed = 0 THEN 'pass'
        WHEN records_failed * 1.0 / NULLIF(records_checked, 0) < 0.05 THEN 'warn'
        ELSE 'fail'
    END AS status
FROM checks