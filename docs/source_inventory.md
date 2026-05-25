# SMB Market Intelligence Source Inventory

## Project framing

Project:

```text
SMB Lending & Market Opportunity Intelligence Dashboard
```

Primary business question:

```text
Where are the strongest SMB market expansion opportunities by county, industry, and quarter?
```

Decision owner:

```text
Internal analytics consultancy / portfolio company concept
```

Current scope:

```text
National / all U.S. states
county_fips × qcew_industry_code × year × quarter
```

## Source summary

| Source | Provider | Current use | Refresh cadence | Current project status |
|---|---|---|---|---|
| QCEW county-industry-quarter data | U.S. Bureau of Labor Statistics | Local market growth proxy | Quarterly | Ingested, staged, scored nationally |
| SBA 7(a) FOIA data | U.S. Small Business Administration | SMB lending activity, lender presence, concentration | Periodic public release | Prepared, loaded, staged, aggregated nationally |
| Census county Gazetteer | U.S. Census Bureau | County/state FIPS mapping for SBA county names | Annual / periodic | Used inside `prepare_sba_7a.py` |
| NAICS sector reference | Project-maintained reference | Target sector metadata | Static unless target sectors change | Stored in `REF.NAICS_SECTOR` |
| U.S. state reference | Project-maintained reference | State FIPS/name/abbreviation mapping | Static unless territory scope changes | Stored in `REF.US_STATE` |

## Source 1: BLS QCEW

### Purpose

QCEW is used as the observed local-market growth proxy.

It supports:

```text
county-industry market size
establishment growth
employment growth
wage/payroll growth
quarterly trend features
growth scores
```

### Project scope

Current intended QCEW scope:

```text
National counties
Private ownership
Target sectors
Quarterly data
Recent years, currently 2023–2025 style vertical slice
```

### Raw/processed storage

Local paths:

```text
data/raw/qcew/
data/processed/qcew/qcew_county_industry_qtr_us_v1.csv
```

Snowflake objects:

```text
RAW.QCEW_COUNTY_INDUSTRY_QTR_RAW
STG.STG_QCEW_COUNTY_INDUSTRY_QTR
INT.INT_QCEW_COUNTY_INDUSTRY_GROWTH_QTR
INT.INT_QCEW_GROWTH_SCORES
```

### Main fields used

```text
state_fips
state_abbr
state_name
county_fips
qcew_industry_code
year
quarter
period_id
qtrly_estabs
avg_monthly_employment
total_qtrly_wages
avg_wkly_wage
oty_qtrly_estabs_pct_chg
oty_total_qtrly_wages_pct_chg
```

### Transformations

Current transformation flow:

```text
download_qcew.py
→ processed national CSV
→ RAW.QCEW_COUNTY_INDUSTRY_QTR_RAW
→ STG.STG_QCEW_COUNTY_INDUSTRY_QTR
→ INT.INT_QCEW_COUNTY_INDUSTRY_GROWTH_QTR
→ INT.INT_QCEW_GROWTH_SCORES
→ MART.COUNTY_INDUSTRY_OPPORTUNITY_QTR
```

Key transformations:

```text
filter to target sectors
standardize state/county/industry/period fields
type numeric measures
derive QoQ growth features
derive trailing four-quarter averages
derive percentile-based growth scores
```

### Data quality expectations

Expected checks:

```text
row count > 0
no null physical grain keys
unique county-industry-quarter grain
non-negative establishments/employment/wages
score fields bounded to [0, 100]
latest period has broad national coverage
latest period includes target sectors
```

### Known limitations

```text
QCEW measures employment and establishment activity, not BI demand directly.
Suppression or missingness may vary by county/industry.
Recent quarters may be revised by BLS.
Quarterly seasonality can affect interpretation.
```

## Source 2: SBA 7(a) FOIA

### Purpose

SBA 7(a) data is used as the SMB lending activity and lender competition proxy.

It supports:

```text
loan activity
approval amount
jobs supported
active lender count
top lender
top lender share
lender HHI
lender concentration tier
lending penetration relative to QCEW establishments
```

### Project scope

Current SBA scope:

```text
SBA 7(a) FY2020-present
National / all states
Target NAICS sectors: 23, 52, 54, 56, 62, 72
```

### Raw/processed storage

Local paths:

```text
data/raw/sba/sba_7a_fy2020_present.csv
data/processed/sba/sba_7a_loans_us_v1.csv
```

Snowflake objects:

```text
RAW.SBA_7A_LOANS_RAW
STG.STG_SBA_7A_LOANS
INT.INT_SBA_LENDING_COUNTY_INDUSTRY_QTR
```

### Prepared output columns

```text
source_file_name
loaded_at
program
loan_name
borrower_name
borrower_city
borrower_state
borrower_zip
borrower_county
naics_code
naics_description
approval_date
fiscal_year
gross_approval_amount
initial_approval_amount
current_approval_amount
lender_name
lender_city
lender_state
jobs_supported
project_county
project_state
project_county_clean
state_fips
county_fips
qcew_industry_code
```

### Transformations

Current transformation flow:

```text
download_sba_7a.py
→ prepare_sba_7a.py
→ data/processed/sba/sba_7a_loans_us_v1.csv
→ RAW.SBA_7A_LOANS_RAW
→ STG.STG_SBA_7A_LOANS
→ INT.INT_SBA_LENDING_COUNTY_INDUSTRY_QTR
→ MART.COUNTY_INDUSTRY_OPPORTUNITY_QTR
```

Key transformations in `prepare_sba_7a.py`:

```text
read raw SBA CSV in chunks
clean dates, amounts, and integer fields
derive qcew_industry_code from NAICS
filter target sectors
map project_state / borrower_state to state_fips
map project_county + state_fips to county_fips using Census Gazetteer
write 26-column Snowflake-loadable CSV
```

Key transformations in staging/intermediate SQL:

```text
normalize raw strings
join REF.US_STATE
join REF.NAICS_SECTOR
derive year, quarter, period_id
add geography and sector quality flags
aggregate loans to county-industry-quarter grain
calculate lender concentration metrics
```

### Data quality expectations

Expected checks:

```text
row count > 0
no null physical grain keys in aggregate
unique county-industry-quarter grain
non-negative loan counts and amounts
HHI fields bounded to [0, 1]
top lender share fields bounded to [0, 1]
broad national state coverage
target sector coverage
```

### Known limitations

```text
SBA 7(a) is not the full SMB lending market.
Borrower/project county fields can be messy and require standardization.
Loan geography may not perfectly represent business operating geography.
Latest available SBA public file may lag actual current lending activity.
Some lender names may require additional normalization in a later version.
```

## Reference source: Census county Gazetteer

### Purpose

Used in `prepare_sba_7a.py` to map:

```text
project_state + project_county_clean → county_fips
```

### Key logic

```text
standardize county names
match within state_fips
use exact/base county-name matching
return five-character county_fips
```

### Known limitations

```text
County-equivalent names can be inconsistent.
Independent cities, parishes, boroughs, and special county equivalents require careful cleaning.
Some SBA records may remain unmatched.
```

## Reference table: REF.NAICS_SECTOR

### Purpose

Maps target sector codes to stakeholder-friendly names.

Current target sectors:

| Sector code | Sector name |
|---|---|
| `23` | Construction |
| `52` | Finance and Insurance |
| `54` | Professional, Scientific, and Technical Services |
| `56` | Administrative and Support Services |
| `62` | Health Care and Social Assistance |
| `72` | Accommodation and Food Services |
| `44_45` | Retail Trade |

Current note:

```text
SBA prepare script currently defaults to 23, 52, 54, 56, 62, 72.
44_45 exists as an optional later expansion sector.
```

## Reference table: REF.US_STATE

### Purpose

Maps:

```text
state_fips ↔ state_abbr ↔ state_name
```

Used in:

```text
STG.STG_QCEW_COUNTY_INDUSTRY_QTR
STG.STG_SBA_7A_LOANS
INT models
MART model
Tableau filters
DQ coverage checks
```

## Refresh and monitoring plan

Recommended future refresh sequence:

```text
download latest QCEW/SBA sources
prepare processed CSVs
PUT files to @RAW.LOAD_STAGE
reload RAW tables
rebuild STG views
rebuild INT tables
rebuild MART.COUNTY_INDUSTRY_OPPORTUNITY_QTR
refresh DQ views
review DQ.VW_DQ_CURRENT_STATUS
refresh Tableau extract/dashboard
```

Recommended freshness checks:

```text
latest QCEW period_id
latest SBA approval_date
RAW/STG/INT/MART row counts
state/county coverage
sector coverage
SBA county FIPS match rate
SBA sector mapping rate
mart scoring_version and scored_at
```

## Governance notes

```text
All current data sources are public datasets.
No private customer data is used.
Do not commit large raw/processed CSV files.
Commit scripts, SQL, docs, notebooks, and small samples/screenshots only.
Treat scores as decision-support rankings, not definitive forecasts or credit decisions.
```
