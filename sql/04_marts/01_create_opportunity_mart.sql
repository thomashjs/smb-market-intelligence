USE ROLE ACCOUNTADMIN;
USE WAREHOUSE COMPUTE_WH;
USE DATABASE SMB_MARKET_INTELLIGENCE_DEV;

CREATE TABLE IF NOT EXISTS MART.COUNTY_INDUSTRY_OPPORTUNITY_QTR (
    scoring_run_id                 STRING,
    scoring_version                STRING,
    scored_at                      TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),

    county_fips                    STRING,
    state_fips                     STRING,
    year                           NUMBER,
    quarter                        NUMBER,

    sector_code                    STRING,
    sector_name                    STRING,

    establishments                 NUMBER,
    avg_monthly_employment          NUMBER(18,2),
    total_qtrly_wages              NUMBER(18,2),
    avg_wkly_wage                  NUMBER(18,2),

    establishments_yoy_pct_chg      FLOAT,
    wages_yoy_pct_chg               FLOAT,

    sba_loan_count                 NUMBER,
    sba_loan_amount                NUMBER(18,2),
    sba_loans_per_100_establishments FLOAT,
    sba_dollars_per_establishment  FLOAT,

    ongoing_growth_score           FLOAT,
    expected_growth_score          FLOAT,
    underserved_score              FLOAT,
    final_opportunity_score        FLOAT,

    opportunity_tier               STRING,
    recommendation                 STRING
);
