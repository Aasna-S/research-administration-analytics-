# Research Administration Reporting Modernization

Synthetic portfolio case study prepared for a Analyst role in university research administration.

## The business problem

A university is moving from a legacy electronic research-administration system to a current cloud platform. Leadership reporting must continue during the transition, but identifiers, status codes, date formats and financial fields differ across the two systems. The solution must reconcile the migration, isolate exceptions, document reporting definitions and provide reusable executive reporting.

## What this project demonstrates

- SQL-based validation and reconciliation across legacy and current systems
- Source-to-target field mapping and governed status definitions
- Exception handling for missing, duplicate, invalid and mismatched records
- A standardized reporting fact prepared for focused Tableau dashboards
- Executive, operational and data-quality dashboard requirements
- Clear source-of-truth KPI definitions and technical documentation

## Files

- `Research_Administration_Tableau_Project.xlsx` - full workbook with raw data, reconciled output, mappings, QA results, KPI definitions and Tableau build specifications
- `Research_Administration_Case_Study.pdf` - concise two-page hiring-manager work sample
- `data/` - Tableau-ready CSV tables, including a one-row migration KPI source
- `sql/research_migration_snowflake.sql` - staged Snowflake-style reconciliation and certified reporting view
- `tableau/tableau_calculated_fields.txt` - ready-to-use calculated fields
- `tableau/tableau_build_guide.md` - connection, worksheet, dashboard and publishing guide

## Controlled migration defects

The dataset contains 2,500 legacy proposal records and deliberately plants 52 records requiring review, including missing and duplicate records, financial mismatches, invalid dimensional keys and date/status issues. The reconciled `fact_research_activity.csv` represents the governed post-remediation reporting output.

## Recommended portfolio framing

> I built this synthetic case study to show how I would approach reporting continuity during an electronic research-administration system migration. I standardized differently structured legacy and current data, created SQL controls for record and field-level reconciliation, documented source-of-truth definitions, and designed Tableau dashboards for executive research reporting and migration-quality review.

## Suggested 60-second interview walkthrough

1. Start with the risk: a technically successful migration can still produce untrustworthy reports.
2. Explain the source-to-target mapping and why raw legacy/current sources remain unchanged.
3. Show the SQL controls: completeness, duplicates, financial differences, null/invalid keys and status/date mismatches.
4. Show the Data Quality page before the Executive page; it establishes why the KPIs can be trusted.
5. Close with the governance layer: metric definitions, documented transformation rules and exception ownership.

## Important disclaimer

All institutions, people, sponsors, identifiers and financial values are synthetic. This project contains no confidential or internal university information and is not affiliated with Northeastern University or McGill University.
