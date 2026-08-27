# Run the Safety Review After a Backup Restore

Date: 2026-08-08
Status: Approved

## Problem

After restoring a backup, the safety review is empty for the whole logbook.
No dive shows findings, and no dive-list row shows a finding badge, until
the user discovers Settings → Safety → "Analyze all dives" and runs it by
hand.

The cause is that the safety review has only two triggers, and a restore is
neither of them:

1. **Lazy compute on first view.** `safetyReviewProvider`
   (`lib/features/dive_log/presentation/providers/safety_review_providers.dart`)
   is a compute-through-cache: it returns the stored review when current,
   otherwise runs the engine over the profile analysis and persists the
   result. It only runs when something watches it — in practice, opening a
   dive's detail page.
2. **The manual sweep.** `_analyzeAllDives` in
   `lib/features/settings/presentation/pages/safety_settings_page.dart`.

A Submersion backup is a whole-file SQLite copy (`DatabaseService.backup`
→ `sourceFile.copy`), so the `dive_safety_reviews` and
`dive_safety_findings` tables travel with it — but carrying only whatever
rows the source database happened to have. Two common cases leave them
empty:

- The backup predates the safety review feature, so the migration ladder
  creates both tables empty during the restore.
- The source device never opened those dives, so lazy compute never ran.

Either way `restoreFromBackup` / `restoreFromFile` land a database with no
reviews, and `DiveSummary.safetyFindingCount` — which reads persisted rows
— reports zero across the library.

## Goals

- A restore leaves the restored library analyzed, with no manual step.
- Cover every restore entry point, including the setup wizard.
- Never let a sweep failure turn a successful restore into a failed one.
- Give the user a way out of a sweep that is taking longer than expected.

## Non-goals

- Changing when the safety review runs outside of a restore (imports,
  dive-computer downloads, and sync keep their current behavior).
- Changing any safety rule, threshold, or `SafetyReviewService.engineVersion`.
- Any schema change. Both safety tables already exist and already sync.
- Resuming a skipped remainder on a later launch.

## Decisions

| Question | Decision |
| --- | --- |
| When does the sweep run? | Inline, as the last step of the restore, before the restore-complete screen |
| Which dives? | Every dive in the restored library, across all divers |
| Long sweeps | Determinate progress plus a Skip button |
| Code structure | Extract a shared sweep helper used by both Settings and restore |

## Design

### 1. `SafetyReviewSweep`

New file:
`lib/features/dive_log/presentation/providers/safety_review_sweep.dart`.

```dart
class SafetyReviewSweepResult {
  final int swept;
  final int failed;
  final bool cancelled;
}

class SafetyReviewSweep {
  final Ref _ref;
  const SafetyReviewSweep(this._ref);

  Future<SafetyReviewSweepResult> run({
    String? diverId,                            // null = every diver
    void Function(int done, int total)? onProgress,
    bool Function()? isCancelled,
  });
}

final safetyReviewSweepProvider =
    Provider<SafetyReviewSweep>((ref) => SafetyReviewSweep(ref));
```

Behavior, lifted verbatim from `_analyzeAllDives`:

- Returns immediately with a zero result when `safetyReviewEnabledProvider`
  is false.
- Resolves dive ids via
  `diveRepositoryProvider.getOrderedDiveIds(diverId: diverId)`. Passing
  `null` already yields every dive across every diver — the SQL only adds
  the `d.diver_id = ?` clause when `diverId` is non-null.
- Per dive: `ref.invalidate(safetyReviewProvider(diveId))` **before**
  `await ref.read(safetyReviewProvider(diveId).future)`. The invalidate is
  load-bearing, not defensive: `safetyReviewProvider` is not `autoDispose`,
  so a bare read returns a stale cached `AsyncValue` — including a cached
  `null` from a dive opened mid-sync before its profile arrived — and
  silently never runs the compute-through-cache.
- Per dive `try/catch`: a corrupt profile increments `failed` and the sweep
  continues.
- Checks `isCancelled()` at the top of each iteration and returns a result
  with `cancelled: true` when it fires.

`_analyzeAllDives` is rewritten to delegate, keeping its current active-diver
scope (`diverId: ref.read(currentDiverIdProvider)`) and its existing progress
and snackbar behavior. The Settings page's user-visible behavior does not
change.

Riverpod note: `Ref` and `WidgetRef` are separate sealed types, so the helper
is exposed as a `Provider` rather than taking a ref parameter. Both call
sites then reach the same object — `ref.read(safetyReviewSweepProvider)` —
and the sweep uses the provider's own long-lived `Ref` internally.

### 2. Restore integration

`BackupOperationNotifier`
(`lib/features/backup/presentation/providers/backup_providers.dart`) is the
single seam: every restore entry point — the backup settings page, a backup
history record, and the setup wizard's restore step — funnels through its
`restoreFromBackup` or `restoreFromFilePath`.

A new private `_runPostRestoreSafetyReview()` is called in both, between the
existing `_syncActiveDiverAfterRestore()` and the
`BackupOperationStatus.restoreComplete` transition. `isRestoring` stays
`true` for its duration, so the restore barrier keeps the app blocked and
nothing can touch the database mid-sweep.

### 3. The sweep runs in a scratch `ProviderContainer`

The restore path must not sweep on the live container. That container still
holds values built against the **pre-restore** database:

- `settingsProvider`, and therefore `gfLowProvider` / `gfHighProvider`,
  which shape the ceiling curve that the `missedDecoStop` and
  `highSurfaceGf` rules grade against.
- `ProfileLegend`, which seeds `defaultCnsSource` / `defaultTtsSource` /
  `defaultDecoStopSource` from `settingsProvider` and feeds
  `overlayComputerDecoData`, changing the very curves the rules read.
- Cached `analysisDiveProvider` and `profileAnalysisProvider` entries.

Sweeping there would persist findings computed from the *replaced* device's
settings, and because `saveReview` stamps the current
`SafetyReviewService.engineVersion`, those wrong findings would never be
recomputed.

So `_runPostRestoreSafetyReview` creates a short-lived `ProviderContainer`
after the database swap, runs the sweep in it, and disposes it in a
`finally`. Every provider builds fresh against the restored database. The
live container is left untouched — `restartApp()` is a soft restart that
rebuilds `ProviderScope` under a fresh key, disposing every provider in it
moments later anyway.

To keep the scratch container faithful to the real one, `main.dart`'s
override list moves into a shared function in a new file,
`lib/core/providers/root_overrides.dart`:

```dart
List<Override> rootProviderOverrides({
  required SharedPreferences prefs,
  required LogFileService logFileService,
}) => [
      sharedPreferencesProvider.overrideWithValue(prefs),
      logFileServiceProvider.overrideWithValue(logFileService),
    ];
```

used by both `SubmersionRestart.build` (`lib/main.dart:136`) and the sweep,
so the two cannot drift apart as overrides are added. Copying
`logFileServiceProvider` is mandatory, not cosmetic: its default
implementation throws `UnimplementedError` unless overridden.

The container construction is wrapped in its own injectable seam so the
notifier stays testable without building the real provider graph:

```dart
class PostRestoreSafetyReview {
  final Ref _ref;
  const PostRestoreSafetyReview(this._ref);

  Future<SafetyReviewSweepResult> run({
    void Function(int done, int total)? onProgress,
    bool Function()? isCancelled,
  });
}

final postRestoreSafetyReviewProvider =
    Provider<PostRestoreSafetyReview>((ref) => PostRestoreSafetyReview(ref));
```

Tests override `postRestoreSafetyReviewProvider` with a fake that records the
call, reports progress, or throws.

### 3b. One pass per diver (added after PR #916 review)

A single all-divers pass is not enough either. Decompression settings are
per-diver (`diver_settings.gf_low` / `gf_high`, ppO2 ceilings, deco stop
increment, CNS method), and `computeAnalysisForProfile` falls back to
`gfLowProvider` / `gfHighProvider` whenever a dive carries no dive-specific
GFs. Those derive from `settingsProvider`, which only ever loads the **active**
diver's row. So one pass over every diver's dives would grade the non-active
divers' dives with the active diver's gradient factors — and, because
`saveReview` stamps the current `engineVersion`, persist them permanently.

The sweep therefore runs one pass per diver, each in a container whose
`settingsProvider` is overridden with a new `SettingsNotifier.preloaded`
constructor pinned to that diver's stored `AppSettings` (no database load, no
diver-change listener). Overriding the single root provider covers every
derived provider, including `ProfileLegend`; enumerating the dozen derived
providers would rot as the analysis pipeline grows. Dives whose `diver_id` is
null (the column is nullable) get a trailing pass under the active diver's
settings, matching the pre-existing behavior for unowned rows.

Settings are read with `getSettingsForDiver`, deliberately not
`getOrCreateSettingsForDiver`: the latter writes a defaults row when none
exists, and a restore must not mint rows that would then sync out as genuine
edits.

Known limitation, pre-existing and out of scope: `getPreviousDiveTimes`
(`dive_repository_impl.dart:4317`) is not diver-scoped, so residual CNS/tissue
lookback can still pull a different diver's previous dive.

A fresh container is necessary but not sufficient. `SettingsNotifier` starts at
the `AppSettings` DEFAULTS and replaces its state asynchronously once the
diver's row is read, so reading gradient factors immediately after building the
container still yields defaults. `PostRestoreSafetyReview` therefore awaits a
new `SettingsNotifier.initialLoad` before sweeping (guarded: a failed load
leaves the defaults in place rather than aborting the restore). The same
asynchrony required a `mounted` guard on `_loadSettings`'s post-await `state`
assignment, since disposing the scratch container mid-load previously threw.

### 4. Progress and the Skip button

`BackupOperationState` gains a structured field rather than another English
`message` string, so the barrier can localize:

```dart
class SafetyReviewSweepProgress {
  final int done;
  final int total;
}

// on BackupOperationState:
final SafetyReviewSweepProgress? sweepProgress;
```

`RestoreBarrier`'s `_RestoreOverlay`
(`lib/features/backup/presentation/widgets/restore_barrier.dart`) renders,
when `sweepProgress` is non-null: a heading, a determinate
`LinearProgressIndicator`, an "Analyzed {done} of {total}" label, and a Skip
button. The notifier exposes `skipSafetyReviewSweep()`, which sets a private
flag that the sweep's `isCancelled` callback reads.

Skipping is lossless. Unswept dives still compute lazily on first view, and
Settings → "Analyze all dives" remains available.

The Bühlmann replay already runs on a background isolate via `compute()`
inside `profileAnalysisProvider`, so the UI thread stays free to paint
progress and accept the Skip tap.

### 5. Data flow

```
restoreFromBackup / restoreFromFilePath
  └─ BackupService.restore*         DB swapped + reopened, sync re-baselined
  └─ _syncActiveDiverAfterRestore   (existing)
  └─ _runPostRestoreSafetyReview    (new)
       ├─ open scratch ProviderContainer(rootProviderOverrides(...))
       ├─ getOrderedDiveIds(diverId: null)      every diver's dives
       ├─ per dive: invalidate + read safetyReviewProvider  → saveReview
       ├─ push {done, total} into BackupOperationState → RestoreBarrier
       ├─ stop when the skip flag is set
       └─ dispose the container (finally)
  └─ state = restoreComplete → RestoreCompletePage → restartApp()
```

## Error handling

1. **Per dive.** `try/catch`, increment `failed`, continue. One corrupt
   profile must not end the sweep.
2. **Per sweep.** The whole `_runPostRestoreSafetyReview` call is wrapped so
   that no sweep failure can fail the restore. By the time it runs, the
   database swap and the sync re-baseline have already succeeded — the
   restore is done. A throw is logged and the flow proceeds to
   `restoreComplete` regardless.
3. **Container lifetime.** `dispose()` in a `finally`, so neither a throw nor
   a Skip leaks the scratch container or its subscriptions.

## Edge cases

| Case | Behavior |
| --- | --- |
| Safety review disabled in restored settings | Sweep returns immediately; no progress UI |
| Restored library has no dives | No-op; no progress UI |
| Older-schema backup | Migration ladder creates the safety tables empty, then the sweep populates them — the case that most needs this fix |
| Merge vs Replace mode | Both sweep. `rebaselineAfterRestore` has already cleared the sync position, so every row is pending regardless; the sweep's parent-dive HLC bumps add no meaningful extra push |
| Skip tapped | Sweep stops at the current dive; the remainder computes lazily on view |
| Wrong passphrase / invalid file | The restore throws before the sweep is reached; nothing runs |
| Setup wizard restore | Uses `restoreFromFilePath` on the same notifier, so it is covered with no extra work |

## Localization

Three new keys in `lib/l10n/arb/app_en.arb`, translated across all eleven
locales (ar, de, en, es, fr, he, hu, it, nl, pt, zh):

- `backup_restore_safetyReview_title`
- `backup_restore_safetyReview_progress` — `{done}`, `{total}` placeholders
- `backup_restore_safetyReview_skip`

`RestoreBarrier` wraps the whole app, which normally makes adding
`context.l10n` to it hazardous for every existing widget test. Here the risk
is bounded: `_RestoreOverlay` is only built when `isRestoring` is true, so
tests that pump unrelated consumers never reach the new calls. Only
`test/features/backup/presentation/widgets/restore_barrier_test.dart`, which
forces that flag, needs `localizationsDelegates` wired.

## Testing

Tests are written before implementation.

**Unit — `test/features/dive_log/presentation/providers/safety_review_sweep_test.dart`** (new),
against a `ProviderContainer` over an in-memory database:

- sweeps dives belonging to more than one diver when `diverId` is null
- scopes to a single diver when `diverId` is supplied
- stops early when `isCancelled` returns true, reporting `cancelled: true`
- counts a dive that throws in `failed` and still sweeps the rest
- returns a zero result without touching the repository when
  `safetyReviewEnabledProvider` is false
- reports monotonic `onProgress` callbacks ending at `total`

**Provider — `test/features/backup/presentation/providers/backup_providers_restore_test.dart`** (existing):

- a restore populates safety reviews for dives across multiple divers
- a sweep that throws still reaches `BackupOperationStatus.restoreComplete`
- `skipSafetyReviewSweep()` halts the sweep and the restore still completes

**Widget — `test/features/backup/presentation/widgets/restore_barrier_test.dart`** (existing):

- the progress label and Skip button render while `sweepProgress` is non-null
- the overlay keeps its current spinner appearance when `sweepProgress` is null

The Skip *tap* is asserted at the notifier level rather than the widget level:
the button's callback resolves `backupOperationProvider.notifier`, which would
drag the whole backup service graph into a widget test for no added coverage.

**Regression:** the existing safety-settings tests must pass unchanged after
`_analyzeAllDives` is extracted — that is the check that the extraction
preserved behavior.

Project gates: `dart format .`, `flutter analyze` clean, 80% coverage
minimum.

## Files touched

| File | Change |
| --- | --- |
| `lib/features/dive_log/presentation/providers/safety_review_sweep.dart` | New: `SafetyReviewSweep`, result type, provider |
| `lib/features/backup/presentation/providers/post_restore_safety_review.dart` | New: `PostRestoreSafetyReview` container seam |
| `lib/features/settings/presentation/pages/safety_settings_page.dart` | `_analyzeAllDives` delegates to the sweep |
| `lib/features/backup/presentation/providers/backup_providers.dart` | `_runPostRestoreSafetyReview`, `skipSafetyReviewSweep`, `sweepProgress` on the state |
| `lib/features/backup/presentation/widgets/restore_barrier.dart` | Determinate progress, localized labels, Skip button |
| `lib/core/providers/root_overrides.dart` | New: `rootProviderOverrides` |
| `lib/main.dart` | Use `rootProviderOverrides` instead of an inline list |
| `lib/features/settings/presentation/providers/settings_providers.dart` | Expose `initialLoad`; `mounted` guard on the post-await state write; `SettingsNotifier.preloaded` for per-diver pinning |
| `lib/l10n/arb/app_*.arb` | Three new keys across nine locales |
