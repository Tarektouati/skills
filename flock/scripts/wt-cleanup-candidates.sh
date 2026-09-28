#!/bin/sh
# wt-cleanup-candidates.sh — read-only: which linked worktrees look safe to remove, and why.
#
# Usage: wt-cleanup-candidates.sh [--cwd PATH | --workspace ID] [--base REF] [--no-pr] [--all]
#
# Emits JSON. Never removes anything: the printed `commands` are proposals to show the user.
# --all also lists linked worktrees with no removal reason (default: only candidates).
set -eu
here=$(dirname "$0")
. "$here/lib.sh"

usage() { sed -n '2,7p' "$0" | sed 's/^# \{0,1\}//'; exit "${1:-0}"; }

pass=
all=0
while [ $# -gt 0 ]; do
  case "$1" in
    --cwd|--workspace|--base) pass="$pass $1 $(printf '%s' "$2" | sed "s/'/'\\\\''/g; s/^/'/; s/\$/'/")"; shift 2 ;;
    --no-pr) pass="$pass --no-pr"; shift ;;
    --all) all=1; shift ;;
    -h|--help) usage ;;
    *) printf 'unknown argument: %s\n' "$1" >&2; usage 2 ;;
  esac
done

eval "set -- $pass"
status=$("$here/wt-status.sh" --json "$@")

printf '%s\n' "$status" | jq --argjson all "$all" '
  . as $s
  | {
      repo_root, repo_name, base, base_ref, pr_lookup,
      worktrees: [
        .worktrees[] | select(.linked)
        | . as $w
        # A merged PR only counts when it merged this exact HEAD: a reused branch name, or
        # commits added after the merge, must not look merged.
        | (.pr.state == "MERGED" and .pr.head_matches == true) as $merged
        | {
            reasons: [
              (if $merged then "pr_merged" else empty end),
              (if .pr.state == "CLOSED" then "pr_closed" else empty end),
              # Ancestry only proves the branch has nothing base lacks: it was merged (non-squash)
              # OR never got a commit. Squash merges only show up as pr_merged.
              (if .contained_in_base == true then "no_unique_commits" else empty end),
              (if .upstream_gone then "upstream_gone" else empty end),
              (if .prunable or (.exists | not) then "prunable" else empty end)
            ],
            blockers: [
              (if .exists and .dirty == null then "git_status_failed" else empty end),
              (if (.dirty // 0) > 0 then "dirty:\(.dirty)" else empty end),
              (if (.unpushed // 0) > 0 then "unpushed:\(.unpushed)" else empty end),
              (if (.ahead // 0) > 0 and .contained_in_base != true and ($merged | not) then "unmerged_commits:\(.ahead)" else empty end),
              (if any(.agents[]; .status != "idle" and .status != "done") then "agent_active" else empty end)
            ]
          } as $v
        | $w + $v
        | .safe = ((.reasons | length) > 0 and (.blockers | length) == 0)
        | .commands = (
            if (.prunable or (.exists | not)) then
              ["git -C \($s.repo_root | @sh) worktree prune"]
            else
              (if .workspace_id == null then ["herdr worktree open --cwd \($s.repo_root | @sh) --path \(.path | @sh) --no-focus  # then use the returned workspace id"] else [] end)
              + ["herdr worktree remove --workspace \(.workspace_id // "<id-from-open>")"]
            end
            + (if .branch then ["git -C \($s.repo_root | @sh) branch -d \(.branch | @sh)"] else [] end)
          )
        | select($all == 1 or (.reasons | length) > 0)
      ]
    }'
