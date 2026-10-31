import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/source_clock_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_series_repository.dart';
import 'package:submersion/features/dive_log/data/services/dive_consolidation_service.dart';
import 'package:submersion/features/dive_log/data/services/dive_split_service.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/codecs/tank_pressure_series_codec.dart';

import '../../../../helpers/test_database.dart';

/// Consolidation slides a folded-in computer onto the target's timeline and
/// records the shift; moving that source back to a dive of its own has to
/// take the shift off again (issue #3916). Every test drives the real
/// consolidation first, so what is split is what a diver actually stores.
void main() {
  late AppDatabase db;
  late DiveRepository repository;
  late DiveConsolidationService consolidation;
  late DiveSplitService splitter;
  late ProfileSeriesRepository profileSeries;
  late TankPressureSeriesRepository tankSeries;

  final tenOClock = DateTime.utc(2026, 5, 7, 10);
  int minutesIn(int minutes) =>
      tenOClock.add(Duration(minutes: minutes)).millisecondsSinceEpoch;

  /// A computer's own recording of [runtime] seconds, entered [startMinutes]
  /// after ten o'clock: samples at 0, the middle and the end on its own
  /// clock, a pressure at each end, a bookmark at 10 and a gas switch at 20.
  /// [withWindow] false leaves the times to the dive's date and gives it no
  /// source row, as a manual or file-imported dive has.
  Future<void> seedRecording(
    String id, {
    required int startMinutes,
    int runtime = 600,
    bool withWindow = true,
  }) async {
    final start = minutesIn(startMinutes);
    final computerId = 'dc-$id';
    await db
        .into(db.diveComputers)
        .insert(
          DiveComputersCompanion.insert(
            id: computerId,
            name: computerId,
            createdAt: 1,
            updatedAt: 1,
          ),
        );
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(id),
            diveDateTime: Value(start),
            computerId: Value(computerId),
            entryTime: Value(withWindow ? start : null),
            exitTime: Value(withWindow ? start + runtime * 1000 : null),
            runtime: Value(runtime),
            maxDepth: const Value(20),
            createdAt: const Value(1),
            updatedAt: const Value(1),
          ),
        );
    final sourceId = 'src-$id';
    if (withWindow) {
      await db
          .into(db.diveDataSources)
          .insert(
            DiveDataSourcesCompanion(
              id: Value(sourceId),
              diveId: Value(id),
              computerId: Value(computerId),
              isPrimary: const Value(true),
              duration: Value(runtime),
              entryTime: Value(DateTime.fromMillisecondsSinceEpoch(start)),
              exitTime: Value(
                DateTime.fromMillisecondsSinceEpoch(start + runtime * 1000),
              ),
              importedAt: Value(tenOClock),
              createdAt: Value(tenOClock.add(Duration(minutes: startMinutes))),
            ),
          );
    }
    final tankId = 'tank-$id';
    await db
        .into(db.diveTanks)
        .insert(
          DiveTanksCompanion(
            id: Value(tankId),
            diveId: Value(id),
            computerId: Value(computerId),
            sourceId: Value(withWindow ? sourceId : null),
            tankOrder: const Value(0),
          ),
        );
    await profileSeries.insertSeries(
      diveId: id,
      computerId: computerId,
      sourceId: withWindow ? sourceId : null,
      samples: [
        const ProfileSample(timestamp: 0, depth: 0),
        ProfileSample(timestamp: runtime ~/ 2, depth: 20),
        ProfileSample(timestamp: runtime, depth: 0),
      ],
    );
    await tankSeries.insertSeries(
      diveId: id,
      tankId: tankId,
      computerId: computerId,
      sourceId: withWindow ? sourceId : null,
      samples: [
        const TankPressureSample(timestamp: 0, pressure: 200),
        TankPressureSample(timestamp: runtime, pressure: 80),
      ],
    );
    await db
        .into(db.diveProfileEvents)
        .insert(
          DiveProfileEventsCompanion(
            id: Value('ev-$id'),
            diveId: Value(id),
            computerId: Value(computerId),
            timestamp: const Value(10),
            eventType: const Value('bookmark'),
            createdAt: const Value(1),
          ),
        );
    await db
        .into(db.gasSwitches)
        .insert(
          GasSwitchesCompanion(
            id: Value('gs-$id'),
            diveId: Value(id),
            computerId: Value(computerId),
            timestamp: const Value(20),
            tankId: Value(tankId),
            createdAt: const Value(1),
          ),
        );
  }

  Future<DiveDataSourcesData> sourceOf(String diveId, String computerId) async {
    final rows = await (db.select(
      db.diveDataSources,
    )..where((t) => t.diveId.equals(diveId))).get();
    return rows.singleWhere((s) => s.computerId == computerId);
  }

  Future<Dive> diveRow(String id) =>
      (db.select(db.dives)..where((t) => t.id.equals(id))).getSingle();

  Future<List<int>> profileTimes(String diveId, String computerId) async => [
    for (final s in await profileSeries.getSeriesForDive(diveId))
      if (s.computerId == computerId)
        for (final p in s.samples) p.timestamp,
  ];

  Future<List<int>> pressureTimes(String diveId, String computerId) async => [
    for (final s in await tankSeries.getSeriesForDive(diveId))
      if (s.computerId == computerId)
        for (final p in s.samples) p.timestamp,
  ];

  Future<List<int>> eventTimes(String diveId, String computerId) async => [
    for (final e in await (db.select(
      db.diveProfileEvents,
    )..where((t) => t.diveId.equals(diveId))).get())
      if (e.computerId == computerId) e.timestamp,
  ];

  Future<List<int>> switchTimes(String diveId, String computerId) async => [
    for (final s in await (db.select(
      db.gasSwitches,
    )..where((t) => t.diveId.equals(diveId))).get())
      if (s.computerId == computerId) s.timestamp,
  ];

  /// Every timeline-bearing child of [computerId] on [diveId], asserted to
  /// sit where a recording seeded by [seedRecording] sits on its own clock,
  /// plus [shift].
  Future<void> expectOnOwnClock(
    String diveId,
    String computerId, {
    int shift = 0,
  }) async {
    expect(await profileTimes(diveId, computerId), [
      0 + shift,
      300 + shift,
      600 + shift,
    ], reason: 'profile samples');
    expect(await pressureTimes(diveId, computerId), [
      0 + shift,
      600 + shift,
    ], reason: 'pressure samples');
    expect(await eventTimes(diveId, computerId), [
      10 + shift,
    ], reason: 'profile events');
    expect(await switchTimes(diveId, computerId), [
      20 + shift,
    ], reason: 'gas switches');
  }

  setUp(() async {
    db = await setUpTestDatabase();
    repository = DiveRepository();
    consolidation = DiveConsolidationService(repository);
    splitter = DiveSplitService(repository);
    profileSeries = ProfileSeriesRepository();
    tankSeries = TankPressureSeriesRepository();
  });

  tearDown(tearDownTestDatabase);

  group('splitting a secondary source', () {
    test('puts it back on its own clock (#3916)', () async {
      await seedRecording('a', startMinutes: 0);
      await seedRecording('b', startMinutes: 2);
      await consolidation.apply(targetDiveId: 'a', secondaryDiveIds: ['b']);
      await expectOnOwnClock('a', 'dc-b', shift: 120);

      final source = await sourceOf('a', 'dc-b');
      final newDive = await splitter.split(diveId: 'a', sourceId: source.id);

      final dive = await diveRow(newDive);
      expect(dive.diveDateTime, minutesIn(2));
      expect(dive.entryTime, minutesIn(2));
      expect(dive.exitTime, minutesIn(2) + 600 * 1000);
      await expectOnOwnClock(newDive, 'dc-b');
      expect((await sourceOf(newDive, 'dc-b')).timeOffsetSeconds ?? 0, 0);
    });

    test('leaves the dive it came from where it was', () async {
      await seedRecording('a', startMinutes: 0);
      await seedRecording('b', startMinutes: 2);
      await consolidation.apply(targetDiveId: 'a', secondaryDiveIds: ['b']);

      final source = await sourceOf('a', 'dc-b');
      await splitter.split(diveId: 'a', sourceId: source.id);

      final dive = await diveRow('a');
      expect(dive.diveDateTime, minutesIn(0));
      expect(dive.entryTime, minutesIn(0));
      await expectOnOwnClock('a', 'dc-a');
    });

    test('undoes a negative offset, for a computer started first', () async {
      await seedRecording('a', startMinutes: 2);
      await seedRecording('b', startMinutes: 0);
      await consolidation.apply(targetDiveId: 'a', secondaryDiveIds: ['b']);
      await expectOnOwnClock('a', 'dc-b', shift: -120);

      final source = await sourceOf('a', 'dc-b');
      final newDive = await splitter.split(diveId: 'a', sourceId: source.id);

      expect((await diveRow(newDive)).entryTime, minutesIn(0));
      await expectOnOwnClock(newDive, 'dc-b');
    });

    test('takes off a composed offset, from a target that was itself '
        'consolidated', () async {
      await seedRecording('a', startMinutes: 0);
      await seedRecording('b', startMinutes: 2);
      await seedRecording('c', startMinutes: 3);
      await consolidation.apply(targetDiveId: 'b', secondaryDiveIds: ['c']);
      await consolidation.apply(targetDiveId: 'a', secondaryDiveIds: ['b']);

      final source =
          (await (db.select(
            db.diveDataSources,
          )..where((t) => t.sourceFileName.isNull())).get()).singleWhere(
            (s) => s.id != 'src-a' && s.computerId == 'dc-c',
          );
      expect(source.timeOffsetSeconds, 180);

      final newDive = await splitter.split(diveId: 'a', sourceId: source.id);

      expect((await diveRow(newDive)).entryTime, minutesIn(3));
      expect(await profileTimes(newDive, 'dc-c'), [0, 300, 600]);
      expect(await pressureTimes(newDive, 'dc-b'), [0, 600]);
    });

    test('a source with no window of its own is placed by its offset, since '
        'its samples go back to its own clock either way', () async {
      await seedRecording('a', startMinutes: 0);
      await seedRecording('b', startMinutes: 2, withWindow: false);
      await consolidation.apply(targetDiveId: 'a', secondaryDiveIds: ['b']);
      final source = await sourceOf('a', 'dc-b');
      expect(source.entryTime, isNull);
      expect(source.timeOffsetSeconds, 120);

      final newDive = await splitter.split(diveId: 'a', sourceId: source.id);

      final dive = await diveRow(newDive);
      expect(dive.diveDateTime, minutesIn(2));
      expect(dive.entryTime, minutesIn(2));
      expect(dive.exitTime, minutesIn(2) + 600 * 1000);
      await expectOnOwnClock(newDive, 'dc-b');
    });

    test('goes by the recorded offset when its clock was realigned', () async {
      await seedRecording('a', startMinutes: 0);
      await seedRecording('b', startMinutes: 2);
      await consolidation.apply(targetDiveId: 'a', secondaryDiveIds: ['b']);
      final source = await sourceOf('a', 'dc-b');
      final clocks = SourceClockRepository(database: db);
      await clocks.shift(
        await clocks.snapshot([source.id]),
        const Duration(minutes: 5),
      );

      final newDive = await splitter.split(diveId: 'a', sourceId: source.id);

      // The window moved to 7 minutes in; the samples only ever moved 120s.
      expect((await diveRow(newDive)).entryTime, minutesIn(7));
      await expectOnOwnClock(newDive, 'dc-b');
    });

    test('consolidating it again lands where it did the first time', () async {
      await seedRecording('a', startMinutes: 0);
      await seedRecording('b', startMinutes: 2);
      await consolidation.apply(targetDiveId: 'a', secondaryDiveIds: ['b']);
      final source = await sourceOf('a', 'dc-b');
      final newDive = await splitter.split(diveId: 'a', sourceId: source.id);

      await consolidation.apply(targetDiveId: 'a', secondaryDiveIds: [newDive]);

      expect((await sourceOf('a', 'dc-b')).timeOffsetSeconds, 120);
      await expectOnOwnClock('a', 'dc-b', shift: 120);
    });
  });

  group('splitting the primary source', () {
    test('moves the dive onto the promoted source and every remaining strand '
        'with it (#3916)', () async {
      await seedRecording('a', startMinutes: 0);
      await seedRecording('b', startMinutes: 2);
      await seedRecording('c', startMinutes: 3);
      await consolidation.apply(
        targetDiveId: 'a',
        secondaryDiveIds: ['b', 'c'],
      );
      // A bookmark the diver dropped on the dive's own timeline.
      await db
          .into(db.diveProfileEvents)
          .insert(
            const DiveProfileEventsCompanion(
              id: Value('ev-diver'),
              diveId: Value('a'),
              timestamp: Value(200),
              eventType: Value('bookmark'),
              createdAt: Value(1),
            ),
          );

      final newDive = await splitter.split(diveId: 'a', sourceId: 'src-a');

      // The computer that left has its own dive, as it had before.
      expect((await diveRow(newDive)).entryTime, minutesIn(0));
      await expectOnOwnClock(newDive, 'dc-a');

      // What stays starts where the promoted computer did, at zero.
      final dive = await diveRow('a');
      expect(dive.diveDateTime, minutesIn(2));
      expect(dive.entryTime, minutesIn(2));
      await expectOnOwnClock('a', 'dc-b');
      expect((await sourceOf('a', 'dc-b')).timeOffsetSeconds ?? 0, 0);

      // The third computer keeps its minute's lead over the promoted one.
      await expectOnOwnClock('a', 'dc-c', shift: 60);
      expect((await sourceOf('a', 'dc-c')).timeOffsetSeconds, 60);

      final diverEvent = await (db.select(
        db.diveProfileEvents,
      )..where((t) => t.id.equals('ev-diver'))).getSingle();
      expect(diverEvent.timestamp, 80);
    });

    test('takes the moment a photo is pinned to along', () async {
      await seedRecording('a', startMinutes: 0);
      await seedRecording('b', startMinutes: 2);
      await consolidation.apply(targetDiveId: 'a', secondaryDiveIds: ['b']);
      await db
          .into(db.media)
          .insert(
            const MediaCompanion(
              id: Value('pinned'),
              diveId: Value('a'),
              filePath: Value('pinned.jpg'),
              manualElapsedSeconds: Value(300),
              createdAt: Value(1),
              updatedAt: Value(1),
            ),
          );
      await db
          .into(db.media)
          .insert(
            const MediaCompanion(
              id: Value('unpinned'),
              diveId: Value('a'),
              filePath: Value('unpinned.jpg'),
              createdAt: Value(1),
              updatedAt: Value(1),
            ),
          );

      await splitter.split(diveId: 'a', sourceId: 'src-a');

      final media = await db.select(db.media).get();
      final pin = {for (final m in media) m.id: m.manualElapsedSeconds};
      expect(pin, {'pinned': 180, 'unpinned': null});
    });

    test(
      'drops the safety review, which graded the computer that left',
      () async {
        await seedRecording('a', startMinutes: 0);
        await seedRecording('b', startMinutes: 0);
        await consolidation.apply(targetDiveId: 'a', secondaryDiveIds: ['b']);
        await db
            .into(db.diveSafetyReviews)
            .insert(
              DiveSafetyReviewsCompanion.insert(
                diveId: 'a',
                engineVersion: 1,
                reviewedAt: 1,
              ),
            );

        await splitter.split(diveId: 'a', sourceId: 'src-a');

        expect(await db.select(db.diveSafetyReviews).get(), isEmpty);
      },
    );

    test('keeps each remaining series and its identity', () async {
      await seedRecording('a', startMinutes: 0);
      await seedRecording('b', startMinutes: 2);
      await consolidation.apply(targetDiveId: 'a', secondaryDiveIds: ['b']);
      final before = (await profileSeries.getSeriesForDive(
        'a',
      )).singleWhere((s) => s.computerId == 'dc-b').id;

      await splitter.split(diveId: 'a', sourceId: 'src-a');

      final after = await profileSeries.getSeriesForDive('a');
      expect(after.single.id, before);
      expect(after.single.isPrimary, isTrue);
    });

    test('a promoted source with no window is placed by its offset', () async {
      await seedRecording('a', startMinutes: 0);
      await seedRecording('b', startMinutes: 2, withWindow: false);
      await consolidation.apply(targetDiveId: 'a', secondaryDiveIds: ['b']);

      await splitter.split(diveId: 'a', sourceId: 'src-a');

      final dive = await diveRow('a');
      expect(dive.diveDateTime, minutesIn(2));
      expect(dive.entryTime, minutesIn(2));
      await expectOnOwnClock('a', 'dc-b');
    });

    test(
      'a promoted source already on the dive time base moves nothing',
      () async {
        await seedRecording('a', startMinutes: 0);
        await seedRecording('b', startMinutes: 0);
        await consolidation.apply(targetDiveId: 'a', secondaryDiveIds: ['b']);

        final before = await (db.select(
          db.diveProfileEvents,
        )..where((t) => t.computerId.equals('dc-b'))).getSingle();
        await splitter.split(diveId: 'a', sourceId: 'src-a');

        final after = await (db.select(
          db.diveProfileEvents,
        )..where((t) => t.computerId.equals('dc-b'))).getSingle();
        expect(after.hlc, before.hlc);
        await expectOnOwnClock('a', 'dc-b');
      },
    );
  });
}
