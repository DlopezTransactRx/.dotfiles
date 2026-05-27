# RFL_JOURNAL.md schemas, lifecycle, and compaction

Append-only markdown log at repo root (`./RFL_JOURNAL.md`). Entries separated by
`---`. Three entry types. Bullet counts and word limits below are hard caps —
enforce them when writing.

## Success entry (written by the in-session agent during a goal session)

```markdown
## <feature_id> — <ISO8601 UTC timestamp> — PASS

**Description:** <one sentence, from prd.json>

**Duration:** <N> turns, ~<K>k tokens

**What was done:**
- <bullet, max 15 words>
- <up to 5 bullets total>

**Validation evidence:**
- `<command>` → <exit code or result>
- <up to 5 bullets total>

**Context for next session:**
- <bullet, max 15 words>
- <up to 3 bullets total>

**Files touched:** <high-level list, comma-separated, one line, max 10 items>

---
```

## Failure entry (written by this skill on next invocation)

```markdown
## <feature_id> — <ISO8601 UTC timestamp> — FAIL (<reason>)

**What was attempted:**
- <bullet, max 15 words>
- <up to 4 bullets total>

**What blocked progress:**
- <bullet, max 15 words>
- <up to 3 bullets total>

**Suggested next approach:**
- <bullet, max 15 words>
- <up to 3 bullets total>

**Files in unknown state:** <high-level list, one line, max 10 items>

---
```

## Skip entry (written by this skill on user request)

```markdown
## <feature_id> — <ISO8601 UTC timestamp> — SKIPPED

**Reason:** <one sentence, max 25 words>

**Dependents now blocked:** <comma-separated feature ids, or "none">

---
```

## Journal contract (lifecycle rules)

- **Successes self-log inline.** The agent inside the `/goal` session writes the
  success entry as part of the goal_condition's required assertions, with
  `tail -40 RFL_JOURNAL.md` evidence in the transcript.
- **Failures and skips log on next invocation.** When this skill activates, its
  first job (after reading state) is to detect any orphaned dispatch and write the
  failure entry retroactively.
- **Entries are immutable.** Never rewrite history. Corrections are new appended
  entries referencing the prior one.
- **The journal is advisory, not authoritative.** progress.jsonl + git state are
  the truth. If the journal contradicts code state, treat the journal as a hint
  and verify against code.
- **Hard caps enforced by schema.** The bullet counts and word limits above are
  the bloat control. Enforce them.

## Compaction policy

When `RFL_JOURNAL.md` exceeds **100 entries OR 500KB**, perform compaction at the
start of an invocation, before any other work:

1. Identify entries older than the most recent 30.
2. Move those older entries verbatim into `RFL_JOURNAL_ARCHIVE.md` (create if
   needed, append if it exists).
3. In `RFL_JOURNAL.md`, replace the moved entries with one rollup block:

```markdown
## ARCHIVED: <id_range_start> through <id_range_end> — <date_range>

<N> entries archived to RFL_JOURNAL_ARCHIVE.md. Persistent context worth keeping:
- <bullet, distilled from "Context for next session" sections>
- <up to 5 bullets total>

---
```

4. The "read last 10 entries" rule operates only on the live file. The archive is
   for human review.

**Do not** compress or rewrite individual entries to save space. Compaction is the
only bloat control; per-entry compression is forbidden.
