---
name: keep-digging
description: Use this skill to build real, fast understanding of unfamiliar code, systems, or concepts by iteratively asking "why" — the technique Tibo Sottiaux (Codex/OpenAI) described for learning quickly while working with AI coding agents. This is a LEARNING/comprehension technique, distinct from incident-postmortem "Five Whys" root-cause analysis. Trigger this whenever the user is exploring an unfamiliar codebase, asks "how does X work" or "why does X happen," wants to deeply understand a mechanism instead of getting a surface-level answer, or explicitly asks to "five whys" something, dig deeper, or not stop at the first explanation.
---

# Keep Digging — Tibo's Five-Whys Learning Mode

## Context

In "Building Codex with Tibo Sottiaux" (The Pragmatic Engineer), Tibo describes how he
absorbs huge amounts of unfamiliar codebase/system knowledge fast: ask good questions
about how things work, then keep going into the five whys — "you can just keep digging
and digging and digging, and you're learning very, very fast through that."

This is NOT the classic incident/postmortem Five Whys (find the one root cause of a bug
and stop). It's a _curiosity engine_: use repeated "why" to pull a surface fact down to
the actual generative mechanism, as fast as possible, while exploring something new.

## When to use

- User is onboarding onto unfamiliar code, a new library, or a system Codex/Claude just
  touched, and a one-line explanation would leave them without real understanding.
- User asks "how does X work," "why does X do that," or similar, about something with
  real depth underneath (not a trivial fact).
- User explicitly says "five whys this," "keep digging," or "don't stop at the surface."

Skip this for trivial or already-well-understood facts — the technique is for closing a
genuine understanding gap, not padding a simple answer.

## Process

1. **Answer the first "why" concretely.** Ground it in the actual code, docs, config, or
   spec in front of you — not a generic textbook explanation. If you're working alongside
   an agent (Codex, Claude Code) that just made a change or explained something, treat its
   first answer as level 1, not the final word.
2. **Ask "why" again on your own answer.** Each round should go one layer more
   fundamental: from _what it does_ → _why it's built that way_ → _what constraint or
   design decision forced that_ → _what upstream system/assumption that decision rests on_.
3. **Keep digging until you hit bedrock, not a fixed count of 5.** Five is a rule of
   thumb. Stop when further "why"s would just be defining words in a circle, or when
   you've reached something axiomatic (a hardware limit, an external API's contract, a
   deliberate tradeoff someone made and documented).
4. **Surface each layer explicitly**, don't just think it silently — the point (per Tibo)
   is that stepping through the layers _is_ the fast-learning mechanism, for both the
   person and anyone reading along.
5. **If a layer is genuinely uncertain**, say so and mark it as an assumption rather than
   inventing a plausible-sounding "why." A wrong chain is worse than a short one.

## Output shape

Present as a short numbered chain, most-surface to most-fundamental:

```
1. [Observed behavior / surface fact]
   why? →
2. [One layer down — mechanism or immediate cause]
   why? →
3. [Design decision or constraint behind that mechanism]
   why? →
4. [What that decision was optimizing for / upstream assumption]
   why? →
5. [Root: a hard constraint, external contract, or foundational design principle]
```

Close with a one-line summary of the root cause/principle in plain language — that's the
thing worth remembering, the rest of the chain was how you got there.

## What this is NOT

- Not a bug-root-cause / incident-response tool (see the engineering incident-response
  or debug skill for that flavor of Five Whys — same question, aimed at "what broke,"
  not "how does this work").
- Not a substitute for reading the actual code/docs — each "why" should be checked
  against a real source, not guessed.
