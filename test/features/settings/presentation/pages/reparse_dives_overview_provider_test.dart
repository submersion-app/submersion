import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_computer/data/services/reparse_service.dart';
import 'package:submersion/features/dive_computer/presentation/providers/reparse_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/pages/reparse_dives_page.dart';

import '../../../../core/database/change_log/change_log_support.dart';
import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;
  final now = DateTime.utc(2026, 1, 15);

  Future<void> addSource(String id, String diveId, String computerId) => db
      .into(db.diveDataSources)
      .insert(
        DiveDataSourcesCompanion(
          id: Value(id),
          diveId: Value(diveId),
          computerId: Value(computerId),
          rawData: Value(Uint8List.fromList([1])),
          importedAt: Value(now),
          createdAt: Value(now),
        ),
      );

  setUp(() async {
    db = createTestDatabase();
    await insertDiver(db, 'me');
    for (final id in ['c1', 'c2']) {
      await db
          .into(db.diveComputers)
          .insert(
            DiveComputersCompanion.insert(
              id: id,
              name: 'Computer $id',
              createdAt: 0,
              updatedAt: 0,
            ),
          );
    }
    for (final id in ['d1', 'd2', 'manual']) {
      await insertDive(db, id, diverId: 'me');
    }
    // d1 was downloaded from both computers.
    await addSource('s1', 'd1', 'c1');
    await addSource('s2', 'd1', 'c2');
    await addSource('s3', 'd2', 'c1');
    container = ProviderContainer(
      overrides: [
        reparseServiceProvider.overrideWithValue(ReparseService(db: db)),
        validatedCurrentDiverIdProvider.overrideWith((ref) async => 'me'),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test('counts each dive once, per computer, and the dives without', () async {
    final overview = await container.read(reparseDivesOverviewProvider.future);

    expect(overview.total, 2);
    expect(
      {for (final c in overview.byComputer) c.computerId: c.dives},
      {'c1': 2, 'c2': 1},
    );
    expect(overview.withoutRawData, 1);
  });

  test('refreshes when stored raw data changes', () async {
    final sub = container.listen(reparseDivesOverviewProvider, (_, _) {});
    addTearDown(sub.close);
    expect(
      (await container.read(reparseDivesOverviewProvider.future)).total,
      2,
    );

    await addSource('s4', 'manual', 'c2');
    await pumpEventQueue();

    expect(
      (await container.read(reparseDivesOverviewProvider.future)).total,
      3,
    );
  });

  test('refreshes when a dive without raw data is added', () async {
    final sub = container.listen(reparseDivesOverviewProvider, (_, _) {});
    addTearDown(sub.close);
    expect(
      (await container.read(
        reparseDivesOverviewProvider.future,
      )).withoutRawData,
      1,
    );

    await insertDive(db, 'manual-2', diverId: 'me');
    await pumpEventQueue();

    expect(
      (await container.read(
        reparseDivesOverviewProvider.future,
      )).withoutRawData,
      2,
    );
  });
}
