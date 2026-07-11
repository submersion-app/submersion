import 'package:submersion/features/dive_3d/domain/entities/dive_3d_scene_data.dart';
import 'package:submersion/features/dive_3d/domain/profile_lookup.dart';
import 'package:submersion/features/dive_3d/domain/geometry/scene_bounds.dart';

enum SceneMarkerKind { gasSwitch, bookmark, photo }

/// A tappable scene annotation anchored to the ribbon at a moment in the
/// dive. x/y are scene coordinates (z is always 0; renderers billboard).
class SceneMarker {
  final SceneMarkerKind kind;
  final String? refId;
  final String label;
  final double x;
  final double y;
  final int timestampSeconds;

  const SceneMarker({
    required this.kind,
    required this.refId,
    required this.label,
    required this.x,
    required this.y,
    required this.timestampSeconds,
  });
}

class MarkerLayout {
  static const double _floatOffset = 0.4;

  static List<SceneMarker> layout({
    required Dive3dSceneData data,
    required SceneBounds bounds,
  }) {
    if (!data.hasProfile) return const [];
    final lookup = ProfileLookup(data.times);
    final nullableDepths = data.depths.cast<double?>();

    SceneMarker at({
      required SceneMarkerKind kind,
      required String? refId,
      required String label,
      required int t,
    }) {
      final depth = lookup.interpolate(nullableDepths, t.toDouble()) ?? 0;
      return SceneMarker(
        kind: kind,
        refId: refId,
        label: label,
        x: bounds.xOf(t),
        y: bounds.yOf(depth) + _floatOffset,
        timestampSeconds: t,
      );
    }

    final markers = <SceneMarker>[
      for (final gs in data.gasSwitches)
        at(
          kind: SceneMarkerKind.gasSwitch,
          refId: gs.gasSwitch.id,
          label: gs.gasMix,
          t: gs.gasSwitch.timestamp,
        ),
      for (final e in data.bookmarkEvents)
        at(
          kind: SceneMarkerKind.bookmark,
          refId: e.id,
          label: e.description ?? '',
          t: e.timestamp,
        ),
      for (final m in data.photos)
        at(
          kind: SceneMarkerKind.photo,
          refId: m.id,
          label: '',
          t: m.enrichment!.elapsedSeconds!,
        ),
    ]..sort((a, b) => a.timestampSeconds - b.timestampSeconds);
    return markers;
  }
}
