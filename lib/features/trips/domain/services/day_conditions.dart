import 'package:equatable/equatable.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/domain/visibility/visibility_scale.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// The water a day's dives met: temperature, visibility and current, each as
/// the range across the dives that logged it.
///
/// Visibility comes in two shapes. Dives logged from v144 carry a measured
/// distance, which wins whenever any dive of the day has one. Older dives
/// carry only a coarse bucket, which can be shown only when every bucketed
/// dive agrees: two buckets have no honest range between them.
class DayConditions extends Equatable {
  final double? minWaterTemp; // celsius
  final double? maxWaterTemp; // celsius
  final double? minVisibilityMeters;
  final double? maxVisibilityMeters;
  final VisibilityBand? legacyVisibility;
  final CurrentStrength? minCurrent;
  final CurrentStrength? maxCurrent;

  const DayConditions({
    this.minWaterTemp,
    this.maxWaterTemp,
    this.minVisibilityMeters,
    this.maxVisibilityMeters,
    this.legacyVisibility,
    this.minCurrent,
    this.maxCurrent,
  });

  factory DayConditions.fromDives(Iterable<Dive> dives) {
    double? minTemp, maxTemp, minVis, maxVis;
    CurrentStrength? minCurrent, maxCurrent;
    final buckets = <VisibilityBand>{};
    for (final dive in dives) {
      final temp = dive.waterTemp;
      if (temp != null) {
        if (minTemp == null || temp < minTemp) minTemp = temp;
        if (maxTemp == null || temp > maxTemp) maxTemp = temp;
      }
      final vis = dive.visibilityMeters;
      if (vis != null) {
        if (minVis == null || vis < minVis) minVis = vis;
        if (maxVis == null || vis > maxVis) maxVis = vis;
      }
      final band = _legacyBand(dive.visibility);
      if (band != null) buckets.add(band);
      final current = dive.currentStrength;
      if (current != null) {
        if (minCurrent == null || current.index < minCurrent.index) {
          minCurrent = current;
        }
        if (maxCurrent == null || current.index > maxCurrent.index) {
          maxCurrent = current;
        }
      }
    }
    return DayConditions(
      minWaterTemp: minTemp,
      maxWaterTemp: maxTemp,
      minVisibilityMeters: minVis,
      maxVisibilityMeters: maxVis,
      legacyVisibility: minVis == null && buckets.length == 1
          ? buckets.single
          : null,
      minCurrent: minCurrent,
      maxCurrent: maxCurrent,
    );
  }

  bool get isEmpty =>
      minWaterTemp == null &&
      minVisibilityMeters == null &&
      legacyVisibility == null &&
      minCurrent == null;

  static VisibilityBand? _legacyBand(Visibility? visibility) =>
      switch (visibility) {
        Visibility.excellent => VisibilityBand.excellent,
        Visibility.good => VisibilityBand.good,
        Visibility.moderate => VisibilityBand.moderate,
        Visibility.poor => VisibilityBand.poor,
        Visibility.unknown || null => null,
      };

  @override
  List<Object?> get props => [
    minWaterTemp,
    maxWaterTemp,
    minVisibilityMeters,
    maxVisibilityMeters,
    legacyVisibility,
    minCurrent,
    maxCurrent,
  ];
}
