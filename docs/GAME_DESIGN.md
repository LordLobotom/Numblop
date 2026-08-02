# Numblop — MVP Game Design

## Product identity

- Public name: **Numblop** in both languages.
- Android application ID: `cz.gutcloud.numblop`.
- Primary platform: portrait Android phone.
- Secondary platform: Windows, using the same centered portrait experience.
- Web platform: an adaptive canvas that fits the available phone viewport and uses a wider
  presentation on desktop without stretching portrait-focused content.
- The game is offline and uses one local child profile with an optional nickname.

## Player promise

Numblop gives a child a short, friendly multiplication session, adapts the selected facts to
what they know, and responds to mistakes without punishment. A playful blob and a guaranteed
reward chest make completing practice feel positive without distracting from the questions.

## Main repeating flow

Open the game → loading screen → main screen with the blob → press Play → answer 10 adaptive
questions → complete the series → tap the chest once → receive coins and experience →
tap to continue → return to the main screen.

No additional game modes are part of the MVP.

## Starting the game

- Show the game background while loading.
- Animate the Numblop pictogram and title simply; a short sound may accompany them.
- Offer Czech and English language buttons. Save the selection locally for later launches.
- Continue to the main screen after the short opening.

## Main screen

- Show the player's blob character as the focus of the screen.
- Give the blob a subtle idle animation such as breathing, blinking, gentle movement, or
  looking around.
- Let touch and mouse input pet or scratch the blob. It responds happily with animation,
  small hearts, and optionally a short positive sound.
- Show coins, experience, player level, and the current correct-answer streak in one shared top bar.
- The primary action is Play. The bottom navigation uses Outfit, Map, Home, Trophies, and Settings
  crests, with Home fixed in the middle and returning directly to the blob screen. All five items
  receive equal horizontal space as the portrait window widens.
- Map opens a read-only winding trail for the eight multiplication-table stages. Its bar and
  percentage move continuously with real mastery gains, while the next island unlocks only after
  at least 9 of 10 facts in the current table reach 80. Tapping an unlocked island opens a compact
  two-column view of all 10 facts, their individual percentage bars, and the four learning bands.
  The winding trail keeps a centered readable width when the portrait window becomes wider. In the
  detail,
  the mastery band moves from red through purple and orange to green. The Czech presentation names
  these bands `Objevuji`, `Procvičuji`, `Upevňuji`, and `Mám jistotu`.
- A correct-answer streak continues across practice series and app restarts. Only an incorrect
  answer ends it. When an ended streak exceeds every previously ended streak, Trophies adds a
  milestone with its count and the local date and time of the interrupting mistake. Shorter ended
  streaks reset the current counter but do not add rows. Streaks never change mastery or rewards.
- Outfit opens a compact Cosmetics shop without a character preview. The six body-color circles
  share one row: green is free, while blue, pink, purple, orange, and yellow cost 100 coins each. Hats,
  glasses, and necklaces use supplied transparent artwork in rounded square cards; every accessory
  costs 100 coins, and a free empty card removes that category. The duck cap joins the hat row and
  crown, duck, and moon necklaces have their own row. Tapping an owned item equips it. Tapping a
  locked item exposes a separate purchase action; purchases and selections persist locally.
- Settings provides English/Czech crest choices, separate background-music and sound-effect
  volume controls, a global mute, and a confirmed Close game action. The exit confirmation uses a
  compact custom card: actions stack on narrow phones and share one row on wider portrait windows.

Coins buy cosmetic items. Experience represents general progress. For the playable
MVP, each correct answer in a completed series grants 1 coin and 1 experience point. A completed
series with no correct answers still grants the minimum of 1 coin and 1 experience point, so its
guaranteed chest is never empty. The displayed level is `1 + floor(total experience / 100)`.
Rewards never alter mastery or table unlocking.

A correct answer that moves a fact upward into the 60-point, 80-point, or 90-point mastery band
immediately grants a separate 5-coin milestone bonus. The practice feedback presents a short
success title, the fact in bold at 1.5 times the title size, the new band name alone, and then the
coin bonus; it plays a level-up cue followed by a coin cue. This bonus grants no experience and does
not replace or alter the completed-series chest reward. The milestone card remains visible for
3.6 seconds, twice its original duration, and a tap anywhere dismisses it early.

Future Cosmetics sections use the same scrollable panel for belly patterns, shoes, and additional
categories. Non-color items use the same rounded cards, selected check, lock, and compact numeric
price followed by the coin crest.

## Question series

- Every completed series contains exactly **10 questions**.
- Question selection, difficulty, and answer mode are adaptive and follow
  `docs/didactic_algorithm.md`.
- Prefer 10 unique facts in each series. Repeat a fact only when a required adaptive review group
  does not contain enough eligible facts to fill its quota.
- Present one question at a time using four choices, six choices, or the numeric keypad.
- A correct answer receives short positive visual/audio feedback and advances.
- An incorrect answer shows the complete correct equation, for example `7 × 4 = 28`, using
  calm and positive presentation, followed by a domino-style dot picture of the fact so the child
  sees the quantity and not only the digits. The picture fills in over 1.2 seconds and the
  continue control appears only once it is complete; after that wait for a tap before advancing,
  with no time limit. This correction is presentation only: it never adds a question, changes
  mastery, counts as an attempt, or affects the streak.
- Never show a stressful answer countdown.
- Do not display the completed-series coin or experience reward during the question series. The
  immediate 5-coin fact-milestone celebration is the only exception.

## Completing the series and reward chest

- Completing all 10 questions always grants a reward chest, even when answers were incorrect.
- Each correct answer grants 1 coin and 1 experience point. A completed series grants at least
  1 of each, producing a reward range of 1–10 without making the guaranteed chest empty.
- Present a closed chest with a short celebratory sound or fanfare.
- The player taps the chest once. The tap shakes the chest and briefly vibrates a supported mobile
  device.
- That tap opens the chest with a sound effect.
- Count the earned coins and experience points up visually and show the updated totals.
- After the count finishes, keep the totals visible briefly and continue automatically. Normally
  return to the main screen, where the blob may play a short happy reaction. If that series
  unlocked a table, reveal its new island on the map instead. Do not show a continue button.

## Interrupted series

- Leaving or closing the game before all 10 questions are complete abandons that series.
- An abandoned series grants no chest or completed-series coins or experience and is not restored
  on relaunch. Any per-answer fact-milestone bonus already earned and saved remains on the device.
- Mastery changes from answers already processed remain saved locally; only unfinished-series
  state and its pending reward are discarded.
- The next press of Play starts a new 10-question series from the beginning.

## Presentation and accessibility

- Use **Baloo 2** as the primary game typeface and include Czech glyph coverage.
- Keep `Numblop` untranslated as the public name.
- Touch targets are at least 48 px and primary actions at least 64 px high.
- Sound and vibration reinforce actions but are never required to understand the state.
- The game remains usable with touch on Android and mobile Web, and mouse/keyboard on Windows and
  desktop Web.
- No feature depends on connectivity, accounts, advertisements, analytics, or cloud services.
