# tell-my-manager

A communication skill. It turns the dense, technical findings at the end of a long session (debugging, review, investigation), or any message you paste in, into a short Slack message your manager can read in ten seconds: where things stand, what's affected, and whether they need to decide something. Code and jargon are stripped; the reply comes back in the language you wrote in.

- `SKILL.md`: picking the source, what to extract, how to translate jargon into consequences, and the output template.

It runs only when you call it as `/tell-my-manager`.

## Install

With the [skills.sh](https://skills.sh/) CLI:

```bash
npx skills add Tarektouati/skills@tell-my-manager
```

Add `-g` to install globally (user-level) instead of into the current project.

## How it works

- With text after the command, it summarizes that text. With nothing, it summarizes the current session's conclusions and skips the dead ends.
- It keeps outcome/status, impact and risk, and any ask or decision, and drops file names, functions, stack traces and commands.
- Mechanisms become consequences: "race condition in the cache" becomes "some users saw outdated prices".
- It never invents impact, numbers or ETAs; missing pieces show up as placeholders like `[ETA?]` for you to fill.
- It writes the message for you to paste and never posts to Slack itself.

## Prompt examples

```
/tell-my-manager
/tell-my-manager <paste the incident write-up here>
/tell-my-manager Le job de synchro plante sur les webhooks dupliqués, ~3% des factures…
```

## Output

```
*TL;DR:* Found why the orders page has been slow since Tuesday; the fix is ready.
*Impact:* Orders pages took up to 4s to load for all customers (normally ~0.1s).
*Next:* Deploying the fix tonight, then confirming tomorrow morning.
```
