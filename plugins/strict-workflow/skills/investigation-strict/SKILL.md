---
name: investigation-strict
description: Use when the task is an open technical question rather than a decided change - why something is slow or behaves a certain way, how a module or flow works, whether something is feasible or safe, or what a change would affect - with no report that current behavior is wrong (that is a bug: bugfix-strict) - and the answer must be backed by evidence
---

# Investigation (Strict)

Answer a question with evidence, then stop. An investigation changes no production code, data, or shared environment; its output is a report whose last section says what to do next.

**Announce:** "I'm using the investigation-strict skill to answer this with evidence."
**Precedence:** user > project `CLAUDE.md`/`AGENTS.md` > global `CLAUDE.md` > this skill.

## 1. Frame

- The question in one sentence, and the decision it feeds (what someone will do with the answer).
- Done when: the answer that is enough (e.g. "the top cause of the latency, with numbers", "yes or no, with the conditions").
- Timebox: propose one that fits the question; at the timebox, report what you have.
- A question too vague to know when it is answered → ask the user to narrow it, with your suggested framing.

## 2. Hypotheses

List the candidate answers before digging, including the boring ones (configuration, data volume, environment, a recent change). For each, the cheapest check that could prove it wrong.

## 3. Gather evidence

- Run the checks, cheapest and most decisive first. Record each: the command or `file:line`, what it showed (trimmed output), and what it means.
- Sources: code and tests, `git log -S`/`-G` and blame for why it is this way, running the code or tests, logs, metrics, profiles, docs, issue history.
- Read-only by default: experiments run in a scratch directory, a temporary worktree, or a local copy of the data. Anything that touches a shared environment, real data, or other people (load on staging, a query on production) needs the user's yes first.
- Measure, don't guess: a performance claim carries a number and the command that produced it; a "this path is never used" claim carries the search that proves it.
- Keep observed and inferred apart in every finding.

## 4. Conclude

- Each hypothesis → confirmed, refuted, or open, with its evidence.
- The answer, with a confidence: high (reproduced or measured), medium (consistent evidence, not reproduced), low (inference).
- Not enough evidence by the timebox → "inconclusive", what is missing, and the next check.

## 5. Report

Save to the project's convention, else `docs/investigations/YYYY-MM-DD-<slug>.md`, and summarize it in chat:

```markdown
# <Question>
**Date / Asked by / Timebox used:**
## Answer        [one paragraph, with confidence]
## Context       [the decision the answer feeds]
## Hypotheses    [hypothesis → confirmed | refuted | open → evidence]
## Evidence      [command or file:line → observation → meaning]
## Not Checked   [what and why | none]
## Next Step     [none | bug → bugfix-strict | change → planning-strict | design → architecture-strict | more investigation: <check>]
```

## 6. Hand off

- A confirmed defect goes to `bugfix-strict`, carrying the reproduction and evidence; do not fix it here.
- A change worth making goes to `planning-strict` as a proposal; the user decides whether to do it.
- Something unrelated but serious turned up (a security hole, data loss) → report it at once, separately.

## Red Flags

| Thought | Reality |
|---|---|
| "I can see the fix, I'll just apply it" | The deliverable is the answer. Propose the fix as the next step. |
| "It's probably the N+1" | "Probably" is a hypothesis. Measure it. |
| "I'll quickly try it on staging" | Shared environment: ask first. |
| "No time to write the report" | The report is the deliverable; chat scrolls away. |
| "Evidence is mixed; I'll pick the likeliest" | Say inconclusive, with the next check. |
