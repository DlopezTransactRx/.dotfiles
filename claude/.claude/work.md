# Work — RedSail RAS AI and Data Services

## Command restrictions
### Terraform commands
- **NEVER** run `terraform apply` without explicit user confirmation
- **NEVER** run `terraform destroy` without explicit user confirmation
- **ALWAYS** run `terraform plan` first and show the output to the user before applying changes
- When user requests terraform changes, show the plan and ask for explicit approval before running apply
- Terraform apply can make infrastructure changes that cost money and affect production systems - always get user approval first

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

## Discovering all API's and end points
- There is a cli "nats-discover" available through brew, if not installed can be installed via tap transactrx (https://github.com/transactrx/homebrew-tap)
- calling nats-discover will return all available microservices
- calling nats-discover --service servicesubject --format JSON will return all endpoints
- calling nats-discover --service servicesubject --stats will give you performance information
- use this tool to find api available through nats.
- only read the github repo if I need help creating a client or microservice, the github repo contains sample clients and services
- with go, if you need to make api calls, use https://github.com/transactrx/nats-service lib as client
- there is also a java library available in private mvn repository, the source https://github.com/transactrx/nats-service-java.  We prefer new projects to be go.

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

### Key files to copy from reference
1. `.github/workflows/build.yml` - Handles AWS auth, ECR push, terraform deploy
2. `terraform/setup.tf` - Defines variables and S3 backend
3. `terraform/ecr_repo.tf` - Creates ECR repository
4. `terraform/job-def.tf` - Defines AWS Batch job (customize env vars, secrets, resources)
5. `terraform/documentation.tf` - Registers job docs in DynamoDB

## Service development (applies to every service, batch job, and script)

### NO PHI IN LOGS — EVER
- **Never log PHI or PII at any log level, in any environment.** Not at `debug`, not "temporarily",
  not behind a flag, not locally. Log identifiers, shapes, and counts — never payloads.
- **Error strings count as logs.** Anything returned up the stack gets logged by the caller, so an
  error message carrying PHI is a PHI log. Check what goes into every `fmt.Errorf`.
- **PHI hides inside composite ids.** An id that looks opaque may be assembled from PHI fields —
  e.g. ClinicalPlus's `PatientRxIDString` is `<PatientIDHash>|<rx_number>|<fill_number>|<npi>`, so
  logging it leaks the prescription number. Before logging any id, check how the producer builds it.
- **`eventId` is always a valid substitute for PHI in a log — use it.** Every event carries one (see
  "Events" below), it is a UUID assigned upstream, and it carries no patient data. When a log line
  needs to name a record, log the `eventId` instead of the record id, patient id, or payload. It also
  keeps the line actionable, because the event it names can be pulled and read back from the event
  store. If an event somehow arrives without one, derive a correlate-only fallback
  (e.g. `norefid-<8 hex of SHA-256>`) — never fall back to the PHI value.
- **Test it.** Add a test asserting the record id / payload never appears in the log or error output,
  and one asserting the safe reference is populated — otherwise the logging story silently rots.

## Events (the envelope, and what is actually guaranteed)

Events flow through the eventsCollector and land in the Snowflake event stage table. Every event —
inbound or outbound, whatever the type — is wrapped in the same envelope.

- **The ONLY three fields common to all events are `eventId`, `eventTime`, and `eventPayload`.**
  Nothing else is guaranteed. Do not assume any other top-level field exists across event types.
- `eventId` — a UUID identifying this transmission, assigned upstream. Log-safe (see the PHI rules
  above). It is per **transmission**, so the same logical record re-sent carries a different
  `eventId`. Never make it part of a durable/business key.
- `eventTime` — when the event was emitted, not when the underlying thing happened.
- `eventPayload` — everything type-specific. Its shape is defined ENTIRELY by the event type; there
  is no shared schema inside it. Read the producer to learn it, never guess.
- **Declare only the payload fields you read.** JSON unmarshal ignores the rest, so a partial struct
  is correct and stays resilient when the producer adds fields. Never assume your struct is the
  whole event.
- **Trace a log line back to its event** by looking the `eventId` up in the stage table, e.g.
  `SELECT * FROM <db>.STAGING.STAGE_EVENTS WHERE DATA:eventId::VARCHAR = '<id>'`.

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
