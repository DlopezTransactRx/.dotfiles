---
name: 10ke
description: Give a 10,000-foot explanation of a topic — the big picture in plain words, no implementation detail. Use when the user types /10ke, $10ke, or 10ke, or asks for a "10,000 foot view", "high-level overview", "big picture", or "explain it simply".
argument-hint: "<topic, system, repo, or concept>"
---

# 10ke — 10,000-foot explanation

Explain the topic the way you would to a smart colleague who has never seen it. The shape of it, not the details.

If the topic is in the user's own code, repos, or infrastructure, look first (read the README, CLAUDE.md, main entry point, or Terraform). Don't guess what it does.

## Shape

In this order, as plain paragraphs. No headers. Bullets only for the parts list, if it helps.

1. **One sentence that answers it.** What it is and what it's for.
2. **Why it exists.** The problem it solves, in one or two sentences.
3. **The main parts.** Three to five pieces and how they connect: what goes in, what happens, what comes out. Name real components if it's the user's system.
4. **Where it sits.** What feeds it and what depends on it.
5. **An analogy or memory hook.** One, and only if it genuinely makes the idea easier to hold.
6. **What it is not.** One line correcting the most common misunderstanding, if there is one.

## Rules

- Aim for 150-250 words.
- Short sentences, one idea each. Everyday words. Define an unavoidable term inline once.
- No code, config, flags, or edge cases. If the user wants the technical version, they'll ask.
- No hedging. State a real caveat in one sentence.
- End by offering one level deeper on a specific part, in one line.
