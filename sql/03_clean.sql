-- ============================================================================
-- 03_clean.sql — Build the cleaned table credit_clean
-- Project: Credit Card Default Prediction
-- Dialect: DuckDB (single local file: data/credit_default.duckdb)
-- Approval: SQL technical proposal v2 approved by the user on 2026-11-25 23:12.
--           Approved for push 2026-11-26 (overnight Part 1): Jensen review passed; user waived per-file approval for this batch only.
--
-- What this file does (the core cleaning list, see sql/README.md):
--   Build credit_clean from credit_raw. All transformations happen here.
--   credit_raw is never modified. No rows are deleted.
--
-- Cleaning decisions (each with its reason — if there is no comment, the
-- decision cannot be defended in an interview):
--
--   1. EDUCATION — unknown codes merged, not deleted.
--      Known: 1 = graduate school, 2 = university, 3 = high school,
--      4 = others. Found in profiling (02): 0 (14 rows), 5 (280), 6 (51).
--      These are unknown / not stated. They are merged into 4
--      ("Others / Unknown"). Deleting them would shrink the sample for no
--      reason and could introduce bias. Both the code and the label are
--      kept: education_code (1–4) and education_label.
--      Expected: education_code 4 = 123 + 14 + 280 + 51 = 468 rows.
--
--   2. MARRIAGE — unknown code merged, not deleted.
--      Known: 1 = married, 2 = single, 3 = others. Found in profiling (02):
--      0 (54 rows). Code 0 is treated as unknown and merged into 3
--      ("Others / Unknown"), the same way as EDUCATION. Both the code and
--      the label are kept: marriage_code (1–3) and marriage_label.
--      Expected: marriage_code 3 = 323 + 54 = 377 rows.
--
--   3. PAY_0, PAY_2–PAY_6 — status codes kept, delay months added.
--      Scale: -2 = no consumption, -1 = paid duly, 0 = revolving credit,
--      1–9 = delayed by that many months. -2 / -1 / 0 are status codes,
--      not delays. The original columns are NOT overwritten.
--      A new column is added for each month (pay_*_delay_months):
--      -2 / -1 / 0 -> 0 months, 1–9 unchanged.
--      Note: there is no PAY_1. PAY_0 is Sep 2005 (most recent) and PAY_6
--      is Apr 2005 (earliest). Do not reverse this order.
--
--   4. BILL_AMT1–BILL_AMT6 — negative values flagged, not deleted.
--      A negative bill may come from a refund or an adjustment and should
--      be confirmed with the business. In this portfolio it is kept and
--      flagged ("flag first, do not delete directly").
--      Two columns are added (Jensen v2 decision):
--        has_negative_bill_amt (0/1): 1 if any of BILL_AMT1–BILL_AMT6 < 0.
--        negative_bill_months_cnt (0–6): how many of the six months < 0.
--      Expected (verified against pandas): has_negative_bill_amt = 1 for
--      1,930 rows, 0 for 28,070 rows; counts by month count are
--      0: 28,070, 1: 993, 2: 412, 3: 240, 4: 118, 5: 79, 6: 88.
--
--   5. PAY_AMT1–PAY_AMT6 — 0 is kept.
--      0 means no repayment was recorded that month. It is itself a risk
--      signal (a bill exists but no repayment). The derived features in
--      04_features.sql use it. No change is made here.
--
--   6. LIMIT_BAL, AGE — range-checked only (see 02).
--      AGE 21–79, LIMIT_BAL 10,000–1,000,000. There is no clear evidence
--      of an error, so nothing is deleted or changed.
--
--   7. SEX, ID, default_payment_next_month — unchanged.
--      The target column is never touched by cleaning; the default rate
--      must be identical before and after cleaning (22.12%).
--
-- Row count: credit_clean must have exactly 30,000 rows, the same as
-- credit_raw. Any removal would have to be documented with a count and a
-- reason. There is none here.
-- ============================================================================

CREATE OR REPLACE TABLE credit_clean AS
SELECT
    ID,
    LIMIT_BAL,
    SEX,
    -- Original codes, kept for audit trail.
    EDUCATION AS education_original,
    MARRIAGE AS marriage_original,
    -- 1. EDUCATION: unknown codes 0 / 5 / 6 merged into 4.
    CASE WHEN EDUCATION IN (1, 2, 3) THEN EDUCATION ELSE 4 END AS education_code,
    CASE EDUCATION
        WHEN 1 THEN 'Graduate school'
        WHEN 2 THEN 'University'
        WHEN 3 THEN 'High school'
        ELSE 'Others / Unknown'
    END AS education_label,
    -- 2. MARRIAGE: unknown code 0 merged into 3.
    CASE WHEN MARRIAGE IN (1, 2) THEN MARRIAGE ELSE 3 END AS marriage_code,
    CASE MARRIAGE
        WHEN 1 THEN 'Married'
        WHEN 2 THEN 'Single'
        ELSE 'Others / Unknown'
    END AS marriage_label,
    AGE,
    -- 3. PAY columns: originals kept unchanged.
    PAY_0,
    PAY_2,
    PAY_3,
    PAY_4,
    PAY_5,
    PAY_6,
    -- 3. PAY columns: delay months (-2 / -1 / 0 -> 0, 1–9 unchanged).
    CASE WHEN PAY_0 < 0 THEN 0 ELSE PAY_0 END AS pay_0_delay_months,
    CASE WHEN PAY_2 < 0 THEN 0 ELSE PAY_2 END AS pay_2_delay_months,
    CASE WHEN PAY_3 < 0 THEN 0 ELSE PAY_3 END AS pay_3_delay_months,
    CASE WHEN PAY_4 < 0 THEN 0 ELSE PAY_4 END AS pay_4_delay_months,
    CASE WHEN PAY_5 < 0 THEN 0 ELSE PAY_5 END AS pay_5_delay_months,
    CASE WHEN PAY_6 < 0 THEN 0 ELSE PAY_6 END AS pay_6_delay_months,
    -- 4. BILL_AMT columns: unchanged (negative values kept, flagged below).
    BILL_AMT1,
    BILL_AMT2,
    BILL_AMT3,
    BILL_AMT4,
    BILL_AMT5,
    BILL_AMT6,
    -- 4. BILL_AMT negative flags (Jensen v2: added here, carried to 04).
    CASE
        WHEN BILL_AMT1 < 0 OR BILL_AMT2 < 0 OR BILL_AMT3 < 0
          OR BILL_AMT4 < 0 OR BILL_AMT5 < 0 OR BILL_AMT6 < 0
        THEN 1 ELSE 0
    END AS has_negative_bill_amt,
    (CASE WHEN BILL_AMT1 < 0 THEN 1 ELSE 0 END
   + CASE WHEN BILL_AMT2 < 0 THEN 1 ELSE 0 END
   + CASE WHEN BILL_AMT3 < 0 THEN 1 ELSE 0 END
   + CASE WHEN BILL_AMT4 < 0 THEN 1 ELSE 0 END
   + CASE WHEN BILL_AMT5 < 0 THEN 1 ELSE 0 END
   + CASE WHEN BILL_AMT6 < 0 THEN 1 ELSE 0 END) AS negative_bill_months_cnt,
    -- 5. PAY_AMT columns: unchanged (0 kept — no repayment that month).
    PAY_AMT1,
    PAY_AMT2,
    PAY_AMT3,
    PAY_AMT4,
    PAY_AMT5,
    PAY_AMT6,
    -- 7. Target: unchanged.
    default_payment_next_month
FROM credit_raw;

-- Post-cleaning spot checks (must all pass before moving to 04_features.sql):
--   row_count = 30,000 in both tables; default_1 = 6,636 in both tables;
--   education_code 4 = 468; marriage_code 3 = 377;
--   has_negative_bill_amt = 1 for 1,930 rows.
SELECT 'clean_row_count' AS check_name, COUNT(*) AS value FROM credit_clean
UNION ALL
SELECT 'raw_row_count', COUNT(*) FROM credit_raw
UNION ALL
SELECT 'clean_default_1', SUM(default_payment_next_month) FROM credit_clean
UNION ALL
SELECT 'raw_default_1', SUM(default_payment_next_month) FROM credit_raw
UNION ALL
SELECT 'education_code_4', COUNT(*) FROM credit_clean WHERE education_code = 4
UNION ALL
SELECT 'marriage_code_3', COUNT(*) FROM credit_clean WHERE marriage_code = 3
UNION ALL
SELECT 'has_negative_bill_amt_1', COUNT(*) FROM credit_clean WHERE has_negative_bill_amt = 1;
