USE ROLE ACCOUNTADMIN;
USE WAREHOUSE COMPUTE_WH;
USE DATABASE SMB_MARKET_INTELLIGENCE_DEV;

CREATE TABLE IF NOT EXISTS OPS.PIPELINE_RUN_LOG (
    run_id              STRING,
    pipeline_name       STRING,
    source_name         STRING,
    started_at          TIMESTAMP_NTZ,
    finished_at         TIMESTAMP_NTZ,
    status              STRING,
    rows_processed      NUMBER,
    message             STRING
);

CREATE TABLE IF NOT EXISTS DQ.SOURCE_FRESHNESS_LOG (
    check_id             STRING,
    source_name          STRING,
    expected_frequency   STRING,
    latest_source_period STRING,
    latest_loaded_at     TIMESTAMP_NTZ,
    checked_at           TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    freshness_status     STRING,
    notes                STRING
);

CREATE TABLE IF NOT EXISTS DQ.DATA_QUALITY_RESULTS (
    check_id             STRING,
    run_id               STRING,
    check_name           STRING,
    table_name           STRING,
    check_status         STRING,
    failed_row_count     NUMBER,
    checked_at           TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    details              STRING
);
