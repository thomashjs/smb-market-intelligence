USE WAREHOUSE COMPUTE_WH;
USE DATABASE SMB_MARKET_INTELLIGENCE_DEV;
USE SCHEMA RAW;

CREATE OR REPLACE FILE FORMAT RAW.SBA_CSV_HEADER_FORMAT
    TYPE = CSV
    SKIP_HEADER = 1
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    EMPTY_FIELD_AS_NULL = TRUE
    NULL_IF = ('', 'NULL', 'null')
    TRIM_SPACE = TRUE
    ERROR_ON_COLUMN_COUNT_MISMATCH = TRUE;

TRUNCATE TABLE RAW.SBA_7A_LOANS_RAW;

COPY INTO RAW.SBA_7A_LOANS_RAW (
    source_file_name,
    loaded_at,
    program,
    loan_name,
    borrower_name,
    borrower_city,
    borrower_state,
    borrower_zip,
    borrower_county,
    naics_code,
    naics_description,
    approval_date,
    fiscal_year,
    gross_approval_amount,
    initial_approval_amount,
    current_approval_amount,
    lender_name,
    lender_city,
    lender_state,
    jobs_supported,
    project_county,
    project_state,
    project_county_clean,
    state_fips,
    county_fips,
    qcew_industry_code
)
FROM (
    SELECT
        $1::VARCHAR,
        TRY_TO_TIMESTAMP_NTZ($2),
        $3::VARCHAR,
        $4::VARCHAR,
        $5::VARCHAR,
        $6::VARCHAR,
        $7::VARCHAR,
        $8::VARCHAR,
        $9::VARCHAR,
        $10::VARCHAR,
        $11::VARCHAR,
        TRY_TO_DATE($12),
        TRY_TO_NUMBER($13),
        TRY_TO_DECIMAL($14, 18, 2),
        TRY_TO_DECIMAL($15, 18, 2),
        TRY_TO_DECIMAL($16, 18, 2),
        $17::VARCHAR,
        $18::VARCHAR,
        $19::VARCHAR,
        TRY_TO_NUMBER($20),
        $21::VARCHAR,
        $22::VARCHAR,
        $23::VARCHAR,
        $24::VARCHAR,
        $25::VARCHAR,
        $26::VARCHAR
    FROM @RAW.LOAD_STAGE/sba
)
FILE_FORMAT = (FORMAT_NAME = RAW.SBA_CSV_HEADER_FORMAT)
PATTERN = '.*sba_7a_loans_us_v1.*[.]csv([.]gz)?'
ON_ERROR = ABORT_STATEMENT
FORCE = TRUE;