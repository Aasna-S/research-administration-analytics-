/*
Research Administration Reporting Modernization
Snowflake SQL portfolio project

Execution order is reflected in the filenames.

Important:
- Source/reference CSVs are assumed to have already been loaded into
  RESEARCH_ADMIN_ANALYTICS.STAGING as source tables.
- The SQL does not pretend to implement production ingestion/orchestration.
- In the portfolio, final reporting outputs were exported to CSV for Tableau.
*/

-- Purpose:
-- Publish governed, Tableau-ready reporting outputs.
-- Depends on: 04_migration_qa.sql and the reference dimensions.

USE DATABASE RESEARCH_ADMIN_ANALYTICS;
USE SCHEMA REPORTING;

-- ============================================================
-- 8. TABLEAU MIGRATION KPI VIEW
--    This now reproduces all columns in tableau_migration_kpis.csv
-- ============================================================

CREATE OR REPLACE VIEW
RESEARCH_ADMIN_ANALYTICS.REPORTING.TABLEAU_MIGRATION_KPIS AS

WITH LEGACY_TOTAL AS (
    SELECT
        COUNT(DISTINCT PROPOSAL_ID) AS LEGACY_RECORD_COUNT,
        MAX(CAST(EXTRACT_TIMESTAMP AS DATE)) AS AS_OF_DATE
    FROM RESEARCH_ADMIN_ANALYTICS.STAGING.VW_LEGACY_STANDARDIZED
),

CURRENT_TOTAL AS (
    SELECT
        COUNT(*) AS CURRENT_ROW_COUNT
    FROM RESEARCH_ADMIN_ANALYTICS.STAGING.VW_CURRENT_STANDARDIZED
),

QA AS (
    SELECT *
    FROM RESEARCH_ADMIN_ANALYTICS.QA.QA_MIGRATION_ISSUES
)

SELECT
    L.AS_OF_DATE,
    L.LEGACY_RECORD_COUNT,
    C.CURRENT_ROW_COUNT,

    L.LEGACY_RECORD_COUNT
        - COUNT(DISTINCT CASE
            WHEN Q.ISSUE_TYPE = 'MISSING_MIGRATION'
            THEN Q.LEGACY_PROPOSAL_ID
          END)
        AS MIGRATED_UNIQUE_RECORD_COUNT,

    COUNT(DISTINCT Q.LEGACY_PROPOSAL_ID)
        AS RECORDS_REQUIRING_REVIEW,

    1
      - (
          COUNT(DISTINCT Q.LEGACY_PROPOSAL_ID)
          / NULLIF(L.LEGACY_RECORD_COUNT, 0)::FLOAT
        )
        AS CLEAN_MATCH_RATE,

    (
        L.LEGACY_RECORD_COUNT
        - COUNT(DISTINCT CASE
            WHEN Q.ISSUE_TYPE = 'MISSING_MIGRATION'
            THEN Q.LEGACY_PROPOSAL_ID
          END)
    )
    / NULLIF(L.LEGACY_RECORD_COUNT, 0)::FLOAT
        AS MIGRATION_COMPLETENESS,

    COUNT_IF(Q.SEVERITY = 'Critical')
        AS CRITICAL_ISSUES,

    COUNT_IF(Q.SEVERITY = 'High')
        AS HIGH_ISSUES,

    COUNT_IF(Q.SEVERITY = 'Medium')
        AS MEDIUM_ISSUES,

    COUNT(DISTINCT CASE
        WHEN Q.ISSUE_TYPE = 'MISSING_MIGRATION'
        THEN Q.LEGACY_PROPOSAL_ID
    END) AS MISSING_RECORDS,

    COUNT(DISTINCT CASE
        WHEN Q.ISSUE_TYPE = 'DUPLICATE_RECORD'
        THEN Q.LEGACY_PROPOSAL_ID
    END) AS DUPLICATE_RECORDS,

    COUNT(CASE
        WHEN Q.ISSUE_TYPE IN (
            'REQUEST_AMOUNT_MISMATCH',
            'AWARD_AMOUNT_MISMATCH'
        )
        THEN 1
    END) AS FINANCIAL_DISCREPANCIES,

    COUNT(Q.ISSUE_TYPE)
        AS TOTAL_ISSUE_FLAGS

FROM LEGACY_TOTAL L
CROSS JOIN CURRENT_TOTAL C
LEFT JOIN QA Q
    ON 1 = 1

GROUP BY
    L.AS_OF_DATE,
    L.LEGACY_RECORD_COUNT,
    C.CURRENT_ROW_COUNT;


-- ============================================================
-- 9. CERTIFIED CURRENT-SYSTEM VIEW
-- ============================================================

CREATE OR REPLACE VIEW
RESEARCH_ADMIN_ANALYTICS.REPORTING.VW_CERTIFIED_CURRENT_PROPOSALS AS

SELECT C.*

FROM RESEARCH_ADMIN_ANALYTICS.STAGING.VW_CURRENT_LATEST C

LEFT JOIN (
    SELECT DISTINCT LEGACY_PROPOSAL_ID
    FROM RESEARCH_ADMIN_ANALYTICS.QA.QA_MIGRATION_ISSUES
) Q
    ON C.PROPOSAL_ID = Q.LEGACY_PROPOSAL_ID

WHERE Q.LEGACY_PROPOSAL_ID IS NULL;


-- ============================================================
-- 10. RESEARCH PORTFOLIO REPORTING FACT
--     This is the missing SQL that explains fact_research_activity.csv.
--
--     The portfolio view deliberately starts from the complete legacy
--     population (2,500 proposals), because the migration QA dashboard
--     separately identifies which of those records have not migrated or
--     have reconciliation issues.
--
--     Reference dimensions enrich the proposal-level transaction with
--     investigator, college, and sponsor descriptions.
-- ============================================================

CREATE OR REPLACE VIEW
RESEARCH_ADMIN_ANALYTICS.REPORTING.VW_RESEARCH_ACTIVITY AS

SELECT
    L.PROPOSAL_ID,

    I.INVESTIGATOR_ID,
    I.INVESTIGATOR_NAME,
    I.CAREER_STAGE,

    CO.COLLEGE_CODE,
    CO.COLLEGE_NAME,

    S.SPONSOR_ID,
    S.SPONSOR_NAME,
    S.SPONSOR_TYPE,

    CASE L.LEGACY_PROPOSAL_TYPE
        WHEN 'RES' THEN 'Research Project'
        WHEN 'TRN' THEN 'Training Grant'
        WHEN 'INT' THEN 'Internal Seed'
        WHEN 'EQP' THEN 'Equipment'
        WHEN 'FEL' THEN 'Fellowship'
        ELSE 'Unknown'
    END AS PROPOSAL_TYPE,

    L.SUBMISSION_DATE,

    TO_CHAR(L.SUBMISSION_DATE, 'YYYY-MM')
        AS SUBMISSION_MONTH,

    -- Synthetic university fiscal year: July through June.
    'FY' ||
    RIGHT(
        TO_VARCHAR(
            YEAR(DATEADD('month', 6, L.SUBMISSION_DATE))
        ),
        2
    ) AS FISCAL_YEAR,

    L.REQUESTED_AMOUNT,

    L.REPORTING_STATUS AS PROPOSAL_STATUS,

    -- In the synthetic data, legacy award IDs use LA- and the
    -- reporting/current convention uses AW2-.  In production this
    -- should come from an authoritative award crosswalk.
    CASE
        WHEN L.LEGACY_AWARD_ID IS NULL THEN NULL
        ELSE REPLACE(L.LEGACY_AWARD_ID, 'LA-', 'AW2-')
    END AS AWARD_ID,

    L.AWARDED_AMOUNT,

    L.DECISION_DATE,

    DATEDIFF(
        'day',
        L.SUBMISSION_DATE,
        L.DECISION_DATE
    ) AS DAYS_TO_DECISION,

    L.AWARD_START_DATE,
    L.AWARD_END_DATE

FROM RESEARCH_ADMIN_ANALYTICS.STAGING.VW_LEGACY_STANDARDIZED L

LEFT JOIN RESEARCH_ADMIN_ANALYTICS.STAGING.DIM_INVESTIGATOR I
    ON L.LEGACY_PI_ID = I.LEGACY_INVESTIGATOR_ID

LEFT JOIN RESEARCH_ADMIN_ANALYTICS.STAGING.DIM_COLLEGE CO
    ON L.LEGACY_COLLEGE = CO.COLLEGE_NAME

LEFT JOIN RESEARCH_ADMIN_ANALYTICS.STAGING.DIM_SPONSOR S
    ON L.LEGACY_SPONSOR = S.SPONSOR_NAME;

