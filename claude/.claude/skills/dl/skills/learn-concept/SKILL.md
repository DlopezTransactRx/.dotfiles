---
name: learn-concept
description: Teach a concept by grilling the user with active-recall questions until they understand it, then turn the confirmed understanding into a memory palace image prompt. Use when the user types /learn-concept or learn-concept, or says "I want to learn X", "quiz me on X", "grill me so I understand X", or "teach me X and make a memory palace".
argument-hint: "<concept to learn, e.g. CloudFront, Kafka consumer groups, OAuth>"
---

# learn-concept — grill to understand, then remember

Two phases, in order: **grill** until the user owns the concept, then **memorize** it with `dl:memory-palace`. Never skip to the palace before the user confirms the recap.

## 1. Frame the concept

- Take the concept from the argument. If none, use the one being discussed. If still unclear, ask one plain-text question.
- If it's the user's own code, repo, or infrastructure, look the facts up first (subagent for broad searches). Never ask the user for a fact you can find.

## 2. Grill — invoke the `grilling` skill

Call the Skill tool with `grilling`, args: "I want to learn <concept>. Ask me questions to build a clear picture of what it does, how it's used, and why. Ultimate goal: complete understanding, then a memory palace." Follow it, with these learning adaptations:

- **Questions test understanding; they aren't decisions.** Start from the core problem the concept solves, then how it works, then the "why would I use it" and the gotchas. Use concrete scenarios ("a user in Tokyo requests…"), not definitions.
- **The ➡️ line is a hint, not the answer.** Say so once at the start. Active recall only works if the user answers before reading the answer.
- **The user answers piecemeal.** Grade what they answered, then re-list only the still-open questions, short. Don't repeat the full question text.
- **Grade every answer.** Lead with right / partly right / wrong in one sentence. Fix the wrong part plainly, and name the common misconception if they hit it. Add one analogy or memory hook when it helps.
- **"Don't know" is fine.** Give the answer with an analogy and move on.
- **Answers grow the tree.** A correction or follow-up opens new branches (e.g. hit/miss → TTL → invalidation). Add them as new numbered questions.
- **Side questions from the user are branches too.** Answer them, then flag the gotcha that will bite later in one line.
- **Track must-remember items.** When the user says something is important or worth remembering, acknowledge it and say how it will appear in the palace.
- **Keep the user's own analogies.** Say what it captures and where it breaks, refine it, and offer it as the palace setting.

## 3. Recap and confirm

When the frontier is empty, give a numbered recap of the whole picture: one line per idea, in the user's terms, with corrected analogies. Call out the must-remember items. Ask the user to confirm or flag anything fuzzy. Fold in any late additions and ask again. Do not build the palace until they confirm.

## 4. Build the memory palace

Call the Skill tool with `dl:memory-palace`. Pass the full recap as args, plus:
- the user's analogy as the scene setting, if they gave one;
- the must-remember items, marked as the biggest, most vivid parts of the scene;
- the misconceptions they hit, so the scene guards against them.

Then follow memory-palace's output rules.
