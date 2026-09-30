---
name: validate-table-sync
description: Validates that table pairs across two Snowflake schemas are synchronized in structure, row counts, and data content
---

# Table Synchronization Validation Skill

Use this skill when you need to verify that tables in two different schemas are perfectly synchronized.

## When to Use

- Validating DATA ↔ DATA_DICTIONARY schema synchronization
- Confirming table replication or mirroring accuracy
- Verifying data pipeline integrity between source and target tables
- Post-deployment validation of schema migrations

## Automatic Configuration

### Database Connection Mapping

The skill automatically maps databases to their snowsql connections:

| Database | Snowsql Connection |
|----------|-------------------|
| `CPE_DEV` | `snowsql -c claude-dev` |
| `CPE_PROD` | `snowsql -c claude-prod` |

**Do not ask the user for the connection string.** The connection is automatically determined from the database name.

### Default Table Mapping (DATA ↔ DATA_DICTIONARY)

When validating `DATA` vs `DATA_DICTIONARY` schemas, use this default mapping unless user specifies otherwise:

| # | DATA Schema Table | DATA_DICTIONARY Schema Table |
|---|-------------------|------------------------------|
| 1 | SWITCH_SERVICE | RULEDATA_PHARMACY_SWITCH_SERVICE |
| 2 | PRICE_SCHEDULES | MYRX_PRICE_SCHEDULES |
| 3 | SWITCH_PRICE_SCHEDULE_PRODUCTS_NDC | MYRX_SWITCH_PRICE_SCHEDULE_PRODUCTS_NDC |
| 4 | RULE_DATA_TENANT | RULEDATA_TENANT |
| 5 | RULE_DATA_ROUTE | RULEDATA_ROUTE |
| 6 | RULE_DATA_PLAN_PCN | RULEDATA_PLAN_PCN |
| 7 | RULE_DATA_PLAN_FEE | RULEDATA_PLAN_FEE |
| 8 | RULE_DATA_PLAN | RULEDATA_PLAN |
| 9 | RULE_DATA_PHARMACY_IDENTIFIER | RULEDATA_PHARMACY_IDENTIFIER |
| 10 | RULE_DATA_PHARMACY_DATA_COLLECTION_OPTIONS | RULEDATA_PHARMACY_DATA_COLLECTION_OPTIONS |
| 11 | RULE_DATA_PAYER_TYPE | RULEDATA_PAYER_TYPE |
| 12 | POWERLINE_RULE_DATA_PHARMACY | RULEDATA_PHARMACY |
| 13 | PHARMACY_ID | DREMIO_PHARMACY_ID |

**Primary keys for data sampling:**
- Most tables: `ID` column
- PRICE_SCHEDULES / MYRX_PRICE_SCHEDULES: `PRICE_SCHEDULE_ID`
- SWITCH_PRICE_SCHEDULE_PRODUCTS_NDC / MYRX_SWITCH_PRICE_SCHEDULE_PRODUCTS_NDC: `PRICE_SCHEDULE_PRODUCT_NDC_ID`
- RULE_DATA_PHARMACY_DATA_COLLECTION_OPTIONS / RULEDATA_PHARMACY_DATA_COLLECTION_OPTIONS: `RECORD_ID`
- PHARMACY_ID / DREMIO_PHARMACY_ID: `LOCATION_PHARMACY_ID`

## Input Parameters

Before starting, gather the following information from the user:

1. **Database name** (e.g., `CPE_DEV` or `CPE_PROD`) - *connection is automatically determined*
2. **Source schema** (e.g., `DATA`)
3. **Target schema** (e.g., `DATA_DICTIONARY`)
4. **Table mapping** (optional if using DATA ↔ DATA_DICTIONARY default):
   - If schemas are `DATA` and `DATA_DICTIONARY`, use the default 13-table mapping above
   - Otherwise, ask user for custom mapping:
     ```
     SOURCE_TABLE_1 → TARGET_TABLE_1
     SOURCE_TABLE_2 → TARGET_TABLE_2
     ...
     ```
5. **Sample size** (optional, default: 2 records per table)

## Validation Process

**Important:** Before executing any queries, determine the connection string:
- If database = `CPE_DEV`, use `snowsql -c claude-dev`
- If database = `CPE_PROD`, use `snowsql -c claude-prod`

### Phase 1: Row Count Validation

**Objective:** Verify all table pairs have matching row counts.

**Steps:**

1. Generate a single SQL query that compares counts for all table pairs:

```sql
SELECT 'SOURCE_TABLE_1 vs TARGET_TABLE_1' AS comparison,
       (SELECT COUNT(*) FROM {database}.{source_schema}.SOURCE_TABLE_1) AS source_count,
       (SELECT COUNT(*) FROM {database}.{target_schema}.TARGET_TABLE_1) AS target_count,
       (SELECT COUNT(*) FROM {database}.{source_schema}.SOURCE_TABLE_1) - 
       (SELECT COUNT(*) FROM {database}.{target_schema}.TARGET_TABLE_1) AS difference
UNION ALL
SELECT 'SOURCE_TABLE_2 vs TARGET_TABLE_2',
       (SELECT COUNT(*) FROM {database}.{source_schema}.SOURCE_TABLE_2),
       (SELECT COUNT(*) FROM {database}.{target_schema}.TARGET_TABLE_2),
       (difference calculation)
-- Repeat for all table pairs
```

2. Execute the query using `snowsql`
3. Parse results and flag any non-zero differences
4. Store results for final report

**Success Criteria:** All differences = 0

### Phase 2: Structure Validation

**Objective:** Verify table structures are identical (columns, types, order).

**Steps:**

For each table pair:

1. Execute DESCRIBE on source table:
   ```sql
   DESCRIBE TABLE {database}.{source_schema}.{SOURCE_TABLE};
   ```

2. Execute DESCRIBE on target table:
   ```sql
   DESCRIBE TABLE {database}.{target_schema}.{TARGET_TABLE};
   ```

3. Compare the outputs focusing on:
   - Column name (must match exactly)
   - Column type (must match exactly, including precision)
   - Column order (must match position)
   - Number of columns (must match)

4. Flag any discrepancies:
   - Missing columns
   - Extra columns
   - Type mismatches
   - Order differences

**Success Criteria:** All columns match in name, type, and order

### Phase 3: Data Content Validation

**Objective:** Verify actual data records exist in both tables.

**Steps:**

For each table pair:

1. **Identify primary key column(s):**
   - Look for ID, composite keys, or unique identifiers
   - If not obvious, ask the user
   - Common patterns: `ID`, `{TABLE}_ID`, composite of multiple columns

2. **Sample records from source:**
   ```sql
   SELECT {key_columns}, {sample_columns} 
   FROM {database}.{source_schema}.{SOURCE_TABLE} 
   LIMIT {sample_size};
   ```

3. **Verify records exist in target:**
   ```sql
   SELECT {key_columns}, {sample_columns}
   FROM {database}.{target_schema}.{TARGET_TABLE}
   WHERE {primary_key} IN (
     SELECT {primary_key} 
     FROM {database}.{source_schema}.{SOURCE_TABLE} 
     LIMIT {sample_size}
   );
   ```

4. **Compare results:**
   - Count of returned records (should match sample size)
   - Data values in key columns (should be identical)
   - If counts don't match, identify missing records

5. **Handle empty tables:**
   - If both tables are empty (count = 0), mark as synchronized
   - If one is empty and one isn't, flag as mismatch

**Success Criteria:** All sampled records found in both tables with matching values

### Phase 4: Generate Report

**Objective:** Provide comprehensive validation summary.

**Report Structure:**

```markdown
## Table Synchronization Validation Report

**Database:** {database}  
**Source Schema:** {source_schema}  
**Target Schema:** {target_schema}  
**Validation Date:** {current_date}  
**Overall Status:** ✅ SYNCHRONIZED / ❌ DISCREPANCIES FOUND

### Phase 1: Row Count Validation

| # | Source Table | Target Table | Source Count | Target Count | Difference | Status |
|---|--------------|--------------|--------------|--------------|------------|--------|
| 1 | TABLE_1      | TABLE_1      | 1,000        | 1,000        | 0          | ✅     |
| 2 | TABLE_2      | TABLE_2      | 500          | 498          | 2          | ❌     |

**Summary:** {X}/{Y} tables synchronized ({percentage}%)

### Phase 2: Structure Validation

| # | Table Pair | Columns Match | Types Match | Order Match | Status |
|---|------------|---------------|-------------|-------------|--------|
| 1 | TABLE_1    | ✅            | ✅          | ✅          | ✅     |
| 2 | TABLE_2    | ❌            | ✅          | ✅          | ❌     |

**Discrepancies:**
- TABLE_2: Missing column `NEW_COLUMN` in target
- TABLE_3: Type mismatch on `AMOUNT` (VARCHAR vs NUMBER)

**Summary:** {X}/{Y} tables structurally identical ({percentage}%)

### Phase 3: Data Content Validation

| # | Table Pair | Sample Size | Records Found | Missing Records | Status |
|---|------------|-------------|---------------|-----------------|--------|
| 1 | TABLE_1    | 2           | 2             | 0               | ✅     |
| 2 | TABLE_2    | 2           | 1             | 1               | ❌     |

**Sample Details:**
- TABLE_1: IDs sampled: 123, 456 - Both found ✅
- TABLE_2: IDs sampled: 789, 012 - Missing: 012 ❌

**Summary:** {X}/{Y} tables with matching data ({percentage}%)

### Overall Assessment

✅ **Fully Synchronized:** {count} table pairs  
⚠️  **Row Count Mismatch:** {count} table pairs  
⚠️  **Structure Mismatch:** {count} table pairs  
⚠️  **Data Content Mismatch:** {count} table pairs  

**Total Records Validated:** {total_row_count}  
**Total Sample Records:** {total_samples}

### Recommended Actions

{If all pass:}
✅ All validations passed. Schemas are fully synchronized.

{If failures:}
1. Investigate row count mismatches in: {list tables}
2. Review structure differences in: {list tables}
3. Check data pipeline for: {list tables with data issues}
4. Consider re-running failed table exports/imports
```

## Error Handling

### Connection Failures
- **Automatic connection mapping:**
  - `CPE_DEV` → `snowsql -c claude-dev`
  - `CPE_PROD` → `snowsql -c claude-prod`
- Verify connection works: Test with simple query like `SELECT CURRENT_DATABASE();`
- Check credentials and permissions
- Ensure database and schemas exist

### Query Failures
- If DESCRIBE fails: Table may not exist or no permissions
- If COUNT fails: May indicate corrupted table or permission issue
- If sampling fails: Primary key assumption may be wrong

### Partial Validation
- If Phase 1 fails on some tables, continue with others
- Report all issues, don't stop on first failure
- Flag which validations couldn't be completed

## Example Usage

**Example 1: Development Database**

**User:** "Validate that DATA and DATA_DICTIONARY schemas are in sync for CPE_DEV"

**Assistant:**
1. Determine connection: `CPE_DEV` → `snowsql -c claude-dev`
2. Request table mapping or use known mapping
3. Execute Phase 1 (counts)
4. Execute Phase 2 (structure) 
5. Execute Phase 3 (data sampling)
6. Generate and present report

**Example 2: Production Database**

**User:** "Run the same validation for CPE_PROD"

**Assistant:**
1. Determine connection: `CPE_PROD` → `snowsql -c claude-prod`
2. Use same table mapping as development
3. Execute all three phases
4. Compare production results to development results if needed

## Notes

- **Performance:** Count queries on large tables (millions of rows) may take 1-2 seconds each
- **Sampling Strategy:** Uses LIMIT which gives arbitrary records, not random sampling
- **Primary Keys:** If composite keys exist, must query all key columns in IN clause
- **Empty Tables:** Both empty = synchronized, one empty = mismatch
- **Large Schema:** For 50+ tables, consider running phases separately or in batches

## Customization Options

Allow user to customize:
- **Sample size:** Default 2, allow 1-10
- **Columns to compare:** Can specify subset of columns instead of all
- **Skip phases:** e.g., "Only validate counts, skip structure"
- **Focus tables:** Validate specific subset instead of all tables

## Success Indicators

✅ All three phases pass for all table pairs  
✅ Zero differences in row counts  
✅ Identical structure across all tables  
✅ Sample data matches perfectly
