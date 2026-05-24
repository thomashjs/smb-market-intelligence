"""
Download BLS QCEW county-industry quarterly CSV slices and prepare a Snowflake-loadable CSV.

This v1 script filters to Texas county-level private-sector records for selected NAICS sectors.
It intentionally creates one clean CSV for the first vertical slice of the project.
"""

from __future__ import annotations

import argparse
from io import BytesIO
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

import pandas as pd


QCEW_COLUMNS = [
    "source_file_name",
    "source_url",
    "area_fips",
    "own_code",
    "industry_code",
    "agglvl_code",
    "size_code",
    "year",
    "qtr",
    "disclosure_code",
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


DEFAULT_SECTORS = [
    "23",     # Construction
    "52",     # Finance and Insurance
    "54",     # Professional, Scientific, and Technical Services
    "56",     # Administrative and Support Services
    "62",     # Health Care and Social Assistance
    "72",     # Accommodation and Food Services
]


def qcew_url(year: int, quarter: int, industry_code: str) -> str:
    return f"https://data.bls.gov/cew/data/api/{year}/{quarter}/industry/{industry_code}.csv"


def fetch_csv(url: str) -> pd.DataFrame | None:
    request = Request(url, headers={"User-Agent": "smb-market-intelligence-demo/0.1"})

    try:
        with urlopen(request, timeout=60) as response:
            content = response.read()
    except HTTPError as exc:
        if exc.code == 404:
            print(f"SKIP 404: {url}")
            return None
        raise
    except URLError as exc:
        print(f"SKIP network error: {url} ({exc})")
        return None

    df = pd.read_csv(BytesIO(content), dtype=str)
    df.columns = [col.strip().lower() for col in df.columns]
    return df


def clean_qcew_frame(
    df: pd.DataFrame,
    source_file_name: str,
    source_url: str,
    state_fips: str,
) -> pd.DataFrame:
    df = df.copy()

    df["source_file_name"] = source_file_name
    df["source_url"] = source_url

    for col in QCEW_COLUMNS:
        if col not in df.columns:
            df[col] = pd.NA

    df["area_fips"] = df["area_fips"].astype(str).str.zfill(5)

    # Keep county-level rows for the selected state.
    # Exclude statewide pseudo-county records like 48000.
    county_mask = (
        df["area_fips"].str.fullmatch(r"\d{5}", na=False)
        & df["area_fips"].str.startswith(state_fips)
        & ~df["area_fips"].str.endswith("000")
    )

    # Private ownership and all establishment sizes.
    business_mask = (df["own_code"] == "5") & (df["size_code"] == "0")

    df = df.loc[county_mask & business_mask, QCEW_COLUMNS]
    return df


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--start-year", type=int, default=2023)
    parser.add_argument("--end-year", type=int, default=2025)
    parser.add_argument("--state-fips", type=str, default="48")
    parser.add_argument("--output", type=Path, default=Path("data/processed/qcew/qcew_county_industry_qtr_tx_v1.csv"))
    parser.add_argument("--sectors", nargs="*", default=DEFAULT_SECTORS)
    args = parser.parse_args()

    frames: list[pd.DataFrame] = []

    for year in range(args.start_year, args.end_year + 1):
        for quarter in range(1, 5):
            for sector in args.sectors:
                url = qcew_url(year, quarter, sector)
                print(f"Downloading {url}")

                raw_df = fetch_csv(url)
                if raw_df is None:
                    continue

                source_file_name = f"qcew_{year}_q{quarter}_industry_{sector}.csv"
                clean_df = clean_qcew_frame(raw_df, source_file_name, url, args.state_fips)

                if clean_df.empty:
                    print(f"No matching county rows: {source_file_name}")
                    continue

                frames.append(clean_df)

    if not frames:
        raise RuntimeError("No QCEW records downloaded. Check years, sectors, or network access.")

    output_df = pd.concat(frames, ignore_index=True)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    output_df.to_csv(args.output, index=False)

    print(f"Wrote {len(output_df):,} rows to {args.output}")


if __name__ == "__main__":
    main()
