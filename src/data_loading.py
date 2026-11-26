"""Canonical raw-data loading.

Canonical workflow (defect 1): the tracked raw file is TAB-SEPARATED TEXT,
not an Excel workbook, even though it was uploaded with a ``.xls`` name.
Its canonical name in the repo is::

    raw data/Default of Credit Card Clients.tsv

Load it with ``pandas.read_csv(..., sep="\t", header=1)``.  The first row
holds X1..X23 / Y; the real column names are in the second row
(``header=1``).  There is no Excel reader in this workflow, so
``python-calamine`` / ``xlrd`` are not required.

A genuine UCI ``.xls`` (OLE workbook, 5,539,328 bytes locally) contains the
same data cell-for-cell (verified 2026-11-26, 30,000 rows), but it is NOT
the tracked file and is NOT needed to reproduce this project.
"""

from pathlib import Path

import pandas as pd

RAW_TSV_NAME = "Default of Credit Card Clients.tsv"
RAW_TSV_DIR = "raw data"

EXPECTED_COLUMNS = [
    "ID", "LIMIT_BAL", "SEX", "EDUCATION", "MARRIAGE", "AGE",
    "PAY_0", "PAY_2", "PAY_3", "PAY_4", "PAY_5", "PAY_6",
    "BILL_AMT1", "BILL_AMT2", "BILL_AMT3", "BILL_AMT4", "BILL_AMT5", "BILL_AMT6",
    "PAY_AMT1", "PAY_AMT2", "PAY_AMT3", "PAY_AMT4", "PAY_AMT5", "PAY_AMT6",
    "default_payment_next_month",
]
TARGET = "default_payment_next_month"


def find_project_root(start=None):
    """Return the project root (the directory containing ``raw data/``)."""
    start = Path(start or Path.cwd())
    for cand in [start, start.parent, *start.parents]:
        if (cand / RAW_TSV_DIR / RAW_TSV_NAME).exists():
            return cand
    return start.parent


def load_raw_tsv(path):
    """Load the tracked TSV and rename the target column."""
    df = pd.read_csv(path, sep="\t", header=1)
    df = df.rename(columns={"default payment next month": TARGET})
    return df


def assert_raw_schema(df):
    """Schema assertions for the raw data (defect 1).

    Raises AssertionError with a clear message on any failure.
    """
    assert df.shape == (30_000, 25), f"raw shape must be (30000, 25), got {df.shape}"
    assert list(df.columns) == EXPECTED_COLUMNS, (
        f"raw columns differ: {list(df.columns)}"
    )
    assert df["ID"].is_unique, "ID must be unique"
    assert int(df.isna().sum().sum()) == 0, "raw data must have zero nulls"
    assert set(df[TARGET].dropna().unique()) == {0, 1}, "target must be {0, 1}"
    assert int((df[TARGET] == 1).sum()) == 6_636, (
        f"defaults must be 6636, got {int((df[TARGET] == 1).sum())}"
    )
    return True


def write_interim_csv(df, project_root):
    """Write the one-off interim CSV used by SQL 01 (see sql/README.md)."""
    out = Path(project_root) / "data" / "interim" / "credit_raw.csv"
    out.parent.mkdir(parents=True, exist_ok=True)
    df.to_csv(out, index=False)
    return out
