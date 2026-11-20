---
name: finishing-branch-strict
description: Use when implementation on a feature branch or worktree is complete and verified, and the work must be integrated, handed off as a PR, kept, or discarded
---

# Finishing a Branch (Strict)

**Announce:** "I'm using the finishing-branch-strict skill to complete this work."
**Precedence:** user > project `CLAUDE.md`/`AGENTS.md` > global `CLAUDE.md` > this skill.

## 1. Gate

- The final gate passed after the last edit, with its output in this session; otherwise run it now. Project or global rules may add steps; these are the minimum:
  1. Read the full diff, untracked files included: nothing unrelated, no debug output, TODOs, commented-out code, or secrets.
  2. Run the full suite of every affected module, integration tests included, plus build/lint/typecheck; quote commands and results.
  3. Self-review, one concrete reason per item: requirements and edge cases, error paths, concurrency, performance, security, tests.
  4. Non-trivial, security-, or money-related change: `code-review-strict` after the last edit, findings addressed or reported.
  5. If 1–4 changed anything, repeat from 1. Failing → report the failures and stop; offer no options.
  6. No loose ends: every gap, follow-up, or pre-existing issue named in this session (plan Scope Map "out", review findings left open, things noticed in passing) is either fixed, or has a ticket the user approved, or the user explicitly dropped it. Business decisions made in this session are on the ticket (or the user declined). Anything still loose → list it and ask before offering options.
- The branch is not `main`/`master`. Base = the branch it was cut from, as the plan or the PR names it, or the branch's creation entry (`git reflog show <branch>`, oldest line) when that names a branch other than this one or its own upstream (`Created from HEAD` or a missing reflog names nothing); unsure → ask. `git merge-base HEAD origin/<base>` is then its fork point.
- Uncommitted work: commit only if the user asked for commits; otherwise list it as "Ready to commit: <files> — <message>" and ask.

## 2. Options

Present exactly these, with no extra commentary, then wait:

```
Work on <branch> is verified. What next?
1. Open a pull request against <base>
2. Merge into <base> locally
3. Keep the branch as-is
4. Discard this work
```

Detached HEAD (externally managed worktree): offer 1 (pushed as a new branch), 3, and 4 only.

## 3. Execute the choice

**1. Pull request**
1. Rebase check: `git fetch`, `git merge-base --is-ancestor origin/<base> HEAD`. Behind → rebase onto `origin/<base>` (or merge, if the project prefers), resolve conflicts, rerun the full suite. A conflict resolution that changed code (not only took one side verbatim) is an edit: rerun the whole Gate, review included.
2. Draft the PR title (project convention, else Conventional Commits) and body, following the project's PR template if it has one, and always covering these sections (write "none" rather than omit one), so a reviewer's usual questions are answered before they ask:
   - **What and why**, with the ticket link (or why there is none).
   - **Decisions:** business decisions the ticket did not spell out, each with its ticket comment link.
   - **Scope:** the rule enforced; what is covered; what is deliberately not covered, each with its follow-up ticket link.
   - **Pre-existing issues noticed:** behavior that was already wrong before this PR, so it is not mistaken for a regression.
   - **Verification:** commands → results (unit and integration counts); CI/pipeline run links and which lanes or suites ran; whether the PR build runs the new tests, and if not, where they were run.
   - **Not verified:** what was not checked, and why.
   Re-read the body against the final code: every sentence must still be true (stale "how to test" or "unchanged" lines draw comments). Show it to the user.
3. Push and create the PR only after the user approves the draft. Rebasing an already-pushed branch needs `--force-with-lease`: ask first.
4. Keep the worktree; review comments will come back to it (`pr-comments-strict`).

**2. Merge locally**
Choosing this option is the user's explicit consent to a merge commit on `<base>`; nothing else is committed there.
1. The main checkout must have a clean working tree (`git status --porcelain` empty); otherwise stop and ask, never stash or discard the user's changes. Then: `git switch <base>`, `git pull --ff-only`, `git merge --no-ff <branch>`.
2. Merge conflict → `git merge --abort`, report the conflicting files, and ask: rebase the branch onto `<base>` (option 1, step 1, then this option again) or resolve here (an edit: rerun the Gate on the result, review included).
3. Rerun the full suite on the merged result. Failing → stop and report; do not push or delete anything.
4. Do not push `<base>` unless the user says so. Then remove the worktree (below) and `git branch -d <branch>`.

**3. Keep:** report the branch and worktree path. Touch nothing.

**4. Discard:** list what will be lost (commits `git log --oneline origin/<base>..<branch>`, uncommitted files) and require the user to type `discard`. Then remove the worktree and `git branch -D <branch>`. Never delete a remote branch without a separate explicit yes.

## Worktree cleanup

Only for options 2 and 4, and only for a worktree this work created: `git worktree remove <path>` from outside it, then `git worktree prune`. A worktree with uncommitted changes is never removed with `--force` without explicit approval.

## Report

The option taken; commands run with results; PR URL or merge SHA; what was removed; anything left for the user.
