# strict-skills

Claude Code plugin `strict-workflow`: plan → execute → review → finish.

| Skill | Use |
|---|---|
| `planning-strict` | Classify the task (feature / refactor / bug / architecture / investigation), route it, and write the TDD plan in `docs/plans/`, blocked on open questions |
| `architecture-strict` | Design decision → options vs drivers → ADR in `docs/adr/`, accepted only by the user |
| `investigation-strict` | Open question → hypotheses → evidence → report in `docs/investigations/` |
| `executing-plans-strict` | Execute a small or tightly coupled plan: this session orchestrates and audits, one implementer sub-session per batch writes the code, batch checkpoints |
| `subagent-driven-strict` | Execute a plan with one implementer subagent per task + per-task review |
| `code-review-strict` | Independent whole-branch review (opus) with triage |
| `finishing-branch-strict` | Final gate, then PR / merge / keep / discard |

## Install

```
/plugin marketplace add linh-nguyen-mesoneer/claude-strict-skills
/plugin install strict-workflow@strict-skills
```

## Notes

- Skills mentioned but not bundled: `pr-comments-strict` (PR review replies) and `bugfix-strict` (bug fixes; `planning-strict` routes bugs to it). The flow works without them.
- Project rules (`CLAUDE.md` / `AGENTS.md`) override the skills: verification commands, commit policy, branch naming.
- Reviewers run on `opus`; implementers on `sonnet` or `opus`, named explicitly.
- Integration tests are mandatory for tasks that touch a DB, HTTP, broker, file system, or external API.
- 1.2.0: `writing-plans-strict` renamed to `planning-strict` (now a router); new `architecture-strict` and `investigation-strict`; `executing-plans-strict` dispatches implementer sub-sessions (desktop app; falls back to subagents); updates to `subagent-driven-strict` and `code-review-strict`.

## Maintaining

Source of truth is `~/.claude/skills`. After editing a skill: `./sync.sh`, bump `version` in `plugins/strict-workflow/.claude-plugin/plugin.json`, commit.
