# Google Play Console compliance worksheet

Status: the live Play Console Data safety and Families answers below were recorded on 2026-08-13
for the first Play Games cloud-save build. The public Czech and English policy pages returned HTTP
200 on that date. Re-check the declarations against every later networking artifact.

This worksheet is intentionally conservative. Google Play defines collection as data transmitted
off device by the app or any bundled SDK, even when the developer never receives it. Google Play
Games states that it may process account/profile information, IP-derived region, game activity,
saved progress, device identifiers, and diagnostics. Sources:

- [Google Play User Data policy](https://support.google.com/googleplay/android-developer/answer/10144311)
- [Data safety form guidance](https://support.google.com/googleplay/android-developer/answer/10787469)
- [How Play Games handles data](https://support.google.com/android/answer/12461859)
- [Play Games profile privacy controls](https://support.google.com/googleplay/answer/3129346)
- [Families policy requirements](https://support.google.com/googleplay/android-developer/answer/17122218)

## Artifact facts to verify first

- Package: `cz.gutcloud.numblop`; target SDK 36.
- Permissions present: `INTERNET`, `ACCESS_NETWORK_STATE`, `VIBRATE`.
- Permissions absent: `AD_ID`, location, camera, microphone, contacts.
- SDK: vendored `godot-sdk-integrations/godot-play-game-services` v3.4.0, which links Google Play
  Games v2. No advertising or analytics SDK is present.
- Cloud save is optional at the product level: the entire game works signed out/offline, and the
  Settings cloud tile stops all Numblop Play Games calls when switched off.
- No Numblop account is created. Google/Family Link owns the Play Games profile.

## Recorded Data safety declaration

The Console answer to “Does your app collect or share any of the required user data types?” is
**Yes**. Data sent by the Play Games SDK and Saved Games snapshot counts even though GutCloud runs
no server.

Security answers:

- Data encrypted in transit: **Yes** — Play Games transport is encrypted.
- Data shared with third parties: **No**.
- Numblop does not create or manage its own user accounts.
- Users can remove local data through Android and Play Games data through Google's controls.
  Switching the in-game tile off does not delete an existing snapshot.

| Data type | Collected | Required/optional | Purpose |
|---|---|---|---|
| Personal info — Name / gamer tag | Yes | Optional | App functionality |
| Personal info — User IDs / Play player ID | Yes | Optional | App functionality |
| App info and performance — Diagnostics | Yes | Required | Analytics |
| App info and performance — Other app performance data | Yes | Required | Analytics |
| App activity — Other actions | Yes | Optional | App functionality |

No other data type is currently declared. Revisit this table if the Play Games SDK disclosure,
Saved Games payload, permissions, achievements, leaderboards, or Console wording changes.

The required diagnostics and performance rows are deliberate: `PlayGames._start()` initialises the
SDK unconditionally on Android, while the cloud tile gates authentication and Numblop's cloud-save
calls. The optional profile/gameplay rows are only collected for a signed-in player. Keep the
published policy aligned with this distinction.

Do **not** declare advertising, financial data, contacts, precise location, photos/videos, audio,
health, messages, browsing history, search history, or files/documents unless a later SDK report or
artifact inspection proves otherwise.

## Target audience and Families

- Keep the existing child target-age selections that accurately describe the store listing; do not
  widen them merely to avoid Families review.
- Contains ads: **No**.
- In-app purchases: **No**.
- Free-form communication or user-generated content: **No**. The local nickname is never public.
- Social features: cloud save is not social. If P4 leaderboards are ever added, re-answer this
  section before that build; Play gamer tags, never local nicknames, are the only allowed identity.
- SDK/API disclosure: list Google Play Games Services. Confirm its terms allow supervised child
  profiles; Family Link requires parent approval to create such a profile.
- Families policy commitment: **Enabled**.
- Re-run the IARC questionnaire. P2 cloud save alone does not add chat or exchange of free-form
  content. Do not answer leaderboard/social questions until P4 actually exists.

## Privacy-policy and store fields

- Canonical privacy URL: `https://numblop.gutcloud.cz/en/privacy/`.
- Czech policy URL: `https://numblop.gutcloud.cz/cs/privacy/`.
- Both URLs returned HTTP 200 on 2026-08-13.
- The policy is published from the separate `numblop-landing` repository. GitHub Pages was never
  enabled here, so the former `lordlobotom.github.io` address returned 404.
- The policy is linked from the Play listing and must also be reachable inside the app.
- Developer/privacy contact: `emichalgut@gmail.com`.
- The app does not create a Numblop account, so the app-account-creation deletion rule does not
  create a separate GutCloud account-deletion URL. The policy still explains how to delete local and
  Play Games data.

## Final Console pass

1. Upload or inspect the exact candidate only after `tools/verify-aab.ps1` passes with bundletool.
2. Compare the generated Data safety summary with the recorded answers and the live privacy policy.
3. Re-check Target audience and content, Families, SDK, and IARC answers.
4. Do not send changes for review until the physical-device sign-in/cloud matrix passes.
5. Capture screenshots or export the completed declarations for the release record; never place
   account credentials or private Console data in this repository.
