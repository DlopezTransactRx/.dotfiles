# About Me
## Philosophies I subscribe to in regards to learning and productivity
- Remember It! by Nelson Dellis
- Getting Things Done: The Art of Stress-Free Productivity by David Allen


# Agent Communication Style Guide

## How to explain things to me
Lead with one plain sentence that answers the question. 
No nonsense. Straigt to the point.
Short sentences. One idea each. No stacked clauses.
Use everyday words. If a technical term is unavoidable, define it inline, once, then use it.
Give a concrete example instead of an abstract description.
Say what something is not when people commonly get it wrong.
Skip headers and bullet lists for anything under ~200 words. Just talk.
Don't hedge. If there's a real caveat, state it in one sentence and move on.
If I need the precise or technical version, I'll ask for it.

Use analogies and memory tricks if they’ll make concepts easier to grasp.


## Commit messages
Subject line: what changed, in plain words, imperative mood, under 60 chars.
Body: 1-2 sentences on why. Skip the body if the subject says it all.
No bullet lists of every file touched. The diff already says that.
## Issue and PR reviews
Open with: what this is asking for, in one sentence.
Then: what's actually wrong or missing, plainly stated.
Then: what it would take to fix. Rough, not a spec.
Flag anything that looks like it'll bite later, but say it in one line.


# RedSail RAS AI Code Assitance useful context

## Scaffolding preferences (my personal golden repos)
- **Kafka consumer services:** when scaffolding a Kafka-consumer ingress (the
  `ras-dev-toolkit` scaffold-microservice skill / golden-repos index), mirror
  **`transactrx/masterPatientIndexClinicalPlusFeeder`** (branch `Development`) as the
  golden reference INSTEAD of `MasterPatientIndexFeeder`. Follow its idiom and layout:
  `pkg/kafka/consumer.go`, `pkg/kafka/MSKTokenProvider.go`, `pkg/kafka/offsettracker.go`,
  the `cmd/<service>/main.go` run-loop + graceful shutdown, and its `pkg/` package
  structure, `pkg/logger` logging idiom, and config style. This is my personal preference
  and overrides the plugin's default golden repo — it is not an org-wide standard.
- **NATS endpoint services:** when scaffolding a NATS-endpoint ingress, mirror
  **`transactrx/SnowflakeDataService`** (branch `Development`) as the golden reference
  INSTEAD of `masterPatientIndex` / the inline `templates/microservice/TEMPLATES.md`
  endpoint sections. Follow its idiom and layout: `cmd/<service>/main.go`,
  `pkg/natsHelper/natsHelper.go`, `pkg/services/*` (endpoint handlers +
  `documentation_test`/`service_metadata` tests), `pkg/models` (`Request.go`/`Response.go`),
  and `pkg/svcctx` (service context, `dbclient`, `logger`). Personal preference, overrides
  the plugin default — not an org-wide standard.
  - **EXCEPTION — logging:** do NOT copy SnowflakeDataService's logging idiom. Use my ECS
    logging conventions instead (see "Creating an ECS service" below): a zap
    **SugaredLogger** (not a plain `*zap.Logger`), `LOG_LEVEL` **defaulting to `info`** when
    unset (never panic on a missing `LOG_LEVEL`), plus the ECS task-metadata startup log and
    the hardcoded `const version` marker. Mirror SnowflakeDataService for layout, handlers,
    NATS wiring, and `svcctx` structure — but the logger follows the ECS conventions.

## My team's GitHub issue board
- Org: `transactrx`. Project board: **"RAS AI and Data Services"**, project number **23**
  (https://github.com/orgs/transactrx/projects/23). This is the board my team works off of.
- When I ask you to create an issue / file a ticket / "track this", create it in the relevant
  `transactrx` repo and then add it to project 23:
  ```bash
  gh issue create --repo transactrx/<repo> --title "..." --body "..."
  gh project item-add 23 --owner transactrx --url <issue-url>
  ```
- To see what's on the board: `gh project item-list 23 --owner transactrx`.
- Always confirm the issue title and body with me before creating it.

## Command Restrictions

### Terraform Commands
- **NEVER** run `terraform apply` without explicit user confirmation
- **NEVER** run `terraform destroy` without explicit user confirmation
- **ALWAYS** run `terraform plan` first and show the output to the user before applying changes
- When user requests terraform changes, show the plan and ask for explicit approval before running apply
- Terraform apply can make infrastructure changes that cost money and affect production systems - always get user approval first

## Discovering all API's and end point
- There is a cli "nats-discover" available through brew, if not installed can be installed via tap transactrx (https://github.com/transactrx/homebrew-tap)
- calling nats-discover will return all available microservices
- calling nats-discover --service servicesubject --format JSON will return all endpoints
- calling nats-discover --service servicesubject --stats will give you performance information
- use this tool to find api available through nats.
- only read the github repo if I need help creating a client or microservice, the github repo contains sample clients and services
- with go, if you need to make api calls, use https://github.com/transactrx/nats-service lib as client
- there is also a java library available in private mvn repository, the source https://github.com/transactrx/nats-service-java.  We prefer new projects to be go.


### Key files to copy from reference
1. `.github/workflows/build.yml` - Handles AWS auth, ECR push, terraform deploy
2. `terraform/setup.tf` - Defines variables and S3 backend
3. `terraform/ecr_repo.tf` - Creates ECR repository
4. `terraform/job-def.tf` - Defines AWS Batch job (customize env vars, secrets, resources)
5. `terraform/documentation.tf` - Registers job docs in DynamoDB

## Creating an ECS service (my conventions)
When I create a new ECS (Fargate) service, always include the following unless I say otherwise:
- **LOG_LEVEL support** — a `LOG_LEVEL` env var (debug|info|warn|error, default info) driving a
  leveled logger (zap SugaredLogger in Go). All runtime logging goes through it. Wire the env
  var in both the app config and terraform taskDef, and route third-party loggers (e.g. sarama)
  through it so LOG_LEVEL actually silences them.
- **Detailed DEBUG logging** — trace the lifecycle at `debug`: startup, each external
  connection/initialization step (connecting → established → ready), and per-record/per-request
  diagnostics. Keep lifecycle milestones at `info`. Never log PII/PHI/credentials at any level
  (log identifiers/shapes/counts, not payloads).
- **Log ECS task metadata at startup** — use `github.com/brunoscheufler/aws-ecs-metadata-go`
  (`metadata.Get(ctx, &http.Client{})`), marshal to JSON, log at `info`. It must no-op (log at
  `debug` and continue) when the metadata endpoint is absent (running locally) — never panic.
- **Hardcoded `version` marker** — a `const version` logged at startup (`info`) so the logs show
  which build is deployed; I bump it before deploying.
