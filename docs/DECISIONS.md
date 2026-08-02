# Numblop Decision Log

## 2026-08-01 — Product and platform baseline

- Public product name is `Numblop`; “Násobilkový kamarád” was mockup placeholder text.
- Permanent Android package ID is `cz.gutcloud.numblop`.
- Android is portrait-locked; Windows uses a centered portrait window.
- MVP has one unnamed local child profile and no accounts, analytics, advertisements, cloud,
  or networking.
- English and Czech ship together from the first playable version.
- Godot 4.6.2 and GL Compatibility are pinned for the initial vertical slice because that exact
  editor, SDK, and template combination has been export-tested locally.

## 2026-08-01 — Learning ambiguities resolved

- Unlocked tables never relock.
- Missing review slots are filled from the current table so every session remains 10 questions.
- The same fact never appears twice in immediate succession.
- Response time is measured for mastery but no visible countdown is shown.
- Ordered table facts are stored separately in MVP (`2 × 3` and `3 × 2` have separate mastery).

## 2026-08-01 — MVP game loop

- A series has exactly 10 questions: 7 current-table, 2 older weak, and 1 older automated
  review question. Selection within those groups remains adaptive.
- The MVP loop includes the interactive blob home screen, local coins/experience/level totals,
  a guaranteed reward chest, one chest tap, reward count-up, and automatic return home without a
  separate continue button.
- An unfinished series is discarded and grants no reward. Mastery already recorded for answered
  questions remains saved, but the unfinished question list is not resumed.
- Reward calculation and cosmetic purchasing rules remain intentionally undefined.
- Fredoka is the primary UI typeface; its license file and Czech glyph coverage travel with the
  font asset.

## 2026-08-01 — Provisional M1 progression

- Every completed 10-question series grants 10 coins and 10 experience points, regardless of
  answer accuracy. An abandoned series still grants nothing.
- The displayed level is `1 + floor(total experience / 100)` and therefore starts at level 1.
- These values are intentionally simple M1 defaults. M3 may tune the reward and level pacing from
  observed play evidence, but reward calculation remains outside the learning/mastery core.

## 2026-08-02 — Accuracy-linked session rewards

- This decision supersedes the fixed 10-coin/10-experience reward above. Each correct answer in a
  completed series grants 1 coin and 1 experience point.
- A completed series always grants at least 1 coin and 1 experience point, including at zero
  correct answers, so the guaranteed reward chest is never empty. The resulting range is 1–10.
- Rewards remain separate from mastery. Incorrect answers affect the documented mastery delta,
  while coins and experience never unlock a multiplication table.

## 2026-08-02 — Unique facts within a series

- A 10-question series prefers unused eligible facts before repeating any fact. This prevents two
  equally weak facts from alternating through the entire series.
- Repetition remains valid only when a required 7-current/2-older-weak/1-older-automated pool is
  too small. The quota and lowest-mastery priority remain unchanged.

## 2026-08-02 — First Cosmetics vertical slice

- Outfit opens a compact Cosmetics shop without showing Numblop. Green is free; blue, pink, purple,
  and orange body colors cost 100 coins each and fit in one row.
- Tapping a locked item selects it for a separate Buy action; a successful atomic save deducts
  coins, unlocks and equips the item, and updates the home Numblop.
- A palette shader recolors the existing body, arms, and legs, so body-color variants require no
  duplicated PNG files. The belly, face, cheeks, and black outlines retain their source colors.
- The three supplied hats and three pairs of glasses join the shop at 100 coins each. They use rounded
  square cards with transparent crests, small borderless selected checks, the supplied lock icon,
  and a compact `100` plus coin crest price. A free empty card removes hats or glasses. The 768px
  accessory canvas is positioned at −128px horizontally and −175px vertically relative to the
  512px character canvas rather than being shrunk, preserving its authored alignment. Future
  patterns and shoes follow this contract.

## 2026-08-01 — M1 home navigation and stage map

- The language chooser appears in the remembered opening flow and the Settings screen; it does
  not occupy the main-screen content area.
- The footer uses Outfit, Map, Home, Trophies, and Settings crests. Home is always centered and
  returns directly to the blob screen, replacing top-level green back arrows. Each of the five
  columns expands equally with window width. Map and Settings are functional in M1. The later
  Cosmetics and streak decisions make Outfit and Trophies functional.
- The map is a read-only presentation of all eight table stages and never changes mastery,
  unlocking, or adaptive session selection.
- Background music starts with the main scene and loops. Settings persists separate Music/SFX
  volumes and global mute; friendly cues reinforce petting, navigation, answers, and rewards.
- Close game is available from Settings behind a confirmation and flushes pending preferences.

## 2026-08-02 — Cross-series correct-answer streak records

- The current streak counts consecutive correct answers across series and app restarts. Completing,
  abandoning, pausing, or closing a series does not end it; only an incorrect answer resets it.
- The interrupting mistake creates a timestamped Trophy milestone only when the ended streak is
  strictly higher than every previously ended streak. The stored history is therefore a compact,
  strictly increasing sequence of personal records rather than a log of every attempt.
- Each milestone stores Unix time plus the system timezone offset at interruption, allowing the UI
  to reproduce the local date and time later. Streak state is saved atomically with per-answer
  mastery and never affects didactic selection, mastery, rewards, coins, XP, or table unlocking.
- Home shows coin, XP, level, and the flame streak in one shared panel. Trophies shows the active
  streak, the best ended streak, and newest milestones first.

## 2026-08-01 — Visible didactic progression

- Every answer continues to use the canonical mastery delta and persists it immediately. Coins,
  experience, and player level never unlock multiplication tables.
- The current map island displays a continuous aggregate progress bar and matching percentage,
  capped at 80 points per fact, so improvement remains visible before a fact is fully ready.
  Unlocking still requires all 10 facts to reach 80 independently.
- Crossing the final mastery gate emits a table-unlocked domain event. After the reward reveal,
  the game opens the map, scrolls to the new island, and celebrates it in both languages.

## 2026-08-01 — Future Endless trail concept

- Clearing every multiplication island may unlock a post-campaign Endless mode with gradually
  higher factors beyond `9×`.
- Endless mode is not part of MVP and does not alter the canonical eight-table learning profile,
  mastery thresholds, or exact 10-question adaptive mix.
- Its factor growth, question selection, difficulty, persistence, and completion semantics require
  a dedicated didactic design decision before implementation.

## 2026-08-02 — Per-fact island detail and centered map

- Every unlocked island is a large touch target. Tapping it opens a dismissible detail with all ten
  facts, exact 0–100 progress bars, and the existing building/practicing/mastered/automatic bands
  supplied by application state. The overlay never mutates learning state.
- Aggregate progress remains capped at 80 per fact. A stage that has not met all ten gates displays
  at most 99%, avoiding a rounded 100% label before the next table unlocks.
- The winding trail uses a centered 350px content canvas. Wider portrait windows retain balanced
  margins instead of stretching the island path and status cards apart.
