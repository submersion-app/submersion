/// Tags and dive types, with the dive type seeds.
library;

// Table classes are pure drift DSL. build_runner reads the column
// getter bodies to generate the `$<Table>Table` subclasses, whose
// fields override the getters, so the bodies never run and no test
// can cover them.
// coverage:ignore-file

import 'package:drift/drift.dart';

import 'package:submersion/core/database/tables/dive_tables.dart';
import 'package:submersion/core/database/tables/diver_tables.dart';

/// Tags for organizing dives (v1.5)
class Tags extends Table {
  TextColumn get id => text()();
  TextColumn get diverId => text().nullable().references(Divers, #id)();
  TextColumn get name => text()();
  TextColumn get color => text().nullable()(); // Hex color code for UI
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution
  /// (nullable: rows written before HLC rollout fall back to updatedAt).
  TextColumn get hlc => text().nullable()();

  /// Whether the tag is offered on dives (v217, issue #1765). Every tag that
  /// existed before v217 is a dive tag.
  BoolColumn get appliesToDives =>
      boolean().withDefault(const Constant(true))();

  /// Whether the tag is offered on dive sites (v217, issue #1765). A tag
  /// always applies to at least one scope; TagRepository enforces it.
  BoolColumn get appliesToSites =>
      boolean().withDefault(const Constant(false))();

  /// Whether the tag is offered on equipment (v219, issue #1942). No tag
  /// that existed before v219 is an equipment tag.
  BoolColumn get appliesToEquipment =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Custom dive types (v1.0)
class DiveTypes extends Table {
  TextColumn get id => text()(); // Unique identifier (slug)
  TextColumn get diverId =>
      text().nullable().references(Divers, #id)(); // null for built-in types
  TextColumn get name => text()(); // Display name
  BoolColumn get isBuiltIn =>
      boolean().withDefault(const Constant(false))(); // System vs user-defined
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution
  /// (nullable: rows written before HLC rollout fall back to updatedAt).
  TextColumn get hlc => text().nullable()();

  /// Abbreviated display form for a custom type (v173). Built-in types never
  /// set this -- they use the fixed translated abbreviation in
  /// builtInDiveTypeShortName instead. Null means the diver hasn't set one.
  TextColumn get shortName => text().nullable()();

  /// Whether this type's badge appears in the dive detail header's type-badge
  /// row (v174). Defaults to shown, so existing dives keep their current
  /// badges after the upgrade.
  BoolColumn get showInDetailHeader =>
      boolean().withDefault(const Constant(true))();

  /// Whether this type's badge appears in the dive list card's type-badge
  /// row (v174). Independent of [showInDetailHeader] -- a diver may want a
  /// type visible in the detail header but not cluttering every list row.
  BoolColumn get showInListView =>
      boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Junction table for dive tags (many-to-many)
class DiveTags extends Table {
  TextColumn get id => text()();
  TextColumn get diveId =>
      text().references(Dives, #id, onDelete: KeyAction.cascade)();
  TextColumn get tagId =>
      text().references(Tags, #id, onDelete: KeyAction.cascade)();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};

  /// v210: this child's own clock, stamped when it is marked pending. The
  /// merge refuses a remote copy strictly older than the local one, so a
  /// stale full row from a peer cannot overwrite a newer local edit
  /// (SyncDataSerializer.parentGatedChildEntities).
  TextColumn get hlc => text().nullable()();
}

/// Junction table for dive types (many-to-many).
///
/// Surrogate UUID primary key (never a composite key) so fresh-id reinserts
/// never collide with a replaced row's tombstone — this is how the junction
/// stays clear of the composite-key sync data-loss bug (#347).
class DiveDiveTypes extends Table {
  TextColumn get id => text()();
  TextColumn get diveId =>
      text().references(Dives, #id, onDelete: KeyAction.cascade)();
  TextColumn get diveTypeId => text()();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};

  /// v210: this child's own clock, stamped when it is marked pending. The
  /// merge refuses a remote copy strictly older than the local one, so a
  /// stale full row from a peer cannot overwrite a newer local edit
  /// (SyncDataSerializer.parentGatedChildEntities).
  TextColumn get hlc => text().nullable()();
}

/// Seeds one junction row per existing dive from its representative dive_type
/// slug. Used by the v92 migration and asserted directly in tests.
///
/// The `NOT EXISTS` guard makes a second run a no-op, which its sibling
/// [kSeedBuiltInDiveTypesSql] has always had via `INSERT OR IGNORE` on stable
/// slug ids. This one mints a RANDOM id per row, so it had nothing to conflict
/// with and a re-run simply doubled every dive's types -- issue #1360. Because
/// the sync merge keys junction rows on that id, each device's own seed pass
/// produced rows the fleet then unioned rather than deduplicated.
///
/// The guard is keyed on the dive having ANY junction row, not on the exact
/// pair: this seed's job is to give a dive its first type, so a dive that
/// already has one (a synced peer's, or a later edit) needs nothing.
const String kSeedDiveDiveTypesSql = '''
  INSERT INTO dive_dive_types (id, dive_id, dive_type_id, created_at)
  SELECT
    lower(hex(randomblob(16))),
    id,
    COALESCE(NULLIF(dive_type, ''), 'recreational'),
    CAST(strftime('%s','now') AS INTEGER) * 1000
  FROM dives
  WHERE NOT EXISTS (
    SELECT 1 FROM dive_dive_types j WHERE j.dive_id = dives.id
  )
''';

/// Seeds the built-in dive types. Used by BOTH [onCreate] (fresh installs) and
/// the v93 migration (backfill for upgraded databases). The full built-in set
/// was historically seeded only in onCreate, so every database that reached the
/// app via migration kept an EMPTY `dive_types` table -- harmless until the
/// multi-select dive-type picker (#414) read it and showed no options.
///
/// `INSERT OR IGNORE` keyed on the stable slug ids preserves any rows already
/// present (synced custom types, or 'cavern' added by the v88 migration) and
/// makes re-running the seed a no-op. Keep this list in sync with the
/// onboarding documentation; it is asserted directly in tests.
///
/// The timestamp is computed once (the trailing `CROSS JOIN`) and reused for
/// both `created_at` and `updated_at`, so the two can never diverge across a
/// `strftime('now')` second boundary.
const String kSeedBuiltInDiveTypesSql = '''
  INSERT OR IGNORE INTO dive_types
    (id, name, is_built_in, sort_order, created_at, updated_at)
  SELECT t.id, t.name, 1, t.sort_order, n.now_ms, n.now_ms
  FROM (
    SELECT 'recreational' AS id, 'Recreational' AS name, 0 AS sort_order
    UNION ALL SELECT 'technical', 'Technical', 1
    UNION ALL SELECT 'freedive', 'Freedive', 2
    UNION ALL SELECT 'training', 'Training', 3
    UNION ALL SELECT 'wreck', 'Wreck', 4
    UNION ALL SELECT 'cave', 'Cave', 5
    UNION ALL SELECT 'ice', 'Ice', 6
    UNION ALL SELECT 'night', 'Night', 7
    UNION ALL SELECT 'drift', 'Drift', 8
    UNION ALL SELECT 'deep', 'Deep', 9
    UNION ALL SELECT 'altitude', 'Altitude', 10
    UNION ALL SELECT 'shore', 'Shore', 11
    UNION ALL SELECT 'boat', 'Boat', 12
    UNION ALL SELECT 'liveaboard', 'Liveaboard', 13
    UNION ALL SELECT 'cavern', 'Cavern', 14
  ) t
  CROSS JOIN (SELECT CAST(strftime('%s','now') AS INTEGER) * 1000 AS now_ms) n
''';
