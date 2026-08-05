import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_3d/domain/geometry/marker_layout.dart';
import 'package:submersion/features/dive_3d/presentation/scene_overlay.dart';

void main() {
  test('SceneMarker carries z, defaulting to 0 for legacy scenes', () {
    const legacy = SceneMarker(
      kind: SceneMarkerKind.bookmark,
      refId: 'b1',
      label: 'note',
      x: 1,
      y: -2,
      timestampSeconds: 60,
    );
    expect(legacy.z, 0);
    const spatial = SceneMarker(
      kind: SceneMarkerKind.site,
      refId: null,
      label: 'Salt Pier',
      x: 5,
      y: 0.15,
      z: -1.25,
      timestampSeconds: 0,
    );
    expect(spatial.z, -1.25);
  });

  test('new marker kinds and paths overlay exist', () {
    expect(SceneMarkerKind.values, contains(SceneMarkerKind.site));
    expect(SceneMarkerKind.values, contains(SceneMarkerKind.nearbySite));
    expect(SceneOverlay.values, contains(SceneOverlay.paths));
  });
}
