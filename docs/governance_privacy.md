# Governance and Privacy — SMB Lending & Market Opportunity Intelligence

## Purpose

This document defines the governance, privacy, and responsible-use expectations for the SMB Lending & Market Opportunity Intelligence Dashboard.

## Scope

Project scope:

```text
National U.S. county-industry-quarter market opportunity analysis
```

Primary analytical grain:

```text
state_fips × county_fips × qcew_industry_code × year × quarter
```

Primary Tableau-facing mart:

```text
MART.COUNTY_INDUSTRY_OPPORTUNITY_QTR
```

## Data classification

| Data area | Source | Classification | Notes |
|---|---|---|---|
| QCEW county-industry-quarter data | BLS | Public, aggregated | No borrower/person-level records. |
| SBA 7(a) FOIA data | SBA | Public, loan-level | Can include borrower/lender names and business geography. |
| Census Gazetteer | Census Bureau | Public reference | Used for county FIPS mapping. |
| NAICS sector reference | Project-maintained | Public/reference | Static lookup. |
| U.S. state reference | Project-maintained | Public/reference | Static lookup. |
| Final opportunity mart | Project-derived | Aggregated analytical output | Intended dashboard data source. |

## Privacy posture

The project uses public data, but public does not mean unrestricted for every presentation context.

The SBA FOIA source may include borrower-level business names and borrower geography. Although this information is public, the dashboard should avoid exposing borrower-level records because the product objective is market prioritization, not individual borrower profiling.

## Recommended exposure policy

### Safe for dashboarding

These fields are safe for Tableau-facing views:

```text
state_fips
state_abbr
state_name
county_fips
qcew_industry_code
sector_code
sector_name
year
quarter
period_id
qtrly_estabs
avg_monthly_employment
total_qtrly_wages
avg_wkly_wage
QCEW growth metrics
SBA aggregate loan counts and amounts
active_lender_count
top_lender_name
top_lender share metrics
lender concentration metrics
opportunity scores and tiers
recommendation text
```

### Not recommended for dashboarding

Do not publish borrower-level records in the public portfolio dashboard:

```text
borrower_name
loan_name
borrower street-level address, if present in future data
raw borrower-level loan records
```

### Acceptable restricted use

Borrower-level fields may be retained in RAW/STG layers for reproducibility, auditability, and source reconciliation, but they should not be the focus of the dashboard or stakeholder memo.

## Data retention

Recommended local/Git policy:

- Do not commit raw or processed CSV files.
- Do not commit Snowflake credentials, `.env` files, or downloaded source files.
- Commit only scripts, SQL, notebooks, documentation, and small non-sensitive screenshots.

Recommended `.gitignore` entries:

```text
data/raw/
data/processed/
*.csv
*.csv.gz
.env
.venv/
__pycache__/
.ipynb_checkpoints/
```

## Access control

Recommended Snowflake role model for a real deployment:

| Role | Access |
|---|---|
| Admin/Engineer | Full RAW/STG/INT/MART/REF/DQ/OPS access. |
| Analyst | Read access to STG, INT, MART, REF, DQ. |
| Dashboard Consumer | Read access to MART and selected DQ views only. |
| Public Portfolio Viewer | Tableau screenshots or published dashboard using aggregated mart only. |

Current development setup uses `ACCOUNTADMIN` for simplicity. A production deployment should use least-privilege roles instead.

## Data quality governance

DQ checks should cover:

- Required key nulls.
- Grain uniqueness.
- Score ranges from 0 to 100.
- Negative-value sanity checks.
- Geography mapping coverage.
- Sector mapping coverage.
- QCEW/SBA join compatibility.
- Latest period/source freshness.
- Mart row count versus QCEW score base.

DQ checks live under:

```text
sql/05_dq/
```

Status views should be reviewed before dashboard publication.

## Metric governance

The final opportunity score is versioned using:

```text
scoring_version
scored_at
```

Current scoring version:

```text
opportunity_score_v1
```

Any material change to score logic should result in a new scoring version, for example:

```text
opportunity_score_v2
```

Material changes include:

- Changing score weights.
- Adding a new data source.
- Changing target sectors.
- Changing lending penetration calculations.
- Replacing heuristic scores with a trained model.

## Responsible-use notes

The dashboard should not be used as the sole basis for lending, credit, underwriting, hiring, or individual business targeting decisions.

The product is appropriate for:

- Market prioritization.
- Internal research.
- Portfolio demonstration.
- Dashboarding and analytics workflow demonstration.
- Identifying candidates for deeper qualitative review.

The product is not appropriate for:

- Individual borrower profiling.
- Credit eligibility decisions.
- Claims about actual BI demand without additional supporting data.
- Claims of causal impact from SBA lending to local growth.

## Source attribution

Project documentation and dashboard footnotes should identify the source families:

- U.S. Bureau of Labor Statistics QCEW.
- U.S. Small Business Administration 7(a) FOIA data.
- U.S. Census Bureau Gazetteer/reference geography.
- Project-maintained NAICS/state reference tables.

## Publication checklist

Before publishing a dashboard screenshot, portfolio page, or Tableau workbook:

- Confirm that dashboard data comes from the aggregated mart.
- Confirm borrower-level names are not displayed.
- Confirm no credentials or local file paths are visible.
- Confirm latest DQ status has no unresolved critical failures.
- Confirm metric dictionary and source inventory are updated.
- Confirm scoring version is visible or documented.
- Confirm README does not claim a real external client if none existed.

## Known governance limitations

- Public source updates may lag current market conditions.
- QCEW sector-level data does not isolate firm size directly.
- SBA 7(a) does not represent the full SMB credit market.
- County FIPS matching can be imperfect when source county names are missing, inconsistent, or ambiguous.
- The dashboard should be treated as a prioritization aid, not an automated decision system.
