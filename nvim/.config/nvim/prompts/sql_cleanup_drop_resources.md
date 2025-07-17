You are given a list of Snowflake database objects in a table format with the following columns:

- `ENVIRONMENT`: The Snowflake database name (e.g., CPE_PROD or CPE_DEV)
- `SCHEMA`: The schema name
- `OBJECT TYPE`: One of FUNCTION, PROCEDURE, TABLE, VIEW, or STREAM
- `NAME`: The object name

Each row represents an object that must be dropped from the database.

**Your task:**

Generate a clean SQL script that issues appropriate `DROP` statements for each object, using correct Snowflake syntax:

- For `FUNCTION`, use: `DROP FUNCTION IF EXISTS ENV.SCHEMA.NAME();`
- For `PROCEDURE`, use: `DROP PROCEDURE IF EXISTS ENV.SCHEMA.NAME();`
- For `TABLE`, use: `DROP TABLE IF EXISTS ENV.SCHEMA.NAME;`
- For `VIEW`, use: `DROP VIEW IF EXISTS ENV.SCHEMA.NAME;`
- For `STREAM`, use: `DROP STREAM IF EXISTS ENV.SCHEMA.NAME;`

**Output formatting rules:**

1. Combine all statements into a single SQL script.
2. Group statements by `ENVIRONMENT`. Each section must begin with a clear comment like:
   `-- ======= CPE_PROD DROPS =======`
3. Each object name must be fully qualified using `ENVIRONMENT.SCHEMA.OBJECT`.
4. Do **not** include any explanation or commentary outside of comments that label environment sections.
5. If an `OBJECT TYPE` is not recognized, skip the row silently.

Below is the table of input data:

```text
[REPLACE WITH TABLE DATA]
