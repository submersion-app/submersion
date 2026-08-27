import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/gps_log/data/repositories/gps_track_repository.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';

import '../../helpers/test_database.dart';

void main() {
  late GpsTrackRepository repo;

  setUp(() async {
    await setUpTestDatabase();
    repo = GpsTrackRepository();
  });

  tearDown(tearDownTestDatabase);

  /// 08:00 to 12:00, one fix per hour, five fixes, recorded in UTC-5.
  Future<String> seed() async {
    final startMs = DateTime.utc(2026, 5, 22, 8).millisecondsSinceEpoch;
    final id = await repo.startTrack(
      startTimeMs: startMs,
      tzOffsetMinutes: -300,
    );
    for (var h = 0; h <= 4; h++) {
      await repo.appendBufferPoint(
        id,
        GpsTrackPoint(
          timestamp: startMs ~/ 1000 + h * 3600,
          latitude: 20.0 + h * 0.01,
          longitude: -87.0,
        ),
      );
    }
    await repo.finalizeTrack(
      id,
      endTimeMs: DateTime.utc(2026, 5, 22, 12).millisecondsSinceEpoch,
    );
    return id;
  }

  /// Same shape as [seed], but imported so it can carry a name - startTrack
  /// has no name parameter, recordings are named only on import.
  Future<String> seedNamed(String name) async {
    final startMs = DateTime.utc(2026, 5, 22, 8).millisecondsSinceEpoch;
    return repo.insertImportedTrack(
      points: [
        for (var h = 0; h <= 4; h++)
          GpsTrackPoint(
            timestamp: startMs ~/ 1000 + h * 3600,
            latitude: 20.0 + h * 0.01,
            longitude: -87.0,
          ),
      ],
      startTimeMs: startMs,
      endTimeMs: DateTime.utc(2026, 5, 22, 12).millisecondsSinceEpoch,
      tzOffsetMinutes: -300,
      source: 'import',
      name: name,
    );
  }

  final tenAm = DateTime.utc(2026, 5, 22, 10).millisecondsSinceEpoch;

  test('produces two tracks covering all the original fixes', () async {
    final id = await seed();
    final (firstId, secondId) = await repo.splitTrack(id, tenAm);

    final first = await repo.getTrack(firstId);
    final second = await repo.getTrack(secondId);
    expect(first!.points.length + second!.points.length, 5);
  });

  test('puts the split point in the first child', () async {
    final id = await seed();
    final (firstId, secondId) = await repo.splitTrack(id, tenAm);
    expect((await repo.getTrack(firstId))!.points.length, 3);
    expect((await repo.getTrack(secondId))!.points.length, 2);
  });

  test('tombstones the parent', () async {
    final id = await seed();
    await repo.splitTrack(id, tenAm);
    expect(await repo.getTrack(id), isNull);
  });

  test('children inherit tzOffsetMinutes and source', () async {
    final id = await seed();
    final (firstId, secondId) = await repo.splitTrack(id, tenAm);
    for (final childId in [firstId, secondId]) {
      final child = await repo.getTrack(childId);
      expect(child!.tzOffsetMinutes, -300);
      expect(child.source, 'phone');
    }
  });

  test('children get suffixed names when the parent had one', () async {
    final id = await seedNamed('Cozumel drift');
    final (firstId, secondId) = await repo.splitTrack(id, tenAm);
    expect((await repo.getTrack(firstId))!.name, 'Cozumel drift (1)');
    expect((await repo.getTrack(secondId))!.name, 'Cozumel drift (2)');
  });

  test('an unnamed parent produces unnamed children, not "null (1)"', () async {
    final id = await seed();
    final (firstId, secondId) = await repo.splitTrack(id, tenAm);
    expect((await repo.getTrack(firstId))!.name, isNull);
    expect((await repo.getTrack(secondId))!.name, isNull);
  });

  test('children exist before the parent is deleted', () async {
    // THE safety property. If this ordering ever inverts, a crash mid-split
    // destroys the track instead of duplicating it - and the final state
    // looks identical either way, so only the write order can prove it.
    final id = await seed();
    final observed = <String>[];
    repo.debugOnWrite = observed.add;

    await repo.splitTrack(id, tenAm);

    expect(observed.length, 3);
    expect(observed.last, 'delete:$id');
    expect(
      observed.sublist(0, 2).every((e) => e.startsWith('insert:')),
      isTrue,
    );
  });

  test('rejects a split point outside the track span', () async {
    final id = await seed();
    expect(
      () =>
          repo.splitTrack(id, DateTime.utc(2026, 5, 23).millisecondsSinceEpoch),
      throwsArgumentError,
    );
  });

  test('rejects a split before the first fix, which empties a child', () async {
    final id = await seed();
    expect(
      () => repo.splitTrack(
        id,
        DateTime.utc(2026, 5, 22, 7).millisecondsSinceEpoch,
      ),
      throwsArgumentError,
    );
  });

  test('splitting exactly on the first fix is allowed', () async {
    // The boundary fix goes to child one, leaving four in child two. A
    // one-point child is degenerate but not data loss, and every renderer
    // already falls back to a marker for it.
    final id = await seed();
    final (firstId, secondId) = await repo.splitTrack(
      id,
      DateTime.utc(2026, 5, 22, 8).millisecondsSinceEpoch,
    );
    expect((await repo.getTrack(firstId))!.points.length, 1);
    expect((await repo.getTrack(secondId))!.points.length, 4);
  });

  test('rejects splitting a track that does not exist', () async {
    expect(() => repo.splitTrack('nope', tenAm), throwsArgumentError);
  });

  test('splitting a trimmed track destroys nothing', () async {
    // Trim promises reversibility ("the points blob is never rewritten...
    // cannot lose a fix"). Building children from the trimmed VIEW and then
    // hard-deleting the parent would break that the first time anyone split
    // a trimmed track.
    final id = await seed();
    await repo.setTrimBounds(
      id,
      startMs: DateTime.utc(2026, 5, 22, 9).millisecondsSinceEpoch,
    );
    final (firstId, secondId) = await repo.splitTrack(id, tenAm);

    final first = await repo.getTrack(firstId);
    final second = await repo.getTrack(secondId);

    // All five raw fixes survive, split across the two children.
    expect(first!.points.length + second!.points.length, 5);
    // The trim still applies, so the 08:00 fix stays hidden.
    expect(first.effectivePoints.length + second.effectivePoints.length, 4);
  });

  test(
    'children carry the parent trim bounds, so Reset trim recovers',
    () async {
      final trimStart = DateTime.utc(2026, 5, 22, 9).millisecondsSinceEpoch;
      final id = await seed();
      await repo.setTrimBounds(id, startMs: trimStart);
      final (firstId, _) = await repo.splitTrack(id, tenAm);

      final first = await repo.getTrack(firstId);
      expect(first!.trimStartTime, trimStart);
      // 08:00 is present in the blob but hidden by the bound.
      expect(first.points.length, 3);
      expect(first.effectivePoints.length, 2);

      await repo.clearTrim(firstId);
      expect((await repo.getTrack(firstId))!.effectivePoints.length, 3);
    },
  );

  test('children inherit deviceName', () async {
    final startMs = DateTime.utc(2026, 5, 22, 8).millisecondsSinceEpoch;
    final id = await repo.startTrack(
      startTimeMs: startMs,
      tzOffsetMinutes: 0,
      deviceName: 'Pixel 9',
    );
    for (var h = 0; h <= 2; h++) {
      await repo.appendBufferPoint(
        id,
        GpsTrackPoint(
          timestamp: startMs ~/ 1000 + h * 3600,
          latitude: 20.0,
          longitude: -87.0,
        ),
      );
    }
    await repo.finalizeTrack(id, endTimeMs: startMs + 7200000);

    final (firstId, secondId) = await repo.splitTrack(id, startMs + 3600000);
    expect((await repo.getTrack(firstId))!.deviceName, 'Pixel 9');
    expect((await repo.getTrack(secondId))!.deviceName, 'Pixel 9');
  });
}
