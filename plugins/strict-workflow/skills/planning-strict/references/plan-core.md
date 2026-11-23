# Plan Core (planning-strict)

Shared by feature and refactor plans. Turn a clear spec into bite-sized tasks for an engineer with zero context. An unclear spec produces questions, not a plan.

**Save to:** `docs/plans/YYYY-MM-DD-<feature>.md` unless the user or project says otherwise.

## 1. Explore

Read project rules, the code the spec touches, its tests, and similar features. Every path, symbol, and command in the plan must be one you have seen.

**Invariant sweep.** A ticket's list of endpoints, screens, or files is a sample, not the scope. Name the rule the change enforces in one sentence (e.g. "only the creator may modify a draft", "a logout clears all user state"). Then find every path that can break it: callers of the shared helpers, queries, and guards involved; sibling endpoints and actions on the same entity; other clients (UIs, public API, jobs); every place that holds the affected state; every path that reads or returns the changed data (queries, detail and list endpoints, exports, serializers), not only the paths that write it, each named. Each one goes into the Scope Map as in or out, with a reason. Reviewers check the rule, not your list.

**Impact sweep.** The invariant sweep finds paths that still break the rule; this finds callers the change itself breaks. For every shared symbol whose signature, return value, thrown error, status code, side effects, or timing changes (helpers, guards, queries, DTOs, events, config keys), list every caller and consumer: other endpoints, jobs, other modules, tests, and clients that read the response. For each, state its behavior before and after, and whether the difference is intended. An unintended change is designed out (keep that caller on the old path, add a variant) or goes to the Requirements Gate; it never ships silently.

**Existing data and states.** List what already exists that the new rule did not allow: legacy rows, duplicates, null fields, sessions or tabs already open, items mid-flow. Work out how each would behave under the change, including no-op updates and state transitions (disabled → enabled, rename, retry); where that is a business choice, it goes to the Requirements Gate.

## 2. Requirements Gate

A question blocks the plan only when the request, the code, and the project rules leave it open and its answer changes a test's expected outcome inside the requested scope (behavior, a key binding, a file/API/message format, or what the user sees). These count: ticket text marked "to be confirmed", "TBD", or "?"; acceptance criteria that disagree with the ticket's Approach or with each other; behavior the ticket does not mention but a test must pin down (URL normalization, status codes, which errors retry); the intended behavior for each Existing Data case the request does not settle; each Scope Map path that breaks the rule if left out, unless the user already excluded it; each Impact Map caller whose behavior would change in a way the spec does not ask for.

These do not count: anything the request already answers (never ask to confirm it); effects outside the requested scope, such as other features, reports, or clients the request does not cover, which go into the Scope Map as out with a follow-up; technical choices with an obvious convention. A spec that settles the behavior is planned, not blocked.

- **Any blocking question →** write no tasks. Output only `# [Feature] — Open Questions (plan blocked)`: numbered questions, each with options, your recommendation, and what it affects. Stop.
- **None →** write the plan. List each technical choice you made under Technical Defaults, and each out-of-scope effect as a follow-up in the Scope Map.
- **User answered, accepted recommendations, or delegated ("use your judgment") →** record each under Confirmed Requirements (`(delegated)` for handed-over choices) and continue without asking again.

**Decision log.** A decision that lives only in this chat gets asked again in review. For every business decision in Confirmed Requirements, draft a short ticket comment (decision, reason, who decided) and a matching line for the PR description. Posting to the ticket is outward-facing: show the draft and post only on the user's yes. Record the link, or "not posted: <reason>", in the plan.

| Rationalization | Reality |
|---|---|
| "User is busy; I'll list decisions to confirm" | A plan on guessed rules gets executed as written. Ask; it takes them a minute. |
| "Assumptions are clearly marked" | Marked assumptions still become code. |
| "Each question has a sensible default" | Put it in the question as your recommendation. |
| "Better to confirm everything first" | Asking what the request already says, or about effects outside its scope, blocks a clear spec. Note follow-ups and plan. |

## 3. Write the Plan

Split by subsystem if the spec spans independent ones. A task is the smallest unit with its own test cycle that a reviewer could reject alone; fold setup and docs into the task that needs them.

**Header — every slot required:**

```markdown
# [Feature] Implementation Plan
> **For agentic workers:** REQUIRED SUB-SKILL: subagent-driven-strict or executing-plans-strict. Tasks are `### Task N: <name>`; steps use `- [ ]`.
**Goal / Architecture / Tech Stack / Branch:** [branch per project convention; ADR path if one decided the design]
## Confirmed Requirements   [user answers; `(delegated)` items | none]
## Decision Log             [decision → ticket comment link | "not posted: reason" | none]
## Scope Map                [invariant sentence; then path → in (task N) | out (follow-up ticket or "user excluded") | out (follow-up: <what>; outside requested scope) | none: reason]
## Impact Map               [changed shared symbol → caller → before / after → intended (task N, test) | unchanged (why) | none: no shared symbol changes]
## Existing Data & States   [pre-existing case → intended behavior → task/test | none: reason]
## Global Constraints       [spec + project rules verbatim: invariants, parity, verification commands, commit policy]
## Technical Defaults       [choice — reason | none]
## Risks & Rollback         [risk → mitigation → revert, covering persisted data, APIs, formats, behavior changes, platform gaps | "none: reason"]
```

**Format (executors parse it):** each task starts with the heading `### Task N: <name>`, numbered from 1 without gaps; no other heading contains `Task <number>`. Every step under it is a `- [ ]` checkbox. A task is complete when all its steps are `- [x]`; that is the only progress marker executors use to resume.

**Each task:** Type (feature | refactor | docs) · Files (exact paths, line ranges) · Interfaces (Consumes/Produces, exact signatures) · steps per its type: feature → `plan-feature.md`, refactor → `plan-refactor.md`. Use the project's real commands. A task with no executable behavior at all (prose docs, comments) names the check that proves it (build, link/render check, docs lint, or a stated diff review): `RED: n/a — no executable behavior, checked by <check>`. A task that changes any observable behavior is a feature task.

**Test level per task:** name it (unit / integration / e2e). A task that touches a real boundary (DB, HTTP endpoint or client, message broker, file system, external API) needs an integration test against the real resource (e.g. Testcontainers), not only unit tests with mocks. Its run steps use the command that actually executes integration tests (e.g. `mvn verify` / failsafe, not `mvn test`).

**Test strength:** the setup creates the precondition the test name claims (a "URL already taken" test stubs a row holding that URL). Assertions check the end state, not only that the old value is gone ("profile is null", not "profile is not A"; status plus body/message, not status alone). Each in-scope Scope Map path and each Existing Data case has a test. Each Impact Map caller whose behavior changes has a test asserting the new behavior; one marked unchanged for a reason that is not obvious from the code has a test pinning the old behavior.

**Commit checkpoint:** if the project allows commits during execution, `git add <files>` + `git commit -m "<project format>"`. If it says commit only when asked, or has no rule: `Ready to commit: <files> — "<message>"`, no `git commit`. The plan file belongs to the branch and is committed with the work, `- [x]` progress included; the executor skill decides when. Reviewers treat it as requirements, not as code under review.

**Last task — Verification & Docs:** full verification list and final gate from project and global rules (`CLAUDE.md` / `AGENTS.md`), an end-to-end check with expected evidence, required doc updates, and any verification gap the executor must report. Note whether CI actually runs the new tests (e.g. a PR build that skips integration tests); if not, the PR must say so and show a local or pipeline run.

**No placeholders:** no TBD/TODO, "handle edge cases", "write tests for the above", "similar to Task N", code steps without code, or symbols no task defines.

## 4. Review

1. Self-review: each requirement maps to a task; every Scope Map path is in (with a task) or out (with a ticket or the user's exclusion, or, for an effect outside the requested scope, a follow-up note); every Impact Map caller is intended (with a test) or unchanged (with a reason); every Existing Data case has a test; no placeholders; names and types consistent across tasks; every header slot filled; task headings and checkboxes follow the Format rule.
2. For 2+ tasks, or changes to persisted data, APIs, formats, invariants, or shared code with other callers: dispatch a reviewer with `plan-document-reviewer-prompt.md` from the planning-strict directory. Fix Critical/Important issues and re-review, max 2 rounds. Report anything still open.

## 5. Handoff

"Plan saved to `<path>`. Reviewer: [Approved | open: …]. Execute via (1) subagent-driven-strict (recommended for more than ~5 independent tasks) or (2) executing-plans-strict?"
