USE ROLE ACCOUNTADMIN;
USE WAREHOUSE COMPUTE_WH;

CREATE DATABASE IF NOT EXISTS SMB_MARKET_INTELLIGENCE_DEV
  COMMENT = 'Development database for SMB market opportunity analytics';

USE DATABASE SMB_MARKET_INTELLIGENCE_DEV;

CREATE SCHEMA IF NOT EXISTS RAW
  COMMENT = 'Raw source-aligned data loaded from public datasets';

CREATE SCHEMA IF NOT EXISTS STG
  COMMENT = 'Cleaned and typed staging views';

CREATE SCHEMA IF NOT EXISTS INT
  COMMENT = 'Intermediate analytical models';

CREATE SCHEMA IF NOT EXISTS MART
  COMMENT = 'Dashboard-ready analytics marts';

CREATE SCHEMA IF NOT EXISTS DQ
  COMMENT = 'Data quality, reconciliation, and freshness checks';

CREATE SCHEMA IF NOT EXISTS REF
  COMMENT = 'Reference tables such as NAICS sectors and geography';

CREATE SCHEMA IF NOT EXISTS OPS
  COMMENT = 'Pipeline run logs and operational metadata';
