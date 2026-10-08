# Fold Buddy Professional Roles into Certifications

Date: 2026-08-08
Status: Approved

## Problem

The same standing fact about a buddy ("Maria is a PADI Instructor, credential
12345") can be recorded in two places with different shapes:

- `certifications` (issue #553): buddy-owned rows with agency, level (including
  Divemaster, Instructor, Master Instructor, Course Director), card number,
  dates, photos, notes.
- `buddy_roles` (issue #395): "professional credentials" limited to
  Instructor / Divemaster / Dive Guide, each with agency, credential number,
  and notes only.

`buddy_roles` predates buddy-owned certifications and is now a degenerate
subset of them. The redundancy is user-visible (the buddy picker subtitle can
show "Instructor | Instructor - PADI #12345") and the split causes a real
functional gap: the instructor picker keys on `buddy_roles` only, so a buddy
recorded as Master Instructor or Course Director via certification is not
surfaced as an instructor.

## Decision

Delete the `buddy_roles` table and everything that serves it. Professional
status becomes a fact derived from a buddy's certifications. Existing
credential rows migrate into buddy-owned certification rows.

Decisions made during brainstorming:

- End state: full fold (not a hidden derived table, not sharpened semantics).
- Dive Guide: add `diveGuide` to `CertificationLevel` (it is a real rating);
  migrate `role=diveGuide` rows to it. No data discarded.
- Instructor picker rule: instructor-level only (Instructor, Master
  Instructor, Course Director) — matches who can actually certify and today's
  behavior. Divemaster/Dive Guide do not float to the top.

### Out of scope

Per-dive roles are a different axis (events, not qualifications) and are
untouched: `dive_roles` table, `dive_buddies.role`, `dives.diver_role`, the
role selector in the buddy picker, and `unanimousBuddyRolesForDives`.

## Domain model changes

- `CertificationLevel` gains `diveGuide('Dive Guide')`. It is inserted into
  every `CertificationLevelCatalog` ladder that includes `diveMaster`,
  directly below it. `primaryCertification()` ranks by ladder index, so this
  placement keeps primary-cert derivation correct.
- New helper `CertificationLevel.isInstructorLevel`: true for `instructor`,
  `masterInstructor`, `courseDirector`, and the agency instructor grades
  already in the enum — `cmas1StarInstructor`, `cmas2StarInstructor`,
  `cmas3StarInstructor`, `bsacOpenWaterInstructor`, `bsacAdvancedInstructor`,
  `bsacNationalInstructor`. Assistant-instructor grades are excluded (they
  cannot independently certify). This is the only derived-professional rule
  added; no broader `isProfessional` until something needs it.
- Deleted: `BuddyRoleCredential`, `kProfessionalBuddyRoles`. The `BuddyRole`
  enum is deleted if nothing else references it after the fold (per-dive roles
  moved to the `dive_roles` table in #551; `buddy_roles` was its last
  consumer). If a residual parse path needs the legacy names, they survive as
  string constants there only.

## UI changes

- Buddy edit page: remove the "Professional roles" section and
  `BuddyRolesEditor`. The certifications section is the one place to record
  Instructor / Divemaster / Dive Guide status.
- Buddy detail page: remove the credentials block; the certifications list
  already shows the same facts with more detail.
- Buddy picker: subtitle drops credential labels, keeps the primary-cert chip.
- `InstructorPickerField` (course + certification edit pages): groups buddies
  first when they hold a certification with `level.isInstructorLevel`,
  choosing the highest such cert if several; annotates from that cert (e.g.
  "PADI Instructor #12345" from agency/level/cardNumber); autofills instructor
  number from the cert's `cardNumber`. Callback signature passes the
  qualifying `Certification` instead of a `BuddyRoleCredential`. Any buddy
  remains selectable, as today.

## Data migration (schema v147, single step)

Originally claimed as v145 against main at 144 (2026-08-08); renumbered to
v147 on 2026-08-09 when PR #908 reserved 145 and the v146 bottom-time
recompute landed on main first — exactly the parallel-branch collision this
paragraph anticipated.

For each `buddy_roles` row, in `onUpgrade` AND as a guarded `beforeOpen`
backstop (amended during execution per review finding — see below):

1. Map role to level: `instructor` -> `instructor`, `diveMaster` ->
   `diveMaster`, `diveGuide` -> `diveGuide`.
2. Dedupe: if a certification already exists for the same
   `(buddyId, agency, level)`, do not insert; but if that cert lacks a
   `cardNumber` and the credential has one, backfill it.
3. Otherwise insert a buddy-owned certification with deterministic id
   `buddyrolecert-<rowId>` (reusing the buddy_roles row's own id: synced
   replicas share row ids, so independent per-device migrations converge on
   identical cert rows — same intent as #553's `buddycert-<buddyId>`),
   `name` = level display name, agency/cardNumber/notes and original
   created/updated timestamps carried over.
4. `DROP TABLE buddy_roles`; remove the table from the Drift schema.

The helper also runs as a guarded `beforeOpen` backstop (v106-style,
mirroring the other parallel-branch collision self-heals). This is safe
unlike #553's inline-cert copy: that helper's source columns
(`buddies.certification_level`/`_agency`) survive until v110, so re-running
it in `beforeOpen` could resurrect a user-deleted cert from still-present
source data. `_migrateBuddyRolesToCertifications` has no such hazard — its
own `DROP TABLE` makes the `sqlite_master` guard a strict no-op the instant
`buddy_roles` is gone, so there is no source data left to resurrect from
after the first run. The backstop exists purely to protect a database whose
`user_version` advanced past 147 (parallel-branch schema-version collision)
without ever executing the v147 `onUpgrade` block: without it, that database
would carry an orphaned `buddy_roles` table that nothing else reads, and its
credentials would silently vanish from the UI forever.

Update tripwire/contract tests: `parentRefs` completeness, streaming parity,
migration version tests.

## Sync and backup

- Remove `buddyRoles` from the sync serializer (`_hlcTargets`, mergeOrder,
  entityHasUpdatedAt, all switch cases) and from `parentRefs`.
- No tombstones for the drop: every device runs the same local conversion at
  upgrade; deterministic ids make the resulting cert rows identical, so
  nothing needs to sync-delete. The existing newer-schema filter
  (`changeset_reader.dart`) makes old devices hold an upgraded peer's
  changesets until they upgrade — nothing is applied lossily either way.
- Inbound legacy payloads: an old-schema peer can still publish `buddyRoles`
  entries; the upgraded device must skip unknown entity keys gracefully.
  Verify the serializer's default path does this; if it throws, add a skip.
- Old backups: restoring a pre-v147 backup surfaces credentials as certs
  automatically — verified: backup restore swaps in the SQLite file and
  reopens through the migration ladder (`DatabaseService.restore` →
  `initialize`), so `onUpgrade` converts the rows. No serializer shim.
  Cloud-sync adopt of an old base silently skips the buddyRoles section
  (`entityHasUpdatedAt` filter); convergence happens when that peer
  upgrades and runs the same deterministic migration.

## Merge and internal cleanup

- `buddy_merge_repository`: delete the `buddy_roles` move/union logic and
  `BuddyRoleSnapshot` (including its slice of undo). Certification union from
  #553 already gives the survivor the right professional facts.
- Remove `BuddyRepository` delegation methods (`getRolesForBuddy`,
  `getAllRoles`, `watchBuddyRolesChanges` for buddy roles) and
  `allBuddyRolesProvider`; the instructor picker watches certification data
  instead. Delete `BuddyRoleRepository`.

## Error handling and testing

- Migration test (v147 tripwire style): seed v146 with credential rows — each
  role; with and without matching certs; with and without card numbers —
  upgrade, assert converted rows, dedupe behavior, cardNumber backfill, and
  table absence.
- Widget tests: instructor picker groups/annotates from certs (including
  Master Instructor and Course Director — the gap today's picker misses);
  buddy edit page no longer shows the roles section.
- Sync contract tests updated for the removed entity; a test that an inbound
  legacy `buddyRoles` payload is skipped without error.
- l10n: remove orphaned `buddies_roles_*` keys across all locales; add
  `diveGuide` level strings where levels are localized.

## What is genuinely lost

The ability to record "acts as a dive guide/instructor professionally"
without phrasing it as a certification. Under this design that fact is a
certification row with only agency + level set (card number and dates may be
empty), which was judged acceptable.
