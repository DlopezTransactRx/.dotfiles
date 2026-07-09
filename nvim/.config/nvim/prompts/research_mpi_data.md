# TASK: PHI Population Metrics for a Snowflake Table

## Parameters
- FULLY_QUALIFIED_TABLE: <DATABASE.SCHEMA.TABLE>   e.g. CPE_PROD.DATA.RXMILE_CUSTOMER_BASE
- SNOW_CONNECTION:       <connection name>          e.g. PROD-CLAUDE

## Hard Constraints (MUST follow exactly)
1. Use the `snow` CLI with the given connection: `snow sql -c <SNOW_CONNECTION> -q "..."`.
2. AGGREGATE / COUNT QUERIES ONLY. Never SELECT, sample, preview, or otherwise read
   row-level data. No `SELECT *`, no `LIMIT`, no `TOP`, no reading individual values.
   Only COUNT(*) / COUNT(CASE WHEN ...) aggregates are permitted.
3. Do not write, modify, or delete anything. Read-only metrics only.

## Steps
1. DISCOVER COLUMNS — run:
     DESCRIBE TABLE <FULLY_QUALIFIED_TABLE>;

2. IDENTIFY PHI COLUMNS — based ONLY on column names, flag columns that are direct or
   indirect patient/person identifiers. Consider name patterns such as:
     - Name:    FIRST_NAME, MIDDLE_NAME, LAST_NAME, FULL_NAME, PATIENT_NAME
     - Contact: PHONE, MOBILE, EMAIL, FAX
     - Address: ADDRESS_1/2/3, STREET, CITY, STATE, ZIP, POSTAL, COUNTY, COUNTRY
     - Identifiers/dates: BIRTH_DATE / DOB, SSN, MRN, MEMBER_ID, LICENSE, ACCOUNT
   EXCLUDE columns that describe an organization rather than a person (e.g. PHARMACY_*,
   STORE_*, NPI of a provider), internal surrogate IDs, boolean HAS_* flags, counts, and
   activity dates — UNLESS the user says otherwise. List each flagged column and why.

3. INDIVIDUAL POPULATION — build ONE query that returns COUNT(*) as TOTAL_ROWS plus, for
   each flagged column, a populated count. "Populated" = NOT NULL AND TRIM(col) <> ''
   (whitespace-only counts as empty). Pattern per column:
     COUNT(CASE WHEN col IS NOT NULL AND TRIM(col) <> '' THEN 1 END) AS col

4. COMBINATION POPULATION — in the SAME query, add columns counting rows where meaningful
   identifier BUNDLES are ALL populated. Choose combos that fit the columns present, e.g.:
     - FULL_NAME              = First + Last
     - NAME_PHONE             = First + Last + Phone
     - FULL_ADDRESS           = Address1 + City + State + Zip
     - NAME_ADDRESS           = First + Last + full Address
     - NAME_PHONE_ADDRESS     = First + Last + Phone + full Address
     - NAME_PHONE_EMAIL       = First + Last + Phone + Email
     - NAME_DOB / NAME_DOB_ZIP
     - FULL_IDENTITY          = Name + DOB + (Phone OR Email) + Address1
   Wrap OR-conditions in explicit parentheses so precedence is correct. Prefix combo
   aliases with COMBO_ so they are distinguishable from individual fields.

5. RUN the single combined query with `snow sql`.

6. REPORT — present:
   a. The list of flagged PHI columns and rationale.
   b. A table of INDIVIDUAL fields: column | populated rows | % of total (sorted desc).
   c. A table of COMBINATIONS: combo | populated rows | % of total.
   d. Short observations (most/least complete fields, limiting field for combos,
      highest-risk common bundle).
   e. The exact SQL used (DESCRIBE + the combined query).
   Percentage = populated / TOTAL_ROWS, two decimals.

## Reminder
Confirm in the output that only COUNT-based aggregates were run and no row-level PHI was
read.
