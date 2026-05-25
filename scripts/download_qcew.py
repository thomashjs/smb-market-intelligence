#!/usr/bin/env python3
"""
Download BLS QCEW county-industry-quarter data and create one Snowflake-loadable CSV.

Default behavior:
- Pull all U.S. counties, not just Texas
- Keep private ownership rows: own_code = 5
- Keep all establishment sizes: size_code = 0
- Keep county-level 5-digit FIPS rows
- Exclude statewide pseudo-county rows ending in 000
- Keep selected NAICS/QCEW sectors
"""

import argparse
import sys
import urllib.error
from datetime import datetime, timezone
from pathlib import Path

import pandas as pd


QCEW_API_TEMPLATE = "https://data.bls.gov/cew/data/api/{year}/{quarter}/industry/{industry_code}.csv"

DEFAULT_SECTORS = "23,52,54,56,62,72"

OUTPUT_COLUMNS = [
    "source_file_name",
    "source_url",
    "loaded_at",
    "area_fips",
    "own_code",
    "industry_code",
    "agglvl_code",
    "size_code",
    "year",
    "qtr",
    "disclosure_code",
    "area_title",
    "own_title",
    "industry_title",
    "agglvl_title",
    "size_title",
    "qtrly_estabs",
    "month1_emplvl",
    "month2_emplvl",
    "month3_emplvl",
    "total_qtrly_wages",
    "taxable_qtrly_wages",
    "qtrly_contributions",
    "avg_wkly_wage",
    "lq_disclosure_code",
    "lq_qtrly_estabs",
    "lq_month1_emplvl",
    "lq_month2_emplvl",
    "lq_month3_emplvl",
    "lq_total_qtrly_wages",
    "lq_taxable_qtrly_wages",
    "lq_qtrly_contributions",
    "lq_avg_wkly_wage",
    "oty_disclosure_code",
    "oty_qtrly_estabs_chg",
    "oty_qtrly_estabs_pct_chg",
    "oty_month1_emplvl_chg",
    "oty_month1_emplvl_pct_chg",
    "oty_month2_emplvl_chg",
    "oty_month2_emplvl_pct_chg",
    "oty_month3_emplvl_chg",
    "oty_month3_emplvl_pct_chg",
    "oty_total_qtrly_wages_chg",
    "oty_total_qtrly_wages_pct_chg",
    "oty_taxable_qtrly_wages_chg",
    "oty_taxable_qtrly_wages_pct_chg",
    "oty_qtrly_contributions_chg",
    "oty_qtrly_contributions_pct_chg",
    "oty_avg_wkly_wage_chg",
    "oty_avg_wkly_wage_pct_chg",
]


def qcew_url_industry_code(sector):
    sector = sector.strip()
    if sector == "44_45":
        return "44-45"
    return sector


def normalized_output_industry_code(value):
    return str(value).strip().replace("-", "_")


def normalize_state_filter(value):
    value = str(value).strip().lower()

    if value in {"", "all", "us", "usa", "*"}:
        return None

    states = []
    for item in value.split(","):
        item = item.strip()
        if not item:
            continue
        states.append(item.zfill(2))

    return set(states)


def is_county_fips(series):
    area_fips = series.astype("string").str.strip()
    return area_fips.str.match(r"^\d{5}$", na=False) & ~area_fips.str.endswith("000", na=False)


def download_qcew_slice(year, quarter, sector):
    industry_for_url = qcew_url_industry_code(sector)
    url = QCEW_API_TEMPLATE.format(
        year=year,
        quarter=quarter,
        industry_code=industry_for_url,
    )

    try:
        frame = pd.read_csv(url, dtype="string")
    except urllib.error.HTTPError as exc:
        if exc.code == 404:
            print(f"Skipping unavailable QCEW slice: {url}")
            return pd.DataFrame()
        raise

    frame["source_file_name"] = f"qcew_{year}_q{quarter}_industry_{industry_for_url}.csv"
    frame["source_url"] = url
    frame["loaded_at"] = datetime.now(timezone.utc).isoformat(timespec="seconds")

    return frame


def standardize_qcew_slice(frame, state_filter):
    if frame.empty:
        return frame

    frame.columns = [col.strip().lower() for col in frame.columns]

    required = {"area_fips", "own_code", "industry_code", "size_code", "year", "qtr"}
    missing = sorted(required - set(frame.columns))
    if missing:
        raise ValueError(f"QCEW slice missing required columns: {missing}")

    frame["area_fips"] = frame["area_fips"].astype("string").str.strip()
    frame["own_code"] = frame["own_code"].astype("string").str.strip()
    frame["size_code"] = frame["size_code"].astype("string").str.strip()
    frame["industry_code"] = frame["industry_code"].map(normalized_output_industry_code)

    keep_mask = (
        is_county_fips(frame["area_fips"])
        & frame["own_code"].eq("5")
        & frame["size_code"].eq("0")
    )

    if state_filter is not None:
        keep_mask = keep_mask & frame["area_fips"].str.slice(0, 2).isin(state_filter)

    frame = frame[keep_mask].copy()

    if frame.empty:
        return frame

    for col in OUTPUT_COLUMNS:
        if col not in frame.columns:
            frame[col] = pd.NA

    return frame[OUTPUT_COLUMNS]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--start-year", type=int, default=2023)
    parser.add_argument("--end-year", type=int, default=2025)
    parser.add_argument(
        "--sectors",
        default=DEFAULT_SECTORS,
        help="Comma-separated QCEW/NAICS sectors, e.g. 23,52,54,56,62,72 or 23,44_45,52.",
    )
    parser.add_argument(
        "--state-fips",
        default="all",
        help="Use 'all' for national data, or comma-separated state FIPS like 06,12,36,48.",
    )
    parser.add_argument(
        "--output",
        default="data/processed/qcew/qcew_county_industry_qtr_us_v1.csv",
    )
    args = parser.parse_args()

    if args.end_year < args.start_year:
        raise ValueError("--end-year must be greater than or equal to --start-year")

    state_filter = normalize_state_filter(args.state_fips)
    sectors = [sector.strip() for sector in args.sectors.split(",") if sector.strip()]

    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)

    wrote_header = False
    total_rows = 0

    for year in range(args.start_year, args.end_year + 1):
        for quarter in range(1, 5):
            for sector in sectors:
                raw = download_qcew_slice(year, quarter, sector)
                prepared = standardize_qcew_slice(raw, state_filter)

                if prepared.empty:
                    print(f"{year} Q{quarter} sector {sector}: wrote 0 rows")
                    continue

                prepared.to_csv(
                    output_path,
                    index=False,
                    mode="w" if not wrote_header else "a",
                    header=not wrote_header,
                )

                wrote_header = True
                total_rows += len(prepared)

                state_count = prepared["area_fips"].str.slice(0, 2).nunique()
                county_count = prepared["area_fips"].nunique()

                print(
                    f"{year} Q{quarter} sector {sector}: "
                    f"wrote {len(prepared):,} rows, "
                    f"states={state_count:,}, counties={county_count:,}"
                )

    if total_rows == 0:
        raise RuntimeError("No QCEW rows were written. Check years, sectors, or state filter.")

    print(f"Wrote {total_rows:,} rows to {output_path}")


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        sys.exit(1)
