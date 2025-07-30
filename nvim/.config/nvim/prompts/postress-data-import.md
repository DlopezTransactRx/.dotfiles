# 🚀 Terraform Generator: SQL to Snowflake Pipeline

Generate complete Terraform code for Snowflake data ingestion pipelines using the `ImportFromStageTable` module.

## 📋 Task Overview

**Input:** SQL SELECT query + namespace  
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
| `*id` | `VARCHAR(100)` | programid, userid |
| `*amount` | `NUMBER(38,2)` | total_amount, fee_amount |
| `*quantity` | `DOUBLE` | order_quantity |
| `*date*` | `TIMESTAMP_NTZ` | created_date, date_modified |
| `*age`, `*days`, `*number`, `*fills` | `INTEGER` | patient_age, refill_fills |
| `require*`, `allow*`, `enable*`, `active*` | `BOOLEAN` | requires_auth, active_status |
| Default | `VARCHAR(255)` | notes, email, type |

## 🏗️ Code Structure

### 1. Snowflake Table Resource
```hcl
resource "snowflake_table" "<TABLE_NAME>" {
  name     = "<TABLE_NAME>"
  database = var.database
  schema   = var.schema

  column {
    name = "VERSION"
    type = "NUMBER(38,0)"
  }
  # Additional columns...
}
```

### 2. Module Block
```hcl
module "<NAMESPACE_TABLENAME>" {
  source = "git::https://github.com/transactrx/DataIngestionS3ToSnowflake.git//ImportFromStageTable?ref=main"
  database_name = snowflake_database.CPE_DATABASE.name
  name = "<NAMESPACE_TABLENAME>"
  schema_name = snowflake_schema.CPE_SCHEMA.name
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
- **Module name:** `<NAMESPACE>_<TABLE_NAME>` 
- **Event type filter:** `<namespace>-<table_name_lower>`

## 🔄 JOB SQL Output

Generate the original query with modifications:
- Cast all columns to `::varchar` 
- Add `db_export_record_version` (no casting)

## 🎯 Complete Example

**Input:**
```
namespace = "copay"
SELECT programid, name, amount FROM programs;
```

**Output 1: Table Resource**
```hcl
resource "snowflake_table" "PROGRAMS" {
  name     = "PROGRAMS"
  database = var.database
  schema   = var.schema

  column {
    name = "VERSION"
    type = "NUMBER(38,0)"
  }
  column {
    name = "PROGRAMID"
    type = "VARCHAR(100)"
  }
  column {
    name = "NAME"
    type = "VARCHAR(255)"
  }
  column {
    name = "AMOUNT"
    type = "NUMBER(38,2)"
  }
}
```

**Output 2: Module Block**
```hcl
module "COPAY_PROGRAMS" {
  source = "git::https://github.com/transactrx/DataIngestionS3ToSnowflake.git//ImportFromStageTable?ref=main"
  database_name = snowflake_database.CPE_DATABASE.name
  name = "COPAY_PROGRAMS"
  schema_name = snowflake_schema.CPE_SCHEMA.name
  sql_import_query = <<SQL
MERGE INTO ${snowflake_table.PROGRAMS.database}.${snowflake_table.PROGRAMS.schema}.${snowflake_table.PROGRAMS.name} AS target
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
    FROM $$STREAM$$ t
    WHERE t.DATA:eventType::varchar = 'copay-programs'
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
FROM programs;
```

---

**Ready for input:** Provide namespace + SQL query to generate code.
