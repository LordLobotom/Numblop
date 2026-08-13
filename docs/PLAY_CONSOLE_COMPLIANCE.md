# Google Play Console compliance worksheet

Status: repository side prepared on 2026-08-13 for the first Play Games cloud-save build. The live
Play Console answers still require an authenticated Console session and must be reviewed again
against the exact artifact before submission.

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

## Data safety draft

Answer **Yes** to “Does your app collect or share any of the required user data types?” Data sent by
the Play Games SDK and Saved Games snapshot counts even though GutCloud runs no server.

Security answers:

- Data encrypted in transit: **Yes** — Play Games transport is encrypted.
- Users can request deletion: disclose Google's per-game/Play Games deletion controls and the
  contact address from the privacy policy. Do not claim that switching the in-game tile off deletes
  an existing snapshot.
- Independent security review: **No**, unless one is actually completed later.

Declare the following conservatively. “Shared with Google Play Games” should be selected if the
Console treats Google's processing for Play-wide analytics/improvement as third-party sharing; do
not use the service-provider exception without the Console's current wording confirming it.

| Data type | Collected | Optional | Purposes |
|---|---|---|---|
| Personal info — Name | Yes; Google account/profile name may be processed, and the optional local nickname is included in the snapshot | Yes | App functionality, account management |
| Personal info — Email address | Yes; Play Games says it may process it when discoverable; Numblop does not receive it | Yes | Account management |
| Personal info — User IDs | Yes; Play player id plus Numblop's random profile id | Yes | App functionality, account management, fraud prevention/security |
| Location — Approximate location | Yes; Play Games may derive country/region from IP | Yes | App functionality, analytics, fraud prevention/security |
| App activity — App interactions | Yes; mastery, XP, streaks, achievements, cosmetics and other saved progress | Yes | App functionality |
| App info and performance — Diagnostics | Yes if shown by the current Play Games SDK disclosure | Yes | App functionality, analytics |
| Device or other IDs | Yes if shown by the current Play Games SDK disclosure; the snapshot also carries a random pseudonymous profile id | Yes | App functionality, fraud prevention/security |

Do **not** declare advertising, financial data, contacts, precise location, photos/videos, audio,
health, messages, browsing history, search history, or files/documents unless the final SDK report or
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
- Re-run the IARC questionnaire. P2 cloud save alone does not add chat or exchange of free-form
  content. Do not answer leaderboard/social questions until P4 actually exists.

## Privacy-policy and store fields

- Privacy URL: `https://lordlobotom.github.io/Numblop/privacy/`.
- The URL must resolve publicly through GitHub Pages before the networking build is submitted.
- The policy is linked from the Play listing and must also be reachable inside the app.
- Developer/privacy contact: `emichalgut@gmail.com`.
- The app does not create a Numblop account, so the app-account-creation deletion rule does not
  create a separate GutCloud account-deletion URL. The policy still explains how to delete local and
  Play Games data.

## Final Console pass

1. Upload or inspect the exact candidate only after `tools/verify-aab.ps1` passes with bundletool.
2. Save the Data safety form answers above; compare the generated summary word-for-word with the
   privacy policy.
3. Save Target audience and content, Families, SDK, and IARC answers.
4. Do not send changes for review until the physical-device sign-in/cloud matrix passes.
5. Capture screenshots or export the completed declarations for the release record; never place
   account credentials or private Console data in this repository.
