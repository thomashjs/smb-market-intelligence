USE WAREHOUSE COMPUTE_WH;
USE DATABASE SMB_MARKET_INTELLIGENCE_DEV;
USE SCHEMA RAW;

TRUNCATE TABLE RAW.QCEW_COUNTY_INDUSTRY_QTR_RAW;

COPY INTO RAW.QCEW_COUNTY_INDUSTRY_QTR_RAW (
    source_file_name,
    source_url,
    loaded_at,
    area_fips,
    own_code,
    industry_code,
    agglvl_code,
    size_code,
    year,
    qtr,
    disclosure_code,
    area_title,
    own_title,
    industry_title,
    agglvl_title,
    size_title,
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
FROM (
    SELECT
        $1::VARCHAR,
        $2::VARCHAR,
        TRY_TO_TIMESTAMP_NTZ($3),

        $4::VARCHAR,
        $5::VARCHAR,
        $6::VARCHAR,
        $7::VARCHAR,
        $8::VARCHAR,

        TRY_TO_NUMBER($9),
        TRY_TO_NUMBER($10),

        $11::VARCHAR,
        $12::VARCHAR,
        $13::VARCHAR,
        $14::VARCHAR,
        $15::VARCHAR,
        $16::VARCHAR,

        TRY_TO_NUMBER($17),
        TRY_TO_NUMBER($18),
        TRY_TO_NUMBER($19),
        TRY_TO_NUMBER($20),

        TRY_TO_NUMBER($21),
        TRY_TO_NUMBER($22),
        TRY_TO_NUMBER($23),
        TRY_TO_NUMBER($24),

        $25::VARCHAR,
        TRY_TO_DOUBLE($26),
        TRY_TO_DOUBLE($27),
        TRY_TO_DOUBLE($28),
        TRY_TO_DOUBLE($29),
        TRY_TO_DOUBLE($30),
        TRY_TO_DOUBLE($31),
        TRY_TO_DOUBLE($32),
        TRY_TO_DOUBLE($33),

        $34::VARCHAR,
        TRY_TO_NUMBER($35),
        TRY_TO_DOUBLE($36),
        TRY_TO_NUMBER($37),
        TRY_TO_DOUBLE($38),
        TRY_TO_NUMBER($39),
        TRY_TO_DOUBLE($40),
        TRY_TO_NUMBER($41),
        TRY_TO_DOUBLE($42),
        TRY_TO_NUMBER($43),
        TRY_TO_DOUBLE($44),
        TRY_TO_NUMBER($45),
        TRY_TO_DOUBLE($46),
        TRY_TO_NUMBER($47),
        TRY_TO_DOUBLE($48),
        TRY_TO_NUMBER($49),
        TRY_TO_DOUBLE($50)
    FROM @RAW.LOAD_STAGE/qcew
)
FILE_FORMAT = (FORMAT_NAME = RAW.CSV_HEADER_FORMAT)
PATTERN = '.*qcew_county_industry_qtr_us_v1.*[.]csv([.]gz)?'
ON_ERROR = ABORT_STATEMENT;
