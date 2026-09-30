---
name: snowflake-role-grant-comparison
description: Generate SQL queries to compare Snowflake role grants across environments with database name normalization. Use when comparing grants between two roles or verifying grant parity across dev/prod.
---

# Snowflake Role Grant Comparison

Generates a read-only SQL query that compares grants between two Snowflake roles, normalizing database names so cross-environment comparisons work correctly.

## Workflow

1. Ask the user for **Role 1** and **Role 2** names
2. Generate SQL that uses `SHOW GRANTS TO ROLE` and `RESULT_SCAN` (no write permissions needed)
3. Output three categories: grants in BOTH roles, grants ONLY in Role 1, grants ONLY in Role 2

## Constraints

- **Read-only access only** — no temp tables, no CREATE statements
- Uses `RESULT_SCAN(LAST_QUERY_ID(-2))` and `RESULT_SCAN(LAST_QUERY_ID(-1))` to reference prior SHOW GRANTS results
- All three statements (two SHOW GRANTS + one SELECT) must run sequentially in the same session
- Database names are normalized to `{DB}` so `DEV_DB.SCHEMA.TABLE` and `PROD_DB.SCHEMA.TABLE` compare as equal

## Generated SQL Template

```sql
-- Step 1: Run these two commands first (order matters)
SHOW GRANTS TO ROLE {ROLE1};
SHOW GRANTS TO ROLE {ROLE2};

-- Step 2: Run the comparison query
WITH role1_grants AS (
    SELECT * FROM TABLE(RESULT_SCAN(LAST_QUERY_ID(-2)))
),
role2_grants AS (
    SELECT * FROM TABLE(RESULT_SCAN(LAST_QUERY_ID(-1)))
),
role1_normalized AS (
    SELECT
        "privilege",
        "granted_on" AS object_type,
        CASE
            WHEN "granted_on" = 'ACCOUNT' THEN "name"
            WHEN "granted_on" = 'DATABASE' THEN '{DB}'
            WHEN "name" LIKE '%.%' THEN '{DB}' || SUBSTR("name", POSITION('.' IN "name"))
            ELSE "name"
        END AS object_name,
        "grant_option",
        "granted_by"
    FROM role1_grants
),
role2_normalized AS (
    SELECT
        "privilege",
        "granted_on" AS object_type,
        CASE
            WHEN "granted_on" = 'ACCOUNT' THEN "name"
            WHEN "granted_on" = 'DATABASE' THEN '{DB}'
            WHEN "name" LIKE '%.%' THEN '{DB}' || SUBSTR("name", POSITION('.' IN "name"))
            ELSE "name"
        END AS object_name,
        "grant_option",
        "granted_by"
    FROM role2_grants
)

SELECT 'BOTH' AS comparison, r1.*
FROM role1_normalized r1
INTERSECT
SELECT 'BOTH', r2.*
FROM role2_normalized r2

UNION ALL

(SELECT 'ONLY_{ROLE1}', r1.*
 FROM role1_normalized r1
 EXCEPT
 SELECT 'ONLY_{ROLE1}', r2.*
 FROM role2_normalized r2)

UNION ALL

(SELECT 'ONLY_{ROLE2}', r2.*
 FROM role2_normalized r2
 EXCEPT
 SELECT 'ONLY_{ROLE2}', r1.*
 FROM role1_normalized r1)

ORDER BY 1, 3, 4, 2;
```

## Interpreting Results

| comparison | Meaning |
|---|---|
| BOTH | Grant exists in both roles (after normalization) |
| ONLY_{ROLE1} | Grant exists only in the first role |
| ONLY_{ROLE2} | Grant exists only in the second role |

## Troubleshooting

- **RESULT_SCAN errors**: All three statements must run in sequence in the same Snowflake session. Do not run other queries between them.
- **Column name issues**: SHOW GRANTS returns lowercase-quoted column names (`"privilege"`, `"granted_on"`, `"name"`, etc.). The query uses quoted identifiers to match.
