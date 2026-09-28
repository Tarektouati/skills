---
name: flock
description: "Control Herdr (terminal multiplexer for coding agents) and manage git worktrees through it: spawn a worktree workspace with an agent and task, show a status overview of worktrees/agents/PRs, clean up merged or stale worktrees, rebase/sync a worktree, collect an agent's results, open a PR. Use when the user mentions Herdr or flock, or asks to manage worktrees or run parallel agents per branch while inside Herdr. Every state-changing action is confirmed with the user first. Requires HERDR_ENV=1."
---

# flock

`flock` manages Herdr workspaces, panes, and agents, plus the git worktrees they run in: one branch per worktree, one agent per worktree.

## 0. Preflight

```bash
test "${HERDR_ENV:-}" = 1 && herdr status
```

- If `HERDR_ENV` isn't `1`, say that you're not running inside Herdr, and stop.
- The installed binary is the authority for syntax. Run `herdr <group>` (e.g. `herdr worktree`, `herdr agent`) to print a command group's usage. Never run bare `herdr`, which opens the TUI. Never probe a mutating subcommand by leaving out its arguments: defaults execute.
- Most commands return JSON. Read IDs from the responses; never predict them.
- Scripts are in `scripts/` next to this file. Detailed flows are in `references/worktrees.md`, and the full upstream Herdr guide (panes, agents, reading output, SSH machines) is in `references/herdr-core.md`. Read the relevant reference before running a workflow.

## 1. Confirmation gate (always applies)

**Ask the user before every state-changing action, every time.** The user asking for the overall task ("clean up my worktrees") is not approval for the individual commands.

**Run freely** (read-only):
- `herdr … list|get|read|layout|current|status`, `herdr agent explain`.
- `git status|log|diff|show|branch --list|worktree list|rev-list|merge-base`, `git fetch`.
  - `git fetch` changes nothing in the working tree. Still, mention it the first time you use it in a repo.
- `gh pr list|view`.
- `scripts/wt-status.sh`, `scripts/wt-cleanup-candidates.sh`, and `scripts/wt-spawn.sh` without `--yes`, which is a dry run.

**Confirm first** (everything else, including):
- **Creating things**: `worktree create|open`, `workspace|tab create`, `pane split`, `agent start`, `wt-spawn.sh --yes`.
- **Sending input**: `agent prompt`, `agent send-keys`, `pane run|send-text|send-keys`. That includes answering another agent's approval or trust dialog.
- **Removing things**: `worktree remove`, `workspace|tab|pane close`, `git branch -d|-D`, `git worktree prune`, `git stash drop`, `git clean`.
- **Changing history or state**: `git rebase|merge|reset|checkout|switch|cherry-pick|stash|commit` in any worktree.
- **Going outward**: `git push` (any form), `gh pr create|merge|close|edit`, and remote branch deletion.
- **Anything with** `--force`, `-D`, or `--trust-repository`.

How to ask:
1. Show the **exact command(s)** and their target: repo, branch, path, workspace or pane ID. For destructive steps, also show **what would be lost**, e.g. "3 untracked files" or "2 unpushed commits".
2. Use `AskUserQuestion` if you have it; otherwise ask in plain text and **end your turn**. For batches (several worktrees, several spawns), let the user pick a subset with a multi-select.
3. An approval covers **only the commands you showed**. It doesn't carry over to later steps, retries, other worktrees, or "the same thing again later".
4. **Escalations need a new confirmation.** For example: `branch -d` fails, and you propose `-D`; `worktree remove` hits a dirty tree, and you propose `--force`; a rebase conflicts, and you propose `--abort` or a resolution.
5. If the user says no, or doesn't answer: don't run it. Report where things stand.

## 2. Herdr basics

- **IDs**
  - IDs are opaque handles: workspace `w1`, tab `w1:t1`, pane `w1:p1`.
  - Herdr injects your own context as `$HERDR_WORKSPACE_ID`, `$HERDR_TAB_ID`, and `$HERDR_PANE_ID`.
  - Use `--current` for the calling pane, or pass explicit IDs. Never rely on the UI-focused pane; it may belong to the user.
- **Focus**
  - Background work always uses `--no-focus`. Focus something (`workspace focus`, `agent focus`) only when the user asks.
- **Panes versus agents**
  - Use pane commands for shells, tests, and servers: `pane run`, `pane wait-output --match … --timeout …`, and `pane read --source recent-unwrapped`.
  - Use agent commands for recognized agents: `agent start <name> --kind <k> --pane <id>`, `agent prompt <name> "…" --wait --timeout <ms>`, `agent wait`, `agent read`, and `agent get`.
  - Agent names match `[a-z][a-z0-9_-]{0,31}`.
- **Agent states**
  - `idle` and `done` mean the agent is ready for input.
  - `blocked` means it's showing an approval or question UI. Read it, show it to the user, and let them decide.
  - `unknown` doesn't mean done.
  - A timeout or `agent_prompt_stalled` doesn't prove the prompt wasn't delivered. **Never re-send blindly.** Read the agent's screen first.
- **Sibling panes**
  - Without worktree mode, start extra agents or commands in a sibling pane: `herdr pane split --current --direction right|down --cwd "$PWD" --no-focus`.
  - Check `herdr pane layout --current` to choose the direction.
- **Never**
  - `herdr server stop`.
  - Killing the Herdr process.
  - Closing workspaces, tabs, or panes you didn't create, unless the user asks and confirms.
  - `workspace close --group`.

For anything beyond this, such as read sources, alternate-screen output, pane moves, or `--machine`, see `references/herdr-core.md`.

## 3. Worktree workflows

Use worktrees when the user asks for isolation, for parallel work on several branches, or explicitly for a worktree. Otherwise, default to a sibling pane in the current tab and cwd.

| Goal | Tool | Gate |
|---|---|---|
| **Status**: worktrees, workspaces, agents, dirty and ahead/behind, PRs | `scripts/wt-status.sh [--cwd <repo>] [--json] [--no-pr]` | free |
| **Spawn**: worktree, then an agent, then an optional task | `scripts/wt-spawn.sh --cwd <repo> --branch <b> [--base <ref>] --kind <k> --name <n> [--prompt "…" --wait --timeout <ms>] [-- <agent-args>]` | dry run first; `--yes` after approval |
| **Cleanup**: merged or stale worktrees | `scripts/wt-cleanup-candidates.sh [--cwd <repo>]`, then run the approved `commands[]` | multi-select approval per worktree |
| **Sync**: rebase or merge base into a worktree | `git -C <path> fetch`, then a confirmed `rebase origin/<base>` | confirm; stop on conflicts |
| **Hand-back**: collect results, open a PR | `agent read`, plus `git log/diff <base>...HEAD`, then a confirmed push and `gh pr create` | confirm push and PR separately |

Key rules (details in `references/worktrees.md`):
- **Spawn**
  - Always dry-run first, and show the plan's `display[]` lines.
  - A new worktree path usually makes the agent show a startup trust dialog. That surfaces as `agent_not_ready`. Show the dialog to the user; never accept it yourself.
- **Remove**
  - `herdr worktree remove` keeps the branch. Deleting the branch is a separate, confirmed step.
  - It refuses dirty trees. Treat that refusal as a stop, not as a reason to retry with `--force`.
- **Protected**
  - Never remove the primary checkout (`is_linked_worktree: false`).
  - Never touch a worktree whose agent is `working` or `blocked` without explicit consent.
- **Weak signal**
  - `no_unique_commits` alone doesn't prove the work was merged. The branch may never have had a commit. Rely on `pr_merged` as the strong signal.
- **Report back**
  - Once a workflow finishes, report what changed: IDs, paths, branches, and what's left.
  - List anything you created as a side effect. For example, `worktree create` may open the primary checkout as a new workspace.
