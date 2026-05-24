USE ROLE ACCOUNTADMIN;
USE WAREHOUSE COMPUTE_WH;
USE DATABASE SMB_MARKET_INTELLIGENCE_DEV;

TRUNCATE TABLE RAW.QCEW_COUNTY_INDUSTRY_QTR_RAW;

COPY INTO RAW.QCEW_COUNTY_INDUSTRY_QTR_RAW (
    source_file_name,
    source_url,
    area_fips,
    own_code,
    industry_code,
    agglvl_code,
    size_code,
    year,
    qtr,
    disclosure_code,
    qtrly_estabs,
    month1_emplvl,
    month2_emplvl,
    month3_emplvl,
    total_qtrly_wages,
    taxable_qtrly_wages,
    qtrly_contributions,
    avg_wkly_wage,
    lq_disclosure_code,
    lq_qtrly_estabs,
    lq_month1_emplvl,
    lq_month2_emplvl,
    lq_month3_emplvl,
    lq_total_qtrly_wages,
    lq_taxable_qtrly_wages,
    lq_qtrly_contributions,
    lq_avg_wkly_wage,
    oty_disclosure_code,
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
    oty_taxable_qtrly_wages_chg,
    oty_taxable_qtrly_wages_pct_chg,
    oty_qtrly_contributions_chg,
    oty_qtrly_contributions_pct_chg,
    oty_avg_wkly_wage_chg,
    oty_avg_wkly_wage_pct_chg
)
FROM @RAW.LOAD_STAGE/qcew
FILE_FORMAT = (FORMAT_NAME = RAW.CSV_HEADER_FORMAT)
PATTERN = '.*qcew_county_industry_qtr_tx_v1[.]csv([.]gz)?'
ON_ERROR = CONTINUE;
