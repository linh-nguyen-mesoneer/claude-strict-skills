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
- The branch is not `main`/`master`. Base = the branch it was cut from (`git merge-base HEAD origin/<base>`); unsure → ask.
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
1. Rebase check: `git fetch`, `git merge-base --is-ancestor origin/<base> HEAD`. Behind → rebase onto `origin/<base>` (or merge, if the project prefers), resolve conflicts, rerun the full suite.
2. Draft the PR title (Conventional Commits) and body: what and why, how it was verified (commands → results, unit and integration counts), what is unverified, follow-ups. Show it to the user.
3. Push and create the PR only after the user approves the draft. Rebasing an already-pushed branch needs `--force-with-lease`: ask first.
4. Keep the worktree; review comments will come back to it (`pr-comments-strict`).

**2. Merge locally**
1. From the main checkout: `git switch <base>`, `git pull --ff-only`, `git merge --no-ff <branch>`.
2. Rerun the full suite on the merged result. Failing → stop and report; do not push or delete anything.
3. Do not push `<base>` unless the user says so. Then remove the worktree (below) and `git branch -d <branch>`.

**3. Keep:** report the branch and worktree path. Touch nothing.

**4. Discard:** list what will be lost (commits `git log --oneline origin/<base>..<branch>`, uncommitted files) and require the user to type `discard`. Then remove the worktree and `git branch -D <branch>`. Never delete a remote branch without a separate explicit yes.

## Worktree cleanup

Only for options 2 and 4, and only for a worktree this work created: `git worktree remove <path>` from outside it, then `git worktree prune`. A worktree with uncommitted changes is never removed with `--force` without explicit approval.

## Report

The option taken; commands run with results; PR URL or merge SHA; what was removed; anything left for the user.
