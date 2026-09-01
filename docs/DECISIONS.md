# Numblop Decision Log

## 2026-08-30 — Completed tables open a separate permanent free-practice loop

- **Table eligibility means permanently completed, not all facts saturated.** The same nine-of-ten
  facts at 80 gate that advances progression makes that table practice-eligible forever. The stricter
  all-ten-at-100 island achievement remains an achievement rule only.
- Earlier completion is already represented by `highest_unlocked_index`. The final table has no next
  index, and its map completion used to be re-derived from live mastery, so save v11 adds only
  `final_table_completed`. It is derived for legacy saves, never cleared by mastery loss, and merged
  with logical OR. No session setup, error counter, or analytics data is persisted.
- **Free practice never enters `SessionGenerator`.** `FreePracticeGenerator` owns its 10, 20, 30,
  40, and 50-question schedules. Explicit tables use seeded round-robin so no selected table
  dominates. Empty selection is a real smart-review mode over all eligible tables, using existing
  mastery plus repetition penalties; it creates no new weakness history.
- Question construction, mastery thresholds/deltas, per-answer saves, streaks, milestones,
  achievements, and the reward chest stay canonical. Sharing those mechanics does not make free
  practice a progression mix.
- Completing 9× permanently changes Home's action from Play to Practice. Home and completed-island
  detail entries both open with no selected table, so the initial Start action is smart review and
  never disabled. Players may explicitly select any combination of completed tables.
- The first-use question count is 10. Choosing a 10/20/30/40/50 length remembers it in
  `user://settings.cfg` for later setup visits on that device. It is not profile progress,
  cloud-save data, analytics, or additional learning history.
- Practice setup is a linked secondary page inside the standard header/body/footer shell. It keeps
  the five shared navigation destinations but highlights none of them; Practice is not a sixth tab.
  Header Back still restores the exact origin, including an open completed-table detail.

## 2026-08-15 — Play achievements are pushed, never waited on

- P3 is implemented. The 25 Console ids live in `scripts/autoload/PlayGamesCatalog.gd`, on the Play
  side of the isolation wall because `scripts/app/` may not name Play at all.
- **Unlocks go out immediately, mid-round included.** Cloud save defers to the end of a round
  because a snapshot merge replaces the in-memory profile and would interrupt the question on
  screen. An achievement push reads nothing back and writes nothing local, so that reason does not
  apply, and making a child wait to be told what they just did is a worse experience for no gain.
- **Steps are absolute rather than incremental.** `set_achievement_steps` keeps the higher value,
  so a fact that drops below mastery 100, or a reinstall whose cloud merge has not landed yet,
  cannot drag a Play progress bar backwards. `increment_achievement` would have made every retry
  and every duplicate event corrupt the count.
- Steps refresh on `session_ended` and on sign-in, not per answer: 25 network calls per tap is not
  a trade worth making on a child's device for progress-bar precision nobody is watching.
- **Sign-in backfills the whole state.** The expected case is a child who played offline for months
  before any account existed. It runs before the cloud-save handshake, because achievements need
  only the sign-in client.
- Everything is fire-and-forget — the plugin's reply signals are deliberately not connected. There
  is no failure here that a child should ever be told about, let alone blocked by.
- An achievement with no Console id is skipped rather than raised, so a build can add one before
  Console has it; a test is what stops that reaching a release.

## 2026-08-15 — Achievement art ships at the size each destination needs, and nowhere else

- 25 icons arrived as 1254 px squares, 51 MB in total. Left in `assets/` they would have been
  imported losslessly and exported: measured at 0.82× source, that is **+41 MB**, taking the AAB
  from 67 MB to about 108 MB. The trophy tile is 64 px.
- Three destinations, each already behaving the way this needs, so nothing new was invented:
  `store/achievements/` at 512×512 for Play Console (`store/.gdignore` hides it from Godot and
  `store/*` is in every preset's `exclude_filter`, yet it is tracked in git);
  `ui/achievements/` at 192×192 for `TrophyScreen`, which is 3× the tile and **1.76 MB** in the
  build; and `input/achievements/` for the originals, git-ignored and export-excluded already.
  A `.gdignore` was added to that one subfolder so 51 MB is never imported either.
- The originals stay out of git deliberately. Git history is permanent — 51 MB committed once is
  51 MB in every clone forever, even after a later delete.
- **The black backdrop is masked off.** Every icon is a round medallion inscribed in a square with
  pure-black corners. Composited unchanged it read as a black square with hard corners sitting on
  the rounded cream tile. `tools/resize-achievement-icons.ps1` cuts the inscribed circle at full
  resolution and only then downscales, so the rim is antialiased by the resample rather than left
  stair-stepped.
- Both sets are RGBA8. For Play Console that is a requirement, not a preference: it accepts a
  512×512 JPEG or a **32-bit** PNG, and 32-bit means RGBA8, so ffmpeg's `-pix_fmt rgba` is load
  bearing — an opaque source would otherwise encode as 24-bit and be rejected.
- `TrophyScreen.achievement_icon` resolves `res://ui/achievements/<id>.png` and falls back to the
  shared trophy crest when a file is missing, so an achievement can enter the catalog before its
  art is drawn. `tests/ui/test_trophy_screen.gd` pins that every catalog id has artwork, that it is
  192×192, and that no two achievements share a file.
- **The Play Console import is generated, not typed.** `tools/export-play-achievements.ps1` builds
  the ZIP of three CSVs plus icons from `AchievementCatalog` and `strings.csv`. Retyping 25 names
  and 225 localized rows into a web form would drift the first time a string is reworded, and there
  is no reason for Console to disagree with the game about what an achievement is called. Only the
  Play point values are editorial, and a test fails if a new achievement arrives without one.

## 2026-08-14 — The tutorial yields to a restored save, and shows the shop without selling

- **A reloaded profile ends the tutorial.** The overlay read `AppState.onboarding` once at boot,
  so a fresh install or a second device latched "not onboarded" while the cloud restore was still
  arriving, and walked a child who had already been taught through the whole loop again. It now
  re-reads that state on `EventBus.profile_reloaded`: completed ends the sequence, and a further
  saved step moves the finger forward. It never rewinds -- the merge already takes the further of
  the two devices' steps, and walking a child back to a control they have used teaches nothing.
- **The finger waits for a restore that could still cancel it.** `PlayGames` publishes
  `EventBus.external_restore_pending` while a remote comparison is outstanding, and the overlay
  holds the finger back on a profile that has played nothing and tapped nothing. The bus carries
  the fact alone, so the scene never names Play Games and the isolation rule in §5.5 of
  `GOOGLE_PLAY_GAMES.md` still holds. The flag is lowered as soon as the *download* half resolves:
  the upload that follows is this device's own data going out and cannot change what is on screen.
  Nothing is gated -- offline no comparison ever starts, and online the existing 15 s sync timeout
  bounds the wait. Only the finger is withheld; the game is fully playable throughout.
- **The shop is one step, and nothing has to be bought.** Hats tab and first hat are gone; the
  finger goes from the Outfit crest straight to the Buy button, and the step ends when the child
  buys anything or leaves the shop. Pointing at Buy is safe unconditionally because
  `CosmeticsScreen` keeps that button visible on every path.
- The affordability exit is dropped with them. Every paid item costs 100 coins and a first round
  pays roughly 10-30, so `coins < price` was true on the frame the step began -- the Buy button was
  never actually pointed at. With no purchase required and leaving always allowed, the step cannot
  dead-end, so the exit bought nothing but invisibility.
- `CosmeticsScreen.item_card` and `previewed_item` existed only for the two deleted steps and were
  removed with them. The screens still expose `correct_answer_control` and `stage_button`.
- The nine steps are: Play, the correct answer, the chest, the Cosmetics crest, Buy, Home, Play
  again, the Map crest after the next completed round, and the open island.

## 2026-08-13 - Cloud synchronization never applies a profile during practice

Hardware testing of code 16 exposed a lifecycle race rather than an Android crash. Every answer is
saved locally, and the cloud wrapper used every local-save event as a debounced sync trigger. A
snapshot request started on the home screen could therefore return after practice began; applying
its merge called `AppState.reload_profile_from_disk()`, which correctly discards an unfinished
runtime session and consequently sent the player home partway through a round.

Practice is now an explicit exclusion window for cloud work. Per-answer saves remain immediate and
authoritative, but their cloud requests coalesce until the session is settled. Purchases and other
saves made outside practice still synchronize normally. If an already-running snapshot load or
conflict response arrives during practice, it is discarded before any durable write or runtime
reload and retried after the round ends. App pause first abandons the runtime session, so its existing
best-effort sync remains safe. Three fake-client regressions cover the per-answer trigger, an
in-flight snapshot response, and an upload acknowledgement crossing into practice. The fix ships as
`0.4.5` / Play code `17`.

## 2026-08-13 — Hardware isolates cloud failure to Play App Signing OAuth

The Play-installed `0.4.4` / code 16 does request sign-in automatically, but Google rejects it before
Numblop receives an account: device logs explicitly report that the Android application is not
registered for OAuth 2.0, followed by `DEVELOPER_ERROR` and `User signed in: false`. Consequently no
player id, snapshot load, or snapshot upload is reached; the merge and Saved Games code remain
unexercised on hardware.

The certificate was extracted from the Play-delivered base APK rather than copied from a document:
package `cz.gutcloud.numblop`, Play App Signing SHA-1
`ED:48:7F:8E:CE:13:07:05:A1:6D:3E:45:70:F9:4A:B3:4F:BF:C1:B7`. The upload certificate is different
(`EB:D1:EA:96:87:CE:DA:41:05:9D:13:0B:CC:93:3D:E1:8A:63:72:DB`), as Play App Signing requires.
The release blocker is therefore Console configuration: create/select the Android OAuth client for
the Play package/fingerprint pair and link it as the PGS Android credential. No rebuild is required.

## 2026-08-13 — Cloud backup requests Play Games sign-in on startup

Hardware testing of code 15 confirmed that a fresh install still remained signed out until the
player found Settings. That makes reinstall recovery technically available but practically hidden,
which contradicts the default-on backup goal. The product decision is therefore to request Google
Play Games sign-in automatically once per Android launch whenever backup is enabled.

The request stays asynchronous and occurs after the game is interactive. Google and Family Link
remain the account gate; refusal, restriction, missing network, or missing account changes no local
gameplay and shows no Numblop error. The Settings tile remains both a manual retry and a persistent
opt-out. This supersedes only code 15's user-initiated-only trigger, not its visible status or dialog.
The change ships as `0.4.4` / Play code `16`.

## 2026-08-13 — Signed-out cloud backup gets an explicit recovery path

The first Play-installed hardware run exposed a gap that fake success-path tests could not: the
plugin's startup `is_authenticated()` check correctly returned false, but Numblop never followed it
with the separate interactive `sign_in()` operation. The lit cloud tile represented the enabled
preference, not a signed-in account, so no player id was loaded and no snapshot could be uploaded.

Numblop still does not force a Google dialog during startup. A signed-out tile now says **Sign in**
visibly, and pressing it opens the existing in-game overlay with two honest choices: **Sign in**
calls the plugin's interactive path, while **Turn off** persists the existing opt-out. Signed-in,
syncing, off, and needs-attention captions are likewise visible in all ten languages. The overlay
reuses the settings dialog and adds no height to the already-full card. Re-enabling a previously
disabled backup is itself an explicit action and therefore calls interactive sign-in directly.

This closes the UI/authentication gap without weakening the permanent offline contract: the dialog
is user-initiated, declining or failing changes no gameplay, and local progress remains authoritative.
The fix ships as `0.4.3` / Play code `15`; Play-track sign-in and reinstall recovery still require a
real-device pass before the Saved Games path is considered verified.

## 2026-08-13 — P2 fails closed at the plugin's unresolved-conflict boundary

The normal Saved Games path is implemented behind `PlayGames.gd`: a fixed snapshot is loaded after
sign-in, newer schemas are refused, two progressed saves get a durable `.premerge` parent, the pure
`CloudSaveMerge` result is written with a counter above both parents, `AppState` reloads through a
provider-neutral method, and upload is acknowledged only after an exact read-back. Local save and
application-pause events trigger the asynchronous work; gameplay never awaits it.

The plugin spike's statement that conflicts are exposed remains true, but exposure is not
resolution. Vendored v3.4.0 supplies the conflict id and both snapshots yet has no GDScript or
Android bridge for the Play Games `resolveConflict` operation. The current upstream source has the
same omission, and repository policy forbids a private edit to vendored code.

Therefore an SDK conflict is merged and saved locally, the pre-merge copy is retained, and further
uploads are blocked for that launch. Numblop will not call ordinary save on a still-conflicted
snapshot and risk silently replacing either candidate. Full cloud convergence is `C22`, blocked
until an upstream release provides the missing bridge and can be replaced wholesale. **The
server-side conflict remains unresolved, so the same player will encounter it again after every
launch and cloud backup is effectively unavailable until that bridge ships.** Settings does not
pretend the enabled backup is healthy: its fourth accessible state says that backup needs attention
and that progress remains safe on this device, in all ten languages.

An upload read-back mismatch is also fail-closed but not allowed to loop forever. Each mismatch is
reported, the merge-triggered immediate retry is suppressed, and later local saves may retry only
up to three consecutive failures per launch. The third failure blocks further uploads and selects
the same needs-attention state, protecting battery and mobile data while keeping local play intact.

The compliance half is also explicit: the bilingual privacy policy and a conservative Play Console
worksheet now describe Play Games processing and the cloud payload, and Settings links to the policy
in every shipped language. Enabling the public Pages URL and applying Data safety, Families,
target-audience, and content-rating answers remain authenticated manual release gates. No networking
build may enter a Play track before those gates close.

## 2026-08-13 — Cloud save on by default, and the plugin spike settles the integration

**The community plugin wins.** `godot-sdk-integrations/godot-play-game-services` v3.4.0 is vendored
unmodified at `addons/GodotPlayGameServices/` with its release hash recorded in `VENDORED.txt`. It
supports authentication and Saved Games, and the in-house Kotlin fallback was not needed.

The spike overturned three assumptions this repository had already built tooling around, which is
exactly what a spike is for:

- **It installs to `addons/`, not `android/plugins/`.** `addons/` is versioned, so the plugin is
  committed like source and needs no reinstall-every-export step. `tools/install-play-games-plugin.ps1`
  was **deleted**: the plugin's own `EditorExportPlugin` already injects the AAR, the Gradle
  dependencies and the manifest meta-data, and the script would have written a second, conflicting
  `game_services_project_id` string resource — a build failure waiting to happen.
- **The project id is an export option, not an environment variable.**
  `godot_play_game_services/game_id` on both Android presets. The leading-space workaround this
  document warned about does not apply, because the id reaches the manifest through `@string/`.
- **Saved Games expose conflicts natively.** `conflict_emitted(PlayGamesSnapshotConflict)` hands over
  both candidate snapshots, which is precisely the input `CloudSaveMerge` already takes. The merge
  written before any plugin existed turns out to plug straight in.

**Cloud save is now on by default and initialises automatically**, reversing the opt-in design from
earlier the same day. The reasoning that changed:

- The account decision is not Numblop's to make. Google, and Family Link for supervised children,
  already govern whether a child may sign in to Play Games at all. A second gate on top would be
  weaker than the one that already exists — a child who can find the Settings screen can pass an
  arithmetic parent gate in a multiplication game — while costing every honest player their backup.
- The problem worth solving is a lost phone taking a year of practice with it. An opt-in switch
  buried in Settings does not solve it for the children who most need it.
- `B35`, the parent gate, is therefore dropped rather than deferred.
- A missing `play_games/enabled` key reads as **on**, so existing installs get cloud save without
  anyone finding a switch. Turning it off is a deliberate act that survives restarts.

Unchanged by any of this: the data-safety declaration and privacy policy still have to be rewritten
before release, leaderboards are still the higher-risk surface and still last, and a failed sign-in
still has to cost a child nothing — which now has its own test that generates a full practice round
after authentication comes back false.

**The switch is a third tile, not a row.** A labelled row with a switch pushed *Close game* below
the fold of the settings card, and scrollbars are hidden, so a guardian would simply not have found
it. A third icon tile beside Sound and Vibration costs zero vertical space and is the language the
screen already speaks. The cloud glyph is a new SVG in `ui/icon/`, struck through when off, matching
how the other two tiles say "off".

The tile is lit by the **setting**, exactly like its siblings — a light that ignored the tap would
not be a switch. Whether Google actually signed the device in is reported by both the visible
one-line caption and the accessible name. A later hardware pass added an explicit sign-in choice
for the signed-out state; see the decision above.

**Two test-hygiene faults were found and fixed, both mine:**

- `tests/run_tests.gd` hung for the full 120-second timeout whenever any test file had a parse
  error, because a broken script still loads and only fails at `new()`. It now scores that as a
  failure and continues — which is how the next two were caught at all.
- **The suite was writing the player's real `settings.cfg`.** `SettingsManager.SETTINGS_PATH` is a
  constant, so every save path writes the file belonging to whoever is at the machine, and both a
  settings-screen debounce timer and `PlayGames.set_enabled` reach it. `NumblopTestCase` gained
  `preserve_settings_file` / `restore_settings_file`, and every case that touches settings now
  brackets itself. A run is verified byte-identical on the real file. The helper resolves the
  autoload by node path rather than by name, because `test_case.gd` compiles as a dependency of the
  runner before autoloads are registered.

**Also fixed here:** `SaveManager` parsed saves with `JSON.parse_string`, which pushes an *engine*
error on malformed input. A corrupt save is something that class handles, not an engine fault, so it
now uses a `JSON` instance and its own warning. That stops a corrupt profile filling a child's device
log — and stops the deliberate-corruption tests making `tools/run-tests.ps1` exit non-zero while
reporting every test passed, which it had been doing unnoticed for several rounds.

## 2026-08-13 — Numblop stops being an app that cannot reach the network

M5 is approved and P1 is built, so the "no networking" clause in `AGENTS.md` is retired and
replaced. Both Android presets now request `INTERNET` and `ACCESS_NETWORK_STATE`, and both build
through Gradle so the plugin can be linked. What replaces the old rule is narrower and stricter than
"no networking": **the game stays fully playable offline, signed out, and accountless, forever.**

- **`permissions/internet=false` was a deliberate tripwire, so it was replaced rather than
  deleted.** `test_project_contract.gd` now pins the two permissions that are wanted and asserts the
  absence of the ones that would be a Families-policy violation — advertising id, location, camera,
  microphone, contacts. The duty the old pin carried is carried forward, not dropped.
- **The SDK is not initialised until a guardian opts in.** The Play Games v2 SDK signs in
  automatically on `initialize()`, so initialising it for a child who never opted in would create an
  account association behind their back. The opt-in therefore gates initialisation itself, not just
  the calls after it, and that is the single most important assertion in `test_play_games.gd`.
- **The opt-in lives in `settings.cfg`, not the profile.** It describes the device and its guardian's
  choice, not the child's progress, so resetting a profile must not silently re-enable it.
- **`PlayGames.gd` is the only file in the repository that knows Play Games exists.** A test walks
  `scripts/core/`, `scripts/app/`, `scripts/ui/` and `scenes/` and fails if any of them so much as
  mentions it. Delete the autoload and the game still runs.
- **No plugin was chosen yet, and the code does not need one to be.** The wrapper looks for any of
  several singleton names and feature-detects the methods it calls; a plugin that is present but
  incomplete is treated as absent, which fails safe to offline rather than half-wired. Whichever
  route wins the spike — community plugin or in-house Kotlin — only has to satisfy
  `PlayGames.REQUIRED_METHODS`.
- **The Android Debug preset moved to a Gradle build** because a plugin cannot be linked without
  one, and a debug APK that cannot sign in is useless for testing this.
- **`tools/install-play-games-plugin.ps1` follows the `patch-android-template.ps1` pattern**, since
  `android/` is git-ignored and Godot regenerates it. It is a no-op until the plugin binaries are
  vendored, so exports keep working meanwhile, and it demands the project id only once a plugin is
  actually being linked — a missing id then would ship an app that dies on launch.
- **The project id goes in a string resource whose value keeps a leading space.** Without it the
  build tools parse the digits as a float and the app crashes at launch with an error that names
  none of this.
- **Unrelated but found the hard way:** `tests/run_tests.gd` used to hang for the full 120-second
  timeout when any test file had a parse error, because a broken script still loads and only fails
  at `new()`. It now scores that as a failure and continues.

## 2026-08-13 — The cloud merge, written before the cloud

`CloudSaveMerge` reconciles two saves of the same profile. It is pure and static, has no plugin,
network, clock, or file access, and exists in full before any Play API is called — because it is the
one piece of the cloud work that can silently destroy a childhood of practice, and it is entirely
provable on a laptop.

- **The governing rule is asymmetric on purpose:** never lose mastery, an owned item, an
  achievement, or a streak record; accept imprecision in the coin balance instead. A hat vanishing
  is a betrayal a child notices; being fifty coins short of the arithmetic sum is invisible.
- **Timestamps decide nothing on their own.** The base save is chosen by experience, then finished
  rounds, then `save_counter`, and only then the clock, with a stable `profile_id` comparison as the
  final tie-break. A tablet whose clock is a year fast would otherwise win every merge permanently
  and erase the other device — a total failure mode, not a degraded one.
- **The merge is commutative except for `profile_id` and `cloud`**, which describe the device rather
  than the player and always come from the local side. Both devices must otherwise compute the same
  state whichever way round they merge, or a two-device pair oscillates forever. A test compares the
  hashes of both directions.
- **The balance is recomputed, never carried or summed.** Two devices that each earned 400 and each
  bought a different 100-coin item end up owning both items with 200 coins, not 400 and not 600.
  That downward imprecision is the documented cost of never losing an item, and it is asserted by
  test rather than left as a hope.
- **An unlocked island never closes**, even when it arrives on the *losing* save and even when the
  fact that opened it has since decayed below the gate on both devices.
- **A finished tutorial on either device is finished.** Being walked through the basics again
  because the other phone had not caught up would read as the game forgetting the child.
- **The same streak length recorded twice keeps the earlier moment**, because that is the run that
  actually happened; two different lengths are two real records and both survive.
- **A merged save adopted onto a fresh device drops the other device's `profile_id` and `cloud`
  block** rather than importing them, so the new device generates its own identity on the next write.
- **Left for the cloud phase, deliberately:** the merged `save_counter` does not yet reach disk,
  because `SaveManager` derives the counter from the file already there. Wiring that now would mean
  adding a parameter for a phase that does not exist; it is recorded as `C20` instead.

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
  *(Superseded on 2026-08-14: the shop is now shown in one step and nothing has to be bought.)*
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
  *(Superseded on 2026-08-14: no affordability exit, because nothing has to be bought.)*
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
