# Numblop Decision Log

## 2026-08-12 — Save version 10: durability and a coin ledger, before any networking

Play Games Services is approved in scope — sign-in, cloud saves, and both leaderboards (total XP and
best streak) — in the order local hardening → authentication → cloud save → achievements →
leaderboards. This entry covers the first of those, which contains no networking at all and ships as
an ordinary offline release.

- **Leaderboards are in scope and built last.** If Families or privacy review objects, they are
  dropped from the release rather than redesigned. Nothing before them references them, so dropping
  them costs two Play Console entries and two calls. Cloud save is the phase players actually feel,
  so it comes before achievements — a change from the first draft of the plan.
- **The coin ledger is built now rather than later.** A balance cannot be merged: two devices that
  each earn 100 coins and each buy a different hat both read zero, and nothing in those numbers says
  the child owns two hats. `earned_rounds` and `earned_milestones` are stored and monotonic;
  achievement earnings and cosmetic spending are **derived** from the granted and owned sets, because
  those sets union cleanly and a stored total would be a second source for the same number with
  nothing keeping the two in step. Deferring this would have meant a second migration over live
  player data.
- **The back-fill reproduces every existing balance exactly.** Everything not derivable is attributed
  to rounds; the split between rounds and milestones is unrecoverable after the fact and only the sum
  is ever used. A test asserts the rebuilt ledger implies the balance the save already had.
- **Writes are now atomic.** `FileAccess.WRITE` truncates on open, so a process killed mid-write left
  a half file that parsed as nothing and loaded as a brand-new profile. Writes go to a temporary file
  and land through two atomic renames, with the previous save kept as `profile.json.bak`. Loading
  falls through to the backup, which also covers a crash between the two renames. This was worth
  doing on its own merits — cloud save only raised the stakes.
- **`version` is finally read.** `SaveMigration` is a real ordered step, guarded by the fields it
  produces rather than by the version alone, so re-running it is a no-op. That guard matters because
  an older build round-trips a newer save and stamps its own version on the way out.
- **Unknown top-level fields are preserved across a save**, so a downgrade — or an older device
  handling a newer cloud snapshot — cannot silently delete what it does not understand.
- **`save_counter` is the merge ordering signal, not the clock.** A child's tablet clock can be wrong
  by years, and the failure mode of trusting it is total: the wrong device would win every merge
  permanently. `updated_at_unix` is recorded but is only ever a tie-breaker of last resort.
- **No `device_id` field was added**, contrary to the first draft of the plan. `profile_id` already
  is this device's pseudonym; storing it twice would be a second thing to keep in step. The snapshot
  payload carries it under that name instead.
- **The `cloud` block is written now while inert**, so switching synchronisation on later needs no
  second migration over live saves.
- **Tests clear the backup, not just the profile.** `SaveManager.delete_profile()` exists partly for
  that: without it one case could recover another's save through the fallback, and the suite would
  quietly become order-dependent.
- **Documented, not fixed: `profile_id` survives a profile reset.** The reset writes over the file
  rather than deleting it, and an id is only generated when none is found.
  [`adr/0001`](adr/0001-teacher-classroom-mode.md) assumes a reset produces a new pseudonym; it does
  not. Changing that is a deliberate decision, not a silent correction, so today's behavior is
  recorded in `SAVE_SYSTEM.md` along with the one-line change that would alter it.

## 2026-08-12 — Documentation reconciled against the code, and a Play Games plan

A full audit of every document against the shipped `0.4.1` build. The code was not changed; the
documents were, because the code is what players actually run.

- **The code is now source of truth #1** in `AGENTS.md`, above `GAME_DESIGN.md`. A document that
  disagrees with shipped behavior is a documentation bug, and fixing it belongs in the same change
  that caused the drift. The exception stays explicit: code that contradicts
  `didactic_algorithm.md` or a decision entry is a real bug, not a licence to rewrite the rule.
- **`SAVE_SYSTEM.md` is new** and is the only place the persisted schema is written out.
  `ARCHITECTURE.md` had been carrying a save-contract JSON block frozen at version 6 while the code
  had moved to 9; duplicating a schema in a document that is not about persistence is what let it
  rot for three versions. `ARCHITECTURE.md` now links instead of restating.
- **Field-tolerant loading is documented as the actual migration mechanism.** `version` is written
  on every save and never read; compatibility comes from each `Local*` model defaulting whatever it
  does not find. That is fine for adding fields and unsafe for renaming them, and the distinction is
  now written down rather than inferred.
- **The known persistence gap is recorded rather than quietly fixed:** there is no atomic write and
  no backup copy, so a process killed mid-write can truncate `profile.json` into a fresh profile.
  Closing it is scoped to the cloud-save work, where a second copy exists anyway.
- **Ten languages, not two.** `AGENTS.md`, `CLAUDE.md`, `LOCALIZATION.md`, and `README.md` all still
  said English and Czech. Responsive captures deliberately stay bilingual; the other eight are
  covered by catalog tests, and that is now stated instead of implied.
- **`ROADMAP.md` was re-scored.** M1 was marked todo while its loop had shipped; M2 and M3 were
  marked partial while their build-side work was complete. The genuinely open items — a usability
  pass with a real child, a threshold review from play evidence, and the manual release execution in
  `D18` — are the only things still open, and they are open because they need people, not code.
- **`TASKS.md` is reframed as a historical ledger** with the two open items lifted to the top. It
  records what each track built, not what the game does; several of its entries name save versions
  and catalogs that have since been superseded.
- **`docs/mockup_*.png` were deleted.** Byte-identical duplicates of `assets/mockup_*.png`,
  referenced by no document, and `docs/` is the GitHub Pages root, so they were 4.7 MB of stale
  concept art published next to the privacy policy.
- **`GOOGLE_PLAY_GAMES.md` is new and is a plan, not an implementation.** It is deliberately
  written against the offline contract rather than around it: the `INTERNET` permission, the
  data-safety declaration, and the privacy policy all have to change together, and the Families
  policy makes a child-directed app the hardest case rather than the easiest. Nothing is built until
  an offline release has shipped and a decision entry approves the milestone.

## 2026-08-06 — One header shape, still four scenes

Cosmetics is the reference top bar: a `SafeArea/Content/Header` PanelContainer on
`ui/styles/header_panel.tres`, no fixed height, title at font 22, and a leading/trailing pair of
expanding spacers that optically centre it. Map, Trophy, Settings and Home now match it, and every
title card measures 52 px.

- **The headers were not extracted into a `HeaderBar.tscn` component.** `unique_name_in_owner`
  resolves against the node's owner, so moving `%TitleLabel` into an instanced sub-scene silently
  breaks the binding on all four screens and forces a property API plus four `_refresh_text()`
  rewrites. The interiors also still differ legitimately — a coin pill on Cosmetics, a crest on
  Trophy, nothing on Map and Settings. `tests/ui/test_main_scene.gd` pays for that choice with
  `test_screen_titles_share_one_size_and_face`, which pins the shared size and face directly.
- **Secondary prose gets its own bubble** rather than a second line inside the title card: Map's
  description moved to `Content/Subheader`, and Settings' version line to `Content/VersionBar`
  below the settings card. Settings lost its subtitle entirely, and `SETTINGS_SUBTITLE` was
  removed from `localization/strings.csv`.
- **Home keeps its own `StatPanel` stylebox.** It is chrome (white, bordered, cool shadow), not a
  title card, and Trophy's cream `SummaryPanel` is likewise a deliberate warm register. Both took
  `header_panel.tres`'s geometry — radius 22, 12/8 padding, shadow 6 — so only colour differs.
  Home's fixed 66 px minimum is gone; its padding is 10.5 rather than 8 purely so the intrinsic
  height lands on the same 52 px as the title cards.

## 2026-08-05 — Longer rounds and scheduled automated review

Supersedes the "exactly 10 questions" and "7 current / 2 older weak / 1 older automated" points
recorded on 2026-08-01.

- Series length now depends on the table being learned: 10 questions up to the 5x table, 12 from
  the 6x table onwards. Both extra slots go to review, giving 8 current / 3 older weak /
  1 older automated. The later tables have more history to keep warm, and the current-table quota
  grows only by one.
- For review purposes a fact counts as automated only at mastery 100. The 90-to-99 band stays in
  the older-weak pool. This is deliberately distinct from `AUTOMATED_MASTERY` (90), which decides
  whether a question is answered by typing rather than how often the fact returns.
- The automated slot no longer selects by mastery. Every candidate sits at 100, so mastery cannot
  rank them and the choice collapsed to the seed, which let individual facts go unvisited for long
  stretches. It now always takes the fact with the oldest `last_practiced` stamp, so the automated
  pool is cycled through continuously.
- `LearningProfile` gained a `last_practiced` stamp per fact and the save format moved to
  version 2. Version 1 saves load with every stamp at zero, which reads as "longest waiting" and
  puts those facts at the front of the review rotation.
- `scripts/core/` still reads no clock. `SessionController` supplies the timestamp, and accepts an
  injected clock so the ordering stays testable.
- Session length is no longer a single global constant: `SessionResult` validates against its own
  question count, and the practice UI already took its total from the generated series.

## 2026-08-01 — Product and platform baseline

- Public product name is `Numblop`; “Násobilkový kamarád” was mockup placeholder text.
- Permanent Android package ID is `cz.gutcloud.numblop`.
- Android is portrait-locked; Windows uses a centered portrait window.
- MVP has one local child profile and no accounts, analytics, advertisements, cloud,
  or networking. (Originally unnamed; the 2026-08-02 optional-nickname decision below adds an
  optional local nickname.)
- English and Czech ship together from the first playable version.
- Godot 4.6.2 and GL Compatibility are pinned for the initial vertical slice because that exact
  editor, SDK, and template combination has been export-tested locally.

## 2026-08-01 — Learning ambiguities resolved

- Unlocked tables never relock.
- Missing review slots are filled from the current table so every session keeps its full length.
  (Superseded 2026-08-05: length is 10 up to the 5x table and 12 from the 6x table onwards.)
- The same fact never appears twice in immediate succession.
- Response time is measured for mastery but no visible countdown is shown.
- Ordered table facts are stored separately in MVP (`2 × 3` and `3 × 2` have separate mastery).

## 2026-08-01 — MVP game loop

- A series has exactly 10 questions: 7 current-table, 2 older weak, and 1 older automated
  review question. Selection within those groups remains adaptive.
  (Superseded 2026-08-05 from the 6x table onwards: 12 questions as 8 / 3 / 1.)
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
  (From 2026-08-05 a twelve-question series ranges 1–12; the reward is one per correct answer and
  was never capped at 10, so no rule changed here.)
- Rewards remain separate from mastery. Incorrect answers affect the documented mastery delta,
  while coins and experience never unlock a multiplication table.

## 2026-08-02 — Unique facts within a series

- A series prefers unused eligible facts before repeating any fact. This prevents two
  equally weak facts from alternating through the entire series.
- Repetition remains valid only when a required current/older-weak/older-automated pool is
  too small. The quota and lowest-mastery priority remain unchanged.
  (From 2026-08-05 the automated slot orders by longest wait rather than by mastery.)

## 2026-08-02 — Cosmetics shop preview dock and category tabs

- Supersedes "Outfit opens a compact Cosmetics shop without showing Numblop" in the *First Cosmetics
  vertical slice* decision below. The shop now shows a 140px non-interactive Numblop in a fixed
  bottom dock. Home remains the only place Numblop can be petted.
- The four categories are tabs and one grid is visible at a time. Body color opens first.
- Tapping an item only previews it. The preview is the equipped outfit with the tapped item
  substituted, built as a throwaway dictionary and never written to `AppState`. The dock's single
  action button reads Buy, Wear, or Worn, and body colors use their own verb pair because the Czech
  "nasadit" suits accessories but not a color.
- Locked artwork is dimmed to 62% alpha and the lock moves to a corner badge instead of covering the
  item. Accessory cards grow from 58px to 96px, and hats, glasses, and necklaces use three columns so
  the artwork is large enough to identify before buying.
- `BlobCharacter` gains an exported `preview_mode` that suppresses petting, the giggle sound, and the
  52px hearts while keeping the idle and blink animations.

## 2026-08-02 — First Cosmetics vertical slice

- Outfit opens a compact Cosmetics shop without showing Numblop. Green is free; blue, pink, purple,
  and orange body colors cost 100 coins each and fit in one row.
- Tapping a locked item selects it for a separate Buy action; a successful atomic save deducts
  coins, unlocks and equips the item, and updates the home Numblop.
- A palette shader recolors the existing body, arms, and legs, so body-color variants require no
  duplicated PNG files. The belly, face, cheeks, and black outlines retain their source colors.
- The supplied hats (four at first, later joined by the dino and pirate hats), three pairs of
  glasses, and three necklaces join the shop at 100 coins
  each. They use rounded square cards with transparent crests, small borderless selected checks,
  the supplied lock icon, and a compact `100` plus coin crest price. A free empty card removes each
  category. The 768px accessory canvas is positioned at −128px horizontally and −175px vertically
  relative to the 512px character canvas rather than being shrunk, preserving its authored
  alignment. The duck necklace's isolated source pixels above the artwork are clipped at render
  time. Future patterns and shoes follow this contract.

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
  This original all-ten unlock rule is superseded by the 2026-08-02 nine-of-ten decision below.
- Crossing the ninth mastery gate emits a table-unlocked domain event. After the reward reveal,
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
- Aggregate progress remains capped at 80 per fact. The original all-ten completion display is
  superseded by the nine-of-ten gate below.
- The winding trail uses a centered 350px content canvas. Wider portrait windows retain balanced
  margins instead of stretching the island path and status cards apart.

## 2026-08-02 — Nine-of-ten island gate and mastery colors

- The next island unlocks when at least 9 of the current table's 10 facts reach 80 mastery. Eight
  ready facts are insufficient. Unlocks remain permanent, and the remaining weak fact continues
  to appear in older-fact review.
- A completed island presents 100% in the overview while its detail keeps every fact's real 0–100
  value. Before the ninth fact crosses 80, the overview percentage remains capped at 99%.
- Fact-detail colors follow a red, yellow, gold, green learning progression. `Mastered` / `Upevněno`
  is orange-gold, while `Automatic` / `Automatizováno` is green.

## 2026-08-02 — Fact mastery milestone celebration

- This decision supersedes the fact-detail color and Czech labels immediately above. The four
  bands are red/purple/orange/green and their Czech names are `Objevuji`, `Procvičuji`,
  `Upevňuji`, and `Mám jistotu`. English labels remain unchanged.
- A correct answer that crosses upward into the existing 60, 80, or 90 mastery band grants an
  immediate 5-coin bonus. It grants no experience and never changes mastery, question selection,
  or unlocking.
- AppState detects the transition and applies the coin bonus before the existing per-answer atomic
  save. Practice feedback names the fact and new band and plays level-up followed by coin SFX.
- Milestone feedback remains visible for 3.6 seconds and can be dismissed early with a tap anywhere
  on its overlay. Ordinary correct-answer timing and incorrect-answer confirmation remain unchanged.
- Its content is deliberately terse: localized Success title, a bold fact at 1.5 times that title's
  size, the localized mastery-band name alone, and the 5-coin reward beneath it.
- The milestone bonus is separate from the 1–10 coin/experience completed-series chest. Leaving an
  unfinished series forfeits only that chest; already processed mastery and milestone coins remain.

## 2026-08-02 — Responsive exit confirmation

- Settings uses a themed in-game exit overlay instead of the platform `ConfirmationDialog`.
- Its two 54px actions stack below 420px screen width and sit side by side on wider portraits.
- Tapping outside, pressing Cancel, Escape, or Android Back closes the overlay without leaving
  Settings. Confirming still flushes audio preferences before emitting the game-exit request.

## 2026-08-02 — Web-safe UI symbols and yellow body color

- Checkmarks in Settings and the numeric keypad use the same vector-drawn geometry as selected
  Cosmetics items, and the keypad delete arrow is also drawn. Map-detail legend dots use rounded
  style boxes. These controls no longer depend on optional Unicode glyphs in the Web font renderer.
- Yellow is the sixth body color and follows the existing 100-coin purchase, equip, and local-save
  contract. Six 48px color targets remain centered in one compact row.

## 2026-08-02 — Adaptive Web export

- Web is a static secondary build of the same game, with no backend, analytics, remote
  configuration, or gameplay networking. PWA support is deferred beyond M1.
- The exported canvas follows the browser viewport. A 390×844 phone remains the compact reference;
  900×900 is the wide desktop reference, at least twice the original development width. Responsive
  containers consume the extra horizontal room while focused content stays centered.
- M1 uses Godot's threadless Web template with the Compatibility renderer. This keeps ordinary
  static hosting simple and avoids cross-origin-isolation requirements while retaining sample
  audio support.
- Web saves remain in browser storage for the deployment origin. Clearing site data or moving the
  build to a different origin starts a new local profile; no account or cloud migration is added.

## 2026-08-02 — Belly color row in the Cosmetics color tab

- The Colors tab gains a second labeled swatch row for the belly. The original cream belly is
  free and default; six pastel shades derived from the body palette cost the standard 100 coins
  each and follow the existing purchase/equip/local-save contract.
- Rendering reuses the body-color shader with a second mask: the bright low-saturation belly
  region is multiplied toward the chosen pastel, preserving painted shading. The cream default
  applies zero strength, leaving the original artwork untouched.
- Persistence adds `unlocked_belly_colors` / `selected_belly_color` to the cosmetics dictionary
  inside save v7; older saves default to cream without migration.

## 2026-08-02 — Baloo 2 replaces Fredoka as the primary typeface

- Baloo 2 (variable, Google Fonts, SIL OFL 1.1) is the primary UI font, keeping the existing
  Noto Sans fallback and the 0.8-embolden bold variation. Fredoka is removed from the bundle.
- The resource structure is unchanged: `ui/fonts/Baloo2WithCzechFallback.tres` is the theme
  default font and `ui/fonts/Baloo2Bold.tres` is the bold variant referenced by scenes.
- Czech glyph coverage remains pinned by the theme test.

## 2026-08-02 — Optional local nickname and stable profile id

- This supersedes the "unnamed" wording of the product baseline: the single local child profile
  may carry an optional nickname. There are still no accounts, analytics, cloud, or networking.
- The nickname is free text typed by the child, sanitized in the application layer (trimmed,
  control characters removed, at most 16 characters), and stored only inside `user://profile.json`.
- An empty nickname is valid and shows the localized `HOME_PROFILE` fallback on Home. Clearing
  the name returns to the fallback; the profile reset also clears it.
- Save version 7 adds the `nickname` field plus a random, never-displayed `profile_id` (32 hex
  characters, generated once on first v7 save and preserved forever). The id exists solely so a
  future classroom feature (see `docs/adr/0001-teacher-classroom-mode.md`) has a stable local
  pseudonym; nothing in the MVP reads it beyond persistence.
- Android device backup is enabled (`user_data_backup/allow=true`), so the profile — including
  the nickname — survives device migration through the user's own Google backup. Data still
  never reaches any Numblop or third-party service.

## 2026-08-02 — Achievements, retroactive rewards, and the end-of-round mastery summary

- The Trophy tab shows only the highest completed streak at the top; the timestamped milestone
  history is removed and the rest of the screen is the achievement list. This supersedes the
  Trophy milestone-history presentation described above; `LocalStreak.milestones` is still
  persisted, it is simply no longer displayed.
- The catalog is fixed: First Steps (finish one round, 100 coins), Streak 10/20/50/100 (coins
  equal to the streak target), and one island achievement per multiplication table (50 coins).
  Superseded on 2026-08-05: the streak ladder runs to 1000 and its payout is capped at 50 coins.
- An island achievement completes only when every one of its ten facts reaches mastery 100. This
  is deliberately stricter than the map's progress bar, which fills at the unlock threshold 80.
- A streak achievement completes the moment the streak is reached. It does not have to be ended
  by a mistake, so it uses `max(all_time_high, current_count)` while the Trophy header keeps
  showing the completed record.
- Every achievement reward is granted exactly once. `LocalAchievements.granted` is the single
  guard, and a grant only counts after the save succeeds; a failed write is rolled back and
  retried on the next evaluation.
- Achievements are evaluated retroactively when a save loads. Saves written before save v8 have
  no session counter, so any stored experience proves at least one finished round. Retroactive
  grants pay their coins silently — the player never triggered that celebration.
- Save version 8 adds `achievements` and `completed_sessions`. Both use an explicit null sentinel
  in `SaveManager.save_game_state` because an empty grant set and a zero session count are
  meaningful values rather than "reload from disk".
- There is exactly one treasure chest in the game, on the end-of-round reward screen, and it is
  the central element of a single unified page. Opening it reveals everything step by step in
  place: mastery gains above the chest, then the itemized coin rewards below it. Achievements
  unlocked by the round are part of that one reveal — there is no separate celebration screen.
  A UI test enforces the single-chest rule across every screen.
- The space above the chest lists every fact whose mastery rose during the round (previous value,
  new value, and amount gained), taken from the session's real answer audit and not from the
  score. Ties break by table then multiplier so the list is deterministic; three rows are visible
  and the rest scroll.
- The space below the chest itemizes the coins earned: the round reward, the mastery bonus when
  any band was crossed, one named line per achievement unlocked, and the total, which always
  equals the sum of those lines. The wallet total walks back the full payout, because bonus and
  achievement coins were already banked as they were earned.
- Achievements unlocked during an abandoned round stay queued and are presented with the next
  finished round, so every unlock is announced exactly once and never mid-question.
- The finished page is held for eight seconds so a child can read it, and a tap anywhere skips
  the remaining wait. The skip surface is invisible and only becomes active once the reveal is
  complete; returning home can happen only once.

## 2026-08-02 — Visual correction moment after a wrong answer

- Every incorrect answer now shows a domino-style dot picture of the fact under the complete
  equation. This extends the wrong-answer rule in `GAME_DESIGN.md`, which previously promised only
  the equation.
- The picture is not gated by mastery. It only ever appears after a mistake, which is precisely
  when help is wanted, and one rule keeps the feedback predictable for a child.
- A fact is drawn as `min(table, multiplier)` groups of `max(table, multiplier)` dots: `3 × 4` is
  three groups of four, `7 × 4` is four groups of seven. The smaller factor is chosen as the group
  count for readability; this commutes some facts on purpose.
- Counts 1–6 use die faces. Counts 7–9 use the domino split `5 + remainder` on a 2:1 wide card
  with a divider. The wide aspect was chosen because it is the only one that fits three columns
  inside the 288 px usable width of the feedback panel.
- `× 0` draws one empty frame with a dedicated sentence rather than nothing at all, so the reveal
  always has exactly one card to time against.
- Both the decomposition and the layout solver live in `scripts/core/DotVisualization.gd`. Keeping
  the solver in core makes "every one of the 80 facts fits 288×200 without overlapping" an
  exhaustive headless unit test instead of something only a real layout pass could catch. The
  drawn control owns nothing but colour and `_draw`.
- The tap gate is preserved, but the continue control is withheld until the 1.2-second reveal
  finishes, so a fast tap can no longer skip the explanation. After that there is no time limit.
- `PracticeScreen._present_answer_feedback` stays synchronous and produces the fully revealed
  state; `show_answer_feedback` rewinds and animates it. Captures and contract tests therefore get
  a deterministic picture with no settle wait.
- The reveal races its tween against `feedback_gate`, mirroring the milestone wait. `Tween.kill()`
  never emits `finished`, so awaiting the tween alone would hang `Main._on_answer_submitted`
  forever when a session is interrupted mid-reveal.
- The correction is presentation only and cannot add a question, change mastery, count as an
  attempt, or affect the streak: all scoring completes before the presentation await.

## 2026-08-04 — One-time guided finger tutorial

- A new profile is walked through the whole loop once by a pointing finger: Play, the correct
  answer on the first question, the reward chest, the Cosmetics crest, the Hats tab, the first
  hat, Buy, Home, Play again, the Map crest after the next completed round, and the open island.
  Then it marks itself completed and never runs again.
- The overlay ignores input. Nothing is gated, dimmed, or blocked; a child who ignores the finger
  plays the game normally. The finger is guidance, not a modal.
- Steps advance on state the app already publishes -- a started session, a correct answer, a
  visible screen, an owned hat, a completed round -- never on a timer and never on a tap the
  tutorial itself intercepted. A step whose target is off screen simply hides the finger, which
  is what covers the eight questions between the first answer and the chest, and the whole
  second round.
- Because a step ends on an outcome rather than on a tap, leaving a round early puts the finger
  back on Play instead of skipping ahead, and answering wrongly keeps it on the correct answer of
  the next question.
- The buy step also ends if the hat has become unaffordable, so a child who spent their coins
  elsewhere is never left with a finger on a permanently disabled button. On the intended path
  the First Steps achievement pays 100 coins with the first round, which covers the hat.
- Save v9 stores `{completed, step}`. The step is kept so closing the game mid-tutorial resumes
  on the same control; only `completed` decides whether the tutorial ever runs again.
- A save written before v9 that already has completed rounds counts as onboarded. That child
  knows the game, and the flag is only adopted in memory, so booting an old profile never writes
  to it. Resetting the local profile replays the tutorial.
- The whole sequence lives in `scripts/ui/OnboardingTutorial.gd`. Screens expose only what it
  points at (`correct_answer_control`, `item_card`, `previewed_item`, `stage_button`), so the
  tutorial is one readable file rather than eleven flags threaded through five screens.

## 2026-08-04 — Cosmetics color page no longer overflows the readable column

- Seven 48 px belly swatches in one row are 348 px wide. A hidden page contributes no minimum
  width, so this only bit when the color tab was open -- and then pushed the header, tab bar,
  dock and footer out past both display edges at 390 px. Belly shades now wrap at four columns
  and the body-color row uses a 2 px separation.
- The color tab's icon is a generated palette. `expand_icon` scales an icon until it fills the
  tab, so an image made only of color went edge to edge while the four artwork tabs kept their
  own empty space. The generated image now carries a transparent border of its own.

## 2026-08-04 — Drag anywhere to scroll, and no scrollbars

- `gui/common/default_scroll_deadzone` alone never fixed touch scrolling. A pressed control
  keeps the gesture for as long as the finger is down, so a drag that began on an island, a
  card, a swatch or a slider was delivered to that control and the page did not move -- and
  those controls cover most of Map, Trophy, Settings, Cosmetics and the reward summary.
- `scripts/ui/TouchScrollContainer.gd` watches the gesture in `_input`, which runs before the
  pressed control's own handling, and takes it over once the finger passes the deadzone. The
  child's press is then *canceled* rather than released, exactly as a native list does: the
  control stops looking held and never fires.
- Below the deadzone nothing is intercepted, so a short tap still activates whatever is under
  it. Lifting the finger after a drag is swallowed too, so the release cannot land as a tap on
  whatever scrolled under it.
- Releasing mid-drag throws the page with a short coast. Speed comes from the last motion, so a
  slow drag stops where it was let go and a flick keeps going.
- Scrollbars are hidden (`SCROLL_MODE_SHOW_NEVER`) now that the whole page is the scroll
  handle. Nothing else changed size; the panels keep the gutter they already had.
- The test runner now awaits each test, so a gesture can be exercised over real frames through
  the real input pipeline rather than by poking the component's internals. `_process` returns
  false while the suite runs, because returning true ends the main loop and a test that spans
  frames would never resume.

## 2026-08-04 — Petting is a stroke, not a tap

- Numblop reacts to a gentle rub across him, not to a tap. A tap was enough before, so every
  accidental touch on the way to the Play button set him off, and the gesture taught nothing
  about petting an animal.
- The trigger is 44 px of travel *along the path*, so rubbing back and forth over one spot
  counts as much as one sweep across. That is far enough that the jitter inside a tap can never
  reach it, and short enough for a small hand.
- Stroking keeps working for as long as the finger is down: one reaction per stroke length.
  The hearts drift the way the hand was moving.
- The home hint now says to stroke him in both languages. A preview avatar stays untouchable.
- Stroking draws its voice at random from the giggle and the two “wee” cheers, never repeating
  the same clip twice in a row, with a touch of pitch variation. One clip cannot carry a gesture
  a child repeats; the node is now `PetVoicePlayer` rather than `GigglePlayer`, because it is no
  longer one sound.
- A reaction that arrives while he is still speaking is silent rather than restarting the clip.
  Reactions come every few hundred milliseconds under a continuous stroke, which is faster than
  a clip finishes, and restarting on each one chopped the giggle into a stutter. The visual
  reaction still plays; only the voice waits its turn.

## 2026-08-05 — XP achievement tier

- The catalog gains four XP achievements: 500, 1000, 5000 and 10000, each paying 50 coins. A 100
  XP tier was cut: ten rounds reach it, which is too little to be worth a trophy.
- XP is the lifetime count of correctly answered questions. A finished round grants one point of
  experience per correct answer (`LocalProgress.apply_completed_session`), so `progress.experience`
  is that count and no separate counter is stored. The one-point minimum for a round without a
  single correct answer is the only place the two differ, and it errs in the child's favour.
- Progress is therefore retroactive for free: an existing save already carries the experience, so
  the tiers a child has passed are granted the moment the save loads, like every other achievement.

## 2026-08-05 — Collection achievements, one per cosmetic category

- Six collection achievements, 50 coins each: body colors, belly colors, hats, glasses,
  necklaces and shoes. A collection completes when every *paid* item of its category is owned;
  the free default item of each category is not part of the count, so a fresh profile starts
  every collection at zero.
- `AchievementCatalog.COLLECTION_TARGETS` restates the paid item count per category rather than
  reading `CosmeticCatalog`, which lives in the app layer. The core stays free of app
  dependencies, and a state test pins the two lists together, so adding a cosmetic fails the
  suite until the target is bumped deliberately — an added item changes what the achievement is
  worth earning, and that should never happen silently.
- The shop grants collection rewards the moment the last item is bought: `purchase_cosmetic`
  ends with `sync_achievements()`. The coins land immediately, while the unlock is announced with
  the next finished round, which is the queueing rule every other achievement already follows.

## 2026-08-05 — Longer streak ladder, capped payout

- Streak achievements now run 10/20/50/100/500/1000. The two new rungs give the flame somewhere
  to go long after the tables are mastered.
- The reward is `min(target, 50)`, so 10/20/50 still pay their own length while 100 and above all
  pay 50. Paying one coin per answer would have made a single lucky run worth ten shop items,
  which is more than a whole cosmetic collection is worth.
- Streak 100 therefore drops from 100 coins to 50. Anyone who already claimed it keeps the 100
  they were paid: a reward is granted once, and the granted set never re-evaluates the amount.

## 2026-08-05 — Haptics: three moments, one switch

- Vibration is reserved for three moments and nothing else: the chest tap (25 ms at amplitude
  0.5), the chest opening (90 ms at 1.0) and the mastery-milestone cheer (80 ms at 0.8). The
  opening is the strongest buzz in the game, because it is the payoff of the whole round.
  *(Durations superseded — all three were doubled to 50 / 180 / 160 ms after they read as a faint
  click on real hardware. Amplitudes are unchanged. `SettingsManager.HAPTIC_PATTERNS` is the
  current value.)*
- Amplitude, not duration, is what makes a buzz noticeable. The previous single call was
  `vibrate_handheld(35)` at the device default strength, which on a modern LRA phone is a tick
  a child does not register. Nothing runs below 20 ms, because several Android vendors drop
  shorter pulses entirely. Amplitude needs API 26, so Android 24 and 25 fall back to the default
  strength on their own — a graceful degrade that needs no guard.
- A wrong answer never buzzes. A buzz on failure reads as a physical scolding, and vibration is
  documented as reinforcement that is never required to understand a state. Correct answers do
  not buzz either: ten per round would turn the phone into a pager and drain a battery a child
  uses daily.
- `SettingsManager.play_haptic` is the only caller of `Input.vibrate_handheld`, so the Settings
  toggle cannot be bypassed by a new call site. Settings stores it under `haptics/enabled` and it
  defaults to on; switching it on plays the tap pattern so the child feels what they enabled.
