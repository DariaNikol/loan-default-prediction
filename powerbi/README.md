# Power BI Dashboard — HMEQ Loan Portfolio

A four-page report built on the model's outputs. This is the presentation layer: the
Python notebook produces the numbers, this makes them navigable by someone who will
never open a notebook.

## Executive View

![Executive View](img/01_executive_view.png)

Portfolio health at a glance — KPI cards, loan outcomes, exposure at risk, default rate
by job, and loan-size distribution. The question this page answers is "how is the book
doing," and nothing on it requires knowing what a random forest is.

## Risk Drivers

![Risk Drivers](img/02_risk_drivers.png)

Default rate cut by job, debt-to-income, credit history age, delinquency, and derogatory
marks. Where the previous page describes, this one directs: it shows *which* segments
carry the risk, which is what an underwriting policy can actually act on.

Debt-to-income turns out to be a cliff rather than a ramp — it barely matters below ~45%,
then default becomes near-certain above it. That threshold sits right on the industry's
43% Qualified Mortgage line.

## Model Performance

![Model Performance](img/03_model_performance.png)

Metric cards, the five-model comparison, the confusion matrix, and the predicted
probability distribution.

The confusion matrix reconciles exactly to the notebook: **TP 165 · FN 73 · FP 103 ·
TN 851**, n=1,192, recall 69.33%. The dashboard doesn't restate the model's claims — it
recomputes them from the raw predictions and lands on the same numbers. The comparison
table also flags the Decision Tree's 91.2% recall as overfitting rather than a win, since
a chart that hides why the best-looking model was rejected is worse than no chart.

## Feature Importance & Recommendations

![Feature Importance](img/04_feature_importance.png)

SHAP feature ranking, paired with four recommendations that each cite the chart value
they rest on. `DELINQ`, `CLAGE`, `DEROG`, and `DEBTINC` lead — all measures of credit
*behavior*. How a borrower has handled credit predicts default far better than how much
credit they hold.

## Data model

Four CSVs exported by the notebook, loaded through Power Query:

- `hmeq_clean` — analysis-ready records, keyed on `Record_ID`
- `predictions` — test-set actual vs. predicted, related 1:1 to `hmeq_clean`
- `model_comparision` and `shap_importance` — deliberately disconnected, since they
  describe models and features rather than loans and shouldn't be filtered by loan-level
  slicers

Banding logic (DTI, delinquency, credit age) is implemented in DAX with `SWITCH(TRUE())`
plus explicit sort-key columns — the same bands the SQL layer builds with `CASE`. The two
agree, which is the point of building them twice.

## Design

Amber marks default and risk, grey marks healthy, held consistently across all four
pages. Every page carries a navigator row and a reset-filters button.

## Files

- `Loan_default_Power_BI.pbix` — opens in Power BI Desktop
- `img/` — page exports (GitHub can't preview `.pbix`, so the images are the report)
