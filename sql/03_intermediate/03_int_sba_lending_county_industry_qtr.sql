USE WAREHOUSE COMPUTE_WH;
USE DATABASE SMB_MARKET_INTELLIGENCE_DEV;
USE SCHEMA INT;

CREATE OR REPLACE VIEW INT.INT_SBA_LENDING_COUNTY_INDUSTRY_QTR AS
WITH loan_base AS (
    SELECT
        state_fips,
        state_abbr,
        state_name,
        county_fips,

        qcew_industry_code,
        sector_code,
        sector_name,

        year,
        quarter,
        period_id,

        approval_date,

        COALESCE(gross_approval_amount, 0) AS gross_approval_amount,
        COALESCE(initial_approval_amount, gross_approval_amount, 0) AS initial_approval_amount,
        COALESCE(current_approval_amount, gross_approval_amount, 0) AS current_approval_amount,

        NULLIF(TRIM(lender_name), '') AS lender_name,
        COALESCE(jobs_supported, 0) AS jobs_supported

    FROM STG.STG_SBA_7A_LOANS
    WHERE approval_date IS NOT NULL
      AND has_state_fips = TRUE
      AND has_county_fips = TRUE
      AND county_state_fips_match = TRUE
      AND has_sector_mapping = TRUE
),

market_totals AS (
    SELECT
        state_fips,
        state_abbr,
        state_name,
        county_fips,

        qcew_industry_code,
        sector_code,
        sector_name,

        year,
        quarter,
        period_id,

        COUNT(*) AS sba_loan_count,
        SUM(gross_approval_amount) AS sba_gross_approval_amount,
        SUM(initial_approval_amount) AS sba_initial_approval_amount,
        SUM(current_approval_amount) AS sba_current_approval_amount,
        SUM(jobs_supported) AS sba_jobs_supported,

        COUNT(DISTINCT lender_name) AS active_lender_count,
        COUNT_IF(lender_name IS NULL) AS loans_missing_lender_name,

        AVG(NULLIF(gross_approval_amount, 0)) AS avg_gross_loan_amount,
        MIN(approval_date) AS first_approval_date,
        MAX(approval_date) AS latest_approval_date

    FROM loan_base
    GROUP BY
        state_fips,
        state_abbr,
        state_name,
        county_fips,
        qcew_industry_code,
        sector_code,
        sector_name,
        year,
        quarter,
        period_id
),

lender_totals AS (
    SELECT
        state_fips,
        county_fips,
        qcew_industry_code,
        year,
        quarter,
        period_id,
        lender_name,

        COUNT(*) AS lender_loan_count,
        SUM(gross_approval_amount) AS lender_gross_approval_amount

    FROM loan_base
    WHERE lender_name IS NOT NULL
    GROUP BY
        state_fips,
        county_fips,
        qcew_industry_code,
        year,
        quarter,
        period_id,
        lender_name
),

lender_shares AS (
    SELECT
        l.*,
        m.sba_loan_count,
        m.sba_gross_approval_amount,

        CASE
            WHEN m.sba_loan_count = 0 THEN NULL
            ELSE l.lender_loan_count / m.sba_loan_count
        END AS lender_share_by_count,

        CASE
            WHEN m.sba_gross_approval_amount = 0 THEN NULL
            ELSE l.lender_gross_approval_amount / m.sba_gross_approval_amount
        END AS lender_share_by_amount

    FROM lender_totals l
    INNER JOIN market_totals m
        ON l.state_fips = m.state_fips
       AND l.county_fips = m.county_fips
       AND l.qcew_industry_code = m.qcew_industry_code
       AND l.year = m.year
       AND l.quarter = m.quarter
),

top_lender AS (
    SELECT
        state_fips,
        county_fips,
        qcew_industry_code,
        year,
        quarter,
        period_id,

        lender_name AS top_lender_name,
        lender_loan_count AS top_lender_loan_count,
        lender_gross_approval_amount AS top_lender_gross_approval_amount,
        lender_share_by_count AS top_lender_share_by_count,
        lender_share_by_amount AS top_lender_share_by_amount

    FROM lender_shares
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY
            state_fips,
            county_fips,
            qcew_industry_code,
            year,
            quarter
        ORDER BY
            lender_gross_approval_amount DESC,
            lender_loan_count DESC,
            lender_name
    ) = 1
),

concentration AS (
    SELECT
        state_fips,
        county_fips,
        qcew_industry_code,
        year,
        quarter,
        period_id,

        SUM(POWER(lender_share_by_amount, 2)) AS lender_hhi_by_amount,
        SUM(POWER(lender_share_by_count, 2)) AS lender_hhi_by_count

    FROM lender_shares
    GROUP BY
        state_fips,
        county_fips,
        qcew_industry_code,
        year,
        quarter,
        period_id
)

SELECT
    'sba_lending_v1' AS model_version,
    CURRENT_TIMESTAMP() AS modeled_at,

    m.state_fips,
    m.state_abbr,
    m.state_name,
    m.county_fips,

    m.qcew_industry_code,
    m.sector_code,
    m.sector_name,

    m.year,
    m.quarter,
    m.period_id,

    m.sba_loan_count,
    m.sba_gross_approval_amount,
    m.sba_initial_approval_amount,
    m.sba_current_approval_amount,
    m.sba_jobs_supported,

    m.active_lender_count,
    m.loans_missing_lender_name,

    ROUND(m.avg_gross_loan_amount, 2) AS avg_gross_loan_amount,

    t.top_lender_name,
    t.top_lender_loan_count,
    t.top_lender_gross_approval_amount,
    ROUND(t.top_lender_share_by_count, 4) AS top_lender_share_by_count,
    ROUND(t.top_lender_share_by_amount, 4) AS top_lender_share_by_amount,

    ROUND(c.lender_hhi_by_amount, 4) AS lender_hhi_by_amount,
    ROUND(c.lender_hhi_by_count, 4) AS lender_hhi_by_count,

    CASE
        WHEN c.lender_hhi_by_amount >= 0.25 THEN 'high_concentration'
        WHEN c.lender_hhi_by_amount >= 0.15 THEN 'moderate_concentration'
        WHEN c.lender_hhi_by_amount IS NULL THEN 'unknown'
        ELSE 'fragmented'
    END AS lender_concentration_tier,

    m.first_approval_date,
    m.latest_approval_date

FROM market_totals m

LEFT JOIN top_lender t
    ON m.state_fips = t.state_fips
   AND m.county_fips = t.county_fips
   AND m.qcew_industry_code = t.qcew_industry_code
   AND m.year = t.year
   AND m.quarter = t.quarter

LEFT JOIN concentration c
    ON m.state_fips = c.state_fips
   AND m.county_fips = c.county_fips
   AND m.qcew_industry_code = c.qcew_industry_code
   AND m.year = c.year
   AND m.quarter = c.quarter;
