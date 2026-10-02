/// GPS surface tracks and measured underwater routes.
library;

// Table classes are pure drift DSL. build_runner reads the column
// getter bodies to generate the `$<Table>Table` subclasses, whose
// fields override the getters, so the bodies never run and no test
// can cover them.
// coverage:ignore-file

import 'package:drift/drift.dart';

import 'package:submersion/core/database/tables/dive_tables.dart';
import 'package:submersion/core/database/tables/diver_tables.dart';
import 'package:submersion/core/database/tables/equipment_tables.dart';
import 'package:submersion/core/database/tables/site_tables.dart';

/// GPS surface tracks recorded by the phone during a dive day (spec
/// 2026-07-06-gps-track-logging). One row per recording session; points
/// live in a gzipped JSON blob because matching always reads whole tracks
/// and blob-per-session keeps sync to one HLC row per boat day.
@DataClassName('GpsTrackRow')
class GpsTracks extends Table {
  // coverage:ignore-start
  TextColumn get id => text()();

  /// Wall-clock-as-UTC epoch milliseconds (same convention as dives.entryTime)
  IntColumn get startTime => integer()();
  IntColumn get endTime => integer().nullable()();

  /// Device UTC offset at recording start, to reconstruct true UTC later
  IntColumn get tzOffsetMinutes => integer().withDefault(const Constant(0))();
  TextColumn get deviceName => text().nullable()();
  IntColumn get pointCount => integer().withDefault(const Constant(0))();

  /// Provenance: 'phone' | 'gpx' | 'fit' | 'kml' | 'csv'. Rendering code
  /// treats this as opaque -- no view logic branches on it.
  TextColumn get source => text().withDefault(const Constant('phone'))();

  /// Originating filename or device, for imported tracks.
  TextColumn get sourceRef => text().nullable()();

  /// User-editable label.
  TextColumn get name => text().nullable()();

  /// Non-destructive trim bounds, wall-clock-as-UTC epoch MILLISECONDS.
  /// The points blob is never rewritten by a trim, so trimming is fully
  /// reversible and cannot lose a fix.
  IntColumn get trimStartTime => integer().nullable()();
  IntColumn get trimEndTime => integer().nullable()();

  /// Gzipped JSON array of [wallClockEpochSeconds, lat, lon, accuracyMeters]
  BlobColumn get points => blob().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
  // coverage:ignore-end
}

/// Local-only append buffer for the in-progress GPS recording session.
/// Never synced (no hlc). Finalized into gps_tracks.points on stop or
/// crash recovery.
@DataClassName('GpsTrackPointRow')
class GpsTrackPointsLocal extends Table {
  // coverage:ignore-start
  IntColumn get rowId => integer().autoIncrement()();
  TextColumn get trackId => text()();

  /// Wall-clock-as-UTC epoch seconds
  IntColumn get timestamp => integer()();
  RealColumn get latitude => real()();
  RealColumn get longitude => real()();
  RealColumn get accuracy => real().nullable()();
  // coverage:ignore-end
}

/// Measured underwater routes from navigation consoles and IMU-equipped
/// dive computers (spec 2026-09-10-underwater-nav-track-design.md, issues
/// #1195 and #1445). One row per recording; points live in a gzipped JSON
/// blob like gps_tracks so sync moves one HLC row per route. The blob is
/// the recording as it came off the device and is never rewritten; every
/// correction column below is a non-destructive parameter applied on read.
@DataClassName('NavTrackRow')
class NavTracks extends Table {
  // coverage:ignore-start
  TextColumn get id => text()();

  /// The dive this route belongs to, or null while unlinked. SET NULL on
  /// dive deletion: the recording outlives the dive and shows as unlinked
  /// in the routes area, ready to be matched again.
  TextColumn get diveId =>
      text().nullable().references(Dives, #id, onDelete: KeyAction.setNull)();

  /// The diver this route belongs to (v252). Stamped with the active diver
  /// at import and moved to the dive's diver whenever the route is linked,
  /// so a linked route's owner always matches its dive. Null is a route
  /// with no owner (imported before v252 and never linked, or with no
  /// diver profile): every diver sees it, the house meaning of an ownerless
  /// row. No ON DELETE action: deleting a diver deletes and tombstones
  /// their routes (`diver_owned_rows.dart`), so a peer never shows them to
  /// everyone after its FK repair nulls the owner.
  TextColumn get diverId => text().nullable().references(Divers, #id)();

  /// 'auto' when the match sweep linked it, 'manual' when the diver did.
  /// The sweep never touches a linked row of either kind; the flag exists
  /// so the UI can say how the link came about.
  TextColumn get linkMode => text().nullable()();

  /// The route the dive's 3D seascape draws when several are linked to the
  /// same dive (two devices on one dive). The first link sets it.
  BoolColumn get isPrimary => boolean().withDefault(const Constant(true))();

  /// The dive site chosen at import (or taken from the linked dive): gives
  /// an unlinked route a map position to start from, the default anchor
  /// until the diver corrects it.
  TextColumn get siteId => text().nullable().references(
    DiveSites,
    #id,
    onDelete: KeyAction.setNull,
  )();

  /// 'seacraft_enc' | 'suunto_route'. Rendering never branches on it; only
  /// the caption and the parser registry do.
  TextColumn get source => text()();
  TextColumn get sourceRef => text().nullable()(); // originating file name
  TextColumn get deviceName => text().nullable()();

  /// User-editable label; defaults to the file name.
  TextColumn get name => text().nullable()();

  /// Optional link to the console or scooter in the equipment list.
  TextColumn get equipmentId => text().nullable().references(
    Equipment,
    #id,
    onDelete: KeyAction.setNull,
  )();

  /// Wall-clock-as-UTC epoch milliseconds (dives.entryTime convention).
  IntColumn get startTime => integer()();
  IntColumn get endTime => integer()();
  IntColumn get tzOffsetMinutes => integer().withDefault(const Constant(0))();

  /// Seconds added to the device's clock to place it on the linked dive's
  /// timeline (same idea as dive_data_sources.time_offset_seconds).
  IntColumn get timeOffsetSeconds => integer().withDefault(const Constant(0))();
  IntColumn get pointCount => integer()();

  /// Summary scalars for list rows and stats, so no blob decode is needed.
  RealColumn get totalDistance => real().nullable()(); // m, device log
  RealColumn get maxDepth => real().nullable()(); // m
  RealColumn get maxSpeed => real().nullable()(); // m/s
  RealColumn get avgSpeed => real().nullable()(); // m/s

  /// Seconds from the first to the last dead-reckoned sample (the active
  /// range), excluding a post-surfacing GPS tail that start/end_time keep
  /// for time matching. Null on rows written before it was stored.
  IntColumn get durationSeconds => integer().nullable()();

  /// Where the route's origin sits on the map. Null until the diver sets
  /// it (or accepts a suggestion); the route then has no 2D position.
  RealColumn get anchorLatitude => real().nullable()();
  RealColumn get anchorLongitude => real().nullable()();

  /// 'none' | 'same_as_start' | 'point' | 'gps_fix'. With 'point',
  /// endLatitude/endLongitude hold the target. 'same_as_start' follows the
  /// anchor when it moves, which a copied coordinate would not.
  TextColumn get endMode => text().withDefault(const Constant('none'))();
  RealColumn get endLatitude => real().nullable()();
  RealColumn get endLongitude => real().nullable()();

  /// Trust mark: fraction of the route's cumulative distance, 0 to 1, up
  /// to which the recording is taken as correct. 0 (default) means the
  /// whole route is corrected proportionally; 1 disables the correction.
  RealColumn get trustFraction => real().withDefault(const Constant(0))();

  /// Clockwise rotation applied to the route (magnetic declination, mount
  /// misalignment).
  RealColumn get headingOffsetDeg => real().withDefault(const Constant(0))();

  IntColumn get codecVersion => integer().withDefault(const Constant(1))();

  /// Gzipped JSON array of
  /// [wallClockEpochSeconds, north, east, depth, course, pitch, roll,
  ///  distance, speed, temp, battV]; null for channels a source lacks.
  BlobColumn get points => blob()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
  // coverage:ignore-end
}
