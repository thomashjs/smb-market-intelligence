#!/usr/bin/env python3
"""
Run the SMB Market Intelligence local/Snowflake pipeline.

This script orchestrates the project from source preparation through Snowflake raw loads,
staging, intermediate models, the final opportunity mart, and DQ SQL files. It is intended
for local development from the repository root, especially in WSL with the Snowflake CLI
already configured.

Examples:
    python3 scripts/run_pipeline.py --connection smb_dev
    python3 scripts/run_pipeline.py --connection smb_dev --dry-run
    python3 scripts/run_pipeline.py --connection smb_dev --skip-downloads --skip-put
    python3 scripts/run_pipeline.py --connection smb_dev --only marts dq
"""

import argparse
import os
from pathlib import Path
import shlex
import subprocess
import sys
from datetime import datetime, timezone
from uuid import uuid4


DEFAULT_DATABASE = "SMB_MARKET_INTELLIGENCE_DEV"
DEFAULT_CONNECTION = "smb_dev"
DEFAULT_QCEW_OUTPUT = "data/processed/qcew/qcew_county_industry_qtr_us_v1.csv"
DEFAULT_SBA_OUTPUT = "data/processed/sba/sba_7a_loans_us_v1.csv"

PIPELINE_GROUPS = ("admin", "extract", "put", "raw", "staging", "intermediate", "marts", "dq")


def parse_args():
    parser = argparse.ArgumentParser(
        description="Run the SMB Market Intelligence pipeline."
    )
    parser.add_argument(
        "--connection",
        default=DEFAULT_CONNECTION,
        help="Snowflake CLI connection name. Default: smb_dev.",
    )
    parser.add_argument(
        "--database",
        default=DEFAULT_DATABASE,
        help="Snowflake database name. Default: SMB_MARKET_INTELLIGENCE_DEV.",
    )
    parser.add_argument(
        "--qcew-output",
        default=DEFAULT_QCEW_OUTPUT,
        help="Processed QCEW CSV output path.",
    )
    parser.add_argument(
        "--sba-output",
        default=DEFAULT_SBA_OUTPUT,
        help="Processed SBA CSV output path.",
    )
    parser.add_argument(
        "--qcew-state",
        default="all",
        help="QCEW state argument passed to download_qcew.py. Default: all.",
    )
    parser.add_argument(
        "--qcew-start-year",
        default=None,
        help="Optional start year passed to download_qcew.py if your script supports it.",
    )
    parser.add_argument(
        "--qcew-end-year",
        default=None,
        help="Optional end year passed to download_qcew.py if your script supports it.",
    )
    parser.add_argument(
        "--sba-state",
        default="all",
        help="SBA state argument passed to prepare_sba_7a.py. Default: all.",
    )
    parser.add_argument(
        "--only",
        nargs="+",
        choices=PIPELINE_GROUPS,
        help="Run only selected pipeline groups.",
    )
    parser.add_argument(
        "--skip-admin",
        action="store_true",
        help="Skip database/schema/reference/raw-stage setup files.",
    )
    parser.add_argument(
        "--skip-downloads",
        action="store_true",
        help="Skip Python source download/prepare steps.",
    )
    parser.add_argument(
        "--skip-put",
        action="store_true",
        help="Skip PUT commands to Snowflake internal stage.",
    )
    parser.add_argument(
        "--skip-dq",
        action="store_true",
        help="Skip SQL files in sql/05_dq.",
    )
    parser.add_argument(
        "--continue-on-error",
        action="store_true",
        help="Continue after failed commands and report all failures at the end.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print commands without executing them.",
    )
    return parser.parse_args()


def repo_root():
    path = Path.cwd().resolve()
    if (path / "sql").exists() and (path / "scripts").exists():
        return path

    for parent in path.parents:
        if (parent / "sql").exists() and (parent / "scripts").exists():
            return parent

    raise SystemExit(
        "Could not find repo root. Run this from smb-market-intelligence or a subdirectory."
    )


def shell_join(cmd):
    return " ".join(shlex.quote(str(part)) for part in cmd)


def run_command(cmd, dry_run=False, continue_on_error=False, cwd=None):
    print("\n$ " + shell_join(cmd), flush=True)

    if dry_run:
        return True

    result = subprocess.run(cmd, cwd=cwd, check=False)
    if result.returncode == 0:
        return True

    message = f"Command failed with exit code {result.returncode}: {shell_join(cmd)}"
    if continue_on_error:
        print("ERROR: " + message, file=sys.stderr)
        return False

    raise SystemExit(message)


def snow_sql_file(connection, path):
    return ["snow", "sql", "-c", connection, "-f", str(path)]


def snow_sql_query(connection, query):
    return ["snow", "sql", "-c", connection, "-q", query]


def existing_sql_files(paths, required=True):
    files = []
    missing = []

    for path in paths:
        if path.exists():
            files.append(path)
        else:
            missing.append(path)

    if missing and required:
        joined = "\n".join(str(path) for path in missing)
        raise SystemExit(f"Required SQL file(s) missing:\n{joined}")

    for path in missing:
        print(f"WARN: skipping missing optional SQL file: {path}")

    return files


def should_run(group, args):
    if args.only:
        return group in args.only
    if group == "admin" and args.skip_admin:
        return False
    if group == "extract" and args.skip_downloads:
        return False
    if group == "put" and args.skip_put:
        return False
    if group == "dq" and args.skip_dq:
        return False
    return True


def qcew_download_command(args, root):
    cmd = [
        sys.executable,
        "scripts/download_qcew.py",
        "--state",
        args.qcew_state,
        "--output",
        args.qcew_output,
    ]

    if args.qcew_start_year:
        cmd.extend(["--start-year", args.qcew_start_year])
    if args.qcew_end_year:
        cmd.extend(["--end-year", args.qcew_end_year])

    return cmd


def put_query(database, local_file, stage_subdir):
    absolute_file = local_file.resolve()
    return (
        f"PUT file://{absolute_file} "
        f"@{database}.RAW.LOAD_STAGE/{stage_subdir} "
        "AUTO_COMPRESS=TRUE OVERWRITE=TRUE;"
    )


def check_local_file(path, dry_run=False):
    if dry_run:
        return
    if not path.exists():
        raise SystemExit(
            f"Expected file does not exist: {path}\n"
            "Run without --skip-downloads, or confirm the output path."
        )


def build_steps(args, root):
    qcew_output = root / args.qcew_output
    sba_output = root / args.sba_output

    steps = []

    if should_run("admin", args):
        admin_files = existing_sql_files(
            [
                root / "sql/00_admin/00_create_database.sql",
                root / "sql/00_admin/01_create_ref_tables.sql",
                root / "sql/01_raw/01_create_qcew_raw.sql",
                root / "sql/01_raw/02_create_sba_raw.sql",
                root / "sql/01_raw/03_create_load_stage.sql",
            ]
        )
        for path in admin_files:
            steps.append(("admin", snow_sql_file(args.connection, path), None))

    if should_run("extract", args):
        steps.append(("extract", qcew_download_command(args, root), None))
        steps.append(
            (
                "extract",
                [sys.executable, "scripts/download_sba_7a.py"],
                None,
            )
        )
        steps.append(
            (
                "extract",
                [
                    sys.executable,
                    "scripts/prepare_sba_7a.py",
                    "--state",
                    args.sba_state,
                    "--output",
                    args.sba_output,
                ],
                None,
            )
        )

    if should_run("put", args):
        steps.append(("check_file", ["__check_file__", str(qcew_output)], None))
        steps.append(
            (
                "put",
                snow_sql_query(args.connection, put_query(args.database, qcew_output, "qcew")),
                None,
            )
        )
        steps.append(("check_file", ["__check_file__", str(sba_output)], None))
        steps.append(
            (
                "put",
                snow_sql_query(args.connection, put_query(args.database, sba_output, "sba")),
                None,
            )
        )

    if should_run("raw", args):
        raw_files = existing_sql_files(
            [
                root / "sql/01_raw/04_load_qcew_raw.sql",
                root / "sql/01_raw/05_load_sba_raw.sql",
            ]
        )
        for path in raw_files:
            steps.append(("raw", snow_sql_file(args.connection, path), None))

    if should_run("staging", args):
        staging_files = existing_sql_files(
            [
                root / "sql/02_staging/01_stg_qcew_county_industry_qtr.sql",
                root / "sql/02_staging/02_stg_sba_7a_loans.sql",
            ]
        )
        for path in staging_files:
            steps.append(("staging", snow_sql_file(args.connection, path), None))

    if should_run("intermediate", args):
        intermediate_files = existing_sql_files(
            [
                root / "sql/03_intermediate/01_int_qcew_county_industry_growth_qtr.sql",
                root / "sql/03_intermediate/02_int_qcew_growth_scores.sql",
                root / "sql/03_intermediate/03_int_sba_lending_county_industry_qtr.sql",
            ]
        )
        for path in intermediate_files:
            steps.append(("intermediate", snow_sql_file(args.connection, path), None))

    if should_run("marts", args):
        mart_files = existing_sql_files(
            [root / "sql/04_marts/02_build_county_industry_opportunity_qtr.sql"]
        )
        for path in mart_files:
            steps.append(("marts", snow_sql_file(args.connection, path), None))

    if should_run("dq", args):
        dq_dir = root / "sql/05_dq"
        dq_files = sorted(dq_dir.glob("*.sql"))
        if not dq_files:
            raise SystemExit(f"No DQ SQL files found in {dq_dir}")
        for path in dq_files:
            steps.append(("dq", snow_sql_file(args.connection, path), None))

    return steps


def main():
    args = parse_args()
    root = repo_root()
    os.chdir(root)

    run_id = str(uuid4())
    started_at = datetime.now(timezone.utc).isoformat(timespec="seconds")

    print(f"Pipeline run id: {run_id}")
    print(f"Started at UTC: {started_at}")
    print(f"Repo root: {root}")
    print(f"Snowflake connection: {args.connection}")
    print(f"Snowflake database: {args.database}")

    steps = build_steps(args, root)
    if not steps:
        print("No steps selected. Nothing to run.")
        return

    failures = []

    for group, cmd, _ in steps:
        if cmd[0] == "__check_file__":
            try:
                check_local_file(Path(cmd[1]), dry_run=args.dry_run)
                print(f"\nChecked local file: {cmd[1]}")
            except SystemExit as exc:
                if args.continue_on_error:
                    print(f"ERROR: {exc}", file=sys.stderr)
                    failures.append((group, cmd, str(exc)))
                    continue
                raise
            continue

        ok = run_command(
            cmd,
            dry_run=args.dry_run,
            continue_on_error=args.continue_on_error,
            cwd=root,
        )
        if not ok:
            failures.append((group, cmd, "command failed"))

    finished_at = datetime.now(timezone.utc).isoformat(timespec="seconds")
    print(f"\nFinished at UTC: {finished_at}")

    if failures:
        print("\nPipeline completed with failures:", file=sys.stderr)
        for group, cmd, message in failures:
            print(f"- [{group}] {message}: {shell_join(cmd)}", file=sys.stderr)
        raise SystemExit(1)

    if args.dry_run:
        print("Dry run completed successfully. No commands were executed.")
    else:
        print("Pipeline completed successfully.")


if __name__ == "__main__":
    main()
