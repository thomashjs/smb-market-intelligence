#!/usr/bin/env python3
"""
Prepare SBA 7(a) loan data for Snowflake loading.

This script:
- Reads the SBA FOIA CSV in chunks
- Filters to US loans; Defaults to Texas loans with --state argument
- Filters to target NAICS sectors used in the QCEW vertical slice
- Standardizes column names and data types
- Maps county names to county FIPS using the Census API
- Writes a Snowflake-loadable CSV
"""

import argparse
import json
import re
import sys
import csv
import io
from io import BytesIO
from zipfile import ZipFile
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

import pandas as pd


CENSUS_COUNTY_API_URL = (
    "https://api.census.gov/data/2020/dec/pl"
    "?get=NAME&for=county:*&in=state:*"
)

CENSUS_COUNTY_GAZETTEER_URL = (
    "https://www2.census.gov/geo/docs/maps-data/data/gazetteer/"
    "2025_Gazetteer/2025_Gaz_counties_national.zip"
)

OUTPUT_COLUMNS = [
    "source_file_name",
    "loaded_at",
    "program",
    "loan_name",
    "borrower_name",
    "borrower_city",
    "borrower_state",
    "borrower_zip",
    "borrower_county",
    "naics_code",
    "naics_description",
    "approval_date",
    "fiscal_year",
    "gross_approval_amount",
    "initial_approval_amount",
    "current_approval_amount",
    "lender_name",
    "lender_city",
    "lender_state",
    "jobs_supported",
    "project_county",
    "project_state",
    "project_county_clean",
    "state_fips",
    "county_fips",
    "qcew_industry_code",
]

COLUMN_ALIASES = {
    "program": ["program"],
    "loan_name": ["loanname", "borrname", "borrowername"],
    "borrower_name": ["borrname", "borrowername"],
    "borrower_city": ["borrcity", "borrowercity"],
    "borrower_state": ["borrstate", "borrowerstate"],
    "borrower_zip": ["borrzip", "borrowerzip"],
    "borrower_county": ["borrcounty", "borrowercounty"],
    "naics_code": ["naicscode", "naics"],
    "naics_description": ["naicsdescription"],
    "approval_date": ["approvaldate"],
    "fiscal_year": ["approvalfiscalyear", "fiscalyear"],
    "gross_approval_amount": ["grossapproval", "grossapprovalamount"],
    "initial_approval_amount": ["initialapprovalamount"],
    "current_approval_amount": ["currentapprovalamount"],
    "lender_name": ["bankname", "lendername"],
    "lender_city": ["bankcity", "lendercity"],
    "lender_state": ["bankstate", "lenderstate"],
    "jobs_supported": ["jobssupported"],
    "project_county": ["projectcounty"],
    "project_state": ["projectstate"],
}

STATE_TO_FIPS = {
    "AL": "01", "ALABAMA": "01",
    "AK": "02", "ALASKA": "02",
    "AZ": "04", "ARIZONA": "04",
    "AR": "05", "ARKANSAS": "05",
    "CA": "06", "CALIFORNIA": "06",
    "CO": "08", "COLORADO": "08",
    "CT": "09", "CONNECTICUT": "09",
    "DE": "10", "DELAWARE": "10",
    "DC": "11", "DISTRICT OF COLUMBIA": "11",
    "FL": "12", "FLORIDA": "12",
    "GA": "13", "GEORGIA": "13",
    "HI": "15", "HAWAII": "15",
    "ID": "16", "IDAHO": "16",
    "IL": "17", "ILLINOIS": "17",
    "IN": "18", "INDIANA": "18",
    "IA": "19", "IOWA": "19",
    "KS": "20", "KANSAS": "20",
    "KY": "21", "KENTUCKY": "21",
    "LA": "22", "LOUISIANA": "22",
    "ME": "23", "MAINE": "23",
    "MD": "24", "MARYLAND": "24",
    "MA": "25", "MASSACHUSETTS": "25",
    "MI": "26", "MICHIGAN": "26",
    "MN": "27", "MINNESOTA": "27",
    "MS": "28", "MISSISSIPPI": "28",
    "MO": "29", "MISSOURI": "29",
    "MT": "30", "MONTANA": "30",
    "NE": "31", "NEBRASKA": "31",
    "NV": "32", "NEVADA": "32",
    "NH": "33", "NEW HAMPSHIRE": "33",
    "NJ": "34", "NEW JERSEY": "34",
    "NM": "35", "NEW MEXICO": "35",
    "NY": "36", "NEW YORK": "36",
    "NC": "37", "NORTH CAROLINA": "37",
    "ND": "38", "NORTH DAKOTA": "38",
    "OH": "39", "OHIO": "39",
    "OK": "40", "OKLAHOMA": "40",
    "OR": "41", "OREGON": "41",
    "PA": "42", "PENNSYLVANIA": "42",
    "RI": "44", "RHODE ISLAND": "44",
    "SC": "45", "SOUTH CAROLINA": "45",
    "SD": "46", "SOUTH DAKOTA": "46",
    "TN": "47", "TENNESSEE": "47",
    "TX": "48", "TEXAS": "48",
    "UT": "49", "UTAH": "49",
    "VT": "50", "VERMONT": "50",
    "VA": "51", "VIRGINIA": "51",
    "WA": "53", "WASHINGTON": "53",
    "WV": "54", "WEST VIRGINIA": "54",
    "WI": "55", "WISCONSIN": "55",
    "WY": "56", "WYOMING": "56",
    "PR": "72", "PUERTO RICO": "72",
}


def normalize_column_name(value):
    return re.sub(r"[^a-z0-9]", "", str(value).lower())


def clean_geo_key(value):
    if pd.isna(value):
        return ""

    text = str(value).upper().strip()
    text = re.sub(r"[^A-Z0-9\s]", " ", text)
    text = re.sub(r"\s+", " ", text).strip()
    return text


def county_base_key(value):
    text = clean_geo_key(value)

    text = re.sub(r"\bCITY OF\b", " ", text)
    text = re.sub(r"\bCOUNTY\b", " ", text)
    text = re.sub(r"\bPARISH\b", " ", text)
    text = re.sub(r"\bBOROUGH\b", " ", text)
    text = re.sub(r"\bCENSUS AREA\b", " ", text)
    text = re.sub(r"\bMUNICIPIO\b", " ", text)
    text = re.sub(r"\bMUNICIPALITY\b", " ", text)
    text = re.sub(r"\s+", " ", text).strip()

    return re.sub(r"[^A-Z0-9]", "", text)


def county_exact_key(value):
    return re.sub(r"[^A-Z0-9]", "", clean_geo_key(value))


def state_fips_from_value(value):
    return STATE_TO_FIPS.get(clean_geo_key(value), "")


def load_us_county_lookup():
    request = urllib.request.Request(
        CENSUS_COUNTY_GAZETTEER_URL,
        headers={"User-Agent": "Mozilla/5.0"},
    )

    with urllib.request.urlopen(request, timeout=60) as response:
        zip_bytes = BytesIO(response.read())

    with ZipFile(zip_bytes) as zip_file:
        txt_names = [name for name in zip_file.namelist() if name.lower().endswith(".txt")]
        if not txt_names:
            raise RuntimeError("No .txt file found inside Census Gazetteer county zip.")

        with zip_file.open(txt_names[0]) as county_file:
            counties = pd.read_csv(
                county_file,
                sep=r"\t|\|",
                engine="python",
                dtype="string",
            )

    counties.columns = [col.strip().upper() for col in counties.columns]

    if "GEOID" not in counties.columns or "NAME" not in counties.columns:
        raise RuntimeError(
            "Unexpected Gazetteer county file layout. "
            f"Columns found: {list(counties.columns)}"
        )

    exact_lookup = {}
    base_candidates = {}

    for _, row in counties.iterrows():
        geoid = str(row["GEOID"]).zfill(5)
        state_fips = geoid[:2]
        county_name = row["NAME"]

        exact_lookup[(state_fips, county_exact_key(county_name))] = geoid

        base_key = county_base_key(county_name)
        base_candidates.setdefault((state_fips, base_key), set()).add(geoid)

    base_lookup = {
        key: next(iter(geoids))
        for key, geoids in base_candidates.items()
        if len(geoids) == 1
    }

    return {
        "exact": exact_lookup,
        "base": base_lookup,
    }


def resolve_county_fips(state_value, county_value, county_lookup):
    state_fips = state_fips_from_value(state_value)

    if not state_fips:
        return ""

    exact_key = county_exact_key(county_value)
    exact_match = county_lookup["exact"].get((state_fips, exact_key))

    if exact_match:
        return exact_match

    base_key = county_base_key(county_value)
    return county_lookup["base"].get((state_fips, base_key), "")


def build_source_column_lookup(columns):
    return {normalize_column_name(col): col for col in columns}


def pick_column(chunk, source_lookup, aliases):
    for alias in aliases:
        source_col = source_lookup.get(alias)
        if source_col is not None:
            return chunk[source_col].astype("string")

    return pd.Series([pd.NA] * len(chunk), index=chunk.index, dtype="string")


def clean_amount(series):
    text = series.astype("string").fillna("")
    text = text.str.replace("$", "", regex=False)
    text = text.str.replace(",", "", regex=False)
    text = text.str.replace(r"^\((.*)\)$", r"-\1", regex=True)
    return pd.to_numeric(text, errors="coerce")


def clean_integer(series):
    return pd.to_numeric(series.astype("string").str.replace(",", "", regex=False), errors="coerce").astype("Int64")


def clean_date(series):
    parsed = pd.to_datetime(series, errors="coerce")
    return parsed.dt.strftime("%Y-%m-%d").fillna("")


def derive_qcew_industry_code(naics_series):
    digits = naics_series.astype("string").fillna("").str.replace(r"\D", "", regex=True)
    sector = digits.str.slice(0, 2)
    return sector.replace({"44": "44_45", "45": "44_45"})


def standardize_chunk(chunk, source_file_name, county_lookup, target_sectors, state):
    source_lookup = build_source_column_lookup(chunk.columns)
    standardized = pd.DataFrame(index=chunk.index)

    for target_col, aliases in COLUMN_ALIASES.items():
        standardized[target_col] = pick_column(chunk, source_lookup, aliases)

    standardized["project_state"] = standardized["project_state"].fillna("").str.upper().str.strip()
    standardized["borrower_state"] = standardized["borrower_state"].fillna("").str.upper().str.strip()

    standardized["project_state"] = standardized["project_state"].mask(
        standardized["project_state"].eq(""),
        standardized["borrower_state"],
    )

    state_filter_value = "all" if state is None else str(state).strip()

    if state_filter_value.lower() != "all":
        state_filter = (
            standardized["project_state"]
            .str.upper()
            .str.strip()
            .eq(state_filter_value.upper())
        )
        standardized = standardized[state_filter].copy()

    if standardized.empty:
        return pd.DataFrame(columns=OUTPUT_COLUMNS)

    standardized["project_county"] = standardized["project_county"].fillna("")
    standardized["borrower_county"] = standardized["borrower_county"].fillna("")

    standardized["project_county"] = standardized["project_county"].mask(
        standardized["project_county"].str.strip().eq(""),
        standardized["borrower_county"],
    )

    standardized["project_county_clean"] = standardized["project_county"].map(clean_geo_key)

    standardized["state_fips"] = standardized["project_state"].map(state_fips_from_value)

    standardized["county_fips"] = standardized.apply(
        lambda row: resolve_county_fips(
            row["project_state"],
            row["project_county"],
            county_lookup,
        ),
        axis=1,
    )

    standardized["naics_code"] = (
        standardized["naics_code"]
        .astype("string")
        .fillna("")
        .str.replace(r"\D", "", regex=True)
    )

    standardized["qcew_industry_code"] = derive_qcew_industry_code(
        standardized["naics_code"]
    )

    if target_sectors:
        standardized = standardized[
            standardized["qcew_industry_code"].isin(target_sectors)
        ].copy()

    if standardized.empty:
        return pd.DataFrame(columns=OUTPUT_COLUMNS)

    standardized["source_file_name"] = source_file_name
    standardized["loaded_at"] = datetime.now(timezone.utc).isoformat(timespec="seconds")

    standardized["approval_date"] = clean_date(standardized["approval_date"])
    standardized["fiscal_year"] = clean_integer(standardized["fiscal_year"])

    standardized["gross_approval_amount"] = clean_amount(
        standardized["gross_approval_amount"]
    )

    initial_blank = (
        standardized["initial_approval_amount"]
        .fillna("")
        .astype("string")
        .str.strip()
        .eq("")
    )

    standardized["initial_approval_amount"] = clean_amount(
        standardized["initial_approval_amount"]
    )

    standardized.loc[
        initial_blank,
        "initial_approval_amount",
    ] = standardized.loc[
        initial_blank,
        "gross_approval_amount",
    ]

    current_blank = (
        standardized["current_approval_amount"]
        .fillna("")
        .astype("string")
        .str.strip()
        .eq("")
    )

    standardized["current_approval_amount"] = clean_amount(
        standardized["current_approval_amount"]
    )

    standardized.loc[
        current_blank,
        "current_approval_amount",
    ] = standardized.loc[
        current_blank,
        "gross_approval_amount",
    ]

    standardized["jobs_supported"] = clean_integer(standardized["jobs_supported"])

    for col in OUTPUT_COLUMNS:
        if col not in standardized.columns:
            standardized[col] = ""

    return standardized[OUTPUT_COLUMNS]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--input",
        default="data/raw/sba/sba_7a_fy2020_present.csv",
        help="Raw SBA 7(a) CSV path.",
    )
    parser.add_argument(
        "--output",
        default="data/processed/sba/sba_7a_loans_us_v1.csv",
        help="Prepared Snowflake-loadable CSV path.",
    )
    parser.add_argument(
        "--state",
        default="all",
        help="Two-letter project state filter, or 'all' for national data (default).",
    )
    parser.add_argument(
        "--target-sectors",
        default="23,52,54,56,62,72",
        help="Comma-separated QCEW/NAICS sector codes to keep.",
    )
    parser.add_argument(
        "--chunksize",
        type=int,
        default=100_000,
        help="Rows per pandas chunk.",
    )
    args = parser.parse_args()

    input_path = Path(args.input)
    output_path = Path(args.output)

    if not input_path.exists():
        raise FileNotFoundError(f"Input file not found: {input_path}")

    output_path.parent.mkdir(parents=True, exist_ok=True)

    target_sectors = {
        sector.strip()
        for sector in args.target_sectors.split(",")
        if sector.strip()
    }

    county_lookup = load_us_county_lookup()

    state_arg = args.state.upper().strip()
    state_filter = None if state_arg in {"ALL", "US", "NATIONAL"} else state_arg

    total_rows_written = 0
    wrote_header = False

    reader = pd.read_csv(
        input_path,
        dtype="string",
        chunksize=args.chunksize,
        encoding="utf-8-sig",
        encoding_errors="replace",
        on_bad_lines="warn",
        low_memory=False,
    )

    for idx, chunk in enumerate(reader, start=1):
        prepared = standardize_chunk(
            chunk=chunk,
            source_file_name=input_path.name,
            county_lookup=county_lookup,
            target_sectors=target_sectors,
            state=state_filter,
        )

        if prepared.empty:
            print(f"Chunk {idx}: wrote 0 rows")
            continue

        prepared.to_csv(
            output_path,
            index=False,
            mode="w" if not wrote_header else "a",
            header=not wrote_header,
        )

        wrote_header = True
        total_rows_written += len(prepared)

        missing_fips = prepared["county_fips"].eq("").sum()
        print(f"Chunk {idx}: wrote {len(prepared):,} rows; missing county_fips={missing_fips:,}")

    print(f"Wrote {total_rows_written:,} rows to {output_path}")

    if total_rows_written == 0:
        raise RuntimeError("No rows were written. Check source columns, state filter, or sector filter.")


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        sys.exit(1)
