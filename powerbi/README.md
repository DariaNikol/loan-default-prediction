# Power BI Dashboard — HMEQ Loan Portfolio

A four-page report built on the model's outputs. This is the presentation layer: the
Python notebook produces the numbers, this makes them navigable by someone who will
never open a notebook.

## Executive View

![Executive View](img/01_executive_view.png)

Portfolio health at a glance — 1,189 defaults across $107.59M of exposure, a 19.95%
default rate, average DTI of 33.16. Loan-size distribution, job mix, and the split of
dollars between repaid and defaulted loans.

The question this page answers is "how is the book doing," and nothing on it requires
knowing what a random forest is.

## Risk Drivers

![Risk Drivers](img/02_risk_drivers.png)

Default rate cut five ways: job type, debt-to-income, delinquencies, derogatory marks,
and credit history age. Where the previous page describes, this one directs — it shows
*which* segments carry the risk, which is what an underwriting policy can act on.

Two patterns worth naming. Debt-to-income is a **cliff, not a ramp**: flat below 50%,
then near-total default above it. And credit age runs the opposite direction to
everything else — risk falls as history lengthens, from 28% under 10 years to 9.9% at
20+.

## Model Performance

![Model Performance](img/03_model_performance.png)

Metric cards, the five-model comparison, the confusion matrix, and predicted risk score
against actual outcome.

The confusion matrix reconciles exactly to the notebook: **TP 165 · FN 73 · FP 103 ·
TN 851**, n=1,192, recall 69.33%. The dashboard doesn't restate the model's claims — it
recomputes them from the raw predictions and lands on the same numbers.

The comparison table flags the Decision Tree's 0.91 recall as overfitting rather than a
win. A chart that hides why the best-looking model was rejected is worse than no chart.

## Feature Importance & Recommendations

![Feature Importance](img/04_feature_importance.png)

SHAP feature ranking, paired with four recommendations that each cite the chart value
they rest on.

`DELINQ` (0.11), `CLAGE` (0.08), and `DEROG` (0.05) lead — all measures of credit
*behavior* — while LOAN, VALUE, and MORTDUE sit at 0.03 or below. How a borrower has
handled credit predicts default far better than how much credit they hold.

## Data model

Four CSVs exported by the notebook, loaded through Power Query:

- `hmeq_clean` — analysis-ready records, keyed on `Record_ID`
- `predictions` — test-set actual vs. predicted, related 1:1 to `hmeq_clean`
- `model_comparision` and `shap_importance` — deliberately disconnected, since they
  describe models and features rather than loans and shouldn't be filtered by loan-level
  slicers

Banding logic for DTI, delinquency, derogatory marks, and credit age is implemented in
DAX with `SWITCH(TRUE())` plus explicit sort-key columns to control display order.

The credit-age bands are cut identically here and in the SQL layer, and the two agree
exactly: 1,262 loans at 20+ years, 9.9% default rate, computed independently in DAX and
in SQL `CASE`.

Note that this page reads the cleaned dataset (post outlier capping), so total exposure
here is $107.59M against $110.9M in the SQL layer, which reads raw. The gap is the
capping, and it's intentional.

## Design

Amber marks default and risk, grey marks healthy, held consistently across all four
pages. Every page carries a navigator row and a reset-filters button.

## Files

- `Loan_default_Power_BI.pbix` — opens in Power BI Desktop
- `img/` — page exports (GitHub can't preview `.pbix`, so the images are the report)

- `Loan_default_Power_BI.pbix` — opens in Power BI Desktop
- `img/` — page exports (GitHub can't preview `.pbix`, so the images are the report)
