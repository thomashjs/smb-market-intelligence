USE DATABASE SMB_MARKET_INTELLIGENCE_DEV;

CREATE SCHEMA IF NOT EXISTS DQ;

CREATE OR REPLACE VIEW DQ.VW_DQ_SBA_CHECKS AS
WITH
base AS (
    SELECT *
    FROM INT.INT_SBA_LENDING_COUNTY_INDUSTRY_QTR
),
row_stats AS (
    SELECT
        COUNT(*) AS row_count,
        COUNT(DISTINCT state_fips) AS state_count,
        COUNT(DISTINCT county_fips) AS county_count,
        COUNT(DISTINCT qcew_industry_code) AS sector_count,
        MIN(first_approval_date) AS min_approval_date,
        MAX(latest_approval_date) AS max_approval_date,
        SUM(sba_loan_count) AS total_loan_count,
        SUM(sba_gross_approval_amount) AS total_gross_approval_amount,
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
        COUNT_IF(sba_loan_count < 0) AS negative_loan_count_rows,
        COUNT_IF(sba_gross_approval_amount < 0) AS negative_gross_amount_rows,
        COUNT_IF(sba_initial_approval_amount < 0) AS negative_initial_amount_rows,
        COUNT_IF(sba_current_approval_amount < 0) AS negative_current_amount_rows,
        COUNT_IF(active_lender_count < 0) AS negative_lender_count_rows,
        COUNT_IF(sba_jobs_supported < 0) AS negative_jobs_rows,
        COUNT_IF(
            lender_hhi_by_amount IS NOT NULL
            AND (lender_hhi_by_amount < 0 OR lender_hhi_by_amount > 1)
        ) AS amount_hhi_out_of_range_rows,
        COUNT_IF(
            lender_hhi_by_count IS NOT NULL
            AND (lender_hhi_by_count < 0 OR lender_hhi_by_count > 1)
        ) AS count_hhi_out_of_range_rows,
        COUNT_IF(
            top_lender_share_by_amount IS NOT NULL
            AND (top_lender_share_by_amount < 0 OR top_lender_share_by_amount > 1)
        ) AS top_lender_amount_share_out_of_range_rows,
        COUNT_IF(
            top_lender_share_by_count IS NOT NULL
            AND (top_lender_share_by_count < 0 OR top_lender_share_by_count > 1)
        ) AS top_lender_count_share_out_of_range_rows
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
)
SELECT
    'SBA' AS check_group,
    'sba_lending_intermediate_row_count_positive' AS check_name,
    'ERROR' AS severity,
    'INT.INT_SBA_LENDING_COUNTY_INDUSTRY_QTR' AS object_name,
    CASE WHEN row_count > 0 THEN 'PASS' ELSE 'FAIL' END AS status,
    TO_VARCHAR(row_count) AS observed_value,
    '> 0' AS expected_value,
    'SBA lending intermediate should not be empty after national load.' AS details,
    CURRENT_TIMESTAMP() AS checked_at
FROM row_stats

UNION ALL
SELECT
    'SBA',
    'sba_key_fields_not_null',
    'ERROR',
    'INT.INT_SBA_LENDING_COUNTY_INDUSTRY_QTR',
    CASE WHEN null_key_rows = 0 THEN 'PASS' ELSE 'FAIL' END,
    TO_VARCHAR(null_key_rows),
    '0',
    'No rows should have null physical grain fields or period fields.',
    CURRENT_TIMESTAMP()
FROM row_stats

UNION ALL
SELECT
    'SBA',
    'sba_unique_county_industry_quarter_key',
    'ERROR',
    'INT.INT_SBA_LENDING_COUNTY_INDUSTRY_QTR',
    CASE WHEN duplicate_key_count = 0 THEN 'PASS' ELSE 'FAIL' END,
    TO_VARCHAR(duplicate_key_count),
    '0',
    'There should be at most one SBA aggregate row per state_fips, county_fips, qcew_industry_code, year, quarter.',
    CURRENT_TIMESTAMP()
FROM duplicate_keys

UNION ALL
SELECT
    'SBA',
    'sba_loan_count_positive_total',
    'ERROR',
    'INT.INT_SBA_LENDING_COUNTY_INDUSTRY_QTR',
    CASE WHEN total_loan_count > 0 THEN 'PASS' ELSE 'FAIL' END,
    TO_VARCHAR(total_loan_count),
    '> 0',
    'Total SBA loan count should be positive.',
    CURRENT_TIMESTAMP()
FROM row_stats

UNION ALL
SELECT
    'SBA',
    'sba_gross_approval_amount_positive_total',
    'ERROR',
    'INT.INT_SBA_LENDING_COUNTY_INDUSTRY_QTR',
    CASE WHEN total_gross_approval_amount > 0 THEN 'PASS' ELSE 'FAIL' END,
    TO_VARCHAR(total_gross_approval_amount),
    '> 0',
    'Total SBA gross approval amount should be positive.',
    CURRENT_TIMESTAMP()
FROM row_stats

UNION ALL
SELECT
    'SBA',
    'sba_amounts_non_negative',
    'ERROR',
    'INT.INT_SBA_LENDING_COUNTY_INDUSTRY_QTR',
    CASE
        WHEN negative_gross_amount_rows = 0
         AND negative_initial_amount_rows = 0
         AND negative_current_amount_rows = 0
        THEN 'PASS'
        ELSE 'FAIL'
    END,
    TO_VARCHAR(
        negative_gross_amount_rows
        + negative_initial_amount_rows
        + negative_current_amount_rows
    ),
    '0',
    'SBA approval amount fields should not be negative.',
    CURRENT_TIMESTAMP()
FROM row_stats

UNION ALL
SELECT
    'SBA',
    'sba_counts_non_negative',
    'ERROR',
    'INT.INT_SBA_LENDING_COUNTY_INDUSTRY_QTR',
    CASE
        WHEN negative_loan_count_rows = 0
         AND negative_lender_count_rows = 0
         AND negative_jobs_rows = 0
        THEN 'PASS'
        ELSE 'FAIL'
    END,
    TO_VARCHAR(
        negative_loan_count_rows
        + negative_lender_count_rows
        + negative_jobs_rows
    ),
    '0',
    'SBA count fields should not be negative.',
    CURRENT_TIMESTAMP()
FROM row_stats

UNION ALL
SELECT
    'SBA',
    'sba_lender_hhi_between_0_and_1',
    'ERROR',
    'INT.INT_SBA_LENDING_COUNTY_INDUSTRY_QTR',
    CASE
        WHEN amount_hhi_out_of_range_rows = 0
         AND count_hhi_out_of_range_rows = 0
        THEN 'PASS'
        ELSE 'FAIL'
    END,
    TO_VARCHAR(amount_hhi_out_of_range_rows + count_hhi_out_of_range_rows),
    '0',
    'HHI values should be bounded to [0, 1].',
    CURRENT_TIMESTAMP()
FROM row_stats

UNION ALL
SELECT
    'SBA',
    'sba_top_lender_shares_between_0_and_1',
    'ERROR',
    'INT.INT_SBA_LENDING_COUNTY_INDUSTRY_QTR',
    CASE
        WHEN top_lender_amount_share_out_of_range_rows = 0
         AND top_lender_count_share_out_of_range_rows = 0
        THEN 'PASS'
        ELSE 'FAIL'
    END,
    TO_VARCHAR(
        top_lender_amount_share_out_of_range_rows
        + top_lender_count_share_out_of_range_rows
    ),
    '0',
    'Top lender share fields should be bounded to [0, 1].',
    CURRENT_TIMESTAMP()
FROM row_stats

UNION ALL
SELECT
    'SBA',
    'sba_state_coverage_national',
    'WARN',
    'INT.INT_SBA_LENDING_COUNTY_INDUSTRY_QTR',
    CASE WHEN state_count >= 50 THEN 'PASS' ELSE 'FAIL' END,
    TO_VARCHAR(state_count),
    '>= 50',
    'National SBA aggregate should include broad state coverage.',
    CURRENT_TIMESTAMP()
FROM row_stats

UNION ALL
SELECT
    'SBA',
    'sba_target_sector_coverage',
    'WARN',
    'INT.INT_SBA_LENDING_COUNTY_INDUSTRY_QTR',
    CASE WHEN sector_count >= 6 THEN 'PASS' ELSE 'FAIL' END,
    TO_VARCHAR(sector_count),
    '>= 6',
    'SBA aggregate should include current target sector set.',
    CURRENT_TIMESTAMP()
FROM row_stats;
