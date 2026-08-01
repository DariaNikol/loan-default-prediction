# Loan Default Prediction — HMEQ Credit Risk Analysis

End-to-end credit risk analysis on the HMEQ home-equity dataset: a Python
machine-learning model, a SQL reconciliation library, a Power BI dashboard,
and an Excel control workbook — supported by full product and governance
documentation.

## Headline result

A reconciliation check in the SQL layer surfaced a hidden pattern: loans with
a **missing** debt-to-income ratio defaulted at roughly **62%**, about triple
the 19.9% book-wide rate. Encoding that missingness as a new model feature and
retraining lifted **recall from 69% to 81%** — catching high-risk borrowers the
first version had missed. This mid-project finding is documented as a genuine
re-plan in the [Project Plan](docs/Loan_Default_Prediction_Project_Management_Plan.docx)
and assessed for fairness risk in the
[Model Risk & Bias Assessment](docs/Loan_Default_Biases_and_Risk_Assessments.docx).

## Problem

The dataset covers 5,960 home-equity loans representing $110.9M in exposure,
of which about 1 in 5 (19.9%) defaulted. The goal is to flag high-risk loans
for reviewer attention as a **decision-support tool** — not to automate
approve/decline decisions. Recall is the priority metric, because a missed
defaulter costs far more than a second review of a good borrower.

## Results

- **Recall: 69% → 81%** (v1 baseline → v2 iteration) on a held-out test set
- Precision held above the 55% target
- Model: a hyperparameter-tuned **random forest**, selected after comparison
  against a logistic-regression baseline and other candidates
- Individual-level explainability (contributing factors per score), to support
  ECOA adverse-action reasoning

## Repository structure

| Folder | Contents |
|--------|----------|
| `python/` | Model notebooks — data prep, v1 baseline, model comparison, and the v2 iteration |
| `sql/` | Reconciliation and monitoring query library |
| `powerbi/` | Dashboard for credit-operations reporting |
| `excel/` | Control workbook with data-quality checks |
| `docs/` | Product and governance documentation (see below) |

## Documentation

The [`docs/`](docs/) folder contains the project's product and governance set:

- **[Product Requirements Document](docs/PRD_Loan_Default_Prediction.docx)** — the problem, goals, scope, and success metrics
- **[Project Plan](docs/Loan_Default_Prediction_Project_Management_Plan.docx)** — how the work was planned and delivered, including the mid-project model iteration
- **[Model Risk & Bias Assessment](docs/Loan_Default_Biases_and_Risk_Assessments.docx)** — model failure modes, fairness considerations, and monitoring requirements

## Approach

The project ran in four iterative phases: (1) data preparation and baseline
modeling, (2) the SQL reconciliation layer and Power BI reporting, (3) the
v1→v2 model iteration driven by the SQL finding, and (4) documentation and
governance. The v2 iteration was an inserted, recorded change rather than part
of the original plan.

## Tech stack

Python (pandas, scikit-learn), SQL, Power BI, Excel.

## Data

HMEQ (Home Equity) dataset — a public credit-risk dataset of 5,960 records.
No new data was collected; all work is on this fixed historical snapshot.

## Author

Daria Nikoliouk
