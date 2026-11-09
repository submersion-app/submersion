/// Readings from Apple Health on a dive (issue #637).
library;

// Table classes are pure drift DSL. build_runner reads the column
// getter bodies to generate the `$<Table>Table` subclasses, whose
// fields override the getters, so the bodies never run and no test
// can cover them.
// coverage:ignore-file

import 'package:drift/drift.dart';

import 'package:submersion/core/database/tables/dive_tables.dart';

/// Heart rate, recovery and sleep from Apple Health for one dive: what the
/// watch read during the dive, how the heart rate fell after it, the night's
/// heart rate variability and the sleep before it. Kept apart from the
/// profile, since the chart draws heart rate only from the main profile and
/// a second series would add zero-depth samples to the merged profile; the
/// detail page merges it in when the profile has none. Synced like the
/// dive's tide record.
class DiveHealthRecords extends Table {
  TextColumn get id => text()();
  TextColumn get diveId =>
      text().references(Dives, #id, onDelete: KeyAction.cascade)();

  /// JSON `[[offsetSeconds, bpm], ...]` from the dive's entry.
  TextColumn get heartRateSamples => text().nullable()();
  IntColumn get avgHeartRate => integer().nullable()();
  IntColumn get maxHeartRate => integer().nullable()();

  /// Recovery: the heart rate at the exit, and five and fifteen minutes on.
  IntColumn get heartRateAtExit => integer().nullable()();
  IntColumn get heartRateExitPlus5 => integer().nullable()();
  IntColumn get heartRateExitPlus15 => integer().nullable()();

  /// The night before the dive: mean heart rate variability (SDNN, ms) and
  /// minutes asleep.
  RealColumn get overnightHrvMs => real().nullable()();
  IntColumn get sleepBeforeMinutes => integer().nullable()();

  /// True once every reading the dive can have is in (the recovery window
  /// has passed), so no later refresh asks Health again.
  BoolColumn get settled => boolean().withDefault(const Constant(false))();
  IntColumn get fetchedAt => integer()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};

  /// This child's own clock, stamped when it is marked pending, as a tide
  /// record's is.
  TextColumn get hlc => text().nullable()();
}
