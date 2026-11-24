# 信用卡違約預測 — Credit Default Prediction

UCI「Default of Credit Card Clients」數據集（台灣信用卡客戶，2005 年 4–9 月，30,000 行），目標係預測下個月有無違約。適用職位：銀行 Data Analyst、Credit Risk Analyst。對照文件：`../credit-default-project-skeleton/credit-default-project-skeleton.docx`（項目骨架，含 SQL 清洗清單、Power BI 規格、面試講法）。

> 提醒：這是 2005 年的台灣舊數據，只適合做作品集示範，不代表現時香港市場，亦不是任何銀行的真實授信模型。

## 檔案結構

```
credit-default-project/
├── data/
│   ├── raw/          # UCI 原始檔（已附上，唔使再下載）
│   └── processed/    # credit_features.csv（01 號筆記本產出）
├── notebooks/
│   ├── 01_eda.ipynb                  # 探索分析（已跑通）
│   └── 02_baseline_logistic.ipynb   # Logistic regression baseline（已跑通）
├── reports/
│   └── model_results.csv             # 模型結果表
└── README.md
```

## 點樣跑

1. 安裝需求：`pip install pandas scikit-learn matplotlib python-calamine`
   （pandas 較舊版本改用 `xlrd` 讀 `.xls`。）
2. 按順序跑 `01_eda.ipynb` → `02_baseline_logistic.ipynb`（Restart & Run All）。
3. 原始數據已放喺 `data/raw/`，唔使再下載；路徑會自動搵項目根目錄。

## 已跑出的結果（真實數據跑出，唔係預填）

- 整體違約率 **22.12%**（6,636 / 30,000），違約係少數類別。
- 最強訊號係還款延遲：最近月延遲 2 個月（PAY_0 = 2）的客戶違約率 **69.1%**，延遲 3 個月 **75.8%**；半年內最嚴重延遲 7 個月更高見 83.6%。
- 信用額度最低四分位違約率 31.8%，最高四分位 14.0%。
- Baseline（logistic regression，門檻 0.5，分層 80／20，random_state=42）：**AUC 0.7481、recall 0.3617、precision 0.6575、accuracy 0.8172**。
- `class_weight='balanced'` 比較：recall 升至 0.5848，precision 跌至 0.4491，AUC 0.7486——預期中的取捨。
- 係數方向大致與常識一致（延遲月數愈多，違約機會愈高）；但 `consecutive_delay` 呈負值，係因為同 `delay_months_cnt` 等欄位共線，面試講係數時要小心。

## 下一步（按骨架四星期節奏）

- [ ] `reports/findings.md` 初稿：3–5 個主要發現（01 號筆記本已有數字）
- [ ] `03_tree_models.ipynb`：random forest，之後先試 XGBoost（共用同一個測試集）
- [ ] SQL 五個檔（`01_create_raw.sql` 至 `05_validation.sql`）：骨架已有詳細清單 A–D
- [ ] Power BI 三頁 dashboard（讀 `credit_features.csv` 同 `model_results.csv`）
- [ ] README 定稿（GitHub 版大綱見骨架最後一節）
