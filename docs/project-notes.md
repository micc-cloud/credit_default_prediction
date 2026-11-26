# Project notes (repository-local)

This document is the repository-local replacement for the former
external skeleton reference (`../credit-default-project-skeleton/...`,
which is not in this repository). It summarises only material that
already exists in this repository; it invents no new requirements.

## Goal

Predict whether a Taiwan credit-card client will default next month,
using the UCI "Default of Credit Card Clients" dataset (30,000 rows,
April–September 2005). The finished project is a portfolio piece for
Bank Data Analyst and Credit Risk Analyst interviews.

## Dataset

- UCI page: https://archive.ics.uci.edu/dataset/350/default+of+credit+card+clients
- DOI: https://doi.org/10.24432/C55S3H
- Direct download (.zip): https://archive.ics.uci.edu/static/public/350/default+of+credit+card+clients.zip
- Tracked raw file: `raw data/Default of Credit Card Clients.tsv`
  (tab-separated text, not an Excel workbook — see README.md, Dataset
  section). Load with `pandas.read_csv(..., sep="\t", header=1)`.
- This is 2005 Taiwan data, for portfolio demonstration only. It does
  not represent the current Hong Kong market.

## Cleaning decisions (see sql/README.md for the full list)

- EDUCATION 0 / 5 / 6 and MARRIAGE 0 are merged into "Others / Unknown",
  not deleted. Both the original code and the label are kept.
- PAY -2 / -1 / 0 are status codes, not delays; delay months are
  -2 / -1 / 0 -> 0, 1–9 unchanged. Original PAY columns are kept.
- Negative BILL_AMT values are flagged (`has_negative_bill_amt`,
  `negative_bill_months_cnt`), not deleted.
- PAY_AMT 0 is kept (no repayment that month is itself a signal).
- No rows are deleted. Row count stays 30,000; defaults stay 6,636 (22.12%).

## Features (see src/features.py)

Derived features include utilisation, pay ratios, worst / count /
consecutive delay months, and bill trend. `pay_ratio_1` and
`pay_ratio_avg` are missing when their denominator is non-positive,
and the fact is carried in the flags
`pay_ratio_1_denominator_le_0` and `pay_ratio_avg_denominator_le_0`
(pre-imputation missing counts 2,598 and 1,071).

## Modelling (see notebooks/02_baseline_logistic.ipynb)

- Stratified 80/20 split, `random_state=42`.
- `SimpleImputer(strategy="median")` inside the numeric pipeline,
  fitted only on training data.
- One-hot encoding with `drop="first"`; coefficients are relative to
  the dropped reference category and are conditional associations,
  not independent causal effects. Correlated delay features make
  individual coefficients unstable.
- Model choice by 5-fold cross-validation inside the training data;
  the selected model is evaluated once on the final test set.

## Power BI (roadmap, not yet built)

Three pages, as specified in the project plan: P1 overall overview,
P2 repayment behaviour and risk, P3 model performance and prediction
(including the model results table and the predicted-probability
distribution). Power BI reads `data/processed/credit_features.csv`
and `reports/model_results.csv`.

## Interview talking points (already in README.md)

- Default is the minority class (22.12%): report AUC, recall and
  precision together with accuracy.
- Delay is the strongest signal; the most recent month matters most.
- `consecutive_delay` can carry a negative coefficient because it is
  collinear with other delay features — explain the correlation,
  do not present the coefficient as a causal effect.
- The data are from 2005 Taiwan; do not present the model as a
  current or production credit model.
