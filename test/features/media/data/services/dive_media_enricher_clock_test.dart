import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/media/data/services/dive_media_enricher.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';

/// Issue #4539: a dive logged at 09:04:00 whose computer began recording at
/// 09:04:39. The profile counts from the computer's entry, so depth follows
/// the seconds since 09:04:39: one metre every ten seconds here.
Dive _dive({int mediaTimeOffsetSeconds = 0}) => Dive(
  id: 'd1',
  dateTime: DateTime.utc(2026, 5, 6, 9, 4),
  entryTime: DateTime.utc(2026, 5, 6, 9, 4),
  mediaTimeOffsetSeconds: mediaTimeOffsetSeconds,
  profile: const [
    DiveProfilePoint(timestamp: 0, depth: 0),
    DiveProfilePoint(timestamp: 250, depth: 25),
    DiveProfilePoint(timestamp: 300, depth: 30),
    DiveProfilePoint(timestamp: 339, depth: 33),
    DiveProfilePoint(timestamp: 600, depth: 0),
  ],
);

final _computerEntry = DateTime.utc(2026, 5, 6, 9, 4, 39);

MediaItem _media({
  required DateTime takenAt,
  int? manualElapsedSeconds,
  MediaType mediaType = MediaType.photo,
}) => MediaItem(
  id: 'm1',
  diveId: 'd1',
  mediaType: mediaType,
  sourceType: MediaSourceType.localFile,
  takenAt: takenAt,
  manualElapsedSeconds: manualElapsedSeconds,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

DiveMediaEnricher _enricher({
  required Dive? dive,
  required MediaItem item,
  required List<MediaEnrichment> saved,
  DateTime? primarySourceEntry,
}) => DiveMediaEnricher(
  loadDive: (_) async => dive,
  loadMediaForDive: (_) async => [item],
  loadPrimarySourceEntry: (_) async => primarySourceEntry,
  saveEnrichments: (rows) async => saved.addAll(rows),
);

void main() {
  group('enrichMissingForDive', () {
    test('counts from when the primary computer began recording', () async {
      final saved = <MediaEnrichment>[];
      final enricher = _enricher(
        dive: _dive(),
        // 09:09:39 is 339 s after 09:04:00 but 300 s after 09:04:39.
        item: _media(takenAt: DateTime.utc(2026, 5, 6, 9, 9, 39)),
        saved: saved,
        primarySourceEntry: _computerEntry,
      );

      await enricher.enrichMissingForDive('d1');

      expect(saved.single.elapsedSeconds, 300);
      expect(saved.single.depthMeters, 30);
    });

    test('counts from the dive start when it has no primary source', () async {
      final saved = <MediaEnrichment>[];
      final enricher = _enricher(
        dive: _dive(),
        item: _media(takenAt: DateTime.utc(2026, 5, 6, 9, 9, 39)),
        saved: saved,
      );

      await enricher.enrichMissingForDive('d1');

      expect(saved.single.elapsedSeconds, 339);
      expect(saved.single.depthMeters, 33);
    });

    // The camera ran 50 seconds ahead of the computer, so its 09:09:39 was
    // the computer's 09:08:49: 250 s into the dive.
    test("moves a capture time by the dive's media time shift", () async {
      final saved = <MediaEnrichment>[];
      final enricher = _enricher(
        dive: _dive(mediaTimeOffsetSeconds: -50),
        item: _media(takenAt: DateTime.utc(2026, 5, 6, 9, 9, 39)),
        saved: saved,
        primarySourceEntry: _computerEntry,
      );

      await enricher.enrichMissingForDive('d1');

      expect(saved.single.elapsedSeconds, 250);
      expect(saved.single.depthMeters, 25);
    });

    // A pin is the diver's statement about one item; the dive's shift
    // corrects capture times, and a pinned item is not placed by its own.
    test('leaves a pinned item where the diver pinned it', () async {
      final saved = <MediaEnrichment>[];
      final enricher = _enricher(
        dive: _dive(mediaTimeOffsetSeconds: -50),
        item: _media(
          takenAt: DateTime.utc(2026, 5, 6, 9, 9, 39),
          manualElapsedSeconds: 340,
        ),
        saved: saved,
        primarySourceEntry: _computerEntry,
      );

      await enricher.enrichMissingForDive('d1');

      expect(saved.single.elapsedSeconds, 340);
      expect(saved.single.matchConfidence, MatchConfidence.manual);
    });
  });

  group('automaticTimeFor', () {
    test("is the item's place by capture time, with the dive shift", () async {
      final item = _media(takenAt: DateTime.utc(2026, 5, 6, 9, 9, 39));
      final enricher = _enricher(
        dive: _dive(mediaTimeOffsetSeconds: -50),
        item: item,
        saved: [],
        primarySourceEntry: _computerEntry,
      );

      final automatic = await enricher.automaticTimeFor(item);

      expect(automatic!.elapsedSeconds, 250);
      expect(automatic.diveShiftSeconds, -50);
    });

    test("ignores the item's own pin", () async {
      final item = _media(
        takenAt: DateTime.utc(2026, 5, 6, 9, 9, 39),
        manualElapsedSeconds: 10,
      );
      final enricher = _enricher(
        dive: _dive(),
        item: item,
        saved: [],
        primarySourceEntry: _computerEntry,
      );

      expect((await enricher.automaticTimeFor(item))!.elapsedSeconds, 300);
    });

    test('is null for an item with no dive', () async {
      final item = MediaItem(
        id: 'm1',
        mediaType: MediaType.photo,
        sourceType: MediaSourceType.localFile,
        takenAt: DateTime.utc(2026, 5, 6, 9, 9, 39),
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      );
      final enricher = _enricher(dive: _dive(), item: item, saved: []);

      expect(await enricher.automaticTimeFor(item), isNull);
    });

    test('is null when the dive is gone or has no profile', () async {
      final item = _media(takenAt: DateTime.utc(2026, 5, 6, 9, 9, 39));

      expect(
        await _enricher(
          dive: null,
          item: item,
          saved: [],
        ).automaticTimeFor(item),
        isNull,
      );
      expect(
        await _enricher(
          dive: Dive(id: 'd1', dateTime: DateTime.utc(2026, 5, 6, 9, 4)),
          item: item,
          saved: [],
        ).automaticTimeFor(item),
        isNull,
      );
    });

    test('is null for a signature, which has no moment in the dive', () async {
      final item = _media(
        takenAt: DateTime.utc(2026, 5, 6, 9, 9, 39),
        mediaType: MediaType.instructorSignature,
      );

      expect(
        await _enricher(
          dive: _dive(),
          item: item,
          saved: [],
        ).automaticTimeFor(item),
        isNull,
      );
    });

    test('a read-only enricher offers none', () async {
      final item = _media(takenAt: DateTime.utc(2026, 5, 6, 9, 9, 39));

      expect(await ReadOnlyDiveMediaEnricher().automaticTimeFor(item), isNull);
    });
  });
}
