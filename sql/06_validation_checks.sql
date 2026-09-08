/*
Research Administration Reporting Modernization
Snowflake SQL portfolio project

Execution order is reflected in the filenames.
- Source/reference CSVs are assumed to have already been loaded into
  RESEARCH_ADMIN_ANALYTICS.STAGING as source tables.
- The SQL does not pretend to implement production ingestion/orchestration.
- In the portfolio, final reporting outputs were exported to CSV for Tableau.
*/

-- Purpose:
-- Run control totals, expected QA checks, dimension-match checks, and inspect
-- the final Tableau-facing outputs after all model objects have been created.
-- Depends on: 05_reporting_views.sql

USE DATABASE RESEARCH_ADMIN_ANALYTICS;

-- ============================================================
-- 4. BASELINE COUNT CHECKS
-- ============================================================

SELECT
    'LEGACY' AS SOURCE_SYSTEM,
    COUNT(*) AS ROW_COUNT,
    COUNT(DISTINCT PROPOSAL_ID) AS DISTINCT_PROPOSALS
FROM RESEARCH_ADMIN_ANALYTICS.STAGING.VW_LEGACY_STANDARDIZED

UNION ALL

SELECT
    'CURRENT',
    COUNT(*),
    COUNT(DISTINCT PROPOSAL_ID)
FROM RESEARCH_ADMIN_ANALYTICS.STAGING.VW_CURRENT_STANDARDIZED;


-- ============================================================
-- 7. QA VALIDATION SUMMARIES
-- ============================================================

SELECT
    ISSUE_TYPE,
    SEVERITY,
    COUNT(*) AS ISSUE_COUNT

FROM RESEARCH_ADMIN_ANALYTICS.QA.QA_MIGRATION_ISSUES

GROUP BY
    ISSUE_TYPE,
    SEVERITY

ORDER BY
    CASE SEVERITY
        WHEN 'Critical' THEN 1
        WHEN 'High'     THEN 2
        WHEN 'Medium'   THEN 3
        ELSE 4
    END,
    ISSUE_TYPE;


/*
Expected results for the synthetic test data:
- 12 missing records
- 7 duplicates
- 8 requested amount differences
- 6 award amount differences
- 5 missing investigators
- 4 status issues
- 4 sponsor issues
- 3 college issues
- 3 date issues
- 52 issues total
*/

SELECT
    COUNT(*) AS TOTAL_QA_ISSUES,
    COUNT(DISTINCT LEGACY_PROPOSAL_ID) AS RECORDS_REQUIRING_REVIEW

FROM RESEARCH_ADMIN_ANALYTICS.QA.QA_MIGRATION_ISSUES;


-- Optional completeness check for the reporting fact.
-- In the supplied synthetic data, all 2,500 legacy proposals resolve
-- to an investigator, college, and sponsor dimension.

SELECT
    COUNT(*) AS FACT_ROW_COUNT,
    COUNT_IF(INVESTIGATOR_ID IS NULL) AS UNMATCHED_INVESTIGATORS,
    COUNT_IF(COLLEGE_CODE IS NULL) AS UNMATCHED_COLLEGES,
    COUNT_IF(SPONSOR_ID IS NULL) AS UNMATCHED_SPONSORS

FROM RESEARCH_ADMIN_ANALYTICS.REPORTING.VW_RESEARCH_ACTIVITY;


-- ============================================================
-- 11. FINAL OUTPUTS USED BY TABLEAU
-- ============================================================

-- Detailed issues for the migration/data-quality dashboard.
SELECT *
FROM RESEARCH_ADMIN_ANALYTICS.QA.QA_MIGRATION_ISSUES
ORDER BY ISSUE_ID;


-- One-row migration KPI input for Tableau.
SELECT *
FROM RESEARCH_ADMIN_ANALYTICS.REPORTING.TABLEAU_MIGRATION_KPIS;


-- Proposal-level portfolio dataset for the Research Portfolio dashboard.
SELECT *
FROM RESEARCH_ADMIN_ANALYTICS.REPORTING.VW_RESEARCH_ACTIVITY
ORDER BY PROPOSAL_ID;


-- Sample of current-system records with no outstanding QA issues.
SELECT *
FROM RESEARCH_ADMIN_ANALYTICS.REPORTING.VW_CERTIFIED_CURRENT_PROPOSALS
LIMIT 20;
