# Distance Unit Setting Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give divers a Distance unit (km / mi) in Manage > Units, independent of the depth unit, plus the missing Altitude tile (issue #2030).

**Architecture:** A new `DistanceUnit` enum and `AppSettings.distanceUnit` field, persisted in a new `diver_settings.distance_unit` column (schema v263, backfilled from the depth unit as the column is added), synced with a depth-derived default for rows from older peers, and read by the single geographic distance formatter `UnitFormatter.formatGeoDistance`. UI adds Altitude and Distance tiles and pickers to Manage > Units, rows to the settings summary pane, and a Distance row to the setup wizard.

**Tech Stack:** Flutter, Riverpod (StateNotifier), Drift (SQLite), flutter_localizations ARB files.

**Spec:** `docs/design/specs/2026-10-05-distance-unit-setting-design.md`

## Global Constraints

- Schema version 263 (`currentSchemaVersion = 263`). Main shipped 261 (#2985); 262 is held by open PR #2991 and is not in this branch's ladder, so the ladder runs 260, 261, 263. (Written against v262 and renumbered when main was merged in; see the note under Task 2.)
- `minimumCompatibleSchemaVersion` stays 240: the column is additive.
- Column: `distance_unit TEXT NOT NULL DEFAULT 'kilometers'`; values are `DistanceUnit` names (`kilometers`, `miles`).
- Backfill: `miles` where `depth_unit = 'feet'`, only on the open that adds the column.
- Fresh `AppSettings()` and fresh databases default to `DistanceUnit.kilometers`.
- Metric preset requires and sets `kilometers`; imperial requires and sets `miles`.
- Short range: kilometres show metres under 1 km; miles show feet under one mile.
- `formatDistance` (surface drift) keeps the depth unit.
- New l10n keys go into all 11 ARB files (`ar de en es fr he hu it nl pt zh`); every ARB is feature-grouped, so insert next to a key of the same group.
- `before_open.dart` is at the 800-line cap: adding the backstop must not grow it.
- No em dashes anywhere; no tool attribution in commits.
- Imports grouped dart, flutter, packages, local. Run `dart format .` before every commit.
- Test commands run from the worktree root: `/Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/build-feature-2030-661a1e`.

## Review Focus

1. A diver who already chose feet for depth upgrades: their site distances must still read in miles (backfill), and the Units page must still say "Imperial" if everything else is imperial. Pinned in Task 2 (migration test) and Task 1 (preset test).
2. A diver who switched distance to km after the upgrade must keep km on every later open, including through the beforeOpen backstop. Pinned in Task 2 (reopen test).
3. A settings row arriving by sync from a pre-v263 peer, for a diver this device has never seen, with depth in feet: it must hydrate to miles, not the column default. Pinned in Task 3, for both `upsertRecord` and `upsertRecords`.
4. Mixed units: depth in metres with distance in miles (and the reverse) must format geo distances by the distance unit only. Pinned in Task 4.
5. A comma-decimal locale must still render "2,5 km" and "1,2 mi". Pinned in Task 4.

---

### Task 1: Domain: `DistanceUnit`, `AppSettings.distanceUnit`, presets, notifier

**Files:**
- Modify: `lib/core/constants/units.dart` (after `AltitudeUnit`, line ~105)
- Modify: `lib/features/settings/presentation/providers/settings_providers.dart` (field ~136, ctor ~571, `unitPreset` ~716-735, `copyWith` ~754 and ~903, `setAltitudeUnit` ~1705, `setMetric`/`setImperial` ~2568-2592, `altitudeUnitProvider` ~2671)
- Modify: `lib/features/setup_wizard/domain/setup_wizard_models.dart:84-110`
- Modify: `test/helpers/mock_providers.dart` (fake notifier ~108, `setMetric`/`setImperial` ~427-442)
- Modify: `test/features/insights/presentation/pages/records_page_test.dart:171` (fake notifier without `noSuchMethod`)
- Modify: `test/features/settings/presentation/pages/settings_page_test.dart` (fake notifier: add `setDistanceUnit` next to `setAltitudeUnit`)
- Test: `test/core/constants/units_test.dart`
- Test: `test/features/settings/presentation/providers/settings_providers_details_pane_test.dart:197-230`
- Test: `test/features/setup_wizard/domain/setup_wizard_models_test.dart:86-100`

**Interfaces:**
- Produces: `enum DistanceUnit { kilometers('km'), miles('mi') }` with `String symbol` and `double convert(double value, DistanceUnit to)`.
- Produces: `AppSettings.distanceUnit` (`DistanceUnit`, default `kilometers`), `copyWith({DistanceUnit? distanceUnit})`.
- Produces: `SettingsNotifier.setDistanceUnit(DistanceUnit unit) -> Future<void>`.
- Produces: `distanceUnitProvider` (`Provider<DistanceUnit>`).

- [ ] **Step 1: Write the failing tests**

Append to `test/core/constants/units_test.dart` inside `main()`:

```dart
  group('DistanceUnit', () {
    test('symbols are km and mi', () {
      expect(DistanceUnit.kilometers.symbol, 'km');
      expect(DistanceUnit.miles.symbol, 'mi');
    });

    test('converts kilometres to miles and back', () {
      expect(
        DistanceUnit.kilometers.convert(1.609344, DistanceUnit.miles),
        closeTo(1.0, 1e-9),
      );
      expect(
        DistanceUnit.miles.convert(10, DistanceUnit.kilometers),
        closeTo(16.09344, 1e-9),
      );
    });

    test('is identity for same-unit conversion', () {
      expect(DistanceUnit.miles.convert(3.5, DistanceUnit.miles), 3.5);
    });
  });
```

In `settings_providers_details_pane_test.dart`, group `AppSettings computed getters`: add `distanceUnit: DistanceUnit.miles,` to the `'unitPreset returns imperial when all units are imperial'` settings, then add after it:

```dart
    test('defaults distance to kilometres', () {
      expect(const AppSettings().distanceUnit, DistanceUnit.kilometers);
    });

    test('unitPreset is custom when only distance differs from metric', () {
      const settings = AppSettings(distanceUnit: DistanceUnit.miles);
      expect(settings.unitPreset, UnitPreset.custom);
    });

    test('unitPreset is custom when only distance differs from imperial', () {
      const settings = AppSettings(
        depthUnit: DepthUnit.feet,
        temperatureUnit: TemperatureUnit.fahrenheit,
        pressureUnit: PressureUnit.psi,
        volumeUnit: VolumeUnit.cubicFeet,
        weightUnit: WeightUnit.pounds,
        altitudeUnit: AltitudeUnit.feet,
      );
      expect(settings.unitPreset, UnitPreset.custom);
    });

    test('copyWith carries the distance unit', () {
      final updated = const AppSettings().copyWith(
        distanceUnit: DistanceUnit.miles,
      );
      expect(updated.distanceUnit, DistanceUnit.miles);
      expect(updated.depthUnit, DepthUnit.meters);
    });
```

In `setup_wizard_models_test.dart`, in `'applyUnitPreset imperial sets the six core units'` add after the altitude expectation:

```dart
      expect(imperial.settings.distanceUnit, DistanceUnit.miles);
```

and add a new test in the same group:

```dart
    test('applyUnitPreset metric sets distance back to kilometres', () {
      const draft = SetupWizardDraft(
        mode: SetupWizardMode.firstRun,
        settings: AppSettings(distanceUnit: DistanceUnit.miles),
      );
      final metric = draft.applyingUnitPreset(UnitPreset.metric);
      expect(metric.settings.distanceUnit, DistanceUnit.kilometers);
    });
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/core/constants/units_test.dart test/features/settings/presentation/providers/settings_providers_details_pane_test.dart test/features/setup_wizard/domain/setup_wizard_models_test.dart`
Expected: compile errors, `DistanceUnit` and `distanceUnit` undefined.

- [ ] **Step 3: Implement the enum**

In `lib/core/constants/units.dart`, after the `AltitudeUnit` enum:

```dart
/// Horizontal geographic distance: how far a site, a chamber or a tide
/// station is, and how long a surface track runs (issue #2030). Independent
/// of the depth unit, so a diver can log depth in feet and read distances in
/// kilometres.
enum DistanceUnit {
  kilometers('km'),
  miles('mi');

  final String symbol;
  const DistanceUnit(this.symbol);

  /// International mile, exact.
  static const double _kilometersPerMile = 1.609344;

  double convert(double value, DistanceUnit to) {
    if (this == to) return value;
    if (this == kilometers && to == miles) return value / _kilometersPerMile;
    if (this == miles && to == kilometers) return value * _kilometersPerMile;
    return value;
  }
}
```

- [ ] **Step 4: Implement the settings field, presets, notifier and provider**

In `settings_providers.dart`:

1. After `final AltitudeUnit altitudeUnit;` add:

```dart

  /// Unit for geographic distances (site distances, track length, tide
  /// station distance, chamber distance, geofence radius). Issue #2030.
  final DistanceUnit distanceUnit;
```

2. In the `AppSettings` constructor, after `this.altitudeUnit = AltitudeUnit.meters,` add `this.distanceUnit = DistanceUnit.kilometers,`.

3. In `unitPreset`, change the two lines `altitudeUnit == AltitudeUnit.meters;` and `altitudeUnit == AltitudeUnit.feet;` to:

```dart
        altitudeUnit == AltitudeUnit.meters &&
        distanceUnit == DistanceUnit.kilometers;
```

```dart
        altitudeUnit == AltitudeUnit.feet &&
        distanceUnit == DistanceUnit.miles;
```

4. In `copyWith`'s parameter list, after `AltitudeUnit? altitudeUnit,` add `DistanceUnit? distanceUnit,`; in its body, after `altitudeUnit: altitudeUnit ?? this.altitudeUnit,` add `distanceUnit: distanceUnit ?? this.distanceUnit,`.

5. After `setAltitudeUnit`:

```dart

  Future<void> setDistanceUnit(DistanceUnit unit) async {
    state = state.copyWith(distanceUnit: unit);
    await _saveSettings();
  }
```

6. In `setMetric()` after `altitudeUnit: AltitudeUnit.meters,` add `distanceUnit: DistanceUnit.kilometers,`; in `setImperial()` after `altitudeUnit: AltitudeUnit.feet,` add `distanceUnit: DistanceUnit.miles,`.

7. After `altitudeUnitProvider`:

```dart

final distanceUnitProvider = Provider<DistanceUnit>((ref) {
  return ref.watch(settingsProvider.select((s) => s.distanceUnit));
});
```

In `setup_wizard_models.dart`, `applyingUnitPreset`: after `altitudeUnit: AltitudeUnit.meters,` add `distanceUnit: DistanceUnit.kilometers,`; after `altitudeUnit: AltitudeUnit.feet,` add `distanceUnit: DistanceUnit.miles,`. Update the doc comment "the six core units" to "the seven core units", and rename the test `'applyUnitPreset imperial sets the six core units'` to `'... seven core units'`.

- [ ] **Step 5: Update the hand-written fake notifiers**

`test/helpers/mock_providers.dart`, after the `setAltitudeUnit` override:

```dart
  @override
  Future<void> setDistanceUnit(DistanceUnit unit) async =>
      state = state.copyWith(distanceUnit: unit);
```

and in its `setMetric`/`setImperial` overrides add `altitudeUnit: AltitudeUnit.meters, distanceUnit: DistanceUnit.kilometers,` and `altitudeUnit: AltitudeUnit.feet, distanceUnit: DistanceUnit.miles,` respectively, so the fake's presets match the real ones.

Add the same `setDistanceUnit` override after `setAltitudeUnit` in `test/features/insights/presentation/pages/records_page_test.dart` and in the fake notifier of `test/features/settings/presentation/pages/settings_page_test.dart`.

- [ ] **Step 6: Run the tests to verify they pass, then analyze**

Run: `flutter test test/core/constants/units_test.dart test/features/settings/presentation/providers/settings_providers_details_pane_test.dart test/features/setup_wizard/domain/setup_wizard_models_test.dart`
Expected: PASS.

Run: `flutter analyze 2>&1 | tail -5`
Expected: `No issues found!` (a missing override in another `implements SettingsNotifier` fake shows here as `non_abstract_class_inherits_abstract_member`; add `setDistanceUnit` there the same way).

- [ ] **Step 7: Commit**

```bash
dart format .
git add lib/core/constants/units.dart lib/features/settings/presentation/providers/settings_providers.dart lib/features/setup_wizard/domain/setup_wizard_models.dart test/core/constants/units_test.dart test/features/settings/presentation/providers/settings_providers_details_pane_test.dart test/features/setup_wizard/domain/setup_wizard_models_test.dart test/helpers/mock_providers.dart test/features/insights/presentation/pages/records_page_test.dart test/features/settings/presentation/pages/settings_page_test.dart
git commit -m "feat(settings): add a distance unit to the diver settings"
```

---

### Task 2: Persistence: column, v263 rung with backfill, repository, wizard apply

> Renumbered: this task was written and first built as v262 while main was at v260 and #2985 held 261. When main was merged in, #2985 had shipped 261 and PR #2991 had claimed 262, so the rung, the test file and every pin moved to 263. From main's v261 the upgrade is still one step.

**Files:**
- Modify: `lib/core/database/tables/diver_tables.dart:85`
- Modify: `lib/core/database/database.dart:235` (`currentSchemaVersion`) and `:1084` (`migrationVersions`)
- Modify: `lib/core/database/migrations/helpers/diver_migrations.dart` (top of the extension)
- Modify: `lib/core/database/migrations/ladder/rungs_v231_onward.dart` (after the v260 block)
- Modify: `lib/core/database/migrations/before_open.dart:29-30`
- Modify: `lib/features/settings/data/repositories/diver_settings_repository.dart:97, 353, 553, ~752`
- Modify: `lib/features/setup_wizard/data/setup_apply_service.dart:67`
- Modify: `test/core/database/migration_v261_drop_ceiling_source_test.dart` (relax the exact version pin)
- Create: `test/core/database/migration_v263_distance_unit_test.dart`
- Create: `test/features/settings/data/repositories/diver_settings_repository_distance_unit_test.dart`
- Modify: `test/features/setup_wizard/data/setup_apply_service_test.dart`

**Interfaces:**
- Consumes: `DistanceUnit`, `AppSettings.distanceUnit`, `SettingsNotifier.setDistanceUnit` (Task 1).
- Produces: Drift column getter `DiverSettings.distanceUnit` (wire key `distanceUnit`), SQL column `distance_unit`.
- Produces: `Future<void> _assertDistanceUnitColumn()` and `Future<void> _assertDiverSettingsDisplayColumns()` on `AppDatabase` (part-file extension, private).

- [ ] **Step 1: Write the failing migration test**

Create `test/core/database/migration_v263_distance_unit_test.dart`:

```dart
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:submersion/core/database/database.dart';

/// v263: diver_settings.distance_unit (issue #2030). Backfilled from each
/// diver's depth unit as the column is added, so nobody's site distances
/// change unit on upgrade; never rewritten afterwards.
void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('v263_'));
  tearDown(() => dir.deleteSync(recursive: true));

  File dbFile() => File(p.join(dir.path, 'v263.db'));

  /// A diver_settings table as it stood at v261: no distance_unit.
  NativeDatabase fixtureAt(int userVersion) => NativeDatabase(
    dbFile(),
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = $userVersion');
      rawDb.execute('''
        CREATE TABLE diver_settings (
          id TEXT NOT NULL PRIMARY KEY,
          depth_unit TEXT NOT NULL DEFAULT 'meters',
          created_at INTEGER,
          updated_at INTEGER
        )
      ''');
      rawDb.execute(
        "INSERT INTO diver_settings (id, depth_unit) VALUES "
        "('metric', 'meters'), ('imperial', 'feet')",
      );
    },
  );

  Future<Map<String, String>> distanceUnits(AppDatabase db) async {
    final rows = await db
        .customSelect('SELECT id, distance_unit FROM diver_settings')
        .get();
    return {
      for (final r in rows) r.read<String>('id'): r.read<String>('distance_unit'),
    };
  }

  test('v263 is the current schema version and is in the ladder', () {
    expect(AppDatabase.currentSchemaVersion, 263);
    expect(AppDatabase.migrationVersions, contains(263));
    expect(AppDatabase.migrationVersions.last, 263);
  });

  test('the column is additive and did not move the sync floor', () {
    expect(AppDatabase.minimumCompatibleSchemaVersion, 240);
  });

  test('a fresh database defaults the column to kilometers', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final cols = await db
        .customSelect("PRAGMA table_info('diver_settings')")
        .get();
    final column = cols.firstWhere(
      (c) => c.read<String>('name') == 'distance_unit',
    );
    expect(column.read<int>('notnull'), 1);
    expect(column.read<String?>('dflt_value'), contains('kilometers'));
  });

  test('upgrading from v261 backfills from the depth unit', () async {
    final db = AppDatabase(fixtureAt(261));
    addTearDown(db.close);
    expect(await distanceUnits(db), {
      'metric': 'kilometers',
      'imperial': 'miles',
    });
  });

  test('a database already at v263 without the column regains it, backfilled, '
      'via beforeOpen', () async {
    final db = AppDatabase(fixtureAt(263));
    addTearDown(db.close);
    expect(await distanceUnits(db), {
      'metric': 'kilometers',
      'imperial': 'miles',
    });
  });

  test('a later choice survives reopening (no second backfill)', () async {
    final first = AppDatabase(fixtureAt(261));
    await distanceUnits(first);
    await first.customStatement(
      "UPDATE diver_settings SET distance_unit = 'kilometers' "
      "WHERE id = 'imperial'",
    );
    await first.close();

    final second = AppDatabase(NativeDatabase(dbFile()));
    addTearDown(second.close);
    expect((await distanceUnits(second))['imperial'], 'kilometers');
  });
}
```

Relax the previous newest rung's exact pins, `test/core/database/migration_v261_drop_ceiling_source_test.dart` (the newest rung owns the exact pin; shown here with the v260 test's wording, the same edit applies):

```dart
  test('v260 is in the ladder', () {
    // Relaxed once v263 (distance unit) landed on top; the newest rung owns
    // the exact assertion.
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(260));
    expect(AppDatabase.migrationVersions, contains(260));
```

(Keep whatever lines followed the original `contains(260)` expectation.)

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/core/database/migration_v263_distance_unit_test.dart`
Expected: FAIL (`currentSchemaVersion` is 260; no `distance_unit` column).

- [ ] **Step 3: Implement the column, helper, rung and backstop**

`diver_tables.dart`, after the `altitudeUnit` line:

```dart

  /// v263: geographic distance unit, a DistanceUnit name (issue #2030).
  /// Backfilled from depth_unit as the column is added.
  TextColumn get distanceUnit =>
      text().withDefault(const Constant('kilometers'))();
```

`diver_migrations.dart`, at the top of `extension DiverMigrations on AppDatabase {`:

```dart
  /// v263: diver_settings.distance_unit (issue #2030). Not null, default
  /// 'kilometers'. As the column is added, a diver who logs depth in feet
  /// gets miles, so nobody's site distances change unit on upgrade. The
  /// backfill runs only on the open that adds the column, so a choice made
  /// afterwards is never rewritten, which makes this safe to call from both
  /// onUpgrade and the beforeOpen backstop.
  Future<void> _assertDistanceUnitColumn() async {
    final cols = await customSelect(
      "PRAGMA table_info('diver_settings')",
    ).get();
    if (cols.isEmpty) return; // partial fixture database: table absent
    final names = {for (final c in cols) c.read<String>('name')};
    if (names.contains('distance_unit')) return;
    await customStatement(
      'ALTER TABLE diver_settings ADD COLUMN distance_unit TEXT NOT NULL '
      "DEFAULT 'kilometers'",
    );
    if (!names.contains('depth_unit')) return;
    await customStatement(
      "UPDATE diver_settings SET distance_unit = 'miles' "
      "WHERE depth_unit = 'feet'",
    );
  }

  /// The beforeOpen backstop for diver_settings display columns: v263's
  /// distance unit and v237's dive figure switch. Grouped so the backstop
  /// list in before_open.dart does not grow past its size cap.
  Future<void> _assertDiverSettingsDisplayColumns() async {
    await _assertDistanceUnitColumn();
    await _assertShowDiveFigureColumn();
  }
```

`before_open.dart` lines 29-30, replace:

```dart
    // v237 backstop: the dive figure switch.
    await _assertShowDiveFigureColumn();
```

with:

```dart
    // v263 and v237 backstops: the distance unit and the dive figure switch.
    await _assertDiverSettingsDisplayColumns();
```

`rungs_v231_onward.dart`, after `if (from < 260) await reportProgress();`:

```dart
    // v263: diver_settings.distance_unit (issue #2030), backfilled from each
    // diver's depth unit as the column is added. Re-asserted in beforeOpen.
    // 262 is held by an open branch (#2991).
    if (from < 263) {
      await _assertDistanceUnitColumn();
    }
    if (from < 263) await reportProgress();
```

`database.dart`: `static const int currentSchemaVersion = 263;`, and in `migrationVersions` add `263,` after `261,`.

Regenerate Drift code:

Run: `dart run build_runner build --delete-conflicting-outputs 2>&1 | tail -3`
Expected: `Succeeded`.

- [ ] **Step 4: Run the migration tests to verify they pass**

Run: `flutter test test/core/database/migration_v263_distance_unit_test.dart test/core/database/migration_v260_tank_shared_computers_test.dart test/core/database/migration_v237_show_dive_figure_test.dart`
Expected: PASS.

- [ ] **Step 5: Write the failing repository and wizard-apply tests**

Create `test/features/settings/data/repositories/diver_settings_repository_distance_unit_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/settings/data/repositories/diver_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

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

  test('new settings default to kilometres', () async {
    await repository.createSettingsForDiver('d1');
    final loaded = await repository.getSettingsForDiver('d1');
    expect(loaded!.distanceUnit, DistanceUnit.kilometers);
  });

  test('createSettingsForDiver stores the given distance unit', () async {
    await repository.createSettingsForDiver(
      'd1',
      settings: const AppSettings(distanceUnit: DistanceUnit.miles),
    );
    final loaded = await repository.getSettingsForDiver('d1');
    expect(loaded!.distanceUnit, DistanceUnit.miles);
  });

  for (final unit in DistanceUnit.values) {
    test('round-trips ${unit.name}', () async {
      await repository.createSettingsForDiver('d1');
      await repository.updateSettingsForDiver(
        'd1',
        AppSettings(distanceUnit: unit),
      );
      final loaded = await repository.getSettingsForDiver('d1');
      expect(loaded!.distanceUnit, unit);
    });
  }

  test('an unrecognized stored value degrades to kilometres', () async {
    await repository.createSettingsForDiver('d1');
    await db.customStatement(
      "UPDATE diver_settings SET distance_unit = 'leagues' "
      "WHERE diver_id = 'd1'",
    );
    final loaded = await repository.getSettingsForDiver('d1');
    expect(loaded!.distanceUnit, DistanceUnit.kilometers);
  });
}
```

In `test/features/setup_wizard/data/setup_apply_service_test.dart`:
- in `'applyFirstRun creates default diver, seeds settings, sets current'`, after `expect(stored.weightUnit, WeightUnit.pounds);` add `expect(stored.distanceUnit, DistanceUnit.miles);`
- in `'applySettingsMode updates the current diver via existing setters'`, after `expect(stored.volumeUnit, VolumeUnit.cubicFeet);` add `expect(stored.distanceUnit, DistanceUnit.miles);`

- [ ] **Step 6: Run them to verify they fail**

Run: `flutter test test/features/settings/data/repositories/diver_settings_repository_distance_unit_test.dart test/features/setup_wizard/data/setup_apply_service_test.dart`
Expected: FAIL (the repository neither writes nor reads `distanceUnit`; `applySettingsMode` never sets it).

- [ ] **Step 7: Implement the repository and apply-service changes**

`diver_settings_repository.dart`:
- line ~97, after `altitudeUnit: Value(s.altitudeUnit.name),` add `distanceUnit: Value(s.distanceUnit.name),`
- line ~353, after `altitudeUnit: Value(settings.altitudeUnit.name),` add `distanceUnit: Value(settings.distanceUnit.name),`
- line ~553, after `altitudeUnit: _parseAltitudeUnit(row.altitudeUnit),` add `distanceUnit: _parseDistanceUnit(row.distanceUnit),`
- after `_parseAltitudeUnit`:

```dart

  DistanceUnit _parseDistanceUnit(String value) {
    return DistanceUnit.values.firstWhere(
      (e) => e.name == value,
      orElse: () => DistanceUnit.kilometers,
    );
  }
```

`setup_apply_service.dart`, after `await notifier.setAltitudeUnit(s.altitudeUnit);` add `await notifier.setDistanceUnit(s.distanceUnit);`.

- [ ] **Step 8: Run the tests to verify they pass**

Run: `flutter test test/features/settings/data/repositories/ test/features/setup_wizard/ test/core/database/`
Expected: PASS.

- [ ] **Step 9: Commit**

```bash
dart format .
git add lib/core/database/ lib/features/settings/data/repositories/diver_settings_repository.dart lib/features/setup_wizard/data/setup_apply_service.dart test/core/database/migration_v263_distance_unit_test.dart test/core/database/migration_v260_tank_shared_computers_test.dart test/features/settings/data/repositories/diver_settings_repository_distance_unit_test.dart test/features/setup_wizard/data/setup_apply_service_test.dart
git commit -m "feat(settings): persist the distance unit, backfilled from depth (v263)"
```

(`git add lib/core/database/` picks up the regenerated `database.g.dart`; check `git show --stat HEAD` lists it.)

---

### Task 3: Sync: derive a missing distance unit from the payload's depth unit

**Files:**
- Modify: `lib/core/services/sync/sync_data_serializer.dart` (`upsertRecord` ~4147-4154, `upsertRecords` ~4993-5003, new helper beside `_withSchemaDefaults` ~9091)
- Create: `test/core/services/sync/sync_diver_settings_distance_unit_test.dart`

**Interfaces:**
- Consumes: the `distanceUnit` column and wire key (Task 2).
- Produces: `static Map<String, dynamic> _withDerivedDistanceUnit(String entityType, Map<String, dynamic> data)` (private).

- [ ] **Step 1: Write the failing test**

Create `test/core/services/sync/sync_diver_settings_distance_unit_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';

import '../../../helpers/test_database.dart';

/// Issue #2030. A diver_settings row from a peer older than v263 carries no
/// distanceUnit. For a row new to this device the column default would make
/// a feet diver's distances kilometres; the unit is derived from the
/// payload's own depth unit instead.
void main() {
  late SyncDataSerializer serializer;
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    serializer = SyncDataSerializer();
    await db.customStatement('PRAGMA foreign_keys = OFF');
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  /// A wire payload for settings row [id] as a pre-v263 peer sends it.
  Future<Map<String, dynamic>> legacyPayload(
    String id, {
    required String depthUnit,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.diverSettings)
        .insert(
          DiverSettingsCompanion.insert(
            id: id,
            diverId: 'diver-$id',
            createdAt: now,
            updatedAt: now,
          ),
        );
    final exported = await serializer.fetchRecord('diverSettings', id);
    await (db.delete(db.diverSettings)..where((t) => t.id.equals(id))).go();
    return Map<String, dynamic>.from(exported!)
      ..remove('distanceUnit')
      ..['depthUnit'] = depthUnit;
  }

  Future<String> storedDistanceUnit(String id) async {
    final row = await (db.select(
      db.diverSettings,
    )..where((t) => t.id.equals(id))).getSingle();
    return row.distanceUnit;
  }

  test('a new feet row from an older peer hydrates to miles', () async {
    await serializer.upsertRecord(
      'diverSettings',
      await legacyPayload('ds1', depthUnit: 'feet'),
    );
    expect(await storedDistanceUnit('ds1'), 'miles');
  });

  test('a new metres row from an older peer hydrates to kilometers', () async {
    await serializer.upsertRecord(
      'diverSettings',
      await legacyPayload('ds1', depthUnit: 'meters'),
    );
    expect(await storedDistanceUnit('ds1'), 'kilometers');
  });

  test('the batch path derives it too', () async {
    await serializer.upsertRecords('diverSettings', [
      await legacyPayload('ds1', depthUnit: 'feet'),
      await legacyPayload('ds2', depthUnit: 'meters'),
    ]);
    expect(await storedDistanceUnit('ds1'), 'miles');
    expect(await storedDistanceUnit('ds2'), 'kilometers');
  });

  test('a payload that carries the unit keeps it', () async {
    final payload = await legacyPayload('ds1', depthUnit: 'feet');
    payload['distanceUnit'] = 'kilometers';
    await serializer.upsertRecord('diverSettings', payload);
    expect(await storedDistanceUnit('ds1'), 'kilometers');
  });

  test('a row this device holds keeps its own unit', () async {
    final payload = await legacyPayload('ds1', depthUnit: 'meters');
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.diverSettings)
        .insert(
          DiverSettingsCompanion.insert(
            id: 'ds1',
            diverId: 'diver-ds1',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db.customStatement(
      "UPDATE diver_settings SET distance_unit = 'miles' WHERE id = 'ds1'",
    );
    await serializer.upsertRecord('diverSettings', payload);
    expect(await storedDistanceUnit('ds1'), 'miles');
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/core/services/sync/sync_diver_settings_distance_unit_test.dart`
Expected: the two feet cases FAIL with `'kilometers'` (schema default); the others pass.

- [ ] **Step 3: Implement the derivation**

In `sync_data_serializer.dart`, directly above `Map<String, dynamic> _withSchemaDefaults(`:

```dart
  /// Issue #2030. A diver_settings row from a peer older than v263 carries
  /// no `distanceUnit`. [_withLocalForOmitted] already kept this device's
  /// value for a row it holds; for a row new here, derive the unit from the
  /// payload's own depth unit before [_withSchemaDefaults] fills the column
  /// default, so a feet diver's settings do not arrive in kilometres.
  static Map<String, dynamic> _withDerivedDistanceUnit(
    String entityType,
    Map<String, dynamic> data,
  ) {
    if (entityType != 'diverSettings' || data['distanceUnit'] != null) {
      return data;
    }
    return {
      ...data,
      'distanceUnit': data['depthUnit'] == 'feet' ? 'miles' : 'kilometers',
    };
  }

```

In `upsertRecord`, replace:

```dart
    data = _withSchemaDefaults(
      entityType,
      (await _withLocalForOmitted(entityType, [data])).single,
    );
```

with:

```dart
    data = _withSchemaDefaults(
      entityType,
      _withDerivedDistanceUnit(
        entityType,
        (await _withLocalForOmitted(entityType, [data])).single,
      ),
    );
```

In `upsertRecords`, replace:

```dart
    records = [
      for (final record in records) _withSchemaDefaults(entityType, record),
    ];
```

with:

```dart
    records = [
      for (final record in records)
        _withSchemaDefaults(
          entityType,
          _withDerivedDistanceUnit(entityType, record),
        ),
    ];
```

- [ ] **Step 4: Run the sync tests to verify they pass**

Run: `flutter test test/core/services/sync/sync_diver_settings_distance_unit_test.dart test/core/services/sync/sync_diver_settings_fallback_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format .
git add lib/core/services/sync/sync_data_serializer.dart test/core/services/sync/sync_diver_settings_distance_unit_test.dart
git commit -m "feat(sync): derive a missing distance unit from the synced depth unit"
```

---

### Task 4: Formatting: `formatGeoDistance` follows the distance unit

**Files:**
- Modify: `lib/core/utils/unit_formatter.dart:124-150` (and the `heightIsMetric` doc comment at ~401-403 that cites `formatGeoDistance`)
- Modify: `test/core/utils/unit_formatter_distance_test.dart`
- Modify: `test/core/utils/unit_formatter_locale_test.dart` (~line 124)
- Modify: `test/features/gps_log/track_display_formatting_test.dart:56-72`
- Check: `test/features/tides/presentation/widgets/tide_source_badge_test.dart`, `test/features/gps_log/track_stats_header_test.dart`, `test/features/gps_log/gps_track_detail_colorization_test.dart`, `test/features/safety/presentation/widgets/chamber_tile_test.dart`, `test/features/nav_track/presentation/pages/nav_track_detail_page_test.dart`, `test/features/dive_log/presentation/widgets/pickers/site_picker_sheet_test.dart`, `test/features/dive_log/presentation/widgets/pickers/pick_or_create_site_test.dart`, `test/features/media/presentation/widgets/site_picker_sheet_test.dart`

**Interfaces:**
- Consumes: `AppSettings.distanceUnit`, `DistanceUnit` (Task 1).
- Produces: unchanged signature `String formatGeoDistance(double meters)`.

- [ ] **Step 1: Write the failing tests**

Replace the `group('formatGeoDistance', ...)` in `test/core/utils/unit_formatter_distance_test.dart` with:

```dart
  group('formatGeoDistance', () {
    const km = UnitFormatter(AppSettings());
    const mi = UnitFormatter(AppSettings(distanceUnit: DistanceUnit.miles));

    test('kilometres scale metres to km', () {
      expect(km.formatGeoDistance(120), '120 m');
      expect(km.formatGeoDistance(999), '999 m');
      expect(km.formatGeoDistance(1000), '1.0 km');
      expect(km.formatGeoDistance(5560), '5.6 km');
      expect(km.formatGeoDistance(23400), '23 km');
    });

    test('miles scale feet to miles', () {
      expect(mi.formatGeoDistance(120), '394 ft');
      expect(mi.formatGeoDistance(1000), '3281 ft');
      expect(mi.formatGeoDistance(3218.688), '2.0 mi');
      expect(mi.formatGeoDistance(160934), '100 mi');
    });

    // Issue #2030: the distance unit, not the depth unit, decides.
    test('feet for depth with kilometres for distance reads km', () {
      const f = UnitFormatter(
        AppSettings(
          depthUnit: DepthUnit.feet,
          distanceUnit: DistanceUnit.kilometers,
        ),
      );
      expect(f.formatGeoDistance(420), '420 m');
      expect(f.formatGeoDistance(5560), '5.6 km');
    });

    test('metres for depth with miles for distance reads mi', () {
      const f = UnitFormatter(
        AppSettings(
          depthUnit: DepthUnit.meters,
          distanceUnit: DistanceUnit.miles,
        ),
      );
      expect(f.formatGeoDistance(120), '394 ft');
      expect(f.formatGeoDistance(3218.688), '2.0 mi');
    });

    test('surface drift keeps the depth unit', () {
      const f = UnitFormatter(
        AppSettings(
          depthUnit: DepthUnit.meters,
          distanceUnit: DistanceUnit.miles,
        ),
      );
      expect(f.formatDistance(120), '120m');
    });
  });
```

In `test/core/utils/unit_formatter_locale_test.dart`, after the `'geo distance uses the locale decimal separator'` expectation `expect(metric.formatGeoDistance(2500), '2,5 km');` add:

```dart
      expect(
        const UnitFormatter(
          AppSettings(distanceUnit: DistanceUnit.miles),
        ).formatGeoDistance(1931.2128),
        '1,2 mi',
      );
```

(Add `import 'package:submersion/core/constants/units.dart';` if the file lacks it.)

In `test/features/gps_log/track_display_formatting_test.dart`, change the group's helper and the miles test:

```dart
    UnitFormatter formatter(DistanceUnit unit) =>
        UnitFormatter(AppSettings(distanceUnit: unit));
```

with `formatter(DistanceUnit.kilometers)` in the two km tests and:

```dart
    test('a diver who reads miles gets miles', () {
      expect(formatter(DistanceUnit.miles).formatGeoDistance(74000), '46 mi');
    });
```

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/core/utils/unit_formatter_distance_test.dart test/core/utils/unit_formatter_locale_test.dart test/features/gps_log/track_display_formatting_test.dart`
Expected: the mixed-unit tests and the miles tests FAIL (the formatter still keys off depth).

- [ ] **Step 3: Implement**

In `unit_formatter.dart`, replace the `formatGeoDistance` doc comment and body:

```dart
  /// Format a geographic distance (meters) for site lists and pickers.
  ///
  /// Unlike [formatDistance] (depth-unit m/ft, for short surface drift), this
  /// auto-scales across the full range of site distances in the diver's
  /// distance unit (issue #2030): kilometres -> m under 1 km else km; miles ->
  /// ft under 1 mile else mi. Unit symbols are latin (m/km/ft/mi),
  /// consistent with [formatDepth].
  String formatGeoDistance(double meters) {
    if (settings.distanceUnit == DistanceUnit.kilometers) {
      if (meters < 1000) return '${meters.round()} m';
      final km = meters / 1000;
      final text = km < 10
          ? formatFixedForDisplay(km, 1)
          : km.round().toString();
      return '$text km';
    }
    final feet = meters * 3.28084;
    const feetPerMile = 5280.0;
    if (feet < feetPerMile) return '${feet.round()} ft';
    final miles = feet / feetPerMile;
    final text = miles < 10
        ? formatFixedForDisplay(miles, 1)
        : miles.round().toString();
    return '$text mi';
  }
```

In the `heightIsMetric` doc comment, change "derived from the depth unit, consistent with [formatGeoDistance]." to "derived from the depth unit, like [formatDistance]." (height no longer shares a rule with geo distance).

- [ ] **Step 4: Run the formatter tests and every consumer test**

Run: `flutter test test/core/utils/ test/features/gps_log/ test/features/tides/presentation/widgets/tide_source_badge_test.dart test/features/safety/presentation/widgets/chamber_tile_test.dart test/features/nav_track/presentation/pages/nav_track_detail_page_test.dart test/features/dive_log/presentation/widgets/pickers/ test/features/media/presentation/widgets/site_picker_sheet_test.dart test/features/equipment/`
Expected: PASS. Any failure that expects `mi` / `ft` from a fixture built with only `depthUnit: DepthUnit.feet` is the old coupling: add `distanceUnit: DistanceUnit.miles` to that fixture's `AppSettings` (that fixture models an imperial diver, who now carries miles explicitly). Do not change an expected string.

- [ ] **Step 5: Commit**

```bash
dart format .
git add lib/core/utils/unit_formatter.dart test/
git commit -m "feat(settings): format geographic distances in the diver's distance unit"
```

(Check `git status` first; stage only this task's test files if anything else is dirty.)

---

### Task 5: Localization strings

**Files:**
- Modify: `lib/l10n/arb/app_{ar,de,en,es,fr,he,hu,it,nl,pt,zh}.arb`
- Regenerate: `lib/l10n/arb/app_localizations*.dart`
- Create (scratchpad, not committed): `insert_distance_keys.py`

**Interfaces:**
- Produces getters on `AppLocalizations`: `settings_units_altitude`, `settings_units_altitude_meters`, `settings_units_altitude_feet`, `settings_units_dialog_altitudeUnit`, `settings_units_distance`, `settings_units_distance_kilometers`, `settings_units_distance_miles`, `settings_units_dialog_distanceUnit`, `settings_summary_altitude`, `settings_summary_distance`, `setup_units_distance`.

- [ ] **Step 1: Write the insertion script**

Save as `<scratchpad>/insert_distance_keys.py` (ARBs are feature-grouped, so each group of keys goes after a neighbouring key of its own group):

```python
import json
import pathlib
import sys

ARB_DIR = pathlib.Path("lib/l10n/arb")

# (anchor key, [new keys in order])
GROUPS = [
    ("settings_units_weight_pounds", [
        "settings_units_altitude",
        "settings_units_altitude_feet",
        "settings_units_altitude_meters",
        "settings_units_dialog_altitudeUnit",
        "settings_units_distance",
        "settings_units_distance_kilometers",
        "settings_units_distance_miles",
        "settings_units_dialog_distanceUnit",
    ]),
    ("settings_summary_weight", [
        "settings_summary_altitude",
        "settings_summary_distance",
    ]),
    ("setup_units_altitude", ["setup_units_distance"]),
]

T = {
    "en": ["Altitude", "Feet (ft)", "Meters (m)", "Altitude Unit", "Distance",
           "Kilometers (km)", "Miles (mi)", "Distance Unit",
           "Altitude", "Distance", "Distance"],
    "ar": ["الارتفاع", "أقدام (ft)", "أمتار (m)", "وحدة الارتفاع", "المسافة",
           "كيلومترات (km)", "أميال (mi)", "وحدة المسافة",
           "الارتفاع", "المسافة", "المسافة"],
    "de": ["Höhe", "Fuß (ft)", "Meter (m)", "Höheneinheit", "Entfernung",
           "Kilometer (km)", "Meilen (mi)", "Entfernungseinheit",
           "Höhe", "Entfernung", "Entfernung"],
    "es": ["Altitud", "Pies (ft)", "Metros (m)", "Unidad de altitud", "Distancia",
           "Kilómetros (km)", "Millas (mi)", "Unidad de distancia",
           "Altitud", "Distancia", "Distancia"],
    "fr": ["Altitude", "Pieds (ft)", "Mètres (m)", "Unité d'altitude", "Distance",
           "Kilomètres (km)", "Miles (mi)", "Unité de distance",
           "Altitude", "Distance", "Distance"],
    "he": ["גובה", "רגל (ft)", "מטרים (m)", "יחידת גובה", "מרחק",
           "קילומטרים (km)", "מיילים (mi)", "יחידת מרחק",
           "גובה", "מרחק", "מרחק"],
    "hu": ["Magasság", "Láb (ft)", "Méter (m)", "Magasság egység", "Távolság",
           "Kilométer (km)", "Mérföld (mi)", "Távolság egység",
           "Magasság", "Távolság", "Távolság"],
    "it": ["Altitudine", "Piedi (ft)", "Metri (m)", "Unità di altitudine", "Distanza",
           "Chilometri (km)", "Miglia (mi)", "Unità di distanza",
           "Altitudine", "Distanza", "Distanza"],
    "nl": ["Hoogte", "Voet (ft)", "Meters (m)", "Hoogte-eenheid", "Afstand",
           "Kilometers (km)", "Mijlen (mi)", "Afstandseenheid",
           "Hoogte", "Afstand", "Afstand"],
    "pt": ["Altitude", "Pés (ft)", "Metros (m)", "Unidade de Altitude", "Distância",
           "Quilômetros (km)", "Milhas (mi)", "Unidade de Distância",
           "Altitude", "Distância", "Distância"],
    "zh": ["海拔", "英尺 (ft)", "米 (m)", "海拔单位", "距离",
           "千米 (km)", "英里 (mi)", "距离单位",
           "海拔", "距离", "距离"],
}

ORDER = [k for _, keys in GROUPS for k in keys]

for locale, values in T.items():
    path = ARB_DIR / f"app_{locale}.arb"
    text = path.read_text(encoding="utf-8")
    newline = "\r\n" if "\r\n" in text else "\n"
    lines = text.split(newline)
    value_of = dict(zip(ORDER, values))
    for anchor, keys in GROUPS:
        idx = next(i for i, l in enumerate(lines) if l.strip().startswith(f'"{anchor}":'))
        indent = lines[idx][: len(lines[idx]) - len(lines[idx].lstrip())]
        had_comma = lines[idx].rstrip().endswith(",")
        if not had_comma:
            lines[idx] = lines[idx].rstrip() + ","
        new = [f"{indent}{json.dumps(k)}: {json.dumps(value_of[k], ensure_ascii=False)},"
               for k in keys]
        if not had_comma:
            new[-1] = new[-1][:-1]
        lines[idx + 1:idx + 1] = new
    out = newline.join(lines)
    data = json.loads(out)
    missing = [k for k in ORDER if k not in data]
    if missing:
        sys.exit(f"{locale}: missing {missing}")
    path.write_text(out, encoding="utf-8")
    print(f"OK {locale}")
```

- [ ] **Step 2: Run it and regenerate**

Run: `python3.14 <scratchpad>/insert_distance_keys.py`
Expected: `OK` for all 11 locales.

Run: `flutter gen-l10n 2>&1 | tail -3`
Expected: no errors and no "untranslated messages" for the new keys.

Run: `git diff --numstat lib/l10n/arb/*.arb`
Expected: each ARB shows 11 added lines and 0 removed (a large removed count means line endings were rewritten; stop and fix).

- [ ] **Step 3: Commit**

```bash
git add lib/l10n/arb/
git commit -m "feat(settings): add altitude and distance unit strings"
```

---

### Task 6: UI: Manage > Units tiles and pickers, summary pane, setup wizard row

**Files:**
- Create: `lib/features/settings/presentation/widgets/altitude_distance_unit_pickers.dart`
- Modify: `lib/features/settings/presentation/pages/settings_page.dart` (after the Weight tile, ~line 523; imports)
- Modify: `lib/features/settings/presentation/widgets/settings_summary_widget.dart` (after the weight row, ~line 146)
- Modify: `lib/features/setup_wizard/presentation/widgets/steps/units_step.dart` (after the altitude row, ~line 152)
- Create: `test/features/settings/presentation/pages/altitude_distance_unit_picker_test.dart`
- Create: `test/features/settings/presentation/widgets/settings_summary_widget_test.dart`
- Modify: `test/features/setup_wizard/presentation/widgets/steps/units_step_test.dart:147-158`

**Interfaces:**
- Consumes: `setAltitudeUnit` (existing), `setDistanceUnit`, `AppSettings.distanceUnit` (Task 1); l10n getters (Task 5).
- Produces: `void showAltitudeUnitPicker(BuildContext, WidgetRef, AltitudeUnit)`, `void showDistanceUnitPicker(BuildContext, WidgetRef, DistanceUnit)`, `String altitudeUnitLabel(AppLocalizations, AltitudeUnit)`, `String distanceUnitLabel(AppLocalizations, DistanceUnit)`.

- [ ] **Step 1: Write the failing widget tests**

Create `test/features/settings/presentation/pages/altitude_distance_unit_picker_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/pages/settings_page.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Records what the pickers ask the notifier to persist, without touching
/// the database. Everything else falls through to noSuchMethod.
class _RecordingSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _RecordingSettingsNotifier(super.settings);

  final List<Object> saved = [];

  @override
  Future<void> setAltitudeUnit(AltitudeUnit unit) async {
    saved.add(unit);
    state = state.copyWith(altitudeUnit: unit);
  }

  @override
  Future<void> setDistanceUnit(DistanceUnit unit) async {
    saved.add(unit);
    state = state.copyWith(distanceUnit: unit);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _RecordingSettingsNotifier notifier;

  Widget host(AppSettings settings) {
    notifier = _RecordingSettingsNotifier(settings);
    return ProviderScope(
      overrides: [settingsProvider.overrideWith((ref) => notifier)],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SettingsSectionDetailPage(sectionId: 'units'),
      ),
    );
  }

  Future<void> openTile(WidgetTester tester, String title) async {
    await tester.scrollUntilVisible(find.text(title), 50.0);
    await tester.pumpAndSettle();
    await tester.tap(find.text(title));
    await tester.pumpAndSettle();
  }

  group('distance unit (issue #2030)', () {
    testWidgets('the tile shows the active unit', (tester) async {
      await tester.pumpWidget(
        host(const AppSettings(distanceUnit: DistanceUnit.miles)),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Distance'), 50.0);
      await tester.pumpAndSettle();
      expect(find.text('mi'), findsOneWidget);
    });

    testWidgets('choosing miles persists it and closes the dialog', (
      tester,
    ) async {
      await tester.pumpWidget(host(const AppSettings()));
      await tester.pumpAndSettle();
      await openTile(tester, 'Distance');

      expect(find.text('Distance Unit'), findsOneWidget);
      expect(find.text('Kilometers (km)'), findsOneWidget);
      await tester.tap(find.text('Miles (mi)'));
      await tester.pumpAndSettle();

      expect(notifier.saved, [DistanceUnit.miles]);
      expect(find.byType(AlertDialog), findsNothing);
    });
  });

  group('altitude unit', () {
    testWidgets('the tile shows the active unit', (tester) async {
      await tester.pumpWidget(
        host(const AppSettings(altitudeUnit: AltitudeUnit.feet)),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Altitude'), 50.0);
      await tester.pumpAndSettle();
      // Depth stays metres, so the only "ft" on the page is altitude's.
      expect(find.text('ft'), findsOneWidget);
    });

    testWidgets('choosing feet persists it and closes the dialog', (
      tester,
    ) async {
      await tester.pumpWidget(host(const AppSettings()));
      await tester.pumpAndSettle();
      await openTile(tester, 'Altitude');

      expect(find.text('Altitude Unit'), findsOneWidget);
      await tester.tap(find.text('Feet (ft)'));
      await tester.pumpAndSettle();

      expect(notifier.saved, [AltitudeUnit.feet]);
      expect(find.byType(AlertDialog), findsNothing);
    });
  });
}
```

Create `test/features/settings/presentation/widgets/settings_summary_widget_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/settings_summary_widget.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

void main() {
  testWidgets('the summary lists the altitude and distance units', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(
            (ref) => MockSettingsNotifier(
              const AppSettings(
                altitudeUnit: AltitudeUnit.feet,
                distanceUnit: DistanceUnit.miles,
              ),
            ),
          ),
          currentDiverProvider.overrideWith((ref) async => null),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: SettingsSummaryWidget()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Altitude'), findsOneWidget);
    expect(find.text('Distance'), findsOneWidget);
    expect(find.text('mi'), findsOneWidget);
  });
}
```

In `units_step_test.dart`, `'each per-unit control writes to the draft'`: after `await tapUnit('setup-unit-altitude-ft');` add `await tapUnit('setup-unit-distance-mi');`, and after `expect(s.altitudeUnit, AltitudeUnit.feet);` add `expect(s.distanceUnit, DistanceUnit.miles);`.

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/features/settings/presentation/pages/altitude_distance_unit_picker_test.dart test/features/settings/presentation/widgets/settings_summary_widget_test.dart test/features/setup_wizard/presentation/widgets/steps/units_step_test.dart`
Expected: FAIL (no Altitude / Distance tiles, rows or wizard key).

- [ ] **Step 3: Create the picker file**

`lib/features/settings/presentation/widgets/altitude_distance_unit_pickers.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The altitude and distance unit pickers on Manage > Units (issue #2030),
/// split out of `settings_page.dart` so that file stops growing.

/// The localized name of an altitude unit.
String altitudeUnitLabel(AppLocalizations l10n, AltitudeUnit unit) =>
    switch (unit) {
      AltitudeUnit.meters => l10n.settings_units_altitude_meters,
      AltitudeUnit.feet => l10n.settings_units_altitude_feet,
    };

/// The localized name of a distance unit.
String distanceUnitLabel(AppLocalizations l10n, DistanceUnit unit) =>
    switch (unit) {
      DistanceUnit.kilometers => l10n.settings_units_distance_kilometers,
      DistanceUnit.miles => l10n.settings_units_distance_miles,
    };

/// Opens the altitude unit picker.
void showAltitudeUnitPicker(
  BuildContext context,
  WidgetRef ref,
  AltitudeUnit current,
) {
  final l10n = AppLocalizations.of(context);
  _showUnitPicker<AltitudeUnit>(
    context,
    title: l10n.settings_units_dialog_altitudeUnit,
    values: AltitudeUnit.values,
    selected: current,
    label: (unit) => altitudeUnitLabel(l10n, unit),
    onSelected: (unit) =>
        ref.read(settingsProvider.notifier).setAltitudeUnit(unit),
  );
}

/// Opens the distance unit picker.
void showDistanceUnitPicker(
  BuildContext context,
  WidgetRef ref,
  DistanceUnit current,
) {
  final l10n = AppLocalizations.of(context);
  _showUnitPicker<DistanceUnit>(
    context,
    title: l10n.settings_units_dialog_distanceUnit,
    values: DistanceUnit.values,
    selected: current,
    label: (unit) => distanceUnitLabel(l10n, unit),
    onSelected: (unit) =>
        ref.read(settingsProvider.notifier).setDistanceUnit(unit),
  );
}

/// The single-choice dialog every unit picker on the page uses: one row per
/// unit, a check on the selected one, and a tap that saves and closes.
void _showUnitPicker<T>(
  BuildContext context, {
  required String title,
  required List<T> values,
  required T selected,
  required String Function(T) label,
  required void Function(T) onSelected,
}) {
  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final value in values)
            ListTile(
              title: Text(label(value)),
              trailing: value == selected
                  ? Icon(
                      Icons.check,
                      color: Theme.of(dialogContext).colorScheme.primary,
                    )
                  : null,
              onTap: () {
                onSelected(value);
                Navigator.of(dialogContext).pop();
              },
            ),
        ],
      ),
    ),
  );
}
```

- [ ] **Step 4: Add the tiles, summary rows and wizard row**

`settings_page.dart`: add `import 'package:submersion/features/settings/presentation/widgets/altitude_distance_unit_pickers.dart';` beside the other `settings/presentation/widgets/` imports. After the Weight tile (the `_buildUnitTile` whose title is `context.l10n.settings_units_weight`, closing `),`) insert:

```dart
                const Divider(height: 1),
                _buildUnitTile(
                  context,
                  title: context.l10n.settings_units_altitude,
                  value: settings.altitudeUnit.symbol,
                  onTap: () =>
                      showAltitudeUnitPicker(context, ref, settings.altitudeUnit),
                ),
                const Divider(height: 1),
                _buildUnitTile(
                  context,
                  title: context.l10n.settings_units_distance,
                  value: settings.distanceUnit.symbol,
                  onTap: () =>
                      showDistanceUnitPicker(context, ref, settings.distanceUnit),
                ),
```

`settings_summary_widget.dart`, after the weight `_buildUnitRow(...)`:

```dart
                  _buildUnitRow(
                    context,
                    context.l10n.settings_summary_altitude,
                    settings.altitudeUnit.symbol,
                  ),
                  _buildUnitRow(
                    context,
                    context.l10n.settings_summary_distance,
                    settings.distanceUnit.symbol,
                  ),
```

`units_step.dart`, after the `_unitRow<AltitudeUnit>(...)` row:

```dart
              _unitRow<DistanceUnit>(
                label: l10n.setup_units_distance,
                keyPrefix: 'setup-unit-distance',
                values: DistanceUnit.values,
                selected: s.distanceUnit,
                symbol: (u) => u.symbol,
                onChanged: (u) =>
                    notifier.updateSettings(s.copyWith(distanceUnit: u)),
              ),
```

- [ ] **Step 5: Run the widget tests to verify they pass**

Run: `flutter test test/features/settings/presentation/ test/features/setup_wizard/`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
dart format .
git add lib/features/settings/presentation/ lib/features/setup_wizard/presentation/widgets/steps/units_step.dart test/features/settings/presentation/pages/altitude_distance_unit_picker_test.dart test/features/settings/presentation/widgets/settings_summary_widget_test.dart test/features/setup_wizard/presentation/widgets/steps/units_step_test.dart
git commit -m "feat(settings): add altitude and distance tiles to Manage > Units"
```

---

### Task 7: Whole-branch verification

**Files:** none new.

- [ ] **Step 1: Format and analyze the whole project**

Run: `dart format . && flutter analyze 2>&1 | tail -3`
Expected: `No issues found!` and `git status --porcelain` shows no format changes left over.

- [ ] **Step 2: Architecture guards (new files under `lib/`)**

Run: `flutter test test/architecture/`
Expected: PASS.

- [ ] **Step 3: Generated-l10n staleness**

Run: `flutter gen-l10n && git status --porcelain lib/l10n`
Expected: empty output.

- [ ] **Step 4: Affected test directories**

Run: `flutter test test/core/ test/features/settings/ test/features/setup_wizard/ test/features/gps_log/ test/features/tides/ test/features/safety/ test/features/equipment/ test/features/dive_log/presentation/widgets/pickers/ test/features/insights/presentation/pages/records_page_test.dart test/l10n/`
Expected: PASS. A failure in a test that builds a full-imperial `AppSettings` and expects `UnitPreset.imperial` / `isMetric == false` gets `distanceUnit: DistanceUnit.miles` added to its fixture (the old fixture is no longer full imperial). Commit such fixture updates as `test(settings): carry the distance unit in imperial fixtures`.

- [ ] **Step 5: After screenshots**

Capture Manage > Units (light, dark; phone and desktop widths), the Distance picker dialog, the settings summary pane, the setup wizard's fine-tune units, and the site picker showing km for a feet-depth diver. See the build-feature Screenshots section for naming.
