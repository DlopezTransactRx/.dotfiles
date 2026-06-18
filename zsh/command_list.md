[ras] [AWS - Edit Config ] nvim /Users/dlopez/.aws/config
[ras] [AWS - SSO Login]	 aws sso login
[ras] [AWS - List Profile] aws configure list-profiles
[ras] [AWS - Set Profile] awsp
[ras] [AWS - Identify Logged In Account] aws sts get-caller-identity && bat /Users/dlopez/.aws/config
[ras] [AWS - Logs] awsp && g=$(awslogs groups | gum filter) && print -z "awslogs get $g -s '12h ago'"
[ras] [AWS - List Batch Schedules] awsp && aws scheduler list-schedules --profile=DEV-BATCH
[ras] [AWS - List Schedule Groups]  awsp && aws scheduler list-schedule-groups --profile=DEV-BATCH
[ras] [AWS - Batch Job Detail]  awsp && s=$(aws scheduler list-schedules --output text --query 'Schedules[].[Name,GroupName]' | gum filter --header 'NAME	GROUP') && n=$(echo "$s" | awk '{print $1}') && g=$(echo "$s" | awk '{print $2}') && print -z "aws scheduler get-schedule --name $n --group-name $g > /tmp/sched.json; echo; gum style --bold --foreground 212 --border normal --padding '0 1' 'Schedule'; jq -C '.' /tmp/sched.json; echo; gum style --bold --foreground 212 --border normal --padding '0 1' 'Job Config'; jq -r '.Target.Input | fromjson' /tmp/sched.json | jq -C '.'"
[ras] [NATS Discover Prod] ndp
[ras] [NATS Discover Dev] ndd
[ras] [Spec - NCPDP] glow "/Users/dlopez/Library/CloudStorage/OneDrive-RedSailTechnologies,LLC/Obsidian/Work/@NOTES/NCPDP/NCPDP - Transaction Codes Explained.md"
[ras] [Network Test] nt
[ras] [Postgres - Edit Config] nvim ~/.config/pgcli/config
[ras] [Postgres - Alias List] pgcli --list-dsn
[ras] [Postgres - Connect] p=$(pgcli --list-dsn | cut -d: -f1 | gum choose) && print -z "pgcli -D $p"
[ras] [Snowflake - Edit Config] nvim	 ~/.snowsql/config
[ras] [Snowflake - DEV] snowsql -c claude-dev
