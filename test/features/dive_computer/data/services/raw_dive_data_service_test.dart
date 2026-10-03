import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/features/dive_computer/data/services/raw_dive_data_service.dart';

import '../../../../helpers/test_database.dart';

/// Raw dive computer bytes are what make a re-parse possible, so they are
/// kept by default; the diver can drop them once they trust the parsed
/// result (issue #1376). A discard clears only the bytes, keeps the
/// fingerprint the importer matches on, and travels to peers.
void main() {
  late AppDatabase db;
  late RawDiveDataService service;

  const nowMs = 1768471200000; // 2026-01-15 10:00 UTC
  final now = DateTime.fromMillisecondsSinceEpoch(nowMs);

  setUp(() async {
    db = await setUpTestDatabase();
    service = RawDiveDataService(db: db);
  });

  tearDown(() async => tearDownTestDatabase());

  Future<void> seedComputer(String id) => db
      .into(db.diveComputers)
      .insert(
        DiveComputersCompanion(
          id: Value(id),
          name: Value(id),
          createdAt: const Value(nowMs),
          updatedAt: const Value(nowMs),
        ),
      );

  Future<void> seedSource(
    String id, {
    required String? computerId,
    Uint8List? rawData,
    String? onDive,
  }) async {
    final diveId = onDive ?? 'dive-$id';
    await db
        .into(db.dives)
        .insertOnConflictUpdate(
          DivesCompanion(
            id: Value(diveId),
            diveDateTime: const Value(nowMs),
            createdAt: const Value(nowMs),
            updatedAt: const Value(nowMs),
          ),
        );
    await db
        .into(db.diveDataSources)
        .insert(
          DiveDataSourcesCompanion(
            id: Value(id),
            diveId: Value(diveId),
            computerId: Value(computerId),
            sourceFormat: const Value('dive_computer'),
            importedAt: Value(now),
            createdAt: Value(now),
            rawData: Value(rawData),
            rawFingerprint: Value(Uint8List.fromList([1, 2, 3, 4])),
          ),
        );
  }

  Uint8List bytes(int length) =>
      Uint8List.fromList(List.generate(length, (i) => i % 251));

  Future<DiveDataSourcesData> source(String id) => (db.select(
    db.diveDataSources,
  )..where((t) => t.id.equals(id))).getSingle();

  /// Two computers with raw bytes, a source without bytes, and one whose
  /// computer was deleted (the FK sets computerId to null) but kept its bytes.
  Future<void> seedLibrary() async {
    await seedComputer('c1');
    await seedComputer('c2');
    await seedSource('c1-a', computerId: 'c1', rawData: bytes(4000));
    await seedSource('c1-b', computerId: 'c1', rawData: bytes(3000));
    await seedSource('c1-none', computerId: 'c1');
    await seedSource('c2-a', computerId: 'c2', rawData: bytes(2000));
    await seedSource('orphan', computerId: null, rawData: bytes(1000));
  }

  /// One dive recorded by two computers, the second folded in by
  /// consolidation: two source rows, one dive.
  Future<void> seedMultiSourceDive() async {
    await seedComputer('c1');
    await seedComputer('c2');
    await seedSource('m-1', computerId: 'c1', rawData: bytes(500), onDive: 'm');
    await seedSource('m-2', computerId: 'c2', rawData: bytes(500), onDive: 'm');
  }

  group('getUsage', () {
    test('counts dives, not their source rows', () async {
      await seedMultiSourceDive();

      expect((await service.getUsage()).diveCount, 1);
      expect((await service.getUsage(computerId: 'c1')).diveCount, 1);
    });

    test('for one computer counts only that computer\'s dives', () async {
      await seedLibrary();

      final usage = await service.getUsage(computerId: 'c1');

      expect(usage.diveCount, 2);
      expect(usage.storedBytes, greaterThan(0));
    });

    test('counts every source holding raw bytes and sums their stored '
        'size', () async {
      await seedLibrary();

      final usage = await service.getUsage();

      expect(usage.diveCount, 4);
      // Stored compressed at rest (issue #227), so the size is what the
      // database actually holds, which is non-zero and below the raw total.
      expect(usage.storedBytes, greaterThan(0));
      expect(usage.storedBytes, lessThan(10000));
    });

    test('is empty when no source holds raw bytes', () async {
      await seedComputer('c1');
      await seedSource('c1-none', computerId: 'c1');

      final usage = await service.getUsage();

      expect(usage.diveCount, 0);
      expect(usage.storedBytes, 0);
    });
  });

  group('discard', () {
    test('reports dives cleared, not source rows', () async {
      await seedMultiSourceDive();

      expect(await service.discard(), 1);
      expect((await service.getUsage()).diveCount, 0);
    });

    test('for one computer clears only that computer\'s bytes', () async {
      await seedLibrary();

      final cleared = await service.discard(computerId: 'c1');

      expect(cleared, 2);
      expect((await source('c1-a')).rawData, isNull);
      expect((await source('c1-b')).rawData, isNull);
      expect((await source('c2-a')).rawData, isNotNull);
      expect((await source('orphan')).rawData, isNotNull);
    });

    test('for all computers clears every source, including one whose '
        'computer was deleted', () async {
      await seedLibrary();

      final cleared = await service.discard();

      expect(cleared, 4);
      final remaining = await (db.select(
        db.diveDataSources,
      )..where((t) => t.rawData.isNotNull())).get();
      expect(remaining, isEmpty);
      expect((await service.getUsage()).diveCount, 0);
    });

    test('keeps the fingerprint the importer matches downloads on', () async {
      await seedLibrary();

      await service.discard();

      expect((await source('c1-a')).rawFingerprint, [1, 2, 3, 4]);
    });

    test('stages each cleared row, so peers drop the bytes too', () async {
      await seedLibrary();
      // Publish the library first, so the next changeset is incremental and
      // carries only what the discard staged.
      final sync = SyncRepository(database: db);
      for (final dive in await db.select(db.dives).get()) {
        await sync.markRecordPending(
          entityType: 'dives',
          recordId: dive.id,
          localUpdatedAt: 1,
        );
      }
      final serializer = SyncDataSerializer();
      final base = await serializer.exportChangeset(
        deviceId: 'test-device',
        hlcWatermark: null,
        deletions: const [],
      );
      expect(base.toHlc, isNotNull);
      await db.customStatement('DELETE FROM sync_records');
      final hlcBefore = (await source('c1-a')).hlc;

      await service.discard(computerId: 'c1');

      expect((await source('c1-a')).hlc, isNot(hlcBefore));
      final pending = await db.select(db.syncRecords).get();
      expect(
        pending
            .where((r) => r.entityType == 'diveDataSources')
            .map((r) => r.recordId),
        unorderedEquals(['c1-a', 'c1-b']),
      );
      final next = await serializer.exportChangeset(
        deviceId: 'test-device',
        hlcWatermark: base.toHlc,
        deletions: const [],
      );
      final published = {
        for (final row in next.data.diveDataSources) row['id']: row,
      };
      expect(published.keys, containsAll(['c1-a', 'c1-b']));
      expect(published['c1-a']!['rawData'], isNull);
      expect(published.containsKey('c2-a'), isFalse);
    });

    test('with nothing to discard changes and stages nothing', () async {
      await seedComputer('c1');
      await seedSource('c1-none', computerId: 'c1');

      expect(await service.discard(computerId: 'c1'), 0);
      expect(await service.discard(), 0);
      expect(await db.select(db.syncRecords).get(), isEmpty);
    });
  });
}
