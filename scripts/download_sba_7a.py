#!/usr/bin/env python3
"""
Download the latest SBA 7(a) FY2020-present FOIA CSV from data.sba.gov.

The script uses the SBA CKAN API instead of hardcoding a dated file URL, so
future quarterly refreshes should still be discoverable from the same dataset.
"""

import argparse
import json
import re
import sys
import urllib.request
from pathlib import Path


PACKAGE_API_URL = "https://data.sba.gov/api/3/action/package_show?id=7-a-504-foia"


def fetch_json(url):
    request = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(request, timeout=60) as response:
        return json.load(response)


def choose_7a_current_resource(resources):
    candidates = []

    for resource in resources:
        name = str(resource.get("name") or "")
        url = str(resource.get("url") or "")
        file_format = str(resource.get("format") or "")

        compact_name = re.sub(r"\s+", "", name.lower())

        is_7a = "7(a)" in compact_name or "7a" in compact_name
        is_current = "fy2020-present" in compact_name
        is_csv = file_format.upper() == "CSV" or url.lower().endswith(".csv")

        if is_7a and is_current and is_csv:
            candidates.append(resource)

    if not candidates:
        available = "\n".join(
            f"- {r.get('name')} | {r.get('format')} | {r.get('url')}"
            for r in resources
            if str(r.get("format") or "").upper() == "CSV"
        )
        raise RuntimeError(
            "Could not find the SBA 7(a) FY2020-present CSV resource.\n"
            f"Available CSV resources:\n{available}"
        )

    return candidates[0]


def download_file(url, output_path):
    output_path.parent.mkdir(parents=True, exist_ok=True)

    request = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})

    with urllib.request.urlopen(request, timeout=60) as response:
        with output_path.open("wb") as output_file:
            while True:
                chunk = response.read(1024 * 1024)
                if not chunk:
                    break
                output_file.write(chunk)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--output",
        default="data/raw/sba/sba_7a_fy2020_present.csv",
        help="Local output CSV path.",
    )
    parser.add_argument(
        "--metadata-output",
        default="data/raw/sba/sba_7a_fy2020_present_metadata.json",
        help="Local output metadata JSON path.",
    )
    args = parser.parse_args()

    package = fetch_json(PACKAGE_API_URL)

    if not package.get("success"):
        raise RuntimeError("SBA CKAN API response was not successful.")

    resources = package["result"]["resources"]
    resource = choose_7a_current_resource(resources)

    output_path = Path(args.output)
    metadata_path = Path(args.metadata_output)

    print(f"Selected resource: {resource.get('name')}")
    print(f"Resource last modified: {resource.get('last_modified')}")
    print(f"Downloading to: {output_path}")

    download_file(resource["url"], output_path)

    metadata_path.parent.mkdir(parents=True, exist_ok=True)
    metadata_path.write_text(json.dumps(resource, indent=2), encoding="utf-8")

    print(f"Wrote: {output_path}")
    print(f"Wrote metadata: {metadata_path}")


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        sys.exit(1)
