# Excel Control Workbook — HMEQ Loan Portfolio

## The control layer
A five-tab control workbook built directly on the raw HMEQ data, independent of the
Python pipeline.

Underwriters, credit operations teams, and internal audit work in Excel. A model
whose inputs can't be inspected in the tool the business already trusts doesn't get
adopted — it gets overridden. This workbook is the **control layer**: it validates the
raw data against documented, field-level rules before any number reaches a model or a
dashboard.

It serves a second purpose. The same figures are computed independently here, in SQL,
and in Power BI. Where the three agree, that agreement is evidence the logic is sound.
Where they disagree, the disagreement is a bug worth finding.

## Workbook Structure:

| Tab | Purpose |
|---|---|
| **Data** | Raw HMEQ imported via Power Query, loaded as a named Table so every downstream formula has a stable reference |
| **Data Dictionary** | Field-level definitions and validation rules — expected type, permitted range, null tolerance |
| **Control Checks** | Automated rule tests using `INDIRECT`, `COUNTBLANK`, `COUNTIFS`, `INDEX/MATCH` — each rule from the dictionary gets a pass/fail |
| **Exceptions** | Dynamic-array `FILTER`/`CHOOSECOLS` output listing the actual records that break a rule, so a reviewer sees the row, not just a count |
| **Dashboard** | PivotTables and KPI summaries — portfolio-level default rate, exposure, and segment cuts |

## Findings:

- **DEBTINC ceiling.** The dictionary sets a maximum of 100 (a debt-to-income ratio
  above 100% is definitionally suspect). The control check flagged a record at **203%** —
  a data error, not a risky borrower.
- **Segment reconciliation.** The Dashboard PivotTable put default rates at **22% for
  HomeImp vs 19% for DebtCon**. The SQL layer, computed independently against the raw
  file, returned 22.2% and 19.0%. Two tools, two methods, same answer.

## Where this layer stops
This workbook validates fields **individually**. It cannot catch
inconsistency *between* columns — a `MORTDUE` of $235k against a `VALUE` of $40k passes
every single-field rule while being obviously wrong.


## Files

- `hmeq_control_workbook.xlsx` — the workbook
