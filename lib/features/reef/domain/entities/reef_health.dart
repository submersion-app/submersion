import 'package:equatable/equatable.dart';

import 'package:submersion/features/reef/domain/services/bleaching_alert_level.dart';

/// Thermal-stress conditions at a reef on a given day.
///
/// Sourced from NOAA Coral Reef Watch (public domain). [degreeHeatingWeeks]
/// must always be displayed alongside [alertLevel]: the level is an
/// instantaneous classification while the damage it implies is cumulative, so
/// a reef mid-mortality can legitimately read "Bleaching Watch".
class ReefHealth extends Equatable {
  /// Sea surface temperature in Celsius. Convert for display.
  final double? sst;

  /// Difference from the daily climatology, in Celsius.
  final double? sstAnomaly;

  /// Difference from the maximum monthly mean, in Celsius.
  final double? hotspot;

  /// Accumulated thermal stress in Celsius-weeks. No imperial equivalent
  /// exists; display in Celsius-weeks in every locale.
  final double? degreeHeatingWeeks;

  final BleachingAlertLevel? alertLevel;

  /// The satellite observation date, which runs 1-5 days behind today.
  final DateTime observedAt;

  const ReefHealth({
    this.sst,
    this.sstAnomaly,
    this.hotspot,
    this.degreeHeatingWeeks,
    this.alertLevel,
    required this.observedAt,
  });

  ReefHealth copyWith({
    double? sst,
    double? sstAnomaly,
    double? hotspot,
    double? degreeHeatingWeeks,
    BleachingAlertLevel? alertLevel,
    DateTime? observedAt,
  }) => ReefHealth(
    sst: sst ?? this.sst,
    sstAnomaly: sstAnomaly ?? this.sstAnomaly,
    hotspot: hotspot ?? this.hotspot,
    degreeHeatingWeeks: degreeHeatingWeeks ?? this.degreeHeatingWeeks,
    alertLevel: alertLevel ?? this.alertLevel,
    observedAt: observedAt ?? this.observedAt,
  );

  Map<String, dynamic> toJson() => {
    'sst': sst,
    'sstAnomaly': sstAnomaly,
    'hotspot': hotspot,
    'degreeHeatingWeeks': degreeHeatingWeeks,
    'alertLevel': alertLevel?.name,
    'observedAt': observedAt.toUtc().toIso8601String(),
  };

  factory ReefHealth.fromJson(Map<String, dynamic> json) => ReefHealth(
    sst: (json['sst'] as num?)?.toDouble(),
    sstAnomaly: (json['sstAnomaly'] as num?)?.toDouble(),
    hotspot: (json['hotspot'] as num?)?.toDouble(),
    degreeHeatingWeeks: (json['degreeHeatingWeeks'] as num?)?.toDouble(),
    // An unrecognised value means the cached row is from a different build or
    // is corrupt. Falling back to noStress would render the safest-looking
    // badge over a reef whose real state is unknown, so treat it as absent.
    alertLevel: BleachingAlertLevel.values
        .cast<BleachingAlertLevel?>()
        .firstWhere((l) => l!.name == json['alertLevel'], orElse: () => null),
    observedAt: DateTime.parse(json['observedAt'] as String).toUtc(),
  );

  @override
  List<Object?> get props => [
    sst,
    sstAnomaly,
    hotspot,
    degreeHeatingWeeks,
    alertLevel,
    observedAt,
  ];
}
