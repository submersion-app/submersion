import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/presentation/widgets/photo_marker_layout.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';

MediaItem _media({
  String id = 'm1',
  MediaType type = MediaType.photo,
  MediaEnrichment? enrichment,
}) {
  final now = DateTime.utc(2026, 1, 1);
  return MediaItem(
    id: id,
    diveId: 'dive-1',
    mediaType: type,
    takenAt: now,
    createdAt: now,
    updatedAt: now,
    enrichment: enrichment,
  );
}

MediaEnrichment _enrichment({
  int? elapsedSeconds = 600,
  double? depthMeters = 18.0,
  MatchConfidence confidence = MatchConfidence.exact,
}) {
  return MediaEnrichment(
    id: 'e1',
    mediaId: 'm1',
    diveId: 'dive-1',
    elapsedSeconds: elapsedSeconds,
    depthMeters: depthMeters,
    matchConfidence: confidence,
    createdAt: DateTime.utc(2026, 1, 1),
  );
}

void main() {
  group('photoMarkersFromMedia', () {
    test('maps an enriched photo to a marker', () {
      final markers = photoMarkersFromMedia([
        _media(enrichment: _enrichment()),
      ], maxProfileSeconds: 3600);
      expect(markers, hasLength(1));
      expect(markers.single.elapsedSeconds, 600);
      expect(markers.single.depthMeters, 18.0);
    });

    test('includes enriched videos alongside photos', () {
      // Underwater libraries are often mostly short clips; a video with a
      // valid profile position gets a marker just like a photo (dive #18).
      final markers = photoMarkersFromMedia([
        _media(id: 'v1', type: MediaType.video, enrichment: _enrichment()),
        _media(id: 'p1', enrichment: _enrichment(elapsedSeconds: 900)),
      ], maxProfileSeconds: 3600);
      expect(markers, hasLength(2));
      expect(markers.map((m) => m.item.id), containsAll(['v1', 'p1']));
    });

    test(
      'excludes signatures, missing enrichment, noProfile, and null fields',
      () {
        final markers = photoMarkersFromMedia([
          _media(
            id: 's1',
            type: MediaType.instructorSignature,
            enrichment: _enrichment(),
          ),
          _media(id: 'm2'),
          _media(
            id: 'm3',
            enrichment: _enrichment(confidence: MatchConfidence.noProfile),
          ),
          _media(id: 'm4', enrichment: _enrichment(elapsedSeconds: null)),
          _media(id: 'm5', enrichment: _enrichment(depthMeters: null)),
        ], maxProfileSeconds: 3600);
        expect(markers, isEmpty);
      },
    );

    test('clamps elapsed seconds into the profile range and sorts by time', () {
      final markers = photoMarkersFromMedia([
        _media(id: 'late', enrichment: _enrichment(elapsedSeconds: 4000)),
        _media(id: 'early', enrichment: _enrichment(elapsedSeconds: -30)),
      ], maxProfileSeconds: 3600);
      expect(markers, hasLength(2));
      expect(markers[0].elapsedSeconds, 0);
      expect(markers[1].elapsedSeconds, 3600);
    });
  });

  group('clusterPhotoMarkers', () {
    // A 100x100 plot over 0..1000s and 0..50 depth keeps the math legible:
    // 1 px per 10 s horizontally, 1 px per 0.5 depth units vertically.
    List<PhotoMarkerCluster> cluster(
      List<({double seconds, double depthDisplay})> points, {
      double mergeRadiusPx = 24,
    }) {
      return clusterPhotoMarkers(
        points: points,
        visibleMinSeconds: 0,
        visibleMaxSeconds: 1000,
        visibleMinDepth: 0,
        visibleMaxDepth: 50,
        plotWidth: 100,
        plotHeight: 100,
        mergeRadiusPx: mergeRadiusPx,
      );
    }

    test('maps a single marker linearly into plot pixels', () {
      final clusters = cluster([(seconds: 500.0, depthDisplay: 25.0)]);
      expect(clusters, hasLength(1));
      expect(clusters.single.memberIndexes, [0]);
      expect(clusters.single.x, closeTo(50, 0.001));
      expect(clusters.single.y, closeTo(50, 0.001));
    });

    test('merges markers within the radius at the mean position', () {
      final clusters = cluster([
        (seconds: 500.0, depthDisplay: 20.0),
        (seconds: 600.0, depthDisplay: 30.0), // 10 px right of the first
      ]);
      expect(clusters, hasLength(1));
      expect(clusters.single.memberIndexes, [0, 1]);
      expect(clusters.single.x, closeTo(55, 0.001));
      expect(clusters.single.y, closeTo(50, 0.001));
    });

    test('keeps markers beyond the radius separate', () {
      final clusters = cluster([
        (seconds: 100.0, depthDisplay: 10.0),
        (seconds: 600.0, depthDisplay: 30.0), // 50 px apart
      ]);
      expect(clusters, hasLength(2));
      expect(clusters[0].memberIndexes, [0]);
      expect(clusters[1].memberIndexes, [1]);
    });

    test('omits markers outside the visible time or depth window', () {
      final clusters = clusterPhotoMarkers(
        points: [
          (seconds: 100.0, depthDisplay: 25.0), // left of window
          (seconds: 500.0, depthDisplay: 45.0), // below window
          (seconds: 600.0, depthDisplay: 25.0), // visible
        ],
        visibleMinSeconds: 400,
        visibleMaxSeconds: 800,
        visibleMinDepth: 10,
        visibleMaxDepth: 40,
        plotWidth: 100,
        plotHeight: 100,
      );
      expect(clusters, hasLength(1));
      expect(clusters.single.memberIndexes, [2]);
    });

    test('returns empty for degenerate geometry', () {
      expect(
        clusterPhotoMarkers(
          points: [(seconds: 500.0, depthDisplay: 25.0)],
          visibleMinSeconds: 0,
          visibleMaxSeconds: 0,
          visibleMinDepth: 0,
          visibleMaxDepth: 50,
          plotWidth: 100,
          plotHeight: 100,
        ),
        isEmpty,
      );
    });
  });
}
