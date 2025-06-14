# Prompt: Context and Task Definition

This prompt defines a repeatable task: generating Terraform code based on SQL input queries.

## Objective

You will be provided with one SQL `SELECT` query at a time. For each query, generate a Terraform code snippet that:

1. Defines a `snowflake_table` resource with column definitions derived from the fields in the `SELECT` clause.
2. Defines a module block using the `ImportFromStageTable` module to ingest data from a Snowflake staging table into the defined table using a `MERGE` statement.
3. Uses external context provided separately, including:
   - `database`
   - `schema`
   - `module_source`
   - `stage_table`
   - `import_interval`
   - `namespace`, which is derived from the `eventType` field in the query’s `WHERE` clause (e.g., `copay-`).

---

## Terraform Code Requirements

### 1. Table Resource (`snowflake_table`)
- Always include a `VERSION` column of type `NUMBER(38,0)` as the first column. This maps from the `db_export_record_version` field, which is **not** included in the SQL query.
- Infer Snowflake data types using naming patterns:
  - `amount` → `NUMBER(38,2)`
  - `dateadded`, `datemodified` → `TIMESTAMP_NTZ`
  - Fields ending in `id` → `VARCHAR(100)`
- All Snowflake resource names (tables, columns, modules) must be in **UPPERCASE** with words separated by **underscores** (UPPER_SNAKE_CASE).

### 2. Module Block
- Use the `ImportFromStageTable` module.
- Construct a `MERGE` SQL block that:
  - Deduplicates using `ROW_NUMBER()` over the primary key, ordered by `db_export_record_version DESC`.
  - Extracts fields using `DATA:eventPayload:<fieldname>` with appropriate type casting.
  - Filters using:

    ```sql
    WHERE t.DATA:eventType::varchar = '<namespace>-<tablename>'
    ```

- Use `$$$STREAM$$$` as the event stream reference.
- Populate the `VERSION` column from `db_export_record_version`.

---

## Naming Requirements

- Derive the table name and Terraform resource/module names from the table in the SQL query’s `FROM` clause.
- Convert all such names to **UPPER_SNAKE_CASE**.
- Format the final `NAME` value as `<namespace>-<event_type>`, all lowercase, with underscores removed.

---

## Sample SQL Input

```sql
SELECT
    pharmacypaymentid,
    amount
FROM pharmacypayments
```

# Response Format #

## Respond with a 2-column Markdown table that includes the following:
- Header row: all headers capitalized
- First column: fixed labels
- Second column: all values lowercase (except CODE_SNIPPET which should be properly formatted Terraform HCL)

## The rows in the table should appear in this order:
1. NAME – combination of the EVENT_NAME_SPACE and EVENT_TYPE, joined by a hyphen (-), with all underscores removed
2. KEY – the primary key from the original SQL query
3. SOURCE_TABLE – the table name from the SQL FROM clause
4. EVENT_NAME_SPACE – the namespace provided by the user (e.g., copay)
5. EVENT_TYPE – derived from the source table name in the SQL
6. QUERY_STRING – the original query with an appended column: db_export_record_version
7. CODE_SNIPPET – the Terraform code block generated from the query

## Immediate Response
After receiving this prompt, respond with:
“Please provide the NAMESPACE and INPUT QUERY.”
