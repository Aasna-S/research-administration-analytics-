/*
Research Administration Reporting Modernization
Snowflake SQL portfolio project
*/

-- Purpose:
-- Identify repeated current-system proposal IDs and establish the comparison
-- grain of one latest current record per proposal.
-- Depends on: 02_standardize_sources.sql

USE DATABASE RESEARCH_ADMIN_ANALYTICS;
USE SCHEMA STAGING;

-- ============================================================
-- 5. DUPLICATE AND LATEST-RECORD LOGIC
-- ============================================================

CREATE OR REPLACE VIEW
RESEARCH_ADMIN_ANALYTICS.QA.VW_DUPLICATE_PROPOSALS AS

SELECT
    PROPOSAL_ID,
    MIN(CURRENT_PROPOSAL_ID) AS CURRENT_PROPOSAL_ID,
    COUNT(*) AS RECORD_COUNT

FROM RESEARCH_ADMIN_ANALYTICS.STAGING.VW_CURRENT_STANDARDIZED

WHERE PROPOSAL_ID IS NOT NULL

GROUP BY PROPOSAL_ID

HAVING COUNT(*) > 1;


-- Bring the current system to one comparable row per proposal
-- before doing field-level reconciliation.
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

