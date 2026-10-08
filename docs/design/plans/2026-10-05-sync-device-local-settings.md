# Sync View Modes, Viewport and pSCR Settings Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Persist the certification and course list view modes in `diver_settings`, and move the "profile metrics follow viewport" and pSCR ratio preferences from SharedPreferences into `diver_settings` so they sync, adopting each device's existing value.

**Architecture:** One schema rung (v262) adds four `diver_settings` columns. The two view modes follow the six existing view-mode columns end to end. The two moved preferences are nullable columns: null means "never held a value", and on load a null column adopts this device's pref, when it differs from the default, through a dedicated write that fills only a still-null column.

> **Revised after the final review (PR #2991).** This plan first said a default-valued pref is adopted too. That was dropped: before v262 every save wrote both prefs, so a default-valued one is no sign of a choice, and adopting it stamps a fresh clock on the whole `diver_settings` row, letting the device upgraded last overwrite a value chosen on another device. As shipped: only a non-default pref is adopted; `adoptDeviceLocalValues` updates `WHERE <column> IS NULL`, returns whether it wrote, and queues the row for sync only then; the load re-reads the row whenever it attempted an adoption; and on import an explicit null for either column is treated as omitted (`_withoutUnsetNulls`). The task steps below are updated to match.

**Tech Stack:** Flutter, Drift (SQLite), Riverpod (StateNotifier), SharedPreferences, flutter_test.

**Spec:** `docs/design/specs/2026-10-05-sync-device-local-settings-design.md`

## Global Constraints

- Schema version 262; `minimumCompatibleSchemaVersion` stays 240.
- Columns: `certification_list_view_mode TEXT NOT NULL DEFAULT 'detailed'`, `course_list_view_mode TEXT NOT NULL DEFAULT 'detailed'`, `profile_metrics_follow_viewport INTEGER` (nullable), `pscr_ratio REAL` (nullable).
- Null `pscr_ratio` reads as `100.0`; null `profile_metrics_follow_viewport` reads as `false`.
- Rule: a diver row with no value adopts this device's pref if it differs from the default, otherwise reads the default. Prefs are not removed.
- With a diver, the two prefs are never written; with no diver they remain the store.
- Home layout, O2 cell unit and Perdix overlay stay device-local.
- Certification and course lists offer only detailed and table; the in-list overflow menu stays session-only.
- No em-dashes anywhere. Run `dart format .` before each commit.

## Review Focus

1. A pref equal to the default (pSCR 100, viewport off) must NOT be adopted: it carries no choice, and writing it would let this device overwrite a value chosen elsewhere. Pinned in Task 4.
2. A row that already holds a value must win over a stale pref on a second device. Pinned in Task 4.
3. A payload from an older peer (v240 to v260) omits the new columns: the view modes must land as `detailed` and the nullable columns as null without failing the import. Pinned in Task 5.
4. A database restored from a backup at v262 that lacks the columns must regain them on open (backstop). Pinned in Task 1.
5. A session override from the certification or course list menu must survive an unrelated settings write (the provider seeds with `ref.read`). Pinned in Task 2.

---

### Task 1: Schema v262 columns, rung and backstop

**Files:**
- Modify: `lib/core/database/tables/diver_tables.dart` (after `diveCenterListViewMode`, around :311)
- Modify: `lib/core/database/migrations/helpers/diver_migrations.dart` (new helper at the top of the extension)
- Modify: `lib/core/database/migrations/ladder/rungs_v231_onward.dart` (after the v260 block)
- Modify: `lib/core/database/migrations/before_open.dart` (next to the v237 backstop)
- Modify: `lib/core/database/database.dart` (`currentSchemaVersion` :235, `migrationVersions` end :1085)
- Create: `test/core/database/migration_v262_synced_device_settings_test.dart`
- Modify: `test/core/database/migration_v260_tank_shared_computers_test.dart:11`

**Interfaces:**
- Produces: Drift fields `DiverSetting.certificationListViewMode` (String), `courseListViewMode` (String), `profileMetricsFollowViewport` (bool?), `pscrRatio` (double?), and the matching `DiverSettingsCompanion` fields.

- [ ] **Step 1: Write the failing migration test**

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// v262: diver_settings columns for settings that now sync (issue #2948):
/// the certification and course list view modes, and the profile "metrics
/// follow viewport" and pSCR ratio preferences, which were device-local.
void main() {
  Future<Map<String, Map<String, Object?>>> settingsColumns(
    AppDatabase db,
  ) async {
    final cols = await db
        .customSelect("PRAGMA table_info('diver_settings')")
        .get();
    return {for (final c in cols) c.read<String>('name'): c.data};
  }

  NativeDatabase strandedAt(int? userVersion) => NativeDatabase.memory(
    setup: (rawDb) {
      if (userVersion != null) {
        rawDb.execute('PRAGMA user_version = $userVersion');
      }
      rawDb.execute('''
        CREATE TABLE diver_settings (
          id TEXT NOT NULL PRIMARY KEY,
          created_at INTEGER,
          updated_at INTEGER
        )
      ''');
    },
  );

  const newColumns = [
    'certification_list_view_mode',
    'course_list_view_mode',
    'profile_metrics_follow_viewport',
    'pscr_ratio',
  ];

  test('v262 is the current schema version and is in the ladder', () {
    // The newest rung owns the exact assertion; relax it to
    // greaterThanOrEqualTo when the next one lands.
    expect(AppDatabase.currentSchemaVersion, 262);
    expect(AppDatabase.migrationVersions, contains(262));
    expect(AppDatabase.migrationStepCount(260), 1);
  });

  test('the columns are additive, so the sync floor does not move', () {
    expect(AppDatabase.minimumCompatibleSchemaVersion, 240);
  });

  test('a fresh database has the view modes defaulted and the moved '
      'preferences nullable', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final cols = await settingsColumns(db);
    for (final name in [
      'certification_list_view_mode',
      'course_list_view_mode',
    ]) {
      expect(cols[name]!['notnull'], 1, reason: name);
      expect(cols[name]!['dflt_value'], contains('detailed'), reason: name);
    }
    for (final name in ['profile_metrics_follow_viewport', 'pscr_ratio']) {
      expect(cols[name]!['notnull'], 0, reason: name);
      expect(cols[name]!['dflt_value'], isNull, reason: name);
    }
  });

  test('a database stranded before v262 gains the columns', () async {
    final db = AppDatabase(strandedAt(null));
    addTearDown(db.close);
    expect((await settingsColumns(db)).keys, containsAll(newColumns));
  });

  test('a database already at v262 without them regains them via '
      'beforeOpen', () async {
    final db = AppDatabase(strandedAt(AppDatabase.currentSchemaVersion));
    addTearDown(db.close);
    expect((await settingsColumns(db)).keys, containsAll(newColumns));
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/core/database/migration_v262_synced_device_settings_test.dart`
Expected: FAIL (`currentSchemaVersion` is 260; columns missing).

- [ ] **Step 3: Add the Drift columns** in `diver_tables.dart`, directly after `diveCenterListViewMode`:

```dart
  /// v262 (issue #2948): the certification and course list view modes,
  /// which were in-memory only and reset on every restart.
  TextColumn get certificationListViewMode =>
      text().withDefault(const Constant('detailed'))();
  TextColumn get courseListViewMode =>
      text().withDefault(const Constant('detailed'))();

  /// v262 (issue #2948): profile metric overlays follow the zoomed depth
  /// window, and the passive-SCR ratio. Both were device-local prefs.
  /// Nullable ON PURPOSE: null marks a row that has never held a value,
  /// which is what lets each device adopt its old pref into it (see
  /// SettingsNotifier). Null reads as off and 100.
  BoolColumn get profileMetricsFollowViewport => boolean().nullable()();
  RealColumn get pscrRatio => real().nullable()();
```

- [ ] **Step 4: Add the helper** at the top of `extension DiverMigrations` in `diver_migrations.dart`:

```dart
  /// v262: diver_settings columns for settings that now sync (issue #2948).
  /// The two view modes are not null with a 'detailed' default; the two
  /// moved preferences are nullable with no default, so null marks a row
  /// that has never held a value. Idempotent, so it is safe to call from
  /// both onUpgrade and the beforeOpen backstop.
  Future<void> _assertSyncedDeviceSettingsColumns() async {
    await _addColumnIfMissing(
      'diver_settings',
      'certification_list_view_mode',
      "TEXT NOT NULL DEFAULT 'detailed'",
    );
    await _addColumnIfMissing(
      'diver_settings',
      'course_list_view_mode',
      "TEXT NOT NULL DEFAULT 'detailed'",
    );
    await _addColumnIfMissing(
      'diver_settings',
      'profile_metrics_follow_viewport',
      'INTEGER',
    );
    await _addColumnIfMissing('diver_settings', 'pscr_ratio', 'REAL');
  }
```

- [ ] **Step 5: Add the rung** after the v260 block in `rungs_v231_onward.dart`:

```dart
    // v262: diver_settings columns for settings that now sync (issue
    // #2948): certification and course list view modes, and the profile
    // "metrics follow viewport" and pSCR ratio prefs. Column only; each
    // device adopts its old pref on load. Re-asserted in beforeOpen.
    if (from < 262) {
      await _assertSyncedDeviceSettingsColumns();
    }
    if (from < 262) await reportProgress();
```

- [ ] **Step 6: Add the backstop** in `before_open.dart`, directly above `// v237 backstop: the dive figure switch.`:

```dart
    // v262 backstop: the synced view mode and device-preference columns.
    await _assertSyncedDeviceSettingsColumns();

```

- [ ] **Step 7: Bump the version** in `database.dart`: set `static const int currentSchemaVersion = 262;` and append to `migrationVersions` after `260,`:

```dart
    // v262: diver_settings certification/course list view modes and the
    // formerly device-local profile "metrics follow viewport" and pSCR
    // ratio (issue #2948). Additive columns, so the floor stays.
    262,
```

- [ ] **Step 8: Relax the v260 tripwire** in `migration_v260_tank_shared_computers_test.dart`: replace `expect(AppDatabase.currentSchemaVersion, 260);` with `expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(260));` and change its comment to `// Relaxed once v262 landed on top; the newest rung owns the exact assertion.`

- [ ] **Step 9: Regenerate and run**

Run: `dart run build_runner build --delete-conflicting-outputs` then `flutter test test/core/database/migration_v262_synced_device_settings_test.dart test/core/database/migration_v260_tank_shared_computers_test.dart test/core/database/migration_v237_show_dive_figure_test.dart`
Expected: PASS. Then `grep -rln "\b260\b" test | xargs grep -ln "user_version\|currentSchemaVersion"` and confirm only the v260 test pins 260 as "current".

- [ ] **Step 10: Commit**

```bash
git add lib/core/database/tables/diver_tables.dart lib/core/database/migrations/helpers/diver_migrations.dart lib/core/database/migrations/ladder/rungs_v231_onward.dart lib/core/database/migrations/before_open.dart lib/core/database/database.dart test/core/database/migration_v262_synced_device_settings_test.dart test/core/database/migration_v260_tank_shared_computers_test.dart
git commit -m "feat(settings): add v262 diver_settings columns for synced view and device settings"
```

---

### Task 2: Persist the certification and course list view modes

**Files:**
- Modify: `lib/features/settings/presentation/providers/settings_providers.dart` (AppSettings fields near :365, constructor near :645, `copyWith` params near :827 and body near :992, setters after `setDiveCenterListViewMode` near :2207)
- Modify: `lib/features/settings/data/repositories/diver_settings_repository.dart` (insert near :178, `_storedColumns` near :434, `_mapRowToAppSettings` near :640)
- Modify: `lib/features/certifications/presentation/providers/certification_providers.dart:296-302`
- Modify: `lib/features/courses/presentation/providers/course_providers.dart` (the `courseListViewModeProvider` block near :362)
- Modify: `lib/features/settings/presentation/pages/section_appearance_page.dart:661-704`
- Modify: `test/helpers/mock_providers.dart` (after `setDiveCenterListViewMode`), `test/features/insights/presentation/pages/records_page_test.dart` (same place)
- Create: `test/features/settings/data/repositories/diver_settings_repository_cert_course_view_mode_test.dart`
- Create: `test/features/settings/presentation/providers/cert_course_view_mode_provider_test.dart`
- Modify: `test/features/settings/presentation/pages/section_appearance_page_test.dart:546-660`

**Interfaces:**
- Consumes: Task 1's `DiverSetting.certificationListViewMode` / `courseListViewMode`.
- Produces: `AppSettings.certificationListViewMode`, `AppSettings.courseListViewMode` (ListViewMode, default `detailed`); `SettingsNotifier.setCertificationListViewMode(ListViewMode)`, `setCourseListViewMode(ListViewMode)` (Future<void>).

- [ ] **Step 1: Write the failing repository test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/settings/data/repositories/diver_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

void main() {
  test('both view modes default to detailed and copyWith carries them', () {
    const settings = AppSettings();
    expect(settings.certificationListViewMode, ListViewMode.detailed);
    expect(settings.courseListViewMode, ListViewMode.detailed);
    final changed = settings.copyWith(
      certificationListViewMode: ListViewMode.table,
      courseListViewMode: ListViewMode.table,
    );
    expect(changed.certificationListViewMode, ListViewMode.table);
    expect(changed.courseListViewMode, ListViewMode.table);
  });

  group('DiverSettingsRepository certification/course view modes', () {
    late AppDatabase db;
    late DiverSettingsRepository repository;

    setUp(() async {
      db = await setUpTestDatabase();
      repository = DiverSettingsRepository();
      final now = DateTime.now().millisecondsSinceEpoch;
      await db
          .into(db.divers)
          .insert(
            DiversCompanion.insert(
              id: 'd1',
              name: 'Test Diver',
              createdAt: now,
              updatedAt: now,
            ),
          );
    });

    tearDown(() {
      DatabaseService.instance.resetForTesting();
    });

    test('new settings start detailed', () async {
      await repository.createSettingsForDiver('d1');
      final loaded = await repository.getSettingsForDiver('d1');
      expect(loaded!.certificationListViewMode, ListViewMode.detailed);
      expect(loaded.courseListViewMode, ListViewMode.detailed);
    });

    test('table round-trips through a partial write', () async {
      final created = await repository.createSettingsForDiver('d1');
      await repository.updateSettingsForDiver(
        'd1',
        created.copyWith(
          certificationListViewMode: ListViewMode.table,
          courseListViewMode: ListViewMode.table,
        ),
        previous: created,
      );
      final loaded = await repository.getSettingsForDiver('d1');
      expect(loaded!.certificationListViewMode, ListViewMode.table);
      expect(loaded.courseListViewMode, ListViewMode.table);
    });
  });
}
```

- [ ] **Step 2: Write the failing provider test** (`cert_course_view_mode_provider_test.dart`)

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';
import 'package:submersion/features/courses/presentation/providers/course_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';

void main() {
  ProviderContainer containerWith(MockSettingsNotifier notifier) {
    final container = ProviderContainer(
      overrides: [settingsProvider.overrideWith((ref) => notifier)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('both list providers seed from the saved settings', () {
    final container = containerWith(
      MockSettingsNotifier(
        const AppSettings(
          certificationListViewMode: ListViewMode.table,
          courseListViewMode: ListViewMode.table,
        ),
      ),
    );
    expect(
      container.read(certificationListViewModeProvider),
      ListViewMode.table,
    );
    expect(container.read(courseListViewModeProvider), ListViewMode.table);
  });

  test('a session override survives an unrelated settings write', () async {
    final notifier = MockSettingsNotifier();
    final container = containerWith(notifier);
    container.read(certificationListViewModeProvider.notifier).state =
        ListViewMode.table;
    container.read(courseListViewModeProvider.notifier).state =
        ListViewMode.table;

    await notifier.setTripListViewMode(ListViewMode.compact);

    expect(
      container.read(certificationListViewModeProvider),
      ListViewMode.table,
    );
    expect(container.read(courseListViewModeProvider), ListViewMode.table);
  });
}
```

- [ ] **Step 3: Update the section appearance widget tests** in `section_appearance_page_test.dart`. Replace the two tests in the group `'SectionAppearancePage - View mode for certifications/courses'` with tests that drive the saved setting, and replace the two "updates runtime provider" tests with tests that check the notifier saved the choice:

```dart
  group('SectionAppearancePage - View mode for certifications/courses', () {
    testWidgets('certifications shows the saved view mode', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 4000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _buildTestWidget(
          'certifications',
          notifier: MockSettingsNotifier(
            const AppSettings(certificationListViewMode: ListViewMode.table),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(DropdownButton<ListViewMode>),
          matching: find.text('Table'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('courses shows the saved view mode', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 4000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _buildTestWidget(
          'courses',
          notifier: MockSettingsNotifier(
            const AppSettings(courseListViewMode: ListViewMode.table),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(DropdownButton<ListViewMode>),
          matching: find.text('Table'),
        ),
        findsOneWidget,
      );
    });
  });
```

and, replacing `'changing dropdown for certifications updates runtime provider'` and `'changing dropdown for courses updates runtime provider'`:

```dart
    for (final key in ['certifications', 'courses']) {
      testWidgets('changing dropdown for $key saves the view mode', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(const Size(400, 4000));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final notifier = MockSettingsNotifier();

        await tester.pumpWidget(_buildTestWidget(key, notifier: notifier));
        await tester.pumpAndSettle();

        await tester.tap(find.byType(DropdownButton<ListViewMode>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Table').last);
        await tester.pumpAndSettle();

        final saved = key == 'certifications'
            ? notifier.state.certificationListViewMode
            : notifier.state.courseListViewMode;
        expect(saved, ListViewMode.table);
        expect(
          find.descendant(
            of: find.byType(DropdownButton<ListViewMode>),
            matching: find.text('Table'),
          ),
          findsOneWidget,
        );
      });
    }
```

Remove the now-unused imports of `certification_providers.dart` and `course_providers.dart` from this test if `flutter analyze` flags them.

- [ ] **Step 4: Run to verify failure**

Run: `flutter test test/features/settings/data/repositories/diver_settings_repository_cert_course_view_mode_test.dart test/features/settings/presentation/providers/cert_course_view_mode_provider_test.dart test/features/settings/presentation/pages/section_appearance_page_test.dart`
Expected: compile FAIL (`certificationListViewMode` not defined on AppSettings).

- [ ] **Step 5: AppSettings fields.** In `settings_providers.dart`, after `final ListViewMode diveCenterListViewMode;`:

```dart
  /// Certification and course list view modes (v262, issue #2948).
  final ListViewMode certificationListViewMode;
  final ListViewMode courseListViewMode;
```

Constructor, after `this.diveCenterListViewMode = ListViewMode.detailed,`:

```dart
    this.certificationListViewMode = ListViewMode.detailed,
    this.courseListViewMode = ListViewMode.detailed,
```

`copyWith` parameters, after `ListViewMode? diveCenterListViewMode,`:

```dart
    ListViewMode? certificationListViewMode,
    ListViewMode? courseListViewMode,
```

`copyWith` body, after the `diveCenterListViewMode:` assignment:

```dart
      certificationListViewMode:
          certificationListViewMode ?? this.certificationListViewMode,
      courseListViewMode: courseListViewMode ?? this.courseListViewMode,
```

- [ ] **Step 6: Setters**, after `setDiveCenterListViewMode`:

```dart
  Future<void> setCertificationListViewMode(ListViewMode mode) async {
    state = state.copyWith(certificationListViewMode: mode);
    await _saveSettings();
  }

  Future<void> setCourseListViewMode(ListViewMode mode) async {
    state = state.copyWith(courseListViewMode: mode);
    await _saveSettings();
  }
```

And in both `test/helpers/mock_providers.dart` and `test/features/insights/presentation/pages/records_page_test.dart`, after `setDiveCenterListViewMode`:

```dart
  @override
  Future<void> setCertificationListViewMode(ListViewMode mode) async =>
      state = state.copyWith(certificationListViewMode: mode);
  @override
  Future<void> setCourseListViewMode(ListViewMode mode) async =>
      state = state.copyWith(courseListViewMode: mode);
```

- [ ] **Step 7: Repository mapping.** In `diver_settings_repository.dart`:

Insert (`createSettingsForDiver`), after `diveCenterListViewMode: Value(s.diveCenterListViewMode.name),`:

```dart
              certificationListViewMode: Value(
                s.certificationListViewMode.name,
              ),
              courseListViewMode: Value(s.courseListViewMode.name),
```

`_storedColumns`, after `diveCenterListViewMode: Value(settings.diveCenterListViewMode.name),`:

```dart
    certificationListViewMode: Value(settings.certificationListViewMode.name),
    courseListViewMode: Value(settings.courseListViewMode.name),
```

`_mapRowToAppSettings`, after the `diveCenterListViewMode:` line:

```dart
      certificationListViewMode: ListViewMode.fromName(
        row.certificationListViewMode,
      ),
      courseListViewMode: ListViewMode.fromName(row.courseListViewMode),
```

- [ ] **Step 8: Seed the list providers.** Replace the block in `certification_providers.dart`:

```dart
/// Runtime-scoped certification list view mode. Initialized from the saved
/// setting (v262), and overridden by the list's menu without changing the
/// saved default.
///
/// Uses `ref.read()` (not `ref.watch()`) for the same reason as
/// [diveListViewModeProvider]: a write to any other setting must not reset
/// the session override.
final certificationListViewModeProvider = StateProvider<ListViewMode>((ref) {
  return ref.read(settingsProvider).certificationListViewMode;
});
```

and in `course_providers.dart`:

```dart
/// Runtime-scoped course list view mode. Same contract as
/// [certificationListViewModeProvider]: seeded once from the saved setting
/// (v262) with `ref.read`, overridden by the list's menu for the session.
final courseListViewModeProvider = StateProvider<ListViewMode>((ref) {
  return ref.read(settingsProvider).courseListViewMode;
});
```

Add `import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';` to either file if it is not already imported (check with `grep -n settings_providers` first; keep import order: dart, flutter, packages, local).

- [ ] **Step 9: Section appearance page.** In `_getCurrentViewMode`, replace the two runtime lines:

```dart
      'certifications' => ref
          .watch(settingsProvider)
          .certificationListViewMode,
      'courses' => ref.watch(settingsProvider).courseListViewMode,
```

In `_setViewMode`, replace the two runtime-only cases:

```dart
      case 'certifications':
        ref.read(settingsProvider.notifier).setCertificationListViewMode(mode);
        ref.read(certificationListViewModeProvider.notifier).state = mode;
      case 'courses':
        ref.read(settingsProvider.notifier).setCourseListViewMode(mode);
        ref.read(courseListViewModeProvider.notifier).state = mode;
```

- [ ] **Step 10: Run the tests**

Run: `flutter test test/features/settings/data/repositories/diver_settings_repository_cert_course_view_mode_test.dart test/features/settings/presentation/providers/cert_course_view_mode_provider_test.dart test/features/settings/presentation/pages/section_appearance_page_test.dart test/features/certifications test/features/courses test/features/insights/presentation/pages/records_page_test.dart`
Expected: PASS.

- [ ] **Step 11: Commit**

```bash
git add lib/features/settings lib/features/certifications/presentation/providers/certification_providers.dart lib/features/courses/presentation/providers/course_providers.dart test/helpers/mock_providers.dart test/features/insights/presentation/pages/records_page_test.dart test/features/settings
git commit -m "feat(settings): save the certification and course list view modes"
```

---

### Task 3: Repository support for the moved preferences

**Files:**
- Modify: `lib/features/settings/data/repositories/diver_settings_repository.dart` (probe next to `hasSeascapeAppearance` :65, `updateSettingsForDiver` :283, `_storedColumns`, `_mapRowToAppSettings`)
- Create: `test/features/settings/data/repositories/diver_settings_repository_adoptable_prefs_test.dart`

**Interfaces:**
- Consumes: Task 1's `DiverSetting.pscrRatio` (double?), `profileMetricsFollowViewport` (bool?).
- Produces:
  - `Future<({bool pscrRatio, bool profileMetricsFollowViewport})> unsetAdoptableColumns(String diverId)`: true for each column that is null (or when the row is missing).
  - `Future<bool> adoptDeviceLocalValues(String diverId, {double? pscrRatio, bool? profileMetricsFollowViewport})`: writes each non-null argument into its column only while that column is still null (`WHERE ... IS NULL`), marks the row pending for sync only when a column was written, and returns whether one was; no-op returning false when both are null.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/settings/data/repositories/diver_settings_repository.dart';

import '../../../../helpers/test_database.dart';

/// v262 (issue #2948): pSCR ratio and "metrics follow viewport" moved from
/// device-local prefs into nullable diver_settings columns.
void main() {
  late AppDatabase db;
  late DiverSettingsRepository repository;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = DiverSettingsRepository();
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.divers)
        .insert(
          DiversCompanion.insert(
            id: 'd1',
            name: 'Test Diver',
            createdAt: now,
            updatedAt: now,
          ),
        );
  });

  tearDown(() {
    DatabaseService.instance.resetForTesting();
  });

  Future<DiverSetting> row() => (db.select(
    db.diverSettings,
  )..where((t) => t.diverId.equals('d1'))).getSingle();

  test('a new row leaves both columns unset and reads the defaults', () async {
    final created = await repository.createSettingsForDiver('d1');
    expect(created.pscrRatio, 100.0);
    expect(created.profileMetricsFollowViewport, isFalse);
    expect((await row()).pscrRatio, isNull);
    expect((await row()).profileMetricsFollowViewport, isNull);
    final unset = await repository.unsetAdoptableColumns('d1');
    expect(unset.pscrRatio, isTrue);
    expect(unset.profileMetricsFollowViewport, isTrue);
  });

  test('a missing row counts as unset', () async {
    final unset = await repository.unsetAdoptableColumns('d1');
    expect(unset.pscrRatio, isTrue);
    expect(unset.profileMetricsFollowViewport, isTrue);
  });

  test('adopting writes values equal to the defaults too', () async {
    await repository.createSettingsForDiver('d1');
    await repository.adoptDeviceLocalValues(
      'd1',
      pscrRatio: 100.0,
      profileMetricsFollowViewport: false,
    );
    expect((await row()).pscrRatio, 100.0);
    expect((await row()).profileMetricsFollowViewport, isFalse);
    final unset = await repository.unsetAdoptableColumns('d1');
    expect(unset.pscrRatio, isFalse);
    expect(unset.profileMetricsFollowViewport, isFalse);
  });

  test('adopting one value leaves the other unset', () async {
    await repository.createSettingsForDiver('d1');
    await repository.adoptDeviceLocalValues('d1', pscrRatio: 40.0);
    final loaded = await repository.getSettingsForDiver('d1');
    expect(loaded!.pscrRatio, 40.0);
    expect((await row()).profileMetricsFollowViewport, isNull);
  });

  test('a changed value round-trips through a partial write', () async {
    final created = await repository.createSettingsForDiver('d1');
    await repository.updateSettingsForDiver(
      'd1',
      created.copyWith(pscrRatio: 25.0, profileMetricsFollowViewport: true),
      previous: created,
    );
    final loaded = await repository.getSettingsForDiver('d1');
    expect(loaded!.pscrRatio, 25.0);
    expect(loaded.profileMetricsFollowViewport, isTrue);
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/settings/data/repositories/diver_settings_repository_adoptable_prefs_test.dart`
Expected: compile FAIL (`unsetAdoptableColumns` not defined).

- [ ] **Step 3: Probe and adoption write.** After `hasSeascapeAppearance` add:

```dart
  /// Which of the diver's settings columns that adopt a device-local pref
  /// (v262, issue #2948) have never held a value. A missing row counts as
  /// unset for both: the load creates it with both columns null.
  Future<({bool pscrRatio, bool profileMetricsFollowViewport})>
  unsetAdoptableColumns(String diverId) async {
    final row = await (_db.select(
      _db.diverSettings,
    )..where((t) => t.diverId.equals(diverId))).getSingleOrNull();
    return (
      pscrRatio: row?.pscrRatio == null,
      profileMetricsFollowViewport: row?.profileMetricsFollowViewport == null,
    );
  }

  /// Stores this device's pref values into the diver's row (v262, issue
  /// #2948), each non-null one, whether or not it equals the default. The
  /// diff in [updateSettingsForDiver] cannot do this: a null column reads
  /// as the default, so adopting a default-valued pref would look like no
  /// change and leave the column null. Queued for sync like any other write.
  Future<void> adoptDeviceLocalValues(
    String diverId, {
    double? pscrRatio,
    bool? profileMetricsFollowViewport,
  }) async {
    if (pscrRatio == null && profileMetricsFollowViewport == null) return;
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await (_db.update(
        _db.diverSettings,
      )..where((t) => t.diverId.equals(diverId))).write(
        DiverSettingsCompanion(
          pscrRatio: pscrRatio == null
              ? const Value.absent()
              : Value(pscrRatio),
          profileMetricsFollowViewport: profileMetricsFollowViewport == null
              ? const Value.absent()
              : Value(profileMetricsFollowViewport),
          updatedAt: Value(now),
        ),
      );
      await _markSettingsPending(diverId, now);
      _log.info('Adopted device-local settings for diver: $diverId');
    } catch (e, stackTrace) {
      _log.error(
        'Failed to adopt device-local settings for diver: $diverId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
```

- [ ] **Step 4: Extract the mark-pending block** from `updateSettingsForDiver` into a helper and call it from there (replace the `final row = ... if (row != null) {...}` block with `await _markSettingsPending(diverId, now);`):

```dart
  /// Queues the diver's settings row for sync after a write at [now].
  Future<void> _markSettingsPending(String diverId, int now) async {
    final row = await (_db.select(
      _db.diverSettings,
    )..where((t) => t.diverId.equals(diverId))).getSingleOrNull();
    if (row == null) return;
    await _syncRepository.markRecordPending(
      entityType: 'diverSettings',
      recordId: row.id,
      localUpdatedAt: now,
    );
    SyncEventBus.notifyLocalChange();
  }
```

- [ ] **Step 5: Stored columns and row mapping.** `_storedColumns`, after the two Task 2 view-mode lines:

```dart
    pscrRatio: Value(settings.pscrRatio),
    profileMetricsFollowViewport: Value(settings.profileMetricsFollowViewport),
```

`_mapRowToAppSettings`, after the Task 2 view-mode lines:

```dart
      // Null: the row has never held a value (v262); read the default.
      pscrRatio: row.pscrRatio ?? 100.0,
      profileMetricsFollowViewport: row.profileMetricsFollowViewport ?? false,
```

Do NOT add them to the insert in `createSettingsForDiver`: a new row starts null so the load can adopt this device's pref.

- [ ] **Step 6: Run the tests**

Run: `flutter test test/features/settings/data/repositories/`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/features/settings/data/repositories/diver_settings_repository.dart test/features/settings/data/repositories/diver_settings_repository_adoptable_prefs_test.dart
git commit -m "feat(settings): store pSCR ratio and viewport following per diver"
```

---

### Task 4: SettingsNotifier adoption, save and reload

**Files:**
- Modify: `lib/features/settings/presentation/providers/settings_providers.dart` (`SettingsKeys` comments :97 and :106-110, `AppSettings.pscrRatio` doc :291-294, `_withDeviceLocalPrefs` :1312, `_loadSettings` :1376-1457, `_saveSettings` :1505-1550)
- Create: `test/features/settings/synced_device_prefs_adoption_test.dart`
- Modify: `test/features/settings/presentation/providers/settings_sync_reload_test.dart:126-135`

**Interfaces:**
- Consumes: Task 3's `unsetAdoptableColumns`, `adoptDeviceLocalValues`.
- Produces: no new public API.

- [ ] **Step 1: Write the failing adoption test** (`synced_device_prefs_adoption_test.dart`, modelled on `seascape_appearance_setting_test.dart`)

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/data/repositories/diver_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../helpers/test_database.dart';

/// Since v262 the pSCR ratio and "metrics follow viewport" are per-diver
/// (synced, issue #2948). A row that has never held one adopts this
/// device's old pref; the pref is kept so every diver can adopt it.
void main() {
  late AppDatabase db;

  Future<void> insertDiver(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.divers)
        .insert(
          DiversCompanion.insert(
            id: id,
            name: 'Diver $id',
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  Future<ProviderContainer> containerWith(
    Map<String, Object> prefsSeed, {
    String? diverId = 'd1',
    bool createRow = true,
    Future<void> Function(AppDatabase db)? prepareDb,
  }) async {
    SharedPreferences.setMockInitialValues({
      if (diverId != null) currentDiverIdKey: diverId,
      ...prefsSeed,
    });
    final prefs = await SharedPreferences.getInstance();
    db = await setUpTestDatabase();
    if (diverId != null) {
      await insertDiver(diverId);
      if (createRow) {
        await DiverSettingsRepository().createSettingsForDiver(diverId);
      }
    }
    await prepareDb?.call(db);
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    await container.read(settingsProvider.notifier).settingsLoaded;
    return container;
  }

  Future<DiverSetting> row(String diverId) => (db.select(
    db.diverSettings,
  )..where((t) => t.diverId.equals(diverId))).getSingle();

  tearDown(() {
    DatabaseService.instance.resetForTesting();
  });

  test('an unset row adopts both prefs and writes them through', () async {
    final container = await containerWith({
      SettingsKeys.pscrRatio: 40.0,
      SettingsKeys.profileMetricsFollowViewport: true,
    });

    expect(container.read(settingsProvider).pscrRatio, 40.0);
    expect(container.read(settingsProvider).profileMetricsFollowViewport, true);
    expect((await row('d1')).pscrRatio, 40.0);
    expect((await row('d1')).profileMetricsFollowViewport, isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getDouble(SettingsKeys.pscrRatio), 40.0);
  });

  test('a pref equal to the default is not adopted', () async {
    final container = await containerWith({
      SettingsKeys.pscrRatio: 100.0,
      SettingsKeys.profileMetricsFollowViewport: false,
    });

    expect(container.read(settingsProvider).pscrRatio, 100.0);
    expect((await row('d1')).pscrRatio, isNull);
    expect((await row('d1')).profileMetricsFollowViewport, isNull);
  });

  test('no pref leaves the columns unset and reads the defaults', () async {
    final container = await containerWith({});

    expect(container.read(settingsProvider).pscrRatio, 100.0);
    expect(container.read(settingsProvider).profileMetricsFollowViewport,
        isFalse);
    expect((await row('d1')).pscrRatio, isNull);
    expect((await row('d1')).profileMetricsFollowViewport, isNull);
  });

  test('a row that holds a value wins over a stale pref', () async {
    final container = await containerWith(
      {
        SettingsKeys.pscrRatio: 40.0,
        SettingsKeys.profileMetricsFollowViewport: false,
      },
      prepareDb: (db) => db.customStatement(
        'UPDATE diver_settings SET pscr_ratio = 15.0, '
        'profile_metrics_follow_viewport = 1',
      ),
    );

    expect(container.read(settingsProvider).pscrRatio, 15.0);
    expect(container.read(settingsProvider).profileMetricsFollowViewport, true);
    expect((await row('d1')).pscrRatio, 15.0);
  });

  test('a new diver with no row yet adopts the pref', () async {
    await containerWith({SettingsKeys.pscrRatio: 40.0}, createRow: false);

    expect((await row('d1')).pscrRatio, 40.0);
  });

  test('a second diver on the device adopts the same pref', () async {
    final container = await containerWith(
      {SettingsKeys.pscrRatio: 40.0},
      prepareDb: (db) async {
        await insertDiver('d2');
        await DiverSettingsRepository().createSettingsForDiver('d2');
      },
    );

    await container.read(currentDiverIdProvider.notifier).setCurrentDiver('d2');
    await container.read(settingsProvider.notifier).settingsLoaded;

    expect(container.read(settingsProvider).pscrRatio, 40.0);
    expect((await row('d2')).pscrRatio, 40.0);
  });

  test('with a diver the setters write the row, not the prefs', () async {
    final container = await containerWith({});

    await container.read(settingsProvider.notifier).setPscrRatio(25.0);
    await container
        .read(settingsProvider.notifier)
        .setProfileMetricsFollowViewport(true);

    expect((await row('d1')).pscrRatio, 25.0);
    expect((await row('d1')).profileMetricsFollowViewport, isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getDouble(SettingsKeys.pscrRatio), isNull);
    expect(prefs.getBool(SettingsKeys.profileMetricsFollowViewport), isNull);
  });

  test('with no diver the prefs remain the store', () async {
    final container = await containerWith(
      {SettingsKeys.pscrRatio: 40.0},
      diverId: null,
    );

    expect(container.read(settingsProvider).pscrRatio, 40.0);
    await container.read(settingsProvider.notifier).setPscrRatio(25.0);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getDouble(SettingsKeys.pscrRatio), 25.0);
  });
}
```

Before running, confirm the diver-switch API: `grep -n "setCurrentDiver\|class CurrentDiverIdNotifier" lib/features/divers/presentation/providers/diver_providers.dart` and use the method name found there (adjust the call in the "second diver" test if it differs). Also confirm `settingsLoaded` is the getter used in `settings_sync_reload_test.dart:109`.

- [ ] **Step 2: Flip the sync-reload assertion** in `settings_sync_reload_test.dart`. Replace the test `'a synced change keeps device-local preferences'` with:

```dart
  test('a synced change keeps device-local preferences', () async {
    await container
        .read(settingsProvider.notifier)
        .setO2CellUnit(O2CellUnit.millivolts);

    await applyPeerRow(diverA, (row) => row.copyWith(gfHigh: 70));
    await pumpEventQueue();

    expect(container.read(settingsProvider).gfHigh, 70);
    expect(container.read(settingsProvider).o2CellUnit, O2CellUnit.millivolts);
  });

  test('a synced pSCR ratio and viewport choice show on this device '
      '(issue #2948)', () async {
    await applyPeerRow(
      diverA,
      (row) => row.copyWith(
        pscrRatio: const Value(40.0),
        profileMetricsFollowViewport: const Value(true),
      ),
    );
    await pumpEventQueue();

    expect(container.read(settingsProvider).pscrRatio, 40.0);
    expect(container.read(settingsProvider).profileMetricsFollowViewport, true);
  });
```

Add `import 'package:submersion/core/constants/o2_cell_unit.dart';` to the imports.

- [ ] **Step 3: Run to verify failure**

Run: `flutter test test/features/settings/synced_device_prefs_adoption_test.dart test/features/settings/presentation/providers/settings_sync_reload_test.dart`
Expected: FAIL (columns stay null; prefs are still written with a diver; synced pSCR is overwritten by `_withDeviceLocalPrefs`).

- [ ] **Step 4: `_loadSettings`.** Replace the pSCR/viewport pref reads:

```dart
    // Since v262 the pSCR ratio and "metrics follow viewport" are per-diver
    // (synced, issue #2948). These prefs are the store while no diver
    // exists, and the value a diver row that has never held one adopts.
    final pscrRatioPref = prefs.getDouble(SettingsKeys.pscrRatio);
    final followViewportPref = prefs.getBool(
      SettingsKeys.profileMetricsFollowViewport,
    );
```

In the no-diver branch use `pscrRatio: pscrRatioPref ?? 100.0,` and `profileMetricsFollowViewport: followViewportPref ?? false,`.

In the diver branch, directly before `// Load settings from database`:

```dart
    // A row with no pSCR ratio or viewport choice yet (pre-v262, or a new
    // diver) adopts this device's pref, but only one that differs from the
    // default (a default-valued pref is no sign of a choice).
    const defaults = AppSettings();
    final unset = await _repository.unsetAdoptableColumns(diverId);
    final adoptPscrRatio =
        unset.pscrRatio && pscrRatioPref != defaults.pscrRatio
        ? pscrRatioPref
        : null;
    final adoptFollowViewport =
        unset.profileMetricsFollowViewport &&
            followViewportPref != defaults.profileMetricsFollowViewport
        ? followViewportPref
        : null;
```

Replace `final settings = await _repository.getOrCreateSettingsForDiver(diverId);` with:

```dart
    final created = await _repository.getOrCreateSettingsForDiver(diverId);
    // Not _saveSettings: its diff cannot see a change in a null column. The
    // write only fills still-null columns, so re-read whenever one was
    // attempted: a sync may have filled a column since [created] was read.
    final adopting = adoptPscrRatio != null || adoptFollowViewport != null;
    await _repository.adoptDeviceLocalValues(
      diverId,
      pscrRatio: adoptPscrRatio,
      profileMetricsFollowViewport: adoptFollowViewport,
    );
    final settings = adopting
        ? await _repository.getSettingsForDiver(diverId) ?? created
        : created;
```

In the `state = settings.copyWith(...)` call that follows, delete the `pscrRatio:` and `profileMetricsFollowViewport:` arguments.

- [ ] **Step 5: `_saveSettings`.** Delete the unconditional `prefs.setDouble(SettingsKeys.pscrRatio, ...)` and `prefs.setBool(SettingsKeys.profileMetricsFollowViewport, ...)` calls, and add them inside the existing `if (diverId == null) {` block, before the seascape write:

```dart
        // No diver yet: these prefs are the pSCR ratio's and viewport
        // choice's only store; a diver row adopts them on load (v262).
        await prefs.setDouble(SettingsKeys.pscrRatio, state.pscrRatio);
        await prefs.setBool(
          SettingsKeys.profileMetricsFollowViewport,
          state.profileMetricsFollowViewport,
        );
```

Update the comment above the remaining pref writes from "Device-local preferences are always persisted" to "Device-local preferences are always persisted to SharedPreferences, independent of whether a diver is currently selected." (unchanged wording is fine if it still holds).

- [ ] **Step 6: `_withDeviceLocalPrefs`.** Delete the `pscrRatio: state.pscrRatio,` and `profileMetricsFollowViewport: state.profileMetricsFollowViewport,` lines.

- [ ] **Step 7: Comments.** In `SettingsKeys`, replace the pSCR key comment context and the viewport comment:

```dart
  // pSCR ratio and profile "metrics follow viewport" (below): since v262
  // per-diver and synced (issue #2948). The prefs are only the store while
  // no diver exists, and the value a diver row with none adopts.
  static const String pscrRatio = 'pscr_ratio';
```

```dart
  // Whether profile-chart metric overlays follow the visible depth window
  // when zoomed. Per-diver since v262; see [pscrRatio].
  static const String profileMetricsFollowViewport =
      'profile_metrics_follow_viewport';
```

And the `AppSettings.pscrRatio` doc: replace "A device-local planning preference describing the diver's pSCR unit" with "A per-diver planning preference (synced since v262) describing the diver's pSCR unit". Update the load comment "pSCR ratio is a device-local planning preference ..." block, which Step 4 replaced.

- [ ] **Step 8: Run the tests**

Run: `flutter test test/features/settings test/features/planner test/features/dive_log/presentation/providers/profile_legend_provider_test.dart`
Expected: PASS. (If `profile_legend_provider_test.dart` does not exist, run `flutter test test/features/dive_log/presentation/providers`.)

- [ ] **Step 9: Commit**

```bash
git add lib/features/settings/presentation/providers/settings_providers.dart test/features/settings/synced_device_prefs_adoption_test.dart test/features/settings/presentation/providers/settings_sync_reload_test.dart
git commit -m "feat(settings): sync pSCR ratio and viewport following, adopting each device's value"
```

---

### Task 5: Sync payload coverage

**Files:**
- Modify: `lib/core/services/sync/sync_data_serializer.dart:9225-9230` (`_applyDiverSettingDefaults`)
- Create: `test/core/services/sync/sync_diver_settings_device_prefs_test.dart`

**Interfaces:**
- Consumes: Task 1 columns.

- [ ] **Step 1: Write the test**

```dart
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';

import '../../../helpers/test_database.dart';

/// The v262 columns (issue #2948) ride the generic diverSettings row, so
/// they reach other devices with no serializer change, and a payload from a
/// peer that predates them still applies.
void main() {
  late SyncDataSerializer serializer;
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    serializer = SyncDataSerializer();
    // A placeholder diver_id need not reference a real diver here.
    await db.customStatement('PRAGMA foreign_keys = OFF');
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<void> insertRow(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.diverSettings)
        .insert(
          DiverSettingsCompanion.insert(
            id: id,
            diverId: 'diver-1',
            createdAt: now,
            updatedAt: now,
            certificationListViewMode: const Value('table'),
            courseListViewMode: const Value('table'),
            profileMetricsFollowViewport: const Value(true),
            pscrRatio: const Value(40.0),
          ),
        );
  }

  Future<DiverSetting> readRow(String id) =>
      (db.select(db.diverSettings)..where((t) => t.id.equals(id))).getSingle();

  test('all four columns export and re-import unchanged', () async {
    await insertRow('ds-262');
    final exported = await serializer.fetchRecord('diverSettings', 'ds-262');
    expect(exported!['certificationListViewMode'], 'table');
    expect(exported['courseListViewMode'], 'table');
    expect(exported['profileMetricsFollowViewport'], true);
    expect(exported['pscrRatio'], 40.0);

    await (db.delete(
      db.diverSettings,
    )..where((t) => t.id.equals('ds-262'))).go();
    await serializer.upsertRecord('diverSettings', exported);

    final row = await readRow('ds-262');
    expect(row.certificationListViewMode, 'table');
    expect(row.courseListViewMode, 'table');
    expect(row.profileMetricsFollowViewport, isTrue);
    expect(row.pscrRatio, 40.0);
  });

  test('a pre-v262 payload without the columns still applies', () async {
    await insertRow('ds-260');
    final exported = await serializer.fetchRecord('diverSettings', 'ds-260');
    final legacy = Map<String, dynamic>.from(exported!)
      ..remove('certificationListViewMode')
      ..remove('courseListViewMode')
      ..remove('profileMetricsFollowViewport')
      ..remove('pscrRatio');
    await (db.delete(
      db.diverSettings,
    )..where((t) => t.id.equals('ds-260'))).go();

    await serializer.upsertRecord('diverSettings', legacy);

    final row = await readRow('ds-260');
    expect(row.certificationListViewMode, 'detailed');
    expect(row.courseListViewMode, 'detailed');
    expect(row.profileMetricsFollowViewport, isNull);
    expect(row.pscrRatio, isNull);
  });
}
```

- [ ] **Step 2: Run it**

Run: `flutter test test/core/services/sync/sync_diver_settings_device_prefs_test.dart`
Expected: PASS already (generic row export and `_withSchemaDefaults`). If the legacy test fails on the view modes, Step 3 is the fix; either way do Step 3 to follow the house convention.

- [ ] **Step 3: Seed the defaults** in `_applyDiverSettingDefaults`, after `'diveCenterListViewMode': 'detailed',`:

```dart
      // v262: seed them so payloads predating the columns hydrate.
      'certificationListViewMode': 'detailed',
      'courseListViewMode': 'detailed',
```

- [ ] **Step 4: Run the sync suite**

Run: `flutter test test/core/services/sync/sync_diver_settings_device_prefs_test.dart test/core/services/sync/sync_diver_settings_site_detail_test.dart test/core/services/sync/sync_diver_settings_fallback_test.dart test/core/services/sync/sync_schema_defaults_replay_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/services/sync/sync_data_serializer.dart test/core/services/sync/sync_diver_settings_device_prefs_test.dart
git commit -m "test(sync): cover the v262 diver_settings columns in sync payloads"
```

---

### Task 6: Docs and full verification

**Files:**
- Modify (only if PR #2968 has merged to main): `docs/guide/multi-device-sync.md` ("What Syncs Between Devices" section)
- Modify: `docs/developer/database.md` (only if it lists diver_settings columns or device-local prefs; check with `grep -n "pscr\|pSCR\|viewport\|ListViewMode" docs/developer/database.md`)

- [ ] **Step 1: Check #2968.** Run `gh pr view 2968 --json state -q .state`. If `MERGED`, merge main into this branch (`sync_with_base_branch` tool if available, else `git fetch origin && git merge origin/main`), run `flutter analyze`, then in the guide's "Stays on This Device" table remove "the pSCR ratio in the dive planner" (and "Profile metrics follow viewport" if listed), and add to the "synced with your diver profile" section: the pSCR ratio (dive planner), the profile "metrics follow viewport" choice, and the certification and course list view modes. If not merged, note in the PR description that the guide update follows whichever PR lands second.

- [ ] **Step 2: Full checks**

Run, in order:
- `dart format .`
- `flutter analyze` (no infos, no warnings)
- `flutter test test/architecture/`
- `flutter test test/core/database test/core/services/sync test/features/settings test/features/certifications test/features/courses test/features/planner test/features/dive_log/presentation/providers test/features/insights/presentation/pages/records_page_test.dart`

Expected: all PASS.

- [ ] **Step 3: Commit any docs and formatting changes**

```bash
git add docs
git commit -m "docs(sync): list the pSCR ratio, viewport and cert/course view modes as synced"
```
