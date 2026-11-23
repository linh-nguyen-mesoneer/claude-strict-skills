---
name: architecture-strict
description: Use when a task needs an architecture or design decision before any implementation plan - choosing between technologies, patterns, or designs; drawing service, module, or component boundaries; designing a data model, public API, or message contract others will build on; or reviewing a design proposal - and the decision should be recorded as an ADR
---

# Architecture Decision (Strict)

Turn a design question into one recorded decision the user accepts. This skill writes no production code; its output is an ADR that `planning-strict` plans from.

**Announce:** "I'm using the architecture-strict skill to work out and record this decision."
**Precedence:** user > project `CLAUDE.md`/`AGENTS.md` > global `CLAUDE.md` > this skill.
**Model:** this runs in the main session on Opus or a higher tier. On Sonnet or Haiku, stop before Step 1 and ask the user to switch the session's model (`/model` or the app's model picker); on a tier you cannot place relative to Opus, ask the user.

## 1. Frame

- Read the code, existing ADRs (the project's location, else `docs/adr/`), and the project rules the decision touches.
- State the problem in two or three sentences: what must be decided, why now, and what breaks or stays blocked without it.
- List the decision drivers, each measurable or checkable: load and latency targets, data volume and growth, consistency needs, cost, team skills, operability, security and compliance, deadlines, compatibility with existing clients and data.
- List the constraints that are not negotiable (stack, hosting, regulation) and where each comes from.

## 2. Requirements Gate

A driver or constraint you would have to guess, and whose value could change the choice, is a question. Always check at least these drivers: scale and load (users, requests, data volume, growth), team (size, skills), deadlines and time constraints, and hosting and operations, plus the others in Step 1. Each one that is unknown and decisive is a question. Ask them all at once: numbered, each with options, your recommendation, and which option each answer would favor. Write no options analysis on guessed drivers. Answers and delegated choices go under the ADR's Drivers marked `(confirmed)` or `(delegated)`.

## 3. Options

- At least two real options; add "keep the current design" when it is viable. A strawman added to make the favorite win is not an option.
- Rate every option against every driver in one table, with evidence: code read (`file:line`), docs (link), measurements, prior incidents. "Unknown" is a valid cell; say what would resolve it.
- A decisive unknown (the choice flips on it) → propose a timeboxed spike through `investigation-strict` before deciding. Spike code is throwaway: a scratch directory or temporary worktree, never merged.
- For each option: the migration path from today, the effect on existing data and clients, rolling-deploy compatibility, rollback, and operating cost.

## 4. Recommend

One option, the drivers that decide it, the trade-offs accepted, and the observable trigger that would make you revisit it. No recommendation possible while unknowns are open → say so and list the spikes.

## 5. Write the ADR

Save to the project's ADR location, else `docs/adr/NNNN-<slug>.md` (next free number), with Status `Proposed`:

```markdown
# NNNN. <Decision title>
- **Status:** Proposed | Accepted | Superseded by NNNN
- **Date:** YYYY-MM-DD   **Deciders:** <names | user>
## Context
## Drivers        [driver → target or evidence; (confirmed) / (delegated)]
## Constraints    [constraint → source]
## Options        [one subsection each: summary, migration, rollback, cost]
## Comparison     [options × drivers table with evidence]
## Decision       [chosen option and why]
## Consequences   [positive, negative, follow-up work, revisit trigger]
## Open Items     [spikes, questions | none]
```

## 6. Review

A decision touching persisted data, public APIs or message formats, security, or more than one service gets an independent reviewer: `general-purpose`, `model: opus`, read-only, given the ADR path, the code paths it cites, and this checklist: every driver rated for every option; evidence real (spot-check each cited `file:line`); no strawman option; migration and rollback concrete; consequences include the negatives; no business choice made without the user. Fix Critical and Important findings, max 2 rounds; report what stays open.

## 7. Decide

Show the user the recommendation and the ADR path. Only the user's yes sets Status `Accepted` (record who and the date). Then hand back to `planning-strict` to plan the work, linking the ADR. If the user rejects the recommendation, revise from Step 3. A ticket comment recording the decision (decision, reason, who decided) is drafted for the user and posted only on their yes.

## Red Flags

| Thought | Reality |
|---|---|
| "The best option is obvious" | Then the comparison is short; still write it. Obvious picks hide unstated drivers. |
| "I'll assume normal load" | A guessed driver is a question (Step 2). |
| "Let me prototype it properly" | A spike answers one question and is thrown away. |
| "The user is busy; mark it Accepted" | Only the user accepts. |
| "Plan now, ADR later" | No plan on a Proposed ADR. |
