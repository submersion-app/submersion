import 'package:equatable/equatable.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    show TankPressurePoint;
import 'package:submersion/features/dive_log/domain/entities/profile_series.dart';
import 'package:submersion/features/dive_log/domain/services/profile_series_merge.dart';

/// One dive's tank pressure series as the UDDF exporter needs them.
///
/// A backup has to say which source recorded each series (issue #2492):
/// written as one merged list per tank, a restore filed every source's
/// readings of a cylinder under one series and interleaved them again,
/// the zigzag #2440 fixes at the source. So this carries every stored
/// series with its [TankPressureSeries.sourceId], plus the dive's
/// [primarySourceId], which [displayedByTank] needs to draw what the app
/// draws.
class DiveTankPressureExport extends Equatable {
  const DiveTankPressureExport({required this.series, this.primarySourceId});

  /// Every series of the dive, of every source, in the order the
  /// repository returns them. A backup drops none of them.
  final List<TankPressureSeries> series;

  /// The dive's primary data source, or null when it has none.
  final String? primarySourceId;

  /// Per tank, the readings the app draws: one source for each stretch of
  /// the tank, preferring the primary one (see [selectTankSeriesPerSource]).
  ///
  /// This is what the standard `<tankpressure>` samples carry, so another
  /// application reading the file sees one curve per cylinder rather than
  /// two recordings interleaved. The rest travel in Submersion's own
  /// extension block.
  Map<String, List<TankPressurePoint>> get displayedByTank {
    final byTank = <String, List<TankPressureSeries>>{};
    for (final s in selectTankSeriesPerSource(
      series,
      preferredSourceId: primarySourceId,
    )) {
      byTank.putIfAbsent(s.tankId, () => []).add(s);
    }
    return {
      for (final entry in byTank.entries)
        entry.key: mergeTankSeriesPoints(entry.value),
    };
  }

  @override
  List<Object?> get props => [series, primarySourceId];
}
