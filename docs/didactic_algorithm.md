# Didactic Algorithm – MVP

## 1. Learning Multiplication Tables

Multiplication tables are learned progressively:

> 2 → 3 → 4 → 5 → 6 → 7 → 8 → 9

Each multiplication table contains 10 facts:

- ×0
- ×1
- ×2
- ×3
- ×4
- ×5
- ×6
- ×7
- ×8
- ×9

Each fact has its own mastery value in the range of **0–100 points**.

---

## 2. Unlocking the Next Multiplication Table

The next multiplication table is unlocked when at least **9 of the 10 facts** in the current table
reach a value of at least **80**.

This keeps the whole table important while allowing one unusually difficult fact to continue in
review without blocking the child's progress to the next island.

---

## 3. Automaticity

Older facts continue to be practiced after the next multiplication table is unlocked.

There are two thresholds:

- **80 points** – the fact is sufficiently mastered to continue.
- **90 points** – the fact is considered automated.

Automated facts still appear occasionally to reinforce them in long-term memory.

---

## 4. Question Type by Mastery

| Fact value | Question type |
|---|---|
| 0–59 | Choice of 4 answers |
| 60–89 | Choice of 6 answers |
| 90–100 | Entering the result using a keyboard |

Using the exact ranges of 0–59, 60–89, and 90–100 prevents ambiguity during implementation.

---

## 4a. Visual Correction Support

After **every** incorrect answer, regardless of the fact's mastery value, the correction shows a
domino-style dot picture of the fact underneath the complete equation. A mistake is exactly the
moment help is wanted, so this is not gated by mastery band; one rule keeps the feedback
predictable for a child.

- The fact is drawn as `min(table, multiplier)` groups holding `max(table, multiplier)` dots each.
  So `3 × 4` is three groups of four, and `7 × 4` is four groups of seven. Choosing the smaller
  factor as the group count keeps the picture readable; it commutes some facts, which is
  mathematically sound and intentional.
- Counts of 1–6 are drawn as the familiar die faces. Counts of 7–9 use the domino decomposition
  `5 + remainder`, so 7 is 5 + 2, 8 is 5 + 3, and 9 is 5 + 4. Recognising five at a glance is what
  makes the larger quantities readable without counting one by one.
- `× 0` has no groups. It draws a single empty frame and says so in words.
- The picture is generated programmatically for all 80 facts; there is no per-fact artwork.

This correction is **presentation only**. It never adds a scored question, changes a mastery
value, counts as an attempt, affects the streak, or alters the fixed round length of section 5. All
scoring for the answer has already completed before the correction is shown.

---

## 5. One Game

Game length and mix depend on how far the child has come.

Up to and including the **5× table**, one game contains **10 questions**:

- **7 questions** from the multiplication table currently being learned,
- **2 questions** from older facts that are not yet saturated,
- **1 question** from an already automated fact.

From the **6× table** onwards, one game contains **12 questions**:

- **8 questions** from the multiplication table currently being learned,
- **3 questions** from older facts that are not yet saturated,
- **1 question** from an already automated fact.

The later tables carry more history behind them, so both extra questions go to review rather
than to new material.

### Automated and Not Yet Automated

For the purpose of choosing review questions, a fact counts as **automated only at a mastery
value of 100**. Anything below that — including the 90 to 99 band — still belongs to the
older-weak pool.

This is deliberately not the same threshold as the one at section 3 that switches a question to
typed input at 90. That threshold decides *how a question is asked*; this one decides *how often
a fact comes back*. A fact at 95 is already answered by typing, but it is not yet finished.

### Selecting a Specific Fact

Within the current-table and older-weak groups, facts with the lowest mastery value have
priority.

The automated group works differently. Every fact in it is at 100, so mastery cannot tell them
apart and the choice would fall entirely to chance — which lets an individual fact go unvisited
for a long stretch. Instead the automated question is always the fact that has gone **longest
since it was last practised**, tracked per fact as `last_practiced`. Facts that have never been
practised count as the longest-waiting, so a freshly saturated fact enters the rotation at once.

This guarantees the automated pool is cycled through continuously and no fact is neglected.

If multiple facts have the same value, they are selected randomly.

---

## 6. Evaluating an Answer

Each answer is evaluated according to:

- correctness,
- speed.

### Changing a Fact's Mastery Value

| Result | Change |
|---|---:|
| Correct and fast | +5 |
| Correct, but slower | +3 |
| Incorrect | −2 |

After every change, the value is clamped to the range of **0–100**.

---

## 7. Fast-Answer Time Limits

| Question type | Fast answer |
|---|---:|
| Choice of 4 answers | within 2.5 s |
| Choice of 6 answers | within 3 s |
| Entering the result | within 4 s |

An answer submitted after the time limit is still correct, but it is counted as a correct slow
answer.

---

## 8. Returning to Easier Questions

If the child starts making mistakes, the fact automatically returns to an easier practice type.

- Falling below **90**
  → answer choices are used again instead of entering the result.

- Falling below **60**
  → the fact returns to a choice of 4 answers.

- Falling below **80**
  → the fact is placed back among the regularly practiced facts.

One mistake must not significantly affect the long-term mastery of a fact. Repeated mistakes,
however, gradually reduce its value.

---

## 9. Practice Priority

The following rules apply when selecting the next question:

1. Facts with the lowest values have the highest priority.
2. Facts below 80 appear most frequently.
3. Facts in the range of 80–89 appear less frequently.
4. Facts with a value of 90 or more appear only occasionally for review.

---

## Algorithm Diagram

```text
              Start of game
                    │
                    ▼
        Select a fact by priority
                    │
                    ▼
      Determine question type by value

      0–59  → 4 choices
      60–89 → 6 choices
      90+   → enter the result

                    │
                    ▼
        The child answers the question
                    │
        ┌───────────┴───────────┐
        │                       │
      Correct                Incorrect
        │                       │
        ▼                       ▼
  Measure time               −2 points
        │
   ┌────┴────┐
   │         │
 Fast      Slower
   │         │
 +5        +3
   │         │
   └────┬────┘
        ▼
  Update value (0–100)
        │
        ▼
 Change question type by the new value
        │
        ▼
 Are at least 9 of 10 facts ≥ 80?
        │
    Yes │ No
        │
        ▼
 Unlock the next multiplication table
```

---

## MVP Note

Changing a fact's value linearly by `+5`, `+3`, and `−2` is suitable for the first version because
it is simple, predictable, and easy to implement.

In the future, the algorithm can be expanded with features such as:

- slowing progress at higher mastery values,
- considering streaks of correct or incorrect answers,
- time elapsed since the fact was last practiced,
- adaptive limits for each individual child,
- spaced repetition.

---

## Confirmed Implementation Decisions

These rules are part of the MVP and remove ambiguity during implementation:

- Once a multiplication table is unlocked, it never locks again, even if the value of an older
  fact later falls below 80.
- Exactly nine facts at 80 or more are sufficient to unlock the next multiplication table. Eight
  are not sufficient. The remaining fact stays in the older-weak review pool until it improves.
- If there are not enough suitable facts for a review group, the missing slots are filled with
  facts from the multiplication table currently being learned. One game always has its full
  length: 10 questions up to the 5× table, 12 from the 6× table onwards.
- When the automated slot has to borrow from the current table because no fact has reached 100
  yet, it selects by lowest mastery like any other current-table slot; the longest-waiting rule
  applies only when a real automated pool exists.
- The same fact must not appear in two immediately consecutive questions.
- Within one series, select unused eligible facts before repeating a fact. Repetition is allowed
  only after the required current, older-weak, or older-automated pool is exhausted. Therefore
  the initial current-table-only series contains all 10 facts exactly once.
- Answer time is measured to calculate the mastery change, but the child does not see a stressful
  countdown while answering.
- In the MVP, the facts `a × b` and `b × a` are tracked separately according to their respective
  multiplication tables.
- Every submitted answer applies the documented mastery delta immediately. Tests must verify the
  complete answer → mastery → save → unlock path without requiring a rendered scene.
- A stage map may show continuous aggregate progress by summing each fact up to the 80-point gate.
  Once 9 of 10 facts reach 80, the completed island displays 100%; the remaining fact keeps its
  real individual value in the detail and continues to be reviewed.
- Tapping an unlocked stage may show the ten individual fact values and their existing didactic
  bands. This drill-down is read-only and does not affect selection, scoring, or unlocking. Until
  nine facts reach the gate, a rounded aggregate label is capped at 99% rather than displaying a
  misleading 100% on a still-locked stage.
