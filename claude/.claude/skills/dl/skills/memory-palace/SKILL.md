---
name: memory-palace
description: Turn a concept or process into one vivid, memorable image plus a numbered legend, delivered as a single paste-ready prompt for ChatGPT image generation. Use when the user types /memory-palace or memory-palace, or asks for a "memory image", "memory palace", "something to help me remember this", or "a picture I can recall". If no concept is given, use the one being discussed in the conversation.
argument-hint: "[concept, process, or flow — omit to use the current conversation's topic]"
---

# memory-palace — one memorable image + legend

Build ONE prompt the user pastes into ChatGPT (image generation). ChatGPT draws a single scene, then writes a numbered legend under it explaining what each part means. It follows the "Remember It!" method (Nelson Dellis): vivid, exaggerated, moving, sensory images tied to each idea.

One scene, not a multi-room palace. The name is the method, not the layout.

## 1. Get the concept right first

- Use the argument. If there is none, take the concept from the conversation. If it's still ambiguous, ask one question, as plain text.
- If the concept is about the user's own code, repo, or infrastructure, check the facts in the source before drawing them. The legend is a teaching aid; a wrong step gets memorized.
- Write the concept as an ordered flow of 5–11 steps. Include the "before it starts" setup if it matters, and the step people most often get wrong.

## 2. Design the scene

- **One metaphor world** that fits the whole flow (a club door, a kitchen, a heist, a post office). Every step is an object or action inside it.
- **One concrete, exaggerated object per step**, with a sensory detail: melting, hissing, glowing, dripping. Prefer actions over static things.
- **One color per actor or system** (e.g., orange = AWS, icy blue = Snowflake) so who-does-what reads at a glance.
- **Left-to-right order = step order.** The scene reads like a comic strip in one frame.
- **Guard the top misconception with an image.** Example: "the bouncer can't open the sealed envelope" = only the provider can verify the proof.
- **A recall hook**: one word per step, joined with " · " (e.g., "Vend · Melt · Seal · Hand · Tube · Snip · Band").

## 3. Write the prompt

Output exactly one fenced block in this shape:

```
Create one illustration, then explain it. Two parts, in this order.

PART 1 — DRAW THIS IMAGE
<style line: whimsical, vividly colored storybook illustration, single wide 16:9 scene, readable left to right like a comic strip in one frame, exaggerated, high contrast; the color-per-actor rule>
Place a small white circle with a bold black number (1–N) next to each element listed below, so the picture can be matched to the legend.
<Far left / Left / Center / Right sections describing each object with its number in parentheses>
<Lighting line.> The only words allowed in the image are <at most 2–3 short labels> and the numbers 1–N. No other text, letters, or captions.

PART 2 — BELOW THE IMAGE, WRITE THIS LEGEND EXACTLY
Title: "<memorable title: what the concept is>"
Recall hook: <Word · Word · Word>
<optional group headings, e.g., "Before X is involved:">
1. <Object> = <what it represents, one or two plain sentences>.
...
End with one line: "<the one-time setup or key takeaway that the picture implies but does not show>"
```

Then, outside the block:
- `🎯 Target: ChatGPT with image generation. 💡 <one sentence on how the scene maps to the flow>`
- One line: paste into ChatGPT (not raw DALL·E) so the image and the written legend come back together.

## Rules

- Keep text inside the image to 2–3 short words plus the numbers. Image models garble longer text; the legend carries the words.
- Every legend line maps one object to one idea. No step without an object, no object without a step.
- Plain words in the legend. Name real components (role names, services) when the concept is the user's own system.
- No PHI, secrets, account keys, or real record ids anywhere in the prompt.
- After the prompt, offer one change in one line (e.g., add a missing step, swap the metaphor).
