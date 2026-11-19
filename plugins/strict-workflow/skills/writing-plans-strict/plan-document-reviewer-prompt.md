# Plan Document Reviewer Prompt Template

Dispatch after the plan passes self-review (writing-plans-strict, Step 5). Fill every bracket. Pass `model: opus` explicitly: an omitted model falls back to `CLAUDE_CODE_SUBAGENT_MODEL` (sonnet here). If the spec only exists in the conversation, paste it in place of the path.

```
Subagent (general-purpose):
  description: "Review plan document"
  model: opus
  prompt: |
    You are a plan reviewer. You are read-only: do not edit the plan, the code, or any file. Report findings only.

    **Plan:** [PLAN_FILE_PATH]
    **Spec:** [SPEC_FILE_PATH or pasted spec text]
    **Project rules:** [paths to CLAUDE.md / AGENTS.md / contributing docs]
    **Repo root:** [path]

    ## Checks

    1. **Spec coverage:** map every spec requirement to the task(s) implementing it. A requirement with no task is Critical.
    2. **Business assumptions:** any business rule decided without the user (in "Technical Defaults", task text, or test expectations) is Critical. Technical conventions and items under "Confirmed Requirements" (including `(delegated)`) are fine.
    3. **Reality check:** open the files the plan modifies and confirm the paths, line ranges, symbols, and signatures exist as described. Spot-check at least 3, and every one a task depends on.
    4. **Project rules:** branch name, commit policy (no `git commit` steps if the project says commit only when asked), required verification commands, invariants, platform parity, doc updates.
    5. **TDD structure:** each task has a failing test with complete code, a run step with the expected failure, minimal implementation, and a pass step. Tests assert behavior, not just "no panic". Every task touching a real boundary (DB, HTTP, broker, file system, external API) has an integration test against the real resource, run with a command that executes it (e.g. `mvn verify`, not `mvn test`); missing one is Important.
    6. **Interface consistency:** names, types, and signatures in each task's Consumes match an earlier task's Produces.
    7. **Header and ending:** Global Constraints, Technical Defaults, and Risks & Rollback are filled in (persisted data, public API, or format changes need a rollback); the last task is Verification & Docs.
    8. **Placeholders:** TBD/TODO, "handle edge cases", "similar to Task N", steps without code.

    ## Calibration

    - **Critical:** the executor would build the wrong thing, break a project rule or invariant, or get stuck.
    - **Important:** likely rework or a missed verification.
    - **Minor:** wording or style. Put these under Recommendations and never let them block approval.

    The status is Approved only when there are zero Critical and zero Important issues.

    ## Output

    ## Plan Review
    **Status:** Approved | Issues Found
    **Coverage:**
    | Spec requirement | Task(s) |
    **Verified against code:** [path:symbol → ok | mismatch]
    **Issues:**
    - [Critical|Important] [Task X, Step Y]: [issue] — [impact on execution] — [suggested fix]
    **Recommendations (non-blocking):**
    - [...]
```

**After review:** fix Critical/Important issues, then re-dispatch, up to 2 rounds total. Report anything still open to the user alongside the plan.
