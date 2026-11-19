# SokoMart Kenya — Advanced SQL

**Jack Kisutsa | LuxDevHQ Cohort 9**

SQL analysis of SokoMart Kenya’s customers, sales, products and payments, covering 10 practice drills and 25 questions using PostgreSQL and DBeaver.

## Files

| SQL file | Contents | Result screenshots |
|---|---|---|
| [00_practice_drills.sql](sql/00_practice_drills.sql) | D1–D10 | [Practice drills](screenshots/practice_drills/) |
| [01_section_a.sql](sql/01_section_a.sql) | Q1–Q5: CTEs and subqueries | [Section A](screenshots/section_a/) |
| [01_section_b.sql](sql/01_section_b.sql) | Q6–Q10: window functions | [Section B](screenshots/section_b/) |
| [01_section_c.sql](sql/01_section_c.sql) | Q11–Q15: advanced aggregation | [Section C](screenshots/section_c/) |
| [01_section_d.sql](sql/01_section_d.sql) | Q16–Q20: views, functions, procedures and triggers | [Section D](screenshots/section_d/) |
| [01_section_e.sql](sql/01_section_e.sql) | Q21–Q25: optimisation and transactions | [Section E](screenshots/section_e/) |

## How to run

1. Install PostgreSQL 14+ and connect in DBeaver to `luxdevhq_cohort9_advanced_sql`.
2. Using the original course package, create the database/schema, then run `03_create_tables.sql`, the data loader (`04_insert_data.sql` through psql, or `04b_insert_data_inserts.sql` in DBeaver), and `05_indexes.sql`.
3. Run `06_validation.sql` and confirm all **41 checks PASS**. Skip loading again if your existing database already passes.
4. Run the practice drills, then Sections **A → B → C → D → E**, question by question. Section D’s later questions depend on objects created earlier; keep the same connection.
5. Save a screenshot of each result in the matching `screenshots/` subfolder, named `q01_result.png`, `q01_summary.png`, etc. Include required error messages and before/after checks. For Q21–Q22, record your own query-plan measurements; Q22 uses the original `05_indexes.sql` for its before/after comparison.

**Transaction exercises:** run statements individually. Intentional-error examples are labelled inside SQL comments; copy them out and execute separately. Run Q20’s insufficient-stock example before Q23 restocks product 59.

**Fresh results:** Sections D and E change data. Use the course’s `07_reset_database.sql`, reload with **03 → 04/04b → 05**, and validate again when repeating the exercises. Capture Q25’s original-data result before Section D, or after a fresh reload. Q20 creates an order dated today.

Screenshot folders are ready for your images. Source CSVs, database dumps and credentials are excluded from this repository.

## Business insights and recommendations

1. **Target the high-spending 2025 cohort (Q1).** Of 4,358 customers with completed purchases in 2025, **1,432** spent above the mean of **KES 118,774.54**. Use that cohort for the loyalty launch, then measure response and repeat purchases rather than inviting every customer indiscriminately.
2. **Plan around the observed year-end peak (Q8).** December 2025 revenue was **KES 72,805,462.45**, the highest month in this dataset and **9.61% above November**. Prepare stock and fulfilment capacity ahead of the year-end period; one observed year is evidence for planning, not proof of a permanent seasonal pattern.
3. **Protect profitable categories (Q14).** Electronics generated **KES 43,556,264.79** gross profit at **13.37%** margin; Fashion generated **KES 24,378,347.62** at **44.50%** margin. Both exceeded the average category profit of **KES 18,572,448.91**. Protect Electronics volume while testing Fashion bundles that preserve margin.
4. **Investigate payment failures by both volume and rate (Q13).** M-Pesa recorded **1,373 failed payments** with **KES 30,210,227.30** in failed amounts, and an **89.33%** success rate. Its payment volume makes it a useful first investigation target. Failed amounts represent attempted payments, not proven lost revenue; check retries and eventual settlement before valuing recoveries.
5. **Review slow-moving inventory (Q5).** **18 products** never appeared on any order, including non-completed orders. Review age, visibility, availability and category relevance before deciding on promotion or discontinuation.
6. **Stop settlement duplication at ingestion (Q24).** **200 payment IDs** had repeated copies, producing **240 extra rows**. Deduplication reduced staging from **2,640 to 2,400 rows**, and reconciled to **KES 60,184,108.05** in the matching payment records. Retain the earliest copy and enforce unique payment IDs after validation.
7. **Pilot retention offers with established repeat buyers (Q25).** **1,459 customers** bought in at least three consecutive months; the longest run was **22 months**. Use the qualifying cohort for a subscription or repeat-order pilot, and compare retention and incremental profit against a suitable control group.

**First priority:** investigate M-Pesa’s failed-payment journey because it combines high transaction volume with KES 30.21 million in failed attempts. Start by reconciling failed attempts to retries and successful payments, then address the largest verified failure causes. This creates a measurable operational improvement without assuming every failed attempt was a lost sale.
