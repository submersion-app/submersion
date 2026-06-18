# Smoother Restore: Resume Sync Without a Manual "Sync Now"

- **Date:** 2026-06-15
- **Status:** Implemented
- **Branch:** feat/smoother-restore-sync
- **Related:** [restore-replace-mode](2026-06-11-restore-replace-mode-design.md), [incremental-sync-changeset-log](2026-06-14-incremental-sync-changeset-log-design.md)

## Problem

When cloud sync is enabled and the user restores a database, syncing silently stops until the user manually opens Cloud Sync settings and taps **Sync Now**. Users are typically unaware this is required, so their devices quietly fall out of sync.

This shows up in two distinct ways:

1. **On the device that restored** (Merge restore): the Cloud Sync page shows *"First sync needs confirmation. Tap Sync Now to review."* Auto-sync silently defers.
2. **On the other devices** (after a Replace-everywhere restore elsewhere): each shows *"Sync is paused: the library was replaced from a backup on '<device>'. Tap Sync Now to review."* Sync pauses until the user manually adopts.

Both are real and both leave the user with no signal that action is needed beyond a banner buried in settings.

## Root cause

Two separate gates, firing in two different restore modes.

### Gate 1 — first-contact confirmation (restoring device, Merge mode)

- A restore calls `_replaceDatabaseAndRebaselineSync` (`backup_service.dart`) -> `rebaselineAfterRestore` (`sync_repository.dart`) -> `resetSyncState`, which nulls `lastSyncTimestamp` / `lastSyncProvider`. This is deliberate: it forces a clean re-publish and re-pull after restore.
- `firstSyncMergeInfo()` (`sync_providers.dart`) treats `lastSyncTime == null` + local dives present + peer files in the cloud as "first contact with an existing library," and returns non-null.
- `performSync(auto: true)` (`sync_providers.dart`) sees that and **defers without syncing**, setting `firstSyncAwaitingConfirmation = true`. Every automatic trigger (sync-on-launch, sync-on-resume, post-write debounce) hits this and quietly backs off.
- Only a manual **Sync Now** + confirming the "Combine Libraries?" dialog completes a sync and rewrites `lastSyncTime`, clearing the state.

**The conflation:** the gate's "have I synced here before?" signal (`lastSyncTime`) is exactly the value a restore is designed to wipe. So a restored device is indistinguishable from a fresh install — even though it had an established sync relationship, and even though the restore flow already asked the user to choose Merge vs. Replace. That Merge/Replace choice is already consent to combine; the gate then re-requests the same consent, silently, in a different place.

### Gate 2 — library-replacement adopt (other devices, Replace mode)

- A Replace-everywhere restore mints a new library epoch and re-seeds the cloud (`executeLibraryReplace`, `sync_service.dart`).
- Other devices detect the unfamiliar epoch on their next sync (`_runEpochGate`, `sync_service.dart`) and, if they hold local dives, set `replaceAwaitingAdoption = true` and **pause** (`performSync`, `sync_providers.dart`). Devices with zero dives already auto-adopt.
- Adopting (`adoptReplacedLibrary`, `sync_service.dart`) is **destructive**: it deletes every local record not in the restored library and replaces local data, after taking a safety backup.
- Two gaps make the pause silent: detection only happens *if a sync runs* (so it is coupled to the auto-sync toggles), and the only surface is the settings-page banner.

The restoring device in **Replace** mode is already smooth: `_initialize` (`sync_providers.dart`) executes the pending replace via `performSync()` (auto=false) on next launch, regardless of toggles. Only the Merge restoring-device path and the other-device adopt path need work.

## Decisions

| # | Decision | Choice |
|---|----------|--------|
| D1 | After a Merge/Replace restore, what should sync do on the restoring device? | **Auto-resume + notice.** The restore dialog's Merge/Replace choice is the consent; carry it forward and show a brief, non-blocking notice. |
| D2 | Should restore proactively trigger a sync, or rely on existing triggers? | **Force one sync after restore**, regardless of the auto-sync toggles. |
| D3 | When another device did Replace-everywhere, how should the other devices behave? | **Unmissable confirm.** Keep the destructive adopt behind a confirmation, but surface it impossible-to-miss (global dialog + persistent banner), not a silent settings banner. |
| D4 | Implementation approach | **Mirror the replace intent + fix the root gate** (Approach 2): a post-restore sync intent that mirrors `pendingReplace`, plus a durable per-provider "established" anchor so a wiped cursor never again impersonates first-contact. |

## Guiding principle

Consent is captured at restore time; downstream syncs honor it instead of silently re-gating. The Merge case can act on that consent automatically (non-destructive). The Replace-adopt case must still confirm (destructive) — but loudly, not silently.

## Design

### Building blocks

| Block | What it is | New/Modified |
|-------|-----------|--------------|
| Post-restore sync intent | A persisted flag set when a **Merge** restore completes, consumed once on next launch to force a gate-bypassing sync. Mirrors `pendingReplace`. | New store `post_restore_sync_store.dart` |
| "Established provider" anchor | A persisted set of `providerId`s this install has successfully synced to. Survives restore (SharedPreferences). Teaches `firstSyncMergeInfo()` that an established device is not first-contact. | New store + hook in the post-sync success path |
| Global sync surfacing | App-root listener that turns transient sync state into unmissable UI: a one-time SnackBar for the Merge notice, and a modal adopt dialog + persistent banner for the replace-adopt pause — independent of the current screen. | New root widget/listener; extract the existing adopt dialog so it is reusable |

### Gate 1 — Merge restore -> auto-resume + notice

**Intent store** (`lib/core/services/sync/post_restore_sync_store.dart`): a thin SharedPreferences wrapper.

```dart
class PostRestoreSyncStore {
  bool get pending;            // key: sync_post_restore_pending
  Future<void> setPending();
  Future<void> clear();
}
```

Kept separate from `pendingReplace` on purpose: `pendingReplace` carries a `LibraryEpochMarker` and means "execute a destructive cloud replace under a new epoch." A merge restore changes no epoch and must not trip replace logic. Two single-purpose flags cannot be cross-wired at the `_initialize` branch.

**Set it** in `backup_service.dart`, symmetric with where Replace mints its intent:

```dart
if (mode == RestoreMode.replace) {
  await _mintPendingReplace(...);            // existing
} else {
  await _postRestoreSyncStore.setPending();  // new: Merge consent
}
```

**Established-provider anchor**: persist the set of `providerId`s with a completed successful sync, written in the notifier's sync-success path (the `result.isSuccess` branch of `performSync`, where the active provider is known and `_ref` is available) so the anchor lands whenever `lastSyncTime` advances. Keyed on the same `providerId` that `getLastSyncTime(forProvider:)` uses, so scoping is consistent. Because it lives in SharedPreferences, a DB restore cannot rewind it.

`firstSyncMergeInfo()` gains one early return:

```dart
final provider = _ref.read(cloudStorageProviderProvider);
if (provider == null) return null;
if (_establishedProviderStore.contains(provider.providerId)) return null; // not first-contact
// existing lastSyncTime / dive-count / peers checks unchanged
```

A genuinely new device has no anchor -> the safety gate still fires exactly as today. A restored-but-established device skips it.

**Consume on launch** — `_initialize` (`sync_providers.dart`) gains two branches after the existing Replace branch:

```dart
// Merge restore: restore dialog was the consent. One gate-bypassing sync,
// regardless of toggles.
if (mounted && provider != null && _postRestoreSyncStore.pending) {
  state = state.copyWith(postRestoreSyncing: true);  // drives the notice
  unawaited(_runPostRestoreSync());                  // performSync(auto:false); clear intent on success
  return;
}
// Other devices: proactively detect a replaced library (Gate 2).
if (mounted && provider != null) {
  unawaited(_detectReplacedLibraryForSurfacing());
}
```

`performSync(auto: false)` is the mechanism: it skips the `if (auto)` first-contact check and runs irrespective of the toggles — the same path Replace already relies on.

**Notice (UI layer, not the notifier):** the notifier only sets `postRestoreSyncing`; the app-root listener turns that into a non-blocking SnackBar via the existing `_scaffoldMessengerKey` ("Syncing your restored library with the cloud...", then a brief "Restored library synced" on completion). The notifier stays UI-free.

**Intent lifecycle:** cleared on a *successful* post-restore sync. If it errors (offline), it stays for the next launch to retry — and established devices sync normally anyway via the anchor. Dormant if no provider is configured. **Reset Sync State** clears both the anchor and this intent, so an explicit reset remains a true fresh start that re-arms the gate.

### Gate 2 — Replace adopt on other devices -> unmissable confirm

**Proactive detection, decoupled from the toggles.** `_detectReplacedLibraryForSurfacing()` (called from `_initialize` and on resume) reuses the existing `libraryReplaceInfo()` epoch-marker read:

```dart
Future<void> _detectReplacedLibraryForSurfacing() async {
  final marker = await libraryReplaceInfo();  // null if we are the replacer or epoch matches
  if (marker == null || !mounted) return;
  final diveCount = await _ref.read(diveRepositoryProvider).getDiveCount();
  if (!mounted) return;
  if (diveCount == 0) {
    unawaited(performSync());                 // nothing to lose -> existing auto-adopt path
  } else {
    state = state.copyWith(                   // arm the unmissable surface; do NOT sync
      replaceAwaitingAdoption: true,
      replaceMarker: marker,
    );
  }
}
```

The pause is now detected on every launch/resume even with Auto Sync off. The network read is already timeout-guarded (8s) and runs `unawaited`, so it never blocks startup.

**Global surfacing.** Extract the adopt dialog out of `cloud_sync_page.dart` into a reusable `showAdoptReplacedLibraryDialog(context, ref, marker)` (e.g. `lib/features/settings/presentation/widgets/adopt_replaced_library_dialog.dart`). It preserves the exact existing behavior: the "Adopt Restored Library?" dialog (`settings_cloudSync_adopt_dialogTitle/Content`) and, on confirm, safety backup (`performBackup(isAutomatic: true)`) then `adoptReplacedLibrary()`.

The app root adds `ref.listen(syncStateProvider, ...)`:

- When `replaceAwaitingAdoption` first flips true this session -> show that modal dialog via the root navigator (wherever the user is).
- Drive a persistent `MaterialBanner` through `_scaffoldMessengerKey` using the existing `settings_cloudSync_replace_banner(deviceName)` string, with a **Review** action that reopens the dialog. The banner rides across all screens until the user adopts.

**Adopt semantics unchanged.** `adoptReplacedLibrary()` still takes the safety backup and replaces local data — the human stays in the loop for the destructive operation. Only the visibility and timing of detection change. The settings-page banner stays as a secondary surface; centralizing the actual dialog in the root listener (guarded by a one-shot session flag) prevents two dialogs stacking when the user is on the settings page.

**Anti-nag rule:** the modal shows at most once per app session; if dismissed, the persistent banner remains visible so it is never lost, and a fresh cold launch may prompt again.

### Data flows

```
MERGE restore (restoring device)
  restore completes -> set postRestoreSyncIntent
  app restarts -> _initialize(): intent present?
    -> performSync(auto:false)        // bypasses first-contact gate, ignores toggles
    -> global SnackBar "Syncing your restored library..."
    -> clear intent on success
  (belt-and-suspenders) firstSyncMergeInfo() returns null because providerId is anchored

REPLACE restore (the other devices)
  app launch/resume -> _initialize(): not the replacer + libraryReplaceInfo() finds foreign epoch?
    diveCount == 0 -> performSync() auto-adopts (nothing to lose)
    diveCount  > 0 -> state.replaceAwaitingAdoption = true, replaceMarker = E
  app-root listener sees the flag (once/session)
    -> modal "Adopt Restored Library?" dialog
    -> persistent MaterialBanner "Sync paused: library replaced on <device>. Review."
  user confirms -> safety backup -> adoptReplacedLibrary()  (unchanged, destructive, confirmed)
```

## Edge cases and error handling

- **Forced post-restore sync fails (offline):** intent is not cleared (only success clears it), so the next launch retries; meanwhile an established device still syncs normally via the anchor. The SnackBar never claims false success — on failure it defers to the existing sync-error surfacing.
- **Branch precedence:** `_initialize` checks `pendingReplace` first and returns, so a Replace intent can never be shadowed by the merge branch. The two are mutually exclusive per restore (mode is exclusive).
- **No provider configured at restore:** intent lies dormant; consumed only once a provider exists.
- **Anchor scoping:** keyed on the same `providerId` as `getLastSyncTime(forProvider:)`, so a backend switch still gates genuine first-contact with the new backend, and the anchor cannot suppress the gate for a different cloud.
- **Reset Sync State:** clears the anchor and the post-restore intent — an explicit reset stays a true fresh start that re-arms the gate.
- **Gate 2 dialog stacking / nag:** one-shot session flag in the root listener — modal shows once per session, persistent banner lingers, the settings-page path calls the same dialog function so two cannot stack.
- **Disposal safety:** every async helper re-checks `mounted` after awaits (the notifier's existing discipline for launch-triggered syncs that outlive the container); SnackBar/banner go through a post-frame callback so the global messenger is mounted.

## Localization

Two new strings only — the Merge notice start/done (e.g. `settings_cloudSync_postRestore_syncing`, `settings_cloudSync_postRestore_synced`). Gate 2 reuses the existing `settings_cloudSync_replace_banner` and `settings_cloudSync_adopt_dialog*` keys verbatim. New strings are translated into all 10 non-en locales and regenerated via gen-l10n.

## Testing (TDD, >=80%)

**Gate 1**
- Merge restore sets the intent; Replace restore does not (sets `pendingReplace` instead).
- `_initialize` with the intent forces `performSync(auto: false)` and **does not defer even when peers + local dives + null cursor coexist** (the exact bug, asserted gone).
- Intent cleared on success, retained on failure, dormant with no provider.

**Anchor / root fix**
- `firstSyncMergeInfo()` returns null when the provider is anchored, non-null when not (**regression guard: a genuinely new device is still gated**).
- Anchor written on sync success, survives a simulated restore, per-provider scoped.
- Reset Sync State clears the anchor.

**Gate 2**
- Proactive detection arms `replaceAwaitingAdoption` (dives > 0) or auto-adopts (dives == 0) **with Auto Sync off**.
- Root listener shows the dialog once per session; persistent banner shown; Review reopens the dialog.
- The extracted adopt dialog preserves safety-backup-then-adopt behavior.
- No double-dialog when on the settings page.

**Convergence**
- Extend the existing 2-device convergence tests: merge-restore converges with no manual Sync Now; replace-restore surfaces and adopts on the other device.

The two highest-value guards: (1) `firstSyncMergeInfo()` still returns non-null for a genuinely new device — the gate doing its real job; (2) the forced post-restore sync demonstrably syncs under the precise condition that previously deferred. A test asserting "the old bug condition now syncs instead of deferring" proves the fix and blocks a future regression.

## Verification

`dart format` + whole-project `flutter analyze` + `flutter test` before commit. Final Mac + iPhone two-device hardware pass reproducing both screenshots' silent stops and confirming them gone, consistent with how the rest of incremental-sync has been verified.

## Non-goals

- No change to merge/conflict resolution, HLC ordering, or tombstone semantics — the merge itself is already correct (HLC-versioned tombstones prevent resurrection); this work only changes when and how consent is collected and surfaced.
- No change to what `adoptReplacedLibrary()` does (still destructive, still safety-backed-up, still confirmed).
- No restructure of the restore confirmation dialog (that was Approach 3, not chosen).
