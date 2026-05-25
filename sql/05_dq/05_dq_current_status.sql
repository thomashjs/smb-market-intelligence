USE DATABASE SMB_MARKET_INTELLIGENCE_DEV;

CREATE SCHEMA IF NOT EXISTS DQ;

CREATE OR REPLACE VIEW DQ.VW_DQ_CURRENT_STATUS AS
SELECT *
FROM DQ.VW_DQ_QCEW_CHECKS

UNION ALL
SELECT *
FROM DQ.VW_DQ_SBA_CHECKS

UNION ALL
SELECT *
FROM DQ.VW_DQ_OPPORTUNITY_MART_CHECKS;

-- Summary: current pass/fail counts by object and severity.
SELECT
    object_name,
    severity,
    status,
    COUNT(*) AS checks
FROM DQ.VW_DQ_CURRENT_STATUS
GROUP BY
    object_name,
    severity,
    status
ORDER BY
    object_name,
    severity,
    status;

-- Detail: failing/warning checks to inspect first.
SELECT
    check_group,
    check_name,
    severity,
    object_name,
    status,
    observed_value,
    expected_value,
    details,
    checked_at
FROM DQ.VW_DQ_CURRENT_STATUS
WHERE status <> 'PASS'
ORDER BY
    CASE severity
        WHEN 'ERROR' THEN 1
        WHEN 'WARN' THEN 2
        ELSE 3
    END,
    object_name,
    check_name;
