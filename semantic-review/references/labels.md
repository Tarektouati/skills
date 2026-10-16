# Labels

The six labels come from Kevin's [Semantic Code Reviews](https://www.m31coding.com/blog/semantic-reviews.html) (m31coding.com). The reviewer "prepends every comment with a label to clearly express their intent and expectations." The quoted definitions below are the article's own words. The **Use when** rubric is this skill's own, and you can tune it.

Format each comment as `**Label:** <one direct sentence>`, optionally followed by a short reason or fix.

## Crucial

> "This code must not be merged. It has a severe issue and must be changed in order to avert harm."

**Use when** merging causes real harm:
- a correctness bug on a reachable path
- a security hole
- data loss or corruption
- a broken build, migration or deploy

**Must** state the concrete failure: the inputs or state, then the wrong outcome. If you can't name a reachable path, it's not Crucial.

## Important

> "This is important to me and I expect a change. If you strongly disagree I expect that we discuss this further."

**Use when** there's a defect or a maintainability cost you can name concretely:
- an unhandled edge case
- a missing test for new logic
- a misleading API, name or contract
- error handling that hides failures

**Must** state the concrete failure or cost: the inputs or situation, then the wrong outcome.

## Suggestion

> "I have a suggestion and I expect that you think about it. Whether you accept it or not is up to you."

**Use when** a better alternative exists but the current code is acceptable: a simpler construct, an existing helper to reuse, a clearer structure. Name the alternative.

## Hint

> "I don't expect any change or answer in this review, but you may find this interesting and consider it for the future."

**Use when** the point is relevant for future work, not this change: an upcoming deprecation, a pattern worth knowing, a follow-up worth filing.

## Remark

> "I have a simple remark, no change or answer is expected from my side."

**Use when** making a neutral observation that's worth having on record. Never restate what the diff does.

## Question

> "I have an honest question and I expect an answer. This label must not be used for rhetorical or leading questions."

**Use when** the intent can't be determined from the code or the repo.

Discipline:
1. Try to answer the question yourself first: read the surrounding code, callers, tests, commit messages, docs and linked issues.
2. Use Question only when the answer depends on intent or context that isn't in the repo, such as product requirements, an external system, or a rollout plan.
3. If you suspect a problem, don't ask about it. Use Important or Suggestion and state the problem directly.
4. Never write "did you consider…?", "what if…?" or "shouldn't this…?"

## Caps

- Remark and Hint together: about 3 per review. Keep the most useful ones.
- Drop any comment that restates the diff.
- Crucial, Important and Question are never capped.

## Verdict

| Comments | Verdict |
|---|---|
| any Crucial | `Blocks merge (N Crucial)` |
| any Important, no Crucial | `Changes expected (N Important)` |
| otherwise | `OK to merge` |

Open Questions don't change the verdict line, but they do affect the GitHub review event and block GitLab approval (see `posting.md`).
