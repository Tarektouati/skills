# keep-digging

A learning skill. You keep asking "why" about unfamiliar code, systems, or concepts, one layer at a time, until you reach bedrock. It's based on how Tibo Sottiaux (Codex/OpenAI) described learning fast on The Pragmatic Engineer. It is **not** the incident-postmortem Five Whys: the goal is understanding how something works, not finding what broke.

- `SKILL.md`: when to use it, the digging process, and the output shape.

## Install

With the [skills.sh](https://skills.sh/) CLI:

```bash
npx skills add Tarektouati/skills@keep-digging
```

Add `-g` to install globally (user-level) instead of into the current project.

## How it works

- The first answer is grounded in the real code, docs, or config in front of you, not in a textbook explanation.
- Each "why?" goes one layer deeper: what it does → why it's built that way → the constraint behind that → the upstream assumption.
- It stops at bedrock (a hardware limit, an external contract, a documented tradeoff), not at a fixed count of 5.
- Layers it isn't sure about are marked as assumptions rather than made up.

## Prompt examples

```
keep digging: why does our build re-run codegen on every test?
five whys this: how does React batch state updates?
don't stop at the surface — why is this query doing a seq scan?
```

## Output

```
1. Tests re-run codegen every time
   why? →
2. The test script calls `pnpm build` first, and `build` has a `prebuild` codegen hook
   why? →
3. Codegen has no cache key, so it can't tell whether its inputs changed
   why? →
4. The schema is fetched from a live endpoint rather than read from a checked-in file
   why? →
5. The API team doesn't publish a versioned schema artifact

Root: codegen can't be skipped because its input isn't versioned anywhere.
```
