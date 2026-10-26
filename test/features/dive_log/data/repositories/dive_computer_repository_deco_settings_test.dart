import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';

import '../../../../helpers/test_database.dart';

/// The deco settings a computer reports for the dive (gradient factors,
/// algorithm and conservatism) land on the dive row as one set. A re-import
/// of the dive's primary reading writes what it reports, none included. A
/// second computer matched onto the dive, or a download that takes the
/// primary role from a UDDF source, leaves them alone when it reports none
/// and replaces all four when it reports any (issue #2556).
void main() {
  late DiveComputerRepository repository;
  late AppDatabase db;

  const computerId = 'perdix';
  const secondComputerId = 'teric';
  const points = [
    ProfilePointData(timestamp: 0, depth: 1.0),
    ProfilePointData(timestamp: 600, depth: 30.0),
    ProfilePointData(timestamp: 1800, depth: 6.0),
  ];

  setUp(() async {
    db = await setUpTestDatabase();
    repository = DiveComputerRepository();

    final now = DateTime.now().millisecondsSinceEpoch;
    for (final (id, model) in [
      (computerId, 'Perdix'),
      (secondComputerId, 'Teric'),
    ]) {
      await db
          .into(db.diveComputers)
          .insert(
            DiveComputersCompanion.insert(
              id: id,
              name: 'Shearwater $model',
              manufacturer: const Value('Shearwater'),
              model: Value(model),
              createdAt: now,
              updatedAt: now,
            ),
          );
    }
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<Dive> storedDive(String diveId) =>
      (db.select(db.dives)..where((t) => t.id.equals(diveId))).getSingle();

  Future<String> importWith({
    required String fromComputer,
    bool reportsDecoSettings = true,
    bool forceNew = false,
  }) {
    return repository.importProfile(
      computerId: fromComputer,
      profileStartTime: DateTime(2026, 7, 4, 10, 0),
      points: points,
      durationSeconds: 2400,
      maxDepth: 30.0,
      gfLow: reportsDecoSettings ? 30 : null,
      gfHigh: reportsDecoSettings ? 70 : null,
      decoAlgorithm: reportsDecoSettings ? 'buhlmann' : null,
      decoConservatism: reportsDecoSettings ? 1 : null,
      forceNew: forceNew,
    );
  }

  test(
    'a second computer that reports no deco settings keeps the dive\'s',
    () async {
      final diveId = await importWith(fromComputer: computerId, forceNew: true);

      final matchedId = await importWith(
        fromComputer: secondComputerId,
        reportsDecoSettings: false,
      );

      expect(matchedId, diveId);
      final dive = await storedDive(diveId);
      expect(dive.gradientFactorLow, 30);
      expect(dive.gradientFactorHigh, 70);
      expect(dive.decoAlgorithm, 'buhlmann');
      expect(dive.decoConservatism, 1);
    },
  );

  test(
    'a re-import of the primary that reports no deco settings clears them',
    () async {
      final diveId = await importWith(fromComputer: computerId, forceNew: true);
      await repository.clearSourceAndProfiles(
        diveId: diveId,
        computerId: computerId,
      );

      final reimportedId = await importWith(
        fromComputer: computerId,
        reportsDecoSettings: false,
      );

      expect(reimportedId, diveId);
      final dive = await storedDive(diveId);
      expect(dive.gradientFactorLow, isNull);
      expect(dive.gradientFactorHigh, isNull);
      expect(dive.decoAlgorithm, isNull);
      expect(dive.decoConservatism, isNull);
    },
  );

  test('a download taking the primary role from a UDDF source keeps the deco '
      'settings that source stored when it reports none', () async {
    // A UDDF import writes the dive with its settings and a summary-only
    // primary source row, and no samples.
    final start = DateTime(2026, 7, 4, 10, 0).millisecondsSinceEpoch;
    final now = DateTime.now();
    const diveId = 'uddf-dive';
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: const Value(diveId),
            diveDateTime: Value(start),
            entryTime: Value(start),
            maxDepth: const Value(30),
            gradientFactorLow: const Value(30),
            gradientFactorHigh: const Value(70),
            decoAlgorithm: const Value('buhlmann'),
            decoConservatism: const Value(1),
            createdAt: Value(now.millisecondsSinceEpoch),
            updatedAt: Value(now.millisecondsSinceEpoch),
          ),
        );
    await db
        .into(db.diveDataSources)
        .insert(
          DiveDataSourcesCompanion.insert(
            id: 'uddf-source',
            diveId: diveId,
            isPrimary: const Value(true),
            sourceFileFormat: const Value('uddf'),
            importedAt: now,
            createdAt: now,
          ),
        );

    final matchedId = await importWith(
      fromComputer: computerId,
      reportsDecoSettings: false,
    );

    expect(matchedId, diveId);
    final dive = await storedDive(diveId);
    expect(dive.gradientFactorLow, 30);
    expect(dive.gradientFactorHigh, 70);
    expect(dive.decoAlgorithm, 'buhlmann');
    expect(dive.decoConservatism, 1);
  });

  test('a second computer that reports some deco settings replaces them as a '
      'set, never mixed with the stored ones', () async {
    final diveId = await importWith(fromComputer: computerId, forceNew: true);

    final matchedId = await repository.importProfile(
      computerId: secondComputerId,
      profileStartTime: DateTime(2026, 7, 4, 10, 0),
      points: points,
      durationSeconds: 2400,
      maxDepth: 30.0,
      decoAlgorithm: 'rgbm',
      decoConservatism: 2,
    );

    expect(matchedId, diveId);
    final dive = await storedDive(diveId);
    expect(dive.decoAlgorithm, 'rgbm');
    expect(dive.decoConservatism, 2);
    expect(dive.gradientFactorLow, isNull);
    expect(dive.gradientFactorHigh, isNull);
  });
}
