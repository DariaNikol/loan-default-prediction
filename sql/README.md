# SQL Query Library — HMEQ Loan Default

A 19-query SQL library analyzing the HMEQ home-equity loan book (5,960 loans),
written for a credit middle-office / operations analyst use case. Queries run
against the **raw** data so they catch problems as they arrive, not after cleaning.

## Contents

| File | What it is |
|---|---|
| `hmeq_queries.sql` | The 19-query library, each with a business question and documented finding |
| `hmeq.db` | SQLite database (raw loans + model predictions) — makes the queries runnable |
| `SQL_Library_Design.md` | Design doc: sourcing decision, query inventory, structure |

## How to run

1. Open `hmeq.db` in any SQLite tool (DB Browser for SQLite, or the VS Code SQLite extension).
2. Run any query from `hmeq_queries.sql` against it.
   - `hmeq_raw` — 5,960 raw loans
   - `predictions` — model output (Actual, Predicted) for the test set

## The five sections

1. **Data Profiling & Quality Controls** — uniqueness, missing values, impossible values, category checks, collateral coverage
2. **Portfolio KPIs** — book-wide health, default by purpose, default by loan size
3. **Risk Segmentation** — default rate by job, delinquency, DTI, credit age, and combinations
4. **Advanced Patterns** — a cleaning pipeline (CTEs), decile analysis (NTILE), ranked risk segments
5. **Model Monitoring** — confusion matrix, recall/precision, and profiling the loans the model missed

## Key findings

**Baseline:** 5,960 loans, 19.9% default rate, $110.9M total exposure.

- **Delinquency is the strongest risk driver.** Default rate climbs sharply with delinquency history — 14% (none) → 37% (1–2) → 67% (3+) — and this holds within every occupation.

- **DTI risk is a cliff, not a ramp.** Debt-to-income barely matters until ~45, where default jumps to 94% — right at the industry Qualified-Mortgage threshold of 43%.

- **Missing DEBTINC is itself a risk signal.** Loans with no debt-to-income recorded default at **62%** — the opposite of other missing fields (missing job/delinquency default *low*). The data isn't missing at random. → *Argues for a `DEBTINC_missing` flag feature in the improved model, since imputing these values erases the signal.*

- **Smallest loans are the riskiest.** Loans under ~$7,600 default at ~38% (2× the book average); loan size stops predicting risk above that.

- **A cluster of loans is grossly underwater — likely data errors.** ~15 loans carry mortgages 5–6× the home's value ($240k owed on a $40k home), a cross-column inconsistency flagged for data review. → *Feeds a data-cleaning step and an "underwater" flag in the improved model.*

- **The model's strength is also its blind spot.** The 73 defaulters the model missed overwhelmingly have *clean* delinquency records — they looked safe on the feature the model trusts most (DELINQ). This is where an alternative signal (e.g. the DEBTINC-missing flag) could help.

## Feeding the improved model

Two findings here point directly at a v2 model: add a **`DEBTINC_missing` flag feature**
(missing DEBTINC = 62% default), and **clean the underwater data-error records** before retraining.
