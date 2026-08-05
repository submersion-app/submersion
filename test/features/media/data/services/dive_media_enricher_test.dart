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
  test('enriches a linked item that has no enrichment yet', () async {
    final saved = <MediaEnrichment>[];
    final enricher = DiveMediaEnricher(
      loadDive: (_) async => _diveWithProfile(),
      loadMediaForDive: (_) async => [
        // Shutter at 12:08 == 2520s (42 min) after the 11:26 entry.
        _media('m1', takenAt: DateTime.utc(2025, 12, 27, 12, 8)),
      ],
      saveEnrichment: (e) async => saved.add(e),
    );

    final count = await enricher.enrichMissingForDive('d1');

    expect(count, 1);
    expect(saved, hasLength(1));
    expect(saved.single.mediaId, 'm1');
    expect(saved.single.diveId, 'd1');
    expect(saved.single.elapsedSeconds, 2520);
    expect(saved.single.depthMeters, 20.0);
  });

  test('is idempotent: skips items already enriched', () async {
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
            matchConfidence: MatchConfidence.exact,
            createdAt: DateTime.utc(2025),
          ),
        ),
      ],
      saveEnrichment: (e) async => saved.add(e),
    );

    expect(await enricher.enrichMissingForDive('d1'), 0);
    expect(saved, isEmpty);
  });

  test('returns 0 and saves nothing when the dive has no profile', () async {
    final saved = <MediaEnrichment>[];
    final enricher = DiveMediaEnricher(
      loadDive: (_) async => Dive(id: 'd1', dateTime: DateTime.utc(2025)),
      loadMediaForDive: (_) async => [
        _media('m1', takenAt: DateTime.utc(2025, 12, 27, 12, 8)),
      ],
      saveEnrichment: (e) async => saved.add(e),
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
      saveEnrichment: (e) async => saved.add(e),
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
      saveEnrichment: (e) async => saved.add(e),
    );

    expect(await enricher.enrichMissingForDive('d1'), 0);
    expect(saved, isEmpty);
  });
}
