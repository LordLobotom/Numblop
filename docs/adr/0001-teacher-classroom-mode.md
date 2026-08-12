# ADR 0001 — Teacher / classroom mode (future concept)

- **Status:** Proposed — design only, no implementation
- **Date:** 2026-08-02
- **Owner:** product (GutCloud)
- **Superseded in part:** the offline-first sync sketch below predates
  [`../GOOGLE_PLAY_GAMES.md`](../GOOGLE_PLAY_GAMES.md), which is now the planned first networking
  milestone (M5). If classroom mode is ever picked up, read that document first: it already answers
  sign-in, the `INTERNET` permission change, the Families-policy consequences, the data-safety
  rewrite, and cloud-save conflict resolution, and a classroom backend should reuse those answers
  rather than invent a parallel set.

## Context

Numblop's shipped contract is strictly offline: one local child profile, no accounts, no
analytics, no networking, and the Android build does not even request the `INTERNET`
permission (`AGENTS.md` product contract, pinned by `tests/smoke/test_project_contract.gd`).
The requested future capability is: a teacher creates a class and receives a short join code;
children's devices join with that code; the class sees an optional leaderboard and the teacher
sees practice statistics. This ADR records how that could work later **without** breaking the
current contract, and which present-day decisions keep the door open.

## Concept

- A teacher registers (teacher-only account — never the child) in a separate teacher web
  dashboard and creates a class, receiving a short human-typeable class code (e.g. 6
  characters, no ambiguous glyphs).
- On the child's device, entering the class code links the local profile to the class. No
  child account is created; the device keeps playing fully offline.
- When online, the device opportunistically syncs a **pseudonymous aggregate snapshot**:
  `profile_id`, nickname, per-table mastery band counts, session counts, and streak length.
- The teacher dashboard shows per-pupil mastery bands and practice frequency. An optional
  class leaderboard shows nicknames only and can be disabled per class by the teacher.

## Privacy constraints (GDPR / GDPR-K / COPPA)

- No child accounts, e-mails, or real names are ever required from children.
- The nickname is child-chosen free text and must be treated as potentially identifying:
  the teacher can rename or hide any pupil's nickname (moderation duty).
- `profile_id` is a random, device-local pseudonym (32 hex chars, save v7+). It is resettable
  by resetting the local profile and links to no identity anywhere else.
- Lawful basis runs through the school (public-task/contract via the school as controller,
  with the app operator as processor), not through child consent. Czech GDPR digital-consent
  age is 15; the school-context basis avoids relying on it. Where COPPA applies, the school
  authorization route is used.
- Data minimization: only aggregates listed above are synced — never per-answer timestamps,
  free text beyond the nickname, or device identifiers. Retention is bounded; deleting a
  class cascades to all its synced snapshots. Leaving a class stops sync immediately.
- The Play data-safety declaration and the privacy policy must be updated **before** any
  networking build ships; today's "no data collected" claim stays true until then.

## Offline-first sync sketch

- The device stays the source of truth. Sync is an append-only outbox of snapshots keyed by
  `profile_id`; the server keeps the latest snapshot per profile per class.
- Conflicts resolve trivially (latest snapshot wins; mastery is monotone in practice).
- Networking would live behind the join-code gate, and preferably in a separate build flavor,
  because adding `INTERNET` changes the export contract (`permissions/internet=false` pin),
  the data-safety answers, and Families-policy review.

## How today's choices keep the door open

- Save v7 already generates and preserves a stable `profile_id` before any networking exists.
- The optional nickname is already the only display identity, so a leaderboard needs no new
  personal data.
- The single-file versioned save (`user://profile.json`) can grow a `classroom` section in a
  later save version without migration risk (the loader is field-tolerant).

## Out of scope now

Any code, any permission change, any backend or hosting selection, any teacher-dashboard
design. Implementation requires a fresh decision entry plus privacy-policy, data-safety, and
export-contract updates in the same change.
