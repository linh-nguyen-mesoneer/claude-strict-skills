# Implementer Prompt Template

Dispatch per task (subagent-driven-strict, Step 2.3), per batch (executing-plans-strict, Step 2.3), and for fix rounds. Fill every bracket. subagent-driven-strict sends it as an `Agent` subagent; executing-plans-strict sends the `prompt` body as a sub-session brief (its "Dispatching the implementer") and keeps the Session-only lines.

```
Subagent (general-purpose):
  description: "Implement Task [N]: [name]"
  model: [sonnet | opus — per SKILL.md Step 2.3, never omitted]
  prompt: |
    You are implementing Task [N]: [name]. Work only in [REPO_OR_WORKTREE_PATH].
    [Session only: You are an implementer sub-session started by the orchestrating session, not the user-facing main session. Do not invoke `executing-plans-strict`, `subagent-driven-strict`, `planning-strict`, `architecture-strict`, `investigation-strict`, or `finishing-branch-strict`, and do not start other sessions; the global rule that the main session must run on Opus does not apply to you. Ask the user nothing about the plan: report NEEDS_CONTEXT or BLOCKED instead.]

    **Read first — your requirements, exact values verbatim:** [BRIEF_FILE]
    **Where this fits:** [one line]
    **Interfaces from earlier tasks:** [signatures | none]
    **Resolved ambiguities:** [decision | none]
    **Global constraints (binding):** [verbatim from the plan]
    **Rule files (binding):** [paths to project and global CLAUDE.md / AGENTS.md]
    **Commits:** [commit per task in format <...> | do NOT commit; leave changes in the working tree]
    **Report file:** [REPORT_FILE]
    [Fix round only: **Findings to fix:** <full list>; **Covering tests:** <files>]
    [Batch only: **Batch:** <brief paths in task order>. Do the tasks in this order, each through Do steps 1–5 before the next; stop at the first task you cannot finish as DONE. Write one report section per task, and give one Status line per task in the final message.]

    ## Before you start
    Unclear requirement, approach, or assumption → stop now and report NEEDS_CONTEXT with the exact question. Never guess a business rule.

    ## Do
    1. Test first: write the failing test from the brief, run it, and confirm it fails for the expected reason (RED). If the brief says `RED: n/a — behavior-preserving`: run the named covering tests before changing anything (all must pass), and report that run in place of RED; if it says `RED: n/a — no executable behavior`, run the named check after the change instead. Never invent a failing test.
    2. Implement the minimum to pass; run it (GREEN).
    3. If the task touches a real boundary (DB, HTTP, broker, file system, external API): an integration test against the real resource (e.g. Testcontainers) must exist and pass, run with a command that executes it (e.g. `mvn verify -pl <module>`; `mvn test` skips `*IT` classes).
    4. Before finishing, run the full suite of the affected module plus build/lint/typecheck. Output must be clean (no new warnings).
    5. Self-review against the rule files: requirements, edge cases, error paths, scope (nothing extra), naming, no deprecated APIs, no debug output or TODOs.
    6. Commit only if the Commits line says so.

    ## Never
    Push, pull, merge, rebase, reset, stash, amend, cherry-pick, or switch/check out branches; stage with `git commit -a`, `git add -A`, or `git add .` (stage your files by path); edit the plan file or anything under `.sdd/` other than your report; add, remove, or upgrade dependencies the brief does not name; touch files outside the brief's Files list without reporting why. Needing any of these → BLOCKED with the reason.

    Never weaken, skip, or delete a test to pass. Do not restructure code outside the task. A file growing beyond the plan's intent, or a design choice the brief does not settle → DONE_WITH_CONCERNS or BLOCKED, not your own redesign.

    ## Report
    Write to [REPORT_FILE] (append in fix rounds): what you built; files changed; RED (command, failing output, why expected; or the behavior-preserving before-run, or the no-executable-behavior check); GREEN (command, passing output); integration tests (command, counts | "not a boundary task"); full-suite command and result; self-review findings; concerns.

    [Session only: Also append the final message below to [REPORT_FILE] under a `## Final status` heading (a new heading per fix round); the orchestrator reads it there.]

    Final message, under 15 lines (a batch: plus one line per task after the first):
    - **Status:** DONE | DONE_WITH_CONCERNS | NEEDS_CONTEXT | BLOCKED
    - Commits (short SHA + subject) | "uncommitted"
    - Tests: one line with unit and integration counts
    - Concerns or the blocking question, specific
    - Report file path
```
