USE ROLE ACCOUNTADMIN;
USE WAREHOUSE COMPUTE_WH;
USE DATABASE SMB_MARKET_INTELLIGENCE_DEV;

CREATE TABLE IF NOT EXISTS REF.NAICS_SECTOR (
    sector_code       STRING,
    sector_name       STRING,
    qcew_industry_code STRING,
    is_core_target    BOOLEAN
);

INSERT INTO REF.NAICS_SECTOR
SELECT * FROM VALUES
    ('11', 'Agriculture, Forestry, Fishing and Hunting', '11', FALSE),
    ('21', 'Mining, Quarrying, and Oil and Gas Extraction', '21', FALSE),
    ('22', 'Utilities', '22', FALSE),
    ('23', 'Construction', '23', TRUE),
    ('31-33', 'Manufacturing', '31_33', TRUE),
    ('42', 'Wholesale Trade', '42', TRUE),
    ('44-45', 'Retail Trade', '44_45', TRUE),
    ('48-49', 'Transportation and Warehousing', '48_49', TRUE),
    ('51', 'Information', '51', TRUE),
    ('52', 'Finance and Insurance', '52', TRUE),
    ('53', 'Real Estate and Rental and Leasing', '53', TRUE),
    ('54', 'Professional, Scientific, and Technical Services', '54', TRUE),
    ('55', 'Management of Companies and Enterprises', '55', TRUE),
    ('56', 'Administrative and Support and Waste Management', '56', TRUE),
    ('61', 'Educational Services', '61', TRUE),
    ('62', 'Health Care and Social Assistance', '62', TRUE),
    ('71', 'Arts, Entertainment, and Recreation', '71', TRUE),
    ('72', 'Accommodation and Food Services', '72', TRUE),
    ('81', 'Other Services', '81', TRUE)
AS t(sector_code, sector_name, qcew_industry_code, is_core_target);
