# QCEW Growth EDA Findings

## Scope

This EDA reviews QCEW county-industry-quarter data before building the intermediate growth model.

Latest period reviewed: `2025 Q3`.

## Key checks

| Area | Result | Follow-up |
|---|---:|---|
| Staging rows | 16,587 | Confirm expected based on downloaded years, quarters, sectors, and counties. |
| Raw rows | 16,587 | Confirm load process did not duplicate or truncate data. |
| Duplicate grain rows | 0 | Should become a DQ failure if nonzero. |
| Latest-period industries | 6 | Compare against configured target sectors. |
| Extreme source YoY establishment growth share | 0.0010 | Investigate small-denominator sensitivity. |

## Modeling decisions to finalize

1. Whether to use QCEW source-provided YoY percent changes, computed YoY percent changes, or both.
2. Whether primary rankings should require a minimum establishment threshold.
3. Whether score confidence should be shown in the dashboard.
4. Whether QoQ growth is stable enough to include in the ongoing growth score.
5. Whether current growth scores show enough signal for an expected-growth proxy.

## Candidate production outputs

- `sql/03_intermediate/01_int_qcew_county_industry_growth_qtr.sql`
- `sql/03_intermediate/02_int_qcew_ongoing_growth_score.sql`
- `sql/05_dq/01_qcew_staging_profile_checks.sql`
