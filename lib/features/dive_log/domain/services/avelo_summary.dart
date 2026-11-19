import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// What an Avelo dive's computer recorded, summed up the way Shearwater
/// Cloud does it (issue #4664). Each value is null when no underwater sample
/// carries it.
class AveloSummary {
  const AveloSummary({
    this.minBuoyancyKg,
    this.maxBuoyancyKg,
    this.meanBuoyancyKg,
    this.minRmv,
    this.maxRmv,
    this.gasRemainingStart,
    this.gasRemainingEnd,
    this.maxPressureBar,
  });

  /// The computer's buoyancy figure, kilograms, negative is heavy.
  final double? minBuoyancyKg;
  final double? maxBuoyancyKg;
  final double? meanBuoyancyKg;

  /// The computer's own RMV, litres per minute.
  final double? minRmv;
  final double? maxRmv;

  /// Hydrotank gas remaining, percent, at the first and last underwater
  /// samples that carry it.
  final int? gasRemainingStart;
  final int? gasRemainingEnd;

  /// The highest Hydrotank pressure, bar.
  final double? maxPressureBar;
}

/// The Avelo summary of [profile], with the highest of [hydrotankPressures].
///
/// Only samples below the surface count: the computer logs a constant
/// buoyancy and a full tank before the dive, and Shearwater Cloud's own
/// statistics leave those out (checked on eight real dives, where this rule
/// reproduces every one of them). A pressure counts when it was logged at
/// the time of an underwater sample.
///
/// Null when no underwater sample carries any of the three Avelo values: a
/// dive outside Avelo mode, or one that never went below the surface.
AveloSummary? aveloSummaryOf(
  List<DiveProfilePoint> profile,
  List<TankPressurePoint>? hydrotankPressures,
) {
  final underwater = [
    for (final p in profile)
      if (p.depth > 0) p,
  ];
  final buoyancy = [for (final p in underwater) ?p.aveloBuoyancy];
  final rmv = [for (final p in underwater) ?p.computerRmv];
  final gas = [for (final p in underwater) ?p.aveloGasRemaining];
  if (buoyancy.isEmpty && rmv.isEmpty && gas.isEmpty) return null;

  final underwaterTimes = {for (final p in underwater) p.timestamp};
  final pressures = [
    for (final p in hydrotankPressures ?? const <TankPressurePoint>[])
      if (underwaterTimes.contains(p.timestamp)) p.pressure,
  ];

  double? minOf(List<double> v) =>
      v.isEmpty ? null : v.reduce((a, b) => a < b ? a : b);
  double? maxOf(List<double> v) =>
      v.isEmpty ? null : v.reduce((a, b) => a > b ? a : b);

  return AveloSummary(
    minBuoyancyKg: minOf(buoyancy),
    maxBuoyancyKg: maxOf(buoyancy),
    meanBuoyancyKg: buoyancy.isEmpty
        ? null
        : buoyancy.reduce((a, b) => a + b) / buoyancy.length,
    minRmv: minOf(rmv),
    maxRmv: maxOf(rmv),
    gasRemainingStart: gas.isEmpty ? null : gas.first,
    gasRemainingEnd: gas.isEmpty ? null : gas.last,
    maxPressureBar: maxOf(pressures),
  );
}
