# Stakeholder Memo — SMB Lending & Market Opportunity Intelligence Dashboard

## Audience

Internal analytics consultancy / portfolio company leadership.

## Decision supported

Prioritize county-industry markets for SMB market expansion review using public indicators of local business growth, SBA lending penetration, and lender concentration.

## Business question

Where are the strongest SMB market expansion opportunities by county, industry, and quarter?

## Executive summary

The v1 SMB Lending & Market Opportunity Intelligence Dashboard combines BLS QCEW county-industry growth data with SBA 7(a) lending activity to identify markets where SMB activity appears strong but lending support appears relatively weak or fragmented.

The dashboard does not claim to directly measure demand for BI or analytics services. Instead, it provides a defensible public-data signal for SMB market opportunity by ranking county-industry-quarter combinations on:

- Ongoing establishment, employment, and wage growth.
- Expected growth based on recent trend behavior.
- SBA lending penetration relative to the establishment base.
- Lender concentration and fragmentation.
- A final opportunity score and action tier.

The recommended use is to identify a short list of markets for deeper review, not to make final expansion decisions automatically.

## Current deliverable

Primary Tableau-ready mart:

```text
MART.COUNTY_INDUSTRY_OPPORTUNITY_QTR
```

Primary grain:

```text
state_fips × county_fips × qcew_industry_code × year × quarter × scoring_version
```

Current scoring version:

```text
opportunity_score_v1
```

## How to interpret the score

The final opportunity score is a transparent v1 index from 0 to 100. Higher scores indicate markets with stronger growth signals and lower relative SBA lending penetration.

Suggested tier interpretation:

| Tier | Score range | Interpretation |
|---|---:|---|
| Very High | 85–100 | Prioritize for near-term market expansion review. |
| High | 70–84.99 | Strong candidate for sales/lending opportunity analysis. |
| Moderate | 55–69.99 | Monitor and compare against neighboring markets. |
| Watchlist | 40–54.99 | Needs stronger growth or lending signal. |
| Low | 0–39.99 | Low priority under current scoring version. |

## Key dashboard questions

The dashboard should help answer:

1. Which county-industry markets have the highest final opportunity scores in the latest quarter?
2. Which states and sectors contain the largest concentration of high-opportunity markets?
3. Are high-opportunity markets driven by growth, low lending penetration, lender fragmentation, or a mix?
4. Which markets show little or no SBA lending activity despite meaningful establishment bases?
5. Which lenders dominate SBA lending in target markets, and where is competition fragmented?
6. Are the underlying sources fresh, complete, and passing basic data quality checks?

## Recommended analysis workflow

1. Start on the executive overview page.
2. Filter to the latest available QCEW quarter.
3. Review top-ranked states, counties, and sectors.
4. Drill into the county-industry explorer for specific market candidates.
5. Use the lending/competition page to distinguish low-penetration markets from dominated markets.
6. Check monitoring/governance status before relying on the latest refresh.
7. Export or screenshot the top market list for discussion.

## Recommended stakeholder actions

For markets in the **Very High** tier:

- Review county-level economic context and neighboring market behavior.
- Compare SBA lending activity to non-SBA competitive signals if available.
- Identify target lenders, chambers of commerce, local business associations, or referral partners.
- Validate whether the sector has enough establishments to support meaningful outreach.

For markets in the **High** tier:

- Add to a prioritized watchlist.
- Track quarter-over-quarter changes in rank and tier.
- Compare against similar counties in the same state or region.

For markets in the **Moderate** tier:

- Monitor rather than prioritize immediately.
- Use as secondary candidates if sales capacity allows.

For **Watchlist** and **Low** markets:

- Do not prioritize for near-term expansion unless there is separate qualitative evidence.

## Known limitations

- QCEW is a proxy for local SMB activity, not a direct count of small businesses.
- SBA 7(a) loans represent one major lending channel, not all SMB credit activity.
- Borrower county matching depends on source county names and Census Gazetteer matching quality.
- The v1 scoring model is transparent and heuristic; it is not a validated predictive model.
- Public source release schedules may lag the current quarter.
- Final recommendations should be reviewed with business context before action.

## Validation checklist before stakeholder use

Before presenting results, confirm:

- `MART.COUNTY_INDUSTRY_OPPORTUNITY_QTR` rebuilt successfully.
- Latest QCEW period is visible in the dashboard.
- SBA latest approval date is current relative to the downloaded FOIA file.
- DQ checks show no critical failures.
- Grain uniqueness check returns zero duplicate keys.
- Opportunity tier distribution is reasonable and not concentrated entirely in one tier.
- Top-ranked markets have non-null geography, sector, and score fields.

## Memo placeholders to complete after dashboard build

Use these once Tableau is complete:

```text
Latest QCEW period reviewed: [YYYY Q#]
Latest SBA approval date reviewed: [YYYY-MM-DD]
Number of county-industry-quarter rows in mart: [row_count]
Number of states represented: [state_count]
Number of counties represented: [county_count]
Top opportunity state: [state]
Top opportunity sector: [sector]
Number of Very High markets in latest period: [count]
Dashboard link or screenshot path: [link/path]
```

## Bottom line

The v1 dashboard is suitable as a portfolio-grade analytics product and as an internal prioritization tool for public-data-driven SMB market research. It should be used to narrow the search space for expansion opportunities, followed by qualitative market review and stakeholder judgment.
