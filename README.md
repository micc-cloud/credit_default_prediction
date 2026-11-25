# Credit Card Default Prediction

UCI "Default of Credit Card Clients" dataset (Taiwan credit card clients, April–September 2005, 30,000 rows). The goal is to predict whether a client will default next month. Target roles: Bank Data Analyst and Credit Risk Analyst. Companion document: `../credit-default-project-skeleton/credit-default-project-skeleton.docx` (project skeleton, with the SQL cleaning checklist, Power BI specification, and interview talking points).

> Note: This is old data from Taiwan in 2005. It is suitable only as a portfolio demonstration. It does not represent the current Hong Kong market, and it is not a real credit model used by any bank.

## Dataset

- Dataset: Default of Credit Card Clients, UCI Machine Learning Repository
- Dataset page: https://archive.ics.uci.edu/dataset/350/default+of+credit+card+clients
- DOI: https://doi.org/10.24432/C55S3H
- Direct download (.zip): https://archive.ics.uci.edu/static/public/350/default+of+credit+card+clients.zip
- Raw file is included in this repo at `raw data/Default of Credit Card Clients.xls` (uploaded 2026-11-26 via GitHub web, 2,867,294 bytes). Content verified identical to the local `data/raw/` copy (30,000 rows, cell-for-cell match, 2026-11-26); the .xls file size differs only due to Excel encoding. The UCI download links above remain the original source.
- Processed file `data/processed/credit_features.csv` is included in this repo

## File structure

```
credit-default-project/
├── data/
│   ├── raw/          # Not included in repo — download from UCI, see Dataset section
│   └── processed/    # credit_features.csv (output of notebook 01)
├── notebooks/
│   ├── 01_eda.ipynb                  # Exploratory analysis (runs clean)
│   └── 02_baseline_logistic.ipynb   # Logistic regression baseline (runs clean)
├── reports/
│   └── model_results.csv             # Model results table
├── sql/
│   ├── 01_create_raw.sql             # Load raw data into credit_raw
│   ├── 02_profile_checks.sql         # Read-only profiling checks
│   ├── 03_clean.sql                  # Build the cleaned table credit_clean
│   └── README.md                     # How to run DuckDB and the cleaning decisions
├── raw data/                         # Raw file uploaded by user via GitHub web on 2026-11-26 — see Dataset section
└── README.md
```

## How to run

1. Install the requirements: `pip install pandas scikit-learn matplotlib python-calamine`
   (On older pandas versions, use `xlrd` to read the `.xls` file.)
2. Run the notebooks in order: `01_eda.ipynb` → `02_baseline_logistic.ipynb` (Restart & Run All).
3. Download the raw .xls from UCI (see Dataset section) and place it in `data/raw/`. Paths are resolved automatically to the project root.

## Results (run on real data, not pre-filled)

- Overall default rate **22.12%** (6,636 / 30,000). Default is the minority class.
- The strongest signal is repayment delay: clients delayed by 2 months in the most recent month (PAY_0 = 2) had a default rate of **69.1%**, and those delayed by 3 months had a rate of **75.8%**; the worst delay of 7 months in six months reached 83.6%.
- The lowest credit-limit quartile had a default rate of 31.8%, compared with 14.0% in the highest quartile.
- Baseline (logistic regression, threshold 0.5, stratified 80/20 split, random_state=42): **AUC 0.7481, recall 0.3617, precision 0.6575, accuracy 0.8172**.
- `class_weight='balanced'` comparison: recall rose to 0.5848, while precision fell to 0.4491 and AUC was 0.7486 — the expected trade-off.
- Coefficient directions are broadly consistent with common sense (more delay months mean a higher chance of default). However, `consecutive_delay` has a negative coefficient because it is collinear with `delay_months_cnt` and related fields, so be careful when discussing coefficient directions in interviews.

## Next steps (following the four-week plan in the skeleton)

- [ ] First draft of `reports/findings.md`: 3–5 key findings (the figures are already in notebook 01)
- [ ] `03_tree_models.ipynb`: random forest, then XGBoost (using the same test set)
- [x] SQL `01_create_raw.sql` to `03_clean.sql` plus `sql/README.md`: done and tested (30,000 rows, default rate 22.12%)
- [ ] SQL `04_features.sql` and `05_validation.sql` plus `run_all.sql`: to be written after 01–03 are on GitHub
- [ ] Three-page Power BI dashboard (reading `credit_features.csv` and `model_results.csv`)
- [ ] Final README (see the GitHub outline in the last section of the skeleton)
