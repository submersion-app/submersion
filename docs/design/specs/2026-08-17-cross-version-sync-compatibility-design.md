# Cross-Version Sync Compatibility

**Date:** 2026-08-17
**Issue:** [#1089](https://github.com/submersion-app/submersion/issues/1089)
**Status:** Approved design, pending implementation plan

## Problem

Submersion ships through two channels that advance at different speeds. GitHub
releases go live the moment CI finishes; App Store releases wait on Apple
review (submission is already automated by `promote.yml`, so the review window
is the irreducible gap). Every release that bumps the database schema opens a
multi-day window in which store builds run an older schema than direct builds.

The sync layer holds any peer publishing from a newer schema
(`changeset_reader.dart`, the `peerSchema > localSchemaVersion` gate). The
hold is per-peer, non-destructive, and correct in mechanism, but it fires on
*any* schema difference, not just breaking ones. During a review window every
store device stops receiving from every direct-download device. As of
2026-08-17 the live skew was App Store 1.7.2 (schema 137) against GitHub 1.7.4
(schema 150), with main at schema 153.

Two adjacent defects compound it:

- The held-peer banner tells the user to "update this device" when no update
  exists in their channel yet.
- Restoring a backup written by a newer schema passes validation, swaps the
  file in, and only then hits the version guard, leaving the app on a terminal
  error screen whose sole remedy is a GitHub download link that store users
  cannot act on.

## Verified findings the design rests on

A spike (2026-08-17) ran a simulated v137 peer round-trip through the real
pipeline (`performSync` to `_mergeEntity` to upsert) against a genuine
post-137 column (`dives.visibility_meters`, added v144). All three cases
passed:

1. An old-peer edit that legitimately wins LWW applies, and the post-137
   column survives via the `_overlayOntoLocal` merge (`sync_service.dart`,
   shipped for issue #474). Omitted keys keep local values; explicit nulls
   still clear.
2. A tied-HLC republish (unedited old-peer snapshot) applies nothing: only a
   strictly greater remote HLC wins.
3. A row created on the old device applies cleanly; newer nullable columns
   backfill as null.

Structural findings:

- Unknown entity types are invisible to old readers on both paths: changeset
  apply iterates the typed `SyncData` object's own fields, and base apply
  requests only the reader's own tables. This holds for the frozen 1.7.2 code.
- The adopt path (`_adoptApplyStreaming`) wipes tables before inserting, so
  the missing overlay there cannot clobber anything.
- `SyncManifest.schemaVersion` has exactly one behavioral reader: the gate.
  `SyncDeviceFootprint.schemaVersion` is informational with no UI consumer.

Conclusion: the hazard the gate defends against (an old device republishing
rows stripped of newer columns) is already closed by the overlay for additive
schema changes. The gate only needs to fire on declared breaking changes.

## Design

### 1. Compatibility floor

`AppDatabase` gains a second constant beside `currentSchemaVersion`:

```dart
/// The oldest schema whose reader can apply this build's sync payloads
/// without loss or misinterpretation. Raise ONLY on a breaking change;
/// see the bump rules below.
static const int minimumCompatibleSchemaVersion = 137;
```

The four manifest stamp sites in `changeset_writer.dart` change from stamping
`currentSchemaVersion` into `manifest.schemaVersion` to stamping the floor,
and additionally stamp a new informational field
`writerSchemaVersion: currentSchemaVersion` for diagnostics and support. The
`schemaVersion` doc comment in `sync_manifest.dart` is rewritten to describe
floor semantics.

**The gate comparison does not change.** The shipped comparison
`manifest.schemaVersion > localSchemaVersion` already computes "the peer's
floor exceeds my schema," which is the correct predicate. Shipped 1.7.2
devices therefore start accepting floor-stamped payloads with no update on
their side; the fix deploys one-sidedly. (The reader gains one additive
change for messaging, described in section 5: collecting held peers' display
names. The gate predicate itself is untouched.)

### 2. Initial floor value: 137

Floor 137 asserts that schemas 138 through 153 are compatibility-preserving
for a v137 reader. The spike verified the additive changes empirically. One
event in the range is not purely additive and is accepted as a documented
caveat: **v147 removed the `buddyRoles` entity** (folded into
certifications). Consequences for a v137 reader: its buddy-role edits publish
into a void until it updates (newer readers no longer parse the entity), its
local role display goes stale, and the fold-at-migration stamps fresh HLCs
that could win LWW over a newer device's intervening certification edits.
This is bounded, low-stakes (buddy professional credentials), causes no
round-trip loss, and self-heals when the device updates. The alternative
(floor 147) would hold the entire 1.7.2 App Store fleet and defeat the fix.

### 3. Migration discipline

The floor is a per-migration human judgment, so the judgment gets a written
rule. The doc comment on `minimumCompatibleSchemaVersion` enumerates:

Bump the floor when a migration:

- drops, renames, or retypes an existing synced column
- changes the meaning or units of an existing column's values
- removes or folds a synced entity (the v147 case)
- tightens a constraint an old writer's payloads would violate

Do not bump for:

- new tables or new synced entities
- new nullable or defaulted columns
- new indexes, dedupe passes, or data repairs that preserve meaning

The spike test is promoted into the suite as
`cross_version_roundtrip_test.dart`. Its v137 projection is driven by a
declared list of post-137 keys per entity, so each schema bump extends the
list consciously rather than silently.

### 4. Restore hardening

- **Pre-check at both entry points.** `restoreFromFile` reads
  `PRAGMA user_version` from the materialized plaintext immediately after
  `_materializePlaintextBackup`, which covers encrypted backups, before
  `performBackup()` and before any swap. `validateBackupFile` gains the same
  check on the plaintext path it already deep-inspects. A newer-than-app
  schema throws a typed exception the dialogs render as "this backup needs
  Submersion X or later," cancel-only, mirroring the existing pre-migration
  hard block in `restore_confirmation_dialog.dart`.
- **Auto-rollback backstop.** The post-swap `initialize()` in
  `DatabaseService.restore` currently sits outside the swap's rollback path;
  a version mismatch there leaves the app with no working database. It gets
  wrapped: on `DatabaseVersionMismatchException`, restore the `.pre-restore`
  copy, reopen, and rethrow. The user sees an error dialog and keeps a
  working app. Rollback is silent and automatic; no recovery UI is built,
  because with the pre-checks in place this path is nearly unreachable.
- `DatabaseVersionMismatchException` fields are renamed to
  `storedSchemaVersion` and `supportedSchemaVersion` (both were already
  schema numbers; the old names implied an app version).

### 5. Channel-aware messaging

The app knows its channel via `UpdateChannelConfig.current`
(`UPDATE_CHANNEL` dart-define; `github` default, `appstore`, `playstore`,
`msstore`, `snapstore`).

- **Held-peer banner** (`settings_cloudSync_peerRequiresUpdate_banner`): the
  reader collects `deviceName` from held peers' manifests (field already
  exists) alongside the ids, following the epoch-skip banner's
  `skippedPeerLabels` pattern. New text names the peers, and on store
  channels replaces "Update this device" with wording acknowledging the
  update may still be in review. All 11 locales.
- **`VersionMismatchView`** (startup, e.g. a store build opening a direct
  build's newer database): on store channels, explain that the store version
  is behind and the update is coming, rather than only offering a GitHub
  download link.

## Testing

- Durable cross-version round-trip test (promoted spike): old-peer edit with
  overlay survival, tied-HLC no-op, old-device row creation.
- Writer test: manifests stamp the floor into `schemaVersion` and the true
  version into `writerSchemaVersion`.
- Reader test: a manifest with floor 137 from a writer at 153 applies on a
  137-local reader; a floor above local holds the peer.
- Restore pre-check tests: plaintext and encrypted, each with newer, equal,
  and older backup schemas.
- Rollback test: a version mismatch surfacing at post-swap reopen restores
  the pre-restore copy and leaves an open database.
- Banner tests: peer naming, store-channel wording.

Known traps: test fakes implementing `SyncNotifier` and `SyncRepository`
break on signature changes and only `flutter analyze` catches it; run the
whole suite before claiming green.

## Rollout

Once a release with the floor-stamping writer ships, App Store devices stop
being cut off during review windows permanently, including future windows,
because shipped old readers benefit from the writer-side stamp alone. The
2026-08 incident resolves independently when Apple approves iOS 1.7.4.

## Out of scope

Filed or to be filed separately:

- The Google Play promotion step has failed in all 7 recorded `promote.yml`
  runs; Android stable users are stranded in the same way as issue #1089.
- A CI check asserting live per-platform store versions against the released
  tag, so channel divergence is observed rather than inferred.

Explicitly not built:

- Unknown-field echo (old clients preserving and republishing fields they do
  not understand). The overlay already covers the fleet's needs; echo only
  pays off once old clients carry it, and no current gap requires it.
- Recovery UI for the `.pre-restore` copy (superseded by automatic rollback).
