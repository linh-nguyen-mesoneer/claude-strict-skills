---
name: writing-plans-strict
description: Use when you have a spec or requirements for a multi-step task and need a written implementation plan (e.g. docs/plans/*.md) before touching code, especially in a repo with project rules (CLAUDE.md) on commits, verification, or invariants
---

# Writing Plans (Strict)

Turn a clear spec into bite-sized TDD tasks for an engineer with zero context. An unclear spec produces questions, not a plan.

**Announce:** "I'm using the writing-plans-strict skill to create the implementation plan."
**Precedence:** user > project `CLAUDE.md`/`AGENTS.md` > this skill.
**Save to:** `docs/plans/YYYY-MM-DD-<feature>.md` unless the user or project says otherwise.

## 1. Explore

Read project rules, the code the spec touches, its tests, and similar features. Every path, symbol, and command in the plan must be one you have seen.

## 2. Requirements Gate

List every question whose answer changes behavior, a test's expected output, a key binding, a file/API/message format, or what the user sees.

- **Any such question →** write no tasks. Output only `# [Feature] — Open Questions (plan blocked)`: numbered questions, each with options, your recommendation, and what it affects. Stop.
- **None →** continue. Technical choices with an obvious convention go under Technical Defaults.
- **User answered, accepted recommendations, or delegated ("use your judgment") →** record each under Confirmed Requirements (`(delegated)` for handed-over choices) and continue without asking again.

| Rationalization | Reality |
|---|---|
| "User is busy; I'll list decisions to confirm" | A plan on guessed rules gets executed as written. Ask; it takes them a minute. |
| "Assumptions are clearly marked" | Marked assumptions still become code. |
| "Each question has a sensible default" | Put it in the question as your recommendation. |

## 3. Write the Plan

Split by subsystem if the spec spans independent ones. A task is the smallest unit with its own test cycle that a reviewer could reject alone; fold setup and docs into the task that needs them.

**Header — every slot required:**

```markdown
# [Feature] Implementation Plan
> **For agentic workers:** REQUIRED SUB-SKILL: subagent-driven-strict or executing-plans-strict. Steps use `- [ ]`.
**Goal / Architecture / Tech Stack / Branch:** [branch per project convention]
## Confirmed Requirements   [user answers; `(delegated)` items | none]
## Global Constraints       [spec + project rules verbatim: invariants, parity, verification commands, commit policy]
## Technical Defaults       [choice — reason | none]
## Risks & Rollback         [risk → mitigation → revert, covering persisted data, APIs, formats, behavior changes, platform gaps | "none: reason"]
```

**Each task:** Files (exact paths, line ranges) · Interfaces (Consumes/Produces, exact signatures) · steps: write failing test (full code) → run, expect FAIL with reason → minimal implementation (full code) → run, expect PASS → commit checkpoint. Use the project's real commands.

**Test level per task:** name it (unit / integration / e2e). A task that touches a real boundary (DB, HTTP endpoint or client, message broker, file system, external API) needs an integration test against the real resource (e.g. Testcontainers), not only unit tests with mocks. Its run steps use the command that actually executes integration tests (e.g. `mvn verify` / failsafe, not `mvn test`).

**Commit checkpoint:** if the project allows commits during execution, `git add <files>` + `git commit -m "<project format>"`. If it says commit only when asked, or has no rule: `Ready to commit: <files> — "<message>"`, no `git commit`.

**Last task — Verification & Docs:** full verification list and final gate from project and global rules (`CLAUDE.md` / `AGENTS.md`), an end-to-end check with expected evidence, required doc updates, and any verification gap the executor must report.

**No placeholders:** no TBD/TODO, "handle edge cases", "write tests for the above", "similar to Task N", code steps without code, or symbols no task defines.

## 4. Review

1. Self-review: each requirement maps to a task; no placeholders; names and types consistent across tasks; every header slot filled.
2. For 2+ tasks, or changes to persisted data, APIs, formats, or invariants: dispatch a reviewer with `plan-document-reviewer-prompt.md` from this directory. Fix Critical/Important issues and re-review, max 2 rounds. Report anything still open.

## 5. Handoff

"Plan saved to `<path>`. Reviewer: [Approved | open: …]. Execute via (1) subagent-driven-strict (recommended for more than ~5 independent tasks) or (2) executing-plans-strict?"
