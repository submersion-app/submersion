import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_import/data/services/dive_reimport_service.dart';

import '../../../../helpers/test_database.dart';

/// A resync writes a cylinder's start and end pressures as an import does,
/// with the glitches the import replaced (issue #2441) replaced again, so a
/// resync never puts back a signal dropout or lead-in reading the import
/// corrected (issue #4665).
void main() {
  late AppDatabase db;
  late DiveReimportService service;
  const diveId = 'dive-1';

  setUp(() async {
    db = await setUpTestDatabase();
    service = DiveReimportService(db: db);
    await db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: diveId,
            diveDateTime: 1000,
            createdAt: 1000,
            updatedAt: 1000,
          ),
        );
    await db
        .into(db.diveTanks)
        .insert(
          DiveTanksCompanion.insert(
            id: 'tank-a',
            diveId: diveId,
            tankOrder: const Value(0),
            startPressure: const Value(200),
            endPressure: const Value(90),
          ),
        );
  });

  tearDown(tearDownTestDatabase);

  /// A cylinder's series, 200 bar down to 90 bar.
  final profile = [
    for (final (t, bar) in [(0, 200.0), (60, 180.0), (1200, 90.0)])
      {
        'timestamp': t,
        'depth': 10.0,
        'allTankPressures': [
          {'tankIndex': 0, 'pressure': bar},
        ],
      },
  ];

  Future<DiveTank> resync(double start, double end) async {
    await service.applyReimport(
      diveId: diveId,
      diveData: {
        'tanks': [
          {'order': 0, 'startPressure': start, 'endPressure': end},
        ],
        'profile': profile,
      },
      now: DateTime(2026, 11, 28),
    );
    return (db.select(
      db.diveTanks,
    )..where((t) => t.id.equals('tank-a'))).getSingle();
  }

  test('a 0 bar start the series contradicts is replaced', () async {
    final tank = await resync(0.0, 90.0);
    expect(tank.startPressure, 200.0);
  });

  test('a 0 bar end the series contradicts is replaced', () async {
    final tank = await resync(200.0, 0.0);
    expect(tank.endPressure, 90.0);
  });

  test('clean pressures are written as the file has them', () async {
    final tank = await resync(198.0, 92.0);
    expect(tank.startPressure, 198.0);
    expect(tank.endPressure, 92.0);
  });
}
