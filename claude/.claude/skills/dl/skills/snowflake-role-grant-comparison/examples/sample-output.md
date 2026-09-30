# Sample Output: Cross-Environment Role Comparison

## Scenario

Comparing `RAS_DEV_ANALYST` and `RAS_PROD_ANALYST` — same logical role across dev and prod databases.

## Sample Results

| comparison | privilege | object_type | object_name | grant_option | granted_by |
|---|---|---|---|---|---|
| BOTH | SELECT | TABLE | {DB}.SALES.CUSTOMERS | NO | SYSADMIN |
| BOTH | SELECT | TABLE | {DB}.SALES.ORDERS | NO | SYSADMIN |
| BOTH | USAGE | SCHEMA | {DB}.SALES | NO | SYSADMIN |
| ONLY_RAS_DEV_ANALYST | INSERT | TABLE | {DB}.SALES.STAGING_TABLE | NO | SYSADMIN |
| ONLY_RAS_PROD_ANALYST | SELECT | VIEW | {DB}.SALES.REVENUE_VIEW | NO | SYSADMIN |
| ONLY_RAS_PROD_ANALYST | USAGE | DATABASE | {DB} | NO | ACCOUNTADMIN |

## Interpretation

- 3 grants are shared — core read access is consistent
- Dev has an extra INSERT on STAGING_TABLE (expected for dev workflow)
- Prod has a REVENUE_VIEW and database USAGE grant not present in dev — may need review
