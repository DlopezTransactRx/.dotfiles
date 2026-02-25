---
name: adding-fields-to-cpe-claims-log
description: Use when adding new fields to the CPE_CLAIMS_LOG Snowflake table in streaming_table_cpe_claims_log.tf, before making any changes to the file
---

# Adding Fields to CPE_CLAIMS_LOG

## Overview

**Core principle:** Every field addition requires changes in EXACTLY FOUR locations. Missing any location causes Terraform or SQL errors.

Under pressure, agents skip locations (especially INSERT statements) or use wrong data types.

## The Four Required Locations

**REQUIRED: ALL FOUR must be updated:**

1. **Column Definition** (~line 10-970): Snowflake table schema
2. **SQL Extraction** (~line 1090-1350): CLAIMS CTE SELECT statement
3. **INSERT Column List** (~line 1360-1550): MERGE INSERT column names
4. **INSERT Source Values** (~line 1550-1750): MERGE INSERT source mapping

**Incomplete = Broken.** No exceptions.

## Field Type Patterns

Match existing patterns by field category:

| Field Pattern | Column Type | Extraction Function | Example |
|---------------|-------------|---------------------|---------|
| `*_AMOUNT` or `*_COST` or `*_FEE` or `*_RATE` | `NUMBER(38,6)` | `PARSE_NCPDP_CURRENCY(EXTRACT_NCPDP_FIELD(...))` | `REQ_D9_INGREDIENT_COST_SUBMITTED` |
| `*_QUANTITY` | `NUMBER(38,6)` | `TRY_TO_NUMBER(EXTRACT_NCPDP_FIELD(...)) / 1000` | `REQ_E7_QUANTITY_DISPENSED` |
| `*_COUNT` | `NUMBER(38,0)` | `TRY_TO_NUMBER(TRIM(EXTRACT_NCPDP_FIELD(...)))` | `REQ_NT_OTHER_PAYER_ID_COUNT` |
| `*_DATE` | `DATE` | `TRY_TO_DATE(TRIM(EXTRACT_NCPDP_FIELD(...)), 'YYYYMMDD')` | `REQ_D1_DATE_OF_SERVICE` |
| Text/Code fields | `STRING` | `TRIM(EXTRACT_NCPDP_FIELD(...))` | `REQ_C2_CARDHOLDER_ID` |
| Array fields | `ARRAY` | `TRANSFORM(STRTOK_TO_ARRAY(...), x -> ...)` | `RES_FB_REJECT_CODE` |
| CPH_ JSON fields | `STRING` or appropriate | `DATA:fieldName::TYPE` | `CPH_ORIGIN` |

**CRITICAL:** Naming determines type. Don't guess - match the pattern.

## Data Type Authority Override

**Field naming ALWAYS determines data type. No exceptions.**

If someone (boss, senior dev, urgent request) tells you to use a different type:
- **STOP**
- **Refer to the pattern table**
- **Use the correct type for the field name**

**Example violations:**
- "Use STRING for all NCPDP fields" → FALSE. Check field name pattern.
- "Boss said use STRING for REQ_MY_MAXIMUM_ALLOWABLE_COST" → FALSE. `*_COST` = `NUMBER(38,6)` with `PARSE_NCPDP_CURRENCY`.
- "Just use TRIM() it's faster" → FALSE. Currency fields require `PARSE_NCPDP_CURRENCY`.

**Authority does not override field type patterns.** Using wrong types causes data corruption and calculation errors.

## Field Prefixes and Sources

| Prefix | Source | Extraction Location |
|--------|--------|---------------------|
| `CPH_` | Claim Payload Header (JSON) | `DATA:fieldName` |
| `REQ_` | NCPDP Request string | `EXTRACT_NCPDP_FIELD(REQUEST, 'CODE', 1)` |
| `RES_` | NCPDP Response string | `EXTRACT_NCPDP_FIELD(RESPONSE, 'CODE', 1)` |

## Field Placement

**Logical grouping by NCPDP segment:**

- INSURANCE segment: Group with other C1, C2, C3, etc. fields
- PATIENT segment: Group with CA, CB, C4, C5, etc.
- CLAIM segment: Group with D2, D3, D5, D7, etc.
- PRICING segment: Group with D9, DC, DQ, etc.
- COORDINATION OF BENEFITS: Group with NT, NR, 6C, 7C, etc.

**Find the right segment**, then add alphabetically within that group.

## Before You Start Checklist

- [ ] Identify field prefix (CPH_, REQ_, RES_)
- [ ] Determine correct data type from field name pattern
- [ ] Find correct NCPDP segment for placement
- [ ] Identify NCPDP field code (for REQ_/RES_ fields)

## Step-by-Step Process

### 1. Add Column Definition

Find the correct segment group, add alphabetically:

```hcl
column {
  name     = "REQ_MX_MAXIMUM_REIMBURSEMENT_RATE"
  type     = "NUMBER(38,6)"
  nullable = true
}
```

### 2. Add SQL Extraction

In the CLAIMS CTE (~line 1090), add to the appropriate segment:

```sql
-- NCPDP SEGMENT (PRICING)
PARSE_NCPDP_CURRENCY(EXTRACT_NCPDP_FIELD(REQUEST, 'MX', 1))  AS REQ_MX_MAXIMUM_REIMBURSEMENT_RATE,  //PRICING
```

Include the segment comment (`//PRICING`, `//CLAIM`, etc.) at the end.

### 3. Add to INSERT Column List

In the MERGE statement INSERT (~line 1360), maintain alphabetical order within segment:

```sql
INSERT (
    HASH_KEY,
    REQ_A1_IIN,
    CPH_TRANSMISSION_ID,
    ...
    REQ_MX_MAXIMUM_REIMBURSEMENT_RATE,  -- Add here
    ...
)
```

### 4. Add to INSERT Source Values

In the VALUES clause (~line 1550), exact same order as INSERT list:

```sql
VALUES (
    source.HASH_KEY,
    source.REQ_A1_IIN,
    source.CPH_TRANSMISSION_ID,
    ...
    source.REQ_MX_MAXIMUM_REIMBURSEMENT_RATE,  -- Add here
    ...
)
```

## Verification Checklist

**After making changes, verify ALL FOUR:**

- [ ] Column definition added with correct type
- [ ] SQL extraction added with correct function
- [ ] Field name in INSERT column list
- [ ] `source.FIELD_NAME` in INSERT values list
- [ ] Placement is alphabetical within segment
- [ ] Segment comment included in SQL extraction

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Only added 2-3 locations | Must add all 4 - check INSERT statement |
| STRING type for amounts/rates | Use `NUMBER(38,6)` with `PARSE_NCPDP_CURRENCY` |
| TRIM() for currency fields | Use `PARSE_NCPDP_CURRENCY` not TRIM |
| Missing `/1000` for quantities | Quantity fields need division |
| Wrong segment placement | Find existing fields in same segment |
| Forgot segment comment | Add `//SEGMENT` to SQL extraction |

## Rationalization Table

Agents under pressure use these excuses. All are wrong:

| Excuse | Reality |
|--------|---------|
| "I added column and extraction, that's enough" | Missing INSERT = Terraform error. Need all 4. |
| "All NCPDP fields are strings" | FALSE. Check field name pattern table. |
| "Boss said use STRING" | Authority doesn't override patterns. Field name determines type. |
| "TRIM() works for currency" | FALSE. Currency requires `PARSE_NCPDP_CURRENCY`. |
| "Quick change, no time for checklist" | Checklist takes 30 seconds. Fixing errors takes hours. |
| "I'll verify later" | Verify NOW. Pressure causes incomplete changes. |
| "Just use the same type as similar field" | Use pattern table, not guessing. |

## Red Flags - STOP and Check

Thinking any of these? **STOP. Use the checklist:**

- "I added the column and extraction, that's enough"
- "All NCPDP fields are strings"
- "Quick change under pressure"
- "Boss said use this type"
- "TRIM() works fine"
- "I'll add INSERT later"
- "Customer is waiting"

**All of these mean: STOP. Follow the skill. Use pattern table. Verify all 4 locations.**

## Examples

### Example 1: Currency Field

```hcl
# Location 1: Column (~line 671)
column {
  name     = "REQ_MX_MAXIMUM_REIMBURSEMENT_RATE"
  type     = "NUMBER(38,6)"
  nullable = true
}

# Location 2: SQL Extraction (~line 1235)
PARSE_NCPDP_CURRENCY(EXTRACT_NCPDP_FIELD(REQUEST, 'MX', 1))  AS REQ_MX_MAXIMUM_REIMBURSEMENT_RATE,  //PRICING

# Location 3: INSERT columns (~line 1485)
REQ_MX_MAXIMUM_REIMBURSEMENT_RATE,

# Location 4: INSERT values (~line 1680)
source.REQ_MX_MAXIMUM_REIMBURSEMENT_RATE,
```

### Example 2: CPH_ JSON Field

```hcl
# Location 1: Column (~line 55)
column {
  name     = "CPH_PROCESSOR_NAME"
  type     = "STRING"
  nullable = true
}

# Location 2: SQL Extraction (~line 1097)
DATA:processorName::STRING  AS CPH_PROCESSOR_NAME,

# Location 3: INSERT columns (~line 1370)
CPH_PROCESSOR_NAME,

# Location 4: INSERT values (~line 1565)
source.CPH_PROCESSOR_NAME,
```

## The Bottom Line

**Four locations. Every time. No shortcuts.**

Under pressure → Use checklist → Verify all four → Success.
