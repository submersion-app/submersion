import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart'
    hide Dive, DiveTank, Diver;
import 'package:submersion/features/dive_computer/data/services/planned_dive_fill_service.dart';
import 'package:submersion/features/dive_computer/domain/entities/downloaded_dive.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late DiveRepository dives;
  late PlannedDiveFillService service;
  late String eric;
  const computerId = 'computer-1';

  setUp(() async {
    db = await setUpTestDatabase();
    dives = DiveRepository();
    service = PlannedDiveFillService();
    eric = (await DiverRepository().createDiver(
      Diver(
        id: '',
        name: 'Eric',
        isDefault: true,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    )).id;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.diveComputers)
        .insert(
          DiveComputersCompanion(
            id: const Value(computerId),
            name: const Value('Perdix'),
            manufacturer: const Value('Shearwater'),
            model: const Value('Perdix'),
            serialNumber: const Value('SN-1'),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  DownloadedDive download({List<DownloadedTank>? tanks}) => DownloadedDive(
    startTime: DateTime(2026, 6, 1, 9, 3),
    durationSeconds: 2700,
    maxDepth: 18.4,
    avgDepth: 11.2,
    minTemperature: 17,
    profile: [
      for (var t = 0; t <= 2700; t += 30)
        ProfileSample(timeSeconds: t, depth: t < 2400 ? 15 : 3),
    ],
    tanks:
        tanks ??
        const [
          DownloadedTank(
            index: 0,
            o2Percent: 32,
            startPressure: 200,
            endPressure: 60,
            volumeLiters: 12,
          ),
        ],
    events: const [],
    rawFingerprint: Uint8List.fromList([9, 9]),
    gfLow: 40,
    gfHigh: 85,
    decoAlgorithm: 'Buhlmann ZHL-16C',
  );

  Future<Dive> plannedDive() => dives.createPlannedDive(
    Dive(
      id: '',
      diverId: eric,
      dateTime: DateTime(2026, 6, 1, 9),
      name: 'Blue Hole plan',
      notes: 'bring the camera',
      rating: 4,
      maxDepth: 20,
      waterTemp: 20,
      tanks: const [DiveTank(id: '', gasMix: GasMix(o2: 32), volume: 12)],
      profile: const [
        DiveProfilePoint(timestamp: 0, depth: 0),
        DiveProfilePoint(timestamp: 600, depth: 20),
      ],
    ),
  );

  test(
    'fill keeps human facts, takes measured facts, promotes and numbers',
    () async {
      await dives.createDive(
        Dive(
          id: '',
          diverId: eric,
          dateTime: DateTime(2026, 5, 1),
          diveNumber: 41,
        ),
      );
      final planned = await plannedDive();

      final outcome = await service.fill(
        plannedDiveId: planned.id,
        dive: download(),
        computerId: computerId,
      );

      final filled = await dives.getDiveById(planned.id);
      expect(filled?.isPlanned, isFalse);
      expect(filled?.diveNumber, 42);
      expect(outcome.assignedDiveNumber, 42);
      // human
      expect(filled?.notes, 'bring the camera');
      expect(filled?.rating, 4);
      expect(filled?.name, 'Blue Hole plan');
      // measured
      expect(filled?.maxDepth, closeTo(18.4, 0.01));
      expect(
        filled?.entryTime?.millisecondsSinceEpoch,
        DateTime(2026, 6, 1, 9, 3).millisecondsSinceEpoch,
      );
      expect(filled?.waterTemp, 17);
      expect(filled?.gradientFactorLow, 40);
      expect(filled?.computerId, computerId);
      expect(filled?.profile.length, greaterThan(50));
    },
  );

  test('the sketched profile is replaced, not merged', () async {
    final planned = await plannedDive();
    await service.fill(
      plannedDiveId: planned.id,
      dive: download(),
      computerId: computerId,
    );
    final series = await ProfileSeriesRepository().getRowsForDives([
      planned.id,
    ]);
    expect(series, hasLength(1));
    expect(series.single.computerId, computerId);
  });

  test('planned tanks are matched by gas mix and receive pressures', () async {
    final planned = await plannedDive();
    await service.fill(
      plannedDiveId: planned.id,
      dive: download(),
      computerId: computerId,
    );
    final filled = await dives.getDiveById(planned.id);
    expect(filled?.tanks, hasLength(1));
    expect(filled?.tanks.single.startPressure, 200);
    expect(filled?.tanks.single.endPressure, 60);
    expect(filled?.tanks.single.volume, 12);
  });

  test('an unmatched downloaded tank is added', () async {
    final planned = await plannedDive();
    await service.fill(
      plannedDiveId: planned.id,
      dive: download(
        tanks: const [
          DownloadedTank(index: 0, o2Percent: 32, startPressure: 200),
          DownloadedTank(index: 1, o2Percent: 50, startPressure: 180),
        ],
      ),
      computerId: computerId,
    );
    final filled = await dives.getDiveById(planned.id);
    expect(filled?.tanks, hasLength(2));
    expect(filled?.tanks.map((t) => t.gasMix.o2), containsAll([32.0, 50.0]));
  });

  test('a data source with the fingerprint exists after the fill', () async {
    final planned = await plannedDive();
    await service.fill(
      plannedDiveId: planned.id,
      dive: download(),
      computerId: computerId,
    );
    final keys = await dives.getSourceKeysByDiveId();
    expect(keys[planned.id], contains('0909'));
  });

  test('a sibling dive at the same minute is never touched', () async {
    // Another profile's dive at 09:03 would win the time match; the fill
    // names its target, so it must not.
    final sibling = await dives.createDive(
      Dive(
        id: '',
        dateTime: DateTime(2026, 6, 1, 9, 3),
        diveNumber: 5,
        notes: 'sibling',
      ),
    );
    final planned = await plannedDive();
    await service.fill(
      plannedDiveId: planned.id,
      dive: download(),
      computerId: computerId,
    );
    expect((await dives.getDiveById(sibling.id))?.profile, isEmpty);
    expect((await dives.getDiveById(planned.id))?.profile, isNotEmpty);
  });

  test('undo restores the planned dive', () async {
    final planned = await plannedDive();
    final before = await dives.getDiveById(planned.id);
    final outcome = await service.fill(
      plannedDiveId: planned.id,
      dive: download(),
      computerId: computerId,
    );

    await service.undo(outcome);

    final after = await dives.getDiveById(planned.id);
    expect(after?.isPlanned, isTrue);
    expect(after?.diveNumber, isNull);
    expect(after?.maxDepth, before?.maxDepth);
    expect(after?.profile.length, before?.profile.length);
    expect(after?.tanks.single.startPressure, isNull);
    final sources = await (db.select(
      db.diveDataSources,
    )..where((t) => t.diveId.equals(planned.id))).get();
    expect(sources, isEmpty);
  });

  test('refuses a dive that is not planned', () async {
    final logged = await dives.createDive(
      Dive(id: '', diverId: eric, dateTime: DateTime(2026, 6, 1, 9)),
    );
    await expectLater(
      service.fill(
        plannedDiveId: logged.id,
        dive: download(),
        computerId: computerId,
      ),
      throwsA(isA<StateError>()),
    );
  });
}
