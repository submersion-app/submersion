import 'package:submersion/features/planner/domain/entities/mission/scooter_spec.dart';

/// Battery use as a fraction of rated burn time.
///
/// Burn accrues at the rated rate for every second under power, even when
/// the team cruises slower than the scooter's rated speed. That is
/// conservative on purpose: a throttled scooter draws less, but by an amount
/// no attribute records, and a plan that under-counts battery is the one that
/// strands a diver.
class BatteryBurnService {
  const BatteryBurnService();

  /// Fraction of burn time used by [poweredSeconds] at cruise plus
  /// [towingSeconds] at the tow burn factor. Infinite for a scooter with no
  /// burn time, so it can never pass a reserve check.
  double burnFraction({
    required ScooterSpec scooter,
    required int poweredSeconds,
    int towingSeconds = 0,
  }) {
    if (poweredSeconds <= 0 && towingSeconds <= 0) return 0;
    if (scooter.burnTimeSeconds <= 0) return double.infinity;
    final rate = 1.0 / scooter.burnTimeSeconds;
    return poweredSeconds * rate + towingSeconds * rate * scooter.towBurnFactor;
  }

  /// True when [burnFraction] leaves at least [reserveFraction] unused. A
  /// tiny epsilon absorbs floating error at the exact boundary.
  bool withinReserve({
    required double burnFraction,
    required double reserveFraction,
  }) {
    return burnFraction <= (1.0 - reserveFraction) + 1e-9;
  }
}
