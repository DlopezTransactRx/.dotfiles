[ras] [AWS - Edit Config ]  nvim /Users/dlopez/.aws/config
[ras] [AWS - SSO Login]	 aws sso login
[ras] [AWS - List Profile]  aws configure list-profiles
[ras] [AWS - Set Profile]  awsp
[ras] [AWS - Identify Logged In Account]  aws sts get-caller-identity && bat /Users/dlopez/.aws/config
[ras] [AWS Logs]  awslogs get `awslogs groups | gum filter` -s '12h ago'
[ras] [AWS - List Batch Schedules - DEV] aws scheduler list-schedules --profile=batch-dev
[ras] [AWS - List Schedule Groups - DEV]  aws scheduler list-schedule-groups --profile=batch-dev
[ras] [NATS Discover Prod]	ndp
[ras] [NATS Discover Dev]	ndd
[ras] [Spec - NCPDP]	 glow "/Users/dlopez/Library/CloudStorage/OneDrive-RedSailTechnologies,LLC/Obsidian/Work/@NOTES/NCPDP/NCPDP - Transaction Codes Explained.md"
[ras] [Network Test]	nt
[ras] [Postgres - Edit Config] nvim ~/.config/pgcli/config
[ras] [Postgres - Alias List]	pgcli --list-dsn
[ras] [Postgres - Connect]	pgcli -D `pgcli --list-dsn | cut -d: -f1 | gum choose`
[ras] [Snowflake - Edit Config] nvim	 ~/.snowsql/config
[ras] [Snowflake - DEV] snowsql -c claude-dev
