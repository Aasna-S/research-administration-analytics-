/*
================================================================================
RESEARCH ADMINISTRATION REPORTING MODERNIZATION
Snowflake Reconciliation + QA + Reporting Views
================================================================================

Purpose
-------
Synthetic portfolio implementation of a legacy-to-current eRA migration
reconciliation workflow.

The script:
1. Preserves raw source tables.
2. Standardizes legacy and current-system fields.
3. Checks target-system duplicates.
4. Selects one current record per proposal for comparison.
5. Reconciles completeness, financial values, dates, statuses, and key fields.
6. Produces a record-level QA exception view.
7. Produces Tableau-ready migration KPI and certified-data views.

Synthetic-data disclaimer
-------------------------
All institutions, identifiers, sponsors, people, and financial values in this
project are synthetic. This script is a portfolio reference implementation and
is not connected to Northeastern University, McGill University, or any
production eRA environment.

Assumptions
-----------
The following raw tables have already been loaded into Snowflake:

    RESEARCH_ADMIN_ANALYTICS.STAGING.LEGACY_PROPOSALS
    RESEARCH_ADMIN_ANALYTICS.STAGING.ERA_PROPOSALS

This script assumes Snowflake normalized the uploaded CSV headers to uppercase
underscore-style column names.

Expected legacy columns:
    PROPOSAL_NO
    PI_ID
    COLLEGE_TEXT
    SPONSOR_NAME
    PROPOSAL_TYPE_CD
    SUBMIT_DT
    REQUEST_AMT
    PROP_STATUS_CD
    AWARD_NO
    AWARD_AMT
    DECISION_DT
    AWARD_START_DT
    AWARD_END_DT
    EXTRACT_TS

Expected current-system columns:
    CURRENT_PROPOSAL_ID
    LEGACY_PROPOSAL_NO
    RESEARCHER_KEY
    ORG_UNIT_CODE
    SPONSOR_ID
    PROPOSAL_CATEGORY
    SUBMITTED_AT
    REQUESTED_TOTAL
    WORKFLOW_STATUS
    CURRENT_AWARD_ID
    OBLIGATED_AMOUNT
    DECISION_AT
    AWARD_START_DATE
    AWARD_END_DATE
    ROW_LAST_UPDATED

If your imported columns differ, run:
    DESCRIBE TABLE RESEARCH_ADMIN_ANALYTICS.STAGING.LEGACY_PROPOSALS;
    DESCRIBE TABLE RESEARCH_ADMIN_ANALYTICS.STAGING.ERA_PROPOSALS;

Then update only the raw-column references in Sections 2 and 3.
================================================================================
*/


/*==============================================================================
1. PROJECT STRUCTURE
WHY:
Keep staging, QA, and reporting logic separated. Raw source data remains
unchanged and auditable.
==============================================================================*/

CREATE DATABASE IF NOT EXISTS RESEARCH_ADMIN_ANALYTICS;

CREATE SCHEMA IF NOT EXISTS RESEARCH_ADMIN_ANALYTICS.STAGING;
CREATE SCHEMA IF NOT EXISTS RESEARCH_ADMIN_ANALYTICS.QA;
CREATE SCHEMA IF NOT EXISTS RESEARCH_ADMIN_ANALYTICS.REPORTING;

USE DATABASE RESEARCH_ADMIN_ANALYTICS;
USE SCHEMA STAGING;


/*==============================================================================
2. STANDARDIZE LEGACY DATA
WHY:
The old system uses legacy codes, YYYYMMDD dates, and legacy field names.
Before comparing old and new systems, equivalent concepts must use equivalent
formats and governed business definitions.
==============================================================================*/

CREATE OR REPLACE VIEW
RESEARCH_ADMIN_ANALYTICS.STAGING.VW_LEGACY_STANDARDIZED AS

SELECT
    TRIM(TO_VARCHAR(PROPOSAL_NO)) AS PROPOSAL_ID,

    NULLIF(TRIM(TO_VARCHAR(PI_ID)), '') AS LEGACY_PI_ID,

    NULLIF(TRIM(TO_VARCHAR(COLLEGE_TEXT)), '') AS LEGACY_COLLEGE,

    NULLIF(TRIM(TO_VARCHAR(SPONSOR_NAME)), '') AS LEGACY_SPONSOR,

    NULLIF(TRIM(TO_VARCHAR(PROPOSAL_TYPE_CD)), '') AS LEGACY_PROPOSAL_TYPE,

    TRY_TO_DATE(
        NULLIF(TRIM(TO_VARCHAR(SUBMIT_DT)), ''),
        'YYYYMMDD'
    ) AS SUBMISSION_DATE,

    TRY_TO_DECIMAL(
        NULLIF(TRIM(TO_VARCHAR(REQUEST_AMT)), ''),
        18,
        2
    ) AS REQUESTED_AMOUNT,

    NULLIF(TRIM(TO_VARCHAR(PROP_STATUS_CD)), '') AS LEGACY_STATUS_CODE,

    /* Translate legacy workflow codes to governed reporting statuses. */
    CASE TRIM(TO_VARCHAR(PROP_STATUS_CD))
        WHEN 'SUB' THEN 'Submitted'
        WHEN 'REV' THEN 'Under Review'
        WHEN 'WD'  THEN 'Withdrawn'
        WHEN 'DCL' THEN 'Not Funded'
        WHEN 'AWD' THEN 'Awarded'
        WHEN 'ACT' THEN 'Active'
        WHEN 'CLS' THEN 'Closed'
        ELSE 'Unknown'
    END AS REPORTING_STATUS,

    NULLIF(TRIM(TO_VARCHAR(AWARD_NO)), '') AS LEGACY_AWARD_ID,

    COALESCE(
        TRY_TO_DECIMAL(
            NULLIF(TRIM(TO_VARCHAR(AWARD_AMT)), ''),
            18,
            2
        ),
        0
    ) AS AWARDED_AMOUNT,

    TRY_TO_DATE(
        NULLIF(TRIM(TO_VARCHAR(DECISION_DT)), ''),
        'YYYYMMDD'
    ) AS DECISION_DATE,

    TRY_TO_DATE(
        NULLIF(TRIM(TO_VARCHAR(AWARD_START_DT)), ''),
        'YYYYMMDD'
    ) AS AWARD_START_DATE,

    TRY_TO_DATE(
        NULLIF(TRIM(TO_VARCHAR(AWARD_END_DT)), ''),
        'YYYYMMDD'
    ) AS AWARD_END_DATE,

    TRY_TO_TIMESTAMP_NTZ(
        NULLIF(TRIM(TO_VARCHAR(EXTRACT_TS)), ''),
        'YYYYMMDD HH24MISS'
    ) AS EXTRACT_TIMESTAMP

FROM RESEARCH_ADMIN_ANALYTICS.STAGING.LEGACY_PROPOSALS;


/*==============================================================================
3. STANDARDIZE CURRENT eRA DATA
WHY:
The current system uses different field names, codes, IDs, and timestamps.
This view puts comparable business concepts into the same format used by the
legacy standardized view.
==============================================================================*/

CREATE OR REPLACE VIEW
RESEARCH_ADMIN_ANALYTICS.STAGING.VW_CURRENT_STANDARDIZED AS

SELECT
    NULLIF(TRIM(TO_VARCHAR(CURRENT_PROPOSAL_ID)), '')
        AS CURRENT_PROPOSAL_ID,

    NULLIF(TRIM(TO_VARCHAR(LEGACY_PROPOSAL_NO)), '')
        AS PROPOSAL_ID,

    NULLIF(TRIM(TO_VARCHAR(RESEARCHER_KEY)), '')
        AS RESEARCHER_KEY,

    NULLIF(TRIM(TO_VARCHAR(ORG_UNIT_CODE)), '')
        AS ORG_UNIT_CODE,

    NULLIF(TRIM(TO_VARCHAR(SPONSOR_ID)), '')
        AS SPONSOR_ID,

    NULLIF(TRIM(TO_VARCHAR(PROPOSAL_CATEGORY)), '')
        AS PROPOSAL_TYPE,

    TRY_TO_DATE(
        NULLIF(TRIM(TO_VARCHAR(SUBMITTED_AT)), '')
    ) AS SUBMISSION_DATE,

    TRY_TO_DECIMAL(
        NULLIF(TRIM(TO_VARCHAR(REQUESTED_TOTAL)), ''),
        18,
        2
    ) AS REQUESTED_AMOUNT,

    NULLIF(TRIM(TO_VARCHAR(WORKFLOW_STATUS)), '')
        AS CURRENT_STATUS_CODE,

    /* Translate current workflow values to the same governed statuses. */
    CASE TRIM(TO_VARCHAR(WORKFLOW_STATUS))
        WHEN 'SUBMITTED'    THEN 'Submitted'
        WHEN 'UNDER_REVIEW' THEN 'Under Review'
        WHEN 'WITHDRAWN'    THEN 'Withdrawn'
        WHEN 'NOT_FUNDED'   THEN 'Not Funded'
        WHEN 'AWARDED'      THEN 'Awarded'
        WHEN 'ACTIVE'       THEN 'Active'
        WHEN 'CLOSED'       THEN 'Closed'
        ELSE 'Unknown'
    END AS REPORTING_STATUS,

    NULLIF(TRIM(TO_VARCHAR(CURRENT_AWARD_ID)), '')
        AS CURRENT_AWARD_ID,

    COALESCE(
        TRY_TO_DECIMAL(
            NULLIF(TRIM(TO_VARCHAR(OBLIGATED_AMOUNT)), ''),
            18,
            2
        ),
        0
    ) AS AWARDED_AMOUNT,

    TRY_TO_DATE(
        NULLIF(TRIM(TO_VARCHAR(DECISION_AT)), '')
    ) AS DECISION_DATE,

    TRY_TO_DATE(
        NULLIF(TRIM(TO_VARCHAR(AWARD_START_DATE)), '')
    ) AS AWARD_START_DATE,

    TRY_TO_DATE(
        NULLIF(TRIM(TO_VARCHAR(AWARD_END_DATE)), '')
    ) AS AWARD_END_DATE,

    TRY_TO_TIMESTAMP_NTZ(
        NULLIF(TRIM(TO_VARCHAR(ROW_LAST_UPDATED)), '')
    ) AS ROW_LAST_UPDATED

FROM RESEARCH_ADMIN_ANALYTICS.STAGING.ERA_PROPOSALS;


/*==============================================================================
4. PROFILE SOURCE COUNTS
WHY:
Before reconciliation, establish the grain and make sure the intended matching
key behaves as expected.
==============================================================================*/

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


/*==============================================================================
5. IDENTIFY DUPLICATE TARGET RECORDS
WHY:
If a proposal appears twice in the new system, joining it directly to one
legacy row can multiply records and distort totals. Preserve the duplicate as
a QA issue before selecting one record for comparison.
==============================================================================*/

CREATE OR REPLACE VIEW
RESEARCH_ADMIN_ANALYTICS.QA.VW_DUPLICATE_PROPOSALS AS

SELECT
    PROPOSAL_ID,
    MAX(CURRENT_PROPOSAL_ID) AS CURRENT_PROPOSAL_ID,
    COUNT(*) AS RECORD_COUNT

FROM RESEARCH_ADMIN_ANALYTICS.STAGING.VW_CURRENT_STANDARDIZED

WHERE PROPOSAL_ID IS NOT NULL

GROUP BY PROPOSAL_ID

HAVING COUNT(*) > 1;


/*==============================================================================
6. SELECT ONE CURRENT RECORD PER PROPOSAL
WHY:
We still need one target record for field-level comparison. ROW_NUMBER ranks
records within each proposal and retains the most recently updated row.

Important:
This does NOT hide the duplicate. Duplicate proposals remain in the QA view.
==============================================================================*/

CREATE OR REPLACE VIEW
RESEARCH_ADMIN_ANALYTICS.STAGING.VW_CURRENT_LATEST AS

SELECT *

FROM RESEARCH_ADMIN_ANALYTICS.STAGING.VW_CURRENT_STANDARDIZED

QUALIFY ROW_NUMBER() OVER (
    PARTITION BY COALESCE(PROPOSAL_ID, CURRENT_PROPOSAL_ID)
    ORDER BY
        ROW_LAST_UPDATED DESC NULLS LAST,
        CURRENT_PROPOSAL_ID DESC
) = 1;


/*==============================================================================
7. BUILD RECORD-LEVEL QA EXCEPTION VIEW
WHY:
Reconciliation means defining what "correct" looks like and testing each
proposal against those expectations.

The controls below test:
    - completeness
    - uniqueness
    - requested funding
    - awarded funding
    - investigator completeness
    - status validity
    - sponsor validity
    - college validity
    - submission-date agreement

For this synthetic portfolio dataset:
    S999 = controlled invalid sponsor code
    ZZZ  = controlled invalid organization/college code

In production, these two checks would normally LEFT JOIN against governed
sponsor and organization master tables rather than hard-code test values.
==============================================================================*/

CREATE OR REPLACE VIEW
RESEARCH_ADMIN_ANALYTICS.QA.QA_MIGRATION_ISSUES AS

WITH ISSUES AS (

    /*----------------------------------------------------------------------
    A. COMPLETENESS
    Keep every legacy proposal and find those with no current-system match.
    ----------------------------------------------------------------------*/

    SELECT
        L.PROPOSAL_ID,
        CAST(NULL AS VARCHAR) AS CURRENT_PROPOSAL_ID,
        'MISSING_MIGRATION' AS ISSUE_TYPE,
        'Critical' AS SEVERITY,
        'record' AS FIELD_NAME,
        'Present' AS LEGACY_VALUE,
        'Missing' AS CURRENT_VALUE,
        'Re-run migration and validate the source extract window.'
            AS RECOMMENDED_ACTION

    FROM RESEARCH_ADMIN_ANALYTICS.STAGING.VW_LEGACY_STANDARDIZED L

    LEFT JOIN RESEARCH_ADMIN_ANALYTICS.STAGING.VW_CURRENT_LATEST C
        ON L.PROPOSAL_ID = C.PROPOSAL_ID

    WHERE C.CURRENT_PROPOSAL_ID IS NULL


    UNION ALL


    /*----------------------------------------------------------------------
    B. UNIQUENESS
    One legacy proposal should not produce multiple target records.
    ----------------------------------------------------------------------*/

    SELECT
        D.PROPOSAL_ID,
        D.CURRENT_PROPOSAL_ID,
        'DUPLICATE_RECORD',
        'High',
        'record',
        '1 source record',
        TO_VARCHAR(D.RECORD_COUNT) || ' target records',
        'Retain the latest valid record and review the upstream merge key.'

    FROM RESEARCH_ADMIN_ANALYTICS.QA.VW_DUPLICATE_PROPOSALS D


    UNION ALL


    /*----------------------------------------------------------------------
    C. REQUESTED-AMOUNT RECONCILIATION
    Financial values should agree to the project's $0.01 tolerance.
    ----------------------------------------------------------------------*/

    SELECT
        L.PROPOSAL_ID,
        C.CURRENT_PROPOSAL_ID,
        'REQUEST_AMOUNT_MISMATCH',
        'High',
        'requested_amount',
        TO_VARCHAR(L.REQUESTED_AMOUNT),
        TO_VARCHAR(C.REQUESTED_AMOUNT),
        'Reconcile amount transformations and confirm currency/rounding logic.'

    FROM RESEARCH_ADMIN_ANALYTICS.STAGING.VW_LEGACY_STANDARDIZED L

    INNER JOIN RESEARCH_ADMIN_ANALYTICS.STAGING.VW_CURRENT_LATEST C
        ON L.PROPOSAL_ID = C.PROPOSAL_ID

    WHERE
        L.REQUESTED_AMOUNT IS DISTINCT FROM C.REQUESTED_AMOUNT
        AND (
            L.REQUESTED_AMOUNT IS NULL
            OR C.REQUESTED_AMOUNT IS NULL
            OR ABS(L.REQUESTED_AMOUNT - C.REQUESTED_AMOUNT) > 0.01
        )


    UNION ALL


    /*----------------------------------------------------------------------
    D. AWARD-AMOUNT RECONCILIATION
    ----------------------------------------------------------------------*/

    SELECT
        L.PROPOSAL_ID,
        C.CURRENT_PROPOSAL_ID,
        'AWARD_AMOUNT_MISMATCH',
        'High',
        'awarded_amount',
        TO_VARCHAR(L.AWARDED_AMOUNT),
        TO_VARCHAR(C.AWARDED_AMOUNT),
        'Validate obligated amount against the authoritative award record.'

    FROM RESEARCH_ADMIN_ANALYTICS.STAGING.VW_LEGACY_STANDARDIZED L

    INNER JOIN RESEARCH_ADMIN_ANALYTICS.STAGING.VW_CURRENT_LATEST C
        ON L.PROPOSAL_ID = C.PROPOSAL_ID

    WHERE
        L.AWARDED_AMOUNT IS DISTINCT FROM C.AWARDED_AMOUNT
        AND (
            L.AWARDED_AMOUNT IS NULL
            OR C.AWARDED_AMOUNT IS NULL
            OR ABS(L.AWARDED_AMOUNT - C.AWARDED_AMOUNT) > 0.01
        )


    UNION ALL


    /*----------------------------------------------------------------------
    E. INVESTIGATOR COMPLETENESS
    The synthetic target defect is represented by a missing researcher key.

    Production enhancement:
    Validate RESEARCHER_KEY against an investigator master dimension and
    validate the legacy-to-current investigator crosswalk.
    ----------------------------------------------------------------------*/

    SELECT
        C.PROPOSAL_ID,
        C.CURRENT_PROPOSAL_ID,
        'MISSING_INVESTIGATOR',
        'High',
        'investigator_id',
        L.LEGACY_PI_ID,
        COALESCE(C.RESEARCHER_KEY, ''),
        'Restore the researcher key using the investigator crosswalk.'

    FROM RESEARCH_ADMIN_ANALYTICS.STAGING.VW_CURRENT_LATEST C

    INNER JOIN RESEARCH_ADMIN_ANALYTICS.STAGING.VW_LEGACY_STANDARDIZED L
        ON L.PROPOSAL_ID = C.PROPOSAL_ID

    WHERE C.RESEARCHER_KEY IS NULL
       OR TRIM(C.RESEARCHER_KEY) = ''


    UNION ALL


    /*----------------------------------------------------------------------
    F. STATUS VALIDITY
    Legacy and current codes were standardized earlier. Here we identify
    current workflow values outside the approved status vocabulary.
    ----------------------------------------------------------------------*/

    SELECT
        C.PROPOSAL_ID,
        C.CURRENT_PROPOSAL_ID,
        'UNMAPPED_STATUS',
        'Medium',
        'proposal_status',
        L.LEGACY_STATUS_CODE,
        C.CURRENT_STATUS_CODE,
        'Add or correct the workflow status mapping before publication.'

    FROM RESEARCH_ADMIN_ANALYTICS.STAGING.VW_CURRENT_LATEST C

    INNER JOIN RESEARCH_ADMIN_ANALYTICS.STAGING.VW_LEGACY_STANDARDIZED L
        ON L.PROPOSAL_ID = C.PROPOSAL_ID

    WHERE C.CURRENT_STATUS_CODE IS NULL
       OR C.CURRENT_STATUS_CODE NOT IN (
            'SUBMITTED',
            'UNDER_REVIEW',
            'WITHDRAWN',
            'NOT_FUNDED',
            'AWARDED',
            'ACTIVE',
            'CLOSED'
       )


    UNION ALL


    /*----------------------------------------------------------------------
    G. SPONSOR VALIDITY
    Synthetic defect rule only.
    Production: replace with LEFT JOIN to sponsor master dimension.
    ----------------------------------------------------------------------*/

    SELECT
        C.PROPOSAL_ID,
        C.CURRENT_PROPOSAL_ID,
        'INVALID_SPONSOR',
        'Medium',
        'sponsor_id',
        L.LEGACY_SPONSOR,
        C.SPONSOR_ID,
        'Resolve the sponsor identifier against the sponsor master table.'

    FROM RESEARCH_ADMIN_ANALYTICS.STAGING.VW_CURRENT_LATEST C

    INNER JOIN RESEARCH_ADMIN_ANALYTICS.STAGING.VW_LEGACY_STANDARDIZED L
        ON L.PROPOSAL_ID = C.PROPOSAL_ID

    WHERE C.SPONSOR_ID = 'S999'


    UNION ALL


    /*----------------------------------------------------------------------
    H. ORGANIZATION / COLLEGE VALIDITY
    Synthetic defect rule only.
    Production: replace with LEFT JOIN to organization master dimension.
    ----------------------------------------------------------------------*/

    SELECT
        C.PROPOSAL_ID,
        C.CURRENT_PROPOSAL_ID,
        'INVALID_COLLEGE',
        'Medium',
        'college_code',
        L.LEGACY_COLLEGE,
        C.ORG_UNIT_CODE,
        'Resolve the organization code against the college crosswalk.'

    FROM RESEARCH_ADMIN_ANALYTICS.STAGING.VW_CURRENT_LATEST C

    INNER JOIN RESEARCH_ADMIN_ANALYTICS.STAGING.VW_LEGACY_STANDARDIZED L
        ON L.PROPOSAL_ID = C.PROPOSAL_ID

    WHERE C.ORG_UNIT_CODE = 'ZZZ'


    UNION ALL


    /*----------------------------------------------------------------------
    I. SUBMISSION-DATE RECONCILIATION
    Both systems were standardized to DATE before comparison.
    ----------------------------------------------------------------------*/

    SELECT
        L.PROPOSAL_ID,
        C.CURRENT_PROPOSAL_ID,
        'SUBMISSION_DATE_MISMATCH',
        'Medium',
        'submission_date',
        TO_VARCHAR(L.SUBMISSION_DATE),
        TO_VARCHAR(C.SUBMISSION_DATE),
        'Confirm the authoritative submission date and timestamp rule.'

    FROM RESEARCH_ADMIN_ANALYTICS.STAGING.VW_LEGACY_STANDARDIZED L

    INNER JOIN RESEARCH_ADMIN_ANALYTICS.STAGING.VW_CURRENT_LATEST C
        ON L.PROPOSAL_ID = C.PROPOSAL_ID

    WHERE L.SUBMISSION_DATE IS DISTINCT FROM C.SUBMISSION_DATE
)

SELECT
    'QA-' ||
    LPAD(
        ROW_NUMBER() OVER (
            ORDER BY PROPOSAL_ID, ISSUE_TYPE
        )::VARCHAR,
        4,
        '0'
    ) AS ISSUE_ID,

    PROPOSAL_ID AS LEGACY_PROPOSAL_ID,
    CURRENT_PROPOSAL_ID,
    ISSUE_TYPE,
    SEVERITY,
    FIELD_NAME,
    LEGACY_VALUE,
    CURRENT_VALUE,
    RECOMMENDED_ACTION

FROM ISSUES;


/*==============================================================================
8. VALIDATE THE QA OUTPUT
WHY:
A reconciliation is not complete just because the SQL ran. Compare outputs
against known test cases and expected aggregate counts.
==============================================================================*/

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
Expected controlled-test counts for this synthetic dataset:

    MISSING_MIGRATION           12
    DUPLICATE_RECORD             7
    REQUEST_AMOUNT_MISMATCH      8
    AWARD_AMOUNT_MISMATCH        6
    MISSING_INVESTIGATOR         5
    UNMAPPED_STATUS              4
    INVALID_SPONSOR              4
    INVALID_COLLEGE              3
    SUBMISSION_DATE_MISMATCH     3
    --------------------------------
    TOTAL                       52
*/

SELECT
    COUNT(*) AS TOTAL_QA_ISSUES,
    COUNT(DISTINCT LEGACY_PROPOSAL_ID) AS RECORDS_REQUIRING_REVIEW

FROM RESEARCH_ADMIN_ANALYTICS.QA.QA_MIGRATION_ISSUES;


/*==============================================================================
9. CREATE TABLEAU-READY MIGRATION KPI VIEW
WHY:
Put governed KPI logic upstream so Tableau does not have to recreate core data
quality definitions.
==============================================================================*/

CREATE OR REPLACE VIEW
RESEARCH_ADMIN_ANALYTICS.REPORTING.TABLEAU_MIGRATION_KPIS AS

WITH LEGACY_TOTAL AS (
    SELECT COUNT(DISTINCT PROPOSAL_ID) AS LEGACY_RECORD_COUNT
    FROM RESEARCH_ADMIN_ANALYTICS.STAGING.VW_LEGACY_STANDARDIZED
),

QA AS (
    SELECT *
    FROM RESEARCH_ADMIN_ANALYTICS.QA.QA_MIGRATION_ISSUES
)

SELECT
    L.LEGACY_RECORD_COUNT,

    L.LEGACY_RECORD_COUNT
        - COUNT(DISTINCT CASE
            WHEN Q.ISSUE_TYPE = 'MISSING_MIGRATION'
            THEN Q.LEGACY_PROPOSAL_ID
          END)
        AS MIGRATED_UNIQUE_RECORD_COUNT,

    COUNT(DISTINCT Q.LEGACY_PROPOSAL_ID)
        AS RECORDS_REQUIRING_REVIEW,

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
        AS MIGRATION_COMPLETENESS

FROM LEGACY_TOTAL L
LEFT JOIN QA Q
    ON 1 = 1

GROUP BY L.LEGACY_RECORD_COUNT;


/*==============================================================================
10. CREATE CERTIFIED CURRENT-PROPOSAL VIEW
WHY:
Keep unresolved QA exceptions separate from trusted reporting records.
==============================================================================*/

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


/*==============================================================================
11. FINAL PORTFOLIO CHECKS
==============================================================================*/

-- QA exceptions used by the Migration Quality dashboard.
SELECT *
FROM RESEARCH_ADMIN_ANALYTICS.QA.QA_MIGRATION_ISSUES
ORDER BY ISSUE_ID;


-- Tableau KPI source.
SELECT *
FROM RESEARCH_ADMIN_ANALYTICS.REPORTING.TABLEAU_MIGRATION_KPIS;


-- Clean/certified records available for governed reporting.
SELECT *
FROM RESEARCH_ADMIN_ANALYTICS.REPORTING.VW_CERTIFIED_CURRENT_PROPOSALS
LIMIT 20;


