import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';

/// A slider range declared once in canonical units.
///
/// Canonical units are the app's storage units: meters for depth and ascent
/// rate, liters per minute for SAC, minutes for time. [min], [max], and [step]
/// are in DISPLAY space, derived from the canonical range and snapped to a
/// grid that reads naturally in the diver's units.
///
/// Every value handed to a widget is display-space; every value handed back
/// through [toCanonical] is canonical. Bounds cannot be expressed in display
/// units at the call site, which is what previously allowed a slider labelled
/// "cuft/min" to carry a 15-35 L/min range.
///
/// Snapping always narrows INWARD (ceil the minimum, floor the maximum) so a
/// rounded bound can never fall outside the canonical range it was derived
/// from.
class UnitAxis {
  final double min;
  final double max;
  final double step;
  final int decimals;
  final String symbol;

  final double Function(double canonical) _toDisplay;
  final double Function(double display) _toCanonical;

  const UnitAxis({
    required this.min,
    required this.max,
    required this.step,
    required this.decimals,
    required this.symbol,
    required double Function(double) toDisplayFn,
    required double Function(double) toCanonicalFn,
  }) : _toDisplay = toDisplayFn,
       _toCanonical = toCanonicalFn;

  double toDisplay(double canonical) => _toDisplay(canonical);

  double toCanonical(double display) => _toCanonical(display);

  /// Slider divisions implied by the snapped grid.
  int get divisions => ((max - min) / step).round();

  /// Format a DISPLAY-space value at this axis's precision.
  String format(double display) => display.toStringAsFixed(decimals);

  /// Clamp a canonical value so it cannot fall outside the display range.
  double clampCanonical(double canonical) {
    final display = toDisplay(canonical).clamp(min, max);
    return toCanonical(display);
  }

  /// Round [value] down to the nearest multiple of [grid].
  static double _floorTo(double value, double grid) =>
      (value / grid).floor() * grid;

  /// Round [value] up to the nearest multiple of [grid].
  static double _ceilTo(double value, double grid) =>
      (value / grid).ceil() * grid;

  /// Maximum depth, canonical 10-50 m.
  factory UnitAxis.depth(UnitFormatter units) =>
      UnitAxis.depthRange(units, minMeters: 10, maxMeters: 50);

  /// Target depth for gas planning, canonical 6-60 m.
  ///
  /// Wider than [UnitAxis.depth] because a best-mix or MOD question is asked
  /// about deco stops as well as bottom depths.
  factory UnitAxis.targetDepth(UnitFormatter units) =>
      UnitAxis.depthRange(units, minMeters: 6, maxMeters: 60);

  /// A depth axis over an explicit canonical range.
  factory UnitAxis.depthRange(
    UnitFormatter units, {
    required double minMeters,
    required double maxMeters,
  }) {
    final metric = units.settings.depthUnit == DepthUnit.meters;
    return UnitAxis(
      min: metric ? minMeters : _ceilTo(units.convertDepth(minMeters), 5),
      max: metric ? maxMeters : _floorTo(units.convertDepth(maxMeters), 5),
      step: metric ? 1 : 5,
      decimals: 0,
      symbol: units.depthSymbol,
      toDisplayFn: units.convertDepth,
      toCanonicalFn: units.depthToMeters,
    );
  }

  /// Ascent rate, canonical 3-18 m/min.
  ///
  /// The recreational ceiling is 9-10 m/min; the range extends below that for
  /// divers who prefer a slower ascent and above it only as far as the
  /// canonical bound allows.
  factory UnitAxis.ascentRate(UnitFormatter units) {
    final metric = units.settings.depthUnit == DepthUnit.meters;
    return UnitAxis(
      min: metric ? 3 : _ceilTo(units.convertDepth(3), 5),
      max: metric ? 18 : _floorTo(units.convertDepth(18), 5),
      step: metric ? 1 : 5,
      decimals: 0,
      symbol: '${units.depthSymbol}/min',
      toDisplayFn: units.convertDepth,
      toCanonicalFn: units.depthToMeters,
    );
  }

  /// Stressed SAC for emergency planning, canonical 15-40 L/min.
  factory UnitAxis.stressedSac(UnitFormatter units) => _sac(units, 15, 40);

  /// Working SAC for consumption planning, canonical 8-30 L/min.
  factory UnitAxis.normalSac(UnitFormatter units) => _sac(units, 8, 30);

  static UnitAxis _sac(UnitFormatter units, double minL, double maxL) {
    final metric = units.settings.volumeUnit == VolumeUnit.liters;
    return UnitAxis(
      min: metric ? minL : _ceilTo(units.convertVolume(minL), 0.05),
      max: metric ? maxL : _floorTo(units.convertVolume(maxL), 0.05),
      step: metric ? 1 : 0.05,
      decimals: metric ? 0 : 2,
      symbol: '${units.volumeSymbol}/min',
      toDisplayFn: units.convertVolume,
      toCanonicalFn: units.volumeToLiters,
    );
  }

  /// A plain minute range, identical in both unit systems.
  factory UnitAxis.minutes({
    required double min,
    required double max,
    double step = 1,
  }) => UnitAxis(
    min: min,
    max: max,
    step: step,
    decimals: 0,
    symbol: 'min',
    toDisplayFn: (v) => v,
    toCanonicalFn: (v) => v,
  );

  /// Dive time in minutes.
  factory UnitAxis.diveTime() => UnitAxis.minutes(min: 5, max: 90);
}
