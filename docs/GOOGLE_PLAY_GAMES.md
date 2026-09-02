# Google Play Games Services — Integration Plan

- **Status:** Approved in scope. P0, P0b, P1 code, and the normal P2 snapshot path are
  **implemented**. P1 still needs tester sign-in on hardware. Full P2 convergence is blocked because
  the vendored v3.4.0 plugin reports conflicts but exposes no conflict-resolution call.
- **Milestone:** M5.
- **Approval:** The 2026-08-13 decision entry approved the networking boundary. Android now requests
  only the connectivity permissions Play Games needs; offline, signed-out, accountless play remains
  permanent.
- **Not a prerequisite:** another Play upload. `0.4.0` / code `12` is already on the internal track,
  so the app entry exists and Play App Signing is enrolled — its SHA-1 is what the OAuth credential
  in §9 needs, and locally signed test builds are covered by the upload-key SHA-1 plus a testers
  list. Save version 10 and this integration are expected to ship in one release, so the privacy,
  data-safety, and Families paperwork happens once.

### Decisions taken (2026-08-12)

- **Both leaderboards are in scope** — total XP and highest streak. If Families or privacy review
  makes them problematic, they are dropped from the release rather than redesigned; the phase order
  below puts them last precisely so that dropping them costs nothing else.
- **Phase order is fixed** as: local save hardening → authentication → cloud save → achievements →
  leaderboards.
- **The coin ledger is implemented up front**, not deferred. A balance is known to be unmergeable,
  and adding the fix later would mean a second migration over live player data.
- **Privacy policy, Play Console data safety, and the Families declarations are updated before the
  first networking build ships**, not after.

The goal is that a child who loses or replaces a device gets their progress back, and that a child
who wants to can compare their XP and best streak with others. The constraint is that **nothing
about the offline experience may get worse**: a player who never signs in must not see a single
extra dialog, a single extra second of startup, or a single behavioural difference.

---

## 1. Read this first: Numblop is the hard case

Most Play Games integration guides assume an adult-audience game. Numblop is a child-directed app
that currently declares **no data collected at all**, and that shapes almost every decision below.

| Today | After integration |
|---|---|
| No `INTERNET` permission at all | `INTERNET` + `ACCESS_NETWORK_STATE` required |
| Data safety: "no data collected" | Must declare account identifiers and gameplay data |
| Privacy policy says the app "is technically unable to send anything off the device" | That sentence becomes false and must be rewritten **before** the build ships |
| No third-party SDKs | Google Play services games SDK linked in |
| Families policy: trivially compliant | Requires a deliberate review of sign-in and any social surface |

Three consequences that are not negotiable:

1. **The privacy policy and Play Console data-safety answers must be updated in the same release
   that first contains the networking build**, not afterwards. `docs/privacy/index.md` is public at
   the URL declared in the store listing and is currently explicit about the `INTERNET` permission.
2. **Nothing may ever be required to play.** No account, no network, no sign-in. Cloud save is *on*
   by default, but a failed or refused sign-in has to cost a child exactly nothing.
3. **The leaderboard identity must be the Play gamer tag, never Numblop's own nickname field.** The
   nickname is free text typed by a child, saved locally, and unmoderated. Publishing it to other
   players turns an innocuous local convenience into user-generated content with a moderation duty.
   The gamer tag is chosen and moderated by Google and carries the account's own visibility settings.

### Cloud save is on by default, and Google owns the account gate

Decided 2026-08-13, replacing an earlier opt-in design.

On Android the plugin initialises at startup and checks for an existing session. There is **no
Numblop-specific guardian opt-in and no parent gate in front of it**, because the account decision is
not this game's to make: Google, and Family Link for supervised children, already govern whether a
child may sign in to Play Games and what a supervised account is allowed to do. Adding a second,
weaker gate on top would be theatre — a child who can read the Settings screen can pass an
arithmetic challenge in a multiplication game — while costing every honest player their backup.

The problem actually worth solving is a lost phone taking a year of practice with it, and an opt-in
switch buried in Settings does not solve it for the children who most need it.

What this does **not** change: the data-safety declaration and privacy policy still have to be
rewritten before release, the leaderboards are still the higher-risk surface and still last, and the
game still has to be completely playable with sign-in failing.

### Leaderboards: in scope, and last

Google's Families policy governs social features in child-directed apps, and Play Games leaderboards
are a social surface. Both leaderboards are in scope, and they are built **last** so that the risk
they carry stays contained:

- Cloud save and achievements ship first and are independently valuable. Neither depends on a
  leaderboard existing.
- If Families or privacy review objects to the leaderboards, they are **dropped from the release**.
  Because they are the final phase and nothing else references them, dropping them means deleting two
  Play Console entries and two submission calls — not a redesign.
- The fallback, if that happens, is a **local-only comparison against the player's own history** —
  best streak this week versus all time — which needs no network and no policy argument at all.

The two rules above (optional sign-in, gamer-tag identity) are what make the leaderboards arguable at
review. They are not optional themselves.

---

## 2. What the current code gives us for free

The integration is much cheaper than it would have been a year ago, because several things already
exist for other reasons:

| Existing | Why it matters here |
|---|---|
| `profile_id` — 32 hex chars, stable since save v7, preserved by every write | A device pseudonym for the snapshot payload; no new identifier needed |
| One save file, one writer (`AppState`) | Exactly one place to hook load/merge/upload |
| `SaveManager.save_game_state()` rewrites the whole file and re-reads anything a caller omits | The snapshot is literally the same dictionary; no partial-state assembly |
| Field-tolerant loaders in every `Local*` model | An older cloud snapshot loads without a migration step |
| `LocalAchievements.granted` is a permanent, one-time set | Maps 1:1 onto Play achievement unlocks and survives a merge as a set union |
| `progress.experience` is the lifetime correct-answer count | The XP leaderboard score, with no new counter |
| `streak.best_count()` | The best-streak leaderboard score, with no new counter |
| `AchievementCatalog` and `CosmeticCatalog` are deterministic and pure | Coin reconciliation during a merge can be *derived* rather than stored |
| `tools/patch-android-template.ps1` | The established pattern for patching the git-ignored `android/` tree on every export |

And three things that are genuinely missing and must be built first — see §3.

---

## 3. Prerequisites in the local save — **implemented**

These are done and shipped in save version 10. They contain no networking and were built and tested
entirely offline, which is the whole point: the parts that can silently destroy a child's progress
are provable on a laptop before a single Play API is called.

### 3.1 Atomic writes, a backup copy, and recovery

`SaveManager.save_game_state()` used to open `profile.json` with `FileAccess.WRITE`, which truncates
before writing. A process killed mid-write left a truncated file that loaded as a brand-new profile.

The write is now:

1. write the full JSON to `profile.json.tmp` and close it;
2. rename the existing `profile.json` to `profile.json.bak`, replacing any previous backup;
3. rename `profile.json.tmp` over `profile.json`.

Both renames replace atomically on every platform Godot targets. At no point do the two files hold
partial data at the same time: a crash between steps 2 and 3 leaves the previous save under the
backup name, and loading falls through to it.

Loading tries the primary file, then the backup, then gives up and starts fresh. A recovery is
logged. `SaveManager.recover_count` records how many times a load fell through, so a test can assert
that recovery actually happened rather than that nothing crashed.

### 3.2 A real schema version, a monotonic write counter, and migrations

`version` used to be written on every save and **never read** — compatibility came from
field-tolerant loading. That works locally, where there is only ever one file. It does not work for a
merge, which must decide which of two saves is newer without trusting a device clock.

Save version 10 adds, at the top level:

```json
{
  "version": 10,
  "save_counter": 4213,
  "updated_at_unix": 1786000000,
  "cloud": {
    "last_synced_counter": 4200,
    "last_synced_at_unix": 1785990000,
    "player_id": ""
  }
}
```

- `save_counter` increments on **every** write and never resets. It is the primary ordering signal
  for a merge, and it is the one signal a wrong clock cannot corrupt.
- `updated_at_unix` is informational and only ever a tie-breaker of last resort.
- `cloud` records what has already been synchronised, so an unchanged profile does not re-upload,
  and remembers which Play account this profile last belonged to.
- There is deliberately **no `device_id` field**: `profile_id` already is this device's pseudonym, and
  storing the same value twice in one file is a second thing to keep in step. The snapshot payload in
  §6.1 carries `profile_id` under the name `device_id`; the local file does not duplicate it.

`SaveMigration` is now a real, ordered migration step applied to every loaded dictionary before any
model sees it — not just field tolerance. Field tolerance still handles an *added* field for free;
migration exists for the fields whose value must be **computed** from other fields, which is exactly
what the coin ledger needs. Migration happens in memory only: booting an old profile never writes to
it, and the migrated shape lands on disk with the next ordinary save.

Unknown top-level keys are now **preserved** across a save. If a newer build writes a field this
build does not know, this build round-trips it instead of deleting it, so a downgrade — or an older
device syncing an newer snapshot — cannot silently drop data.

### 3.3 A coin ledger, so a merge cannot invent or destroy currency

This is the one place the model genuinely could not merge. `coins` is a balance; balances are not
mergeable. Two devices that each earned 100 coins and each bought a different hat cannot be
reconciled from balances alone.

Save v10 therefore also records **what was earned**, not only what is left:

```json
{
  "coins": 240,
  "earned_rounds": 610,
  "earned_milestones": 145
}
```

Only the two monotonic buckets are stored. The other two terms are **derived**, which is what makes
them merge-safe — a set union produces the same number on both devices:

- achievement earnings = `Σ AchievementCatalog.reward_coins(id)` over the granted set;
- spending = `Σ CosmeticCatalog` price of every paid item owned.

`CoinLedger` (`scripts/app/CoinLedger.gd`) owns this arithmetic. It is pure and static, so the merge
in §7.4 calls exactly the same code the running game does, and both are covered by the same tests.

Back-fill for an existing save, applied by `SaveMigration`:
`earned_rounds = max(0, coins + derived_spent − derived_achievement_coins)` with
`earned_milestones = 0`. The split between the two buckets is lost for old saves, which is harmless:
only their sum is ever used, and their sum is preserved exactly.

A consistency invariant worth stating, because the tests assert it: for any state reachable by
playing, `CoinLedger.balance(...)` equals the stored `coins`. The stored balance stays authoritative
at runtime — the ledger is not re-derived on every load — but a divergence between the two means a
bug, and `CoinLedger.balance()` is what a merge uses to recompute.

---

## 4. Feature scope

| Feature | Play API | Local source of truth |
|---|---|---|
| Sign-in | `GamesSignInClient` | — |
| Cloud save | `SnapshotsClient` (Saved Games) | `profile.json` |
| XP leaderboard | `LeaderboardsClient` | `LocalProgress.experience` |
| Best-streak leaderboard | `LeaderboardsClient` | `LocalStreak.best_count()` |
| Achievements | `AchievementsClient` | `LocalAchievements.granted` |
| Player identity for display | `PlayersClient` | — (never stored in the save) |

**The local save is always the source of truth during play.** Play Games is a backup and a
publishing surface, never an authority. No game rule ever waits on a network call.

### Explicitly out of scope

Multiplayer, friends lists, Play Games events/quests, in-app purchases, ads, Player Stats API,
recall API, and any server of our own. If a feature would create a second place where game rules
live, it is out.

---

## 5. Technical integration

### 5.1 Android plugin — chosen and vendored

**`godot-sdk-integrations/godot-play-game-services` v3.4.0**, vendored unmodified at
`addons/GodotPlayGameServices/`. Provenance and the release hash are in `VENDORED.txt` beside it.
The in-house Kotlin fallback was not needed.

What the spike found, which differs from this document's earlier assumptions:

- **It installs to `addons/`, not `android/plugins/`.** `addons/` is versioned, so the plugin is
  committed like any other source and needs no reinstall-on-every-export tooling. The
  `tools/install-play-games-plugin.ps1` written before the spike was deleted: it duplicated work the
  plugin already does and would have written a **conflicting second `game_services_project_id`
  string resource**, breaking the build.
- **The plugin injects its own manifest meta-data, Gradle dependencies, and string resource** through
  an `EditorExportPlugin`. It pulls `com.google.android.gms:play-services-games-v2:21.0.0` and
  `com.google.code.gson:gson:2.11.0`.
- **The project id is an export option, not an environment variable.**
  `godot_play_game_services/game_id` in `export_presets.cfg`, set on both Android presets. The
  leading-space trick is unnecessary here because the id reaches the manifest via `@string/`.
- **One autoload, `GodotPlayGameServices`; the feature clients are Nodes.** `PlayGamesSignInClient`,
  `PlayGamesSnapshotsClient`, and the rest are instantiated rather than global. Numblop creates only
  the ones it uses, as children of its own `PlayGames` autoload.
- **Saved Games are fully supported and expose conflicts natively**: `save_game`, `load_game`,
  `game_saved`, `game_loaded`, and `conflict_emitted(PlayGamesSnapshotConflict)` carrying both
  candidate snapshots. That maps directly onto `CloudSaveMerge` in §7 — the conflict signal supplies
  the two saves the merge already knows how to reconcile.

Numblop talks to the plugin only through `scripts/autoload/PlayGames.gd`, and looks everything up by
node path and script path rather than by `class_name`, so deleting the addon leaves the game parsing
and running with cloud save simply unavailable.

### 5.2 Export presets and the pinned project contract

Concrete, currently-failing-by-design changes to `export_presets.cfg`:

| Setting | Now | Needs to be |
|---|---|---|
| `permissions/internet` (both Android presets) | `false` | `true` |
| `permissions/access_network_state` | absent | `true` |
| `gradle_build/use_gradle_build` (Android **Debug**) | `false` | `true` — a plugin cannot link without it |
| `gradle_build/use_gradle_build` (Android Release) | `true` | unchanged |

`tests/smoke/test_project_contract.gd:54` asserts `permissions/internet=false` with the message
"Android exports remain offline". That assertion is doing its job: it is a tripwire that makes this
change impossible to land by accident. Update it deliberately, in the same commit, and keep an
assertion in its place — assert that `AD_ID` is **absent** from the merged manifest, because Google
Play services modules have historically pulled in `com.google.android.gms.permission.AD_ID`, and an
ad identifier in a children's app is a policy violation and a false data-safety declaration. Strip it
with `tools:node="remove"` if it appears.

Also verify after the first Gradle build: APK/AAB size delta (expect a few MB), and that no
`ACCESS_ADSERVICES_*` or advertising-related permission was merged in.

### 5.3 The git-ignored `android/` tree — a non-problem, as it turned out

`/android/` is git-ignored and Godot overwrites it whenever the build template is reinstalled, which
is why `tools/patch-android-template.ps1` re-applies the SDK levels on every Android export.

The plugin needs none of that. It lives in `addons/`, which is versioned, and its
`EditorExportPlugin` regenerates everything that belongs under `android/` at export time — the AAR
reference, the Gradle dependencies, the manifest meta-data, and `android/build/res/values/strings.xml`
carrying the game id. Nothing extra to install and nothing extra to re-apply.

### 5.4 Manifest meta-data — supplied by the plugin

The plugin injects this itself, so nothing here is hand-written:

```xml
<meta-data android:name="com.google.android.gms.games.APP_ID"
           android:value="@string/game_services_project_id" />
```

The id comes from the `godot_play_game_services/game_id` export option, which the plugin writes into
a string resource. Because it reaches the manifest through `@string/` rather than as an inline
value, the leading-space workaround that earlier drafts of this document warned about does not apply.

### 5.5 Godot-side architecture

```
addons/GodotPlayGameServices/     Vendored plugin, unmodified. Never edited.
scripts/app/CloudSaveMerge.gd     Pure, deterministic merge of two profile dictionaries.
                                  No plugin, no clock, no files. Unit-testable headlessly.
scripts/autoload/PlayGames.gd     Thin wrapper. Owns the plugin lookup, the feature client Nodes,
                                  and the sign-in state. Every method is a no-op when the plugin
                                  is absent.
```

A `PlayGamesCatalog.gd` mapping local achievement ids to Play ids arrives with P3; it is not needed
for sign-in or cloud save.

Rules that keep this from infecting the rest of the codebase:

- `scripts/core/` is untouched. It has no idea Play exists.
- `PlayGames.gd` resolves the plugin by **node path and script path**, never by `class_name`, so
  deleting the addon leaves the file parsing and reporting unavailable rather than breaking the
  build. **No `#if`-style platform branching anywhere else.**
- Only `SettingsScreen` may reference the autoload, and only to offer the switch. `AppState` never
  calls it; save and pause triggers reach `PlayGames` through `EventBus`, and the one fact it
  publishes back the same way is `external_restore_pending`, which says a remote save could still
  replace this device without naming who is bringing it. A provider-neutral
  `AppState.reload_profile_from_disk()` callable refreshes runtime models after a durable merge. A test walks
  `scripts/core/`, `scripts/app/`, `scripts/ui/` and `scenes/` and enforces this, with a second test
  asserting that `scripts/core/` and `scripts/app/` can never be added to the exemption list.
- **All the difficult logic lives in `CloudSaveMerge.gd`, which is pure.** That is the whole point:
  conflict resolution is the part that can silently destroy a child's progress, and it must be
  testable exhaustively without an Android device, a network, or a Google account.
- The switch lives in `user://settings.cfg`, never in the progress file:

```ini
[play_games]
enabled=true       ; cloud save; on unless deliberately switched off
```

---

## 6. Cloud save: payload, schema versioning, and migration

### 6.1 Snapshot payload

One Saved Game snapshot, fixed name `numblop_profile_v1`. The name is a namespace, not a version —
schema changes go inside.

```json
{
  "schema": 10,
  "app_version": "0.4.1",
  "written_at_unix": 1786000000,
  "device_id": "9f1c…",
  "save_counter": 4213,
  "profile": { "…the exact profile.json dictionary…" }
}
```

Limits to respect: snapshot data max 3 MB, cover image max 800 KB, description max 1024 chars.
Numblop's profile is a few kilobytes, so there is no packing concern. Use the description for a
human-readable summary the Play UI can show — level, XP, and highest table — localised into the
player's language.

### 6.2 Version handling

| Case | Behaviour |
|---|---|
| `schema` < `SAVE_VERSION` | Load it. Field-tolerant loaders fill the gaps, exactly as for an old local file. |
| `schema` == `SAVE_VERSION` | Normal path. |
| `schema` > `SAVE_VERSION` | **Do not load, do not overwrite.** The player has a newer build elsewhere. Keep playing locally, disable upload for the session, and surface a quiet, child-appropriate "this device needs an update" state. Silently overwriting would delete fields this build cannot represent. |

This is the rule the local loader never needed and the cloud one cannot live without.

### 6.3 Future migrations

Adding a field stays free. Renaming or re-meaning one requires a real migration function keyed on
`schema`, applied after load and before merge, in `CloudSaveMerge`. Because the merge is pure, every
migration gets a unit test with a frozen fixture of the older payload — check those fixtures into
`tests/fixtures/` and never edit them afterwards.

---

## 7. Conflict resolution

The merge runs when the cloud snapshot and the local save have diverged: both changed since
`cloud.last_synced_counter`. Play's `SnapshotsClient` also reports genuine conflicts with two
candidate snapshots; both cases feed the same pure function.

### 7.1 The principle

**Never lose mastery, an owned item, an achievement, or a streak record. Accept small imprecision in
the coin balance instead.** For a child, seeing a hat disappear is a betrayal; ending up 50 coins
short of arithmetic is invisible.

Do not use "latest timestamp wins". Device clocks are wrong often enough, and the failure mode is
total: a phone whose clock is a year fast would permanently win every merge and erase the other
device.

### 7.2 Choosing a base record

Deterministic, clock-last:

1. higher `experience`
2. then higher `completed_sessions`
3. then higher `save_counter`
4. then higher `updated_at_unix`
5. then the lexicographically larger `device_id` — arbitrary, but stable, so both devices compute the
   same answer

### 7.3 Field rules

| Field | Rule |
|---|---|
| `mastery` (per fact) | `max` — never demote a fact a child has practised |
| `last_practiced` (per fact) | `max` |
| `highest_unlocked_index` | `max` — already monotonic by design |
| `final_table_completed` | logical **or** — completing 9× is permanent earned progress |
| `experience` | `max` |
| `completed_sessions` | `max` |
| `earned_rounds`, `earned_milestones` | `max` per bucket |
| `cosmetics.unlocked_*` | set **union** |
| `cosmetics.selected_*` | from the base record, validated against the merged unlocked set, falling back to the category default |
| `achievements.granted` | set **union** |
| `streak.all_time_high` | `max` |
| `streak.milestones` | union by `count`, keeping the earliest `ended_at_unix` per count, then re-applying the strictly-increasing rule the loader already enforces |
| `streak.current_count` | from the base record — it is ephemeral by nature |
| `onboarding.completed` | logical **or**; `step` = `max` |
| `nickname` | from the base record; if the base has none and the other does, take the other |
| `profile_id` / `device_id` | keep the **local** device's own; it identifies this device, not the player |
| `coins` | recomputed, below |

### 7.4 Recomputing coins

```
earned  = max(A.earned_rounds, B.earned_rounds)
        + max(A.earned_milestones, B.earned_milestones)
        + Σ AchievementCatalog.reward_coins(id) for id in granted_union

spent   = Σ CosmeticCatalog.item(category, id).price
          for every paid item in the merged unlocked sets

coins   = clamp(earned - spent, 0, earned)
```

Both terms are derived from pure catalogs, so both devices compute the same number.

**The known imprecision, stated honestly:** a child who plays offline on two devices and buys
different items on each ends up owning both items but with fewer coins than the two balances added
together, because the `max` over earnings does not sum divergent play. This is the deliberate trade —
items and mastery are preserved exactly, currency is approximated downward, and the balance can never
go negative or be inflated. The scenario also requires two devices, both offline, both playing: rare,
and the visible outcome is "I kept everything".

### 7.5 After a merge

Write the merged profile locally through the normal `SaveManager` path — one file, one writer, no
special case — increment `save_counter`, then upload it as the new snapshot and record
`cloud.last_synced_counter`. If the upload fails, the local file is still correct and the next sync
retries. **Never apply a merge only in memory.**

### 7.6 First sign-in on a device with existing local progress

The single riskiest moment, and it deserves its own handling rather than being treated as an ordinary
conflict:

- **Local is fresh (no `completed_sessions`, no XP) and cloud has progress** → adopt the cloud save
  silently. This is the reinstall case and the whole point of the feature.
- **Local has progress and cloud is empty** → upload local. No prompt.
- **Both have progress** → run the merge, and *tell the player something happened* in
  child-appropriate language ("We found your Numblop from another device and put everything
  together!"). Do not present a technical choice dialog to a seven-year-old.
- **Always write the pre-merge local profile to `profile.json.premerge` first** and keep it until the
  next successful sync. If the merge is ever wrong, there is something to recover from.

---

## 8. Offline behaviour

The requirement is that offline is not a degraded mode, it is the normal mode.

- Every game rule — questions, mastery, coins, achievements, streaks, purchases — is evaluated and
  saved locally, exactly as today. Nothing awaits a network call, ever.
- Play Games sign-in is requested once per Android launch, asynchronously, after the game is already
  interactive. This lets a fresh install restore without requiring the player to discover Settings.
  Failure or refusal is silent and changes no gameplay; Settings remains the manual retry and opt-out.
- Leaderboard and achievement submissions go into a small pending queue held in
  `user://settings.cfg`-adjacent state (not in the progress file) and are flushed on the next
  successful sign-in. The Play SDK buffers some of this itself, but do not rely on it: local values
  are absolute and re-submission is idempotent.
- Snapshot sync is attempted on sign-in, on app pause, after a finished round, and for local changes
  such as purchases made outside practice — debounced, and skipped entirely when
  `save_counter == cloud.last_synced_counter`. Per-answer saves only mark work pending; no remote
  response may write or reload the profile until the runtime session has ended.
- A signed-out or never-signed-in player sees no Numblop error toast or blocking spinner. Google may
  show its account/sign-in surface for the single startup request. Settings visibly reports
  **Sign in** and offers Sign in / Turn off; fail-closed states appear on the same tile.
- Airplane mode for a month followed by one sync must produce a correct merge. This is a required
  test case, not a hypothetical.

---

## 9. Play Console configuration

Everything below is manual, done once, and gates any device testing.

**Play Games Services setup**

1. Play Console → the Numblop app → *Play Games Services* → *Setup and management* →
   *Configuration*. Create a new Games Services project and link the app `cz.gutcloud.numblop`.
   Note the numeric **project id** — this is the `APP_ID` from §5.4.
2. *Credentials* → add an **Android** credential backed by an Android OAuth 2.0 client in the linked
   Google Cloud project. The Play-distributed app must use the **Play App Signing certificate**
   SHA-1, not the upload-certificate SHA-1; Android OAuth clients bind one package/fingerprint pair,
   so a separately signed local build needs a separate client/credential. Missing the Play App
   Signing SHA-1 is the classic "upload succeeds, Play install gets `DEVELOPER_ERROR`" bug. Read it
   from Play Console → *Protected with Play* → *Play app signing*. The fingerprint independently
   extracted from the Play-installed code 16 APK is
   `ED:48:7F:8E:CE:13:07:05:A1:6D:3E:45:70:F9:4A:B3:4F:BF:C1:B7`.
3. Enable **Saved Games** in the project configuration. Snapshots do not work until this is on.
4. Create the achievements — one per entry in `AchievementCatalog`. Record each generated Play id in
   `PlayGamesCatalog.gd`. Use **incremental** achievements for the tiered ones (streak, XP,
   collection, island) so Play can show progress, and drive them with absolute
   `setSteps()` rather than `increment()` — absolute is idempotent, so a re-submission after a
   reinstall cannot double-count.
5. Create the two leaderboards, if position C in §1 is approved: **Total XP** and **Best streak**,
   both larger-is-better, integer.
6. Every achievement and leaderboard needs a name, description, and icon **in all twenty shipped
   languages**. Play Console localisation is separate from `strings.csv`; budget real time for this
   and keep the source text in the repository so it can be reviewed like any other copy.
7. Add tester accounts. Games Services must be **published** separately from the app before
   non-testers can use it.

**Compliance, in the same release**

8. Rewrite `docs/privacy/index.md` — both language sections — to describe sign-in, what is stored in
   Saved Games, and that it is optional. Remove the "technically unable to send anything off the
   device" claim.
9. Update the Play Console **Data safety** form: account identifiers and gameplay/app-activity data,
   transmitted, tied to the account, optional, and deletable via the Play Games account controls.
10. Re-answer the **Families policy** questionnaire and the target-audience declaration, and confirm
    every linked SDK is declared.
11. Re-check the content rating questionnaire — user interaction and shared data answers change.

---

## 10. Phases

Each phase ends in something shippable, and each one keeps offline play intact.

**P0 — Local prerequisites (no networking at all). ☑ Done.**
Atomic write, backup, and recovery (§3.1); save v10 with `save_counter`, the `cloud` block, real
migrations, and unknown-key preservation (§3.2); the coin ledger (§3.3). Ships as a normal offline
release and is valuable on its own — it closes a real truncation risk that predates any Play work.

**P0b — `CloudSaveMerge`, still with no networking. ☑ Done.**
The merge from §7 in `scripts/app/CloudSaveMerge.gd`, pure and static, covered by
`tests/state/test_cloud_save_merge.gd`. **The part that can silently destroy a child's progress is
proven on a laptop before any Play API exists.**

P2 closed its remaining integration requirement with `SaveManager.save_merged_state()`: the merged
`save_counter` is seeded above both parents before the result reaches disk.

**P1 — Plugin spike and sign-in only. ◐ Code complete; device confirmation outstanding.**

Done:
- Play Console partly configured — PGS project created, testers added, and Saved Games enabled.
  Hardware code 16 proved that the linked Android OAuth credential does not match the Play App
  Signing SHA-1 and returns `DEVELOPER_ERROR`; replace/link the credential described in §9 before
  retrying. **The PGS project stays in draft until sign-in and cloud save are verified on a device.**
- Both Android presets request `INTERNET` and `ACCESS_NETWORK_STATE` and build through Gradle;
  `test_project_contract.gd` pins that and asserts no advertising, location, camera, microphone, or
  contacts permission.
- `scripts/autoload/PlayGames.gd` — the only game-side file that wraps the plugin, no-op on every
  non-Android build, and covered by `tests/state/test_play_games.gd` including a test that no
  gameplay system may reference it.
- `play_games/enabled` in `settings.cfg`, defaulting to on. Android startup requests Play Games
  sign-in once; Google and Family Link own the account decision, and failure leaves play unchanged.
- `godot-sdk-integrations/godot-play-game-services` v3.4.0 vendored unmodified at
  `addons/GodotPlayGameServices/`. Its export plugin injects the AAR, dependencies, manifest
  metadata, and game id `1018864218554`; the pre-spike installer script was deleted.
- A Settings tile — a third icon tile beside Sound and Vibration, with a drawn cloud that is struck
  through when off, visible status captions in all shipped languages, and matching accessible states.
  A signed-out press offers interactive Sign in or a persistent opt-out. It **hides itself unless a
  usable plugin is present**, so no
  Windows or Web player is offered a backup switch that cannot work.

  It became a tile rather than a labelled row because the settings card was already full: a row
  pushed *Close game* below the fold, and scrollbars are hidden, so a guardian would not have found
  it. A third tile costs zero vertical space. The tile is lit by the **setting**, like its two
  siblings — a light that ignored the tap would not be a switch — and whether Google actually
  signed the device in is also carried by its visible caption and accessible name.

Verified locally:
- A fresh Godot 4.6.2 Gradle debug export links the plugin and carries exactly
  `ACCESS_NETWORK_STATE`, `INTERNET`, and `VIBRATE`; the merged manifest has no `AD_ID` permission.
- A second Numblop parent gate was explicitly dropped. It would be weaker than Google/Family Link
  and would prevent the automatic backup this milestone exists to provide.

Remaining:
- Confirm a listed tester account signs in on a real Android device. The PGS project stays in draft
  until that and P2 cloud save are verified.

Success criteria: the game behaves identically for a signed-out player, Windows and Web builds are
unaffected, and a tester account can sign in on a device.

**P2 — Cloud save. ◐ Normal path complete; conflict convergence blocked upstream.**

Implemented in `PlayGames.gd` and covered by fake-client tests:

- fixed snapshot `numblop_profile_v1` with schema, app version, write time, device id, counter, and
  the complete profile;
- player-id binding, first-sign-in load, empty-side adoption, pure merge, seeded durable write, and
  asynchronous upload on sign-in, pause, and local-save events outside practice; answer saves are
  coalesced until the session ends, including when a snapshot response is already in flight;
- `.premerge` recovery before every two-progress merge, refusal to touch a newer schema, generic
  runtime reload, and exact read-back before acknowledging an upload or clearing the safety copy;
- an empty cloud uploads the existing file without a pointless preliminary local rewrite, while
  three consecutive read-back mismatches stop further attempts for that launch;
- both conflict candidates are merged into the local durable save, after which uploads are blocked
  for that launch.

The last behavior is deliberately fail-closed. The plugin's GDScript and Android bridge expose the
conflict id and candidates but no `resolveConflict` operation; current upstream has the same gap.
The vendored addon may not be patched locally. P2 becomes complete only after an upstream release
adds that bridge, it is replaced wholesale, and the physical two-device matrix passes. Until then,
the unresolved server conflict returns on every launch and cloud backup is effectively unavailable
for that player. The Settings tile exposes a fourth accessible needs-attention state and explicitly
says that progress remains safe on the device.

**P3 — Achievements. ☑ implemented, pending hardware verification.**
Local stays truth; Play is a mirror that is only ever written to.

- `scripts/autoload/PlayGamesCatalog.gd` holds the 25 opaque Console ids. It sits beside
  `PlayGames.gd` rather than with the other catalogs because everything under `scripts/app/` is
  forbidden from naming Play. `tests/state/test_play_games_catalog.gd` fails if the achievement
  catalog grows an entry the table does not know — without it a new achievement would silently
  never reach Play, failing nowhere at runtime.
- **Completion is sent the moment an achievement finishes, mid-round included.** Unlike a snapshot
  merge this reads nothing back and touches no local state, so there is nothing for it to disturb
  and no reason to make a child wait for the round to end.
- **How completion is sent depends on the Console type, and getting it wrong is silent.** Only
  `first_steps` has `target == 1`, so it is the only standard achievement and the only one
  `unlock()` finishes. The other twenty-four are incremental — Console is imported that way from
  `incremental := target > 1` — and Play **ignores `unlock()` on an incremental achievement**; it
  completes only when its steps reach the target. Shipped builds up to `0.4.6` sent `unlock()` for
  every completed achievement, so a child who had earned tiers offline saw exactly one of them
  appear on sign-in. A finished achievement is now published as its full absolute step count, and
  the once-per-launch record marks both the unlock and the step value so the in-progress path can
  never follow it with a lower number.
- **Steps are absolute, never deltas**, refreshed on `EventBus.session_ended` and on sign-in. Play
  keeps the higher value, so a local mastery dip or a reinstall that has not merged yet cannot move
  a Play progress bar backwards. Per-answer pushes were rejected: 25 calls per tap is not worth the
  precision on a child's device.
- **Sign-in backfills everything.** A child may have played offline for months before an account
  ever exists, and all of it has to arrive on the first sign-in. Achievements do not need the
  snapshot clients, so the backfill does not wait on the cloud-save handshake.
- Every call is fire-and-forget; the plugin's replies are not connected. An achievement that fails
  to reach Play costs a child nothing. What has already been sent is remembered for the launch so
  an unchanged achievement is not resent every round, and it is cleared on sign-out so a different
  account is told everything from scratch.
- `AppState` is read through `achievements_state_callable`, the same seam shape as
  `reload_profile_callable`, which is what keeps the state provider swappable in tests and keeps
  `AppState` itself unaware that Play exists.

Artwork is already drawn for all 25, one file per `AchievementCatalog` id, in two sizes:

| Where | Size | Purpose |
|---|---|---|
| `store/achievements/<id>.png` | 512×512 RGBA8 | uploaded in Play Console; never ships in the app |
| `ui/achievements/<id>.png` | 192×192 RGBA8 | the `TrophyScreen` tile, 1.76 MB in the build |

Console icons must be a 512×512 JPEG or a **32-bit** PNG — 32-bit meaning RGBA8, so a 24-bit file
is rejected. `tools/resize-achievement-icons.ps1` regenerates both sets from the full-size
originals and forces the pixel format; the originals live in `input/`, which is git-ignored and
excluded from every export preset. `store/` carries a `.gdignore`, so the Console set is invisible
to Godot and costs the build nothing.

**Creating the 25 entries in Console** is a ZIP import rather than 250 form fields.
`tools/export-play-achievements.ps1` writes `artifacts/play-achievements.zip` containing the three
CSVs Console expects — no header rows, unquoted, comma-separated — plus the 25 icons:

| File | Columns |
|---|---|
| `AchievementsMetadata.csv` | Name, Description, Incremental Value, Steps Needed, Initial State, Points, List Order |
| `AchievementsLocalizations.csv` | Name, Localized name, Localized description, Locale |
| `AchievementsIconsMappings.csv` | Name, icon filename |

Names, descriptions and step targets are read from `AchievementCatalog` and `strings.csv`, so what
Console shows is what the game shows, in all twenty languages. English is the default locale and
lives in the metadata file; the other nineteen are localization rows.

**Locale codes come from the game's own language list in Play Games Services, not from the language
tag.** A row naming a locale the game is not configured for rejects the entire import, and Console
reports it by listing all 25 achievements rather than naming the locale — so the failure says
nothing about where it is. Two of the nine break the `xx-YY` pattern: **Slovak is bare `sk`** and
Norwegian is `no-NO`. `CONSOLE_LOCALES` in `tests/smoke/export_play_achievements.gd` mirrors the
configured list and the suite fails on a code that is not in it; update both together if a language
is added to the game in Console. Play points are the one editorial table — `POINTS` in
`tests/smoke/export_play_achievements.gd` — spending 1075 of the 2000 a game may ever use, which
leaves 925 for achievements added with later content. Everything is `Revealed`: nothing here is a
spoiler. `tests/smoke/test_play_achievements_export.gd` fails if an achievement is added without a
point value, if the budget is exceeded, or if any string in any language grows a comma.

Regenerate and re-import after adding an achievement or rewording a string. Note that Console's own
upload dialog spells the third file `AchievementsIconsMappings.csv` while Google's help page spells
it `AchievementsIconMappings.csv`; the dialog wins, but rename it if an import is rejected.

**P4 — Leaderboards. ☐**
Total XP and best streak, gamer-tag identity, submissions on round end and sign-in. Last on purpose:
if review objects, this phase is dropped without touching anything before it.

**P5 — Polish. ☐**
A child-appropriate "we merged your progress" moment and the account-deletion path Play requires.
Google and Family Link remain the account gate; Numblop does not add another one.

**Compliance gate — before P1 ships to any track, not after.**
The bilingual `docs/privacy/index.md` rewrite and `docs/PLAY_CONSOLE_COMPLIANCE.md` worksheet are
complete, and Settings links to the policy in all shipped languages. The public Czech/English policy
pages return HTTP 200, Data safety is configured, and the Families commitment is enabled. The live
policy's analytics wording, target-audience answers, and content rating still need their final
release check. §9 lists the specific items.

---

## 11. Testing strategy

**Headless and deterministic — the bulk of the confidence, `tests/state/test_cloud_save_merge.gd`:**

- identical records merge to themselves (idempotence);
- merge is commutative — `merge(A,B) == merge(B,A)` for every case, since two devices must agree;
- per-fact mastery and `last_practiced` take the maximum;
- cosmetics, achievements, and streak milestones union without loss;
- the coin formula never returns a negative number and never exceeds lifetime earnings;
- the divergent-purchase scenario from §7.4 produces both items;
- fresh-local-versus-populated-cloud adopts the cloud record;
- populated-local-versus-empty-cloud keeps local;
- a `schema` newer than the build is refused rather than loaded;
- frozen fixtures of every historical payload still load after each future migration.

**Autoload tests with a fake plugin double** (`tests/state/test_play_games.gd`): every `PlayGames`
method is a no-op when unavailable; the pending queue survives a failed submit and flushes once; no
gameplay path ever blocks on a call.

**Existing suite:** the full 301-test baseline must still pass. If a Play change requires editing a
test that is not about Play, that is a signal the isolation in §5.5 has leaked.

**Manual device matrix** (extends the checklist in [`RELEASES.md`](RELEASES.md)):

| # | Scenario | Expected |
|---|---|---|
| 1 | Never sign in, play a full session | Byte-for-byte the current experience; no dialogs |
| 2 | Airplane mode from launch, full round, chest, purchase | Everything works; nothing hangs |
| 3 | Sign in on a device with local progress, cloud empty | Local uploads, nothing changes on screen |
| 4 | Reinstall, sign in, cloud has progress | Progress restored, tutorial does not replay — no finger appears at all, not even briefly |
| 4b | Second device, first launch, signed into the same account | Same as 4: a fresh local save is the same code path as a reinstall |
| 5 | Two devices, both offline, different purchases, then both sync | Both items owned on both devices, coins non-negative, identical final state |
| 6 | Sign out mid-session | Play stops, game continues, local save intact |
| 7 | Kill the app during a snapshot write | Local profile still loads; backup used if needed |
| 8 | Deliberately set the device clock a year forward | Merge is unaffected — `save_counter` decides |
| 9 | Supervised (Family Link) child account | Sign-in behaviour documented; graceful if restricted |
| 10 | Older app build meets a newer cloud schema | Refuses to load, keeps playing, does not overwrite |

Scenarios 5, 8, and 10 are the ones that catch the bugs that destroy progress, and they are the ones
easiest to skip. They are mandatory before the cloud-save phase leaves the internal track.

---

## 12. Open questions for the remaining phases

1. **Account deletion path.** Play provides account-level controls, but the store listing must state
   how a player removes their data. Decide whether "sign out and delete cloud save" lives in Settings.
2. **Web and Windows builds** get none of this. Confirm that is acceptable, and that a child moving
   between the Web build and Android will not expect shared progress.
3. **Whether Play achievement unlocks should be re-derived from the local granted set on every
   sign-in**, or only backfilled once. Re-deriving is more robust and costs one batch call.

Resolved: the community plugin is vendored; cloud defaults on; Google/Family Link own the account
gate; leaderboard scope remains both, built last and droppable; and the coin ledger was built before
networking rather than migrated twice.
