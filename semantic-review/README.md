# semantic-review

A code review skill. The agent labels every comment with one of the six labels from Kevin's [Semantic Code Reviews](https://www.m31coding.com/blog/semantic-reviews.html) (m31coding.com): **Remark, Question, Hint, Suggestion, Important, Crucial**. Each label tells the author what response is expected, from "no reply needed" up to "must not be merged". The article defines only the labels. This skill adds a labeling rubric, a review workflow, and posting to GitHub PRs and GitLab MRs.

- `SKILL.md`: the workflow. Resolve the target, review, label, print, and post if you confirm.
- `references/labels.md`: the six labels quoted from the article, plus the rubric for choosing between them. Tune the rubric here.
- `references/posting.md`: the `gh` and `glab` commands for inline comments, review events, approving or revoking, and duplicate detection.

## Install

With the [skills.sh](https://skills.sh/) CLI:

```bash
npx skills add Tarektouati/skills@semantic-review
```

Add `-g` to install globally (user-level) instead of into the current project. Posting needs `gh` (GitHub) or `glab` (GitLab), authenticated. Without them it still reviews and prints to the terminal.

## How it works

- It only runs when you invoke `/semantic-review`. A plain "review this PR" won't trigger it.
- The target is the argument you give it (PR/MR number or URL, branch, path, pasted diff). Otherwise it's the current branch's open PR/MR. Otherwise it asks which branch to diff against (suggesting the default branch), then reviews the diff from the merge-base, including uncommitted and untracked changes.
- Crucial and Important comments must state the concrete failure. Questions are honest questions only: the agent answers what it can from the repo first and never asks "did you consider…?", "what if…?" or "shouldn't this…?"
- Remark and Hint are capped at about 3 per review. Crucial, Important and Question are never capped.
- Diffs over about 1,500 changed lines are reviewed commit by commit, and each finding is checked against the final state, so a bug fixed in a later commit isn't reported.
- Nothing is posted until you pick the comments and confirm. Duplicates of your earlier comments are skipped. The GitHub review event or the GitLab approval follows from the verdict, and open Questions hold back approval on both.

## Prompt examples

```
/semantic-review
/semantic-review 123
/semantic-review https://gitlab.com/group/project/-/merge_requests/45
/semantic-review feat/csv-export
/semantic-review src/api/
```

After the review:
```
post 1,2,4
relabel 3 as Hint, then post all
drop 5
```

## Output

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
