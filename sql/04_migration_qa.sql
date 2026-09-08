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
-- Reconcile legacy and current proposal data and create one standardized
-- exception log for migration/data-quality review.
-- Depends on: 02_standardize_sources.sql, 03_deduplicate_current.sql

USE DATABASE RESEARCH_ADMIN_ANALYTICS;
USE SCHEMA QA;

-- ============================================================
-- 6. MIGRATION QA ISSUE LOG
-- ============================================================

CREATE OR REPLACE VIEW
RESEARCH_ADMIN_ANALYTICS.QA.QA_MIGRATION_ISSUES AS

WITH ISSUES AS (

    -- Records present in the legacy system but absent from the current system.
    SELECT
        L.PROPOSAL_ID,
        CAST(NULL AS VARCHAR) AS CURRENT_PROPOSAL_ID,
        'MISSING_MIGRATION' AS ISSUE_TYPE,
        'Critical' AS SEVERITY,
        'record' AS FIELD_NAME,
        'Present' AS LEGACY_VALUE,
        'Missing' AS CURRENT_VALUE,
        'Re-run migration for the missing proposal and validate the source extract window.'
            AS RECOMMENDED_ACTION

    FROM RESEARCH_ADMIN_ANALYTICS.STAGING.VW_LEGACY_STANDARDIZED L

    LEFT JOIN RESEARCH_ADMIN_ANALYTICS.STAGING.VW_CURRENT_LATEST C
        ON L.PROPOSAL_ID = C.PROPOSAL_ID

    WHERE C.CURRENT_PROPOSAL_ID IS NULL


    UNION ALL


    -- Proposal IDs with more than one row in the current system.
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


    -- Differences in requested funding amounts.
    SELECT
        L.PROPOSAL_ID,
        C.CURRENT_PROPOSAL_ID,
        'REQUEST_AMOUNT_MISMATCH',
        'High',
        'requested_amount',
        TO_CHAR(L.REQUESTED_AMOUNT, 'FM999999999999990.00'),
        TO_CHAR(C.REQUESTED_AMOUNT, 'FM999999999999990.00'),
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


    -- Differences in awarded / obligated funding amounts.
    SELECT
        L.PROPOSAL_ID,
        C.CURRENT_PROPOSAL_ID,
        'AWARD_AMOUNT_MISMATCH',
        'High',
        'awarded_amount',
        TO_CHAR(L.AWARDED_AMOUNT, 'FM999999999999990.00'),
        TO_CHAR(C.AWARDED_AMOUNT, 'FM999999999999990.00'),
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


    -- Missing or invalid researcher IDs.  The dimension is the governed
    -- crosswalk from legacy PI IDs to current researcher IDs.
    SELECT
        C.PROPOSAL_ID,
        C.CURRENT_PROPOSAL_ID,
        'MISSING_INVESTIGATOR',
        'High',
        'investigator_id',
        L.LEGACY_PI_ID,
        COALESCE(C.RESEARCHER_KEY, 'NULL'),
        'Restore the researcher key using the investigator crosswalk.'

    FROM RESEARCH_ADMIN_ANALYTICS.STAGING.VW_CURRENT_LATEST C

    INNER JOIN RESEARCH_ADMIN_ANALYTICS.STAGING.VW_LEGACY_STANDARDIZED L
        ON L.PROPOSAL_ID = C.PROPOSAL_ID

    LEFT JOIN RESEARCH_ADMIN_ANALYTICS.STAGING.DIM_INVESTIGATOR I
        ON C.RESEARCHER_KEY = I.INVESTIGATOR_ID

    WHERE C.RESEARCHER_KEY IS NULL
       OR TRIM(C.RESEARCHER_KEY) = ''
       OR I.INVESTIGATOR_ID IS NULL


    UNION ALL


    -- Current status values that cannot be resolved through the governed mapping.
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

    LEFT JOIN RESEARCH_ADMIN_ANALYTICS.STAGING.STATUS_MAPPING SM
        ON C.CURRENT_STATUS_CODE = SM.CURRENT_STATUS_CODE

    WHERE C.CURRENT_STATUS_CODE IS NULL
       OR SM.CURRENT_STATUS_CODE IS NULL


    UNION ALL


    -- Sponsor IDs that do not resolve to the sponsor master dimension.
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

    LEFT JOIN RESEARCH_ADMIN_ANALYTICS.STAGING.DIM_SPONSOR S
        ON C.SPONSOR_ID = S.SPONSOR_ID

    WHERE C.SPONSOR_ID IS NULL
       OR S.SPONSOR_ID IS NULL


    UNION ALL


    -- Organization codes that do not resolve to the college dimension.
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

    LEFT JOIN RESEARCH_ADMIN_ANALYTICS.STAGING.DIM_COLLEGE CO
        ON C.ORG_UNIT_CODE = CO.COLLEGE_CODE

    WHERE C.ORG_UNIT_CODE IS NULL
       OR CO.COLLEGE_CODE IS NULL


    UNION ALL


    -- Submission dates that differ after standardization.
    -- Raw values are retained in the issue log to make investigation easier.
    SELECT
        L.PROPOSAL_ID,
        C.CURRENT_PROPOSAL_ID,
        'SUBMISSION_DATE_MISMATCH',
        'Medium',
        'submission_date',
        L.LEGACY_SUBMISSION_RAW,
        'ISO ' || C.CURRENT_SUBMISSION_RAW,
        'Confirm the authoritative submission timestamp and timezone rule.'

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

