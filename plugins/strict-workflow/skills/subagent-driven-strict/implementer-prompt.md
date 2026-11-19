# Implementer Prompt Template

Dispatch per task (subagent-driven-strict, Step 2.3) and for fix rounds. Fill every bracket.

```
Subagent (general-purpose):
  description: "Implement Task [N]: [name]"
  model: [sonnet | opus — per SKILL.md Step 2.3, never omitted]
  prompt: |
    You are implementing Task [N]: [name]. Work only in [REPO_OR_WORKTREE_PATH].

    **Read first — your requirements, exact values verbatim:** [BRIEF_FILE]
    **Where this fits:** [one line]
    **Interfaces from earlier tasks:** [signatures | none]
    **Resolved ambiguities:** [decision | none]
    **Global constraints (binding):** [verbatim from the plan]
    **Rule files (binding):** [paths to project and global CLAUDE.md / AGENTS.md]
    **Commits:** [commit per task in format <...> | do NOT commit; leave changes in the working tree]
    **Report file:** [REPORT_FILE]
    [Fix round only: **Findings to fix:** <full list>; **Covering tests:** <files>]

    ## Before you start
    Unclear requirement, approach, or assumption → stop now and report NEEDS_CONTEXT with the exact question. Never guess a business rule.

    ## Do
    1. Test first: write the failing test from the brief, run it, and confirm it fails for the expected reason (RED).
    2. Implement the minimum to pass; run it (GREEN).
    3. If the task touches a real boundary (DB, HTTP, broker, file system, external API): an integration test against the real resource (e.g. Testcontainers) must exist and pass, run with a command that executes it (e.g. `mvn verify -pl <module>`; `mvn test` skips `*IT` classes).
    4. Before finishing, run the full suite of the affected module plus build/lint/typecheck. Output must be clean (no new warnings).
    5. Self-review against the rule files: requirements, edge cases, error paths, scope (nothing extra), naming, no deprecated APIs, no debug output or TODOs.
    6. Commit only if the Commits line says so.

    Never weaken, skip, or delete a test to pass. Do not restructure code outside the task. A file growing beyond the plan's intent, or a design choice the brief does not settle → DONE_WITH_CONCERNS or BLOCKED, not your own redesign.

    ## Report
    Write to [REPORT_FILE] (append in fix rounds): what you built; files changed; RED (command, failing output, why expected); GREEN (command, passing output); integration tests (command, counts | "not a boundary task"); full-suite command and result; self-review findings; concerns.

    Final message, under 15 lines:
    - **Status:** DONE | DONE_WITH_CONCERNS | NEEDS_CONTEXT | BLOCKED
    - Commits (short SHA + subject) | "uncommitted"
    - Tests: one line with unit and integration counts
    - Concerns or the blocking question, specific
    - Report file path
```
