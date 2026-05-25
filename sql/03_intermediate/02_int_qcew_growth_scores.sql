USE WAREHOUSE COMPUTE_WH;
USE DATABASE SMB_MARKET_INTELLIGENCE_DEV;
USE SCHEMA INT;

CREATE OR REPLACE VIEW INT.INT_QCEW_GROWTH_SCORES AS
WITH base AS (
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

        growth_signal_flag
    FROM INT.INT_QCEW_COUNTY_INDUSTRY_GROWTH_QTR
    WHERE sector_code IS NOT NULL
),

trend_inputs AS (
    SELECT
        base.*,

        LAG(estabs_qoq_pct_chg) OVER (
            PARTITION BY county_fips, qcew_industry_code
            ORDER BY year, quarter
        ) AS estabs_qoq_pct_chg_prev_qtr,

        LAG(estabs_4q_avg) OVER (
            PARTITION BY county_fips, qcew_industry_code
            ORDER BY year, quarter
        ) AS estabs_4q_avg_prev_qtr,

        LAG(employment_4q_avg) OVER (
            PARTITION BY county_fips, qcew_industry_code
            ORDER BY year, quarter
        ) AS employment_4q_avg_prev_qtr,

        STDDEV_SAMP(estabs_qoq_pct_chg) OVER (
            PARTITION BY county_fips, qcew_industry_code
            ORDER BY year, quarter
            ROWS BETWEEN 3 PRECEDING AND CURRENT ROW
        ) AS estabs_qoq_volatility_4q

    FROM base
),

features AS (
    SELECT
        trend_inputs.*,

        oty_qtrly_estabs_pct_chg AS estabs_yoy_growth_raw,
        estabs_qoq_pct_chg AS estabs_qoq_growth_raw,
        employment_qoq_pct_chg AS employment_qoq_growth_raw,
        oty_total_qtrly_wages_pct_chg AS wages_yoy_growth_raw,
        qtrly_estabs AS establishment_scale_raw,

        CASE
            WHEN estabs_qoq_pct_chg IS NULL
                 OR estabs_qoq_pct_chg_prev_qtr IS NULL
                THEN NULL
            ELSE estabs_qoq_pct_chg - estabs_qoq_pct_chg_prev_qtr
        END AS estabs_growth_acceleration_raw,

        CASE
            WHEN estabs_4q_avg_prev_qtr IS NULL
                 OR estabs_4q_avg_prev_qtr = 0
                THEN NULL
            ELSE 100.0 * (estabs_4q_avg - estabs_4q_avg_prev_qtr) / estabs_4q_avg_prev_qtr
        END AS estabs_4q_trend_raw,

        CASE
            WHEN employment_4q_avg_prev_qtr IS NULL
                 OR employment_4q_avg_prev_qtr = 0
                THEN NULL
            ELSE 100.0 * (employment_4q_avg - employment_4q_avg_prev_qtr) / employment_4q_avg_prev_qtr
        END AS employment_4q_trend_raw,

        /*
        Lower volatility is better for expected growth, so multiply by -1.
        Higher value = more stable.
        */
        -1.0 * estabs_qoq_volatility_4q AS estabs_stability_raw

    FROM trend_inputs
),

bounds AS (
    SELECT
        features.*,

        PERCENTILE_CONT(0.05) WITHIN GROUP (ORDER BY estabs_yoy_growth_raw)
            OVER (PARTITION BY year, quarter, qcew_industry_code) AS estabs_yoy_p05,
        PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY estabs_yoy_growth_raw)
            OVER (PARTITION BY year, quarter, qcew_industry_code) AS estabs_yoy_p50,
        PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY estabs_yoy_growth_raw)
            OVER (PARTITION BY year, quarter, qcew_industry_code) AS estabs_yoy_p95,

        PERCENTILE_CONT(0.05) WITHIN GROUP (ORDER BY estabs_qoq_growth_raw)
            OVER (PARTITION BY year, quarter, qcew_industry_code) AS estabs_qoq_p05,
        PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY estabs_qoq_growth_raw)
            OVER (PARTITION BY year, quarter, qcew_industry_code) AS estabs_qoq_p50,
        PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY estabs_qoq_growth_raw)
            OVER (PARTITION BY year, quarter, qcew_industry_code) AS estabs_qoq_p95,

        PERCENTILE_CONT(0.05) WITHIN GROUP (ORDER BY employment_qoq_growth_raw)
            OVER (PARTITION BY year, quarter, qcew_industry_code) AS employment_qoq_p05,
        PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY employment_qoq_growth_raw)
            OVER (PARTITION BY year, quarter, qcew_industry_code) AS employment_qoq_p50,
        PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY employment_qoq_growth_raw)
            OVER (PARTITION BY year, quarter, qcew_industry_code) AS employment_qoq_p95,

        PERCENTILE_CONT(0.05) WITHIN GROUP (ORDER BY wages_yoy_growth_raw)
            OVER (PARTITION BY year, quarter, qcew_industry_code) AS wages_yoy_p05,
        PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY wages_yoy_growth_raw)
            OVER (PARTITION BY year, quarter, qcew_industry_code) AS wages_yoy_p50,
        PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY wages_yoy_growth_raw)
            OVER (PARTITION BY year, quarter, qcew_industry_code) AS wages_yoy_p95,

        PERCENTILE_CONT(0.05) WITHIN GROUP (ORDER BY establishment_scale_raw)
            OVER (PARTITION BY year, quarter, qcew_industry_code) AS establishment_scale_p05,
        PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY establishment_scale_raw)
            OVER (PARTITION BY year, quarter, qcew_industry_code) AS establishment_scale_p50,
        PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY establishment_scale_raw)
            OVER (PARTITION BY year, quarter, qcew_industry_code) AS establishment_scale_p95,

        PERCENTILE_CONT(0.05) WITHIN GROUP (ORDER BY estabs_4q_trend_raw)
            OVER (PARTITION BY year, quarter, qcew_industry_code) AS estabs_4q_trend_p05,
        PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY estabs_4q_trend_raw)
            OVER (PARTITION BY year, quarter, qcew_industry_code) AS estabs_4q_trend_p50,
        PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY estabs_4q_trend_raw)
            OVER (PARTITION BY year, quarter, qcew_industry_code) AS estabs_4q_trend_p95,

        PERCENTILE_CONT(0.05) WITHIN GROUP (ORDER BY estabs_growth_acceleration_raw)
            OVER (PARTITION BY year, quarter, qcew_industry_code) AS estabs_accel_p05,
        PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY estabs_growth_acceleration_raw)
            OVER (PARTITION BY year, quarter, qcew_industry_code) AS estabs_accel_p50,
        PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY estabs_growth_acceleration_raw)
            OVER (PARTITION BY year, quarter, qcew_industry_code) AS estabs_accel_p95,

        PERCENTILE_CONT(0.05) WITHIN GROUP (ORDER BY employment_4q_trend_raw)
            OVER (PARTITION BY year, quarter, qcew_industry_code) AS employment_4q_trend_p05,
        PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY employment_4q_trend_raw)
            OVER (PARTITION BY year, quarter, qcew_industry_code) AS employment_4q_trend_p50,
        PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY employment_4q_trend_raw)
            OVER (PARTITION BY year, quarter, qcew_industry_code) AS employment_4q_trend_p95,

        PERCENTILE_CONT(0.05) WITHIN GROUP (ORDER BY estabs_stability_raw)
            OVER (PARTITION BY year, quarter, qcew_industry_code) AS estabs_stability_p05,
        PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY estabs_stability_raw)
            OVER (PARTITION BY year, quarter, qcew_industry_code) AS estabs_stability_p50,
        PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY estabs_stability_raw)
            OVER (PARTITION BY year, quarter, qcew_industry_code) AS estabs_stability_p95

    FROM features
),

scoring_inputs AS (
    SELECT
        bounds.*,

        LEAST(GREATEST(COALESCE(estabs_yoy_growth_raw, estabs_yoy_p50, 0), estabs_yoy_p05), estabs_yoy_p95)
            AS estabs_yoy_score_value,

        LEAST(GREATEST(COALESCE(estabs_qoq_growth_raw, estabs_qoq_p50, 0), estabs_qoq_p05), estabs_qoq_p95)
            AS estabs_qoq_score_value,

        LEAST(GREATEST(COALESCE(employment_qoq_growth_raw, employment_qoq_p50, 0), employment_qoq_p05), employment_qoq_p95)
            AS employment_qoq_score_value,

        LEAST(GREATEST(COALESCE(wages_yoy_growth_raw, wages_yoy_p50, 0), wages_yoy_p05), wages_yoy_p95)
            AS wages_yoy_score_value,

        LEAST(GREATEST(COALESCE(establishment_scale_raw, establishment_scale_p50, 0), establishment_scale_p05), establishment_scale_p95)
            AS establishment_scale_score_value,

        LEAST(GREATEST(COALESCE(estabs_4q_trend_raw, estabs_4q_trend_p50, 0), estabs_4q_trend_p05), estabs_4q_trend_p95)
            AS estabs_4q_trend_score_value,

        LEAST(GREATEST(COALESCE(estabs_growth_acceleration_raw, estabs_accel_p50, 0), estabs_accel_p05), estabs_accel_p95)
            AS estabs_acceleration_score_value,

        LEAST(GREATEST(COALESCE(employment_4q_trend_raw, employment_4q_trend_p50, 0), employment_4q_trend_p05), employment_4q_trend_p95)
            AS employment_4q_trend_score_value,

        LEAST(GREATEST(COALESCE(estabs_stability_raw, estabs_stability_p50, 0), estabs_stability_p05), estabs_stability_p95)
            AS estabs_stability_score_value

    FROM bounds
),

ranked AS (
    SELECT
        scoring_inputs.*,

        100.0 * PERCENT_RANK() OVER (
            PARTITION BY year, quarter, qcew_industry_code
            ORDER BY estabs_yoy_score_value
        ) AS estabs_yoy_component_score,

        100.0 * PERCENT_RANK() OVER (
            PARTITION BY year, quarter, qcew_industry_code
            ORDER BY estabs_qoq_score_value
        ) AS estabs_qoq_component_score,

        100.0 * PERCENT_RANK() OVER (
            PARTITION BY year, quarter, qcew_industry_code
            ORDER BY employment_qoq_score_value
        ) AS employment_qoq_component_score,

        100.0 * PERCENT_RANK() OVER (
            PARTITION BY year, quarter, qcew_industry_code
            ORDER BY wages_yoy_score_value
        ) AS wages_yoy_component_score,

        100.0 * PERCENT_RANK() OVER (
            PARTITION BY year, quarter, qcew_industry_code
            ORDER BY establishment_scale_score_value
        ) AS establishment_scale_component_score,

        100.0 * PERCENT_RANK() OVER (
            PARTITION BY year, quarter, qcew_industry_code
            ORDER BY estabs_4q_trend_score_value
        ) AS estabs_4q_trend_component_score,

        100.0 * PERCENT_RANK() OVER (
            PARTITION BY year, quarter, qcew_industry_code
            ORDER BY estabs_acceleration_score_value
        ) AS estabs_acceleration_component_score,

        100.0 * PERCENT_RANK() OVER (
            PARTITION BY year, quarter, qcew_industry_code
            ORDER BY employment_4q_trend_score_value
        ) AS employment_4q_trend_component_score,

        100.0 * PERCENT_RANK() OVER (
            PARTITION BY year, quarter, qcew_industry_code
            ORDER BY estabs_stability_score_value
        ) AS estabs_stability_component_score

    FROM scoring_inputs
),

final_scores AS (
    SELECT
        ranked.*,

        ROUND(
              0.35 * estabs_yoy_component_score
            + 0.15 * estabs_qoq_component_score
            + 0.15 * employment_qoq_component_score
            + 0.15 * wages_yoy_component_score
            + 0.20 * establishment_scale_component_score
        , 2) AS ongoing_growth_score,

        ROUND(
              0.35 * estabs_4q_trend_component_score -- for momentum, consider using the momentum formula for finance
            + 0.20 * estabs_acceleration_component_score
            + 0.20 * employment_4q_trend_component_score
            + 0.10 * wages_yoy_component_score
            + 0.15 * estabs_stability_component_score
        , 2) AS expected_growth_score

    FROM ranked
)

SELECT
    'qcew_growth_v1' AS scoring_version,
    CURRENT_TIMESTAMP() AS scored_at,

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
    estabs_qoq_pct_chg,
    employment_qoq_pct_chg,
    wages_qoq_pct_chg,

    estabs_4q_avg,
    employment_4q_avg,
    wages_4q_avg,

    growth_signal_flag,

    estabs_yoy_growth_raw,
    estabs_qoq_growth_raw,
    employment_qoq_growth_raw,
    wages_yoy_growth_raw,
    establishment_scale_raw,
    estabs_4q_trend_raw,
    estabs_growth_acceleration_raw,
    employment_4q_trend_raw,
    estabs_qoq_volatility_4q,

    ROUND(estabs_yoy_component_score, 2) AS estabs_yoy_component_score,
    ROUND(estabs_qoq_component_score, 2) AS estabs_qoq_component_score,
    ROUND(employment_qoq_component_score, 2) AS employment_qoq_component_score,
    ROUND(wages_yoy_component_score, 2) AS wages_yoy_component_score,
    ROUND(establishment_scale_component_score, 2) AS establishment_scale_component_score,

    ROUND(estabs_4q_trend_component_score, 2) AS estabs_4q_trend_component_score,
    ROUND(estabs_acceleration_component_score, 2) AS estabs_acceleration_component_score,
    ROUND(employment_4q_trend_component_score, 2) AS employment_4q_trend_component_score,
    ROUND(estabs_stability_component_score, 2) AS estabs_stability_component_score,

    ongoing_growth_score,
    expected_growth_score,

    CASE
        WHEN ongoing_growth_score >= 80 THEN 'very_high'
        WHEN ongoing_growth_score >= 60 THEN 'high'
        WHEN ongoing_growth_score >= 40 THEN 'moderate'
        WHEN ongoing_growth_score >= 20 THEN 'low'
        ELSE 'very_low'
    END AS ongoing_growth_tier,

    CASE
        WHEN expected_growth_score >= 80 THEN 'very_high'
        WHEN expected_growth_score >= 60 THEN 'high'
        WHEN expected_growth_score >= 40 THEN 'moderate'
        WHEN expected_growth_score >= 20 THEN 'low'
        ELSE 'very_low'
    END AS expected_growth_tier

FROM final_scores;
