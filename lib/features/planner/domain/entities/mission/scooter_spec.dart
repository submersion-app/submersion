import 'package:equatable/equatable.dart';

/// Tower's speed while towing, as a fraction of the scooter's rated speed.
const double kDefaultTowSpeedFactor = 0.6;

/// Burn-rate multiplier while towing.
const double kDefaultTowBurnFactor = 1.5;

/// The numbers a mission needs from a scooter.
///
/// Snapshotted from the equipment item when the scooter is picked, so a plan
/// stays computable after the item is deleted, and overlaid with the item's
/// live attributes whenever it still exists (see `ScooterSpecResolver`).
class ScooterSpec extends Equatable {
  /// The equipment item this came from; null for a manual scooter.
  final String? equipmentId;
  final String name;

  /// Rated cruise speed in m/s.
  final double ratedSpeedMps;

  /// Rated run time at rated speed, in seconds.
  final int burnTimeSeconds;
  final double towSpeedFactor;
  final double towBurnFactor;

  const ScooterSpec({
    this.equipmentId,
    required this.name,
    required this.ratedSpeedMps,
    required this.burnTimeSeconds,
    this.towSpeedFactor = kDefaultTowSpeedFactor,
    this.towBurnFactor = kDefaultTowBurnFactor,
  });

  /// Speed in m/s this scooter makes while towing another diver.
  double get towSpeedMps => ratedSpeedMps * towSpeedFactor;

  ScooterSpec copyWith({
    String? equipmentId,
    bool clearEquipmentId = false,
    String? name,
    double? ratedSpeedMps,
    int? burnTimeSeconds,
    double? towSpeedFactor,
    double? towBurnFactor,
  }) {
    return ScooterSpec(
      equipmentId: clearEquipmentId ? null : (equipmentId ?? this.equipmentId),
      name: name ?? this.name,
      ratedSpeedMps: ratedSpeedMps ?? this.ratedSpeedMps,
      burnTimeSeconds: burnTimeSeconds ?? this.burnTimeSeconds,
      towSpeedFactor: towSpeedFactor ?? this.towSpeedFactor,
      towBurnFactor: towBurnFactor ?? this.towBurnFactor,
    );
  }

  @override
  List<Object?> get props => [
    equipmentId,
    name,
    ratedSpeedMps,
    burnTimeSeconds,
    towSpeedFactor,
    towBurnFactor,
  ];
}
