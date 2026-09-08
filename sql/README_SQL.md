# Snowflake SQL execution order

## 1. `01_setup.sql`
Creates the Snowflake database and the three logical schemas:

- `STAGING` — raw/source tables and standardized views
- `QA` — reconciliation exceptions and data-quality logic
- `REPORTING` — Tableau-ready views and KPIs

The CSV source/reference tables are assumed to have already been loaded into `STAGING`.
For the portfolio, ingestion was intentionally kept simple rather than presenting a
production `STAGE` / `COPY INTO` / Snowpipe process that was not actually implemented.

## 2. `02_standardize_sources.sql`
Creates:

- `VW_LEGACY_STANDARDIZED`
- `VW_CURRENT_STANDARDIZED`

This layer:
- trims/normalizes IDs
- converts blanks to `NULL`
- parses dates/timestamps
- casts monetary values to decimals
- maps source statuses through `STATUS_MAPPING`
- preserves raw submission values for QA traceability

Conceptually this is similar to a **Silver/cleaned layer**.

## 3. `03_deduplicate_current.sql`
Creates:

- `QA.VW_DUPLICATE_PROPOSALS`
- `STAGING.VW_CURRENT_LATEST`

This establishes the intended reconciliation grain:
**one latest current-system row per proposal**.

## 4. `04_migration_qa.sql`
Creates:

- `QA.QA_MIGRATION_ISSUES`

Checks for:
- missing migrations
- duplicate current records
- requested-amount mismatches
- award-amount mismatches
- missing/invalid investigators
- unmapped statuses
- invalid sponsors
- invalid colleges
- submission-date mismatches

The dimension/mapping tables are used as governed reference data instead of relying
only on hard-coded invalid values.

## 5. `05_reporting_views.sql`
Creates the Tableau-facing reporting layer:

- `REPORTING.TABLEAU_MIGRATION_KPIS`
- `REPORTING.VW_CERTIFIED_CURRENT_PROPOSALS`
- `REPORTING.VW_RESEARCH_ACTIVITY`

`VW_RESEARCH_ACTIVITY` explains the creation of the portfolio fact dataset:
the complete legacy proposal population is enriched with investigator, college,
and sponsor dimensions and with derived reporting fields such as fiscal year and
days to decision.

Conceptually this is similar to a **Gold/reporting layer**.

## 6. `06_validation_checks.sql`
Runs:
- source row-count / distinct-count checks
- QA counts by issue type and severity
- expected 52-issue validation
- dimension completeness checks for the research-activity fact
- final inspection queries for the three Tableau-facing outputs

## Tableau handoff used in the portfolio

For the standalone portfolio, the final Snowflake query outputs were represented as
CSV data sources in Tableau:

- `VW_RESEARCH_ACTIVITY` → `fact_research_activity.csv`
- `QA_MIGRATION_ISSUES` → `qa_issue_log.csv`
- `TABLEAU_MIGRATION_KPIS` → `tableau_migration_kpis.csv`

