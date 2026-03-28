import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late DiveRepository repository;
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = DiveRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Future<String> insertTestDive({
    String? id,
    String? computerId,
    String? diveComputerModel,
    String? diveComputerSerial,
    double? maxDepth,
    double? avgDepth,
    int? duration,
    double? waterTemp,
    int? entryTime,
    int? exitTime,
    int? surfaceIntervalSeconds,
    double? cnsEnd,
    String? decoAlgorithm,
    int? gradientFactorLow,
    int? gradientFactorHigh,
  }) async {
    final diveId = id ?? 'dive-${DateTime.now().microsecondsSinceEpoch}';
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(diveId),
            diveDateTime: Value(now),
            computerId: Value(computerId),
            diveComputerModel: Value(diveComputerModel),
            diveComputerSerial: Value(diveComputerSerial),
            maxDepth: Value(maxDepth),
            avgDepth: Value(avgDepth),
            bottomTime: Value(duration),
            waterTemp: Value(waterTemp),
            entryTime: Value(entryTime),
            exitTime: Value(exitTime),
            surfaceIntervalSeconds: Value(surfaceIntervalSeconds),
            cnsEnd: Value(cnsEnd),
            decoAlgorithm: Value(decoAlgorithm),
            gradientFactorLow: Value(gradientFactorLow),
            gradientFactorHigh: Value(gradientFactorHigh),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    return diveId;
  }

  DiveDataSourcesCompanion buildReading({
    String? id,
    required String diveId,
    bool isPrimary = false,
    String? computerId,
    String? computerModel,
    double? maxDepth,
  }) {
    final now = DateTime.now();
    return DiveDataSourcesCompanion(
      id: Value(id ?? 'reading-${now.microsecondsSinceEpoch}'),
      diveId: Value(diveId),
      isPrimary: Value(isPrimary),
      computerId: Value(computerId),
      computerModel: Value(computerModel),
      maxDepth: Value(maxDepth),
      importedAt: Value(now),
      createdAt: Value(now),
    );
  }

  // ---------------------------------------------------------------------------
  // getDataSources
  // ---------------------------------------------------------------------------

  group('getDataSources', () {
    test('returns empty list when no rows exist for diveId', () async {
      final diveId = await insertTestDive();
      final readings = await repository.getDataSources(diveId);
      expect(readings, isEmpty);
    });

    test('returns only readings for the requested diveId', () async {
      final diveId1 = await insertTestDive(id: 'dive-1');
      final diveId2 = await insertTestDive(id: 'dive-2');

      await repository.saveComputerReading(
        buildReading(id: 'r1', diveId: diveId1, isPrimary: true),
      );
      await repository.saveComputerReading(
        buildReading(id: 'r2', diveId: diveId2),
      );

      final readings = await repository.getDataSources(diveId1);
      expect(readings.length, equals(1));
      expect(readings.first.id, equals('r1'));
    });

    test(
      'returns readings ordered: primary first, then by createdAt',
      () async {
        final diveId = await insertTestDive();

        await repository.saveComputerReading(
          buildReading(id: 'secondary', diveId: diveId),
        );
        await repository.saveComputerReading(
          buildReading(id: 'primary', diveId: diveId, isPrimary: true),
        );

        final readings = await repository.getDataSources(diveId);
        expect(readings.first.isPrimary, isTrue);
        expect(readings.first.id, equals('primary'));
      },
    );
  });

  // ---------------------------------------------------------------------------
  // saveComputerReading + round-trip
  // ---------------------------------------------------------------------------

  group('saveComputerReading', () {
    test(
      'persists a reading that can be retrieved via getDataSources',
      () async {
        final diveId = await insertTestDive();
        final now = DateTime.now().toUtc();

        await repository.saveComputerReading(
          DiveDataSourcesCompanion(
            id: const Value('reading-abc'),
            diveId: Value(diveId),
            isPrimary: const Value(true),
            computerModel: const Value('Suunto D5'),
            computerSerial: const Value('SN-001'),
            maxDepth: const Value(30.5),
            avgDepth: const Value(18.2),
            duration: const Value(2700),
            waterTemp: const Value(22.0),
            surfaceInterval: const Value(90),
            cns: const Value(12.5),
            decoAlgorithm: const Value('buhlmann'),
            gradientFactorLow: const Value(30),
            gradientFactorHigh: const Value(85),
            importedAt: Value(now),
            createdAt: Value(now),
          ),
        );

        final readings = await repository.getDataSources(diveId);
        expect(readings.length, equals(1));

        final r = readings.first;
        expect(r.id, equals('reading-abc'));
        expect(r.diveId, equals(diveId));
        expect(r.isPrimary, isTrue);
        expect(r.computerModel, equals('Suunto D5'));
        expect(r.computerSerial, equals('SN-001'));
        expect(r.maxDepth, equals(30.5));
        expect(r.avgDepth, equals(18.2));
        expect(r.duration, equals(2700));
        expect(r.waterTemp, equals(22.0));
        expect(r.surfaceInterval, equals(90));
        expect(r.cns, equals(12.5));
        expect(r.decoAlgorithm, equals('buhlmann'));
        expect(r.gradientFactorLow, equals(30));
        expect(r.gradientFactorHigh, equals(85));
      },
    );
  });

  // ---------------------------------------------------------------------------
  // deleteComputerReading
  // ---------------------------------------------------------------------------

  group('deleteComputerReading', () {
    test('removes the row with the given id', () async {
      final diveId = await insertTestDive();

      await repository.saveComputerReading(
        buildReading(id: 'to-delete', diveId: diveId),
      );
      await repository.saveComputerReading(
        buildReading(id: 'to-keep', diveId: diveId),
      );

      await repository.deleteComputerReading('to-delete');

      final readings = await repository.getDataSources(diveId);
      expect(readings.length, equals(1));
      expect(readings.first.id, equals('to-keep'));
    });

    test('is a no-op when the id does not exist', () async {
      await expectLater(
        repository.deleteComputerReading('nonexistent-id'),
        completes,
      );
    });
  });

  // ---------------------------------------------------------------------------
  // hasMultipleDataSources
  // ---------------------------------------------------------------------------

  group('hasMultipleDataSources', () {
    test('returns false when there are no readings', () async {
      final diveId = await insertTestDive();
      expect(await repository.hasMultipleDataSources(diveId), isFalse);
    });

    test('returns false when there is exactly one reading', () async {
      final diveId = await insertTestDive();
      await repository.saveComputerReading(
        buildReading(id: 'r1', diveId: diveId),
      );
      expect(await repository.hasMultipleDataSources(diveId), isFalse);
    });

    test('returns true when there are two or more readings', () async {
      final diveId = await insertTestDive();
      await repository.saveComputerReading(
        buildReading(id: 'r1', diveId: diveId),
      );
      await repository.saveComputerReading(
        buildReading(id: 'r2', diveId: diveId),
      );
      expect(await repository.hasMultipleDataSources(diveId), isTrue);
    });

    test('counts only readings for the requested diveId', () async {
      final diveId1 = await insertTestDive(id: 'dive-1');
      final diveId2 = await insertTestDive(id: 'dive-2');

      // Two readings on dive-2, one on dive-1
      await repository.saveComputerReading(
        buildReading(id: 'r1', diveId: diveId2),
      );
      await repository.saveComputerReading(
        buildReading(id: 'r2', diveId: diveId2),
      );
      await repository.saveComputerReading(
        buildReading(id: 'r3', diveId: diveId1),
      );

      expect(await repository.hasMultipleDataSources(diveId1), isFalse);
      expect(await repository.hasMultipleDataSources(diveId2), isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // backfillPrimaryDataSource
  // ---------------------------------------------------------------------------

  group('backfillPrimaryDataSource', () {
    test('creates a primary reading from the dives row', () async {
      final entryMs = DateTime(2024, 6, 1, 9, 0).millisecondsSinceEpoch;
      final exitMs = DateTime(2024, 6, 1, 9, 45).millisecondsSinceEpoch;

      final diveId = await insertTestDive(
        diveComputerModel: 'Shearwater Petrel 3',
        diveComputerSerial: 'SN-999',
        maxDepth: 40.0,
        avgDepth: 22.5,
        duration: 2700,
        waterTemp: 19.0,
        entryTime: entryMs,
        exitTime: exitMs,
        surfaceIntervalSeconds: 3600,
        cnsEnd: 15.0,
        decoAlgorithm: 'buhlmann',
        gradientFactorLow: 35,
        gradientFactorHigh: 75,
      );

      await repository.backfillPrimaryDataSource(diveId);

      final readings = await repository.getDataSources(diveId);
      expect(readings.length, equals(1));

      final r = readings.first;
      expect(r.isPrimary, isTrue);
      expect(r.computerModel, equals('Shearwater Petrel 3'));
      expect(r.computerSerial, equals('SN-999'));
      expect(r.maxDepth, equals(40.0));
      expect(r.avgDepth, equals(22.5));
      expect(r.duration, equals(2700));
      expect(r.waterTemp, equals(19.0));
      expect(r.entryTime?.millisecondsSinceEpoch, equals(entryMs));
      expect(r.exitTime?.millisecondsSinceEpoch, equals(exitMs));
      expect(r.surfaceInterval, equals(3600));
      expect(r.cns, equals(15.0));
      expect(r.decoAlgorithm, equals('buhlmann'));
      expect(r.gradientFactorLow, equals(35));
      expect(r.gradientFactorHigh, equals(75));
    });

    test('is a no-op when a primary reading already exists', () async {
      final diveId = await insertTestDive(maxDepth: 30.0);

      // Insert a primary reading manually
      await repository.saveComputerReading(
        buildReading(id: 'existing-primary', diveId: diveId, isPrimary: true),
      );

      // Calling backfill should not add another reading
      await repository.backfillPrimaryDataSource(diveId);

      final readings = await repository.getDataSources(diveId);
      expect(readings.length, equals(1));
      expect(readings.first.id, equals('existing-primary'));
    });

    test('is a no-op when the dive does not exist', () async {
      await expectLater(
        repository.backfillPrimaryDataSource('nonexistent-dive'),
        completes,
      );
    });

    test('handles null optional fields gracefully', () async {
      final diveId = await insertTestDive();

      await repository.backfillPrimaryDataSource(diveId);

      final readings = await repository.getDataSources(diveId);
      expect(readings.length, equals(1));

      final r = readings.first;
      expect(r.isPrimary, isTrue);
      expect(r.computerModel, isNull);
      expect(r.maxDepth, isNull);
      expect(r.cns, isNull);
    });
  });
}
