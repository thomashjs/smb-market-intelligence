USE WAREHOUSE COMPUTE_WH;
USE DATABASE SMB_MARKET_INTELLIGENCE_DEV;
USE SCHEMA STG;

CREATE OR REPLACE VIEW STG.STG_QCEW_COUNTY_INDUSTRY_QTR AS
WITH cleaned AS (
    SELECT
        source_file_name,
        source_url,
        loaded_at,

        TRIM(area_fips) AS county_fips,
        LEFT(TRIM(area_fips), 2) AS state_fips,

        TRIM(own_code) AS own_code,
        REPLACE(TRIM(industry_code), '-', '_') AS qcew_industry_code,
        TRIM(agglvl_code) AS agglvl_code,
        TRIM(size_code) AS size_code,

        year,
        qtr AS quarter,
        year * 4 + qtr AS period_id,

        area_title,
        industry_title,

        qtrly_estabs,
        month1_emplvl,
        month2_emplvl,
        month3_emplvl,

        ROUND(
            (COALESCE(month1_emplvl, 0)
           + COALESCE(month2_emplvl, 0)
           + COALESCE(month3_emplvl, 0)) / 3.0,
            2
        ) AS avg_monthly_employment,

        total_qtrly_wages,
        taxable_qtrly_wages,
        qtrly_contributions,
        avg_wkly_wage,

        oty_qtrly_estabs_chg,
        oty_qtrly_estabs_pct_chg,
        oty_month1_emplvl_chg,
        oty_month1_emplvl_pct_chg,
        oty_month2_emplvl_chg,
        oty_month2_emplvl_pct_chg,
        oty_month3_emplvl_chg,
        oty_month3_emplvl_pct_chg,
        oty_total_qtrly_wages_chg,
        oty_total_qtrly_wages_pct_chg,
        oty_avg_wkly_wage_chg,
        oty_avg_wkly_wage_pct_chg

    FROM RAW.QCEW_COUNTY_INDUSTRY_QTR_RAW
    WHERE own_code = '5'
      AND size_code = '0'
      AND qtr BETWEEN 1 AND 4
      AND REGEXP_LIKE(TRIM(area_fips), '^[0-9]{5}$')
      AND RIGHT(TRIM(area_fips), 3) <> '000'
)

SELECT
    c.source_file_name,
    c.source_url,
    c.loaded_at,

    c.county_fips,
    c.state_fips,
    st.state_abbr,
    st.state_name,

    c.own_code,
    c.qcew_industry_code,
    c.agglvl_code,
    c.size_code,

    c.year,
    c.quarter,
    c.period_id,

    c.area_title,
    c.industry_title,

    s.sector_code,
    s.sector_name,
    s.is_core_target,

    c.qtrly_estabs,
    c.month1_emplvl,
    c.month2_emplvl,
    c.month3_emplvl,
    c.avg_monthly_employment,

    c.total_qtrly_wages,
    c.taxable_qtrly_wages,
    c.qtrly_contributions,
    c.avg_wkly_wage,

    c.oty_qtrly_estabs_chg,
    c.oty_qtrly_estabs_pct_chg,
    c.oty_month1_emplvl_chg,
    c.oty_month1_emplvl_pct_chg,
    c.oty_month2_emplvl_chg,
    c.oty_month2_emplvl_pct_chg,
    c.oty_month3_emplvl_chg,
    c.oty_month3_emplvl_pct_chg,
    c.oty_total_qtrly_wages_chg,
    c.oty_total_qtrly_wages_pct_chg,
    c.oty_avg_wkly_wage_chg,
    c.oty_avg_wkly_wage_pct_chg

FROM cleaned c
LEFT JOIN REF.NAICS_SECTOR s
    ON c.qcew_industry_code = s.qcew_industry_code
LEFT JOIN REF.US_STATE st
    ON c.state_fips = st.state_fips;