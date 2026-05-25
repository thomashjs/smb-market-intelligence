USE WAREHOUSE COMPUTE_WH;
USE DATABASE SMB_MARKET_INTELLIGENCE_DEV;

-- ============================================================
-- Validation checks for INT.INT_QCEW_COUNTY_INDUSTRY_GROWTH_QTR
-- Purpose:
--   Smoke-test row counts, grain uniqueness, quarter coverage,
--   reference mapping, and growth-signal outputs.
-- ============================================================

-- 1. Overall row count: validate existance
SELECT COUNT(*) AS row_count
FROM SMB_MARKET_INTELLIGENCE_DEV.INT.INT_QCEW_COUNTY_INDUSTRY_GROWTH_QTR;

-- 2. Check year/quarter coverage
SELECT                      
    year,                                                                
    quarter,
    COUNT(*) AS row_count,
    COUNT(DISTINCT county_fips) AS counties,
    COUNT(DISTINCT qcew_industry_code) AS industries,
    SUM(qtrly_estabs) AS establishments
FROM SMB_MARKET_INTELLIGENCE_DEV.INT.INT_QCEW_COUNTY_INDUSTRY_GROWTH_QTR
GROUP BY year, quarter
ORDER BY year DESC, quarter DESC;

-- 3. Inspect sample growth calculations
SELECT
    county_fips,
    sector_code,
    sector_name,
    year,
    quarter,
    qtrly_estabs,
    estabs_prev_qtr,
    estabs_qoq_pct_chg,
    oty_qtrly_estabs_pct_chg,
    avg_monthly_employment,
    employment_prev_qtr,
    employment_qoq_pct_chg,
    total_qtrly_wages,
    wages_prev_qtr,
    wages_qoq_pct_chg,
    growth_signal_flag
FROM SMB_MARKET_INTELLIGENCE_DEV.INT.INT_QCEW_COUNTY_INDUSTRY_GROWTH_QTR
ORDER BY county_fips, sector_code, year, quarter
LIMIT 50;

-- 4. Check whether any industries failed to map to ref
SELECT
    qcew_industry_code,
    COUNT(*) AS row_count
FROM SMB_MARKET_INTELLIGENCE_DEV.INT.INT_QCEW_COUNTY_INDUSTRY_GROWTH_QTR
WHERE sector_code IS NULL
GROUP BY qcew_industry_code
ORDER BY row_count DESC;

-- 5. Check gorwth flag distribution
SELECT
    growth_signal_flag,
    COUNT(*) AS row_count
FROM SMB_MARKET_INTELLIGENCE_DEV.INT.INT_QCEW_COUNTY_INDUSTRY_GROWTH_QTR
GROUP BY growth_signal_flag
ORDER BY row_count DESC;

-- 6. Grain check: should be one row per county × industry × year × quarter
SELECT
    county_fips,
    qcew_industry_code,
    year,
    quarter,
    COUNT(*) AS row_count
FROM INT.INT_QCEW_COUNTY_INDUSTRY_GROWTH_QTR
GROUP BY
    county_fips,
    qcew_industry_code,
    year,
    quarter
HAVING COUNT(*) > 1
ORDER BY row_count DESC
LIMIT 50;

-- 7. Required-key null check
SELECT
    COUNT_IF(county_fips IS NULL) AS null_county_fips,
    COUNT_IF(state_fips IS NULL) AS null_state_fips,
    COUNT_IF(qcew_industry_code IS NULL) AS null_qcew_industry_code,
    COUNT_IF(year IS NULL) AS null_year,
    COUNT_IF(quarter IS NULL) AS null_quarter
FROM INT.INT_QCEW_COUNTY_INDUSTRY_GROWTH_QTR;

-- 8. Basic metric sanity check
SELECT
    MIN(qtrly_estabs) AS min_establishments,
    MAX(qtrly_estabs) AS max_establishments,
    MIN(avg_monthly_employment) AS min_avg_monthly_employment,
    MAX(avg_monthly_employment) AS max_avg_monthly_employment,
    MIN(total_qtrly_wages) AS min_total_qtrly_wages,
    MAX(total_qtrly_wages) AS max_total_qtrly_wages
FROM INT.INT_QCEW_COUNTY_INDUSTRY_GROWTH_QTR;

-- 9. After 02_int_qcew_growth_scores.sql

-- Row count
SELECT COUNT(*) AS row_count
FROM SMB_MARKET_INTELLIGENCE_DEV.INT.INT_QCEW_GROWTH_SCORES;

-- Score ranges
SELECT
    MIN(ongoing_growth_score) AS min_ongoing_growth_score,
    MAX(ongoing_growth_score) AS max_ongoing_growth_score,
    AVG(ongoing_growth_score) AS avg_ongoing_growth_score,
    MIN(expected_growth_score) AS min_expected_growth_score,
    MAX(expected_growth_score) AS max_expected_growth_score,
    AVG(expected_growth_score) AS avg_expected_growth_score
FROM SMB_MARKET_INTELLIGENCE_DEV.INT.INT_QCEW_GROWTH_SCORES;

-- Top scored markets
SELECT
    county_fips,
    sector_code,
    sector_name,
    year,
    quarter,
    qtrly_estabs,
    oty_qtrly_estabs_pct_chg,
    estabs_qoq_pct_chg,
    employment_qoq_pct_chg,
    oty_total_qtrly_wages_pct_chg,
    ongoing_growth_score,
    expected_growth_score,
    ongoing_growth_tier,
    expected_growth_tier
FROM SMB_MARKET_INTELLIGENCE_DEV.INT.INT_QCEW_GROWTH_SCORES
ORDER BY year DESC, quarter DESC, ongoing_growth_score DESC
LIMIT 25;

-- Distribution by latest quarter; sector and county level are aggregated
WITH latest_period AS (
    SELECT MAX(period_id) AS max_period_id
    FROM SMB_MARKET_INTELLIGENCE_DEV.INT.INT_QCEW_GROWTH_SCORES
)
SELECT
    sector_code,
    sector_name,
    COUNT(*) AS county_industry_rows,
    ROUND(AVG(ongoing_growth_score), 2) AS avg_ongoing_growth_score,
    ROUND(AVG(expected_growth_score), 2) AS avg_expected_growth_score,
    COUNT_IF(ongoing_growth_tier IN ('high', 'very_high')) AS high_ongoing_growth_markets,
    COUNT_IF(expected_growth_tier IN ('high', 'very_high')) AS high_expected_growth_markets
FROM SMB_MARKET_INTELLIGENCE_DEV.INT.INT_QCEW_GROWTH_SCORES g
JOIN latest_period p
    ON g.period_id = p.max_period_id
GROUP BY sector_code, sector_name
ORDER BY avg_ongoing_growth_score DESC;