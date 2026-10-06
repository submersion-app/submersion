# Hide Built-in Entries Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task, inline in this session. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let each diver hide built-in dive types, dive roles, site types, service types and pre-dive checklist templates from the pickers, with a labeled "Show" switch column on every Manage page (Tank Presets included).

**Architecture:** One nullable JSON column `diver_settings.hidden_built_in_ids` (schema v261) holds `{catalogKey: [ids]}` per diver and syncs with the settings row. `AppSettings.hiddenBuiltInIds` carries it; `SettingsNotifier.setBuiltInHidden` writes it. A family provider `hiddenBuiltInIdsProvider(catalog)` exposes one catalog's set, and a pure helper `visibleBuiltIns` narrows a picker's list while keeping selected values. Two shared widgets draw the labeled column.

**Tech Stack:** Flutter, Riverpod (legacy StateNotifier plus Provider.family), Drift (SQLite), flutter_test, ARB l10n via `flutter gen-l10n`.

**Spec:** `docs/design/specs/2026-10-05-hide-built-in-entries-design.md`

**Renumbered after this plan was executed:** while this branch was open, other rungs took v261 through v267 and #3043 holds v268, so the column landed as **v269** (`from < 269`, test `migration_v269_hidden_built_ins_test.dart`). Read every v261 below as v269.

## Global Constraints

- Issue: #401. Release: v1.8.2.
- Schema: `currentSchemaVersion` goes from 260 to 261. The rung lives in `lib/core/database/migrations/ladder/rungs_v231_onward.dart`; the column assert lives in `lib/core/database/migrations/helpers/diver_migrations.dart`; the table column in `lib/core/database/tables/diver_tables.dart`. Never add a table or rung body to `database.dart` (only the version constant and the `migrationVersions` entry go there).
- Column-only rung, no backfill. `minimumCompatibleSchemaVersion` stays 240.
- Catalog keys are stored and synced; never rename them: `diveTypes`, `diveRoles`, `siteTypes`, `serviceKinds`, `preDiveTemplates`.
- Encoding: keys sorted, ids sorted, empty catalogs omitted, nothing hidden encodes to null.
- Decoding never throws: null, empty, malformed JSON, or wrongly typed values read as nothing hidden. Unknown keys are kept.
- Hiding narrows pickers only. Labels, exports, import matching, filters, insights, statistics and Manage pages keep the full lists.
- A custom (non built-in) entry is never hidden.
- Hidden service types do not auto-attach to new equipment. Existing clocks are untouched.
- New strings in all 11 ARB locales: `builtIns_showColumnLabel` ("Show") and `builtIns_showInPickers` ("Show in pickers").
- No em dashes anywhere (code, comments, strings, commits). No mention of AI tools in commits.
- `dart format .` before every commit. Paths in tests via `p.join`, never `/`.
- A test that changes process-wide state restores it.

## Review Focus

1. **A hidden entry already on a record.** Opening a dive whose type is hidden, a buddy with a hidden role, a site with a hidden type, or a service record of a hidden kind must still show and keep that value. Pinned by keep-tests in Tasks 7, 8, 9, 10.
2. **Unchecking a hidden site type must not make its chip vanish** mid-edit (keep = original types plus current selection). Pinned in Task 9.
3. **Settings arriving by sync from a newer app version** with an unknown catalog key must survive a save by this version. Pinned in Task 1 (codec) and Task 3 (repository round trip).
4. **Switching diver profiles** must switch hidden sets. Covered by the per-diver settings row; pinned in Task 3 (two divers, independent sets).
5. **Long translations of "Show"** (Hungarian "Megjelenítés") must not push the header out of alignment with the switches. Pinned in Task 5 (alignment test under `hu`).

---

## File Structure

Create:
- `lib/core/built_ins/built_in_catalog.dart`: `BuiltInCatalog` enum and the pure `withBuiltInHidden` transition.
- `lib/core/built_ins/hidden_built_ins_codec.dart`: `encodeHiddenBuiltIns` / `decodeHiddenBuiltIns`.
- `lib/core/built_ins/visible_built_ins.dart`: generic `visibleBuiltIns`.
- `lib/features/settings/presentation/providers/hidden_built_ins_provider.dart`: `hiddenBuiltInIdsProvider`.
- `lib/shared/widgets/built_in_show_column.dart`: `BuiltInShowColumnHeader`, `BuiltInShowSwitch`, `builtInShowSwitchKey`, `kBuiltInShowColumnWidth`.
- Tests listed per task.

Modify:
- `lib/core/database/tables/diver_tables.dart`, `.../migrations/helpers/diver_migrations.dart`, `.../migrations/ladder/rungs_v231_onward.dart`, `.../migrations/before_open.dart`, `lib/core/database/database.dart`.
- `lib/features/settings/presentation/providers/settings_providers.dart`, `lib/features/settings/data/repositories/diver_settings_repository.dart`.
- Five fake settings notifiers in tests (Task 3).
- Six Manage pages, the pickers listed in the spec, `service_schedule_repository.dart`.
- All 11 ARB files plus regenerated `lib/l10n/arb/app_localizations*.dart`.

---

### Task 1: Pure core: catalog enum, codec, visibility helper

**Files:**
- Create: `lib/core/built_ins/built_in_catalog.dart`
- Create: `lib/core/built_ins/hidden_built_ins_codec.dart`
- Create: `lib/core/built_ins/visible_built_ins.dart`
- Test: `test/core/built_ins/built_in_catalog_test.dart`
- Test: `test/core/built_ins/hidden_built_ins_codec_test.dart`
- Test: `test/core/built_ins/visible_built_ins_test.dart`

**Interfaces:**
- Produces:
  - `enum BuiltInCatalog { diveTypes, diveRoles, siteTypes, serviceKinds, preDiveTemplates }` with `final String key`.
  - `Map<String, Set<String>> withBuiltInHidden(Map<String, Set<String>> current, BuiltInCatalog catalog, String id, bool hidden)`
  - `String? encodeHiddenBuiltIns(Map<String, Set<String>> hidden)`
  - `Map<String, Set<String>> decodeHiddenBuiltIns(String? raw)`
  - `List<T> visibleBuiltIns<T>(List<T> all, Set<String> hidden, {required bool Function(T) isBuiltIn, required String Function(T) idOf, Iterable<String?> keep = const []})`

- [ ] **Step 1: Write the failing tests**

`test/core/built_ins/built_in_catalog_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/built_ins/built_in_catalog.dart';

void main() {
  test('catalog keys are the stored, synced names', () {
    expect({for (final c in BuiltInCatalog.values) c.name: c.key}, {
      'diveTypes': 'diveTypes',
      'diveRoles': 'diveRoles',
      'siteTypes': 'siteTypes',
      'serviceKinds': 'serviceKinds',
      'preDiveTemplates': 'preDiveTemplates',
    });
  });

  group('withBuiltInHidden', () {
    test('adds an id to an empty map', () {
      expect(
        withBuiltInHidden(const {}, BuiltInCatalog.diveRoles, 'solo', true),
        {'diveRoles': {'solo'}},
      );
    });

    test('removing the last id drops the catalog key', () {
      expect(
        withBuiltInHidden(
          const {'diveRoles': {'solo'}},
          BuiltInCatalog.diveRoles,
          'solo',
          false,
        ),
        isEmpty,
      );
    });

    test('leaves other catalogs, including unknown keys, untouched', () {
      final next = withBuiltInHidden(
        const {
          'siteTypes': {'lake'},
          'futureKind': {'x'},
        },
        BuiltInCatalog.diveTypes,
        'night',
        true,
      );
      expect(next, {
        'siteTypes': {'lake'},
        'futureKind': {'x'},
        'diveTypes': {'night'},
      });
    });

    test('returns the same map when nothing changes', () {
      const current = {
        'diveTypes': {'night'},
      };
      expect(
        identical(
          withBuiltInHidden(current, BuiltInCatalog.diveTypes, 'night', true),
          current,
        ),
        isTrue,
      );
    });

    test('does not mutate its input', () {
      final current = {
        'diveTypes': {'night'},
      };
      withBuiltInHidden(current, BuiltInCatalog.diveTypes, 'wreck', true);
      expect(current, {
        'diveTypes': {'night'},
      });
    });
  });
}
```

`test/core/built_ins/hidden_built_ins_codec_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/built_ins/hidden_built_ins_codec.dart';

void main() {
  group('encodeHiddenBuiltIns', () {
    test('nothing hidden encodes to null', () {
      expect(encodeHiddenBuiltIns(const {}), isNull);
      expect(encodeHiddenBuiltIns(const {'diveTypes': <String>{}}), isNull);
    });

    test('sorts keys and ids so equal contents encode equal', () {
      final a = encodeHiddenBuiltIns({
        'siteTypes': {'wall', 'lake'},
        'diveRoles': {'solo'},
      });
      final b = encodeHiddenBuiltIns({
        'diveRoles': {'solo'},
        'siteTypes': {'lake', 'wall'},
      });
      expect(a, b);
      expect(a, '{"diveRoles":["solo"],"siteTypes":["lake","wall"]}');
    });

    test('omits empty catalogs', () {
      expect(
        encodeHiddenBuiltIns({
          'diveRoles': <String>{},
          'diveTypes': {'night'},
        }),
        '{"diveTypes":["night"]}',
      );
    });
  });

  group('decodeHiddenBuiltIns', () {
    test('null and empty read as nothing hidden', () {
      expect(decodeHiddenBuiltIns(null), isEmpty);
      expect(decodeHiddenBuiltIns(''), isEmpty);
    });

    test('malformed or wrongly typed input reads as nothing hidden', () {
      expect(decodeHiddenBuiltIns('{not json'), isEmpty);
      expect(decodeHiddenBuiltIns('["a"]'), isEmpty);
      expect(decodeHiddenBuiltIns('42'), isEmpty);
    });

    test('skips entries that are not a list of strings', () {
      expect(
        decodeHiddenBuiltIns(
          '{"diveTypes":"night","siteTypes":[1,"lake",""],"diveRoles":[]}',
        ),
        {
          'siteTypes': {'lake'},
        },
      );
    });

    test('keeps unknown catalog keys through a round trip', () {
      const raw = '{"diveTypes":["night"],"futureKind":["x"]}';
      expect(encodeHiddenBuiltIns(decodeHiddenBuiltIns(raw)), raw);
    });
  });
}
```

`test/core/built_ins/visible_built_ins_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/built_ins/visible_built_ins.dart';

class _Entry {
  const _Entry(this.id, {this.builtIn = true});
  final String id;
  final bool builtIn;
}

List<_Entry> _visible(
  List<_Entry> all,
  Set<String> hidden, {
  Iterable<String?> keep = const [],
}) => visibleBuiltIns(
  all,
  hidden,
  isBuiltIn: (e) => e.builtIn,
  idOf: (e) => e.id,
  keep: keep,
);

void main() {
  const a = _Entry('a');
  const b = _Entry('b');
  const c = _Entry('c');
  const customB = _Entry('b', builtIn: false);

  test('returns the same list when nothing is hidden', () {
    final all = [a, b];
    expect(identical(_visible(all, const {}), all), isTrue);
  });

  test('drops hidden built-ins and keeps the order of the rest', () {
    expect(_visible([a, b, c], {'b'}), [a, c]);
  });

  test('never drops a custom entry, even one sharing a built-in id', () {
    expect(_visible([a, customB], {'b'}), [a, customB]);
  });

  test('keeps a hidden entry that is currently selected', () {
    expect(_visible([a, b, c], {'b', 'c'}, keep: ['c', null]), [a, c]);
  });

  test('ignores hidden ids that match nothing', () {
    final all = [a, b];
    expect(identical(_visible(all, {'gone'}), all), isTrue);
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/core/built_ins/`
Expected: FAIL, the three `lib/core/built_ins/` imports do not exist.

- [ ] **Step 3: Write the implementation**

`lib/core/built_ins/built_in_catalog.dart`:

```dart
/// The catalogs whose built-in entries a diver can hide from the pickers
/// (issue #401). Tank presets predate this and keep their own column.
enum BuiltInCatalog {
  diveTypes('diveTypes'),
  diveRoles('diveRoles'),
  siteTypes('siteTypes'),
  serviceKinds('serviceKinds'),
  preDiveTemplates('preDiveTemplates');

  const BuiltInCatalog(this.key);

  /// The key this catalog is stored under in
  /// `diver_settings.hidden_built_in_ids`. Synced rows carry it, so it must
  /// never be renamed.
  final String key;
}

/// [current] with [id] hidden or shown in [catalog]. Other catalogs, including
/// keys this version does not know, are carried over unchanged, and a catalog
/// left with no hidden ids is dropped. Returns [current] itself when nothing
/// changes.
Map<String, Set<String>> withBuiltInHidden(
  Map<String, Set<String>> current,
  BuiltInCatalog catalog,
  String id,
  bool hidden,
) {
  final ids = current[catalog.key] ?? const <String>{};
  if (ids.contains(id) == hidden) return current;
  final next = hidden ? {...ids, id} : {for (final x in ids) if (x != id) x};
  return {
    for (final entry in current.entries)
      if (entry.key != catalog.key) entry.key: entry.value,
    if (next.isNotEmpty) catalog.key: next,
  };
}
```

`lib/core/built_ins/hidden_built_ins_codec.dart`:

```dart
import 'dart:convert';

/// Encodes the hidden built-in ids for `diver_settings.hidden_built_in_ids`
/// (issue #401): a JSON object of catalog key to id list. Keys and ids are
/// sorted and empty catalogs omitted, so equal contents always encode equal
/// (the settings save compares encoded columns). Nothing hidden is null.
String? encodeHiddenBuiltIns(Map<String, Set<String>> hidden) {
  final keys = [
    for (final entry in hidden.entries)
      if (entry.value.isNotEmpty) entry.key,
  ]..sort();
  if (keys.isEmpty) return null;
  return jsonEncode({for (final key in keys) key: hidden[key]!.toList()..sort()});
}

/// Reads what [encodeHiddenBuiltIns] wrote. Never throws: null, empty,
/// malformed or wrongly typed input reads as nothing hidden, and entries that
/// are not a list of strings are skipped. Keys this version does not know are
/// kept, so a save does not drop what a newer version synced in.
Map<String, Set<String>> decodeHiddenBuiltIns(String? raw) {
  if (raw == null || raw.isEmpty) return const {};
  Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } on FormatException {
    return const {};
  }
  if (decoded is! Map) return const {};
  return {
    for (final entry in decoded.entries)
      if (entry.key is String && entry.value is List)
        if (_ids(entry.value as List) case final ids when ids.isNotEmpty)
          entry.key as String: ids,
  };
}

Set<String> _ids(List<dynamic> values) => {
  for (final value in values)
    if (value is String && value.isNotEmpty) value,
};
```

`lib/core/built_ins/visible_built_ins.dart`:

```dart
/// [all] without the built-in entries whose id is in [hidden] (issue #401).
///
/// Custom entries are never dropped, even one sharing a built-in's id. An
/// entry whose id is in [keep] stays even when hidden, so a picker still
/// shows the value a record already uses. Order is preserved, and [all]
/// itself is returned when nothing is dropped.
List<T> visibleBuiltIns<T>(
  List<T> all,
  Set<String> hidden, {
  required bool Function(T) isBuiltIn,
  required String Function(T) idOf,
  Iterable<String?> keep = const [],
}) {
  if (hidden.isEmpty) return all;
  final kept = {for (final id in keep) ?id};
  final visible = [
    for (final entry in all)
      if (!isBuiltIn(entry) ||
          !hidden.contains(idOf(entry)) ||
          kept.contains(idOf(entry)))
        entry,
  ];
  return visible.length == all.length ? all : visible;
}
```

If the analyzer rejects the null-aware element `?id` (Dart below 3.8), use `if (id != null) id` instead.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/core/built_ins/`
Expected: PASS (all tests in three files).

- [ ] **Step 5: Commit**

```bash
dart format lib/core/built_ins test/core/built_ins
git add lib/core/built_ins test/core/built_ins
git commit -m "feat(settings): built-in catalog keys, hidden-set codec and picker filter"
```

---

### Task 2: Schema v261 column

**Files:**
- Modify: `lib/core/database/tables/diver_tables.dart` (after `hiddenTankPresetIds`, around line 258)
- Modify: `lib/core/database/migrations/helpers/diver_migrations.dart` (after `_assertHiddenTankPresetIdsColumn`, around line 125)
- Modify: `lib/core/database/migrations/ladder/rungs_v231_onward.dart` (append after the v260 rung)
- Modify: `lib/core/database/migrations/before_open.dart` (next to the v227 backstop, around line 36)
- Modify: `lib/core/database/database.dart` (`currentSchemaVersion` line 235, `migrationVersions` after `260,`)
- Modify: `test/core/database/migration_v260_tank_shared_computers_test.dart:11-13`
- Test: `test/core/database/migration_v261_hidden_built_ins_test.dart`

**Interfaces:**
- Produces: Drift column `DiverSettings.hiddenBuiltInIds` (`TextColumn`, nullable, SQL `hidden_built_in_ids`), so `DiverSetting.hiddenBuiltInIds` is `String?` and `DiverSettingsCompanion(hiddenBuiltInIds: Value<String?>)`.

- [ ] **Step 1: Write the failing migration test**

`test/core/database/migration_v261_hidden_built_ins_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// Schema v261: diver_settings.hidden_built_in_ids, the built-in catalog
/// entries each diver hid from the pickers (issue #401).
void main() {
  /// A v260 database whose diver_settings lacks the column.
  NativeDatabase setupDb() => NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = 260');
      rawDb.execute(
        'CREATE TABLE diver_settings (id TEXT NOT NULL PRIMARY KEY, '
        'diver_id TEXT NOT NULL)',
      );
      rawDb.execute(
        "INSERT INTO diver_settings (id, diver_id) VALUES ('s1', 'd1')",
      );
    },
  );

  test('v261 is the current schema version and is in the ladder', () {
    // The newest rung owns the exact assertion; relax it to
    // greaterThanOrEqualTo when the next one lands.
    expect(AppDatabase.currentSchemaVersion, 261);
    expect(AppDatabase.migrationVersions, contains(261));
    expect(AppDatabase.migrationStepCount(260), 1);
  });

  test('this rung is additive and did not move the sync floor', () {
    expect(AppDatabase.minimumCompatibleSchemaVersion, 240);
  });

  test(
    'upgrading from v260 adds a null hidden_built_in_ids and keeps the row',
    () async {
      final db = AppDatabase(setupDb());
      addTearDown(db.close);
      final rows = await db
          .customSelect(
            'SELECT diver_id, hidden_built_in_ids FROM diver_settings',
          )
          .get();
      expect(rows.single.read<String>('diver_id'), 'd1');
      expect(rows.single.read<String?>('hidden_built_in_ids'), isNull);
    },
  );
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/core/database/migration_v261_hidden_built_ins_test.dart`
Expected: FAIL, `currentSchemaVersion` is 260 and the column query errors with "no such column".

- [ ] **Step 3: Add the column, rung, backstop and version**

In `diver_tables.dart`, directly after `TextColumn get hiddenTankPresetIds => text().nullable()();`:

```dart

  /// v261: built-in catalog entries the diver hid from the pickers (issue
  /// #401), a JSON object of catalog key to id list. Null or absent = none
  /// hidden.
  TextColumn get hiddenBuiltInIds => text().nullable()();
```

In `diver_migrations.dart`, directly after the closing brace of `_assertHiddenTankPresetIdsColumn`:

```dart

  /// v261: diver_settings.hidden_built_in_ids (issue #401). PRAGMA-guarded
  /// and idempotent so both onUpgrade and the beforeOpen backstop can call it.
  Future<void> _assertHiddenBuiltInIdsColumn() async {
    final cols = await customSelect(
      "PRAGMA table_info('diver_settings')",
    ).get();
    if (cols.isEmpty) return;
    final names = cols.map((c) => c.read<String>('name')).toSet();
    if (!names.contains('hidden_built_in_ids')) {
      await customStatement(
        'ALTER TABLE diver_settings ADD COLUMN hidden_built_in_ids TEXT',
      );
    }
  }
```

In `rungs_v231_onward.dart`, after `if (from < 260) await reportProgress();`:

```dart
    // v261: diver_settings.hidden_built_in_ids (issue #401). Column-only
    // rung, no backfill: null reads back as "nothing hidden".
    if (from < 261) {
      await _assertHiddenBuiltInIdsColumn();
    }
    if (from < 261) await reportProgress();
```

In `before_open.dart`, directly above `// v227 backstop: the hidden built-in tank presets.`:

```dart
    // v261 backstop: the hidden built-in catalog entries.
    await _assertHiddenBuiltInIdsColumn();

```

In `database.dart`: change `static const int currentSchemaVersion = 260;` to `261`, and after the `260,` entry of `migrationVersions` add:

```dart
    // v261: diver_settings.hidden_built_in_ids, the built-in dive types,
    // roles, site types, service types and pre-dive templates each diver hid
    // from the pickers (issue #401). Additive nullable column, no backfill,
    // so the floor stays.
    261,
```

In `test/core/database/migration_v260_tank_shared_computers_test.dart`, relax the exact assertions:

```dart
  test('v260 is at or below the current schema version and in the ladder', () {
    // Relaxed once v261 (diver_settings.hidden_built_in_ids, #401) landed on
    // top; the newest rung owns the exact assertions.
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(260));
    expect(AppDatabase.migrationVersions, contains(260));
    expect(
      AppDatabase.migrationStepCount(259),
      AppDatabase.migrationStepCount(260) + 1,
    );
  });
```

- [ ] **Step 4: Regenerate Drift code and run the database tests**

Run: `dart run build_runner build --delete-conflicting-outputs`
Then: `grep -rn "currentSchemaVersion, 260\b\|migrationStepCount(259), 1" test` (expect no output; fix any hit the same way).
Then: `flutter test test/core/database/`
Expected: PASS, including the new v261 test and the relaxed v260 test.

- [ ] **Step 5: Commit**

```bash
dart format lib/core/database test/core/database
git add lib/core/database test/core/database
git commit -m "feat(settings): diver_settings.hidden_built_in_ids column (schema v261)"
```

---

### Task 3: Settings field, persistence and setter

**Files:**
- Modify: `lib/features/settings/presentation/providers/settings_providers.dart` (field near line 212, constructor near 595, `copyWith` params near 779 and body near 935, setter after `setTankPresetHidden` near 1806)
- Modify: `lib/features/settings/data/repositories/diver_settings_repository.dart` (create near line 156, `_storedColumns` near 411, `_mapRowToAppSettings` near 611)
- Modify fakes: `test/helpers/mock_providers.dart`, `test/features/insights/presentation/pages/records_page_test.dart`, `test/features/settings/presentation/pages/settings_page_shared_data_test.dart`, `test/features/settings/presentation/pages/settings_page_test.dart`, `test/helpers/deferred_settings_notifier.dart` (only if it defines `setTankPresetHidden`; check with grep)
- Test: `test/features/settings/data/repositories/diver_settings_repository_hidden_built_ins_test.dart`
- Test: `test/features/settings/presentation/providers/settings_notifier_real_test.dart` (add to the group that holds `setTankPresetHidden toggles hidden tank presets`)

**Interfaces:**
- Consumes: Task 1 (`BuiltInCatalog`, `withBuiltInHidden`, codec), Task 2 (column).
- Produces:
  - `AppSettings.hiddenBuiltInIds` (`Map<String, Set<String>>`, default `const {}`), `copyWith(hiddenBuiltInIds:)`.
  - `Set<String> AppSettings.hiddenBuiltIns(BuiltInCatalog catalog)`.
  - `Future<void> SettingsNotifier.setBuiltInHidden(BuiltInCatalog catalog, String id, bool hidden)`.

- [ ] **Step 1: Write the failing repository test**

`test/features/settings/data/repositories/diver_settings_repository_hidden_built_ins_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/built_ins/built_in_catalog.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/settings/data/repositories/diver_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

/// diver_settings.hidden_built_in_ids round trip (issue #401).
void main() {
  late DiverSettingsRepository repository;

  Future<void> insertDiver(String id) =>
      DatabaseService.instance.database.customStatement(
        'INSERT INTO divers (id, name, created_at, updated_at) '
        "VALUES ('$id', '$id', 1000, 1000)",
      );

  setUp(() async {
    await setUpTestDatabase();
    await insertDiver('d1');
    await insertDiver('d2');
    repository = DiverSettingsRepository();
  });

  tearDown(tearDownTestDatabase);

  test('a new diver hides nothing', () async {
    await repository.createSettingsForDiver('d1');
    final settings = await repository.getSettingsForDiver('d1');
    expect(settings!.hiddenBuiltInIds, isEmpty);
    expect(settings.hiddenBuiltIns(BuiltInCatalog.diveTypes), isEmpty);
  });

  test('create and update round trip the hidden sets', () async {
    await repository.createSettingsForDiver(
      'd1',
      settings: const AppSettings(
        hiddenBuiltInIds: {
          'diveRoles': {'solo'},
        },
      ),
    );
    var settings = await repository.getSettingsForDiver('d1');
    expect(settings!.hiddenBuiltIns(BuiltInCatalog.diveRoles), {'solo'});

    final updated = settings.copyWith(
      hiddenBuiltInIds: {
        'diveRoles': {'solo'},
        'siteTypes': {'lake', 'quarry'},
        'futureKind': {'x'},
      },
    );
    await repository.updateSettingsForDiver('d1', updated, previous: settings);
    settings = await repository.getSettingsForDiver('d1');
    expect(settings!.hiddenBuiltInIds, {
      'diveRoles': {'solo'},
      'siteTypes': {'lake', 'quarry'},
      'futureKind': {'x'},
    });
  });

  test('hidden sets are per diver', () async {
    await repository.createSettingsForDiver(
      'd1',
      settings: const AppSettings(
        hiddenBuiltInIds: {
          'diveTypes': {'night'},
        },
      ),
    );
    await repository.createSettingsForDiver('d2');
    expect(
      (await repository.getSettingsForDiver('d2'))!.hiddenBuiltInIds,
      isEmpty,
    );
  });

  test('the same contents in another order store the same settings', () {
    expect(
      DiverSettingsRepository.storesSameSettings(
        const AppSettings(
          hiddenBuiltInIds: {
            'siteTypes': {'wall', 'lake'},
            'diveRoles': {'solo'},
          },
        ),
        const AppSettings(
          hiddenBuiltInIds: {
            'diveRoles': {'solo'},
            'siteTypes': {'lake', 'wall'},
          },
        ),
      ),
      isTrue,
    );
  });
}
```

Add to `settings_notifier_real_test.dart`, right after the test `setTankPresetHidden toggles hidden tank presets`:

```dart
    test('setBuiltInHidden toggles one catalog at a time', () async {
      container.read(settingsProvider.notifier);
      await waitForInit();

      final notifier = container.read(settingsProvider.notifier);
      await notifier.setBuiltInHidden(BuiltInCatalog.diveRoles, 'solo', true);
      await notifier.setBuiltInHidden(BuiltInCatalog.siteTypes, 'lake', true);
      var settings = container.read(settingsProvider);
      expect(settings.hiddenBuiltIns(BuiltInCatalog.diveRoles), {'solo'});
      expect(settings.hiddenBuiltIns(BuiltInCatalog.siteTypes), {'lake'});

      await notifier.setBuiltInHidden(BuiltInCatalog.diveRoles, 'solo', false);
      settings = container.read(settingsProvider);
      expect(settings.hiddenBuiltIns(BuiltInCatalog.diveRoles), isEmpty);
      expect(settings.hiddenBuiltInIds, {
        'siteTypes': {'lake'},
      });
    });
```

and add `import 'package:submersion/core/built_ins/built_in_catalog.dart';` to that file's imports.

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/features/settings/data/repositories/diver_settings_repository_hidden_built_ins_test.dart test/features/settings/presentation/providers/settings_notifier_real_test.dart`
Expected: FAIL to compile, `hiddenBuiltInIds`, `hiddenBuiltIns` and `setBuiltInHidden` are undefined.

- [ ] **Step 3: Add the field, accessor, setter and persistence**

`settings_providers.dart`, imports: add `import 'package:submersion/core/built_ins/built_in_catalog.dart';`.

Field, directly after `final Set<String> hiddenTankPresetIds;`:

```dart

  /// Built-in catalog entries hidden from the pickers (issue #401), as
  /// catalog key to ids. Keyed by string rather than [BuiltInCatalog] so a
  /// key a newer version synced in survives a save. Read one catalog through
  /// [hiddenBuiltIns].
  final Map<String, Set<String>> hiddenBuiltInIds;
```

Constructor, after `this.hiddenTankPresetIds = const {},`:

```dart
    this.hiddenBuiltInIds = const {},
```

`copyWith` parameter after `Set<String>? hiddenTankPresetIds,`:

```dart
    Map<String, Set<String>>? hiddenBuiltInIds,
```

`copyWith` body after `hiddenTankPresetIds: hiddenTankPresetIds ?? this.hiddenTankPresetIds,`:

```dart
      hiddenBuiltInIds: hiddenBuiltInIds ?? this.hiddenBuiltInIds,
```

Accessor, inside `class AppSettings` directly after the `copyWith` method:

```dart

  /// The ids hidden from the pickers in [catalog] (issue #401).
  Set<String> hiddenBuiltIns(BuiltInCatalog catalog) =>
      hiddenBuiltInIds[catalog.key] ?? const {};
```

Setter, in `SettingsNotifier` directly after `setTankPresetHidden`:

```dart

  /// Hides or shows a built-in entry of [catalog] in the pickers (issue
  /// #401). The Manage pages still list it, and records that use it keep it.
  Future<void> setBuiltInHidden(
    BuiltInCatalog catalog,
    String id,
    bool hidden,
  ) async {
    final next = withBuiltInHidden(state.hiddenBuiltInIds, catalog, id, hidden);
    if (identical(next, state.hiddenBuiltInIds)) return;
    state = state.copyWith(hiddenBuiltInIds: next);
    await _saveSettings();
  }
```

`diver_settings_repository.dart`, imports: add `import 'package:submersion/core/built_ins/hidden_built_ins_codec.dart';`.

In `createSettingsForDiver`, after the `hiddenTankPresetIds: Value(_encodeDisabledRules(s.hiddenTankPresetIds)),` entry:

```dart
              hiddenBuiltInIds: Value(encodeHiddenBuiltIns(s.hiddenBuiltInIds)),
```

In `_storedColumns`, after its `hiddenTankPresetIds:` entry:

```dart
    hiddenBuiltInIds: Value(encodeHiddenBuiltIns(settings.hiddenBuiltInIds)),
```

In `_mapRowToAppSettings`, after `hiddenTankPresetIds: _decodeDisabledRules(row.hiddenTankPresetIds),`:

```dart
      hiddenBuiltInIds: decodeHiddenBuiltIns(row.hiddenBuiltInIds),
```

Fakes. In each of `test/helpers/mock_providers.dart`, `records_page_test.dart`, `settings_page_shared_data_test.dart`, `settings_page_test.dart` (and any other file `grep -rln "Future<void> setTankPresetHidden" test` lists), directly after the fake's `setTankPresetHidden`:

```dart
  @override
  Future<void> setBuiltInHidden(
    BuiltInCatalog catalog,
    String id,
    bool hidden,
  ) async {
    state = state.copyWith(
      hiddenBuiltInIds: withBuiltInHidden(
        state.hiddenBuiltInIds,
        catalog,
        id,
        hidden,
      ),
    );
  }
```

with `import 'package:submersion/core/built_ins/built_in_catalog.dart';` added to each file.

- [ ] **Step 4: Run tests and analyze**

Run: `flutter analyze lib test` (expect "No issues found"; any `missing_concrete_implementation` names a fake still to update).
Then: `flutter test test/features/settings/data/repositories/ test/features/settings/presentation/providers/settings_notifier_real_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format lib/features/settings test
git add lib/features/settings test
git commit -m "feat(settings): per-diver hidden built-in ids in the settings row"
```

---

### Task 4: hiddenBuiltInIdsProvider

**Files:**
- Create: `lib/features/settings/presentation/providers/hidden_built_ins_provider.dart`
- Test: `test/features/settings/presentation/providers/hidden_built_ins_provider_test.dart`

**Interfaces:**
- Consumes: Task 3 (`AppSettings.hiddenBuiltIns`, `setBuiltInHidden`, `MockSettingsNotifier.setBuiltInHidden`).
- Produces: `final hiddenBuiltInIdsProvider = Provider.family<Set<String>, BuiltInCatalog>(...)`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/built_ins/built_in_catalog.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/providers/hidden_built_ins_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';

void main() {
  ProviderContainer container(MockSettingsNotifier settings) {
    final c = ProviderContainer(
      overrides: [settingsProvider.overrideWith((ref) => settings)],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('yields only its own catalog', () {
    final c = container(
      MockSettingsNotifier(
        const AppSettings(
          hiddenBuiltInIds: {
            'diveRoles': {'solo'},
            'siteTypes': {'lake'},
          },
        ),
      ),
    );
    expect(c.read(hiddenBuiltInIdsProvider(BuiltInCatalog.diveRoles)), {
      'solo',
    });
    expect(
      c.read(hiddenBuiltInIdsProvider(BuiltInCatalog.diveTypes)),
      isEmpty,
    );
  });

  test('another catalog changing does not notify listeners', () async {
    final settings = MockSettingsNotifier();
    final c = container(settings);
    var notified = 0;
    c.listen(
      hiddenBuiltInIdsProvider(BuiltInCatalog.diveRoles),
      (_, _) => notified++,
    );

    await settings.setBuiltInHidden(BuiltInCatalog.siteTypes, 'lake', true);
    expect(notified, 0);

    await settings.setBuiltInHidden(BuiltInCatalog.diveRoles, 'solo', true);
    expect(notified, 1);
    expect(c.read(hiddenBuiltInIdsProvider(BuiltInCatalog.diveRoles)), {
      'solo',
    });
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/settings/presentation/providers/hidden_built_ins_provider_test.dart`
Expected: FAIL, the provider file does not exist.

- [ ] **Step 3: Write the provider**

```dart
import 'package:submersion/core/built_ins/built_in_catalog.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// The active diver's hidden ids for one [BuiltInCatalog] (issue #401).
///
/// Selects a sorted, newline-joined key rather than the set itself, since
/// every settings load decodes a fresh Set: this way a picker rebuilds only
/// when its own catalog's ids change, not on every settings write.
final hiddenBuiltInIdsProvider = Provider.family<Set<String>, BuiltInCatalog>((
  ref,
  catalog,
) {
  final key = ref.watch(
    settingsProvider.select(
      (settings) =>
          (settings.hiddenBuiltIns(catalog).toList()..sort()).join('\n'),
    ),
  );
  return key.isEmpty ? const {} : key.split('\n').toSet();
});
```

- [ ] **Step 4: Run it to verify it passes**

Run: `flutter test test/features/settings/presentation/providers/hidden_built_ins_provider_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format lib/features/settings test/features/settings
git add lib/features/settings/presentation/providers/hidden_built_ins_provider.dart test/features/settings/presentation/providers/hidden_built_ins_provider_test.dart
git commit -m "feat(settings): provider for one catalog's hidden built-in ids"
```

---

### Task 5: Shared "Show" column widgets and strings

**Files:**
- Create: `lib/shared/widgets/built_in_show_column.dart`
- Modify: all 11 `lib/l10n/arb/app_*.arb` (append two keys before the closing brace), then regenerate `lib/l10n/arb/app_localizations*.dart`
- Test: `test/shared/widgets/built_in_show_column_test.dart`

**Interfaces:**
- Consumes: Task 1 (`BuiltInCatalog`).
- Produces:
  - `const double kBuiltInShowColumnWidth = 64;`
  - `Key builtInShowSwitchKey(BuiltInCatalog catalog, String id)` returning `ValueKey('built-in-show-${catalog.key}-$id')`.
  - `BuiltInShowColumnHeader({Key? key, String? title, TextStyle? titleStyle, double trailingInset = 0, double top = 16, double bottom = 8})`
  - `BuiltInShowSwitch({Key? key, required bool shown, required ValueChanged<bool>? onChanged, Key? switchKey, String? tooltip})`
  - l10n getters `builtIns_showColumnLabel`, `builtIns_showInPickers`.

- [ ] **Step 1: Add the strings**

Append to each ARB with a script (keeps UTF-8 intact; the Write tool would decode escape sequences):

```bash
python3.14 - <<'EOF'
import json, pathlib, re
strings = {
    'en': ('Show', 'Show in pickers'),
    'de': ('Anzeigen', 'In der Auswahl anzeigen'),
    'es': ('Mostrar', 'Mostrar en los selectores'),
    'fr': ('Afficher', 'Afficher dans les sélecteurs'),
    'it': ('Mostra', 'Mostra nei selettori'),
    'nl': ('Tonen', 'Tonen in kiezers'),
    'pt': ('Mostrar', 'Mostrar nos seletores'),
    'hu': ('Megjelenítés', 'Megjelenítés a választókban'),
    'he': ('הצג', 'הצג בבוררים'),
    'ar': ('إظهار', 'إظهار في قوائم الاختيار'),
    'zh': ('显示', '在选择列表中显示'),
}
for lang, (label, tip) in strings.items():
    path = pathlib.Path(f'lib/l10n/arb/app_{lang}.arb')
    text = path.read_text(encoding='utf-8').rstrip()
    assert text.endswith('}')
    lines = [
        f'  "builtIns_showColumnLabel": {json.dumps(label, ensure_ascii=False)}',
    ]
    if lang == 'en':
        lines.append('  "@builtIns_showColumnLabel": {"description": "Column header above the switches that hide built-in entries from the pickers on the Manage pages"}')
    lines.append(f'  "builtIns_showInPickers": {json.dumps(tip, ensure_ascii=False)}')
    if lang == 'en':
        lines.append('  "@builtIns_showInPickers": {"description": "Tooltip on a built-in entry\'s show/hide switch on a Manage page"}')
    body = text[:-1].rstrip()
    path.write_text(body + ',\n' + ',\n'.join(lines) + '\n}\n', encoding='utf-8')
EOF
flutter gen-l10n
git diff --stat lib/l10n
```

Expected: 11 ARB files and 12 generated `app_localizations*.dart` files changed; `git diff --numstat lib/l10n/arb/*.arb` shows only additions (plus one changed line per file for the added comma).

- [ ] **Step 2: Write the failing widget test**

`test/shared/widgets/built_in_show_column_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/built_ins/built_in_catalog.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/built_in_show_column.dart';

void main() {
  Widget page({
    Locale locale = const Locale('en'),
    double trailingInset = 0,
    List<Widget> trailingAfterSwitch = const [],
    ValueChanged<bool>? onChanged,
  }) => MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: ListView(
        children: [
          BuiltInShowColumnHeader(
            title: 'Built-in',
            trailingInset: trailingInset,
          ),
          ListTile(
            title: const Text('Buddy'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                BuiltInShowSwitch(
                  shown: true,
                  switchKey: builtInShowSwitchKey(
                    BuiltInCatalog.diveRoles,
                    'buddy',
                  ),
                  onChanged: onChanged ?? (_) {},
                ),
                ...trailingAfterSwitch,
              ],
            ),
          ),
        ],
      ),
    ),
  );

  double centerX(WidgetTester tester, Finder finder) =>
      tester.getCenter(finder).dx;

  testWidgets('the Show label sits centred over the switch', (tester) async {
    await tester.pumpWidget(page());
    final label = find.text('Show');
    expect(label, findsOneWidget);
    expect(
      centerX(tester, label),
      moreOrLessEquals(centerX(tester, find.byType(Switch)), epsilon: 0.5),
    );
  });

  testWidgets('a trailing inset keeps the label over a non-final switch', (
    tester,
  ) async {
    await tester.pumpWidget(
      page(
        trailingInset: 48,
        trailingAfterSwitch: [
          PopupMenuButton<int>(itemBuilder: (_) => const []),
        ],
      ),
    );
    expect(
      centerX(tester, find.text('Show')),
      moreOrLessEquals(centerX(tester, find.byType(Switch)), epsilon: 0.5),
    );
  });

  testWidgets('a long translation still lines up and fits the column', (
    tester,
  ) async {
    await tester.pumpWidget(page(locale: const Locale('hu')));
    final label = find.text('Megjelenítés');
    expect(
      centerX(tester, label),
      moreOrLessEquals(centerX(tester, find.byType(Switch)), epsilon: 0.5),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('the switch reports changes and carries its key', (
    tester,
  ) async {
    bool? reported;
    await tester.pumpWidget(page(onChanged: (v) => reported = v));
    await tester.tap(
      find.byKey(builtInShowSwitchKey(BuiltInCatalog.diveRoles, 'buddy')),
    );
    expect(reported, isFalse);
  });

  testWidgets('the switch has the generic tooltip', (tester) async {
    await tester.pumpWidget(page());
    expect(find.byTooltip('Show in pickers'), findsOneWidget);
  });
}
```

- [ ] **Step 3: Run it to verify it fails**

Run: `flutter test test/shared/widgets/built_in_show_column_test.dart`
Expected: FAIL, `built_in_show_column.dart` does not exist.

- [ ] **Step 4: Write the widgets**

`lib/shared/widgets/built_in_show_column.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/built_ins/built_in_catalog.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Width of the "Show" column on the Manage pages (issue #401). The header
/// label and each row's switch are centred in a box this wide, so the two
/// line up whatever size the switch or the translated label has.
const double kBuiltInShowColumnWidth = 64;

/// ListTile's default end padding, which the row switches sit inside. No app
/// theme overrides ListTile padding.
const double _tileEndPadding = 24;

/// The key of the show switch on [catalog]'s Manage page row for [id].
Key builtInShowSwitchKey(BuiltInCatalog catalog, String id) =>
    ValueKey('built-in-show-${catalog.key}-$id');

/// A Manage page section header with a "Show" label over the switch column
/// of the rows below it. [trailingInset] is the width of anything that sits
/// after the switch in those rows, such as a 48-wide menu button.
class BuiltInShowColumnHeader extends StatelessWidget {
  const BuiltInShowColumnHeader({
    super.key,
    this.title,
    this.titleStyle,
    this.trailingInset = 0,
    this.top = 16,
    this.bottom = 8,
  });

  final String? title;
  final TextStyle? titleStyle;
  final double trailingInset;
  final double top;
  final double bottom;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(
        16,
        top,
        _tileEndPadding + trailingInset,
        bottom,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: title == null
                ? const SizedBox.shrink()
                : Text(title!, style: titleStyle),
          ),
          SizedBox(
            width: kBuiltInShowColumnWidth,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                context.l10n.builtIns_showColumnLabel,
                maxLines: 1,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The switch in a built-in row's "Show" column. Off hides the entry from the
/// pickers. Place it last in the row's trailing widgets, or give the header a
/// matching [BuiltInShowColumnHeader.trailingInset].
class BuiltInShowSwitch extends StatelessWidget {
  const BuiltInShowSwitch({
    super.key,
    required this.shown,
    required this.onChanged,
    this.switchKey,
    this.tooltip,
  });

  final bool shown;
  final ValueChanged<bool>? onChanged;
  final Key? switchKey;

  /// Defaults to the generic "Show in pickers".
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: kBuiltInShowColumnWidth,
      child: Center(
        child: Tooltip(
          message: tooltip ?? context.l10n.builtIns_showInPickers,
          child: Switch(key: switchKey, value: shown, onChanged: onChanged),
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Run the test and the trailing-width guard**

Run: `flutter test test/shared/widgets/built_in_show_column_test.dart test/architecture/list_tile_trailing_width_test.dart test/l10n/`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
dart format lib/shared test/shared
git add lib/shared/widgets/built_in_show_column.dart test/shared/widgets/built_in_show_column_test.dart lib/l10n
git commit -m "feat(settings): labeled Show column widgets for built-in entries"
```

---

### Task 6: Tank Presets page gets the column label

**Files:**
- Modify: `lib/features/tank_presets/presentation/pages/tank_presets_page.dart` (built-in section header near line 98, switch near line 228)
- Test: `test/features/tank_presets/presentation/pages/tank_presets_page_test.dart` (add one test using the file's existing harness)

**Interfaces:**
- Consumes: Task 5 (`BuiltInShowColumnHeader`, `BuiltInShowSwitch`).

- [ ] **Step 1: Write the failing test**

Add to `tank_presets_page_test.dart` inside `group('TankPresetsPage', ...)`, reusing the first test's setup verbatim (built-in presets, `MockSettingsNotifier`, router, `ProviderScope`) and then:

```dart
    testWidgets('labels the show switch column', (tester) async {
      final builtInPresets = TankPresets.all
          .map((p) => TankPresetEntity.fromBuiltIn(p))
          .toList();
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (context, state) => const TankPresetsPage()),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
            currentDiverIdProvider.overrideWith(
              (ref) => MockCurrentDiverIdNotifier(),
            ),
            tankPresetListNotifierProvider.overrideWith(
              (ref) => _MockTankPresetListNotifier(builtInPresets),
            ),
          ].cast(),
          child: MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final label = find.text('Show');
      expect(label, findsOneWidget);
      final firstSwitch = find.byKey(const ValueKey('tank-preset-visible-al100'));
      expect(
        tester.getCenter(label).dx,
        moreOrLessEquals(tester.getCenter(firstSwitch).dx, epsilon: 0.5),
      );
    });
```

The first built-in preset in `TankPresets.all` is `al100` (it is first on the page in the before screenshot). If the key differs, take the first name from `TankPresets.all.first.name`.

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/tank_presets/presentation/pages/tank_presets_page_test.dart`
Expected: the new test FAILS (no "Show" text); the others pass.

- [ ] **Step 3: Implement**

Add `import 'package:submersion/shared/widgets/built_in_show_column.dart';`.

Replace the built-in section header call:

```dart
              _buildSectionHeader(
                context,
                context.l10n.tankPresets_builtInPresets,
              ),
```

with:

```dart
              BuiltInShowColumnHeader(
                title: context.l10n.tankPresets_builtInPresets,
                titleStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
```

Replace the `Visibility` child (the `Tooltip` wrapping the `Switch`):

```dart
              child: BuiltInShowSwitch(
                switchKey: ValueKey('tank-preset-visible-${preset.name}'),
                tooltip: context.l10n.tankPresets_showInPickers,
                shown: !isHidden,
                onChanged: (visible) => ref
                    .read(settingsProvider.notifier)
                    .setTankPresetHidden(preset.name, !visible),
              ),
```

- [ ] **Step 4: Run the page tests**

Run: `flutter test test/features/tank_presets/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format lib/features/tank_presets test/features/tank_presets
git add lib/features/tank_presets test/features/tank_presets
git commit -m "feat(tank-presets): label the show switch column"
```

---

### Task 7: Dive types (Manage page and picker)

**Files:**
- Modify: `lib/features/dive_types/presentation/pages/dive_types_page.dart` (built-in header near line 55, `_buildDiveTypeTile`)
- Modify: `lib/features/dive_log/presentation/widgets/dive_type_multi_select_field.dart` (`build`, `_openPicker` call)
- Test: `test/features/dive_types/presentation/pages/dive_types_page_hide_test.dart`
- Test: `test/features/dive_log/presentation/widgets/dive_type_multi_select_field_test.dart` (add settings override to `harness`, add tests)

**Interfaces:**
- Consumes: Tasks 1, 3, 4, 5.

- [ ] **Step 1: Write the failing tests**

`test/features/dive_types/presentation/pages/dive_types_page_hide_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/built_ins/built_in_catalog.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_types/presentation/pages/dive_types_page.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/built_in_show_column.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// Settings > Dive Types hide switches (issue #401).
void main() {
  late MockCurrentDiverIdNotifier diverIdNotifier;
  late MockSettingsNotifier settings;

  setUp(() async {
    await setUpTestDatabase();
    await DatabaseService.instance.database.customStatement(
      'INSERT INTO divers (id, name, created_at, updated_at) '
      "VALUES ('diver-1', 'Test Diver', 1000, 1000)",
    );
    await DatabaseService.instance.database.customStatement(
      'INSERT INTO dive_types (id, diver_id, name, is_built_in, sort_order, '
      "created_at, updated_at) VALUES ('mine', 'diver-1', 'Mine', 0, 99, "
      '1000, 1000)',
    );
    diverIdNotifier = MockCurrentDiverIdNotifier();
    await diverIdNotifier.setCurrentDiver('diver-1');
    settings = MockSettingsNotifier();
  });

  tearDown(tearDownTestDatabase);

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentDiverIdProvider.overrideWith((ref) => diverIdNotifier),
          validatedCurrentDiverIdProvider.overrideWith(
            (ref) async => 'diver-1',
          ),
          settingsProvider.overrideWith((ref) => settings),
        ].cast(),
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: DiveTypesPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  final nightKey = builtInShowSwitchKey(BuiltInCatalog.diveTypes, 'night');

  testWidgets('built-in rows have a labeled switch, custom rows none', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('Show'), findsOneWidget);
    await tester.scrollUntilVisible(find.byKey(nightKey), 200);
    expect(find.byKey(nightKey), findsOneWidget);
    expect(
      find.byKey(builtInShowSwitchKey(BuiltInCatalog.diveTypes, 'mine')),
      findsNothing,
    );
  });

  testWidgets('switching a type off hides it and dims its row', (
    tester,
  ) async {
    await pump(tester);
    await tester.scrollUntilVisible(find.byKey(nightKey), 200);
    await tester.tap(find.byKey(nightKey));
    await tester.pumpAndSettle();

    expect(settings.state.hiddenBuiltIns(BuiltInCatalog.diveTypes), {'night'});
    final title = tester.widget<ListTile>(
      find.ancestor(of: find.byKey(nightKey), matching: find.byType(ListTile)),
    );
    final context = tester.element(find.byKey(nightKey));
    expect(title.textColor, Theme.of(context).disabledColor);
    expect(tester.widget<Switch>(find.byKey(nightKey)).value, isFalse);
  });
}
```

Before writing the custom-type insert, confirm the `dive_types` column names with `grep -n "get " lib/core/database/tables/tag_tables.dart` inside `class DiveTypes`; add any NOT NULL column without a default to the insert.

In `dive_type_multi_select_field_test.dart`: add a `MockSettingsNotifier? settings` parameter to `harness`, add `settingsProvider.overrideWith((ref) => settings ?? MockSettingsNotifier())` to its overrides, mark the three test types built-in (`isBuiltIn: true` in the `type` helper), and add imports for `package:submersion/features/settings/presentation/providers/settings_providers.dart` (for `settingsProvider` and `AppSettings`) and `../../../../helpers/mock_providers.dart`. Then add:

```dart
  testWidgets('the checklist leaves out hidden types', (tester) async {
    await tester.pumpWidget(
      harness(
        selected: ['shore'],
        onChanged: (_) {},
        settings: MockSettingsNotifier(
          const AppSettings(
            hiddenBuiltInIds: {
              'diveTypes': {'night'},
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(InputDecorator));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(CheckboxListTile, 'Wreck'), findsOneWidget);
    expect(find.widgetWithText(CheckboxListTile, 'Night'), findsNothing);
  });

  testWidgets('a hidden type the dive already has stays in the checklist', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(
        selected: ['night'],
        onChanged: (_) {},
        settings: MockSettingsNotifier(
          const AppSettings(
            hiddenBuiltInIds: {
              'diveTypes': {'night'},
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(InputDecorator));
    await tester.pumpAndSettle();
    final night = find.widgetWithText(CheckboxListTile, 'Night');
    expect(night, findsOneWidget);
    expect(tester.widget<CheckboxListTile>(night).value, isTrue);
  });
```

The built-in names render through `localizedName`; if `Night` and `Wreck` translate differently in `en`, use the strings the existing tests in this file already expect.

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/features/dive_types/presentation/pages/dive_types_page_hide_test.dart test/features/dive_log/presentation/widgets/dive_type_multi_select_field_test.dart`
Expected: the new tests FAIL (no switches; hidden type still listed).

- [ ] **Step 3: Implement the page**

`dive_types_page.dart`: add imports for `built_in_catalog.dart`, `hidden_built_ins_provider.dart`, `settings_providers.dart` and `shared/widgets/built_in_show_column.dart`.

In `build`, after `final diveTypesAsync = ...`:

```dart
    final hidden = ref.watch(hiddenBuiltInIdsProvider(BuiltInCatalog.diveTypes));
```

Replace the built-in `_buildSectionHeader(context, context.l10n.diveTypes_builtInHeader)` with:

```dart
              BuiltInShowColumnHeader(
                title: context.l10n.diveTypes_builtInHeader,
                titleStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
```

and pass `isHidden: hidden.contains(type.id)` to the built-in `_buildDiveTypeTile` calls. Add the parameter `bool isHidden = false` to `_buildDiveTypeTile`, then in the `ListTile`:

```dart
      // A hidden built-in stays listed so it can be shown again (issue #401).
      // Only its text and icon dim; the switch stays usable.
      textColor: isHidden ? Theme.of(context).disabledColor : null,
      leading: Icon(
        canDelete ? Icons.label_outline : Icons.label,
        color: isHidden
            ? Theme.of(context).disabledColor
            : canDelete
            ? Theme.of(context).colorScheme.secondary
            : Theme.of(context).colorScheme.primary,
      ),
```

and in the trailing `Row` children, after the badge block:

```dart
          if (!canDelete)
            BuiltInShowSwitch(
              switchKey: builtInShowSwitchKey(
                BuiltInCatalog.diveTypes,
                diveType.id,
              ),
              shown: !isHidden,
              onChanged: (shown) => ref
                  .read(settingsProvider.notifier)
                  .setBuiltInHidden(
                    BuiltInCatalog.diveTypes,
                    diveType.id,
                    !shown,
                  ),
            ),
```

- [ ] **Step 4: Implement the picker**

`dive_type_multi_select_field.dart`: add imports for `built_in_catalog.dart`, `visible_built_ins.dart` and `hidden_built_ins_provider.dart`. In `build`, after `final typesAsync = ref.watch(diveTypesProvider);`:

```dart
    final hidden = ref.watch(hiddenBuiltInIdsProvider(BuiltInCatalog.diveTypes));
```

Change the `onTap` to:

```dart
      // Hidden built-ins leave the checklist (issue #401), except the ones
      // this dive already has. The list is fixed while the sheet is open, so
      // unticking a hidden type there does not make it vanish.
      onTap: () => _openPicker(
        context,
        visibleBuiltIns(
          types,
          hidden,
          isBuiltIn: (t) => t.isBuiltIn,
          idOf: (t) => t.id,
          keep: selectedTypeIds,
        ),
        label,
      ),
```

- [ ] **Step 5: Run the tests**

Run: `flutter test test/features/dive_types/ test/features/dive_log/presentation/widgets/dive_type_multi_select_field_test.dart`
Expected: PASS. If an existing dive types page test now fails with "SharedPreferences must be initialized", add `settingsProvider.overrideWith((ref) => MockSettingsNotifier())` to its `ProviderScope` overrides.

- [ ] **Step 6: Commit**

```bash
dart format lib/features/dive_types lib/features/dive_log test/features/dive_types test/features/dive_log
git add lib/features/dive_types lib/features/dive_log/presentation/widgets/dive_type_multi_select_field.dart test/features/dive_types test/features/dive_log/presentation/widgets/dive_type_multi_select_field_test.dart
git commit -m "feat(dive-types): hide built-in dive types from the pickers"
```

---

### Task 8: Dive roles (Manage page, selector sheet, buddy picker, bulk edit, legacy review)

**Files:**
- Modify: `lib/features/dive_roles/presentation/pages/dive_roles_page.dart`
- Modify: `lib/features/dive_roles/presentation/widgets/dive_role_selector_sheet.dart` (`showDiveRoleSelector`)
- Modify: `lib/features/buddies/presentation/widgets/buddy_picker.dart` (lines 49, 186-245, 296-306, 737-743)
- Modify: `lib/features/dive_log/presentation/pages/dive_edit_page.dart` (`_showBulkDiverRolePicker` near 1553, `_showBulkBuddyRolePicker` near 1596)
- Modify: `lib/features/buddies/presentation/widgets/legacy_buddy_review_row.dart`, `legacy_buddy_review_sheet.dart` (near line 98 and 135)
- Test: `test/features/dive_roles/presentation/pages/dive_roles_page_hide_test.dart`
- Test: `test/features/dive_roles/presentation/widgets/dive_role_selector_sheet_test.dart` (add tests)
- Test: `test/features/buddies/presentation/widgets/legacy_buddy_review_row_hide_test.dart`

**Interfaces:**
- Consumes: Tasks 1, 3, 4, 5.
- Produces: `showDiveRoleSelector(..., Set<String> hiddenRoleIds = const {})`; `LegacyBuddyReviewRow(..., Set<String> hiddenRoleIds = const {})`.

- [ ] **Step 1: Write the failing tests**

In `dive_role_selector_sheet_test.dart`, add a `Set<String> hiddenRoleIds = const {}` parameter to `_harness` and pass `hiddenRoleIds: hiddenRoleIds` to `showDiveRoleSelector`. Add:

```dart
  testWidgets('leaves out hidden built-in roles', (tester) async {
    await tester.pumpWidget(
      _harness(onResult: (_) {}, hiddenRoleIds: {DiveRole.rearGuardId}),
    );
    await _open(tester);
    expect(find.text('Rear Guard'), findsNothing);
    expect(find.text('Instructor'), findsOneWidget);
    expect(find.text('Hekkensluiter'), findsOneWidget);
  });

  testWidgets('keeps a hidden role that is currently selected', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        onResult: (_) {},
        hiddenRoleIds: {DiveRole.buddyId, DiveRole.rearGuardId},
        selectedRoleId: DiveRole.buddyId,
      ),
    );
    await _open(tester);
    expect(find.text('Buddy'), findsOneWidget);
    expect(find.text('Rear Guard'), findsNothing);
  });
```

`test/features/dive_roles/presentation/pages/dive_roles_page_hide_test.dart`: same structure as the Task 7 page test, with these differences: import `dive_roles_page.dart` and pump `DiveRolesPage()`; insert the custom role with
`INSERT INTO dive_roles (id, diver_id, name, is_built_in, sort_order, created_at, updated_at) VALUES ('uuid-1', 'diver-1', 'Hekkensluiter', 0, 99, 1000, 1000)` (confirm the columns in `class DiveRoles` of `lib/core/database/tables/buddy_tables.dart`); the switch key is `builtInShowSwitchKey(BuiltInCatalog.diveRoles, 'solo')`; the custom one `builtInShowSwitchKey(BuiltInCatalog.diveRoles, 'uuid-1')` must find nothing; after tapping `solo`, expect `settings.state.hiddenBuiltIns(BuiltInCatalog.diveRoles)` to equal `{'solo'}`, the tile `textColor` to be `disabledColor`, and the switch value to be false.

`test/features/buddies/presentation/widgets/legacy_buddy_review_row_hide_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/buddies/domain/entities/legacy_buddy_conversion.dart';
import 'package:submersion/features/buddies/presentation/widgets/legacy_buddy_review_row.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The legacy buddy review row's role dropdown narrows to visible roles
/// (issue #401) but keeps the row's own role.
void main() {
  final now = DateTime(2026);
  DiveRole builtIn(String id, String name) => DiveRole(
    id: id,
    name: name,
    isBuiltIn: true,
    createdAt: now,
    updatedAt: now,
  );
  final roles = [
    builtIn(DiveRole.buddyId, 'Buddy'),
    builtIn(DiveRole.instructorId, 'Instructor'),
    builtIn(DiveRole.soloId, 'Solo'),
  ];

  Future<void> pump(WidgetTester tester, String roleId) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: LegacyBuddyReviewRow(
            link: PlannedLink(
              target: const NewBuddyTarget('Ann'),
              roleId: roleId,
            ),
            roles: roles,
            hiddenRoleIds: {DiveRole.soloId, DiveRole.instructorId},
            onRoleChanged: (_) {},
            onUseSuggestion: () {},
            onEditName: () {},
            onChooseExisting: () {},
            onRemove: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('legacy-row-role-new:ann')));
    await tester.pumpAndSettle();
  }

  testWidgets('hidden roles leave the dropdown', (tester) async {
    await pump(tester, DiveRole.buddyId);
    expect(find.text('Solo'), findsNothing);
    expect(find.text('Instructor'), findsNothing);
  });

  testWidgets("the row's own hidden role stays, by its real name", (
    tester,
  ) async {
    await pump(tester, DiveRole.instructorId);
    expect(find.text('Instructor'), findsWidgets);
    expect(find.text('Solo'), findsNothing);
  });
}
```

Before running, confirm `DiveRole.soloId` / `instructorId` constant names (`grep -n "static const" lib/features/dive_roles/domain/entities/dive_role.dart`), the `PlannedLink` optional fields, and the identity string for `NewBuddyTarget('Ann')` (`legacyNameKey('Ann')`); adjust the key literal to match.

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/features/dive_roles/ test/features/buddies/presentation/widgets/legacy_buddy_review_row_hide_test.dart`
Expected: FAIL to compile (`hiddenRoleIds` undefined).

- [ ] **Step 3: Implement the selector and the row**

`dive_role_selector_sheet.dart`: import `visible_built_ins.dart`. Add the parameter and filter before ordering:

```dart
  /// Built-in roles the diver hid from the pickers (issue #401). The
  /// selected role stays even when hidden.
  Set<String> hiddenRoleIds = const {},
}) {
  final shownRoles = visibleBuiltIns(
    roles,
    hiddenRoleIds,
    isBuiltIn: (r) => r.isBuiltIn,
    idOf: (r) => r.id,
    keep: [selectedRoleId],
  );
  final orderedRoles = [
    ...shownRoles.where((r) => credentialRoleIds.contains(r.id)),
    ...shownRoles.where((r) => !credentialRoleIds.contains(r.id)),
  ];
```

(the doc comment goes on the parameter line inside the parameter list, after `onCreateCustomRole`).

`legacy_buddy_review_row.dart`: import `visible_built_ins.dart`; add field and constructor parameter `this.hiddenRoleIds = const {}` with `/// Built-in roles hidden from the pickers (issue #401); the row's own role stays.` and `final Set<String> hiddenRoleIds;`. Change `options`:

```dart
    final shown = visibleBuiltIns(
      roles,
      hiddenRoleIds,
      isBuiltIn: (r) => r.isBuiltIn,
      idOf: (r) => r.id,
      keep: [link.roleId],
    );
    final options = [
      ...shown,
      if (!shown.any((r) => r.id == link.roleId))
        DiveRole.synthetic(link.roleId),
    ];
```

`legacy_buddy_review_sheet.dart`: import `built_in_catalog.dart` and `hidden_built_ins_provider.dart`; after `final roles = ...` add `final hiddenRoleIds = ref.watch(hiddenBuiltInIdsProvider(BuiltInCatalog.diveRoles));` and pass `hiddenRoleIds: hiddenRoleIds,` to `LegacyBuddyReviewRow`.

- [ ] **Step 4: Wire the callers**

`buddy_picker.dart`: import `built_in_catalog.dart` and `hidden_built_ins_provider.dart`.
- In `BuddyPicker.build` after line 49: `final hiddenRoleIds = ref.watch(hiddenBuiltInIdsProvider(BuiltInCatalog.diveRoles));`, and pass `hiddenRoleIds: hiddenRoleIds,` where `_BuddyChip(...)` is built (next to `roles: roles,`).
- `_BuddyChip`: add `final Set<String> hiddenRoleIds;` with constructor parameter `this.hiddenRoleIds = const {}`, and pass `hiddenRoleIds: hiddenRoleIds,` in `_showRoleSelector`.
- `_MeChip` (line 300) and `_showRoleSelectorForBuddy` (line 738): add `hiddenRoleIds: ref.read(hiddenBuiltInIdsProvider(BuiltInCatalog.diveRoles)),` to the `showDiveRoleSelector` call.

`dive_edit_page.dart`: in `_showBulkDiverRolePicker` and `_showBulkBuddyRolePicker`, add to `showDiveRoleSelector(...)`:

```dart
      hiddenRoleIds: ref.read(
        hiddenBuiltInIdsProvider(BuiltInCatalog.diveRoles),
      ),
```

with the two imports added if missing.

- [ ] **Step 5: Implement the Manage page**

`dive_roles_page.dart`: same pattern as Task 7 Step 3, with `BuiltInCatalog.diveRoles`, the header `context.l10n.diveRoles_builtInHeader`, the `_buildDiveRoleTile(... canEdit: false)` calls passing `isHidden: hidden.contains(role.id)`, the leading icon `Icons.groups` dimmed when hidden, and `trailing:` for built-ins becoming:

```dart
          : BuiltInShowSwitch(
              switchKey: builtInShowSwitchKey(BuiltInCatalog.diveRoles, role.id),
              shown: !isHidden,
              onChanged: (shown) => ref
                  .read(settingsProvider.notifier)
                  .setBuiltInHidden(BuiltInCatalog.diveRoles, role.id, !shown),
            ),
```

- [ ] **Step 6: Run the tests**

Run: `flutter test test/features/dive_roles/ test/features/buddies/ test/features/dive_log/presentation/pages/`
Expected: PASS. Any harness failing with "SharedPreferences must be initialized" gets `settingsProvider.overrideWith((ref) => MockSettingsNotifier())`.

- [ ] **Step 7: Commit**

```bash
dart format lib/features/dive_roles lib/features/buddies lib/features/dive_log test/features/dive_roles test/features/buddies test/features/dive_log
git add lib/features/dive_roles lib/features/buddies lib/features/dive_log/presentation/pages/dive_edit_page.dart test/features/dive_roles test/features/buddies test/features/dive_log
git commit -m "feat(dive-roles): hide built-in dive roles from the pickers"
```

---

### Task 9: Site types (Manage page and site edit chips)

**Files:**
- Modify: `lib/features/site_types/presentation/pages/site_types_page.dart`
- Modify: `lib/features/dive_sites/presentation/widgets/edit_sections/type_tags_section.dart`
- Modify: `lib/features/dive_sites/presentation/pages/site_edit_page.dart` (near line 1023)
- Test: `test/features/site_types/presentation/pages/site_types_page_hide_test.dart`
- Test: `test/features/dive_sites/presentation/widgets/edit_sections/type_tags_section_test.dart` (add tests)

**Interfaces:**
- Consumes: Tasks 1, 3, 4, 5.
- Produces: `TypeTagsSection(..., Set<String> hiddenTypeIds = const {}, Set<String> keepTypeIds = const {})`.

- [ ] **Step 1: Write the failing tests**

Add to `type_tags_section_test.dart` (the `types` list has built-ins `wreck`, `lake` and custom `mine`):

```dart
  testWidgets('hidden built-in types leave the chips', (tester) async {
    await tester.pumpWidget(
      harness(
        TypeTagsSection(
          allTypes: types,
          selectedTypeIds: const {},
          onTypesChanged: (_) {},
          selectedTags: const [],
          onTagsChanged: (_) {},
          hiddenTypeIds: const {'lake'},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilterChip, 'Lake'), findsNothing);
    expect(find.widgetWithText(FilterChip, 'Mine'), findsOneWidget);
  });

  testWidgets('a hidden type the site had stays after it is unticked', (
    tester,
  ) async {
    var selected = <String>{'lake'};
    await tester.pumpWidget(
      harness(
        StatefulBuilder(
          builder: (context, setState) => TypeTagsSection(
            allTypes: types,
            selectedTypeIds: selected,
            onTypesChanged: (ids) => setState(() => selected = ids),
            selectedTags: const [],
            onTagsChanged: (_) {},
            hiddenTypeIds: const {'lake'},
            keepTypeIds: const {'lake'},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, 'Lake'));
    await tester.pumpAndSettle();
    expect(selected, isEmpty);
    expect(find.widgetWithText(FilterChip, 'Lake'), findsOneWidget);
  });
```

Use the chip labels the file's existing `shows every type` test expects for `lake` (built-ins render translated).

`test/features/site_types/presentation/pages/site_types_page_hide_test.dart`: the Task 7 page test structure with `SiteTypesPage()`, a custom row inserted via `INSERT INTO site_types (id, diver_id, name, is_built_in, sort_order, created_at, updated_at) VALUES ('mine', 'diver-1', 'Mine', 0, 99, 1000, 1000)` (confirm the columns in `class SiteTypes` of `site_tables.dart`), key `builtInShowSwitchKey(BuiltInCatalog.siteTypes, 'lake')`, custom key for `'mine'` finding nothing, and after the tap `settings.state.hiddenBuiltIns(BuiltInCatalog.siteTypes)` equal to `{'lake'}` with the tile dimmed.

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/features/site_types/ test/features/dive_sites/presentation/widgets/edit_sections/type_tags_section_test.dart`
Expected: FAIL to compile (`hiddenTypeIds` undefined).

- [ ] **Step 3: Implement the chips**

`type_tags_section.dart`: import `visible_built_ins.dart`; add:

```dart
    this.hiddenTypeIds = const {},
    this.keepTypeIds = const {},
```

```dart
  /// Built-in types the diver hid from the pickers (issue #401).
  final Set<String> hiddenTypeIds;

  /// Types to offer even when hidden: the ones the site had when the editor
  /// opened, so unticking one does not make its chip vanish.
  final Set<String> keepTypeIds;
```

In `build`, before `return FormSection(`:

```dart
    final shownTypes = visibleBuiltIns(
      allTypes,
      hiddenTypeIds,
      isBuiltIn: (t) => t.isBuiltIn,
      idOf: (t) => t.id,
      keep: {...keepTypeIds, ...selectedTypeIds},
    );
```

and change `for (final type in allTypes)` to `for (final type in shownTypes)`.

`site_edit_page.dart` (`TypeTagsSection(` call): add

```dart
              hiddenTypeIds: ref.watch(
                hiddenBuiltInIdsProvider(BuiltInCatalog.siteTypes),
              ),
              keepTypeIds: _originalTypeIds,
```

with imports for `built_in_catalog.dart` and `hidden_built_ins_provider.dart`.

- [ ] **Step 4: Implement the Manage page**

`site_types_page.dart`: imports as in Task 7. In `build`, add `final hidden = ref.watch(hiddenBuiltInIdsProvider(BuiltInCatalog.siteTypes));`. Replace `_header(context, l10n.siteTypes_builtIn),` with:

```dart
              BuiltInShowColumnHeader(
                title: l10n.siteTypes_builtIn,
                titleStyle: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
```

Pass `isHidden: hidden.contains(type.id)` to `_tile` (new named parameter `bool isHidden = false`). In `_tile`: add `textColor: isHidden ? Theme.of(context).disabledColor : null,`, dim the leading icon color when hidden, and change `trailing: type.isBuiltIn ? null : Row(...)` to:

```dart
      trailing: type.isBuiltIn
          ? BuiltInShowSwitch(
              switchKey: builtInShowSwitchKey(BuiltInCatalog.siteTypes, type.id),
              shown: !isHidden,
              onChanged: (shown) => ref
                  .read(settingsProvider.notifier)
                  .setBuiltInHidden(BuiltInCatalog.siteTypes, type.id, !shown),
            )
          : Row(
```

- [ ] **Step 5: Run the tests**

Run: `flutter test test/features/site_types/ test/features/dive_sites/`
Expected: PASS (add the settings override to any harness failing on SharedPreferences).

- [ ] **Step 6: Commit**

```bash
dart format lib/features/site_types lib/features/dive_sites test/features/site_types test/features/dive_sites
git add lib/features/site_types lib/features/dive_sites test/features/site_types test/features/dive_sites
git commit -m "feat(site-types): hide built-in site types from the pickers"
```

---

### Task 10: Service types (Manage page, pickers, auto-attach)

**Files:**
- Modify: `lib/features/equipment/presentation/pages/service_kind_list_page.dart` (built-in tiles near line 118)
- Modify: `lib/features/equipment/presentation/widgets/service_schedule_dialogs.dart` (`showServiceKindPicker`)
- Modify: `lib/features/equipment/presentation/widgets/service_record_dialog.dart` (`offered`, near line 193)
- Modify: `lib/features/equipment/data/repositories/service_schedule_repository.dart` (`autoAttachForEquipment`)
- Test: `test/features/equipment/data/service_schedule_repository_test.dart` (add tests)
- Test: `test/features/equipment/presentation/widgets/service_kind_picker_test.dart` (add test)
- Test: `test/features/equipment/presentation/widgets/service_record_dialog_hidden_kinds_test.dart`
- Test: `test/features/equipment/presentation/pages/service_kind_list_page_hide_test.dart`

**Interfaces:**
- Consumes: Tasks 1, 3, 4, 5.

- [ ] **Step 1: Write the failing auto-attach tests**

Add to `service_schedule_repository_test.dart` (imports: `built_in_catalog.dart` is not needed; add `diver_settings_repository.dart`, `settings_providers.dart`):

```dart
  Future<void> diverHiding(String diverId, Set<String> kinds) async {
    await db.customStatement(
      'INSERT INTO divers (id, name, created_at, updated_at) '
      "VALUES ('$diverId', '$diverId', 1000, 1000)",
    );
    await DiverSettingsRepository().createSettingsForDiver(
      diverId,
      settings: AppSettings(hiddenBuiltInIds: {'serviceKinds': kinds}),
    );
  }

  test('auto-attach skips kinds the owning diver hid (issue #401)', () async {
    await diverHiding('d1', {'vip'});
    final tank = await equipmentRepo.createEquipment(
      const EquipmentItem(
        id: '',
        name: 'AL80',
        type: EquipmentType.tank,
        diverId: 'd1',
      ),
    );
    final kindIds = (await repo.getSchedulesForEquipment(
      tank.id,
    )).map((s) => s.serviceKindId).toSet();
    expect(kindIds, contains('hydro'));
    expect(kindIds, isNot(contains('vip')));
  });

  test("another diver's hidden kinds do not apply", () async {
    await diverHiding('d1', {'vip'});
    await diverHiding('d2', const {});
    final tank = await equipmentRepo.createEquipment(
      const EquipmentItem(
        id: '',
        name: 'AL80',
        type: EquipmentType.tank,
        diverId: 'd2',
      ),
    );
    final kindIds = (await repo.getSchedulesForEquipment(
      tank.id,
    )).map((s) => s.serviceKindId).toSet();
    expect(kindIds, containsAll(['hydro', 'vip']));
  });
```

If `EquipmentItem` has no `diverId` constructor parameter, check its fields (`grep -n "diverId" lib/features/equipment/domain/entities/equipment_item.dart`) and set ownership the way `createEquipment` reads it.

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/features/equipment/data/service_schedule_repository_test.dart`
Expected: the first new test FAILS (`vip` attached).

- [ ] **Step 3: Implement auto-attach**

`service_schedule_repository.dart`: import `built_in_catalog.dart` and `hidden_built_ins_codec.dart`. In `autoAttachForEquipment`, after `final existingKindIds = ...`:

```dart
    final hidden = await _hiddenServiceKinds(diverId);
```

and in the loop, after the auto-attach/applies check:

```dart
      // Hidden by the owning diver (issue #401): an unwanted clock would
      // only nag with due reminders.
      if (kind.isBuiltIn && hidden.contains(kind.id)) continue;
```

Add next to `getDueSoonWindowDays`:

```dart
  /// The built-in service kinds [diverId] hid from the pickers (issue #401).
  /// Read straight from diver_settings, as [getDueSoonWindowDays] does, so
  /// equipment creation does not depend on the settings notifier.
  Future<Set<String>> _hiddenServiceKinds(String? diverId) async {
    if (diverId == null) return const {};
    final row =
        await (_db.select(_db.diverSettings)
              ..where((t) => t.diverId.equals(diverId))
              ..limit(1))
            .getSingleOrNull();
    return decodeHiddenBuiltIns(
          row?.hiddenBuiltInIds,
        )[BuiltInCatalog.serviceKinds.key] ??
        const {};
  }
```

Run: `flutter test test/features/equipment/data/service_schedule_repository_test.dart` (expect PASS).

- [ ] **Step 4: Write the failing picker and dialog tests**

Add to `service_kind_picker_test.dart`: give `pumpPicker` an optional `MockSettingsNotifier? settings` and add `settingsProvider.overrideWith((ref) => settings ?? MockSettingsNotifier())` to its overrides (imports: `settings_providers.dart`, `../../../../helpers/mock_providers.dart`). Then:

```dart
  testWidgets('hidden built-in kinds are not offered (issue #401)', (
    tester,
  ) async {
    await pumpPicker(
      tester,
      _FakeScheduleRepo(),
      settings: MockSettingsNotifier(
        const AppSettings(
          hiddenBuiltInIds: {
            'serviceKinds': {'general-service'},
          },
        ),
      ),
    );
    expect(find.text('General service'), findsNothing);
    expect(find.text('Regulator service'), findsOneWidget);
  });
```

`service_record_dialog_hidden_kinds_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/service_record_dialog.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// The service record type dropdown leaves out hidden built-in kinds
/// (issue #401) but keeps the one the record uses.
void main() {
  final t0 = DateTime(2026, 1, 1);
  ServiceKind builtIn(String id, String name) => ServiceKind(
    id: id,
    name: name,
    isBuiltIn: true,
    createdAt: t0,
    updatedAt: t0,
  );
  final kinds = [
    builtIn('hydro', 'Hydrostatic test'),
    builtIn('vip', 'Visual inspection (VIP)'),
  ];

  Future<void> pumpDialog(WidgetTester tester, {String? serviceKindId}) async {
    await tester.binding.setSurfaceSize(const Size(800, 4000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final overrides = await getBaseOverrides(
      settingsNotifier: MockSettingsNotifier(
        const AppSettings(
          hiddenBuiltInIds: {
            'serviceKinds': {'vip'},
          },
        ),
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          serviceKindsProvider.overrideWith((ref) async => kinds),
          serviceSchedulesForEquipmentProvider(
            'e1',
          ).overrideWith((ref) async => const []),
        ].cast(),
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ServiceRecordDialog(
              equipmentId: 'e1',
              serviceKindId: serviceKindId,
              onSave: (record) async {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('service-record-service-type')));
    await tester.pumpAndSettle();
  }

  testWidgets('a hidden kind is not offered', (tester) async {
    await pumpDialog(tester);
    expect(find.text('Hydrostatic test'), findsWidgets);
    expect(find.text('Visual inspection (VIP)'), findsNothing);
  });

  testWidgets('a hidden kind stays when the record already uses it', (
    tester,
  ) async {
    await pumpDialog(tester, serviceKindId: 'vip');
    expect(find.text('Visual inspection (VIP)'), findsWidgets);
  });
}
```

Run: `flutter test test/features/equipment/presentation/widgets/`
Expected: the new picker test and the first dialog test FAIL (hidden kinds still offered).

- [ ] **Step 5: Implement the pickers**

`service_schedule_dialogs.dart`: import `built_in_catalog.dart` and `hidden_built_ins_provider.dart`. In `showServiceKindPicker`:

```dart
  final hidden = ref.read(hiddenBuiltInIdsProvider(BuiltInCatalog.serviceKinds));
  final candidates = kinds
      .where(
        (k) =>
            k.appliesTo(equipmentType) &&
            !attached.contains(k.id) &&
            !(k.isBuiltIn && hidden.contains(k.id)),
      )
      .toList();
```

`service_record_dialog.dart`: import `built_in_catalog.dart`, `visible_built_ins.dart`, `hidden_built_ins_provider.dart`. Before `List<ServiceKind> offered(...)`:

```dart
    final hiddenKinds = ref.watch(
      hiddenBuiltInIdsProvider(BuiltInCatalog.serviceKinds),
    );
```

and change `offered` to:

```dart
    // Hidden built-in kinds leave the dropdown (issue #401), except the one
    // this record uses; any kind this item's own clocks use is re-added below.
    List<ServiceKind> offered(List<ServiceKind> scoped) {
      final shown = visibleBuiltIns(
        scoped,
        hiddenKinds,
        isBuiltIn: (k) => k.isBuiltIn,
        idOf: (k) => k.id,
        keep: [_serviceKindId],
      );
      return [
        ...shown,
        for (final s in schedules)
          if (allKinds[s.serviceKindId] case final k?)
            if (!shown.any((e) => e.id == k.id)) k,
      ];
    }
```

- [ ] **Step 6: Implement the Manage page**

`service_kind_list_page.dart`: imports as in Task 7. In `build`, `final hidden = ref.watch(hiddenBuiltInIdsProvider(BuiltInCatalog.serviceKinds));`. Replace `_SectionHeader(title: l10n.equipment_serviceKinds_builtIn),` with:

```dart
                  BuiltInShowColumnHeader(
                    title: l10n.equipment_serviceKinds_builtIn,
                    titleStyle: Theme.of(context).textTheme.titleSmall
                        ?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                    bottom: 4,
                  ),
```

In the built-in `ListTile`, add:

```dart
                      textColor: hidden.contains(kind.id)
                          ? Theme.of(context).disabledColor
                          : null,
                      // Yields to selection mode like the custom rows' trash.
                      trailing: _isSelectionMode
                          ? null
                          : BuiltInShowSwitch(
                              switchKey: builtInShowSwitchKey(
                                BuiltInCatalog.serviceKinds,
                                kind.id,
                              ),
                              shown: !hidden.contains(kind.id),
                              onChanged: (shown) => ref
                                  .read(settingsProvider.notifier)
                                  .setBuiltInHidden(
                                    BuiltInCatalog.serviceKinds,
                                    kind.id,
                                    !shown,
                                  ),
                            ),
```

`service_kind_list_page_hide_test.dart`: pump `ServiceKindListPage` the way `service_kind_list_page_test.dart` does (`serviceKindsProvider.overrideWith((ref) async => kinds)` with two built-ins `hydro`, `vip` and one custom), plus `settingsProvider.overrideWith((ref) => settings)`. Assert: "Show" once; `builtInShowSwitchKey(BuiltInCatalog.serviceKinds, 'vip')` found; the custom kind's key not found; tapping `vip` makes `settings.state.hiddenBuiltIns(BuiltInCatalog.serviceKinds)` equal `{'vip'}`; tapping `find.byKey(const ValueKey('enter_selection'))` then pumping removes every `Switch`.

- [ ] **Step 7: Run the tests**

Run: `flutter test test/features/equipment/`
Expected: PASS (settings override added to any harness failing on SharedPreferences).

- [ ] **Step 8: Commit**

```bash
dart format lib/features/equipment test/features/equipment
git add lib/features/equipment test/features/equipment
git commit -m "feat(equipment): hide built-in service types from pickers and auto-attach"
```

---

### Task 11: Pre-dive checklist templates (Manage page and start sheet)

**Files:**
- Modify: `lib/features/pre_dive/presentation/pages/pre_dive_templates_page.dart`
- Modify: `lib/features/pre_dive/presentation/widgets/start_session_sheet.dart` (near line 149)
- Test: `test/features/pre_dive/presentation/pages/pre_dive_templates_page_hide_test.dart`
- Test: `test/features/pre_dive/presentation/widgets/start_session_sheet_test.dart` (add test)

**Interfaces:**
- Consumes: Tasks 1, 3, 4, 5.

- [ ] **Step 1: Write the failing tests**

In `start_session_sheet_test.dart`, give `pumpSheet` an optional `MockSettingsNotifier? settings`, add `settingsProvider.overrideWith((ref) => settings ?? MockSettingsNotifier())` to its overrides, and make the `template` helper take `{bool builtIn = false}` passed to `isBuiltIn`. Mark `plain` (`BWRAF`) built-in. Add:

```dart
  testWidgets('hidden built-in templates are not offered (issue #401)', (
    tester,
  ) async {
    await pumpSheet(
      tester,
      settings: MockSettingsNotifier(
        const AppSettings(
          hiddenBuiltInIds: {
            'preDiveTemplates': {'plain'},
          },
        ),
      ),
    );
    await tester.tap(find.byType(DropdownButtonFormField<PreDiveChecklistTemplate>));
    await tester.pumpAndSettle();
    expect(find.text('BWRAF'), findsNothing);
    expect(find.text('Gear Packing'), findsWidgets);
  });
```

`pre_dive_templates_page_hide_test.dart`: pump `PreDiveTemplatesPage` the way `pre_dive_templates_page_test.dart`'s `pumpPage` does (`testApp` with `preDiveTemplatesProvider.overrideWith(...)`), with one built-in template `builtin-predive-bwraf` and one custom `custom-1`, plus `settingsProvider.overrideWith((ref) => settings)`. Assert: "Show" once and centred over the built-in row's switch within 0.5 px; `builtInShowSwitchKey(BuiltInCatalog.preDiveTemplates, 'builtin-predive-bwraf')` found; the custom key not found; tapping it makes `settings.state.hiddenBuiltIns(BuiltInCatalog.preDiveTemplates)` equal `{'builtin-predive-bwraf'}`.

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/features/pre_dive/`
Expected: the new tests FAIL.

- [ ] **Step 3: Implement the sheet**

`start_session_sheet.dart`: imports for `built_in_catalog.dart`, `visible_built_ins.dart`, `hidden_built_ins_provider.dart`. Replace `final templates = templatesAsync.value ?? const [];` with:

```dart
    // Hidden built-ins are not offered (issue #401), except the one already
    // chosen: the dropdown asserts its value is among its items.
    final templates = visibleBuiltIns(
      templatesAsync.value ?? const <PreDiveChecklistTemplate>[],
      ref.watch(hiddenBuiltInIdsProvider(BuiltInCatalog.preDiveTemplates)),
      isBuiltIn: (t) => t.isBuiltIn,
      idOf: (t) => t.id,
      keep: [_template?.id],
    );
```

- [ ] **Step 4: Implement the Manage page**

`pre_dive_templates_page.dart`: imports as in Task 7. Replace the `ListView.separated(...)` branch with a column that puts the header above the list:

```dart
          : Column(
              children: [
                // Built-in and custom templates share one list, so the
                // header carries only the "Show" label (issue #401). Each
                // row's menu button sits after the switch.
                const BuiltInShowColumnHeader(trailingInset: 48, top: 8),
                Expanded(
                  child: ListView.separated(
                    padding: kFabListPadding,
                    itemCount: templates.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) =>
                        _TemplateTile(template: templates[index]),
                  ),
                ),
              ],
            ),
```

In `_TemplateTile.build`: `final isHidden = template.isBuiltIn && ref.watch(hiddenBuiltInIdsProvider(BuiltInCatalog.preDiveTemplates)).contains(template.id);`, add `textColor: isHidden ? Theme.of(context).disabledColor : null,`, dim the leading icon when hidden, and change `trailing: PopupMenuButton<String>(...)` to:

```dart
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (template.isBuiltIn)
            BuiltInShowSwitch(
              switchKey: builtInShowSwitchKey(
                BuiltInCatalog.preDiveTemplates,
                template.id,
              ),
              shown: !isHidden,
              onChanged: (shown) => ref
                  .read(settingsProvider.notifier)
                  .setBuiltInHidden(
                    BuiltInCatalog.preDiveTemplates,
                    template.id,
                    !shown,
                  ),
            ),
          PopupMenuButton<String>(
            // ...the existing onSelected and itemBuilder, unchanged...
          ),
        ],
      ),
```

Move the existing `onSelected` and `itemBuilder` bodies into the new `PopupMenuButton` unchanged.

- [ ] **Step 5: Run the tests**

Run: `flutter test test/features/pre_dive/ test/architecture/list_tile_trailing_width_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
dart format lib/features/pre_dive test/features/pre_dive
git add lib/features/pre_dive test/features/pre_dive
git commit -m "feat(pre-dive): hide built-in checklist templates from the start sheet"
```

---

### Task 12: Whole-branch verification

**Files:** none new; fixes only.

- [ ] **Step 1: Format and analyze**

Run: `dart format .` then `flutter analyze` (do not pipe it through grep; read the exit status).
Expected: "No issues found!".

- [ ] **Step 2: Architecture guards**

Run: `flutter test test/architecture/`
Expected: PASS.

- [ ] **Step 3: Consumer sweep for the new settings dependency**

Run: `flutter test test/features/dive_log test/features/buddies test/features/dive_sites test/features/equipment test/features/pre_dive test/features/trips test/features/settings test/features/dive_types test/features/dive_roles test/features/site_types test/features/tank_presets test/core test/shared`
Expected: PASS. Each "SharedPreferences must be initialized" failure gets `settingsProvider.overrideWith((ref) => MockSettingsNotifier())` in that harness; commit those as `test: give harnesses a settings override for the hidden built-ins`.

- [ ] **Step 4: Em dash scan**

Run: `git diff origin/main | python3.14 -c "import sys; t=sys.stdin.read(); bad=[l for l in t.splitlines() if l.startswith('+') and chr(0x2014) in l]; print(*bad, sep=chr(10)); sys.exit(1 if bad else 0)"` (expect exit 0 and no output).

- [ ] **Step 5: After screenshots**

Render the six Manage pages again with the throwaway golden harness (`test/zz_screens/`, untracked), with one entry hidden per page, light and dark, desktop and phone widths, plus a picker with a hidden entry. Delete `test/zz_screens/` afterwards.
