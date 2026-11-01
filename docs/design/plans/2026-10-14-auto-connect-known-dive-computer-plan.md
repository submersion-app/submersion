# Auto-Connect for Known Dive Computers - Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Design reference:** `docs/design/specs/2026-10-14-auto-connect-known-dive-computer-design.md`

**Goal:** While the diver is on the Dive Computers section of the Transfer tab
(`_ComputersSectionContent`), passively scan for Bluetooth dive computers the
app already knows, and automatically connect and download when one is
reachable - gated by a global switch and a per-device opt-out.

**Architecture:** Adds one new lightweight coordinator,
`AutoConnectController` (`autoConnectControllerProvider`, `autoDispose`), that
drives the *existing* `DiscoveryNotifier` and `DownloadNotifier` rather than
reimplementing scanning or downloading. It activates on ordinary
`initState`/`dispose` of `_ComputersSectionContent` - confirmed that
`MasterDetailScaffold` calls `detailBuilder(context, selectedId!)` directly
with no `IndexedStack`/`Offstage` (`master_detail_scaffold.dart:587`), so
switching to a sibling section (Import/Export) really disposes this widget,
on both the desktop master-detail layout and the mobile per-section route.
Section switches also go through `context.go(...)`
(`transfer_page.dart:210`), not a `Navigator.push`, so `RouteAware` would not
reliably fire for them anyway. `RouteAware` is still needed, but only for the
*cover* case: pushing a child route on top (the discovery wizard, a computer
detail page, the download page - all real `context.push()` calls) leaves
`_ComputersSectionContent` mounted but hidden underneath, so its `dispose()`
never runs; `didPushNext`/`didPopNext` pause and resume the scan for that
case specifically. Matching reuses `sameModelFallbackDevice()`
(`lib/features/dive_computer/domain/services/known_computer_reacquisition.dart`)
and `bluetoothAddressesMatch()`
(`lib/features/dive_computer/presentation/providers/discovery_providers.dart:395`).
The global switch is a new device-local `AppSettings` field (same pattern as
`applyDefaultTankToImports`); the per-device opt-out is a new column on the
`DiveComputers` Drift table, surfaced through the `DiveComputer` entity.

**Tech Stack:** Flutter, Riverpod (`StateNotifierProvider`, `autoDispose`),
Drift (schema migration), `go_router` + a `RouteObserver` registered on
`GoRouter.observers` (not currently used anywhere in the app).

---

### Task 1: Add the per-device opt-out column

**Files:**

- Modify: `lib/core/database/tables/dive_profile_tables.dart:35` (insert
  after `isFavorite`)
- Modify: `lib/core/database/database.dart:302` (bump
  `currentSchemaVersion` from `331` to `332` - re-verified against
  `upstream/main` on 2026-10-31; the original draft's `290`/`291` was
  already stale) and the migration strategy (`onUpgrade`, in
  `lib/core/database/migrations/ladder/rungs_v231_onward.dart`, the rung
  after v331's `_assertEquipmentLocationCenterColumn()`)
- Modify: `lib/features/dive_log/domain/entities/dive_computer.dart` (new
  field, `copyWith`, `props`, `DiveComputer.create` stays unaffected -
  default applies)
- Modify: `lib/features/dive_log/data/repositories/dive_computer_repository_impl.dart`
  (row <-> entity mapping, both directions)

**Step 1: Table column**

```dart
/// Excludes this computer from auto-download even when the global
/// auto-connect switch is on (per-device opt-out, issue #TBD).
BoolColumn get autoDownloadDisabled =>
    boolean().withDefault(const Constant(false))();
```

**Step 2: Schema version + migration**

Bump `currentSchemaVersion` to `291`. The migration ladder lives in
`lib/core/database/migrations/ladder/rungs_v231_onward.dart`; the current
last rung is:

```dart
// v290: dive_plan_segments.split_at_configured_rate (issue #3264).
// Column only, defaulting off; re-asserted in beforeOpen. Renumbered
// from 277, 282 then 286, as earlier rungs shipped or were claimed
// first.
if (from < 290) {
  await _assertSegmentSplitAtRateColumn();
}
if (from < 290) await reportProgress();
```

Add a v291 rung in the same shape: an idempotent `_assertAutoDownloadDisabledColumn()`
helper (`ALTER TABLE` guarded by a column-exists check, matching
`_assertSegmentSplitAtRateColumn`'s pattern), called from `if (from < 291)`,
followed by `if (from < 291) await reportProgress();`, and the same column
re-asserted in `beforeOpen` so a fresh install and an upgrade converge on the
same schema. Note in the comment that the rung number may need renumbering
again if another branch claims 291 first before this merges - same caveat
the v288 comment already documents.

**Step 3: Entity + mapping**

Add `final bool autoDownloadDisabled;` to `DiveComputer` (default `false`),
thread it through `copyWith` and `props`, and through the repository's
row-to-entity and entity-to-row conversions in
`dive_computer_repository_impl.dart`.

**Decided (cross-examination):** this column syncs across devices - no
device-local marker comment, no exclusion from the sync path. The opt-out
expresses the diver's intent about that computer, the same as most other
`DiveComputer` fields, not a device-specific technical detail like
`bluetoothAddress`.

---

### Task 2: Add the global auto-connect switch to settings

**Files:**

- Modify: `lib/features/settings/presentation/providers/settings_providers.dart`
  - `SettingsKeys` (near `applyDefaultTankToImports`, line ~89): new key
    `autoConnectKnownComputers`
  - `AppSettings` class: new field `autoConnectKnownComputers` (default
    `true` - decided in cross-examination), threaded through `copyWith`
  - `SettingsNotifier`: new setter `setAutoConnectKnownComputers(bool value)`
    following the exact shape of `setApplyDefaultTankToImports` (line
    ~1979)
  - Load/save: wherever `AppSettings` is read from and written to
    SharedPreferences (same block that persists
    `applyDefaultTankToImports`)

**Step 1-3:** Mirror `applyDefaultTankToImports` end to end: key constant,
field + default + `copyWith` branch, setter calling `_saveSettings()`, and
the SharedPreferences read/write lines for the new key.

Mark it `Device-local:` in the doc comment, matching the convention used for
`mediaProvenanceBadges` and `viewerFullscreenMode` (line ~79-85) - this
switch controls whether *this device* scans, not a synced preference.

---

### Task 3: `AutoConnectController` - the coordinator

**Files:**

- Create: `lib/features/dive_computer/presentation/providers/auto_connect_providers.dart`

**Step 1: State**

```dart
class AutoConnectState {
  final bool isActive; // true while this controller owns an active scan
  final Set<String> triggeredComputerIds; // downloaded-or-downloading this visit

  const AutoConnectState({
    this.isActive = false,
    this.triggeredComputerIds = const {},
  });

  AutoConnectState copyWith({
    bool? isActive,
    Set<String>? triggeredComputerIds,
  }) => AutoConnectState(
    isActive: isActive ?? this.isActive,
    triggeredComputerIds: triggeredComputerIds ?? this.triggeredComputerIds,
  );
}
```

**Step 2: Notifier**

`AutoConnectController extends StateNotifier<AutoConnectState>` holding a
`Ref`. Two lifecycle methods, `activate()` and `deactivate()`, called by the
widget in Task 5 (not by Riverpod's own dispose, since this must react to
route push/pop, not just widget mount/unmount):

- `activate()`: no-op if `ref.read(settingsProvider).autoConnectKnownComputers`
  is false. Otherwise calls
  `ref.read(discoveryNotifierProvider.notifier).startScan()` and subscribes
  to `ref.listen(discoveredDevicesProvider, _onDevicesChanged)`. Sets
  `isActive: true`.
- `deactivate()`: cancels the listener subscription and, **only if this
  controller started the scan** (track a local bool, since the discovery
  wizard's own `startScan`/`stopScan` must not be stopped by this
  controller if the diver happened to open it), calls
  `ref.read(discoveryNotifierProvider.notifier).stopScan()`. Sets
  `isActive: false`. Clears `triggeredComputerIds` so leaving and
  re-entering the screen re-arms every computer.

**Step 3: Matching + trigger, `_tryTriggerNextMatch()`**

Runs the same matching pass in two places: (a) from `ref.listen` on
`discoveredDevicesProvider`, for newly-seen advertisements, and (b) from
`ref.listen` on `isDownloadingProvider`, specifically on its `true -> false`
edge (a download just finished). Both call into one shared routine rather
than only reacting to new scan results.

**Why (b) is required, not optional:** if computer A and computer B are both
already in `discoveredDevicesProvider` when A's download starts, the list
does not change again when A finishes - B was already in it. A listener that
only reacts to list changes would never notice B is still sitting there
reachable. Re-running the match pass when a download completes is what
actually delivers the "download sequentially from everything in range"
behavior decided in cross-examination; without it, only the first computer
discovered in a visit would ever download automatically.

For each device in the current `discoveredDevicesProvider` snapshot, not yet
in `state.triggeredComputerIds`, stopping at the first match that starts a
download (since `DownloadNotifier` cannot run two downloads at once -
confirmed it holds single `_computer`/`_device` fields, no queue, in
`download_providers.dart:191-193`):

1. Skip if `ref.read(isDownloadingProvider)` is true (a download - manual or
   auto-triggered - is already running; do not start a second one). Re-check
   this fresh for every device in the loop, not once before the loop, so a
   trigger earlier in the same pass is respected by later iterations.
2. Resolve the known computer: match `device.address` via
   `bluetoothAddressesMatch` against every `DiveComputer.bluetoothAddress`
   from `ref.read(allDiveComputersProvider.future)` (or the cached sync
   value), falling back to `sameModelFallbackDevice`-equivalent
   manufacturer/model matching for devices whose address rotated (reuse the
   existing matcher rather than re-deriving the logic).
3. Skip if no match, if `computer.autoDownloadDisabled` is true, or if
   `computer.diverId` is not the active diver's id (decided in
   cross-examination: auto-download only considers the active profile's own
   computers, read via `ref.read(currentDiverIdProvider)` - a computer
   belonging to a different diver on a shared device is left for manual
   download even when its own owner profile is not selected).
4. Mark the id in `triggeredComputerIds` (so a repeat advertisement from the
   same device during this visit is not retried), then call
   `ref.read(downloadNotifierProvider.notifier).startDownload(device, computer: computer)`.

   **Superseded during review:** calling `startDownload` directly downloaded
   the dives but never imported them, since importing (and the dive count,
   fingerprint and connection updates) happens only in the download page's
   import steps. The controller now opens the computer's download page
   instead, pausing its own scan first, and picks computers in the order
   they were discovered; see the design spec, Behavior items 4 and 5.
5. Surface the "Downloading from <name>..." feedback (Task 6) via a
   side-channel the widget listens to - e.g. a
   `StreamController<DiveComputer>` or a transient field on the state - since
   a `StateNotifier` has no built-in one-shot event channel and a snackbar
   must fire exactly once per trigger, not every rebuild.

**Step 4: Provider**

```dart
final autoConnectControllerProvider =
    StateNotifierProvider.autoDispose<AutoConnectController, AutoConnectState>(
      (ref) => AutoConnectController(ref: ref),
    );
```

`autoDispose` so leaving the Transfer tab entirely (not just the Computers
section) tears it down even if the widget in Task 5 somehow failed to call
`deactivate()`.

**Verify before implementing this task:** `scan_step_widget.dart`'s
`dispose()` (lines 46-48) disposes only its `TabController` and does not
call `stopScan()`. Before relying on "this controller only stops the scan it
itself started" (the `deactivate()` rule above), confirm where - if
anywhere - the manual discovery wizard reliably stops its own scan when the
diver backs out of it (a wizard-level close handler, a `reset()` call on
pop, or similar). If it turns out the wizard already leaves scans running
in some exit paths, that is a pre-existing issue independent of this
feature, but this task's "don't stop a scan we didn't start" rule depends on
knowing the actual behavior, not assuming it.

---

### Task 4: Route-aware pause/resume for the cover case only

This task exists solely for "a child route is pushed on top of the Computers
section and later popped back" (the discovery wizard, a computer detail
page, the download page). Entering/leaving the section itself is handled by
plain `initState`/`dispose` in Task 5 and needs no route observer.

**Files:**

- Modify: `lib/core/router/app_router.dart:230` (register a `RouteObserver`
  on `GoRouter(observers: [...])`)
- Create: `lib/core/router/computers_section_route_observer.dart` (or add
  the observer as a small top-level `RouteObserver<PageRoute>` constant next
  to `rootNavigatorKey`, whichever keeps it closest to its one caller)

**Step 1:** Add `final computersRouteObserver = RouteObserver<PageRoute>();`
and pass it in `GoRouter(... observers: [computersRouteObserver])`.

**Step 2:** This observer is consumed by the widget wrapper in Task 5, via
`RouteAware.didPushNext` (pause: a route was pushed on top of this one) and
`RouteAware.didPopNext` (resume: back on top again after that route popped).
`didPush`/`didPop` (this route's own push/pop) are not used here - they
overlap with `initState`/`dispose`, which already cover that case.

---

### Task 4b: Guard against root-navigator overlays (added 2026-10-31, second cross-examination)

**Why this is needed:** Verified against the go_router 17.5.0 source
(`route.dart`): `GoRouter.observers` are merged into every `ShellRoute`'s
nested `Navigator` by default (`notifyRootObserver: true`, not overridden
anywhere in `app_router.dart`), so Task 4's `RouteObserver` does correctly
fire `didPushNext`/`didPopNext` for the three dive-computer child routes -
the original worry that go_router breaks `RouteAware` here does not apply.

But `RouteAware` only reports push/pop within the *same* `Navigator`'s route
stack, and four existing app flows push straight onto the root `Navigator`
(`Navigator.of(context, rootNavigator: true)` /
`rootNavigatorKey.currentContext`), one level above the `ShellRoute`'s own
nested `Navigator` entirely:

- `RestoreCompletePage.show()` (`lib/features/.../restore_complete_page.dart`)
  - `pushAndRemoveUntil`, wipes the whole stack, after a cloud restore
    finishes.
- `_openAdoptDialog` / `showAdoptReplacedLibraryDialog` (`lib/app.dart`)
  - after a cloud library replacement.
- `openBuddyCard` (`lib/app.dart`, buddy-card link/share)
- `openScannedTag` (`lib/app.dart`, passport NFC tag link)

None of these dispose `_ComputersSectionContent` or fire its
`didPushNext`, because the push happens one `Navigator` level up. If one of
these fires while the diver is on Transfer > Computers with the passive
scan active, the scan (and a just-triggered auto-download) keeps running
underneath a screen that is now fully covered or replaced - violating the
design's own "only while this screen is visible" scope.

**Files:**

- Create: `lib/core/providers/root_overlay_providers.dart`
- Modify: `lib/app.dart` (the four call sites above)
- Modify: `lib/features/.../restore_complete_page.dart`
- Modify: `lib/features/dive_computer/presentation/providers/auto_connect_providers.dart`
  (from Task 3)

**Step 1:** Add a small `StateProvider<bool>` (or an equivalent notifier),
`rootOverlayActiveProvider`, defaulting to `false`. This is a plain
foreground signal, not a lifecycle/background concept - the app stays in
the foreground the whole time, a root-level screen is just covering the
shell.

**Step 2:** Each of the four call sites sets it `true` immediately before
the push and `false` once the overlay is gone:

- `RestoreCompletePage.show`: set `true` before `pushAndRemoveUntil`; the
  page itself sets it back to `false` when the diver dismisses it (it is
  the only one that is not naturally `await`-wrapped, since
  `pushAndRemoveUntil` does not return when the pushed page closes the
  normal way - it has no "closes" by popping back to the prior stack, since
  that prior stack was removed. Resetting the flag therefore happens from
  `RestoreCompletePage`'s own "Continue" action, not from the caller).
- `_openAdoptDialog`, `openBuddyCard`, `openScannedTag`: these are already
  `await`-ed or self-contained async calls, so wrap each with
  `ref.read(rootOverlayActiveProvider.notifier).state = true;` before and
  `= false;` in a `finally` after.

**Step 3:** `AutoConnectController` generalizes its pause/resume: rename the
internal pause logic shared by `deactivate()` and the `RouteAware` callbacks
into private `_pause()`/`_resume()` methods, and additionally
`ref.listen(rootOverlayActiveProvider, (prev, next) { if (next) {
_pause(); } else { _resume(); } })` from `activate()`. This reuses the exact
same "only stop a scan we started" bookkeeping Task 3 already has - no new
state needed, just one more trigger for the same pause/resume path.

**Verify before implementing:** confirm none of the four call sites can
already be reached *from* the auto-connect download flow itself (e.g. a
share arriving while an auto-download is mid-flight) in a way that would
make `_pause()` race with `DownloadNotifier` - if the plan's existing "skip
if `isDownloadingProvider` is true" check in Task 3 already covers this, no
extra guard is needed here.

---

### Task 5: Wire the controller into the Computers section

**Files:**

- Modify: `lib/features/transfer/presentation/pages/transfer_page.dart:615`
  (`_ComputersSectionContent`)

**Step 1:** Convert `_ComputersSectionContent` from a `ConsumerWidget` to a
`ConsumerStatefulWidget` (or wrap it in a small new `StatefulWidget` that
hosts the `RouteAware` subscription and delegates to the existing build
method, if minimizing the diff on the existing widget is preferred).

**Step 2:** `initState` calls
`ref.read(autoConnectControllerProvider.notifier).activate()`; `dispose`
calls `.deactivate()` - this is what fires on every sibling-section switch
(Import/Export) and on leaving Transfer entirely. Separately, in
`didChangeDependencies`, subscribe to `computersRouteObserver` via
`ModalRoute.of(context)` (unsubscribe in `dispose` alongside the above);
implement `RouteAware.didPushNext` to call `.deactivate()` and
`RouteAware.didPopNext` to call `.activate()` again - this is what fires
when the wizard/detail/download page is pushed on top and later popped,
while this widget stays mounted underneath the whole time.

**Step 3:** `ref.listen` the controller's one-shot trigger channel (Task 3,
Step 3.5) to show the snackbar, and watch `state.isActive` to render the
"Searching..." indicator described in Task 6.

---

### Task 6: UI - switch, opt-out, indicator, feedback

**Files:**

- Modify: `lib/features/transfer/presentation/pages/transfer_page.dart`
  (section header area around `_ComputersSectionContent`'s build, and
  `_buildComputerCard` near line 751)
- Modify: the computer detail page (route `/dive-computers/{id}`) for the
  per-device opt-out toggle - locate via
  `lib/core/router/app_router.dart` route definition for that path
- Modify: l10n ARB files, `lib/l10n/arb/app_en.arb` and
  `lib/l10n/arb/app_de.arb` (new keys for the switch label/subtitle, the
  per-device opt-out label, the "Searching..." indicator, and the
  "Downloading from {name}..." snackbar - follow the existing
  `transfer_computers_*` key naming already used on this page)

**Step 1:** Global switch: a `SwitchListTile` (or reuse the existing toggle
pattern from `clock_sync_global_switch.dart`, which is the same shape of
problem - a global switch that affects per-device behavior - living in
`lib/features/dive_computer/presentation/widgets/`) placed in the Computers
section header, bound to `settingsProvider.autoConnectKnownComputers` /
`setAutoConnectKnownComputers`.

**Step 2:** Per-device opt-out: a toggle on the computer detail page,
bound to `computer.autoDownloadDisabled`, calling the repository's
`updateComputer` the same way other detail-page edits do.

**Step 3:** "Searching..." indicator: a small inline row (spinner + text)
shown in the section only while `autoConnectControllerProvider`'s
`isActive` is true, placed near the existing "Connect new computer" card.

**Step 4:** Snackbar: `ScaffoldMessenger.of(context).showSnackBar(...)` with
the localized "Downloading from {name}..." text, triggered from the
`ref.listen` in Task 5 Step 3.

---

### Task 7: Tests

**Files:**

- Create: `test/features/dive_computer/presentation/providers/auto_connect_providers_test.dart`
- Modify/extend: existing discovery/download provider tests if the matcher
  reuse needs a shared test double
- Create or extend: a widget test for `_ComputersSectionContent` covering
  route-aware activation/deactivation
- Extend: the database migration test suite for the schema bump (project
  convention: every `currentSchemaVersion` bump needs a migration test -
  find the existing pattern for the most recent prior bump and mirror it)

**Coverage targets (unit, `AutoConnectController`):**

1. Switch off -> `activate()` does not start a scan.
2. Switch on, matching known computer discovered, not opted out, no
   download in progress -> `startDownload` called exactly once.
3. Same computer advertises twice in one visit -> `startDownload` called
   only once (idempotent via `triggeredComputerIds`).
4. Computer has `autoDownloadDisabled: true` -> skipped, even with the
   switch on.
5. A manual download is already in progress (`isDownloadingProvider` true)
   -> auto-trigger suppressed for that cycle.
6. `deactivate()` after `activate()` stops the scan only when this
   controller owns it (does not stop a scan the manual wizard started
   independently - this needs a test double that lets both paths be
   exercised against the same `DiscoveryNotifier` instance).
7. Leaving and re-entering the section resets `triggeredComputerIds`, so a
   computer downloaded once can trigger again on a later visit (e.g. after
   surfacing from a second dive the same day).
8. Two known, non-opted-out computers both reachable: downloading from A
   completes -> B is picked up and downloaded automatically next, without a
   new scan event being the trigger (covers the bug found in
   cross-examination: matching must also re-run when
   `isDownloadingProvider` flips back to `false`, not only on new scan
   results).
9. A known computer belongs to a diver other than the currently active
   profile -> skipped, even with the switch on and no opt-out set.

---

## Decisions confirmed via cross-examination

1. Default state of the global switch (Task 2): **on** by default.
2. `autoDownloadDisabled` (Task 1): **synced** across devices, not
   device-local.
3. Multiple known, reachable computers at once (Task 3): **download from
   all of them automatically, one after another** - not just the first,
   and not a manual picker for the rest.
4. Diver scoping (Task 3, Step 3.3): **only the active diver's own known
   computers** are matched; a computer belonging to another diver on a
   shared device is left for manual download.
5. No explicit idle-scan timeout: the Computers section's own visibility
   (Task 4/5) is treated as a sufficient bound on how long the passive scan
   runs.

UI placement (switch in the section header, opt-out on the device detail
page) was carried over from the design doc as an assumption and not
separately re-litigated in this pass - still worth a quick sanity check once
Task 6 is underway, since it is a UI call rather than a logic decision.

## Remaining open item before implementation

Not a product decision, but unverified: see Task 3's "Verify before
implementing this task" note on whether the manual discovery wizard reliably
stops its own scan on exit. Confirm this before writing `AutoConnectController`'s
`deactivate()`, since its "only stop a scan we started" rule assumes a
specific, currently unconfirmed behavior from the wizard side.
