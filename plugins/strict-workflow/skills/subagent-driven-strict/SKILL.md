---
name: subagent-driven-strict
description: Use when executing a written implementation plan (e.g. docs/plans/*.md) in the current session by dispatching one fresh implementer subagent per task, with a strict per-task review and a final whole-branch review, especially when the plan has more than ~5 mostly independent tasks
---

# Subagent-Driven Execution (Strict)

You are the controller. Per task: one fresh implementer subagent, then one task reviewer; at the end, one whole-branch review. You never write the code yourself; you prepare inputs, check outputs, and keep the ledger.

**Announce:** "I'm using the subagent-driven-strict skill to execute this plan."
**Precedence:** user > project `CLAUDE.md`/`AGENTS.md` > global `CLAUDE.md` > this skill > the plan.
**Use `executing-plans-strict` instead** when the plan has ≤ ~5 tasks or its tasks depend on each other so tightly that a fresh subagent would lack needed context.

## Step 0: Workspace

1. **Branch:** never implement on `main`/`master`. Create the branch the plan names (or `feature|fix|chore/<short-desc>`) from the latest `origin/<base>`. For isolation, use a worktree: `git worktree add ../<repo>-<branch> -b <branch> origin/<base>`, then work only inside it. The plan file must live on that branch: if it is untracked in the main checkout, copy it into the worktree at the same path and use only that copy from then on.
2. **Clean start:** the working tree is clean, or its changes belong to this plan.
3. **Baseline:** run the project's test suite (integration tests included) before Task 1. Failing baseline → report and ask; never build on red.
4. **Commits:** the global rule is "commit only when asked". Ask once: "Commit per task on `<branch>`?" (one question, before Task 1).
   - **Yes:** implementers commit per task in the project's format; per-task diffs are `BASE..HEAD`.
   - **No:** implementers do not commit. After a task's review is clean, you stage exactly the reviewed paths (staging is the checkpoint, not a commit; see Close the task); per-task diffs are the unstaged and untracked changes (see Review package).
5. **Workspace dir:** `bash <this skill>/scripts/task-brief` creates `<repo>/.sdd/` (self-ignored) for briefs, reports, packages, and the ledger.

## Step 1: Load and Pre-flight

1. **Resume:** read `<repo>/.sdd/progress.md` if it exists. Tasks listed complete are done; never re-dispatch them. After any compaction, trust the ledger and `git log` over memory.
2. Read the whole plan once. Copy its **Global Constraints** verbatim; every dispatch carries them.
3. **Staleness:** confirm every file, symbol, and command the plan names still exists as described.
4. **Conflicts:** tasks contradicting each other, the Global Constraints, or project rules; a plan-mandated defect (a test that asserts nothing, a boundary task without an integration test, duplicated logic).
5. Any finding from 3–4 → present all of them in one message, each beside the plan text, and wait. None → proceed without comment.

## Step 2: Per Task

1. **Record BASE** (`git rev-parse HEAD`) before dispatching.
2. **Brief:** `bash <this skill>/scripts/task-brief <plan> <N>` prints the brief path. The report path is the same with `-report.md`.
3. **Dispatch the implementer** with `implementer-prompt.md`. Model: `sonnet` when the brief contains the complete code; `opus` for multi-file integration, design judgment, or any task touching security, money, concurrency, or persisted formats. Never omit the model.
4. **Handle the status:**

| Status | Action |
|---|---|
| DONE | Check the report has RED (or the behavior-preserving before-run, or for a `no executable behavior` task its named check) and GREEN evidence, the commands, and (for a boundary task) integration-test results. Missing any → send back. Then check it yourself: (a) commit mode: `git status --porcelain` lists nothing but the plan file (your ticks) and `HEAD` moved past BASE, else uncommitted work would escape the review → send back; (b) re-run the report's GREEN command(s), integration tests included (no GREEN command → re-run the named check); a result that differs from the report → send back with both outputs. Running tests is not writing code. Then review. |
| DONE_WITH_CONCERNS | Correctness or scope concerns → resolve before review. Observations → note them in the ledger, then review. |
| NEEDS_CONTEXT | Supply the missing context; re-dispatch. |
| BLOCKED | Context problem → more context. Too hard → re-dispatch on `opus`. Too big → split. Plan wrong → ask the user. Never retry unchanged. |

5. **Review package:** with commits, `bash <code-review-strict>/scripts/review-package --base <BASE> --head HEAD`. Without commits, write to `<repo>/.sdd/task-<N>-package.md`: `git diff --stat`, `git diff -U10`, and for each `git ls-files --others --exclude-standard` file, `git diff --no-index -U10 /dev/null <file>`. Never read the package yourself.
6. **Dispatch the task reviewer** with `task-reviewer-prompt.md`, model **`opus`**, always explicit.
7. **Act on the verdict:**
   - Critical or Important → one fix dispatch (implementer template, same brief, the full findings list, the covering test files named); the fixer appends test results to the report. Its status goes through step 4 again (checks a and b included), then step 5 rebuilds the package; re-review. At most 3 rounds, then ask the user.
   - ⚠️ cannot-verify items → check each yourself against the plan and the code; a real gap is a failed review.
   - A finding that conflicts with the plan's text → ask the user which governs; never dismiss it and never fix against the plan silently.
   - Minor → record in the ledger for the final review.
8. **Close the task:** tick all the task's steps `- [x]` in the plan. No-commit mode: compare `git status --porcelain` with the files in the reviewed package and stage exactly those plus the plan file (`git add -- <paths>`); never `git add -A`. A path the review never saw (build output, logs, a `.env` written by tests) stays unstaged: remove it via a fix dispatch if the task created it by mistake, otherwise ask. Commit mode: leave the ticks uncommitted (implementers never touch the plan file); they are committed with the branch at the end. Append to the ledger: `Task N: complete (<base7>..<head7> | staged), review clean, Minor: <list | none>`.

Run tasks one at a time, never two implementers in parallel. Do not stop between tasks to ask "continue?"; stop only for a question, a blocker, or a plan conflict.

## Step 3: Finish

1. Run the final gate yourself (steps 1–3 of the `finishing-branch-strict` Gate, plus any stricter project or global rule): full diff, full test suite with integration tests, build/lint/typecheck. Integration tests that cannot run → Unverified; the plan is not done.
2. Whole-branch review: `code-review-strict` (model `opus`), with the plan as requirements and the ledger's Minor list attached.
3. Fix Critical/Important findings with one fix dispatch carrying the whole list, then re-run step 1 and re-review per `code-review-strict`.
4. Report:

```
Plan: <path>   Tasks: <done>/<total>
Verification: <command → result, unit and integration counts>
Review: <verdict, rounds; fixed / rejected / open>
Deviations: <plan said X, did Y, because Z | none>
Unverified: <gap and why | none>
Follow-ups: <Minor and out-of-scope items | none>
```

5. Plan file: commit mode → commit it with its ticks (`git add -- <plan>`, project format); no-commit mode → it is already staged. Then `finishing-branch-strict`.

## Dispatch Rules

- A dispatch holds one task: where it fits (one line), the brief path, interfaces from earlier tasks, your resolution of any ambiguity, the Global Constraints, the rule-file paths, and the report path. No accumulated history from earlier tasks.
- Never tell a reviewer what not to flag or pre-rate a severity; let the finding come and decide it in triage.
- Never fix code yourself; a fix goes through a dispatch so it carries test evidence.
- Hand bulky artifacts over as files (brief, report, package); never paste them.

## Red Flags

| Thought | Reality |
|---|---|
| "Reviewer model doesn't matter for a small diff" | Reviewers are `opus`, named explicitly. |
| "Unit tests pass; the DB part is mocked anyway" | A boundary task without a passing integration test is not done. |
| "Implementer self-review is enough" | Self-review never replaces the task review. |
| "The finding is plan-mandated, skip it" | Plan conflicts go to the user. |
| "Compaction happened, I'll redo Task 1" | Read the ledger and `git log` first. |
| "The report says GREEN, no need to run it" | Re-run the GREEN commands; reports are claims. |
| "`git add -A` is quicker" | Stage only reviewed paths; stray files may be secrets. |
