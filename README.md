# strict-skills

Claude Code plugin `strict-workflow`: plan → execute → review → finish.

| Skill | Use |
|---|---|
| `writing-plans-strict` | Spec → TDD plan in `docs/plans/`, blocked on open questions |
| `executing-plans-strict` | Execute a plan inline with batch checkpoints |
| `subagent-driven-strict` | Execute a plan with one implementer subagent per task + per-task review |
| `code-review-strict` | Independent whole-branch review (opus) with triage |
| `finishing-branch-strict` | Final gate, then PR / merge / keep / discard |

## Install

```
/plugin marketplace add linh-nguyen-mesoneer/claude-strict-skills
/plugin install strict-workflow@strict-skills
```

## Notes

- Skills mentioned but not bundled: `pr-comments-strict` (PR review replies). The flow works without it.
- Project rules (`CLAUDE.md` / `AGENTS.md`) override the skills: verification commands, commit policy, branch naming.
- Reviewers run on `opus`; implementers on `sonnet` or `opus`, named explicitly.
- Integration tests are mandatory for tasks that touch a DB, HTTP, broker, file system, or external API.

## Maintaining

Source of truth is `~/.claude/skills`. After editing a skill: `./sync.sh`, bump `version` in `plugins/strict-workflow/.claude-plugin/plugin.json`, commit.
