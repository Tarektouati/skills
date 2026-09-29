# flock

A Herdr skill that also manages git worktrees. It's a superset of Herdr's built-in `herdr` skill.

- `SKILL.md`: the entry point. Preflight, the **confirmation gate**, core Herdr rules, and the worktree workflows.
- `references/worktrees.md`: detailed spawn / status / cleanup / sync / hand-back flows, and Herdr's worktree JSON shapes.
- `references/herdr-core.md`: a snapshot of `herdr --skill` (herdr 0.9.1).
- `scripts/`: POSIX sh + jq. Requires `herdr`, `jq`, `git`; `gh` is optional, for PR info.
  - `wt-status.sh`: read-only table or JSON of the worktrees, their workspaces, agents, dirty and ahead/behind counts, and PRs.
  - `wt-cleanup-candidates.sh`: read-only. For each linked worktree: reasons to remove it, blockers, and proposed commands.
  - `wt-spawn.sh`: runs `worktree create`, then `agent start`, then `agent prompt`. It's a **dry run unless you pass `--yes`**.

## Install

With the [skills.sh](https://skills.sh/) CLI:

```bash
npx skills add Tarektouati/skills@flock
```

Add `-g` to install globally (user-level) instead of into the current project. It needs `herdr`, `jq` and `git` on your `PATH`, and `gh` if you want PR info.

## Refresh the upstream snapshot

After upgrading herdr:

```bash
{ printf '<!-- Snapshot of `herdr --skill` (herdr %s), frontmatter stripped. -->\n' "$(herdr --version | awk '{print $2}')"
  herdr --skill | awk 'f>=2{print} /^---$/{f++}'; } > references/herdr-core.md
```

Then diff it against `SKILL.md` §2 for rule changes.

## Prompt examples

Start prompts with `flock:` (or `/flock`) so this skill is used rather than the built-in `herdr` skill. "this repo" means the repo of the pane you're in; name another repo or path to target it instead.

### Spawn an agent in a new worktree
```
flock: create a worktree for feat/csv-export and spawn claude code into it to add CSV export to the stats page
```
Claude shows the dry-run plan (branch, base, path, agent name, task text) and waits for your OK before running it. When the new agent stops at Claude Code's "trust this folder?" dialog, Claude shows it to you and asks before answering.

To skip the follow-up questions, give the details up front:
```
flock: spawn claude (name: csv) in a new worktree feat/csv-export off main, task: "add CSV export to the stats page, with tests". Don't wait for it to finish.
```

### Several agents at once
```
flock: in this repo, spawn 3 worktrees with claude code:
- fix/year-filter → fix the spurious year filter in chat
- feat/dark-mode → add a dark mode toggle
- chore/deps → bump vitest and fix any breakage
```
Claude shows all three plans and lets you pick which ones to run.

### Check on them
```
flock: status of my worktrees in this repo
flock: which agents are blocked or done?
```

### Get results back
```
flock: what did the csv agent do? compare its answer with the actual diff
flock: tell the csv agent to also handle empty datasets
```

### Sync and PRs
```
flock: rebase feat/csv-export on main
flock: push feat/csv-export and open a PR, let the agent draft the description
```

### Clean up
```
flock: clean up my merged worktrees in this repo
flock: remove the chore/deps worktree and its branch
```
Claude lists the candidates with what's blocking each one (uncommitted files, unpushed commits, an active agent). Nothing is deleted until you approve each one.

### Tips
- If you don't name an agent kind, Claude asks for one. Say "claude code" or "codex" to skip that question.
- To pass options to the agent, add something like "run claude with `--model sonnet`".
- If you want plain "herdr …" prompts to use this skill too, remove the built-in link (`rm ~/.claude/skills/herdr`). flock covers everything it did, and `references/herdr-core.md` holds the newer upstream guide.
