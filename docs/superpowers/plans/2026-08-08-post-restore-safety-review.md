# Post-Restore Safety Review Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Run the post-dive safety review automatically over the whole
restored library at the end of a backup restore, with progress and a Skip
button, so a restore no longer leaves every dive un-analyzed until the user
finds the manual sweep in Settings.

**Architecture:** Extract the existing "Analyze all dives" loop out of
`safety_settings_page.dart` into a shared `SafetyReviewSweep` provider. Call
it from `BackupOperationNotifier` — the single seam every restore path funnels
through — after the database swap and before the restore-complete transition.
The restore-side call runs the sweep inside a short-lived, disposable
`ProviderContainer` so the engine sees the restored database's settings rather
than the replaced device's cached ones.

**Tech Stack:** Flutter 3.x, Riverpod 3.1 (`flutter_riverpod`), Drift ORM over
SQLite, `flutter_test`, `flutter gen-l10n` for ARB localization.

**Spec:** `docs/superpowers/specs/2026-08-08-post-restore-safety-review-design.md`

## Global Constraints

- All Dart code must pass `dart format .` with no changes.
- `flutter analyze` must be clean across the whole project; infos are fatal in
  CI, so no unused imports or dangling references.
- TDD: write the failing test first, watch it fail, then implement.
- No emojis in code, comments, or documentation.
- Immutability: never mutate entities in place; use `copyWith`.
- 80% minimum test coverage.
- Localized strings go in `lib/l10n/arb/app_en.arb` and must be translated
  into all eleven locales: `ar, de, en, es, fr, he, hu, it, nl, pt, zh`.
- Do not change `SafetyReviewService.engineVersion` or any safety rule.
- No database schema changes. Both safety tables already exist.
- Run tests from the worktree root:
  `/Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/safety-review-after-restore`

---

### Task 1: Extract the root provider overrides

The sweep needs to build a second `ProviderContainer` with the same overrides
as the app's real one. `logFileServiceProvider` throws `UnimplementedError`
unless overridden, so copying the list is mandatory, not cosmetic. Extracting
it into one function stops the two lists from drifting apart.

**Files:**
- Create: `lib/core/providers/root_overrides.dart`
- Modify: `lib/main.dart:134-141`
- Test: `test/core/providers/root_overrides_test.dart`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: `List<Override> rootProviderOverrides({required SharedPreferences prefs, required LogFileService logFileService})`

- [ ] **Step 1: Write the failing test**

Create `test/core/providers/root_overrides_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/providers/root_overrides.dart';
import 'package:submersion/core/services/log_file_service.dart';
import 'package:submersion/features/settings/presentation/providers/debug_log_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('supplies both providers that would otherwise throw', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final logFileService = LogFileService();

    final container = ProviderContainer(
      overrides: rootProviderOverrides(
        prefs: prefs,
        logFileService: logFileService,
      ),
    );
    addTearDown(container.dispose);

    expect(container.read(sharedPreferencesProvider), same(prefs));
    expect(container.read(logFileServiceProvider), same(logFileService));
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/core/providers/root_overrides_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:submersion/core/providers/root_overrides.dart'`

- [ ] **Step 3: Create the override helper**

Create `lib/core/providers/root_overrides.dart`:

```dart
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/log_file_service.dart';
import 'package:submersion/features/settings/presentation/providers/debug_log_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// The provider overrides the app's root [ProviderScope] installs.
///
/// Shared with the post-restore safety sweep, which builds a second, throwaway
/// container against the freshly restored database. Both must install the same
/// overrides: [logFileServiceProvider] throws unless overridden, and a
/// container missing [sharedPreferencesProvider] cannot resolve settings. Keep
/// this the single definition so the two cannot drift apart.
List<Override> rootProviderOverrides({
  required SharedPreferences prefs,
  required LogFileService logFileService,
}) {
  return [
    sharedPreferencesProvider.overrideWithValue(prefs),
    logFileServiceProvider.overrideWithValue(logFileService),
  ];
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/core/providers/root_overrides_test.dart`
Expected: PASS

- [ ] **Step 5: Use the helper in main.dart**

In `lib/main.dart`, add the import:

```dart
import 'package:submersion/core/providers/root_overrides.dart';
```

Replace the inline override list in `SubmersionRestart.build` (currently
`lib/main.dart:136-139`):

```dart
        return ProviderScope(
          key: key,
          overrides: rootProviderOverrides(
            prefs: prefs,
            logFileService: logFileService,
          ),
          child: const SubmersionApp(),
        );
```

- [ ] **Step 6: Verify formatting, analysis, and tests**

Run:
```bash
dart format .
flutter analyze
flutter test test/core/providers/root_overrides_test.dart
```
Expected: no formatting changes, no analyzer issues, test passes.

- [ ] **Step 7: Commit**

```bash
git add lib/core/providers/root_overrides.dart lib/main.dart test/core/providers/root_overrides_test.dart
git commit -m "refactor(providers): extract rootProviderOverrides for reuse"
```

---

### Task 2: The shared SafetyReviewSweep

The loop that currently lives inline in the settings page becomes a reusable
provider. The `ref.invalidate` before the read is load-bearing:
`safetyReviewProvider` is not `autoDispose`, so a bare read returns a stale
cached `AsyncValue` — including a cached `null` from a dive opened mid-sync —
and silently never runs the compute-through-cache.

**Files:**
- Create: `lib/features/dive_log/presentation/providers/safety_review_sweep.dart`
- Test: `test/features/dive_log/presentation/providers/safety_review_sweep_test.dart`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces:
  - `class SafetyReviewSweepResult { final int swept; final int failed; final bool cancelled; }`
  - `class SafetyReviewSweep { Future<SafetyReviewSweepResult> run({String? diverId, void Function(int done, int total)? onProgress, bool Function()? isCancelled}); }`
  - `final safetyReviewSweepProvider = Provider<SafetyReviewSweep>(...)`

- [ ] **Step 1: Write the failing test**

Create `test/features/dive_log/presentation/providers/safety_review_sweep_test.dart`:

```dart
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/safety_findings_repository.dart';
import 'package:submersion/features/dive_log/domain/entities/safety_finding.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/safety_review_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/safety_review_sweep.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';
import '../../domain/services/safety_review_fixtures.dart';

/// Records every review handed to it, so the sweep's coverage can be asserted
/// without inspecting the database.
class _RecordingRepo extends SafetyFindingsRepository {
  final saved = <String>[];

  @override
  Future<SafetyReview?> getReview(String diveId) async => null;

  @override
  Future<void> saveReview(SafetyReview review) async =>
      saved.add(review.diveId);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime.utc(2026, 8, 8);
  late AppDatabase db;

  /// Inserts a dive owned by [diverId].
  ///
  /// `dives.diver_id` is a nullable FK to `divers`, but foreign keys are off
  /// in the test database, so no matching diver row is needed. If this ever
  /// starts failing with a constraint error, insert the two `Divers` rows in
  /// setUp first.
  Future<void> insertDive(String id, String diverId) async {
    final ts = now.millisecondsSinceEpoch;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(id),
            diverId: Value(diverId),
            diveDateTime: Value(ts),
            createdAt: Value(ts),
            updatedAt: Value(ts),
          ),
        );
  }

  setUp(() async {
    db = await setUpTestDatabase();
    await insertDive('d1', 'diver-a');
    await insertDive('d2', 'diver-b');
  });

  tearDown(() => tearDownTestDatabase());

  /// A container whose analysis always yields a rapid-ascent fixture, so every
  /// dive produces a persistable review.
  ProviderContainer makeContainer(_RecordingRepo repo) {
    final profile = rapidAscentProfile();
    final analysis = analyzeFixture(
      depths: profile.depths,
      timestamps: profile.timestamps,
    );
    final container = ProviderContainer(
      overrides: [
        safetyFindingsRepositoryProvider.overrideWithValue(repo),
        safetyReviewEnabledProvider.overrideWithValue(true),
        profileAnalysisProvider('d1').overrideWith((ref) async => analysis),
        profileAnalysisProvider('d2').overrideWith((ref) async => analysis),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('sweeps every diver when diverId is null', () async {
    final repo = _RecordingRepo();
    final result = await makeContainer(repo).read(safetyReviewSweepProvider).run();

    expect(repo.saved, containsAll(<String>['d1', 'd2']));
    expect(result.swept, 2);
    expect(result.failed, 0);
    expect(result.cancelled, isFalse);
  });

  test('scopes to a single diver when diverId is supplied', () async {
    final repo = _RecordingRepo();
    final result = await makeContainer(
      repo,
    ).read(safetyReviewSweepProvider).run(diverId: 'diver-a');

    expect(repo.saved, <String>['d1']);
    expect(result.swept, 1);
  });

  test('reports progress ending at the total', () async {
    final repo = _RecordingRepo();
    final seen = <(int, int)>[];
    await makeContainer(repo).read(safetyReviewSweepProvider).run(
      onProgress: (done, total) => seen.add((done, total)),
    );

    expect(seen.first, (0, 2), reason: 'an initial 0-of-N sizes the bar');
    expect(seen.last, (2, 2));
  });

  test('stops early and reports cancelled when isCancelled fires', () async {
    final repo = _RecordingRepo();
    final result = await makeContainer(
      repo,
    ).read(safetyReviewSweepProvider).run(isCancelled: () => true);

    expect(repo.saved, isEmpty);
    expect(result.cancelled, isTrue);
    expect(result.swept, 0);
  });

  test('an empty logbook sweeps nothing and reports a zero total', () async {
    await db.delete(db.dives).go();
    final repo = _RecordingRepo();
    final seen = <(int, int)>[];

    final result = await makeContainer(repo).read(safetyReviewSweepProvider).run(
      onProgress: (done, total) => seen.add((done, total)),
    );

    expect(result.swept, 0);
    expect(result.failed, 0);
    expect(result.cancelled, isFalse);
    expect(seen, <(int, int)>[(0, 0)]);
  });

  test('does nothing when the master toggle is off', () async {
    final repo = _RecordingRepo();
    final container = ProviderContainer(
      overrides: [
        safetyFindingsRepositoryProvider.overrideWithValue(repo),
        safetyReviewEnabledProvider.overrideWithValue(false),
      ],
    );
    addTearDown(container.dispose);

    final result = await container.read(safetyReviewSweepProvider).run();

    expect(repo.saved, isEmpty);
    expect(result.swept, 0);
    expect(result.cancelled, isFalse);
  });

  test('counts a failing dive and still sweeps the rest', () async {
    final repo = _RecordingRepo();
    final profile = rapidAscentProfile();
    final analysis = analyzeFixture(
      depths: profile.depths,
      timestamps: profile.timestamps,
    );
    final container = ProviderContainer(
      overrides: [
        safetyFindingsRepositoryProvider.overrideWithValue(repo),
        safetyReviewEnabledProvider.overrideWithValue(true),
        profileAnalysisProvider('d1').overrideWith(
          (ref) async => throw StateError('corrupt profile'),
        ),
        profileAnalysisProvider('d2').overrideWith((ref) async => analysis),
      ],
    );
    addTearDown(container.dispose);

    final result = await container.read(safetyReviewSweepProvider).run();

    expect(result.failed, 1);
    expect(result.swept, 2, reason: 'swept counts dives visited, not successes');
    expect(repo.saved, <String>['d2']);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/dive_log/presentation/providers/safety_review_sweep_test.dart`
Expected: FAIL — `Target of URI doesn't exist: '.../safety_review_sweep.dart'`

- [ ] **Step 3: Implement the sweep**

Create `lib/features/dive_log/presentation/providers/safety_review_sweep.dart`:

```dart
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/safety_review_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// Outcome of a [SafetyReviewSweep.run].
class SafetyReviewSweepResult {
  /// Dives visited, including those that failed analysis. Mirrors the progress
  /// bar's position rather than a success count.
  final int swept;

  /// Dives whose analysis threw. They stay unanalyzed and recompute lazily.
  final int failed;

  /// True when the caller's isCancelled callback stopped the sweep early.
  final bool cancelled;

  const SafetyReviewSweepResult({
    required this.swept,
    required this.failed,
    required this.cancelled,
  });

  static const empty = SafetyReviewSweepResult(
    swept: 0,
    failed: 0,
    cancelled: false,
  );
}

/// Runs the post-dive safety review over a logbook, persisting each result.
///
/// Shared by the manual Settings sweep and the post-restore sweep so the
/// invalidate-before-read invariant below lives in exactly one place.
class SafetyReviewSweep {
  final Ref _ref;

  const SafetyReviewSweep(this._ref);

  /// Analyzes every dive matching [diverId] (null means every diver).
  ///
  /// [onProgress] fires once with (0, total) to size a progress bar, then after
  /// each dive. [isCancelled] is polled before each dive; returning true stops
  /// the sweep and yields a result with `cancelled: true`. Cancelling is
  /// lossless -- unswept dives still compute lazily on first view.
  Future<SafetyReviewSweepResult> run({
    String? diverId,
    void Function(int done, int total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    // Master toggle off: safetyReviewProvider would refuse to compute anyway,
    // so skip the whole pass rather than issuing a marker read per dive.
    if (!_ref.read(safetyReviewEnabledProvider)) {
      return SafetyReviewSweepResult.empty;
    }

    final diveIds = await _ref
        .read(diveRepositoryProvider)
        .getOrderedDiveIds(diverId: diverId);

    final total = diveIds.length;
    onProgress?.call(0, total);

    var swept = 0;
    var failed = 0;

    for (final diveId in diveIds) {
      if (isCancelled?.call() ?? false) {
        return SafetyReviewSweepResult(
          swept: swept,
          failed: failed,
          cancelled: true,
        );
      }
      try {
        // Invalidate first. safetyReviewProvider is not autoDispose, so any
        // dive whose detail page was opened this session holds a cached
        // AsyncValue -- including a cached null from a dive opened mid-sync
        // before its profile arrived. A bare read would return that cached
        // value and never run the compute-through-cache, leaving the review
        // missing until an app restart.
        _ref.invalidate(safetyReviewProvider(diveId));
        await _ref.read(safetyReviewProvider(diveId).future);
      } catch (_) {
        // A dive that fails analysis (corrupt profile) must not abort the
        // sweep; it stays unanalyzed. Counted so callers can report honestly
        // rather than implying every dive was analyzed.
        failed++;
      }
      swept++;
      onProgress?.call(swept, total);
    }

    return SafetyReviewSweepResult(
      swept: swept,
      failed: failed,
      cancelled: false,
    );
  }
}

final safetyReviewSweepProvider = Provider<SafetyReviewSweep>(
  (ref) => SafetyReviewSweep(ref),
);
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/dive_log/presentation/providers/safety_review_sweep_test.dart`
Expected: PASS — all seven tests.

- [ ] **Step 5: Verify formatting and analysis**

Run:
```bash
dart format .
flutter analyze
```
Expected: no formatting changes, no analyzer issues.

- [ ] **Step 6: Commit**

```bash
git add lib/features/dive_log/presentation/providers/safety_review_sweep.dart test/features/dive_log/presentation/providers/safety_review_sweep_test.dart
git commit -m "feat(safety): add reusable SafetyReviewSweep provider"
```

---

### Task 3: Settings page delegates to the sweep

Behavior must not change. The existing safety settings page test is the
regression gate.

**Files:**
- Modify: `lib/features/settings/presentation/pages/safety_settings_page.dart:149-203`
- Test: `test/features/settings/presentation/pages/safety_settings_page_test.dart` (existing, unchanged)

**Interfaces:**
- Consumes: `safetyReviewSweepProvider`, `SafetyReviewSweep.run`, `SafetyReviewSweepResult` from Task 2.
- Produces: nothing new.

- [ ] **Step 1: Run the existing test to capture the green baseline**

Run: `flutter test test/features/settings/presentation/pages/safety_settings_page_test.dart`
Expected: PASS. Note the count — it must be identical after the refactor.

- [ ] **Step 2: Add the import**

In `lib/features/settings/presentation/pages/safety_settings_page.dart`, add:

```dart
import 'package:submersion/features/dive_log/presentation/providers/safety_review_sweep.dart';
```

- [ ] **Step 3: Replace `_analyzeAllDives` with a delegating version**

Replace the whole `_analyzeAllDives` method body (currently lines 149-203):

```dart
  Future<void> _analyzeAllDives() async {
    // Scope the sweep to the active diver's logbook so "Analyze all dives"
    // only touches the current diver's dives, not every diver on the device.
    final diverId = ref.read(currentDiverIdProvider);
    setState(() {
      _analyzing = true;
      _analyzeDone = 0;
      _analyzeTotal = 0;
      _analyzeFailed = 0;
    });

    final result = await ref
        .read(safetyReviewSweepProvider)
        .run(
          diverId: diverId,
          onProgress: (done, total) {
            if (!mounted) return;
            setState(() {
              _analyzeDone = done;
              _analyzeTotal = total;
            });
          },
          // Leaving the page ends the sweep, matching the previous
          // `if (!mounted) return;` guard inside the loop.
          isCancelled: () => !mounted,
        );

    if (!mounted) return;
    setState(() {
      _analyzing = false;
      _analyzeFailed = result.failed;
    });
    if (result.cancelled) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.failed == 0
              ? context.l10n.safetySettings_analyzeAll_done
              : context.l10n.safetySettings_analyzeAll_doneWithErrors(
                  result.failed,
                ),
        ),
      ),
    );
  }
```

- [ ] **Step 4: Run the regression test**

Run: `flutter test test/features/settings/presentation/pages/safety_settings_page_test.dart`
Expected: PASS with the same test count as Step 1.

- [ ] **Step 5: Verify formatting and analysis**

Run:
```bash
dart format .
flutter analyze
```
Expected: no formatting changes, no analyzer issues. In particular the
`_analyzeFailed` field must still be referenced; if the analyzer reports it
unused, the `setState` in Step 3 was not applied correctly.

- [ ] **Step 6: Commit**

```bash
git add lib/features/settings/presentation/pages/safety_settings_page.dart
git commit -m "refactor(safety): route Analyze all dives through SafetyReviewSweep"
```

---

### Task 4: The post-restore container seam

Wraps the throwaway `ProviderContainer` so the notifier can be tested without
building the real provider graph.

**Files:**
- Create: `lib/features/backup/presentation/providers/post_restore_safety_review.dart`
- Test: `test/features/backup/presentation/providers/post_restore_safety_review_test.dart`

**Interfaces:**
- Consumes: `rootProviderOverrides` (Task 1); `safetyReviewSweepProvider`, `SafetyReviewSweepResult` (Task 2).
- Produces:
  - `class PostRestoreSafetyReview { Future<SafetyReviewSweepResult> run({void Function(int done, int total)? onProgress, bool Function()? isCancelled}); }`
  - `final postRestoreSafetyReviewProvider = Provider<PostRestoreSafetyReview>(...)`

- [ ] **Step 1: Write the failing test**

Create `test/features/backup/presentation/providers/post_restore_safety_review_test.dart`:

```dart
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/log_file_service.dart';
import 'package:submersion/features/backup/presentation/providers/post_restore_safety_review.dart';
import 'package:submersion/features/settings/presentation/providers/debug_log_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late SharedPreferences prefs;

  setUp(() async {
    db = await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    final ts = DateTime.utc(2026, 8, 8).millisecondsSinceEpoch;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: const Value('d1'),
            diverId: const Value('diver-a'),
            diveDateTime: Value(ts),
            createdAt: Value(ts),
            updatedAt: Value(ts),
          ),
        );
  });

  tearDown(() => tearDownTestDatabase());

  ProviderContainer makeContainer() {
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        logFileServiceProvider.overrideWithValue(LogFileService()),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('runs a whole-library sweep and reports progress', () async {
    final seen = <(int, int)>[];

    final result = await makeContainer()
        .read(postRestoreSafetyReviewProvider)
        .run(onProgress: (done, total) => seen.add((done, total)));

    // The dive has no profile, so nothing is persisted -- but it is visited,
    // which is what proves the scratch container reached the restored data.
    expect(result.swept, 1);
    expect(result.cancelled, isFalse);
    expect(seen.first, (0, 1));
    expect(seen.last, (1, 1));
  });

  test('honours cancellation', () async {
    final result = await makeContainer()
        .read(postRestoreSafetyReviewProvider)
        .run(isCancelled: () => true);

    expect(result.cancelled, isTrue);
    expect(result.swept, 0);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/backup/presentation/providers/post_restore_safety_review_test.dart`
Expected: FAIL — `Target of URI doesn't exist: '.../post_restore_safety_review.dart'`

- [ ] **Step 3: Implement the seam**

Create `lib/features/backup/presentation/providers/post_restore_safety_review.dart`:

```dart
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/providers/root_overrides.dart';
import 'package:submersion/features/dive_log/presentation/providers/safety_review_sweep.dart';
import 'package:submersion/features/settings/presentation/providers/debug_log_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// Runs the whole-library safety sweep that follows a database restore.
///
/// The sweep deliberately runs in its own short-lived [ProviderContainer]
/// rather than the live one. After a restore the live container still holds
/// values built against the REPLACED database -- settingsProvider (and so the
/// gradient factors that shape the ceiling curve the missedDecoStop and
/// highSurfaceGf rules grade against), ProfileLegend's metric-source defaults,
/// and cached analysisDiveProvider/profileAnalysisProvider entries. Computing
/// findings from that state would persist the old device's settings into the
/// restored library, and because saveReview stamps the current engineVersion
/// they would never be recomputed.
///
/// A fresh container builds every provider against the restored database. The
/// live container is left untouched; restartApp() rebuilds the root
/// ProviderScope under a new key moments later and discards it anyway.
class PostRestoreSafetyReview {
  final Ref _ref;

  const PostRestoreSafetyReview(this._ref);

  Future<SafetyReviewSweepResult> run({
    void Function(int done, int total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final container = ProviderContainer(
      overrides: rootProviderOverrides(
        prefs: _ref.read(sharedPreferencesProvider),
        logFileService: _ref.read(logFileServiceProvider),
      ),
    );
    try {
      return await container
          .read(safetyReviewSweepProvider)
          .run(
            // A restore replaces the whole library, so sweep every diver.
            diverId: null,
            onProgress: onProgress,
            isCancelled: isCancelled,
          );
    } finally {
      container.dispose();
    }
  }
}

final postRestoreSafetyReviewProvider = Provider<PostRestoreSafetyReview>(
  (ref) => PostRestoreSafetyReview(ref),
);
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/backup/presentation/providers/post_restore_safety_review_test.dart`
Expected: PASS — both tests.

- [ ] **Step 5: Verify formatting and analysis**

Run:
```bash
dart format .
flutter analyze
```
Expected: clean.

- [ ] **Step 6: Commit**

```bash
git add lib/features/backup/presentation/providers/post_restore_safety_review.dart test/features/backup/presentation/providers/post_restore_safety_review_test.dart
git commit -m "feat(backup): add isolated post-restore safety review runner"
```

---

### Task 5: Wire the sweep into the restore flow

**Files:**
- Modify: `lib/features/backup/presentation/providers/backup_providers.dart` (state class ~170-203, notifier ~206-292 and ~369-427)
- Test: `test/features/backup/presentation/providers/backup_providers_restore_test.dart` (existing, add cases)

**Interfaces:**
- Consumes: `postRestoreSafetyReviewProvider`, `PostRestoreSafetyReview.run`, `SafetyReviewSweepResult` (Tasks 2 and 4).
- Produces:
  - `class SafetyReviewSweepProgress { final int done; final int total; }`
  - `BackupOperationState.sweepProgress` (`SafetyReviewSweepProgress?`)
  - `BackupOperationNotifier.skipSafetyReviewSweep()`

- [ ] **Step 1: Write the failing tests**

Append to `test/features/backup/presentation/providers/backup_providers_restore_test.dart`, inside the existing `main()` (after the last test). Add these imports at the top of the file:

```dart
import 'package:submersion/features/backup/presentation/providers/post_restore_safety_review.dart';
import 'package:submersion/features/dive_log/presentation/providers/safety_review_sweep.dart';
```

Add this fake above `void main()`:

```dart
/// Stands in for the real sweep so the notifier can be exercised without
/// building a second provider graph.
class _FakePostRestoreSafetyReview implements PostRestoreSafetyReview {
  int calls = 0;
  bool throwOnRun = false;

  /// Progress pairs emitted before returning.
  List<(int, int)> emit = const [];

  /// Captured so a test can assert the notifier's skip flag reaches the sweep.
  bool Function()? capturedIsCancelled;

  @override
  Future<SafetyReviewSweepResult> run({
    void Function(int done, int total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    calls++;
    capturedIsCancelled = isCancelled;
    if (throwOnRun) throw StateError('sweep exploded');
    for (final (done, total) in emit) {
      onProgress?.call(done, total);
    }
    return SafetyReviewSweepResult(
      swept: emit.isEmpty ? 0 : emit.last.$1,
      failed: 0,
      cancelled: isCancelled?.call() ?? false,
    );
  }
}
```

Then add the tests:

```dart
  test('a restore runs the post-restore safety sweep', () async {
    final sweep = _FakePostRestoreSafetyReview();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        cloudStorageProviderProvider.overrideWithValue(null),
        backupServiceProvider.overrideWithValue(service),
        postRestoreSafetyReviewProvider.overrideWithValue(sweep),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(backupOperationProvider.notifier)
        .restoreFromFilePath('/tmp/backup.db');

    expect(sweep.calls, 1);
    expect(
      container.read(backupOperationProvider).status,
      BackupOperationStatus.restoreComplete,
    );
  });

  test('sweep progress is published while the barrier is still up', () async {
    final sweep = _FakePostRestoreSafetyReview()..emit = const [(0, 2), (1, 2)];
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        cloudStorageProviderProvider.overrideWithValue(null),
        backupServiceProvider.overrideWithValue(service),
        postRestoreSafetyReviewProvider.overrideWithValue(sweep),
      ],
    );
    addTearDown(container.dispose);

    final seen = <SafetyReviewSweepProgress?>[];
    final sub = container.listen(
      backupOperationProvider,
      (_, next) => seen.add(next.sweepProgress),
    );
    addTearDown(sub.close);

    await container
        .read(backupOperationProvider.notifier)
        .restoreFromFilePath('/tmp/backup.db');

    final published = seen.whereType<SafetyReviewSweepProgress>().toList();
    expect(published, isNotEmpty);
    expect(published.last.done, 1);
    expect(published.last.total, 2);
  });

  test('a sweep failure still completes the restore', () async {
    final sweep = _FakePostRestoreSafetyReview()..throwOnRun = true;
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        cloudStorageProviderProvider.overrideWithValue(null),
        backupServiceProvider.overrideWithValue(service),
        postRestoreSafetyReviewProvider.overrideWithValue(sweep),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(backupOperationProvider.notifier)
        .restoreFromFilePath('/tmp/backup.db');

    expect(
      container.read(backupOperationProvider).status,
      BackupOperationStatus.restoreComplete,
      reason: 'the data restore already succeeded; the sweep is a convenience',
    );
  });

  test('skipSafetyReviewSweep is visible to the running sweep', () async {
    final sweep = _FakePostRestoreSafetyReview();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        cloudStorageProviderProvider.overrideWithValue(null),
        backupServiceProvider.overrideWithValue(service),
        postRestoreSafetyReviewProvider.overrideWithValue(sweep),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(backupOperationProvider.notifier);
    await notifier.restoreFromFilePath('/tmp/backup.db');

    expect(sweep.capturedIsCancelled, isNotNull);
    expect(sweep.capturedIsCancelled!(), isFalse);
    notifier.skipSafetyReviewSweep();
    expect(sweep.capturedIsCancelled!(), isTrue);
  });
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/features/backup/presentation/providers/backup_providers_restore_test.dart`
Expected: FAIL — `postRestoreSafetyReviewProvider` / `sweepProgress` / `skipSafetyReviewSweep` undefined.

- [ ] **Step 3: Add the progress type and state field**

In `lib/features/backup/presentation/providers/backup_providers.dart`, add these imports:

```dart
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/backup/presentation/providers/post_restore_safety_review.dart';
```

Add above `class BackupOperationState`:

```dart
/// Progress of the whole-library safety review sweep that runs at the end of a
/// restore. Structured rather than a pre-formatted string so the restore
/// barrier can render it in the user's language.
class SafetyReviewSweepProgress {
  final int done;
  final int total;

  const SafetyReviewSweepProgress({required this.done, required this.total});
}
```

Add the field to `BackupOperationState` (after `isRestoring`):

```dart
  /// Non-null only while the post-restore safety sweep is running.
  final SafetyReviewSweepProgress? sweepProgress;
```

Add it to the constructor:

```dart
    this.sweepProgress,
```

and to `copyWith` — deliberately NOT `??`-merged, because a null must be able
to clear the field when the sweep ends. `BackupOperationState.copyWith` has no
callers today (the `state.copyWith` calls elsewhere in this file belong to
`BackupSettings`), so this cannot regress an existing path:

```dart
  BackupOperationState copyWith({
    BackupOperationStatus? status,
    String? message,
    BackupRecord? lastRecord,
    bool? isRestoring,
    SafetyReviewSweepProgress? sweepProgress,
  }) {
    return BackupOperationState(
      status: status ?? this.status,
      message: message ?? this.message,
      lastRecord: lastRecord ?? this.lastRecord,
      isRestoring: isRestoring ?? this.isRestoring,
      sweepProgress: sweepProgress,
    );
  }
```

- [ ] **Step 4: Add the sweep runner to the notifier**

In `BackupOperationNotifier`, add a logger and the skip flag next to
`_desktopBackupTimer`:

```dart
  final _log = LoggerService.forClass(BackupOperationNotifier);
  bool _sweepSkipped = false;
```

Add these methods next to `_syncActiveDiverAfterRestore`:

```dart
  /// Stops the post-restore safety sweep at the next dive boundary.
  ///
  /// Lossless: unswept dives still compute lazily when opened, and
  /// Settings > Safety > "Analyze all dives" remains available.
  void skipSafetyReviewSweep() {
    _sweepSkipped = true;
  }

  /// Analyze the restored library so safety findings and dive-list badges are
  /// present immediately, instead of only after each dive is opened.
  ///
  /// Deliberately cannot fail the restore: by the time this runs the database
  /// swap and the sync re-baseline have already succeeded, so a sweep error is
  /// logged and swallowed rather than turning a completed restore into a
  /// failed one. isRestoring stays true so the barrier keeps the app blocked.
  Future<void> _runPostRestoreSafetyReview() async {
    _sweepSkipped = false;
    try {
      await _ref
          .read(postRestoreSafetyReviewProvider)
          .run(
            onProgress: (done, total) {
              if (!mounted || total == 0) return;
              state = BackupOperationState(
                status: BackupOperationStatus.inProgress,
                isRestoring: true,
                sweepProgress: SafetyReviewSweepProgress(
                  done: done,
                  total: total,
                ),
              );
            },
            isCancelled: () => _sweepSkipped,
          );
    } catch (e, st) {
      _log.error(
        'Post-restore safety review failed; the restore itself is unaffected',
        error: e,
        stackTrace: st,
      );
    }
  }
```

- [ ] **Step 5: Call it from both restore methods**

In `restoreFromBackup`, replace:

```dart
      await _syncActiveDiverAfterRestore();
      state = const BackupOperationState(
        status: BackupOperationStatus.restoreComplete,
      );
```

with:

```dart
      await _syncActiveDiverAfterRestore();
      await _runPostRestoreSafetyReview();
      state = const BackupOperationState(
        status: BackupOperationStatus.restoreComplete,
      );
```

Make the identical change in `restoreFromFilePath`.

- [ ] **Step 6: Run the tests to verify they pass**

Run: `flutter test test/features/backup/presentation/providers/backup_providers_restore_test.dart`
Expected: PASS — the pre-existing tests plus the four new ones.

- [ ] **Step 7: Verify formatting and analysis**

Run:
```bash
dart format .
flutter analyze
```
Expected: clean.

- [ ] **Step 8: Commit**

```bash
git add lib/features/backup/presentation/providers/backup_providers.dart test/features/backup/presentation/providers/backup_providers_restore_test.dart
git commit -m "feat(backup): run the safety review sweep at the end of a restore"
```

---

### Task 6: Localized strings

**Files:**
- Modify: `lib/l10n/arb/app_en.arb` and the ten other `app_*.arb` files
- Regenerate: `lib/l10n/arb/app_localizations*.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: `l10n.backup_restore_safetyReview_title`,
  `l10n.backup_restore_safetyReview_progress(done, total)`,
  `l10n.backup_restore_safetyReview_skip`

- [ ] **Step 1: Add the template strings**

In `lib/l10n/arb/app_en.arb`, add next to the other `backup_restore*` keys:

```json
  "backup_restore_safetyReview_title": "Running the safety review",
  "backup_restore_safetyReview_progress": "Analyzed {done} of {total} dives",
  "@backup_restore_safetyReview_progress": {
    "placeholders": {
      "done": {
        "type": "int"
      },
      "total": {
        "type": "int"
      }
    }
  },
  "backup_restore_safetyReview_skip": "Skip",
```

- [ ] **Step 2: Translate into the other ten locales**

Add all three keys to each of `app_ar.arb`, `app_de.arb`, `app_es.arb`,
`app_fr.arb`, `app_he.arb`, `app_hu.arb`, `app_it.arb`, `app_nl.arb`,
`app_pt.arb`, `app_zh.arb`.

Every locale file in this project repeats the `@`-metadata block for
placeholder keys, not just the template — compare
`safetySettings_analyzeAll_progress` in `app_de.arb:6571-6581`. So the
`@backup_restore_safetyReview_progress` block from Step 1 must be copied
verbatim (English key names, `"type": "int"`) into all ten files alongside
the translated string.

Suggested translations for the title / skip (translate the progress string to
match each locale's existing `safetySettings_analyzeAll_progress` phrasing):

| Locale | title | skip |
| --- | --- | --- |
| ar | جارٍ تشغيل مراجعة السلامة | تخطي |
| de | Sicherheitsprüfung läuft | Überspringen |
| es | Ejecutando la revisión de seguridad | Omitir |
| fr | Analyse de sécurité en cours | Ignorer |
| he | מריץ את סקירת הבטיחות | דלג |
| hu | Biztonsági ellenőrzés folyamatban | Kihagyás |
| it | Revisione di sicurezza in corso | Salta |
| nl | Veiligheidscontrole wordt uitgevoerd | Overslaan |
| pt | Executando a revisão de segurança | Ignorar |
| zh | 正在运行安全审查 | 跳过 |

- [ ] **Step 3: Regenerate the localization classes**

Run: `flutter gen-l10n`
Expected: `lib/l10n/arb/app_localizations*.dart` updated with the three new
getters/methods on every locale class.

- [ ] **Step 4: Verify the generated API compiles**

Run:
```bash
dart format .
flutter analyze
```
Expected: clean. An "is missing translations" warning for any locale means a
key was not added everywhere — fix and regenerate.

- [ ] **Step 5: Commit**

```bash
git add lib/l10n/arb/
git commit -m "i18n: add post-restore safety review barrier strings"
```

---

### Task 7: Restore barrier progress and Skip button

**Files:**
- Modify: `lib/features/backup/presentation/widgets/restore_barrier.dart`
- Test: `test/features/backup/presentation/widgets/restore_barrier_test.dart` (existing, add cases)

**Interfaces:**
- Consumes: `SafetyReviewSweepProgress`, `BackupOperationState.sweepProgress`, `BackupOperationNotifier.skipSafetyReviewSweep` (Task 5); the three l10n keys (Task 6).
- Produces: `restoreSweepProgressProvider` (`Provider<SafetyReviewSweepProgress?>`)

- [ ] **Step 1: Write the failing tests**

In `test/features/backup/presentation/widgets/restore_barrier_test.dart`, add
the import:

```dart
import 'package:submersion/features/backup/presentation/providers/backup_providers.dart';
```

Extend the existing `wrap` helper with an optional progress override:

```dart
  Widget wrap({
    required bool restoring,
    String? message,
    SafetyReviewSweepProgress? sweepProgress,
    required VoidCallback onTap,
  }) {
    return testApp(
      locale: const Locale('en'),
      overrides: [
        restoreInProgressProvider.overrideWithValue(restoring),
        restoreMessageProvider.overrideWithValue(message),
        restoreSweepProgressProvider.overrideWithValue(sweepProgress),
      ],
      child: RestoreBarrier(
        child: Center(
          child: ElevatedButton(onPressed: onTap, child: const Text('Tap me')),
        ),
      ),
    );
  }
```

Add these tests. They assert that the Skip button renders, not that tapping it
works: the tap closure calls `ref.read(backupOperationProvider.notifier)`,
which would need the whole backup service graph. The skip behavior itself is
already covered by the notifier test in Task 5.

```dart
  testWidgets('shows determinate sweep progress and a Skip button', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        restoring: true,
        sweepProgress: const SafetyReviewSweepProgress(done: 3, total: 10),
        onTap: () {},
      ),
    );

    expect(find.text('Running the safety review'), findsOneWidget);
    expect(find.text('Analyzed 3 of 10 dives'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);

    final bar = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(bar.value, closeTo(0.3, 0.001));
  });

  testWidgets('keeps the plain spinner when no sweep is running', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(restoring: true, message: 'Restoring backup...', onTap: () {}),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.text('Skip'), findsNothing);
  });
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/features/backup/presentation/widgets/restore_barrier_test.dart`
Expected: FAIL — `restoreSweepProgressProvider` undefined.

- [ ] **Step 3: Rewrite the barrier**

Replace the whole contents of
`lib/features/backup/presentation/widgets/restore_barrier.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/backup/presentation/providers/backup_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// True while a database restore is running. Derived (not the whole operation
/// state) so widgets rebuild only when this specific flag flips, and so tests
/// can override it with a plain value.
final restoreInProgressProvider = Provider<bool>(
  (ref) => ref.watch(backupOperationProvider.select((s) => s.isRestoring)),
);

/// The current restore progress message (e.g. "Restoring backup...").
final restoreMessageProvider = Provider<String?>(
  (ref) => ref.watch(backupOperationProvider.select((s) => s.message)),
);

/// Non-null only while the post-restore safety review sweep is running.
final restoreSweepProgressProvider = Provider<SafetyReviewSweepProgress?>(
  (ref) => ref.watch(backupOperationProvider.select((s) => s.sweepProgress)),
);

/// Wraps the whole app and, while a database restore is running, covers it with
/// an interaction-blocking overlay.
///
/// A restore briefly closes and reopens the database. Without this barrier the
/// user could navigate to a data page mid-restore, whose providers would build
/// against the transient null database and cache a fatal "Database not
/// initialized" error that survives until a full app restart (the DiveCenters
/// red-screen bug). Blocking all interaction until the restore finishes — and
/// hands off to RestoreCompletePage — closes that gap.
class RestoreBarrier extends ConsumerWidget {
  const RestoreBarrier({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isRestoring = ref.watch(restoreInProgressProvider);

    return Stack(
      children: [
        child,
        if (isRestoring)
          Positioned.fill(
            child: _RestoreOverlay(
              message: ref.watch(restoreMessageProvider),
              sweepProgress: ref.watch(restoreSweepProgressProvider),
              onSkipSweep: () => ref
                  .read(backupOperationProvider.notifier)
                  .skipSafetyReviewSweep(),
            ),
          ),
      ],
    );
  }
}

class _RestoreOverlay extends StatelessWidget {
  const _RestoreOverlay({
    this.message,
    this.sweepProgress,
    required this.onSkipSweep,
  });

  final String? message;
  final SafetyReviewSweepProgress? sweepProgress;
  final VoidCallback onSkipSweep;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sweep = sweepProgress;

    // The provider already supplies an English progress string for the swap
    // phases; fall back to a plain one if it is ever absent. Once the safety
    // sweep starts, its own localized label takes over.
    final label = sweep != null
        ? context.l10n.backup_restore_safetyReview_progress(
            sweep.done,
            sweep.total,
          )
        : (message ?? 'Restoring backup...');

    // Announce the busy/restoring state to screen readers as a live region, and
    // exclude the inner widgets' own semantics so the state is announced once
    // (not duplicated by the progress indicator and the label Text).
    return Semantics(
      container: true,
      liveRegion: true,
      label: label,
      child: ExcludeSemantics(
        child: Stack(
          children: [
            // Absorbs every pointer event and paints the scrim, so nothing
            // beneath can be tapped or scrolled during the restore.
            const ModalBarrier(dismissible: false, color: Colors.black54),
            Center(
              child: Material(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 320),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: sweep != null
                          ? _sweepChildren(context, theme, sweep, label)
                          : _spinnerChildren(theme, label),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _spinnerChildren(ThemeData theme, String label) {
    return [
      const CircularProgressIndicator(),
      const SizedBox(height: 16),
      Text(label, style: theme.textTheme.bodyMedium),
    ];
  }

  List<Widget> _sweepChildren(
    BuildContext context,
    ThemeData theme,
    SafetyReviewSweepProgress sweep,
    String label,
  ) {
    return [
      Text(
        context.l10n.backup_restore_safetyReview_title,
        style: theme.textTheme.titleMedium,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 16),
      LinearProgressIndicator(
        value: sweep.total == 0 ? null : sweep.done / sweep.total,
      ),
      const SizedBox(height: 12),
      Text(label, style: theme.textTheme.bodyMedium),
      const SizedBox(height: 8),
      // Skipping is lossless: unswept dives still compute lazily when opened.
      TextButton(
        onPressed: onSkipSweep,
        child: Text(context.l10n.backup_restore_safetyReview_skip),
      ),
    ];
  }
}
```

- [ ] **Step 4: Run the barrier tests to verify they pass**

Run: `flutter test test/features/backup/presentation/widgets/restore_barrier_test.dart`
Expected: PASS — the four pre-existing tests plus the two new ones.

- [ ] **Step 5: Verify formatting and analysis**

Run:
```bash
dart format .
flutter analyze
```
Expected: clean.

- [ ] **Step 6: Run the full test suite**

Run: `flutter test`
Expected: PASS. `RestoreBarrier` now calls `context.l10n`, so any test that
pumps it with `restoreInProgressProvider` true under a bare `MaterialApp`
would throw in `build`. If one fails, fix it by pumping through the shared
`testApp` helper (`test/helpers/test_app.dart`), which wires
`localizationsDelegates`, `supportedLocales`, and `locale`.

- [ ] **Step 7: Commit**

```bash
git add lib/features/backup/presentation/widgets/restore_barrier.dart test/features/backup/presentation/widgets/restore_barrier_test.dart
git commit -m "feat(backup): show safety sweep progress and a Skip button on the restore barrier"
```

---

## As built: deviations from the plan

Five things the plan got wrong, all corrected during execution. Recorded here
because each one is a trap the next person will hit.

1. **`Override` cannot be named.** Riverpod 3 does not export its `Override`
   type, so `List<Override> rootProviderOverrides(...)` does not compile.
   Leaving the return type to inference works but trips
   `strict_top_level_inference`, and this project treats analyzer infos as
   fatal. Final shape: return `List<dynamic>` and `.cast()` at each call site,
   matching `test/helpers/test_app.dart`. (That helper reaches the real type via
   an `// ignore: implementation_imports` import of
   `package:riverpod/src/framework.dart` — acceptable in a test helper, not in
   `lib/`.)

2. **`LogFileService` has a required `logDirectory`.** It touches no filesystem
   until `initialize()`, so tests construct it with any path.

3. **Foreign keys ARE enforced by `setUpTestDatabase()`.** A `dives` row whose
   `diver_id` has no `divers` parent fails with SQLITE_CONSTRAINT (787). Every
   test fixture inserts the diver first.

4. **`SettingsNotifier` needed two fixes, both latent bugs independent of
   backups.** `state` starts at the `AppSettings` DEFAULTS and is replaced
   asynchronously, so the scratch container would have graded dives against
   default gradient factors — defeating its entire purpose. Added
   `initialLoad`, awaited by `PostRestoreSafetyReview` before sweeping.
   Separately, `_loadSettings` assigned `state` after an `await` with no
   `mounted` check, throwing "Tried to use SettingsNotifier after dispose"
   whenever a `ProviderScope` is torn down mid-load — reachable today via
   `restartApp()`'s soft restart, not just the new container. Added the guard.
   Consequence: four test fakes that `implements SettingsNotifier` had to gain
   `Future<void> get initialLoad async {}` (`test/helpers/mock_providers.dart`,
   `settings_page_test.dart`, `settings_page_shared_data_test.dart`,
   `records_page_test.dart`).

5. **`_analyzeFailed` was deleted, not reassigned.** Once the snackbar reads
   `result.failed`, the field becomes write-only, which the analyzer flags.

6. **The all-divers sweep needed one pass per diver** (found in PR #916 review,
   fixed in `3202c07`). The plan's single container with `diverId: null` graded
   every non-active diver's dives with the ACTIVE diver's gradient factors and
   persisted the result stamped with the current `engineVersion`. Fixed with a
   `SettingsNotifier.preloaded` constructor and one container per diver, plus a
   trailing pass for dives with a null `diver_id`. See spec section 3b.

An extra test was added beyond the plan:
`reads settings from the restored database, not the defaults` in
`post_restore_safety_review_test.dart`. It switches the master toggle off in the
restored diver's row and asserts the sweep no-ops — the only assertion that
actually proves the scratch container reads restored settings rather than
defaults, and the regression guard for deviation 4.

## Verification

- [ ] `dart format .` reports no changes
- [ ] `flutter analyze` is clean across the whole project
- [ ] `flutter test` passes in full
- [ ] Manual: restore a backup created before the safety review feature
      existed. The barrier shows "Running the safety review" with a moving
      determinate bar, then the restore-complete screen appears. After the
      restart, dive-list rows show finding badges and dive detail pages show a
      populated safety review section without opening each dive first.
- [ ] Manual: tap Skip mid-sweep. The restore completes immediately, and an
      unswept dive still populates its review when opened.
