USE WAREHOUSE COMPUTE_WH;
USE DATABASE SMB_MARKET_INTELLIGENCE_DEV;
USE SCHEMA INT;

CREATE OR REPLACE VIEW INT.INT_QCEW_COUNTY_INDUSTRY_GROWTH_QTR AS
WITH base AS (
    SELECT
        q.county_fips,
        LEFT(q.county_fips, 2) AS state_fips,
        q.qcew_industry_code,
        s.sector_code,
        s.sector_name,
        q.year,
        q.quarter,

        /* Continuous quarter index for time ordering. */
        q.year * 4 + q.quarter AS period_id,

        q.qtrly_estabs,
        q.avg_monthly_employment,
        q.total_qtrly_wages,
        q.avg_wkly_wage,

        q.oty_qtrly_estabs_pct_chg,
        q.oty_total_qtrly_wages_pct_chg

    FROM STG.STG_QCEW_COUNTY_INDUSTRY_QTR q
    LEFT JOIN REF.NAICS_SECTOR s
        ON q.qcew_industry_code = s.qcew_industry_code
),

windowed AS (
    SELECT
        base.*,

        LAG(qtrly_estabs) OVER (
            PARTITION BY county_fips, qcew_industry_code
            ORDER BY year, quarter
        ) AS estabs_prev_qtr,

        LAG(avg_monthly_employment) OVER (
            PARTITION BY county_fips, qcew_industry_code
            ORDER BY year, quarter
        ) AS employment_prev_qtr,

        LAG(total_qtrly_wages) OVER (
            PARTITION BY county_fips, qcew_industry_code
            ORDER BY year, quarter
        ) AS wages_prev_qtr,

        AVG(qtrly_estabs) OVER (
            PARTITION BY county_fips, qcew_industry_code
            ORDER BY year, quarter
            ROWS BETWEEN 3 PRECEDING AND CURRENT ROW
        ) AS estabs_4q_avg,

        AVG(avg_monthly_employment) OVER (
            PARTITION BY county_fips, qcew_industry_code
            ORDER BY year, quarter
            ROWS BETWEEN 3 PRECEDING AND CURRENT ROW
        ) AS employment_4q_avg,

        AVG(total_qtrly_wages) OVER (
            PARTITION BY county_fips, qcew_industry_code
            ORDER BY year, quarter
            ROWS BETWEEN 3 PRECEDING AND CURRENT ROW
        ) AS wages_4q_avg

    FROM base
),

growth AS (
    SELECT
        county_fips,
        state_fips,
        qcew_industry_code,
        sector_code,
        sector_name,
        year,
        quarter,
        period_id,

        qtrly_estabs,
        avg_monthly_employment,
        total_qtrly_wages,
        avg_wkly_wage,

        oty_qtrly_estabs_pct_chg,
        oty_total_qtrly_wages_pct_chg,

        estabs_prev_qtr,

        CASE
            WHEN estabs_prev_qtr IS NULL OR estabs_prev_qtr = 0 THEN NULL
            ELSE ROUND(100.0 * (qtrly_estabs - estabs_prev_qtr) / estabs_prev_qtr, 2)
        END AS estabs_qoq_pct_chg,

        employment_prev_qtr,

        CASE
            WHEN employment_prev_qtr IS NULL OR employment_prev_qtr = 0 THEN NULL
            ELSE ROUND(100.0 * (avg_monthly_employment - employment_prev_qtr) / employment_prev_qtr, 2)
        END AS employment_qoq_pct_chg,

        wages_prev_qtr,

        CASE
            WHEN wages_prev_qtr IS NULL OR wages_prev_qtr = 0 THEN NULL
            ELSE ROUND(100.0 * (total_qtrly_wages - wages_prev_qtr) / wages_prev_qtr, 2)
        END AS wages_qoq_pct_chg,

        ROUND(estabs_4q_avg, 2) AS estabs_4q_avg,
        ROUND(employment_4q_avg, 2) AS employment_4q_avg,
        ROUND(wages_4q_avg, 2) AS wages_4q_avg

    FROM windowed
)

SELECT
    county_fips,
    state_fips,
    qcew_industry_code,
    sector_code,
    sector_name,
    year,
    quarter,
    period_id,

    qtrly_estabs,
    avg_monthly_employment,
    total_qtrly_wages,
    avg_wkly_wage,

    oty_qtrly_estabs_pct_chg,
    oty_total_qtrly_wages_pct_chg,

    estabs_prev_qtr,
    estabs_qoq_pct_chg,

    employment_prev_qtr,
    employment_qoq_pct_chg,

    wages_prev_qtr,
    wages_qoq_pct_chg,

    estabs_4q_avg,
    employment_4q_avg,
    wages_4q_avg,

    CASE
        WHEN estabs_prev_qtr IS NULL THEN 'insufficient_history'
        WHEN estabs_qoq_pct_chg > 0
             AND COALESCE(oty_qtrly_estabs_pct_chg, 0) > 0
             AND COALESCE(employment_qoq_pct_chg, 0) >= 0
            THEN 'positive_growth'
        WHEN estabs_qoq_pct_chg < 0
             AND COALESCE(oty_qtrly_estabs_pct_chg, 0) < 0
            THEN 'negative_growth'
        ELSE 'mixed_growth'
    END AS growth_signal_flag

FROM growth;
