---
name: tell-my-manager
description: "Turn the current session's findings, or a pasted message, into a short paste-ready Slack message for your manager: status, impact/risk, and any ask. Strips code and jargon, matches the input's language. Invoke only via /tell-my-manager."
disable-model-invocation: true
---

# tell-my-manager

Long sessions end with dense technical findings. A manager doesn't need the mechanism; they need to know where things stand, what it costs or risks, and whether they have to decide something. This skill turns those findings into a short Slack message the user can paste as is.

## 1. Pick the source

- **Text was passed or pasted with the command** → summarize that text only.
- **Nothing was passed** → summarize this session: the conclusions reached, what was found or fixed, and what's still open. Skip dead ends, abandoned hypotheses, and tool noise; they matter to the engineer, not the manager.
- **The session has no real findings yet** → ask the user what they want summarized instead of guessing.

## 2. Extract (internally, don't print this step)

Pull out four things:

- **Outcome / status**: what happened, and where it stands now (fixed, in progress, blocked, investigating).
- **Impact & risk**: who or what is affected, how badly, any deadline or customer exposure.
- **Ask / decision**: anything the manager has to approve, choose, unblock, or communicate onward.
- **Next step**: what the user does next, with an ETA if the source gives one.

Don't invent impact, numbers, or ETAs. A manager will repeat these upward, so a made-up figure becomes a commitment. If something important is missing, either leave the line out or put a placeholder like `[ETA?]` for the user to fill in.

## 3. Translate

The manager decides on priority and risk, not on implementation, so describe consequences, not mechanisms:

- "race condition in the cache layer" → "some users saw outdated prices for a few minutes"
- "N+1 query in the orders endpoint" → "the orders page got slow under load"
- Drop file names, function names, stack traces, commands, config keys, and library names.
- Keep ticket/PR/incident links and numbers that matter (users affected, duration, money, dates).
- If there's a trade-off, state both options in plain terms and what each one costs.

## 4. Output

Write the message in the **same language as the source** (French in → French out). Use Slack formatting, at most ~6 lines:

```
*TL;DR:* <one sentence: what happened / where it stands>
*Impact:* <who/what is affected, how badly>
*Next:* <what I'm doing next, ETA>
*Need from you:* <the decision or approval, with the options>
```

- Leave out *Impact* if there is none, and *Need from you* if nothing is needed. Don't pad.
- Translate the labels when the message isn't in English (e.g. *En bref / Impact / Suite / Besoin de toi*).
- Tone: neutral and direct, first person, no stacked hedges, no blame on people or teams.
- Put the message in a fenced code block so it copies cleanly.

Below the block, add one line listing what the user should check before sending: placeholders like `[ETA?]`, or assumptions you made. Skip the line if there's nothing to check.

Then offer one short follow-up: shorter, more detail, or as an email. Don't post anything to Slack yourself.

## Examples

**English.** Source: "Root cause is a missing index on `orders.customer_id` after the migration in #4521; p95 on /api/orders went from 120ms to 4s since Tuesday. Added the index in staging, fix verified, prod deploy tonight."

```
*TL;DR:* Found why the orders page has been slow since Tuesday; the fix is ready.
*Impact:* Orders pages took up to 4s to load for all customers (normally ~0.1s).
*Next:* Deploying the fix tonight, then confirming tomorrow morning.
```

**French.** Source: "Le job de synchro Stripe plante sur les webhooks dupliqués, ~3% des factures de novembre ne sont pas marquées payées. Je peux corriger en 2 jours, ou on fait un script de rattrapage manuel aujourd'hui et le vrai fix la semaine prochaine."

```
*En bref :* Environ 3 % des factures de novembre apparaissent comme impayées alors qu'elles sont réglées.
*Impact :* Risque de relances envoyées à tort à des clients qui ont payé.
*Suite :* Je corrige la cause ; correction complète en 2 jours.
*Besoin de toi :* On attend les 2 jours, ou je lance aujourd'hui un rattrapage manuel et le vrai fix la semaine prochaine ?
```
