# Save and Persistence System

This document describes what the code does today. It is written from `scripts/autoload/SaveManager.gd`,
`scripts/autoload/SettingsManager.gd`, `scripts/autoload/AppState.gd`, and the `Local*` models in
`scripts/app/`. When this file and any other document disagree, the code wins and this file is the
one to correct first.

## Two files, two purposes

| File | Owner | Format | Contains |
|---|---|---|---|
| `user://profile.json` | `SaveManager` | JSON, pretty-printed | Everything the child earned: mastery, coins, XP, cosmetics, streak, achievements, tutorial state, nickname, profile id |
| `user://settings.cfg` | `SettingsManager` | Godot `ConfigFile` | Device preferences: language, music/SFX volume, mute, haptics |

They are deliberately separate. Language and volume are properties of the device, not of the child's
progress, and a reset profile must not reset them.

`user://` resolves to the app-private data directory: `%APPDATA%\Godot\app_userdata\Numblop\` on
Windows, the app sandbox on Android, and origin-scoped IndexedDB storage in a browser.

## `profile.json` — the single progress file

There is exactly one profile. There are no slots, no accounts, and no per-child selection.

Every write goes through `SaveManager.save_game_state()`, which rewrites the **whole** file. Callers
that only change one thing (a purchase, a nickname) pass the rest through unchanged, and any argument
left out is re-read from disk before writing, so no save path can silently drop another system's data.

### Current shape — save version 9

```json
{
  "version": 9,
  "highest_unlocked_index": 0,
  "mastery": { "2_x_0": 0, "2_x_1": 0, "…": 0, "9_x_9": 0 },
  "last_practiced": { "2_x_0": 0, "…": 0, "9_x_9": 0 },
  "coins": 0,
  "experience": 0,
  "completed_sessions": 0,
  "cosmetics": {
    "unlocked_body_colors": ["green"],
    "selected_body_color": "green",
    "unlocked_belly_colors": ["cream"],
    "selected_belly_color": "cream",
    "unlocked_hats": ["hat_none"],
    "selected_hat": "hat_none",
    "unlocked_glasses": ["glasses_none"],
    "selected_glasses": "glasses_none",
    "unlocked_necklaces": ["necklace_none"],
    "selected_necklace": "necklace_none",
    "unlocked_footwear": ["footwear_none"],
    "selected_footwear": "footwear_none"
  },
  "streak": {
    "current_count": 0,
    "all_time_high": 0,
    "milestones": [
      { "count": 12, "ended_at_unix": 1785765600, "utc_offset_minutes": 120 }
    ]
  },
  "achievements": { "granted": [] },
  "onboarding": { "completed": false, "step": 0 },
  "nickname": "",
  "profile_id": "9f1c…"
}
```

### Field reference

| Field | Type | Written by | Rules on load |
|---|---|---|---|
| `version` | int | `SaveManager.SAVE_VERSION` | Written on every save, **never read**. See "Versioning" below. |
| `highest_unlocked_index` | int `0–7` | `LearningProfile` | Clamped to the table range, then `_advance_unlocks()` re-derives any unlock the mastery values already earn. Never decreases. |
| `mastery` | 80 × `"<table>_x_<multiplier>"` → int | `LearningProfile` | Only known keys are copied; each value is clamped to `0–100`. Unknown keys are dropped, missing keys stay `0`. |
| `last_practiced` | 80 × fact key → unix seconds | `LearningProfile` | `0` means "never practised", which sorts as longest-waiting. Supplied by `SessionController`, never read from a clock inside `scripts/core/`. |
| `coins` | int ≥ 0 | `LocalProgress` | Negative values clamp to `0`. |
| `experience` | int ≥ 0 | `LocalProgress` | Also the lifetime correct-answer count (one XP per correct answer). |
| `completed_sessions` | int ≥ 0 | `LocalProgress` | If it is `0` while `experience > 0`, it is back-filled to `1`: that save predates the counter but proves at least one finished round. |
| `cosmetics` | dict of 6 `unlocked_*` arrays + 6 `selected_*` ids | `LocalCosmetics` | Item ids are validated against `CosmeticCatalog`; unknown ids are dropped. The free default of each category is always present. A `selected_*` id that is not owned falls back to the category default. |
| `streak` | `current_count`, `all_time_high`, `milestones[]` | `LocalStreak` | Milestones must be strictly increasing in `count`; any row that is not is dropped. `utc_offset_minutes` is clamped to ±14 h. `all_time_high` is raised to the highest surviving milestone. |
| `achievements.granted` | array of achievement ids | `LocalAchievements` | Ids are validated against `AchievementCatalog`; unknown and duplicate ids are dropped. This set is the only thing that makes an achievement reward one-time. |
| `onboarding` | `completed` bool, `step` int | `LocalOnboarding` | Anything that is not a real bool counts as "not finished", so a corrupt save replays the tutorial rather than skipping it. |
| `nickname` | string, ≤ 16 chars | `LocalNickname.sanitize` | Control characters stripped, trimmed, truncated to 16. Optional; empty is normal. |
| `profile_id` | 32 lowercase hex chars | `SaveManager` | 16 random bytes from `Crypto`, generated on the first save and preserved by every later one. A device-local pseudonym that links to no identity. Cleared and regenerated by a profile reset. |

### When a save happens

Writes are frequent and small, and every one of them is a full-file rewrite:

- **After every submitted answer** — `SessionController._save_after_answer()` persists mastery and
  `last_practiced` immediately, so a killed app never loses answered questions.
- **On a mastery-band crossing** — the 5-coin bonus is applied to `LocalProgress` before that same
  per-answer save, so the coins and the mastery that earned them land together.
- **On a finished round** — `LocalProgress.apply_completed_session()` writes coins, XP, and the
  incremented `completed_sessions` in one save. The counter is rolled back if the write fails.
- **On an achievement grant** — `AppState.sync_achievements()` writes the granted ids and the coin
  reward together. If the write fails, the coins and the granted flags are both rolled back and the
  achievement is re-evaluated on the next opportunity.
- **On a purchase or equip** — `AppState._save_state_with_cosmetics()`.
- **On a nickname change, a tutorial step, and tutorial completion.**

`AppState` holds the loaded state in memory and is the only thing that calls `SaveManager` during
play. Scenes never write saves.

### What is deliberately *not* saved

- **The active question session.** An interrupted round (app paused, Android Back, force-stop) is
  discarded by `AppState._interrupt_unfinished_session()`. Mastery from answers already submitted is
  already on disk and stays; the unfinished round grants no chest and is not resumed.
- **Any answer log or timing history.** Only the aggregate mastery value and the `last_practiced`
  stamp survive a question.

## Versioning and migration — how it actually works

`SAVE_VERSION` is currently `9`. The important detail is that **loading does not branch on it**:

- `SaveManager` writes `version` on every save and never reads it back.
- `LearningProfile` also carries its own `SAVE_VERSION = 2`, which is overwritten by the
  `SaveManager` value before the file is written, so it never reaches disk.
- Compatibility comes from every loader being *field-tolerant* instead: each `Local*` model takes a
  dictionary, ignores what it does not recognise, and substitutes a documented default for whatever
  is missing. `LearningProfile.from_dictionary()` does the same for the 80 facts.

The practical consequences:

- **Adding a field is free.** An older save simply gets the default, which is what save versions 6
  through 9 each did (necklaces, nickname + `profile_id`, achievements + `completed_sessions`,
  onboarding).
- **Renaming or re-meaning a field is not free.** There is no migration step to hang it on, so a
  rename silently resets that field to its default for every existing player. Any such change must
  add an explicit version-aware migration in `SaveManager` first.
- **The version number is documentation, not behaviour.** It is worth keeping accurate, because the
  first system that will genuinely need it is cloud save (see
  [`GOOGLE_PLAY_GAMES.md`](GOOGLE_PLAY_GAMES.md)).

### Corruption and failure behaviour

`SaveManager._load_state_dictionary()` returns an empty dictionary — meaning "fresh profile" — when
the file is missing, cannot be opened, or does not parse as a JSON object. It warns and continues;
it never crashes and never deletes the bad file. A partially valid file is *not* rejected: parsing
succeeds and each model then repairs its own section.

There is currently **no backup copy and no atomic write**. `FileAccess.WRITE` truncates the file
before the new content is written, so a process killed mid-write can leave a truncated profile,
which loads as a fresh one. This has not been observed in play (writes are small and frequent), but
it is a real gap and the natural place to close it is alongside cloud save.

Write failures propagate as `Error` values, and the callers above treat a failed write as "the thing
did not happen" rather than pretending it did.

## `settings.cfg` — device preferences

```ini
[language]
locale="system"        ; "system" or a locale from LanguageCatalog

[audio]
music_volume=0.75      ; 0.0–1.0, applied to the Music bus
sfx_volume=0.9         ; 0.0–1.0, applied to the SFX bus
muted=false

[haptics]
enabled=true
```

- `locale="system"` resolves through `SettingsManager.effective_locale()`: the device language when
  Numblop ships it, English otherwise, with `no`/`nn` folded to `nb`.
- An unknown saved locale is ignored and falls back to `system`.
- Volumes are clamped on load and applied to the `Music` and `SFX` audio buses.
- Missing file or missing keys → the defaults above.
- `SettingsManager.play_haptic()` is the only caller of `Input.vibrate_handheld`, so the toggle
  cannot be bypassed by a new call site.

## Android backup

`user_data_backup/allow=true` in both Android presets, so `profile.json` and `settings.cfg` are
included in Android's own device-to-device transfer and cloud backup when the player's Google
account has backup enabled. This is Android's mechanism, not the app's — the app performs no
networking and the current privacy policy describes exactly this.

## Resetting

`AppState.reset_local_profile()` abandons any active session, replaces every model with a fresh
instance — including `onboarding`, so the tutorial replays — and writes the empty profile. Settings
are untouched. The `profile_id` is regenerated on the next write, so a reset profile is a new
pseudonym.

There is currently no in-game control that calls it; it exists for tests and for a future
parent-facing action.

## Where the tests are

| Area | Test |
|---|---|
| Whole-file round trip, defaults, corrupt input | `tests/state/test_profile_persistence.gd` |
| Coins, XP, level, completed rounds, milestone bonus | `tests/state/test_progression_persistence.gd` |
| Cosmetic ownership and equip persistence | `tests/state/test_cosmetics_persistence.gd` |
| Streak counters and milestone rows | `tests/state/test_streak_persistence.gd` |
| One-time achievement grants, retroactive award | `tests/state/test_achievements_persistence.gd` |
| Nickname sanitising and `profile_id` stability | `tests/state/test_nickname_persistence.gd` |
| Tutorial state and pre-v9 adoption | `tests/state/test_onboarding_persistence.gd` |
| Settings file and audio bus application | `tests/state/test_settings_persistence.gd` |
| Pause / resume / Back discarding a round | `tests/state/test_android_lifecycle.gd` |

`AppState` writes the live save file, so tests must always pass an explicit temporary path to
`SaveManager` rather than letting a test touch the real profile.
