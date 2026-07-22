# Python Notebook — Loan Default Model

The modeling engine of the project. Takes the raw HMEQ file, cleans it, trains and
compares five classifiers, explains the winner with SHAP, and exports everything the
Power BI dashboard and SQL layer are built on.

Two notebooks live here:

- `Loan-default-prediction.ipynb` — the original build (v1).
- `Loan-default-prediction_v2.ipynb` — the current model, rebuilt after the SQL layer
  surfaced a signal v1 was throwing away. Recall 69.3% → **81.5%**.

GitHub renders both inline — charts, tables, and SHAP plots included. No setup needed to read them.

## The problem, and the metric that follows from it

HMEQ is 5,960 home equity loans with 13 fields and a binary target: did this loan
default. About 20% did.

The costs are asymmetric. A missed defaulter is a loan written off. A false positive is
a good application declined — real, but recoverable. So the model is tuned for
**Recall**: of all the borrowers who actually defaulted, how many did we catch. Accuracy
would be the wrong target here; a model that predicts "no default" every time scores 80%
accuracy and is worthless.

## Preparation

- **Outliers** — IQR capping, deliberately excluding `DEROG` and `DELINQ`. Extreme values
  in those two aren't noise, they're the signal — capping them would erase the borrowers
  the model most needs to find.
- **Missing values** — KNN imputation for `DEBTINC` (21% missing, and too predictive to
  drop), median for other numerics, mode for categoricals.
- **Engineered features (v2)** — `DEBTINC_missing`, a flag capturing which loans arrived
  without a debt-to-income figure, created *before* imputation fills the gap; and
  `underwater` (`MORTDUE > VALUE`). 17 records with impossible MORTDUE/VALUE pairs — a
  $235k mortgage against a $40k home — were blanked and re-imputed rather than deleted,
  so the train/test split stays identical to v1 and the two models remain comparable.
- **Encoding and scaling** — Label Encoding, then StandardScaler.
- **Split** — stratified 80/20, so the 20% default rate holds in both halves.
- `random_state=42` throughout. The results below reproduce exactly.

## Model comparison

| Model | Recall | Verdict |
|---|---|---|
| Logistic Regression | 52.5% | Misses half the defaulters — underfit |
| Decision Tree (stratified) | 90.3% | **Rejected** — overfit, doesn't generalize |
| Random Forest (baseline) | 64.3% | Better, untuned |
| Random Forest (grid 1) | 80.7% | Tuning helps |
| Random Forest (wider grid) — v1 | 69.3% | Superseded |
| **Random Forest (wider grid) — v2** | **81.5%** | **Selected** |

The Decision Tree scored highest and was rejected anyway. That's the point of the table:
the headline number isn't the decision, generalization is.

**Final model:** Recall 81.5% · Accuracy 87.5% · F1 0.72 · ROC-AUC 0.85

## What drives default

SHAP ranks `DEBTINC_missing` first by a wide margin — roughly 2.5× the next feature.
`DELINQ`, `CLAGE`, and `DEROG` follow. Raw `DEBTINC` still sits fifth, and `JOB` and
`REASON` contributed almost nothing and were dropped.

Two findings in one chart. First: **how a borrower has handled credit predicts default
far better than how much credit they hold** — a single past delinquency outweighs loan
size or property value. Second, and less obvious: **the most predictive fact in the file
isn't a value the bank recorded, it's one it failed to record.**

## What the SQL layer found, and what it changed

Recommendation 4 in v1 argued that DEBTINC's 21% missing rate was an underwriting gap.
The SQL layer tested it directly: **loans with missing DEBTINC default at 62%** — over
three times the book average. The missingness is itself a predictor, and KNN imputation
erases it by filling those rows with ordinary-looking values.

v2 acts on that. Capturing the gap as a feature before imputation lifted recall from
69.3% to 81.5% — from catching roughly 7 defaulters in 10 to 8 — with precision holding
steady. Every model family improved, not just the winner, which is the signature of real
signal rather than a lucky tuning run.

The loop is the point: descriptive work in SQL diagnosed a weakness that predictive
modeling alone had missed, and feeding it back produced a measurable gain.

## Exports

The notebook writes four CSVs consumed by the Power BI dashboard:

| File | Contents |
|---|---|
| `hmeq_clean.csv` | Analysis-ready data, pre-encoding, with `Record_ID` |
| `model_comparision.csv` | The comparison table above |
| `shap_importance.csv` | Mean absolute SHAP value per feature |
| `predictions.csv` | Test-set Actual / Predicted / Prob_Default by `Record_ID` |

The final cell persists the raw data and predictions to SQLite (`hmeq.db`), which is the
database the SQL layer queries. It's what lets the model's predictions be interrogated in
SQL — and it makes the SQL analysis reproducible rather than just described.
