# Custom Certification Agencies and Levels Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add ACUC and DAN as built-in agencies, and let divers create their own certification agencies and levels (shareable between profiles), resolved everywhere through one catalog.

**Architecture:** Built-in agencies and levels stay code constants (`CertificationAgency`, `CertificationLevel`, `CertificationLevelCatalog`). Two new HLC-synced tables hold only custom entries. Domain fields that held enums become `String` ids (the DB columns already store enum names as text, so no data migration). An immutable `CertificationCatalog` merges built-ins with custom rows and resolves any id, falling back to a placeholder entry instead of collapsing unknown values to "Other".

**Tech Stack:** Flutter, Drift (SQLite), Riverpod, flutter_test, ARB l10n (11 locales).

**Spec:** `docs/design/specs/2026-10-05-custom-certification-agencies-design.md`

## Global Constraints

- Schema version: `currentSchemaVersion` goes from 260 to **261**. Tables go in `lib/core/database/tables/buddy_tables.dart`; the rung goes in `lib/core/database/migrations/ladder/rungs_v231_onward.dart`; the helper in `lib/core/database/migrations/helpers/`. Never add a table or rung to `database.dart` itself (only the registration list, `currentSchemaVersion` and `migrationVersions`).
- `minCompatibleSchemaVersion` (the sync floor) is NOT raised: new tables and synced entities never raise it.
- Built-in ids are the enum `.name` strings. Custom ids are UUID v4.
- Agency names (built-in brands and user text) are never translated. ACUC and DAN level names fall back to `displayName` in every locale.
- No em-dashes or en-dashes as prose punctuation anywhere (code, comments, ARB values, commits). No emojis.
- No AI-tool attribution in any commit, comment or PR text (see the Attribution section of the project instructions).
- Imports grouped dart, flutter, packages, local. Files 200-400 lines typical, 800 max.
- All domain entities get `copyWith`.
- Paths in tests are built with `p.join`, temp space via `Directory.systemTemp`.
- A test that replaces process-wide state restores it in `addTearDown`.
- Units: nothing here displays units.
- After every task: `dart format .`, `flutter analyze` (zero issues, infos included), the task's tests. After any task adding files under `lib/`: `flutter test test/architecture/`.
- Never run `git add -A` or `git add .`; stage explicit paths.
- Commit after each task with the message given in the task.

## Review Focus

1. A certification whose stored agency is a custom id from a not-yet-synced or deleted row must open, display "Unknown agency", and save without changing the stored id (Task 6 test "unknown stored ids survive load and save").
2. Another profile's shared custom agency on a certification must still resolve by name even when it is not visible in the viewer's pickers (Task 4 test "resolves an invisible custom agency by name").
3. Two divers on one device: diver B must not be able to rename or delete diver A's shared agency through the repository, even if UI is bypassed (Task 3 test "refuses writes from a non-owner").
4. An agency's progression order must survive a reorder and a sync round-trip, and `primaryCertification` must rank a custom rung above every built-in rung of the same agency (Task 4 test "custom rung outranks built-ins"; Task 5 sync test).
5. Re-importing the same UDDF file twice must not create two custom agencies with the same name (Task 10 test "second import reuses the custom agency").

---

## File Structure

New feature folder `lib/features/certification_agencies/`:

| File | Responsibility |
| --- | --- |
| `domain/entities/custom_certification_agency.dart` | `CustomCertificationAgency` entity |
| `domain/entities/custom_certification_level.dart` | `CustomCertificationLevel` entity |
| `domain/entities/certification_usage.dart` | `CertificationUsage` value (reference counts) |
| `domain/certification_catalog.dart` | `CertificationCatalog`, `AgencyEntry`, `LevelEntry`, fallback, ranking |
| `domain/agency_colors.dart` | `defaultAgencyColorArgb(id)`, `secondaryAgencyColor(primary)` |
| `data/repositories/custom_certification_repository.dart` | CRUD, visibility, uniqueness, usage, delete refusal, reorder, share |
| `presentation/certification_entry_display.dart` | `localizedName(l10n)` on `AgencyEntry` / `LevelEntry` |
| `presentation/providers/certification_catalog_providers.dart` | repository provider, `certificationCatalogProvider`, `certificationCatalogSyncProvider` |
| `presentation/pages/certification_agencies_page.dart` | Settings > Manage list page |
| `presentation/pages/certification_agency_edit_page.dart` | agency editor (name, colour, share, preview, levels) |
| `presentation/widgets/certification_level_dialog.dart` | add/edit level dialog |
| `presentation/widgets/custom_agency_dialog.dart` | quick-create agency dialog (name + colour) |
| `presentation/widgets/certification_delete_refusal.dart` | refusal dialog helper |
| `presentation/widgets/agency_swatch.dart` | small gradient swatch used in list rows and preview |

Modified (main ones; each task lists its own):

| File | Change |
| --- | --- |
| `lib/core/constants/enums.dart` | `acuc`, `dan`; ACUC/DAN levels; `fromId`; `isInstructorLevel` |
| `lib/core/constants/certification_levels.dart` | `_acucLadder`, `_danLadder`, `_danSpecialties` |
| `lib/core/database/tables/buddy_tables.dart` | two tables |
| `lib/core/database/database.dart` | registration, version 261, `migrationVersions` |
| `lib/core/database/migrations/...` | helper, rung, backstop, `_hlcTables` |
| `lib/core/services/sync/sync_data_serializer.dart`, `sync_service.dart`, `lib/core/data/repositories/sync_repository.dart` | two entities |
| `lib/features/divers/data/repositories/diver_owned_rows.dart` | two owned tables |
| `lib/features/certifications/**`, `lib/features/courses/**`, `lib/features/buddies/**` | String ids, catalog lookups, pickers |
| import/export and query files | Tasks 10 and 11 |

---

### Task 1: ACUC and DAN built-ins

**Files:**
- Modify: `lib/core/constants/enums.dart` (agency enum ~L157-208; level enum ~L219-345; `isInstructorLevel` ~L348)
- Modify: `lib/core/constants/certification_levels.dart`
- Modify: `lib/features/certifications/presentation/certification_agency_display.dart`
- Modify: `lib/features/certifications/presentation/certification_level_display.dart`
- Modify: all 11 `lib/l10n/arb/app_*.arb` (two agency keys each)
- Test: `test/core/constants/certification_levels_test.dart`, `test/core/constants/certification_level_instructor_test.dart`, `test/core/constants/certification_agency_color_test.dart`

**Interfaces:**
- Produces: `CertificationAgency.acuc`, `CertificationAgency.dan`; `CertificationAgency.fromId(String? id) -> CertificationAgency?`; `CertificationLevel.fromId(String? id) -> CertificationLevel?`; the 17 level values below; `CertificationLevelCatalog.ladderFor(CertificationAgency.acuc|dan)`, `specialtiesFor(CertificationAgency.dan)`.

- [ ] **Step 1: Write the failing tests**

Append to `test/core/constants/certification_levels_test.dart` inside `main()`:

```dart
  group('ACUC and DAN (issue #690)', () {
    test('ACUC ladder is its own progression in rank order', () {
      expect(CertificationLevelCatalog.ladderFor(CertificationAgency.acuc), [
        CertificationLevel.acucScubaDiver,
        CertificationLevel.openWater,
        CertificationLevel.acucAdvancedDiver,
        CertificationLevel.acucRescueLeader,
        CertificationLevel.masterDiver,
        CertificationLevel.acucUnderwaterGuide,
        CertificationLevel.acucTeachingAssistant,
        CertificationLevel.acucOpenWaterInstructor,
        CertificationLevel.acucAdvancedInstructor,
        CertificationLevel.acucInstructorTrainer,
        CertificationLevel.acucInstructorTrainerEvaluator,
      ]);
    });

    test('ACUC offers the shared diving specialties', () {
      expect(
        CertificationLevelCatalog.specialtiesFor(CertificationAgency.acuc),
        CertificationLevelCatalog.specialties,
      );
    });

    test('DAN ladder holds first-aid credentials, never diver grades', () {
      expect(CertificationLevelCatalog.ladderFor(CertificationAgency.dan), [
        CertificationLevel.danBls,
        CertificationLevel.danEmergencyOxygen,
        CertificationLevel.danDfaPro,
        CertificationLevel.danDemp,
        CertificationLevel.danInstructor,
        CertificationLevel.danInstructorTrainer,
      ]);
      final offered = CertificationLevelCatalog.levelsFor(CertificationAgency.dan);
      expect(offered, isNot(contains(CertificationLevel.openWater)));
      expect(offered, isNot(contains(CertificationLevel.trimix)));
    });

    test('DAN specialties replace the diving specialties', () {
      expect(CertificationLevelCatalog.specialtiesFor(CertificationAgency.dan), [
        CertificationLevel.danAdvancedOxygen,
        CertificationLevel.danNeurologicalAssessment,
        CertificationLevel.danMarineLifeInjuries,
      ]);
    });
  });

  group('fromId', () {
    test('returns the built-in for its enum name and null otherwise', () {
      expect(CertificationAgency.fromId('acuc'), CertificationAgency.acuc);
      expect(CertificationAgency.fromId('3f1c-uuid'), isNull);
      expect(CertificationAgency.fromId(null), isNull);
      expect(CertificationLevel.fromId('danDemp'), CertificationLevel.danDemp);
      expect(CertificationLevel.fromId('Open Water'), isNull);
    });
  });
```

Append to `test/core/constants/certification_level_instructor_test.dart` inside `main()`:

```dart
  test('ACUC and DAN instructor grades can certify students', () {
    for (final level in [
      CertificationLevel.acucOpenWaterInstructor,
      CertificationLevel.acucAdvancedInstructor,
      CertificationLevel.acucInstructorTrainer,
      CertificationLevel.acucInstructorTrainerEvaluator,
      CertificationLevel.danInstructor,
      CertificationLevel.danInstructorTrainer,
    ]) {
      expect(level.isInstructorLevel, isTrue, reason: level.name);
    }
    expect(CertificationLevel.acucTeachingAssistant.isInstructorLevel, isFalse);
    expect(CertificationLevel.danDemp.isInstructorLevel, isFalse);
  });
```

Append to `test/core/constants/certification_agency_color_test.dart` inside `main()`:

```dart
  test('ACUC is navy and DAN is crimson', () {
    expect(CertificationAgency.acuc.primaryColor, const Color(0xFF0D3B7A));
    expect(CertificationAgency.acuc.secondaryColor, const Color(0xFF2E6BC4));
    expect(CertificationAgency.dan.primaryColor, const Color(0xFF9E1B32));
    expect(CertificationAgency.dan.secondaryColor, const Color(0xFFD23C52));
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/core/constants/certification_levels_test.dart test/core/constants/certification_level_instructor_test.dart test/core/constants/certification_agency_color_test.dart`
Expected: compile errors (`acuc`, `dan`, `fromId`, the new levels are undefined).

- [ ] **Step 3: Add the agencies**

In `enums.dart`, insert before `other('Other');` in `CertificationAgency`:

```dart
  ffessm('FFESSM'),
  // American Canadian Underwater Certifications and Divers Alert Network
  // (issue #690). Brand names, never translated.
  acuc('ACUC'),
  dan('DAN'),
  other('Other');
```

(Replace the existing `ffessm('FFESSM'),` line with the three lines above it so ordering is ffessm, acuc, dan, other.) Add arms to both colour switches:

```dart
    CertificationAgency.acuc => const Color(0xFF0D3B7A),
    CertificationAgency.dan => const Color(0xFF9E1B32),
```

```dart
    CertificationAgency.acuc => const Color(0xFF2E6BC4),
    CertificationAgency.dan => const Color(0xFFD23C52),
```

Add after the secondary colour getter:

```dart
  /// The built-in whose enum name is [id], or null for a custom agency id,
  /// an unknown slug or null. Stored ids are enum names (issue #690).
  static CertificationAgency? fromId(String? id) {
    if (id == null) return null;
    for (final a in values) {
      if (a.name == id) return a;
    }
    return null;
  }
```

- [ ] **Step 4: Add the levels**

In `CertificationLevel`, insert before `other('Other');` (after the last FFESSM value):

```dart
  // ACUC, American Canadian Underwater Certifications (issue #690). Proper
  // names, kept untranslated like the BSAC, GUE and FFESSM ratings.
  acucScubaDiver('Scuba Diver'),
  acucAdvancedDiver('Advanced Diver'),
  acucRescueLeader('Rescue Leader'),
  acucUnderwaterGuide('Underwater Guide'),
  acucTeachingAssistant('Teaching Assistant'),
  acucOpenWaterInstructor('Open Water Instructor'),
  acucAdvancedInstructor('Advanced Instructor'),
  acucInstructorTrainer('Instructor Trainer'),
  acucInstructorTrainerEvaluator('Instructor Trainer Evaluator'),
  // DAN, Divers Alert Network (issue #690). First-aid and emergency
  // credentials, not diver grades.
  danBls('Basic Life Support: CPR and First Aid'),
  danEmergencyOxygen('Emergency Oxygen for Scuba Diving Injuries'),
  danDfaPro('Diving First Aid for Professional Divers'),
  danDemp('Diving Emergency Management Provider'),
  danInstructor('DAN Instructor'),
  danInstructorTrainer('DAN Instructor Trainer'),
  danAdvancedOxygen('Advanced Oxygen Provider'),
  danNeurologicalAssessment('On-Site Neurological Assessment'),
  danMarineLifeInjuries('First Aid for Hazardous Marine Life Injuries'),
```

Add the static lookup after the `displayName` constructor:

```dart
  /// The built-in whose enum name is [id], or null (issue #690).
  static CertificationLevel? fromId(String? id) {
    if (id == null) return null;
    for (final l in values) {
      if (l.name == id) return l;
    }
    return null;
  }
```

Extend `isInstructorLevel` with:

```dart
    CertificationLevel.acucOpenWaterInstructor ||
    CertificationLevel.acucAdvancedInstructor ||
    CertificationLevel.acucInstructorTrainer ||
    CertificationLevel.acucInstructorTrainerEvaluator ||
    CertificationLevel.danInstructor ||
    CertificationLevel.danInstructorTrainer ||
```

(before `CertificationLevel.ffessmMf1 ||`).

- [ ] **Step 5: Add the ladders**

In `certification_levels.dart`, after `_ffessmSpecialties` add:

```dart
  /// ACUC progression (issue #690), from ACUC's own course pages: entry,
  /// recreational, leadership, then the instructor track.
  static const List<CertificationLevel> _acucLadder = [
    CertificationLevel.acucScubaDiver,
    CertificationLevel.openWater,
    CertificationLevel.acucAdvancedDiver,
    CertificationLevel.acucRescueLeader,
    CertificationLevel.masterDiver,
    CertificationLevel.acucUnderwaterGuide,
    CertificationLevel.acucTeachingAssistant,
    CertificationLevel.acucOpenWaterInstructor,
    CertificationLevel.acucAdvancedInstructor,
    CertificationLevel.acucInstructorTrainer,
    CertificationLevel.acucInstructorTrainerEvaluator,
  ];

  /// DAN issues first-aid and emergency credentials, not diver grades
  /// (issue #690). The provider track, then the teaching track.
  static const List<CertificationLevel> _danLadder = [
    CertificationLevel.danBls,
    CertificationLevel.danEmergencyOxygen,
    CertificationLevel.danDfaPro,
    CertificationLevel.danDemp,
    CertificationLevel.danInstructor,
    CertificationLevel.danInstructorTrainer,
  ];

  /// DAN's add-on provider courses. They replace the diving [specialties]
  /// so DAN never offers "Trimix".
  static const List<CertificationLevel> _danSpecialties = [
    CertificationLevel.danAdvancedOxygen,
    CertificationLevel.danNeurologicalAssessment,
    CertificationLevel.danMarineLifeInjuries,
  ];
```

In `ladderFor` add arms before `other || null`:

```dart
        CertificationAgency.acuc => _acucLadder,
        CertificationAgency.dan => _danLadder,
```

Replace the pool selection in `specialtiesFor` with:

```dart
    final pool = switch (agency) {
      CertificationAgency.ffessm => _ffessmSpecialties,
      CertificationAgency.dan => _danSpecialties,
      _ => specialties,
    };
```

- [ ] **Step 6: Wire display names**

`certification_agency_display.dart`, add arms:

```dart
    CertificationAgency.acuc => l10n.enum_certificationAgency_acuc,
    CertificationAgency.dan => l10n.enum_certificationAgency_dan,
```

`certification_level_display.dart`: add every new ACUC and DAN value to the existing proprietary-name arm that returns `displayName` (the arm that lists `CertificationLevel.ffessmPlongeurBronze || ...`), and extend the doc comment's list to "BSAC, GUE, TDI Extended Range, ACUC, DAN and the whole FFESSM federation cursus".

ARB: in every `lib/l10n/arb/app_*.arb`, after the `enum_certificationAgency_ffessm` line add (the value is the brand in every locale):

```json
  "enum_certificationAgency_acuc": "ACUC",
  "enum_certificationAgency_dan": "DAN",
```

In `app_en.arb` only, if the ffessm key has an `@enum_certificationAgency_ffessm` metadata entry, add matching `@...acuc` and `@...dan` entries with descriptions "ACUC certification agency (brand name, do not translate)" and "DAN certification agency (brand name, do not translate)".

Run: `flutter gen-l10n`

- [ ] **Step 7: Run tests to verify they pass**

Run: `flutter test test/core/constants/ test/features/certifications/presentation/`
Expected: PASS. If a test enumerates `CertificationAgency.values` with a fixed count, update the count and note the two new values.

- [ ] **Step 8: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/core/constants/enums.dart lib/core/constants/certification_levels.dart lib/features/certifications/presentation/certification_agency_display.dart lib/features/certifications/presentation/certification_level_display.dart lib/l10n/arb/ test/core/constants/
git commit -m "feat(certifications): add ACUC and DAN as built-in agencies"
```

---

### Task 2: Schema v261, the two custom tables

**Files:**
- Modify: `lib/core/database/tables/buddy_tables.dart` (after `DiveRoles`, ~L143)
- Modify: `lib/core/database/database.dart` (registration list after `DiveRoles,` ~L115; `currentSchemaVersion` ~L235; `migrationVersions` ~L326)
- Modify: `lib/core/database/migrations/helpers/buddy_migrations.dart` (new helper)
- Modify: `lib/core/database/migrations/ladder/rungs_v231_onward.dart` (rung after v260)
- Modify: `lib/core/database/migrations/before_open.dart` (backstop near the v234 one ~L178)
- Modify: `lib/core/database/migrations/app_database_migrations.dart` (`_hlcTables`, after `'dive_roles',`)
- Modify: `lib/features/divers/data/repositories/diver_owned_rows.dart` (`_ownedTables`, after the `dive_roles` entry)
- Test: `test/core/database/migrations/custom_certification_tables_migration_test.dart`

**Interfaces:**
- Produces: Drift tables `CustomCertificationAgencies` (data class `CustomCertificationAgencyRow`, accessor `db.customCertificationAgencies`) and `CustomCertificationLevels` (data class `CustomCertificationLevelRow`, accessor `db.customCertificationLevels`); SQL names `custom_certification_agencies`, `custom_certification_levels`; helper `_assertCustomCertificationSchema()`.

- [ ] **Step 1: Write the failing migration test**

Look at an existing table-only rung test for the stranded-database pattern first: `grep -rln "_assertEquipmentSharingSchema\|equipment_shares" test/core/database | head`. Mirror its "stranded below vN" setup (it sets `PRAGMA user_version` and drops the table, then reopens). Create:

```dart
// test/core/database/migrations/custom_certification_tables_migration_test.dart
import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

import '../../../helpers/test_database.dart';

/// v261 (issue #690): custom certification agencies and levels. Table-only
/// rung, no data migration: stored agency/level text are enum names, which
/// stay valid ids.
void main() {
  late AppDatabase db;

  setUp(() async => db = await setUpTestDatabase());
  tearDown(tearDownTestDatabase);

  Future<Set<String>> columns(String table) async {
    final rows = await db
        .customSelect('SELECT name FROM pragma_table_info(?)',
            variables: [Variable.withString(table)])
        .get();
    return {for (final r in rows) r.read<String>('name')};
  }

  test('schema version is 261', () {
    expect(AppDatabase.currentSchemaVersion, 261);
    expect(AppDatabase.migrationVersions.last, 261);
  });

  test('a fresh database has both tables with every column', () async {
    expect(await columns('custom_certification_agencies'), {
      'id', 'diver_id', 'name', 'color_argb', 'is_shared',
      'created_at', 'updated_at', 'hlc',
    });
    expect(await columns('custom_certification_levels'), {
      'id', 'diver_id', 'agency_id', 'name', 'is_progression',
      'sort_order', 'is_shared', 'created_at', 'updated_at', 'hlc',
    });
  });

  test('levels are indexed by agency', () async {
    final rows = await db.customSelect(
      "SELECT name FROM sqlite_master WHERE type = 'index' "
      "AND tbl_name = 'custom_certification_levels'",
    ).get();
    expect(rows.map((r) => r.read<String>('name')),
        contains('idx_custom_certification_levels_agency'));
  });

  test('the beforeOpen backstop recreates missing tables', () async {
    await db.customStatement('DROP TABLE custom_certification_levels');
    await db.customStatement('DROP TABLE custom_certification_agencies');
    await db.close();
    // Reopening runs beforeOpen again; follow the pattern the equipment
    // sharing backstop test uses to reopen the same in-memory executor.
    // (Use the helper that test uses; if it reopens via a file database
    // under Directory.systemTemp, do the same here.)
  });
}
```

For the last test, copy the reopen mechanics verbatim from the equipment sharing backstop test you found (it is the established pattern; do not invent a new one), then assert both tables exist again with `columns(...)` non-empty.

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/core/database/migrations/custom_certification_tables_migration_test.dart`
Expected: FAIL (version 260; tables missing).

- [ ] **Step 3: Define the tables**

Append after the `DiveRoles` class in `buddy_tables.dart`:

```dart
/// A diver's own certification agency (v261, issue #690). Built-in agencies
/// are code constants and never have a row; custom ids are UUIDs, stored in
/// the same agency text columns as the built-in enum names.
@DataClassName('CustomCertificationAgencyRow')
class CustomCertificationAgencies extends Table {
  TextColumn get id => text()();
  // No ON DELETE action: the diver deletion clears and tombstones these
  // rows itself (diver_owned_rows.dart), as it does dive_roles.
  TextColumn get diverId => text().references(Divers, #id)();
  TextColumn get name => text()();

  /// Primary e-card colour (ARGB). The gradient's second colour is derived.
  IntColumn get colorArgb => integer()();
  BoolColumn get isShared => boolean().withDefault(const Constant(false))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution.
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// A diver's own certification (level) under any agency, built-in or custom
/// (v261, issue #690). [agencyId] is a built-in enum name or a custom agency
/// UUID, so it carries no foreign key.
@DataClassName('CustomCertificationLevelRow')
class CustomCertificationLevels extends Table {
  TextColumn get id => text()();
  TextColumn get diverId => text().references(Divers, #id)();
  TextColumn get agencyId => text()();
  TextColumn get name => text()();

  /// A ranked rung (after the agency's built-in ladder) or a specialty.
  BoolColumn get isProgression => boolean()();

  /// Rank among this agency's custom progression rungs.
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  /// Used only under a built-in agency; under a custom agency the level
  /// follows its agency's visibility.
  BoolColumn get isShared => boolean().withDefault(const Constant(false))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
```

In `database.dart` add `CustomCertificationAgencies, CustomCertificationLevels,` after `DiveRoles,` in the `@DriftDatabase` tables list, set `currentSchemaVersion = 261`, and append to `migrationVersions`: `261, // 261: custom certification agencies and levels (issue #690)`.

- [ ] **Step 4: Helper, rung, backstop, HLC list, owned tables**

In `helpers/buddy_migrations.dart`, inside its extension, add:

```dart
  /// Idempotent creation of the v261 custom certification tables (issue
  /// #690) and the level-by-agency index. Called from the v261 rung and the
  /// beforeOpen backstop. Skipped on a partial migration fixture without
  /// `divers`, so an older fixture does not gain tables whose foreign keys
  /// point nowhere.
  Future<void> _assertCustomCertificationSchema() async {
    final divers = await customSelect(
      "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = 'divers'",
    ).get();
    if (divers.isEmpty) return;
    await Migrator(this).createTable(customCertificationAgencies);
    await Migrator(this).createTable(customCertificationLevels);
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_custom_certification_levels_agency '
      'ON custom_certification_levels(agency_id)',
    );
  }
```

`Migrator.createTable` uses `CREATE TABLE IF NOT EXISTS`, so it is idempotent (the v234 helper relies on the same).

Rung, appended after the v260 block in `rungs_v231_onward.dart`:

```dart
    // v261: custom certification agencies and levels (issue #690). Table
    // and index only, no backfill: stored agency/level text are built-in
    // enum names, which stay valid ids. Re-asserted in beforeOpen.
    if (from < 261) {
      await _assertCustomCertificationSchema();
    }
    if (from < 261) await reportProgress();
```

Backstop in `before_open.dart` after the v234 block:

```dart
    // v261 backstop: the custom certification tables (parallel-branch
    // version-collision self-heal; idempotent).
    await _assertCustomCertificationSchema();
```

`_hlcTables`: add `'custom_certification_agencies',` and `'custom_certification_levels',` after `'dive_roles',`.

`diver_owned_rows.dart` `_ownedTables`, after the `dive_roles` entry (levels first, they reference agencies by id):

```dart
  (
    table: 'custom_certification_levels',
    entityType: 'customCertificationLevels',
    hasBuiltIns: false,
    children: [],
  ),
  (
    table: 'custom_certification_agencies',
    entityType: 'customCertificationAgencies',
    hasBuiltIns: false,
    children: [],
  ),
```

- [ ] **Step 5: Codegen and run**

Run: `dart run build_runner build --delete-conflicting-outputs`
Run: `flutter test test/core/database/migrations/custom_certification_tables_migration_test.dart test/features/divers/data/repositories/diver_delete_owned_tables_test.dart`
Expected: PASS. If the owned-tables test has a list of expected owned table names (it names `'dive_roles'` near L800), add both new tables to it.

- [ ] **Step 6: Run the schema guard suites**

Run: `flutter test test/core/database/ test/architecture/`
Expected: PASS. Tests that pin `currentSchemaVersion` literals (memory: "ladder-literals") may need 260 -> 261; update only literals that mean "current version".

- [ ] **Step 7: Commit**

```bash
dart format .
flutter analyze
git add lib/core/database/ lib/features/divers/data/repositories/diver_owned_rows.dart test/core/database/migrations/custom_certification_tables_migration_test.dart test/features/divers/
git commit -m "feat(certification-agencies): add custom agency and level tables (v261)"
```

(`database.g.dart` is generated; stage it too if it is tracked: check `git status`.)

---

### Task 3: Entities and CustomCertificationRepository

**Files:**
- Create: `lib/features/certification_agencies/domain/entities/custom_certification_agency.dart`
- Create: `lib/features/certification_agencies/domain/entities/custom_certification_level.dart`
- Create: `lib/features/certification_agencies/domain/entities/certification_usage.dart`
- Create: `lib/features/certification_agencies/domain/agency_colors.dart`
- Create: `lib/features/certification_agencies/data/repositories/custom_certification_repository.dart`
- Test: `test/features/certification_agencies/data/custom_certification_repository_test.dart`
- Test: `test/features/certification_agencies/domain/agency_colors_test.dart`

**Interfaces:**
- Consumes: Task 2 tables; `SyncRepository.markRecordPending({entityType, recordId, localUpdatedAt})`, `logDeletion({entityType, recordId})`; `SyncEventBus.notifyLocalChange()`; `DatabaseService.instance.database`.
- Produces:
  - `CustomCertificationAgency({id, diverId, name, colorArgb, isShared, createdAt, updatedAt})`
  - `CustomCertificationLevel({id, diverId, agencyId, name, isProgression, sortOrder, isShared, createdAt, updatedAt})`
  - `CertificationUsage({certifications, courses})`, `bool get isUsed`
  - `int defaultAgencyColorArgb(String id)`, `Color secondaryAgencyColor(Color primary)`
  - `class CustomCertificationRepository` with:
    - `static const agencyEntityType = 'customCertificationAgencies'`, `levelEntityType = 'customCertificationLevels'`
    - `Stream<void> watchChanges()`
    - `Future<List<CustomCertificationAgency>> getAllAgencies()`, `Future<List<CustomCertificationLevel>> getAllLevels()`
    - `Future<CustomCertificationAgency> createAgency({required String diverId, required String name, int? colorArgb, required bool isShared})`
    - `Future<CustomCertificationAgency> updateAgency(CustomCertificationAgency agency, {required String actingDiverId})`
    - `Future<CustomCertificationLevel> createLevel({required String diverId, required String agencyId, required String name, required bool isProgression, required bool isShared})`
    - `Future<CustomCertificationLevel> updateLevel(CustomCertificationLevel level, {required String actingDiverId})`
    - `Future<void> reorderProgression(String agencyId, List<String> orderedIds, {required String actingDiverId})`
    - `Future<CertificationUsage> usage(String id)`
    - `Future<CertificationUsage?> deleteAgency(String id, {required String actingDiverId})` (returns non-null usage when refused)
    - `Future<CertificationUsage?> deleteLevel(String id, {required String actingDiverId})`
  - Exceptions: `CertificationNameTakenException`, `CertificationNotOwnerException` (both `implements Exception`, in the repository file).

- [ ] **Step 1: Write the entity, colour and repository tests**

`test/features/certification_agencies/domain/agency_colors_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/certification_agencies/domain/agency_colors.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';

void main() {
  test('the default colour is stable for an id and from the tag palette', () {
    final a = defaultAgencyColorArgb('8c1e5a2e-0000-4000-8000-000000000001');
    expect(defaultAgencyColorArgb('8c1e5a2e-0000-4000-8000-000000000001'), a);
    final palette = TagColors.predefined
        .map((h) => TagColors.fromHex(h).toARGB32())
        .toSet();
    expect(palette, contains(a));
  });

  test('the secondary colour is a lighter shade of the primary', () {
    const primary = Color(0xFF0D3B7A);
    final secondary = secondaryAgencyColor(primary);
    expect(HSLColor.fromColor(secondary).lightness,
        greaterThan(HSLColor.fromColor(primary).lightness));
  });
}
```

`test/features/certification_agencies/data/custom_certification_repository_test.dart`:

```dart
import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/certification_agencies/data/repositories/custom_certification_repository.dart';

import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late CustomCertificationRepository repo;

  Future<void> insertDiver(String id) => db.into(db.divers).insert(
    DiversCompanion.insert(id: id, name: id, createdAt: 0, updatedAt: 0),
  );

  setUp(() async {
    db = await setUpTestDatabase();
    repo = CustomCertificationRepository();
    await insertDiver('a');
    await insertDiver('b');
  });
  tearDown(tearDownTestDatabase);

  Future<List<String>> pending(String type) async =>
      (await db.select(db.syncRecords).get())
          .where((r) => r.entityType == type)
          .map((r) => r.recordId)
          .toList();

  Future<List<String>> tombstones(String type) async =>
      (await db.select(db.deletionLog).get())
          .where((r) => r.entityType == type)
          .map((r) => r.recordId)
          .toList();

  group('agencies', () {
    test('create trims, assigns a uuid and marks pending', () async {
      final a = await repo.createAgency(diverId: 'a', name: '  Club X ', isShared: false);
      expect(a.name, 'Club X');
      expect(a.id, hasLength(36));
      expect(await pending(CustomCertificationRepository.agencyEntityType), [a.id]);
    });

    test('a built-in name is taken, case-insensitively', () async {
      expect(
        () => repo.createAgency(diverId: 'a', name: 'padi', isShared: false),
        throwsA(isA<CertificationNameTakenException>()),
      );
    });

    test('a name visible to the diver is taken; another diver may reuse a private one', () async {
      await repo.createAgency(diverId: 'a', name: 'Club X', isShared: false);
      expect(
        () => repo.createAgency(diverId: 'a', name: 'CLUB x', isShared: false),
        throwsA(isA<CertificationNameTakenException>()),
      );
      await repo.createAgency(diverId: 'b', name: 'Club X', isShared: false);
    });

    test('a shared agency blocks the same name for every diver', () async {
      await repo.createAgency(diverId: 'a', name: 'Club X', isShared: true);
      expect(
        () => repo.createAgency(diverId: 'b', name: 'club x', isShared: false),
        throwsA(isA<CertificationNameTakenException>()),
      );
    });

    test('refuses writes from a non-owner', () async {
      final a = await repo.createAgency(diverId: 'a', name: 'Club X', isShared: true);
      expect(
        () => repo.updateAgency(a.copyWith(name: 'Hijacked'), actingDiverId: 'b'),
        throwsA(isA<CertificationNotOwnerException>()),
      );
      expect(
        () => repo.deleteAgency(a.id, actingDiverId: 'b'),
        throwsA(isA<CertificationNotOwnerException>()),
      );
    });

    test('delete is refused while a certification, credential or course uses it', () async {
      final a = await repo.createAgency(diverId: 'a', name: 'Club X', isShared: false);
      await db.customStatement(
        "INSERT INTO certifications (id, name, agency, notes, created_at, updated_at) "
        "VALUES ('c1', 'x', '${a.id}', '', 0, 0)",
      );
      await db.customStatement(
        "INSERT INTO certifications (id, name, agency, additional_credentials, notes, created_at, updated_at) "
        "VALUES ('c2', 'y', 'padi', '[{\"agency\":\"${a.id}\"}]', '', 0, 0)",
      );
      final refused = await repo.deleteAgency(a.id, actingDiverId: 'a');
      expect(refused, isNotNull);
      expect(refused!.certifications, 2);
      expect(refused.courses, 0);
      expect(await repo.getAllAgencies(), hasLength(1));
    });

    test('deleting an unused agency removes its unused levels and tombstones both', () async {
      final a = await repo.createAgency(diverId: 'a', name: 'Club X', isShared: false);
      final l = await repo.createLevel(
        diverId: 'a', agencyId: a.id, name: 'Club Diver', isProgression: true, isShared: false);
      expect(await repo.deleteAgency(a.id, actingDiverId: 'a'), isNull);
      expect(await repo.getAllAgencies(), isEmpty);
      expect(await repo.getAllLevels(), isEmpty);
      expect(await tombstones(CustomCertificationRepository.agencyEntityType), [a.id]);
      expect(await tombstones(CustomCertificationRepository.levelEntityType), [l.id]);
    });

    test('an agency whose level is in use cannot be deleted', () async {
      final a = await repo.createAgency(diverId: 'a', name: 'Club X', isShared: false);
      final l = await repo.createLevel(
        diverId: 'a', agencyId: a.id, name: 'Club Diver', isProgression: true, isShared: false);
      await db.customStatement(
        "INSERT INTO certifications (id, name, agency, level, notes, created_at, updated_at) "
        "VALUES ('c1', 'x', 'padi', '${l.id}', '', 0, 0)",
      );
      expect(await repo.deleteAgency(a.id, actingDiverId: 'a'), isNotNull);
    });
  });

  group('levels', () {
    test('progression levels append in sort order; reorder rewrites it', () async {
      final l1 = await repo.createLevel(
        diverId: 'a', agencyId: 'padi', name: 'Ice Diver', isProgression: true, isShared: false);
      final l2 = await repo.createLevel(
        diverId: 'a', agencyId: 'padi', name: 'Ice Instructor', isProgression: true, isShared: false);
      expect(l2.sortOrder, greaterThan(l1.sortOrder));
      await repo.reorderProgression('padi', [l2.id, l1.id], actingDiverId: 'a');
      final byId = {for (final l in await repo.getAllLevels()) l.id: l};
      expect(byId[l2.id]!.sortOrder, lessThan(byId[l1.id]!.sortOrder));
      expect(await pending(CustomCertificationRepository.levelEntityType),
          containsAll([l1.id, l2.id]));
    });

    test('a built-in level name under the same agency is taken', () async {
      expect(
        () => repo.createLevel(diverId: 'a', agencyId: 'padi', name: 'open water',
            isProgression: true, isShared: false),
        throwsA(isA<CertificationNameTakenException>()),
      );
    });

    test('delete is refused while a certification uses it', () async {
      final l = await repo.createLevel(
        diverId: 'a', agencyId: 'padi', name: 'Ice Diver', isProgression: false, isShared: false);
      await db.customStatement(
        "INSERT INTO certifications (id, name, agency, level, notes, created_at, updated_at) "
        "VALUES ('c1', 'x', 'padi', '${l.id}', '', 0, 0)",
      );
      final refused = await repo.deleteLevel(l.id, actingDiverId: 'a');
      expect(refused?.certifications, 1);
    });
  });
}
```

Check `DiversCompanion.insert`'s required parameters with `grep -n "class Divers extends" -A30 lib/core/database/tables/diver_tables.dart` and adjust `insertDiver` if more columns are required. Check the `certifications` insert columns against `buddy_tables.dart` L72-119 (all NOT NULL columns without defaults must be given).

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/certification_agencies/`
Expected: compile errors (missing files).

- [ ] **Step 3: Write the entities**

`custom_certification_agency.dart`:

```dart
import 'package:equatable/equatable.dart';

/// A certification agency a diver added (issue #690). Built-in agencies are
/// the CertificationAgency enum and never take this shape.
class CustomCertificationAgency extends Equatable {
  final String id;
  final String diverId;
  final String name;
  final int colorArgb;
  final bool isShared;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CustomCertificationAgency({
    required this.id,
    required this.diverId,
    required this.name,
    required this.colorArgb,
    this.isShared = false,
    required this.createdAt,
    required this.updatedAt,
  });

  CustomCertificationAgency copyWith({
    String? id,
    String? diverId,
    String? name,
    int? colorArgb,
    bool? isShared,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => CustomCertificationAgency(
    id: id ?? this.id,
    diverId: diverId ?? this.diverId,
    name: name ?? this.name,
    colorArgb: colorArgb ?? this.colorArgb,
    isShared: isShared ?? this.isShared,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  @override
  List<Object?> get props => [
    id, diverId, name, colorArgb, isShared, createdAt, updatedAt,
  ];
}
```

`custom_certification_level.dart`:

```dart
import 'package:equatable/equatable.dart';

/// A certification a diver added under any agency, built-in or custom
/// (issue #690). [agencyId] is a built-in enum name or a custom agency id.
class CustomCertificationLevel extends Equatable {
  final String id;
  final String diverId;
  final String agencyId;
  final String name;
  final bool isProgression;
  final int sortOrder;

  /// Meaningful only under a built-in agency; under a custom agency the
  /// level follows its agency's visibility.
  final bool isShared;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CustomCertificationLevel({
    required this.id,
    required this.diverId,
    required this.agencyId,
    required this.name,
    required this.isProgression,
    this.sortOrder = 0,
    this.isShared = false,
    required this.createdAt,
    required this.updatedAt,
  });

  CustomCertificationLevel copyWith({
    String? id,
    String? diverId,
    String? agencyId,
    String? name,
    bool? isProgression,
    int? sortOrder,
    bool? isShared,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => CustomCertificationLevel(
    id: id ?? this.id,
    diverId: diverId ?? this.diverId,
    agencyId: agencyId ?? this.agencyId,
    name: name ?? this.name,
    isProgression: isProgression ?? this.isProgression,
    sortOrder: sortOrder ?? this.sortOrder,
    isShared: isShared ?? this.isShared,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  @override
  List<Object?> get props => [
    id, diverId, agencyId, name, isProgression, sortOrder, isShared,
    createdAt, updatedAt,
  ];
}
```

`certification_usage.dart`:

```dart
import 'package:equatable/equatable.dart';

/// How many rows reference a custom agency or level. Deletion is refused
/// while [isUsed] (issue #690).
class CertificationUsage extends Equatable {
  /// Diver and buddy certification rows, counting the row's own agency and
  /// level and its additional credentials.
  final int certifications;
  final int courses;

  const CertificationUsage({this.certifications = 0, this.courses = 0});

  bool get isUsed => certifications > 0 || courses > 0;

  CertificationUsage operator +(CertificationUsage other) => CertificationUsage(
    certifications: certifications + other.certifications,
    courses: courses + other.courses,
  );

  @override
  List<Object?> get props => [certifications, courses];
}
```

`agency_colors.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/features/tags/domain/entities/tag.dart';

/// A stable default card colour for a new custom agency (issue #690): the
/// id's hash picks a tag palette colour, so a quick-created agency needs no
/// extra step and keeps its colour on every device.
int defaultAgencyColorArgb(String id) {
  var hash = 0;
  for (final unit in id.codeUnits) {
    hash = (hash * 31 + unit) & 0x7fffffff;
  }
  final hex = TagColors.predefined[hash % TagColors.predefined.length];
  return TagColors.fromHex(hex).toARGB32();
}

/// The gradient's second colour: the primary, lightened. Built-in agencies
/// carry a hand-picked secondary; custom ones derive it.
Color secondaryAgencyColor(Color primary) {
  final hsl = HSLColor.fromColor(primary);
  return hsl.withLightness((hsl.lightness + 0.18).clamp(0.0, 0.85)).toColor();
}
```

- [ ] **Step 4: Write the repository**

```dart
// lib/features/certification_agencies/data/repositories/custom_certification_repository.dart
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/constants/certification_levels.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/certification_agencies/domain/agency_colors.dart';
import 'package:submersion/features/certification_agencies/domain/entities/certification_usage.dart';
import 'package:submersion/features/certification_agencies/domain/entities/custom_certification_agency.dart';
import 'package:submersion/features/certification_agencies/domain/entities/custom_certification_level.dart';

class CertificationNameTakenException implements Exception {
  final String name;
  const CertificationNameTakenException(this.name);
  @override
  String toString() => 'CertificationNameTakenException($name)';
}

class CertificationNotOwnerException implements Exception {
  final String id;
  const CertificationNotOwnerException(this.id);
  @override
  String toString() => 'CertificationNotOwnerException($id)';
}

CustomCertificationAgency mapCustomAgencyRow(CustomCertificationAgencyRow r) =>
    CustomCertificationAgency(
      id: r.id,
      diverId: r.diverId,
      name: r.name,
      colorArgb: r.colorArgb,
      isShared: r.isShared,
      createdAt: DateTime.fromMillisecondsSinceEpoch(r.createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(r.updatedAt),
    );

CustomCertificationLevel mapCustomLevelRow(CustomCertificationLevelRow r) =>
    CustomCertificationLevel(
      id: r.id,
      diverId: r.diverId,
      agencyId: r.agencyId,
      name: r.name,
      isProgression: r.isProgression,
      sortOrder: r.sortOrder,
      isShared: r.isShared,
      createdAt: DateTime.fromMillisecondsSinceEpoch(r.createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(r.updatedAt),
    );

/// Custom certification agencies and levels (issue #690). Owned per diver,
/// optionally shared; only the owner writes. Deletion is refused while any
/// certification or course references the entry, so nothing is rewritten.
class CustomCertificationRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
  final _uuid = const Uuid();
  final _log = LoggerService.forClass(CustomCertificationRepository);

  static const agencyEntityType = 'customCertificationAgencies';
  static const levelEntityType = 'customCertificationLevels';

  Stream<void> watchChanges() => _db.tableUpdates(
    TableUpdateQuery.onAllTables([
      _db.customCertificationAgencies,
      _db.customCertificationLevels,
    ]),
  );

  Future<List<CustomCertificationAgency>> getAllAgencies() async {
    final rows = await (_db.select(_db.customCertificationAgencies)
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .get();
    return rows.map(mapCustomAgencyRow).toList();
  }

  Future<List<CustomCertificationLevel>> getAllLevels() async {
    final rows = await (_db.select(_db.customCertificationLevels)
          ..orderBy([
            (t) => OrderingTerm.asc(t.sortOrder),
            (t) => OrderingTerm.asc(t.name),
          ]))
        .get();
    return rows.map(mapCustomLevelRow).toList();
  }

  Future<CustomCertificationAgency> createAgency({
    required String diverId,
    required String name,
    int? colorArgb,
    required bool isShared,
  }) async {
    try {
      final trimmed = _requireName(name);
      await _ensureAgencyNameFree(trimmed, diverId: diverId);
      final id = _uuid.v4();
      final now = DateTime.now().millisecondsSinceEpoch;
      await _db.into(_db.customCertificationAgencies).insert(
        CustomCertificationAgenciesCompanion.insert(
          id: id,
          diverId: diverId,
          name: trimmed,
          colorArgb: colorArgb ?? defaultAgencyColorArgb(id),
          isShared: Value(isShared),
          createdAt: now,
          updatedAt: now,
        ),
      );
      await _markPending(agencyEntityType, id, now);
      return (await _agency(id))!;
    } catch (e, st) {
      _log.error('Failed to create agency', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<CustomCertificationAgency> updateAgency(
    CustomCertificationAgency agency, {
    required String actingDiverId,
  }) async {
    try {
      final existing = await _agency(agency.id);
      if (existing == null || existing.diverId != actingDiverId) {
        throw CertificationNotOwnerException(agency.id);
      }
      final trimmed = _requireName(agency.name);
      await _ensureAgencyNameFree(trimmed,
          diverId: actingDiverId, exceptId: agency.id);
      final now = DateTime.now().millisecondsSinceEpoch;
      await (_db.update(_db.customCertificationAgencies)
            ..where((t) => t.id.equals(agency.id)))
          .write(
        CustomCertificationAgenciesCompanion(
          name: Value(trimmed),
          colorArgb: Value(agency.colorArgb),
          isShared: Value(agency.isShared),
          updatedAt: Value(now),
        ),
      );
      await _markPending(agencyEntityType, agency.id, now);
      return (await _agency(agency.id))!;
    } catch (e, st) {
      _log.error('Failed to update agency ${agency.id}', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<CustomCertificationLevel> createLevel({
    required String diverId,
    required String agencyId,
    required String name,
    required bool isProgression,
    required bool isShared,
  }) async {
    try {
      final trimmed = _requireName(name);
      await _ensureLevelNameFree(trimmed, agencyId: agencyId, diverId: diverId);
      final id = _uuid.v4();
      final now = DateTime.now().millisecondsSinceEpoch;
      final sortOrder = isProgression ? await _nextSortOrder(agencyId) : 0;
      await _db.into(_db.customCertificationLevels).insert(
        CustomCertificationLevelsCompanion.insert(
          id: id,
          diverId: diverId,
          agencyId: agencyId,
          name: trimmed,
          isProgression: isProgression,
          sortOrder: Value(sortOrder),
          isShared: Value(isShared),
          createdAt: now,
          updatedAt: now,
        ),
      );
      await _markPending(levelEntityType, id, now);
      return (await _level(id))!;
    } catch (e, st) {
      _log.error('Failed to create level', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<CustomCertificationLevel> updateLevel(
    CustomCertificationLevel level, {
    required String actingDiverId,
  }) async {
    try {
      final existing = await _level(level.id);
      if (existing == null || existing.diverId != actingDiverId) {
        throw CertificationNotOwnerException(level.id);
      }
      final trimmed = _requireName(level.name);
      await _ensureLevelNameFree(trimmed,
          agencyId: existing.agencyId,
          diverId: actingDiverId,
          exceptId: level.id);
      final now = DateTime.now().millisecondsSinceEpoch;
      // Moving a specialty onto the ladder appends it; the agency is fixed.
      final sortOrder = level.isProgression && !existing.isProgression
          ? await _nextSortOrder(existing.agencyId)
          : existing.sortOrder;
      await (_db.update(_db.customCertificationLevels)
            ..where((t) => t.id.equals(level.id)))
          .write(
        CustomCertificationLevelsCompanion(
          name: Value(trimmed),
          isProgression: Value(level.isProgression),
          sortOrder: Value(sortOrder),
          isShared: Value(level.isShared),
          updatedAt: Value(now),
        ),
      );
      await _markPending(levelEntityType, level.id, now);
      return (await _level(level.id))!;
    } catch (e, st) {
      _log.error('Failed to update level ${level.id}', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Rewrites sort_order for [orderedIds] (the agency's custom progression
  /// rungs owned by [actingDiverId]) in the given sequence. Each row is
  /// updated in place and stamped, never deleted and reinserted (#347).
  Future<void> reorderProgression(
    String agencyId,
    List<String> orderedIds, {
    required String actingDiverId,
  }) async {
    try {
      await _db.transaction(() async {
        final now = DateTime.now().millisecondsSinceEpoch;
        for (var i = 0; i < orderedIds.length; i++) {
          final existing = await _level(orderedIds[i]);
          if (existing == null ||
              existing.diverId != actingDiverId ||
              existing.agencyId != agencyId) {
            throw CertificationNotOwnerException(orderedIds[i]);
          }
          await (_db.update(_db.customCertificationLevels)
                ..where((t) => t.id.equals(orderedIds[i])))
              .write(CustomCertificationLevelsCompanion(
            sortOrder: Value(i),
            updatedAt: Value(now),
          ));
          await _syncRepository.markRecordPending(
            entityType: levelEntityType,
            recordId: orderedIds[i],
            localUpdatedAt: now,
          );
        }
      });
      SyncEventBus.notifyLocalChange();
    } catch (e, st) {
      _log.error('Failed to reorder levels of $agencyId', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// References to [id] from certifications (own agency, own level, and the
  /// additional_credentials JSON) and courses.
  Future<CertificationUsage> usage(String id) async {
    final row = await _db.customSelect(
      'SELECT '
      // stats-scope-exempt: deletion guard. Counts references across every
      // diver, not statistics.
      '(SELECT COUNT(*) FROM certifications WHERE agency = ?1 OR level = ?1 '
      'OR additional_credentials LIKE ?2) AS certs, '
      '(SELECT COUNT(*) FROM courses WHERE agency = ?1) AS courses',
      variables: [Variable.withString(id), Variable.withString('%"$id"%')],
    ).getSingle();
    return CertificationUsage(
      certifications: row.read<int>('certs'),
      courses: row.read<int>('courses'),
    );
  }

  /// Deletes an unused agency and its custom levels. Returns the usage and
  /// deletes nothing when the agency or any of its levels is referenced.
  Future<CertificationUsage?> deleteAgency(
    String id, {
    required String actingDiverId,
  }) async {
    try {
      final existing = await _agency(id);
      if (existing == null) return null;
      if (existing.diverId != actingDiverId) {
        throw CertificationNotOwnerException(id);
      }
      final levels = await (_db.select(_db.customCertificationLevels)
            ..where((t) => t.agencyId.equals(id)))
          .get();
      var total = await usage(id);
      for (final l in levels) {
        total = total + await usage(l.id);
      }
      if (total.isUsed) return total;
      await _db.transaction(() async {
        for (final l in levels) {
          await (_db.delete(_db.customCertificationLevels)
                ..where((t) => t.id.equals(l.id)))
              .go();
          await _syncRepository.logDeletion(
              entityType: levelEntityType, recordId: l.id);
        }
        await (_db.delete(_db.customCertificationAgencies)
              ..where((t) => t.id.equals(id)))
            .go();
        await _syncRepository.logDeletion(
            entityType: agencyEntityType, recordId: id);
      });
      SyncEventBus.notifyLocalChange();
      return null;
    } catch (e, st) {
      _log.error('Failed to delete agency $id', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<CertificationUsage?> deleteLevel(
    String id, {
    required String actingDiverId,
  }) async {
    try {
      final existing = await _level(id);
      if (existing == null) return null;
      if (existing.diverId != actingDiverId) {
        throw CertificationNotOwnerException(id);
      }
      final used = await usage(id);
      if (used.isUsed) return used;
      await (_db.delete(_db.customCertificationLevels)
            ..where((t) => t.id.equals(id)))
          .go();
      await _syncRepository.logDeletion(entityType: levelEntityType, recordId: id);
      SyncEventBus.notifyLocalChange();
      return null;
    } catch (e, st) {
      _log.error('Failed to delete level $id', error: e, stackTrace: st);
      rethrow;
    }
  }

  // ----- helpers -----

  String _requireName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw ArgumentError.value(name, 'name', 'empty');
    return trimmed;
  }

  Future<CustomCertificationAgency?> _agency(String id) async {
    final row = await (_db.select(_db.customCertificationAgencies)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : mapCustomAgencyRow(row);
  }

  Future<CustomCertificationLevel?> _level(String id) async {
    final row = await (_db.select(_db.customCertificationLevels)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : mapCustomLevelRow(row);
  }

  /// Built-in display names, the diver's own agencies and every shared one.
  Future<void> _ensureAgencyNameFree(
    String name, {
    required String diverId,
    String? exceptId,
  }) async {
    final lower = name.toLowerCase();
    final builtIn = CertificationAgency.values.any(
      (a) => a.displayName.toLowerCase() == lower || a.name.toLowerCase() == lower,
    );
    if (builtIn) throw CertificationNameTakenException(name);
    final clash = (await getAllAgencies()).any(
      (a) =>
          a.id != exceptId &&
          (a.diverId == diverId || a.isShared) &&
          a.name.toLowerCase() == lower,
    );
    if (clash) throw CertificationNameTakenException(name);
  }

  /// The agency's built-in levels and the custom levels of it the diver can
  /// see (own, or shared).
  Future<void> _ensureLevelNameFree(
    String name, {
    required String agencyId,
    required String diverId,
    String? exceptId,
  }) async {
    final lower = name.toLowerCase();
    final builtInAgency = CertificationAgency.fromId(agencyId);
    if (builtInAgency != null) {
      final builtIns = CertificationLevelCatalog.levelsFor(builtInAgency);
      if (builtIns.any((l) => l.displayName.toLowerCase() == lower)) {
        throw CertificationNameTakenException(name);
      }
    }
    final clash = (await getAllLevels()).any(
      (l) =>
          l.id != exceptId &&
          l.agencyId == agencyId &&
          (l.diverId == diverId || l.isShared || builtInAgency == null) &&
          l.name.toLowerCase() == lower,
    );
    if (clash) throw CertificationNameTakenException(name);
  }

  Future<int> _nextSortOrder(String agencyId) async {
    final row = await _db.customSelect(
      'SELECT MAX(sort_order) AS m FROM custom_certification_levels '
      'WHERE agency_id = ? AND is_progression = 1',
      variables: [Variable.withString(agencyId)],
    ).getSingle();
    final max = row.data['m'] as int?;
    return max == null ? 0 : max + 1;
  }

  Future<void> _markPending(String type, String id, int now) async {
    await _syncRepository.markRecordPending(
      entityType: type,
      recordId: id,
      localUpdatedAt: now,
    );
    SyncEventBus.notifyLocalChange();
  }
}
```

Note on `_ensureLevelNameFree`: under a custom agency every level of that agency is checked regardless of owner, because those levels follow the agency's visibility.

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/features/certification_agencies/`
Expected: PASS.

- [ ] **Step 6: Architecture guards and commit**

```bash
dart format .
flutter analyze
flutter test test/architecture/
git add lib/features/certification_agencies/ test/features/certification_agencies/
git commit -m "feat(certification-agencies): custom agency and level repository"
```

If an architecture guard flags the `COUNT(*)` query, read its message and use the exemption comment form it asks for.

---

### Task 4: CertificationCatalog and ranking

**Files:**
- Create: `lib/features/certification_agencies/domain/certification_catalog.dart`
- Modify: `lib/features/certifications/domain/certification_primary.dart`
- Test: `test/features/certification_agencies/domain/certification_catalog_test.dart`
- Test: `test/features/certifications/domain/certification_primary_test.dart` (exists; extend)

**Interfaces:**
- Consumes: Task 1 enums/catalog, Task 3 entities and `defaultAgencyColorArgb`, `secondaryAgencyColor`.
- Produces:
  - `class AgencyEntry` fields: `String id`, `String name`, `Color primaryColor`, `Color secondaryColor`, `bool isFallback`, `CertificationAgency? builtIn`, `CustomCertificationAgency? custom`; getters `bool get isBuiltIn`, `bool get isSlugFallback`, `String get interchangeName`.
  - `class LevelEntry` fields: `String id`, `String name`, `String? agencyId`, `bool isProgression`, `bool isFallback`, `CertificationLevel? builtIn`, `CustomCertificationLevel? custom`; getters `isBuiltIn`, `isSlugFallback`, `isInstructorLevel`, `interchangeName`.
  - `class CertificationCatalog`:
    - `CertificationCatalog({List<CustomCertificationAgency> agencies = const [], List<CustomCertificationLevel> levels = const [], String? viewerDiverId})`
    - `static final CertificationCatalog builtInOnly`
    - `List<AgencyEntry> get agencies` (picker list)
    - `AgencyEntry agency(String? id)`
    - `LevelEntry level(String id)`
    - `List<LevelEntry> ladderFor(String? agencyId)`, `List<LevelEntry> specialtiesFor(String? agencyId)`, `List<LevelEntry> levelsFor(String? agencyId, {String? ensure})`
    - `int rankOf(String? agencyId, String? levelId)`
    - `bool canEditAgency(String id)`, `bool canEditLevel(String id)` (viewer owns it)
    - `List<CustomCertificationLevel> ownCustomLevelsOf(String agencyId)` (for the editor)
    - `CustomCertificationAgency? customAgency(String id)`, `CustomCertificationLevel? customLevel(String id)`
  - `bool looksLikeSlug(String id)` top-level.
  - `primaryCertification(List<Certification> certs, {CertificationCatalog? catalog})` (defaults to `builtInOnly`).

- [ ] **Step 1: Write the failing catalog tests**

```dart
// test/features/certification_agencies/domain/certification_catalog_test.dart
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/certification_levels.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/certification_agencies/domain/certification_catalog.dart';
import 'package:submersion/features/certification_agencies/domain/entities/custom_certification_agency.dart';
import 'package:submersion/features/certification_agencies/domain/entities/custom_certification_level.dart';

final _t = DateTime(2026);

CustomCertificationAgency agency(String id, String owner,
        {String name = 'Club X', bool shared = false}) =>
    CustomCertificationAgency(
        id: id, diverId: owner, name: name, colorArgb: 0xFF3B82F6,
        isShared: shared, createdAt: _t, updatedAt: _t);

CustomCertificationLevel level(String id, String owner, String agencyId,
        {String name = 'Lvl', bool progression = true, int order = 0,
        bool shared = false}) =>
    CustomCertificationLevel(
        id: id, diverId: owner, agencyId: agencyId, name: name,
        isProgression: progression, sortOrder: order, isShared: shared,
        createdAt: _t, updatedAt: _t);

void main() {
  test('built-ins resolve to their enum with brand colours', () {
    final e = CertificationCatalog.builtInOnly.agency('acuc');
    expect(e.builtIn, CertificationAgency.acuc);
    expect(e.primaryColor, CertificationAgency.acuc.primaryColor);
    expect(e.isFallback, isFalse);
  });

  test('null agency behaves like Other', () {
    expect(CertificationCatalog.builtInOnly.agency(null).builtIn,
        CertificationAgency.other);
  });

  test('a custom agency resolves with its stored and derived colours', () {
    final c = CertificationCatalog(agencies: [agency('u1', 'a')], viewerDiverId: 'a');
    final e = c.agency('u1');
    expect(e.name, 'Club X');
    expect(e.primaryColor.toARGB32(), 0xFF3B82F6);
    expect(e.isBuiltIn, isFalse);
  });

  test('resolves an invisible custom agency by name', () {
    final c = CertificationCatalog(
        agencies: [agency('u1', 'b', shared: false)], viewerDiverId: 'a');
    expect(c.agency('u1').name, 'Club X');
    expect(c.agencies.map((e) => e.id), isNot(contains('u1')));
  });

  test('pickers show own and shared agencies between built-ins and Other', () {
    final c = CertificationCatalog(agencies: [
      agency('own', 'a', name: 'Zeta'),
      agency('shared', 'b', name: 'Alpha', shared: true),
      agency('private', 'b', name: 'Hidden'),
    ], viewerDiverId: 'a');
    final ids = c.agencies.map((e) => e.id).toList();
    expect(ids.last, 'other');
    expect(ids.sublist(ids.length - 3, ids.length - 1), ['shared', 'own']);
    expect(ids, isNot(contains('private')));
  });

  test('unknown slug ids display as themselves; UUIDs are flagged unknown', () {
    final slug = CertificationCatalog.builtInOnly.agency('newAgency');
    expect(slug.isFallback, isTrue);
    expect(slug.isSlugFallback, isTrue);
    expect(slug.name, 'newAgency');
    expect(slug.primaryColor, CertificationAgency.other.primaryColor);
    final uuid = CertificationCatalog.builtInOnly
        .agency('2b1f7c3e-9d8a-4c55-8e21-0f6a1b2c3d4e');
    expect(uuid.isFallback, isTrue);
    expect(uuid.isSlugFallback, isFalse);
    expect(uuid.interchangeName, 'Unknown agency');
  });

  test('ladder is built-ins then visible custom rungs in sort order', () {
    final c = CertificationCatalog(levels: [
      level('r2', 'a', 'padi', name: 'Ice Instructor', order: 1),
      level('r1', 'a', 'padi', name: 'Ice Diver', order: 0),
      level('s1', 'a', 'padi', name: 'Altitude', progression: false),
      level('hidden', 'b', 'padi', name: 'Private'),
    ], viewerDiverId: 'a');
    final builtIn = CertificationLevelCatalog.ladderFor(CertificationAgency.padi);
    final ladder = c.ladderFor('padi').map((e) => e.id).toList();
    expect(ladder.sublist(0, builtIn.length), builtIn.map((l) => l.name));
    expect(ladder.sublist(builtIn.length), ['r1', 'r2']);
    expect(c.specialtiesFor('padi').map((e) => e.id), contains('s1'));
    expect(ladder, isNot(contains('hidden')));
  });

  test('levels of a custom agency follow the agency visibility', () {
    final c = CertificationCatalog(
      agencies: [agency('ag', 'b', shared: true)],
      levels: [level('l1', 'b', 'ag', shared: false)],
      viewerDiverId: 'a',
    );
    expect(c.ladderFor('ag').map((e) => e.id), ['l1']);
  });

  test('levelsFor keeps a stored foreign value before Other', () {
    final ids = CertificationCatalog.builtInOnly
        .levelsFor('dan', ensure: 'openWater')
        .map((e) => e.id)
        .toList();
    expect(ids.last, 'other');
    expect(ids[ids.length - 2], 'openWater');
  });

  test('custom rung outranks built-ins of the same agency', () {
    final c = CertificationCatalog(
        levels: [level('r1', 'a', 'padi')], viewerDiverId: 'b');
    expect(c.rankOf('padi', 'r1'),
        greaterThan(c.rankOf('padi', 'courseDirector')));
    expect(c.rankOf('padi', null), -1);
    expect(c.rankOf('padi', 'nitrox'), -1);
  });

  test('ownership drives canEdit', () {
    final c = CertificationCatalog(
        agencies: [agency('u1', 'a', shared: true)], viewerDiverId: 'b');
    expect(c.canEditAgency('u1'), isFalse);
    expect(c.canEditAgency('padi'), isFalse);
  });
}
```

Extend `test/features/certifications/domain/certification_primary_test.dart` (read it first for its `cert(...)` helper) with:

```dart
  test('a custom progression rung beats every built-in rung (issue #690)', () {
    final catalog = CertificationCatalog(levels: [
      CustomCertificationLevel(
          id: 'ice', diverId: 'a', agencyId: 'padi', name: 'Ice',
          isProgression: true, createdAt: DateTime(2026), updatedAt: DateTime(2026)),
    ]);
    final ice = cert(agency: 'padi', level: 'ice');
    final cd = cert(agency: 'padi', level: 'courseDirector');
    expect(primaryCertification([cd, ice], catalog: catalog), ice);
  });
```

(Its `cert` helper takes enums today; Task 6 changes it to String ids. Write this test now with String ids and leave it failing to compile until Task 6 if the helper is enum-typed; or, if simpler, add it in Task 6 Step 1 instead. Choose one and note it in the commit.)

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/certification_agencies/domain/certification_catalog_test.dart`
Expected: compile error, catalog missing.

- [ ] **Step 3: Write the catalog**

```dart
// lib/features/certification_agencies/domain/certification_catalog.dart
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

import 'package:submersion/core/constants/certification_levels.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/certification_agencies/domain/agency_colors.dart';
import 'package:submersion/features/certification_agencies/domain/entities/custom_certification_agency.dart';
import 'package:submersion/features/certification_agencies/domain/entities/custom_certification_level.dart';

final _slug = RegExp(r'^[a-z][A-Za-z0-9]*$');

/// True for an id shaped like a built-in enum name (a newer build's
/// built-in this build does not know), false for a UUID.
bool looksLikeSlug(String id) => _slug.hasMatch(id);

/// One agency as every screen sees it: a built-in, a custom row, or a
/// fallback for an id nothing here knows (issue #690).
class AgencyEntry extends Equatable {
  final String id;
  final String name;
  final Color primaryColor;
  final Color secondaryColor;
  final bool isFallback;
  final CertificationAgency? builtIn;
  final CustomCertificationAgency? custom;

  const AgencyEntry({
    required this.id,
    required this.name,
    required this.primaryColor,
    required this.secondaryColor,
    this.isFallback = false,
    this.builtIn,
    this.custom,
  });

  bool get isBuiltIn => builtIn != null;
  bool get isSlugFallback => isFallback && looksLikeSlug(id);

  /// English text for interchange (UDDF, CSV, PDF): the built-in display
  /// name, the custom name, the slug, or "Unknown agency".
  String get interchangeName {
    if (builtIn != null) return builtIn!.displayName;
    if (isFallback && !isSlugFallback) return 'Unknown agency';
    return name;
  }

  @override
  List<Object?> get props => [id, name, primaryColor, secondaryColor, isFallback];
}

class LevelEntry extends Equatable {
  final String id;
  final String name;
  final String? agencyId;
  final bool isProgression;
  final bool isFallback;
  final CertificationLevel? builtIn;
  final CustomCertificationLevel? custom;

  const LevelEntry({
    required this.id,
    required this.name,
    this.agencyId,
    this.isProgression = false,
    this.isFallback = false,
    this.builtIn,
    this.custom,
  });

  bool get isBuiltIn => builtIn != null;
  bool get isSlugFallback => isFallback && looksLikeSlug(id);

  /// Custom and fallback levels never qualify as instructor grades.
  bool get isInstructorLevel => builtIn?.isInstructorLevel ?? false;

  String get interchangeName {
    if (builtIn != null) return builtIn!.displayName;
    if (isFallback && !isSlugFallback) return 'Unknown certification';
    return name;
  }

  @override
  List<Object?> get props => [id, name, agencyId, isProgression, isFallback];
}

/// Built-in agencies and levels merged with custom rows (issue #690).
///
/// Holds every custom row (so any stored id resolves, visible or not) and
/// filters pickers by what [viewerDiverId] can see: own rows and shared
/// ones. A level under a custom agency follows that agency's visibility.
class CertificationCatalog {
  CertificationCatalog({
    List<CustomCertificationAgency> agencies = const [],
    List<CustomCertificationLevel> levels = const [],
    this.viewerDiverId,
  }) : _agencies = {for (final a in agencies) a.id: a},
       _levels = {for (final l in levels) l.id: l};

  static final CertificationCatalog builtInOnly = CertificationCatalog();

  final String? viewerDiverId;
  final Map<String, CustomCertificationAgency> _agencies;
  final Map<String, CustomCertificationLevel> _levels;

  CustomCertificationAgency? customAgency(String id) => _agencies[id];
  CustomCertificationLevel? customLevel(String id) => _levels[id];

  bool _agencyVisible(CustomCertificationAgency a) =>
      a.isShared || a.diverId == viewerDiverId;

  bool _levelVisible(CustomCertificationLevel l) {
    final parent = _agencies[l.agencyId];
    if (parent != null) return _agencyVisible(parent);
    return l.isShared || l.diverId == viewerDiverId;
  }

  bool canEditAgency(String id) {
    final a = _agencies[id];
    return a != null && viewerDiverId != null && a.diverId == viewerDiverId;
  }

  bool canEditLevel(String id) {
    final l = _levels[id];
    return l != null && viewerDiverId != null && l.diverId == viewerDiverId;
  }

  AgencyEntry _builtInAgency(CertificationAgency a) => AgencyEntry(
    id: a.name,
    name: a.displayName,
    primaryColor: a.primaryColor,
    secondaryColor: a.secondaryColor,
    builtIn: a,
  );

  AgencyEntry _customAgency(CustomCertificationAgency a) {
    final primary = Color(a.colorArgb);
    return AgencyEntry(
      id: a.id,
      name: a.name,
      primaryColor: primary,
      secondaryColor: secondaryAgencyColor(primary),
      custom: a,
    );
  }

  /// Picker order: built-ins (enum order), visible custom agencies by name,
  /// then Other.
  List<AgencyEntry> get agencies {
    final custom = _agencies.values.where(_agencyVisible).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return [
      for (final a in CertificationAgency.values)
        if (a != CertificationAgency.other) _builtInAgency(a),
      for (final a in custom) _customAgency(a),
      _builtInAgency(CertificationAgency.other),
    ];
  }

  AgencyEntry agency(String? id) {
    if (id == null) return _builtInAgency(CertificationAgency.other);
    final builtIn = CertificationAgency.fromId(id);
    if (builtIn != null) return _builtInAgency(builtIn);
    final custom = _agencies[id];
    if (custom != null) return _customAgency(custom);
    return AgencyEntry(
      id: id,
      name: id,
      primaryColor: CertificationAgency.other.primaryColor,
      secondaryColor: CertificationAgency.other.secondaryColor,
      isFallback: true,
    );
  }

  LevelEntry _builtInLevel(CertificationLevel l, {bool progression = false}) =>
      LevelEntry(id: l.name, name: l.displayName, isProgression: progression, builtIn: l);

  LevelEntry _customLevel(CustomCertificationLevel l) => LevelEntry(
    id: l.id,
    name: l.name,
    agencyId: l.agencyId,
    isProgression: l.isProgression,
    custom: l,
  );

  LevelEntry level(String id) {
    final builtIn = CertificationLevel.fromId(id);
    if (builtIn != null) return _builtInLevel(builtIn);
    final custom = _levels[id];
    if (custom != null) return _customLevel(custom);
    return LevelEntry(id: id, name: id, isFallback: true);
  }

  List<CustomCertificationLevel> _customRungs(String agencyId, {required bool visibleOnly}) =>
      _levels.values
          .where((l) => l.agencyId == agencyId && l.isProgression)
          .where((l) => !visibleOnly || _levelVisible(l))
          .toList()
        ..sort((a, b) {
          final byOrder = a.sortOrder.compareTo(b.sortOrder);
          return byOrder != 0 ? byOrder : a.name.compareTo(b.name);
        });

  List<LevelEntry> ladderFor(String? agencyId) {
    final builtInAgency = CertificationAgency.fromId(agencyId);
    final builtIn = CertificationLevelCatalog.ladderFor(builtInAgency);
    return [
      for (final l in builtIn) _builtInLevel(l, progression: true),
      if (agencyId != null)
        for (final l in _customRungs(agencyId, visibleOnly: true)) _customLevel(l),
    ];
  }

  List<LevelEntry> specialtiesFor(String? agencyId) {
    final builtInAgency = CertificationAgency.fromId(agencyId);
    final custom = agencyId == null
        ? <CustomCertificationLevel>[]
        : (_levels.values
              .where((l) => l.agencyId == agencyId && !l.isProgression)
              .where(_levelVisible)
              .toList()
            ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())));
    return [
      for (final l in CertificationLevelCatalog.specialtiesFor(builtInAgency))
        _builtInLevel(l),
      for (final l in custom) _customLevel(l),
    ];
  }

  /// Ladder, specialties, then [ensure] when it is set, not Other and not
  /// already listed, then Other. Mirrors CertificationLevelCatalog.levelsFor.
  List<LevelEntry> levelsFor(String? agencyId, {String? ensure}) {
    final result = [...ladderFor(agencyId), ...specialtiesFor(agencyId)];
    if (ensure != null &&
        ensure != CertificationLevel.other.name &&
        !result.any((e) => e.id == ensure)) {
      result.add(level(ensure));
    }
    result.add(_builtInLevel(CertificationLevel.other));
    return result;
  }

  /// Rank for primaryCertification: index in the agency's built-in ladder,
  /// then built-in length plus position among ALL of the agency's custom
  /// rungs (visibility does not change rank). -1 for null, specialties and
  /// unknown ids.
  int rankOf(String? agencyId, String? levelId) {
    if (levelId == null) return -1;
    final builtIn = CertificationLevelCatalog.ladderFor(
      CertificationAgency.fromId(agencyId),
    );
    final builtInLevel = CertificationLevel.fromId(levelId);
    if (builtInLevel != null) return builtIn.indexOf(builtInLevel);
    if (agencyId == null) return -1;
    final rungs = _customRungs(agencyId, visibleOnly: false);
    final i = rungs.indexWhere((l) => l.id == levelId);
    return i < 0 ? -1 : builtIn.length + i;
  }

  /// The viewer's own custom levels of [agencyId], for the editor.
  List<CustomCertificationLevel> ownCustomLevelsOf(String agencyId) =>
      _levels.values
          .where((l) => l.agencyId == agencyId && l.diverId == viewerDiverId)
          .toList();
}
```

- [ ] **Step 4: Switch primaryCertification to the catalog**

Replace the body's `rank` in `certification_primary.dart`:

```dart
Certification? primaryCertification(
  List<Certification> certs, {
  CertificationCatalog? catalog,
}) {
  if (certs.isEmpty) return null;
  final c = catalog ?? CertificationCatalog.builtInOnly;

  int rank(Certification cert) => c.rankOf(cert.agency, cert.level);
  // ... sort unchanged ...
}
```

Update the doc comment: rank comes from `CertificationCatalog.rankOf`; custom rungs rank after the agency's built-in ladder. Update imports (drop `certification_levels.dart`, add the catalog). This compiles only after Task 6 makes `Certification.agency/level` Strings; until then it is a type error. **Therefore do Step 4 as the first step of Task 6** and run only the catalog tests now.

- [ ] **Step 5: Run catalog tests**

Run: `flutter test test/features/certification_agencies/domain/`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
dart format .
flutter analyze
git add lib/features/certification_agencies/domain/certification_catalog.dart test/features/certification_agencies/domain/certification_catalog_test.dart
git commit -m "feat(certification-agencies): catalog merging built-in and custom entries"
```

---

### Task 5: Sync wiring

**Files:**
- Modify: `lib/core/services/sync/sync_data_serializer.dart` (every site naming `diveRoles`: `grep -n "diveRoles\|DiveRoles" lib/core/services/sync/sync_data_serializer.dart` lists them: field ~L317, constructor default ~L427, `toJson` ~L532, `fromJson` ~L640, export descriptor ~L1094, `_safeExport` ~L2226, then the switch sites ~L2988, ~L3422, ~L4580, ~L5820, ~L6356, ~L6496, ~L6761, ~L7255, and `_exportDiveRoles` ~L8285)
- Modify: `lib/core/services/sync/sync_service.dart` (merge order ~L1502; `entityHasUpdatedAt` ~L2560)
- Modify: `lib/core/data/repositories/sync_repository.dart` (~L96)
- Modify: `test/core/services/sync/sync_parent_refs_completeness_test.dart` (`syncedTables`)
- Test: `test/core/services/sync/sync_custom_certifications_test.dart`

**Interfaces:**
- Consumes: Task 2 row classes `CustomCertificationAgencyRow`, `CustomCertificationLevelRow`.
- Produces: sync entity types `'customCertificationAgencies'`, `'customCertificationLevels'`; `SyncData.customCertificationAgencies`, `SyncData.customCertificationLevels`.

- [ ] **Step 1: Write the failing sync test**

Read `test/core/services/sync/sync_dive_roles_test.dart` first and mirror its setup exactly (it is the closest entity). Then:

```dart
// test/core/services/sync/sync_custom_certifications_test.dart
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';

import '../../../helpers/test_database.dart';

void main() {
  late SyncDataSerializer serializer;

  setUp(() async {
    final db = await setUpTestDatabase();
    await db.customStatement(
      "INSERT INTO divers (id, name, created_at, updated_at) VALUES ('a', 'A', 0, 0)",
    );
    serializer = SyncDataSerializer();
  });
  tearDown(tearDownTestDatabase);

  Map<String, dynamic> agencyJson(String id) => {
    'id': id, 'diverId': 'a', 'name': 'Club X', 'colorArgb': 0xFF3B82F6,
    'isShared': true, 'createdAt': 1000, 'updatedAt': 1000, 'hlc': null,
  };

  Map<String, dynamic> levelJson(String id, {String agencyId = 'ag1', int order = 0}) => {
    'id': id, 'diverId': 'a', 'agencyId': agencyId, 'name': 'L$id',
    'isProgression': true, 'sortOrder': order, 'isShared': false,
    'createdAt': 1000, 'updatedAt': 1000, 'hlc': null,
  };

  test('agencies round-trip through single and batch paths', () async {
    await serializer.upsertRecord('customCertificationAgencies', agencyJson('ag1'));
    final row = await serializer.fetchRecord('customCertificationAgencies', 'ag1');
    expect(row!['name'], 'Club X');
    expect(row['isShared'], isTrue);
    await serializer.upsertRecords('customCertificationAgencies', [agencyJson('ag2')]);
    expect(await serializer.recordIdsFor('customCertificationAgencies'),
        containsAll(['ag1', 'ag2']));
    await serializer.deleteRecord('customCertificationAgencies', 'ag1');
    expect(await serializer.fetchRecord('customCertificationAgencies', 'ag1'), isNull);
  });

  test('a level applies before its agency arrives, and sort order survives', () async {
    await serializer.upsertRecords('customCertificationLevels', [
      levelJson('l1', order: 1),
      levelJson('l2', order: 0),
    ]);
    final rows = await serializer.fetchRecords('customCertificationLevels', ['l1', 'l2']);
    expect(rows['l1']!['sortOrder'], 1);
    expect(rows['l2']!['sortOrder'], 0);
  });

  test('both are clocked entities, agencies merged before levels', () {
    expect(SyncService.entityHasUpdatedAt['customCertificationAgencies'], isTrue);
    expect(SyncService.entityHasUpdatedAt['customCertificationLevels'], isTrue);
  });
}
```

If `sync_dive_roles_test.dart` asserts merge order via a public list, add an equivalent assertion that `customCertificationAgencies` precedes `customCertificationLevels`.

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/core/services/sync/sync_custom_certifications_test.dart`
Expected: FAIL (unknown entity type).

- [ ] **Step 3: Register both entities**

At every `diveRoles` site in `sync_data_serializer.dart`, add two twins directly after it, same shape, substituting names:

- Fields: `final List<Map<String, dynamic>> customCertificationAgencies;` and `...Levels;`
- Constructor defaults: `this.customCertificationAgencies = const [],` and levels.
- `toJson`: `'customCertificationAgencies': customCertificationAgencies,` and levels.
- `fromJson`: `customCertificationAgencies: _parseList(json['customCertificationAgencies']),` and levels.
- Export descriptor (copy the `diveRoles` descriptor at ~L1094 and change key/table/export fn; use `full: () => _exportCustomCertificationAgencies(null)` if the dive roles one uses `full:`).
- `_safeExport`: `customCertificationAgencies: await _safeExport('customCertificationAgencies', () => _exportCustomCertificationAgencies(hlcSince)),` and levels.
- Each `case 'diveRoles':` switch arm: copy it verbatim into `case 'customCertificationAgencies':` and `case 'customCertificationLevels':`, replacing `_db.diveRoles` with `_db.customCertificationAgencies` / `_db.customCertificationLevels` and `DiveRoleRow` with `CustomCertificationAgencyRow` / `CustomCertificationLevelRow`. Where the dive roles arm special-cases built-ins (`isBuiltIn`), drop that special case: these tables have no built-ins.
- Export functions, after `_exportDiveRoles`:

```dart
  Future<List<Map<String, dynamic>>> _exportCustomCertificationAgencies(
    String? hlcSince,
  ) async {
    final query = _db.select(_db.customCertificationAgencies);
    if (hlcSince != null) {
      query.where((t) => t.hlc.isBiggerThanValue(hlcSince));
    }
    final rows = await query.get();
    return rows.map((r) => r.toJson()).toList();
  }
```

and the same for levels. Before writing these, read `_exportDiveRoles` and copy its HLC filter expression exactly (it may use a helper rather than `isBiggerThanValue`); keep everything except the `isBuiltIn.equals(false)` filter.

`sync_service.dart` merge order, after the diveRoles entry:

```dart
          (
            type: 'customCertificationAgencies',
            records: data.customCertificationAgencies,
            hasUpdatedAt: true,
          ),
          (
            type: 'customCertificationLevels',
            records: data.customCertificationLevels,
            hasUpdatedAt: true,
          ),
```

`entityHasUpdatedAt`: `'customCertificationAgencies': true, 'customCertificationLevels': true,`.

`sync_repository.dart` clock targets:

```dart
    'customCertificationAgencies': (table: 'custom_certification_agencies', pk: 'id'),
    'customCertificationLevels': (table: 'custom_certification_levels', pk: 'id'),
```

`sync_parent_refs_completeness_test.dart` `syncedTables`:

```dart
    'custom_certification_agencies': 'customCertificationAgencies',
    'custom_certification_levels': 'customCertificationLevels',
```

No `parentRefs` entry is needed: the only FK is `diver_id`, and divers are excluded from deletable parents (see that test's comment).

- [ ] **Step 4: Run sync suites**

Run: `flutter test test/core/services/sync/`
Expected: PASS. If a test enumerates every SyncData key or table (search the failure for a list literal), add the two new entities there.

- [ ] **Step 5: Commit**

```bash
dart format .
flutter analyze
git add lib/core/services/sync/ lib/core/data/repositories/sync_repository.dart test/core/services/sync/
git commit -m "feat(certification-agencies): sync custom agencies and levels"
```

---

### Task 6: String ids in the domain, no more silent "Other"

This is the large mechanical task. The analyzer is the completeness check: when `flutter analyze` is clean and the suites below pass, it is done.

**Files:**
- Modify: `lib/features/certifications/domain/entities/certification.dart`
- Modify: `lib/features/certifications/domain/certification_primary.dart` (Task 4 Step 4)
- Modify: `lib/features/certifications/domain/certification_title.dart`
- Modify: `lib/features/certifications/data/repositories/certification_repository.dart` (~L203, ~L255, ~L366, ~L437-449)
- Modify: `lib/features/courses/domain/entities/course.dart`, `lib/features/courses/data/repositories/course_repository.dart` (~L554-574)
- Modify: `lib/features/buddies/domain/entities/buddy.dart`, `lib/features/buddies/data/repositories/buddy_repository.dart` (~L937-945, ~L1208-1267)
- Modify: `lib/core/database/migrations/helpers/buddy_migrations.dart` (~L205-216)
- Modify: every other lib file the analyzer flags (the Explore report lists them: field extractors, providers, pickers, PDF, card renderer, query entity/labels, import/export)
- Test: `test/features/certifications/data/certification_unknown_id_test.dart`
- Test: every existing test the analyzer flags

**Interfaces:**
- Consumes: Task 4 `CertificationCatalog`.
- Produces: `Certification.agency: String`, `Certification.level: String?`, `CertificationCredential.agency: String`, `.level: String?`, `Course.agency: String` (default `'padi'`), `Buddy.certificationAgency: String?`, `Buddy.certificationLevel: String?`. Repository filter methods take `String agencyId`.

- [ ] **Step 1: Write the failing survival test**

```dart
// test/features/certifications/data/certification_unknown_id_test.dart
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/certifications/data/repositories/certification_repository.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/courses/data/repositories/course_repository.dart';

import '../../../helpers/test_database.dart';

/// Issue #690: an agency or level id this build does not know (a custom row
/// not yet synced, or a newer build's built-in) used to parse as "Other"
/// and be lost on the next save.
void main() {
  late AppDatabase db;

  setUp(() async => db = await setUpTestDatabase());
  tearDown(tearDownTestDatabase);

  const unknownAgency = '2b1f7c3e-9d8a-4c55-8e21-0f6a1b2c3d4e';
  const unknownLevel = 'futureLevel';

  test('unknown stored ids survive load and save', () async {
    await db.customStatement(
      "INSERT INTO certifications (id, name, agency, level, additional_credentials, notes, created_at, updated_at) "
      "VALUES ('c1', 'Card', '$unknownAgency', '$unknownLevel', "
      "'[{\"agency\":\"$unknownAgency\",\"level\":\"$unknownLevel\"}]', '', 0, 0)",
    );
    final repo = CertificationRepository();
    final cert = (await repo.getCertificationById('c1'))!;
    expect(cert.agency, unknownAgency);
    expect(cert.level, unknownLevel);
    expect(cert.additionalCredentials.single,
        const CertificationCredential(agency: unknownAgency, level: unknownLevel));

    await repo.updateCertification(cert.copyWith(notes: 'edited'));
    final row = await (db.select(db.certifications)
          ..where((t) => t.id.equals('c1')))
        .getSingle();
    expect(row.agency, unknownAgency);
    expect(row.level, unknownLevel);
    expect(row.additionalCredentials, contains(unknownAgency));
  });

  test('an unknown course agency survives load', () async {
    await db.customStatement(
      "INSERT INTO courses (id, name, agency, created_at, updated_at) "
      "VALUES ('k1', 'Course', '$unknownAgency', 0, 0)",
    );
    final course = await CourseRepository().getCourseById('k1');
    expect(course!.agency, unknownAgency);
  });
}
```

Check the real method names first (`grep -n "Future<.*> \(get\|update\)" lib/features/certifications/data/repositories/certification_repository.dart lib/features/courses/data/repositories/course_repository.dart`) and the `courses` NOT NULL columns (`buddy_tables.dart` ~L169), and adjust the test to them.

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/certifications/data/certification_unknown_id_test.dart`
Expected: compile failure (`agency` is an enum).

- [ ] **Step 3: Change the entities**

`certification.dart`: `CertificationCredential.agency` becomes `final String agency;`, `level` becomes `final String? level;`. Replace `toJson`/`fromJson`:

```dart
  Map<String, dynamic> toJson() => {
    'agency': agency,
    if (level != null) 'level': level,
  };

  /// Ids are kept verbatim: an id this build does not know (a custom agency
  /// not yet synced, a newer build's built-in) must survive a save, never
  /// collapse to "Other" (issue #690). A missing agency is Other.
  factory CertificationCredential.fromJson(Map<String, dynamic> json) =>
      CertificationCredential(
        agency: (json['agency'] as String?) ?? CertificationAgency.other.name,
        level: json['level'] as String?,
      );
```

`Certification.agency` -> `String`, `level` -> `String?`, and the same in `copyWith`. Drop the `enums.dart` import if unused (keep it for `CertificationAgency.other.name`).

`course.dart`: `final String agency;`, constructor default `this.agency = 'padi'` only if the current constructor has a default of `CertificationAgency.padi` (keep the existing required/optional shape), `copyWith` parameters `String? agency`.

`buddy.dart`: `final String? certificationLevel; final String? certificationAgency;`. Its English line (~L56-66) used `certificationLevel?.displayName` and the agency's displayName: change to `CertificationCatalog.builtInOnly.level(id).interchangeName` and `.agency(id).interchangeName` so built-ins read exactly as before and custom ids read as their id until Task 7 replaces display paths with catalog-aware ones.

- [ ] **Step 4: Repositories: write ids, read ids verbatim**

`certification_repository.dart`: writes become `agency: Value(cert.agency)`, `level: Value(cert.level)`. Delete `_parseCertificationAgency` / `_parseCertificationLevel`; the mappers read `agency: row.agency` and `level: row.level` (and the query-row mapper `row.read<String>('agency')`, `row.readNullable<String>('level')`). `getCertificationsByAgency(String agencyId)` filters `t.agency.equals(agencyId)`.

`course_repository.dart`: same: write `Value(course.agency)`, read `row.agency`, delete the parse helper, filter by `String`.

`buddy_repository.dart`: the dead parse at ~L937-945 (columns dropped in v110) is removed: the buddy's level and agency come only from `_withPrimaryCerts`. In `_withPrimaryCerts` (~L1208-1230) pass the catalog to `primaryCertification`: load custom rows once per call with `CustomCertificationRepository().getAllAgencies()` / `getAllLevels()` and build `CertificationCatalog(agencies: ..., levels: ...)` (no viewer: ranking ignores visibility). Assign `certificationLevel: primary?.level`, `certificationAgency: primary?.agency`. Remove the `orElse` parse at ~L1253-1267.

`buddy_migrations.dart` (~L205-216): this is a one-off migration that builds a display name; replace the enum parse with `CertificationAgency.fromId(value)?.displayName ?? value` and the same for levels. Do not change what the migration writes for known values.

Apply Task 4 Step 4 (`primaryCertification` with the catalog).

- [ ] **Step 5: Fix every remaining lib call site**

Run `flutter analyze` and fix each error by these rules, in order of preference:

| Old pattern | New pattern |
| --- | --- |
| `cert.agency == CertificationAgency.padi` | `cert.agency == CertificationAgency.padi.name` |
| `agency: CertificationAgency.x` (constructing) | `agency: CertificationAgency.x.name` |
| `level: CertificationLevel.x` | `level: CertificationLevel.x.name` |
| `cert.agency.displayName` / `.name` used for interchange text | `CertificationCatalog.builtInOnly.agency(cert.agency).interchangeName` (Task 7 swaps UI paths to the provider catalog; data-layer and interchange paths keep `builtInOnly` until Tasks 7 and 10 thread the real catalog) |
| `cert.agency.primaryColor` | `CertificationCatalog.builtInOnly.agency(cert.agency).primaryColor` (Task 7 swaps to provider) |
| `cert.agency.localizedName(l10n)` in widgets | `CertificationCatalog.builtInOnly.agency(cert.agency).localizedName(l10n)` once Task 7's display extension exists; until then `CertificationAgency.fromId(cert.agency)?.localizedName(l10n) ?? cert.agency` |
| `level.isInstructorLevel` on a stored level | `CertificationLevel.fromId(id)?.isInstructorLevel ?? false` |
| `CertificationLevelCatalog.levelsFor(agency).contains(level)` in the edit page | leave the edit page compiling with `CertificationAgency.fromId(...)` conversions; Task 8 rewrites it on the catalog |

The certification query entity's `enumValues` stay `.name` lists (unchanged). `app_query_labels.dart` keeps `byName` for now (Task 11).

UDDF export writes `.name` today; with String fields it writes the id unchanged, which is correct for built-ins (Task 10 handles custom names).

- [ ] **Step 6: Fix the tests**

Run `flutter analyze` again; it now lists test files. Apply the same table rules. For bulk constructor rewrites a script is acceptable: write it to the scratchpad, run it with `python3.14`, and inspect `git diff --stat` afterwards. Example rewrite (run per file the analyzer flags, never repo-wide blind):

```python
import re, sys
for path in sys.argv[1:]:
    raw = open(path, 'rb').read()
    crlf = b'\r\n' in raw
    text = raw.decode('utf-8')
    text = re.sub(r'(\b(?:agency|level|certificationAgency|certificationLevel):\s*)(CertificationAgency|CertificationLevel)\.(\w+)(?!\.name)',
                  r'\1\2.\3.name', text)
    out = text.encode('utf-8')
    if crlf:
        out = out.replace(b'\r\n', b'\n').replace(b'\n', b'\r\n')
    open(path, 'wb').write(out)
```

(Preserve CRLF: about 76 .dart files are CRLF; check `git diff --numstat` shows only intended lines.) Comparisons in expectations (`expect(cert.agency, CertificationAgency.padi)`) become `expect(cert.agency, CertificationAgency.padi.name)`; fix those by hand from the analyzer list.

- [ ] **Step 7: Run the affected suites**

Run: `flutter analyze` (must be clean)
Run: `flutter test test/features/certifications/ test/features/courses/ test/features/buddies/ test/features/certification_agencies/ test/core/`
Expected: PASS, including `certification_unknown_id_test.dart` and the Task 4 primary-ranking test.

- [ ] **Step 8: Commit**

```bash
dart format .
git status --short
git add <every modified lib/ and test/ path from git status>
git commit -m "refactor(certifications): store agency and level as string ids"
```

---

### Task 7: Catalog provider, display extension, readers

**Files:**
- Create: `lib/features/certification_agencies/presentation/certification_entry_display.dart`
- Create: `lib/features/certification_agencies/presentation/providers/certification_catalog_providers.dart`
- Modify: every widget/service that Task 6 left on `CertificationCatalog.builtInOnly` for display: certification detail and list content, `certification_ecard_front.dart`, `certification_ecard.dart` (semantics label ~L62), `certification_wallet_card.dart`, `certification_card_renderer.dart` (~L54, ~L57, ~L301), `buddy_list_tile.dart` (~L69), `buddy_picker.dart`, `buddy_certification_l10n.dart`, `instructor_picker_field.dart`, `certification_title.dart` / `certification_title_l10n.dart`, `certification_providers.dart` (~L95 sort), `course_providers.dart` (~L86 sort), PDF files (`pdf_front_matter.dart:182`, `pdf_shared_components.dart:324,390`, `pdf_course_export_service.dart`), field extractors (`certification_field.dart:216-219`, `buddy_field.dart:179-181`, `course_field.dart`)
- Modify: all 11 ARB files (`certificationAgencies_unknownAgency`, `certificationAgencies_unknownCertification`)
- Test: `test/features/certification_agencies/presentation/certification_entry_display_test.dart`, `test/features/certification_agencies/presentation/certification_catalog_provider_test.dart`

**Interfaces:**
- Consumes: Task 3 repository, Task 4 catalog, `validatedCurrentDiverIdProvider` (`lib/features/divers/presentation/providers/diver_providers.dart`), `ref.invalidateSelfWhen` (as `allDiveRolesProvider` uses).
- Produces:
  - `extension AgencyEntryDisplay on AgencyEntry { String localizedName(AppLocalizations l10n) }`
  - `extension LevelEntryDisplay on LevelEntry { String localizedName(AppLocalizations l10n) }`
  - `final customCertificationRepositoryProvider = Provider<CustomCertificationRepository>`
  - `final certificationCatalogProvider = FutureProvider<CertificationCatalog>`
  - `final certificationCatalogSyncProvider = Provider<CertificationCatalog>` (the loaded catalog, or `builtInOnly` while loading)

- [ ] **Step 1: ARB keys**

In `app_en.arb` (alphabetical position among `certification*` keys):

```json
  "certificationAgencies_unknownAgency": "Unknown agency",
  "@certificationAgencies_unknownAgency": {"description": "Shown for a certification agency id that matches no built-in or custom agency (not yet synced or deleted)."},
  "certificationAgencies_unknownCertification": "Unknown certification",
  "@certificationAgencies_unknownCertification": {"description": "Shown for a certification level id that matches nothing known."},
```

Translations for the other 10 locales:

| Locale | unknownAgency | unknownCertification |
| --- | --- | --- |
| ar | وكالة غير معروفة | شهادة غير معروفة |
| de | Unbekannte Organisation | Unbekanntes Brevet |
| es | Agencia desconocida | Certificación desconocida |
| fr | Organisme inconnu | Brevet inconnu |
| he | ארגון לא ידוע | הסמכה לא ידועה |
| hu | Ismeretlen szervezet | Ismeretlen minősítés |
| it | Didattica sconosciuta | Brevetto sconosciuto |
| nl | Onbekende organisatie | Onbekend brevet |
| pt | Agência desconhecida | Certificação desconhecida |
| zh | 未知机构 | 未知证书 |

Before using these, check each locale's existing `certifications_edit_label_agency` and `certifications_edit_label_certification` values and reuse the same nouns they use, so the vocabulary matches. Run `flutter gen-l10n`.

- [ ] **Step 2: Failing display and provider tests**

```dart
// test/features/certification_agencies/presentation/certification_entry_display_test.dart
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/certification_agencies/domain/certification_catalog.dart';
import 'package:submersion/features/certification_agencies/presentation/certification_entry_display.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';

void main() {
  final l10n = AppLocalizationsEn();
  final c = CertificationCatalog.builtInOnly;

  test('built-ins use their localized names', () {
    expect(c.agency('other').localizedName(l10n), 'Other');
    expect(c.level('openWater').localizedName(l10n), 'Open Water');
  });

  test('a UUID fallback reads as unknown, a slug fallback as itself', () {
    expect(c.agency('2b1f7c3e-9d8a-4c55-8e21-0f6a1b2c3d4e').localizedName(l10n),
        'Unknown agency');
    expect(c.agency('newAgency').localizedName(l10n), 'newAgency');
    expect(c.level('2b1f7c3e-9d8a-4c55-8e21-0f6a1b2c3d4e').localizedName(l10n),
        'Unknown certification');
  });
}
```

Provider test: read an existing provider test that overrides `validatedCurrentDiverIdProvider` (`grep -rln "validatedCurrentDiverIdProvider.overrideWith" test | head -3`) and mirror it: insert a diver and a custom agency with the repository, read `certificationCatalogProvider.future`, expect `catalog.agency(id).name`; then create a second agency and expect the provider to emit a catalog containing it (await `container.read(certificationCatalogProvider.future)` after `pumpEventQueue()`).

- [ ] **Step 3: Implement**

```dart
// lib/features/certification_agencies/presentation/certification_entry_display.dart
import 'package:submersion/features/certification_agencies/domain/certification_catalog.dart';
import 'package:submersion/features/certifications/presentation/certification_agency_display.dart';
import 'package:submersion/features/certifications/presentation/certification_level_display.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// On-screen names (issue #690): built-ins localize, custom names and slug
/// fallbacks are shown verbatim, an unknown UUID reads as "Unknown agency".
extension AgencyEntryDisplay on AgencyEntry {
  String localizedName(AppLocalizations l10n) {
    final b = builtIn;
    if (b != null) return b.localizedName(l10n);
    if (isFallback && !isSlugFallback) {
      return l10n.certificationAgencies_unknownAgency;
    }
    return name;
  }
}

extension LevelEntryDisplay on LevelEntry {
  String localizedName(AppLocalizations l10n) {
    final b = builtIn;
    if (b != null) return b.localizedName(l10n);
    if (isFallback && !isSlugFallback) {
      return l10n.certificationAgencies_unknownCertification;
    }
    return name;
  }
}
```

```dart
// lib/features/certification_agencies/presentation/providers/certification_catalog_providers.dart
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/certification_agencies/data/repositories/custom_certification_repository.dart';
import 'package:submersion/features/certification_agencies/domain/certification_catalog.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';

final customCertificationRepositoryProvider =
    Provider<CustomCertificationRepository>(
      (ref) => CustomCertificationRepository(),
    );

/// Built-ins plus every custom row, filtered for pickers by the active
/// diver (issue #690). Rebuilds on any write to either custom table,
/// including sync applies.
final certificationCatalogProvider = FutureProvider<CertificationCatalog>((
  ref,
) async {
  final repository = ref.watch(customCertificationRepositoryProvider);
  final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
  ref.invalidateSelfWhen(repository.watchChanges());
  final agencies = await repository.getAllAgencies();
  final levels = await repository.getAllLevels();
  return CertificationCatalog(
    agencies: agencies,
    levels: levels,
    viewerDiverId: diverId,
  );
});

/// The loaded catalog for synchronous build methods; built-ins only while
/// loading, so built-in names and colours never flicker.
final certificationCatalogSyncProvider = Provider<CertificationCatalog>(
  (ref) =>
      ref.watch(certificationCatalogProvider).value ??
      CertificationCatalog.builtInOnly,
);
```

(Match the import of `Provider` / `FutureProvider` to what `dive_role_providers.dart` imports: `package:submersion/core/providers/provider.dart`.)

- [ ] **Step 4: Swap readers to the provider catalog**

In every widget that Task 6 left on `CertificationCatalog.builtInOnly` for display, read `final catalog = ref.watch(certificationCatalogSyncProvider);` (convert a `StatelessWidget` to `ConsumerWidget` only where needed; prefer passing an `AgencyEntry` down from a parent that already watches) and use `catalog.agency(id).localizedName(context.l10n)`, `.primaryColor`, `.secondaryColor`, `catalog.level(id).localizedName(...)`.

Services without a `ref` (PDF builders, card renderer, field extractors): add a `CertificationCatalog catalog` parameter (default `CertificationCatalog.builtInOnly`) and pass `ref.read(certificationCatalogSyncProvider)` from the caller. English interchange text uses `interchangeName`.

Providers sorting by agency display name use `catalog.agency(c.agency).interchangeName.toLowerCase()`.

- [ ] **Step 5: Run**

Run: `flutter analyze`
Run: `flutter test test/features/certification_agencies/ test/features/certifications/ test/features/buddies/ test/features/courses/ test/core/services/pdf/ test/features/dive_log/`
(Use `find test -path "*pdf*" -name "*_test.dart" | head` to locate PDF tests if that path is wrong.)
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
dart format .
flutter test test/architecture/
git add <explicit paths>
git commit -m "feat(certification-agencies): resolve agency and level display through the catalog"
```

---

### Task 8: Edit-page pickers with quick-create

**Files:**
- Create: `lib/features/certification_agencies/presentation/widgets/custom_agency_dialog.dart`
- Create: `lib/features/certification_agencies/presentation/widgets/certification_level_dialog.dart`
- Modify: `lib/features/certifications/presentation/pages/certification_edit_page.dart` (~L80-81 state; ~L408-441 accessors/setters; ~L459-578 rows and items; ~L1151 `_ExtraCredential` fields)
- Modify: `lib/features/certifications/presentation/widgets/certification_option.dart`
- Modify: `lib/features/courses/presentation/pages/course_edit_page.dart` (~L145-154)
- Modify: all 11 ARB files
- Test: `test/features/certifications/presentation/pages/certification_edit_custom_entries_test.dart`
- Test: `test/features/courses/presentation/pages/course_edit_custom_agency_test.dart`

**Interfaces:**
- Consumes: Task 3 repository (`createAgency`, `createLevel`, exceptions), Task 4 catalog, Task 7 providers and display extension, `shareByDefaultProvider` (`lib/features/settings/presentation/providers/settings_providers.dart`), `diverCountProvider` or the equivalent used by the site editor to decide whether to show the share switch (find it: `grep -n "isShared\|diverCount\|divers.length" lib/features/dive_sites/presentation/pages/site_edit_page.dart | head`).
- Produces:
  - `Future<CustomCertificationAgency?> showCustomAgencyDialog(BuildContext context, WidgetRef ref, {CustomCertificationAgency? existing})`
  - `Future<CustomCertificationLevel?> showCertificationLevelDialog(BuildContext context, WidgetRef ref, {required String agencyId, CustomCertificationLevel? existing})`
  - `CertificationOption.value(String? id)`, `CertificationOption.header(String key)`, `CertificationOption.addCustom()`.

ARB keys (en values; translate for the other 10 locales using the same nouns as their existing certification strings):

| Key | en |
| --- | --- |
| `certificationAgencies_addCustomAgency` | Add custom agency... |
| `certificationAgencies_addCustomCertification` | Add custom certification... |
| `certificationAgencies_dialog_newAgencyTitle` | New agency |
| `certificationAgencies_dialog_editAgencyTitle` | Edit agency |
| `certificationAgencies_dialog_newCertificationTitle` | New certification |
| `certificationAgencies_dialog_editCertificationTitle` | Edit certification |
| `certificationAgencies_dialog_nameLabel` | Name |
| `certificationAgencies_dialog_colorLabel` | Card colour |
| `certificationAgencies_dialog_progression` | Progression |
| `certificationAgencies_dialog_specialty` | Specialty |
| `certificationAgencies_dialog_share` | Share with other divers |
| `certificationAgencies_error_nameRequired` | Enter a name |
| `certificationAgencies_error_nameTaken` | That name is already in use |

Use the `…` character for the ellipsis only if the existing ARB strings do (check `grep -n "\.\.\.\"\|…\"" lib/l10n/arb/app_en.arb | head`); match the dominant form.

- [ ] **Step 1: Failing widget tests**

Read an existing edit-page widget test (`ls test/features/certifications/presentation/pages/`) for its pump helper and provider overrides, and mirror them. Tests:

```dart
  testWidgets('custom agencies appear in the agency dropdown before Other', (tester) async {
    // seed diver 'a' and createAgency(diverId: 'a', name: 'Club X', isShared: false)
    // pump CertificationEditPage, open the agency dropdown (key 'cred-agency-0')
    // expect find.text('Club X') and find.text('Add custom agency...')
  });

  testWidgets('Add custom agency creates and selects the new agency', (tester) async {
    // open dropdown, tap 'Add custom agency...', enter 'Club Y', tap Save
    // expect repository has 'Club Y' and the dropdown shows 'Club Y'
  });

  testWidgets('a custom level appears under Progression and Add custom certification creates one', (tester) async {
    // select PADI, open the certification dropdown (key starts 'cred-level-0')
    // tap 'Add custom certification...', enter 'Ice Diver', keep Progression, Save
    // expect the dropdown shows 'Ice Diver' and the repository row isProgression
  });

  testWidgets('an unknown stored agency renders and is not reset on save', (tester) async {
    // insert a certification row with agency '2b1f7c3e-9d8a-4c55-8e21-0f6a1b2c3d4e'
    // open it in the edit page, expect 'Unknown agency' visible, tap save
    // expect the row's agency unchanged
  });
```

Write each body fully using the helper you mirrored; every `// ...` line above is a concrete action to translate into `tester` calls (`tester.tap(find.byKey(...))`, `tester.enterText(find.byType(TextField).last, 'Club Y')`, `tester.pumpAndSettle()`), and every `expect` into `expect(find.text(...), findsOneWidget)` or a repository read.

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/certifications/presentation/pages/certification_edit_custom_entries_test.dart`
Expected: FAIL (no custom items).

- [ ] **Step 3: Dialogs**

`custom_agency_dialog.dart`: an `AlertDialog` with a name `TextField`, `TagColorPicker` (from `lib/features/tags/presentation/widgets/tag_input_widget.dart`; read its constructor: `selectedColor`, `nameController`, `onColorSelected`) for the colour, and, when the database has two or more divers, a `SwitchListTile` for sharing initialised from `shareByDefaultProvider`. On Save: call `createAgency` (or `updateAgency` when `existing != null`) with `diverId` from `validatedCurrentDiverIdProvider`; on `CertificationNameTakenException` show `certificationAgencies_error_nameTaken` as the field's `errorText` and keep the dialog open; on empty name show `nameRequired`. Returns the saved entity or null on cancel. For a new agency the initial selected colour is `Color(defaultAgencyColorArgb(<a fresh uuid generated when the dialog opens>))` and that same uuid is not reused as the id (the repository assigns its own); this only seeds the swatch.

`certification_level_dialog.dart`: name field, a `SegmentedButton<bool>` (Progression / Specialty, default Progression for a built-in or custom agency), and the share switch only when `CertificationAgency.fromId(agencyId) != null` and there are two or more divers, initialised from `shareByDefaultProvider` for a new level (spec: a new custom level under a built-in agency starts shared per that setting). With one diver, a new level saves `isShared` from the same setting. Save calls `createLevel` / `updateLevel` with the same error handling.

Both dialogs are under ~200 lines each; keep them separate files.

- [ ] **Step 4: Rewrite the pickers on ids**

`certification_option.dart`: change the wrapped value from `CertificationLevel?` to `String?` and add an `addCustom` variant (a third constructor with a distinct key, e.g. `const CertificationOption.addCustom() : key = '__add__', id = null, isHeader = false, isAddCustom = true;`). Read the current class first and keep its equality semantics (unique value per row).

`certification_edit_page.dart`:
- State `_agency` becomes `String _agency = CertificationAgency.padi.name;`, `_level` becomes `String? _level;`, `_ExtraCredential` fields become `String agency; String? level;`.
- `_setAgencyAt` resets the level when `!catalog.levelsFor(agency).any((e) => e.id == level)`.
- The agency dropdown is `DropdownButtonFormField<String>` with items from `catalog.agencies` (`Text(entry.localizedName(context.l10n))`), plus, when the stored agency is a fallback (not in `catalog.agencies`), an item for `catalog.agency(stored)` so the value always renders, plus a final item with value `'__addAgency__'` and text `certificationAgencies_addCustomAgency`. In `onChanged`, when the value is `'__addAgency__'`: `final created = await showCustomAgencyDialog(context, ref); if (created != null) _setAgencyAt(i, created.id); else setState(() {});` (the `setState` remounts the field so the add item is not left selected; bump a counter in the field's `ValueKey` to force the remount).
- `_certificationItems` builds from `catalog.ladderFor(agency)` and `catalog.specialtiesFor(agency)`, keeps the "extra" logic for a stored level not in either, then adds `CertificationOption.addCustom()` with text `certificationAgencies_addCustomCertification`, then Other (`catalog.level(CertificationLevel.other.name)`). Selecting add-custom opens `showCertificationLevelDialog(context, ref, agencyId: agency)` and selects the created id.
- `catalog` comes from `ref.watch(certificationCatalogSyncProvider)` in `build`, passed to the row and item builders.

`course_edit_page.dart`: the agency dropdown gets the same agency items and the add-custom entry (extract a shared `CertificationAgencyDropdown` widget into `lib/features/certification_agencies/presentation/widgets/certification_agency_dropdown.dart` used by both pages, taking `value`, `onChanged(String)`, `labelText`, `key`).

- [ ] **Step 5: Run**

Run: `flutter test test/features/certifications/ test/features/courses/ test/features/certification_agencies/`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
dart format .
flutter analyze
flutter test test/architecture/
git add <explicit paths>
git commit -m "feat(certification-agencies): pick and quick-create custom agencies and certifications"
```

---

### Task 9: Settings > Manage > Certification Agencies

**Files:**
- Create: `lib/features/certification_agencies/presentation/pages/certification_agencies_page.dart`
- Create: `lib/features/certification_agencies/presentation/pages/certification_agency_edit_page.dart`
- Create: `lib/features/certification_agencies/presentation/widgets/agency_swatch.dart`
- Create: `lib/features/certification_agencies/presentation/widgets/certification_delete_refusal.dart`
- Modify: `lib/core/router/app_router.dart` (beside `/dive-roles` ~L1496)
- Modify: `lib/features/settings/presentation/pages/settings_page.dart` (Manage tiles, after Dive Roles ~L2453)
- Modify: all 11 ARB files
- Test: `test/features/certification_agencies/presentation/pages/certification_agencies_page_test.dart`
- Test: `test/features/certification_agencies/presentation/pages/certification_agency_edit_page_test.dart`

**Interfaces:**
- Consumes: Tasks 3, 4, 7, 8 (dialogs).
- Produces: routes `/certification-agencies` and `/certification-agencies/:id` (`:id` is a built-in enum name or custom UUID); `CertificationAgenciesPage`, `CertificationAgencyEditPage({required String agencyId})`; `Future<void> showCertificationDeleteRefusal(BuildContext context, CertificationUsage usage)`; `AgencySwatch({required AgencyEntry entry, double size = 28})`.

ARB keys (en; translate for the other 10):

| Key | en |
| --- | --- |
| `settings_manage_certificationAgencies` | Certification Agencies |
| `settings_manage_certificationAgencies_subtitle` | Manage custom agencies and certifications |
| `certificationAgencies_page_title` | Certification Agencies |
| `certificationAgencies_section_yours` | Your agencies |
| `certificationAgencies_section_builtIn` | Built-in agencies |
| `certificationAgencies_addAgency` | Add agency |
| `certificationAgencies_sharedBy` | Shared by {name} |
| `certificationAgencies_editor_progression` | Progression |
| `certificationAgencies_editor_specialties` | Specialties |
| `certificationAgencies_editor_addCertification` | Add certification |
| `certificationAgencies_editor_builtInHint` | Built-in certifications cannot be changed. You can add your own. |
| `certificationAgencies_delete_confirmTitle` | Delete {name}? |
| `certificationAgencies_delete_refusedTitle` | Still in use |
| `certificationAgencies_delete_refusedBody` | ICU: `{certifications, plural, =0{} =1{Used by 1 certification} other{Used by {certifications} certifications}}{courses, plural, =0{} =1{ and 1 course} other{ and {courses} courses}}. Change those first.` |

The refused body must read well when either count is zero; write the en message as two plural selects joined as above and test the three cases (certs only, courses only, both). If the course-only case reads "and 1 course", restructure into three separate keys (`_certsOnly`, `_coursesOnly`, `_both`) chosen in Dart instead; prefer whichever produces natural sentences in every locale.

- [ ] **Step 1: Failing page tests**

Mirror `test/features/dive_roles/presentation/pages/dive_roles_page_test.dart` (find it with `ls test/features/dive_roles/presentation/pages/`). Tests:

- the page lists own custom agencies under "Your agencies" with edit and delete icons, a shared agency of another diver with "Shared by B" and no icons, and built-ins under "Built-in agencies" without icons;
- the extended FAB "Add agency" opens the agency dialog and the new agency appears;
- deleting an unused agency asks for confirmation then removes it;
- deleting a used agency shows "Still in use" with the counts and keeps it;
- the editor for `padi` shows built-in rungs as disabled tiles and lets the user add "Ice Diver", which then appears under Progression with edit and delete icons;
- the editor for an own custom agency shows the name field, colour picker and (with two divers) the share switch; with one diver the switch is absent;
- reordering two custom rungs (drag the second above the first with `tester.drag` on the `ReorderableDragStartListener`) persists the new order (read the repository).

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/certification_agencies/presentation/pages/`
Expected: FAIL.

- [ ] **Step 3: Build the pages**

`certification_agencies_page.dart`: copy the structure of `lib/features/dive_roles/presentation/pages/dive_roles_page.dart` (Scaffold, AppBar title, `FloatingActionButton.extended(icon: Icon(Icons.add), label: Text(addAgency), tooltip: addAgency)`, list with section headers). Rows: `ListTile(leading: AgencySwatch(entry: e), title: Text(e.localizedName(l10n)), subtitle: shared-by text when not own, trailing: own ? Row(mainAxisSize: MainAxisSize.min, children: [IconButton(Icons.edit_outlined), IconButton(Icons.delete_outline)]) : null, onTap: () => context.push('/certification-agencies/${e.id}'))`. Built-in rows have no trailing icons and push the editor. The owner name for "Shared by" comes from the divers provider used elsewhere (`grep -rn "allDiversProvider\|diverListProvider" lib/features/divers/presentation/providers/diver_providers.dart | head -3`).

Delete: `final refused = await repo.deleteAgency(id, actingDiverId: diverId);` after a confirm dialog; when non-null call `showCertificationDeleteRefusal(context, refused)`.

`certification_agency_edit_page.dart` (target under 400 lines; split section widgets into `widgets/` if it grows):
- For a custom own agency: name `TextField` (saved on an app-bar Save action, like other editor pages; check `dive_types` or tank preset editor for the save convention), `TagColorPicker`, share switch (two or more divers), a preview card (`AgencySwatch` large, with the agency name over the gradient).
- For a built-in, or another diver's shared agency: header with name and swatch, `certificationAgencies_editor_builtInHint` (built-in only), no name/colour/share fields.
- Progression section: built-in rungs as `ListTile(enabled: false)`; then the viewer's own custom rungs in a `ReorderableListView` (`shrinkWrap: true`, `physics: NeverScrollableScrollPhysics()`), each with edit and delete icons; `onReorder` calls `repo.reorderProgression(agencyId, newOrderIds, actingDiverId: diverId)`. Other divers' shared rungs (visible, not own) render as plain tiles after the reorderable list.
- Specialties section: built-in specialties disabled, then custom specialties (own with icons).
- "Add certification" `OutlinedButton.icon` opens `showCertificationLevelDialog(context, ref, agencyId: agencyId)`.
- Another diver's shared agency: everything read-only, but "Add certification" is hidden (levels under a custom agency belong to its owner).

`agency_swatch.dart`: a `Container` with a `LinearGradient(colors: [entry.primaryColor, entry.secondaryColor])` and rounded corners.

`certification_delete_refusal.dart`: an `AlertDialog` with `refusedTitle`, the body from usage counts, and an OK button.

Router: add beside `/dive-roles`:

```dart
          GoRoute(
            path: '/certification-agencies',
            builder: (context, state) => const CertificationAgenciesPage(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (context, state) => CertificationAgencyEditPage(
                  agencyId: state.pathParameters['id']!,
                ),
              ),
            ],
          ),
```

(Match the exact `GoRoute` shape the `/dive-roles` route uses: it may use `pageBuilder` or a shared transition helper.)

Settings tile after Dive Roles, same shape as its neighbours:

```dart
                ListTile(
                  leading: const Icon(Icons.workspace_premium_outlined),
                  title: Text(context.l10n.settings_manage_certificationAgencies),
                  subtitle: Text(
                    context.l10n.settings_manage_certificationAgencies_subtitle,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/certification-agencies'),
                ),
```

(Copy the leading/trailing of the Dive Roles tile exactly; only the icon, strings and route differ.)

- [ ] **Step 4: Run**

Run: `flutter test test/features/certification_agencies/ test/features/settings/`
Expected: PASS. If a settings test counts Manage tiles, update its count.

- [ ] **Step 5: Commit**

```bash
dart format .
flutter analyze
flutter test test/architecture/
git add <explicit paths>
git commit -m "feat(certification-agencies): manage page and agency editor"
```

---

### Task 10: Import and export

**Files:**
- Modify: `lib/core/services/export/uddf/uddf_export_builders.dart` (~L963, ~L965, ~L1456), `lib/core/services/export/uddf/uddf_participant_writers.dart` (~L65, ~L71)
- Modify: `lib/features/dive_import/data/services/uddf_entity_importer.dart` (`_parseEnum` uses ~L1022-1034; ~L3585-3611)
- Modify: `lib/core/services/export/uddf/uddf_import_parsers.dart` (~L908-918, ~L1077-1083)
- Modify: `lib/features/dive_import/.../divelogs_reference_mappers.dart` (~L40-62) (locate with `find lib -name divelogs_reference_mappers.dart`)
- Modify: `lib/features/dive_import/.../universal_adapter.dart`, `import_duplicate_checker.dart` (~L597)
- Create: `lib/features/certification_agencies/data/services/certification_import_resolver.dart`
- Test: `test/features/certification_agencies/data/certification_import_resolver_test.dart`
- Test: extend the existing UDDF export test for certifications (`grep -rln "certification" test/core/services/export | head`)

**Interfaces:**
- Consumes: Task 3 repository, Task 4 catalog.
- Produces:
  - `class CertificationImportResolver` with `CertificationImportResolver(CustomCertificationRepository repo, {required String diverId, required bool shareByDefault})`, `Future<String> agencyId(String? text)`, `Future<String?> levelId(String agencyId, String? text)`. It caches created and matched agencies for one import run, so the same text maps to one id.

- [ ] **Step 1: Failing resolver tests**

```dart
// test/features/certification_agencies/data/certification_import_resolver_test.dart
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/certification_agencies/data/repositories/custom_certification_repository.dart';
import 'package:submersion/features/certification_agencies/data/services/certification_import_resolver.dart';

import '../../../helpers/test_database.dart';

void main() {
  late CustomCertificationRepository repo;

  setUp(() async {
    final db = await setUpTestDatabase();
    await db.customStatement(
      "INSERT INTO divers (id, name, created_at, updated_at) VALUES ('a', 'A', 0, 0)",
    );
    repo = CustomCertificationRepository();
  });
  tearDown(tearDownTestDatabase);

  CertificationImportResolver resolver() =>
      CertificationImportResolver(repo, diverId: 'a', shareByDefault: false);

  test('built-ins match by enum name or display name, case-insensitively', () async {
    final r = resolver();
    expect(await r.agencyId('PADI'), 'padi');
    expect(await r.agencyId('acuc'), 'acuc');
    expect(await r.levelId('padi', 'Open Water'), 'openWater');
  });

  test('blank agency keeps the existing default', () async {
    expect(await resolver().agencyId(''), 'padi');
    expect(await resolver().agencyId(null), 'padi');
  });

  test('an unknown agency becomes a private custom agency', () async {
    final id = await resolver().agencyId('Club X');
    final agencies = await repo.getAllAgencies();
    expect(agencies.single.id, id);
    expect(agencies.single.name, 'Club X');
    expect(agencies.single.isShared, isFalse);
  });

  test('second import reuses the custom agency', () async {
    final first = await resolver().agencyId('Club X');
    final second = await resolver().agencyId('club x');
    expect(second, first);
    expect(await repo.getAllAgencies(), hasLength(1));
  });

  test('unknown level text is not auto-created; a known custom level matches', () async {
    final r = resolver();
    expect(await r.levelId('padi', 'Underwater Basket Weaving'), isNull);
    expect(await repo.getAllLevels(), isEmpty);
    final l = await repo.createLevel(
        diverId: 'a', agencyId: 'padi', name: 'Ice Diver',
        isProgression: true, isShared: false);
    expect(await r.levelId('padi', 'ice diver'), l.id);
  });
}
```

Note: the current importer uses `padi` for blank and `other` for unrecognised agency text (#912). The blank-to-padi default stays; the unrecognised-to-other branch is what this task replaces. Confirm the blank default by reading `uddf_entity_importer.dart` ~L3585-3611 before relying on it.

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/certification_agencies/data/certification_import_resolver_test.dart`
Expected: FAIL (file missing).

- [ ] **Step 3: Write the resolver**

```dart
// lib/features/certification_agencies/data/services/certification_import_resolver.dart
import 'package:submersion/core/constants/certification_levels.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/certification_agencies/data/repositories/custom_certification_repository.dart';

/// Maps imported agency and level text to ids (issue #690). Built-ins match
/// as before; an unknown agency becomes a custom agency for the importing
/// diver instead of collapsing to Other. Level text is never auto-created:
/// importers such as MacDive send free-form card names as the level.
class CertificationImportResolver {
  CertificationImportResolver(
    this._repo, {
    required this.diverId,
    required this.shareByDefault,
  });

  final CustomCertificationRepository _repo;
  final String diverId;
  final bool shareByDefault;
  final Map<String, String> _agencyCache = {};

  Future<String> agencyId(String? text) async {
    final t = text?.trim() ?? '';
    if (t.isEmpty) return CertificationAgency.padi.name;
    final lower = t.toLowerCase();
    for (final a in CertificationAgency.values) {
      if (a.name.toLowerCase() == lower || a.displayName.toLowerCase() == lower) {
        return a.name;
      }
    }
    final cached = _agencyCache[lower];
    if (cached != null) return cached;
    final existing = (await _repo.getAllAgencies()).where(
      (a) => (a.diverId == diverId || a.isShared) && a.name.toLowerCase() == lower,
    );
    if (existing.isNotEmpty) return _agencyCache[lower] = existing.first.id;
    final created = await _repo.createAgency(
      diverId: diverId,
      name: t,
      isShared: shareByDefault,
    );
    return _agencyCache[lower] = created.id;
  }

  Future<String?> levelId(String agencyId, String? text) async {
    final t = text?.trim() ?? '';
    if (t.isEmpty) return null;
    final lower = t.toLowerCase();
    for (final l in CertificationLevel.values) {
      if (l.name.toLowerCase() == lower || l.displayName.toLowerCase() == lower) {
        return l.name;
      }
    }
    final builtInAgency = CertificationAgency.fromId(agencyId);
    final custom = (await _repo.getAllLevels()).where(
      (l) =>
          l.agencyId == agencyId &&
          (l.diverId == diverId || l.isShared || builtInAgency == null) &&
          l.name.toLowerCase() == lower,
    );
    return custom.isEmpty ? null : custom.first.id;
  }
}
```

(`CertificationLevelCatalog` import is unused here; drop it if the analyzer says so.)

- [ ] **Step 4: Wire the importers**

- `uddf_entity_importer.dart`: construct one resolver per import run (where the importer has the target diver id and can read `shareByDefault`; if the importer has no `ref`, add a `bool shareByDefault` parameter to its entry point and pass it from the caller that has a `ref`). Replace the agency parsing at ~L1022-1034 and ~L3585-3611 with `await resolver.agencyId(text)`, and the level parsing with `await resolver.levelId(agencyId, text)` (unmatched level text keeps flowing into the certification name exactly as today).
- `uddf_import_parsers.dart`: its `parseEnumValue` calls for agency/level produce intermediate values; keep them returning the raw text (String) instead of an enum so the importer resolves it. Read how its results are consumed and change only the agency/level fields.
- `divelogs_reference_mappers.dart`: same replacement using a resolver passed in.
- `universal_adapter.dart` preview items: show `catalog.agency(id).interchangeName` (built-ins) or the raw text for not-yet-created custom agencies.
- `import_duplicate_checker.dart`: the key becomes `'${name}|${agencyId}'` (string id); for incoming items not yet resolved, compare against the existing row's `interchangeName` lowercased as a second key, so a re-import of a custom agency card is detected as a duplicate.
- UDDF export: where the builders write `cert.agency` / `cert.level`, write `catalog.agency(id).isBuiltIn ? id : catalog.agency(id).interchangeName` (and the level equivalent). Thread `CertificationCatalog catalog` into the export builder entry point with default `builtInOnly`, passed from `export_providers.dart` via `ref.read(certificationCatalogProvider.future)`.

- [ ] **Step 5: Tests for import and export integration**

Add to the existing UDDF certification import test (find with `grep -rln "certification" test/features/dive_import | head`): importing a UDDF file whose certification agency is "Club X" creates one custom agency, and importing it again creates no second one (Review Focus 5). Add to the UDDF export test: a certification with a custom agency exports `<organization>`/agency text "Club X" (match the element the builder writes at ~L963), and a built-in still exports `padi`.

Run: `flutter test test/features/certification_agencies/ test/features/dive_import/ test/core/services/export/`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
dart format .
flutter analyze
flutter test test/architecture/
git add <explicit paths>
git commit -m "feat(certification-agencies): import unknown agencies as custom, export custom names"
```

---

### Task 11: Explore query language

**Files:**
- Modify: `lib/core/query/domain/query_subject.dart` (two name-only subjects)
- Modify: `lib/core/query/domain/query_value.dart` (`EnumValue.label`)
- Modify: `lib/core/query/domain/query_json.dart` (~L41, ~L133)
- Modify: `lib/core/query/syntax/query_printer.dart` (~L138)
- Modify: `lib/core/query/registry/query_field.dart` (`customValueSubject`)
- Modify: `lib/core/query/syntax/query_parser.dart` (~L660-678)
- Modify: `lib/core/query/compiler/query_validator.dart` (~L279-296)
- Modify: `lib/core/query/presentation/query_completions.dart` (~L110-122), `query_value_editor.dart` (~L246-290)
- Modify: `lib/features/certifications/query/certification_query_entity.dart`, the courses query entity (`find lib -name "course_query_entity.dart"`)
- Modify: `lib/features/query/data/name_index_loader.dart`
- Modify: `lib/core/query/presentation/app_query_labels.dart` (find with `find lib -name app_query_labels.dart`) (~L108-113)
- Modify: `lib/features/explore/domain/explore_clause_lowering.dart` (~L145-152)
- Test: `test/core/query/custom_certification_query_test.dart`

**Interfaces:**
- Consumes: Task 4 catalog; NameIndex (`NameEntry`, `NameTarget`, `NameIndex.fromRefs`).
- Produces:
  - `QuerySubject.certificationAgencies`, `QuerySubject.certificationLevels` (doc: name-only subjects, no registry entity; never a query root or relation target).
  - `EnumValue(String name, {String? label})`; equality on `name` only; JSON `{'k': 'enum', 'v': name, 'label': label}` when label is set.
  - `QueryField.customValueSubject` (`QuerySubject?`).

- [ ] **Step 1: Failing query tests**

```dart
// test/core/query/custom_certification_query_test.dart
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/query/compiler/query_validator.dart';
import 'package:submersion/core/query/domain/query_json.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/domain/query_value.dart';
import 'package:submersion/core/query/names/name_index.dart';
import 'package:submersion/features/certifications/query/certification_query_entity.dart';
import 'package:submersion/features/query/app_query_registry.dart';

const clubId = '2b1f7c3e-9d8a-4c55-8e21-0f6a1b2c3d4e';

void main() {
  final names = NameIndex.fromRefs({
    QuerySubject.certificationAgencies: [const RefValue(clubId, 'Club X')],
  });

  test('a custom agency name parses to its id with the label kept', () {
    // Parse 'agency = "Club X"' against certificationQueryEntity using the
    // same parse entry point the existing parser tests use (see
    // test/core/query/syntax/query_parser_test.dart for the call and the
    // ParseContext construction), passing `names`.
    // expect the condition value == EnumValue(clubId) and its label 'Club X'.
  });

  test('a custom id validates for an open enum field', () {
    // Build the same condition tree directly and run validateQuery(tree,
    // certificationQueryEntity, appQueryRegistry); expect no errors.
  });

  test('a built-in still parses by name', () {
    // 'agency = padi' parses to EnumValue('padi').
  });

  test('EnumValue label round-trips through JSON and prints quoted', () {
    const v = EnumValue(clubId, label: 'Club X');
    // encode/decode with the query_json helpers used in
    // test/core/query/domain/query_json_test.dart; expect name and label.
    expect(v, const EnumValue(clubId));
  });
}
```

Fill each commented body by copying the exact calls from the named existing test files (they show `ParseContext(prefs: ..., now: ..., names: ...)` and the parse entry point); every comment names the input and the expected value.

Also extend the NameIndexLoader test (`find test -name "name_index_loader*_test.dart"`): a diver's own custom agency and another diver's shared one load under `QuerySubject.certificationAgencies`; another diver's private one does not.

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/core/query/custom_certification_query_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

`query_subject.dart`, append:

```dart
  /// Custom certification agencies (issue #690): name-only, for resolving
  /// typed and spoken agency values. No registry entity.
  certificationAgencies,

  /// Custom certification levels (issue #690): name-only, as above.
  certificationLevels,
```

Run `flutter analyze` and add arms to any exhaustive `switch` over `QuerySubject` that now fails (e.g. `rowTargetFor` falls through `_ => NameTarget.row`, which is correct; others may need `=> null` or an `assert(false)` arm consistent with neighbours).

`query_value.dart` `EnumValue`:

```dart
class EnumValue extends QueryValue {
  final String name;

  /// Display text for a custom value (issue #690): the custom agency or
  /// level name. Not part of equality; printed instead of the id.
  final String? label;
  const EnumValue(this.name, {this.label});
  @override
  bool operator ==(Object other) => other is EnumValue && other.name == name;
  @override
  int get hashCode => name.hashCode;
  @override
  String toString() => 'EnumValue($name)';
}
```

(Keep the existing `hashCode`/`toString` shape if it differs.)

`query_json.dart`: encode `EnumValue(:final name, :final label) => {'k': 'enum', 'v': name, if (label != null) 'label': label}`; decode `EnumValue(_str(m['v']), label: m['label'] as String?)`.

`query_printer.dart`: `EnumValue(:final name, :final label) => label != null ? _quote(label) : name,`.

`query_field.dart`: add `final QuerySubject? customValueSubject;` with doc "For an enumName field whose values may also be custom ids (issue #690): unmatched typed text resolves through this name subject, and the validator accepts any value.", constructor parameter `this.customValueSubject,`.

`query_parser.dart` enumName case, replace the `match == null` branch head:

```dart
        if (match == null) {
          final custom = field.customValueSubject;
          if (custom != null) {
            final ref = context.names.resolve(custom, tok.text);
            if (ref != null) return EnumValue(ref.id, label: ref.label);
          }
          // existing suggestion + _Abort unchanged
```

and include `context.names.candidates(custom, tok.text)` in `suggestions` when `custom != null`.

`query_validator.dart`: change the `notEnumValue` condition to `} else if (field.customValueSubject == null && !(field.enumValues ?? const []).contains(value.name)) {`.

`certification_query_entity.dart`: `agency` field gets `customValueSubject: QuerySubject.certificationAgencies`, `level` gets `customValueSubject: QuerySubject.certificationLevels`. Update the entity doc comment: custom ids are valid values. Same for the course entity's `agency`.

`name_index_loader.dart`: add a `_customCertificationEntries(String? diverId)` that selects visible rows (SQL: `SELECT id, name FROM custom_certification_agencies WHERE diver_id = ? OR is_shared = 1`; for levels, `SELECT l.id, l.name FROM custom_certification_levels l LEFT JOIN custom_certification_agencies a ON a.id = l.agency_id WHERE (a.id IS NOT NULL AND (a.diver_id = ?1 OR a.is_shared = 1)) OR (a.id IS NULL AND (l.diver_id = ?1 OR l.is_shared = 1))`; with a null diver, only shared rows) and returns `NameEntry(subject: QuerySubject.certificationAgencies, label: name, ids: [id], target: NameTarget.row, primary: true)` per row (read `NameEntry`'s constructor for its exact required parameters). Append its entries in `load`. Add both tables to `tables`.

`query_completions.dart`: where it emits `field.enumValues`, also emit the quoted labels of `refEntries(field.customValueSubject!)` when the resolver implements `NameEntries` (read how the file reaches names for relation completions and reuse that path).

`query_value_editor.dart`: the enum dropdown (~L246-290) adds, after the built-in values, items for `refEntries(customValueSubject)` with `EnumValue(ref.id, label: ref.label)` values and `ref.label` text. Find how the editor obtains a `NameEntries` for ref pickers (search the file for `refEntries`) and reuse it.

`app_query_labels.dart`: for `query_certifications_agency` / `query_courses_agency`, when `byName` returns null, label with the catalog: take a `CertificationCatalog` in the labels class constructor (default `builtInOnly`) and return `catalog.agency(value).localizedName(_l10n)`; same for level. Pass `ref.read(certificationCatalogSyncProvider)` where the labels object is created.

`explore_clause_lowering.dart` (~L145-152): when a value is not in `allowed` and `field.field?.customValueSubject != null`, resolve it with the names resolver available there (read the surrounding function for how names are reached) to an `EnumValue(id, label:)`; otherwise keep the existing behaviour.

- [ ] **Step 4: Run**

Run: `flutter test test/core/query/ test/features/query/ test/features/explore/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format .
flutter analyze
flutter test test/architecture/
git add <explicit paths>
git commit -m "feat(certification-agencies): query custom agencies and certifications in Explore"
```

---

### Task 12: Final verification

**Files:** none new.

- [ ] **Step 1: Generated files and l10n staleness**

Run: `flutter gen-l10n && dart run build_runner build --delete-conflicting-outputs && git status --short`
Expected: no unexpected generated diffs left unstaged.

- [ ] **Step 2: Whole-project checks**

Run: `dart format .` (expect no changes)
Run: `flutter analyze` (expect "No issues found!")
Run: `flutter test test/architecture/`
Run: `./scripts/run_all_tests.sh` if present (check `ls scripts/run_all_tests.sh`), else `flutter test`
Expected: all PASS. Do not pipe the test command through `grep` (it hides the exit status); write output to a scratchpad log and read its tail.

- [ ] **Step 3: Em-dash and attribution scan of the branch diff**

```bash
git diff origin/main...HEAD | python3.14 -c "import sys; t=sys.stdin.read(); print('emdash', t.count(chr(0x2014)), 'endash', t.count(chr(0x2013)))"
git log origin/main..HEAD --format=%B | grep -i -E "co-authored-by|generated with" || echo clean
```

Expected: `emdash 0 endash 0` for added lines (pre-existing ones in context lines are fine; inspect any hit) and `clean`.

- [ ] **Step 4: Commit any fixes**

```bash
git add <explicit paths>
git commit -m "fix(certification-agencies): final verification fixes"
```

(Skip if nothing changed.)
