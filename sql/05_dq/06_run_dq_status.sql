USE DATABASE SMB_MARKET_INTELLIGENCE_DEV;

-- Run this file after:
--   01_dq_qcew_checks.sql
--   02_dq_sba_checks.sql
--   03_dq_opportunity_mart_checks.sql
--   04_dq_current_status.sql

SELECT
    check_group,
    severity,
    status,
    COUNT(*) AS checks
FROM DQ.VW_DQ_CURRENT_STATUS
GROUP BY
    check_group,
    severity,
    status
ORDER BY
    check_group,
    severity,
    status;

SELECT
    check_group,
    check_name,
    severity,
    object_name,
    status,
    observed_value,
    expected_value,
    details
FROM DQ.VW_DQ_CURRENT_STATUS
ORDER BY
    CASE status WHEN 'FAIL' THEN 1 ELSE 2 END,
    CASE severity
        WHEN 'ERROR' THEN 1
        WHEN 'WARN' THEN 2
        WHEN 'INFO' THEN 3
        ELSE 4
    END,
    check_group,
    check_name;
