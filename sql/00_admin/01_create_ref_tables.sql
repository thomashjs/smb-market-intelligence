USE ROLE ACCOUNTADMIN;
USE WAREHOUSE COMPUTE_WH;
USE DATABASE SMB_MARKET_INTELLIGENCE_DEV;

CREATE TABLE IF NOT EXISTS REF.NAICS_SECTOR (
    sector_code       STRING,
    sector_name       STRING,
    qcew_industry_code STRING,
    is_core_target    BOOLEAN
);

CREATE TABLE IF NOT EXISTS REF.US_STATE (
    state_fips STRING,
    state_abbr STRING,
    state_name STRING
);

CREATE TABLE IF NOT EXISTS REF.US_COUNTY (
    county_fips STRING,
    state_fips STRING,
    state_abbr STRING,
    county_name STRING,
    county_name_clean STRING
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

INSERT INTO REF.US_STATE (
    state_fips,
    state_abbr,
    state_name
)
VALUES
    ('01', 'AL', 'Alabama'),
    ('02', 'AK', 'Alaska'),
    ('04', 'AZ', 'Arizona'),
    ('05', 'AR', 'Arkansas'),
    ('06', 'CA', 'California'),
    ('08', 'CO', 'Colorado'),
    ('09', 'CT', 'Connecticut'),
    ('10', 'DE', 'Delaware'),
    ('11', 'DC', 'District of Columbia'),
    ('12', 'FL', 'Florida'),
    ('13', 'GA', 'Georgia'),
    ('15', 'HI', 'Hawaii'),
    ('16', 'ID', 'Idaho'),
    ('17', 'IL', 'Illinois'),
    ('18', 'IN', 'Indiana'),
    ('19', 'IA', 'Iowa'),
    ('20', 'KS', 'Kansas'),
    ('21', 'KY', 'Kentucky'),
    ('22', 'LA', 'Louisiana'),
    ('23', 'ME', 'Maine'),
    ('24', 'MD', 'Maryland'),
    ('25', 'MA', 'Massachusetts'),
    ('26', 'MI', 'Michigan'),
    ('27', 'MN', 'Minnesota'),
    ('28', 'MS', 'Mississippi'),
    ('29', 'MO', 'Missouri'),
    ('30', 'MT', 'Montana'),
    ('31', 'NE', 'Nebraska'),
    ('32', 'NV', 'Nevada'),
    ('33', 'NH', 'New Hampshire'),
    ('34', 'NJ', 'New Jersey'),
    ('35', 'NM', 'New Mexico'),
    ('36', 'NY', 'New York'),
    ('37', 'NC', 'North Carolina'),
    ('38', 'ND', 'North Dakota'),
    ('39', 'OH', 'Ohio'),
    ('40', 'OK', 'Oklahoma'),
    ('41', 'OR', 'Oregon'),
    ('42', 'PA', 'Pennsylvania'),
    ('44', 'RI', 'Rhode Island'),
    ('45', 'SC', 'South Carolina'),
    ('46', 'SD', 'South Dakota'),
    ('47', 'TN', 'Tennessee'),
    ('48', 'TX', 'Texas'),
    ('49', 'UT', 'Utah'),
    ('50', 'VT', 'Vermont'),
    ('51', 'VA', 'Virginia'),
    ('53', 'WA', 'Washington'),
    ('54', 'WV', 'West Virginia'),
    ('55', 'WI', 'Wisconsin'),
    ('56', 'WY', 'Wyoming'),
    ('60', 'AS', 'American Samoa'),
    ('66', 'GU', 'Guam'),
    ('69', 'MP', 'Northern Mariana Islands'),
    ('72', 'PR', 'Puerto Rico'),
    ('78', 'VI', 'U.S. Virgin Islands');