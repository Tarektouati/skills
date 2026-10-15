# Posting

Post only for PR or MR targets, and only after the user confirms (SKILL.md §5). Local and pasted diffs only print to the terminal.

Each inline comment body keeps its `**Label:**` prefix. The verdict line, and any comments that can't be anchored to a changed line, go in the review body or summary note.

## GitHub (`gh`)

### Context

```bash
gh pr view <n> --json number,url,headRefOid,author,baseRefName -q '.'
gh api user -q .login                     # who is reviewing
gh repo view --json nameWithOwner -q .nameWithOwner
```

The PR is your own when `author.login` equals your login.

### Duplicate detection

```bash
gh api "repos/<owner>/<repo>/pulls/<n>/comments" --paginate \
  --jq '.[] | select(.user.login=="<me>") | {path, line, body}'
```

Skip a new comment when an existing one by you has the same `path`, the same `line`, the same `**Label:**` prefix, and similar text (same point, maybe reworded). List the skipped ones to the user. There's no other state tracking.

### Review event

Check these in order and take the first that matches:

1. Questions still open, or the user is reviewing their own PR → `COMMENT`. GitHub rejects `APPROVE` and `REQUEST_CHANGES` on your own PR.
2. Any Crucial or Important → `REQUEST_CHANGES`.
3. Only Suggestion, Hint or Remark → `APPROVE`.

"Open Questions" means the comments being posted include at least one Question.

### Post one review

Write the payload to a file in the scratchpad, then:

```bash
gh api "repos/<owner>/<repo>/pulls/<n>/reviews" -X POST --input review.json
```

```json
{
  "commit_id": "<headRefOid>",
  "event": "REQUEST_CHANGES",
  "body": "Changes expected (2 Important)\n\n**Suggestion:** ... (unanchored comments go here)",
  "comments": [
    { "path": "src/foo.ts", "line": 42, "side": "RIGHT", "body": "**Important:** ..." },
    { "path": "src/foo.ts", "start_line": 50, "line": 54, "side": "RIGHT", "body": "**Suggestion:** ..." }
  ]
}
```

- `line` is the line number in the PR's head version of the file, and it must be inside a diff hunk. Otherwise the API returns 422. Move a comment that can't be anchored into `body`.
- If the review fails with 422, find the comment that caused it, move it into `body`, and retry once. Tell the user that you did.

## GitLab (`glab`)

`glab api` expands `:id` to the current project.

### Context

```bash
glab mr view <iid> -F json                # author, diff_refs, web_url
glab api user | jq -r .username           # who is reviewing
glab api "projects/:id/merge_requests/<iid>/approvals" \
  | jq -r '.approved_by[].user.username'  # has the user already approved?
```

Read `diff_refs.base_sha`, `start_sha` and `head_sha` from the MR.

### Duplicate detection

```bash
glab api "projects/:id/merge_requests/<iid>/discussions" --paginate \
  | jq '.[].notes[] | select(.author.username=="<me>") | {path: .position.new_path, line: .position.new_line, body}'
```

Use the same rule as on GitHub: same path, same line, same label and similar text means skip it and list it.

### Inline comment

One call per comment:

```bash
glab api "projects/:id/merge_requests/<iid>/discussions" -X POST \
  -f body='**Important:** ...' \
  -f 'position[position_type]=text' \
  -f 'position[base_sha]=<base_sha>' \
  -f 'position[start_sha]=<start_sha>' \
  -f 'position[head_sha]=<head_sha>' \
  -f 'position[new_path]=src/foo.ts' \
  -f 'position[old_path]=src/foo.ts' \
  -F 'position[new_line]=42'
```

If a position is rejected, move that comment into the summary note.

### Summary note and approval

```bash
glab mr note <iid> -m "<verdict line + unanchored comments>"
```

| Verdict | Action |
|---|---|
| `OK to merge` | `glab mr approve <iid>` |
| `Changes expected` or `Blocks merge` | Post the comments and the summary note. Don't approve. If the user already approved, offer `glab mr revoke <iid>` and wait for them to confirm. |
