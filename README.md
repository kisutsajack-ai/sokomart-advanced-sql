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
