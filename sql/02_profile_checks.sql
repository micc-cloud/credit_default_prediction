-- ============================================================================
-- 02_profile_checks.sql — Read-only profiling of credit_raw
-- Project: Credit Card Default Prediction
-- Dialect: DuckDB (single local file: data/credit_default.duckdb)
-- Approval: SQL technical proposal v2 approved by the user on 2026-11-25 23:12.
--           Approved for push 2026-11-26 (overnight Part 1): Jensen review passed; user waived per-file approval for this batch only.
--
-- What this file does:
--   Profile credit_raw BEFORE any cleaning (see sql/README.md).
--   Read the results first; do not rush to change anything.
--
-- What this file does NOT do:
--   - No CREATE, INSERT, UPDATE, DELETE, or ALTER. This file is read-only.
--     It creates no tables and changes no data. Run it as many times as
--     needed; the results must not change.
--
-- Checks (in order):
--   A. Row count, ID uniqueness, fully duplicated rows.
--   B. Missing values per column (this dataset has few surface nulls, but
--      unknown categories are hidden inside the codes — see section C).
--   C. Distinct values for every categorical column: SEX, EDUCATION,
--      MARRIAGE, and the six PAY columns.
--   D. Min / max / average for numeric columns: LIMIT_BAL, AGE,
--      BILL_AMT1–BILL_AMT6, PAY_AMT1–PAY_AMT6. Note negative BILL_AMT and
--      zero PAY_AMT here; record them, do not delete them yet.
--   E. Target distribution: default = 1 is the minority class.
--
-- Expected results (verified against the pandas version, notebook 01):
--   - Row count 30,000; ID unique 30,000; fully duplicated rows 0.
--   - Missing values 0 in every column.
--   - EDUCATION: 0 (14), 1 (10,585), 2 (14,030), 3 (4,917), 4 (123),
--     5 (280), 6 (51). Codes 0 / 5 / 6 are unknown.
--   - MARRIAGE: 0 (54), 1 (13,659), 2 (15,964), 3 (323). Code 0 is unknown.
--   - SEX: 1 (11,888), 2 (18,112).
--   - PAY_0: -2 (2,759), -1 (5,686), 0 (14,737), 1 (3,688), 2 (2,667),
--     3 (322), 4 (76), 5 (26), 6 (11), 7 (9), 8 (19).
--   - AGE: 21–79. LIMIT_BAL: 10,000–1,000,000.
--   - BILL_AMT1 minimum is negative (-165,580); PAY_AMT1 is 0 for 5,249 rows.
--   - Target: default = 1 is 6,636 rows (22.12%), default = 0 is 23,364 rows.
-- ============================================================================

-- A. Row count, ID uniqueness, fully duplicated rows.
SELECT 'total_rows' AS check_name, COUNT(*) AS value FROM credit_raw
UNION ALL
SELECT 'distinct_id', COUNT(DISTINCT ID) FROM credit_raw
UNION ALL
SELECT 'distinct_rows', COUNT(*) FROM (SELECT DISTINCT * FROM credit_raw);

-- B. Missing values per column (0 expected in every column).
SELECT 'missing_ID' AS check_name, SUM(CASE WHEN ID IS NULL THEN 1 ELSE 0 END) AS value FROM credit_raw
UNION ALL SELECT 'missing_LIMIT_BAL', SUM(CASE WHEN LIMIT_BAL IS NULL THEN 1 ELSE 0 END) FROM credit_raw
UNION ALL SELECT 'missing_SEX', SUM(CASE WHEN SEX IS NULL THEN 1 ELSE 0 END) FROM credit_raw
UNION ALL SELECT 'missing_EDUCATION', SUM(CASE WHEN EDUCATION IS NULL THEN 1 ELSE 0 END) FROM credit_raw
UNION ALL SELECT 'missing_MARRIAGE', SUM(CASE WHEN MARRIAGE IS NULL THEN 1 ELSE 0 END) FROM credit_raw
UNION ALL SELECT 'missing_AGE', SUM(CASE WHEN AGE IS NULL THEN 1 ELSE 0 END) FROM credit_raw
UNION ALL SELECT 'missing_PAY_0', SUM(CASE WHEN PAY_0 IS NULL THEN 1 ELSE 0 END) FROM credit_raw
UNION ALL SELECT 'missing_PAY_2', SUM(CASE WHEN PAY_2 IS NULL THEN 1 ELSE 0 END) FROM credit_raw
UNION ALL SELECT 'missing_PAY_3', SUM(CASE WHEN PAY_3 IS NULL THEN 1 ELSE 0 END) FROM credit_raw
UNION ALL SELECT 'missing_PAY_4', SUM(CASE WHEN PAY_4 IS NULL THEN 1 ELSE 0 END) FROM credit_raw
UNION ALL SELECT 'missing_PAY_5', SUM(CASE WHEN PAY_5 IS NULL THEN 1 ELSE 0 END) FROM credit_raw
UNION ALL SELECT 'missing_PAY_6', SUM(CASE WHEN PAY_6 IS NULL THEN 1 ELSE 0 END) FROM credit_raw
UNION ALL SELECT 'missing_BILL_AMT1', SUM(CASE WHEN BILL_AMT1 IS NULL THEN 1 ELSE 0 END) FROM credit_raw
UNION ALL SELECT 'missing_BILL_AMT2', SUM(CASE WHEN BILL_AMT2 IS NULL THEN 1 ELSE 0 END) FROM credit_raw
UNION ALL SELECT 'missing_BILL_AMT3', SUM(CASE WHEN BILL_AMT3 IS NULL THEN 1 ELSE 0 END) FROM credit_raw
UNION ALL SELECT 'missing_BILL_AMT4', SUM(CASE WHEN BILL_AMT4 IS NULL THEN 1 ELSE 0 END) FROM credit_raw
UNION ALL SELECT 'missing_BILL_AMT5', SUM(CASE WHEN BILL_AMT5 IS NULL THEN 1 ELSE 0 END) FROM credit_raw
UNION ALL SELECT 'missing_BILL_AMT6', SUM(CASE WHEN BILL_AMT6 IS NULL THEN 1 ELSE 0 END) FROM credit_raw
UNION ALL SELECT 'missing_PAY_AMT1', SUM(CASE WHEN PAY_AMT1 IS NULL THEN 1 ELSE 0 END) FROM credit_raw
UNION ALL SELECT 'missing_PAY_AMT2', SUM(CASE WHEN PAY_AMT2 IS NULL THEN 1 ELSE 0 END) FROM credit_raw
UNION ALL SELECT 'missing_PAY_AMT3', SUM(CASE WHEN PAY_AMT3 IS NULL THEN 1 ELSE 0 END) FROM credit_raw
UNION ALL SELECT 'missing_PAY_AMT4', SUM(CASE WHEN PAY_AMT4 IS NULL THEN 1 ELSE 0 END) FROM credit_raw
UNION ALL SELECT 'missing_PAY_AMT5', SUM(CASE WHEN PAY_AMT5 IS NULL THEN 1 ELSE 0 END) FROM credit_raw
UNION ALL SELECT 'missing_PAY_AMT6', SUM(CASE WHEN PAY_AMT6 IS NULL THEN 1 ELSE 0 END) FROM credit_raw
UNION ALL SELECT 'missing_target', SUM(CASE WHEN default_payment_next_month IS NULL THEN 1 ELSE 0 END) FROM credit_raw;

-- C1. Distinct values: SEX.
SELECT SEX, COUNT(*) AS n FROM credit_raw GROUP BY SEX ORDER BY SEX;

-- C2. Distinct values: EDUCATION (expect 0, 5, 6 as unknown codes).
SELECT EDUCATION, COUNT(*) AS n FROM credit_raw GROUP BY EDUCATION ORDER BY EDUCATION;

-- C3. Distinct values: MARRIAGE (expect 0 as unknown code).
SELECT MARRIAGE, COUNT(*) AS n FROM credit_raw GROUP BY MARRIAGE ORDER BY MARRIAGE;

-- C4. Distinct values: PAY_0 (most recent month, Sep 2005).
SELECT PAY_0, COUNT(*) AS n FROM credit_raw GROUP BY PAY_0 ORDER BY PAY_0;

-- C5. Distinct values: PAY_2.
SELECT PAY_2, COUNT(*) AS n FROM credit_raw GROUP BY PAY_2 ORDER BY PAY_2;

-- C6. Distinct values: PAY_3.
SELECT PAY_3, COUNT(*) AS n FROM credit_raw GROUP BY PAY_3 ORDER BY PAY_3;

-- C7. Distinct values: PAY_4.
SELECT PAY_4, COUNT(*) AS n FROM credit_raw GROUP BY PAY_4 ORDER BY PAY_4;

-- C8. Distinct values: PAY_5.
SELECT PAY_5, COUNT(*) AS n FROM credit_raw GROUP BY PAY_5 ORDER BY PAY_5;

-- C9. Distinct values: PAY_6 (earliest month, Apr 2005).
SELECT PAY_6, COUNT(*) AS n FROM credit_raw GROUP BY PAY_6 ORDER BY PAY_6;

-- D1. Numeric summary: LIMIT_BAL and AGE.
SELECT
    MIN(LIMIT_BAL) AS limit_bal_min,
    MAX(LIMIT_BAL) AS limit_bal_max,
    ROUND(AVG(LIMIT_BAL), 2) AS limit_bal_avg,
    MIN(AGE) AS age_min,
    MAX(AGE) AS age_max,
    ROUND(AVG(AGE), 2) AS age_avg
FROM credit_raw;

-- D2. Numeric summary: BILL_AMT1–BILL_AMT6.
-- Note negative values (e.g. BILL_AMT1 minimum -165,580): record, do not delete.
SELECT
    MIN(BILL_AMT1) AS bill_amt1_min, MAX(BILL_AMT1) AS bill_amt1_max, ROUND(AVG(BILL_AMT1), 2) AS bill_amt1_avg,
    MIN(BILL_AMT2) AS bill_amt2_min, MAX(BILL_AMT2) AS bill_amt2_max, ROUND(AVG(BILL_AMT2), 2) AS bill_amt2_avg,
    MIN(BILL_AMT3) AS bill_amt3_min, MAX(BILL_AMT3) AS bill_amt3_max, ROUND(AVG(BILL_AMT3), 2) AS bill_amt3_avg,
    MIN(BILL_AMT4) AS bill_amt4_min, MAX(BILL_AMT4) AS bill_amt4_max, ROUND(AVG(BILL_AMT4), 2) AS bill_amt4_avg,
    MIN(BILL_AMT5) AS bill_amt5_min, MAX(BILL_AMT5) AS bill_amt5_max, ROUND(AVG(BILL_AMT5), 2) AS bill_amt5_avg,
    MIN(BILL_AMT6) AS bill_amt6_min, MAX(BILL_AMT6) AS bill_amt6_max, ROUND(AVG(BILL_AMT6), 2) AS bill_amt6_avg
FROM credit_raw;

-- D3. Numeric summary: PAY_AMT1–PAY_AMT6.
-- Note: 0 is a common value (no repayment recorded that month). Keep it.
SELECT
    MIN(PAY_AMT1) AS pay_amt1_min, MAX(PAY_AMT1) AS pay_amt1_max, ROUND(AVG(PAY_AMT1), 2) AS pay_amt1_avg,
    MIN(PAY_AMT2) AS pay_amt2_min, MAX(PAY_AMT2) AS pay_amt2_max, ROUND(AVG(PAY_AMT2), 2) AS pay_amt2_avg,
    MIN(PAY_AMT3) AS pay_amt3_min, MAX(PAY_AMT3) AS pay_amt3_max, ROUND(AVG(PAY_AMT3), 2) AS pay_amt3_avg,
    MIN(PAY_AMT4) AS pay_amt4_min, MAX(PAY_AMT4) AS pay_amt4_max, ROUND(AVG(PAY_AMT4), 2) AS pay_amt4_avg,
    MIN(PAY_AMT5) AS pay_amt5_min, MAX(PAY_AMT5) AS pay_amt5_max, ROUND(AVG(PAY_AMT5), 2) AS pay_amt5_avg,
    MIN(PAY_AMT6) AS pay_amt6_min, MAX(PAY_AMT6) AS pay_amt6_max, ROUND(AVG(PAY_AMT6), 2) AS pay_amt6_avg
FROM credit_raw;

-- D4. Negative bill amounts and zero repayments (counts only, no deletion).
SELECT 'negative_bill_amt1_rows' AS check_name, COUNT(*) AS value FROM credit_raw WHERE BILL_AMT1 < 0
UNION ALL SELECT 'zero_pay_amt1_rows', COUNT(*) FROM credit_raw WHERE PAY_AMT1 = 0
UNION ALL SELECT 'negative_bill_any_month_rows', COUNT(*) FROM credit_raw
    WHERE BILL_AMT1 < 0 OR BILL_AMT2 < 0 OR BILL_AMT3 < 0
       OR BILL_AMT4 < 0 OR BILL_AMT5 < 0 OR BILL_AMT6 < 0;

-- E. Target distribution: default is the minority class (22.12%).
SELECT
    default_payment_next_month,
    COUNT(*) AS n,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct
FROM credit_raw
GROUP BY default_payment_next_month
ORDER BY default_payment_next_month;
