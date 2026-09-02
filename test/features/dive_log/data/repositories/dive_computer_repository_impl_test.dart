import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/imported_computer_identity.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart'
    as domain;

import '../../../../helpers/test_database.dart';

void main() {
  late DiveComputerRepository repository;
  late ProfileSeriesRepository profileSeries;
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = DiveComputerRepository();
    profileSeries = ProfileSeriesRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Future<String> insertComputer({
    String id = 'computer-1',
    String name = 'Shearwater Perdix',
    String? diverId,
    String? manufacturer = 'Shearwater',
    String? model = 'Perdix',
    String? serialNumber = 'SN-12345',
    String? bluetoothAddress,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.diveComputers)
        .insert(
          DiveComputersCompanion(
            id: Value(id),
            diverId: Value(diverId),
            name: Value(name),
            manufacturer: Value(manufacturer),
            model: Value(model),
            serialNumber: Value(serialNumber),
            bluetoothAddress: Value(bluetoothAddress),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    return id;
  }

  Future<String> insertDive({
    String? id,
    String? computerId,
    int? diveDateTime,
    int? entryTime,
    int? exitTime,
    int? duration,
    double? maxDepth,
    double? avgDepth,
    int? diveNumber,
  }) async {
    final diveId = id ?? 'dive-${DateTime.now().microsecondsSinceEpoch}';
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(diveId),
            diveDateTime: Value(diveDateTime ?? now),
            computerId: Value(computerId),
            entryTime: Value(entryTime),
            exitTime: Value(exitTime),
            bottomTime: Value(duration),
            maxDepth: Value(maxDepth),
            avgDepth: Value(avgDepth),
            diveNumber: Value(diveNumber),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    return diveId;
  }

  Future<void> insertDataSource({
    required String diveId,
    String? computerId,
    bool isPrimary = false,
    String? computerModel,
    String? computerSerial,
    String? sourceFormat,
  }) async {
    final id = 'ds-${DateTime.now().microsecondsSinceEpoch}';
    final now = DateTime.now();
    await db
        .into(db.diveDataSources)
        .insert(
          DiveDataSourcesCompanion(
            id: Value(id),
            diveId: Value(diveId),
            computerId: Value(computerId),
            isPrimary: Value(isPrimary),
            computerModel: Value(computerModel),
            computerSerial: Value(computerSerial),
            sourceFormat: Value(sourceFormat),
            importedAt: Value(now),
            createdAt: Value(now),
          ),
        );
  }

  Future<void> insertDiver(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.divers)
        .insertOnConflictUpdate(
          DiversCompanion(
            id: Value(id),
            name: Value('Diver $id'),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  // ---------------------------------------------------------------------------
  // findByBluetoothAddress - diver-scoped lookup
  // ---------------------------------------------------------------------------

  group('findByBluetoothAddress', () {
    test('returns computer matching address and diverId', () async {
      await insertDiver('diver-a');
      await insertDiver('diver-b');
      await insertComputer(
        id: 'comp-a',
        diverId: 'diver-a',
        bluetoothAddress: 'AA:BB:CC:DD:EE:FF',
      );
      await insertComputer(
        id: 'comp-b',
        diverId: 'diver-b',
        bluetoothAddress: 'AA:BB:CC:DD:EE:FF',
      );

      final result = await repository.findByBluetoothAddress(
        'AA:BB:CC:DD:EE:FF',
        diverId: 'diver-b',
      );
      expect(result?.id, equals('comp-b'));
      expect(result?.diverId, equals('diver-b'));
    });

    test(
      'returns null when address exists but diverId does not match',
      () async {
        await insertDiver('diver-a');
        await insertComputer(
          id: 'comp-a',
          diverId: 'diver-a',
          bluetoothAddress: 'AA:BB:CC:DD:EE:FF',
        );

        final result = await repository.findByBluetoothAddress(
          'AA:BB:CC:DD:EE:FF',
          diverId: 'diver-other',
        );
        expect(result, isNull);
      },
    );

    test(
      'does not throw when multiple records share the same address',
      () async {
        await insertDiver('diver-a');
        await insertDiver('diver-b');
        await insertComputer(
          id: 'comp-a',
          diverId: 'diver-a',
          bluetoothAddress: 'AA:BB:CC:DD:EE:FF',
        );
        await insertComputer(
          id: 'comp-b',
          diverId: 'diver-b',
          bluetoothAddress: 'AA:BB:CC:DD:EE:FF',
        );

        final result = await repository.findByBluetoothAddress(
          'AA:BB:CC:DD:EE:FF',
        );
        expect(result, isNotNull);
      },
    );

    test('treats empty diverId as null (no filter)', () async {
      await insertDiver('diver-a');
      await insertComputer(
        id: 'comp-a',
        diverId: 'diver-a',
        bluetoothAddress: 'AA:BB:CC:DD:EE:FF',
      );

      // Empty string should not be treated as a diver filter; should
      // find the computer regardless of its diverId.
      final result = await repository.findByBluetoothAddress(
        'AA:BB:CC:DD:EE:FF',
        diverId: '',
      );
      expect(result?.id, equals('comp-a'));
    });
  });

  // ---------------------------------------------------------------------------
  // findByHardwareIdentity - manufacturer/model/serial lookup
  // ---------------------------------------------------------------------------

  group('findByHardwareIdentity', () {
    test('returns computer matching manufacturer, model and serial', () async {
      await insertComputer(
        id: 'comp-a',
        manufacturer: 'Shearwater',
        model: 'Perdix',
        serialNumber: 'SN-12345',
      );

      final result = await repository.findByHardwareIdentity(
        manufacturer: 'Shearwater',
        model: 'Perdix',
        serialNumber: 'SN-12345',
      );
      expect(result?.id, equals('comp-a'));
    });

    test(
      'returns null when serial matches but manufacturer/model do not',
      () async {
        await insertComputer(
          id: 'comp-a',
          manufacturer: 'Shearwater',
          model: 'Perdix',
          serialNumber: 'SN-12345',
        );

        final result = await repository.findByHardwareIdentity(
          manufacturer: 'Suunto',
          model: 'D5',
          serialNumber: 'SN-12345',
        );
        expect(result, isNull);
      },
    );

    test('scopes the match to the given diverId', () async {
      await insertDiver('diver-a');
      await insertDiver('diver-b');
      await insertComputer(
        id: 'comp-a',
        diverId: 'diver-a',
        manufacturer: 'Shearwater',
        model: 'Perdix',
        serialNumber: 'SN-12345',
      );
      await insertComputer(
        id: 'comp-b',
        diverId: 'diver-b',
        manufacturer: 'Shearwater',
        model: 'Perdix',
        serialNumber: 'SN-12345',
      );

      final result = await repository.findByHardwareIdentity(
        manufacturer: 'Shearwater',
        model: 'Perdix',
        serialNumber: 'SN-12345',
        diverId: 'diver-b',
      );
      expect(result?.id, equals('comp-b'));
    });

    test('returns null when diverId does not match', () async {
      await insertDiver('diver-a');
      await insertComputer(
        id: 'comp-a',
        diverId: 'diver-a',
        manufacturer: 'Shearwater',
        model: 'Perdix',
        serialNumber: 'SN-12345',
      );

      final result = await repository.findByHardwareIdentity(
        manufacturer: 'Shearwater',
        model: 'Perdix',
        serialNumber: 'SN-12345',
        diverId: 'diver-other',
      );
      expect(result, isNull);
    });

    test(
      'matches manufacturer and model case-insensitively with whitespace',
      () async {
        await insertComputer(
          id: 'comp-a',
          manufacturer: 'Shearwater',
          model: 'Perdix',
          serialNumber: 'SN-12345',
        );

        final result = await repository.findByHardwareIdentity(
          manufacturer: '  SHEARWATER  ',
          model: '  perdix  ',
          serialNumber: 'SN-12345',
        );
        expect(result?.id, equals('comp-a'));
      },
    );

    test('trims serialNumber before matching', () async {
      await insertComputer(
        id: 'comp-a',
        manufacturer: 'Shearwater',
        model: 'Perdix',
        serialNumber: 'SN-12345',
      );

      final result = await repository.findByHardwareIdentity(
        manufacturer: 'Shearwater',
        model: 'Perdix',
        serialNumber: '  SN-12345  ',
      );
      expect(result?.id, equals('comp-a'));
    });

    test('returns null when no computer has a matching serial', () async {
      final result = await repository.findByHardwareIdentity(
        manufacturer: 'Shearwater',
        model: 'Perdix',
        serialNumber: 'SN-does-not-exist',
      );
      expect(result, isNull);
    });

    test(
      'matches a stored serialNumber that itself has stray whitespace',
      () async {
        await insertComputer(
          id: 'comp-a',
          manufacturer: 'Shearwater',
          model: 'Perdix',
          serialNumber: '  SN-12345  ',
        );

        final result = await repository.findByHardwareIdentity(
          manufacturer: 'Shearwater',
          model: 'Perdix',
          serialNumber: 'SN-12345',
        );
        expect(result?.id, equals('comp-a'));
      },
    );
  });

  // ---------------------------------------------------------------------------
  // deleteComputer - FK reference clearing
  // ---------------------------------------------------------------------------

  group('deleteComputer', () {
    test('nulls out FK references in the series before deleting', () async {
      final computerId = await insertComputer();
      final diveId = await insertDive();
      final seriesId = await profileSeries.insertSeries(
        diveId: diveId,
        computerId: computerId,
        samples: const [ProfileSample(timestamp: 0, depth: 10.0)],
        now: 1000,
      );
      final beforeHlc = (await profileSeries.getRowsForDives([
        diveId,
      ])).firstWhere((r) => r.id == seriesId).hlc;

      await repository.deleteComputer(computerId);

      // Series should still exist but with null computerId and a restamped
      // hlc.
      final seriesRow = (await profileSeries.getRowsForDives([
        diveId,
      ])).firstWhere((r) => r.id == seriesId);
      expect(seriesRow.computerId, isNull);
      expect(seriesRow.hlc, isNot(beforeHlc));

      // Computer should be deleted.
      final computers = await (db.select(
        db.diveComputers,
      )..where((t) => t.id.equals(computerId))).get();
      expect(computers, isEmpty);
    });

    test(
      'nulls out FK references in dive_data_sources before deleting',
      () async {
        final computerId = await insertComputer();
        final diveId = await insertDive();
        await insertDataSource(
          diveId: diveId,
          computerId: computerId,
          isPrimary: true,
        );

        await repository.deleteComputer(computerId);

        // Data source should still exist but with null computerId.
        final sources = await (db.select(
          db.diveDataSources,
        )..where((t) => t.diveId.equals(diveId))).get();
        expect(sources, hasLength(1));
        expect(sources.first.computerId, isNull);
      },
    );

    test('handles deletion when no FK references exist', () async {
      final computerId = await insertComputer(id: 'standalone-computer');

      await repository.deleteComputer('standalone-computer');

      final computers = await (db.select(
        db.diveComputers,
      )..where((t) => t.id.equals(computerId))).get();
      expect(computers, isEmpty);
    });

    test('deletes a computer linked as a dive\'s primary computer with foreign '
        'keys enforced (issue #823)', () async {
      // The app's real connection runs with PRAGMA foreign_keys = ON, but
      // the in-memory test database defaults to OFF, which masked the
      // missing dives.computer_id clearing: deleting a computer that any
      // dive referenced failed with SqliteException(787) on devices.
      await db.customStatement('PRAGMA foreign_keys = ON');
      final computerId = await insertComputer();
      final diveId = await insertDive(computerId: computerId);

      await repository.deleteComputer(computerId);

      // Computer gone; the dive survives with the link cleared.
      final computers = await (db.select(
        db.diveComputers,
      )..where((t) => t.id.equals(computerId))).get();
      expect(computers, isEmpty);
      final dives = await (db.select(
        db.dives,
      )..where((t) => t.id.equals(diveId))).get();
      expect(dives, hasLength(1));
      expect(dives.first.computerId, isNull);
    });

    test(
      'backfills a provenance snapshot for dives lacking a data source row',
      () async {
        // Legacy dives predate dive_data_sources: without a snapshot, deleting
        // the computer would permanently lose which device produced the dive.
        final computerId = await insertComputer(
          manufacturer: 'Shearwater',
          model: 'Perdix',
          serialNumber: 'SN-12345',
        );
        final diveId = await insertDive(computerId: computerId);

        await repository.deleteComputer(computerId);

        final sources = await (db.select(
          db.diveDataSources,
        )..where((t) => t.diveId.equals(diveId))).get();
        expect(sources, hasLength(1));
        expect(sources.first.computerModel, equals('Shearwater Perdix'));
        expect(sources.first.computerSerial, equals('SN-12345'));
        expect(sources.first.sourceFormat, equals('dive_computer'));
        expect(sources.first.computerId, isNull);
        expect(sources.first.isPrimary, isTrue);
      },
    );

    test('does not duplicate an existing provenance snapshot', () async {
      final computerId = await insertComputer(
        manufacturer: 'Shearwater',
        model: 'Perdix',
        serialNumber: 'SN-12345',
      );
      final diveId = await insertDive(computerId: computerId);
      await insertDataSource(
        diveId: diveId,
        computerId: computerId,
        isPrimary: true,
        computerModel: 'Shearwater Perdix',
        computerSerial: 'SN-12345',
        sourceFormat: 'dive_computer',
      );

      await repository.deleteComputer(computerId);

      final sources = await (db.select(
        db.diveDataSources,
      )..where((t) => t.diveId.equals(diveId))).get();
      expect(sources, hasLength(1));
      expect(sources.first.computerId, isNull);
      expect(sources.first.computerModel, equals('Shearwater Perdix'));
      expect(sources.first.computerSerial, equals('SN-12345'));
    });
  });

  // ---------------------------------------------------------------------------
  // createComputer - relinking orphaned dives when the same hardware returns
  // ---------------------------------------------------------------------------

  group('createComputer relinking', () {
    domain.DiveComputer newComputer({
      String? serialNumber = 'SN-12345',
      String manufacturer = 'Shearwater',
      String model = 'Perdix',
    }) {
      final now = DateTime.now();
      return domain.DiveComputer(
        id: '',
        name: 'My Perdix',
        manufacturer: manufacturer,
        model: model,
        serialNumber: serialNumber,
        createdAt: now,
        updatedAt: now,
      );
    }

    test(
      'relinks orphaned dive, source, and profile rows from the same hardware',
      () async {
        final oldId = await insertComputer(
          manufacturer: 'Shearwater',
          model: 'Perdix',
          serialNumber: 'SN-12345',
        );
        final diveId = await insertDive(computerId: oldId);
        await insertDataSource(
          diveId: diveId,
          computerId: oldId,
          isPrimary: true,
          computerModel: 'Shearwater Perdix',
          computerSerial: 'SN-12345',
          sourceFormat: 'dive_computer',
        );
        final seriesId = await profileSeries.insertSeries(
          diveId: diveId,
          computerId: oldId,
          samples: const [ProfileSample(timestamp: 0, depth: 10.0)],
          now: 1000,
        );
        await repository.deleteComputer(oldId);

        final created = await repository.createComputer(newComputer());

        final sources = await (db.select(
          db.diveDataSources,
        )..where((t) => t.diveId.equals(diveId))).get();
        expect(sources.single.computerId, equals(created.id));
        final dive = await (db.select(
          db.dives,
        )..where((t) => t.id.equals(diveId))).getSingle();
        expect(dive.computerId, equals(created.id));
        final series = (await profileSeries.getRowsForDives([
          diveId,
        ])).firstWhere((r) => r.id == seriesId);
        expect(series.computerId, equals(created.id));
      },
    );

    test('does not relink without a serial number', () async {
      final oldId = await insertComputer(
        manufacturer: 'Shearwater',
        model: 'Perdix',
        serialNumber: null,
      );
      final diveId = await insertDive(computerId: oldId);
      await insertDataSource(
        diveId: diveId,
        computerId: oldId,
        isPrimary: true,
        computerModel: 'Shearwater Perdix',
        sourceFormat: 'dive_computer',
      );
      await repository.deleteComputer(oldId);

      await repository.createComputer(newComputer(serialNumber: null));

      final sources = await (db.select(
        db.diveDataSources,
      )..where((t) => t.diveId.equals(diveId))).get();
      expect(sources.single.computerId, isNull);
      final dive = await (db.select(
        db.dives,
      )..where((t) => t.id.equals(diveId))).getSingle();
      expect(dive.computerId, isNull);
    });

    test('leaves rows linked to another computer untouched', () async {
      final otherId = await insertComputer(
        id: 'other-computer',
        manufacturer: 'Shearwater',
        model: 'Perdix',
        serialNumber: 'SN-12345',
      );
      final diveId = await insertDive(computerId: otherId);
      await insertDataSource(
        diveId: diveId,
        computerId: otherId,
        isPrimary: true,
        computerModel: 'Shearwater Perdix',
        computerSerial: 'SN-12345',
        sourceFormat: 'dive_computer',
      );

      final created = await repository.createComputer(newComputer());

      final sources = await (db.select(
        db.diveDataSources,
      )..where((t) => t.diveId.equals(diveId))).get();
      expect(sources.single.computerId, equals(otherId));
      final dive = await (db.select(
        db.dives,
      )..where((t) => t.id.equals(diveId))).getSingle();
      expect(dive.computerId, equals(otherId));
      expect(created.id, isNot(equals(otherId)));
    });

    test(
      'relinks profiles only when the dive has a single computer source',
      () async {
        // A dive built from two computers keeps profile attribution ambiguous
        // once one of them is deleted, so only the source row is relinked.
        final oldId = await insertComputer(
          manufacturer: 'Shearwater',
          model: 'Perdix',
          serialNumber: 'SN-12345',
        );
        final liveId = await insertComputer(
          id: 'live-computer',
          manufacturer: 'Shearwater',
          model: 'Teric',
          serialNumber: 'SN-99999',
        );
        final diveId = await insertDive(computerId: oldId);
        await insertDataSource(
          diveId: diveId,
          computerId: oldId,
          isPrimary: true,
          computerModel: 'Shearwater Perdix',
          computerSerial: 'SN-12345',
          sourceFormat: 'dive_computer',
        );
        await insertDataSource(
          diveId: diveId,
          computerId: liveId,
          computerModel: 'Shearwater Teric',
          computerSerial: 'SN-99999',
          sourceFormat: 'dive_computer',
        );
        final seriesId = await profileSeries.insertSeries(
          diveId: diveId,
          computerId: oldId,
          samples: const [ProfileSample(timestamp: 0, depth: 10.0)],
          now: 1000,
        );
        await repository.deleteComputer(oldId);

        final created = await repository.createComputer(newComputer());

        final sources =
            await (db.select(db.diveDataSources)
                  ..where((t) => t.diveId.equals(diveId))
                  ..orderBy([(t) => OrderingTerm.asc(t.computerSerial)]))
                .get();
        expect(sources, hasLength(2));
        expect(sources.first.computerId, equals(created.id));
        expect(sources.last.computerId, equals(liveId));
        final dive = await (db.select(
          db.dives,
        )..where((t) => t.id.equals(diveId))).getSingle();
        expect(dive.computerId, equals(created.id));
        final series = (await profileSeries.getRowsForDives([
          diveId,
        ])).firstWhere((r) => r.id == seriesId);
        expect(series.computerId, isNull);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // importProfile with forceNew parameter
  // ---------------------------------------------------------------------------

  group('importProfile', () {
    test(
      'forceNew=true skips dive matching and always creates new dive',
      () async {
        final computerId = await insertComputer();

        // Create an existing dive that would normally match.
        final entryTime = DateTime(2026, 3, 15, 10, 0);
        await insertDive(
          id: 'existing-dive',
          computerId: computerId,
          diveDateTime: entryTime.millisecondsSinceEpoch,
          entryTime: entryTime.millisecondsSinceEpoch,
          exitTime: entryTime
              .add(const Duration(minutes: 45))
              .millisecondsSinceEpoch,
          duration: 45 * 60,
          maxDepth: 30.0,
        );

        // Import a profile with the same timestamp but forceNew=true.
        final resultDiveId = await repository.importProfile(
          computerId: computerId,
          profileStartTime: entryTime,
          points: [
            const ProfilePointData(timestamp: 0, depth: 0.0),
            const ProfilePointData(timestamp: 60, depth: 10.0),
            const ProfilePointData(timestamp: 120, depth: 20.0),
          ],
          durationSeconds: 45 * 60,
          maxDepth: 30.0,
          forceNew: true,
        );

        // Should create a new dive, not match the existing one.
        expect(resultDiveId, isNot(equals('existing-dive')));

        // Verify both dives exist.
        final allDives = await db.select(db.dives).get();
        expect(allDives.length, equals(2));
      },
    );

    Future<List<String>> diveTypeIdsFor(String diveId) async {
      final rows = await (db.select(
        db.diveDiveTypes,
      )..where((t) => t.diveId.equals(diveId))).get();
      return rows.map((r) => r.diveTypeId).toList();
    }

    test(
      'a profile with a deco ceiling defaults the dive type to technical',
      () async {
        final computerId = await insertComputer();
        final entryTime = DateTime(2026, 4, 1, 9, 0);

        final diveId = await repository.importProfile(
          computerId: computerId,
          profileStartTime: entryTime,
          points: const [
            ProfilePointData(timestamp: 0, depth: 1.5, ceiling: 0.0),
            ProfilePointData(timestamp: 600, depth: 42.0, ceiling: 6.0),
          ],
          durationSeconds: 3600,
          maxDepth: 42.0,
          forceNew: true,
        );

        final dive = await (db.select(
          db.dives,
        )..where((t) => t.id.equals(diveId))).getSingle();
        expect(dive.diveType, 'technical');
        expect(await diveTypeIdsFor(diveId), ['technical']);
      },
    );

    test('exhausted NDL with TTS remaining at depth defaults the dive type to '
        'technical', () async {
      final computerId = await insertComputer();
      final entryTime = DateTime(2026, 4, 1, 10, 0);

      final diveId = await repository.importProfile(
        computerId: computerId,
        profileStartTime: entryTime,
        points: const [
          ProfilePointData(timestamp: 0, depth: 30.0, ndl: 300, tts: 120),
          ProfilePointData(timestamp: 900, depth: 32.0, ndl: 0, tts: 600),
        ],
        durationSeconds: 1800,
        maxDepth: 32.0,
        forceNew: true,
      );

      final dive = await (db.select(
        db.dives,
      )..where((t) => t.id.equals(diveId))).getSingle();
      expect(dive.diveType, 'technical');
      expect(await diveTypeIdsFor(diveId), ['technical']);
    });

    test('a deco-stop event defaults the dive type to technical even with a '
        'no-deco profile', () async {
      final computerId = await insertComputer();
      final entryTime = DateTime(2026, 4, 1, 11, 0);

      final diveId = await repository.importProfile(
        computerId: computerId,
        profileStartTime: entryTime,
        points: const [
          ProfilePointData(timestamp: 0, depth: 1.0, ndl: 3600),
          ProfilePointData(timestamp: 600, depth: 18.0, ndl: 1200),
        ],
        durationSeconds: 1800,
        maxDepth: 18.0,
        events: const [EventData(timestamp: 900, type: 'deco')],
        forceNew: true,
      );

      final dive = await (db.select(
        db.dives,
      )..where((t) => t.id.equals(diveId))).getSingle();
      expect(dive.diveType, 'technical');
      expect(await diveTypeIdsFor(diveId), ['technical']);
    });

    test('a deepstop event alone (precautionary, not mandatory deco) keeps the '
        'dive type recreational', () async {
      final computerId = await insertComputer();
      final entryTime = DateTime(2026, 4, 1, 11, 30);

      final diveId = await repository.importProfile(
        computerId: computerId,
        profileStartTime: entryTime,
        points: const [
          ProfilePointData(timestamp: 0, depth: 1.0, ndl: 3600),
          ProfilePointData(timestamp: 600, depth: 18.0, ndl: 1200),
        ],
        durationSeconds: 1800,
        maxDepth: 18.0,
        events: const [EventData(timestamp: 900, type: 'deepstop')],
        forceNew: true,
      );

      final dive = await (db.select(
        db.dives,
      )..where((t) => t.id.equals(diveId))).getSingle();
      expect(dive.diveType, 'recreational');
      expect(await diveTypeIdsFor(diveId), ['recreational']);
    });

    test('a ceiling_safetystop event alone (a breached safety stop ceiling, '
        'not a deco ceiling) keeps the dive type recreational', () async {
      final computerId = await insertComputer();
      final entryTime = DateTime(2026, 4, 1, 11, 45);

      final diveId = await repository.importProfile(
        computerId: computerId,
        profileStartTime: entryTime,
        points: const [
          ProfilePointData(timestamp: 0, depth: 1.0, ndl: 3600),
          ProfilePointData(timestamp: 600, depth: 18.0, ndl: 1200),
        ],
        durationSeconds: 1800,
        maxDepth: 18.0,
        events: const [EventData(timestamp: 900, type: 'ceiling_safetystop')],
        forceNew: true,
      );

      final dive = await (db.select(
        db.dives,
      )..where((t) => t.id.equals(diveId))).getSingle();
      expect(dive.diveType, 'recreational');
      expect(await diveTypeIdsFor(diveId), ['recreational']);
    });

    test('a ceiling event (a real deco ceiling) still defaults the dive type '
        'to technical', () async {
      final computerId = await insertComputer();
      final entryTime = DateTime(2026, 4, 1, 11, 50);

      final diveId = await repository.importProfile(
        computerId: computerId,
        profileStartTime: entryTime,
        points: const [
          ProfilePointData(timestamp: 0, depth: 1.0, ndl: 3600),
          ProfilePointData(timestamp: 600, depth: 40.0, ndl: 1200),
        ],
        durationSeconds: 1800,
        maxDepth: 40.0,
        events: const [EventData(timestamp: 900, type: 'ceiling')],
        forceNew: true,
      );

      final dive = await (db.select(
        db.dives,
      )..where((t) => t.id.equals(diveId))).getSingle();
      expect(dive.diveType, 'technical');
      expect(await diveTypeIdsFor(diveId), ['technical']);
    });

    test('a no-deco profile defaults the dive type to recreational', () async {
      final computerId = await insertComputer();
      final entryTime = DateTime(2026, 4, 1, 12, 0);

      final diveId = await repository.importProfile(
        computerId: computerId,
        profileStartTime: entryTime,
        points: const [
          ProfilePointData(timestamp: 0, depth: 1.0, ndl: 3600),
          ProfilePointData(timestamp: 600, depth: 18.0, ndl: 1200, tts: 60),
        ],
        durationSeconds: 1800,
        maxDepth: 18.0,
        forceNew: true,
      );

      final dive = await (db.select(
        db.dives,
      )..where((t) => t.id.equals(diveId))).getSingle();
      expect(dive.diveType, 'recreational');
      expect(await diveTypeIdsFor(diveId), ['recreational']);
    });

    test('importProfile persists the computer dive mode (gauge)', () async {
      final computerId = await insertComputer();
      final entryTime = DateTime(2026, 3, 15, 12, 0);

      final diveId = await repository.importProfile(
        computerId: computerId,
        profileStartTime: entryTime,
        points: const [
          ProfilePointData(timestamp: 0, depth: 0.0),
          ProfilePointData(timestamp: 60, depth: 10.0),
        ],
        durationSeconds: 20 * 60,
        maxDepth: 10.0,
        diveMode: DiveMode.gauge,
        forceNew: true,
      );

      final dive = await (db.select(
        db.dives,
      )..where((t) => t.id.equals(diveId))).getSingle();
      expect(dive.diveMode, 'gauge');
    });

    test(
      'forceNew=false (default) matches existing dive by timestamp',
      () async {
        final computerId = await insertComputer();

        // Create an existing dive.
        final entryTime = DateTime(2026, 3, 15, 10, 0);
        await insertDive(
          id: 'existing-dive',
          computerId: computerId,
          diveDateTime: entryTime.millisecondsSinceEpoch,
          entryTime: entryTime.millisecondsSinceEpoch,
          exitTime: entryTime
              .add(const Duration(minutes: 45))
              .millisecondsSinceEpoch,
          duration: 45 * 60,
          maxDepth: 30.0,
        );

        // Import a profile with a matching timestamp.
        final resultDiveId = await repository.importProfile(
          computerId: computerId,
          profileStartTime: entryTime,
          points: [
            const ProfilePointData(timestamp: 0, depth: 0.0),
            const ProfilePointData(timestamp: 60, depth: 10.0),
          ],
          durationSeconds: 45 * 60,
          maxDepth: 30.0,
        );

        // Should match the existing dive.
        expect(resultDiveId, equals('existing-dive'));

        // Only one dive should exist.
        final allDives = await db.select(db.dives).get();
        expect(allDives.length, equals(1));
      },
    );

    test('links a gas switch to the cylinder that holds the gas', () async {
      final computerId = await insertComputer();
      final entryTime = DateTime(2026, 5, 1, 10, 0);

      final diveId = await repository.importProfile(
        computerId: computerId,
        profileStartTime: entryTime,
        points: const [
          ProfilePointData(timestamp: 0, depth: 0.0),
          ProfilePointData(timestamp: 600, depth: 20.0),
        ],
        durationSeconds: 1800,
        maxDepth: 25.0,
        tanks: const [
          TankData(index: 0, o2Percent: 32.0),
          TankData(index: 1, o2Percent: 99.0),
        ],
        gasSwitches: const [
          GasSwitchData(timestamp: 600, depth: 6.0, toTankIndex: 1),
        ],
      );

      final switches = await (db.select(
        db.gasSwitches,
      )..where((t) => t.diveId.equals(diveId))).get();
      expect(switches, hasLength(1));
      expect(switches.single.timestamp, 600);

      final tank = await (db.select(
        db.diveTanks,
      )..where((t) => t.id.equals(switches.single.tankId))).getSingle();
      expect(tank.o2Percent, 99.0);
    });

    test('persists the preset-derived cylinder attributes', () async {
      // The default tank preset fills size, rated pressure, material and the
      // preset label on downloaded cylinders (issue #386); the insert must
      // carry all four, not just the volume.
      final computerId = await insertComputer();

      final diveId = await repository.importProfile(
        computerId: computerId,
        profileStartTime: DateTime(2026, 5, 3, 10, 0),
        points: const [ProfilePointData(timestamp: 0, depth: 0.0)],
        durationSeconds: 1800,
        maxDepth: 18.0,
        tanks: const [
          TankData(
            index: 0,
            o2Percent: 21.0,
            volumeLiters: 11.1,
            workingPressure: 207.0,
            material: 'aluminum',
            presetName: 'al80',
          ),
        ],
      );

      final tank = await (db.select(
        db.diveTanks,
      )..where((t) => t.diveId.equals(diveId))).getSingle();
      expect(tank.volume, 11.1);
      expect(tank.workingPressure, 207.0);
      expect(tank.tankMaterial, 'aluminum');
      expect(tank.presetName, 'al80');
    });

    test('replace-source: links a gas switch by gas mix even when the stored '
        'tank order differs from the parsed cylinder index', () async {
      // Regression for the re-download path: existing cylinders are kept (not
      // re-created), and their tankOrder need not match the parsed cylinder
      // index. The switch must still resolve to the 99% cylinder by gas, not by
      // the index (here the 99% gas is stored at order 5, but parsed index 1).
      final computerId = await insertComputer();
      final entryTime = DateTime(2026, 5, 2, 9, 0);
      await insertDive(
        id: 'dive-redownload',
        computerId: computerId,
        diveDateTime: entryTime.millisecondsSinceEpoch,
        entryTime: entryTime.millisecondsSinceEpoch,
        exitTime: entryTime
            .add(const Duration(minutes: 30))
            .millisecondsSinceEpoch,
        duration: 1800,
        maxDepth: 25.0,
      );
      await db
          .into(db.diveTanks)
          .insert(
            const DiveTanksCompanion(
              id: Value('tank-back'),
              diveId: Value('dive-redownload'),
              o2Percent: Value(32.0),
              hePercent: Value(0.0),
              tankOrder: Value(0),
            ),
          );
      await db
          .into(db.diveTanks)
          .insert(
            const DiveTanksCompanion(
              id: Value('tank-deco'),
              diveId: Value('dive-redownload'),
              o2Percent: Value(99.0),
              hePercent: Value(0.0),
              tankOrder: Value(5),
            ),
          );

      final resultId = await repository.importProfile(
        computerId: computerId,
        profileStartTime: entryTime,
        points: const [
          ProfilePointData(timestamp: 0, depth: 0.0),
          ProfilePointData(timestamp: 600, depth: 20.0),
        ],
        durationSeconds: 1800,
        maxDepth: 25.0,
        tanks: const [
          TankData(index: 0, o2Percent: 32.0),
          TankData(index: 1, o2Percent: 99.0),
        ],
        gasSwitches: const [
          GasSwitchData(timestamp: 600, depth: 6.0, toTankIndex: 1),
        ],
      );

      expect(resultId, 'dive-redownload');
      final switches = await (db.select(
        db.gasSwitches,
      )..where((t) => t.diveId.equals('dive-redownload'))).get();
      expect(switches, hasLength(1));
      expect(
        switches.single.tankId,
        'tank-deco',
        reason: 'switch links to the 99% cylinder by gas, not by index',
      );
    });

    test('drops a gas switch that matches no cylinder', () async {
      // The switch points at a cylinder index that doesn't exist in the parse
      // (no gas match, and the index-fallback finds no tank either), so it must
      // be dropped rather than linked to the wrong tank.
      final computerId = await insertComputer();
      final diveId = await repository.importProfile(
        computerId: computerId,
        profileStartTime: DateTime(2026, 5, 3, 10, 0),
        points: const [
          ProfilePointData(timestamp: 0, depth: 0.0),
          ProfilePointData(timestamp: 600, depth: 20.0),
        ],
        durationSeconds: 1800,
        maxDepth: 25.0,
        tanks: const [TankData(index: 0, o2Percent: 32.0)],
        gasSwitches: const [
          GasSwitchData(timestamp: 600, depth: 6.0, toTankIndex: 9),
        ],
      );

      final switches = await (db.select(
        db.gasSwitches,
      )..where((t) => t.diveId.equals(diveId))).get();
      expect(switches, isEmpty);
    });

    test('creates a data source record when creating a new dive', () async {
      final computerId = await insertComputer();

      final entryTime = DateTime(2026, 3, 15, 10, 0);
      final diveId = await repository.importProfile(
        computerId: computerId,
        profileStartTime: entryTime,
        points: [
          const ProfilePointData(timestamp: 0, depth: 0.0, temperature: 22.0),
          const ProfilePointData(timestamp: 60, depth: 15.0, temperature: 21.0),
          const ProfilePointData(
            timestamp: 120,
            depth: 25.0,
            temperature: 20.0,
          ),
        ],
        durationSeconds: 45 * 60,
        maxDepth: 25.0,
        avgDepth: 15.0,
      );

      // Verify a data source was created.
      final dataSources = await (db.select(
        db.diveDataSources,
      )..where((t) => t.diveId.equals(diveId))).get();
      expect(dataSources, hasLength(1));
      expect(dataSources.first.computerId, equals(computerId));
      expect(dataSources.first.isPrimary, isTrue);
      expect(dataSources.first.maxDepth, equals(25.0));
      expect(dataSources.first.avgDepth, equals(15.0));
      expect(dataSources.first.duration, equals(45 * 60));
    });

    test('data source derives min water temp from profile samples', () async {
      final computerId = await insertComputer();

      final entryTime = DateTime(2026, 3, 15, 10, 0);
      final diveId = await repository.importProfile(
        computerId: computerId,
        profileStartTime: entryTime,
        points: [
          const ProfilePointData(timestamp: 0, depth: 0.0, temperature: 24.0),
          const ProfilePointData(timestamp: 60, depth: 15.0, temperature: 21.0),
          const ProfilePointData(
            timestamp: 120,
            depth: 25.0,
            temperature: 19.5,
          ),
        ],
        durationSeconds: 30 * 60,
        maxDepth: 25.0,
      );

      final dataSources = await (db.select(
        db.diveDataSources,
      )..where((t) => t.diveId.equals(diveId))).get();
      expect(dataSources.first.waterTemp, equals(19.5));
    });

    test('data source derives max CNS from profile samples', () async {
      final computerId = await insertComputer();

      final entryTime = DateTime(2026, 3, 15, 10, 0);
      final diveId = await repository.importProfile(
        computerId: computerId,
        profileStartTime: entryTime,
        points: [
          const ProfilePointData(timestamp: 0, depth: 0.0, cns: 10.0),
          const ProfilePointData(timestamp: 60, depth: 15.0, cns: 25.0),
          const ProfilePointData(timestamp: 120, depth: 25.0, cns: 42.0),
        ],
        durationSeconds: 30 * 60,
        maxDepth: 25.0,
      );

      final dataSources = await (db.select(
        db.diveDataSources,
      )..where((t) => t.diveId.equals(diveId))).get();
      expect(dataSources.first.cns, equals(42.0));
    });

    test('new dive derives cnsEnd from profile samples', () async {
      final computerId = await insertComputer();

      final entryTime = DateTime(2026, 3, 15, 10, 0);
      final diveId = await repository.importProfile(
        computerId: computerId,
        profileStartTime: entryTime,
        points: [
          const ProfilePointData(timestamp: 0, depth: 0.0, cns: 10.0),
          const ProfilePointData(timestamp: 60, depth: 15.0, cns: 25.0),
          const ProfilePointData(timestamp: 120, depth: 25.0, cns: 42.0),
        ],
        durationSeconds: 30 * 60,
        maxDepth: 25.0,
      );

      final dive = await (db.select(
        db.dives,
      )..where((t) => t.id.equals(diveId))).getSingle();
      expect(dive.cnsEnd, equals(42.0));
    });

    test('new dive cnsEnd is null when no samples report CNS', () async {
      final computerId = await insertComputer();

      final entryTime = DateTime(2026, 3, 15, 10, 0);
      final diveId = await repository.importProfile(
        computerId: computerId,
        profileStartTime: entryTime,
        points: [
          const ProfilePointData(timestamp: 0, depth: 0.0),
          const ProfilePointData(timestamp: 60, depth: 15.0),
        ],
        durationSeconds: 30 * 60,
        maxDepth: 15.0,
      );

      final dive = await (db.select(
        db.dives,
      )..where((t) => t.id.equals(diveId))).getSingle();
      expect(dive.cnsEnd, isNull);
    });

    test(
      'data source waterTemp is null when no samples have temperature',
      () async {
        final computerId = await insertComputer();

        final entryTime = DateTime(2026, 3, 15, 10, 0);
        final diveId = await repository.importProfile(
          computerId: computerId,
          profileStartTime: entryTime,
          points: [
            const ProfilePointData(timestamp: 0, depth: 0.0),
            const ProfilePointData(timestamp: 60, depth: 15.0),
          ],
          durationSeconds: 30 * 60,
          maxDepth: 15.0,
        );

        final dataSources = await (db.select(
          db.diveDataSources,
        )..where((t) => t.diveId.equals(diveId))).get();
        expect(dataSources.first.waterTemp, isNull);
      },
    );

    test('data source includes deco algorithm and GF settings', () async {
      final computerId = await insertComputer();

      final entryTime = DateTime(2026, 3, 15, 10, 0);
      final diveId = await repository.importProfile(
        computerId: computerId,
        profileStartTime: entryTime,
        points: [const ProfilePointData(timestamp: 0, depth: 0.0)],
        durationSeconds: 30 * 60,
        maxDepth: 25.0,
        decoAlgorithm: 'Buhlmann ZHL-16C',
        gfLow: 30,
        gfHigh: 70,
      );

      final dataSources = await (db.select(
        db.diveDataSources,
      )..where((t) => t.diveId.equals(diveId))).get();
      expect(dataSources.first.decoAlgorithm, equals('Buhlmann ZHL-16C'));
      expect(dataSources.first.gradientFactorLow, equals(30));
      expect(dataSources.first.gradientFactorHigh, equals(70));
    });

    test('importProfile persists GPS entry/exit on the dive row', () async {
      final computerId = await insertComputer();

      final diveId = await repository.importProfile(
        computerId: computerId,
        profileStartTime: DateTime(2026, 5, 22, 9, 14),
        points: [const ProfilePointData(timestamp: 0, depth: 0.0)],
        durationSeconds: 38 * 60,
        maxDepth: 30.0,
        entryLatitude: 12.34567,
        entryLongitude: 98.76543,
        exitLatitude: 12.34612,
        exitLongitude: 98.76489,
      );

      final row = await (db.select(
        db.dives,
      )..where((t) => t.id.equals(diveId))).getSingle();
      expect(row.entryLatitude, 12.34567);
      expect(row.entryLongitude, 98.76543);
      expect(row.exitLatitude, 12.34612);
      expect(row.exitLongitude, 98.76489);

      // The provenance (data source) row carries GPS too, for attribution.
      final source = await (db.select(
        db.diveDataSources,
      )..where((t) => t.diveId.equals(diveId))).getSingle();
      expect(source.entryLatitude, 12.34567);
      expect(source.exitLongitude, 98.76489);
    });
  });

  // ---------------------------------------------------------------------------
  // findOrRegisterImportedComputer (issue #1288)
  //
  // File imports name a computer on every dive but register no
  // `dive_computers` row, so the Dives filter reports "No dive computers
  // registered". Registration keys on the serial when the file supplies one
  // and falls back to the model string when it does not.
  // ---------------------------------------------------------------------------
  group('findOrRegisterImportedComputer', () {
    // dive_computers.diver_id is a real FK, so the owners must exist.
    setUp(() async {
      await insertDiver('diver-1');
      await insertDiver('diver-2');
    });

    test('creates a computer when nothing matches', () async {
      final computer = await repository.findOrRegisterImportedComputer(
        model: 'Perdix 2',
        manufacturer: 'Shearwater',
        serialNumber: 'SN-999',
        diverId: 'diver-1',
      );

      expect(computer, isNotNull);
      expect(computer!.model, 'Perdix 2');
      expect(computer.manufacturer, 'Shearwater');
      expect(computer.serialNumber, 'SN-999');
      expect(computer.diverId, 'diver-1');
      expect(computer.name, 'Shearwater Perdix 2');

      final rows = await db.select(db.diveComputers).get();
      expect(rows, hasLength(1));
      expect(rows.single.id, computer.id);
    });

    test('reuses an existing computer with the same serial', () async {
      await insertComputer(
        id: 'existing',
        diverId: 'diver-1',
        serialNumber: 'SN-999',
        manufacturer: 'Shearwater',
        model: 'Perdix',
      );

      // A different model spelling must not defeat the serial match: the
      // serial is the strong key, exactly as on the download path.
      final computer = await repository.findOrRegisterImportedComputer(
        model: 'Shearwater Perdix AI',
        serialNumber: 'SN-999',
        diverId: 'diver-1',
      );

      expect(computer!.id, 'existing');
      expect(await db.select(db.diveComputers).get(), hasLength(1));
    });

    test('matches a serial despite stored whitespace', () async {
      await insertComputer(
        id: 'existing',
        diverId: 'diver-1',
        serialNumber: '  SN-999 ',
      );

      final computer = await repository.findOrRegisterImportedComputer(
        model: 'Perdix',
        serialNumber: 'SN-999',
        diverId: 'diver-1',
      );

      expect(computer!.id, 'existing');
    });

    test('reuses a serial-less computer with the same model', () async {
      await insertComputer(
        id: 'existing',
        diverId: 'diver-1',
        manufacturer: null,
        model: 'Perdix 2',
        serialNumber: null,
      );

      final computer = await repository.findOrRegisterImportedComputer(
        model: '  perdix   2 ',
        diverId: 'diver-1',
      );

      expect(computer!.id, 'existing');
      expect(await db.select(db.diveComputers).get(), hasLength(1));
    });

    test('matches a serial-less row on its manufacturer plus model', () async {
      // The download path stores vendor and product separately; a file
      // usually carries them jammed into one string.
      await insertComputer(
        id: 'existing',
        diverId: 'diver-1',
        manufacturer: 'Shearwater',
        model: 'Perdix',
        serialNumber: null,
      );

      final computer = await repository.findOrRegisterImportedComputer(
        model: 'Shearwater Perdix',
        diverId: 'diver-1',
      );

      expect(computer!.id, 'existing');
    });

    test(
      'does not adopt a serial-bearing row when the file has no serial',
      () async {
        await insertComputer(
          id: 'registered',
          diverId: 'diver-1',
          model: 'Perdix 2',
          serialNumber: 'SN-999',
        );

        final computer = await repository.findOrRegisterImportedComputer(
          model: 'Perdix 2',
          diverId: 'diver-1',
        );

        expect(computer!.id, isNot('registered'));
        expect(await db.select(db.diveComputers).get(), hasLength(2));
      },
    );

    test('does not reuse a computer belonging to another diver', () async {
      await insertComputer(
        id: 'other-diver',
        diverId: 'diver-2',
        serialNumber: 'SN-999',
      );

      final computer = await repository.findOrRegisterImportedComputer(
        model: 'Perdix',
        serialNumber: 'SN-999',
        diverId: 'diver-1',
      );

      expect(computer!.id, isNot('other-diver'));
      expect(computer.diverId, 'diver-1');
    });

    test('is idempotent: a second call registers nothing new', () async {
      final first = await repository.findOrRegisterImportedComputer(
        model: 'Perdix 2',
        diverId: 'diver-1',
      );
      final second = await repository.findOrRegisterImportedComputer(
        model: 'Perdix 2',
        diverId: 'diver-1',
      );

      expect(second!.id, first!.id);
      expect(await db.select(db.diveComputers).get(), hasLength(1));
    });

    test('derives a deterministic id from the normalized identity', () async {
      // Every device must derive the SAME id for the same physical computer,
      // or the beforeOpen backfill mints one row per synced device and there
      // is no merge UI to clean that up.
      final computer = await repository.findOrRegisterImportedComputer(
        model: 'Perdix 2',
        diverId: 'diver-1',
      );

      expect(
        computer!.id,
        importedDiveComputerId(
          diverId: 'diver-1',
          model: 'Perdix 2',
          serialNumber: null,
        ),
      );
      // Normalization feeds the id, so spelling noise cannot fork it.
      expect(
        importedDiveComputerId(
          diverId: 'diver-1',
          model: '  PERDIX   2 ',
          serialNumber: null,
        ),
        computer.id,
      );
    });

    test('adopts the row already holding the deterministic id', () async {
      // The user renamed a computer that a previous import registered, so
      // the identity match now misses while the derived id still collides.
      // Inserting blind would throw UNIQUE constraint failed and abort the
      // whole import.
      final id = importedDiveComputerId(
        diverId: 'diver-1',
        model: 'Perdix',
        serialNumber: null,
      );
      await insertComputer(
        id: id,
        diverId: 'diver-1',
        manufacturer: null,
        model: 'My Renamed Perdix',
        serialNumber: null,
      );

      final computer = await repository.findOrRegisterImportedComputer(
        model: 'Perdix',
        diverId: 'diver-1',
      );

      expect(computer!.id, id);
      expect(computer.model, 'My Renamed Perdix');
      expect(await db.select(db.diveComputers).get(), hasLength(1));
    });

    test('breaks a tie on id so every device resolves alike', () async {
      // matchImportedComputer's contract is that candidates arrive in a
      // deterministic preference order. Ordering on updatedAt alone leaves
      // same-timestamp rows in whatever order SQLite happens to return, so
      // two devices could attribute the same dives to different rows.
      await insertComputer(
        id: 'dc-z',
        diverId: 'diver-1',
        manufacturer: null,
        model: 'Perdix 2',
        serialNumber: null,
      );
      await insertComputer(
        id: 'dc-a',
        diverId: 'diver-1',
        manufacturer: null,
        model: 'Perdix 2',
        serialNumber: null,
      );
      // Same updatedAt on both, which insertComputer already guarantees.
      await db.customStatement('UPDATE dive_computers SET updated_at = 1000');

      final computer = await repository.findOrRegisterImportedComputer(
        model: 'Perdix 2',
        diverId: 'diver-1',
      );

      expect(computer!.id, 'dc-a');
    });

    test('registers nothing when the model is blank', () async {
      final computer = await repository.findOrRegisterImportedComputer(
        model: '   ',
        diverId: 'diver-1',
      );

      expect(computer, isNull);
      expect(await db.select(db.diveComputers).get(), isEmpty);
    });

    test('marks the new computer pending so it syncs', () async {
      final computer = await repository.findOrRegisterImportedComputer(
        model: 'Perdix 2',
        diverId: 'diver-1',
      );

      final pending = await (db.select(
        db.syncRecords,
      )..where((t) => t.entityType.equals('diveComputers'))).get();
      expect(pending.map((r) => r.recordId), contains(computer!.id));
      expect(pending.single.syncStatus, 'pending');
    });
  });
}
