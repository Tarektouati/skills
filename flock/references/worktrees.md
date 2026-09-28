# Worktree flows (detail)

Read this when you run any worktree workflow. Every state-changing step below goes through the
confirmation gate in `SKILL.md`: show the exact command, wait for approval, then run it.

## Herdr worktree model

- A Herdr worktree is a `git worktree` plus a workspace that is open on it. The CLI:
  ```
  herdr worktree list   [--workspace ID | --cwd PATH]
  herdr worktree create [--workspace ID | --cwd PATH] [--branch NAME] [--base REF] [--path PATH] [--label TEXT] [--no-focus]
  herdr worktree open   [--workspace ID | --cwd PATH] (--path PATH | --branch NAME) [--label TEXT] [--no-focus]
  herdr worktree remove --workspace ID [--force]
  ```
- The default checkout path is `<[worktrees] directory>/<repo>/<branch-slug>`. The directory setting defaults to `~/.herdr/worktrees`; check `herdr --default-config`, or the user's `config.toml`, for the value.
- **`worktree list`** returns:
  - `.result.source{repo_root, repo_name, source_workspace_id}`.
  - `.result.worktrees[]{branch, path, is_linked_worktree, is_prunable, is_detached, open_workspace_id}`.
  - The primary checkout has `is_linked_worktree: false`.
- **`worktree create`** returns:
  - `.result.workspace.workspace_id`.
  - `.result.root_pane.pane_id`: start the agent here.
  - `.result.tab.tab_id`.
  - `.result.worktree{branch, path, open_workspace_id}`.
- **`worktree create --cwd <repo>`** also opens the primary checkout as a workspace if it isn't already open. Tell the user when that happens, and count that workspace as one you created.
- **`worktree remove --workspace ID`**:
  - It deletes the checkout and closes its workspace. It **keeps the branch**; deleting the branch is a separate step that needs its own confirmation.
  - It refuses dirty trees with `dirty_worktree_requires_force`. That error is a stop sign. Tell the user what is dirty (`git -C <path> status --short`). Don't retry with `--force` unless they explicitly approve losing those changes.
  - It needs the worktree to be open. For a closed worktree, run `worktree open --path … --no-focus` first; that is a state change too, so confirm it as part of the same batch.
- `workspace list` includes `.worktree{checkout_path, is_linked_worktree, repo_root}` for workspaces that are worktrees, so you can find a worktree's workspace without guessing.

## Spawn: worktree + agent + task

1. Establish the inputs: repo (`--cwd`), branch, base, agent kind, agent name, and the task text.
   - **Branch**: follow the repo's convention; check `git branch -a`, falling back to `feat/…` / `fix/…`.
   - **Base**: the repo's default branch, unless the user says otherwise.
   - **Kind**: the one the user named. If they didn't name one, ask.
   - **Name**: short and unique, matching `[a-z][a-z0-9_-]{0,31}`, e.g. `llm-o11y`.
2. Dry run: `scripts/wt-spawn.sh --cwd <repo> --branch <b> [--base <ref>] --kind <k> --name <n> [--prompt "<task>"] [--wait --timeout <ms>] [-- <agent args>]`.
   The script prints the plan, with `display[]` holding the exact commands. It exits 1 with `branch_already_checked_out` if the branch already has a worktree; in that case offer `worktree open` or reusing the existing workspace instead.
3. Show `display[]` to the user and ask for approval.
4. On approval, re-run the identical command with `--yes`. It prints `{ok, workspace_id, pane_id, path, branch, agent, kind}`.
5. **Failures**: the script never rolls back. It prints `{ok:false, failed_step, created, error}`. When `agent_start` fails, `created` includes `agent` and `kind` with `agent_started: false`: the agent may still be running in the pane.
   - `agent_start` failing with `agent_not_ready` usually means the agent is showing a startup dialog. For Claude Code in a new path, that's the "trust this folder" check. Run `herdr agent read <name> --source visible` and show the user the dialog. **Don't answer it yourself**: trusting a folder, or approving a tool, is the user's call. Only if they tell you to answer it: `herdr agent send-keys <name> <keys>`, then `herdr agent wait <name>`, then send the prompt with `herdr agent prompt` (after confirming that too).
   - Whatever the failure, list what already exists (the `created` object) and ask what to do next: retry, keep it, or clean up.
6. Don't focus the new workspace unless the user asks for that: `herdr workspace focus <id>`.

Several spawns in one request: dry-run each one, show all the plans together, and let the user approve a subset (multi-select). Then run the approved ones one at a time.

## Status

`scripts/wt-status.sh [--cwd <repo>] [--base <ref>] [--no-pr] [--json]` is read-only, so run it freely.

- **The table**: for each worktree, it shows the branch (the primary checkout is marked), the workspace, its agents as `name:status`, the dirty file count, `+ahead/-behind` vs `origin/<base>` (or the local base), upstream plus unpushed count (`gone` if the tracked upstream was deleted), the PR number and state, and the path, marked if it's missing or prunable.
- **`--json`** gives the same data as objects: `worktrees[]{branch, path, linked, head, workspace_id, agents[], dirty, ahead, behind, upstream, upstream_gone, unpushed, contained_in_base, pr}`. `dirty` is `null` when git couldn't read the worktree. `pr` is `{number, state, url, title, head_oid, head_matches}`, where `head_matches` means the PR's head commit is the worktree's HEAD. PRs come from one `gh pr list` of the newest 200, so older branches show no PR.
- **PR lookup** uses `gh pr list --head <branch>`. It's `null` when `gh` fails, for example when there's no GitHub remote or the host is logged out. Pass `--no-pr` for speed.
- The ahead/behind counts are against the *last fetched* remote state. If you want fresh numbers, ask the user whether to run `git fetch`. It's harmless, but it's still network I/O on their repo.

When you report status, lead with what needs attention: blocked agents, dirty worktrees with no agent, branches far behind base, and merged PRs whose worktree is still around.

## Cleanup: merged / stale worktrees

1. Run `scripts/wt-cleanup-candidates.sh [--cwd <repo>] [--all]`. It's read-only. For each linked worktree it gives:
   - **`reasons[]`**: why the worktree might be removable.
     - `pr_merged`: the strongest signal. It also catches squash merges. It only counts when the merged PR's head is the worktree's HEAD, so a reused branch name or commits added after the merge don't qualify.
     - `pr_closed`: the PR was closed without merging. Ask; the work might still matter.
     - `no_unique_commits`: the branch has no commits that base lacks. That means it was merged normally, **or it never got a commit**. On its own it doesn't prove the work landed.
     - `upstream_gone`: the remote branch was deleted, which usually happens after merge.
     - `prunable`: git already considers the checkout stale or missing.
   - **`blockers[]`**: what would be lost or disrupted.
     - `git_status_failed`: git couldn't read the worktree, so its dirty state is unknown.
     - `dirty:N`: uncommitted files.
     - `unpushed:N`: commits that aren't on the upstream.
     - `unmerged_commits:N`: commits that aren't in base, and there's no merged PR.
     - `agent_active`: an agent in that workspace isn't `idle` or `done` (`working`, `blocked` or `unknown`).
   - **`safe`**: at least one reason and no blockers.
   - **`commands[]`**: the proposed commands, in order.
2. Show the candidates as a list: branch, reasons, blockers, and the commands. Use a **multi-select** question, so the user approves specific worktrees. Put the `safe` ones first. Mark blocked ones clearly, and never pre-select them.
3. For each approved worktree, run its commands in order. Stop at the first error and report it.
   - `herdr worktree remove --workspace <id>`: it fails on dirty trees. Handle that as described in the model section above.
   - `git -C <repo_root> branch -d <branch>`: lowercase `-d` refuses unmerged branches. After a squash merge that refusal is expected. Offer `-D` as a **separate** confirmation, and quote the PR state as evidence.
   - For `prunable` / missing checkouts: `git -C <repo_root> worktree prune`.
4. Never remove the primary checkout. Never use `workspace close --group`. Never touch worktrees whose agent is active unless the user explicitly insists, and even then read the agent's screen and warn them first.
5. Remote branch deletion (`git push origin --delete <b>`) is outward-facing. Only do it if the user asks for it specifically, with its own confirmation.

## Sync / hand-back

**Update a worktree from base**, for example rebasing onto main:

1. Check first: `git -C <path> status --porcelain` must be empty, and no agent in that workspace may be `working`. If an agent is idle there, tell the user that the rebase will change files under it.
2. `git -C <path> fetch origin`. It's read-only for the working tree, so you can run it after the user agrees to the sync.
3. Propose the command, `git -C <path> rebase origin/<base>` (or `merge`, if the repo or the user prefers merges), and confirm.
4. On conflict, **stop**. Show `git -C <path> status --short` and the conflicting files. Offer three options: resolve (for that, use the `resolving-merge-conflicts` skill if it's available), `git -C <path> rebase --abort`, or leave it for the user. Each is its own confirmation.
5. After a rebase, the branch needs a force-push if it was already pushed. That's outward-facing and history-rewriting, so it needs a separate confirmation. Use `--force-with-lease`, never `--force`.

**Collect an agent's results** back into the calling pane:

- `herdr agent get <name>`: is it `idle` or `done`? If it's `working`, ask whether to wait: `herdr agent wait <name> --timeout <ms>`.
- `herdr agent read <name> --source recent-unwrapped --lines 200`: the agent's final answer.
- `git -C <path> log --oneline origin/<base>..HEAD`, `git -C <path> diff --stat origin/<base>...HEAD`, and `git -C <path> status --short`: what actually changed.
- Summarize for the user: the agent's claim, compared with the actual diff, plus anything left uncommitted.

**Open a PR**:

1. Propose `git -C <path> push -u origin <branch>` and `gh pr create --head <branch> --base <base> --title … --body …`. Show the title and body.
2. Confirm. Pushing and creating the PR are outward-facing, and each approval covers only what you showed.
3. Report the PR URL.

Optionally, ask the worktree's agent to write the PR description first (`agent prompt`, which needs confirmation), then show its text to the user before creating the PR.

## Troubleshooting

- `herdr worktree …` fails asking for repository trust: Herdr needs per-request Git trust for this repo. Explain that, and only add `--trust-repository` after the user confirms they trust the repo.
- `workspace_group_close_required`: you tried to close a primary workspace that has linked worktrees. Don't add `--group`. Remove the linked worktrees individually, with confirmation, or leave everything as it is.
- Missing path, but git still lists it: `git worktree prune`, with confirmation. `herdr worktree list` shows it as `is_prunable`.
- Version skew: check `herdr status`. If a flag is missing, check `herdr worktree` help on the installed binary. Don't upgrade or restart the server.
