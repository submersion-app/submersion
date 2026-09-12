import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:libdivecomputer_plugin/libdivecomputer_plugin.dart' as pigeon;

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/dive_computer/data/services/reparse_service.dart';

import '../../../../helpers/bound_variables.dart';
import '../../../../helpers/test_database.dart';

/// A re-parse rewrites its source row, the dive's tanks, events and gas
/// switches, and (from the primary source) the dive row itself. The dive row
/// is staged only when it changed; the children are staged themselves and
/// travel without it, and the rows the re-parse removes are tombstoned, or a
/// peer keeps the replaced events and switches beside the new ones.
void main() {
  late AppDatabase db;
  late ReparseService service;
  late SyncDataSerializer serializer;

  const nowMs = 1768471200000; // 2026-01-15 10:00 UTC

  setUp(() async {
    db = await setUpTestDatabase();
    service = ReparseService(db: db);
    serializer = SyncDataSerializer();
  });

  tearDown(() async => tearDownTestDatabase());

  /// A single-computer dive with a tank the next parse keeps, a tank it
  /// drops, one event and one gas switch, all already published.
  Future<void> seedPublishedDive({bool primary = true}) async {
    await db
        .into(db.dives)
        .insert(
          const DivesCompanion(
            id: Value('d1'),
            diveDateTime: Value(nowMs),
            createdAt: Value(nowMs),
            updatedAt: Value(nowMs),
          ),
        );
    await db
        .into(db.diveComputers)
        .insert(
          const DiveComputersCompanion(
            id: Value('c1'),
            name: Value('Perdix'),
            createdAt: Value(nowMs),
            updatedAt: Value(nowMs),
          ),
        );
    final now = DateTime.fromMillisecondsSinceEpoch(nowMs);
    await db
        .into(db.diveDataSources)
        .insert(
          DiveDataSourcesCompanion(
            id: const Value('src-1'),
            diveId: const Value('d1'),
            computerId: const Value('c1'),
            isPrimary: Value(primary),
            sourceFormat: const Value('dive_computer'),
            importedAt: Value(now),
            createdAt: Value(now),
          ),
        );
    for (final (id, index) in [('kept', 0), ('gone', 5)]) {
      await db
          .into(db.diveTanks)
          .insert(
            DiveTanksCompanion(
              id: Value(id),
              diveId: const Value('d1'),
              computerId: const Value('c1'),
              tankOrder: Value(index),
              sourceTankIndex: Value(index),
              startPressure: const Value(180),
            ),
          );
    }
    await db
        .into(db.diveProfileEvents)
        .insert(
          const DiveProfileEventsCompanion(
            id: Value('old-event'),
            diveId: Value('d1'),
            computerId: Value('c1'),
            timestamp: Value(30),
            eventType: Value('bookmark'),
            createdAt: Value(nowMs),
          ),
        );
    await db
        .into(db.gasSwitches)
        .insert(
          const GasSwitchesCompanion(
            id: Value('old-switch'),
            diveId: Value('d1'),
            timestamp: Value(10),
            tankId: Value('kept'),
            createdAt: Value(nowMs),
          ),
        );
    await SyncRepository(
      database: db,
    ).markRecordPending(entityType: 'dives', recordId: 'd1', localUpdatedAt: 1);
  }

  /// Records the watermark a device keeps after publishing everything so
  /// far, and clears what that publish staged.
  Future<String> publishEverything() async {
    final base = await serializer.exportChangeset(
      deviceId: 'test-device',
      hlcWatermark: null,
      deletions: await db.select(db.deletionLog).get(),
    );
    await db.customStatement('DELETE FROM sync_records');
    return base.toHlc!;
  }

  Future<SyncPayload> nextChangeset(String watermark) async =>
      serializer.exportChangeset(
        deviceId: 'test-device',
        hlcWatermark: watermark,
        deletions: await db.select(db.deletionLog).get(),
      );

  pigeon.ParsedDive parsedDive() => pigeon.ParsedDive(
    fingerprint: 'fp',
    dateTimeYear: 2026,
    dateTimeMonth: 1,
    dateTimeDay: 15,
    dateTimeHour: 10,
    dateTimeMinute: 0,
    dateTimeSecond: 0,
    maxDepthMeters: 25,
    avgDepthMeters: 14,
    durationSeconds: 3000,
    gasMixes: [
      pigeon.GasMix(index: 0, o2Percent: 32, hePercent: 0),
      pigeon.GasMix(index: 1, o2Percent: 99, hePercent: 0),
    ],
    tanks: [
      pigeon.TankInfo(
        index: 0,
        gasMixIndex: 0,
        startPressureBar: 200,
        endPressureBar: 50,
      ),
    ],
    samples: [
      pigeon.ProfileSample(timeSeconds: 0, depthMeters: 0, gasMixIndex: 0),
      pigeon.ProfileSample(timeSeconds: 120, depthMeters: 25, gasMixIndex: 0),
      pigeon.ProfileSample(timeSeconds: 180, depthMeters: 6, gasMixIndex: 1),
      pigeon.ProfileSample(timeSeconds: 240, depthMeters: 5, gasMixIndex: 1),
    ],
    events: [pigeon.DiveEvent(timeSeconds: 60, type: 'bookmark')],
  );

  Future<void> reparse() => service.applyParsedUpdate(
    diveId: 'd1',
    sourceRowId: 'src-1',
    parsed: parsedDive(),
    descriptorVendor: null,
    descriptorProduct: null,
    descriptorModel: null,
    libdivecomputerVersion: null,
  );

  Future<String?> diveHlc() async =>
      (await db
              .customSelect("SELECT hlc FROM dives WHERE id = 'd1'")
              .getSingle())
          .read<String?>('hlc');

  test(
    'a dive with many events binds within SQLite\'s variable limit',
    () async {
      // Every replaced event's id went into one DELETE ... IN list.
      await tearDownTestDatabase();
      db = setUpLoggingTestDatabase();
      service = ReparseService(db: db);
      serializer = SyncDataSerializer();
      await quietly(() async {
        await seedPublishedDive();
        await db.batch(
          (b) => b.insertAll(db.diveProfileEvents, [
            for (var i = 0; i < 1200; i++)
              DiveProfileEventsCompanion(
                id: Value('e$i'),
                diveId: const Value('d1'),
                computerId: const Value('c1'),
                timestamp: Value(i),
                eventType: const Value('bookmark'),
                createdAt: const Value(nowMs),
              ),
          ]),
        );
        await publishEverything();
      });

      final most = await maxBoundVariables(reparse);
      expect(most, lessThanOrEqualTo(sqliteVariableLimit));
      expect(
        await db.select(db.diveProfileEvents).get(),
        hasLength(1),
        reason: 'every replaced event is gone',
      );
      expect(
        (await db.select(db.deletionLog).get()).where(
          (d) => d.entityType == 'diveProfileEvents',
        ),
        hasLength(1201),
      );
    },
  );

  test('stages the dive, so the rewritten rows reach peers in the next '
      'changeset', () async {
    await seedPublishedDive();
    final watermark = await publishEverything();

    await reparse();

    final pending = await db.select(db.syncRecords).get();
    expect(
      pending.where((r) => r.entityType == 'dives').map((r) => r.recordId),
      ['d1'],
    );
    expect((await diveHlc())!.compareTo(watermark), greaterThan(0));

    final data = (await nextChangeset(watermark)).data;
    expect(data.dives.map((d) => d['id']), ['d1']);
    expect(data.diveDataSources.map((s) => s['id']), ['src-1']);
    final tanks = {for (final t in data.diveTanks) t['id']: t};
    expect(tanks.keys, contains('kept'));
    expect(tanks['kept']!['startPressure'], 200);
    final events = await db.select(db.diveProfileEvents).get();
    expect(
      data.diveProfileEvents.map((e) => e['id']).toSet(),
      events.map((e) => e.id).toSet(),
    );
    final switches = await db.select(db.gasSwitches).get();
    expect(switches, isNotEmpty);
    expect(
      data.gasSwitches.map((s) => s['id']).toSet(),
      switches.map((s) => s.id).toSet(),
    );
  });

  test('tombstones the tank, event and gas switch it removes', () async {
    await seedPublishedDive();
    final watermark = await publishEverything();

    await reparse();

    expect(
      await (db.select(
        db.diveTanks,
      )..where((t) => t.id.equals('gone'))).getSingleOrNull(),
      isNull,
      reason: 'the parse no longer reports tank 5',
    );
    final deletions = (await nextChangeset(watermark)).deletions;
    List<String> ids(String entity) =>
        (deletions[entity] ?? const []).map((d) => d.id).toList();
    expect(ids('diveTanks'), ['gone']);
    expect(ids('diveProfileEvents'), ['old-event']);
    expect(ids('gasSwitches'), ['old-switch']);
  });

  test('a non-primary source publishes its source row without re-stamping '
      'the dive', () async {
    // The dive row did not change. Re-stamping it would let this device's
    // copy of the dive win over a newer edit to it made on another device.
    await seedPublishedDive(primary: false);
    final watermark = await publishEverything();
    final before = await diveHlc();

    await reparse();

    expect(await diveHlc(), before, reason: 'not re-stamped');
    final data = (await nextChangeset(watermark)).data;
    expect(data.dives, isEmpty);
    expect(data.diveDataSources.map((s) => s['id']), ['src-1']);
  });

  test('announces the change, so an auto-sync publishes it', () async {
    // A non-primary re-parse writes no series, so the series repositories'
    // own announcements never fire for it.
    await seedPublishedDive(primary: false);
    var notifications = 0;
    final subscription = SyncEventBus.changes.listen((_) => notifications++);
    addTearDown(subscription.cancel);

    await reparse();
    await Future<void>.delayed(Duration.zero);

    expect(notifications, 1);
  });
}
