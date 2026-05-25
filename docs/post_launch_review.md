# Post-Launch Review — SMB Lending & Market Opportunity Intelligence Dashboard

## Review purpose

Evaluate whether the v1 dashboard is useful, reliable, maintainable, and ready to present as a portfolio-grade analytics product.

## Launch scope

Product:

```text
SMB Lending & Market Opportunity Intelligence Dashboard
```

Primary mart:

```text
MART.COUNTY_INDUSTRY_OPPORTUNITY_QTR
```

Primary dashboard objective:

```text
Help stakeholders prioritize county-industry markets for SMB market expansion review.
```

Current score version:

```text
opportunity_score_v1
```

## Launch checklist

| Area | Status | Notes |
|---|---|---|
| QCEW national ingestion complete | To confirm | Validate latest available quarter. |
| SBA national ingestion complete | To confirm | Validate latest approval date. |
| Intermediate models built | To confirm | QCEW growth, QCEW scores, SBA lending aggregates. |
| Opportunity mart built | To confirm | Validate row counts and uniqueness. |
| DQ checks passing | To confirm | Review `DQ.VW_DQ_CURRENT_STATUS` or equivalent. |
| EDA notebooks reviewed | To confirm | Confirm distributions and top-score reasonableness. |
| Tableau dashboard built | To confirm | Add screenshot/link after build. |
| README updated | To confirm | Include dashboard image/link after build. |
| Governance doc complete | To confirm | Confirm borrower-level fields are not exposed. |

## Success criteria

The v1 release is successful if:

- The pipeline can rebuild the mart from source files with documented commands.
- The final mart has one row per scoring version, county, industry, year, and quarter.
- Opportunity scores are populated and bounded from 0 to 100.
- Dashboard users can identify top markets by state, county, sector, and quarter.
- Users can explain why a market ranks highly using component scores.
- DQ checks make failures visible before dashboard use.
- Documentation is sufficient for another analyst to continue the project.

## KPI review

Populate after dashboard build and validation:

```text
Latest QCEW period: [YYYY Q#]
Latest SBA approval date: [YYYY-MM-DD]
Mart row count: [count]
State count: [count]
County count: [count]
Industry count: [count]
Very High markets in latest period: [count]
High markets in latest period: [count]
DQ critical failures: [count]
Dashboard pages completed: [count]
Pipeline dry run successful: [yes/no]
Full pipeline run successful: [yes/no]
```

## User/stakeholder feedback questions

Use these to evaluate the dashboard:

1. Can a stakeholder identify the top markets within 60 seconds?
2. Are the scoring components understandable without reading SQL?
3. Does the dashboard make it clear that the score is a prioritization index, not a prediction guarantee?
4. Can the user distinguish high-growth markets from underserved markets?
5. Can the user see whether a market has no SBA activity versus concentrated SBA activity?
6. Are filters intuitive by state, county, sector, period, and tier?
7. Are source freshness and DQ status visible enough?
8. What additional data would improve confidence in the recommendations?

## Findings template

### What worked

- [Add finding]
- [Add finding]
- [Add finding]

### What did not work

- [Add finding]
- [Add finding]
- [Add finding]

### Data issues found

- [Add issue]
- [Add issue]
- [Add issue]

### Dashboard usability issues

- [Add issue]
- [Add issue]
- [Add issue]

## Known v1 limitations

- QCEW is a local market activity proxy and does not directly measure SMB demand.
- SBA 7(a) captures one lending channel and does not represent all business credit.
- The v1 opportunity score is heuristic and transparent, not a validated predictive model.
- Retail sector `44_45` exists in reference logic but may not yet be fully included in all source pipelines.
- County FIPS matching for SBA data depends on source county quality and Gazetteer matching logic.
- Public source release timing may cause freshness lag.

## Recommended v2 improvements

### Data improvements

- Add lending momentum as a real feature rather than neutral placeholder logic.
- Add county names from a county reference table for dashboard readability.
- Add CBP or Census Business Dynamics as annual context if useful.
- Add population, income, or business density context for market normalization.
- Add non-SBA lending or bank branch data if a reliable public source is selected.

### Modeling/scoring improvements

- Test alternative opportunity score weights.
- Add score stability checks quarter over quarter.
- Compare rankings against known economic-growth indicators.
- Add minimum establishment thresholds by sector to avoid tiny-market artifacts.
- Add a confidence/coverage score based on geography quality and source freshness.

### Dashboard improvements

- Add county names and state map labels.
- Add tooltip explanations for each score.
- Add a score-component waterfall or stacked bar.
- Add dashboard-level DQ/freshness indicators.
- Add exportable ranked market table.

### Engineering improvements

- Fully test `scripts/run_pipeline.py` in WSL.
- Add a scheduled run pattern or documented manual refresh cadence.
- Insert pipeline run results into `OPS.PIPELINE_RUN_LOG`.
- Persist DQ results into `DQ.DATA_QUALITY_RESULTS`, not only status views.
- Add GitHub Actions for linting SQL/Python if desired.

## Decision log

| Date | Decision | Rationale |
|---|---|---|
| [YYYY-MM-DD] | Use QCEW as core growth source | Quarterly public county-industry data. |
| [YYYY-MM-DD] | Use SBA 7(a) as lending source | Public loan-level data with lender and geography fields. |
| [YYYY-MM-DD] | Use county-industry-quarter grain | Aligns growth and lending signals for Tableau. |
| [YYYY-MM-DD] | Use heuristic score v1 | Transparent and explainable for portfolio project. |
| [YYYY-MM-DD] | Aggregate before dashboarding | Avoid borrower-level exposure and improve usability. |

## Final release assessment

Complete after dashboard launch:

```text
Release status: [Released / Released with caveats / Not ready]
Primary reason: [summary]
Next recommended action: [summary]
```
