import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_series_repository.dart';
import 'package:submersion/features/dive_log/data/services/dive_merge_service.dart';
import 'package:submersion/features/dive_log/domain/codecs/tank_pressure_series_codec.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late DiveRepository diveRepo;
  late DiveMergeService service;
  late ProfileSeriesRepository profileSeries;
  late TankPressureSeriesRepository tankSeries;

  setUp(() async {
    db = await setUpTestDatabase();
    await db.customStatement('PRAGMA foreign_keys = OFF');
    diveRepo = DiveRepository();
    service = DiveMergeService(diveRepo);
    profileSeries = ProfileSeriesRepository();
    tankSeries = TankPressureSeriesRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  /// Seeds a dive with one tank, a three-point profile series, and the link
  /// rows dive_merge_service_test.dart's fixture also seeds (buddy, sighting,
  /// event, gas switch, a tank pressure series, a data source). 'a' and 'b'
  /// are always fifteen minutes apart (by entry time), matching that
  /// fixture's spacing.
  ///
  /// DiveRepository.createDive writes one packed profile series with no
  /// computer and no source (the identity a manual dive carries). When
  /// [computerId] is given, that series is deleted and re-inserted with the
  /// computer stamped on it, same samples and flags, mirroring how a real
  /// download attributes a profile.
  Future<void> createDive(
    String id, {
    int runtimeMin = 30,
    double depth = 10,
    String? computerId,
  }) async {
    final baseEntry = DateTime.utc(2026, 7, 1, 9);
    final entry = id == 'a'
        ? baseEntry
        : baseEntry.add(const Duration(minutes: 15));
    await diveRepo.createDive(
      domain.Dive(
        id: id,
        diverId: 'diver1',
        dateTime: entry,
        entryTime: entry,
        runtime: Duration(minutes: runtimeMin),
        maxDepth: depth,
        tanks: [domain.DiveTank(id: 'tank-$id', volume: 11.1)],
        profile: [
          const domain.DiveProfilePoint(timestamp: 0, depth: 0),
          domain.DiveProfilePoint(timestamp: runtimeMin * 30, depth: depth),
          domain.DiveProfilePoint(timestamp: runtimeMin * 60, depth: 0),
        ],
      ),
    );
    if (computerId != null) {
      final created = await profileSeries.getSeriesForDive(id);
      await profileSeries.deleteForDive(id);
      for (final s in created) {
        await profileSeries.insertSeries(
          diveId: id,
          computerId: computerId,
          sourceId: s.sourceId,
          isPrimary: s.isPrimary,
          samples: s.samples,
          now: 1000,
        );
      }
    }
    await db
        .into(db.diveBuddies)
        .insert(
          DiveBuddiesCompanion.insert(
            id: 'buddy-$id',
            diveId: id,
            buddyId: 'buddy-cat-1',
            createdAt: 0,
          ),
        );
    await db
        .into(db.sightings)
        .insert(
          SightingsCompanion.insert(
            id: 'sight-$id',
            diveId: id,
            speciesId: 'turtle',
          ),
        );
    await db
        .into(db.diveProfileEvents)
        .insert(
          DiveProfileEventsCompanion.insert(
            id: 'event-$id',
            diveId: id,
            timestamp: 60,
            eventType: 'gaschange',
            createdAt: 0,
          ),
        );
    await db
        .into(db.gasSwitches)
        .insert(
          GasSwitchesCompanion.insert(
            id: 'switch-$id',
            diveId: id,
            timestamp: 60,
            tankId: 'tank-$id',
            createdAt: 0,
          ),
        );
    await tankSeries.insertSeries(
      diveId: id,
      tankId: 'tank-$id',
      samples: const [TankPressureSample(timestamp: 60, pressure: 180.0)],
      now: 1000,
    );
    await db
        .into(db.diveDataSources)
        .insert(
          DiveDataSourcesCompanion.insert(
            id: 'src-$id',
            diveId: id,
            importedAt: DateTime.utc(2026, 7, 1),
            createdAt: DateTime.utc(2026, 7, 1),
          ).copyWith(isPrimary: const Value(true)),
        );
  }

  void expectAscending(Iterable<int> timestamps) {
    final list = timestamps.toList();
    for (var i = 1; i < list.length; i++) {
      expect(list[i], greaterThanOrEqualTo(list[i - 1]), reason: 'index $i');
    }
  }

  test('apply re-bases every series onto the merged timeline and fills the gap '
      'into the adjacent series', () async {
    await createDive('a', runtimeMin: 10, depth: 20);
    await createDive(
      'b',
      runtimeMin: 10,
      depth: 20 /* fifteen minutes after a, as the fixture does */,
    );

    final outcome = await service.apply(['a', 'b']);

    final merged = await profileSeries.getSeriesForDive(outcome.mergedDive.id);
    expect(merged, hasLength(2));
    final first = merged.firstWhere((s) => s.samples.first.timestamp == 0);
    final second = merged.firstWhere((s) => s.samples.first.timestamp != 0);
    final offsetB = second.samples.first.timestamp;
    expect(offsetB, greaterThan(600));
    expect(second.samples.map((s) => s.timestamp), [
      offsetB,
      offsetB + 300,
      offsetB + 600,
    ]);
    final gap = first.samples
        .where((s) => s.timestamp > 600 && s.timestamp < offsetB)
        .toList();
    expect(
      gap,
      isNotEmpty,
      reason:
          'the surface gap is filled into the '
          'segment before it',
    );
    expect(gap.every((s) => s.depth == 0), isTrue);
    expect(gap.last.timestamp, offsetB - 1);
    expectAscending(first.samples.map((s) => s.timestamp));
    expect(first.sourceId, isNotNull);
  });

  test('apply moves tank pressure series onto the merged tanks with the '
      'segment offset', () async {
    await createDive('a', runtimeMin: 10, depth: 20);
    await createDive('b', runtimeMin: 10, depth: 20);

    final outcome = await service.apply(['a', 'b']);

    final tanks = await tankSeries.getSeriesForDive(outcome.mergedDive.id);
    expect(tanks, hasLength(2));
    final mergedTankIds =
        (await (db.select(
              db.diveTanks,
            )..where((t) => t.diveId.equals(outcome.mergedDive.id))).get())
            .map((t) => t.id)
            .toSet();
    expect(tanks.map((s) => s.tankId).toSet(), mergedTankIds);
    final timestamps = tanks.map((s) => s.samples.single.timestamp).toList()
      ..sort();
    expect(timestamps.first, 60);
    expect(timestamps.last, greaterThan(660));
  });

  test(
    'undo tombstones the merged series and restores the original rows',
    () async {
      await createDive('a', runtimeMin: 10, depth: 20);
      await createDive('b', runtimeMin: 10, depth: 20);
      final before = await profileSeries.getRowsForDives(['a', 'b']);
      final beforeTanks = await tankSeries.getRowsForDives(['a', 'b']);

      final outcome = await service.apply(['a', 'b']);
      final mergedIds = (await profileSeries.getRowsForDives([
        outcome.mergedDive.id,
      ])).map((r) => r.id).toSet();
      final mergedTankIds = (await tankSeries.getRowsForDives([
        outcome.mergedDive.id,
      ])).map((r) => r.id).toSet();
      await service.undo(outcome.snapshot);

      expect(
        await profileSeries.getRowsForDives([outcome.mergedDive.id]),
        isEmpty,
      );
      final tombstones = await db.select(db.deletionLog).get();
      expect(
        tombstones
            .where((t) => t.entityType == 'diveProfileSeries')
            .map((t) => t.recordId)
            .toSet(),
        mergedIds,
      );
      expect(
        tombstones
            .where((t) => t.entityType == 'tankPressureSeries')
            .map((t) => t.recordId)
            .toSet(),
        mergedTankIds,
      );
      expect(
        tombstones.any((t) => before.any((r) => r.id == t.recordId)),
        isFalse,
      );
      // Row identity plus raw bytes, as plain lists rather than records: the
      // matcher's deep equality recurses into a List (down to the nested
      // Uint8List's own bytes) but falls back to plain `==` for a record
      // field, which compares a Uint8List by identity, not content.
      final after = await profileSeries.getRowsForDives(['a', 'b']);
      expect(
        after
            .map(
              (r) => [
                r.id,
                r.diveId,
                r.computerId,
                r.sourceId,
                r.isPrimary,
                r.samples,
              ],
            )
            .toList(),
        before
            .map(
              (r) => [
                r.id,
                r.diveId,
                r.computerId,
                r.sourceId,
                r.isPrimary,
                r.samples,
              ],
            )
            .toList(),
      );
      final afterTanks = await tankSeries.getRowsForDives(['a', 'b']);
      expect(
        afterTanks.map((r) => [r.id, r.tankId, r.samples]).toList(),
        beforeTanks.map((r) => [r.id, r.tankId, r.samples]).toList(),
      );
    },
  );

  test('when no segment series is primary the gap fill lands on the one with '
      'a computerId', () async {
    await createDive('a', runtimeMin: 10, depth: 20, computerId: 'comp-a');
    await createDive('b', runtimeMin: 10, depth: 20, computerId: 'comp-b');
    // Demote every series: the computer id is then the only signal
    // _adjacentDraft has left to pick a segment's representative series.
    await profileSeries.demoteAll('a');
    await profileSeries.demoteAll('b');

    final outcome = await service.apply(['a', 'b']);

    final merged = await profileSeries.getSeriesForDive(outcome.mergedDive.id);
    expect(merged, hasLength(2));
    expect(merged.every((s) => s.isPrimary), isFalse);
    expect(merged.map((s) => s.computerId).toSet(), {'comp-a', 'comp-b'});
    // The gap fill (extra 0-depth samples beyond the original three
    // points) landed on one of the computer-attributed series, never
    // dropped for lack of a primary host.
    expect(merged.any((s) => s.samples.length > 3), isTrue);
  });

  test('the gap fill falls back to the later dive when the earlier one has no '
      'profile', () async {
    await createDive('a', runtimeMin: 10, depth: 20);
    await createDive('b', runtimeMin: 10, depth: 20);
    // 'a' is the dive the gap follows (afterDiveId); stripping its series
    // forces _adjacentDraft's afterDiveId lookup to come back null, so the
    // fill can only land through the beforeDiveId fallback onto 'b'.
    await profileSeries.deleteForDive('a');

    final outcome = await service.apply(['a', 'b']);

    final merged = await profileSeries.getSeriesForDive(outcome.mergedDive.id);
    expect(merged, hasLength(1));
    final host = merged.single;
    // b's own three re-based points contribute exactly two 0-depth
    // samples (entry and exit); every extra 0-depth sample beyond those
    // came from the gap fill landing on this series through the
    // beforeDiveId fallback.
    expect(host.samples.length, greaterThan(3));
    expect(host.samples.where((s) => s.depth == 0).length, greaterThan(2));
    expect(host.samples.any((s) => s.depth > 0), isTrue);
  });

  test('a merge of two profile-less dives creates an unattributed gap-fill '
      'series', () async {
    await createDive('a', runtimeMin: 10, depth: 20);
    await createDive('b', runtimeMin: 10, depth: 20);
    await profileSeries.deleteForDive('a');
    await profileSeries.deleteForDive('b');

    final outcome = await service.apply(['a', 'b']);

    final merged = await profileSeries.getSeriesForDive(outcome.mergedDive.id);
    expect(merged, hasLength(1));
    final synthetic = merged.single;
    expect(synthetic.computerId, isNull);
    expect(synthetic.sourceId, isNull);
    expect(synthetic.isPrimary, isTrue);
    expect(synthetic.samples, isNotEmpty);
    expect(synthetic.samples.every((s) => s.depth == 0), isTrue);
  });
}
