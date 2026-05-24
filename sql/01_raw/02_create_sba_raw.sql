USE ROLE ACCOUNTADMIN;
USE WAREHOUSE COMPUTE_WH;
USE DATABASE SMB_MARKET_INTELLIGENCE_DEV;

CREATE TABLE IF NOT EXISTS RAW.SBA_7A_LOANS_RAW (
    source_file_name             STRING,
    loaded_at                    TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),

    program                      STRING,
    loan_name                    STRING,
    borrower_name                STRING,
    borrower_city                STRING,
    borrower_state               STRING,
    borrower_zip                 STRING,
    borrower_county              STRING,

    naics_code                   STRING,
    naics_description            STRING,

    approval_date                DATE,
    fiscal_year                  NUMBER,
    gross_approval_amount        NUMBER(18,2),
    initial_approval_amount      NUMBER(18,2),
    current_approval_amount      NUMBER(18,2),

    lender_name                  STRING,
    lender_city                  STRING,
    lender_state                 STRING,

    jobs_supported               NUMBER,
    project_county               STRING,
    project_state                STRING
);
