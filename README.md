# Research Administration Reporting Modernization

A synthetic case study I built to explore a common reporting challenge in university research administration: maintaining reliable reporting while moving from a legacy research system to a new cloud platform.

## Project overview

During a system migration, the same proposal or award data may be represented differently across the old and new systems. IDs, status values, dates, sponsor information and financial fields may not line up cleanly, which can create problems for reporting and data validation.

For this project, I created a synthetic research administration dataset and built a reconciliation process to identify those differences, flag records that need review and prepare a consistent dataset for reporting.

## What I worked on

* Used SQL to compare and reconcile records between legacy and current-system data
* Created source-to-target mappings for fields and status values
* Identified missing records, duplicates, financial mismatches and invalid values
* Built a cleaned reporting table for use in Tableau
* Defined requirements for executive, operational and data-quality dashboards
* Documented KPI definitions, field mappings and validation rules


## Data Pipeline
Legacy + Cloud Data
      ↓
Standardization
      ↓
SQL Reconciliation
      ↓
QA / Exception Handling
      ↓
Reporting Model
      ↓
Tableau



## Files

* `Research Administration Data Reconciliation Project.xlsx` — project workbook containing the source data, reconciliation results, mappings, QA checks, KPI definitions. 
* `data/` — synthetic CSV datasets used in the project
* `research_migration.sql` — SQL used to stage, compare and reconcile the datasets

## Reconciliation test cases

The dataset contains 2,500 synthetic legacy proposal records. I intentionally introduced 52 migration issues so the reconciliation logic could be tested against realistic problems such as:

* missing records
* duplicate records
* funding mismatches
* invalid dimension keys
* date inconsistencies
* status mapping issues

The final `fact_research_activity.csv` contains the standardized records prepared for reporting after those issues are resolved.

## Tableau Dashboard

### Research Portfolio Overview
![Research Portfolio Overview](images/Dashboard%20Page1.png)


### Migration & Data Quality
![Migration and Data Quality](images/Dashboard%20Page2.png) 

View interactive dashboard →
