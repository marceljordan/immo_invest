SELECT
    distributed_statement_id                        AS run_id,
    login_name                                      AS pipeline_name,
    'DEV'                                           AS environment,
    status,
    CAST(start_time AS DATETIME2(6))                AS start_time,
    CAST(end_time AS DATETIME2(6))                  AS end_time,
    total_elapsed_time_ms / 1000                    AS duration_seconds,
    row_count                                       AS rows_processed,
    CASE
        WHEN error_code = 0 THEN NULL
        ELSE CAST(error_code AS VARCHAR(4000))
    END                                             AS error_message,
    CAST(GETDATE() AS DATETIME2(6))                 AS inserted_at
FROM queryinsights.exec_requests_history
WHERE start_time >= DATEADD(DAY, -7, GETDATE())
  AND statement_type NOT IN ('COND WITH QUERY', 'USE')