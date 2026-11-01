import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/insights/data/repositories/insights_repository.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late InsightsRepository repo;
  late ProfileSeriesRepository seriesRepository;

  setUp(() async {
    db = await setUpTestDatabase();
    repo = InsightsRepository();
    seriesRepository = ProfileSeriesRepository();
  });
  tearDown(() async {
    await tearDownTestDatabase();
  });

  final now = DateTime(2026, 6, 1).millisecondsSinceEpoch;

  Future<void> dive(String id) async {
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(id),
            diveDateTime: Value(now),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  /// Inserts one series from (timestamp, depth, decoType, ceiling) tuples.
  Future<void> profile(
    String diveId,
    List<(int, double, int?, double?)> samples,
  ) async {
    await seriesRepository.insertSeries(
      diveId: diveId,
      samples: [
        for (final (ts, depth, decoType, ceiling) in samples)
          ProfileSample(
            timestamp: ts,
            depth: depth,
            decoType: decoType,
            ceiling: ceiling,
          ),
      ],
      now: now,
    );
  }

  Future<void> decoStopEvent(String diveId) async {
    await db
        .into(db.diveProfileEvents)
        .insert(
          DiveProfileEventsCompanion(
            id: Value('$diveId-evt'),
            diveId: Value(diveId),
            timestamp: const Value(600),
            eventType: const Value('decoStopStart'),
            createdAt: Value(now),
          ),
        );
  }

  group('scanRecordedDecoSignals', () {
    test('a safety stop is not a decompression obligation', () async {
      await dive('safety');
      // deco_type 1 is DC_DECO_SAFETYSTOP; the mapper writes ceiling for it.
      await profile('safety', [
        (0, 10.0, 0, null),
        (300, 30.0, 0, null),
        (600, 5.0, 1, 5.0),
      ]);

      final scan = await repo.scanRecordedDecoSignals();

      expect(scan.recordedDeco, isEmpty);
      expect(scan.recordedNoDeco, {'safety'});
    });

    test('a deco stop sample is a decompression obligation', () async {
      await dive('deco');
      await profile('deco', [(0, 10.0, 0, null), (300, 45.0, 2, 9.0)]);

      final scan = await repo.scanRecordedDecoSignals();

      expect(scan.recordedDeco, {'deco'});
      expect(scan.recordedNoDeco, isEmpty);
    });

    test('a decoStopStart event is a decompression obligation', () async {
      await dive('evt');
      await profile('evt', [(0, 10.0, null, null)]);
      await decoStopEvent('evt');

      final scan = await repo.scanRecordedDecoSignals();

      expect(scan.recordedDeco, {'evt'});
      expect(scan.needsCompute, isEmpty);
    });

    test(
      'ceiling alone counts only when the source wrote no decoType',
      () async {
        await dive('ceilingOnly');
        // Subsurface XML and DAN DL7 write ceiling without any decoType.
        await profile('ceilingOnly', [
          (0, 10.0, null, null),
          (300, 45.0, null, 9.0),
        ]);

        final scan = await repo.scanRecordedDecoSignals();

        expect(scan.recordedDeco, {'ceilingOnly'});
      },
    );

    test('a profile with no deco signal at all needs computing', () async {
      await dive('bare');
      await profile('bare', [(0, 10.0, null, null), (300, 45.0, null, null)]);

      final scan = await repo.scanRecordedDecoSignals();

      expect(scan.needsCompute.keys, {'bare'});
      // The dive's own stamp plus its one profile series.
      expect(scan.needsCompute['bare'], now * 2);
      expect(scan.recordedNoDeco, isEmpty);
      expect(scan.noProfile, isEmpty);
    });

    group('the revision (#3924)', () {
      Future<int> revision() async =>
          (await repo.scanRecordedDecoSignals()).needsCompute['bare']!;

      setUp(() async {
        await dive('bare');
        await profile('bare', [(0, 10.0, null, null)]);
        await db
            .into(db.dives)
            .insert(
              DivesCompanion(
                id: const Value('earlier'),
                diveDateTime: Value(
                  now - const Duration(hours: 6).inMilliseconds,
                ),
                createdAt: Value(now),
                updatedAt: Value(now),
              ),
            );
      });

      test('moves with a write to a dive in the lookback', () async {
        final before = await revision();

        await db.customStatement(
          "UPDATE dives SET updated_at = updated_at + 5 WHERE id = 'earlier'",
        );

        expect(await revision(), isNot(before));
      });

      test('moves on a write stamped older than the dive itself', () async {
        await db.customStatement(
          "UPDATE dives SET updated_at = $now + 1000 WHERE id = 'bare'",
        );
        final before = await revision();

        await db.customStatement(
          "UPDATE dives SET updated_at = updated_at - 5 WHERE id = 'earlier'",
        );

        expect(await revision(), isNot(before));
      });

      test('moves on a profile that does not re-stamp its dive', () async {
        final before = await revision();

        await profile('earlier', [(0, 10.0, null, null)]);

        expect(await revision(), isNot(before));
      });

      test("moves on the dive's own profile too", () async {
        final before = await revision();

        await db.customStatement(
          "UPDATE dive_profile_series SET updated_at = updated_at + 5 "
          "WHERE dive_id = 'bare'",
        );

        expect(await revision(), isNot(before));
      });
    });

    test('a dive with no profile is unclassifiable', () async {
      await dive('manual');

      final scan = await repo.scanRecordedDecoSignals();

      expect(scan.noProfile, {'manual'});
      expect(scan.needsCompute, isEmpty);
    });
  });

  group('getDecoObligationStats', () {
    test(
      'unclassifiable dives are reported separately, not as no-deco',
      () async {
        await dive('deco');
        await profile('deco', [(300, 45.0, 2, 9.0)]);
        await dive('manual');

        final stats = await repo.getDecoObligationStats();

        expect(stats.decoCount, 1);
        expect(stats.noDecoCount, 0);
        expect(stats.unknownCount, 1);
      },
    );

    test('honours the diver filter', () async {
      await db
          .into(db.divers)
          .insert(
            DiversCompanion(
              id: const Value('diver-a'),
              name: const Value('A'),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
      await db
          .into(db.dives)
          .insert(
            DivesCompanion(
              id: const Value('mine'),
              diveDateTime: Value(now),
              diverId: const Value('diver-a'),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
      await profile('mine', [(300, 45.0, 2, 9.0)]);
      await dive('theirs');
      await profile('theirs', [(300, 45.0, 2, 9.0)]);

      final stats = await repo.getDecoObligationStats(
        diverId: 'diver-a',
        filter: const DiveFilterState(),
      );

      expect(stats.decoCount, 1);
      expect(stats.unknownCount, 0);
      expect(stats.noDecoCount, 0);
    });
  });
}
