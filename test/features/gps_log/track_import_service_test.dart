import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/gps_log/data/repositories/gps_track_repository.dart';
import 'package:submersion/features/gps_log/data/services/track_import/parsed_track.dart';
import 'package:submersion/features/gps_log/data/services/track_import/track_import_service.dart';

import '../../helpers/test_database.dart';

Uint8List _bytes(String name) =>
    File('test/fixtures/gps_tracks/$name').readAsBytesSync();

Uint8List _utf8Bytes(String s) => Uint8List.fromList(utf8.encode(s));

void main() {
  late TrackImportService service;
  late GpsTrackRepository repo;

  setUp(() async {
    await setUpTestDatabase();
    repo = GpsTrackRepository();
    service = TrackImportService();
  });

  tearDown(tearDownTestDatabase);

  group('sniffFormat', () {
    test('recognises gpx by extension', () {
      expect(
        sniffFormat('track.gpx', _utf8Bytes('<gpx/>')),
        TrackFileFormat.gpx,
      );
    });

    test('recognises kml by extension', () {
      expect(
        sniffFormat('track.kml', _utf8Bytes('<kml/>')),
        TrackFileFormat.kml,
      );
    });

    test('recognises csv by extension', () {
      expect(
        sniffFormat('track.csv', _utf8Bytes('a,b,c')),
        TrackFileFormat.csv,
      );
    });

    test('recognises fit by its binary magic, not just the extension', () {
      // A FIT file carries ASCII ".FIT" at byte offset 8.
      final fit = Uint8List(16)..setAll(8, utf8.encode('.FIT'));
      expect(sniffFormat('download.bin', fit), TrackFileFormat.fit);
    });

    test('falls back to content sniffing for an unknown extension', () {
      expect(
        sniffFormat(
          'track.dat',
          _utf8Bytes('<?xml version="1.0"?><gpx><trk/></gpx>'),
        ),
        TrackFileFormat.gpx,
      );
    });

    test('returns null for something unrecognisable', () {
      expect(sniffFormat('notes.txt', _utf8Bytes('hello world')), isNull);
    });

    test('returns null for binary that is not FIT, without throwing', () {
      // utf8.decode on arbitrary bytes throws; sniffing must not.
      final noise = Uint8List.fromList([0xFF, 0xFE, 0x00, 0x01, 0x80]);
      expect(sniffFormat('mystery.bin', noise), isNull);
    });
  });

  group('overlapsMoreThan', () {
    test('detects a full overlap', () {
      expect(overlapsMoreThan(0, 100, 0, 100, 0.8), isTrue);
    });

    test('detects a 90 percent overlap', () {
      expect(overlapsMoreThan(0, 100, 10, 110, 0.8), isTrue);
    });

    test('rejects a 50 percent overlap', () {
      expect(overlapsMoreThan(0, 100, 50, 150, 0.8), isFalse);
    });

    test('rejects disjoint spans', () {
      expect(overlapsMoreThan(0, 100, 200, 300, 0.8), isFalse);
    });

    test('rejects touching-but-not-overlapping spans', () {
      expect(overlapsMoreThan(0, 100, 100, 200, 0.8), isFalse);
    });

    test('treats a short clip fully inside a long track as a duplicate', () {
      // Compared against the shorter span, so re-importing a subset is caught.
      expect(overlapsMoreThan(0, 1000, 400, 450, 0.8), isTrue);
    });
  });

  group('prepare', () {
    test('parses a GPX file into a candidate', () async {
      final candidate = await service.prepare(
        fileName: 'sample.gpx',
        bytes: _bytes('sample.gpx'),
      );
      expect(candidate.format, TrackFileFormat.gpx);
      expect(candidate.parsed.fixes.length, 3);
      expect(candidate.sourceRef, 'sample.gpx');
    });

    test('defaults the offset to device-local when no dives overlap', () async {
      final candidate = await service.prepare(
        fileName: 'sample.gpx',
        bytes: _bytes('sample.gpx'),
      );
      expect(
        candidate.tzOffsetMinutes,
        DateTime.now().timeZoneOffset.inMinutes,
      );
    });

    test('flags nothing as duplicate on an empty database', () async {
      final candidate = await service.prepare(
        fileName: 'sample.gpx',
        bytes: _bytes('sample.gpx'),
      );
      expect(candidate.duplicateOfTrackId, isNull);
    });

    test('rejects a timestamp-less file', () async {
      expect(
        () => service.prepare(
          fileName: 'no_time.gpx',
          bytes: _bytes('no_time.gpx'),
        ),
        throwsA(isA<TrackParseException>()),
      );
    });

    test('rejects an unrecognised file type', () async {
      expect(
        () =>
            service.prepare(fileName: 'notes.txt', bytes: _utf8Bytes('hello')),
        throwsA(isA<TrackParseException>()),
      );
    });
  });

  group('commit', () {
    test('writes a track with the right source and sourceRef', () async {
      final candidate = await service.prepare(
        fileName: 'sample.gpx',
        bytes: _bytes('sample.gpx'),
      );
      final id = await service.commit(candidate);

      final track = await repo.getTrack(id);
      expect(track!.source, 'gpx');
      expect(track.sourceRef, 'sample.gpx');
      expect(track.pointCount, 3);
      expect(track.name, 'Cozumel Day 3');
    });

    test(
      'converts fixes to wall-clock-as-UTC using the resolved offset',
      () async {
        final base = await service.prepare(
          fileName: 'sample.gpx',
          bytes: _bytes('sample.gpx'),
        );
        // Force UTC-5: 13:00 real UTC must land as 08:00 wall clock.
        final id = await service.commit(base.copyWith(tzOffsetMinutes: -300));

        final track = await repo.getTrack(id);
        final first = DateTime.fromMillisecondsSinceEpoch(
          track!.points.first.timestamp * 1000,
          isUtc: true,
        );
        expect(first.hour, 8);
        expect(track.tzOffsetMinutes, -300);
      },
    );

    test('flags a re-import of the same file as a duplicate', () async {
      final first = await service.prepare(
        fileName: 'sample.gpx',
        bytes: _bytes('sample.gpx'),
      );
      await service.commit(first);

      final second = await service.prepare(
        fileName: 'sample.gpx',
        bytes: _bytes('sample.gpx'),
      );
      expect(second.duplicateOfTrackId, isNotNull);
    });

    test(
      'does not flag an overlapping track from a different source',
      () async {
        final gpx = await service.prepare(
          fileName: 'sample.gpx',
          bytes: _bytes('sample.gpx'),
        );
        await service.commit(gpx);

        // Same times arriving as CSV: a phone and a handheld recording the
        // same boat day are two legitimate records, not a duplicate.
        final csv = await service.prepare(
          fileName: 'sample.csv',
          bytes: _bytes('sample.csv'),
        );
        expect(csv.duplicateOfTrackId, isNull);
      },
    );

    test('imports a KML gx:Track end to end', () async {
      final candidate = await service.prepare(
        fileName: 'sample.kml',
        bytes: _bytes('sample.kml'),
      );
      final id = await service.commit(candidate);

      final track = await repo.getTrack(id);
      expect(track!.source, 'kml');
      expect(track.points.length, 3);
      // Axis order preserved through the whole pipeline.
      expect(track.points.first.latitude, closeTo(20.50, 1e-9));
      expect(track.points.first.longitude, closeTo(-87.25, 1e-9));
    });
  });
}
