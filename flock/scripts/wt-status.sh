#!/bin/sh
# wt-status.sh — read-only overview of a repo's worktrees, their Herdr workspaces and agents.
#
# Usage: wt-status.sh [--cwd PATH | --workspace ID] [--base REF] [--no-pr] [--json]
#
# Never changes anything: runs only herdr list commands, git read commands, and one gh pr list.
set -eu
. "$(dirname "$0")/lib.sh"

usage() { sed -n '2,6p' "$0" | sed 's/^# \{0,1\}//'; exit "${1:-0}"; }

target_flag=--cwd
target=$PWD
base=
want_pr=1
json=0
while [ $# -gt 0 ]; do
  case "$1" in
    --cwd) target_flag=--cwd; target=$2; shift 2 ;;
    --workspace) target_flag=--workspace; target=$2; shift 2 ;;
    --base) base=$2; shift 2 ;;
    --no-pr) want_pr=0; shift ;;
    --json) json=1; shift ;;
    -h|--help) usage ;;
    *) printf 'unknown argument: %s\n' "$1" >&2; usage 2 ;;
  esac
done

require_herdr

wt_json=$(herdr worktree list "$target_flag" "$target")
agents_json=$(herdr agent list)
repo_root=$(printf '%s' "$wt_json" | jq -r '.result.source.repo_root')
repo_name=$(printf '%s' "$wt_json" | jq -r '.result.source.repo_name')
[ -n "$base" ] || base=$(default_base "$repo_root")

# Compare against the remote-tracking base when it exists: it reflects merges done on GitHub.
base_ref=$base
git -C "$repo_root" show-ref --verify --quiet "refs/remotes/origin/$base" && base_ref="origin/$base"

pr_enabled=0
[ "$want_pr" = 1 ] && gh_ready && pr_enabled=1

# One PR lookup for the whole repo. Any gh failure (no GitHub remote, host logged out) just
# means "no PR info". Branches whose PR is older than the newest 200 get no PR info either.
prs='[]'
if [ "$pr_enabled" = 1 ]; then
  prs=$(cd "$repo_root" && gh pr list --state all --limit 200 \
    --json number,state,url,title,headRefName,headRefOid 2>/dev/null) || prs='[]'
  [ -n "$prs" ] || prs='[]'
fi

# Unit Separator, not tab: tab is IFS whitespace, so `read` would merge empty fields.
us=$(printf '\037')
rows=$(
  printf '%s' "$wt_json" |
    jq -r '.result.worktrees[] | [.path, (.branch // ""), (.open_workspace_id // ""), .is_linked_worktree, .is_prunable, .is_detached] | map(tostring) | join("\u001f")' |
    while IFS=$us read -r path branch ws linked prunable detached; do
      exists=false dirty=null ahead=null behind=null upstream=null upstream_gone=false unpushed=null
      contained=null head=
      if [ -d "$path" ]; then
        exists=true
        # dirty stays null when git can't read the worktree: unknown, not clean.
        if st=$(git -C "$path" status --porcelain 2>/dev/null); then
          dirty=$(printf '%s' "$st" | grep -c . || true)
        fi
        head=$(git -C "$path" rev-parse --verify --quiet HEAD 2>/dev/null) || head=
        if git -C "$path" rev-parse --verify --quiet "$base_ref" >/dev/null 2>&1; then
          set -- $(git -C "$path" rev-list --left-right --count "$base_ref...HEAD")
          behind=$1 ahead=$2
          if git -C "$path" merge-base --is-ancestor HEAD "$base_ref"; then contained=true; else contained=false; fi
        fi
        if [ -n "$branch" ] && [ "$detached" = false ]; then
          if u=$(git -C "$path" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null); then
            upstream=$(jq -n --arg u "$u" '$u')
            unpushed=$(git -C "$path" rev-list --count '@{u}..HEAD')
          elif git -C "$repo_root" config --get "branch.$branch.merge" >/dev/null; then
            upstream_gone=true
          fi
        fi
      fi
      pr=null
      if [ -n "$branch" ] && [ "$linked" = true ]; then
        # Prefer the PR whose head is this worktree's HEAD; else the newest one for the branch.
        pr=$(printf '%s' "$prs" | jq -c --arg b "$branch" --arg head "$head" '
          [.[] | select(.headRefName == $b)]
          | (map(select(.headRefOid == $head))[0] // .[0])
          | if . == null then null else
              {number, state, url, title, head_oid: .headRefOid, head_matches: ($head != "" and .headRefOid == $head)}
            end' 2>/dev/null) || pr=null
        [ -n "$pr" ] || pr=null
      fi
      printf '%s' "$agents_json" | jq -c \
        --arg path "$path" --arg branch "$branch" --arg ws "$ws" --arg head "$head" \
        --argjson linked "$linked" --argjson prunable "$prunable" --argjson detached "$detached" \
        --argjson exists "$exists" --argjson dirty "$dirty" --argjson ahead "$ahead" --argjson behind "$behind" \
        --argjson upstream "$upstream" --argjson upstream_gone "$upstream_gone" --argjson unpushed "$unpushed" \
        --argjson contained "$contained" --argjson pr "$pr" '
        {
          branch: (if $branch == "" then null else $branch end),
          path: $path,
          linked: $linked, prunable: $prunable, detached: $detached, exists: $exists,
          head: (if $head == "" then null else $head end),
          workspace_id: (if $ws == "" then null else $ws end),
          agents: [.result.agents[] | select($ws != "" and .workspace_id == $ws)
                   | {name: (.name // null), kind: .agent, status: .agent_status, pane_id}],
          dirty: $dirty, ahead: $ahead, behind: $behind,
          upstream: $upstream, upstream_gone: $upstream_gone, unpushed: $unpushed,
          contained_in_base: $contained,
          pr: $pr
        }'
    done
)

report=$(printf '%s\n' "$rows" | jq -s \
  --arg repo_root "$repo_root" --arg repo_name "$repo_name" --arg base "$base" --arg base_ref "$base_ref" \
  --argjson pr_enabled "$pr_enabled" \
  '{repo_root: $repo_root, repo_name: $repo_name, base: $base, base_ref: $base_ref, pr_lookup: ($pr_enabled == 1), worktrees: .}')

if [ "$json" = 1 ]; then
  printf '%s\n' "$report"
  exit 0
fi

printf '%s\n' "$report" | jq -r '"repo: \(.repo_name)  (\(.repo_root))  base: \(.base_ref)\(if .pr_lookup then "" else "  [PR lookup off]" end)\n"'
printf '%s\n' "$report" | jq -r '
  (["BRANCH", "WS", "AGENTS", "DIRTY", "+AHEAD/-BEHIND", "UPSTREAM", "PR", "PATH"] | @tsv),
  (.worktrees[] | [
     ((.branch // "(detached)") + (if .linked then "" else " *primary" end)),
     (.workspace_id // "-"),
     (if (.agents | length) == 0 then "-" else (.agents | map("\(.name // .kind):\(.status)") | join(",")) end),
     (.dirty // "?" | tostring),
     (if .ahead == null then "?" else "+\(.ahead)/-\(.behind)" end),
     (if .upstream_gone then "gone" elif .upstream == null then "-" else "\(.upstream) (\(.unpushed) unpushed)" end),
     (if .pr == null then "-" else "#\(.pr.number) \(.pr.state)" end),
     (.path + (if .exists then "" else " (missing)" end) + (if .prunable then " (prunable)" else "" end))
   ] | @tsv)' | column -t -s "$(printf '\t')"
