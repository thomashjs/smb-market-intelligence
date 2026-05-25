# SMB Market Intelligence Metric Dictionary

## Project grain

Primary analytical grain:

```text
state_fips × county_fips × qcew_industry_code × year × quarter
```

Final mart grain:

```text
scoring_version × state_fips × county_fips × qcew_industry_code × year × quarter
```

Final mart table:

```text
MART.COUNTY_INDUSTRY_OPPORTUNITY_QTR
```

## Dimension fields

| Field | Layer | Definition | Notes |
|---|---:|---|---|
| `state_fips` | All | Two-character state FIPS code. | Required national geography key. |
| `state_abbr` | All | USPS-style state abbreviation. | Joined from `REF.US_STATE`. |
| `state_name` | All | Full state name. | Joined from `REF.US_STATE`. |
| `county_fips` | All | Five-character county FIPS code. | Physical county key. First two digits should match `state_fips`. |
| `qcew_industry_code` | All | Target QCEW/NAICS sector code. | Current target set: `23`, `52`, `54`, `56`, `62`, `72`; `44_45` optional later. |
| `sector_code` | STG+ | Sector code from `REF.NAICS_SECTOR`. | May match `qcew_industry_code`. |
| `sector_name` | STG+ | Sector label from `REF.NAICS_SECTOR`. | Used in Tableau filters and labels. |
| `year` | All | Calendar year for QCEW quarter or SBA approval date quarter. | Numeric year. |
| `quarter` | All | Calendar quarter number. | Expected values: `1`, `2`, `3`, `4`. |
| `period_id` | STG+ | Compact period identifier. | Recommended format: `YYYYQ`, for example `20251`. |
| `scoring_version` | MART | Opportunity score version. | Current value: `opportunity_score_v1`. |
| `scored_at` | MART | Timestamp when mart was rebuilt. | Used for auditability. |

## QCEW base metrics

| Metric | Source object | Definition | Business interpretation |
|---|---|---|---|
| `qtrly_estabs` | `STG.STG_QCEW_COUNTY_INDUSTRY_QTR` | Quarterly establishment count. | Local business presence proxy. |
| `avg_monthly_employment` | `STG.STG_QCEW_COUNTY_INDUSTRY_QTR` | Average monthly employment during quarter. | Local labor-market scale proxy. |
| `total_qtrly_wages` | `STG.STG_QCEW_COUNTY_INDUSTRY_QTR` | Total wages paid during quarter. | Local payroll/economic activity proxy. |
| `avg_wkly_wage` | `STG.STG_QCEW_COUNTY_INDUSTRY_QTR` | Average weekly wage. | Wage level / market-value proxy. |
| `oty_qtrly_estabs_pct_chg` | `STG.STG_QCEW_COUNTY_INDUSTRY_QTR` | Over-the-year percent change in establishments. | Direct QCEW YoY establishment growth signal. |
| `oty_total_qtrly_wages_pct_chg` | `STG.STG_QCEW_COUNTY_INDUSTRY_QTR` | Over-the-year percent change in wages. | Direct QCEW YoY payroll growth signal. |

## QCEW growth feature metrics

Source object:

```text
INT.INT_QCEW_COUNTY_INDUSTRY_GROWTH_QTR
```

| Metric | Definition | Business interpretation |
|---|---|---|
| `estabs_prev_qtr` | Previous quarter establishment count for same county-industry. | Baseline for QoQ establishment growth. |
| `estabs_qoq_pct_chg` | Quarter-over-quarter establishment percent change. | Near-term local business growth signal. |
| `employment_prev_qtr` | Previous quarter average monthly employment. | Baseline for QoQ employment growth. |
| `employment_qoq_pct_chg` | Quarter-over-quarter employment percent change. | Near-term labor demand signal. |
| `wages_prev_qtr` | Previous quarter total quarterly wages. | Baseline for QoQ wage growth. |
| `wages_qoq_pct_chg` | Quarter-over-quarter wage percent change. | Near-term economic activity signal. |
| `estabs_4q_avg` | Trailing four-quarter average establishments. | Smoothed business base. |
| `employment_4q_avg` | Trailing four-quarter average employment. | Smoothed employment base. |
| `wages_4q_avg` | Trailing four-quarter average wages. | Smoothed payroll base. |
| `growth_signal_flag` | Boolean or categorical flag from growth model. | Marks rows with usable/reliable growth signal. |

## Growth scores

Source object:

```text
INT.INT_QCEW_GROWTH_SCORES
```

| Metric | Definition | Range | Interpretation |
|---|---|---:|---|
| `ongoing_growth_score` | Percentile-based score from observed current/recent growth features within same period and industry. | 0–100 | Higher means stronger current growth relative to peer county-industries. |
| `expected_growth_score` | Percentile-based score from smoothed / forward-looking growth proxy features within same period and industry. | 0–100 | Higher means stronger expected or persistent growth signal. |
| `ongoing_growth_tier` | Tier label derived from `ongoing_growth_score`. | Text | Used for stakeholder filtering. |
| `expected_growth_tier` | Tier label derived from `expected_growth_score`. | Text | Used for stakeholder filtering. |

Important interpretation:

```text
These are transparent v1 index scores, not validated forecasts or probabilities.
```

## SBA lending metrics

Source object:

```text
INT.INT_SBA_LENDING_COUNTY_INDUSTRY_QTR
```

| Metric | Definition | Business interpretation |
|---|---|---|
| `sba_loan_count` | Count of SBA 7(a) loans approved in the county-industry-quarter. | Observed SBA lending activity. |
| `sba_gross_approval_amount` | Sum of gross approval amount. | Total approved SBA capital flow. |
| `sba_initial_approval_amount` | Sum of initial approval amount. | Original approval amount. |
| `sba_current_approval_amount` | Sum of current approval amount. | Current approval exposure after changes. |
| `sba_jobs_supported` | Sum of jobs supported reported by SBA. | Reported jobs impact proxy. |
| `active_lender_count` | Count of distinct non-null lenders in county-industry-quarter. | Lender participation depth. |
| `loans_missing_lender_name` | Count of loans without usable lender name. | Lender data quality indicator. |
| `avg_gross_loan_amount` | Gross approval amount divided by loan count. | Average SBA loan size. |
| `top_lender_name` | Lender with highest activity by amount/count logic in intermediate model. | Dominant lender identity. |
| `top_lender_loan_count` | Number of loans from top lender. | Top lender activity by count. |
| `top_lender_gross_approval_amount` | Gross approval amount from top lender. | Top lender activity by dollars. |
| `top_lender_share_by_count` | Top lender loan count divided by total loans. | Count-based lender concentration. |
| `top_lender_share_by_amount` | Top lender amount divided by total gross approval amount. | Dollar-based lender concentration. |
| `lender_hhi_by_amount` | Sum of squared lender dollar shares. | Market concentration by dollars; closer to 1 means more concentrated. |
| `lender_hhi_by_count` | Sum of squared lender loan-count shares. | Market concentration by loan count. |
| `lender_concentration_tier` | Tier label derived from HHI/share thresholds. | Competition context for market entry. |
| `first_approval_date` | Earliest SBA approval date in aggregate row. | Time span audit field. |
| `latest_approval_date` | Latest SBA approval date in aggregate row. | Freshness/coverage audit field. |

## Mart-derived penetration metrics

Source object:

```text
MART.COUNTY_INDUSTRY_OPPORTUNITY_QTR
```

| Metric | Formula | Interpretation |
|---|---|---|
| `sba_loans_per_100_establishments` | `100 * sba_loan_count / qtrly_estabs` | SBA loan penetration relative to business base. |
| `sba_dollars_per_establishment` | `sba_gross_approval_amount / qtrly_estabs` | SBA capital penetration relative to business base. |
| `lending_penetration_score` | Percentile blend of loan and dollar penetration within same period and industry. | Higher means more SBA support relative to peer markets. |
| `low_lending_penetration_score` | `100 - lending_penetration_score` | Higher means more under-supported by SBA relative to peer markets. |

Recommended v1 blend:

```text
lending_penetration_score =
    0.60 * loan_penetration_pct_rank
  + 0.40 * dollar_penetration_pct_rank
```

## Opportunity score components

| Metric | Formula / method | Interpretation |
|---|---|---|
| `underserved_score` | Weighted blend of expected growth, ongoing growth, and low SBA penetration. Current v1: `0.55 * expected_growth_score + 0.25 * ongoing_growth_score + 0.20 * low_lending_penetration_score`. | High-growth market with relatively weak SBA lending penetration. |
| `lender_fragmentation_score` | `100 * (1 - lender_hhi_by_amount)`, neutral `50` when no SBA activity or missing HHI. | Higher means lending is less concentrated and potentially more contestable. |
| `lending_momentum_score` | Neutral `50` in v1 unless SBA trend features are added. | Placeholder for future lending acceleration/slowdown. |
| `final_opportunity_score` | Weighted composite of growth, underserved, fragmentation, and momentum components. | Overall market opportunity ranking score. |

Current v1 final score:

```text
final_opportunity_score =
    0.30 * ongoing_growth_score
  + 0.30 * expected_growth_score
  + 0.25 * underserved_score
  + 0.10 * lender_fragmentation_score
  + 0.05 * lending_momentum_score
```

## Opportunity tiers

| Tier | Rule | Recommended action |
|---|---:|---|
| `Very High` | `final_opportunity_score >= 85` | Prioritize for near-term market expansion review. |
| `High` | `70 <= final_opportunity_score < 85` | Strong candidate for sales and lending opportunity analysis. |
| `Moderate` | `55 <= final_opportunity_score < 70` | Monitor and compare against neighboring counties/industries. |
| `Watchlist` | `40 <= final_opportunity_score < 55` | Watchlist only; needs stronger growth or lending signal. |
| `Low` | `< 40` | Low priority under current scoring version. |

## Known limitations

- QCEW is a market-growth proxy, not a direct measure of BI/data analytics demand.
- SBA 7(a) reflects SBA-backed lending only, not all SMB lending.
- SBA borrower/project geography may be imperfect because county mapping depends on standardized county/state fields.
- Current v1 opportunity score is a transparent index, not a trained predictive model.
- `lending_momentum_score` is neutral in v1 until a dedicated SBA trend intermediate is added.
