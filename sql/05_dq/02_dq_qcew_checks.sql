USE DATABASE SMB_MARKET_INTELLIGENCE_DEV;

CREATE SCHEMA IF NOT EXISTS DQ;

CREATE OR REPLACE VIEW DQ.VW_DQ_QCEW_CHECKS AS
WITH
base AS (
    SELECT *
    FROM INT.INT_QCEW_GROWTH_SCORES
),
row_stats AS (
    SELECT
        COUNT(*) AS row_count,
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
        ) AS null_key_rows,
        COUNT_IF(qtrly_estabs < 0) AS negative_estab_rows,
        COUNT_IF(avg_monthly_employment < 0) AS negative_employment_rows,
        COUNT_IF(total_qtrly_wages < 0) AS negative_wage_rows,
        COUNT_IF(
            ongoing_growth_score < 0
            OR ongoing_growth_score > 100
            OR expected_growth_score < 0
            OR expected_growth_score > 100
        ) AS score_out_of_range_rows
    FROM base
),
duplicate_keys AS (
    SELECT COUNT(*) AS duplicate_key_count
    FROM (
        SELECT
            state_fips,
            county_fips,
            qcew_industry_code,
            year,
            quarter,
            COUNT(*) AS rows_per_key
        FROM base
        GROUP BY
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
    FROM base
),
latest_stats AS (
    SELECT
        COUNT(*) AS latest_row_count,
        COUNT(DISTINCT state_fips) AS latest_state_count,
        COUNT(DISTINCT county_fips) AS latest_county_count,
        COUNT(DISTINCT qcew_industry_code) AS latest_sector_count,
        COUNT_IF(qtrly_estabs > 0) AS latest_positive_estab_rows
    FROM base
    WHERE period_id = (SELECT latest_period_id FROM latest_period)
)
SELECT
    'QCEW' AS check_group,
    'qcew_growth_scores_row_count_positive' AS check_name,
    'ERROR' AS severity,
    'INT.INT_QCEW_GROWTH_SCORES' AS object_name,
    CASE WHEN row_count > 0 THEN 'PASS' ELSE 'FAIL' END AS status,
    TO_VARCHAR(row_count) AS observed_value,
    '> 0' AS expected_value,
    'QCEW growth score table should not be empty.' AS details,
    CURRENT_TIMESTAMP() AS checked_at
FROM row_stats

UNION ALL
SELECT
    'QCEW',
    'qcew_key_fields_not_null',
    'ERROR',
    'INT.INT_QCEW_GROWTH_SCORES',
    CASE WHEN null_key_rows = 0 THEN 'PASS' ELSE 'FAIL' END,
    TO_VARCHAR(null_key_rows),
    '0',
    'No rows should have null physical grain fields or period fields.',
    CURRENT_TIMESTAMP()
FROM row_stats

UNION ALL
SELECT
    'QCEW',
    'qcew_unique_county_industry_quarter_key',
    'ERROR',
    'INT.INT_QCEW_GROWTH_SCORES',
    CASE WHEN duplicate_key_count = 0 THEN 'PASS' ELSE 'FAIL' END,
    TO_VARCHAR(duplicate_key_count),
    '0',
    'There should be at most one row per state_fips, county_fips, qcew_industry_code, year, quarter.',
    CURRENT_TIMESTAMP()
FROM duplicate_keys

UNION ALL
SELECT
    'QCEW',
    'qcew_establishments_non_negative',
    'ERROR',
    'INT.INT_QCEW_GROWTH_SCORES',
    CASE WHEN negative_estab_rows = 0 THEN 'PASS' ELSE 'FAIL' END,
    TO_VARCHAR(negative_estab_rows),
    '0',
    'Quarterly establishments should not be negative.',
    CURRENT_TIMESTAMP()
FROM row_stats

UNION ALL
SELECT
    'QCEW',
    'qcew_employment_non_negative',
    'WARN',
    'INT.INT_QCEW_GROWTH_SCORES',
    CASE WHEN negative_employment_rows = 0 THEN 'PASS' ELSE 'FAIL' END,
    TO_VARCHAR(negative_employment_rows),
    '0',
    'Average monthly employment should not be negative.',
    CURRENT_TIMESTAMP()
FROM row_stats

UNION ALL
SELECT
    'QCEW',
    'qcew_wages_non_negative',
    'WARN',
    'INT.INT_QCEW_GROWTH_SCORES',
    CASE WHEN negative_wage_rows = 0 THEN 'PASS' ELSE 'FAIL' END,
    TO_VARCHAR(negative_wage_rows),
    '0',
    'Quarterly wages should not be negative.',
    CURRENT_TIMESTAMP()
FROM row_stats

UNION ALL
SELECT
    'QCEW',
    'qcew_growth_scores_between_0_and_100',
    'ERROR',
    'INT.INT_QCEW_GROWTH_SCORES',
    CASE WHEN score_out_of_range_rows = 0 THEN 'PASS' ELSE 'FAIL' END,
    TO_VARCHAR(score_out_of_range_rows),
    '0',
    'Growth score fields should be bounded to [0, 100].',
    CURRENT_TIMESTAMP()
FROM row_stats

UNION ALL
SELECT
    'QCEW',
    'qcew_latest_period_state_coverage',
    'WARN',
    'INT.INT_QCEW_GROWTH_SCORES',
    CASE WHEN latest_state_count >= 50 THEN 'PASS' ELSE 'FAIL' END,
    TO_VARCHAR(latest_state_count),
    '>= 50',
    'Latest QCEW period should have broad national state coverage.',
    CURRENT_TIMESTAMP()
FROM latest_stats

UNION ALL
SELECT
    'QCEW',
    'qcew_latest_period_county_coverage',
    'WARN',
    'INT.INT_QCEW_GROWTH_SCORES',
    CASE WHEN latest_county_count >= 2500 THEN 'PASS' ELSE 'FAIL' END,
    TO_VARCHAR(latest_county_count),
    '>= 2500',
    'Latest QCEW period should have broad county coverage for a national build.',
    CURRENT_TIMESTAMP()
FROM latest_stats

UNION ALL
SELECT
    'QCEW',
    'qcew_latest_period_target_sector_coverage',
    'WARN',
    'INT.INT_QCEW_GROWTH_SCORES',
    CASE WHEN latest_sector_count >= 6 THEN 'PASS' ELSE 'FAIL' END,
    TO_VARCHAR(latest_sector_count),
    '>= 6',
    'Latest QCEW period should include the current target sector set.',
    CURRENT_TIMESTAMP()
FROM latest_stats;
