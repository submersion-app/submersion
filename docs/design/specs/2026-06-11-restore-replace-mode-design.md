# Restore Replace Mode (Library Epoch) — Design

- Date: 2026-06-11
- Status: Approved (design); implementation not started
- Owner: Eric
- Related: builds on the plaintext iCloud sync design (2026-06-01), the restore
  sync re-baseline fix (PR #309), and the upgrade-path hardening (PR #316).
  Work happens in the `restore-replace-mode` worktree.

## 1. Background

Restoring a database backup today always ends in a merge. Both restore entry
points converge on `BackupService._replaceDatabaseAndRebaselineSync()`
(`lib/features/backup/data/services/backup_service.dart:327` at main
`03bd0b04aac`), which swaps the database file and then clears the sync position
(`SyncRepository.rebaselineAfterRestore` -> `resetSyncState()`: last-sync
timestamp, remote file id, sync records, deletion log). Clearing the position
makes the next sync look like this device's first contact with existing cloud
data, which raises the "Combine Libraries?" dialog
(`lib/features/settings/presentation/pages/cloud_sync_page.dart:772`) whose only
forward action is "Merge and Sync". The merge pulls the current cloud library
back into the freshly restored data.

That is the right default, but it makes restore useless as a rollback for
synced data: whatever state the user restored away from merges straight back.
There is currently no way to say "this restored snapshot should win".

### Restore path parity (audit result)

The user asked whether restoring from a backup-history entry performs the same
steps as restoring from a picked file. Verified answer: yes at the core. Both
paths show the same `RestoreConfirmationDialog`, create a safety backup of the
current data first (`performBackup()`), run the same swap + re-baseline, the
same post-restore active-diver fixup, and the same Restore Complete page.

Two differences exist:

1. **Validation gap (to be fixed in this work).** The file-picker path runs
   `validateBackupFile()` (read-only SQLite open, expected-tables check) before
   restoring; the history path never validates, trusting a file that may have
   been corrupted or truncated since the record was written. The history path
   will validate its resolved source file (local or freshly downloaded) with
   the same routine before the swap.
2. **Source resolution (a feature, not a divergence).** The history path can
   download the backup from cloud storage when the local file is gone; the
   picker path is inherently local.

### Sync architecture facts this design relies on

- Sync is per-device files: every device uploads a full snapshot of its
  library as `submersion_sync_<deviceId>.json`; merges read peers' files.
- The payload (`lib/core/services/sync/sync_data_serializer.dart`,
  `SyncPayload`) already carries top-level `version`, `exportedAt`,
  `deviceId`, `checksum`, `data`, `deletions`.
- `SyncService.deleteDeviceSyncFile()` (`sync_service.dart:1453`) already
  deletes a named per-device file from the cloud (built for identity
  retirement); Replace generalizes this to all sync files.
- Device identity is dual-anchored (in `sync_metadata` and mirrored in
  SharedPreferences) and reconciled at launch by `SyncInitializer`, so a
  restored database does not hijack identity. The epoch record reuses this
  pattern.

## 2. Decisions taken

These were settled with the owner during design review:

1. **Replace scope: everywhere.** Replace wipes the cloud sync files, re-seeds
   them from the restored library, and writes a replacement marker; other
   devices detect it and are prompted before any merge can occur.
2. **Peer prompt: adopt only.** A peer offers "Adopt restored library" (after
   an automatic local safety backup) or "Not now" (sync stays paused). There
   is deliberately no "merge mine in" escape hatch: Replace means replace.
3. **Mechanism: marker file plus epoch-stamped sync files** (Approach A),
   chosen over stamp-only inference and heuristic detection for race
   resistance and auditability.

## 3. Goals and non-goals

### Goals

- Offer a Replace mode alongside the existing Merge behavior whenever a
  restore happens while cloud sync is enabled — from either restore entry
  point, with identical behavior.
- Make Replace stick: stale cloud files and late uploads from offline peers
  must not leak the old library back in.
- Give every other device an explicit, safe adoption step with an automatic
  safety backup before its data is overwritten.
- Close the history-restore validation gap (parity fix).

### Non-goals (explicitly out of scope)

- No Replace option in the generic first-contact "Combine Libraries?" dialog;
  only restore-initiated replaces.
- No partial or date-based merging (e.g., "keep peer dives newer than the
  backup"). Adopt replaces the peer's synced data wholesale.
- No changes to backup creation, pruning, or the backup history store.
- No changes to the Merge path beyond sharing the redesigned dialog.
- No media/blob handling changes; sync remains structured data only.

## 4. User experience

### Restore confirmation dialog (shared by both entry points)

When cloud sync is enabled and a provider is configured, the existing
`RestoreConfirmationDialog` gains a mode choice (radio group above the warning
text):

- **Merge on next sync** (default, pre-selected): today's behavior. Restore
  locally; the next sync combines restored data with the cloud library.
- **Replace everywhere**: the restored backup becomes the library — locally,
  in the cloud, and on every synced device.

The confirm button label follows the selection ("Restore" vs "Restore and
Replace Everywhere"). Confirming Replace shows one extra confirmation dialog
stating the consequence: the library on all synced devices will be replaced
with this backup, and each device makes a safety backup of its current data
first. When sync is disabled or signed out, the dialog is unchanged from today
(single Restore action, no mode choice).

The pre-migration restore variants of the dialog keep their existing
schema-gated flows; when they permit a restore and sync is enabled, they get
the same mode choice.

### Peer devices

A peer discovers the replacement at its next sync attempt:

- **Automatic sync** halts before merging and shows a persistent banner
  ("Sync paused: the library was replaced from a backup on <device> at
  <time>. Tap Sync Now to review."), following the existing
  `firstSyncAwaitingConfirmation` banner pattern.
- **Manual Sync Now** (or tapping through the banner) shows a dialog:
  - **Adopt restored library** — automatic local safety backup (a normal
    backup-history entry), then this device's synced data is replaced by the
    restored library and sync resumes.
  - **Not now** — sync stays paused; the banner remains.

If the peer's library is empty (no dives), it adopts silently with no prompt,
consistent with how an empty device already joins sync without the
first-contact dialog.

### The replacing device

Sees no adoption prompt (it initiated the replace) and lands on the existing
Restore Complete page.

### Localization

All new strings are added to `app_en.arb` and translated into all ten
non-English locales, then regenerated — no English fallbacks.

## 5. Mechanism: the library epoch

A replace mints a new epoch id (UUID v4). Three records carry it:

1. **Cloud marker file `submersion_library_epoch.json`** in the sync folder:
   `{epochId, replacedAt, deviceId, deviceName, appVersion}`. Authoritative
   statement of the current library generation and the audit record of who
   replaced it and when. The name must NOT contain the `submersion_sync` stem:
   peer-file discovery (`SyncInitializer.peerSyncFiles`, and the matching
   listing in `SyncService.performSync`) lists files by that stem and would
   otherwise treat the marker as a peer's sync file.
2. **Epoch stamp in every sync payload**: a new optional top-level
   `epochId` field in `SyncPayload`. Absent (legacy) or non-current stamps
   mark a file as stale: ignored by every merge and opportunistically deleted
   by devices on the current epoch. The existing integer `version` field is
   left for the implementation plan to decide (the field is additive and
   `fromJson` must tolerate its absence either way).
3. **Per-device last-accepted epoch**, dual-anchored like device identity:
   a `lastAcceptedEpochId` column on `sync_metadata` plus a SharedPreferences
   mirror, reconciled at launch by `SyncInitializer`. The mirror is
   load-bearing: a Merge-mode restore swaps in a database whose in-DB epoch is
   stale (or null); without the mirror realigning it, the restoring device
   would wrongly prompt itself to adopt, and its uploads would carry a stale
   stamp that current-epoch peers ignore.

A **pending-replace intent** (the minted epoch id plus the marker metadata to
write, as JSON in SharedPreferences) makes the cloud side of a replace
at-least-once: it survives restarts and is retried until it succeeds, and
while it exists the device never merges.

## 6. Flows

### 6.1 Replace execution (restoring device)

The existing restore pipeline runs unchanged first: safety backup -> validate
(both paths, per the parity fix) -> database swap -> sync re-baseline
preserving live device identity. Then, only in Replace mode:

1. Persist the pending-replace intent (new epoch id) to SharedPreferences.
2. Execute the cloud replacement:
   a. Write the marker file first (closes the race where a peer syncs
      mid-replace and would otherwise misread a half-empty folder).
   b. Best-effort delete every sync file: all peers' files, our own old file,
      the legacy shared `submersion_sync.json`, and conflict-copy duplicates.
   c. Upload our own sync file — the normal full-snapshot upload — stamped
      with the new epoch.
3. Record the new epoch as last-accepted (DB + mirror) and clear the intent.

If the device is offline or any cloud step fails, the local restore stands,
the intent persists, and the next sync attempt executes the replace instead of
merging.

### 6.2 Sync gating (every device, top of `performSync`)

1. Pending-replace intent present? Execute flow 6.1 step 2-3 and stop.
2. Read the marker. Read failure: treat as a sync failure (no merge, no
   prompt — never guess about a replace). Marker absent: if our last-accepted
   epoch is null, this is the pre-epoch world; behave exactly as today. If our
   last-accepted epoch is non-null, rewrite the marker from it (self-healing)
   and continue.
3. Marker epoch equals our last-accepted epoch: normal sync, but exclude peer
   files whose stamp is not the current epoch from the merge, and
   opportunistically delete them.
4. Marker epoch differs: halt before any download, merge, upload, or deletion
   processing. Raise the awaiting-adoption state consumed by the Section 4
   banner/prompt. If the local library is empty, adopt silently (flow 6.3)
   without prompting.

### 6.3 Adoption (peer that accepts)

1. Safety backup via the existing `performBackup()` (normal history entry).
2. Download all current-epoch sync files.
3. Apply them as authoritative, inside a transaction: upsert every cloud
   record for every entity type in `SyncData`; delete local records of synced
   types that are absent from the cloud set, in FK-safe order, reusing the
   FK-repair machinery from the sync-deletion work. Device identity (device
   id, instance token) is untouched: adoption changes data, not identity.
   Local-only state (backup history, non-synced tables, app preferences
   outside synced settings) is untouched.
4. Reset the sync baseline (the same re-baseline used after restore), record
   the epoch as last-accepted (DB + mirror), and run the existing post-restore
   active-diver fixup.
5. Upload our own freshly stamped sync file and resume normal sync.

If adoption crashes mid-way, the transaction rolls back the data apply and the
last-accepted epoch was never advanced, so the next sync prompts again; the
apply is idempotent. The extra safety backup taken on retry is harmless.

## 7. Error handling and edge cases

- **Partial cloud wipe**: stale files are inert (wrong or missing stamp) and
  get cleaned up opportunistically by current-epoch devices.
- **Offline peer uploads a stale file after the replace**: ignored by
  everyone; that peer is prompted to adopt the moment it next reads the
  marker. Gating runs at the top of `performSync`, so the peer cannot upload
  before it has checked the marker in that same run.
- **Repeated replaces**: each mints a new epoch; the last marker written wins.
  Devices still on an older epoch are prompted once, against the newest epoch.
- **Marker unreadable (transient)**: sync fails closed for that run.
- **Marker missing but stamped files present** (e.g., user deleted it):
  current-epoch devices self-heal by rewriting it; devices that never saw any
  epoch behave as legacy and may merge — accepted residual risk, noted in
  section 9.
- **Replace fails after the local swap**: the user's data is already restored
  locally; the persisted intent retries the cloud side. "Reset Sync State"
  remains the manual escape hatch and must clear any pending intent and
  awaiting-adoption state it finds.
- **Restore-with-Merge after a historical replace**: handled by the
  dual-anchored last-accepted epoch (section 5, item 3) — no false adopt
  prompt, uploads carry the current stamp.

## 8. Compatibility and limitations

- **Older app versions** ignore the marker and stamps entirely. Replace
  propagates correctly only once all of the user's devices run the version
  shipping this feature. Until then an old-version device can merge the old
  library back into its own local data and upload an unstamped (therefore
  ignored) file. Stated limitation, recorded in release notes.
- **Legacy shared `submersion_sync.json`** is deleted during the wipe and,
  being unstamped, stays inert even if the delete fails.
- **iCloud propagation cannot be tested in the iOS Simulator** (ubiquity
  containers do not propagate there). Final verification requires real
  hardware: replace on Mac, adopt on iPhone, and the reverse.

## 9. Testing strategy

TDD throughout; tests are written before the code they cover.

- **Unit**: epoch-gating decision table (no marker / matching / differing /
  unreadable / missing-with-local-epoch); pending-intent persistence, retry,
  and merge fencing; stale-stamp filtering; marker self-healing; dual-anchor
  reconcile for the epoch (including the Merge-restore-after-old-replace
  case); authoritative apply (upserts, FK-safe deletes, transactionality,
  idempotent re-run, local-only tables untouched); history-restore validation
  parity; marker filename excluded from peer-file discovery.
- **Widget**: restore dialog with sync on/off (mode choice presence, dynamic
  confirm label, second confirmation); adopt prompt; paused-sync banner;
  empty-library silent adopt.
- **Service-level with a fake cloud provider**: full replace sequence; peer
  syncing mid-wipe sees the marker first; offline replace resuming on next
  sync; stale-epoch upload ignored and cleaned; repeated replace.
- **Mocks**: sync-state/notifier additions require updating the existing test
  mocks; the implementation plan lists the affected mock files explicitly and
  gates on whole-project `flutter analyze`.

## 10. Risks and open questions (for the implementation plan)

- **Nonce-twin interplay (PR #316)**: after a replace wipes a peer's own
  file, launch-time nonce reconciliation must treat "own file absent" as
  benign (not a foreign-nonce identity event). Verify; even if a fresh
  identity were adopted, marker gating still halts the merge, so the failure
  mode is cosmetic (a new device id), not data loss.
- **Marker write vs provider consistency**: iCloud is eventually consistent;
  a peer could briefly read a stale marker after a replace. The stamp filter
  prevents stale data from merging in that window; the peer prompts on its
  next run. No correctness loss, possible one-cycle delay.
- **Entity coverage of the authoritative apply**: enumerate every entity type
  in `SyncData` at implementation time and add a drift guard so future synced
  tables cannot fall out of adoption silently (mirror of the coverage guard
  in the 2026-06-01 sync design).
- **`SyncPayload.version` bump**: decide whether adding the optional
  `epochId` warrants incrementing the payload version int; either way old
  readers must keep parsing files that lack it.
- **Where the marker read lives**: one small read per sync is the accepted
  cost; if profiling shows it matters, it can fold into the existing
  list-files call (names alone cannot carry the epoch, so a read of the
  marker object is still required).
