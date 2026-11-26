# Credit Card Default Prediction

UCI "Default of Credit Card Clients" dataset (Taiwan credit card clients, April–September 2005, 30,000 rows). The goal is to predict whether a client will default next month. Target roles: Bank Data Analyst and Credit Risk Analyst. Project notes (repository-local summary of the plan, cleaning decisions, Power BI specification and interview talking points): `docs/project-notes.md`.

> Note: This is old data from Taiwan in 2005. It is suitable only as a portfolio demonstration. It does not represent the current Hong Kong market, and it is not a real credit model used by any bank.

## Dataset

- Dataset: Default of Credit Card Clients, UCI Machine Learning Repository
- Dataset page: https://archive.ics.uci.edu/dataset/350/default+of+credit+card+clients
- DOI: https://doi.org/10.24432/C55S3H
- Direct download (.zip): https://archive.ics.uci.edu/static/public/350/default+of+credit+card+clients.zip
- Raw file is included in this repo at `raw data/Default of Credit Card Clients.tsv` (uploaded 2026-11-26 via GitHub web, 2,867,294 bytes). **It is tab-separated ASCII text, not an Excel workbook** — it was uploaded with a `.xls` name, but that name is wrong and must not be used to describe it. Do not try to open it with an Excel reader (`calamine` / `xlrd` cannot read it). Load it with `pandas.read_csv(..., sep="\t", header=1)`; see `src/data_loading.py`. Content verified identical to the local genuine UCI `.xls` copy (30,000 rows, cell-for-cell match, 2026-11-26); the file-size difference is only due to Excel encoding. The UCI download links above remain the original source.
- The tracked file was renamed from `.xls` to `.tsv` to match its actual format. The old `.xls` name must be removed with `git rm` when this change is committed; the data itself was not deleted.
- Processed file `data/processed/credit_features.csv` is included in this repo (36 columns: the 34 columns from notebook 01 plus the two denominator flags `pay_ratio_1_denominator_le_0` and `pay_ratio_avg_denominator_le_0`; see `src/features.py`)

## File structure

```
credit-default-project/
├── data/
│   ├── raw/          # Local genuine UCI .xls only (ignored by git, not in the repo)
│   ├── interim/      # credit_raw.csv, generated from the TSV (ignored by git)
│   └── processed/    # credit_features.csv (output of notebook 01)
├── notebooks/
│   ├── 01_eda.ipynb                  # Exploratory analysis (runs clean)
│   └── 02_baseline_logistic.ipynb   # Logistic regression baseline (runs clean)
├── reports/
│   └── model_results.csv             # Model results table (CV rows + final-test row)
├── sql/
│   ├── 01_create_raw.sql             # Load raw data into credit_raw
│   ├── 02_profile_checks.sql         # Read-only profiling checks
│   ├── 03_clean.sql                  # Build the cleaned table credit_clean
│   └── README.md                     # How to run DuckDB and the cleaning decisions
├── src/
│   ├── data_loading.py               # Canonical TSV loader + raw schema assertions
│   └── features.py                   # Shared feature generation + denominator flags
├── scripts/
│   ├── validate_sql.py               # Enforceable SQL 01-03 validation (exits non-zero on FAIL)
│   └── smoke_test.py                 # Data, features, SQL 01-03 and model smoke test
├── docs/
│   └── project-notes.md              # Repository-local project notes
├── .github/workflows/smoke-test.yml  # CI: smoke test + both notebooks
├── requirements.txt                  # Pinned dependencies (Python 3.12)
├── raw data/                         # Tracked TSV raw file — see Dataset section
└── README.md
```

## How to run

1. Install the requirements: `pip install -r requirements.txt` (Python 3.12).
2. Validate the SQL layer: `python scripts/validate_sql.py` (exits non-zero if any documented invariant fails).
3. Run the notebooks in order: `01_eda.ipynb` → `02_baseline_logistic.ipynb` (Restart & Run All). No manual download is needed: a clean clone already contains the tracked TSV raw file, and the notebooks load it directly. Paths are resolved automatically to the project root.

## Results (run on real data, not pre-filled)

- Overall default rate **22.12%** (6,636 / 30,000). Default is the minority class.
- The strongest signal is repayment delay: clients delayed by 2 months in the most recent month (PAY_0 = 2) had a default rate of **69.1%**, and those delayed by 3 months had a rate of **75.8%**; the worst delay of 7 months in six months reached 83.6%.
- The lowest credit-limit quartile had a default rate of 31.8%, compared with 14.0% in the highest quartile.
- Model selection is by 5-fold cross-validation inside the training data only; the selected model is then evaluated once on the final test set. `reports/model_results.csv` labels CV rows and the final-test row separately — do not compare them as if they were the same thing.
- Cross-validation (train only, 5-fold, threshold 0.5): baseline **AUC 0.7692, recall 0.3692, precision 0.6605, accuracy 0.8185**; `class_weight='balanced'` **AUC 0.7700, recall 0.6125, precision 0.4699, accuracy 0.7613**. The balanced version was selected on CV AUC (0.7700 vs 0.7692).
- Final test, selected model only (`class_weight='balanced'`, threshold 0.5, stratified 80/20 split, random_state=42): **AUC 0.7539, recall 0.5818, precision 0.4555, accuracy 0.7537**.
- Intentional change vs the previous test metrics (2026-11-25: balanced AUC 0.7486, recall 0.5848, precision 0.4491, accuracy 0.7495): AUC +0.0053, precision +0.0064, recall −0.0030, accuracy +0.0042. The change comes from the corrected methodology — the two denominator flags are now model features, the imputer is fitted on training data only, and one-hot encoding drops the reference category. The underlying data and split are unchanged (30,000 rows, 6,636 defaults, same 80/20 split).
- Coefficients are conditional associations relative to each variable's reference category (`OneHotEncoder(drop="first")`), not independent causal effects. Delay features are strongly correlated, so individual coefficients are unstable: `consecutive_delay` can carry a negative coefficient even though delay itself raises default risk, because `delay_months_cnt` and related fields already carry most of that signal. Do not describe a single coefficient as "changing this one thing by itself causes this change in default risk".

## Next steps (following the four-week plan in `docs/project-notes.md`)

- [ ] First draft of `reports/findings.md`: 3–5 key findings (the figures are already in notebook 01)
- [ ] `03_tree_models.ipynb`: random forest, then XGBoost (using the same test set)
- [x] SQL `01_create_raw.sql` to `03_clean.sql` plus `sql/README.md`: done and tested (30,000 rows, default rate 22.12%)
- [ ] SQL `04_features.sql` and `05_validation.sql` plus `run_all.sql`: to be written after 01–03 are on GitHub
- [ ] Three-page Power BI dashboard (reading `credit_features.csv` and `model_results.csv`)
- [ ] Final README polish (results section updated from the regenerated `reports/model_results.csv`)
