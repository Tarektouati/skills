# Posting

Post only for PR or MR targets, and only after the user confirms (SKILL.md §5). Local and pasted diffs only print to the terminal.

Each inline comment body keeps its `**Label:**` prefix. The verdict line, and any comments that can't be anchored to a changed line, go in the review body or summary note. Write each unanchored comment there as one line, so that a later run can match it as a duplicate:

```
- `src/foo.ts:42` **Suggestion:** ...
```

## Repository

Take the repository from the target, never from the current checkout alone:

- **GitHub URL** `https://github.com/<owner>/<repo>/pull/<n>`: use `<owner>/<repo>`, and pass `-R <owner>/<repo>` to every `gh pr` command. `gh api` paths already name the repo.
- **GitLab URL** `https://<host>/<group>/<project>/-/merge_requests/<iid>`: the project is `<group>/<project>`, including any subgroups. Pass `-R https://<host>/<group>/<project>` to every `glab mr` command. `glab api` has no `-R`, so name the project in the path, URL-encoded (`group%2Fproject`), and add `--hostname <host>` when it isn't gitlab.com. Don't use `:id`: it always resolves to the current checkout.
- **A bare number, or the branch's own PR or MR**: use the current repository (`gh repo view --json nameWithOwner -q .nameWithOwner`, or the `origin` remote for GitLab).

Below, `<owner>/<repo>` and `<project>` (URL-encoded) stand for the result.

## Diff and commits

Review the PR or MR head, not whatever is checked out locally.

```bash
# GitHub
gh pr view <n> -R <owner>/<repo> --json headRefOid,baseRefName,baseRefOid,commits
gh pr diff <n> -R <owner>/<repo>

# GitLab
glab mr view <iid> -R <project-url> -F json        # diff_refs.base_sha/start_sha/head_sha
glab mr diff <iid> -R <project-url> --raw
glab api "projects/<project>/merge_requests/<iid>/commits" --paginate
```

For commit-by-commit review (large diffs), when the local checkout's `origin` is the same repository, fetch the head and use git:

```bash
git fetch origin pull/<n>/head            # GitHub
git fetch origin merge-requests/<iid>/head  # GitLab
head=$(git rev-parse FETCH_HEAD)          # must equal headRefOid / diff_refs.head_sha
base=$(git merge-base "$head" origin/<baseRefName>)
git log --reverse --format=%H "$base..$head"
git show <sha>                            # each commit
git show "$head:<path>"                   # final state of a file
```

If the repository isn't checked out locally, read the commits through the API instead:

```bash
gh api -H 'Accept: application/vnd.github.diff' "repos/<owner>/<repo>/commits/<sha>"
glab api "projects/<project>/repository/commits/<sha>/diff"
```

## Anchorable lines

Check every comment's location against the hunks of the PR or MR diff before posting. Walk each hunk `@@ -a,b +c,d @@` from `-a` and `+c`. A `+` line advances only the new counter, a `-` line advances only the old counter, and a context (` `) line advances both.

- `path:line` (new side) can be anchored when the walk reaches new line `line` on a `+` or context line.
- `path:-line` (old side, a removed line) can be anchored when the walk reaches old line `line` on a `-` line. A removed file has only `-` lines. Put the comment on the new side instead if the line is context, not removed.

Move every other comment into the body or summary note before the first post, and tell the user which ones moved. For each anchored comment, record:

- whether the line is **added** (`+`), **removed** (`-`) or **context** (` `),
- its `old_line` (removed and context lines) and `new_line` (added and context lines),
- the file's `old_path` and `new_path`. They differ for a renamed file.

## GitHub (`gh`)

### Context

```bash
gh pr view <n> -R <owner>/<repo> --json number,url,headRefOid,author,baseRefName
gh api user -q .login                     # who is reviewing
```

The PR is your own when `author.login` equals your login.

### Duplicate detection

Read both your inline comments and your review bodies:

```bash
gh api "repos/<owner>/<repo>/pulls/<n>/comments" --paginate \
  --jq '.[] | select(.user.login=="<me>") | {path, side, line, original_line, body}'
gh api "repos/<owner>/<repo>/pulls/<n>/reviews" --paginate \
  --jq '.[] | select(.user.login=="<me>") | .body'
```

- **Inline comments:** an existing comment matches on line when its `side` matches (`LEFT` for a `path:-line` comment, `RIGHT` otherwise) and `line` equals the new comment's line, or, if `line` is `null` (the comment is outdated), when `original_line` does.
- **Review bodies:** parse the `` - `path:line` **Label:** ... `` lines written there.

Skip a new comment when an existing one by you has the same path, the same line, the same `**Label:**` prefix, and similar text (same point, maybe reworded). List the skipped ones to the user. There's no other state tracking.

### Review event

Check these in order and take the first that matches:

1. Any Crucial or Important → `REQUEST_CHANGES`, or `COMMENT` on your own PR (GitHub rejects `REQUEST_CHANGES` there).
2. Questions still open → `COMMENT`.
3. Only Suggestion, Hint or Remark, or no comments at all → `APPROVE`.

"Open Questions" means the comments being posted include at least one Question. They only turn an approval into `COMMENT`. They never weaken a request for changes, because the article's Crucial means "This code must not be merged".

### Approval refused

Always try `APPROVE` when rule 3 matches, even on your own PR. If GitHub refuses it (your own PR, or a rule that blocks your approval), nothing was posted. Send the same review again with `"event": "COMMENT"`, and add this line to the body after the verdict:

```
Approval wasn't possible (<reason from the API error>). LGTM: no blocking issues found.
```

Tell the user that the approval was refused and why. Treat this as the one expected refusal. Any other error still follows the "don't retry blindly" rule below.

### Post one review

Write the payload to a file in the scratchpad, then:

```bash
gh api "repos/<owner>/<repo>/pulls/<n>/reviews" -X POST --input review.json
```

```json
{
  "commit_id": "<headRefOid>",
  "event": "REQUEST_CHANGES",
  "body": "Changes expected (2 Important)\n\n- `src/bar.ts:7` **Suggestion:** ... (unanchored comments go here)",
  "comments": [
    { "path": "src/foo.ts", "line": 42, "side": "RIGHT", "body": "**Important:** ..." },
    { "path": "src/foo.ts", "start_line": 50, "line": 54, "side": "RIGHT", "body": "**Suggestion:** ..." },
    { "path": "src/foo.ts", "line": 40, "side": "LEFT", "body": "**Important:** ..." }
  ]
}
```

- `path` is the file's path in the PR's head version, even for a `LEFT` comment on a renamed file.
- `side: "RIGHT"` with `line` from the PR's head version is for `path:line` (added and context lines).
- `side: "LEFT"` with `line` from the base version is for `path:-line` (removed lines). The third comment above is `src/foo.ts:-40`.
- Every `line` (and `start_line`) must have passed the anchorable-lines check above.
- If the API still returns an error, don't retry blindly. Show the error to the user, say nothing was posted, and ask how to proceed.

## GitLab (`glab`)

### Context

```bash
glab mr view <iid> -R <project-url> -F json        # author, diff_refs, web_url
glab api user | jq -r .username                    # who is reviewing
glab api "projects/<project>/merge_requests/<iid>/approvals" \
  | jq -r '.approved_by[].user.username'           # has the user already approved?
```

Read `diff_refs.base_sha`, `start_sha` and `head_sha` from the MR.

### Duplicate detection

```bash
glab api "projects/<project>/merge_requests/<iid>/discussions" --paginate \
  | jq '.[].notes[] | select(.author.username=="<me>") | {new_path: .position.new_path, new_line: .position.new_line, old_path: .position.old_path, old_line: .position.old_line, body}'
```

- **Notes with a position:** a note with a `new_line` matches a `path:line` comment on `new_path` and `new_line`. A note with only an `old_line` matches a `path:-line` comment on `old_path` and `old_line`.
- **Notes without one** (summary notes): parse the `` - `path:line` **Label:** ... `` lines in their `body`.

Then use the same rule as on GitHub: same path, same line, same label and similar text means skip it and list it.

### Inline comment

Take `old_path`, `new_path` and each line's kind from the MR diff. The per-file list carries both paths and the hunk text:

```bash
glab api "projects/<project>/merge_requests/<iid>/diffs" --paginate \
  | jq '.[] | {old_path, new_path, renamed_file, diff}'
```

Use the anchorable-lines walk above on each file's `diff`.

One call per comment. `glab api` doesn't turn `position[...]` field names into a nested object on a POST, so send a JSON body with `--input`. Write the payload to a file in the scratchpad:

```json
{
  "body": "**Important:** ...",
  "position": {
    "position_type": "text",
    "base_sha": "<base_sha>",
    "start_sha": "<start_sha>",
    "head_sha": "<head_sha>",
    "old_path": "src/old_name.ts",
    "new_path": "src/foo.ts",
    "old_line": 40,
    "new_line": 42
  }
}
```

- **Added line:** send `new_line` only and leave out `old_line`.
- **Removed line** (`path:-line`): send `old_line` only and leave out `new_line`.
- **Context (unchanged) line:** send both `old_line` and `new_line`. GitLab rejects a context line that has only `new_line`.
- Always send the file's real `old_path`. For a file that wasn't renamed, it equals `new_path`.

```bash
glab api "projects/<project>/merge_requests/<iid>/discussions" -X POST \
  -H 'Content-Type: application/json' --input comment.json
```

Check that the created note has a `position`. If the API rejects the position, or returns a note without one, move that comment into the summary note.

### Summary note and approval

```bash
glab mr note create <iid> -R <project-url> -m "<verdict line + unanchored comments>" --resolvable=false
```

`--resolvable=false` keeps the summary note from blocking merge when the project requires all threads to be resolved. (`glab mr note <iid> -m` is deprecated.)

This matches the GitHub event: Crucial or Important rules out approval, and open Questions hold back an otherwise approving review. Post in this order: inline comments, then the approval (if any), then the summary note. That way the note can report the outcome of the approval.

| Verdict | Action |
|---|---|
| `OK to merge`, no Questions being posted (including no comments at all) | `glab mr approve <iid> -R <project-url>` |
| `OK to merge` with Questions being posted | Post the comments and the summary note. Don't approve. |
| `Changes expected` or `Blocks merge` | Post the comments and the summary note. Don't approve. If the user already approved, offer `glab mr revoke <iid> -R <project-url>` and wait for them to confirm. |

If `glab mr approve` is refused (your own MR, or project approval rules), add this line to the summary note after the verdict, and tell the user:

```
Approval wasn't possible (<reason from the error>). LGTM: no blocking issues found.
```

When there are no comments at all, that note is the only thing posted.
