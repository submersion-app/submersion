import 'package:drift/drift.dart';

/// Each dive's vertical distance worked out from its profile (issue #4569),
/// so the Insights card decodes only new or changed profiles.
///
/// Local-only by construction: every device can work it out again from the
/// profiles it already holds, so it carries no HLC, is never synced and is
/// never backed up.
class DiveVerticalDistanceCache extends Table {
  @override
  String get tableName => 'dive_vertical_distance_cache';

  TextColumn get diveId => text()();

  /// Metres travelled down, from the profile alone. The floor at the dive's
  /// max depth is applied when read, so a max depth edit needs no refresh.
  RealColumn get meters => real()();

  /// Algorithm version and a fingerprint of the dive's primary series rows.
  /// A mismatch means recompute.
  TextColumn get inputsHash => text()();

  IntColumn get computedAt => integer()();

  @override
  Set<Column> get primaryKey => {diveId};
}

/// The table as [DiveVerticalDistanceCache] declares it, for the open
/// backstop that heals a database a colliding branch stamped at v23 first.
/// Keep the columns in step with the class.
const String kCreateDiveVerticalDistanceCacheSql = '''
  CREATE TABLE IF NOT EXISTS dive_vertical_distance_cache (
    dive_id TEXT NOT NULL,
    meters REAL NOT NULL,
    inputs_hash TEXT NOT NULL,
    computed_at INTEGER NOT NULL,
    PRIMARY KEY (dive_id)
  )
''';
