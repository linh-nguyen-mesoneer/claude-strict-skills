---
name: code-review-strict
description: Use when a non-trivial change is finished and needs an independent review before it is reported done, merged, or put in a PR, especially when the work is uncommitted or the repo has project rules (CLAUDE.md) on invariants and verification
---

# Code Review (Strict)

Hand an independent reviewer the whole change, the requirements, and the project rules, then check what comes back before acting on it. A reviewer given a partial diff approves code it never read.

**Announce:** "I'm using the code-review-strict skill to get an independent review."
**Precedence:** user > project `CLAUDE.md`/`AGENTS.md` > global `CLAUDE.md` > this skill.
**Used for:** any independent review, including the final whole-branch review of `subagent-driven-strict` (its per-task reviews use their own template).

## 1. Verify First

Run the project's verification commands (tests, build, lint, typecheck). Keep each command with its result; the reviewer receives them as evidence. Fix failures before requesting review.

## 2. Build the Review Package

Run `scripts/review-package` (in this skill's directory) from inside the repo. It writes one file outside the repo and prints its path. It never touches the working tree, the index, or any ref.

| Reviewing | Command |
|---|---|
| Whole branch, uncommitted and untracked work included (default) | `review-package` |
| Against another base (a release branch, a SHA recorded before the work) | `review-package --base <ref>` |
| Commits only, ignoring the working tree | `review-package --base <ref> --head <ref>` |
| One subsystem | `review-package -- <pathspec>...` |

- **Exit 3 (nothing to review):** the base is wrong. Correct it; dispatch nothing.
- **Package over ~150 KB:** build one package per subsystem with pathspecs and dispatch one reviewer each. Every changed path belongs to exactly one package. Splitting hides contracts between slices, so fill each reviewer's **Other packages** slot with the other package paths; then check every cross-package contract they list against the package on the other side (or dispatch one reviewer with just those contracts and both sides' packages).

## 3. Dispatch

Fill every slot of `code-reviewer-prompt.md` (this directory).

- **Requirements:** the source requirements (ticket text with acceptance criteria and Approach, or the user's request, verbatim) **and** the plan path. The plan is the author's reading of the ticket; a reviewer given only the plan approves a plan that was too narrow.
- **Rule files:** project and user rule files (`CLAUDE.md`, `AGENTS.md`, contributing docs).
- **Model:** always `opus`, named explicitly.

## 4. Triage

Findings are claims to verify, not orders. Read the whole report before fixing anything; if any item is unclear, settle it before touching code, since items are often related. No performative agreement: state the technical verdict, then act.

Re-rate every finding against the rule files: one that breaks a mandatory rule (e.g. changed behavior with no test that can fail) is at least Important, whatever the reviewer called it. Open the `file:line` of every Critical and Important finding and check its failure scenario against the code. Also check whether a fix would break existing behavior or callers, and whether it conflicts with the requirements or project rules (that conflict goes to the user).

| Finding turns out | Action |
|---|---|
| Real | Fix it. A bug gets a failing test first. |
| Wrong | Reject it, citing the code that disproves it. |
| Plausible, untraced | Run the check the reviewer named, then decide. |
| Minor | List it for the user; leave the code alone. |
| Real but out of scope | Not a silent follow-up: the user decides fix-now or follow-up. A follow-up needs a ticket and a line in the PR description before the PR opens; a gap that only lives in the chat report comes back as a review comment. |

## 5. Re-review

If any fix changed code: rerun Step 1, rebuild the package, and dispatch again with **Previous round** filled in (each finding marked `fixed` or `rejected: <reason>`). At most 2 re-review rounds; whatever is still open after that goes to the user.

The verdict you report must come from a package built after the last edit.

## 6. Report

State: the final verdict and number of rounds; findings fixed (finding → fix → test); findings rejected, with the reason; findings still open; the reviewer's "Not verified" items; Minor and out-of-scope items as follow-ups.

## Common Mistakes

| Mistake | Instead |
|---|---|
| `HEAD~1` as the base | Script default (merge-base with the default branch), or a SHA recorded before the work began |
| Reviewing `BASE..HEAD` while the work is uncommitted | Default mode, which includes the working tree |
| Paraphrasing the requirements | Path or verbatim quote |
| Passing only the plan as requirements | Ticket or request verbatim, plus the plan |
| Calling a known gap "follow-up" in the report only | Ticket + PR description line, or fix it now |
| Applying every finding as written | Triage each against the code first |
| Skipping re-review because the fix was small | A fix is a change; re-review it |
| Omitting the model | Pass `model: opus`; an omitted model falls back to the agent definition's model, else the configured default subagent model (e.g. `CLAUDE_CODE_SUBAGENT_MODEL`), else the caller's model |
