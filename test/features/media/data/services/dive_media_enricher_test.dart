import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/media/data/services/dive_media_enricher.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';

Dive _diveWithProfile() => Dive(
  id: 'd1',
  dateTime: DateTime.utc(2025, 12, 27, 11, 26),
  entryTime: DateTime.utc(2025, 12, 27, 11, 26),
  profile: const [
    DiveProfilePoint(timestamp: 0, depth: 0),
    DiveProfilePoint(timestamp: 2520, depth: 20, temperature: 26), // 42 min in
    DiveProfilePoint(timestamp: 2580, depth: 5),
  ],
);

MediaItem _media(
  String id, {
  required DateTime takenAt,
  MediaEnrichment? enrichment,
}) => MediaItem(
  id: id,
  diveId: 'd1',
  mediaType: MediaType.photo,
  sourceType: MediaSourceType.localFile,
  takenAt: takenAt,
  enrichment: enrichment,
  createdAt: DateTime.utc(2025),
  updatedAt: DateTime.utc(2025),
);

void main() {
  manualPositionTests();
  test('enriches a linked item that has no enrichment yet', () async {
    final saved = <MediaEnrichment>[];
    final enricher = DiveMediaEnricher(
      loadDive: (_) async => _diveWithProfile(),
      loadMediaForDive: (_) async => [
        // Shutter at 12:08 == 2520s (42 min) after the 11:26 entry.
        _media('m1', takenAt: DateTime.utc(2025, 12, 27, 12, 8)),
      ],
      saveEnrichments: (rows) async => saved.addAll(rows),
    );

    final count = await enricher.enrichMissingForDive('d1');

    expect(count, 1);
    expect(saved, hasLength(1));
    expect(saved.single.mediaId, 'm1');
    expect(saved.single.diveId, 'd1');
    expect(saved.single.elapsedSeconds, 2520);
    expect(saved.single.depthMeters, 20.0);
  });

  /// The recompute is cheap arithmetic over an in-memory profile, but the
  /// WRITE is not free: mediaEnrichment is an HLC-synced entity, so saving a
  /// row that did not change would bump its clock and ship a no-op to every
  /// other device. Matching rows must therefore be left completely alone.
  test(
    'is idempotent: writes nothing when the stored enrichment matches',
    () async {
      final saved = <MediaEnrichment>[];
      final enricher = DiveMediaEnricher(
        loadDive: (_) async => _diveWithProfile(),
        loadMediaForDive: (_) async => [
          _media(
            'm1',
            takenAt: DateTime.utc(2025, 12, 27, 12, 8),
            enrichment: MediaEnrichment(
              id: 'e1',
              mediaId: 'm1',
              diveId: 'd1',
              elapsedSeconds: 2520,
              depthMeters: 20,
              temperatureCelsius: 26,
              timestampOffsetSeconds: 0,
              matchConfidence: MatchConfidence.exact,
              createdAt: DateTime.utc(2025),
            ),
          ),
        ],
        saveEnrichments: (rows) async => saved.addAll(rows),
      );

      expect(await enricher.enrichMissingForDive('d1'), 0);
      expect(saved, isEmpty);
    },
  );

  /// Rows written before the taken_at wall-clock-UTC fix carry an elapsed
  /// time skewed by the host's offset and a depth clamped to the first
  /// profile point. Skipping every item that merely HAS a row meant those
  /// never healed: the only remedy was unlinking and re-adding the photo.
  test(
    'recomputes a stored enrichment that disagrees with the profile',
    () async {
      final saved = <MediaEnrichment>[];
      final enricher = DiveMediaEnricher(
        loadDive: (_) async => _diveWithProfile(),
        loadMediaForDive: (_) async => [
          _media(
            'm1',
            takenAt: DateTime.utc(2025, 12, 27, 12, 8),
            enrichment: MediaEnrichment(
              id: 'e1',
              mediaId: 'm1',
              diveId: 'd1',
              // The -5h skew and clamped surface depth the old bug produced.
              elapsedSeconds: -16692,
              depthMeters: 0.4572,
              matchConfidence: MatchConfidence.estimated,
              createdAt: DateTime.utc(2025),
            ),
          ),
        ],
        saveEnrichments: (rows) async => saved.addAll(rows),
      );

      expect(await enricher.enrichMissingForDive('d1'), 1);
      expect(saved, hasLength(1));
      expect(saved.single.elapsedSeconds, 2520);
      expect(saved.single.depthMeters, 20.0);
      expect(saved.single.matchConfidence, MatchConfidence.exact);
    },
  );

  /// Defence in depth for the re-link path: reassignMediaToDive deletes the
  /// stale rows itself, but a row that reaches the new dive still pointing at
  /// the old one is wrong by definition and must not be trusted.
  test('recomputes an enrichment still pointing at a different dive', () async {
    final saved = <MediaEnrichment>[];
    final enricher = DiveMediaEnricher(
      loadDive: (_) async => _diveWithProfile(),
      loadMediaForDive: (_) async => [
        _media(
          'm1',
          takenAt: DateTime.utc(2025, 12, 27, 12, 8),
          enrichment: MediaEnrichment(
            id: 'e1',
            mediaId: 'm1',
            // Values happen to match; only the dive is wrong.
            diveId: 'some-other-dive',
            elapsedSeconds: 2520,
            depthMeters: 20,
            temperatureCelsius: 26,
            timestampOffsetSeconds: 0,
            matchConfidence: MatchConfidence.exact,
            createdAt: DateTime.utc(2025),
          ),
        ),
      ],
      saveEnrichments: (rows) async => saved.addAll(rows),
    );

    expect(await enricher.enrichMissingForDive('d1'), 1);
    expect(saved.single.diveId, 'd1');
  });

  test('returns 0 and saves nothing when the dive has no profile', () async {
    final saved = <MediaEnrichment>[];
    final enricher = DiveMediaEnricher(
      loadDive: (_) async => Dive(id: 'd1', dateTime: DateTime.utc(2025)),
      loadMediaForDive: (_) async => [
        _media('m1', takenAt: DateTime.utc(2025, 12, 27, 12, 8)),
      ],
      saveEnrichments: (rows) async => saved.addAll(rows),
    );

    expect(await enricher.enrichMissingForDive('d1'), 0);
    expect(saved, isEmpty);
  });

  test('skips instructor signatures (never plotted on the chart)', () async {
    final saved = <MediaEnrichment>[];
    final signature = MediaItem(
      id: 'sig',
      diveId: 'd1',
      mediaType: MediaType.instructorSignature,
      sourceType: MediaSourceType.localFile,
      takenAt: DateTime.utc(2025, 12, 27, 12, 8),
      createdAt: DateTime.utc(2025),
      updatedAt: DateTime.utc(2025),
    );
    final enricher = DiveMediaEnricher(
      loadDive: (_) async => _diveWithProfile(),
      loadMediaForDive: (_) async => [signature],
      saveEnrichments: (rows) async => saved.addAll(rows),
    );

    expect(await enricher.enrichMissingForDive('d1'), 0);
    expect(saved, isEmpty);
  });

  test('returns 0 when the dive is not found', () async {
    final saved = <MediaEnrichment>[];
    final enricher = DiveMediaEnricher(
      loadDive: (_) async => null,
      loadMediaForDive: (_) async => [
        _media('m1', takenAt: DateTime.utc(2025, 12, 27, 12, 8)),
      ],
      saveEnrichments: (rows) async => saved.addAll(rows),
    );

    expect(await enricher.enrichMissingForDive('d1'), 0);
    expect(saved, isEmpty);
  });

  /// The backfill fires from the media viewer, where each write used to tick
  /// watchMediaChanges and re-run every media provider. All of a dive's
  /// missing rows must therefore leave in ONE batched save (one transaction,
  /// one tick), not one save per item.
  test('saves all missing enrichments in a single batched call', () async {
    final batches = <List<MediaEnrichment>>[];
    final enricher = DiveMediaEnricher(
      loadDive: (_) async => _diveWithProfile(),
      loadMediaForDive: (_) async => [
        _media('m1', takenAt: DateTime.utc(2025, 12, 27, 12, 8)),
        _media('m2', takenAt: DateTime.utc(2025, 12, 27, 12, 9)),
      ],
      saveEnrichments: (rows) async => batches.add(rows),
    );

    final count = await enricher.enrichMissingForDive('d1');

    expect(count, 2);
    expect(batches, hasLength(1), reason: 'one save call for the whole dive');
    expect(batches.single.map((e) => e.mediaId), ['m1', 'm2']);
  });

  test('a dive with nothing to enrich never calls the save at all', () async {
    var calls = 0;
    final enricher = DiveMediaEnricher(
      loadDive: (_) async => _diveWithProfile(),
      loadMediaForDive: (_) async => [
        _media(
          'm1',
          takenAt: DateTime.utc(2025, 12, 27, 12, 8),
          enrichment: MediaEnrichment(
            id: 'e1',
            mediaId: 'm1',
            diveId: 'd1',
            elapsedSeconds: 2520,
            depthMeters: 20,
            temperatureCelsius: 26,
            timestampOffsetSeconds: 0,
            matchConfidence: MatchConfidence.exact,
            createdAt: DateTime.utc(2025),
          ),
        ),
      ],
      saveEnrichments: (rows) async => calls++,
    );

    expect(await enricher.enrichMissingForDive('d1'), 0);
    expect(
      calls,
      0,
      reason:
          'an empty batch must not reach the repository: even a no-op save '
          'would tick watchMediaChanges and invalidate the media providers',
    );
  });
}

/// Issue #1090: a diver can pin a media item to a moment in the dive when
/// the file's capture time is wrong or missing. The pin lives on the media
/// row, so the enricher (the only writer of enrichment rows) must derive
/// the row from it instead of from the capture time, and must not revert it
/// on the next backfill pass.
void manualPositionTests() {
  test(
    'positions a pinned item at its manual offset, not its capture time',
    () async {
      final saved = <MediaEnrichment>[];
      final enricher = DiveMediaEnricher(
        loadDive: (_) async => _diveWithProfile(),
        loadMediaForDive: (_) async => [
          // Capture time is a decade off; the diver pinned it 42 min in.
          _media(
            'm1',
            takenAt: DateTime.utc(2016, 1, 6, 0, 3),
          ).copyWith(manualElapsedSeconds: 2520),
        ],
        saveEnrichments: (rows) async => saved.addAll(rows),
      );

      expect(await enricher.enrichMissingForDive('d1'), 1);
      expect(saved.single.elapsedSeconds, 2520);
      expect(saved.single.depthMeters, 20.0);
      expect(saved.single.matchConfidence, MatchConfidence.manual);
    },
  );

  test('leaves a stored manual row alone when it already matches', () async {
    final saved = <MediaEnrichment>[];
    final enricher = DiveMediaEnricher(
      loadDive: (_) async => _diveWithProfile(),
      loadMediaForDive: (_) async => [
        _media(
          'm1',
          takenAt: DateTime.utc(2016, 1, 6, 0, 3),
          enrichment: MediaEnrichment(
            id: 'e1',
            mediaId: 'm1',
            diveId: 'd1',
            elapsedSeconds: 2520,
            depthMeters: 20,
            temperatureCelsius: 26,
            timestampOffsetSeconds: 0,
            matchConfidence: MatchConfidence.manual,
            createdAt: DateTime.utc(2025),
          ),
        ).copyWith(manualElapsedSeconds: 2520),
      ],
      saveEnrichments: (rows) async => saved.addAll(rows),
    );

    expect(await enricher.enrichMissingForDive('d1'), 0);
    expect(saved, isEmpty);
  });

  test('clearing the pin recomputes from the capture time again', () async {
    final saved = <MediaEnrichment>[];
    final enricher = DiveMediaEnricher(
      loadDive: (_) async => _diveWithProfile(),
      loadMediaForDive: (_) async => [
        _media(
          'm1',
          takenAt: DateTime.utc(2025, 12, 27, 12, 8),
          enrichment: MediaEnrichment(
            id: 'e1',
            mediaId: 'm1',
            diveId: 'd1',
            elapsedSeconds: 600,
            depthMeters: 20,
            matchConfidence: MatchConfidence.manual,
            createdAt: DateTime.utc(2025),
          ),
        ),
      ],
      saveEnrichments: (rows) async => saved.addAll(rows),
    );

    expect(await enricher.enrichMissingForDive('d1'), 1);
    expect(saved.single.id, 'e1');
    expect(saved.single.elapsedSeconds, 2520);
    expect(saved.single.matchConfidence, MatchConfidence.exact);
  });
}
