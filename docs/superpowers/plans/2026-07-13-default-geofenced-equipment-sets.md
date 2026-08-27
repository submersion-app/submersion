# Default & Geofenced Equipment Sets Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a diver mark one equipment set as default and attach geofences to sets, so the app auto-selects the right kit by dive location (form, computer downloads, file imports), suggesting rather than overwriting when gear is already present.

**Architecture:** One pure selection function (`EquipmentSetSelector.bestSetFor`) evaluated wherever a dive is created or its location changes: a geofence match (nearest center) beats the global default, which beats nothing. A new synced child table (`EquipmentSetGeofences`) and one boolean column (`EquipmentSets.isDefault`) back it. A `DiveEquipmentDefaulter` applies the selection on-empty at the non-interactive persistence seams; the dive edit form applies it in-memory and shows a dismissible suggestion banner.

**Tech Stack:** Flutter, Drift (SQLite ORM + codegen), Riverpod, HLC-based sync, Flutter gen-l10n.

## Global Constraints

- **Spec:** `docs/superpowers/specs/2026-07-13-default-geofenced-equipment-sets-design.md`.
- **Schema migration:** bump `currentSchemaVersion` (currently `108`) to the next free version — **use `109` on this branch**; if PR #584 (buddy-cert, reserves v109/v110) lands first, rebase and bump to the next free number. Append the new version to the `migrationVersions` list. Add an idempotent `onUpgrade` block AND a `beforeOpen` backstop (parallel-branch collision self-heal).
- **Drift codegen after any schema change:** `dart run build_runner build --delete-conflicting-outputs`.
- **Formatting:** all Dart must pass `dart format .` with no changes (pre-push enforces `dart format --set-exit-if-changed`, `flutter analyze`, `flutter test`).
- **Localization:** every new user-facing string is added to `lib/l10n/arb/app_en.arb` AND all 10 non-English arb files (`app_ar/de/es/fr/he/hu/it/nl/pt/zh.arb`), then regenerated with `flutter gen-l10n`.
- **Units:** geofence radius is stored as **meters**; the UI displays/accepts it in the diver's active distance unit.
- **Scope:** everything is per-diver. Default mutual-exclusion is scoped to `diverId`. Geofences inherit their set's diver scope via `setId`.
- **Sync:** `EquipmentSetGeofences` is a first-class synced entity (own `id` + `hlc`); writes call `markRecordPending`, removes call `logDeletion`, and mutations call `SyncEventBus.notifyLocalChange()`.
- **Style:** no emojis; immutability (never mutate entities in place); small focused files.

---

## File Structure

**Created:**
- `lib/features/equipment/domain/entities/equipment_set_geofence.dart` — geofence value object.
- `lib/features/equipment/domain/services/equipment_set_selector.dart` — pure selection function.
- `lib/features/equipment/data/services/dive_equipment_defaulter.dart` — on-empty applier for non-interactive seams.
- `lib/features/equipment/presentation/widgets/geofence_editor_sheet.dart` — add/edit one geofence (site or pin anchor + radius).
- `lib/features/dive_log/presentation/widgets/geofence_suggestion_banner.dart` — dismissible suggestion in the dive form.
- Test files mirroring each of the above under `test/`.

**Modified:**
- `lib/core/database/database.dart` — `isDefault` column, `EquipmentSetGeofences` table, registration, migration, backstop.
- `lib/features/equipment/domain/entities/equipment_set.dart` — add `isDefault`, `geofences`.
- `lib/features/equipment/data/repositories/equipment_set_repository_impl.dart` — `setAsDefault`, geofence CRUD, hydrate geofences.
- `lib/features/equipment/presentation/providers/equipment_set_providers.dart` — default + geofence + selection providers, notifier methods.
- `lib/core/services/sync/sync_data_serializer.dart` — register `equipmentSetGeofences` across all sync sites.
- `lib/features/equipment/presentation/pages/equipment_set_edit_page.dart` — default switch + geofences section.
- `lib/features/equipment/presentation/widgets/equipment_set_list_content.dart` — default badge + geofence indicator.
- `lib/features/equipment/presentation/pages/equipment_set_detail_page.dart` — "Set as default" menu action + badges.
- `lib/features/dive_log/presentation/pages/dive_edit_page.dart` — auto-apply on empty + suggestion banner.
- `lib/features/dive_log/data/repositories/dive_computer_repository_impl.dart` — defaulter call after download insert.
- `lib/features/dive_import/data/services/uddf_entity_importer.dart`, `lib/features/dive_import/presentation/providers/dive_import_providers.dart`, `lib/features/import_wizard/data/adapters/healthkit_adapter.dart` — defaulter call after import create.
- `lib/l10n/arb/app_*.arb` — new strings.

---

## Task 1: Schema — `isDefault` column, `EquipmentSetGeofences` table, migration

**Files:**
- Modify: `lib/core/database/database.dart` (table `EquipmentSets` ~785; `@DriftDatabase` list ~2081-2162; `currentSchemaVersion` 2171; `migrationVersions` ~2173; `onUpgrade` end ~5362; `beforeOpen` ~5364-5511)
- Test: `test/core/database/equipment_set_geofence_schema_test.dart`

**Interfaces:**
- Produces: Drift table `EquipmentSetGeofences` → generated row class `EquipmentSetGeofence` (with `.toJson()`, `.fromJson()`, `.toCompanion(false)`) and `EquipmentSetGeofencesCompanion`; new `EquipmentSets.isDefault` (bool, generated on row class `EquipmentSet`). Consumed by Tasks 2, 4, 6, 7.

- [ ] **Step 1: Add the `isDefault` column to `EquipmentSets`**

In `database.dart`, add to the `EquipmentSets` class (after `updatedAt`, before `hlc`, ~line 791):

```dart
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Whether this set is the diver's default (auto-applied to new dives with
  /// no equipment). Mutual exclusion is enforced per-diver at the repository
  /// layer, mirroring DiverRepository.setDefaultDiver.
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();

  /// Hybrid Logical Clock for cross-device conflict resolution
  /// (nullable: rows written before HLC rollout fall back to updatedAt).
  TextColumn get hlc => text().nullable()();
```

- [ ] **Step 2: Add the `EquipmentSetGeofences` table**

Immediately after the `EquipmentSetItems` class (~line 810), add:

```dart
/// Geofences attached to an equipment set. A geofence matches a dive when its
/// center is within [radiusMeters] of any of the dive's known points (linked
/// site GPS, or the computer's entry/exit fixes). First-class synced entity:
/// own id + hlc.
class EquipmentSetGeofences extends Table {
  TextColumn get id => text()();
  TextColumn get setId =>
      text().references(EquipmentSets, #id, onDelete: KeyAction.cascade)();

  /// Display label; seeded from the anchor site's name or diver-entered.
  TextColumn get label => text().nullable()();
  RealColumn get latitude => real()();
  RealColumn get longitude => real()();
  RealColumn get radiusMeters => real()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution.
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
```

- [ ] **Step 3: Register the table in `@DriftDatabase`**

In the `tables:` list (~line 2096), add `EquipmentSetGeofences` right after `EquipmentSetItems`:

```dart
    EquipmentSets,
    EquipmentSetItems,
    EquipmentSetGeofences,
```

- [ ] **Step 4: Bump schema version and record the migration version**

Change line 2171:

```dart
  static const int currentSchemaVersion = 109;
```

Append `109` as the final element of the `migrationVersions` list constant (~line 2173).

- [ ] **Step 5: Add the idempotent schema-assert helper**

Add a private method on `AppDatabase` next to the other `_assert*Schema` helpers (e.g. near `_assertConnectedAccountsSchema`):

```dart
  /// v109: equipment_sets.is_default column + equipment_set_geofences table.
  /// Idempotent (createTable is IF NOT EXISTS; the ALTER is PRAGMA-guarded) so
  /// it is safe to call from both onUpgrade and the beforeOpen backstop.
  Future<void> _assertEquipmentSetDefaultAndGeofenceSchema() async {
    await createMigrator().createTable(equipmentSetGeofences);
    final cols = await customSelect(
      "PRAGMA table_info('equipment_sets')",
    ).get();
    final hasIsDefault = cols.any(
      (c) => c.read<String>('name') == 'is_default',
    );
    if (cols.isNotEmpty && !hasIsDefault) {
      await customStatement(
        'ALTER TABLE equipment_sets ADD COLUMN is_default '
        'INTEGER NOT NULL DEFAULT 0 CHECK (is_default IN (0, 1))',
      );
    }
  }
```

- [ ] **Step 6: Call the helper from `onUpgrade`**

At the end of the `onUpgrade` callback (after the `if (from < 108) await reportProgress();` line ~5362), add:

```dart
        if (from < 109) {
          await _assertEquipmentSetDefaultAndGeofenceSchema();
        }
        if (from < 109) await reportProgress();
```

- [ ] **Step 7: Add the `beforeOpen` backstop**

In the `beforeOpen` callback, after the v108 backstop line (`await _assertMediaSubscriptionsHlc();`, ~line 5380), add:

```dart
        // v109 backstop: re-assert equipment_sets.is_default + the
        // equipment_set_geofences table (parallel-branch collision self-heal).
        await _assertEquipmentSetDefaultAndGeofenceSchema();
```

- [ ] **Step 8: Regenerate Drift code**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: `database.g.dart` regenerates with `EquipmentSetGeofence`, `EquipmentSetGeofencesCompanion`, and `EquipmentSet.isDefault`. No errors.

- [ ] **Step 9: Write the schema test**

Create `test/core/database/equipment_set_geofence_schema_test.dart`:

```dart
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = createTestDatabase();
  });

  tearDown(() async {
    await db.close();
  });

  test('equipment_sets.is_default defaults to false', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.equipmentSets)
        .insert(
          EquipmentSetsCompanion.insert(
            id: 's1',
            name: 'Cold Water',
            createdAt: now,
            updatedAt: now,
          ),
        );
    final row = await (db.select(
      db.equipmentSets,
    )..where((t) => t.id.equals('s1'))).getSingle();
    expect(row.isDefault, isFalse);
  });

  test('equipment_set_geofences round-trips and cascades on set delete', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.into(db.equipmentSets).insert(
          EquipmentSetsCompanion.insert(
            id: 's1',
            name: 'Cold Water',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db.into(db.equipmentSetGeofences).insert(
          EquipmentSetGeofencesCompanion.insert(
            id: 'g1',
            setId: 's1',
            latitude: 36.62,
            longitude: -121.9,
            radiusMeters: 24000,
            createdAt: now,
            updatedAt: now,
          ),
        );

    final geofences = await db.select(db.equipmentSetGeofences).get();
    expect(geofences, hasLength(1));
    expect(geofences.first.setId, 's1');

    await (db.delete(db.equipmentSets)..where((t) => t.id.equals('s1'))).go();
    final afterDelete = await db.select(db.equipmentSetGeofences).get();
    expect(afterDelete, isEmpty, reason: 'geofences cascade-delete with the set');
  });
}
```

- [ ] **Step 10: Run the test**

Run: `flutter test test/core/database/equipment_set_geofence_schema_test.dart`
Expected: PASS (both tests).

- [ ] **Step 11: Commit**

```bash
git add lib/core/database/database.dart lib/core/database/database.g.dart test/core/database/equipment_set_geofence_schema_test.dart
git commit -m "feat(equipment): schema for default set flag + geofence table (#583)"
```

---

## Task 2: Domain entities — `EquipmentSetGeofence` + extend `EquipmentSet`

**Files:**
- Create: `lib/features/equipment/domain/entities/equipment_set_geofence.dart`
- Modify: `lib/features/equipment/domain/entities/equipment_set.dart`
- Test: `test/features/equipment/domain/entities/equipment_set_geofence_test.dart`

**Interfaces:**
- Produces: `EquipmentSetGeofence` (domain) with `GeoPoint get center`; `EquipmentSet.isDefault` (bool), `EquipmentSet.geofences` (`List<EquipmentSetGeofence>`). Consumed by Tasks 3, 4, 5, 7, 10, 11.
- Consumes: `GeoPoint` from `lib/features/dive_sites/domain/entities/dive_site.dart` (positional `GeoPoint(lat, lng)`).

- [ ] **Step 1: Write the failing entity test**

Create `test/features/equipment/domain/entities/equipment_set_geofence_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set_geofence.dart';

void main() {
  EquipmentSetGeofence make() => EquipmentSetGeofence(
        id: 'g1',
        setId: 's1',
        label: 'Monterey',
        latitude: 36.62,
        longitude: -121.9,
        radiusMeters: 24000,
        createdAt: DateTime(2026, 7, 1),
        updatedAt: DateTime(2026, 7, 1),
      );

  test('center exposes a GeoPoint from lat/lng', () {
    expect(make().center, const GeoPoint(36.62, -121.9));
  });

  test('copyWith overrides only provided fields and is equatable', () {
    final a = make();
    final b = a.copyWith(radiusMeters: 30000);
    expect(b.radiusMeters, 30000);
    expect(b.copyWith(radiusMeters: 24000), a);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/equipment/domain/entities/equipment_set_geofence_test.dart`
Expected: FAIL — `equipment_set_geofence.dart` does not exist.

- [ ] **Step 3: Create the entity**

Create `lib/features/equipment/domain/entities/equipment_set_geofence.dart`:

```dart
import 'package:equatable/equatable.dart';

import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

/// A circular geofence attached to an equipment set. Matches a dive when its
/// [center] is within [radiusMeters] of one of the dive's known points.
class EquipmentSetGeofence extends Equatable {
  final String id;
  final String setId;
  final String? label;
  final double latitude;
  final double longitude;
  final double radiusMeters;
  final DateTime createdAt;
  final DateTime updatedAt;

  const EquipmentSetGeofence({
    required this.id,
    required this.setId,
    this.label,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    required this.createdAt,
    required this.updatedAt,
  });

  GeoPoint get center => GeoPoint(latitude, longitude);

  EquipmentSetGeofence copyWith({
    String? id,
    String? setId,
    String? label,
    double? latitude,
    double? longitude,
    double? radiusMeters,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return EquipmentSetGeofence(
      id: id ?? this.id,
      setId: setId ?? this.setId,
      label: label ?? this.label,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      radiusMeters: radiusMeters ?? this.radiusMeters,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        setId,
        label,
        latitude,
        longitude,
        radiusMeters,
        createdAt,
        updatedAt,
      ];
}
```

- [ ] **Step 4: Extend `EquipmentSet`**

In `lib/features/equipment/domain/entities/equipment_set.dart`, add the import, two fields (with defaults), constructor params, `copyWith`, and `props`. The full updated file:

```dart
import 'package:equatable/equatable.dart';

import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set_geofence.dart';

/// A named collection of equipment items
class EquipmentSet extends Equatable {
  final String id;
  final String? diverId;
  final String name;
  final String description;
  final List<String> equipmentIds;
  final List<EquipmentItem>? items; // Populated when fetched with items
  final bool isDefault;
  final List<EquipmentSetGeofence> geofences; // Populated when fetched
  final DateTime createdAt;
  final DateTime updatedAt;

  const EquipmentSet({
    required this.id,
    this.diverId,
    required this.name,
    this.description = '',
    this.equipmentIds = const [],
    this.items,
    this.isDefault = false,
    this.geofences = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  /// Number of items in this set
  int get itemCount => equipmentIds.length;

  /// Check if set contains a specific equipment item
  bool containsEquipment(String equipmentId) {
    return equipmentIds.contains(equipmentId);
  }

  EquipmentSet copyWith({
    String? id,
    String? diverId,
    String? name,
    String? description,
    List<String>? equipmentIds,
    List<EquipmentItem>? items,
    bool? isDefault,
    List<EquipmentSetGeofence>? geofences,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return EquipmentSet(
      id: id ?? this.id,
      diverId: diverId ?? this.diverId,
      name: name ?? this.name,
      description: description ?? this.description,
      equipmentIds: equipmentIds ?? this.equipmentIds,
      items: items ?? this.items,
      isDefault: isDefault ?? this.isDefault,
      geofences: geofences ?? this.geofences,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        diverId,
        name,
        description,
        equipmentIds,
        isDefault,
        geofences,
        createdAt,
        updatedAt,
      ];
}
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `flutter test test/features/equipment/domain/entities/equipment_set_geofence_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/features/equipment/domain/entities/equipment_set_geofence.dart lib/features/equipment/domain/entities/equipment_set.dart test/features/equipment/domain/entities/equipment_set_geofence_test.dart
git commit -m "feat(equipment): domain entity for geofence + default flag (#583)"
```

---

## Task 3: `EquipmentSetSelector` — pure multi-point selection

**Files:**
- Create: `lib/features/equipment/domain/services/equipment_set_selector.dart`
- Test: `test/features/equipment/domain/services/equipment_set_selector_test.dart`

**Interfaces:**
- Produces: `EquipmentSetSelector.bestSetFor({required List<GeoPoint> divePoints, required List<EquipmentSet> sets, required List<EquipmentSetGeofence> geofences}) → EquipmentSet?`. Consumed by Tasks 5, 7, 10.
- Consumes: `distanceMeters(GeoPoint, GeoPoint)` from `lib/core/utils/geo_math.dart`; `GeoPoint`; `EquipmentSet`; `EquipmentSetGeofence`.

- [ ] **Step 1: Write the failing test**

Create `test/features/equipment/domain/services/equipment_set_selector_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set_geofence.dart';
import 'package:submersion/features/equipment/domain/services/equipment_set_selector.dart';

EquipmentSet set(String id, {bool isDefault = false}) => EquipmentSet(
      id: id,
      name: id,
      isDefault: isDefault,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

EquipmentSetGeofence fence(
  String id,
  String setId,
  double lat,
  double lng,
  double radius,
) =>
    EquipmentSetGeofence(
      id: id,
      setId: setId,
      latitude: lat,
      longitude: lng,
      radiusMeters: radius,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

void main() {
  const monterey = GeoPoint(36.62, -121.90); // ~ dive point
  final cold = set('cold');
  final warm = set('warm');
  final def = set('def', isDefault: true);

  test('returns null when nothing matches and no default', () {
    expect(
      EquipmentSetSelector.bestSetFor(
        divePoints: const [monterey],
        sets: [cold, warm],
        geofences: const [],
      ),
      isNull,
    );
  });

  test('falls back to the global default when no geofence matches', () {
    final result = EquipmentSetSelector.bestSetFor(
      divePoints: const [monterey],
      sets: [cold, def],
      geofences: [fence('g', 'cold', 0, 0, 1000)], // far away
    );
    expect(result, def);
  });

  test('geofence match beats the global default', () {
    final result = EquipmentSetSelector.bestSetFor(
      divePoints: const [monterey],
      sets: [cold, def],
      geofences: [fence('g', 'cold', 36.62, -121.90, 25000)],
    );
    expect(result, cold);
  });

  test('matches when ANY dive point is inside the fence', () {
    const elsewhere = GeoPoint(0, 0);
    final result = EquipmentSetSelector.bestSetFor(
      divePoints: const [elsewhere, monterey], // exit fix lands in fence
      sets: [cold, def],
      geofences: [fence('g', 'cold', 36.62, -121.90, 25000)],
    );
    expect(result, cold);
  });

  test('overlapping fences resolve to nearest center', () {
    // cold centered exactly on the dive point (0 m); warm 10 km off but still
    // containing the point with a large radius. Nearest center wins.
    final result = EquipmentSetSelector.bestSetFor(
      divePoints: const [monterey],
      sets: [cold, warm],
      geofences: [
        fence('gw', 'warm', 36.70, -121.90, 40000),
        fence('gc', 'cold', 36.62, -121.90, 40000),
      ],
    );
    expect(result, cold);
  });

  test('empty divePoints skips geofences and uses default', () {
    final result = EquipmentSetSelector.bestSetFor(
      divePoints: const [],
      sets: [cold, def],
      geofences: [fence('g', 'cold', 36.62, -121.90, 25000)],
    );
    expect(result, def);
  });

  test('matchingGeofenceSet returns null when only the default would apply', () {
    expect(
      EquipmentSetSelector.matchingGeofenceSet(
        divePoints: const [monterey],
        sets: [cold, def],
        geofences: [fence('g', 'cold', 0, 0, 1000)], // far away
      ),
      isNull,
    );
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/equipment/domain/services/equipment_set_selector_test.dart`
Expected: FAIL — `equipment_set_selector.dart` does not exist.

- [ ] **Step 3: Implement the selector**

Create `lib/features/equipment/domain/services/equipment_set_selector.dart`:

```dart
import 'package:submersion/core/utils/geo_math.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set_geofence.dart';

/// Pure selection of the best equipment set for a dive.
///
/// Precedence: a geofence containing any of the dive's points (nearest center
/// wins) beats the global default, which beats nothing.
class EquipmentSetSelector {
  const EquipmentSetSelector._();

  /// The geofence-matched set (nearest center) for [divePoints], or null when
  /// no geofence contains any point. Ignores the global default -- callers use
  /// this to decide whether to *suggest* a set (only geofences suggest).
  static EquipmentSet? matchingGeofenceSet({
    required List<GeoPoint> divePoints,
    required List<EquipmentSet> sets,
    required List<EquipmentSetGeofence> geofences,
  }) {
    if (divePoints.isEmpty || geofences.isEmpty) return null;
    EquipmentSetGeofence? best;
    var bestDistance = double.infinity;
    for (final fence in geofences) {
      final nearest = _minDistanceToAnyPoint(fence.center, divePoints);
      if (nearest > fence.radiusMeters) continue;
      if (best == null ||
          nearest < bestDistance ||
          (nearest == bestDistance && _isMoreSpecific(fence, best))) {
        best = fence;
        bestDistance = nearest;
      }
    }
    if (best == null) return null;
    for (final s in sets) {
      if (s.id == best.setId) return s;
    }
    return null;
  }

  /// Best set for a dive: a geofence match beats the global default, which
  /// beats nothing.
  static EquipmentSet? bestSetFor({
    required List<GeoPoint> divePoints,
    required List<EquipmentSet> sets,
    required List<EquipmentSetGeofence> geofences,
  }) {
    final geofenceMatch = matchingGeofenceSet(
      divePoints: divePoints,
      sets: sets,
      geofences: geofences,
    );
    if (geofenceMatch != null) return geofenceMatch;
    for (final s in sets) {
      if (s.isDefault) return s;
    }
    return null;
  }

  static double _minDistanceToAnyPoint(GeoPoint center, List<GeoPoint> points) {
    var min = double.infinity;
    for (final p in points) {
      final d = distanceMeters(center, p);
      if (d < min) min = d;
    }
    return min;
  }

  /// Tie-break when two fences are equidistant: smaller radius (more specific)
  /// wins, then lexicographic setId for determinism.
  static bool _isMoreSpecific(
    EquipmentSetGeofence candidate,
    EquipmentSetGeofence current,
  ) {
    if (candidate.radiusMeters != current.radiusMeters) {
      return candidate.radiusMeters < current.radiusMeters;
    }
    return candidate.setId.compareTo(current.setId) < 0;
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/equipment/domain/services/equipment_set_selector_test.dart`
Expected: PASS (all 6 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/equipment/domain/services/equipment_set_selector.dart test/features/equipment/domain/services/equipment_set_selector_test.dart
git commit -m "feat(equipment): pure multi-point equipment set selector (#583)"
```

---

## Task 4: Repository — default flag, geofence CRUD, hydration

**Files:**
- Modify: `lib/features/equipment/data/repositories/equipment_set_repository_impl.dart`
- Test: `test/features/equipment/data/repositories/equipment_set_repository_default_geofence_test.dart`

**Interfaces:**
- Consumes: `EquipmentSetGeofence`, `EquipmentSet.isDefault/geofences`, generated `EquipmentSetGeofencesCompanion`.
- Produces: `EquipmentSetRepository.setAsDefault(String id, {String? diverId})`, `.addGeofence(EquipmentSetGeofence)`, `.updateGeofence(EquipmentSetGeofence)`, `.removeGeofence(String geofenceId)`, `.getGeofencesForSet(String setId) → List<EquipmentSetGeofence>`, `.getAllGeofences({String? diverId}) → List<EquipmentSetGeofence>`; `getSetById(..., {bool includeGeofences})` and `getAllSets` now populate `isDefault`. Consumed by Tasks 5, 7.

- [ ] **Step 1: Write the failing repository test**

Create `test/features/equipment/data/repositories/equipment_set_repository_default_geofence_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_set_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set_geofence.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late EquipmentSetRepository repo;

  setUp(() async {
    db = await setUpTestDatabase();
    repo = EquipmentSetRepository();
  });

  tearDown(tearDownTestDatabase);

  EquipmentSet newSet(String id, String name, {String? diverId}) => EquipmentSet(
        id: id,
        diverId: diverId,
        name: name,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

  test('setAsDefault flips exactly one default within a diver', () async {
    await repo.createSet(newSet('a', 'A', diverId: 'd1'));
    await repo.createSet(newSet('b', 'B', diverId: 'd1'));

    await repo.setAsDefault('a', diverId: 'd1');
    expect((await repo.getSetById('a'))!.isDefault, isTrue);
    expect((await repo.getSetById('b'))!.isDefault, isFalse);

    await repo.setAsDefault('b', diverId: 'd1');
    expect((await repo.getSetById('a'))!.isDefault, isFalse);
    expect((await repo.getSetById('b'))!.isDefault, isTrue);
  });

  test('default is independent across divers', () async {
    await repo.createSet(newSet('a', 'A', diverId: 'd1'));
    await repo.createSet(newSet('z', 'Z', diverId: 'd2'));
    await repo.setAsDefault('a', diverId: 'd1');
    await repo.setAsDefault('z', diverId: 'd2');
    expect((await repo.getSetById('a'))!.isDefault, isTrue);
    expect((await repo.getSetById('z'))!.isDefault, isTrue);
  });

  test('geofence CRUD round-trips through the set', () async {
    await repo.createSet(newSet('a', 'A', diverId: 'd1'));
    final fence = EquipmentSetGeofence(
      id: 'g1',
      setId: 'a',
      label: 'Monterey',
      latitude: 36.62,
      longitude: -121.9,
      radiusMeters: 24000,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await repo.addGeofence(fence);
    expect(await repo.getGeofencesForSet('a'), hasLength(1));

    await repo.updateGeofence(fence.copyWith(radiusMeters: 30000));
    expect((await repo.getGeofencesForSet('a')).first.radiusMeters, 30000);

    final withGeofences = await repo.getSetById('a', includeGeofences: true);
    expect(withGeofences!.geofences, hasLength(1));

    await repo.removeGeofence('g1');
    expect(await repo.getGeofencesForSet('a'), isEmpty);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/equipment/data/repositories/equipment_set_repository_default_geofence_test.dart`
Expected: FAIL — the new methods do not exist.

- [ ] **Step 3: Add the imports and `setAsDefault`**

In `equipment_set_repository_impl.dart`, add the domain geofence import at the top:

```dart
import 'package:submersion/features/equipment/domain/entities/equipment_set_geofence.dart'
    as domain;
```

Add the `setAsDefault` method (mirrors `DiverRepository.setDefaultDiver`, scoped per diver):

```dart
  /// Set [id] as the diver's default equipment set, clearing the flag from the
  /// diver's other sets. Scoped per diver; each touched row is marked pending.
  Future<void> setAsDefault(String id, {String? diverId}) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    final clear = _db.update(_db.equipmentSets)
      ..where((t) => diverId == null
          ? t.diverId.isNull()
          : t.diverId.equals(diverId));
    await clear.write(
      EquipmentSetsCompanion(isDefault: const Value(false), updatedAt: Value(now)),
    );

    await (_db.update(_db.equipmentSets)..where((t) => t.id.equals(id))).write(
      EquipmentSetsCompanion(isDefault: const Value(true), updatedAt: Value(now)),
    );

    final affected = await (_db.select(_db.equipmentSets)
          ..where((t) => diverId == null
              ? t.diverId.isNull()
              : t.diverId.equals(diverId)))
        .get();
    for (final row in affected) {
      await _syncRepository.markRecordPending(
        entityType: 'equipmentSets',
        recordId: row.id,
        localUpdatedAt: now,
      );
    }
    SyncEventBus.notifyLocalChange();
  }
```

- [ ] **Step 4: Add geofence CRUD + read methods**

```dart
  /// All geofences for a set.
  Future<List<domain.EquipmentSetGeofence>> getGeofencesForSet(
    String setId,
  ) async {
    final rows = await (_db.select(_db.equipmentSetGeofences)
          ..where((t) => t.setId.equals(setId)))
        .get();
    return rows.map(_mapRowToGeofence).toList();
  }

  /// All geofences belonging to the given diver's sets (or all sets when
  /// [diverId] is null).
  Future<List<domain.EquipmentSetGeofence>> getAllGeofences({
    String? diverId,
  }) async {
    final setQuery = _db.select(_db.equipmentSets);
    if (diverId != null) {
      setQuery.where((t) => t.diverId.equals(diverId));
    }
    final setIds = (await setQuery.get()).map((s) => s.id).toSet();
    if (setIds.isEmpty) return [];
    final rows = await (_db.select(_db.equipmentSetGeofences)
          ..where((t) => t.setId.isIn(setIds)))
        .get();
    return rows.map(_mapRowToGeofence).toList();
  }

  Future<void> addGeofence(domain.EquipmentSetGeofence fence) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.into(_db.equipmentSetGeofences).insert(
          EquipmentSetGeofencesCompanion(
            id: Value(fence.id),
            setId: Value(fence.setId),
            label: Value(fence.label),
            latitude: Value(fence.latitude),
            longitude: Value(fence.longitude),
            radiusMeters: Value(fence.radiusMeters),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    await _syncRepository.markRecordPending(
      entityType: 'equipmentSetGeofences',
      recordId: fence.id,
      localUpdatedAt: now,
    );
    SyncEventBus.notifyLocalChange();
  }

  Future<void> updateGeofence(domain.EquipmentSetGeofence fence) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(_db.equipmentSetGeofences)
          ..where((t) => t.id.equals(fence.id)))
        .write(
      EquipmentSetGeofencesCompanion(
        label: Value(fence.label),
        latitude: Value(fence.latitude),
        longitude: Value(fence.longitude),
        radiusMeters: Value(fence.radiusMeters),
        updatedAt: Value(now),
      ),
    );
    await _syncRepository.markRecordPending(
      entityType: 'equipmentSetGeofences',
      recordId: fence.id,
      localUpdatedAt: now,
    );
    SyncEventBus.notifyLocalChange();
  }

  Future<void> removeGeofence(String geofenceId) async {
    await (_db.delete(_db.equipmentSetGeofences)
          ..where((t) => t.id.equals(geofenceId)))
        .go();
    await _syncRepository.logDeletion(
      entityType: 'equipmentSetGeofences',
      recordId: geofenceId,
    );
    SyncEventBus.notifyLocalChange();
  }

  domain.EquipmentSetGeofence _mapRowToGeofence(EquipmentSetGeofence row) {
    return domain.EquipmentSetGeofence(
      id: row.id,
      setId: row.setId,
      label: row.label,
      latitude: row.latitude,
      longitude: row.longitude,
      radiusMeters: row.radiusMeters,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
    );
  }
```

- [ ] **Step 5: Populate `isDefault` in `_mapRowToSet` and hydrate geofences in `getSetById`**

Update `_mapRowToSet` to carry `isDefault` (the `row` here is the Drift `EquipmentSet` row class, which now has `isDefault`):

```dart
  domain.EquipmentSet _mapRowToSet(
    EquipmentSet row,
    List<String> equipmentIds,
  ) {
    return domain.EquipmentSet(
      id: row.id,
      diverId: row.diverId,
      name: row.name,
      description: row.description,
      equipmentIds: equipmentIds,
      isDefault: row.isDefault,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
    );
  }
```

In `getSetById`, add an `includeGeofences` parameter and hydrate:

```dart
  Future<domain.EquipmentSet?> getSetById(
    String id, {
    bool includeItems = false,
    bool includeGeofences = false,
  }) async {
    final query = _db.select(_db.equipmentSets)..where((t) => t.id.equals(id));
    final row = await query.getSingleOrNull();
    if (row == null) return null;

    final equipmentIds = await getEquipmentIdsInSet(id);
    var set = _mapRowToSet(row, equipmentIds);

    if (includeItems) {
      final items = await _equipmentRepo.getEquipmentByIds(equipmentIds);
      set = set.copyWith(items: items);
    }
    if (includeGeofences) {
      set = set.copyWith(geofences: await getGeofencesForSet(id));
    }
    return set;
  }
```

- [ ] **Step 6: Run the test to verify it passes**

Run: `flutter test test/features/equipment/data/repositories/equipment_set_repository_default_geofence_test.dart`
Expected: PASS (all 3 tests).

- [ ] **Step 7: Commit**

```bash
git add lib/features/equipment/data/repositories/equipment_set_repository_impl.dart test/features/equipment/data/repositories/equipment_set_repository_default_geofence_test.dart
git commit -m "feat(equipment): repository default flag + geofence CRUD (#583)"
```

---

## Task 5: Providers — default, geofences, selection inputs, notifier methods

**Files:**
- Modify: `lib/features/equipment/presentation/providers/equipment_set_providers.dart`
- Test: `test/features/equipment/presentation/providers/equipment_set_providers_default_test.dart`

**Interfaces:**
- Consumes: repository methods from Task 4; `EquipmentSetSelector` (Task 3); `validatedCurrentDiverIdProvider`.
- Produces: `defaultEquipmentSetProvider → FutureProvider<EquipmentSet?>`; `equipmentSetGeofencesProvider.family<List<EquipmentSetGeofence>, String setId>`; `equipmentSetSelectionInputsProvider → FutureProvider<EquipmentSetSelectionInputs>` (holds the active diver's `sets` + `geofences`); notifier methods `setAsDefault`, `addGeofence`, `updateGeofence`, `removeGeofence`. Consumed by Tasks 10, 11, 12.

- [ ] **Step 1: Write the failing provider test**

Create `test/features/equipment/presentation/providers/equipment_set_providers_default_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_set_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_set_providers.dart';

import '../../../../helpers/test_database.dart';

void main() {
  setUp(() async {
    await setUpTestDatabase();
  });
  tearDown(tearDownTestDatabase);

  test('defaultEquipmentSetProvider returns the flagged set', () async {
    final repo = EquipmentSetRepository();
    await repo.createSet(EquipmentSet(
      id: 'a',
      diverId: 'd1',
      name: 'A',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ));
    await repo.setAsDefault('a', diverId: 'd1');

    final container = ProviderContainer(overrides: [
      validatedCurrentDiverIdProvider.overrideWith((ref) async => 'd1'),
    ]);
    addTearDown(container.dispose);

    final result = await container.read(defaultEquipmentSetProvider.future);
    expect(result?.id, 'a');
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/equipment/presentation/providers/equipment_set_providers_default_test.dart`
Expected: FAIL — `defaultEquipmentSetProvider` does not exist.

- [ ] **Step 3: Add the providers and the selection-inputs holder**

Append to `equipment_set_providers.dart` (add imports for `EquipmentSetGeofence`, `EquipmentSetSelector`):

```dart
/// The active diver's default equipment set, or null.
final defaultEquipmentSetProvider = FutureProvider<EquipmentSet?>((ref) async {
  final sets = await ref.watch(equipmentSetsProvider.future);
  for (final s in sets) {
    if (s.isDefault) {
      return ref.watch(equipmentSetWithItemsProvider(s.id).future);
    }
  }
  return null;
});

/// Geofences for a single set.
final equipmentSetGeofencesProvider =
    FutureProvider.family<List<EquipmentSetGeofence>, String>((ref, setId) async {
  final repo = ref.watch(equipmentSetRepositoryProvider);
  return repo.getGeofencesForSet(setId);
});

/// Immutable bundle the selector needs for the active diver.
class EquipmentSetSelectionInputs {
  final List<EquipmentSet> sets;
  final List<EquipmentSetGeofence> geofences;
  const EquipmentSetSelectionInputs({required this.sets, required this.geofences});
}

/// The active diver's sets (with items) + all their geofences, ready for the
/// selector.
final equipmentSetSelectionInputsProvider =
    FutureProvider<EquipmentSetSelectionInputs>((ref) async {
  final repo = ref.watch(equipmentSetRepositoryProvider);
  final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
  final sets = <EquipmentSet>[];
  for (final base in await repo.getAllSets(diverId: diverId)) {
    sets.add((await repo.getSetById(base.id, includeItems: true)) ?? base);
  }
  final geofences = await repo.getAllGeofences(diverId: diverId);
  return EquipmentSetSelectionInputs(sets: sets, geofences: geofences);
});
```

Also update the existing `equipmentSetProvider` so the set editor and detail page receive hydrated geofences — change its repository call to include them:

```dart
final equipmentSetProvider = FutureProvider.family<EquipmentSet?, String>((
  ref,
  id,
) async {
  final repository = ref.watch(equipmentSetRepositoryProvider);
  return repository.getSetById(id, includeItems: true, includeGeofences: true);
});
```

- [ ] **Step 4: Add notifier methods**

In `EquipmentSetListNotifier`, add:

```dart
  Future<void> setAsDefault(String id) async {
    final diverId = await _ref.read(validatedCurrentDiverIdProvider.future);
    await _repository.setAsDefault(id, diverId: diverId);
    await refresh();
    _ref.invalidate(defaultEquipmentSetProvider);
    _ref.invalidate(equipmentSetSelectionInputsProvider);
  }

  Future<void> addGeofence(EquipmentSetGeofence fence) async {
    await _repository.addGeofence(fence);
    _ref.invalidate(equipmentSetGeofencesProvider(fence.setId));
    _ref.invalidate(equipmentSetSelectionInputsProvider);
  }

  Future<void> updateGeofence(EquipmentSetGeofence fence) async {
    await _repository.updateGeofence(fence);
    _ref.invalidate(equipmentSetGeofencesProvider(fence.setId));
    _ref.invalidate(equipmentSetSelectionInputsProvider);
  }

  Future<void> removeGeofence(String setId, String geofenceId) async {
    await _repository.removeGeofence(geofenceId);
    _ref.invalidate(equipmentSetGeofencesProvider(setId));
    _ref.invalidate(equipmentSetSelectionInputsProvider);
  }
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `flutter test test/features/equipment/presentation/providers/equipment_set_providers_default_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/features/equipment/presentation/providers/equipment_set_providers.dart test/features/equipment/presentation/providers/equipment_set_providers_default_test.dart
git commit -m "feat(equipment): default + geofence + selection providers (#583)"
```

---

## Task 6: Sync — register `equipmentSetGeofences`

**Files:**
- Modify: `lib/core/services/sync/sync_data_serializer.dart`
- Test: `test/core/services/sync/equipment_set_geofence_sync_test.dart`

**Interfaces:**
- Consumes: generated `EquipmentSetGeofence` row class (`.toJson`, `.fromJson`, `.toCompanion(false)`), `_db.equipmentSetGeofences`.
- Produces: `equipmentSetGeofences` handled everywhere `equipmentSets` is (single-id + HLC entity template). `EquipmentSets.isDefault` rides the existing full-row `EquipmentSet.toJson/fromJson` (no serializer change needed beyond Task 1 codegen).

Mirror the `equipmentSets` (single-id + HLC) pattern — NOT the composite-key `equipmentSetItems` pattern — at every site below.

- [ ] **Step 1: Add the payload field + defaults**

After the `equipmentSetItems` field (~line 224):

```dart
  final List<Map<String, dynamic>> equipmentSets;
  final List<Map<String, dynamic>> equipmentSetItems;
  final List<Map<String, dynamic>> equipmentSetGeofences;
```

In the constructor defaults (~line 280):

```dart
    this.equipmentSets = const [],
    this.equipmentSetItems = const [],
    this.equipmentSetGeofences = const [],
```

- [ ] **Step 2: Add `toJson` + `fromJson` entries**

`toJson` (~line 337):

```dart
    'equipmentSets': equipmentSets,
    'equipmentSetItems': equipmentSetItems,
    'equipmentSetGeofences': equipmentSetGeofences,
```

`fromJson` (~line 395):

```dart
      equipmentSets: _parseList(json['equipmentSets']),
      equipmentSetItems: _parseList(json['equipmentSetItems']),
      equipmentSetGeofences: _parseList(json['equipmentSetGeofences']),
```

- [ ] **Step 3: Register in the export list + export assembly**

Export registry (~line 580, compact single-id form like `equipmentSets`):

```dart
    (key: 'equipmentSets', table: _db.equipmentSets, blob: false, full: null),
    (
      key: 'equipmentSetGeofences',
      table: _db.equipmentSetGeofences,
      blob: false,
      full: null,
    ),
```

Add the export helper next to `_exportEquipmentSets`:

```dart
  Future<List<Map<String, dynamic>>> _exportEquipmentSetGeofences(
    String? hlcSince,
  ) async {
    final query = _db.select(_db.equipmentSetGeofences);
    if (hlcSince != null) {
      query.where((t) => t.hlc.isBiggerThanValue(hlcSince));
    }
    final rows = await query.get();
    return rows.map((r) => r.toJson()).toList();
  }
```

Export assembly (~line 989):

```dart
      equipmentSetItems: await _safeExport(
        'equipmentSetItems',
        () => _exportEquipmentSetItems(hlcSince),
      ),
      equipmentSetGeofences: await _safeExport(
        'equipmentSetGeofences',
        () => _exportEquipmentSetGeofences(hlcSince),
      ),
```

- [ ] **Step 4: Add the six switch cases (mirror `equipmentSets`)**

`fetchRecord` (~line 1307):

```dart
      case 'equipmentSetGeofences':
        final row = await (_db.select(
          _db.equipmentSetGeofences,
        )..where((t) => t.id.equals(recordId))).getSingleOrNull();
        return row?.toJson();
```

`fetchRecords` (~line 1599):

```dart
      case 'equipmentSetGeofences':
        final rows = await (_db.select(
          _db.equipmentSetGeofences,
        )..where((t) => t.id.isIn(idList))).get();
        return {for (final r in rows) r.id: r.toJson()};
```

`upsertRecord` (~line 1831):

```dart
      case 'equipmentSetGeofences':
        await _db
            .into(_db.equipmentSetGeofences)
            .insertOnConflictUpdate(
              EquipmentSetGeofence.fromJson(data).toCompanion(false),
            );
        return;
```

`upsertRecords` (~line 2232):

```dart
      case 'equipmentSetGeofences':
        await _db.batch(
          (b) => b.insertAllOnConflictUpdate(
            _db.equipmentSetGeofences,
            records
                .map((r) => EquipmentSetGeofence.fromJson(r).toCompanion(false))
                .toList(),
          ),
        );
        return;
```

`recordIdsFor` (~line 2793, uses the `plain` helper like `equipmentSets`):

```dart
      case 'equipmentSetGeofences':
        return plain(_db.equipmentSetGeofences, _db.equipmentSetGeofences.id);
```

`_syncTableFor` (~line 2962):

```dart
      case 'equipmentSetGeofences':
        return _db.equipmentSetGeofences;
```

`deleteRecord` (~line 3094):

```dart
      case 'equipmentSetGeofences':
        await (_db.delete(
          _db.equipmentSetGeofences,
        )..where((t) => t.id.equals(recordId))).go();
        return;
```

- [ ] **Step 5: Write the sync round-trip test**

Create `test/core/services/sync/equipment_set_geofence_sync_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';

import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late SyncDataSerializer serializer;

  setUp(() async {
    db = await setUpTestDatabase();
    serializer = SyncDataSerializer();
  });
  tearDown(tearDownTestDatabase);

  test('geofence upsert + isDefault survive an export/import round-trip', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.into(db.equipmentSets).insert(
          EquipmentSetsCompanion.insert(
            id: 's1',
            name: 'Cold',
            createdAt: now,
            updatedAt: now,
            isDefault: const Value(true),
          ),
        );
    await db.into(db.equipmentSetGeofences).insert(
          EquipmentSetGeofencesCompanion.insert(
            id: 'g1',
            setId: 's1',
            latitude: 36.62,
            longitude: -121.9,
            radiusMeters: 24000,
            createdAt: now,
            updatedAt: now,
          ),
        );

    final exported = await serializer.exportData();
    expect(exported.equipmentSetGeofences, hasLength(1));

    // Wipe and re-import.
    await db.delete(db.equipmentSetGeofences).go();
    await db.delete(db.equipmentSets).go();
    await serializer.upsertRecords(
      'equipmentSets',
      exported.equipmentSets,
    );
    await serializer.upsertRecords(
      'equipmentSetGeofences',
      exported.equipmentSetGeofences,
    );

    final set = await (db.select(db.equipmentSets)
          ..where((t) => t.id.equals('s1')))
        .getSingle();
    expect(set.isDefault, isTrue);
    final fences = await db.select(db.equipmentSetGeofences).get();
    expect(fences.single.radiusMeters, 24000);
  });
}
```

> Note: match the exact `SyncDataSerializer` construction and `exportData`/`upsertRecords` entry points used by the neighboring sync tests in `test/core/services/sync/` — adjust the harness above if those tests use a wrapper (e.g. a `DatabaseService`-backed constructor or a named export method).

- [ ] **Step 6: Regenerate + run**

Run: `dart run build_runner build --delete-conflicting-outputs` (only if not already regenerated)
Run: `flutter test test/core/services/sync/equipment_set_geofence_sync_test.dart`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/core/services/sync/sync_data_serializer.dart test/core/services/sync/equipment_set_geofence_sync_test.dart
git commit -m "feat(sync): register equipmentSetGeofences entity (#583)"
```

---

## Task 7: `DiveEquipmentDefaulter` — apply on empty at persistence seams

**Files:**
- Create: `lib/features/equipment/data/services/dive_equipment_defaulter.dart`
- Test: `test/features/equipment/data/services/dive_equipment_defaulter_test.dart`

**Interfaces:**
- Consumes: `EquipmentSetRepository.getAllSets/getAllGeofences` (Task 4), `EquipmentSetSelector.bestSetFor` (Task 3), `DiveRepository.bulkAddEquipment(List<String> diveIds, List<String> equipmentIds)`, `GeoPoint`.
- Produces: `DiveEquipmentDefaulter().applyDefaultEquipmentIfEmpty({required String diveId, required String? diverId, required List<GeoPoint> divePoints}) → Future<bool>` (true when a set was applied). Consumed by Tasks 8, 9.

> Test note: the in-memory test DB does not enforce cross-table foreign keys (see `test/core/database/new_tables_drift_access_test.dart`, which inserts an orphan `credentialsHostId`). So these tests insert junction rows keyed by arbitrary `diveId`/`equipmentId` without seeding `Dives`/`Equipment`/`Divers` parents. If FK enforcement is ever enabled, seed those parents first.

- [ ] **Step 1: Write the failing test**

Create `test/features/equipment/data/services/dive_equipment_defaulter_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_set_repository_impl.dart';
import 'package:submersion/features/equipment/data/services/dive_equipment_defaulter.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set_geofence.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late EquipmentSetRepository sets;
  late DiveEquipmentDefaulter defaulter;

  setUp(() async {
    db = await setUpTestDatabase();
    sets = EquipmentSetRepository();
    defaulter = DiveEquipmentDefaulter();
  });
  tearDown(tearDownTestDatabase);

  EquipmentSet setWith(String id, List<String> equipmentIds,
          {bool isDefault = false}) =>
      EquipmentSet(
        id: id,
        diverId: 'd1',
        name: id,
        equipmentIds: equipmentIds,
        isDefault: isDefault,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

  Future<Set<String>> equipmentOn(String diveId) async {
    final rows = await (db.select(db.diveEquipment)
          ..where((t) => t.diveId.equals(diveId)))
        .get();
    return rows.map((r) => r.equipmentId).toSet();
  }

  test('applies the default set to a dive with no equipment', () async {
    await sets.createSet(setWith('def', ['e1', 'e2']));
    await sets.setAsDefault('def', diverId: 'd1');

    final applied = await defaulter.applyDefaultEquipmentIfEmpty(
      diveId: 'dive1',
      diverId: 'd1',
      divePoints: const [],
    );

    expect(applied, isTrue);
    expect(await equipmentOn('dive1'), {'e1', 'e2'});
  });

  test('never overwrites a dive that already has equipment', () async {
    await sets.createSet(setWith('def', ['e1'], isDefault: true));
    await sets.setAsDefault('def', diverId: 'd1');
    await db.into(db.diveEquipment).insert(
          DiveEquipmentCompanion.insert(diveId: 'dive2', equipmentId: 'existing'),
        );

    final applied = await defaulter.applyDefaultEquipmentIfEmpty(
      diveId: 'dive2',
      diverId: 'd1',
      divePoints: const [],
    );

    expect(applied, isFalse);
    expect(await equipmentOn('dive2'), {'existing'});
  });

  test('a matching geofence beats the default (entry GPS)', () async {
    await sets.createSet(setWith('def', ['warm'], isDefault: true));
    await sets.setAsDefault('def', diverId: 'd1');
    await sets.createSet(setWith('cold', ['drysuit']));
    await sets.addGeofence(EquipmentSetGeofence(
      id: 'g1',
      setId: 'cold',
      latitude: 36.62,
      longitude: -121.90,
      radiusMeters: 25000,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ));

    final applied = await defaulter.applyDefaultEquipmentIfEmpty(
      diveId: 'dive3',
      diverId: 'd1',
      divePoints: const [GeoPoint(36.62, -121.90)],
    );

    expect(applied, isTrue);
    expect(await equipmentOn('dive3'), {'drysuit'});
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/equipment/data/services/dive_equipment_defaulter_test.dart`
Expected: FAIL — `dive_equipment_defaulter.dart` does not exist.

- [ ] **Step 3: Implement the service**

Create `lib/features/equipment/data/services/dive_equipment_defaulter.dart`:

```dart
import 'package:drift/drift.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_set_repository_impl.dart';
import 'package:submersion/features/equipment/domain/services/equipment_set_selector.dart';

/// Applies a diver's default / geofenced equipment set to a dive that has no
/// equipment yet. Used by the non-interactive creation seams (dive-computer
/// download, file import). Never overwrites gear already present.
class DiveEquipmentDefaulter {
  DiveEquipmentDefaulter({
    EquipmentSetRepository? equipmentSetRepository,
    DiveRepository? diveRepository,
  })  : _sets = equipmentSetRepository ?? EquipmentSetRepository(),
        _dives = diveRepository ?? DiveRepository();

  final EquipmentSetRepository _sets;
  final DiveRepository _dives;

  AppDatabase get _db => DatabaseService.instance.database;

  /// Returns true when a set was applied.
  Future<bool> applyDefaultEquipmentIfEmpty({
    required String diveId,
    required String? diverId,
    required List<GeoPoint> divePoints,
  }) async {
    final existing = await (_db.select(_db.diveEquipment)
          ..where((t) => t.diveId.equals(diveId)))
        .get();
    if (existing.isNotEmpty) return false;

    final candidateSets = await _sets.getAllSets(diverId: diverId);
    if (candidateSets.isEmpty) return false;
    final geofences = await _sets.getAllGeofences(diverId: diverId);

    final best = EquipmentSetSelector.bestSetFor(
      divePoints: divePoints,
      sets: candidateSets,
      geofences: geofences,
    );
    if (best == null || best.equipmentIds.isEmpty) return false;

    await _dives.bulkAddEquipment([diveId], best.equipmentIds);
    SyncEventBus.notifyLocalChange();
    return true;
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/equipment/data/services/dive_equipment_defaulter_test.dart`
Expected: PASS (all 3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/equipment/data/services/dive_equipment_defaulter.dart test/features/equipment/data/services/dive_equipment_defaulter_test.dart
git commit -m "feat(equipment): dive equipment defaulter service (#583)"
```

---

## Task 8: Wire the defaulter into the dive-computer download seam

**Files:**
- Modify: `lib/features/dive_log/data/repositories/dive_computer_repository_impl.dart` (the `isNewDive` block, right after the `markRecordPending(entityType: 'dives', ...)` at ~line 913-919)

**Interfaces:**
- Consumes: `DiveEquipmentDefaulter.applyDefaultEquipmentIfEmpty`, `GeoPoint`; the in-scope download variables `diveId`, `diverId`, `entryLatitude`, `entryLongitude`, `exitLatitude`, `exitLongitude` (all `double?` except the ids).

> This seam is exercised end-to-end only with real hardware. Its behavior (apply-on-empty, geofence-by-entry-GPS) is unit-covered by Task 7; this task is the wiring plus an analyze/format gate and a manual smoke note.

- [ ] **Step 1: Add imports**

At the top of `dive_computer_repository_impl.dart`, add:

```dart
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/equipment/data/services/dive_equipment_defaulter.dart';
```

- [ ] **Step 2: Call the defaulter after the new-dive insert**

Immediately after the `await _syncRepository.markRecordPending(entityType: 'dives', recordId: diveId, localUpdatedAt: now);` block inside `if (isNewDive)`, add:

```dart
        // Auto-apply the diver's default / geofenced equipment set to this
        // freshly downloaded dive (only when it has no equipment yet). Entry
        // and exit GPS fixes drive geofence matching.
        final defaultPoints = <GeoPoint>[
          if (entryLatitude != null && entryLongitude != null)
            GeoPoint(entryLatitude, entryLongitude),
          if (exitLatitude != null && exitLongitude != null)
            GeoPoint(exitLatitude, exitLongitude),
        ];
        await DiveEquipmentDefaulter().applyDefaultEquipmentIfEmpty(
          diveId: diveId,
          diverId: diverId,
          divePoints: defaultPoints,
        );
```

- [ ] **Step 3: Verify analyze + format**

Run: `flutter analyze lib/features/dive_log/data/repositories/dive_computer_repository_impl.dart`
Expected: No issues.
Run: `dart format lib/features/dive_log/data/repositories/dive_computer_repository_impl.dart`
Expected: no changes (already formatted).

- [ ] **Step 4: Run the equipment + dive_log test suites (regression)**

Run: `flutter test test/features/equipment test/features/dive_log`
Expected: PASS (no regressions).

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_log/data/repositories/dive_computer_repository_impl.dart
git commit -m "feat(dive-computer): apply default equipment set on download (#583)"
```

---

## Task 9: Wire the defaulter into the file-import seams

**Files:**
- Modify: `lib/features/dive_import/data/services/uddf_entity_importer.dart:1279`
- Modify: `lib/features/dive_import/presentation/providers/dive_import_providers.dart:381`
- Modify: `lib/features/import_wizard/data/adapters/healthkit_adapter.dart:269`

**Interfaces:**
- Consumes: `DiveRepository.createDive` (returns the persisted `domain.Dive` with its final `id`), `DiveEquipmentDefaulter`, `GeoPoint`; each imported `dive` exposes `diverId`, `site?.location`, `entryLocation`, `exitLocation`.

> Merge/consolidation (`dive_merge_service.dart:145`) also calls `createDive` but is intentionally NOT wired — a merged dive's equipment comes from its source dives.

- [ ] **Step 1: Add a shared helper on the defaulter for imported domain dives**

To avoid repeating point-assembly at three call sites, add this method to `DiveEquipmentDefaulter` (in `dive_equipment_defaulter.dart`), importing `Dive`:

```dart
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
```

```dart
  /// Convenience for imported domain dives: assembles the dive's known points
  /// (linked site + entry/exit fixes) and applies on empty.
  Future<bool> applyForImportedDive(Dive dive) {
    final points = <GeoPoint>[
      if (dive.site?.location != null) dive.site!.location!,
      if (dive.entryLocation != null) dive.entryLocation!,
      if (dive.exitLocation != null) dive.exitLocation!,
    ];
    return applyDefaultEquipmentIfEmpty(
      diveId: dive.id,
      diverId: dive.diverId,
      divePoints: points,
    );
  }
```

- [ ] **Step 2: Extend the defaulter test to cover `applyForImportedDive`**

Add to `dive_equipment_defaulter_test.dart`:

```dart
  test('applyForImportedDive uses the linked site location', () async {
    await sets.createSet(setWith('cold', ['drysuit']));
    await sets.addGeofence(EquipmentSetGeofence(
      id: 'g1',
      setId: 'cold',
      latitude: 36.62,
      longitude: -121.90,
      radiusMeters: 25000,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ));
    final dive = createTestDiveWithBottomTime().copyWith(
      id: 'dive-import',
      diverId: 'd1',
      site: const DiveSite(
        id: 'site1',
        name: 'Breakwater',
        location: GeoPoint(36.62, -121.90),
      ),
    );

    final applied = await defaulter.applyForImportedDive(dive);
    expect(applied, isTrue);
    expect(await equipmentOn('dive-import'), {'drysuit'});
  });
```

Add the imports this test needs at the top of the file:

```dart
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import '../../../../helpers/mock_providers.dart';
```

> Confirm `createTestDiveWithBottomTime` (from `mock_providers.dart`) and the `DiveSite` constructor's required fields against the actual signatures; adjust the fixture if `DiveSite`/`Dive` require additional non-null fields.

- [ ] **Step 3: Wire the UDDF importer**

In `uddf_entity_importer.dart`, change line 1279 from:

```dart
        await repos.diveRepository.createDive(dive);
```

to:

```dart
        final createdDive = await repos.diveRepository.createDive(dive);
        await DiveEquipmentDefaulter().applyForImportedDive(createdDive);
```

Add the import at the top:

```dart
import 'package:submersion/features/equipment/data/services/dive_equipment_defaulter.dart';
```

- [ ] **Step 4: Wire the dive-import provider**

In `dive_import_providers.dart`, change line 381 from:

```dart
        await repository.createDive(dive);
```

to:

```dart
        final createdDive = await repository.createDive(dive);
        await DiveEquipmentDefaulter().applyForImportedDive(createdDive);
```

Add the import at the top:

```dart
import 'package:submersion/features/equipment/data/services/dive_equipment_defaulter.dart';
```

- [ ] **Step 5: Wire the HealthKit adapter**

In `healthkit_adapter.dart`, change line 269 from:

```dart
      await _diveRepository.createDive(dive);
```

to:

```dart
      final createdDive = await _diveRepository.createDive(dive);
      await DiveEquipmentDefaulter().applyForImportedDive(createdDive);
```

Add the import at the top:

```dart
import 'package:submersion/features/equipment/data/services/dive_equipment_defaulter.dart';
```

- [ ] **Step 6: Run tests + analyze**

Run: `flutter test test/features/equipment/data/services/dive_equipment_defaulter_test.dart`
Expected: PASS (now 4 tests).
Run: `flutter analyze lib/features/dive_import lib/features/import_wizard/data/adapters/healthkit_adapter.dart`
Expected: No issues.

- [ ] **Step 7: Commit**

```bash
git add lib/features/equipment/data/services/dive_equipment_defaulter.dart lib/features/dive_import lib/features/import_wizard/data/adapters/healthkit_adapter.dart test/features/equipment/data/services/dive_equipment_defaulter_test.dart
git commit -m "feat(import): apply default equipment set on file import (#583)"
```

---

## Task 10: Dive edit form — auto-apply on empty + suggestion banner

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/geofence_suggestion_banner.dart`
- Modify: `lib/features/dive_log/presentation/pages/dive_edit_page.dart`
- Modify: `lib/l10n/arb/app_en.arb`
- Test: `test/features/dive_log/presentation/widgets/geofence_suggestion_banner_test.dart`

**Interfaces:**
- Consumes: `equipmentSetSelectionInputsProvider` (Task 5), `EquipmentSetSelector.bestSetFor/matchingGeofenceSet` (Task 3), `GeoPoint`; existing page state `_selectedEquipment` (`List<EquipmentItem>`), `_selectedSite` (`DiveSite?`), `_existingDive` (`Dive?`), `_markDirty()`, widget getters `isEditing` (`diveId != null`) and `bulkDiveIds`.
- Produces: `GeofenceSuggestionBanner` widget.

> The page itself is large and provider-heavy; the banner widget is unit-tested here and the decision logic reuses the Task 3 selector (already tested). The page wiring is verified via analyze + a manual macOS smoke. Keep the added state and methods small and self-contained.

- [ ] **Step 1: Write the failing banner test**

Create `test/features/dive_log/presentation/widgets/geofence_suggestion_banner_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/presentation/widgets/geofence_suggestion_banner.dart';

import '../../../../helpers/test_app.dart';

void main() {
  testWidgets('shows set + location and fires callbacks', (tester) async {
    var applied = false;
    var dismissed = false;
    await tester.pumpWidget(testApp(
      child: GeofenceSuggestionBanner(
        setName: 'Cold Water',
        locationLabel: 'Monterey Bay',
        onApply: () => applied = true,
        onDismiss: () => dismissed = true,
      ),
    ));

    expect(find.textContaining('Monterey Bay'), findsOneWidget);
    expect(find.textContaining('Cold Water'), findsOneWidget);

    await tester.tap(find.text('Apply'));
    expect(applied, isTrue);
    await tester.tap(find.text('Dismiss'));
    expect(dismissed, isTrue);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/dive_log/presentation/widgets/geofence_suggestion_banner_test.dart`
Expected: FAIL — widget does not exist.

- [ ] **Step 3: Add the l10n keys (English)**

Add to `lib/l10n/arb/app_en.arb`:

```json
  "diveLog_edit_geofenceSuggestion_near": "Near {location}",
  "@diveLog_edit_geofenceSuggestion_near": {
    "placeholders": { "location": { "type": "String" } }
  },
  "diveLog_edit_geofenceSuggestion_title": "Equipment suggestion",
  "diveLog_edit_geofenceSuggestion_body": "Apply your \"{setName}\" set?",
  "@diveLog_edit_geofenceSuggestion_body": {
    "placeholders": { "setName": { "type": "String" } }
  },
  "diveLog_edit_geofenceSuggestion_apply": "Apply",
  "common_action_dismiss": "Dismiss",
```

Run: `flutter gen-l10n`
Expected: `AppLocalizations` regenerates with the new getters. No errors.

- [ ] **Step 4: Create the banner widget**

Create `lib/features/dive_log/presentation/widgets/geofence_suggestion_banner.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// Dismissible banner suggesting a geofenced equipment set for the current dive.
class GeofenceSuggestionBanner extends StatelessWidget {
  final String setName;
  final String? locationLabel;
  final VoidCallback onApply;
  final VoidCallback onDismiss;

  const GeofenceSuggestionBanner({
    super.key,
    required this.setName,
    required this.locationLabel,
    required this.onApply,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.secondaryContainer,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        child: Row(
          children: [
            Icon(
              Icons.place_outlined,
              color: theme.colorScheme.onSecondaryContainer,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    locationLabel != null
                        ? context.l10n.diveLog_edit_geofenceSuggestion_near(
                            locationLabel!,
                          )
                        : context.l10n.diveLog_edit_geofenceSuggestion_title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSecondaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    context.l10n.diveLog_edit_geofenceSuggestion_body(setName),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: onDismiss,
              child: Text(context.l10n.common_action_dismiss),
            ),
            const SizedBox(width: 4),
            FilledButton(
              onPressed: onApply,
              child: Text(context.l10n.diveLog_edit_geofenceSuggestion_apply),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Run the banner test to verify it passes**

Run: `flutter test test/features/dive_log/presentation/widgets/geofence_suggestion_banner_test.dart`
Expected: PASS.

- [ ] **Step 6: Add page imports + state fields**

In `dive_edit_page.dart`, add imports:

```dart
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/equipment/domain/services/equipment_set_selector.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_set_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/geofence_suggestion_banner.dart';
```

Add state fields near the other `_selected*` fields (~line 165):

```dart
  EquipmentSet? _geofenceSuggestion;
  final Set<String> _dismissedSuggestionSetIds = {};
```

- [ ] **Step 7: Add the decision methods**

Add these methods to the state class:

```dart
  List<GeoPoint> _currentDivePoints() => [
        if (_selectedSite?.location != null) _selectedSite!.location!,
        if (_existingDive?.entryLocation != null) _existingDive!.entryLocation!,
        if (_existingDive?.exitLocation != null) _existingDive!.exitLocation!,
      ];

  /// New-dive path: fill empty equipment with the best set (geofence or default).
  Future<void> _applyEquipmentDefaultsOnEmpty() async {
    if (_selectedEquipment.isNotEmpty) return;
    final inputs = await ref.read(equipmentSetSelectionInputsProvider.future);
    final best = EquipmentSetSelector.bestSetFor(
      divePoints: _currentDivePoints(),
      sets: inputs.sets,
      geofences: inputs.geofences,
    );
    final items = best?.items ?? const [];
    if (items.isEmpty || !mounted) return;
    setState(() => _selectedEquipment = [...items]);
  }

  /// Site-change path: apply on empty, else suggest a differing geofence set.
  Future<void> _reevaluateGeofenceForSite() async {
    final inputs = await ref.read(equipmentSetSelectionInputsProvider.future);
    final points = _currentDivePoints();
    if (_selectedEquipment.isEmpty) {
      final best = EquipmentSetSelector.bestSetFor(
        divePoints: points,
        sets: inputs.sets,
        geofences: inputs.geofences,
      );
      final items = best?.items ?? const [];
      if (items.isNotEmpty && mounted) {
        setState(() => _selectedEquipment = [...items]);
      }
      return;
    }
    final geofenceSet = EquipmentSetSelector.matchingGeofenceSet(
      divePoints: points,
      sets: inputs.sets,
      geofences: inputs.geofences,
    );
    if (geofenceSet == null || !mounted) return;
    if (_dismissedSuggestionSetIds.contains(geofenceSet.id)) return;
    final currentIds = _selectedEquipment.map((e) => e.id).toSet();
    final hasNewItem =
        (geofenceSet.items ?? const []).any((e) => !currentIds.contains(e.id));
    if (!hasNewItem) return; // already fully present
    setState(() => _geofenceSuggestion = geofenceSet);
  }
```

- [ ] **Step 8: Schedule the on-empty apply for a new single dive**

At the end of `initState`, add (single new dive only — not editing, not bulk):

```dart
    if (!widget.isEditing && widget.bulkDiveIds == null) {
      Future.microtask(() {
        if (mounted) _applyEquipmentDefaultsOnEmpty();
      });
    }
```

- [ ] **Step 9: Re-evaluate on site selection**

In `_showSitePicker`, after each `setState(() => _selectedSite = site);` (the `onSiteSelected` callback ~line 1961 and the create-new-site branch ~line 1978), add a call on the next line:

```dart
            setState(() => _selectedSite = site);
            _reevaluateGeofenceForSite();
```

(and in the create-new-site branch:)

```dart
          setState(() => _selectedSite = site);
          _reevaluateGeofenceForSite();
```

- [ ] **Step 10: Render the banner in the equipment section**

In `_equipmentChild`, immediately after the header `Row(...)` (the one with the "Use Set" / "Add" buttons) and before the `if (_selectedEquipment.isEmpty)` block, insert:

```dart
          if (_geofenceSuggestion != null)
            GeofenceSuggestionBanner(
              setName: _geofenceSuggestion!.name,
              locationLabel: _selectedSite?.name,
              onApply: () {
                setState(() {
                  _markDirty();
                  final ids = _selectedEquipment.map((e) => e.id).toSet();
                  for (final item in _geofenceSuggestion!.items ?? const []) {
                    if (!ids.contains(item.id)) _selectedEquipment.add(item);
                  }
                  _geofenceSuggestion = null;
                });
              },
              onDismiss: () => setState(() {
                _dismissedSuggestionSetIds.add(_geofenceSuggestion!.id);
                _geofenceSuggestion = null;
              }),
            ),
```

- [ ] **Step 11: Verify analyze + format + regression**

Run: `flutter analyze lib/features/dive_log/presentation/pages/dive_edit_page.dart lib/features/dive_log/presentation/widgets/geofence_suggestion_banner.dart`
Expected: No issues.
Run: `dart format lib/features/dive_log test/features/dive_log`
Expected: no changes.
Run: `flutter test test/features/dive_log`
Expected: PASS.

- [ ] **Step 12: Commit**

```bash
git add lib/features/dive_log/presentation/pages/dive_edit_page.dart lib/features/dive_log/presentation/widgets/geofence_suggestion_banner.dart lib/l10n/arb/app_en.arb lib/l10n/arb/app_localizations*.dart test/features/dive_log/presentation/widgets/geofence_suggestion_banner_test.dart
git commit -m "feat(dive-log): auto-apply equipment set + geofence suggestion banner (#583)"
```

---

## Task 11: Set editor — default switch + geofences section

**Files:**
- Create: `lib/features/equipment/presentation/widgets/geofence_editor_sheet.dart`
- Modify: `lib/features/equipment/presentation/pages/equipment_set_edit_page.dart`
- Modify: `lib/l10n/arb/app_en.arb`
- Test: `test/features/equipment/presentation/widgets/geofence_editor_sheet_test.dart`

**Interfaces:**
- Consumes: `EquipmentSetGeofence` (Task 2), `equipmentSetGeofencesProvider` + notifier `addGeofence/updateGeofence/removeGeofence/setAsDefault` (Task 5), `LocationPickerMap` (`lib/features/dive_sites/presentation/widgets/location_picker_map.dart`, returns `PickedLocation{latitude, longitude, country, region, locality}`), `UnitFormatter.formatGeoDistance(double meters)` (`lib/core/utils/unit_formatter.dart`), `settingsProvider` / `depthUnit`.
- Produces: `GeofenceEditorSheet` returning a `GeofenceDraft({double latitude, double longitude, String? label, double radiusMeters})?` via `Navigator.pop`.

> The geofence editor offers two anchor sources: reuse the existing `LocationPickerMap` full-screen picker for "drop a pin", and reuse `SitePickerSheet` (already used by `dive_edit_page._showSitePicker`) for "from dive site". Construct `UnitFormatter` the same way neighboring widgets do (confirm whether it is `ref.watch(unitFormatterProvider)` or `UnitFormatter(settings)` and match it).

- [ ] **Step 1: Add l10n keys (English)**

Add to `lib/l10n/arb/app_en.arb`:

```json
  "equipment_setEdit_defaultSwitch_title": "Default set",
  "equipment_setEdit_defaultSwitch_subtitle": "Auto-applied to new dives that have no equipment yet",
  "equipment_setEdit_geofencesTitle": "Geofences",
  "equipment_setEdit_geofencesSubtitle": "Auto-suggest this set for dives near these locations",
  "equipment_setEdit_addGeofence": "Add geofence",
  "equipment_setEdit_geofenceRadius": "Radius: {distance}",
  "@equipment_setEdit_geofenceRadius": {
    "placeholders": { "distance": { "type": "String" } }
  },
  "equipment_geofenceEditor_title": "Geofence",
  "equipment_geofenceEditor_fromSite": "From dive site",
  "equipment_geofenceEditor_dropPin": "Drop a pin",
  "equipment_geofenceEditor_labelLabel": "Label",
  "equipment_geofenceEditor_noCenter": "Choose a center point",
  "equipment_geofenceEditor_save": "Save geofence",
```

Run: `flutter gen-l10n`
Expected: regenerates with new getters.

- [ ] **Step 2: Write the failing geofence-editor test**

Create `test/features/equipment/presentation/widgets/geofence_editor_sheet_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/equipment/presentation/widgets/geofence_editor_sheet.dart';

import '../../../../helpers/test_app.dart';

void main() {
  testWidgets('save is disabled until a center is chosen', (tester) async {
    await tester.pumpWidget(testApp(
      child: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => showGeofenceEditor(context),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final saveButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Save geofence'),
    );
    expect(saveButton.onPressed, isNull, reason: 'disabled without a center');
  });
}
```

- [ ] **Step 3: Run it to verify it fails**

Run: `flutter test test/features/equipment/presentation/widgets/geofence_editor_sheet_test.dart`
Expected: FAIL — file does not exist.

- [ ] **Step 4: Create the geofence editor sheet**

Create `lib/features/equipment/presentation/widgets/geofence_editor_sheet.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/location_picker_map.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Result of the geofence editor: a center + radius (+ optional label).
class GeofenceDraft {
  final double latitude;
  final double longitude;
  final String? label;
  final double radiusMeters;

  const GeofenceDraft({
    required this.latitude,
    required this.longitude,
    this.label,
    required this.radiusMeters,
  });
}

/// Opens the geofence editor and returns the draft, or null if cancelled.
Future<GeofenceDraft?> showGeofenceEditor(
  BuildContext context, {
  GeofenceDraft? initial,
}) {
  return showModalBottomSheet<GeofenceDraft>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _GeofenceEditorSheet(initial: initial),
  );
}

class _GeofenceEditorSheet extends ConsumerStatefulWidget {
  final GeofenceDraft? initial;
  const _GeofenceEditorSheet({this.initial});

  @override
  ConsumerState<_GeofenceEditorSheet> createState() =>
      _GeofenceEditorSheetState();
}

class _GeofenceEditorSheetState extends ConsumerState<_GeofenceEditorSheet> {
  double? _latitude;
  double? _longitude;
  double _radiusMeters = 15000;
  final _labelController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _latitude = widget.initial?.latitude;
    _longitude = widget.initial?.longitude;
    _radiusMeters = widget.initial?.radiusMeters ?? 15000;
    _labelController.text = widget.initial?.label ?? '';
  }

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  Future<void> _dropPin() async {
    final result = await Navigator.of(context).push<PickedLocation>(
      MaterialPageRoute(
        builder: (_) => LocationPickerMap(
          initialLocation: _latitude != null && _longitude != null
              ? LatLng(_latitude!, _longitude!)
              : null,
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _latitude = result.latitude;
        _longitude = result.longitude;
        if (_labelController.text.isEmpty) {
          _labelController.text = result.locality ?? result.region ?? '';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final formatter = UnitFormatter(settings.depthUnit);
    final hasCenter = _latitude != null && _longitude != null;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.equipment_geofenceEditor_title,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _dropPin,
            icon: const Icon(Icons.map_outlined),
            label: Text(context.l10n.equipment_geofenceEditor_dropPin),
          ),
          const SizedBox(height: 8),
          Text(
            hasCenter
                ? '${_latitude!.toStringAsFixed(5)}, '
                    '${_longitude!.toStringAsFixed(5)}'
                : context.l10n.equipment_geofenceEditor_noCenter,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _labelController,
            decoration: InputDecoration(
              labelText: context.l10n.equipment_geofenceEditor_labelLabel,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.equipment_setEdit_geofenceRadius(
              formatter.formatGeoDistance(_radiusMeters),
            ),
          ),
          Slider(
            min: 500,
            max: 100000,
            value: _radiusMeters,
            onChanged: (v) => setState(() => _radiusMeters = v),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: hasCenter
                  ? () => Navigator.of(context).pop(
                        GeofenceDraft(
                          latitude: _latitude!,
                          longitude: _longitude!,
                          label: _labelController.text.trim().isEmpty
                              ? null
                              : _labelController.text.trim(),
                          radiusMeters: _radiusMeters,
                        ),
                      )
                  : null,
              child: Text(context.l10n.equipment_geofenceEditor_save),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Run the editor test to verify it passes**

Run: `flutter test test/features/equipment/presentation/widgets/geofence_editor_sheet_test.dart`
Expected: PASS.

- [ ] **Step 6: Add the default switch + geofences section to the set editor**

In `equipment_set_edit_page.dart`:

Add state fields and initialize them in `_initializeFromSet`:

```dart
  bool _isDefault = false;
  List<EquipmentSetGeofence> _geofences = [];
```

In `_initializeFromSet(EquipmentSet set)`:

```dart
    _isDefault = set.isDefault;
    _geofences = List.of(set.geofences);
```

The editor already watches `equipmentSetProvider(widget.setId!)`, which (after the Task 5 change) hydrates `geofences`, so `set.geofences` is populated here.

In `_buildForm`, after the description `TextFormField` (before the equipment selection `Text`), add the default switch and geofences section:

```dart
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(context.l10n.equipment_setEdit_defaultSwitch_title),
              subtitle:
                  Text(context.l10n.equipment_setEdit_defaultSwitch_subtitle),
              value: _isDefault,
              onChanged: (v) => setState(() => _isDefault = v),
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.equipment_setEdit_geofencesTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              context.l10n.equipment_setEdit_geofencesSubtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 8),
            ..._geofences.asMap().entries.map((entry) {
              final i = entry.key;
              final g = entry.value;
              final formatter =
                  UnitFormatter(ref.watch(settingsProvider).depthUnit);
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.place_outlined),
                title: Text(g.label ?? context.l10n.equipment_geofenceEditor_title),
                subtitle: Text(
                  context.l10n.equipment_setEdit_geofenceRadius(
                    formatter.formatGeoDistance(g.radiusMeters),
                  ),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => _geofences.removeAt(i)),
                ),
              );
            }),
            OutlinedButton.icon(
              onPressed: _addGeofence,
              icon: const Icon(Icons.add_location_alt_outlined),
              label: Text(context.l10n.equipment_setEdit_addGeofence),
            ),
            const SizedBox(height: 24),
```

Add the `_addGeofence` method and the required imports (`showGeofenceEditor`, `EquipmentSetGeofence`, `UnitFormatter`, `settingsProvider`, `uuid`):

```dart
  Future<void> _addGeofence() async {
    final draft = await showGeofenceEditor(context);
    if (draft == null || !mounted) return;
    setState(() {
      _geofences = [
        ..._geofences,
        EquipmentSetGeofence(
          id: const Uuid().v4(),
          setId: widget.setId ?? '',
          label: draft.label,
          latitude: draft.latitude,
          longitude: draft.longitude,
          radiusMeters: draft.radiusMeters,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];
    });
  }
```

- [ ] **Step 7: Persist default + geofences in `_saveSet`**

In `_saveSet`, after the set is created/updated via the notifier, persist the default flag and reconcile geofences. Replace the save block so that, for both new and edit, the final `setId` is known (for a new set, `notifier.addSet` returns the created set with its id):

```dart
      final notifier = ref.read(equipmentSetListNotifierProvider.notifier);

      final String savedId;
      if (widget.isEditing) {
        await notifier.updateSet(set);
        savedId = set.id;
      } else {
        final created = await notifier.addSet(set);
        savedId = created.id;
      }

      // Default flag (per-diver mutual exclusion handled in the repository).
      if (_isDefault) {
        await notifier.setAsDefault(savedId);
      }

      // Reconcile geofences: remove those dropped, add/update the rest.
      final existing = await ref
          .read(equipmentSetRepositoryProvider)
          .getGeofencesForSet(savedId);
      final keptIds = _geofences.map((g) => g.id).toSet();
      for (final old in existing) {
        if (!keptIds.contains(old.id)) {
          await notifier.removeGeofence(savedId, old.id);
        }
      }
      for (final g in _geofences) {
        final fence = g.copyWith(setId: savedId);
        if (existing.any((e) => e.id == g.id)) {
          await notifier.updateGeofence(fence);
        } else {
          await notifier.addGeofence(fence);
        }
      }
```

- [ ] **Step 8: Verify analyze + format + tests**

Run: `flutter analyze lib/features/equipment`
Expected: No issues.
Run: `dart format lib/features/equipment test/features/equipment`
Expected: no changes.
Run: `flutter test test/features/equipment`
Expected: PASS.

- [ ] **Step 9: Commit**

```bash
git add lib/features/equipment/presentation/widgets/geofence_editor_sheet.dart lib/features/equipment/presentation/pages/equipment_set_edit_page.dart lib/l10n/arb/app_en.arb lib/l10n/arb/app_localizations*.dart test/features/equipment/presentation/widgets/geofence_editor_sheet_test.dart
git commit -m "feat(equipment): default switch + geofences editor in set editor (#583)"
```

---

## Task 12: Set list + detail — default badge, "Set as default", geofences

**Files:**
- Modify: `lib/features/equipment/presentation/widgets/equipment_set_list_content.dart`
- Modify: `lib/features/equipment/presentation/pages/equipment_set_detail_page.dart`
- Modify: `lib/l10n/arb/app_en.arb`
- Test: `test/features/equipment/presentation/pages/equipment_set_detail_default_test.dart`

**Interfaces:**
- Consumes: `EquipmentSet.isDefault` (Task 2), `equipmentSetGeofencesProvider` (Task 5), notifier `setAsDefault` (Task 5), `equipmentSetProvider` (existing).

- [ ] **Step 1: Add l10n keys (English)**

Add to `lib/l10n/arb/app_en.arb`:

```json
  "equipment_sets_defaultBadge": "Default",
  "equipment_setDetail_setAsDefault": "Set as default",
  "equipment_setDetail_setAsDefaultSnackbar": "\"{name}\" is now your default set",
  "@equipment_setDetail_setAsDefaultSnackbar": {
    "placeholders": { "name": { "type": "String" } }
  },
  "equipment_setDetail_geofencesTitle": "Geofences",
  "equipment_setDetail_noGeofences": "No geofences",
```

Run: `flutter gen-l10n`

- [ ] **Step 2: Write the failing detail test**

Create `test/features/equipment/presentation/pages/equipment_set_detail_default_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/equipment/presentation/pages/equipment_set_detail_page.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_set_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  EquipmentSet set({required bool isDefault}) => EquipmentSet(
        id: 's1',
        name: 'Cold Water',
        isDefault: isDefault,
        items: const [],
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );

  Future<void> pump(WidgetTester tester, {required bool isDefault}) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        equipmentSetProvider.overrideWith((ref, id) async => set(isDefault: isDefault)),
        equipmentSetGeofencesProvider.overrideWith((ref, id) async => []),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const EquipmentSetDetailPage(setId: 's1'),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the Default badge when the set is default', (tester) async {
    await pump(tester, isDefault: true);
    expect(find.text('Default'), findsOneWidget);
  });

  testWidgets('offers "Set as default" only when not already default',
      (tester) async {
    await pump(tester, isDefault: false);
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    expect(find.text('Set as default'), findsOneWidget);
  });
}
```

- [ ] **Step 3: Run it to verify it fails**

Run: `flutter test test/features/equipment/presentation/pages/equipment_set_detail_default_test.dart`
Expected: FAIL — no Default badge / menu item yet.

- [ ] **Step 4: Add the Default badge to list tiles**

In `equipment_set_list_content.dart`, inside `_buildSetsList`'s `ListTile`, replace `title: Text(set.name),` with a title Row that appends a Default chip:

```dart
                title: Row(
                  children: [
                    Flexible(child: Text(set.name)),
                    if (set.isDefault) ...[
                      const SizedBox(width: 8),
                      Chip(
                        label: Text(context.l10n.equipment_sets_defaultBadge),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                      ),
                    ],
                  ],
                ),
```

- [ ] **Step 5: Add the "Set as default" menu action + badge + geofences to the detail page**

In `equipment_set_detail_page.dart`, in the AppBar `PopupMenuButton.itemBuilder`, add a `setAsDefault` item before `delete` (only when not already default):

```dart
            itemBuilder: (context) => [
              if (!set.isDefault)
                PopupMenuItem(
                  value: 'setAsDefault',
                  child: ListTile(
                    leading: const Icon(Icons.star_outline),
                    title: Text(context.l10n.equipment_setDetail_setAsDefault),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: Text(
                    context.l10n.equipment_setDetail_deleteMenuItem,
                    style: const TextStyle(color: Colors.red),
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
```

In `_handleMenuAction`, add the `setAsDefault` branch before the `delete` branch:

```dart
    if (action == 'setAsDefault') {
      await ref
          .read(equipmentSetListNotifierProvider.notifier)
          .setAsDefault(setId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.equipment_setDetail_setAsDefaultSnackbar(set.name),
            ),
          ),
        );
      }
      return;
    }
```

In the header `Card` (inside the `Column` with the set name `Text(set.name, ...)`), add a Default chip right after the name when `set.isDefault`:

```dart
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  set.name,
                                  style:
                                      Theme.of(context).textTheme.titleLarge,
                                ),
                              ),
                              if (set.isDefault) ...[
                                const SizedBox(width: 8),
                                Chip(
                                  label: Text(
                                    context.l10n.equipment_sets_defaultBadge,
                                  ),
                                  visualDensity: VisualDensity.compact,
                                ),
                              ],
                            ],
                          ),
```

(Replace the existing bare `Text(set.name, style: ...titleLarge)` line in the header with the Row above.)

After the equipment items section (at the end of the detail `Column`), add a geofences section:

```dart
            const SizedBox(height: 24),
            Text(
              context.l10n.equipment_setDetail_geofencesTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Consumer(
              builder: (context, ref, _) {
                final fencesAsync =
                    ref.watch(equipmentSetGeofencesProvider(setId));
                return fencesAsync.maybeWhen(
                  data: (fences) => fences.isEmpty
                      ? Text(context.l10n.equipment_setDetail_noGeofences)
                      : Column(
                          children: [
                            for (final g in fences)
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.place_outlined),
                                title: Text(
                                  g.label ??
                                      context.l10n.equipment_geofenceEditor_title,
                                ),
                              ),
                          ],
                        ),
                  orElse: () => const SizedBox.shrink(),
                );
              },
            ),
```

Add any missing imports (`Consumer` comes from the Riverpod barrel already imported via `core/providers/provider.dart`).

- [ ] **Step 6: Run the test + analyze + format**

Run: `flutter test test/features/equipment/presentation/pages/equipment_set_detail_default_test.dart`
Expected: PASS (both tests).
Run: `flutter analyze lib/features/equipment`
Expected: No issues.
Run: `dart format lib/features/equipment test/features/equipment`
Expected: no changes.

- [ ] **Step 7: Commit**

```bash
git add lib/features/equipment/presentation/widgets/equipment_set_list_content.dart lib/features/equipment/presentation/pages/equipment_set_detail_page.dart lib/l10n/arb/app_en.arb lib/l10n/arb/app_localizations*.dart test/features/equipment/presentation/pages/equipment_set_detail_default_test.dart
git commit -m "feat(equipment): default badge + set-as-default action + geofence list (#583)"
```

---

## Task 13: Localize all locales + final verification

**Files:**
- Modify: `lib/l10n/arb/app_ar.arb`, `app_de.arb`, `app_es.arb`, `app_fr.arb`, `app_he.arb`, `app_hu.arb`, `app_it.arb`, `app_nl.arb`, `app_pt.arb`, `app_zh.arb`

**Interfaces:**
- Consumes: the English keys added in Tasks 10-12.

The complete set of new keys (with English source text):

| Key | English |
| --- | --- |
| `diveLog_edit_geofenceSuggestion_near` | "Near {location}" |
| `diveLog_edit_geofenceSuggestion_title` | "Equipment suggestion" |
| `diveLog_edit_geofenceSuggestion_body` | "Apply your \"{setName}\" set?" |
| `diveLog_edit_geofenceSuggestion_apply` | "Apply" |
| `common_action_dismiss` | "Dismiss" |
| `equipment_setEdit_defaultSwitch_title` | "Default set" |
| `equipment_setEdit_defaultSwitch_subtitle` | "Auto-applied to new dives that have no equipment yet" |
| `equipment_setEdit_geofencesTitle` | "Geofences" |
| `equipment_setEdit_geofencesSubtitle` | "Auto-suggest this set for dives near these locations" |
| `equipment_setEdit_addGeofence` | "Add geofence" |
| `equipment_setEdit_geofenceRadius` | "Radius: {distance}" |
| `equipment_geofenceEditor_title` | "Geofence" |
| `equipment_geofenceEditor_fromSite` | "From dive site" |
| `equipment_geofenceEditor_dropPin` | "Drop a pin" |
| `equipment_geofenceEditor_labelLabel` | "Label" |
| `equipment_geofenceEditor_noCenter` | "Choose a center point" |
| `equipment_geofenceEditor_save` | "Save geofence" |
| `equipment_sets_defaultBadge` | "Default" |
| `equipment_setDetail_setAsDefault` | "Set as default" |
| `equipment_setDetail_setAsDefaultSnackbar` | "\"{name}\" is now your default set" |
| `equipment_setDetail_geofencesTitle` | "Geofences" |
| `equipment_setDetail_noGeofences` | "No geofences" |

- [ ] **Step 1: Add every key to all 10 non-English arb files**

For each of the 10 locale files, add all 22 keys with the locale's translation. Match the existing style of each file (placeholder `@`-metadata blocks are only required in the template `app_en.arb`; locale files carry just the translated key/value pairs, keeping `{location}`, `{setName}`, `{distance}`, `{name}` placeholders intact).

> Translation: use the project's established translation workflow to produce native strings for each locale. If native translations are not available in this session, add the keys with the English source text as an interim value (`flutter gen-l10n` falls back to English for any key missing from a locale, so functionality is unaffected) and flag these keys for a follow-up translation pass. Do NOT invent low-confidence translations.

- [ ] **Step 2: Regenerate localizations**

Run: `flutter gen-l10n`
Expected: no errors; every locale class compiles.

- [ ] **Step 3: Full verification pass**

Run: `dart format .`
Expected: no changes (all code already formatted).
Run: `flutter analyze`
Expected: No issues found.
Run: `flutter test`
Expected: All tests pass.

- [ ] **Step 4: Commit**

```bash
git add lib/l10n/arb/
git commit -m "feat(l10n): translations for default + geofenced equipment sets (#583)"
```

---

## Manual verification (device / macOS smoke)

After all tasks, verify on macOS (`flutter run -d macos`):
1. Equipment set editor: toggle **Default set**, add a geofence via "Drop a pin" (map) and via "From dive site", confirm radius shows in your unit; save.
2. Equipment set list/detail: the default set shows a **Default** badge; "Set as default" moves it.
3. New manual dive with no gear: the default set's equipment auto-populates.
4. Pick a site inside a geofence on a dive that already has (different) gear: the **suggestion banner** appears; Apply merges, Dismiss hides it for the session.
5. Sync round-trip across two profiles/devices (if available): default flag + geofences propagate.

The dive-computer download and file-import seams (Tasks 8-9) require real hardware / import files and are covered by unit tests plus this smoke.
