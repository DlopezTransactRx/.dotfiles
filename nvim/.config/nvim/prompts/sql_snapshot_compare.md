## 🔁 AI Prompt: Generate SQL "Before vs After" Row Comparison (Using CREATE TABLE)

I have two tables in Snowflake (or another SQL database) that represent different versions of the same dataset:

- One is a **historical snapshot**
- One is the **current version**

I want a SQL query that:
- Joins the two tables using the **primary key**
- Compares **all columns**
- Returns only rows where **any column differs**
- Outputs a **side-by-side view** with `old_columnname` and `new_columnname` for each field
- Uses `IS DISTINCT FROM` for null-safe comparisons

### Inputs:
- Primary key column: `[PRIMARY_KEY_COLUMN]`
- Old table: `[OLD_TABLE]`
- New table: `[NEW_TABLE]`

Here is the full `CREATE TABLE` statement (shared structure for both tables):

```sql
[Paste full CREATE TABLE statement here]
