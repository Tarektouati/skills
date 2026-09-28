#!/bin/sh
# wt-spawn.sh — create a worktree workspace, optionally start an agent in it and send a task.
#
# Usage: wt-spawn.sh --branch NAME [--cwd PATH | --workspace ID] [--base REF] [--path PATH]
#                    [--label TEXT] [--kind KIND --name AGENT [--prompt TEXT [--wait] [--timeout MS]]]
#                    [--yes] [-- <agent-args...>]
#
# DRY RUN BY DEFAULT: without --yes it only prints the plan as JSON and changes nothing.
# Show that plan to the user, get approval, then re-run the same command with --yes.
# The new workspace is always created with --no-focus.
set -eu
. "$(dirname "$0")/lib.sh"

usage() { sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; exit "${1:-0}"; }

target_flag=--cwd
target=$PWD
branch= base= wt_path= label= kind= name= prompt= wait=0 timeout= yes=0
while [ $# -gt 0 ]; do
  case "$1" in
    --cwd) target_flag=--cwd; target=$2; shift 2 ;;
    --workspace) target_flag=--workspace; target=$2; shift 2 ;;
    --branch) branch=$2; shift 2 ;;
    --base) base=$2; shift 2 ;;
    --path) wt_path=$2; shift 2 ;;
    --label) label=$2; shift 2 ;;
    --kind) kind=$2; shift 2 ;;
    --name) name=$2; shift 2 ;;
    --prompt) prompt=$2; shift 2 ;;
    --wait) wait=1; shift ;;
    --timeout) timeout=$2; shift 2 ;;
    --yes) yes=1; shift ;;
    --) shift; break ;;
    -h|--help) usage ;;
    *) printf 'unknown argument: %s\n' "$1" >&2; usage 2 ;;
  esac
done
# Remaining "$@" are native agent args.

require_herdr
[ -n "$branch" ] || die "wt-spawn: --branch is required"
if [ -n "$kind" ] || [ -n "$name" ]; then
  [ -n "$kind" ] && [ -n "$name" ] || die "wt-spawn: --kind and --name go together"
  printf '%s' "$name" | grep -Eq '^[a-z][a-z0-9_-]{0,31}$' || die "wt-spawn: agent name must match [a-z][a-z0-9_-]{0,31}"
fi
[ -z "$prompt" ] || [ -n "$kind" ] || die "wt-spawn: --prompt needs --kind/--name"
if [ "$wait" = 1 ] || [ -n "$timeout" ]; then
  [ -n "$prompt" ] || die "wt-spawn: --wait/--timeout only apply with --prompt"
fi

wt_json=$(herdr worktree list "$target_flag" "$target")
repo_root=$(printf '%s' "$wt_json" | jq -r '.result.source.repo_root')
[ -n "$base" ] || base=$(default_base "$repo_root")

existing=$(printf '%s' "$wt_json" | jq -c --arg b "$branch" '[.result.worktrees[] | select(.branch == $b)][0] // null')
if [ "$existing" != null ]; then
  printf '%s' "$existing" | jq --arg repo "$repo_root" '{
    error: "branch_already_checked_out",
    message: "This branch already has a worktree. Open it instead of creating one (ask the user first).",
    worktree: .,
    suggestion: (if .open_workspace_id then "already open as workspace \(.open_workspace_id)"
                 else "herdr worktree open --cwd \($repo | @sh) --path \(.path | @sh) --no-focus" end)
  }' >&2
  exit 1
fi

# Build the commands (as argv arrays in JSON) so the dry run shows exactly what --yes runs.
create=$(jq -n --arg flag "$target_flag" --arg target "$target" --arg branch "$branch" --arg base "$base" \
  --arg path "$wt_path" --arg label "$label" '
  ["herdr", "worktree", "create", $flag, $target, "--branch", $branch, "--base", $base]
  + (if $path != "" then ["--path", $path] else [] end)
  + (if $label != "" then ["--label", $label] else [] end)
  + ["--no-focus"]')
start=null
send=null
if [ -n "$kind" ]; then
  start=$(jq -n --arg name "$name" --arg kind "$kind" '$ARGS.positional as $extra
    | ["herdr", "agent", "start", $name, "--kind", $kind, "--pane", "<root_pane_id>"]
      + (if ($extra | length) > 0 then ["--"] + $extra else [] end)' --args -- "$@")
fi
if [ -n "$prompt" ]; then
  send=$(jq -n --arg name "$name" --arg prompt "$prompt" --argjson wait "$wait" --arg timeout "$timeout" '
    ["herdr", "agent", "prompt", $name, $prompt]
    + (if $wait == 1 then ["--wait"] else [] end)
    + (if $timeout != "" then ["--timeout", $timeout] else [] end)')
fi

plan=$(jq -n --arg repo "$repo_root" --arg branch "$branch" --arg base "$base" --arg path "$wt_path" \
  --argjson create "$create" --argjson start "$start" --argjson send "$send" '{
    repo_root: $repo, branch: $branch, base: $base,
    path: (if $path != "" then $path else "herdr default ([worktrees] directory)/<repo>/<branch-slug>" end),
    commands: ([$create, $start, $send] | map(select(. != null)))
  }')

if [ "$yes" != 1 ]; then
  printf '%s' "$plan" | jq '{dry_run: true} + . + {
    display: (.commands | map(map(if test("^[A-Za-z0-9_./:=@%+,<>-]+$") then . else @sh end) | join(" "))),
    next: "Show this plan to the user. Only after they approve, re-run the same command with --yes."
  }'
  exit 0
fi

err=$(mktemp "${TMPDIR:-/tmp}/flock-spawn.XXXXXX")
trap 'rm -f "$err"' EXIT HUP INT TERM

# run_json <argv-json>: run the command; print stdout; on failure print herdr's error to stderr.
run_json() {
  eval "set -- $(printf '%s' "$1" | jq -r 'map(@sh) | join(" ")')"
  "$@" 2>"$err"
}

fail() { # fail <step> <created-json>
  jq -n --arg step "$1" --argjson created "$2" --rawfile err "$err" '{
    ok: false, failed_step: $step, created: $created,
    error: ($err | try fromjson catch $err),
    note: "Nothing was rolled back. Report what exists and ask the user before retrying or cleaning up."
  }' >&2
  exit 1
}

out=$(run_json "$create") || fail worktree_create null
created=$(printf '%s' "$out" | jq -c '.result | {
  workspace_id: .workspace.workspace_id, pane_id: .root_pane.pane_id, path: .worktree.path, branch: .worktree.branch }')
pane_id=$(printf '%s' "$created" | jq -r .pane_id)

if [ "$start" != null ]; then
  start=$(printf '%s' "$start" | jq -c --arg p "$pane_id" 'map(if . == "<root_pane_id>" then $p else . end)')
  # On failure the agent may still be running in the pane (e.g. at a startup dialog), so report it.
  run_json "$start" >/dev/null ||
    fail agent_start "$(printf '%s' "$created" | jq -c --arg n "$name" --arg k "$kind" '. + {agent: $n, kind: $k, agent_started: false}')"
  created=$(printf '%s' "$created" | jq -c --arg n "$name" --arg k "$kind" '. + {agent: $n, kind: $k}')
fi

if [ "$send" != null ]; then
  prompt_out=$(run_json "$send") || fail agent_prompt "$created"
  created=$(printf '%s' "$created" | jq -c --argjson r "$prompt_out" '. + {prompt_result: $r.result}')
fi

printf '%s' "$created" | jq '{ok: true} + .'
