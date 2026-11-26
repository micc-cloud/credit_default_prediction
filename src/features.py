"""Feature generation shared by notebook 01, notebook 02 and the smoke test.

Single source of truth for the derived features, so the notebook, the
model and the tests cannot drift apart.  Definitions match the SQL
cleaning layer (sql/README.md) where they overlap.

Defect 3: ``pay_ratio_1`` and ``pay_ratio_avg`` keep their ratio as
missing when the denominator is non-positive, and the fact is carried
explicitly in two flag columns::

    pay_ratio_1_denominator_le_0   (1 when BILL_AMT1 <= 0)
    pay_ratio_avg_denominator_le_0 (1 when sum(BILL_AMT1..6) <= 0)

The flags are part of ``credit_features.csv`` and of the model feature
list.  Their sums must equal the pre-imputation missing counts
(2,598 and 1,071 respectively).

NOTE: the BILL_AMT negative flags (``has_negative_bill_amt`` /
``negative_bill_months_cnt``) live in SQL 03_clean.sql and are carried
into the future SQL 04_features.sql.  They are NOT in this pandas
feature table yet; adding them here is a roadmap item, not part of
this fix.
"""

import numpy as np
import pandas as pd

PAY_COLS = ["PAY_0", "PAY_2", "PAY_3", "PAY_4", "PAY_5", "PAY_6"]
BILL_COLS = [f"BILL_AMT{i}" for i in range(1, 7)]
PAY_AMT_COLS = [f"PAY_AMT{i}" for i in range(1, 7)]
TARGET = "default_payment_next_month"

EDU_LABEL = {1: "Graduate school", 2: "University", 3: "High school", 4: "Others / Unknown"}
MAR_LABEL = {1: "Married", 2: "Single", 3: "Others / Unknown"}

NUMERIC_FEATURES = (
    ["LIMIT_BAL", "AGE"]
    + BILL_COLS
    + PAY_AMT_COLS
    + ["pay_0_delay_months", "pay_2_delay_months", "pay_3_delay_months",
       "pay_4_delay_months", "pay_5_delay_months", "pay_6_delay_months"]
    + ["utilisation_1", "pay_ratio_1", "pay_ratio_avg",
       "pay_ratio_1_denominator_le_0", "pay_ratio_avg_denominator_le_0",
       "max_delay_6m", "delay_months_cnt", "consecutive_delay", "bill_trend"]
)
CATEGORICAL_FEATURES = ["SEX", "education_label", "marriage_label"]


def build_features(df):
    """Build the 36-column feature table from the raw dataframe."""
    delay = df[PAY_COLS].clip(lower=0)
    delay.columns = [c.lower() + "_delay_months" for c in PAY_COLS]

    edu_code = df["EDUCATION"].where(df["EDUCATION"].isin([1, 2, 3]), 4)
    mar_code = df["MARRIAGE"].where(df["MARRIAGE"].isin([1, 2]), 3)

    features = pd.DataFrame({
        "ID": df["ID"],
        "LIMIT_BAL": df["LIMIT_BAL"],
        "SEX": df["SEX"],
        "education_code": edu_code,
        "education_label": edu_code.map(EDU_LABEL),
        "marriage_code": mar_code,
        "marriage_label": mar_code.map(MAR_LABEL),
        "AGE": df["AGE"],
        **{c: df[c] for c in BILL_COLS},
        **{c: df[c] for c in PAY_AMT_COLS},
        **delay.to_dict("series"),
        TARGET: df[TARGET],
    })

    features["utilisation_1"] = np.where(
        features["LIMIT_BAL"] > 0, features["BILL_AMT1"] / features["LIMIT_BAL"], np.nan)
    features["pay_ratio_1"] = np.where(
        features["BILL_AMT1"] > 0, features["PAY_AMT1"] / features["BILL_AMT1"], np.nan)
    bill_total = features[BILL_COLS].sum(axis=1)
    pay_total = features[PAY_AMT_COLS].sum(axis=1)
    features["pay_ratio_avg"] = np.where(bill_total > 0, pay_total / bill_total, np.nan)

    # Defect 3 flags: explicit, 0/1, carried into the model.
    features["pay_ratio_1_denominator_le_0"] = (features["BILL_AMT1"] <= 0).astype(int)
    features["pay_ratio_avg_denominator_le_0"] = (bill_total <= 0).astype(int)

    delay_cols = list(delay.columns)
    features["max_delay_6m"] = features[delay_cols].max(axis=1)
    features["delay_months_cnt"] = (features[delay_cols] >= 1).sum(axis=1)

    consec = []
    for _, row in features[delay_cols].iterrows():
        n = 0
        for v in row:
            if v >= 1:
                n += 1
            else:
                break
        consec.append(n)
    features["consecutive_delay"] = consec
    features["bill_trend"] = features["BILL_AMT1"] - features["BILL_AMT6"]
    return features


def assert_features_schema(features):
    """Assertions for the generated feature table (defects 1 and 3)."""
    assert features.shape == (30_000, 36), (
        f"credit_features shape must be (30000, 36), got {features.shape}"
    )
    assert int(features["pay_ratio_1"].isna().sum()) == 2_598, (
        f"pay_ratio_1 missing must be 2598, got {int(features['pay_ratio_1'].isna().sum())}"
    )
    assert int(features["pay_ratio_avg"].isna().sum()) == 1_071, (
        f"pay_ratio_avg missing must be 1071, got {int(features['pay_ratio_avg'].isna().sum())}"
    )
    assert int(features["utilisation_1"].isna().sum()) == 0, "utilisation_1 missing must be 0"
    assert int(features["pay_ratio_1_denominator_le_0"].sum()) == 2_598
    assert int(features["pay_ratio_avg_denominator_le_0"].sum()) == 1_071
    assert features["ID"].is_unique
    return True
