---
name: semantic-review
description: "Review a change (PR, MR, branch, path or pasted diff) and label every finding with a semantic label from m31coding's Semantic Code Reviews: Remark, Question, Hint, Suggestion, Important or Crucial. Each label tells the author what response is expected. Prints a verdict and numbered comments, then can post them to a GitHub PR or GitLab MR after confirmation. Invoke only via /semantic-review."
disable-model-invocation: true
---

# semantic-review

Review a change and prefix every comment with one of six labels from [Semantic Code Reviews](https://www.m31coding.com/blog/semantic-reviews.html), so the author knows what response each comment expects. The label definitions and the rubric are in `references/labels.md`. The `gh` and `glab` commands are in `references/posting.md`. Read both before you start.

## 1. Resolve the target

Take the first one that applies:

1. **An explicit argument**: a PR or MR number or URL, a branch, a path, or a pasted diff. A path means that path's diff against the merge-base with the default branch, plus its uncommitted changes, not the whole file.
2. **The branch's open PR or MR**: `gh pr view --json number,url` or `glab mr view -F json`.
3. **The local branch**: the diff against the merge-base with the default branch (`git merge-base HEAD origin/<default>`), plus uncommitted changes.

For a PR or MR target, take the repository from the URL (not from the current checkout), and review the PR or MR head, not the local working tree. `references/posting.md` (Repository, and Diff and commits) has the commands.

The first output line names the target: `Reviewing PR #123 (owner/repo)`, `Reviewing feat/x vs main (merge-base abc1234) + uncommitted changes`, `Reviewing src/api/ vs main (merge-base abc1234)`, or `Reviewing pasted diff`.

## 2. Review

Run this checklist on the changed lines and on whatever those lines directly affect, such as callers, callees, and tests of changed code:

- **Correctness**: logic errors, edge cases, error handling, concurrency, off-by-one errors.
- **Security**: injection, authn and authz, secrets, unsafe input handling.
- **Tests**: new logic without tests, tests that don't actually assert the behavior.
- **Design and API**: misleading contracts, leaky abstractions, breaking changes.
- **Naming and readability**: names that mislead, code that's hard to follow.

Stay in scope. Don't review untouched code that the change doesn't affect.

**Large diffs (more than about 1,500 changed lines):**
- Review commit by commit (`git log --reverse <base>..<head>`, then `git show <sha>`) so that no file is skipped. For a PR or MR, `<head>` is the fetched PR or MR head, not local `HEAD` (see `references/posting.md`).
- A later commit may fix what an earlier one broke. Check every finding against the final state, drop any that are already fixed, and anchor each comment to lines in the final `<head>`.
- If commits aren't available (a pasted diff or a single commit), go file by file instead. Skip lockfiles, generated files and vendored files, and list what you skipped.

Do the review yourself as a single agent. Don't spawn subagents.

## 3. Label each finding

Use the rubric in `references/labels.md`. In short:

| Label | When |
|---|---|
| **Crucial** | Merging causes real harm: a reachable correctness bug, a security hole, data loss, a broken build or migration. |
| **Important** | A concrete defect or maintainability cost: an unhandled edge case, a missing test for new logic, a misleading API. |
| **Suggestion** | A better alternative exists, but the current code is acceptable. |
| **Hint** | Relevant for the future, not for this change. |
| **Remark** | A neutral observation. |
| **Question** | The intent can't be determined from the code or the repo. |

Rules:
- Crucial and Important comments must state the concrete failure: the inputs, then the wrong outcome.
- **Question discipline**: answer it from the repo first. Ask only when the answer depends on intent or context that isn't in the code. If you suspect a problem, use Important or Suggestion and state it directly. Never write "did you consider…?"
- Cap Remark and Hint at about 3 combined. Drop comments that restate the diff. Crucial, Important and Question are never capped.

## 4. Output

```
Reviewing PR #123 (owner/repo)
Changes expected (2 Important)

1. src/api/users.ts:42
   **Important:** `limit=0` returns every row, because `0` is falsy and falls through to the unbounded query.
   Fix: check `limit === undefined` instead.
2. src/api/users.test.ts:10
   **Important:** The new pagination path has no test, so the `limit=0` case above goes unnoticed.
3. src/api/users.ts:58
   **Suggestion:** `paginate()` in `src/lib/db.ts` already does this offset math.
4. src/api/users.ts:12
   **Question:** Is the 100-row maximum a product requirement, or a guess? Nothing in the repo or the linked issue says.
```

- The target line comes first, then the verdict line: `Blocks merge (N Crucial)`, `Changes expected (N Important)` or `OK to merge`.
- Then the comments, numbered and grouped by severity: Crucial, Important, Question, Suggestion, Hint, Remark.
- Each comment is `path:line`, then `**Label:** <one direct sentence>`, then an optional short reason or fix.
- If there are no findings, print the target line, `OK to merge`, and nothing else.

For local and pasted-diff targets, stop here.

## 5. Post (PR or MR targets only)

1. Ask which comments to post. Accept edits such as `post 1,3,5`, `post all`, `drop 4` or `relabel 2 as Suggestion`. Recompute the verdict after any relabeling and show the final list.
2. Fetch the user's existing comments, inline comments and review bodies or summary notes alike, and skip any duplicate: the same label at the same line with similar text. List the ones you skipped.
3. Check each comment's line against the diff hunks. Any comment that can't be anchored moves into the review body now, not after a failed post.
4. Show what will be posted: the comments, the review body, and the GitHub event or GitLab action. Then wait for an explicit confirmation. Use `AskUserQuestion` if you have it; otherwise ask in plain text and end your turn.
5. Post using `references/posting.md`:
   - Inline comments keep their `**Label:**` prefix. The verdict and any comments that can't be anchored go in the review body, one `` - `path:line` **Label:** ... `` line each.
   - **GitHub event**, first match wins: open Questions or your own PR → `COMMENT`; any Crucial or Important → `REQUEST_CHANGES`; only Suggestion, Hint or Remark → `APPROVE`.
   - **GitLab**: `OK to merge` with no open Questions → `glab mr approve`. Otherwise post the comments and a summary note without approving. If the verdict is `Changes expected` or `Blocks merge` and the user already approved, offer to revoke the approval and wait for them to confirm.
6. Report what was posted, with the review or note URL, and anything that was skipped or moved into the body.
