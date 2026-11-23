---
name: planning-strict
description: Use when a non-trivial engineering task needs thinking before code - a new feature (including a vague feature request), a refactor, an architecture or design decision, an investigation or open technical question, or a bug whose fix may span several steps - to classify it, route each phase to the right skill, ask the open questions, and write the implementation plan (e.g. docs/plans/*.md)
---

# Planning (Strict)

The front door for work that needs thinking before code. Classify the task, send each phase to the skill built for it, and write a TDD plan only when the input is a clear spec.

**Announce:** "I'm using the planning-strict skill to classify and plan this task."
**Precedence:** user > project `CLAUDE.md`/`AGENTS.md` > global `CLAUDE.md` > this skill > the skills and modules it routes to.
**Model:** this runs in the main session on Opus or a higher tier. On Sonnet or Haiku, stop before Step 1 and ask the user to switch the session's model (`/model` or the app's model picker); on a tier you cannot place relative to Opus, ask the user.

## 1. Classify

Read the request, then enough code to tell what kind of work it is. Pick the first row that fits. A vague feature request is still a feature: the Requirements Gate in `references/plan-core.md` turns its gaps into questions (not `development-superpowers:brainstorming`).

| Type | Signals | Route |
|---|---|---|
| Bug | Current behavior contradicts requirements, docs, tests, or established behavior; a failing test or CI run; a user or incident reporting wrong behavior, even before it is reproduced (`bugfix-strict` confirms it) | `bugfix-strict` |
| Investigation | A question, not a decided change: "why", "how does", "can we", "is it safe", "what would break"; slowness or behavior someone wants explained, with no claim that it is wrong | `investigation-strict` |
| Architecture | A choice between designs, technologies, or patterns; new service, module, or component boundaries; a data model, public API, or message contract others will build on; anything an ADR would record | `architecture-strict` |
| Refactor | Structure changes and no observable behavior changes (outputs, errors, ordering, timing others rely on, persisted data, APIs) | `references/plan-core.md` + `references/plan-refactor.md` |
| Feature | New or changed observable behavior | `references/plan-core.md` + `references/plan-feature.md` |

- Say the result in one line before acting: `Classified as <type>: <signal>. Next: <skill or module>.`
- A request that spans types becomes phases in this order: investigation → bug or architecture → plan. Name every phase in the classification line.
- A "refactor" that changes any observable behavior (a faster query that changes result order, a rename that changes an API field) is a feature, or a refactor and a feature split into separate tasks.
- Two types fit equally and the choice changes what you produce → ask the user one question with your recommendation.

## 2. Run the phase

Invoke the routed skill and follow it; this skill does not repeat its rules. For `bugfix-strict`, run it through its root-cause step, then decide here before it fixes anything. Come back here with each phase's output:

| Phase output | Next |
|---|---|
| Investigation report | Its Next Step decides: none → report and stop; a confirmed defect → `bugfix-strict` with the report's evidence; a proposed change → the user decides; once they say yes, classify it (Step 1); a design choice → `architecture-strict` |
| ADR with status Accepted by the user | It is the spec: plan it as a feature (one plan per independent subsystem), with the ADR path on the plan's **Architecture** line |
| ADR still Proposed | Stop. No plan on an unaccepted decision |
| `bugfix-strict` root cause found | The fix fits one test cycle in one module and needs no data repair → back to `bugfix-strict` to fix, sweep variants, and report. Otherwise → a feature plan: Task 1's failing test is the captured reproduction, the Scope Map includes the variants `bugfix-strict` asks you to sweep for, a data repair gets its own task, and `bugfix-strict`'s fix, variant, and data-impact steps are the plan's acceptance criteria |
| `bugfix-strict` cannot reproduce, or not a bug | Report and stop |
| Expected behavior not established by a requirement, doc, test, or documented contract (only inferred by analogy with other code) | Report it as unconfirmed and ask the user to confirm it is a bug; no fix or plan until they do |

Never start a plan from an unfinished phase: an investigation with no conclusion, a Proposed ADR, a bug with no root cause.

## 3. Plan

For a feature or refactor: read `references/plan-core.md` and the type's module in this directory, then follow both. The core holds Explore, the Requirements Gate, the header, the format, review, and handoff; the module holds the task rules for that type. A plan that mixes types applies each task's own module.

## Red Flags

| Thought | Reality |
|---|---|
| "It's obviously a feature, skip the classification line" | The line costs one sentence and lets the user catch a wrong route. |
| "I'll plan the fix while I look for the cause" | A plan before the root cause encodes a guess. `bugfix-strict` first. |
| "The user asked a question, but I can see the fix" | Answer the question (`investigation-strict`); propose the change as its next step. |
| "Two options are close; I'll pick one and plan" | That is an architecture decision. Write the ADR and get it accepted. |
| "It's a refactor, so no questions" | A refactor that changes behavior is a feature; check before calling it behavior-preserving. |
