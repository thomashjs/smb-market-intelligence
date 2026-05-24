USE ROLE ACCOUNTADMIN;
USE WAREHOUSE COMPUTE_WH;
USE DATABASE SMB_MARKET_INTELLIGENCE_DEV;

CREATE OR REPLACE VIEW STG.STG_QCEW_COUNTY_INDUSTRY_QTR AS
SELECT
    area_fips AS county_fips,
    industry_code AS qcew_industry_code,
    year,
    TRY_TO_NUMBER(qtr) AS quarter,

    qtrly_estabs,
    month1_emplvl,
    month2_emplvl,
    month3_emplvl,
    ROUND((month1_emplvl + month2_emplvl + month3_emplvl) / 3.0, 2) AS avg_monthly_employment,
    total_qtrly_wages,
    avg_wkly_wage,

    lq_qtrly_estabs,
    lq_total_qtrly_wages,

    oty_qtrly_estabs_chg,
    oty_qtrly_estabs_pct_chg,
    oty_total_qtrly_wages_chg,
    oty_total_qtrly_wages_pct_chg,

    source_file_name,
    source_url,
    loaded_at
FROM RAW.QCEW_COUNTY_INDUSTRY_QTR_RAW
WHERE own_code = '5'              -- private ownership
  AND size_code = '0'             -- all establishment sizes
  AND TRY_TO_NUMBER(qtr) BETWEEN 1 AND 4
  AND area_fips REGEXP '^[0-9]{5}$';
