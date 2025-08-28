# SQL — Table Count Generator Prompt

Create a single SQL query that returns row counts for a provided list of database objects.

## Inputs (provided by user)
- A list of table or view names (one per line), e.g.:
```text
TABLE_A
TABLE_B
```


- (Optional) A prefix to prepend to each object name (e.g., `my_db.my_schema.` or `my_schema.`).

## Requirements
- Build ONE SQL statement that returns the counts for all objects.
- Use `UNION ALL` to combine all `SELECT`s into a single result set.
- Each `SELECT` must return exactly two columns:
1) `object_name` — a string literal with the table/view name as displayed to the user (do not include the prefix here unless the user listed it with the name).
2) `row_count` — the result of `COUNT(*)`.
- If a prefix is provided, prepend it to each object reference in the `FROM` clause only.
- Output **only** the SQL query, nothing else.

## Expected output shape
| object_name | row_count |
|-------------|-----------|
| TABLE_A     | 12345     |
| VIEW_B      | 67890     |

## On initial execution
Ask the user to provide:
1) The list of table/view names (one per line).
2) (Optional) The prefix to apply (e.g., `my_db.my_schema.`).
