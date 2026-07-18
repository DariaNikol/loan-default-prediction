-- HMEQ Loan Default — SQL Query Library
-- 19 queries across 5 sections: Data Profiling, Portfolio KPIs, Risk Segmentation,
-- Advanced Patterns, Model Monitoring. Run against raw hmeq_raw (5,960 loans) + predictions.
-- Baseline: 19.9% default rate, $110.9M exposure. Findings noted under each query.

-- Data Profiling & Quality Controls 

-- Q1. Is every loan record unique?
SELECT COUNT(*) AS total_rows,
COUNT(DISTINCT Record_ID) unique_records
FROM hmeq_raw;
-- Result: 5960 rows = 5960 distinct Record_IDs, thus no duplicate records.

-- Q2. WHere are the gaps, and how bad?
SELECT
    COUNT(*) - COUNT(DEBTINC) AS debtinc_missing,
    ROUND((COUNT(*) - COUNT(DEBTINC)) * 100.0 / COUNT(*), 1) AS debtinc_pct,

    COUNT(*) - COUNT(DEROG) AS derog_missing,
    ROUND((COUNT(*) - COUNT(DEROG)) * 100.0 / COUNT(*), 1) AS derog_pct,

    COUNT(*) - COUNT(DELINQ) AS delinq_missing,
    ROUND((COUNT(*) - COUNT(DELINQ)) * 100.0 / COUNT(*), 1) AS delinq_pct,

    COUNT(*) - COUNT(JOB) AS job_missing,
    ROUND((COUNT(*) - COUNT(JOB)) * 100.0 / COUNT(*), 1) AS job_pct
FROM hmeq_raw;
-- Checked missing counts for the columns that mattered most in the Python analysis: DEBTINC, DEROG, DELINQ, JOB.
-- DEBTINC 1267 (21%), DEROG 708 (12%), DELINQ 580 (10%), JOB 279 (5%).
-- Confirms the Python findings in SQL — DEBTINC, a top predictor, is missing on 1  in 5 loans.

-- Q3. which records carry impossible values? 
SELECT *
FROM hmeq_raw
WHERE DEBTINC > 100;
-- 5 records with DEBTINC > 100 (max 203% = Record_ID 4473). All 5 have BAD=1.
-- Likely data errors, but all are defaulters — cap at 100 rather than delete, to preserve minority-class signal.

-- Q4. Are the category codes clean?
SELECT JOB, COUNT(*) AS total_count 
FROM hmeq_raw
GROUP BY JOB
ORDER BY total_count DESC;

SELECT REASON, COUNT(*) as total_count
FROM hmeq_raw
GROUP BY REASON
ORDER BY total_count DESC;
-- JOB has 6 valid features + 279 NULL; REASON has DebtCon/HomeImp + 252 NULL. No invalid categories — codes are clean.

-- Q5. Does the collateral cover the debt?
SELECT COUNT(*) as total_values
FROM hmeq_raw
WHERE MORTDUE > VALUE OR LOAN <= 0;
-- See the actual rows:
SELECT Record_ID, MORTDUE, VALUE, (MORTDUE - VALUE) AS gap
FROM hmeq_raw
WHERE MORTDUE > VALUE OR LOAN <= 0
ORDER BY gap DESC;
-- 51 loans have MORTDUE > VALUE (owe more than the home is worth), ~0.9% of the book.
-- Sorting by gap reveals three tiers:
--   * Grossly underwater (gap ~$185-205k, MORTDUE 5-6x VALUE, IDs 5434-5550): almost certainly
--     VALUE/MORTDUE data-entry errors, not real loans.
--   * Mid band (gap ~$22-70k): mixed, some plausible some suspect.
--   * Mildly underwater (gap <$12k): genuine cases of a home slipping below its mortgage.
-- Mostly BAD=0, so underwater status here does NOT track default.
-- New finding: this cross-column inconsistency was not caught in the Python notebook (never compared
-- MORTDUE vs VALUE) or the Excel workbook (validated fields individually) — unique to the SQL layer.
-- Action: flag the top cluster for data review before it feeds any model.

-- Portfolio KPIs

-- Q6. What is the headline health of the loan book?
SELECT COUNT(*) AS total_loans, 
ROUND(AVG(BAD) * 100.0, 1) AS avg_default_rate_pct,
SUM(LOAN) AS total_exposure, ROUND(AVG(LOAN), 1) AS avg_loan_amount
FROM hmeq_raw;
-- 5,960 loans, 19.9% default rate, $110.9M total exposure, $18,608 avg loan.
-- The ~20% default rate = the class imbalance the model was built to handle.
-- Average LOAN ($18.6k) is small relative to home VALUE (~$70-100k) — this is CORRECT,
-- not an error. HMEQ = Home Equity loans: LOAN is a small second loan drawn against existing equity,
-- not a mortgage to buy the house. VALUE = home worth, MORTDUE = balance on the original mortgage,
-- LOAN = the new equity draw against what's left. A small LOAN vs a large VALUE is expected.

-- Q7. Does default rate differ by loan purpose?
SELECT REASON,
ROUND(AVG(BAD) * 100.0, 1) AS avg_default_rate_pct,
SUM(LOAN) AS total_exposure, ROUND(AVG(LOAN), 1) AS avg_loan_amount
FROM hmeq_raw
GROUP BY REASON
ORDER BY avg_default_rate_pct;
-- HomeImp defaults highest at 22.2% (above the 19.9% book avg); DebtCon and NULL both ~19.0%.
-- Cross-checked against the Excel workbook PivotTable (HomeImp 22% / DebtCon 19%) — same ranking, same gap,
-- computed independently.
-- Debt-consolidation borrowers repay reliably — folding many debts into one fixed monthly
-- payment appears to stabilize their finances rather than signal distress.

--Q8. How is the book distributed by loan size?
SELECT  COUNT(*) AS loan_count,
ROUND(AVG(BAD) * 100.0, 1) AS default_rate_pct,
CASE
WHEN LOAN <10000 THEN 'Under 10k'
WHEN LOAN < 20000 THEN '10k-20k'
WHEN LOAN < 30000 THen '20k-30k'
ELSE '30k+'
END AS loan_band
FROM hmeq_raw
GROUP BY loan_band
ORDER BY loan_band ASC;
-- Smallest loans (Under 10k) default highest at 28.5%; 20k-30k safest at 15.4%.
-- Inverse pattern at the low end — small loan size may signal a financially tighter borrower (hypothesis).
-- Book concentrates in 10k-20k (2,627 loans).

-- Risk Segmentation

-- Q9. Which occupations default most?
SELECT JOB, COUNT(*) AS loan_count,
ROUND(AVG(BAD) * 100, 1) AS default_rate_pct
FROM hmeq_raw
GROUP BY JOB
ORDER BY default_rate_pct DESC;
-- Sales defaults highest at 34.9%, Office lowest at 13.2% — a 2.7x spread across occupations.
-- Self (30.1%) also high; ProfExe/Office low. Matches Excel PivotTable exactly (Sales 35%; Office 13%).
-- NULL job defaults LOWEST (8.2%) — missing job is not a risk signal here.

--Q10. does delinquency history predict default? 
SELECT CASE
WHEN DELINQ IS NULL THEN 'Unknown'
WHEN DELINQ = 0 THEN 'None'
WHEN DELINQ <= 2 THEN '1-2'
ELSE '3+'
END AS delinq_band, 
COUNT(*) AS loan_count, 
ROUND(AVG(BAD) * 100, 1) AS default_rate_pct
FROM hmeq_raw
GROUP BY delinq_band
ORDER BY delinq_band;
-- Sharp risk gradient — None 14.0%; 1-2 36.9%; 3+ 67.3% (roughly doubles per tier).
-- 3+ delinquencies = 2-in-3 default. Confirms DELINQ as a top predictor (matches Python SHAP).
-- Unknown (missing DELINQ) defaults LOW at 12.4% — missing data is not a risk signal.
-- NULLs handled explicitly: leaving them in ELSE had masked the 3+ signal at a false 31%.

-- Q11. At what debt load does risk accelerate? 
SELECT CASE
WHEN DEBTINC IS NULL THEN 'Unknown'
WHEN DEBTINC <= 35 THEN 'Under 35'
WHEN DEBTINC <= 45 THEN '35-45'
ELSE '45+'
END AS debtinc_band, 
COUNT(*) AS loan_count, 
ROUND(AVG(BAD) * 100, 1) AS default_rate_pct
FROM hmeq_raw
GROUP BY debtinc_band
ORDER BY debtinc_band;
-- Banded at 35 / 45, close to the industry DTI thresholds (36 comfortable, 43 = the Qualified Mortgage
-- ceiling, 43+ high-risk). 
-- Result: risk is a CLIFF, not a ramp — Under 35 = 5.6%, 35-45 = 8.5%,
-- then 45+ jumps to 94%. The industry danger line (43%) and this book's empirical cliff (~45) agree.
-- KEY FINDING: missing DEBTINC defaults at 62% — OPPOSITE of missing JOB (8%) and DELINQ (12%).
-- Missingness itself is a risk signal here (not missing at random). Note: Python KNN-imputed DEBTINC
-- may have discarded this signal; a "DEBTINC_missing" flag feature would preserve it.

-- Q12. Does thin credit history mean higher risk?
SELECT CASE
WHEN CLAGE IS NULL THEN 'Unknown'
WHEN CLAGE <= 120  THEN 'under 10 years - weak'
WHEN CLAGE <= 240  THEN '10-20 years - established'
ELSE '20+ years - seasoned'
END AS clage_band,
COUNT(*) AS loan_count, 
ROUND(AVG(BAD) * 100, 1) AS default_rate_pct
FROM hmeq_raw
GROUP BY clage_band
ORDER BY clage_band;
-- Risk FALLS as credit history lengthens — weak (<10yr) 28.3%; established(10-20) 19.2%; seasoned (20+) 9.9%.
-- Thin credit file almost triples default rate vs seasoned. OPPOSITE direction to DELINQ/DTI: not all factors point one way.
-- Unknown CLAGE 25.3% — missing credit age is moderately high.

-- Q13. Does job and delinquency risk compound?
SELECT JOB,
CASE
WHEN DELINQ IS NULL THEN 'Unknown'
WHEN DELINQ = 0 THEN 'None'
WHEN DELINQ <= 2 THEN '1-2'
ELSE '3+'
END AS delinq_band,
COUNT(*) AS loan_count,
ROUND(AVG(BAD) * 100, 1) AS default_rate_pct
FROM hmeq_raw
GROUP BY JOB, delinq_band
ORDER BY JOB, delinq_band;
-- Delinquency compounds within every job — Other: None 17%; 1-2 41%; 3+ 77%.
-- DELINQ is the DOMINANT axis: a 3+ Office borrower (56%) out-risks a clean-history Sales borrower (29%).
-- Job modulates, delinquency drives — explains why the model kept DELINQ and dropped JOB.
-- CAUTION: several 100% cells sit on tiny samples (Sales+3+ = 1 loan) — noise, not signal. Trust only healthy counts.

-- Advanced Patterns

-- Q14. Reproduction of the cleaning pipeline in SQL.
-- NOTE: SQL reproduces the DETERMINISTIC cleaning only. The notebook uses KNN imputation for DEBTINC,
-- which is a model, not a SQL operation. Here DEBTINC is median-imputed as a stated simplification —
-- the notebook remains the source of truth for the modelling dataset.
WITH capped AS (    
SELECT Record_ID, DEBTINC, MIN(DEBTINC, 100) AS capped
FROM hmeq_raw),
imputed AS(
SELECT Record_ID,
COALESCE(capped, (SELECT DEBTINC 
FROM hmeq_raw
WHERE DEBTINC IS NOT NULL
ORDER BY DEBTINC
LIMIT 1
OFFSET(SELECT COUNT(DEBTINC) FROM hmeq_raw) / 2)) AS cleaned_DEBTINC
FROM capped)
SELECT Record_ID, cleaned_DEBTINC,
CASE
WHEN cleaned_DEBTINC < 36 THEN 'Comfortable'
WHEN cleaned_DEBTINC < 43 THEN 'Caution'
ELSE 'High_risk exposure'
END AS dti_band
FROM imputed;


-- 14b. How much of the book is high-risk DTI, after cleaning?
WITH capped AS (    
SELECT Record_ID, DEBTINC, MIN(DEBTINC, 100) AS capped
FROM hmeq_raw),
imputed AS(
SELECT Record_ID,
COALESCE(capped, (SELECT DEBTINC 
FROM hmeq_raw
WHERE DEBTINC IS NOT NULL
ORDER BY DEBTINC
LIMIT 1
OFFSET(SELECT COUNT(DEBTINC) FROM hmeq_raw) / 2)) AS cleaned_DEBTINC
FROM capped),
banded AS(
SELECT Record_ID, cleaned_DEBTINC,
CASE
WHEN cleaned_DEBTINC < 36 THEN 'Comfortable'
WHEN cleaned_DEBTINC < 43 THEN 'Caution'
ELSE 'High_risk exposure'
END AS dti_band
FROM imputed)
SELECT Record_ID, cleaned_DEBTINC
FROM banded
WHERE dti_band = 'High_risk exposure'
ORDER BY cleaned_DEBTINC DESC;
-- Median (34.818) is used as a stated simplification
-- Result: 206 loans (3.5% of book) land in High_risk (43+) after cleaning — including all 5 Q3 records,
-- capped 203%→100 and carried through the pipeline intact.
-- ARTIFACT: the 1,267 median-imputed rows all land in "Comfortable" — but those borrowers default at 62%
-- (Q11). Median imputation files the riskiest cohort under the safest label, destroying the missingness
-- signal. Concrete argument for a DEBTINC_missing flag feature in the v2 model.

-- Q15. Does risk vary across the loan-size distribution?
WITH deciles AS(
SELECT Record_ID, BAD, LOAN, 
NTILE(10) OVER (ORDER BY LOAN) AS  loan_decile
FROM hmeq_raw)
SELECT  loan_decile,
COUNT(*) AS loan_count,
MIN(LOAN) AS min_loan,
MAX(LOAN) AS max_loan,
ROUND(AVG(BAD) * 100, 1) AS default_rate_pct
FROM deciles
GROUP BY  loan_decile
ORDER BY  loan_decile;
-- Risk is a CLIFF at the bottom, not a gradient. Decile 1 ($1,100-7,600) defaults at 38.4%
-- (approximately 2x book avg), decile 2 drops to 21.0%, deciles 3-10 hover 14-22% with no trend.
-- Largest loans ($30.5k-$89.9k) default at 19.8% — exactly average. Loan size only predicts risk at the low end.
-- REFINES Q8: the "Under 10k = 28.5%" band was masking the real threshold — the risk sits under ~$7,600.
-- NTILE gives equal-COUNT buckets (596 each), so rates are directly comparable — unlike hand-picked CASE bands.

-- Q16. What are the top 5 riskiest segments?
WITH segments AS(
SELECT JOB,
CASE
WHEN DELINQ IS NULL THEN 'Unknown'
WHEN DELINQ = 0 THEN 'None'
WHEN DELINQ <= 2 THEN '1-2'
ELSE '3+'
END AS delinq_band,
COUNT(*) AS loan_count,
SUM(LOAN) AS total_exposure,
ROUND(AVG(BAD) * 100, 1) AS default_rate_pct
FROM hmeq_raw
GROUP BY JOB, delinq_band
HAVING COUNT (*) >= 50)
SELECT RANK() OVER(ORDER BY default_rate_pct DESC) AS risk_rank,
JOB, delinq_band, loan_count, total_exposure, default_rate_pct
FROM segments
ORDER BY risk_rank
LIMIT 5;
-- Ranks 1-4 are ALL "3+ delinquency" segments spanning 4 different jobs —
-- Other 76.8%, ProfExe 60.3%, Mgr 59.4%, Office 55.8%. Even the safest occupations (ProfExe 16.6%,
-- Office 13.2% book-wide) become top-tier risk once delinquency is present. Delinquency dominates.
-- Rank 5 (Mgr + 1-2, 41.5%) is the first non-3+ segment, but carries the largest exposure ($2.3M).
-- NOTE: Sales and Self — the two riskiest JOBS — are absent, filtered out by HAVING COUNT(*) >= 50
-- (their 3+ cells held 1 and 14 loans). Riskiest jobs =/= riskiest segments; small populations can't
-- support a trustworthy rate.

-- Model Monitoring

-- Q17. Construction of the confusion matrix in SQL
SELECT
SUM(CASE WHEN Actual = 1 AND Predicted = 1 THEN 1 ELSE 0 END) AS true_positives,
SUM(CASE WHEN Actual = 0 AND Predicted = 1 THEN 1 ELSE 0 END) AS false_positives,
SUM(CASE WHEN Actual = 1 AND Predicted = 0 THEN 1 ELSE 0 END) AS false_negatives,
SUM(CASE WHEN Actual = 0 AND Predicted = 0 THEN 1 ELSE 0 END) AS true_negatives
FROM predictions;
-- TP 165, FP 103, FN 73, TN 851 (test set = 1,192).
-- THIRD independent computation of these values — matches the Python notebook and the Power BI pivotTable
-- exactly. Same numbers, three different tools/engines: full confusion-matrix reconciliation.
-- The 73 False Negatives are the costly cell — real defaulters the model waved through. 

-- Q18. Compute recall and precision from the confusion matrix
WITH cm AS(
SELECT
SUM(CASE WHEN Actual = 1 AND Predicted = 1 THEN 1 ELSE 0 END) AS TP,
SUM(CASE WHEN Actual = 0 AND Predicted = 1 THEN 1 ELSE 0 END) AS FP,
SUM(CASE WHEN Actual = 1 AND Predicted = 0 THEN 1 ELSE 0 END) AS FN
FROM predictions)
SELECT 
TP, FP, FN,
ROUND(TP * 100.0 / (TP + FN), 1) AS recall_pct,
ROUND(TP * 100.0 / (TP + FP), 1) AS precision_pct
FROM cm;
-- Recall 69.0%, Precision 61.0% — matches the notebook (fourth reconciliation of the recall figure).
-- Recall = 165/(165+73): the model catches ~69% of true defaulters. Precision = 165/(165+103): ~61% of
-- flagged loans truly default. Project optimizes RECALL because a missed defaulter (FN) is a realized loss,
-- while a false alarm (FP) only costs a review — asymmetric costs justify favouring recall over precision.

-- Q19. Who did the model miss? (profile the 73 False Negatives)
SELECT p.Record_ID, h.JOB, h.LOAN, h.DELINQ, h.CLAGE
FROM predictions AS p
JOIN hmeq_raw AS h
ON p.Record_ID = h.Record_ID
WHERE p.Actual = 1 AND p.Predicted = 0
ORDER BY h.DELINQ DESC;
-- The 73 missed defaulters overwhelmingly have DELINQ = 0 — clean delinquency records, normal loans,
-- established credit. They looked SAFE on the model's dominant feature (DELINQ, per Q13/Q16), so it cleared them.
-- The model's strength (DELINQ) is also its blind spot: it fails on defaulters who have no delinquency signal.
-- Implication for v2: these clean-DELINQ defaulters are exactly where an alternative signal (e.g. DEBTINC_missing)
-- could catch what delinquency history cannot.