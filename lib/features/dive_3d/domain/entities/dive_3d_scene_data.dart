import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/dive_log/domain/entities/profile_event.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/dive_3d/domain/metric_palette.dart';

/// Everything the 3D scene needs, extracted from domain objects into
/// parallel plain-Dart series. Pure data: no Drift, no Riverpod, no
/// engine imports, so it crosses isolates and is trivially testable.
class Dive3dSceneData {
  final String diveId;
  final List<double> times;
  final List<double> depths;
  final List<double?> temperatures;
  final List<double?> ascentRates;
  final List<double?> ppO2s;
  final List<double?> cnss;
  final List<double?> heartRates;
  final List<double?> ceilings;
  final List<int?> ttss;
  final Map<String, List<TankPressurePoint>> tankPressures;
  final List<GasSwitchWithTank> gasSwitches;
  final List<ProfileEvent> bookmarkEvents;
  final List<MediaItem> photos;
  final double durationSeconds;
  final double maxDepthMeters;

  const Dive3dSceneData({
    required this.diveId,
    required this.times,
    required this.depths,
    required this.temperatures,
    required this.ascentRates,
    required this.ppO2s,
    required this.cnss,
    required this.heartRates,
    required this.ceilings,
    required this.ttss,
    required this.tankPressures,
    required this.gasSwitches,
    required this.bookmarkEvents,
    required this.photos,
    required this.durationSeconds,
    required this.maxDepthMeters,
  });

  factory Dive3dSceneData.fromDomain({
    required String diveId,
    required List<DiveProfilePoint> points,
    required Map<String, List<TankPressurePoint>> tankPressures,
    required List<GasSwitchWithTank> gasSwitches,
    required List<ProfileEvent> events,
    required List<MediaItem> photos,
  }) {
    final sorted = [...points]..sort((a, b) => a.timestamp - b.timestamp);
    double maxDepth = 0;
    for (final p in sorted) {
      if (p.depth > maxDepth) maxDepth = p.depth;
    }
    return Dive3dSceneData(
      diveId: diveId,
      times: [for (final p in sorted) p.timestamp.toDouble()],
      depths: [for (final p in sorted) p.depth],
      temperatures: [for (final p in sorted) p.temperature],
      ascentRates: [for (final p in sorted) p.ascentRate],
      ppO2s: [for (final p in sorted) p.ppO2],
      cnss: [for (final p in sorted) p.cns],
      heartRates: [for (final p in sorted) p.heartRate?.toDouble()],
      ceilings: [for (final p in sorted) p.ceiling],
      ttss: [for (final p in sorted) p.tts],
      tankPressures: tankPressures,
      gasSwitches: gasSwitches,
      bookmarkEvents: [
        for (final e in events)
          if (e.eventType == ProfileEventType.bookmark) e,
      ],
      photos: [
        for (final m in photos)
          if (m.enrichment?.elapsedSeconds != null) m,
      ],
      durationSeconds: sorted.isEmpty ? 0 : sorted.last.timestamp.toDouble(),
      maxDepthMeters: maxDepth,
    );
  }

  bool get hasProfile => times.length >= 2;

  bool _any(List<double?> series) => series.any((v) => v != null && v.isFinite);

  Set<SceneMetric> get availableMetrics => {
    SceneMetric.depth,
    if (_any(temperatures)) SceneMetric.temperature,
    if (_any(ascentRates)) SceneMetric.ascentRate,
    if (_any(ppO2s)) SceneMetric.ppO2,
    if (_any(cnss)) SceneMetric.cns,
    if (_any(heartRates)) SceneMetric.heartRate,
    if (tankPressures.values.any((l) => l.isNotEmpty)) SceneMetric.tankPressure,
  };
}
