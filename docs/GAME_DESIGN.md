# Numblop — Game Design

## Product identity

- Public name: **Numblop**, untranslated in every language.
- Android application ID: `cz.gutcloud.numblop`.
- Primary platform: portrait Android phone.
- Secondary platform: Windows, using the same centered portrait experience.
- Web platform: an adaptive canvas that fits the available phone viewport and uses a wider
  presentation on desktop without stretching portrait-focused content.
- The game is offline and uses one local child profile with an optional nickname.
- The interface ships in ten languages; see [`LOCALIZATION.md`](LOCALIZATION.md).

## Player promise

Numblop gives a child a short, friendly multiplication session, adapts the selected facts to what
they know, and responds to mistakes without punishment. A playful blob and a guaranteed reward chest
make completing practice feel positive without distracting from the questions.

## Main repeating flow

Open the game → loading screen → main screen with the blob → press Play → answer the series of
adaptive questions → complete the series → tap the chest once → receive coins and experience → tap to
continue → return to the main screen.

Once every table through 9× has been permanently completed, the main action becomes Practice. It
opens free-practice setup: choose 10, 20, 30, 40, or 50 questions and any permanently completed
tables, or leave every table unselected for smart review across all completed tables. The questions,
feedback, mastery changes, saving, streak, and reward chest use the same play loop. Setup is a
secondary page in the normal Numblop shell: it keeps the shared header and five-item bottom
navigation, highlights no primary tab, and Back returns to the Home or table detail that opened it.
Every entry starts with no table selected, including entry from a table detail. The first-use length
is 10; choosing another length remembers it only in this device's settings.

## Starting the game

- Show the game background while loading.
- Animate the Numblop pictogram and title simply; a short sound may accompany them.
- Offer the shipped languages as flag buttons. Save the selection locally for later launches.
- Continue to the main screen after the short opening.

## First-run tutorial

A new profile is walked through the loop once by a pointing finger overlay, across two rounds:

1. Play → the correct answer → the chest → Outfit → the Buy button → Home.
2. Play again → the Map → open an island.

It ends permanently once completed and never runs again on that profile.

- The finger points; it does not block. The child performs every real action themselves.
- The first round shows where the shop and the Buy button are; **nothing has to be bought**. That
  step ends when the child buys something or simply leaves the shop again.
- Each step is recorded, so closing the game halfway resumes at the step it stopped on rather than
  starting over.
- A save that predates the tutorial belongs to a child who already knows the game: it counts as
  onboarded and is never walked through the basics.
- The same applies to a save that arrives from the cloud. A reinstall or a second device restores a
  profile that has already been onboarded, and the tutorial stops the moment it lands. While that
  restore is still on its way the finger waits, so a returning child never sees it at all.
- Resetting the profile replays it, because that is a new child.

## Main screen

- Show the player's blob character as the focus of the screen.
- Give the blob a subtle idle animation such as breathing, blinking, gentle movement, or looking
  around.
- **Petting is a stroke across the avatar, not a tap.** It responds happily with animation, small
  hearts, and one of three voice clips chosen without repeating the previous one.
- Show coins, experience, player level, and the current correct-answer streak in one shared top bar,
  plus the optional nickname pill.
- The primary action is Play. The bottom navigation uses Outfit, Map, Home, Trophies, and Settings
  crests, with Home fixed in the middle and returning directly to the blob screen. All five items
  receive equal horizontal space as the portrait window widens.
- After 9× first passes the normal nine-of-ten completion gate, the primary action permanently reads
  Practice and opens free-practice setup. Completion is not revoked by a later mastery decrease. The
  setup page retains the same five navigation destinations as the primary pages; it is a linked
  secondary destination, not a sixth tab.
- Every scrolling screen can be dragged from anywhere, including from on top of a button or slider;
  the child's press is cancelled once the gesture is taken over. Scrollbars are hidden.

### Map

Map opens a read-only winding trail for the eight multiplication-table stages. Its bar and percentage
move continuously with real mastery gains, while the next island unlocks only after at least 9 of 10
facts in the current table reach 80. Tapping an unlocked island opens a compact two-column view of
all 10 facts, their individual percentage bars, and the four learning bands. The winding trail keeps
a centered readable width when the portrait window becomes wider.

In the detail, the mastery band moves from red through purple and orange to green — Czech
`Objevuji`, `Procvičuji`, `Upevňuji`, `Mám jistotu`. A rounded aggregate label is capped at 99 %
until the island's gate is actually passed, so it never shows a misleading 100 % on a locked stage.

### Trophies

Trophies is a read-only screen with two parts:

- The best correct-answer streak ever reached, and the timestamped personal-record milestones. A
  streak continues across practice series and app restarts; only an incorrect answer ends it. When an
  ended streak exceeds every previously ended streak, a milestone row is added with its count and the
  local date and time of the interrupting mistake. Shorter ended streaks reset the counter but add no
  row. Streaks never change mastery or rewards.
- Achievement cards, each with its own icon, title, description, progress towards its target, and
  its coin reward. Every achievement has dedicated artwork — a round medallion named after the
  achievement id — and a locked one is the same picture, dimmed.

### Outfit

Outfit opens a compact cosmetics shop without a character preview, organised into tabs:

| Category | Free default | Paid items |
|---|---|---:|
| Body colour | green | 5 |
| Belly colour | cream | 6 |
| Hats | none | 6 |
| Glasses | none | 5 |
| Necklaces | none | 5 |
| Shoes | none | 5 |

Every paid item costs 100 coins. Body and belly colours are circular swatches; the four accessory
categories use rounded square cards with supplied transparent artwork, and each has a free empty card
that removes that category. Tapping an owned item equips it. Tapping a locked item exposes a separate
purchase action. Purchases and selections persist locally.

### Settings

Settings provides the language flag choices, separate background-music and sound-effect volume
controls, a global mute, a haptics toggle, the public application version, and a confirmed Close game
action. The exit confirmation uses a compact custom card: actions stack on narrow phones and share
one row on wider portrait windows.

Vibration is reserved for three moments and nothing else: the chest tap, the chest opening, and the
mastery-milestone cheer. A wrong answer never buzzes — a buzz on failure reads as a physical
scolding. Correct answers do not buzz either; ten per round would turn the phone into a pager.
Switching the toggle on plays the tap pattern so the child feels what they enabled.

## Economy

Coins buy cosmetic items. Experience represents general progress and equals the lifetime count of
correctly answered questions. The displayed level is `1 + floor(total experience / 100)`. Rewards
never alter mastery or table unlocking, and there are no purchases with real money.

There are three ways to earn coins:

1. **The completed-round chest.** Each correct answer in a completed series grants 1 coin and
   1 experience point. A completed series with no correct answers still grants the minimum of 1 coin
   and 1 experience point, so its guaranteed chest is never empty. The range is therefore 1–10 for a
   ten-question round and 1–12 for a twelve-question one.
2. **Mastery milestones.** A correct answer that moves a fact upward into the 60, 80, or 90 band
   immediately grants a separate 5-coin bonus. It grants no experience and does not replace the chest.
3. **Achievements**, below.

## Achievements

Each achievement pays its coins exactly once, and never pays again — the granted set is permanent
even if the underlying statistic later drops.

| Achievement | Target | Reward |
|---|---|---:|
| First steps | 1 completed round | 100 |
| Streak | 10 / 20 / 50 / 100 / 500 / 1000 correct answers in a row | `min(target, 50)` |
| Experience | 500 / 1000 / 5000 / 10000 XP | 50 each |
| Collection | every paid item of one cosmetic category | 50 each |
| Island | all 10 facts of one table at mastery 100 | 50 each |

Notes that keep the numbers honest:

- A streak counts the moment it is reached; it does not have to be ended by a mistake first.
- Collections count paid items only, so a fresh profile starts every collection at zero. Buying the
  last item pays immediately, while the celebration waits for the next end-of-round page.
- Island achievements need full saturation at 100, which is stricter than the 9-of-10-at-80 gate that
  unlocks the next island.
- An existing save is evaluated retroactively on load: everything already earned is granted at once,
  silently, without a celebration the child never triggered.

## Question series

- Every progression series contains exactly **10 questions** up to the 5× table and exactly
  **12 questions** from the 6× table onwards.
- Question selection, difficulty, and answer mode are adaptive and follow
  [`didactic_algorithm.md`](didactic_algorithm.md).
- Prefer unique facts in each series. Repeat a fact only when a required adaptive review group does
  not contain enough eligible facts to fill its quota.
- Free practice is generated separately from progression. Explicitly selected tables are mixed so
  their counts differ by at most one; weaker facts may lead within each table. With no table selected,
  smart review uses every completed table, favors lower mastery, penalizes repetition, and approaches
  a balanced table mix when mastery is similar. It stores no error history beyond existing mastery.
- Present one question at a time using four choices, six choices, or the numeric keypad.
- A correct answer receives short positive visual/audio feedback and advances.
- An incorrect answer shows the complete correct equation, for example `7 × 4 = 28`, using calm and
  positive presentation, followed by a domino-style dot picture of the fact so the child sees the
  quantity and not only the digits. The picture fills in over 1.2 seconds and the continue control
  appears only once it is complete; after that it waits for a tap, with no time limit. This
  correction is presentation only: it never adds a question, changes mastery, counts as an attempt,
  or affects the streak.
- Never show a stressful answer countdown.
- Do not display the completed-series coin or experience reward during the question series. The
  immediate 5-coin fact-milestone celebration is the only exception. It shows a short success title,
  the fact in bold at 1.5 times the title size, the new band name alone, then the coin bonus; it
  remains visible for 3.6 seconds and a tap anywhere dismisses it early.

## Completing the series and the reward page

Completing every question always grants a reward chest, even when answers were incorrect. The
end-of-round page is one scrolling page built around a single chest and revealed step by step:

1. A closed chest with a short celebratory sound or fanfare.
2. The player taps the chest once. The tap shakes the chest and briefly vibrates a supported device.
3. That tap opens the chest with a sound effect.
4. The per-fact mastery summary appears above the chest, showing each practised fact's gain on a dot
   scale rather than as a numeric jump.
5. The itemised coin rewards appear below it — round reward, mastery-milestone bonus, achievement
   rewards, and the total — followed by the counted-up coin and experience totals.
6. The finished page is held briefly, then continues automatically; a tap anywhere skips the wait.
   Normally it returns to the main screen, where the blob may play a short happy reaction. If that
   series unlocked a table, it reveals the new island on the map instead. There is no continue button.

## Interrupted series

- Leaving or closing the game before the series is complete abandons that series.
- An abandoned series grants no chest and no completed-series coins or experience, and is not restored
  on relaunch. Any per-answer fact-milestone bonus already earned and saved remains on the device.
- Mastery changes from answers already processed remain saved locally; only unfinished-series state
  and its pending reward are discarded.
- The next press of Play starts a new series from the beginning.

## Presentation and accessibility

- Use **Baloo 2** as the primary game typeface, with a Noto Sans fallback for glyph coverage.
- Touch targets are at least 48 px and primary actions at least 64 px high.
- Sound and vibration reinforce actions but are never required to understand the state.
- The game remains usable with touch on Android and mobile Web, and mouse/keyboard on Windows and
  desktop Web.
- No feature depends on connectivity, accounts, advertisements, analytics, or cloud services.
