# Configurable Default Equipment View Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task, inline in this session. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let each diver choose which statuses the Equipment list's default view shows (issue #2628).

**Architecture:** A synced, nullable `diver_settings.equipment_default_statuses` JSON column feeds `AppSettings.equipmentDefaultStatuses`. `EquipmentFilterQuery` lowers the default view from that set instead of three hard-coded conditions, and the two compile callers (the list's id-set provider and the save-reveal helper) pass it in, so every default-view surface follows the setting. A Settings page edits the set, reached from Settings > Manage and from an "Edit default" link in the filter panel.

**Tech Stack:** Flutter, Riverpod (legacy `StateNotifier` settings), Drift (SQLite), the in-house query AST (`lib/core/query`), ARB l10n in 11 locales.

**Spec:** `docs/design/specs/2026-10-12-equipment-default-view-design.md`

## Global Constraints

- Factory default set: `{active, spare, needsService, inService, loaned, lost}` (every status except `retired`, `sold`, `wanted`). An unchanged setting is stored as null.
- Existing rows are never backfilled (null reads as the factory default).
- Schema rung: **v286** (282 is held by PR #3133, 284 by a local branch, 285 by PR #3306). If main ships 286 first, renumber to the next free version in every place this plan names 286.
- The default view always includes at least one status.
- Dive gear pickers, sets, service clocks, statistics and totals are out of scope and must not change.
- Every new user-facing string is translated into all 10 non-English locales; `flutter gen-l10n` runs last (Task 9).
- No em dashes or en dashes as punctuation in code, comments, docs or commit messages. No AI attribution anywhere.
- Paths in tests via `p.join`; tests restore any global state they replace.

## Review Focus

1. A custom set containing `retired`: legacy rows that only cleared `is_active` must appear, but sold and wanted rows must not. (Task 2 test "a custom set keeps the legacy retired rule".)
2. A peer from a newer build syncs a status name this build lacks: unknown names are dropped, and a value with no known name reads as the factory default rather than an empty, all-hiding view. (Task 1 tests.)
3. Changing the setting while the Equipment list is open must re-query it at once, not on the next launch. (Task 5 test "changing the default statuses re-queries the open list".)
4. The default view hiding everything the diver owns must not show "Add Your First Equipment". (Task 8 test.)
5. The last ticked status cannot be unticked, so the list can never default to nothing; a direct call with an empty set is ignored. (Task 3 setter test and Task 6 widget test.)

---

### Task 1: Default statuses codec

**Files:**
- Create: `lib/features/equipment/domain/models/equipment_default_view.dart`
- Test: `test/features/equipment/domain/models/equipment_default_view_test.dart`

**Interfaces:**
- Produces:
  - `const Set<EquipmentStatus> factoryDefaultEquipmentStatuses`
  - `bool isFactoryDefaultEquipmentStatuses(Set<EquipmentStatus> statuses)`
  - `String? encodeEquipmentDefaultStatuses(Set<EquipmentStatus> statuses)`: null for the factory set or an empty set, else a JSON array of names in enum order.
  - `Set<EquipmentStatus>? tryDecodeEquipmentDefaultStatuses(String? raw)`: the known statuses named, or null when the value is null, unreadable, not a list, or names no known status.
  - `Set<EquipmentStatus> decodeEquipmentDefaultStatuses(String? raw)`: `tryDecode... ?? factoryDefaultEquipmentStatuses`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/models/equipment_default_view.dart';

void main() {
  test('the factory default is every status but retired, sold and wanted', () {
    expect(factoryDefaultEquipmentStatuses, {
      EquipmentStatus.active,
      EquipmentStatus.spare,
      EquipmentStatus.needsService,
      EquipmentStatus.inService,
      EquipmentStatus.loaned,
      EquipmentStatus.lost,
    });
    expect(
      isFactoryDefaultEquipmentStatuses({...factoryDefaultEquipmentStatuses}),
      isTrue,
    );
    expect(isFactoryDefaultEquipmentStatuses({EquipmentStatus.active}), isFalse);
  });

  group('encode', () {
    test('the factory set and the empty set store nothing', () {
      expect(encodeEquipmentDefaultStatuses(factoryDefaultEquipmentStatuses),
          isNull);
      expect(encodeEquipmentDefaultStatuses(const {}), isNull);
    });

    test('a custom set stores its names in enum order', () {
      expect(
        encodeEquipmentDefaultStatuses({
          EquipmentStatus.lost,
          EquipmentStatus.active,
        }),
        '["active","lost"]',
      );
    });
  });

  group('decode', () {
    test('null reads as the factory default', () {
      expect(decodeEquipmentDefaultStatuses(null),
          factoryDefaultEquipmentStatuses);
      expect(tryDecodeEquipmentDefaultStatuses(null), isNull);
    });

    test('a custom set round-trips', () {
      final set = {EquipmentStatus.active, EquipmentStatus.retired};
      expect(
        decodeEquipmentDefaultStatuses(encodeEquipmentDefaultStatuses(set)),
        set,
      );
    });

    test('unknown names from a newer build are dropped', () {
      expect(decodeEquipmentDefaultStatuses('["active","hovercraft"]'),
          {EquipmentStatus.active});
    });

    test('a value naming no known status reads as the factory default', () {
      for (final raw in ['["hovercraft"]', '[]', '[1, 2]']) {
        expect(tryDecodeEquipmentDefaultStatuses(raw), isNull, reason: raw);
        expect(decodeEquipmentDefaultStatuses(raw),
            factoryDefaultEquipmentStatuses, reason: raw);
      }
    });

    test('unreadable JSON and non-lists read as the factory default', () {
      for (final raw in ['not json', '{"active": true}', '"active"', '']) {
        expect(decodeEquipmentDefaultStatuses(raw),
            factoryDefaultEquipmentStatuses, reason: raw);
      }
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/equipment/domain/models/equipment_default_view_test.dart`
Expected: FAIL, the import does not exist.

- [ ] **Step 3: Write the implementation**

```dart
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:submersion/core/constants/enums.dart';

/// The statuses the Equipment list's default view shows until the diver
/// picks others (issue #2628): everything but retired and sold gear (#636)
/// and wishlist gear (#2025).
const Set<EquipmentStatus> factoryDefaultEquipmentStatuses = {
  EquipmentStatus.active,
  EquipmentStatus.spare,
  EquipmentStatus.needsService,
  EquipmentStatus.inService,
  EquipmentStatus.loaned,
  EquipmentStatus.lost,
};

bool isFactoryDefaultEquipmentStatuses(Set<EquipmentStatus> statuses) =>
    setEquals(statuses, factoryDefaultEquipmentStatuses);

/// The stored form of [statuses]: null for the factory set (so an untouched
/// setting stores nothing and a later factory change reaches it) and for an
/// empty set, which the default view never uses; otherwise a JSON array of
/// names in enum order, so equal sets store equal text.
String? encodeEquipmentDefaultStatuses(Set<EquipmentStatus> statuses) {
  if (statuses.isEmpty || isFactoryDefaultEquipmentStatuses(statuses)) {
    return null;
  }
  return jsonEncode([
    for (final s in EquipmentStatus.values)
      if (statuses.contains(s)) s.name,
  ]);
}

/// The known statuses [raw] names, or null when it names none: null,
/// unreadable, not a list, or only names from a newer build.
Set<EquipmentStatus>? tryDecodeEquipmentDefaultStatuses(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } on FormatException {
    return null;
  }
  if (decoded is! List) return null;
  final names = decoded.whereType<String>().toSet();
  final statuses = {
    for (final s in EquipmentStatus.values)
      if (names.contains(s.name)) s,
  };
  return statuses.isEmpty ? null : statuses;
}

/// [tryDecodeEquipmentDefaultStatuses], falling back to the factory set so
/// a bad value can never leave the default view empty.
Set<EquipmentStatus> decodeEquipmentDefaultStatuses(String? raw) =>
    tryDecodeEquipmentDefaultStatuses(raw) ?? factoryDefaultEquipmentStatuses;
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/equipment/domain/models/equipment_default_view_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/equipment/domain/models/equipment_default_view.dart test/features/equipment/domain/models/equipment_default_view_test.dart
git commit -m "feat(equipment): add the default equipment view status codec"
```

---

### Task 2: Lower the default view from a status set

**Files:**
- Modify: `lib/features/equipment/query/equipment_filter_query.dart`
- Test: `test/features/equipment/query/equipment_filter_query_semantics_test.dart`

**Interfaces:**
- Consumes: `factoryDefaultEquipmentStatuses`, `isFactoryDefaultEquipmentStatuses` (Task 1).
- Produces:
  - `QueryNode? EquipmentFilterQuery.toQuery({Set<EquipmentStatus> defaultStatuses = factoryDefaultEquipmentStatuses})`
  - `CompiledQuery compileEquipmentFilter(EquipmentFilterState filter, {String? diverId, Set<EquipmentStatus> defaultStatuses = factoryDefaultEquipmentStatuses})`
  - `toSavedQuery()` unchanged.

- [ ] **Step 1: Write the failing tests**

In the semantics test, give `selected` an optional set and add a group after the existing tests. The fixture rows (setUp) are: `bcd`, `suit` (active), `old` (retired, is_active left set), `shelved` (status active, is_active cleared: legacy retired), `gone` (sold), `loan` (loaned), `lent` (another diver's, shared with me), `wish`, `wish2` (wanted).

```dart
  Future<Set<String>> selected(
    EquipmentFilterState f, {
    Set<EquipmentStatus> defaults = factoryDefaultEquipmentStatuses,
  }) async {
    final visible = {
      for (final e in await EquipmentRepository().getAllEquipment(
        diverId: 'me',
      ))
        e.id,
    };
    final ids = await QueryIdSetRunner(db).ids(
      compileEquipmentFilter(f, defaultStatuses: defaults),
      scope: f.ownerScope('me'),
    );
    return ids.intersection(visible);
  }
```

```dart
  group('a configured default view (#2628)', () {
    const none = EquipmentFilterState();

    test('the factory set selects what the default view always did', () async {
      expect(await selected(none), defaultView);
    });

    test('Active only leaves out loaned and legacy retired gear', () async {
      expect(
        await selected(none, defaults: {EquipmentStatus.active}),
        {'bcd', 'suit', 'lent'},
      );
    });

    test('a custom set keeps the legacy retired rule', () async {
      expect(
        await selected(
          none,
          defaults: {EquipmentStatus.active, EquipmentStatus.retired},
        ),
        {'bcd', 'suit', 'lent', 'old', 'shelved'},
      );
    });

    test('sold and wanted gear can join the default view', () async {
      expect(
        await selected(
          none,
          defaults: {EquipmentStatus.loaned, EquipmentStatus.sold},
        ),
        {'loan', 'gone'},
      );
      expect(
        await selected(none, defaults: {EquipmentStatus.wanted}),
        {'wish', 'wish2'},
      );
    });

    test('an explicit status or All Equipment ignores the default', () async {
      expect(
        await selected(
          const EquipmentFilterState(status: EquipmentStatus.sold),
          defaults: {EquipmentStatus.active},
        ),
        {'gone'},
      );
      expect(
        await selected(
          const EquipmentFilterState(allStatuses: true),
          defaults: {EquipmentStatus.active},
        ),
        await selected(const EquipmentFilterState(allStatuses: true)),
      );
    });

    test('an empty set reads as the factory default', () async {
      expect(await selected(none, defaults: const {}), defaultView);
    });

    test('the other axes still narrow a custom default view', () async {
      expect(
        await selected(
          const EquipmentFilterState(type: EquipmentType.computer),
          defaults: {EquipmentStatus.loaned},
        ),
        {'loan'},
      );
    });

    test('saved queries never carry the default view', () {
      expect(none.toSavedQuery(), isNull);
    });
  });
```

Add the import `package:submersion/features/equipment/domain/models/equipment_default_view.dart`.

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/equipment/query/equipment_filter_query_semantics_test.dart`
Expected: FAIL to compile, `defaultStatuses` is not a parameter of `compileEquipmentFilter`.

- [ ] **Step 3: Implement**

In `equipment_filter_query.dart`, import the Task 1 file and replace `toQuery`, `toSavedQuery`, the head of `_lower` and its `s == null` and retired branches:

```dart
  /// Null only under [allStatuses] (#2590) with no other axis set: every
  /// other status choice narrows. With no status chosen, [defaultStatuses]
  /// decides what shows: the diver's default view (#2628), by default
  /// everything but retired, sold (#636) and wishlist (#2025) gear.
  QueryNode? toQuery({
    Set<EquipmentStatus> defaultStatuses = factoryDefaultEquipmentStatuses,
  }) => _lower(defaultStatuses: defaultStatuses);

  /// What Save stores (#2989): [toQuery] without the default status view,
  /// which every unfiltered list applies on its own, so a saved query names
  /// only what the diver chose. Null while nothing else is set.
  QueryNode? toSavedQuery() => _lower(defaultStatuses: null);

  QueryNode? _lower({required Set<EquipmentStatus>? defaultStatuses}) {
    final parts = <QueryNode>[];
    final s = status;
    if (allStatuses) {
      // Every status (#2590): the axis adds no condition.
    } else if (s == null) {
      // Not saved: the list applies it without being asked.
      if (defaultStatuses != null) {
        parts.addAll(_defaultViewParts(defaultStatuses));
      }
    } else if (s == EquipmentStatus.retired) {
      parts.addAll(_retiredView());
    } else {
      parts.add(_c('status', QueryOp.eq, EnumValue(s.name)));
    }
```

Then, in the rest of `_lower`, replace the local helpers `c(...)` and `e(...)` with `_c(...)` and `EnumValue(...)` (or keep the locals and add the top-level helpers below; either way the remaining axes stay exactly as they are). Add these top-level private helpers below the extension:

```dart
QueryNode _c(String key, QueryOp op, QueryValue? v) =>
    ConditionNode(FieldPath([key]), op, v);

/// getEquipmentByStatus(retired): legacy rows that only flipped
/// is_active, but not sold or wanted gear (stored inactive too).
List<QueryNode> _retiredView() => [
  OrNode([
    _c('status', QueryOp.eq, EnumValue(EquipmentStatus.retired.name)),
    _c('active', QueryOp.eq, const BoolValue(false)),
  ]),
  _c('status', QueryOp.neq, EnumValue(EquipmentStatus.sold.name)),
  _c('status', QueryOp.neq, EnumValue(EquipmentStatus.wanted.name)),
];

/// Statuses whose rows are stored inactive by design, so their view reads
/// the status alone.
const _inactiveByDesign = {EquipmentStatus.sold, EquipmentStatus.wanted};

/// The default view for [statuses] (#2628). The factory set (and an empty
/// one, which the setting never stores) keeps getActiveEquipment's exact
/// conditions: legacy rows can be retired with is_active still set, sold
/// gear has left the kit, and wanted gear has not joined it. A custom set
/// ORs each status's own view, so the legacy retired rule still holds.
List<QueryNode> _defaultViewParts(Set<EquipmentStatus> statuses) {
  if (statuses.isEmpty || isFactoryDefaultEquipmentStatuses(statuses)) {
    return [
      _c('active', QueryOp.eq, const BoolValue(true)),
      _c('status', QueryOp.neq, EnumValue(EquipmentStatus.retired.name)),
      _c('status', QueryOp.neq, EnumValue(EquipmentStatus.sold.name)),
      _c('status', QueryOp.neq, EnumValue(EquipmentStatus.wanted.name)),
    ];
  }
  final owned = [
    for (final s in EquipmentStatus.values)
      if (statuses.contains(s) &&
          s != EquipmentStatus.retired &&
          !_inactiveByDesign.contains(s))
        s,
  ];
  final options = <QueryNode>[
    if (owned.isNotEmpty)
      AndNode([
        _c('active', QueryOp.eq, const BoolValue(true)),
        owned.length == 1
            ? _c('status', QueryOp.eq, EnumValue(owned.single.name))
            : _c(
                'status',
                QueryOp.inList,
                ListValue([for (final s in owned) EnumValue(s.name)]),
              ),
      ]),
    for (final s in EquipmentStatus.values)
      if (statuses.contains(s) && _inactiveByDesign.contains(s))
        _c('status', QueryOp.eq, EnumValue(s.name)),
    if (statuses.contains(EquipmentStatus.retired)) AndNode(_retiredView()),
  ];
  return [options.length == 1 ? options.single : OrNode(options)];
}
```

`_retiredView` is the existing retired branch's conditions moved verbatim.

Update `compileEquipmentFilter`:

```dart
/// The one compile call the equipment list shares. Root alias `r0`, which
/// [EquipmentFilterQuery.ownerScope] assumes. [diverId] reads shared gear's
/// dives as that diver's alone; [defaultStatuses] is the diver's default
/// view (#2628).
CompiledQuery compileEquipmentFilter(
  EquipmentFilterState filter, {
  String? diverId,
  Set<EquipmentStatus> defaultStatuses = factoryDefaultEquipmentStatuses,
}) => compileQuery(
  filter.toQuery(defaultStatuses: defaultStatuses),
  equipmentQueryEntity,
  appQueryRegistry,
  diverId: diverId,
);
```

- [ ] **Step 4: Run the query tests**

Run: `flutter test test/features/equipment/query/`
Expected: PASS, including `equipment_filter_query_census_test.dart` and `equipment_saved_status_test.dart` unchanged.

- [ ] **Step 5: Commit**

```bash
git add lib/features/equipment/query/equipment_filter_query.dart test/features/equipment/query/equipment_filter_query_semantics_test.dart
git commit -m "feat(equipment): lower the default equipment view from a status set"
```

---

### Task 3: Persist and sync the setting

**Files:**
- Modify: `lib/core/database/tables/diver_tables.dart` (column after `hasAcceptedPlanningDisclaimer`)
- Modify: `lib/core/database/database.dart` (`currentSchemaVersion` to 286; `migrationVersions` gains 286)
- Modify: `lib/core/database/migrations/helpers/diver_migrations.dart` (helper at the end)
- Modify: `lib/core/database/migrations/ladder/rungs_v231_onward.dart` (rung at the end)
- Modify: `lib/core/database/migrations/before_open.dart` (backstop after the v281 one)
- Modify: `lib/features/settings/data/repositories/diver_settings_repository.dart` (three sites, next to `insightsMutedObservationRules`)
- Modify: `lib/features/settings/presentation/providers/settings_providers.dart` (field, constructor default, `copyWith`, setter, provider)
- Modify: `test/helpers/mock_providers.dart`, `test/features/insights/presentation/pages/records_page_test.dart` (mock setter)
- Test: `test/core/database/migration_v286_equipment_default_statuses_test.dart`
- Test: `test/features/settings/data/repositories/diver_settings_repository_equipment_default_view_test.dart`
- Test: `test/core/services/sync/sync_diver_settings_equipment_default_view_test.dart`

**Interfaces:**
- Consumes: Task 1 codec.
- Produces:
  - `AppSettings.equipmentDefaultStatuses` (`Set<EquipmentStatus>`, default `factoryDefaultEquipmentStatuses`), `copyWith(equipmentDefaultStatuses:)`
  - `Future<void> SettingsNotifier.setEquipmentDefaultStatuses(Set<EquipmentStatus> value)`: ignores an empty set.
  - `final equipmentDefaultStatusesProvider = Provider<Set<EquipmentStatus>>`
  - Drift: `DiverSettings.equipmentDefaultStatuses` (`TextColumn`, nullable), SQL `equipment_default_statuses`, sync key `equipmentDefaultStatuses`.

- [ ] **Step 1: Write the failing tests**

`test/core/database/migration_v286_equipment_default_statuses_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// Schema v286: diver_settings.equipment_default_statuses (issue #2628).
void main() {
  NativeDatabase setupDb() => NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = 285');
      rawDb.execute(
        'CREATE TABLE diver_settings (id TEXT NOT NULL PRIMARY KEY, '
        'diver_id TEXT NOT NULL)',
      );
      rawDb.execute(
        "INSERT INTO diver_settings (id, diver_id) VALUES ('s1', 'd1')",
      );
    },
  );

  test('v286 is at or below the current schema version and in the ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(286));
    expect(AppDatabase.migrationVersions, contains(286));
    expect(
      AppDatabase.migrationStepCount(285),
      AppDatabase.migrationStepCount(286) + 1,
    );
  });

  test('this rung is additive and did not move the sync floor', () {
    expect(AppDatabase.minimumCompatibleSchemaVersion, lessThan(286));
  });

  test('upgrading keeps every diver on the factory default view', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);
    final rows = await db
        .customSelect(
          'SELECT equipment_default_statuses AS v FROM diver_settings',
        )
        .get();
    expect(rows.single.read<String?>('v'), isNull);
  });
}
```

`test/features/settings/data/repositories/diver_settings_repository_equipment_default_view_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/equipment/domain/models/equipment_default_view.dart';
import 'package:submersion/features/settings/data/repositories/diver_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

void main() {
  test('the default view defaults to the factory set; copyWith carries it', () {
    const settings = AppSettings();
    expect(settings.equipmentDefaultStatuses, factoryDefaultEquipmentStatuses);
    expect(
      settings
          .copyWith(equipmentDefaultStatuses: {EquipmentStatus.active})
          .equipmentDefaultStatuses,
      {EquipmentStatus.active},
    );
  });

  group('DiverSettingsRepository default equipment view', () {
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
      await repository.createSettingsForDiver('d1');
    });

    tearDown(() {
      DatabaseService.instance.resetForTesting();
    });

    Future<String?> stored() async => (await db
            .customSelect(
              "SELECT equipment_default_statuses AS v FROM diver_settings "
              "WHERE diver_id = 'd1'",
            )
            .getSingle())
        .read<String?>('v');

    test('new settings read the factory set and store nothing', () async {
      final loaded = await repository.getSettingsForDiver('d1');
      expect(loaded!.equipmentDefaultStatuses, factoryDefaultEquipmentStatuses);
      expect(await stored(), isNull);
    });

    test('a custom set round-trips', () async {
      await repository.updateSettingsForDiver(
        'd1',
        const AppSettings(
          equipmentDefaultStatuses: {
            EquipmentStatus.active,
            EquipmentStatus.retired,
          },
        ),
      );
      final loaded = await repository.getSettingsForDiver('d1');
      expect(loaded!.equipmentDefaultStatuses, {
        EquipmentStatus.active,
        EquipmentStatus.retired,
      });
      expect(await stored(), '["active","retired"]');
    });

    test('going back to the factory set stores null again', () async {
      await repository.updateSettingsForDiver(
        'd1',
        const AppSettings(equipmentDefaultStatuses: {EquipmentStatus.active}),
      );
      await repository.updateSettingsForDiver('d1', const AppSettings());
      expect(await stored(), isNull);
    });

    test('an unreadable stored value reads as the factory set', () async {
      await db.customStatement(
        "UPDATE diver_settings SET equipment_default_statuses = 'oops' "
        "WHERE diver_id = 'd1'",
      );
      final loaded = await repository.getSettingsForDiver('d1');
      expect(loaded!.equipmentDefaultStatuses, factoryDefaultEquipmentStatuses);
    });
  });
}
```

`test/core/services/sync/sync_diver_settings_equipment_default_view_test.dart`:

```dart
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';

import '../../../helpers/test_database.dart';

/// The default equipment view syncs as a nullable JSON column (#2628); a
/// peer still before v286 exports no such key.
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

  Future<void> insert(String? statuses) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return db
        .into(db.diverSettings)
        .insert(
          DiverSettingsCompanion.insert(
            id: 'ds-ev',
            diverId: 'diver-ev',
            createdAt: now,
            updatedAt: now,
          ).copyWith(equipmentDefaultStatuses: Value(statuses)),
        );
  }

  test('a custom default view is exported and applied', () async {
    await insert('["active"]');
    final exported = await serializer.fetchRecord('diverSettings', 'ds-ev');
    expect(exported!['equipmentDefaultStatuses'], '["active"]');

    await (db.delete(db.diverSettings)..where((t) => t.id.equals('ds-ev')))
        .go();
    await serializer.upsertRecord('diverSettings', exported);
    final row = await (db.select(
      db.diverSettings,
    )..where((t) => t.id.equals('ds-ev'))).getSingle();
    expect(row.equipmentDefaultStatuses, '["active"]');
  });

  test('a pre-v286 payload without the key applies as null', () async {
    await insert(null);
    final exported = await serializer.fetchRecord('diverSettings', 'ds-ev');
    final legacy = Map<String, dynamic>.from(exported!)
      ..remove('equipmentDefaultStatuses');
    await (db.delete(db.diverSettings)..where((t) => t.id.equals('ds-ev')))
        .go();
    await serializer.upsertRecord('diverSettings', legacy);
    final row = await (db.select(
      db.diverSettings,
    )..where((t) => t.id.equals('ds-ev'))).getSingle();
    expect(row.equipmentDefaultStatuses, isNull);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/core/database/migration_v286_equipment_default_statuses_test.dart test/features/settings/data/repositories/diver_settings_repository_equipment_default_view_test.dart test/core/services/sync/sync_diver_settings_equipment_default_view_test.dart`
Expected: FAIL to compile (`equipmentDefaultStatuses` unknown).

- [ ] **Step 3: Add the column and the rung**

`diver_tables.dart`, after `hasAcceptedPlanningDisclaimer`:

```dart
  // v286: the statuses the Equipment list's default view shows (issue
  // #2628), a JSON array of EquipmentStatus names. Null reads as the factory
  // default, everything but retired, sold and wanted gear.
  TextColumn get equipmentDefaultStatuses => text().nullable()();
```

`diver_migrations.dart`, at the end of the extension:

```dart
  /// v286: diver_settings.equipment_default_statuses (issue #2628). Column
  /// only, nullable and never backfilled; re-asserted in beforeOpen.
  Future<void> _assertEquipmentDefaultStatusesColumn() async {
    final cols = await customSelect(
      "PRAGMA table_info('diver_settings')",
    ).get();
    if (cols.isEmpty) return;
    final names = cols.map((c) => c.read<String>('name')).toSet();
    if (!names.contains('equipment_default_statuses')) {
      await customStatement(
        'ALTER TABLE diver_settings ADD COLUMN equipment_default_statuses TEXT',
      );
    }
  }
```

`rungs_v231_onward.dart`, after the v283 rung:

```dart
    // v286: diver_settings.equipment_default_statuses (issue #2628). Column
    // only; re-asserted in beforeOpen. 284 and 285 are held by other work.
    if (from < 286) {
      await _assertEquipmentDefaultStatusesColumn();
    }
    if (from < 286) await reportProgress();
```

`before_open.dart`, after the v281 backstop:

```dart
    // v286 backstop: diver_settings.equipment_default_statuses.
    await _assertEquipmentDefaultStatusesColumn();
```

`database.dart`: `currentSchemaVersion = 286`, and after the `283,` entry:

```dart
    // v286: diver_settings.equipment_default_statuses (issue #2628).
    // Additive nullable column, so the floor stays at 280. 284 and 285 are
    // held by a local branch and PR #3306.
    286,
```

Run: `dart run build_runner build --delete-conflicting-outputs`

- [ ] **Step 4: Add the setting to AppSettings, the notifier and the repository**

`settings_providers.dart`: import the Task 1 file. After the `trendGapThreshold` field:

```dart
  /// The statuses the Equipment list shows with no filter set (issue
  /// #2628). Never empty.
  final Set<EquipmentStatus> equipmentDefaultStatuses;
```

Constructor, after `this.trendGapThreshold = TrendGapThreshold.year1,`:

```dart
    this.equipmentDefaultStatuses = factoryDefaultEquipmentStatuses,
```

`copyWith` parameter `Set<EquipmentStatus>? equipmentDefaultStatuses,` and body
`equipmentDefaultStatuses: equipmentDefaultStatuses ?? this.equipmentDefaultStatuses,`.

Setter, after `setTrendGapThreshold`:

```dart
  /// The default equipment view (issue #2628). Waits for the load like
  /// [setTrendGapThreshold], so a pick made first is not overwritten. An
  /// empty set is ignored: the default view always shows something.
  Future<void> setEquipmentDefaultStatuses(Set<EquipmentStatus> value) async {
    if (value.isEmpty) return;
    try {
      await settingsLoaded;
    } catch (_) {
      // Already logged by the load; defaults are the fallback.
    }
    if (!mounted) return;
    state = state.copyWith(
      equipmentDefaultStatuses: Set.unmodifiable(value),
    );
    await _saveSettings();
  }
```

Provider, after `trendGapThresholdProvider`:

```dart
/// The diver's default equipment view (issue #2628).
final equipmentDefaultStatusesProvider = Provider<Set<EquipmentStatus>>((ref) {
  return ref.watch(settingsProvider.select((s) => s.equipmentDefaultStatuses));
});
```

`diver_settings_repository.dart`: import the Task 1 file; at the create site and the update companion, next to `insightsMutedObservationRules`:

```dart
              equipmentDefaultStatuses: Value(
                encodeEquipmentDefaultStatuses(s.equipmentDefaultStatuses),
              ),
```

(`settings.` instead of `s.` in the update companion), and at the read site:

```dart
      equipmentDefaultStatuses: decodeEquipmentDefaultStatuses(
        row.equipmentDefaultStatuses,
      ),
```

Mocks: in `test/helpers/mock_providers.dart` and `test/features/insights/presentation/pages/records_page_test.dart`, next to `setTrendGapThreshold`:

```dart
  @override
  Future<void> setEquipmentDefaultStatuses(Set<EquipmentStatus> value) async {
    if (value.isEmpty) return;
    state = state.copyWith(equipmentDefaultStatuses: value);
  }
```

(Add the `enums.dart` import where missing.)

- [ ] **Step 5: Add a setter test to the repository test file**

```dart
  test('the setter ignores an empty set', () async {
    final notifier = MockSettingsNotifier(
      const AppSettings(equipmentDefaultStatuses: {EquipmentStatus.active}),
    );
    await notifier.setEquipmentDefaultStatuses(const {});
    expect(notifier.state.equipmentDefaultStatuses, {EquipmentStatus.active});
  });
```

Add the import `../../../../helpers/mock_providers.dart`. The real notifier's empty-set guard is exercised end to end in Task 5.

- [ ] **Step 6: Run the tests**

Run: `flutter test test/core/database/migration_v286_equipment_default_statuses_test.dart test/features/settings/data/repositories/diver_settings_repository_equipment_default_view_test.dart test/core/services/sync/sync_diver_settings_equipment_default_view_test.dart`
Expected: PASS. Then `flutter test test/core/database` (the ladder, backstop and 800-line guards).

- [ ] **Step 7: Commit**

```bash
git add lib/core/database/tables/diver_tables.dart lib/core/database/database.dart lib/core/database/database.g.dart lib/core/database/migrations/ lib/features/settings/data/repositories/diver_settings_repository.dart lib/features/settings/presentation/providers/settings_providers.dart test/helpers/mock_providers.dart test/features/insights/presentation/pages/records_page_test.dart test/core/database/migration_v286_equipment_default_statuses_test.dart test/features/settings/data/repositories/diver_settings_repository_equipment_default_view_test.dart test/core/services/sync/sync_diver_settings_equipment_default_view_test.dart
git commit -m "feat(settings): persist and sync the default equipment view"
```

(Stage any other generated file `git status` shows changed by codegen.)

---

### Task 4: Name the setting in the sync conflict dialog

**Files:**
- Create: `lib/features/equipment/presentation/utils/equipment_default_view_label.dart`
- Modify: `lib/features/settings/presentation/conflicts/conflict_enum_labels_settings.dart`
- Modify: `lib/features/settings/presentation/conflicts/catalogue/diver_settings_fields.dart`
- Modify: `lib/l10n/arb/app_en.arb` (2 keys)
- Test: `test/features/equipment/presentation/utils/equipment_default_view_label_test.dart`

**Interfaces:**
- Consumes: Task 1 codec, `EquipmentStatusDisplay.localizedName`.
- Produces:
  - `String equipmentDefaultStatusesLabel(Set<EquipmentStatus> statuses, AppLocalizations l10n)`: localized names in enum order, joined by `l10n.settings_equipmentDefaultView_listSeparator`.
  - `String? equipmentDefaultStatusesLabeler(AppLocalizations l10n, String stored)`
  - ARB keys `settings_equipmentDefaultView_listSeparator` (", "), `settings_conflict_field_equipmentDefaultStatuses` ("Default equipment view").

- [ ] **Step 1: Add the English strings**

In `app_en.arb`, insert by anchor (the file is feature-grouped; never json round-trip it):
- on the line before `"settings_conflict_field_equipmentListViewMode"` (keeps the run sorted): `"settings_conflict_field_equipmentDefaultStatuses": "Default equipment view",`
- a new `"settings_equipmentDefaultView_listSeparator": ", ",` with `"@settings_equipmentDefaultView_listSeparator": {"description": "Joins status names in the default equipment view's summary, e.g. 'Active, Spare'."},` next to the other `settings_e...` keys.

Prove the file parses: `python3.14 -c "import json; json.load(open('lib/l10n/arb/app_en.arb'))"`. Then `flutter gen-l10n` (English only for now; Task 9 regenerates after the translations).

- [ ] **Step 2: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/models/equipment_default_view.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_default_view_label.dart';
import 'package:submersion/features/settings/presentation/conflicts/conflict_enum_labels_settings.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';

void main() {
  final en = AppLocalizationsEn();

  test('the label lists statuses in enum order', () {
    expect(
      equipmentDefaultStatusesLabel({
        EquipmentStatus.lost,
        EquipmentStatus.active,
      }, en),
      'Active, Lost',
    );
    expect(
      equipmentDefaultStatusesLabel(factoryDefaultEquipmentStatuses, en),
      'Active, Spare, Needs Service, In Service, Loaned Out, Lost',
    );
  });

  test('the conflict labeler names a stored set, or nothing it cannot read', () {
    expect(
      equipmentDefaultStatusesLabeler(en, '["active","retired"]'),
      'Active, Retired',
    );
    expect(equipmentDefaultStatusesLabeler(en, 'oops'), isNull);
    expect(equipmentDefaultStatusesLabeler(en, '["hovercraft"]'), isNull);
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/features/equipment/presentation/utils/equipment_default_view_label_test.dart`
Expected: FAIL, the label file does not exist.

- [ ] **Step 4: Implement**

`equipment_default_view_label.dart`:

```dart
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_enum_display.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The default equipment view's statuses as one line (issue #2628), in enum
/// order so it reads the same as the checklist that edits it.
String equipmentDefaultStatusesLabel(
  Set<EquipmentStatus> statuses,
  AppLocalizations l10n,
) => [
  for (final s in EquipmentStatus.values)
    if (statuses.contains(s)) s.localizedName(l10n),
].join(l10n.settings_equipmentDefaultView_listSeparator);
```

`conflict_enum_labels_settings.dart` (with the two imports):

```dart
/// The stored default equipment view (issue #2628), or null for a value
/// this build cannot read, which the dialog then shows raw.
String? equipmentDefaultStatusesLabeler(AppLocalizations l10n, String stored) {
  final statuses = tryDecodeEquipmentDefaultStatuses(stored);
  return statuses == null
      ? null
      : equipmentDefaultStatusesLabel(statuses, l10n);
}
```

`diver_settings_fields.dart`, in key order (before `'equipmentListViewMode'`, or wherever the sorted run places it):

```dart
  'equipmentDefaultStatuses': ConflictField(
    (l) => l.settings_conflict_field_equipmentDefaultStatuses,
    FieldKind.enumValue,
    enumLabel: equipmentDefaultStatusesLabeler,
  ),
```

- [ ] **Step 5: Run the tests**

Run: `flutter test test/features/equipment/presentation/utils/equipment_default_view_label_test.dart test/features/settings/presentation/conflicts/`
Expected: PASS (the catalogue coverage test now finds the new column).

- [ ] **Step 6: Commit**

```bash
git add lib/features/equipment/presentation/utils/equipment_default_view_label.dart lib/features/settings/presentation/conflicts/ lib/l10n/arb/ test/features/equipment/presentation/utils/equipment_default_view_label_test.dart
git commit -m "feat(settings): name the default equipment view in sync conflicts"
```

---

### Task 5: Feed the setting to the list's query

**Files:**
- Modify: `lib/features/equipment/presentation/providers/equipment_query_providers.dart:14-21`
- Modify: `lib/features/equipment/presentation/helpers/saved_equipment_visibility.dart`
- Modify: `lib/features/equipment/presentation/pages/equipment_edit_page.dart:1140` (caller)
- Test: `test/features/equipment/presentation/providers/equipment_query_providers_test.dart`
- Test: `test/features/equipment/presentation/helpers/saved_equipment_visibility_test.dart`

**Interfaces:**
- Consumes: `equipmentDefaultStatusesProvider`, `setEquipmentDefaultStatuses` (Task 3); `compileEquipmentFilter(..., defaultStatuses:)` (Task 2).
- Produces: `viewRevealingSavedEquipment({..., Set<EquipmentStatus> defaultStatuses = factoryDefaultEquipmentStatuses})`.

- [ ] **Step 1: Write the failing tests**

In `equipment_query_providers_test.dart` (fixture: `bcd`, `reg` active; `old` retired):

```dart
  test(
    'changing the default statuses re-queries the open list (#2628)',
    () async {
      expect((await settledItems()).map((e) => e.id).toSet(), {'bcd', 'reg'});
      await container
          .read(settingsProvider.notifier)
          .setEquipmentDefaultStatuses({EquipmentStatus.retired});
      expect((await settledItems()).map((e) => e.id).toSet(), {'old'});
    },
  );

  test('the real setter ignores an empty set', () async {
    final notifier = container.read(settingsProvider.notifier);
    await notifier.setEquipmentDefaultStatuses({EquipmentStatus.active});
    await notifier.setEquipmentDefaultStatuses(const {});
    expect(
      container.read(equipmentDefaultStatusesProvider),
      {EquipmentStatus.active},
    );
  });
```

In `saved_equipment_visibility_test.dart` (fixture: `fins` active, `wish` wanted, `old` retired), extend `reveal` with an optional `defaults` passed as `defaultStatuses:` and add:

```dart
  test('a custom default view that shows the item needs no new view',
      () async {
    expect(
      await reveal(
        const EquipmentFilterState(),
        'old',
        EquipmentStatus.retired,
        defaults: {EquipmentStatus.active, EquipmentStatus.retired},
      ),
      isNull,
    );
  });

  test('a custom default view that hides the item offers its status view',
      () async {
    expect(
      await reveal(
        const EquipmentFilterState(),
        'fins',
        EquipmentStatus.active,
        defaults: {EquipmentStatus.wanted},
      ),
      const EquipmentFilterState(status: EquipmentStatus.active),
    );
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/equipment/presentation/providers/equipment_query_providers_test.dart test/features/equipment/presentation/helpers/saved_equipment_visibility_test.dart`
Expected: FAIL (the list ignores the setting; `defaultStatuses` is not a parameter).

- [ ] **Step 3: Implement**

`equipment_query_providers.dart`:

```dart
final queryFilteredEquipmentIdsProvider = FutureProvider.autoDispose
    .family<Set<String>, ({EquipmentFilterState filter, String? diverId})>(
      // The default view is read here, not keyed: a change rebuilds every
      // live instance, so an open list re-queries at once (#2628).
      (ref, key) => watchQueryIds(
        ref,
        compileEquipmentFilter(
          key.filter,
          diverId: key.diverId,
          defaultStatuses: ref.watch(equipmentDefaultStatusesProvider),
        ),
        scope: key.filter.ownerScope(key.diverId),
      ),
    );
```

(Import `settings_providers.dart`.)

`saved_equipment_visibility.dart`: add the parameter, documented as "the diver's default view (#2628), which the list's unfiltered view and the default view offered here both use", and pass it to both `compileEquipmentFilter` calls via `shows`:

```dart
  Set<EquipmentStatus> defaultStatuses = factoryDefaultEquipmentStatuses,
```

```dart
    final compiled = compileEquipmentFilter(
      view,
      diverId: diverId,
      defaultStatuses: defaultStatuses,
    );
```

`equipment_edit_page.dart` caller: add `defaultStatuses: ref.read(equipmentDefaultStatusesProvider),`.

- [ ] **Step 4: Run tests**

Run: `flutter test test/features/equipment/presentation/providers/ test/features/equipment/presentation/helpers/ test/features/equipment/presentation/pages/`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/equipment/presentation/providers/equipment_query_providers.dart lib/features/equipment/presentation/helpers/saved_equipment_visibility.dart lib/features/equipment/presentation/pages/equipment_edit_page.dart test/features/equipment/presentation/providers/equipment_query_providers_test.dart test/features/equipment/presentation/helpers/saved_equipment_visibility_test.dart
git commit -m "feat(equipment): open the Equipment list on the diver's default view"
```

---

### Task 6: Settings page and Manage row

**Files:**
- Create: `lib/features/settings/presentation/pages/equipment_default_view_page.dart`
- Create: `lib/features/settings/presentation/widgets/equipment_default_view_tile.dart`
- Modify: `lib/core/router/app_router.dart` (route under `/settings`, beside `default-metrics`)
- Modify: `lib/features/settings/presentation/pages/settings_page.dart` (tile after the Locations row, ~line 2373)
- Modify: `lib/l10n/arb/app_en.arb` (2 keys)
- Test: `test/features/settings/presentation/pages/equipment_default_view_page_test.dart`

**Interfaces:**
- Consumes: Tasks 1, 3, 4.
- Produces: `class EquipmentDefaultViewPage extends ConsumerWidget`, `const String kEquipmentDefaultViewRoute = '/settings/equipment-default-view'`, `class EquipmentDefaultViewTile extends ConsumerWidget`. Widget keys: `equipment_default_view_<status.name>`, `equipment_default_view_reset`, `settings_manage_equipmentDefaultView`.
- ARB keys: `settings_equipmentDefaultView_title` ("Default equipment view"), `settings_equipmentDefaultView_intro` ("When no filter is set, the Equipment list shows gear with these statuses."). Reset reuses `equipment_arrange_reset` ("Reset to defaults").

- [ ] **Step 1: Add the English strings** next to `settings_equipmentDefaultView_listSeparator` (sorted: `_intro`, `_listSeparator`, `_title`), then `json.load` the file and run `flutter gen-l10n`.

- [ ] **Step 2: Write the failing tests**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/models/equipment_default_view.dart';
import 'package:submersion/features/settings/presentation/pages/equipment_default_view_page.dart';
import 'package:submersion/features/settings/presentation/pages/settings_page.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

void main() {
  Future<MockSettingsNotifier> pump(
    WidgetTester tester,
    Set<EquipmentStatus> statuses,
  ) async {
    final notifier = MockSettingsNotifier(
      AppSettings(equipmentDefaultStatuses: statuses),
    );
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [settingsProvider.overrideWith((ref) => notifier)],
        child: const EquipmentDefaultViewPage(),
      ),
    );
    await tester.pumpAndSettle();
    return notifier;
  }

  CheckboxListTile box(WidgetTester tester, EquipmentStatus s) =>
      tester.widget(find.byKey(ValueKey('equipment_default_view_${s.name}')));

  testWidgets('every status is listed, ticked when in the default view', (
    tester,
  ) async {
    await pump(tester, factoryDefaultEquipmentStatuses);
    for (final s in EquipmentStatus.values) {
      expect(
        box(tester, s).value,
        factoryDefaultEquipmentStatuses.contains(s),
        reason: s.name,
      );
    }
    expect(find.text('Default equipment view'), findsOneWidget);
  });

  testWidgets('ticking and unticking edits the setting', (tester) async {
    final notifier = await pump(tester, {EquipmentStatus.active});
    await tester.tap(find.byKey(const ValueKey('equipment_default_view_lost')));
    await tester.pumpAndSettle();
    expect(notifier.state.equipmentDefaultStatuses, {
      EquipmentStatus.active,
      EquipmentStatus.lost,
    });
    await tester.tap(
      find.byKey(const ValueKey('equipment_default_view_active')),
    );
    await tester.pumpAndSettle();
    expect(notifier.state.equipmentDefaultStatuses, {EquipmentStatus.lost});
  });

  testWidgets('the last ticked status cannot be unticked', (tester) async {
    await pump(tester, {EquipmentStatus.active});
    expect(box(tester, EquipmentStatus.active).onChanged, isNull);
    expect(box(tester, EquipmentStatus.spare).onChanged, isNotNull);
  });

  testWidgets('Reset restores the factory set, and is off when already there',
      (tester) async {
    final notifier = await pump(tester, {EquipmentStatus.active});
    final reset = find.byKey(const ValueKey('equipment_default_view_reset'));
    await tester.ensureVisible(reset);
    await tester.tap(reset);
    await tester.pumpAndSettle();
    expect(
      notifier.state.equipmentDefaultStatuses,
      factoryDefaultEquipmentStatuses,
    );
    expect(tester.widget<TextButton>(reset).onPressed, isNull);
  });

  testWidgets('Manage lists the default view with its statuses', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) =>
              const SettingsSectionDetailPage(sectionId: 'manage'),
        ),
        GoRoute(
          path: kEquipmentDefaultViewRoute,
          builder: (context, state) => const EquipmentDefaultViewPage(),
        ),
      ],
    );
    await tester.pumpWidget(
      testAppRouter(
        router: router,
        // Riverpod refuses a second settingsProvider override, so the
        // notifier goes through getBaseOverrides' own parameter.
        overrides: await getBaseOverrides(
          settingsNotifier: MockSettingsNotifier(
            const AppSettings(
              hasAcceptedPlanningDisclaimer: true,
              equipmentDefaultStatuses: {
                EquipmentStatus.active,
                EquipmentStatus.spare,
              },
            ),
          ),
        ),
        locale: const Locale('en'),
      ),
    );
    await tester.pumpAndSettle();
    final tile = find.byKey(const ValueKey('settings_manage_equipmentDefaultView'));
    await tester.scrollUntilVisible(
      tile,
      100,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Active, Spare'), findsOneWidget);
    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(find.byType(EquipmentDefaultViewPage), findsOneWidget);
  });
}
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `flutter test test/features/settings/presentation/pages/equipment_default_view_page_test.dart`
Expected: FAIL, the page does not exist.

- [ ] **Step 4: Implement the page**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/models/equipment_default_view.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_enum_display.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

const String kEquipmentDefaultViewRoute = '/settings/equipment-default-view';

/// Which statuses the Equipment list shows with no filter set (issue
/// #2628). Changes save as they are made; at least one status stays ticked
/// so the list never opens empty by design.
class EquipmentDefaultViewPage extends ConsumerWidget {
  const EquipmentDefaultViewPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final selected = ref.watch(equipmentDefaultStatusesProvider);
    final notifier = ref.read(settingsProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings_equipmentDefaultView_title)),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              l10n.settings_equipmentDefaultView_intro,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          for (final status in EquipmentStatus.values)
            CheckboxListTile(
              key: ValueKey('equipment_default_view_${status.name}'),
              title: Text(status.localizedName(l10n)),
              value: selected.contains(status),
              onChanged: selected.length == 1 && selected.contains(status)
                  ? null
                  : (ticked) => notifier.setEquipmentDefaultStatuses(
                      ticked == true
                          ? {...selected, status}
                          : selected.difference({status}),
                    ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                key: const ValueKey('equipment_default_view_reset'),
                onPressed: isFactoryDefaultEquipmentStatuses(selected)
                    ? null
                    : () => notifier.setEquipmentDefaultStatuses(
                        factoryDefaultEquipmentStatuses,
                      ),
                child: Text(l10n.equipment_arrange_reset),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

Tile (`equipment_default_view_tile.dart`):

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/features/equipment/presentation/utils/equipment_default_view_label.dart';
import 'package:submersion/features/settings/presentation/pages/equipment_default_view_page.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Settings > Manage row for the default equipment view (issue #2628); its
/// subtitle is the statuses the view shows.
class EquipmentDefaultViewTile extends ConsumerWidget {
  const EquipmentDefaultViewTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return ListTile(
      key: const ValueKey('settings_manage_equipmentDefaultView'),
      leading: const Icon(Icons.filter_list),
      title: Text(l10n.settings_equipmentDefaultView_title),
      subtitle: Text(
        equipmentDefaultStatusesLabel(
          ref.watch(equipmentDefaultStatusesProvider),
          l10n,
        ),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push(kEquipmentDefaultViewRoute),
    );
  }
}
```

`settings_page.dart`, after the Locations `ListTile` (`key: ValueKey('settings_manage_locations')`):

```dart
                const Divider(height: 1),
                const EquipmentDefaultViewTile(),
```

`app_router.dart`, beside the `default-metrics` route (and its import):

```dart
              GoRoute(
                path: 'equipment-default-view',
                name: 'equipmentDefaultView',
                builder: (context, state) => const EquipmentDefaultViewPage(),
              ),
```

- [ ] **Step 5: Run tests**

Run: `flutter test test/features/settings/presentation/pages/equipment_default_view_page_test.dart test/features/settings/presentation/pages/settings_manage_nav_routes_test.dart test/features/settings/presentation/pages/settings_page_test.dart`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add lib/features/settings/presentation/pages/equipment_default_view_page.dart lib/features/settings/presentation/widgets/equipment_default_view_tile.dart lib/core/router/app_router.dart lib/features/settings/presentation/pages/settings_page.dart lib/l10n/arb/ test/features/settings/presentation/pages/equipment_default_view_page_test.dart
git commit -m "feat(settings): choose the default equipment view under Manage"
```

---

### Task 7: Filter panel: "Default View" chip and "Edit default" link

**Files:**
- Modify: `lib/features/equipment/presentation/widgets/equipment_filter_sheet.dart` (`_buildStatusSection` heading, ~line 221)
- Modify: `lib/l10n/arb/app_en.arb` (`equipment_list_filterCurrent` value and description; new `equipment_filter_editDefault`)
- Modify: `test/features/equipment/presentation/widgets/equipment_filter_sheet_test.dart` (line ~257 expects "Current Equipment"; doc comment at ~101)

**Interfaces:**
- Consumes: `EquipmentDefaultViewPage` (Task 6).
- Produces: widget key `equipment_filter_editDefault`.

- [ ] **Step 1: Strings**

Change `"equipment_list_filterCurrent": "Default View",` and its description to `"Equipment filter status chip for the diver's default view: the statuses chosen in Settings > Manage > Default equipment view (issue #2628)"`. Add `"equipment_filter_editDefault": "Edit default",` with `"@equipment_filter_editDefault": {"description": "Button beside the Status heading in the equipment filter panel that opens the default equipment view settings"},` in the `equipment_filter_*` group. `json.load`, then `flutter gen-l10n`.

- [ ] **Step 2: Write the failing tests**

Update the existing expectation at line ~257 from `'Current Equipment'` to `'Default View'` and the doc comment at ~101. Add:

```dart
  testWidgets('Edit default opens the default view settings over the panel',
      (tester) async {
    final container = await _container();
    addTearDown(container.dispose);
    await tester.pumpWidget(_app(container));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('equipment_filter_editDefault')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(EquipmentDefaultViewPage), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(EquipmentFilterSheet), findsOneWidget);
  });
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `flutter test test/features/equipment/presentation/widgets/equipment_filter_sheet_test.dart`
Expected: FAIL (no Edit default button; the label assertion fails before regeneration if gen-l10n was not run).

- [ ] **Step 4: Implement**

Replace the Status heading `Text` in `_buildStatusSection` with:

```dart
        Row(
          children: [
            Expanded(
              child: Text(
                context.l10n.equipment_filter_section_status,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            // Opens over the panel, which keeps its draft; the list follows
            // the new default as soon as it is saved (#2628).
            TextButton(
              key: const ValueKey('equipment_filter_editDefault'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const EquipmentDefaultViewPage(),
                ),
              ),
              child: Text(context.l10n.equipment_filter_editDefault),
            ),
          ],
        ),
```

Also update the chip's comment to `// The default view: the diver's chosen statuses (#636, #2628).`

- [ ] **Step 5: Run tests**

Run: `flutter test test/features/equipment/presentation/widgets/`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add lib/features/equipment/presentation/widgets/equipment_filter_sheet.dart lib/l10n/arb/ test/features/equipment/presentation/widgets/equipment_filter_sheet_test.dart
git commit -m "feat(equipment): rename the default chip and link it to its settings"
```

---

### Task 8: Empty state when the default view hides the diver's gear

**Files:**
- Create: `lib/features/equipment/presentation/widgets/equipment_default_view_empty_state.dart`
- Modify: `lib/features/equipment/presentation/widgets/equipment_list_content.dart` (`_buildEmptyState`, ~line 1267)
- Modify: `lib/l10n/arb/app_en.arb` (3 keys)
- Test: `test/features/equipment/presentation/widgets/equipment_default_view_empty_state_test.dart`

**Interfaces:**
- Produces: `class EquipmentDefaultViewEmptyState extends ConsumerWidget`; widget key `equipment_list_showAll`.
- ARB keys: `equipment_list_emptyState_defaultView_title` ("No equipment in your default view"), `equipment_list_emptyState_defaultView_subtitle` ("Your default view hides the rest of your gear."), `equipment_list_emptyState_showAll` ("Show All Equipment").

- [ ] **Step 1: Strings** in the `equipment_list_emptyState_*` group (sorted), `json.load`, `flutter gen-l10n`.

- [ ] **Step 2: Write the failing tests**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_list_content.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/equipment_query_fakes.dart';
import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

/// The default view is the diver's to choose (#2628), so it can hide every
/// item they own; the list must not then invite them to add their first.
Future<void> _pump(WidgetTester tester, List<EquipmentItem> owned) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    testApp(
      locale: const Locale('en'),
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        currentDiverIdProvider.overrideWith(
          (ref) => MockCurrentDiverIdNotifier(),
        ),
        // The fake reads the default view from the active list.
        activeEquipmentProvider.overrideWith(
          (ref) async => const <EquipmentItem>[],
        ),
        allEquipmentProvider.overrideWith((ref) async => owned),
        fakeEquipmentQueryIds(),
        equipmentListViewModeProvider.overrideWith(
          (ref) => ListViewMode.detailed,
        ),
      ],
      child: const EquipmentListContent(showAppBar: true),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  const spareReg = EquipmentItem(
    id: 'reg',
    name: 'Spare Regulator',
    type: EquipmentType.regulator,
    status: EquipmentStatus.spare,
  );

  testWidgets('a default view hiding owned gear says so and offers it all', (
    tester,
  ) async {
    await _pump(tester, const [spareReg]);
    expect(find.text('No equipment in your default view'), findsOneWidget);
    expect(
      find.text('Your default view hides the rest of your gear.'),
      findsOneWidget,
    );
    expect(find.text('Add Your First Equipment'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('equipment_list_showAll')));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(EquipmentListContent)),
    );
    expect(container.read(equipmentFilterProvider).allStatuses, isTrue);
    expect(find.text('Spare Regulator'), findsWidgets);
  });

  testWidgets('with no gear at all the add prompt stays', (tester) async {
    await _pump(tester, const []);
    expect(find.text('No equipment in your default view'), findsNothing);
    expect(find.text('Add Your First Equipment'), findsOneWidget);
  });
}
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `flutter test test/features/equipment/presentation/widgets/equipment_default_view_empty_state_test.dart`
Expected: FAIL, the old empty state with "Add Your First Equipment" shows.

- [ ] **Step 4: Implement**

`equipment_default_view_empty_state.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The empty list when the diver's default view (#2628) hides every item
/// they own: it names the view as the cause and offers All Equipment,
/// rather than inviting them to add gear they already have.
class EquipmentDefaultViewEmptyState extends ConsumerWidget {
  const EquipmentDefaultViewEmptyState({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.backpack,
            size: 80,
            color: theme.colorScheme.primary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.equipment_list_emptyState_defaultView_title,
            style: theme.textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.equipment_list_emptyState_defaultView_subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            key: const ValueKey('equipment_list_showAll'),
            onPressed: () {
              final notifier = ref.read(equipmentFilterProvider.notifier);
              notifier.state = notifier.state.copyWith(allStatuses: true);
            },
            icon: const Icon(Icons.inventory_2_outlined),
            label: Text(l10n.equipment_list_emptyState_showAll),
          ),
        ],
      ),
    );
  }
}
```

In `_buildEmptyState`, right after `final filter = ref.watch(effectiveEquipmentFilterProvider);`:

```dart
    // The default view is the diver's choice (#2628) and can hide all they
    // own; with no other filter set, that is the only cause left.
    if (!filter.hasActiveFilters &&
        (ref.watch(allEquipmentProvider).value?.isNotEmpty ?? false)) {
      return const EquipmentDefaultViewEmptyState();
    }
```

- [ ] **Step 5: Run tests**

Run: `flutter test test/features/equipment/presentation/widgets/`
Expected: PASS (including `equipment_service_due_empty_state_test.dart` and `equipment_list_content_test.dart`)

- [ ] **Step 6: Commit**

```bash
git add lib/features/equipment/presentation/widgets/equipment_default_view_empty_state.dart lib/features/equipment/presentation/widgets/equipment_list_content.dart lib/l10n/arb/ test/features/equipment/presentation/widgets/equipment_default_view_empty_state_test.dart
git commit -m "feat(equipment): explain an empty default view instead of asking to add gear"
```

---

### Task 9: Translations

**Files:**
- Modify: `lib/l10n/arb/app_{ar,de,es,fr,he,hu,it,nl,pt,zh}.arb`
- Regenerate: `lib/l10n/arb/app_localizations*.dart`

Ten keys per locale: the changed `equipment_list_filterCurrent` value and nine new keys. Insert new keys by anchor (each after an existing key of the same group, found with `grep -n`); rewrite the changed value in place. Never json round-trip a locale file; `json.load` each afterwards. Locale files need no `@` metadata.

| key | de | es | fr | it | nl |
| --- | --- | --- | --- | --- | --- |
| equipment_list_filterCurrent | Standardansicht | Vista predeterminada | Vue par défaut | Vista predefinita | Standaardweergave |
| equipment_filter_editDefault | Standard bearbeiten | Editar predeterminada | Modifier la vue par défaut | Modifica predefinita | Standaard bewerken |
| equipment_list_emptyState_defaultView_title | Keine Ausrüstung in Ihrer Standardansicht | No hay equipo en tu vista predeterminada | Aucun équipement dans votre vue par défaut | Nessuna attrezzatura nella vista predefinita | Geen uitrusting in je standaardweergave |
| equipment_list_emptyState_defaultView_subtitle | Ihre Standardansicht blendet Ihre übrige Ausrüstung aus. | Tu vista predeterminada oculta el resto de tu equipo. | Votre vue par défaut masque le reste de votre équipement. | La vista predefinita nasconde il resto della tua attrezzatura. | Je standaardweergave verbergt de rest van je uitrusting. |
| equipment_list_emptyState_showAll | Gesamte Ausrüstung anzeigen | Mostrar todo el equipo | Afficher tout l'équipement | Mostra tutta l'attrezzatura | Alle uitrusting tonen |
| settings_equipmentDefaultView_title | Standardansicht der Ausrüstung | Vista predeterminada del equipo | Vue par défaut de l'équipement | Vista predefinita dell'attrezzatura | Standaardweergave van de uitrusting |
| settings_equipmentDefaultView_intro | Ohne Filter zeigt die Ausrüstungsliste Ausrüstung mit diesen Status. | Sin filtro, la lista de equipo muestra el equipo con estos estados. | Sans filtre, la liste de l'équipement affiche le matériel ayant ces statuts. | Senza filtri, l'elenco dell'attrezzatura mostra l'attrezzatura con questi stati. | Zonder filter toont de uitrustingslijst uitrusting met deze statussen. |
| settings_equipmentDefaultView_listSeparator | `, ` | `, ` | `, ` | `, ` | `, ` |
| settings_conflict_field_equipmentDefaultStatuses | Standardansicht der Ausrüstung | Vista predeterminada del equipo | Vue par défaut de l'équipement | Vista predefinita dell'attrezzatura | Standaardweergave van de uitrusting |

| key | pt | hu | ar | he | zh |
| --- | --- | --- | --- | --- | --- |
| equipment_list_filterCurrent | Visualização Padrão | Alapnézet | العرض الافتراضي | תצוגת ברירת מחדל | 默认视图 |
| equipment_filter_editDefault | Editar padrão | Alapnézet szerkesztése | تعديل الافتراضي | עריכת ברירת המחדל | 编辑默认 |
| equipment_list_emptyState_defaultView_title | Nenhum equipamento na sua visualização padrão | Nincs felszerelés az alapnézetben | لا توجد معدات في العرض الافتراضي | אין ציוד בתצוגת ברירת המחדל שלך | 默认视图中没有装备 |
| equipment_list_emptyState_defaultView_subtitle | Sua visualização padrão oculta o restante dos seus equipamentos. | Az alapnézet elrejti a többi felszerelésedet. | يخفي العرض الافتراضي بقية معداتك. | תצוגת ברירת המחדל מסתירה את שאר הציוד שלך. | 默认视图隐藏了你的其他装备。 |
| equipment_list_emptyState_showAll | Mostrar Todos os Equipamentos | Összes felszerelés megjelenítése | عرض جميع المعدات | הצגת כל הציוד | 显示全部装备 |
| settings_equipmentDefaultView_title | Visualização padrão dos equipamentos | Felszerelés alapnézete | العرض الافتراضي للمعدات | תצוגת ברירת מחדל של הציוד | 装备默认视图 |
| settings_equipmentDefaultView_intro | Sem filtro, a lista de equipamentos mostra os equipamentos com estes status. | Szűrő nélkül a felszereléslista az ilyen állapotú felszereléseket mutatja. | عند عدم تعيين أي عامل تصفية، تعرض قائمة المعدات المعدات ذات هذه الحالات. | כשאין מסנן, רשימת הציוד מציגה ציוד בסטטוסים אלה. | 未设置筛选时，装备列表显示这些状态的装备。 |
| settings_equipmentDefaultView_listSeparator | `, ` | `, ` | `، ` | `, ` | `、` |
| settings_conflict_field_equipmentDefaultStatuses | Visualização padrão dos equipamentos | Felszerelés alapnézete | العرض الافتراضي للمعدات | תצוגת ברירת מחדל של הציוד | 装备默认视图 |

- [ ] **Step 1:** Write the inserts with a python3.14 script in the scratchpad (anchor-line insertion, `json.dumps(value, ensure_ascii=False)`), then `json.load` all 11 ARBs.
- [ ] **Step 2:** `flutter gen-l10n` (last), then confirm no untranslated messages for these keys and spot-check: `grep -A1 "get equipment_list_filterCurrent" lib/l10n/arb/app_localizations_de.dart` shows `Standardansicht`.
- [ ] **Step 3:** `git diff --numstat -- lib/l10n/arb/*.arb` shows equal +10/-1 rows for every locale (nine new keys plus the rewritten chip label); explain any row that differs.
- [ ] **Step 4:** `flutter test test/l10n/`
- [ ] **Step 5: Commit**

```bash
git add lib/l10n/arb/
git commit -m "i18n(equipment): translate the default equipment view"
```

---

### Task 10: Whole-branch checks

- [ ] **Step 1:** `dart format .` (commit any changes as part of the last task's files).
- [ ] **Step 2:** `flutter analyze`: no issues.
- [ ] **Step 3:** `flutter test test/architecture/ test/shared/` (new files under `lib/`).
- [ ] **Step 4:** `flutter test test/core/database test/core/services/sync test/features/equipment test/features/settings test/features/insights/presentation/pages/records_page_test.dart test/l10n`
- [ ] **Step 5:** Scan the diff for dashes used as punctuation: `git diff origin/main -- . ':!lib/l10n' | grep -nP '^\+.*(\xe2\x80\x93|\xe2\x80\x94)'` returns nothing (the bytes of the en and em dash).
