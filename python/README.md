# Python Notebook — Loan Default Model

The modeling engine of the project. Takes the raw HMEQ file, cleans it, trains and
compares five classifiers, explains the winner with SHAP, and exports everything the
Power BI dashboard and SQL layer are built on.

GitHub renders the notebook inline — charts, tables, and SHAP plots included. No setup
needed to read it.

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
- **Encoding and scaling** — Label Encoding, then StandardScaler.
- **Split** — stratified 80/20, so the 20% default rate holds in both halves.
- `random_state=42` throughout. The results below reproduce exactly.

## Model comparison

| Model | Recall | Verdict |
|---|---|---|
| Logistic Regression | 29.8% | Misses 7 of 10 defaulters — underfit |
| Decision Tree | 91.2% | **Rejected** — overfit, doesn't generalize |
| Random Forest (baseline) | 56.7% | Better, untuned |
| Random Forest (grid 1) | 68.1% | Tuning helps |
| **Random Forest (wider grid)** | **69.3%** | **Selected** |

The Decision Tree scored highest and was rejected anyway. That's the point of the table:
the headline number isn't the decision, generalization is.

**Final model:** Recall 69.3% · Accuracy 85.2% · F1 0.65 · ROC-AUC 0.79
**Confusion matrix (n=1,192):** TP 165 · FN 73 · FP 103 · TN 851

## What drives default

SHAP put `DELINQ`, `CLAGE`, `DEROG`, and `DEBTINC` on top — every one a measure of credit
*behavior*. `JOB` and `REASON` contributed almost nothing and were dropped.

The finding in one line: **how a borrower has handled credit predicts default far better
than how much credit they hold.** Loan size and property value are weaker signals than
a single past delinquency.

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

## What the SQL layer found afterward

Recommendation 4 in the notebook argues that DEBTINC's 21% missing rate is an
underwriting gap. The SQL layer later tested it directly: **loans with missing DEBTINC
default at 62%** — over three times the book average. The missingness is itself a
predictor, and KNN imputation erases it.

A `DEBTINC_missing` flag is the first change in the next model iteration.
