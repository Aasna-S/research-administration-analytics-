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
- `data/` - Tableau-ready CSV tables, including a one-row migration KPI source
- `research_migration_snowflake.sql` - staged Snowflake-style reconciliation and certified reporting view sample

## Controlled migration defects

The dataset contains 2,500 legacy proposal records and deliberately plants 52 records requiring review, including missing and duplicate records, financial mismatches, invalid dimensional keys and date/status issues. The reconciled `fact_research_activity.csv` represents the governed post-remediation reporting output.


## Important disclaimer

All institutions, people, sponsors, identifiers and financial values are synthetic.
