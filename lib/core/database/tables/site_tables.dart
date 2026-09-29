/// Dive sites, their classification, and dive centers.
library;

// Table classes are pure drift DSL. build_runner reads the column
// getter bodies to generate the `$<Table>Table` subclasses, whose
// fields override the getters, so the bodies never run and no test
// can cover them.
// coverage:ignore-file

import 'package:drift/drift.dart';

import 'package:submersion/core/database/tables/dive_tables.dart';
import 'package:submersion/core/database/tables/diver_tables.dart';
import 'package:submersion/core/database/tables/marine_life_tables.dart';
import 'package:submersion/core/database/tables/tag_tables.dart';

/// Dive sites/locations
class DiveSites extends Table {
  TextColumn get id => text()();
  TextColumn get diverId => text().nullable().references(Divers, #id)();
  TextColumn get name => text()();
  TextColumn get description => text().withDefault(const Constant(''))();
  RealColumn get latitude => real().nullable()();
  RealColumn get longitude => real().nullable()();
  RealColumn get minDepth => real().nullable()(); // Shallowest point
  RealColumn get maxDepth => real().nullable()(); // Deepest point
  TextColumn get difficulty =>
      text().nullable()(); // Beginner, Intermediate, Advanced, Technical
  // MacDive site metadata
  TextColumn get waterType => text().nullable()();
  TextColumn get bodyOfWater => text().nullable()();
  // Location hierarchy
  TextColumn get city => text().nullable()();
  TextColumn get island => text().nullable()();
  TextColumn get country => text().nullable()();
  TextColumn get region => text().nullable()();
  RealColumn get rating => real().nullable()();
  TextColumn get notes => text().withDefault(const Constant(''))();
  TextColumn get hazards =>
      text().nullable()(); // Currents, boats, marine life, etc.
  TextColumn get accessNotes =>
      text().nullable()(); // How to get there, entry points
  TextColumn get mooringNumber =>
      text().nullable()(); // Mooring buoy number for boats
  TextColumn get parkingInfo =>
      text().nullable()(); // Parking availability and tips
  RealColumn get altitude => real()
      .nullable()(); // Altitude above sea level in meters (for altitude diving)
  /// Typical entry and exit method at this site, stored as EntryMethod.name
  /// (issue #1104). Snapped onto a dive when the site is assigned.
  TextColumn get entryMethod => text().nullable()();
  TextColumn get exitMethod => text().nullable()();
  BoolColumn get isShared => boolean().withDefault(const Constant(false))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution
  /// (nullable: rows written before HLC rollout fall back to updatedAt).
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Rental gear memory (v221, issue #2075): what a diver learned about a dive
/// center's rental gear, kept per center so it surfaces on a return visit.
/// The note is the diver's judgement; the numbers of the last dive at the
/// center (lead, feedback, tanks) are read off that dive, never copied here.
@DataClassName('DiveCenterGearNoteRow')
class DiveCenterGearNotes extends Table {
  TextColumn get id => text()();
  TextColumn get diveCenterId =>
      text().references(DiveCenters, #id, onDelete: KeyAction.cascade)();

  /// EquipmentType.name of the rental item.
  TextColumn get gearType => text()();

  /// The operator's mark for the item: "14", "AL80".
  TextColumn get label => text().nullable()();
  TextColumn get size => text().nullable()();

  /// RentalVerdict.name: worked or avoid.
  TextColumn get verdict => text()();

  /// Signed kg: lead needed beyond the diver's usual with this gear.
  RealColumn get leadAdjustmentKg => real().nullable()();

  /// The cylinder's true capacity, for tank notes.
  RealColumn get volumeLiters => real().nullable()();
  TextColumn get note => text().withDefault(const Constant(''))();

  /// The dive the note was written on, if any; the note outlives it.
  TextColumn get diveId =>
      text().nullable().references(Dives, #id, onDelete: KeyAction.setNull)();
  IntColumn get notedAt => integer()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};

  /// This child's own clock, stamped when it is marked pending, so the merge
  /// refuses a remote copy strictly older than the local one
  /// (SyncDataSerializer.parentGatedChildEntities).
  TextColumn get hlc => text().nullable()();
}

/// Dive centers/operators
class DiveCenters extends Table {
  TextColumn get id => text()();
  TextColumn get diverId => text().nullable().references(Divers, #id)();
  TextColumn get name => text()();
  TextColumn get street => text().nullable()(); // Street address
  TextColumn get city => text().nullable()();
  TextColumn get stateProvince =>
      text().nullable()(); // State, province, or region
  TextColumn get postalCode => text().nullable()();
  RealColumn get latitude => real().nullable()();
  RealColumn get longitude => real().nullable()();
  TextColumn get country => text().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get website => text().nullable()();
  TextColumn get affiliations =>
      text().nullable()(); // PADI, SSI, etc. comma-separated
  RealColumn get rating => real().nullable()();
  TextColumn get notes => text().withDefault(const Constant(''))();

  /// v249: fill hours for the trip fill forecast, minutes after local
  /// midnight; null when unknown.
  IntColumn get fillOpensAt => integer().nullable()();
  IntColumn get fillClosesAt => integer().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution
  /// (nullable: rows written before HLC rollout fall back to updatedAt).
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Dive site type vocabulary (v217, issue #1765). The twin of [DiveTypes]:
/// slug ids, built-ins (diverId null) seeded identically on every device by
/// `kSeedBuiltInSiteTypesSql` and never synced, custom types per diver.
class SiteTypes extends Table {
  TextColumn get id => text()(); // Unique identifier (slug)
  TextColumn get diverId =>
      text().nullable().references(Divers, #id)(); // null for built-ins
  TextColumn get name => text()();
  BoolColumn get isBuiltIn => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution.
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Junction table for a site's types (many-to-many, v217). Surrogate uuid
/// primary key, as [DiveDiveTypes]. `siteTypeId` has no foreign key for the
/// same reason as `DiveDiveTypes.diveTypeId`: a custom type can arrive by
/// sync after a junction row that references it.
class SiteSiteTypes extends Table {
  TextColumn get id => text()();
  TextColumn get siteId =>
      text().references(DiveSites, #id, onDelete: KeyAction.cascade)();
  TextColumn get siteTypeId => text()();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};

  /// This child's own clock, stamped when it is marked pending
  /// (SyncDataSerializer.parentGatedChildEntities).
  TextColumn get hlc => text().nullable()();
}

/// Junction table for a site's tags (many-to-many, v217), the twin of
/// [DiveTags].
class SiteTags extends Table {
  TextColumn get id => text()();
  TextColumn get siteId =>
      text().references(DiveSites, #id, onDelete: KeyAction.cascade)();
  TextColumn get tagId =>
      text().references(Tags, #id, onDelete: KeyAction.cascade)();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};

  /// This child's own clock, stamped when it is marked pending
  /// (SyncDataSerializer.parentGatedChildEntities).
  TextColumn get hlc => text().nullable()();
}

/// Junction table for expected species at dive sites (manual curation)
class SiteSpecies extends Table {
  TextColumn get id => text()();
  TextColumn get siteId =>
      text().references(DiveSites, #id, onDelete: KeyAction.cascade)();
  TextColumn get speciesId =>
      text().references(Species, #id, onDelete: KeyAction.cascade)();
  TextColumn get notes => text().withDefault(const Constant(''))();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};

  /// v210: this child's own clock, stamped when it is marked pending. The
  /// merge refuses a remote copy strictly older than the local one, so a
  /// stale full row from a peer cannot overwrite a newer local edit
  /// (SyncDataSerializer.parentGatedChildEntities).
  TextColumn get hlc => text().nullable()();
}

/// Diver-placed annotations on a dive site (slice 2 of the seascape
/// usefulness program): wrecks, moorings, entry/exit points,
/// swim-throughs, hazards, and typical-current arrows. Points only;
/// optional bearing (current direction, wreck orientation) and optional
/// depth (meters). Mutable LWW entity: carries its own hlc.
class SiteFeatures extends Table {
  TextColumn get id => text()();
  TextColumn get siteId =>
      text().references(DiveSites, #id, onDelete: KeyAction.cascade)();

  /// SiteFeatureType enum name. Plain text so rows from a newer build
  /// with unknown types survive; the UI renders a generic marker.
  TextColumn get type => text()();
  TextColumn get name => text().withDefault(const Constant(''))();
  RealColumn get latitude => real()();
  RealColumn get longitude => real()();

  /// 0-359 compass degrees; current direction or wreck orientation.
  RealColumn get bearingDeg => real().nullable()();

  /// Stored meters; displayed in the diver's unit.
  RealColumn get depthMeters => real().nullable()();
  TextColumn get notes => text().withDefault(const Constant(''))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution
  /// (nullable: rows written before HLC rollout fall back to updatedAt).
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
