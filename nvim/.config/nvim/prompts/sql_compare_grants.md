# Snowflake Role Grant Comparison Query Generator

I need you to generate a SQL query that compares grants between two Snowflake roles.

## Step 1: Collect Information

Please ask me for:
1. **Role 1 Name**: The first role to compare
2. **Role 2 Name**: The second role to compare
3. **Environment Type**: 
   - Cross-Environment (comparing Dev vs Prod, different databases)
   - Same-Environment (comparing two roles in the same database)
4. **Connection Details**:
   - If Cross-Environment: Which snowsql connection for each role (claude-dev or claude-prod)
   - If Same-Environment: Which single snowsql connection to use

## Step 2: Generate SQL Query

Based on my inputs, generate a complete SQL query that:

1. Uses `SHOW GRANTS TO ROLE` to fetch grant data for both roles
2. Normalizes database names (for cross-environment only):
   - Replace database names with `{DB}` placeholder
   - Example: `DEV_DATABASE.SALES.CUSTOMERS` → `{DB}.SALES.CUSTOMERS`
   - Example: `PROD_DATABASE.SALES.CUSTOMERS` → `{DB}.SALES.CUSTOMERS`
3. Compares grants on ALL attributes: privilege, object_type, object_name, grant_option, granted_by
4. Produces a single result set with three categories:
   - `BOTH`: Grants that exist in both roles
   - `ONLY_ROLE1`: Grants that exist only in the first role
   - `ONLY_ROLE2`: Grants that exist only in the second role

## Required Query Structure

The query should use this structure:

```sql
-- ============================================================
-- SNOWFLAKE ROLE GRANT COMPARISON
-- Role 1: {ROLE1_NAME} 
-- Role 2: {ROLE2_NAME}
-- Environment: {CROSS_ENV or SAME_ENV}
-- ============================================================

-- First, run these commands to fetch grant data:
-- snowsql -c {CONNECTION1} -q "SHOW GRANTS TO ROLE {ROLE1}"
-- snowsql -c {CONNECTION2} -q "SHOW GRANTS TO ROLE {ROLE2}"

WITH role1_raw_grants AS (
    -- After running: SHOW GRANTS TO ROLE {ROLE1};
    SELECT * FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))
),
role2_raw_grants AS (
    -- After running: SHOW GRANTS TO ROLE {ROLE2};
    SELECT * FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))
),
role1_normalized_grants AS (
    SELECT 
        privilege,
        granted_on AS object_type,
        -- NORMALIZATION LOGIC HERE
        CASE 
            WHEN granted_on = 'ACCOUNT' THEN name
            WHEN granted_on = 'DATABASE' THEN '{DB}'  -- For cross-env only
            WHEN name LIKE '%.%' THEN 
                '{DB}' || SUBSTR(name, POSITION('.' IN name))  -- For cross-env only
            ELSE name
        END AS object_name,
        grant_option,
        granted_by
    FROM role1_raw_grants
),
role2_normalized_grants AS (
    SELECT 
        privilege,
        granted_on AS object_type,
        -- SAME NORMALIZATION LOGIC
        CASE 
            WHEN granted_on = 'ACCOUNT' THEN name
            WHEN granted_on = 'DATABASE' THEN '{DB}'
            WHEN name LIKE '%.%' THEN 
                '{DB}' || SUBSTR(name, POSITION('.' IN name))
            ELSE name
        END AS object_name,
        grant_option,
        granted_by
    FROM role2_raw_grants
)

-- Grants in BOTH roles
SELECT 
    'BOTH' AS comparison_result,
    privilege, 
    object_type, 
    object_name, 
    grant_option, 
    granted_by
FROM role1_normalized_grants
INTERSECT
SELECT 
    'BOTH' AS comparison_result,
    privilege, 
    object_type, 
    object_name, 
    grant_option, 
    granted_by
FROM role2_normalized_grants

UNION ALL

-- Grants ONLY in role1
SELECT 
    'ONLY_ROLE1' AS comparison_result,
    privilege, 
    object_type, 
    object_name, 
    grant_option, 
    granted_by
FROM role1_normalized_grants
EXCEPT
SELECT 
    'ONLY_ROLE1' AS comparison_result,
    privilege, 
    object_type, 
    object_name, 
    grant_option, 
    granted_by
FROM role2_normalized_grants

UNION ALL

-- Grants ONLY in role2
SELECT 
    'ONLY_ROLE2' AS comparison_result,
    privilege, 
    object_type, 
    object_name, 
    grant_option, 
    granted_by
FROM role2_normalized_grants
EXCEPT
SELECT 
    'ONLY_ROLE2' AS comparison_result,
    privilege, 
    object_type, 
    object_name, 
    grant_option, 
    granted_by
FROM role1_normalized_grants

ORDER BY comparison_result, object_type, object_name, privilege;
```

## Important Notes

1. **For Same-Environment**: Skip the `{DB}` normalization - just use `name` directly in the CASE statements
2. **For Cross-Environment**: Use the full normalization logic shown above
3. Include helpful comments in the generated SQL
4. Provide usage instructions after the query

## Output Format

After generating the query, provide:
1. The complete SQL query ready to copy/paste
2. Step-by-step instructions on how to run it
3. Brief explanation of how to interpret the results

