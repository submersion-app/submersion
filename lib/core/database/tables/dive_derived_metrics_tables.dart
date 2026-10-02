/// The Explore derived metrics (issue #2195, phase 2).
library;

// Table classes are pure drift DSL: the generated code is what runs.
// coverage:ignore-file

import 'package:drift/drift.dart';
import 'package:submersion/core/database/tables/dive_tables.dart';

/// What only a profile decode can answer about a dive, computed once per
/// dive version by `DerivedMetricsService` and read by the dive query
/// fields (`sacTrend`, `sacChange`, `finalStop`, `finalStopExcursion`,
/// `finalStopDuration`). Device-local: no hlc column, so sync never reads or
/// writes it; a restore or a synced pull rebuilds it by sweep.
///
/// Named `...Rows` because `DiveDerivedMetrics` is the domain value type.
@DataClassName('DiveDerivedMetricsRow')
class DiveDerivedMetricsRows extends Table {
  @override
  String get tableName => 'dive_derived_metrics';

  TextColumn get diveId =>
      text().references(Dives, #id, onDelete: KeyAction.cascade)();
  IntColumn get engineVersion => integer()();

  /// The dive's `updated_at` this row was built from; a mismatch is stale.
  IntColumn get sourceUpdatedAt => integer()();
  IntColumn get computedAt => integer()();

  /// `FinalStopKind.name`, defaulting to none so a row always classifies.
  TextColumn get finalStopKind => text().withDefault(const Constant('none'))();

  /// `FinalStopState.name`; null when the profile could not be judged.
  TextColumn get finalStopState => text().nullable()();
  IntColumn get finalStopStartS => integer().nullable()();
  IntColumn get finalStopDurationS => integer().nullable()();
  RealColumn get finalStopDepthStddevM => real().nullable()();

  /// How far the diver strayed from the stop's mean depth, in metres: the
  /// 90th percentile of the samples, not the single worst one, so a sample
  /// passing through is not counted as straying.
  RealColumn get finalStopMaxExcursionM => real().nullable()();

  /// Bar per minute at surface pressure.
  RealColumn get sacMeanBarMin => real().nullable()();
  RealColumn get sacSlopeBarMinPerMin => real().nullable()();

  /// `SacTrend.name`; null when no slope could be computed.
  TextColumn get sacTrend => text().nullable()();

  /// Percent change of mean SAC from the dive's first half to its second.
  RealColumn get sacChangePct => real().nullable()();
  IntColumn get runtimeS => integer().nullable()();

  /// `UnsupportedReason.name` when a metric could not be derived.
  TextColumn get unsupportedReason => text().nullable()();

  @override
  Set<Column> get primaryKey => {diveId};
}
