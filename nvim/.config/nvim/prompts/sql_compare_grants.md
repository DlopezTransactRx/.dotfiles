# Snowflake Role Grant Comparison Query Generator

I need you to generate a SQL query that compares grants between two Snowflake roles within the same account.

## Step 1: Collect Information

Please ask me for:
1. **Role 1 Name**: The first role to compare
2. **Role 2 Name**: The second role to compare

**Note**: 
- Both roles must exist in the same Snowflake account accessible via `snowsql -c claude-dev`
- Database names will be automatically normalized (no need to specify patterns)

## Step 2: Generate SQL Query

Based on my inputs, generate a complete SQL query that:

1. Uses `SHOW GRANTS TO ROLE` to fetch grant data for both roles
2. **Automatically normalizes database names** in fully-qualified object names:
   - Replaces the database portion (everything before the first `.`) with `{DB}`
   - Works for ANY database name - no need to specify patterns
   - Examples:
     - `DEV_DATABASE.SALES.CUSTOMERS` → `{DB}.SALES.CUSTOMERS`
     - `PROD_DATABASE.SALES.CUSTOMERS` → `{DB}.SALES.CUSTOMERS`
     - `RAS_DEV.PUBLIC.USERS` → `{DB}.PUBLIC.USERS`
     - `RAS_PROD.PUBLIC.USERS` → `{DB}.PUBLIC.USERS`
3. Compares grants on ALL attributes: privilege, object_type, object_name, grant_option, granted_by
4. Produces a single result set with three categories:
   - `BOTH`: Grants that exist in both roles
   - `ONLY_{ROLE1}`: Grants that exist only in the first role
   - `ONLY_{ROLE2}`: Grants that exist only in the second role

## Required Query Structure

The query should use this structure:

```sql
-- ============================================================
-- SNOWFLAKE ROLE GRANT COMPARISON
-- Role 1: {ROLE1_NAME} 
-- Role 2: {ROLE2_NAME}
-- Connection: claude-dev
-- ============================================================

-- Step 1: Show grants for Role 1
SHOW GRANTS TO ROLE {ROLE1};

-- Step 2: Show grants for Role 2
SHOW GRANTS TO ROLE {ROLE2};

-- Step 3: Run the comparison query below

WITH role1_raw_grants AS (
    -- Captures the first SHOW GRANTS result
    -- NOTE: You must run both SHOW GRANTS commands above first,
    -- then use RESULT_SCAN to get the second-to-last query
    SELECT * FROM TABLE(RESULT_SCAN(LAST_QUERY_ID(-1)))
),
role2_raw_grants AS (
    -- Captures the second SHOW GRANTS result
    SELECT * FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))
),
role1_normalized_grants AS (
    SELECT 
        privilege,
        granted_on AS object_type,
        -- Automatically normalize database names
        CASE 
            WHEN granted_on = 'ACCOUNT' THEN name
            WHEN granted_on = 'DATABASE' THEN '{DB}'
            WHEN name LIKE '%.%' THEN 
                -- Replace database portion with {DB} for fully-qualified names
                '{DB}' || SUBSTR(name, POSITION('.' IN name))
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
        -- Same automatic normalization logic
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
    'ONLY_{ROLE1}' AS comparison_result,
    privilege, 
    object_type, 
    object_name, 
    grant_option, 
    granted_by
FROM role1_normalized_grants
EXCEPT
SELECT 
    'ONLY_{ROLE1}' AS comparison_result,
    privilege, 
    object_type, 
    object_name, 
    grant_option, 
    granted_by
FROM role2_normalized_grants

UNION ALL

-- Grants ONLY in role2
SELECT 
    'ONLY_{ROLE2}' AS comparison_result,
    privilege, 
    object_type, 
    object_name, 
    grant_option, 
    granted_by
FROM role2_normalized_grants
EXCEPT
SELECT 
    'ONLY_{ROLE2}' AS comparison_result,
    privilege, 
    object_type, 
    object_name, 
    grant_option, 
    granted_by
FROM role1_normalized_grants

ORDER BY comparison_result, object_type, object_name, privilege;
```

## Output Format

After generating the query, provide:
1. The complete SQL query ready to copy/paste (with role names substituted)
2. Step-by-step instructions on how to run it
3. Brief explanation of how to interpret the results

## How Database Normalization Works

The normalization logic automatically handles any database names:

- **Account-level grants**: No normalization (`ACCOUNT` stays as-is)
- **Database grants**: Database name → `{DB}`
- **Fully-qualified names**: `DATABASE.SCHEMA.OBJECT` → `{DB}.SCHEMA.OBJECT`
- **Schema/table only**: No normalization (no `.` found)

This works for ANY database naming convention without requiring you to specify patterns.

## Example Usage

```bash
# Connect to Snowflake
snowsql -c claude-dev

# Run the three commands in sequence:
# 1. SHOW GRANTS TO ROLE ROLE1;
# 2. SHOW GRANTS TO ROLE ROLE2;
# 3. SELECT ... (the comparison query)
```
