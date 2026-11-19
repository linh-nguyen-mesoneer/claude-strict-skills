---
name: executing-plans-strict
description: Use when executing a written implementation plan (e.g. docs/plans/*.md) inline in the current session, with progress tracked in the plan file, batch checkpoints for user review, and project rules (CLAUDE.md) taking precedence over the plan
---

# Executing Plans (Strict)

## Overview

Verify the plan is still valid, execute it in reviewed batches, track progress in the plan file so any session can resume, and report deviations instead of improvising.

**Announce at start:** "I'm using the executing-plans-strict skill to implement this plan."

**Precedence:** user instructions > project `CLAUDE.md` / `AGENTS.md` > this skill > the plan. When the plan conflicts with a project rule (branch naming, verification commands, commit policy), the project rule wins; note the conflict in the next checkpoint.

**When to use this instead of `subagent-driven-strict`:** the user wants the work done inline, the plan is small (≤ ~5 tasks), or tasks depend on each other so tightly that fresh-context subagents would lose needed context. Otherwise prefer `subagent-driven-strict`.

## Step 0: Workspace

1. Locate the plan. If the user did not give a path, look in `docs/plans/`; if several candidates exist, ask which one.
2. Check the current branch. Never implement on `main`/`master` without explicit consent. If no feature branch exists, create one from the latest `origin/<base>` following the project's naming rule (fall back to `feature|fix|chore/<short-desc>`). For isolation, use a worktree: `git worktree add ../<repo>-<branch> -b <branch> origin/<base>`, then work only inside it.
3. Run the project's test suite (integration tests included) as a baseline. Failing baseline → report and ask; never build on red.
4. Confirm the working tree is clean, or that existing changes belong to this plan.

## Step 1: Load and Review

1. Read the whole plan.
2. **Resume check:** tasks already marked `- [x]` are done. Verify the last completed task's verification still passes before continuing; never redo or skip silently.
3. **Staleness check:** for every file, function, type, or command the plan references, confirm it still exists and matches what the plan assumes. Check `git log` since the plan's date for commits touching those areas.
4. Review critically: missing steps, unclear acceptance criteria, untested behavior, conflicts with project rules.
5. If there are concerns or staleness findings, raise them all at once and wait. If none, create todos for the tasks and proceed.

## Step 2: Execute in Batches

Batch size: one phase if the plan has phases, otherwise 3 tasks. The user may change it (e.g. "run all without stopping").

For each task:
1. Mark the todo in_progress.
2. Follow the plan's steps exactly.
3. Run the verification the plan specifies **plus** the project's required verification for the files touched (from `CLAUDE.md`). If the task touches a real boundary (DB, HTTP, broker, file system, external API), also run the integration tests of the affected module with a command that executes them (e.g. `mvn verify -pl <module>`; `mvn test` skips `*IT` classes). A boundary task with no integration test is a plan gap: stop and report it.
4. Mark the task `- [x]` in the plan file, appending a short note if anything deviated (e.g. `- [x] Task 3 — deviated: see checkpoint 2`).
5. Mark the todo completed.

**Commits:** follow the project commit policy. If the project says "commit only when asked", do not commit per task even if the plan says to; list ready-to-commit units in the checkpoint instead.

### Checkpoint (after each batch)

Report, then wait for the user's go-ahead:

```
Checkpoint N — tasks <a>..<b>
Done:        <task — one line each>
Verified:    <command → result, with unit and integration test counts>
Deviations:  <plan said X, did Y, because Z | none>
Unverified:  <what and why | none>
Next batch:  <tasks>
```

## Deviations

When a plan step does not match reality (the code differs, an API does not exist, a step would break a project invariant):
- Do not invent a replacement approach.
- Stop, state what the plan says, what you found, and the options you see, then ask.
- A purely mechanical difference with an obvious fix (renamed file, moved line number) may be applied, but must be listed under Deviations.

## When to Stop and Ask

Stop immediately when:
- A blocker appears (missing dependency, unclear instruction, unavailable environment).
- The same verification fails **twice for the same cause** after a fix attempt.
- The plan has a gap that prevents the next task.
- Continuing would require changing a public API, schema, persisted format, or dependency the plan did not explicitly cover.

Never force through a blocker, weaken a test, or skip a verification to keep going.

## When to Revisit Step 1

- The user updates the plan after your feedback.
- The fundamental approach needs rethinking.
- New commits land on the base branch touching the plan's areas.

## Step 3: Complete

After all tasks are `- [x]` and verified:
1. Run the full verification suite of the project (not only per-task checks): unit tests, integration tests, and build/lint/typecheck. If integration tests cannot run (no container runtime, missing environment), report them under Unverified; the plan is not done.
2. Give the final report:

```
Plan: <path>
Completed:   <n>/<total> tasks
Skipped:     <task — reason | none>
Deviations:  <summary | none>
Verification: <command → result, each>
Unverified:  <gaps and why | none>
Follow-ups:  <out-of-scope issues noticed | none>
```

3. For non-trivial plans, get the whole-branch review with `code-review-strict` (plan as requirements) and address its findings before the report.
4. Then `finishing-branch-strict`.

## Integration

- `writing-plans-strict` creates the plan (default `docs/plans/YYYY-MM-DD-<feature>.md`).
- `code-review-strict` for the whole-branch review.
- `finishing-branch-strict` to finish.
