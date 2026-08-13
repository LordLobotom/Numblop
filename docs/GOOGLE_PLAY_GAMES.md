# Google Play Games Services — Integration Plan

- **Status:** Approved in scope. Phase P0 (local prerequisites) is **implemented**; everything from
  P1 onwards is still a plan.
- **Milestone:** M5. The networking phases start after `D18` ships an offline release.
- **Prerequisite:** P1 onwards breaks the "no networking" product contract in `AGENTS.md`. It does
  not begin until an entry in [`DECISIONS.md`](DECISIONS.md) approves that change.

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
2. **Sign-in must be optional, off by default, and never required to play.** A child-directed app
   that gates content behind a Google account will not pass Families review, and it would break the
   product promise regardless of review.
3. **The leaderboard identity must be the Play gamer tag, never Numblop's own nickname field.** The
   nickname is free text typed by a child, saved locally, and unmoderated. Publishing it to other
   players turns an innocuous local convenience into user-generated content with a moderation duty.
   The gamer tag is chosen and moderated by Google and carries the account's own visibility settings.

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

### 5.1 Android plugin

Godot 4.2+ uses the v2 Android plugin API (`GodotAndroidPluginV2`), which requires a Gradle build
and a `.gdap` config plus AAR under `res://android/plugins/`.

Two options:

- **Community plugin — `godot-play-game-services`.** Wraps PGS v2 for sign-in, achievements,
  leaderboards, saved games/snapshots, players, and events. Saves the most work.
  *Must be verified against Godot 4.6.2 before it is adopted* — the plugin's AAR builds against a
  specific `godot-lib` version, and the last release predating 4.6 may need a rebuild from source.
  Treat "does it build and run on 4.6.2" as a spike, not an assumption.
- **In-house Kotlin plugin.** The surface actually needed is small: initialise, `isAuthenticated`,
  `signIn`, `submitScore`, `unlockAchievement`, `setAchievementSteps`, `openSnapshot`,
  `writeSnapshot`, `resolveConflict`. A few hundred lines of Kotlin, no external dependency, full
  control of the merged manifest, and it can be pinned to 4.6.2 exactly.

**Recommendation:** spike the community plugin for one day. If it builds cleanly on 4.6.2, use it.
If it needs patching, write the in-house plugin instead — a forked AAR that must be rebuilt for every
Godot update is worse than owning the code.

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

### 5.3 The git-ignored `android/` problem

`/android/` is git-ignored at the repository root, and Godot overwrites it whenever the build
template is reinstalled. Both the plugin files (`android/plugins/*.gdap` + AAR) and the manifest
meta-data live there.

Follow the pattern that already exists for exactly this reason: `tools/patch-android-template.ps1`
is idempotent and is invoked automatically by `tools/export.ps1` on every Android release export.
Add a sibling `tools/install-play-games-plugin.ps1` that:

1. copies the versioned plugin artefacts from a tracked location (e.g. `third_party/play-games/`)
   into `android/plugins/`;
2. patches `android/build/AndroidManifest.xml` with the required meta-data;
3. is idempotent and safe to run on every export.

Wire it into `export.ps1` next to the existing template patch. The alternative — un-ignoring
`android/` — drags Godot's entire generated Gradle tree into version control and is worse.

### 5.4 Manifest meta-data

```xml
<meta-data android:name="com.google.android.gms.games.APP_ID"
           android:value="@string/game_services_project_id" />
<meta-data android:name="com.google.android.gms.version"
           android:value="@integer/google_play_services_version" />
```

`game_services_project_id` **must be a string resource whose value begins with a space** (e.g.
`" 123456789012"`). Without the leading space the build tools parse the numeric id as a float and
the app crashes on start with an opaque error. This is the single most common first-time failure.

### 5.5 Godot-side architecture

Two new files plus one pure model — the shape mirrors how the learning core is already separated
from the platform:

```
scripts/app/CloudSaveMerge.gd     Pure, deterministic merge of two profile dictionaries.
                                  No plugin, no clock, no files. Unit-testable headlessly.
scripts/app/PlayGamesCatalog.gd   Static mapping: local achievement id -> Play achievement id,
                                  and the two leaderboard ids. Pure data.
scripts/autoload/PlayGames.gd     Thin autoload. Owns the plugin singleton, the sign-in state,
                                  the pending-submission queue, and the snapshot calls.
                                  Every method is a no-op when the plugin is absent.
```

Rules that keep this from infecting the rest of the codebase:

- `scripts/core/` is untouched. It has no idea Play exists.
- `PlayGames.gd` checks `Engine.has_singleton()` once at `_ready()`. On Windows, Web, in the editor,
  and on an Android build without the plugin, `available()` is `false` and every call returns
  immediately. **No `#if`-style platform branching anywhere else.**
- `AppState` never calls `PlayGames` directly for gameplay. It emits what it already emits, and
  `PlayGames` listens on `EventBus` (`reward_applied`, `achievements_unlocked`, `streak_changed`,
  `profile_saved`). If the autoload were deleted, the game would still run.
- **All the difficult logic lives in `CloudSaveMerge.gd`, which is pure.** That is the whole point:
  conflict resolution is the part that can silently destroy a child's progress, and it must be
  testable exhaustively without an Android device, a network, or a Google account.
- New settings keys in `user://settings.cfg`, so they never touch the progress file:

```ini
[play_games]
enabled=false      ; opt-in, off until a parent turns it on
auto_sync=true
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
- Sign-in is attempted at most once per launch, asynchronously, after the game is already interactive.
  Failure is silent.
- Leaderboard and achievement submissions go into a small pending queue held in
  `user://settings.cfg`-adjacent state (not in the progress file) and are flushed on the next
  successful sign-in. The Play SDK buffers some of this itself, but do not rely on it: local values
  are absolute and re-submission is idempotent.
- Snapshot sync is attempted on sign-in, on app pause, and after a finished round — debounced, and
  skipped entirely when `save_counter == cloud.last_synced_counter`.
- A signed-out or never-signed-in player sees no dialogs, no spinners, and no error toasts. Sync
  failures are logged, not surfaced.
- Airplane mode for a month followed by one sync must produce a correct merge. This is a required
  test case, not a hypothetical.

---

## 9. Play Console configuration

Everything below is manual, done once, and gates any device testing.

**Play Games Services setup**

1. Play Console → the Numblop app → *Play Games Services* → *Setup and management* →
   *Configuration*. Create a new Games Services project and link the app `cz.gutcloud.numblop`.
   Note the numeric **project id** — this is the `APP_ID` from §5.4.
2. *Credentials* → add an **Android** credential. It needs an OAuth 2.0 client in the linked Google
   Cloud project with the SHA-1 of **both** the upload certificate **and** the Play App Signing
   certificate. Missing the Play App Signing SHA-1 is the classic "works from Android Studio, fails
   from the Play track" bug.
3. Enable **Saved Games** in the project configuration. Snapshots do not work until this is on.
4. Create the achievements — one per entry in `AchievementCatalog`. Record each generated Play id in
   `PlayGamesCatalog.gd`. Use **incremental** achievements for the tiered ones (streak, XP,
   collection, island) so Play can show progress, and drive them with absolute
   `setSteps()` rather than `increment()` — absolute is idempotent, so a re-submission after a
   reinstall cannot double-count.
5. Create the two leaderboards, if position C in §1 is approved: **Total XP** and **Best streak**,
   both larger-is-better, integer.
6. Every achievement and leaderboard needs a name, description, and icon **in all ten shipped
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

**P0b — `CloudSaveMerge`, still with no networking. ☐**
The merge from §7, written and unit-tested against synthetic save pairs, before any Play API exists.
**The part that can silently destroy a child's progress is proven on a laptop first.** It can be
written any time; it does not depend on P1.

**P1 — Plugin spike and sign-in only. ☐**
Console setup, plugin verified on 4.6.2, manifest and export-preset changes, `PlayGames.gd` with
sign-in and nothing else. Success criteria: the game behaves identically for a signed-out player,
Windows and Web builds are unaffected, and the merged manifest contains no advertising permission.

**P2 — Cloud save. ☐**
Wire `CloudSaveMerge` to `SnapshotsClient`. First-sign-in handling from §7.6, the `.premerge` safety
copy, and the schema-newer refusal from §6.2. This is the phase players actually feel, which is why
it comes before achievements.

**P3 — Achievements. ☐**
Map the catalog, push unlocks and absolute steps on `EventBus.achievements_unlocked`, backfill
everything already granted on first sign-in. Local stays truth; Play is a mirror.

**P4 — Leaderboards. ☐**
Total XP and best streak, gamer-tag identity, submissions on round end and sign-in. Last on purpose:
if review objects, this phase is dropped without touching anything before it.

**P5 — Polish. ☐**
Settings UI for sign-in/sign-out behind a parent gate, a child-appropriate "we merged your progress"
moment, and the account-deletion path Play requires.

**Compliance gate — before P1 ships to any track, not after.**
Rewrite `docs/privacy/index.md` in both languages, update the Play Console data-safety declaration,
re-answer the Families and target-audience questionnaires, and re-check the content rating. §9 lists
the specific items.

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

**Existing suite:** the full 198 tests must still pass unchanged. If a Play change requires editing a
test that is not about Play, that is a signal the isolation in §5.5 has leaked.

**Manual device matrix** (extends the checklist in [`RELEASES.md`](RELEASES.md)):

| # | Scenario | Expected |
|---|---|---|
| 1 | Never sign in, play a full session | Byte-for-byte the current experience; no dialogs |
| 2 | Airplane mode from launch, full round, chest, purchase | Everything works; nothing hangs |
| 3 | Sign in on a device with local progress, cloud empty | Local uploads, nothing changes on screen |
| 4 | Reinstall, sign in, cloud has progress | Progress restored, tutorial does not replay |
| 5 | Two devices, both offline, different purchases, then both sync | Both items owned on both devices, coins non-negative, identical final state |
| 6 | Sign out mid-session | Play stops, game continues, local save intact |
| 7 | Kill the app during a snapshot write | Local profile still loads; backup used if needed |
| 8 | Deliberately set the device clock a year forward | Merge is unaffected — `save_counter` decides |
| 9 | Supervised (Family Link) child account | Sign-in behaviour documented; graceful if restricted |
| 10 | Older app build meets a newer cloud schema | Refuses to load, keeps playing, does not overwrite |

Scenarios 5, 8, and 10 are the ones that catch the bugs that destroy progress, and they are the ones
easiest to skip. They are mandatory before the cloud-save phase leaves the internal track.

---

## 12. Open questions to resolve before P1

1. **Community plugin or in-house Kotlin** (§5.1). Answered by the one-day spike, not by preference.
2. **Parent gate mechanism** for enabling sign-in — Google offers no standard widget, and a simple
   arithmetic gate is both conventional and, for a multiplication game, slightly funny.
3. **Account deletion path.** Play provides account-level controls, but the store listing must state
   how a player removes their data. Decide whether "sign out and delete cloud save" lives in Settings.
4. **Web and Windows builds** get none of this. Confirm that is acceptable, and that a child moving
   between the Web build and Android will not expect shared progress.
5. **Whether Play achievement unlocks should be re-derived from the local granted set on every
   sign-in**, or only backfilled once. Re-deriving is more robust and costs one batch call.

Resolved on 2026-08-12: leaderboard scope (both, built last, droppable), phase order, and building
the coin ledger up front rather than migrating twice.
