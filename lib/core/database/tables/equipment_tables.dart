/// Equipment, equipment sets, sharing and the dive gear junction.
library;

// Table classes are pure drift DSL. build_runner reads the column
// getter bodies to generate the `$<Table>Table` subclasses, whose
// fields override the getters, so the bodies never run and no test
// can cover them.
// coverage:ignore-file

import 'package:drift/drift.dart';

import 'package:submersion/core/database/tables/dive_tables.dart';
import 'package:submersion/core/database/tables/diver_tables.dart';
import 'package:submersion/core/database/tables/tag_tables.dart';

/// Equipment catalog
class Equipment extends Table {
  TextColumn get id => text()();
  TextColumn get diverId => text().nullable().references(Divers, #id)();
  TextColumn get name => text()();
  TextColumn get type => text()(); // regulator, bcd, wetsuit, etc.
  TextColumn get brand => text().nullable()();
  TextColumn get model => text().nullable()();
  TextColumn get serialNumber => text().nullable()();
  TextColumn get size => text().nullable()(); // S, M, L, XL, or specific size
  TextColumn get thickness => text().nullable()(); // 2,3,4,5,6 or 6mm (v112)
  // Buoyancy metadata (v104): net in-water buoyancy in kg (positive floats),
  // and dry weight in kg (feeds displacement scaling).
  RealColumn get buoyancyKg => real().nullable()();
  RealColumn get weightKg => real().nullable()();
  TextColumn get status => text().withDefault(
    const Constant('active'),
  )(); // active, needsService, retired, etc.
  IntColumn get purchaseDate => integer().nullable()();
  RealColumn get purchasePrice => real().nullable()();
  TextColumn get purchaseCurrency =>
      text().withDefault(const Constant('USD'))();
  IntColumn get lastServiceDate => integer().nullable()();
  IntColumn get serviceIntervalDays => integer().nullable()();
  TextColumn get notes => text().withDefault(const Constant(''))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  // Notification overrides (v27)
  BoolColumn get customReminderEnabled => boolean()
      .nullable()(); // NULL = use global, true = custom, false = disabled
  TextColumn get customReminderDays =>
      text().nullable()(); // JSON array override, e.g. "[7, 30]"

  /// v202: the item this one is installed in (an O2 cell in a rebreather, a
  /// battery in a computer). A child inherits the parent's dive links from
  /// its `installed_date` attribute. Deleting the parent orphans the child
  /// rather than deleting its history.
  TextColumn get parentEquipmentId => text().nullable().references(
    Equipment,
    #id,
    onDelete: KeyAction.setNull,
  )();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution
  /// (nullable: rows written before HLC rollout fall back to updatedAt).
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Type-specific and user-defined attributes for equipment items (v124).
/// Curated rows (isCustom = false) use deterministic ids
/// `attr_<equipmentId>_<attrKey>` so independently migrated devices converge;
/// custom rows use random UUIDs. "Unset" is "no row" -- clearing a value
/// deletes the row and writes a tombstone.
@DataClassName('EquipmentAttributeRow')
class EquipmentAttributes extends Table {
  TextColumn get id => text()();
  TextColumn get equipmentId =>
      text().references(Equipment, #id, onDelete: KeyAction.cascade)();
  TextColumn get attrKey => text()();
  BoolColumn get isCustom => boolean().withDefault(const Constant(false))();
  TextColumn get valueText => text().nullable()();
  RealColumn get valueNum => real().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution.
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {equipmentId, attrKey, isCustom},
  ];
}

/// The assembly template (issue #1487): one row per part of a parent item.
/// A clocked child of equipment, shaped like [EquipmentAttributes], because
/// role and order are mutable payload that must merge on their own clock.
/// An item is an assembly when it has at least one row here; there is no
/// assembly type.
@DataClassName('EquipmentComponentRow')
class EquipmentComponents extends Table {
  TextColumn get id => text()();
  TextColumn get parentEquipmentId =>
      text().references(Equipment, #id, onDelete: KeyAction.cascade)();
  TextColumn get componentEquipmentId =>
      text().references(Equipment, #id, onDelete: KeyAction.cascade)();

  /// Free text such as "Primary second stage"; empty when unset.
  TextColumn get role => text().withDefault(const Constant(''))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution.
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {parentEquipmentId, componentEquipmentId},
  ];
}

/// Junction table for equipment used per dive
class DiveEquipment extends Table {
  TextColumn get diveId =>
      text().references(Dives, #id, onDelete: KeyAction.cascade)();
  TextColumn get equipmentId =>
      text().references(Equipment, #id, onDelete: KeyAction.cascade)();

  /// Provenance (issue #1487): the immediate parent assembly this row was
  /// attached through, null for a top-level row. SET NULL on delete so the
  /// part stays on the dive as flat gear when its assembly is deleted.
  TextColumn get viaEquipmentId => text().nullable().references(
    Equipment,
    #id,
    onDelete: KeyAction.setNull,
  )();

  /// The equipment set that was applied, carried by every row of the
  /// expanded subtree; null when the row was added by hand.
  TextColumn get viaSetId => text().nullable().references(
    EquipmentSets,
    #id,
    onDelete: KeyAction.setNull,
  )();

  /// When this link was last written, in Unix ms (issue #1728). NOT an LWW
  /// clock for the row's payload: the junction carries no hlc and rides its
  /// parent, and the merge still applies it as a clockless upsert. It exists
  /// so the merge has an age signal at all. Without one,
  /// `_extractUpdatedAtMillis` returns null, which collapses both guards in
  /// `SyncService._applyRemoteDeletions` to false (each is written
  /// `localUpdatedAt != null && ...`) and makes the revival branch in
  /// `_mergeEntity` unreachable, so a link lost anywhere is permanent.
  /// Nullable so a row from a pre-v207 peer still parses, and a
  /// `clientDefault` stamps every local insert so a future call site cannot
  /// silently reintroduce a clockless link.
  IntColumn get updatedAt => integer().nullable().clientDefault(
    () => DateTime.now().millisecondsSinceEpoch,
  )();

  @override
  Set<Column> get primaryKey => {diveId, equipmentId};

  /// v210: this child's own clock, stamped when it is marked pending. The
  /// merge refuses a remote copy strictly older than the local one, so a
  /// stale full row from a peer cannot overwrite a newer local edit
  /// (SyncDataSerializer.parentGatedChildEntities).
  TextColumn get hlc => text().nullable()();
}

/// Equipment sets (named collections of equipment items)
class EquipmentSets extends Table {
  TextColumn get id => text()();
  TextColumn get diverId => text().nullable().references(Divers, #id)();
  TextColumn get name => text()();
  TextColumn get description => text().withDefault(const Constant(''))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Whether this set is the diver's default (auto-applied to new dives with
  /// no equipment). Mutual exclusion is enforced per-diver at the repository
  /// layer, mirroring DiverRepository.setDefaultDiver.
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();

  /// Whether this set is auto-applied to a dive whose computer is a member
  /// of it (issue #1020), e.g. a CCR rig set that bundles the controller
  /// with drysuit and tec fins. Opt-in per set, off by default: unlike
  /// [isDefault] this has no diver-wide mutual exclusion, several sets can
  /// have it on at once.
  BoolColumn get autoApplyOnComputerImport =>
      boolean().withDefault(const Constant(false))();

  /// Whether the set page draws this set's gear on the diver figure
  /// (issue #2326, v229). Opt-in per set and off by default, including for
  /// every set that existed before the column.
  BoolColumn get showFigure => boolean().withDefault(const Constant(false))();

  /// Hybrid Logical Clock for cross-device conflict resolution
  /// (nullable: rows written before HLC rollout fall back to updatedAt).
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Junction table for equipment items in sets
class EquipmentSetItems extends Table {
  TextColumn get setId =>
      text().references(EquipmentSets, #id, onDelete: KeyAction.cascade)();
  TextColumn get equipmentId =>
      text().references(Equipment, #id, onDelete: KeyAction.cascade)();

  /// The sync merge's age signal for this link; see [DiveEquipment.updatedAt]
  /// for why the junctions need one (issue #1728).
  IntColumn get updatedAt => integer().nullable().clientDefault(
    () => DateTime.now().millisecondsSinceEpoch,
  )();

  @override
  Set<Column> get primaryKey => {setId, equipmentId};

  /// v210: this child's own clock, stamped when it is marked pending. The
  /// merge refuses a remote copy strictly older than the local one, so a
  /// stale full row from a peer cannot overwrite a newer local edit
  /// (SyncDataSerializer.parentGatedChildEntities).
  TextColumn get hlc => text().nullable()();
}

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

/// Junction table for an equipment item's tags (many-to-many, v219, issue
/// #1942), the twin of [SiteTags]. Surrogate uuid primary key, so a
/// re-inserted pair never collides with its predecessor's tombstone (#347);
/// the (equipment_id, tag_id) unique index lives in tag_uniqueness.dart.
class EquipmentTags extends Table {
  TextColumn get id => text()();
  TextColumn get equipmentId =>
      text().references(Equipment, #id, onDelete: KeyAction.cascade)();
  TextColumn get tagId =>
      text().references(Tags, #id, onDelete: KeyAction.cascade)();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};

  /// This child's own clock, stamped when it is marked pending
  /// (SyncDataSerializer.parentGatedChildEntities).
  TextColumn get hlc => text().nullable()();
}

/// Diver profiles an equipment item is shared with (v234, issue #2046). The
/// owner stays `equipment.diver_id`; a row here makes the item visible to
/// [diverId] too. Surrogate uuid primary key like [EquipmentTags]; the
/// (equipment_id, diver_id) unique index lives in
/// equipment_share_uniqueness.dart. The repository never writes a row that
/// names the item's own owner.
@DataClassName('EquipmentShareRow')
class EquipmentShares extends Table {
  TextColumn get id => text()();
  TextColumn get equipmentId =>
      text().references(Equipment, #id, onDelete: KeyAction.cascade)();
  TextColumn get diverId =>
      text().references(Divers, #id, onDelete: KeyAction.cascade)();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};

  /// This child's own clock, stamped when it is marked pending
  /// (SyncDataSerializer.parentGatedChildEntities).
  TextColumn get hlc => text().nullable()();
}

/// Append-only log of an item's share and ownership changes (v234, issue
/// #2046): `shared`, `unshared`, and `transferred` from the transfer work.
/// Diver references are SET NULL, so deleting a profile keeps the event,
/// read as "a deleted profile". No row is ever updated, except by a diver
/// merge repointing both sides to the surviving profile.
@DataClassName('EquipmentOwnershipEventRow')
class EquipmentOwnershipEvents extends Table {
  TextColumn get id => text()();
  TextColumn get equipmentId =>
      text().references(Equipment, #id, onDelete: KeyAction.cascade)();
  TextColumn get kind => text()();
  TextColumn get fromDiverId =>
      text().nullable().references(Divers, #id, onDelete: KeyAction.setNull)();
  TextColumn get toDiverId =>
      text().nullable().references(Divers, #id, onDelete: KeyAction.setNull)();
  IntColumn get occurredAt => integer()();

  @override
  Set<Column> get primaryKey => {id};

  /// This child's own clock, stamped when it is marked pending
  /// (SyncDataSerializer.parentGatedChildEntities).
  TextColumn get hlc => text().nullable()();
}
