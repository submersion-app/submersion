import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_3d/domain/entities/dive_3d_scene_data.dart';
import 'package:submersion/features/dive_3d/domain/geometry/marker_layout.dart';
import 'package:submersion/features/dive_3d/domain/geometry/scene_bounds.dart';
import 'package:submersion/features/dive_log/domain/entities/profile_event.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';

void main() {
  final createdAt = DateTime.utc(2026, 7, 11);

  Dive3dSceneData sceneData({
    List<ProfileEvent> events = const [],
    List<MediaItem> photos = const [],
  }) => Dive3dSceneData(
    diveId: 'd1',
    times: const [0, 100],
    depths: const [0, 20],
    temperatures: const [null, null],
    ascentRates: const [null, null],
    ppO2s: const [null, null],
    cnss: const [null, null],
    heartRates: const [null, null],
    ceilings: const [null, null],
    ttss: const [null, null],
    tankPressures: const {},
    gasSwitches: const [],
    bookmarkEvents: events,
    photos: photos,
    durationSeconds: 100,
    maxDepthMeters: 20,
  );

  test('bookmark events become bookmark markers with their note', () {
    final data = sceneData(
      events: [
        ProfileEvent.bookmark(
          id: 'b1',
          diveId: 'd1',
          timestamp: 25,
          note: 'saw a turtle',
          createdAt: createdAt,
        ),
      ],
    );
    const bounds = SceneBounds(durationSeconds: 100, maxDepthMeters: 20);
    final markers = MarkerLayout.layout(data: data, bounds: bounds);
    expect(markers.single.kind, SceneMarkerKind.bookmark);
    expect(markers.single.label, 'saw a turtle');
    expect(markers.single.x, closeTo(2.5, 1e-9));
  });

  test('enriched photos become photo markers at their elapsed time', () {
    final photo = MediaItem(
      id: 'm1',
      diveId: 'd1',
      mediaType: MediaType.photo,
      takenAt: createdAt,
      createdAt: createdAt,
      updatedAt: createdAt,
      enrichment: MediaEnrichment(
        id: 'e1',
        mediaId: 'm1',
        diveId: 'd1',
        elapsedSeconds: 50,
        matchConfidence: MatchConfidence.exact,
        createdAt: createdAt,
      ),
    );
    final data = sceneData(photos: [photo]);
    const bounds = SceneBounds(durationSeconds: 100, maxDepthMeters: 20);
    final markers = MarkerLayout.layout(data: data, bounds: bounds);
    expect(markers.single.kind, SceneMarkerKind.photo);
    expect(markers.single.refId, 'm1');
    expect(markers.single.x, closeTo(5.0, 1e-9));
  });

  test('markers are sorted by timestamp', () {
    final data = sceneData(
      events: [
        ProfileEvent.bookmark(
          id: 'b2',
          diveId: 'd1',
          timestamp: 80,
          note: 'late',
          createdAt: createdAt,
        ),
        ProfileEvent.bookmark(
          id: 'b1',
          diveId: 'd1',
          timestamp: 10,
          note: 'early',
          createdAt: createdAt,
        ),
      ],
    );
    const bounds = SceneBounds(durationSeconds: 100, maxDepthMeters: 20);
    final markers = MarkerLayout.layout(data: data, bounds: bounds);
    expect(markers.first.label, 'early');
    expect(markers.last.label, 'late');
  });
}
