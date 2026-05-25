USE DATABASE SMB_MARKET_INTELLIGENCE_DEV;

CREATE OR REPLACE TABLE MART.COUNTY_INDUSTRY_OPPORTUNITY_QTR AS
WITH qcew_base AS (
    SELECT
        g.state_fips,
        g.state_abbr,
        g.state_name,
        g.county_fips,
        g.qcew_industry_code,
        g.sector_code,
        g.sector_name,
        g.year,
        g.quarter,
        g.period_id,

        g.qtrly_estabs,
        g.avg_monthly_employment,
        g.total_qtrly_wages,
        g.avg_wkly_wage,
        g.oty_qtrly_estabs_pct_chg,
        g.oty_total_qtrly_wages_pct_chg,

        g.estabs_prev_qtr,
        g.estabs_qoq_pct_chg,
        g.employment_prev_qtr,
        g.employment_qoq_pct_chg,
        g.wages_prev_qtr,
        g.wages_qoq_pct_chg,

        g.estabs_4q_avg,
        g.employment_4q_avg,
        g.wages_4q_avg,
        g.growth_signal_flag,

        s.ongoing_growth_score,
        s.expected_growth_score,
        s.ongoing_growth_tier,
        s.expected_growth_tier
    FROM INT.INT_QCEW_COUNTY_INDUSTRY_GROWTH_QTR g
    INNER JOIN INT.INT_QCEW_GROWTH_SCORES s
        ON g.state_fips = s.state_fips
       AND g.county_fips = s.county_fips
       AND g.qcew_industry_code = s.qcew_industry_code
       AND g.year = s.year
       AND g.quarter = s.quarter
),

sba_base AS (
    SELECT
        state_fips,
        county_fips,
        qcew_industry_code,
        year,
        quarter,

        sba_loan_count,
        sba_gross_approval_amount,
        sba_initial_approval_amount,
        sba_current_approval_amount,
        sba_jobs_supported,
        active_lender_count,
        loans_missing_lender_name,
        avg_gross_loan_amount,

        top_lender_name,
        top_lender_loan_count,
        top_lender_gross_approval_amount,
        top_lender_share_by_count,
        top_lender_share_by_amount,
        lender_hhi_by_amount,
        lender_hhi_by_count,
        lender_concentration_tier,

        first_approval_date,
        latest_approval_date
    FROM INT.INT_SBA_LENDING_COUNTY_INDUSTRY_QTR
),

joined AS (
    SELECT
        q.state_fips,
        q.state_abbr,
        q.state_name,
        q.county_fips,
        q.qcew_industry_code,
        q.sector_code,
        q.sector_name,
        q.year,
        q.quarter,
        q.period_id,

        q.qtrly_estabs,
        q.avg_monthly_employment,
        q.total_qtrly_wages,
        q.avg_wkly_wage,
        q.oty_qtrly_estabs_pct_chg,
        q.oty_total_qtrly_wages_pct_chg,

        q.estabs_prev_qtr,
        q.estabs_qoq_pct_chg,
        q.employment_prev_qtr,
        q.employment_qoq_pct_chg,
        q.wages_prev_qtr,
        q.wages_qoq_pct_chg,

        q.estabs_4q_avg,
        q.employment_4q_avg,
        q.wages_4q_avg,
        q.growth_signal_flag,

        q.ongoing_growth_score,
        q.expected_growth_score,
        q.ongoing_growth_tier,
        q.expected_growth_tier,

        COALESCE(s.sba_loan_count, 0) AS sba_loan_count,
        COALESCE(s.sba_gross_approval_amount, 0) AS sba_gross_approval_amount,
        COALESCE(s.sba_initial_approval_amount, 0) AS sba_initial_approval_amount,
        COALESCE(s.sba_current_approval_amount, 0) AS sba_current_approval_amount,
        COALESCE(s.sba_jobs_supported, 0) AS sba_jobs_supported,
        COALESCE(s.active_lender_count, 0) AS active_lender_count,
        COALESCE(s.loans_missing_lender_name, 0) AS loans_missing_lender_name,
        s.avg_gross_loan_amount,

        s.top_lender_name,
        COALESCE(s.top_lender_loan_count, 0) AS top_lender_loan_count,
        COALESCE(s.top_lender_gross_approval_amount, 0) AS top_lender_gross_approval_amount,
        s.top_lender_share_by_count,
        s.top_lender_share_by_amount,
        s.lender_hhi_by_amount,
        s.lender_hhi_by_count,

        CASE
            WHEN COALESCE(s.sba_loan_count, 0) = 0 THEN 'No SBA activity'
            ELSE s.lender_concentration_tier
        END AS lender_concentration_tier,

        s.first_approval_date,
        s.latest_approval_date,

        CASE
            WHEN q.qtrly_estabs > 0
                THEN 100.0 * COALESCE(s.sba_loan_count, 0) / q.qtrly_estabs
            ELSE NULL
        END AS sba_loans_per_100_establishments,

        CASE
            WHEN q.qtrly_estabs > 0
                THEN COALESCE(s.sba_gross_approval_amount, 0) / q.qtrly_estabs
            ELSE NULL
        END AS sba_dollars_per_establishment
    FROM qcew_base q
    LEFT JOIN sba_base s
        ON q.state_fips = s.state_fips
       AND q.county_fips = s.county_fips
       AND q.qcew_industry_code = s.qcew_industry_code
       AND q.year = s.year
       AND q.quarter = s.quarter
),

penetration_ranked AS (
    SELECT
        *,
        100.0 * PERCENT_RANK() OVER (
            PARTITION BY period_id, qcew_industry_code
            ORDER BY COALESCE(sba_loans_per_100_establishments, 0)
        ) AS loan_penetration_pct_rank,

        100.0 * PERCENT_RANK() OVER (
            PARTITION BY period_id, qcew_industry_code
            ORDER BY COALESCE(sba_dollars_per_establishment, 0)
        ) AS dollar_penetration_pct_rank
    FROM joined
),

component_scores AS (
    SELECT
        *,
        ROUND(
            0.60 * loan_penetration_pct_rank
          + 0.40 * dollar_penetration_pct_rank,
            2
        ) AS lending_penetration_score,

        ROUND(
            100 - (
                0.60 * loan_penetration_pct_rank
              + 0.40 * dollar_penetration_pct_rank
            ),
            2
        ) AS low_lending_penetration_score,

        CASE
            WHEN sba_loan_count = 0 THEN 50
            WHEN lender_hhi_by_amount IS NULL THEN 50
            ELSE ROUND(
                100 * (1 - LEAST(1, GREATEST(0, lender_hhi_by_amount))),
                2
            )
        END AS lender_fragmentation_score,

        50.00 AS lending_momentum_score
    FROM penetration_ranked
),

opportunity_scored AS (
    SELECT
        *,
        ROUND(
            LEAST(
                100,
                GREATEST(
                    0,
                    0.55 * COALESCE(expected_growth_score, 50)
                  + 0.25 * COALESCE(ongoing_growth_score, 50)
                  + 0.20 * COALESCE(low_lending_penetration_score, 50)
                )
            ),
            2
        ) AS underserved_score
    FROM component_scores
),

final_scored AS (
    SELECT
        *,
        ROUND(
            LEAST(
                100,
                GREATEST(
                    0,
                    0.30 * COALESCE(ongoing_growth_score, 50)
                  + 0.30 * COALESCE(expected_growth_score, 50)
                  + 0.25 * COALESCE(underserved_score, 50)
                  + 0.10 * COALESCE(lender_fragmentation_score, 50)
                  + 0.05 * COALESCE(lending_momentum_score, 50)
                )
            ),
            2
        ) AS final_opportunity_score
    FROM opportunity_scored
)

SELECT
    'opportunity_score_v1' AS scoring_version,
    CURRENT_TIMESTAMP() AS scored_at,

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
    growth_signal_flag,

    ongoing_growth_score,
    expected_growth_score,
    ongoing_growth_tier,
    expected_growth_tier,

    sba_loan_count,
    sba_gross_approval_amount,
    sba_initial_approval_amount,
    sba_current_approval_amount,
    sba_jobs_supported,
    active_lender_count,
    loans_missing_lender_name,
    avg_gross_loan_amount,

    top_lender_name,
    top_lender_loan_count,
    top_lender_gross_approval_amount,
    top_lender_share_by_count,
    top_lender_share_by_amount,
    lender_hhi_by_amount,
    lender_hhi_by_count,
    lender_concentration_tier,

    first_approval_date,
    latest_approval_date,

    sba_loans_per_100_establishments,
    sba_dollars_per_establishment,

    lending_penetration_score,
    low_lending_penetration_score,
    underserved_score,
    lender_fragmentation_score,
    lending_momentum_score,
    final_opportunity_score,

    CASE
        WHEN final_opportunity_score >= 85 THEN 'Very High'
        WHEN final_opportunity_score >= 70 THEN 'High'
        WHEN final_opportunity_score >= 55 THEN 'Moderate'
        WHEN final_opportunity_score >= 40 THEN 'Watchlist'
        ELSE 'Low'
    END AS opportunity_tier,

    CASE
        WHEN final_opportunity_score >= 85
            THEN 'Prioritize for near-term market expansion review'
        WHEN final_opportunity_score >= 70
            THEN 'Strong candidate for sales and lending opportunity analysis'
        WHEN final_opportunity_score >= 55
            THEN 'Monitor and compare against neighboring counties/industries'
        WHEN final_opportunity_score >= 40
            THEN 'Watchlist only; needs stronger growth or lending signal'
        ELSE 'Low priority under current scoring version'
    END AS recommendation
FROM final_scored;