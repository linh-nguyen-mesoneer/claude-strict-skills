---
name: executing-plans-strict
description: Use when executing a written implementation plan (e.g. docs/plans/*.md) that is small or tightly coupled, with this session orchestrating and auditing while one implementer sub-session per batch writes the code, progress tracked in the plan file, batch checkpoints for user review, and project rules (CLAUDE.md) taking precedence over the plan
---

# Executing Plans (Strict)

## Overview

Verify the plan is still valid, hand each batch of tasks to one implementer sub-session, audit what comes back, track progress in the plan file so any session can resume, and report deviations instead of improvising.

**Announce at start:** "I'm using the executing-plans-strict skill to implement this plan."

**Precedence:** user > project `CLAUDE.md`/`AGENTS.md` > global `CLAUDE.md` > this skill > the plan. When the plan conflicts with a project rule (branch naming, verification commands, commit policy), the project rule wins; note the conflict in the next checkpoint.

**Roles and models:** this session holds the plan, orchestrates, and audits. It never writes the code: each batch goes to one implementer sub-session (see Dispatching the implementer). This main session runs on Opus or a higher tier; on Sonnet or Haiku, stop before Step 0 and ask the user to switch the session's model (`/model` or the app's model picker); on a tier you cannot place relative to Opus, ask the user. The implementer runs on `sonnet` by default, and on `opus` when any task in its batch meets an exception in `subagent-driven-strict` Step 2.3.

**When to use this instead of `subagent-driven-strict`:** the plan is small (≤ ~5 tasks), or its tasks depend on each other so tightly that one implementer should carry a whole batch. Otherwise prefer `subagent-driven-strict`.

## Dispatching the implementer

The implementer is a **sub-session**: a separate Claude Code session started with `mcp__ccd_session__start_session` (load it with `ToolSearch` `select:mcp__ccd_session__start_session` if it is only listed as deferred), not an `Agent` subagent. The user sees it in the sidebar and can open, steer, or stop it.

- **Start:** `initiation: "user_asked"` (the user asked for the plan to be executed, and this skill is their standing instruction), `context: "fresh"`, `use_worktree: false` (it must edit the checkout this session audits), `wake_when_done: true`, `title` = `Implement Task [N]: [name]`, `name` = `impl-<a>-<b>` (fix rounds reuse the session, see below). `prompt` = the filled `implementer-prompt.md` body, with the session lines filled in. `background` = the plan path, the feature goal in one sentence, and that this session orchestrates and audits while the sub-session only implements. Model: `sonnet` → pass the current Sonnet model id; `opus` → pass the current Opus model id. Never omit it.
- **Wait:** after the start call, end the turn and wait for the app to continue you with the sub-session's note. Never poll, sleep, or write code meanwhile. If its note shows it waiting on the user (a permission prompt, a question), tell the user and link the session.
- **Read the result from the report file**, not the note: the note quotes only the first 400 characters. The Status lines are in the report's `## Final status` section; a missing section is NEEDS_CONTEXT for that batch.
- **Fix rounds** go to the same sub-session with `SendMessage` (load it via `ToolSearch` if deferred; `to` = its `local_…` id), carrying the full findings list. If it was stopped, archived, or cannot receive messages, start a new one with the same brief and the findings.
- **Fallback:** if `start_session` is unavailable (CLI without the desktop app) or refuses the start, dispatch the same prompt as an `Agent` subagent (`general-purpose`, same model) and record `Dispatch: subagent (fallback: <reason>)` in the checkpoint.

## Step 0: Workspace

1. Locate the plan. If the user did not give a path, look in `docs/plans/`; if several candidates exist, ask which one.
2. Check the current branch. Never implement on `main`/`master` without explicit consent. If no feature branch exists, create one from the latest `origin/<base>` following the project's naming rule (fall back to `feature|fix|chore/<short-desc>`). For isolation, use a worktree: `git worktree add ../<repo>-<branch> -b <branch> origin/<base>`, then work only inside it. The plan file must live on that branch: if it is untracked in the main checkout, copy it into the worktree at the same path and use only that copy from then on.
3. Run the project's test suite (integration tests included) as a baseline. Failing baseline → report and ask; never build on red.
4. Confirm the working tree is clean, or that existing changes belong to this plan.

## Step 1: Load and Review

1. Read the whole plan.
2. **Resume check:** a task whose steps are all `- [x]` is done (format: `planning-strict` `references/plan-core.md`, Format rule; a plan that does not follow it is a concern for item 5). Verify the last completed task's verification still passes before continuing; never redo or skip silently.
3. **Staleness check:** for every file, function, type, or command the plan references, confirm it still exists and matches what the plan assumes. Check `git log` since the plan's date for commits touching those areas.
4. Review critically: missing steps, unclear acceptance criteria, untested behavior, conflicts with project rules.
5. If there are concerns or staleness findings, raise them all at once and wait. If none, create todos for the tasks and proceed.

## Step 2: Execute in Batches

Batch size: one phase if the plan has phases, otherwise 3 tasks. The user may change it (e.g. "run all without stopping").

**Commits:** follow the project commit policy. If the project says "commit only when asked", the implementer does not commit, even if the plan says to; list ready-to-commit units in the checkpoint instead.

For each batch:
1. **Record BASE** (`git rev-parse HEAD`) and mark the batch's todos in_progress.
2. **Briefs:** for each task in the batch, `bash <subagent-driven-strict>/scripts/task-brief <plan> <N>` prints its brief path.
3. **Dispatch one implementer sub-session** (see Dispatching the implementer) with `<subagent-driven-strict>/implementer-prompt.md`, filled for the whole batch: `[N]` is the task range (`<a>–<b>`), `[name]` is the phase name (no phases: the task names joined by `; `), `[BRIEF_FILE]` is the first brief, the **Batch** line lists every brief path in task order, one report file (`.sdd/batch-<a>-<b>-report.md`), and the Commits line per the policy above. Model per Roles and models; never omit it.
4. **Audit** (this session, never delegated to the implementer):
   - Handle each task's status as in `subagent-driven-strict` Step 2.4 (DONE checks, concerns, NEEDS_CONTEXT, BLOCKED), except that this audit replaces its "Then review" and observations go to the checkpoint instead of a ledger. Tasks after the first one that is not DONE were not started; they go back into the next dispatch.
   - Re-run every task's GREEN command and the plan's verification **plus** the project's required verification for the files touched (from `CLAUDE.md`). A task that touches a real boundary (DB, HTTP, broker, file system, external API) needs its module's integration tests run with a command that executes them (e.g. `mvn verify -pl <module>`; `mvn test` skips `*IT` classes). A boundary task with no integration test is a plan gap: stop and report it.
   - Read the whole batch diff against the plan's steps, the Global Constraints, and the rule files: requirements, edge cases, tests that can fail, scope, nothing the plan did not ask for. With commits it is `BASE..HEAD`; without, it is `git diff` (unstaged only, since earlier batches are staged at step 5) plus each untracked file.
   - Findings → one fix dispatch to the same sub-session (same template, same briefs, the full findings list), then audit again. At most 3 rounds, then ask the user.
5. **Tick** each verified step `- [x]` in the plan file; if anything deviated, append a short note to the step it concerns (e.g. `- [x] Run the tests — deviated: see checkpoint 2`). Without commits, stage exactly the audited paths plus the plan file (`git add -- <paths>`, never `git add -A`); a path the audit never saw stays unstaged, as in `subagent-driven-strict` Step 2.8. Mark the batch's todos completed.

### Checkpoint (after each batch)

Report, then wait for the user's go-ahead:

```
Checkpoint N — tasks <a>..<b>
Done:        <task — one line each>
Verified:    <command → result, with unit and integration test counts, re-run by this session>
Dispatch:    <sub-session name and link | subagent (fallback: reason)>
Audit:       <findings fixed, rounds | clean>
Deviations:  <plan said X, did Y, because Z | none>
Unverified:  <what and why | none>
Next batch:  <tasks>
```

## Deviations

When a plan step does not match reality (the code differs, an API does not exist, a step would break a project invariant), whether the implementer reports it or the audit finds it:
- Do not invent a replacement approach, and do not let the implementer invent one.
- Stop, state what the plan says, what was found, and the options you see, then ask.
- A purely mechanical difference with an obvious fix (renamed file, moved line number) may be applied through a fix dispatch, but must be listed under Deviations.

## When to Stop and Ask

Stop immediately when:
- A blocker appears (missing dependency, unclear instruction, unavailable environment).
- The same verification fails **twice for the same cause** after a fix dispatch.
- The plan has a gap that prevents the next task.
- Continuing would require changing a public API, schema, persisted format, or dependency the plan did not explicitly cover.

Never force through a blocker, weaken a test, skip a verification, or write the code yourself to keep going.

## When to Revisit Step 1

- The user updates the plan after your feedback.
- The fundamental approach needs rethinking.
- New commits land on the base branch touching the plan's areas.

## Step 3: Complete

After every step of every task is `- [x]` and verified:
1. Run the full verification suite of the project (not only per-task checks): unit tests, integration tests, and build/lint/typecheck. If integration tests cannot run (no container runtime, missing environment), report them under Unverified; the plan is not done.
2. For non-trivial plans, get the whole-branch review with `code-review-strict` (plan as requirements) and address its findings through fix dispatches; any fix reruns step 1.
3. Give the final report:

```
Plan: <path>
Completed:   <n>/<total> tasks
Skipped:     <task — reason | none>
Deviations:  <summary | none>
Verification: <command → result, each>
Unverified:  <gaps and why | none>
Review:      <verdict, rounds; fixed / rejected / open | not run: trivial plan>
Follow-ups:  <out-of-scope issues noticed | none>
```

4. The plan file, ticks included, is part of the work: commit it as its own commit (project format, never `--amend`) if commits are allowed, otherwise list it under Ready to commit. Then `finishing-branch-strict`.

## Integration

- `planning-strict` creates the plan (default `docs/plans/YYYY-MM-DD-<feature>.md`).
- `subagent-driven-strict` provides `scripts/task-brief` and `implementer-prompt.md`.
- `code-review-strict` for the whole-branch review.
- `finishing-branch-strict` to finish.
