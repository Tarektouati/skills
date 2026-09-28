# shellcheck shell=sh
# Shared helpers for flock scripts. Source, don't execute.

die() {
  printf '%s\n' "$*" >&2
  exit 1
}

need() {
  for _bin in "$@"; do
    command -v "$_bin" >/dev/null 2>&1 || die "flock: missing required command: $_bin"
  done
}

require_herdr() {
  [ "${HERDR_ENV:-}" = 1 ] || die "flock: not running inside a Herdr pane (HERDR_ENV != 1)"
  need herdr jq git
}

# default_base <repo_root>: origin/HEAD's branch, else main, else master, else current branch.
default_base() {
  _ref=$(git -C "$1" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null) && {
    printf '%s\n' "${_ref#origin/}"
    return
  }
  for _b in main master; do
    git -C "$1" show-ref --verify --quiet "refs/heads/$_b" && {
      printf '%s\n' "$_b"
      return
    }
  done
  git -C "$1" branch --show-current
}

# gh_ready: true when gh is installed. Auth is per-host (gh auth status fails if ANY host is
# logged out), so callers treat each failed gh call as "no PR info" instead of pre-checking.
gh_ready() {
  command -v gh >/dev/null 2>&1
}
