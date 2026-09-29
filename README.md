# skills

Personal agent skills. Each top-level folder is one skill (`<name>/SKILL.md`).

| Skill | What it does |
|---|---|
| [`flock`](flock/) | Herdr control plus git worktree management (spawn, status, cleanup, sync, hand-back), with a confirmation step before any change. See [prompt examples](flock/README.md#prompt-examples). |
| [`keep-digging`](keep-digging/) | Learn unfamiliar code or systems fast by asking "why" layer after layer until you hit bedrock (Tibo Sottiaux's five-whys learning mode). See [prompt examples](keep-digging/README.md#prompt-examples). |

## Install

With the [skills.sh](https://skills.sh/) CLI:

```bash
# all skills
npx skills add Tarektouati/skills

# a single skill
npx skills add Tarektouati/skills@keep-digging
```

Add `-g` to install globally (user-level) instead of into the current project.
