# Phase 2 — Write the worker

## Naming and placement

- File: `backfill_<table>_<ticket>.tf` (lowercase) in the owning repo root, next to the table's file.
- Resource: `snowflake_procedure_sql.backfill_<table>_<ticket>`.
- Procedure: `BACKFILL_<TABLE>_<TICKET>`, in the **target table's** database and schema.
- Registered backfill name (used in kickoff): `<TABLE>_<TICKET>`.
- Header comment: ticket, columns filled, technique, "Remove after the backfill completes."
- Reference the target through the table resource (`snowflake_table.<T>.database` / `.schema` / `.name`) and functions through the same locals the live load uses. Nothing else from other files.

## Terraform shape

```hcl
#################################################################
# BACKFILL WORKER — <TABLE> #<ticket>
# Fills <columns> on historical rows (<technique>), one window per call.
# Framework: SnowflakeWHAdministration-Modules//backfill. Remove after the backfill completes.
#################################################################
resource "snowflake_procedure_sql" "backfill_<table>_<ticket>" {
  database    = snowflake_table.<T>.database
  schema      = snowflake_table.<T>.schema
  name        = "BACKFILL_<TABLE>_<TICKET>"
  comment     = "Backfill worker for #<ticket>. Remove after the backfill completes."
  return_type = "NUMBER"
  execute_as  = "OWNER"

  arguments {
    arg_name      = "P_START"
    arg_data_type = "TIMESTAMP_NTZ"
  }
  arguments {
    arg_name      = "P_END"
    arg_data_type = "TIMESTAMP_NTZ"
  }
  arguments {
    arg_name      = "P_META"
    arg_data_type = "OBJECT"
  }

  procedure_definition = <<-EOT
  BEGIN
      MERGE INTO <db>.<schema>.<table> AS target
      USING ( <source for [P_START, P_END), exactly one row per match key> ) AS source
         ON target.<KEY> = source.<KEY>
        <AND target.<window col> >= :P_START AND target.<window col> < :P_END   -- when the target stores the window value>
      WHEN MATCHED AND target.<GUARD_COL> IS NULL THEN UPDATE SET
          target.<COL_1> = source.<COL_1>,
          ...
          target.TASK_META = ARRAY_SLICE(ARRAY_PREPEND(COALESCE(target.TASK_META, ARRAY_CONSTRUCT()), :P_META), 0, <max_history>);
      RETURN SQLROWCOUNT;
  END;
  EOT
}
```

- No `EXCEPTION` block. Errors propagate to the framework, which records SQLCODE / query id.
- No `WHEN NOT MATCHED`. No `DELETE`.
- Omit the `TASK_META` line only when the target has no `TASK_META` column (warn the user once).
- Inside the heredoc, `${...}` is Terraform interpolation; use it only for database/schema/table/function names.
- `procedure_sql` bodies end statements with `;` (unlike task SQL).

## Source: one row per match key

`MERGE` fails ("Duplicate row detected") if two source rows match one target row. The source must be unique on the key: `QUALIFY ROW_NUMBER() OVER (PARTITION BY <KEY> ORDER BY <INGESTED_TIMESTAMP> ASC) = 1`.

## Insert-only hash-keyed tables (e.g. TRANSACTION_LOG)

The live MERGE only inserts, and the key is a hash of content (`MD5(id | request | response)`). Each batch keeps one copy per record (e.g. latest per `TRANSMISSION_ID`), so different copies of the same record, in different batches, became **separate rows** with different hashes.

- **Do not** copy the live per-record dedup. Over a window it keeps one copy and drops the others' hashes, so their rows never match and stay NULL silently.
- **Do** derive every copy in the window, build the key exactly as the live load does, then keep one row per **distinct key** (earliest `INGESTED_TIMESTAMP` first, matching the insert that created the row).
- Every copy lands in exactly one window, and every target row came from one copy, so every row matches. The Development check "rows still NULL in the window = 0" proves it.

## Same-row expression

```sql
UPDATE <db>.<schema>.<table> AS target
   SET <COL_1> = <expr over target columns>, ...,
       TASK_META = ARRAY_SLICE(ARRAY_PREPEND(COALESCE(target.TASK_META, ARRAY_CONSTRUCT()), :P_META), 0, <max_history>)
 WHERE target.<window col> >= :P_START AND target.<window col> < :P_END
   AND target.<GUARD_COL> IS NULL;
RETURN SQLROWCOUNT;
```

## Correction workers

A worker that must overwrite existing values drops the `<GUARD_COL> IS NULL` condition. Mark it in the header comment (`CORRECTION WORKER — overwrites existing values`) and register it with a NULL end ("now"). Re-run safety then has to come from `WHEN MATCHED AND (target.<col> IS DISTINCT FROM source.<col> OR ...)` so a re-run changes nothing.

## Validate

In the owning repo: `terraform fmt -check <file>` and `terraform init -backend=false` + `terraform validate` (use a scratch `TF_DATA_DIR`). Never `plan` or `apply`.
