USE ROLE ACCOUNTADMIN;
USE WAREHOUSE COMPUTE_WH;
USE DATABASE SMB_MARKET_INTELLIGENCE_DEV;

CREATE TABLE IF NOT EXISTS RAW.QCEW_COUNTY_INDUSTRY_QTR_RAW (
    source_file_name                 STRING,
    source_url                       STRING,
    loaded_at                        TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),

    area_fips                        STRING,
    own_code                         STRING,
    industry_code                    STRING,
    agglvl_code                      STRING,
    size_code                        STRING,
    year                             NUMBER,
    qtr                              STRING,
    disclosure_code                  STRING,

    qtrly_estabs                     NUMBER,
    month1_emplvl                    NUMBER,
    month2_emplvl                    NUMBER,
    month3_emplvl                    NUMBER,
    total_qtrly_wages                NUMBER(18,2),
    taxable_qtrly_wages              NUMBER(18,2),
    qtrly_contributions              NUMBER(18,2),
    avg_wkly_wage                    NUMBER(18,2),

    lq_disclosure_code               STRING,
    lq_qtrly_estabs                  FLOAT,
    lq_month1_emplvl                 FLOAT,
    lq_month2_emplvl                 FLOAT,
    lq_month3_emplvl                 FLOAT,
    lq_total_qtrly_wages             FLOAT,
    lq_taxable_qtrly_wages           FLOAT,
    lq_qtrly_contributions           FLOAT,
    lq_avg_wkly_wage                 FLOAT,

    oty_disclosure_code              STRING,
    oty_qtrly_estabs_chg             NUMBER,
    oty_qtrly_estabs_pct_chg         FLOAT,
    oty_month1_emplvl_chg            NUMBER,
    oty_month1_emplvl_pct_chg        FLOAT,
    oty_month2_emplvl_chg            NUMBER,
    oty_month2_emplvl_pct_chg        FLOAT,
    oty_month3_emplvl_chg            NUMBER,
    oty_month3_emplvl_pct_chg        FLOAT,
    oty_total_qtrly_wages_chg        NUMBER(18,2),
    oty_total_qtrly_wages_pct_chg    FLOAT,
    oty_taxable_qtrly_wages_chg      NUMBER(18,2),
    oty_taxable_qtrly_wages_pct_chg  FLOAT,
    oty_qtrly_contributions_chg      NUMBER(18,2),
    oty_qtrly_contributions_pct_chg  FLOAT,
    oty_avg_wkly_wage_chg            NUMBER(18,2),
    oty_avg_wkly_wage_pct_chg        FLOAT
);
