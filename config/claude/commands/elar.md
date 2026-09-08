---
name: elar
description: "Explain the thing in plain terms, assuming no background knowledge"
category: utility
complexity: basic
mcp-servers: []
personas: []
---

# /elar - Explain Like A Retard

Explain `$ARGUMENTS` — or, if empty, whatever was just discussed — in the
simplest terms that are still true.

## Two rules

**1. They know nothing about the topic.** Not the jargon, not the acronyms, not
the thing everyone in the field takes for granted and never says out loud. That
last one is the whole job — most bad explanations aren't too advanced, they're
missing the sentence that says what kind of thing this even is.

**2. They have lost the conversation.** Assume the reader is walking in cold and
remembers none of it. Anything you established earlier — a name, a decision, a
number, a file, "the fix", "the second attempt" — no longer exists for them.
Re-introduce it here, in one line, the first time you use it.

So do not write a continuation. Write a standalone explanation that happens to
be about what was just discussed.

## Format

**Answer in small pieces.** A screen of prose is a failure even if every
sentence is correct.

- Short lines. One idea each.
- Blank lines between them. Let it breathe.
- Group it under 2–4 small headings so it can be skimmed and re-entered.
- Bold **the one word that matters** in a line — the number, the name, the thing
  that broke. If everything is bold, nothing is.
- A tiny table or a two-line code block beats a paragraph. Use them.

Total length: as short as the truth allows. Ad copy, not a textbook.

## Order

1. **What it is** — one line. A person, a rule, a file, a mistake, a step.
2. **Why it exists** — what breaks without it.
3. **How it works** — only as far as the question actually needs.

## Frame the ask first

Take the ask apart. **Every significant word gets a line** — not just the
domain-sounding one. The ordinary-looking words usually carry the unexplained
weight, and explaining the exotic term while skipping the plain one is the
standard failure.

Ask of each: *what is this thing, and what is it for?*

Then say what the whole thing is trying to achieve, and scale it — how many, how
often, how much, who wants it.

Two or three lines total. Not a preamble, a foothold.

If the ask is genuinely self-contained, skip this. Do not manufacture context
that isn't needed.

## Every name you use, you define

The moment you write a label — a version, a stage, a run, a batch, an id, a
count — **say what it is before you use it.** These feel obvious to you because
you can see the thing they point at. The reader cannot.

A table of labels with numbers beside them is unreadable unless each row says
what was in it and how it differed from the row above.

Same for bare pronouns and words that hide a direction. **"It" is never
self-explanatory** — name the thing every time:

| Vague | What's missing |
|---|---|
| "it changed" | what changed, up or down, and by how much |
| "I attributed it to X" | what "it" is, and whether X helped or hurt |
| "that invalidates it" | what is invalidated, how, and what's unknown now |

The test: could someone who never read the earlier conversation follow this?

## Analogies

One, at most, and only if it genuinely carries the idea. A bad analogy costs
more than none — they now have to unlearn it. Say plainly where it stops being
true.

## Do not

- Pad with "basically", "essentially", "at a high level".
- Apologise, moralise, or note that the question is basic.
- Add caveats nobody asked for.

## Ending

Stop when it is explained. No summary, no "hope that helps". Offer to go deeper
only if something real was left out — and then name it in one line.
