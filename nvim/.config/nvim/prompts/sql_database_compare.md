    Create a SQL query that compares row counts between two Snowflake databases:

    Please provide:
    - Source Database: [Which database do you have access to?]
    - Target Database: [Which database should be compared against?]
    - Snowsql Connection: [Which connection profile should be used? e.g., claude-dev]

    Scope: All tables across all schemas in both databases

    Query should return:
    1. Schema name
    2. Table name
    3. Row count in {source_database}.{schema}.{table}
    4. Row count in {target_database}.{schema}.{table}
    5. Difference (source count - target count)

    Requirements:
    - DO NOT execute the query, just generate it
    - Structure as a single query using UNION ALL for all table pairs
    - The query should be ready to run once you have access to both databases
    - Assume both databases have identical schema structures
