import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_scrubber_entry.dart';

import '../../../../helpers/test_database.dart';

/// The dive list's scrubber classes a dive by its breathing gas, never by a
/// suit inflation bottle (issue #4243).
void main() {
  late AppDatabase db;
  final now = DateTime(2026, 11, 6).millisecondsSinceEpoch;

  setUp(() async => db = await setUpTestDatabase());
  tearDown(tearDownTestDatabase);

  Future<void> dive(String id) => db
      .into(db.dives)
      .insert(
        DivesCompanion(
          id: Value(id),
          diveDateTime: Value(now),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

  Future<void> tank(String id, String diveId, String role, double o2) => db
      .into(db.diveTanks)
      .insert(
        DiveTanksCompanion(
          id: Value(id),
          diveId: Value(diveId),
          tankRole: Value(role),
          o2Percent: Value(o2),
          hePercent: const Value(0.0),
        ),
      );

  test('a dive with only a suit bottle has no gas class', () async {
    await dive('only');
    await tank('only-suit', 'only', 'suitInflation', 21);

    final entries = await DiveRepository().getDiveScrubberIndex();

    expect(entries.single.gas, isNull);
  });

  test('an oxygen-rich suit bottle does not make an air dive nitrox', () async {
    await dive('air');
    await tank('air-suit', 'air', 'suitInflation', 40);
    await tank('air-back', 'air', 'backGas', 21);

    final entries = await DiveRepository().getDiveScrubberIndex();

    expect(entries.single.gas, DiveScrubberGas.air);
  });
}
