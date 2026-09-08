/*
Research Administration Reporting Modernization
Snowflake SQL portfolio project

Execution order is reflected in the filenames.
- Source/reference CSVs are assumed to have already been loaded into
  RESEARCH_ADMIN_ANALYTICS.STAGING as source tables.
- The SQL does not pretend to implement production ingestion/orchestration.
- In the portfolio, final reporting outputs were exported to CSV for Tableau.
*/

-- ============================================================
-- 1. DATABASE AND SCHEMAS
-- ============================================================

CREATE DATABASE IF NOT EXISTS RESEARCH_ADMIN_ANALYTICS;

CREATE SCHEMA IF NOT EXISTS RESEARCH_ADMIN_ANALYTICS.STAGING;
CREATE SCHEMA IF NOT EXISTS RESEARCH_ADMIN_ANALYTICS.QA;
CREATE SCHEMA IF NOT EXISTS RESEARCH_ADMIN_ANALYTICS.REPORTING;

USE DATABASE RESEARCH_ADMIN_ANALYTICS;
USE SCHEMA STAGING;

