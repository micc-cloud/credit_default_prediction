-- ============================================================================
-- 01_create_raw.sql — Load the raw data into credit_raw
-- Project: Credit Card Default Prediction
-- Dialect: DuckDB (single local file: data/credit_default.duckdb)
-- Approval: SQL technical proposal v2 approved by the user on 2026-11-25 23:12.
--           Approved for push 2026-11-26 (overnight Part 1): Jensen review passed; user waived per-file approval for this batch only.
--
-- What this file does:
--   1. Create the raw table credit_raw from the interim CSV.
--   2. Rename the target column to default_payment_next_month.
--   3. Check that the load is complete: 30,000 rows, ID unique, 0 nulls.
--   The null_total check is enforced by scripts/validate_sql.py, which
--   exits non-zero if any documented invariant fails.
--
-- What this file does NOT do:
--   - No cleaning, no recoding, no deletion. All transformations belong in
--     03_clean.sql. credit_raw must stay an exact copy of the source.
--   - No modelling. No writes to any production database. The DuckDB file
--     is local only (see sql/README.md).
--
-- Input: data/interim/credit_raw.csv
--   This is a one-off conversion of the tracked TSV raw file. The
--   conversion is reproducible and documented in sql/README.md
--   (Step 0): pandas read_csv with sep="\t", header=1 (the first row
--   is a header row X1, X2, ...; the real column names are in the
--   second row). No Excel reader is used. The interim CSV is local
--   only and is never pushed to GitHub.
--
-- Original column mapping (UCI file, X1–X23 plus Y):
--   X1  -> LIMIT_BAL                  Credit limit (TWD, incl. family cards)
--   X2  -> SEX                        1 = male, 2 = female
--   X3  -> EDUCATION                  1 = graduate school, 2 = university,
--                                      3 = high school, 4 = others
--   X4  -> MARRIAGE                   1 = married, 2 = single, 3 = others
--   X5  -> AGE                        Age in years
--   X6  -> PAY_0                      Repayment status, Sep 2005 (most recent)
--   X7  -> PAY_2                      Repayment status, Aug 2005
--   X8  -> PAY_3                      Repayment status, Jul 2005
--   X9  -> PAY_4                      Repayment status, Jun 2005
--   X10 -> PAY_5                      Repayment status, May 2005
--   X11 -> PAY_6                      Repayment status, Apr 2005 (earliest)
--   X12–X17 -> BILL_AMT1–BILL_AMT6    Bill amounts, Sep 2005 to Apr 2005
--   X18–X23 -> PAY_AMT1–PAY_AMT6      Repayment amounts, Sep 2005 to Apr 2005
--   Y   -> default_payment_next_month  1 = default next month, 0 = no default
--   Note: there is no PAY_1. PAY_0 is the most recent month (Sep 2005) and
--   PAY_6 is the earliest month (Apr 2005). Do not reverse this order.
--
-- PAY scale (most important, easiest to get wrong):
--   -2 = no consumption, -1 = paid duly, 0 = revolving credit,
--   1–9 = delayed by 1–9 months. -2 / -1 / 0 are status codes, not delays.
-- ============================================================================

-- DuckDB-specific import (isolated here; the rest of this file is ANSI SQL).
-- read_csv with header=true reads the column names from the first row of the
-- interim CSV, which already carries the readable names above, except for
-- the target column, which is renamed in the SELECT below.
CREATE OR REPLACE TABLE credit_raw AS
SELECT
    CAST(ID AS INTEGER) AS ID,
    CAST(LIMIT_BAL AS INTEGER) AS LIMIT_BAL,
    CAST(SEX AS INTEGER) AS SEX,
    CAST(EDUCATION AS INTEGER) AS EDUCATION,
    CAST(MARRIAGE AS INTEGER) AS MARRIAGE,
    CAST(AGE AS INTEGER) AS AGE,
    CAST(PAY_0 AS INTEGER) AS PAY_0,
    CAST(PAY_2 AS INTEGER) AS PAY_2,
    CAST(PAY_3 AS INTEGER) AS PAY_3,
    CAST(PAY_4 AS INTEGER) AS PAY_4,
    CAST(PAY_5 AS INTEGER) AS PAY_5,
    CAST(PAY_6 AS INTEGER) AS PAY_6,
    CAST(BILL_AMT1 AS INTEGER) AS BILL_AMT1,
    CAST(BILL_AMT2 AS INTEGER) AS BILL_AMT2,
    CAST(BILL_AMT3 AS INTEGER) AS BILL_AMT3,
    CAST(BILL_AMT4 AS INTEGER) AS BILL_AMT4,
    CAST(BILL_AMT5 AS INTEGER) AS BILL_AMT5,
    CAST(BILL_AMT6 AS INTEGER) AS BILL_AMT6,
    CAST(PAY_AMT1 AS INTEGER) AS PAY_AMT1,
    CAST(PAY_AMT2 AS INTEGER) AS PAY_AMT2,
    CAST(PAY_AMT3 AS INTEGER) AS PAY_AMT3,
    CAST(PAY_AMT4 AS INTEGER) AS PAY_AMT4,
    CAST(PAY_AMT5 AS INTEGER) AS PAY_AMT5,
    CAST(PAY_AMT6 AS INTEGER) AS PAY_AMT6,
    CAST("default_payment_next_month" AS INTEGER) AS default_payment_next_month
FROM read_csv(
    'data/interim/credit_raw.csv',
    header = true,
    columns = {
        'ID': 'INTEGER',
        'LIMIT_BAL': 'INTEGER',
        'SEX': 'INTEGER',
        'EDUCATION': 'INTEGER',
        'MARRIAGE': 'INTEGER',
        'AGE': 'INTEGER',
        'PAY_0': 'INTEGER',
        'PAY_2': 'INTEGER',
        'PAY_3': 'INTEGER',
        'PAY_4': 'INTEGER',
        'PAY_5': 'INTEGER',
        'PAY_6': 'INTEGER',
        'BILL_AMT1': 'INTEGER',
        'BILL_AMT2': 'INTEGER',
        'BILL_AMT3': 'INTEGER',
        'BILL_AMT4': 'INTEGER',
        'BILL_AMT5': 'INTEGER',
        'BILL_AMT6': 'INTEGER',
        'PAY_AMT1': 'INTEGER',
        'PAY_AMT2': 'INTEGER',
        'PAY_AMT3': 'INTEGER',
        'PAY_AMT4': 'INTEGER',
        'PAY_AMT5': 'INTEGER',
        'PAY_AMT6': 'INTEGER',
        'default_payment_next_month': 'INTEGER'
    }
);

-- Load checks (must all pass before moving to 02_profile_checks.sql):
--   row_count = 30,000; id_unique = 30,000; null_total = 0;
--   default_1 = 6,636; default_rate = 22.12%.
--   These rows are informational in SQL; scripts/validate_sql.py
--   asserts the same values and exits non-zero on failure.
SELECT 'row_count' AS check_name, COUNT(*) AS value FROM credit_raw
UNION ALL
SELECT 'id_unique', COUNT(DISTINCT ID) FROM credit_raw
UNION ALL
SELECT 'null_total', (
    SUM(CASE WHEN ID IS NULL THEN 1 ELSE 0 END)
  + SUM(CASE WHEN LIMIT_BAL IS NULL THEN 1 ELSE 0 END)
  + SUM(CASE WHEN SEX IS NULL THEN 1 ELSE 0 END)
  + SUM(CASE WHEN EDUCATION IS NULL THEN 1 ELSE 0 END)
  + SUM(CASE WHEN MARRIAGE IS NULL THEN 1 ELSE 0 END)
  + SUM(CASE WHEN AGE IS NULL THEN 1 ELSE 0 END)
  + SUM(CASE WHEN PAY_0 IS NULL THEN 1 ELSE 0 END)
  + SUM(CASE WHEN PAY_2 IS NULL THEN 1 ELSE 0 END)
  + SUM(CASE WHEN PAY_3 IS NULL THEN 1 ELSE 0 END)
  + SUM(CASE WHEN PAY_4 IS NULL THEN 1 ELSE 0 END)
  + SUM(CASE WHEN PAY_5 IS NULL THEN 1 ELSE 0 END)
  + SUM(CASE WHEN PAY_6 IS NULL THEN 1 ELSE 0 END)
  + SUM(CASE WHEN BILL_AMT1 IS NULL THEN 1 ELSE 0 END)
  + SUM(CASE WHEN BILL_AMT2 IS NULL THEN 1 ELSE 0 END)
  + SUM(CASE WHEN BILL_AMT3 IS NULL THEN 1 ELSE 0 END)
  + SUM(CASE WHEN BILL_AMT4 IS NULL THEN 1 ELSE 0 END)
  + SUM(CASE WHEN BILL_AMT5 IS NULL THEN 1 ELSE 0 END)
  + SUM(CASE WHEN BILL_AMT6 IS NULL THEN 1 ELSE 0 END)
  + SUM(CASE WHEN PAY_AMT1 IS NULL THEN 1 ELSE 0 END)
  + SUM(CASE WHEN PAY_AMT2 IS NULL THEN 1 ELSE 0 END)
  + SUM(CASE WHEN PAY_AMT3 IS NULL THEN 1 ELSE 0 END)
  + SUM(CASE WHEN PAY_AMT4 IS NULL THEN 1 ELSE 0 END)
  + SUM(CASE WHEN PAY_AMT5 IS NULL THEN 1 ELSE 0 END)
  + SUM(CASE WHEN PAY_AMT6 IS NULL THEN 1 ELSE 0 END)
  + SUM(CASE WHEN default_payment_next_month IS NULL THEN 1 ELSE 0 END)
) FROM credit_raw
UNION ALL
SELECT 'default_1', SUM(default_payment_next_month) FROM credit_raw
UNION ALL
SELECT 'default_0', SUM(1 - default_payment_next_month) FROM credit_raw;
