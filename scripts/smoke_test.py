"""Lightweight smoke test (defect 6).

Checks, in order: raw TSV loading + schema, feature generation,
SQL 01-03 (via scripts/validate_sql.py), and model execution
(a logistic-regression pipeline fitted on the training split only).

Usage (from the project root):
    python scripts/smoke_test.py

Full notebook execution is covered by the GitHub Actions workflow
(.github/workflows/smoke-test.yml), which runs both notebooks with
`jupyter nbconvert --execute` after this smoke test.
"""
import subprocess
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(PROJECT_ROOT / "src"))

import pandas as pd  # noqa: E402
from sklearn.compose import ColumnTransformer  # noqa: E402
from sklearn.impute import SimpleImputer  # noqa: E402
from sklearn.linear_model import LogisticRegression  # noqa: E402
from sklearn.metrics import roc_auc_score  # noqa: E402
from sklearn.model_selection import train_test_split  # noqa: E402
from sklearn.pipeline import Pipeline  # noqa: E402
from sklearn.preprocessing import OneHotEncoder, StandardScaler  # noqa: E402

from data_loading import assert_raw_schema, load_raw_tsv  # noqa: E402
from features import (  # noqa: E402
    CATEGORICAL_FEATURES, NUMERIC_FEATURES, assert_features_schema, build_features,
)


def main():
    print("1. Raw data loading + schema")
    df = load_raw_tsv(PROJECT_ROOT / "raw data" / "Default of Credit Card Clients.tsv")
    assert_raw_schema(df)
    print(f"   OK: shape {df.shape}, defaults {int((df['default_payment_next_month'] == 1).sum())}")

    print("2. Feature generation")
    features = build_features(df)
    assert_features_schema(features)
    print(f"   OK: shape {features.shape}")

    print("3. SQL 01-03 validation")
    res = subprocess.run(
        [sys.executable, str(PROJECT_ROOT / "scripts" / "validate_sql.py")],
        cwd=PROJECT_ROOT, capture_output=True, text=True)
    print(res.stdout)
    if res.returncode != 0:
        print(res.stderr)
        print("   FAIL: SQL validation failed")
        return 1
    print("   OK: SQL 01-03 passed")

    print("4. Model execution (logistic regression, train split only)")
    X = features[list(NUMERIC_FEATURES) + list(CATEGORICAL_FEATURES)].copy()
    y = features["default_payment_next_month"]
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.20, stratify=y, random_state=42)
    pipe = Pipeline([
        ("preprocess", ColumnTransformer([
            ("num", Pipeline([("imputer", SimpleImputer(strategy="median")),
                              ("scaler", StandardScaler())]), list(NUMERIC_FEATURES)),
            ("cat", OneHotEncoder(drop="first", handle_unknown="ignore", sparse_output=False),
             list(CATEGORICAL_FEATURES)),
        ])),
        ("clf", LogisticRegression(max_iter=1000, random_state=42)),
    ])
    pipe.fit(X_train, y_train)
    auc = roc_auc_score(y_test, pipe.predict_proba(X_test)[:, 1])
    print(f"   OK: test AUC {auc:.4f}")
    assert auc > 0.65, f"smoke-test AUC too low: {auc}"
    print("Smoke test passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
