import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';

import '../../../../helpers/test_database.dart';

/// PR #342, the Cressi Leonardo.
///
/// Two gaps in the download path that computer shows up: a deco stop's end
/// arrives as the same libdivecomputer event as its start, distinguished only
/// by a flag, and a computer that reports its water temperature in the dive
/// header rather than in the sample stream never had that value carried into
/// the dive record.
void main() {
  late DiveComputerRepository repository;
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = DiveComputerRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<String> insertComputer() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.diveComputers)
        .insert(
          DiveComputersCompanion.insert(
            id: 'cressi-leonardo',
            name: 'Cressi Leonardo',
            manufacturer: const Value('Cressi'),
            model: const Value('Leonardo'),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return 'cressi-leonardo';
  }

  Future<List<String>> eventTypesFor(String diveId) async {
    final rows =
        await (db.select(db.diveProfileEvents)
              ..where((t) => t.diveId.equals(diveId))
              ..orderBy([(t) => OrderingTerm(expression: t.timestamp)]))
            .get();
    return rows.map((r) => r.eventType).toList();
  }

  Future<double?> waterTempFor(String diveId) async {
    final row = await (db.select(
      db.diveDataSources,
    )..where((t) => t.diveId.equals(diveId))).getSingle();
    return row.waterTemp;
  }

  const points = [
    ProfilePointData(timestamp: 0, depth: 1.0),
    ProfilePointData(timestamp: 600, depth: 18.0),
    ProfilePointData(timestamp: 1200, depth: 6.0),
  ];

  group('deco stop events', () {
    test(
      'the END flag persists the end of the stop, not another start',
      () async {
        final computerId = await insertComputer();

        final diveId = await repository.importProfile(
          computerId: computerId,
          profileStartTime: DateTime(2026, 5, 1, 9, 0),
          points: points,
          durationSeconds: 1800,
          maxDepth: 18.0,
          events: const [
            EventData(timestamp: 600, type: 'deco', flags: 1),
            EventData(timestamp: 900, type: 'deco', flags: 2),
          ],
          forceNew: true,
        );

        expect(await eventTypesFor(diveId), ['decoStopStart', 'decoStopEnd']);
      },
    );

    test('an unflagged deco event is still the start of a stop', () async {
      final computerId = await insertComputer();

      final diveId = await repository.importProfile(
        computerId: computerId,
        profileStartTime: DateTime(2026, 5, 1, 10, 0),
        points: points,
        durationSeconds: 1800,
        maxDepth: 18.0,
        events: const [EventData(timestamp: 600, type: 'deco')],
        forceNew: true,
      );

      expect(await eventTypesFor(diveId), ['decoStopStart']);
    });

    test(
      'a start and end pair still defaults the dive type to technical',
      () async {
        final computerId = await insertComputer();

        final diveId = await repository.importProfile(
          computerId: computerId,
          profileStartTime: DateTime(2026, 5, 1, 11, 0),
          points: points,
          durationSeconds: 1800,
          maxDepth: 18.0,
          events: const [
            EventData(timestamp: 600, type: 'deco', flags: 1),
            EventData(timestamp: 900, type: 'deco', flags: 2),
          ],
          forceNew: true,
        );

        final dive = await (db.select(
          db.dives,
        )..where((t) => t.id.equals(diveId))).getSingle();
        expect(dive.diveType, 'technical');
      },
    );
  });

  group('water temperature', () {
    test(
      'the dive header value is stored when no sample carries one',
      () async {
        final computerId = await insertComputer();

        final diveId = await repository.importProfile(
          computerId: computerId,
          profileStartTime: DateTime(2026, 5, 1, 12, 0),
          points: points,
          durationSeconds: 1800,
          maxDepth: 18.0,
          minTemperature: 18.0,
          forceNew: true,
        );

        expect(await waterTempFor(diveId), 18.0);
      },
    );

    test(
      'the sample-derived minimum stands when the header carries none',
      () async {
        final computerId = await insertComputer();

        final diveId = await repository.importProfile(
          computerId: computerId,
          profileStartTime: DateTime(2026, 5, 1, 13, 0),
          points: const [
            ProfilePointData(timestamp: 0, depth: 1.0, temperature: 24.0),
            ProfilePointData(timestamp: 600, depth: 18.0, temperature: 14.5),
            ProfilePointData(timestamp: 1200, depth: 6.0, temperature: 19.0),
          ],
          durationSeconds: 1800,
          maxDepth: 18.0,
          forceNew: true,
        );

        expect(await waterTempFor(diveId), 14.5);
      },
    );

    test('a null header value never blanks a sample-derived minimum', () async {
      final computerId = await insertComputer();

      final diveId = await repository.importProfile(
        computerId: computerId,
        profileStartTime: DateTime(2026, 5, 1, 14, 0),
        points: const [
          ProfilePointData(timestamp: 0, depth: 1.0, temperature: 24.0),
          ProfilePointData(timestamp: 600, depth: 18.0, temperature: 14.5),
        ],
        durationSeconds: 1800,
        maxDepth: 18.0,
        minTemperature: null,
        forceNew: true,
      );

      expect(await waterTempFor(diveId), 14.5);
    });
  });
}
