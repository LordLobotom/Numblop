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
  a guaranteed reward chest, five chest taps, reward count-up, and return home.
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
