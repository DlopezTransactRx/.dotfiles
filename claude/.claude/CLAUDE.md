# RedSail RAS AI Code Assitance useful context

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

## Creating a jobstream batch job
- There is a job scheduling platform available on our system. Jobs can be scheduled, they run on AWS Batch, all Fargate instances.
- Only read the following repository, if I ask to create a job.
- Reference example: https://github.com/transactrx/batchAIGeneratedJobSample (Rust, but language is irrelevant, our default language is Go)
- Env variables are suported, secrets must have the suffix _SECRET_ARN
- With secrets, the job must read the secret from secret manager using the appropriate AWS SDK
- Logs are automatic, all output to stdout will be pushed to AWS CloudWatch. Never print sensitive (PII, credentials, keys) information to stdout.

### Required project structure
```
project/
├── .github/
│   └── workflows/
│       └── build.yml           # CI/CD workflow (REQUIRED)
├── Dockerfile                  # Container build
├── terraform/
│   ├── setup.tf                # Variables (project_name, image_full) and S3 backend
│   ├── ecr_repo.tf             # ECR repository definition
│   ├── job-def.tf              # AWS Batch job definition (Fargate)
│   ├── documentation.tf        # DynamoDB job documentation entry
│   └── jobdoc.md               # Job documentation markdown
└── src/                        # Application source code
```

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

