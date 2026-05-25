# Tableau Dashboard Spec — SMB Market Intelligence

## Dashboard name

```text
SMB Lending & Market Opportunity Intelligence Dashboard
```

## Primary data source

Snowflake table:

```text
SMB_MARKET_INTELLIGENCE_DEV.MART.COUNTY_INDUSTRY_OPPORTUNITY_QTR
```

Recommended Tableau data source name:

```text
mart_county_industry_opportunity_qtr
```

## Dashboard purpose

Help stakeholders identify and explain high-potential SMB market expansion opportunities by county, industry, and quarter.

The dashboard should answer:

- Where are the top opportunity markets?
- Which sectors and geographies drive those rankings?
- Are high rankings driven by growth, low lending penetration, lender fragmentation, or a mix?
- Which lenders dominate SBA activity in a market?
- Is the data fresh and passing quality checks?

## Recommended workbook structure

Create four dashboard pages:

```text
1. Executive Overview
2. County-Industry Explorer
3. Lending & Competition
4. Monitoring & Governance
```

## Global filters

Use these across relevant pages:

| Filter | Source field | Recommended type |
|---|---|---|
| Year | `year` | Single/multi-select |
| Quarter | `quarter` | Single/multi-select |
| Period | `period_id` | Single-select, latest default |
| State | `state_abbr` / `state_name` | Multi-select |
| County | `county_fips` | Multi-select |
| Sector | `sector_name` | Multi-select |
| Opportunity tier | `opportunity_tier` | Multi-select |
| Scoring version | `scoring_version` | Single-select |

If Tableau performance is slow, default to the latest period and expose historical period selection only on detail pages.

## Recommended calculated fields

### Latest period flag

```text
[period_id] = { FIXED : MAX([period_id]) }
```

Name:

```text
Is Latest Period
```

### State-county display

```text
[state_abbr] + ' - ' + [county_fips]
```

Name:

```text
County Display
```

Replace this later with county name once a county reference table is added.

### Sector display

```text
[qcew_industry_code] + ' - ' + [sector_name]
```

Name:

```text
Sector Display
```

### SBA activity status

```text
IF ZN([sba_loan_count]) = 0 THEN 'No SBA activity'
ELSE 'SBA activity present'
END
```

Name:

```text
SBA Activity Status
```

### Opportunity rank

Use Tableau table calculation:

```text
RANK_DENSE(SUM([final_opportunity_score]), 'desc')
```

Name:

```text
Opportunity Rank
```

Compute using county-sector rows in the table view.

### High opportunity flag

```text
IF [opportunity_tier] = 'Very High' OR [opportunity_tier] = 'High' THEN 'High priority'
ELSE 'Lower priority'
END
```

Name:

```text
High Opportunity Flag
```

### Lending penetration label

```text
STR(ROUND([sba_loans_per_100_establishments], 2)) + ' loans per 100 establishments'
```

Name:

```text
Lending Penetration Label
```

## Page 1: Executive Overview

### Objective

Give a quick national view of where the strongest opportunities are in the latest period.

### Recommended layout

Top row KPI cards:

1. Latest period.
2. Number of states represented.
3. Number of counties represented.
4. Number of Very High / High markets.
5. Average final opportunity score.
6. Latest SBA approval date.

Middle row:

- National map colored by average or max final opportunity score.
- Top 10 county-industry opportunities table.

Bottom row:

- Opportunity tier distribution.
- Top sectors by average final opportunity score.

### Sheets

#### KPI: Latest period

- Text: `MAX(period_id)`.
- Filter: `Is Latest Period = True` if using latest-only view.

#### KPI: Markets represented

- Count distinct: `county_fips`.
- Count distinct: `state_fips`.

#### KPI: High opportunity markets

- Count rows where `opportunity_tier IN ('Very High', 'High')`.

#### Map: National opportunity map

Options:

- If Tableau recognizes `county_fips`, use county geography.
- If not, use state-level aggregation first.

Recommended mark:

- Geometry/geography: county or state.
- Color: `AVG(final_opportunity_score)` or `MAX(final_opportunity_score)`.
- Tooltip: state, county FIPS, sector, final score, tier, top lender, loan count.

#### Table: Top 10 opportunities

Columns:

```text
state_abbr
county_fips
sector_name
qtrly_estabs
ongoing_growth_score
expected_growth_score
underserved_score
lender_fragmentation_score
final_opportunity_score
opportunity_tier
recommendation
```

Sort descending by `final_opportunity_score`.

## Page 2: County-Industry Explorer

### Objective

Allow detailed drilldown by geography, industry, and quarter.

### Recommended layout

Left sidebar filters:

```text
state
county
sector
period
opportunity tier
```

Main area:

- Ranked county-industry table.
- Score component bar chart.
- Trend line for selected county-sector over time.

### Sheets

#### Ranked market table

Columns:

```text
state_abbr
county_fips
sector_name
year
quarter
qtrly_estabs
avg_monthly_employment
estabs_qoq_pct_chg
oty_qtrly_estabs_pct_chg
ongoing_growth_score
expected_growth_score
underserved_score
final_opportunity_score
opportunity_tier
```

#### Score component chart

Rows:

```text
ongoing_growth_score
expected_growth_score
underserved_score
lender_fragmentation_score
```

Columns:

```text
score value
```

Use selected county-sector row or top N markets.

#### Trend line

X-axis:

```text
period_id
```

Y-axis options:

```text
final_opportunity_score
ongoing_growth_score
expected_growth_score
sba_loans_per_100_establishments
```

Color:

```text
sector_name
```

## Page 3: Lending & Competition

### Objective

Explain whether a market is underserved, lender-dominated, or fragmented.

### Recommended layout

Top KPI cards:

```text
SBA loan count
SBA gross approval amount
SBA loans per 100 establishments
SBA dollars per establishment
Active lender count
Top lender share by amount
Lender HHI by amount
```

Main charts:

- Scatter plot: growth score versus lending penetration.
- Table of top lenders/markets.
- Lender concentration distribution.

### Sheets

#### Scatter: Growth versus lending penetration

X-axis:

```text
sba_loans_per_100_establishments
```

Y-axis:

```text
expected_growth_score
```

Size:

```text
qtrly_estabs
```

Color:

```text
opportunity_tier
```

Tooltip:

```text
state_abbr
county_fips
sector_name
final_opportunity_score
underserved_score
sba_loan_count
sba_gross_approval_amount
top_lender_name
lender_concentration_tier
```

#### Table: Lender concentration detail

Columns:

```text
state_abbr
county_fips
sector_name
sba_loan_count
sba_gross_approval_amount
active_lender_count
top_lender_name
top_lender_share_by_count
top_lender_share_by_amount
lender_hhi_by_amount
lender_concentration_tier
```

Sort descending by `final_opportunity_score`, then `sba_gross_approval_amount`.

#### Chart: Concentration tiers

Rows:

```text
lender_concentration_tier
```

Columns:

```text
COUNTD(county_fips + qcew_industry_code + STR(year) + STR(quarter))
```

Color:

```text
lender_concentration_tier
```

## Page 4: Monitoring & Governance

### Objective

Show whether the dashboard is safe to use and whether sources are fresh enough for the current analysis.

### Primary data options

Option A: Use the mart only.

Option B: Add a second Tableau data source from:

```text
DQ.VW_DQ_CURRENT_STATUS
```

Option B is preferred if your DQ SQL views are installed.

### Recommended layout

Top row:

- Latest QCEW period.
- Latest SBA approval date.
- Mart row count.
- Score version.
- Last scored timestamp.

Middle row:

- DQ status summary by object.
- Failing/warning checks table.

Bottom row:

- Notes on data limitations.
- Score version and source attribution.

### Mart-only monitoring fields

Use these if not connecting to DQ views:

```text
MAX(period_id)
MAX(latest_approval_date)
COUNT(*)
COUNTD(state_fips)
COUNTD(county_fips)
COUNTD(qcew_industry_code)
MAX(scored_at)
ATTR(scoring_version)
```

### DQ view fields

If using `DQ.VW_DQ_CURRENT_STATUS`, display:

```text
check_group
check_name
severity
object_name
status
observed_value
expected_value
details
```

## Tooltip standards

Every major mark should include:

```text
State
County FIPS
Sector
Period
Final opportunity score
Opportunity tier
Ongoing growth score
Expected growth score
Underserved score
SBA loan count
SBA gross approval amount
Top lender name
Recommendation
```

## Formatting standards

Recommended number formats:

| Field | Format |
|---|---|
| Score fields | Number, 1–2 decimals |
| Amount fields | Currency, no decimals for large numbers |
| Share fields | Percentage, 1 decimal |
| HHI fields | Decimal, 3 decimals |
| Establishments/employment | Whole number |
| Dates | `YYYY-MM-DD` |

## Dashboard annotations

Add a small footer or info note:

```text
Sources: BLS QCEW, SBA 7(a) FOIA, Census Gazetteer, project reference tables. Scores are heuristic v1 market prioritization indices, not forecasts or credit decisions.
```

## Recommended Tableau build order

1. Connect to Snowflake.
2. Select `SMB_MARKET_INTELLIGENCE_DEV.MART.COUNTY_INDUSTRY_OPPORTUNITY_QTR`.
3. Create calculated fields.
4. Build Executive Overview sheets first.
5. Build County-Industry Explorer.
6. Build Lending & Competition.
7. Add Monitoring & Governance page.
8. Apply global filters.
9. Validate top 25 rows against Snowflake SQL query.
10. Export screenshots and update `README.md`.

## Validation against Snowflake

After building the top opportunities table, compare with this query:

```sql
SELECT
    state_abbr,
    county_fips,
    sector_name,
    year,
    quarter,
    final_opportunity_score,
    opportunity_tier,
    recommendation
FROM SMB_MARKET_INTELLIGENCE_DEV.MART.COUNTY_INDUSTRY_OPPORTUNITY_QTR
WHERE period_id = (
    SELECT MAX(period_id)
    FROM SMB_MARKET_INTELLIGENCE_DEV.MART.COUNTY_INDUSTRY_OPPORTUNITY_QTR
)
ORDER BY final_opportunity_score DESC
LIMIT 25;
```

The Tableau top-ranked table should match the same ordering after filters are aligned.

## Portfolio presentation guidance

For the public project README or portfolio page, include:

- One executive dashboard screenshot.
- One county-industry explorer screenshot.
- One short paragraph explaining the business problem.
- One short paragraph explaining the data model.
- One short paragraph explaining the score interpretation and limitations.
- Link to key SQL, Python, and documentation files.

Do not include borrower-level records or raw data files in screenshots.
