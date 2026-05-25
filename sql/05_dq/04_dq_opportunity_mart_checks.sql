USE DATABASE SMB_MARKET_INTELLIGENCE_DEV;

CREATE SCHEMA IF NOT EXISTS DQ;

CREATE OR REPLACE VIEW DQ.VW_DQ_OPPORTUNITY_MART_CHECKS AS
WITH
mart AS (
    SELECT *
    FROM MART.COUNTY_INDUSTRY_OPPORTUNITY_QTR
),
qcew AS (
    SELECT *
    FROM INT.INT_QCEW_GROWTH_SCORES
),
row_stats AS (
    SELECT
        COUNT(*) AS mart_row_count,
        COUNT(DISTINCT state_fips) AS state_count,
        COUNT(DISTINCT county_fips) AS county_count,
        COUNT(DISTINCT qcew_industry_code) AS sector_count,
        MIN(period_id) AS min_period_id,
        MAX(period_id) AS max_period_id,
        COUNT_IF(
            state_fips IS NULL
            OR state_abbr IS NULL
            OR state_name IS NULL
            OR county_fips IS NULL
            OR qcew_industry_code IS NULL
            OR year IS NULL
            OR quarter IS NULL
            OR period_id IS NULL
            OR scoring_version IS NULL
        ) AS null_key_rows,
        COUNT_IF(qtrly_estabs < 0) AS negative_estab_rows,
        COUNT_IF(sba_loan_count < 0) AS negative_sba_loan_rows,
        COUNT_IF(sba_gross_approval_amount < 0) AS negative_sba_amount_rows,
        COUNT_IF(sba_loans_per_100_establishments < 0) AS negative_loan_penetration_rows,
        COUNT_IF(sba_dollars_per_establishment < 0) AS negative_dollar_penetration_rows,
        COUNT_IF(
            ongoing_growth_score < 0 OR ongoing_growth_score > 100
            OR expected_growth_score < 0 OR expected_growth_score > 100
            OR lending_penetration_score < 0 OR lending_penetration_score > 100
            OR low_lending_penetration_score < 0 OR low_lending_penetration_score > 100
            OR underserved_score < 0 OR underserved_score > 100
            OR lender_fragmentation_score < 0 OR lender_fragmentation_score > 100
            OR lending_momentum_score < 0 OR lending_momentum_score > 100
            OR final_opportunity_score < 0 OR final_opportunity_score > 100
        ) AS score_out_of_range_rows,
        COUNT_IF(opportunity_tier NOT IN ('Very High', 'High', 'Moderate', 'Watchlist', 'Low')) AS invalid_tier_rows,
        COUNT_IF(recommendation IS NULL OR TRIM(recommendation) = '') AS missing_recommendation_rows,
        COUNT_IF(sba_loan_count = 0) AS no_sba_activity_rows
    FROM mart
),
qcew_stats AS (
    SELECT COUNT(*) AS qcew_row_count
    FROM qcew
),
duplicate_keys AS (
    SELECT COUNT(*) AS duplicate_key_count
    FROM (
        SELECT
            scoring_version,
            state_fips,
            county_fips,
            qcew_industry_code,
            year,
            quarter,
            COUNT(*) AS rows_per_key
        FROM mart
        GROUP BY
            scoring_version,
            state_fips,
            county_fips,
            qcew_industry_code,
            year,
            quarter
        HAVING COUNT(*) > 1
    )
),
latest_period AS (
    SELECT MAX(period_id) AS latest_period_id
    FROM mart
),
latest_stats AS (
    SELECT
        COUNT(*) AS latest_row_count,
        COUNT(DISTINCT state_fips) AS latest_state_count,
        COUNT(DISTINCT county_fips) AS latest_county_count,
        COUNT(DISTINCT qcew_industry_code) AS latest_sector_count,
        COUNT_IF(final_opportunity_score >= 70) AS latest_high_opportunity_rows
    FROM mart
    WHERE period_id = (SELECT latest_period_id FROM latest_period)
)
SELECT
    'MART' AS check_group,
    'opportunity_mart_row_count_positive' AS check_name,
    'ERROR' AS severity,
    'MART.COUNTY_INDUSTRY_OPPORTUNITY_QTR' AS object_name,
    CASE WHEN mart_row_count > 0 THEN 'PASS' ELSE 'FAIL' END AS status,
    TO_VARCHAR(mart_row_count) AS observed_value,
    '> 0' AS expected_value,
    'Opportunity mart should not be empty.' AS details,
    CURRENT_TIMESTAMP() AS checked_at
FROM row_stats

UNION ALL
SELECT
    'MART',
    'opportunity_mart_preserves_qcew_base_rows',
    'ERROR',
    'MART.COUNTY_INDUSTRY_OPPORTUNITY_QTR',
    CASE WHEN mart_row_count = qcew_row_count THEN 'PASS' ELSE 'FAIL' END,
    TO_VARCHAR(mart_row_count),
    'equals INT.INT_QCEW_GROWTH_SCORES row count: ' || TO_VARCHAR(qcew_row_count),
    'The mart should left join SBA to QCEW and preserve every QCEW county-industry-quarter market.',
    CURRENT_TIMESTAMP()
FROM row_stats
CROSS JOIN qcew_stats

UNION ALL
SELECT
    'MART',
    'opportunity_mart_key_fields_not_null',
    'ERROR',
    'MART.COUNTY_INDUSTRY_OPPORTUNITY_QTR',
    CASE WHEN null_key_rows = 0 THEN 'PASS' ELSE 'FAIL' END,
    TO_VARCHAR(null_key_rows),
    '0',
    'No rows should have null physical grain fields, period fields, or scoring version.',
    CURRENT_TIMESTAMP()
FROM row_stats

UNION ALL
SELECT
    'MART',
    'opportunity_mart_unique_scored_key',
    'ERROR',
    'MART.COUNTY_INDUSTRY_OPPORTUNITY_QTR',
    CASE WHEN duplicate_key_count = 0 THEN 'PASS' ELSE 'FAIL' END,
    TO_VARCHAR(duplicate_key_count),
    '0',
    'There should be at most one row per scoring_version, state_fips, county_fips, qcew_industry_code, year, quarter.',
    CURRENT_TIMESTAMP()
FROM duplicate_keys

UNION ALL
SELECT
    'MART',
    'opportunity_scores_between_0_and_100',
    'ERROR',
    'MART.COUNTY_INDUSTRY_OPPORTUNITY_QTR',
    CASE WHEN score_out_of_range_rows = 0 THEN 'PASS' ELSE 'FAIL' END,
    TO_VARCHAR(score_out_of_range_rows),
    '0',
    'All score fields should be bounded to [0, 100].',
    CURRENT_TIMESTAMP()
FROM row_stats

UNION ALL
SELECT
    'MART',
    'opportunity_tier_valid_values',
    'ERROR',
    'MART.COUNTY_INDUSTRY_OPPORTUNITY_QTR',
    CASE WHEN invalid_tier_rows = 0 THEN 'PASS' ELSE 'FAIL' END,
    TO_VARCHAR(invalid_tier_rows),
    '0',
    'Opportunity tier should use the approved v1 tier labels.',
    CURRENT_TIMESTAMP()
FROM row_stats

UNION ALL
SELECT
    'MART',
    'opportunity_recommendation_present',
    'WARN',
    'MART.COUNTY_INDUSTRY_OPPORTUNITY_QTR',
    CASE WHEN missing_recommendation_rows = 0 THEN 'PASS' ELSE 'FAIL' END,
    TO_VARCHAR(missing_recommendation_rows),
    '0',
    'Every scored market should have a stakeholder-readable recommendation.',
    CURRENT_TIMESTAMP()
FROM row_stats

UNION ALL
SELECT
    'MART',
    'opportunity_mart_non_negative_market_values',
    'ERROR',
    'MART.COUNTY_INDUSTRY_OPPORTUNITY_QTR',
    CASE
        WHEN negative_estab_rows = 0
         AND negative_sba_loan_rows = 0
         AND negative_sba_amount_rows = 0
         AND negative_loan_penetration_rows = 0
         AND negative_dollar_penetration_rows = 0
        THEN 'PASS'
        ELSE 'FAIL'
    END,
    TO_VARCHAR(
        negative_estab_rows
        + negative_sba_loan_rows
        + negative_sba_amount_rows
        + negative_loan_penetration_rows
        + negative_dollar_penetration_rows
    ),
    '0',
    'Core market, lending, and penetration values should not be negative.',
    CURRENT_TIMESTAMP()
FROM row_stats

UNION ALL
SELECT
    'MART',
    'opportunity_mart_latest_period_state_coverage',
    'WARN',
    'MART.COUNTY_INDUSTRY_OPPORTUNITY_QTR',
    CASE WHEN latest_state_count >= 50 THEN 'PASS' ELSE 'FAIL' END,
    TO_VARCHAR(latest_state_count),
    '>= 50',
    'Latest mart period should have broad national state coverage.',
    CURRENT_TIMESTAMP()
FROM latest_stats

UNION ALL
SELECT
    'MART',
    'opportunity_mart_latest_period_county_coverage',
    'WARN',
    'MART.COUNTY_INDUSTRY_OPPORTUNITY_QTR',
    CASE WHEN latest_county_count >= 2500 THEN 'PASS' ELSE 'FAIL' END,
    TO_VARCHAR(latest_county_count),
    '>= 2500',
    'Latest mart period should have broad county coverage.',
    CURRENT_TIMESTAMP()
FROM latest_stats

UNION ALL
SELECT
    'MART',
    'opportunity_mart_preserves_no_sba_markets',
    'INFO',
    'MART.COUNTY_INDUSTRY_OPPORTUNITY_QTR',
    CASE WHEN no_sba_activity_rows > 0 THEN 'PASS' ELSE 'FAIL' END,
    TO_VARCHAR(no_sba_activity_rows),
    '> 0',
    'A national QCEW-left mart should preserve markets with no SBA activity.',
    CURRENT_TIMESTAMP()
FROM row_stats;
