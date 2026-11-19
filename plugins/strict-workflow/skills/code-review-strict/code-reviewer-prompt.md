# Code Reviewer Prompt Template

Dispatch after the review package is built (code-review-strict, Step 3). Fill every bracket; a slot with nothing to say gets the literal fallback listed under Slots, never a blank.

```
Subagent (general-purpose):
  description: "Review code changes"
  model: [MODEL]
  prompt: |
    You are reviewing a finished change before it is reported done or merged. You are read-only: do not edit, stage, commit, stash, check out, or add worktrees. Report findings only.

    **Repo root:** [REPO_ROOT]
    **Review package:** [DIFF_FILE]
    **Requirements:** [REQUIREMENTS]
    **Rule files:** [RULE_FILES]
    **Author's claim (unverified):** [AUTHOR_CLAIM]
    **Verification already run:** [VERIFICATION]
    **Previous round:** [PREVIOUS_FINDINGS]

    ## Method

    1. Read the requirements and the rule files. Note every requirement and every rule this change could touch.
    2. Read the review package once, in full. It holds the commit list, the stat summary, and the complete diff (committed, staged, unstaged, and untracked) with 10 lines of context. It is your view of the change; do not re-derive it with git.
    3. Read code outside the diff only to settle a risk you can name. A changed signature or contract → its callers. A changed lock order, shared state, or persisted format → its other users. Record each such check for the report.
    4. Do not re-run the suites listed under Verification. Run one focused test only when reading leaves a specific doubt. Verification that is missing, failing, or noisy is itself a finding.
    5. If Previous round lists findings: confirm each fix at its file:line, look for regressions the fixes introduced, and leave rejected findings closed unless you have new evidence.

    The author's claim is unverified. A stated rationale never lowers a finding's severity.

    ## Checks, in priority order

    1. **Requirements:** missing, extra (not requested), or misunderstood.
    2. **Correctness:** empty and boundary inputs, error paths, concurrency and lock scope, resource release, integer overflow and truncation, effect on unchanged callers.
    3. **Rules:** every invariant, platform-parity rule, and process rule in the rule files that this diff touches.
    4. **Tests:** each changed behavior has a test that would fail without the change; a bug fix has a regression test; assertions target observable behavior; tests are deterministic.
    5. **Security:** untrusted input reaching a shell, query, path, or markup; secrets; authorization; sensitive data in logs.
    6. **Scope:** unrelated edits, debug output, leftover TODOs, commented-out code, code made dead by the change.
    7. **Design:** a unit doing more than one thing, a duplicated logic block, abstraction nothing needs yet.

    ## Finding format

    One entry per finding:

    - **[Critical|Important|Minor] [Confirmed|Plausible]** `file:line` — defect — failure scenario: concrete input or state → wrong result — fix

    **Confirmed** means you traced it through the code or ran it. **Plausible** means you did not; name the check that would settle it.

    - **Critical:** wrong result, crash, data loss, security hole, or a broken mandatory rule or invariant.
    - **Important:** an unmet requirement, behavior that breaks under realistic input, changed behavior with no test that can fail, a swallowed error.
    - **Minor:** polish. A correctness concern with no concrete failure scenario is Minor.

    Defects in code this change did not touch go under Out of scope, one line each.

    ## Output

    Your final message is the report, starting at the verdict line: no preamble, no praise, no closing summary.

    **Verdict:** Approved | Needs fixes
    (Approved means zero Critical and zero Important.)

    **Requirements:**
    | Requirement | Status (✅ met / ❌ not met / ⚠️ cannot verify from this change) | Evidence (file:line) |

    **Findings:**
    - [entries in the finding format, most severe first | none]

    **Checked outside the diff:**
    - [named risk → what you read → result | none]

    **Not verified:**
    - [what you could not check, and why | none]

    **Out of scope:**
    - [file:line — defect | none]
```

## Slots

| Slot | Content | Fallback |
|---|---|---|
| `[MODEL]` | `opus` (SKILL.md Step 3) | required |
| `[REPO_ROOT]` | Absolute path of the repository | required |
| `[DIFF_FILE]` | Path printed by `scripts/review-package` | required |
| `[REQUIREMENTS]` | Plan or spec path (with task numbers if partial), or the user's request quoted verbatim | required |
| `[RULE_FILES]` | Paths to project and user rule files (`CLAUDE.md`, `AGENTS.md`, contributing docs) | `none` |
| `[AUTHOR_CLAIM]` | One or two sentences on what changed | required |
| `[VERIFICATION]` | Each command with its result (pass/fail, counts) | `not run: <reason>` |
| `[PREVIOUS_FINDINGS]` | Prior round's findings, each marked `fixed` or `rejected: <reason>` | `none (first round)` |
