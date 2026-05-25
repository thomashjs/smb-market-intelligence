USE WAREHOUSE COMPUTE_WH;
USE DATABASE SMB_MARKET_INTELLIGENCE_DEV;
USE SCHEMA RAW;

CREATE OR REPLACE TABLE RAW.QCEW_COUNTY_INDUSTRY_QTR_RAW (
    source_file_name VARCHAR,
    source_url VARCHAR,
    loaded_at TIMESTAMP_NTZ,

    area_fips VARCHAR,
    own_code VARCHAR,
    industry_code VARCHAR,
    agglvl_code VARCHAR,
    size_code VARCHAR,

    year NUMBER(4, 0),
    qtr NUMBER(1, 0),

    disclosure_code VARCHAR,
    area_title VARCHAR,
    own_title VARCHAR,
    industry_title VARCHAR,
    agglvl_title VARCHAR,
    size_title VARCHAR,

    qtrly_estabs NUMBER(18, 0),
    month1_emplvl NUMBER(18, 0),
    month2_emplvl NUMBER(18, 0),
    month3_emplvl NUMBER(18, 0),

    total_qtrly_wages NUMBER(18, 0),
    taxable_qtrly_wages NUMBER(18, 0),
    qtrly_contributions NUMBER(18, 0),
    avg_wkly_wage NUMBER(18, 0),

    lq_disclosure_code VARCHAR,
    lq_qtrly_estabs FLOAT,
    lq_month1_emplvl FLOAT,
    lq_month2_emplvl FLOAT,
    lq_month3_emplvl FLOAT,
    lq_total_qtrly_wages FLOAT,
    lq_taxable_qtrly_wages FLOAT,
    lq_qtrly_contributions FLOAT,
    lq_avg_wkly_wage FLOAT,

    oty_disclosure_code VARCHAR,
    oty_qtrly_estabs_chg NUMBER(18, 0),
    oty_qtrly_estabs_pct_chg FLOAT,
    oty_month1_emplvl_chg NUMBER(18, 0),
    oty_month1_emplvl_pct_chg FLOAT,
    oty_month2_emplvl_chg NUMBER(18, 0),
    oty_month2_emplvl_pct_chg FLOAT,
    oty_month3_emplvl_chg NUMBER(18, 0),
    oty_month3_emplvl_pct_chg FLOAT,
    oty_total_qtrly_wages_chg NUMBER(18, 0),
    oty_total_qtrly_wages_pct_chg FLOAT,
    oty_taxable_qtrly_wages_chg NUMBER(18, 0),
    oty_taxable_qtrly_wages_pct_chg FLOAT,
    oty_qtrly_contributions_chg NUMBER(18, 0),
    oty_qtrly_contributions_pct_chg FLOAT,
    oty_avg_wkly_wage_chg NUMBER(18, 0),
    oty_avg_wkly_wage_pct_chg FLOAT
);
