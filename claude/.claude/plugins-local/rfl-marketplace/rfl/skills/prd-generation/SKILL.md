---
name: prd-generation
description: Use when asked to generate a PRD, create prd.json, decompose a project, break a project into features, or "PRD this project" — produces a prd.json of tiny independently-buildable features with transcript-observable /goal termination conditions. Language- and toolchain-agnostic.
---

# prd-generation (rfl)

Phase 1 of the Ralph Feedback Loop (RFL). Decompose a project description into
a `prd.json` of tiny, independently-buildable features. Each feature carries a
pre-written `goal_condition` for Claude Code's `/goal` command and a deterministic
`validation` command for external re-verification.

This skill is **language- and toolchain-agnostic**. The RFL pattern (tiny
features, a `depends_on` DAG, transcript-observable termination conditions) works
for any stack. Before decomposing, establish the project's **toolchain** — the
concrete build, test, format, and lint commands — and use those commands
throughout the `goal_condition` and `validation` fields. See "Establishing the
toolchain" and the "Validation primitives" reference table below.

**Companion:** rfl:goal-runner consumes the `prd.json` this skill produces.

## How /goal constrains everything

`/goal` keeps Claude working until a small evaluator model confirms a termination
condition. The evaluator **only reads the conversation transcript** — it cannot
run commands, read files, or check state. So every `goal_condition` assertion must
be something the agent demonstrates *in the visible transcript*. Condition strings
are capped at 4,000 characters. One goal is active per session.

## Schema

The prd.json schema, goal_condition format, progress.jsonl shapes, and a worked
feature are in `prd-schema.md` and `example-prd.json` in this folder. Read them
before emitting. The worked feature in `example-prd.json` uses Go commands purely
as **one illustration** of the pattern — substitute the toolchain you established
above. Key invariant: **no `passes` field** — completion lives only in
`progress.jsonl`.

## Interaction flow

1. If the project description wasn't provided, ask for it.
2. Confirm the working directory is the target repo. If `./prd.json` already
   exists, warn and ask before overwriting.
3. **Establish the toolchain** (see next section). State the detected
   build/test/format/lint commands and confirm them before proceeding.
4. Apply the decomposition and condition-writing rules below.
5. Run the final checklist silently.
6. Emit a single valid JSON file to `./prd.json` — top-level array, no fences,
   no commentary, no comments. First char `[`, last char `]`.

All paths are relative to the current working directory. Never absolute, never
under `~/.claude/`.

## Establishing the toolchain

The `goal_condition` and `validation` commands must be real, runnable commands
for *this* project's stack. Determine them before decomposing:

1. **Auto-detect, then confirm.** Inspect the repo for a manifest/build file and
   infer the toolchain from it:

   | Manifest / marker | Likely stack | Format | Build / compile | Test | Lint / static analysis |
   |---|---|---|---|---|---|
   | `go.mod` | Go | `gofmt -l .` (empty) | `go build ./...` | `go test ./...` / `-run X -v` | `go vet ./...`, `staticcheck`, `golangci-lint run` |
   | `package.json` | Node / TS | `prettier --check .` | `tsc --noEmit` / `npm run build` | `npm test`, `jest`, `vitest run` | `eslint .` |
   | `pyproject.toml` / `setup.py` / `requirements.txt` | Python | `ruff format --check .` / `black --check .` | `python -m compileall .` | `pytest`, `pytest -k X -v` | `ruff check .`, `mypy .` |
   | `Cargo.toml` | Rust | `cargo fmt --check` | `cargo build` | `cargo test`, `cargo test X` | `cargo clippy -- -D warnings` |
   | `pom.xml` / `build.gradle` | Java / Kotlin | `mvn spotless:check` / `gradle spotlessCheck` | `mvn compile` / `gradle build` | `mvn test` / `gradle test` | `mvn verify`, `gradle check` |
   | `*.csproj` / `*.sln` | .NET | `dotnet format --verify-no-changes` | `dotnet build` | `dotnet test` | analyzers via `dotnet build` |
   | `Gemfile` | Ruby | `rubocop` | — | `rspec`, `rake test` | `rubocop` |

   This table is illustrative, not exhaustive — apply the same idea to any stack.

2. **State the inferred commands** to the user (format / build / test / lint) and
   proceed unless they correct you.
3. **Ask only when ambiguous** — empty/bootstrapping repo, multiple manifests
   (e.g. a polyglot monorepo), or no recognizable marker. Ask for the four
   commands explicitly rather than guessing.

Throughout the rest of this skill, "format / build / test / lint" mean **the
commands established here**, substituted into the goal_condition style examples
in place of the Go commands shown.

## Decomposition rules (apply aggressively)

1. **Split by user action** — each CLI subcommand, flag, API endpoint, or workflow step is its own feature.
2. **Split by state transition** — loading, empty, success, and error states are separate features.
3. **Split by validation type** — HTTP shape, persistence, CLI output, and internal invariants are separate.
4. **Split by failure mode** — success path and each distinct error path are separate.
5. **Split by integration boundary** — each external service interaction is its own feature.
6. **Split by definition of done** — if a goal_condition needs more than ~5 numbered assertions or would exceed ~1500 chars, split further.

Encode ordering with `depends_on`. Never bundle prerequisites into one feature.

## goal_condition writing rules (the heart of this skill)

Every `goal_condition` MUST:

1. Start with: `Feature <id> is complete when ALL of the following are visible in this session's transcript:`
2. Enumerate concrete transcript-observable assertions, numbered `(1)`, `(2)`, ... Each references a specific executed command and its exact visible evidence (exit code, output substring, empty output, PASS line).
3. Require full output + exit codes visible: "Each command's full output and exit code must be visible in this transcript."
4. Include the progress.jsonl append as an assertion: `Append a line to progress.jsonl of the form {"feature_id":"<id>","status":"pass","timestamp":"<ISO8601>"} and \`cat progress.jsonl | tail -1\` must show that line in the transcript.`
5. Include the journal append as an assertion: `Append an entry to RFL_JOURNAL.md following the success-entry schema, then run \`tail -40 RFL_JOURNAL.md\` so the entry is visible in the transcript.`
6. End with: `Stop after <turn_cap> turns if not complete and report what is blocking.`
7. Stay under 4000 characters.
8. Use no vague predicates. Required style references a specific command and its
   exact evidence — e.g. ``\`<test> -run TestX -v\` was executed and the transcript
   shows it exited 0 with PASS visible`` (substitute the project's real test
   command from the toolchain step).

## Validation primitives (toolchain-agnostic)

Express each assertion in terms of the four toolchain commands established above.
Substitute the project's real commands for the Go examples shown:

- **Format:** the format-check command reports no changes needed (e.g. `gofmt -l .`
  empty, `prettier --check .` exit 0, `cargo fmt --check` exit 0).
- **Compile / build:** the build command exits 0 (e.g. `go build ./...`,
  `tsc --noEmit`, `cargo build`, `mvn compile`).
- **Tests:** the full test command exits 0; a focused run exits 0 with a PASS
  line visible (e.g. `go test ./... -run X -v`, `pytest -k X -v`, `cargo test X`).
- **Static analysis / lint:** the lint command exits 0 (e.g. `go vet ./...`,
  `eslint .`, `cargo clippy -- -D warnings`, `ruff check .`).
- **Behavioral checks** (HTTP, persistence, CLI exit codes) SHOULD be expressed
  as automated tests invoked through the project's test runner with a focused,
  verbose flag, so the PASS line is transcript-observable — not ad-hoc `curl` or
  shell pipelines. If the stack genuinely has no test runner, use a deterministic
  command whose exit code and output substring are asserted in the goal_condition.

## Categories (enum)

`functional` | `api-contract` | `cli` | `integration` | `technical` | `non-functional`. No `ui`.

## Steps field

1–6 entries. Black-box assertions or concrete actions. No file/package/function/
library names. Mirror the assertions in the goal_condition.

## Final checklist (silent, before emit)

1. Single top-level JSON array, no fences, no prose.
2. Every feature has all required fields.
3. All ids unique; all `depends_on` references point to existing ids; no cycles.
4. Every category is in the allowed enum.
5. Every goal_condition: starts with the prescribed identifier clause; has numbered transcript-observable assertions; requires command output + exit codes visible; includes the progress.jsonl assertion with `tail -1` evidence; includes the RFL_JOURNAL.md assertion with `tail -40` evidence; ends with the turn-cap clause; is under 4000 chars; contains no vague predicates.
6. Every `validation.command` is a runnable command in the project's established toolchain, consistent with the goal_condition.
7. `progress_log_entry.feature_id` equals the feature's `id`.
8. No feature has a `passes` field.
9. No step or condition references files, packages, functions, or libraries by name (except `progress.jsonl` and `RFL_JOURNAL.md`).

## Scale guidance

Be exhaustive. Be tiny. Be deterministic. Be parallelizable. When in doubt, split
smaller. If the project exceeds ~150 features, prefix ids by milestone
(`M1-FEAT-001`, `M2-FEAT-001`) and use `depends_on` for cross-milestone ordering.
