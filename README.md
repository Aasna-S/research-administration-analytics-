# Research Administration Reporting Modernization

A synthetic case study I built to explore a common reporting challenge in university research administration: maintaining reliable reporting while moving from a legacy research system to a new cloud platform.

## Project overview

During a system migration, the same proposal or award data may be represented differently across the old and new systems. IDs, status values, dates, sponsor information and financial fields may not line up cleanly, which can create problems for reporting and data validation.

For this project, I created a synthetic research administration dataset and built a reconciliation process to identify those differences, flag records that need review and prepare a consistent dataset for reporting.

**Tools:** SQL (Snowflake-compatible), Excel, Tableau

## What I worked on

* Wrote Snowflake-compatible SQL to stage, standardize and reconcile records between legacy and current-system data
* Created source-to-target mappings for fields and status values
* Identified missing records, duplicates, financial mismatches and invalid values
* Built a standardized reporting table for downstream analysis
* Built Tableau dashboards for portfolio reporting and migration/data-quality monitoring
* Documented KPI definitions, field mappings and validation rules


## Files

* `Research Administration Data Reconciliation Project.xlsx` — project workbook containing the source data, reconciliation results, mappings, QA checks, KPI definitions. 
* `data/` — synthetic CSV datasets used in the project
* `research_migration.sql` — SQL used to stage, compare and reconcile the datasets

## Reconciliation test cases

The dataset contains 2,500 synthetic legacy proposal records. I intentionally introduced 52 migration issues to test the reconciliation logic against problems such as:

* missing records
* duplicate records
* funding mismatches
* invalid dimension keys
* date inconsistencies
* status mapping issues

The reconciliation process identifies and categorizes these exceptions so they can be reviewed before the data is used for reporting. The resulting `fact_research_activity.csv` provides the standardized reporting dataset used by the Tableau dashboards.


## Tableau Dashboard

### Research Portfolio Overview
![Research Portfolio Overview](images/Dashboard%20Page1.png)


### Migration & Data Quality
![Migration and Data Quality](images/Dashboard%20Page2.png) 

[View the interactive dashboard on Tableau Public](https://public.tableau.com/views/ResearchAdminPortfolio/ResearchPortfolioDashboard?:language=en-US&:sid=&:redirect=auth&:display_count=n&:origin=viz_share_link) 
