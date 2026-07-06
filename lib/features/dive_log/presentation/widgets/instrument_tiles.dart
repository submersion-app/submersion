import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/services/profile_position.dart';

/// Identifiers for instrument bar tiles. [key] is the persisted string used
/// in settings; never rename a key without a migration.
enum InstrumentTileId {
  depth('depth'),
  runtime('runtime'),
  temperature('temperature'),
  ndl('ndl'),
  ceiling('ceiling'),
  tts('tts'),
  tankPressure('tankPressure'),
  ppO2('ppO2'),
  gf('gf'),
  cns('cns'),
  sac('sac'),
  heartRate('heartRate'),
  ascentRate('ascentRate');

  const InstrumentTileId(this.key);
  final String key;

  static InstrumentTileId? fromKey(String key) {
    for (final id in values) {
      if (id.key == key) return id;
    }
    return null;
  }
}

/// Priority order for candidate tiles. Depth and runtime always lead.
const List<InstrumentTileId> _priorityOrder = [
  InstrumentTileId.depth,
  InstrumentTileId.runtime,
  InstrumentTileId.temperature,
  InstrumentTileId.ndl,
  InstrumentTileId.ceiling,
  InstrumentTileId.tts,
  InstrumentTileId.tankPressure,
  InstrumentTileId.ppO2,
  InstrumentTileId.gf,
  InstrumentTileId.cns,
  InstrumentTileId.sac,
  InstrumentTileId.heartRate,
  InstrumentTileId.ascentRate,
];

/// Tiles the dive's data can actually populate, in priority order.
List<InstrumentTileId> computeCandidateTiles({
  required List<DiveProfilePoint> profile,
  ProfileAnalysis? analysis,
  Map<String, List<TankPressurePoint>>? tankPressures,
}) {
  bool anyPoint(bool Function(DiveProfilePoint) test) => profile.any(test);

  final available = <InstrumentTileId>{
    if (profile.isNotEmpty) InstrumentTileId.depth,
    if (profile.isNotEmpty) InstrumentTileId.runtime,
    if (anyPoint((p) => p.temperature != null)) InstrumentTileId.temperature,
    if ((analysis?.ndlCurve.isNotEmpty ?? false) ||
        anyPoint((p) => p.ndl != null))
      InstrumentTileId.ndl,
    if ((analysis?.ceilingCurve.isNotEmpty ?? false) ||
        anyPoint((p) => p.ceiling != null))
      InstrumentTileId.ceiling,
    if ((analysis?.ttsCurve?.isNotEmpty ?? false) ||
        anyPoint((p) => p.tts != null))
      InstrumentTileId.tts,
    if (tankPressures != null &&
        tankPressures.values.any((points) => points.isNotEmpty))
      InstrumentTileId.tankPressure,
    if ((analysis?.ppO2Curve.isNotEmpty ?? false) ||
        anyPoint((p) => p.ppO2 != null))
      InstrumentTileId.ppO2,
    if (analysis?.gfCurve?.isNotEmpty ?? false) InstrumentTileId.gf,
    if ((analysis?.cnsCurve?.isNotEmpty ?? false) ||
        anyPoint((p) => p.cns != null))
      InstrumentTileId.cns,
    if (analysis?.smoothedSacCurve?.isNotEmpty ?? false) InstrumentTileId.sac,
    if (anyPoint((p) => p.heartRate != null)) InstrumentTileId.heartRate,
    if ((analysis?.ascentRates.isNotEmpty ?? false) ||
        anyPoint((p) => p.ascentRate != null))
      InstrumentTileId.ascentRate,
  };

  return [
    for (final id in _priorityOrder)
      if (available.contains(id)) id,
  ];
}

/// Applies the user's persisted order and hidden set on top of [candidates].
///
/// Unknown keys in [order] are ignored; candidates not mentioned in [order]
/// keep priority order and append after the ordered ones. Hidden tiles are
/// removed last, so hiding never reorders the rest.
List<InstrumentTileId> applyTilePreferences({
  required List<InstrumentTileId> candidates,
  required List<String> order,
  required List<String> hidden,
}) {
  final candidateSet = candidates.toSet();
  final ordered = <InstrumentTileId>[];
  for (final key in order) {
    final id = InstrumentTileId.fromKey(key);
    if (id != null && candidateSet.contains(id) && !ordered.contains(id)) {
      ordered.add(id);
    }
  }
  final remaining = [
    for (final id in candidates)
      if (!ordered.contains(id)) id,
  ];
  final hiddenSet = hidden.toSet();
  return [
    for (final id in [...ordered, ...remaining])
      if (!hiddenSet.contains(id.key)) id,
  ];
}

/// Merges a freshly reordered set of candidate tile keys back into the
/// persisted global tile order without discarding tiles that belong to
/// other dives.
///
/// The customize sheet only ever shows (and lets the user reorder) the
/// tiles applicable to the current dive, but [stored] may contain keys for
/// tiles this dive doesn't have (e.g. `heartRate` when this dive has no
/// heart-rate data). Persisting [reordered] alone would silently drop those
/// keys from the global order. Instead, the result is [reordered] followed
/// by every key from [stored] that isn't in [candidates], preserving their
/// relative order from [stored].
List<String> mergeTileOrder({
  required List<String> reordered,
  required List<String> stored,
  required Set<String> candidates,
}) {
  return [
    ...reordered,
    for (final key in stored)
      if (!candidates.contains(key) && !reordered.contains(key)) key,
  ];
}

/// Deco-aware instrument swap, mirroring a real dive computer: NDL shows
/// outside deco; ceiling and TTS replace it during mandatory decompression.
List<InstrumentTileId> applyDecoSwap({
  required List<InstrumentTileId> tiles,
  required bool inDeco,
}) {
  return [
    for (final id in tiles)
      if (inDeco
          ? id != InstrumentTileId.ndl
          : id != InstrumentTileId.ceiling && id != InstrumentTileId.tts)
        id,
  ];
}

/// Raw (metric, unformatted) instrument values at one review position.
class InstrumentSample {
  final int runtimeSeconds;
  final double? depthMeters;
  final double? temperatureCelsius;
  final int? ndlSeconds;
  final double? ceilingMeters;
  final int? ttsSeconds;
  final Map<String, double> tankPressuresBar;
  final double? ppO2Bar;
  final double? gfPercent;
  final double? cnsPercent;
  final double? sacRate;
  final int? heartRateBpm;
  final double? ascentRateMetersPerMin;
  final bool inDeco;

  const InstrumentSample({
    required this.runtimeSeconds,
    this.depthMeters,
    this.temperatureCelsius,
    this.ndlSeconds,
    this.ceilingMeters,
    this.ttsSeconds,
    this.tankPressuresBar = const {},
    this.ppO2Bar,
    this.gfPercent,
    this.cnsPercent,
    this.sacRate,
    this.heartRateBpm,
    this.ascentRateMetersPerMin,
    this.inDeco = false,
  });
}

/// Resolves instrument values at [timestamp] (dive-seconds).
InstrumentSample resolveSample({
  /// The profile the analysis curves were computed over (the active source's
  /// rendered profile). Curve values are read by INDEX, so passing any other
  /// array (e.g. dive.profile when a different source is active, or when the
  /// sources sample at different rates) reads wrong values where the arrays
  /// diverge and null past the shorter one's end.
  required List<DiveProfilePoint> profile,
  ProfileAnalysis? analysis,
  Map<String, List<TankPressurePoint>>? tankPressures,
  required int timestamp,
}) {
  final index = indexForTimestamp(profile, timestamp);
  if (index == null) {
    return InstrumentSample(runtimeSeconds: timestamp);
  }
  final point = profile[index];

  T? curveAt<T>(List<T>? curve) =>
      (curve != null && index < curve.length) ? curve[index] : null;

  return InstrumentSample(
    runtimeSeconds: point.timestamp,
    depthMeters: point.depth,
    temperatureCelsius: point.temperature,
    ndlSeconds: curveAt(analysis?.ndlCurve) ?? point.ndl,
    ceilingMeters: curveAt(analysis?.ceilingCurve) ?? point.ceiling,
    ttsSeconds: curveAt(analysis?.ttsCurve) ?? point.tts,
    tankPressuresBar: {
      if (tankPressures != null)
        for (final entry in tankPressures.entries)
          entry.key: ?pressureAtTimestamp(entry.value, timestamp),
    },
    ppO2Bar: curveAt(analysis?.ppO2Curve) ?? point.ppO2,
    gfPercent: curveAt(analysis?.gfCurve),
    cnsPercent: curveAt(analysis?.cnsCurve) ?? point.cns,
    sacRate: curveAt(analysis?.smoothedSacCurve),
    heartRateBpm: point.heartRate,
    ascentRateMetersPerMin:
        curveAt(analysis?.ascentRates)?.rateMetersPerMin ?? point.ascentRate,
    inDeco: point.decoType == 2,
  );
}
