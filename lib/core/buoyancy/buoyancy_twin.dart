import 'package:submersion/core/buoyancy/buoyancy_physics.dart';
import 'package:submersion/core/buoyancy/gas_density.dart';
import 'package:submersion/core/buoyancy/suit_compression.dart';
import 'package:submersion/core/buoyancy/weight_prediction_engine.dart'
    show TermSource;
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/tank_presets.dart';
import 'package:submersion/core/deco/entities/dive_environment.dart';

/// One depth sample of the dive being modeled (primary profile only).
class TwinProfileSample {
  final int timestamp; // seconds from dive start
  final double depthM;
  const TwinProfileSample({required this.timestamp, required this.depthM});
}

/// One measured tank-pressure reading.
class TwinPressureSample {
  final int timestamp; // seconds from dive start
  final double pressureBar;
  const TwinPressureSample({
    required this.timestamp,
    required this.pressureBar,
  });
}

/// A tank in the modeled rig. [pressureSeries] is the measured transmitter
/// data when available; when null the pressure is interpolated from
/// start/end, or held at the reserve convention when neither is known.
class TwinTankInput {
  final String id;
  final String label;
  final String? presetName;
  final double? volumeL;
  final double? workingPressureBar;
  final TankMaterial? material;
  final double o2Percent;
  final double hePercent;
  final double? startPressureBar;
  final double? endPressureBar;
  final List<TwinPressureSample>? pressureSeries;

  const TwinTankInput({
    required this.id,
    required this.label,
    this.presetName,
    this.volumeL,
    this.workingPressureBar,
    this.material,
    this.o2Percent = 21,
    this.hePercent = 0,
    this.startPressureBar,
    this.endPressureBar,
    this.pressureSeries,
  });

  bool get hasMeasuredSeries =>
      pressureSeries != null && pressureSeries!.isNotEmpty;
}

enum TwinSuitKind { none, wetsuit, drysuit }

/// The exposure suit. [anchorKg] is the calibrated (or prior) buoyancy near
/// the safety stop; the simulator inverts it to a surface value for
/// wetsuits, and treats it as constant loft for drysuits.
class TwinSuitInput {
  final TwinSuitKind kind;
  final double anchorKg;
  final TermSource source;
  const TwinSuitInput({
    required this.kind,
    required this.anchorKg,
    required this.source,
  });
}

/// A depth-independent buoyancy term (personal baseline, a non-suit gear
/// item, or the water-density shift).
class TwinStaticTerm {
  final String label;
  final double kg;
  final TermSource source;
  const TwinStaticTerm({
    required this.label,
    required this.kg,
    required this.source,
  });
}

/// The complete input to [runBuoyancyTwin]. Immutable and isolate-sendable.
class TwinInput {
  final List<TwinProfileSample> profile; // empty = no-profile dive
  final List<TwinTankInput> tanks;
  final TwinSuitInput suit;
  final List<TwinStaticTerm> staticTerms;
  final double leadKg;
  final double droppableLeadKg;
  final DiveEnvironment environment;

  /// Body + rig displaced mass; lets the what-if sheet rescale the water term
  /// when the water type changes without re-assembling from the database.
  final double totalMassKg;

  const TwinInput({
    required this.profile,
    required this.tanks,
    required this.suit,
    required this.staticTerms,
    required this.leadKg,
    required this.droppableLeadKg,
    required this.environment,
    this.totalMassKg = 0.0,
  });

  TwinInput copyWith({
    List<TwinTankInput>? tanks,
    TwinSuitInput? suit,
    List<TwinStaticTerm>? staticTerms,
    double? leadKg,
    double? droppableLeadKg,
    DiveEnvironment? environment,
  }) => TwinInput(
    profile: profile,
    tanks: tanks ?? this.tanks,
    suit: suit ?? this.suit,
    staticTerms: staticTerms ?? this.staticTerms,
    leadKg: leadKg ?? this.leadKg,
    droppableLeadKg: droppableLeadKg ?? this.droppableLeadKg,
    environment: environment ?? this.environment,
    totalMassKg: totalMassKg,
  );
}

/// The buoyancy state at one profile sample.
class TwinSample {
  final int timestamp;
  final double depthM;
  final double suitKg;
  final double tanksKg;
  final double netKg;
  const TwinSample({
    required this.timestamp,
    required this.depthM,
    required this.suitKg,
    required this.tanksKg,
    required this.netKg,
  });
}

/// The full simulation output. Echoes [input] so analyzers and the what-if
/// sheet can re-derive terms without re-assembling from the database.
class BuoyancyTwinResult {
  final List<TwinSample> samples;
  final double staticKg;
  final double suitSurfaceKg;
  final double drysuitGasLiters;
  final bool pressuresEstimated;
  final TwinInput input;
  const BuoyancyTwinResult({
    required this.samples,
    required this.staticKg,
    required this.suitSurfaceKg,
    required this.drysuitGasLiters,
    required this.pressuresEstimated,
    required this.input,
  });
}

/// Near-empty-tank buoyancy of [tank] at [pressureBar]: the empty-tank
/// buoyancy from the physics catalog minus the mass of gas still inside.
double twinTankKgAt(TwinTankInput tank, double pressureBar) {
  // reserveBar: 0 makes tankTermKg return the empty-tank buoyancy alone.
  final emptyBuoyancy = BuoyancyPhysics.tankTermKg(
    presetName: tank.presetName,
    volumeL: tank.volumeL,
    workingPressureBar: tank.workingPressureBar,
    material: tank.material,
    reserveBar: 0.0,
  );
  final presetVolume = tank.presetName != null
      ? TankPresets.byName(tank.presetName!)?.volumeLiters
      : null;
  final volume = tank.volumeL ?? presetVolume ?? 11.0;
  final density = GasDensity.mixDensityKgPerLBar(
    o2Percent: tank.o2Percent,
    hePercent: tank.hePercent,
  );
  return emptyBuoyancy - volume * pressureBar * density;
}

/// Tank pressure at [timestamp]. Measured series win; otherwise interpolate
/// start->end across [firstTs]..[lastTs]; otherwise the reserve convention.
double twinTankPressureAt(
  TwinTankInput tank,
  int timestamp,
  int firstTs,
  int lastTs,
) {
  final series = tank.pressureSeries;
  if (series != null && series.isNotEmpty) {
    final sorted = [...series]
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return _pressureFromSortedSeries(sorted, timestamp);
  }
  return _interpolatedPressure(tank, timestamp, firstTs, lastTs);
}

double _interpolatedPressure(
  TwinTankInput tank,
  int timestamp,
  int firstTs,
  int lastTs,
) {
  final start = tank.startPressureBar;
  final end = tank.endPressureBar;
  if (start != null && end != null) {
    if (lastTs <= firstTs) return start;
    final frac = ((timestamp - firstTs) / (lastTs - firstTs)).clamp(0.0, 1.0);
    return start + (end - start) * frac;
  }
  if (start != null) return start;
  if (end != null) return end;
  return BuoyancyPhysics.defaultReserveBar;
}

double _pressureFromSortedSeries(List<TwinPressureSample> s, int t) {
  if (t <= s.first.timestamp) return s.first.pressureBar;
  if (t >= s.last.timestamp) return s.last.pressureBar;
  var lo = 0;
  var hi = s.length - 1;
  while (hi - lo > 1) {
    final mid = (lo + hi) >> 1;
    if (s[mid].timestamp <= t) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  final a = s[lo];
  final b = s[hi];
  if (b.timestamp == a.timestamp) return a.pressureBar;
  final frac = (t - a.timestamp) / (b.timestamp - a.timestamp);
  return a.pressureBar + (b.pressureBar - a.pressureBar) * frac;
}

/// Time window (seconds) over which depth is averaged before it feeds the
/// suit-compression term, so depth jitter shorter than the window does not
/// surface as buoyancy the diver never felt.
const int kSuitDepthSmoothingSeconds = 30;

/// Centered time-windowed moving average of the profile's depths, returned as
/// a list parallel to [profile]: each entry is the mean depth of the samples
/// within +/- [windowSeconds]/2 of that sample. O(n) via a sliding window;
/// assumes the profile is time-ordered (as hydrated profiles are).
List<double> smoothDepths(
  List<TwinProfileSample> profile, {
  int windowSeconds = kSuitDepthSmoothingSeconds,
}) {
  final n = profile.length;
  if (n == 0) return const [];
  final half = windowSeconds / 2.0;
  final result = List<double>.filled(n, 0.0);
  var lo = 0;
  var hi = 0;
  var sum = 0.0;
  for (var i = 0; i < n; i++) {
    final t = profile[i].timestamp;
    while (lo < n && profile[lo].timestamp < t - half) {
      sum -= profile[lo].depthM;
      lo++;
    }
    while (hi < n && profile[hi].timestamp <= t + half) {
      sum += profile[hi].depthM;
      hi++;
    }
    final count = hi - lo;
    result[i] = count > 0 ? sum / count : profile[i].depthM;
  }
  return result;
}

/// Runs the buoyancy twin. Top-level so it is safe to hand to `compute`.
BuoyancyTwinResult runBuoyancyTwin(TwinInput input) {
  final env = input.environment;
  final profile = input.profile;
  final staticKg = input.staticTerms.fold(0.0, (sum, t) => sum + t.kg);

  final firstTs = profile.isEmpty ? 0 : profile.first.timestamp;
  final lastTs = profile.isEmpty ? 0 : profile.last.timestamp;

  // Pre-sort measured series once for the hot loop.
  final sortedSeries = <String, List<TwinPressureSample>>{};
  for (final tank in input.tanks) {
    if (tank.hasMeasuredSeries) {
      sortedSeries[tank.id] = [...tank.pressureSeries!]
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    }
  }

  double tankPressure(TwinTankInput tank, int t) {
    final sorted = sortedSeries[tank.id];
    if (sorted != null) return _pressureFromSortedSeries(sorted, t);
    return _interpolatedPressure(tank, t, firstTs, lastTs);
  }

  // Wetsuit: invert the anchor to a surface buoyancy once.
  final suit = input.suit;
  final suitSurfaceKg = suit.kind == TwinSuitKind.wetsuit
      ? SuitCompression.surfaceFromAnchor(
          anchorKg: suit.anchorKg,
          anchorPressureBar: env.pressureAtDepth(5.0),
          surfacePressureBar: env.surfacePressureBar,
        )
      : 0.0;

  double suitAt(double depthM) {
    switch (suit.kind) {
      case TwinSuitKind.none:
        return 0.0;
      case TwinSuitKind.drysuit:
        return suit.anchorKg;
      case TwinSuitKind.wetsuit:
        return SuitCompression.buoyancyAtPressure(
          surfaceKg: suitSurfaceKg,
          pressureBar: env.pressureAtDepth(depthM),
          surfacePressureBar: env.surfacePressureBar,
        );
    }
  }

  // The suit term follows depth, so it would otherwise stamp the depth
  // sensor's high-frequency jitter (wave action, sensor precision) onto the
  // buoyancy curve -- jitter the diver never feels as buoyancy. Feed the suit
  // a time-smoothed depth; each sample still reports its raw depth.
  final suitDepths = smoothDepths(profile);

  final samples = <TwinSample>[];
  for (var i = 0; i < profile.length; i++) {
    final point = profile[i];
    final suitKg = suitAt(suitDepths[i]);
    var tanksKg = 0.0;
    for (final tank in input.tanks) {
      tanksKg += twinTankKgAt(tank, tankPressure(tank, point.timestamp));
    }
    samples.add(
      TwinSample(
        timestamp: point.timestamp,
        depthM: point.depthM,
        suitKg: suitKg,
        tanksKg: tanksKg,
        netKg: suitKg + tanksKg + staticKg - input.leadKg,
      ),
    );
  }

  // Drysuit gas budget: liters added to hold constant loft on descents.
  // Smoothed depth avoids counting sensor jitter as many tiny descents.
  var drysuitGasLiters = 0.0;
  if (suit.kind == TwinSuitKind.drysuit && profile.isNotEmpty) {
    final loft = SuitCompression.loftLitersFromBuoyancy(
      suitTermKg: suit.anchorKg,
      waterDensityKgL: env.waterDensityKgM3 / 1000.0,
    );
    drysuitGasLiters = SuitCompression.drysuitGasLiters(
      loftLiters: loft,
      pressuresBar: [for (final d in suitDepths) env.pressureAtDepth(d)],
    );
  }

  final pressuresEstimated = input.tanks.any((t) => !t.hasMeasuredSeries);

  return BuoyancyTwinResult(
    samples: samples,
    staticKg: staticKg,
    suitSurfaceKg: suitSurfaceKg,
    drysuitGasLiters: drysuitGasLiters,
    pressuresEstimated: pressuresEstimated,
    input: input,
  );
}
