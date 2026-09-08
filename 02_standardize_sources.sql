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
-- Convert legacy/current source fields to consistent analytical types and
-- governed reporting values before reconciliation.
-- Depends on: 01_setup.sql + source/reference tables loaded into STAGING.

USE DATABASE RESEARCH_ADMIN_ANALYTICS;
USE SCHEMA STAGING;

-- ============================================================
-- 2. STANDARDIZE LEGACY DATA
-- ============================================================

CREATE OR REPLACE VIEW
RESEARCH_ADMIN_ANALYTICS.STAGING.VW_LEGACY_STANDARDIZED AS

SELECT
    TRIM(TO_VARCHAR(L.PROPOSAL_NO)) AS PROPOSAL_ID,

    NULLIF(TRIM(TO_VARCHAR(L.PI_ID)), '') AS LEGACY_PI_ID,

    NULLIF(TRIM(TO_VARCHAR(L.COLLEGE_TEXT)), '') AS LEGACY_COLLEGE,

    NULLIF(TRIM(TO_VARCHAR(L.SPONSOR_NAME)), '') AS LEGACY_SPONSOR,

    NULLIF(TRIM(TO_VARCHAR(L.PROPOSAL_TYPE_CD)), '') AS LEGACY_PROPOSAL_TYPE,

    -- Keep the original value for QA traceability.
    NULLIF(TRIM(TO_VARCHAR(L.SUBMIT_DT)), '') AS LEGACY_SUBMISSION_RAW,

    TRY_TO_DATE(
        NULLIF(TRIM(TO_VARCHAR(L.SUBMIT_DT)), ''),
        'YYYYMMDD'
    ) AS SUBMISSION_DATE,

    TRY_TO_DECIMAL(
        NULLIF(TRIM(TO_VARCHAR(L.REQUEST_AMT)), ''),
        18,
        2
    ) AS REQUESTED_AMOUNT,

    NULLIF(TRIM(TO_VARCHAR(L.PROP_STATUS_CD)), '') AS LEGACY_STATUS_CODE,

    -- Governed status comes from the status crosswalk rather than
    -- duplicating the mapping logic in multiple queries.
    COALESCE(SM.REPORTING_STATUS, 'Unknown') AS REPORTING_STATUS,

    NULLIF(TRIM(TO_VARCHAR(L.AWARD_NO)), '') AS LEGACY_AWARD_ID,

    COALESCE(
        TRY_TO_DECIMAL(
            NULLIF(TRIM(TO_VARCHAR(L.AWARD_AMT)), ''),
            18,
            2
        ),
        0
    ) AS AWARDED_AMOUNT,

    TRY_TO_DATE(
        NULLIF(TRIM(TO_VARCHAR(L.DECISION_DT)), ''),
        'YYYYMMDD'
    ) AS DECISION_DATE,

    TRY_TO_DATE(
        NULLIF(TRIM(TO_VARCHAR(L.AWARD_START_DT)), ''),
        'YYYYMMDD'
    ) AS AWARD_START_DATE,

    TRY_TO_DATE(
        NULLIF(TRIM(TO_VARCHAR(L.AWARD_END_DT)), ''),
        'YYYYMMDD'
    ) AS AWARD_END_DATE,

    TRY_TO_TIMESTAMP_NTZ(
        NULLIF(TRIM(TO_VARCHAR(L.EXTRACT_TS)), ''),
        'YYYYMMDD HH24MISS'
    ) AS EXTRACT_TIMESTAMP

FROM RESEARCH_ADMIN_ANALYTICS.STAGING.LEGACY_PROPOSALS L

LEFT JOIN RESEARCH_ADMIN_ANALYTICS.STAGING.STATUS_MAPPING SM
    ON TRIM(TO_VARCHAR(L.PROP_STATUS_CD)) = SM.LEGACY_STATUS_CODE;


-- ============================================================
-- 3. STANDARDIZE CURRENT-SYSTEM DATA
-- ============================================================

CREATE OR REPLACE VIEW
RESEARCH_ADMIN_ANALYTICS.STAGING.VW_CURRENT_STANDARDIZED AS

SELECT
    NULLIF(TRIM(TO_VARCHAR(C.CURRENT_PROPOSAL_ID)), '')
        AS CURRENT_PROPOSAL_ID,

    NULLIF(TRIM(TO_VARCHAR(C.LEGACY_PROPOSAL_NO)), '')
        AS PROPOSAL_ID,

    NULLIF(TRIM(TO_VARCHAR(C.RESEARCHER_KEY)), '')
        AS RESEARCHER_KEY,

    NULLIF(TRIM(TO_VARCHAR(C.ORG_UNIT_CODE)), '')
        AS ORG_UNIT_CODE,

    NULLIF(TRIM(TO_VARCHAR(C.SPONSOR_ID)), '')
        AS SPONSOR_ID,

    NULLIF(TRIM(TO_VARCHAR(C.PROPOSAL_CATEGORY)), '')
        AS PROPOSAL_TYPE,

    -- Keep the original value for QA traceability.
    NULLIF(TRIM(TO_VARCHAR(C.SUBMITTED_AT)), '')
        AS CURRENT_SUBMISSION_RAW,

    TRY_TO_DATE(
        NULLIF(TRIM(TO_VARCHAR(C.SUBMITTED_AT)), '')
    ) AS SUBMISSION_DATE,

    TRY_TO_DECIMAL(
        NULLIF(TRIM(TO_VARCHAR(C.REQUESTED_TOTAL)), ''),
        18,
        2
    ) AS REQUESTED_AMOUNT,

    NULLIF(TRIM(TO_VARCHAR(C.WORKFLOW_STATUS)), '')
        AS CURRENT_STATUS_CODE,

    COALESCE(SM.REPORTING_STATUS, 'Unknown')
        AS REPORTING_STATUS,

    NULLIF(TRIM(TO_VARCHAR(C.CURRENT_AWARD_ID)), '')
        AS CURRENT_AWARD_ID,

    COALESCE(
        TRY_TO_DECIMAL(
            NULLIF(TRIM(TO_VARCHAR(C.OBLIGATED_AMOUNT)), ''),
            18,
            2
        ),
        0
    ) AS AWARDED_AMOUNT,

    TRY_TO_DATE(
        NULLIF(TRIM(TO_VARCHAR(C.DECISION_AT)), '')
    ) AS DECISION_DATE,

    TRY_TO_DATE(
        NULLIF(TRIM(TO_VARCHAR(C.AWARD_START_DATE)), '')
    ) AS AWARD_START_DATE,

    TRY_TO_DATE(
        NULLIF(TRIM(TO_VARCHAR(C.AWARD_END_DATE)), '')
    ) AS AWARD_END_DATE,

    TRY_TO_TIMESTAMP_NTZ(
        NULLIF(TRIM(TO_VARCHAR(C.ROW_LAST_UPDATED)), '')
    ) AS ROW_LAST_UPDATED

FROM RESEARCH_ADMIN_ANALYTICS.STAGING.ERA_PROPOSALS C

LEFT JOIN RESEARCH_ADMIN_ANALYTICS.STAGING.STATUS_MAPPING SM
    ON TRIM(TO_VARCHAR(C.WORKFLOW_STATUS)) = SM.CURRENT_STATUS_CODE;

