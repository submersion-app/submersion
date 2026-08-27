# Reset/rebuild UX: closing the remaining pieces of issue #652

Date: 2026-08-11
Issue: [#652](https://github.com/submersion-app/submersion/issues/652)
Branch: `worktree-issue-652-reset-rebuild-ux` (from `origin/main` @ ae5a0c47ced)

## Background

Issue #652 was filed as a sync-protocol incident: after a database reset or
library reimport on one device, peers kept publishing an older library
generation, and syncs reported success while silently merging nothing.

The protocol half has shipped and is explicitly out of scope here:

- **#646** made the library-epoch fence strict. `ChangesetReader.pull` skips any
  peer whose `manifest.epochId` differs from the accepted epoch, including
  unstamped peers, with no timestamp exception.
- **#661** stopped Reset Database from being undone: `disableForDatabaseReset()`
  cancels the auto-sync debounce, disables auto-sync, and signs out before the
  wipe.
- **#720** cleared the follow-on failure where a device could hold an unprovable
  epoch and skip every peer forever behind a green "Sync complete".

What remains is user-facing. This work must not change fence semantics.

## Goals

1. The reset flow describes what it actually does, including the sync sign-out.
2. A user can make this device's library authoritative without laundering it
   through a backup restore.
3. A user who meets the first-contact dialog learns the replace path exists.
4. Devices that still need to adopt are named, not counted.

## Non-goals

- No change to epoch fence semantics, `_runEpochGate`, or `ChangesetReader`
  skip logic beyond collecting names.
- No standing "Devices" list on the Cloud Sync page. Considered and rejected:
  in a healthy fleet it is pure noise, its unique value only materialises in
  the failure case the banner already covers, and it would launch showing
  opaque device ids until peers republish. Revisit as a follow-up if the
  pre-sync question ("is my iPad current?") proves to matter.
- No fleet-wide reset. Reset stays local-only, per the decision recorded in
  #661.

## Design

### Item 1 — reset flow copy

Three strings change, propagated to all 11 locales. No widget or behavior
changes; `ResetDatabaseDialog` and `ResetCompletePage` keep their structure.

| Key | Change |
| --- | --- |
| `settings_storage_resetDatabase_subtitle` | Scope to this device |
| `settings_storage_resetDialog_body` | Add: cloud library is not deleted, other devices keep their data, cloud sync will be disconnected so the reset is not undone, reconnect in Settings > Cloud Sync |
| `settings_storage_resetComplete_description` | Add: sync is currently off, and where to turn it back on |

Approved body text:

> Permanently deletes all data on THIS device - dives, sites, gear, settings.
> A backup is created first.
>
> Your cloud library is not deleted, and other devices keep their data. Cloud
> sync will be disconnected so the reset is not undone; you can reconnect it in
> Settings > Cloud Sync.

**Known caveat, accepted.** `_handleResetDatabase` calls
`disableForDatabaseReset()` inside a `try/catch` that only `debugPrint`s on
failure (`storage_settings_page.dart:428-432`). The dialog therefore promises a
disconnect that can silently fail. Accepted: the promise holds in every normal
case, and the failure mode is exactly the pre-#661 behavior. Not worth blocking
a reset on.

### Item 2 — "Replace cloud library" action

#### Two new files

Today the same "device identity for a marker" logic exists in three places:

- `BackupService._mintPendingReplace` (`backup_service.dart:825`)
- `SyncNotifier._deviceMetadata` (`sync_providers.dart:918`)
- and item 4 needs it a third time, for the manifest.

Because the third consumer is the manifest writer - which has nothing to do
with replace intents - this extracts as two files, not one:

**`lib/core/services/sync/sync_device_metadata.dart`** - who this device is,
independent of what it is being stamped onto:

```dart
class SyncDeviceMetadata {
  /// (deviceId, deviceName, appVersion), each degrading to a safe default.
  /// deviceName is sanitized: empty, whitespace, and 'localhost' become null.
  Future<({String id, String? name, String? appVersion})> resolve();
}
```

**`lib/core/services/sync/library_replace_intent.dart`** - the replace-specific
piece, depending on the above:

```dart
class LibraryReplaceIntent {
  /// Mint, persist, and return the pending-replace marker.
  Future<LibraryEpochMarker> mint();
}
```

`BackupService._mintPendingReplace` delegates to `LibraryReplaceIntent`;
`SyncNotifier._deviceMetadata` delegates to `SyncDeviceMetadata`; the manifest
writer takes a name resolved from `SyncDeviceMetadata`. Behavior is otherwise
unchanged, so the existing replace-restore tests act as the regression net.

**One deliberate behavior change:** sanitization now applies to every marker,
not just manifests. A device whose hostname is `localhost` previously published
that as `LibraryEpochMarker.deviceName` and rendered it in adopt prompts; it now
falls back to `displayName`'s device-id branch. This is an improvement and is
covered by a test.

Import direction is already established: backup providers import sync
providers, so a sync-layer service is reachable from both callers.

#### Data flow

```
Cloud Sync page - tap "Replace cloud library"
      |
      +- SyncNotifier.replacePreflight()  -> (localDiveCount, peerFileCount)
      |     reuses diveRepository.getDiveCount() + syncInitializer.peerSyncFiles(),
      |     the pair firstSyncMergeInfo already uses, with an 8s timeout
      |
      +- ReplaceCloudLibraryDialog - type "Replace" - Cancel | Replace
      |
      +- backupService.performBackup(isAutomatic: true)
      |
      +- SyncNotifier.replaceCloudLibraryFromThisDevice()
            +- LibraryReplaceIntent.mint()   -> pendingReplace persisted
            +- performSync()
                  +- _runEpochGate sees pendingReplace -> executeLibraryReplace()
```

The safety backup runs in the widget layer, not `SyncNotifier`, because backup
providers import sync providers; a widget may import both. This mirrors
`adopt_replaced_library_dialog.dart`, which documents the same constraint.

#### Properties inherited from existing machinery

- **Crash-safe.** `executeLibraryReplace` keeps the intent on failure so the
  next sync retries instead of merging, and `_initialize`
  (`sync_providers.dart:623`) runs `performSync()` on launch whenever
  `pendingReplace != null`. A force-quit between mint and execute resumes with
  no new code.
- **Outranks awaiting-adoption.** `_runEpochGate` checks `pendingReplace`
  before reading the cloud marker (`sync_service.dart:725`), so a device fenced
  off by someone else's replacement can still declare "mine wins". This makes
  the action a universal escape hatch.
- **No restart.** The restore path restarts because the database is swapped
  under a running app. Here the database is already the desired one, so
  mint-then-sync suffices.

#### Confirmation

Type-to-confirm, reusing the reset dialog's pattern, because the blast radius is
strictly larger than reset's. Approved text:

> **Replace Cloud Library?**
>
> This device's library becomes the one every device uses.
>
> The cloud library is erased and replaced with this device's 1,247 dives.
> 2 other devices will be asked to adopt it; until they do, their changes are
> not merged.
>
> A backup of this device is created first. This cannot be undone.
>
> [Type "Replace" to confirm]  [Cancel] [Replace]

#### Error handling

| Case | Behavior |
| --- | --- |
| No provider / not authenticated | Tile not rendered |
| `pendingReplace` already set | Skip minting; run `performSync()` |
| Preflight times out or throws | Show the dialog with a count-less string variant; never let a pre-check gate the escape hatch (the rule `libraryReplaceInfo` already follows) |
| `performSync` fails after mint | Intent persists; surfaced via the normal sync error state, retried next sync/launch |

#### UI placement

Cloud Sync page gains a danger-zone header and the replace tile at the end of
the Advanced section, BELOW the existing Sign Out tile.

Sign Out deliberately stays outside the danger zone: it is reversible and
routine, so putting it under a "Danger Zone" header would both overstate it and
dilute the header for the action that actually earns it. The header therefore
introduces only the replace tile, matching how storage settings scopes its own
danger zone to Reset Database.

The tile renders only when a cloud provider is configured, and is disabled
while a sync is running -- publishing under an epoch the replace is about to
wipe would race the writer.

### Item 3 — first-contact hint

A new key `settings_cloudSync_firstSync_replaceHint`, rendered as a second
paragraph in the existing dialog. Deliberately not appended to
`settings_cloudSync_firstSync_dialogContent`, which carries `{deviceCount}` and
`{diveCount}` placeholders; a separate key is independently translatable and
independently testable.

The dialog's `content` becomes a `Column` instead of a bare `Text`. No new
buttons, no navigation, no destructive action reachable from this dialog.

Approved text:

> If instead this device's library should replace what is in the cloud, cancel
> and use Settings > Cloud Sync > Replace cloud library.

### Item 4 — name the skipped peers

#### Protocol

`SyncManifest` gains `String? deviceName`, nullable in `toJson`/`fromJson`,
matching the shape `schemaVersion` documents ("Null on manifests written before
this field existed"). `ChangesetWriter.publish` populates it from a value
`SyncService` resolves once via `SyncDeviceMetadata`, keeping `dart:io` out of
the writer and making it injectable in tests.

Sanitization (`localhost`, empty, whitespace -> null) lives in
`SyncDeviceMetadata` and therefore applies to markers as well as manifests; see
item 2.

#### Flow to the UI

```
ChangesetReader.pull - already downloads every peer manifest
      +- for skipped peers only: collect id -> deviceName
ChangesetReadResult.skippedPeerNames  ->  SyncResult.skippedPeerNames
      +- SyncNotifier resolves labels: name ?? "device ${id.substring(0, 8)}"
            +- SyncState.skippedPeerLabels (List<String>)
                  +- localized banner card, mirroring the newer-schema card
```

Names appear only once a peer republishes a manifest; until then that peer shows
as `device a1b2c3d4`. The degradation is per-peer, not all-or-nothing.

The banner mirrors `newerSchemaPeerCount` (`cloud_sync_page.dart:996`), which is
the structural twin of this case and is already rendered as a localized card
rather than service-layer English.

#### Folded-in cleanup

`pullResultMessages` currently emits English sentences for both skipped peers
and newer-schema peers, and the newer-schema sentence is rendered *in addition
to* its banner - the notice appears twice today.

Remove both peer sentences from `pullResultMessages`, leaving `recordsFailed`
and `adoptedFreshIdentity`, which have no banner. This fixes the existing
double-render and removes untranslated user-facing text from the service layer.

This is the one change in the spec that is not strictly additive. It is
deliberately isolated so it can be dropped at review without touching anything
else.

## Testing

| Layer | Coverage |
| --- | --- |
| Intent | Mints and persists a marker; degrades id/name/version independently |
| BackupService | Replace-mode restore still mints (existing tests) |
| Manifest | Round-trip with and without `deviceName`; old bytes parse to null |
| Metadata | `localhost`, empty, whitespace -> null; real name preserved; epoch marker falls back to the id branch for a sanitized-away name |
| Reader | Names collected for skipped peers only, not healthy ones |
| Notifier | Skips mint when already armed; errors without a provider; label falls back to `device xxxxxxxx` |
| Messages | `pullResultMessages` no longer emits peer sentences; still emits failures |
| Widget | Replace disabled until "Replace" typed; Cancel mints nothing; confirm calls backup then replace; preflight failure renders count-less variant; banner renders labels and is absent when nothing was skipped |
| l10n | New keys present in all 11 locales |

The existing ~903 tests in `test/core/services/sync` and `test/features/backup`
must stay green; none of this touches fence semantics.

## Decisions settled during design

- Replace is reachable from Settings only, not from the first-contact dialog.
  Putting a fleet-wide wipe one tap away in a routine prompt was rejected.
- Skipped peers are surfaced as a conditional banner, not a standing device
  list.
- The reset flow explains; it does not gain navigation or new controls.
- Replace uses type-to-confirm, a stricter gate than the existing adopt dialog,
  because its blast radius is fleet-wide where adopt's is one device.
