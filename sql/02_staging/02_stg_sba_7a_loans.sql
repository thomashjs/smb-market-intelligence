USE WAREHOUSE COMPUTE_WH;
USE DATABASE SMB_MARKET_INTELLIGENCE_DEV;
USE SCHEMA STG;

CREATE OR REPLACE VIEW STG.STG_SBA_7A_LOANS AS
WITH raw_normalized AS (
    SELECT
        source_file_name,
        loaded_at,

        NULLIF(TRIM(program), '') AS program,
        NULLIF(TRIM(loan_name), '') AS loan_name,
        NULLIF(TRIM(borrower_name), '') AS borrower_name,
        NULLIF(TRIM(borrower_city), '') AS borrower_city,
        NULLIF(UPPER(TRIM(borrower_state)), '') AS borrower_state,
        NULLIF(TRIM(borrower_zip), '') AS borrower_zip,
        NULLIF(TRIM(borrower_county), '') AS borrower_county,

        NULLIF(TRIM(project_county), '') AS project_county,
        NULLIF(UPPER(TRIM(project_state)), '') AS project_state,
        NULLIF(TRIM(project_county_clean), '') AS project_county_clean,

        NULLIF(TRIM(state_fips), '') AS raw_state_fips,
        NULLIF(TRIM(county_fips), '') AS county_fips,

        NULLIF(TRIM(naics_code), '') AS naics_code,
        NULLIF(TRIM(naics_description), '') AS naics_description,

        CASE
            WHEN NULLIF(TRIM(qcew_industry_code), '') IS NOT NULL
                THEN NULLIF(TRIM(qcew_industry_code), '')
            WHEN LEFT(REGEXP_REPLACE(naics_code, '[^0-9]', ''), 2) IN ('44', '45')
                THEN '44_45'
            ELSE NULLIF(LEFT(REGEXP_REPLACE(naics_code, '[^0-9]', ''), 2), '')
        END AS qcew_industry_code,

        approval_date,
        fiscal_year,

        gross_approval_amount,
        initial_approval_amount,
        current_approval_amount,

        NULLIF(TRIM(lender_name), '') AS lender_name,
        NULLIF(TRIM(lender_city), '') AS lender_city,
        NULLIF(UPPER(TRIM(lender_state)), '') AS lender_state,

        jobs_supported

    FROM RAW.SBA_7A_LOANS_RAW
),

state_resolved AS (
    SELECT
        r.*,

        COALESCE(
            r.raw_state_fips,
            LEFT(r.county_fips, 2),
            state_from_project.state_fips,
            state_from_borrower.state_fips
        ) AS state_fips

    FROM raw_normalized r

    LEFT JOIN REF.US_STATE state_from_project
        ON r.project_state = state_from_project.state_abbr
        OR r.project_state = UPPER(state_from_project.state_name)

    LEFT JOIN REF.US_STATE state_from_borrower
        ON r.borrower_state = state_from_borrower.state_abbr
        OR r.borrower_state = UPPER(state_from_borrower.state_name)
),

enriched AS (
    SELECT
        r.source_file_name,
        r.loaded_at,

        r.program,
        r.loan_name,
        r.borrower_name,
        r.borrower_city,
        r.borrower_state,
        r.borrower_zip,
        r.borrower_county,

        r.project_county,
        r.project_state,
        r.project_county_clean,

        r.state_fips,
        us.state_abbr,
        us.state_name,
        r.county_fips,

        r.naics_code,
        r.naics_description,
        r.qcew_industry_code,

        ns.sector_code,
        ns.sector_name,
        ns.is_core_target,

        r.approval_date,
        YEAR(r.approval_date) AS year,
        QUARTER(r.approval_date) AS quarter,
        YEAR(r.approval_date) * 4 + QUARTER(r.approval_date) AS period_id,
        r.fiscal_year,

        r.gross_approval_amount,
        r.initial_approval_amount,
        r.current_approval_amount,

        r.lender_name,
        r.lender_city,
        r.lender_state,

        r.jobs_supported

    FROM state_resolved r

    LEFT JOIN REF.US_STATE us
        ON r.state_fips = us.state_fips

    LEFT JOIN REF.NAICS_SECTOR ns
        ON r.qcew_industry_code = ns.qcew_industry_code
)

SELECT
    source_file_name,
    loaded_at,

    program,
    loan_name,
    borrower_name,
    borrower_city,
    borrower_state,
    borrower_zip,
    borrower_county,

    project_county,
    project_state,
    project_county_clean,

    state_fips,
    state_abbr,
    state_name,
    county_fips,

    naics_code,
    naics_description,
    qcew_industry_code,
    sector_code,
    sector_name,
    is_core_target,

    approval_date,
    year,
    quarter,
    period_id,
    fiscal_year,

    gross_approval_amount,
    initial_approval_amount,
    current_approval_amount,

    lender_name,
    lender_city,
    lender_state,

    jobs_supported,

    CASE
        WHEN state_fips IS NULL OR state_fips = '' THEN FALSE
        ELSE TRUE
    END AS has_state_fips,

    CASE
        WHEN county_fips IS NULL OR county_fips = '' THEN FALSE
        ELSE TRUE
    END AS has_county_fips,

    CASE
        WHEN county_fips IS NOT NULL
             AND county_fips <> ''
             AND state_fips IS NOT NULL
             AND state_fips <> ''
             AND LEFT(county_fips, 2) = state_fips
            THEN TRUE
        ELSE FALSE
    END AS county_state_fips_match,

    CASE
        WHEN sector_code IS NULL THEN FALSE
        ELSE TRUE
    END AS has_sector_mapping

FROM enriched
WHERE approval_date IS NOT NULL;
