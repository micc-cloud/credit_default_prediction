# SQL — Data Loading and Cleaning

Dialect: DuckDB. All SQL is written to be ANSI-portable where possible. Only the
import / export parts in `01_create_raw.sql` use DuckDB-specific syntax, and
those parts are isolated and labelled in the file header.

Approval: SQL technical proposal v2 was approved by the user on 2026-11-25
23:12. Files `01`–`03` are written first; each file needs Jensen's review
before it counts as complete. Approved for push 2026-11-26 (overnight Part 1):
Jensen review passed; user waived per-file approval for this batch only.
Files `04`–`05` are written only after `01`–`03` are approved. Nothing in
`sql/` is pushed to GitHub until Jensen has reviewed it.

## Files

| File | What it does | Output |
| --- | --- | --- |
| `01_create_raw.sql` | Load the raw data into `credit_raw` | `credit_raw` (30,000 rows) |
| `02_profile_checks.sql` | Read-only profiling checks | No writes; result tables only |
| `03_clean.sql` | Build the cleaned table | `credit_clean` (30,000 rows) |
| `04_features.sql` | Build the feature table | `credit_features` (to do, after 01–03 are approved) |
| `05_validation.sql` | Validation queries, PASS / FAIL | Validation results (to do, after 01–03 are approved) |
| `run_all.sql` | Run `01` → `05` in order | All tables above |
| `README.md` | This file | — |

## How to run DuckDB

Run all commands from the project root
(`credit-default-project/`), so the relative paths below resolve.

### Option A — DuckDB Python API (recommended, used for testing)

```bash
# Install once (already installed in .credit-venv):
# pip install duckdb
python -c "import duckdb; print(duckdb.__version__)"
```

```python
import duckdb

con = duckdb.connect("data/credit_default.duckdb")
con.execute(open("sql/01_create_raw.sql").read())
con.execute(open("sql/02_profile_checks.sql").read())
con.execute(open("sql/03_clean.sql").read())
con.close()
```

### Option B — DuckDB CLI

```bash
duckdb data/credit_default.duckdb < sql/01_create_raw.sql
duckdb data/credit_default.duckdb < sql/02_profile_checks.sql
duckdb data/credit_default.duckdb < sql/03_clean.sql
```

### Option C — `run_all.sql` (once 04–05 exist)

`run_all.sql` runs the five files in order, `01` → `05`, against the same
database file. It uses DuckDB's `.read` command, so run it with the CLI:

```bash
duckdb data/credit_default.duckdb < sql/run_all.sql
```

Run order is `01` → `02` → `03` → `04` → `05`. Do not skip `02`: profiling
must be read before any cleaning decision is applied. Do not run `05` before
`03` and `04` exist — validation checks the cleaned and feature tables.

The database file `data/credit_default.duckdb` is local only. It is listed in
`.gitignore` and is never pushed to GitHub.

## Step 0 — Convert the tracked TSV to CSV (one-off, reproducible)

The tracked raw file is tab-separated text, not an Excel workbook
(see the main `README.md` Dataset section). It is converted to CSV
once, using exactly the same read logic as notebook `01_eda.ipynb`
(`src/data_loading.py`). No Excel reader is involved.

Reproducible steps (run from the project root):

```python
import sys
sys.path.insert(0, "src")
from pathlib import Path
from data_loading import load_raw_tsv, assert_raw_schema, write_interim_csv

base = Path(".")
raw = base / "raw data/Default of Credit Card Clients.tsv"

# sep="\t", header=1: the first row is a header row (X1, X2, ...);
# the real column names are in the second row.
df = load_raw_tsv(raw)
assert_raw_schema(df)  # 30,000 rows, 25 columns, unique ID, 0 nulls, 6,636 defaults
write_interim_csv(df, base)

print(df.shape)  # must be (30000, 25)
print("ID unique:", df["ID"].is_unique)  # must be True
print("Missing values:", int(df.isna().sum().sum()))  # must be 0
print("Default rate:", round(df["default_payment_next_month"].mean() * 100, 2), "%")  # 22.12
```

Requirements: `pandas` only (`pip install -r requirements.txt`).
`scripts/validate_sql.py` runs this step automatically if the interim
CSV is missing.

The interim file `data/interim/credit_raw.csv` is local only. It is listed in
`.gitignore` and is never pushed to GitHub. The tracked raw TSV and the processed
`data/processed/credit_features.csv` belong in the repo. A genuine UCI
`.xls` may be kept locally under `data/raw/` for cross-checking only;
it is ignored by git and is not needed to reproduce this project.

## Cleaning decisions (summary)

Full reasoning is in the header comment of each SQL file. Summary:

- `EDUCATION` 0 / 5 / 6 (unknown) are merged into 4 ("Others / Unknown").
  No rows are deleted. Both the original code and the label are kept.
- `MARRIAGE` 0 (unknown) is merged into 3 ("Others / Unknown").
  No rows are deleted. Both the original code and the label are kept.
- `PAY_0`, `PAY_2`–`PAY_6`: -2 / -1 / 0 are status codes, not delays.
  The cleaning layer keeps the original values and adds a delay-months
  column (`pay_*_delay_months`): -2 / -1 / 0 → 0 months, 1–9 unchanged.
- `BILL_AMT1`–`BILL_AMT6`: negative values are flagged, not deleted.
  `03_clean.sql` adds `has_negative_bill_amt` (0/1) and
  `negative_bill_months_cnt` (0–6). A negative bill may come from a refund
  or adjustment and should be confirmed with the business; in this portfolio
  it is kept and noted in the limitations.
- `PAY_AMT1`–`PAY_AMT6`: 0 is kept. It means no repayment was recorded
  that month, which is itself a risk signal.
- `LIMIT_BAL`, `AGE`: range-checked only. Nothing is deleted or changed
  without clear evidence of an error.

## Validation (zero tolerance)

`05_validation.sql` checks, among others, that row count is 30,000,
defaults are 6,636 (22.12%), `pay_ratio_1` has 2,598 nulls,
`pay_ratio_avg` has 1,071 nulls, and `utilisation_1` has 0 nulls, exactly
matching the pandas version. Any mismatch is a FAIL. The SQL output is the
source of truth; the pandas version is kept for cross-checking.
