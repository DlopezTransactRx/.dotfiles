# 🚀 Postgres to Snowflake Import Prompt

Generate complete Terraform code for Snowflake data ingestion pipelines using the `ImportFromStageTable` module.

## 📋 Task Overview

**Input:** SQL SELECT query + namespace + database name + schema name. 
**Output:** 3 code blocks
1. `snowflake_table` resource
2. `module` block with MERGE SQL
3. JOB SQL statement

## 🎯 Column Type Mapping

**Always include first:**
- VERSION → `NUMBER(38,0)` (from `db_export_record_version`)

**Auto-detect types by pattern:**
| Pattern | Type | Examples |
|---------|------|----------|
| `*id` | `STRING` | programid, userid |
| `*amount` | `NUMBER(38,2)` | total_amount, fee_amount |
| `*quantity` | `DOUBLE` | order_quantity |
| `*date*` | `TIMESTAMP_NTZ` | created_date, date_modified |
| `*age`, `*days`, `*number`, `*fills` | `INTEGER` | patient_age, refill_fills |
| `require*`, `allow*`, `enable*`, `active*` | `BOOLEAN` | requires_auth, active_status |
| Default | `STRING` | notes, email, type |

## 🏗️ Code Structure

### 1. Snowflake Table Resource
```hcl
resource "snowflake_table" "<TABLE_NAME>" {
  name     = "<TABLE_NAME>"
  database = snowflake_database.<DATABASE_NAME>.name
  schema   = snowflake_schema.<SCHEMA_NAME>.name
  comment  = "<RAW_TABLE_NAME> data exported from external <NAMESPACE> database.
"
  column {
    name = "VERSION"
    type = "NUMBER(38,0)"
  }
  # Additional columns...
}
```

### 2. Module Block
```hcl
#=[DataExport - <TABLE_NAME>]========================================================================
# Batch Job           = <NAMESPACE>-<TABLE_NAME>
# Source Database     =  
# Source Table        = <TABLE_NAME>
# Event Type          = <NAMESPACE>-<TABLE_NAME>
# Snowflake Table     = <TABLE_NAME>
#====================================================================================================
module "<TABLE_NAME>" {
  source = "git::https://github.com/transactrx/DataIngestionS3ToSnowflake.git//ImportFromStageTable?ref=main"  
  database_name = snowflake_database.<DATABASE_NAME>.name
  schema_name   = snowflake_schema.<SCHEMA_NAME>.name  
  name = "<TABLE_NAME>"  
  sql_import_query = <<SQL
    # MERGE logic here
  SQL
  load_historical_data = true
  stage_table_full_name = module.events_s3_to_stage_table.stage_table_full_name
  import_interval = "25 * * * * UTC"
}
```

### 3. MERGE SQL Template
```sql
MERGE INTO ${snowflake_table.<TABLE>.database}.${snowflake_table.<TABLE>.schema}.${snowflake_table.<TABLE>.name} AS target
USING (
  WITH ranked_data AS (
    SELECT
      ROW_NUMBER() OVER (
        PARTITION BY DATA:eventPayload:<primary_key>::varchar
        ORDER BY DATA:eventPayload:db_export_record_version::numeric DESC
      ) AS rnk,
      DATA:eventPayload:db_export_record_version::numeric AS VERSION,
      # Cast all fields from DATA:eventPayload:<field>::<type>
    FROM $$STREAM$$ t
    WHERE t.DATA:eventType::varchar = '<namespace>-<table_name_lower>'
  )
  SELECT * FROM ranked_data WHERE rnk = 1
) AS source
ON target.<PRIMARY_KEY> = source.<PRIMARY_KEY>
WHEN MATCHED THEN UPDATE SET # all fields
WHEN NOT MATCHED THEN INSERT # all fields
```

## 📝 Naming Conventions

- **Resource/Module names:** UPPER_SNAKE_CASE
- **Table name:** Extract from `FROM` clause → UPPER_SNAKE_CASE
- **Raw Table Name:** Extract from `FROM` clause. Unmodifed format.
- **snowflake_table name :** <TABLE_NAME> → UPPER_SNAKE_CASE
- **Module name:** `<TABLE_NAME>` → UPPER_SNAKE_CASE

## 🔄 JOB SQL Output

Generate the original query with modifications:
- Cast all columns to `::varchar` 
- Add `db_export_record_version` (no casting)

## 🔎 Formatting Rules for snowflake_table

- Each `column {}` block must use multi-line formatting.
- Put the `name` and `type` attributes on their own lines inside the block.
- Example (required style):

  column { 
    name = "VERSION"     
    type = "NUMBER(38,0)" 
  }

## 🔎 Formatting Rules for MODULE

- The section 'FROM $$$STREAM$$$ t' must be present with 3 $ symbols on either side of the word STREAM.
  
## 🎯 Complete Example

**Input:**
```
namespace = "copay"
database = "CPE_DATABASE"
schema = "COPAY"
SELECT programid, name, amount FROM programtiers;
```

**Output 1: Table Resource**
```hcl
resource "snowflake_table" "PROGRAM_TIERS" {
  database = snowflake_database.CPE_DATABASE.name
  schema   = snowflake_schema.COPAY.name
  name     = "PROGRAM_TIERS"
  comment  = "programtiers data exported from external copay database."
  change_tracking = false


  column {
    name = "VERSION"
    type = "NUMBER(38,0)"
  }
  column {
    name = "PROGRAMID"
    type = "STRING"
  }
  column {
    name = "NAME"
    type = "STRING"
  }
  column {
    name = "AMOUNT"
    type = "NUMBER(38,2)"
  }
}
```

**Output 2: Module Block**
```hcl
#=[DataExport - COPAY_PROGRAMS]========================================================================
# Batch Job           = copay_programs
# Source Database     = copay
# Source Table        = programs
# Event Type          = copay-programs
# Snowflake Table     = COPAY_PROGRAMS
#====================================================================================================
module "PROGRAMS" {
  source = "git::https://github.com/transactrx/DataIngestionS3ToSnowflake.git//ImportFromStageTable?ref=main"
  database_name = snowflake_database.CPE_DATABASE.name
  schema_name = snowflake_schema.COPAY.name
  name = "PROGRAMS"
  sql_import_query = <<SQL
MERGE INTO ${snowflake_table.PROGRAM_TIERS.database}.${snowflake_table.PROGRAM_TIERS.schema}.${snowflake_table.PROGRAM_TIERS.name} AS target
USING (
  WITH ranked_data AS (
    SELECT
      ROW_NUMBER() OVER (
        PARTITION BY DATA:eventPayload:programid::varchar
        ORDER BY DATA:eventPayload:db_export_record_version::numeric DESC
      ) AS rnk,
      DATA:eventPayload:db_export_record_version::numeric AS VERSION,
      DATA:eventPayload:programid::varchar AS PROGRAMID,
      DATA:eventPayload:name::varchar AS NAME,
      DATA:eventPayload:amount::number(38,2) AS AMOUNT
    FROM $$$STREAM$$$ t
    WHERE t.DATA:eventType::varchar = 'copay-program-tiers'
  )
  SELECT * FROM ranked_data WHERE rnk = 1
) AS source
ON target.PROGRAMID = source.PROGRAMID
WHEN MATCHED THEN
  UPDATE SET
    VERSION = source.VERSION,
    PROGRAMID = source.PROGRAMID,
    NAME = source.NAME,
    AMOUNT = source.AMOUNT
WHEN NOT MATCHED THEN
  INSERT (VERSION, PROGRAMID, NAME, AMOUNT)
  VALUES (source.VERSION, source.PROGRAMID, source.NAME, source.AMOUNT)
SQL
  load_historical_data = true
  stage_table_full_name = module.events_s3_to_stage_table.stage_table_full_name
  import_interval = "25 * * * * UTC"
}
```

**Output 3: JOB SQL**
```sql
SELECT
  programid::varchar,
  name::varchar,
  amount::varchar,
  db_export_record_version
FROM programtiers;
```

---

**Ready for input:** 
Please provide ....
- Provide namespace
- Database
- Schema
- SQL query 
...to generate code.
