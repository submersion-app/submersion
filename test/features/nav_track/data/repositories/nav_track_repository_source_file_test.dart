import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:submersion/core/services/sync/sync_clock.dart';
import 'package:submersion/features/nav_track/data/repositories/nav_track_repository.dart';
import 'package:submersion/features/nav_track/data/services/parsers/seacraft_enc_csv_parser.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track_marker.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track_point.dart';
import 'package:submersion/features/nav_track/domain/nav_track_corrector.dart';

import '../../../../helpers/test_database.dart';

Uint8List _fixture(String name) =>
    File(p.join('test', 'fixtures', 'nav_tracks', name)).readAsBytesSync();

/// `nav_tracks.source_file` (issue #4231): the original file a route was
/// imported from, kept byte for byte so its points can be derived again,
/// its markers read and the file exported unchanged.
void main() {
  late NavTrackRepository repo;

  setUp(() async {
    await setUpTestDatabase();
    SyncClock.instance.configure(nodeId: 'node-test', now: () => 1000);
    repo = NavTrackRepository();
  });

  tearDown(() async {
    SyncClock.instance.reset();
    await tearDownTestDatabase();
  });

  Future<List<NavTrackMarker>> markersOf(String id) async =>
      repo.getMarkers((await repo.getById(id))!);

  Future<String> insertFixture(String name, {bool withFile = true}) {
    final bytes = _fixture(name);
    return repo.insertImportedRoute(
      points: parseSeacraftEncCsv(bytes).points,
      source: NavTrackSource.seacraftEnc,
      sourceRef: name,
      sourceFile: withFile ? bytes : null,
    );
  }

  group('storing the original file', () {
    test('hands the file back byte for byte', () async {
      final id = await insertFixture('seacraft_enc3_gps_fix.csv');

      expect(
        await repo.getSourceFile(id),
        _fixture('seacraft_enc3_gps_fix.csv'),
      );
    });

    test('a route imported without a file has none', () async {
      final id = await insertFixture('seacraft_enc3_real.csv', withFile: false);

      expect(await repo.getSourceFile(id), isNull);
      expect((await repo.getById(id))!.hasSourceFile, isFalse);
    });

    test('a missing route has no file', () async {
      expect(await repo.getSourceFile('nope'), isNull);
    });

    test(
      'a list read says whether a file is kept without loading it',
      () async {
        final withFile = await insertFixture('seacraft_enc3_gps_fix.csv');
        final without = await insertFixture(
          'seacraft_enc3_real.csv',
          withFile: false,
        );

        final listed = {
          for (final route in await repo.getAll()) route.id: route,
        };

        expect(listed[withFile]!.hasSourceFile, isTrue);
        expect(listed[without]!.hasSourceFile, isFalse);
        // A list row hydrates neither the points nor the markers.
        expect(listed[withFile]!.points, isEmpty);
        expect(listed[withFile]!.markers, isEmpty);
      },
    );
  });

  group('markers', () {
    test('a detail read leaves the markers to getMarkers', () async {
      final id = await insertFixture('seacraft_enc3_gps_fix.csv');

      // getById hydrates points for thumbnails and maps too, which draw no
      // markers, so it never parses the file.
      expect((await repo.getById(id))!.markers, isEmpty);
      expect(await markersOf(id), hasLength(2));
    });

    test('getMarkers reads the markers of the stored file', () async {
      final id = await insertFixture('seacraft_enc3_gps_fix.csv');

      final route = (await repo.getById(id))!;
      final markers = await repo.getMarkers(route);

      expect(markers.map((m) => m.rawValue), [-1, -101]);
      expect(route.points[markers.first.index].batteryVolts, isNull);
    });

    test('shows no markers when the stored points do not derive from the '
        'stored file', () async {
      // Points of one recording next to the file of another: what a sync
      // conflict that kept each from a different side, or a parser that
      // maps rows to samples differently, would leave behind.
      final id = await repo.insertImportedRoute(
        points: parseSeacraftEncCsv(_fixture('seacraft_enc3_bench.csv')).points,
        source: NavTrackSource.seacraftEnc,
        sourceRef: 'seacraft_enc3_gps_fix.csv',
        sourceFile: _fixture('seacraft_enc3_gps_fix.csv'),
      );

      expect(await markersOf(id), isEmpty);
    });

    test('a new file on the same route brings its own markers', () async {
      final id = await insertFixture('seacraft_enc3_bench.csv');
      expect(await markersOf(id), isEmpty);
      final bytes = _fixture('seacraft_enc3_gps_fix.csv');

      await repo.updateImportedData(
        id,
        points: parseSeacraftEncCsv(bytes).points,
        sourceFile: bytes,
      );

      expect(await markersOf(id), hasLength(2));
    });

    test('a route without a file shows no markers', () async {
      final id = await insertFixture('seacraft_enc3_real.csv', withFile: false);

      expect(await markersOf(id), isEmpty);
    });

    test('an unparseable stored file shows no markers instead of failing the '
        'read', () async {
      final id = await repo.insertImportedRoute(
        points: const [
          NavTrackPoint(timestamp: 0, north: 0, east: 0, depth: 2),
          NavTrackPoint(timestamp: 2, north: 1, east: 0, depth: 2),
        ],
        source: NavTrackSource.seacraftEnc,
        sourceRef: 'broken.csv',
        sourceFile: Uint8List.fromList(utf8.encode('not,a,route\n1,2,3')),
      );

      final route = (await repo.getById(id))!;

      expect(await repo.getMarkers(route), isEmpty);
      expect(route.points, hasLength(2));
    });
  });

  group('updateImportedData', () {
    test('replaces the data and keeps every setting', () async {
      final id = await repo.insertImportedRoute(
        points: const [
          NavTrackPoint(timestamp: 100, north: 0, east: 0, depth: 2),
          NavTrackPoint(timestamp: 102, north: 1, east: 0, depth: 2),
        ],
        source: NavTrackSource.seacraftEnc,
        sourceRef: '011.DAT.csv',
        name: 'My track',
      );
      const correction = NavTrackCorrection(
        endMode: NavTrackEndMode.sameAsStart,
        trustFraction: 0.4,
        headingOffsetDeg: 12,
        scaleFactor: 1.1,
      );
      await repo.updateCorrection(id, correction);
      final bytes = _fixture('seacraft_enc3_gps_fix.csv');
      final parsed = parseSeacraftEncCsv(bytes);

      final updated = await repo.updateImportedData(
        id,
        points: parsed.points,
        sourceFile: bytes,
      );

      expect(updated, isTrue);
      final route = (await repo.getById(id))!;
      expect(route.pointCount, parsed.points.length);
      expect(route.points, parsed.points);
      expect(route.startTime, parsed.points.first.timestamp * 1000);
      expect(route.endTime, parsed.points.last.timestamp * 1000);
      expect(route.totalDistance, isNotNull);
      expect(await repo.getMarkers(route), hasLength(2));
      expect(await repo.getSourceFile(id), bytes);
      // Settings stay.
      expect(route.name, 'My track');
      expect(route.sourceRef, '011.DAT.csv');
      expect(route.endMode, NavTrackEndMode.sameAsStart);
      expect(route.trustFraction, 0.4);
      expect(route.headingOffsetDeg, 12);
      expect(route.scaleFactor, 1.1);
    });

    test('records a new file name when one is given', () async {
      final id = await insertFixture('seacraft_enc3_gps_fix.csv');
      final bytes = _fixture('seacraft_enc3_gps_fix.csv');

      await repo.updateImportedData(
        id,
        points: parseSeacraftEncCsv(bytes).points,
        sourceFile: bytes,
        sourceRef: 'renamed.csv',
      );

      expect((await repo.getById(id))!.sourceRef, 'renamed.csv');
    });

    test('returns false for a route that no longer exists', () async {
      final bytes = _fixture('seacraft_enc3_gps_fix.csv');

      final updated = await repo.updateImportedData(
        'gone',
        points: parseSeacraftEncCsv(bytes).points,
        sourceFile: bytes,
      );

      expect(updated, isFalse);
    });

    test('refuses a recording of fewer than two samples', () async {
      final id = await insertFixture('seacraft_enc3_gps_fix.csv');

      expect(
        () => repo.updateImportedData(
          id,
          points: const [
            NavTrackPoint(timestamp: 0, north: 0, east: 0, depth: 1),
          ],
          sourceFile: Uint8List(0),
        ),
        throwsArgumentError,
      );
    });
  });
}
