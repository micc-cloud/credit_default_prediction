"""Enforceable validation for SQL 01-03 (defect 7).

The SQL files print check queries, but a printed row cannot fail a run.
This runner executes SQL 01, 02 and 03 against a fresh DuckDB file,
then asserts the documented invariants and exits non-zero on failure.

It does NOT implement SQL 04 or 05 (roadmap, not in scope).

Usage (from the project root):
    python scripts/validate_sql.py [--db data/credit_default.duckdb]

The interim CSV (data/interim/credit_raw.csv) is generated from the
tracked TSV first if it is missing, using src/data_loading.py.
"""
import argparse
import sys
import tempfile
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(PROJECT_ROOT / "src"))

import duckdb  # noqa: E402

from data_loading import assert_raw_schema, load_raw_tsv, write_interim_csv  # noqa: E402

EXPECTED = {
    "row_count": 30_000,
    "id_unique": 30_000,
    "null_total": 0,
    "default_1": 6_636,
    "default_0": 23_364,
    "clean_row_count": 30_000,
    "education_code_4": 468,
    "marriage_code_3": 377,
    "has_negative_bill_amt_1": 1_930,
}


def run_sql_file(con, path):
    con.execute(Path(path).read_text())


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--db", default=None, help="DuckDB file (default: temp file)")
    args = parser.parse_args()

    tsv = PROJECT_ROOT / "raw data" / "Default of Credit Card Clients.tsv"
    if not tsv.exists():
        print(f"FAIL: tracked raw TSV not found: {tsv}")
        return 1
    df = load_raw_tsv(tsv)
    assert_raw_schema(df)
    interim = PROJECT_ROOT / "data" / "interim" / "credit_raw.csv"
    if not interim.exists():
        write_interim_csv(df, PROJECT_ROOT)
        print(f"Generated interim CSV: {interim}")

    db_path = args.db or str(Path(tempfile.mkdtemp()) / "validate.duckdb")
    con = duckdb.connect(db_path)
    try:
        run_sql_file(con, PROJECT_ROOT / "sql" / "01_create_raw.sql")
        run_sql_file(con, PROJECT_ROOT / "sql" / "02_profile_checks.sql")
        run_sql_file(con, PROJECT_ROOT / "sql" / "03_clean.sql")

        checks = {}
        checks["row_count"] = con.execute("SELECT COUNT(*) FROM credit_raw").fetchone()[0]
        checks["id_unique"] = con.execute("SELECT COUNT(DISTINCT ID) FROM credit_raw").fetchone()[0]
        cols = [r[1] for r in con.execute("PRAGMA table_info('credit_raw')").fetchall()]
        null_sql = " + ".join(f"SUM(CASE WHEN \"{c}\" IS NULL THEN 1 ELSE 0 END)" for c in cols)
        checks["null_total"] = con.execute(f"SELECT {null_sql} FROM credit_raw").fetchone()[0]
        checks["default_1"] = con.execute(
            "SELECT SUM(default_payment_next_month) FROM credit_raw").fetchone()[0]
        checks["default_0"] = con.execute(
            "SELECT SUM(1 - default_payment_next_month) FROM credit_raw").fetchone()[0]
        checks["clean_row_count"] = con.execute("SELECT COUNT(*) FROM credit_clean").fetchone()[0]
        checks["education_code_4"] = con.execute(
            "SELECT COUNT(*) FROM credit_clean WHERE education_code = 4").fetchone()[0]
        checks["marriage_code_3"] = con.execute(
            "SELECT COUNT(*) FROM credit_clean WHERE marriage_code = 3").fetchone()[0]
        checks["has_negative_bill_amt_1"] = con.execute(
            "SELECT COUNT(*) FROM credit_clean WHERE has_negative_bill_amt = 1").fetchone()[0]
        # Target domain and clean/raw agreement.
        domain = con.execute(
            "SELECT DISTINCT default_payment_next_month FROM credit_clean ORDER BY 1").fetchall()
        assert [r[0] for r in domain] == [0, 1], f"target domain must be [0, 1], got {domain}"
        clean_default = con.execute(
            "SELECT SUM(default_payment_next_month) FROM credit_clean").fetchone()[0]
        assert clean_default == 6_636, f"clean default_1 must be 6636, got {clean_default}"
        neg_dist = con.execute(
            "SELECT negative_bill_months_cnt, COUNT(*) FROM credit_clean "
            "GROUP BY 1 ORDER BY 1").fetchall()
        assert dict(neg_dist) == {0: 28_070, 1: 993, 2: 412, 3: 240, 4: 118, 5: 79, 6: 88}, (
            f"negative_bill_months_cnt distribution differs: {neg_dist}"
        )
    finally:
        con.close()

    failures = []
    for name, expected in EXPECTED.items():
        got = checks.get(name)
        status = "OK " if got == expected else "FAIL"
        print(f"{status} {name}: got {got}, expected {expected}")
        if got != expected:
            failures.append(name)
    if failures:
        print(f"VALIDATION FAILED: {failures}")
        return 1
    print("SQL 01-03 validation passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
