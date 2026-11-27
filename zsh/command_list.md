[ras] [AWS - Edit Config ] nvim /Users/dlopez/.aws/config
[ras] [AWS - SSO Login]	 aws sso login
[ras] [AWS - List Profile] aws configure list-profiles
[ras] [AWS - Set Profile] awsp
[ras] [AWS - Identify Logged In Account] aws sts get-caller-identity && bat /Users/dlopez/.aws/config
[ras] [AWS - Logs] awsp && g=$(awslogs groups | gum filter) && print -z "awslogs get $g -s '12h ago'"
[ras] [AWS - List Schedules] awsp && aws scheduler list-schedules --output=text
[ras] [AWS - Batch Jobs]  awsp && s=$(aws scheduler list-schedules --output text --query 'Schedules[].[Name,GroupName]' | gum filter --header 'NAME	GROUP') && n=$(echo "$s" | awk '{print $1}') && g=$(echo "$s" | awk '{print $2}') && a=$(gum choose --header "Schedule: $n" 'SHOW DETAIL' 'TRIGGER JOB') && if [ "$a" = 'TRIGGER JOB' ]; then print -z "aws scheduler get-schedule --name $n --group-name $g --query 'Target.Input' --output text | jq 'walk(objects |= with_entries(.key |= (.[0:1]|ascii_downcase)+.[1:]))' > /tmp/submit.json && aws batch submit-job --cli-input-json file:///tmp/submit.json --query '{jobName:jobName,jobId:jobId}'"; else print -z "aws scheduler get-schedule --name $n --group-name $g > /tmp/sched.json; echo; gum style --bold --foreground 212 --border normal --padding '0 1' 'Schedule'; jq -C '.' /tmp/sched.json; echo; gum style --bold --foreground 212 --border normal --padding '0 1' 'Job Config'; jq -r '.Target.Input | fromjson' /tmp/sched.json | jq -C '.'"; fi
[ras] [AWS - Get Secret]  awsp && sec=$(aws secretsmanager list-secrets --query 'SecretList[].Name' --output text | tr '\t' '\n' | fzf) && print -z "aws secretsmanager get-secret-value --secret-id $sec --query SecretString --output text | { jq -C '.' 2>/dev/null || cat; }"
[ras] [AWS - ECS Describe Service]  awsp && c=$(aws ecs list-clusters --query 'clusterArns' --output text | tr '\t' '\n' | gum choose) && s=$(aws ecs list-services --cluster "$c" --query 'serviceArns' --output text | tr '\t' '\n' | fzf) && print -z "aws ecs describe-services --cluster $c --services $s --output table"
[ras] [AWS - Tail ECS Service]  awsp && c=$(aws ecs list-clusters --query 'clusterArns' --output text | tr '\t' '\n' | gum choose) && s=$(aws ecs list-services --cluster "$c" --query 'serviceArns' --output text | tr '\t' '\n' | fzf) && td=$(aws ecs describe-services --cluster "$c" --services "$s" --query 'services[0].taskDefinition' --output text) && lg=$(aws ecs describe-task-definition --task-definition "$td" --query 'taskDefinition.containerDefinitions[0].logConfiguration.options."awslogs-group"' --output text) && print -z "aws logs tail $lg --follow"
[ras] [AWS - SSM Session]  awsp && id=$(aws ec2 describe-instances --filters "Name=instance-state-name,Values=running" --query "Reservations[].Instances[].[Tags[?Key=='Name']|[0].Value,InstanceId]" --output text | sort | fzf --prompt="Pick an instance: " | awk '{print $NF}') && [ -n "$id" ] && (trap 'printf "\033]111\007"' EXIT INT; printf '\033]11;#241a3a\007'; aws ssm start-session --target "$id")
[ras] [AWS - Airflow Trigger DAG]  awsp && e=$(aws mwaa list-environments --output json | jq -r '.Environments[]' | gum choose --header 'Airflow (MWAA) environment') && d=$(o=0; while :; do p=$(aws mwaa invoke-rest-api --name "$e" --method GET --path /dags --query-parameters '{"limit":100,"offset":'$o'}' --output json | jq -r '.RestApiResponse.dags[] | [.dag_id, (if .is_paused then "paused" else "active" end), (.timetable_summary // "manual")] | join("|")'); [ -z "$p" ] && break; print -r -- "$p"; o=$((o+100)); done | sort -f | column -t -s '|' | fzf --header 'DAG   STATE   SCHEDULE' --prompt='Pick a DAG: ' | awk '{print $1}') && [ -n "$d" ] && b='{"logical_date": null}' && print -z "aws mwaa invoke-rest-api --name $e --method POST --path /dags/$d/dagRuns --body '$b' --query 'RestApiResponse.{run:dag_run_id,state:state}'"
[ras] [AWS - Airflow List Variables]  awsp && e=$(aws mwaa list-environments --output json | jq -r '.Environments[]' | gum choose --header 'Airflow (MWAA) environment') && (o=0; while :; do p=$(aws mwaa invoke-rest-api --name "$e" --method GET --path /variables --query-parameters '{"limit":100,"offset":'$o'}' --output json | jq -r '.RestApiResponse.variables[] | [.key, ((.value // "") | tostring | @json | .[0:80] | gsub("[|]"; "/"))] | join("|")'); [ -z "$p" ] && break; print -r -- "$p"; o=$((o+100)); done) | sort -f | column -t -s '|' | fzf --header 'VARIABLE   VALUE (first 80 chars)' --prompt='Filter variables: '
[ras] [AWS - Airflow Connect (airflowctl)]  mwaa-login
[ras] [AWS - S3 Browser (stu)]  awsp && gum confirm "Open S3 in $AWS_PROFILE?" && stu --profile "$AWS_PROFILE"
[ras] [AWS - Terminal UI (taws, read-only)]  p=$(aws configure list-profiles | gum filter --header 'AWS profile for taws') && [ -n "$p" ] && taws --readonly --profile "$p"
[ras] [AWS - Batch & Schedules (batchtui)]  p=$(aws configure list-profiles | gum filter --header 'AWS profile for batchtui') && [ -n "$p" ] && batchtui -p "$p"
[ras] [NATS Discover Prod] ndp
[ras] [NATS Discover Dev] ndd
[ras] [NATS - Edit Context (Development) ] nvim /Users/dlopez/.config/nats/context/Development.json
[ras] [NATS - Edit Key/Seed (Development) ] nvim /Users/dlopez/.nats/dlopez_dev.creds
[ras] [NATS - Edit Context (Production) ] nvim /Users/dlopez/.config/nats/context/Production.json
[ras] [NATS - Edit Key/Seed (Production) ] nvim /Users/dlopez/.nats/dlopez_prod.creds
[ras] [Network Test] nt
[ras] [Postgres - Edit PGCLI Config] nvim ~/.config/pgcli/config
[ras] [Postgres - Edit Passwords] nvim ~/.pgpass && chmod 600 ~/.pgpass
[ras] [Postgres - Alias List] pgcli --list-dsn
[ras] [Postgres - DB Connect] p=$(pgcli --list-dsn | cut -d: -f1 | gum filter) && print -z "pgcli -D $p"
[ras] [Snowflake - Update Client Version] echo "Updating SnowSql" | lolcat && gum spin -- sh -c 'snowsql --upgrade --version' | lolcat
[ras] [Snowflake - Edit Config] nvim	 ~/.snowflake/config.toml
[ras] [Snowflake - Connect] p=$(snow connection list --format CSV |rg -v connection_name | cut -d, -f1 | gum filter) && print -z "snow sql -c $p"
[ras] [GitHub Login] gh auth login
[ras] [DOC - NCPDP Codes Spec] glow "/Users/dlopez/Library/CloudStorage/OneDrive-RedSailTechnologies,LLC/Obsidian/Work/ATLAS/NCPDP/NCPDP - Transaction Codes Explained.md"
[ras] [DOC - Pharmacy Business Terminology] glow "/Users/dlopez/Library/CloudStorage/OneDrive-RedSailTechnologies,LLC/Obsidian/Work/ATLAS/RedSail/Pharmacy Business Terminology.md"
[ras] [DOC - Pharmacy Claims Routing] glow "/Users/dlopez/Library/CloudStorage/OneDrive-RedSailTechnologies,LLC/Obsidian/Work/ATLAS/RedSail/Pharmacy Claim Routing.md"
[ras] [DOC - Kafka Lag Alert Reasons] glow "/Users/dlopez/Library/CloudStorage/OneDrive-RedSailTechnologies,LLC/Obsidian/Work/ATLAS/Kafka/Kafka Lag Alert Reasons.md"
[ras] [DOC - NCPDP Specs] yazi "/Users/dlopez/Documents/Specs/NCPDP"
[ras] [Obsidian - Edit KeyMap Plugin(vimrc) ] nvim /Users/dlopez/Library/CloudStorage/OneDrive-RedSailTechnologies,LLC/Obsidian/Work/.obsidian.vimrc
[ras] [Nats-Agents Chat - snowflakeOpsAssistant (Development)] nad chat snowflakeOpsAssistant ""
[ras] [Nats-Agents Chat - snowflakeOpsAssistant (Production)] nap chat snowflakeOpsAssistant ""
[ras] [Script - Protect Repo Branches (Github)] sh /Users/dlopez/scripts/github-branch-protection/config-repo.sh "transactrx" "<REPO_NAME>"
