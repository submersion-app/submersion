import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_computer/data/services/raw_dive_data_service.dart';
import 'package:submersion/features/dive_computer/data/services/reparse_service.dart';
import 'package:submersion/features/dive_computer/presentation/providers/raw_dive_data_providers.dart';
import 'package:submersion/features/dive_computer/presentation/providers/reparse_providers.dart';

import '../../../../helpers/test_database.dart';

/// The per-computer raw data count is cached for the session, so it must
/// follow the table: a discard made elsewhere, or synced in from another
/// device, would otherwise leave the detail page offering to re-parse and
/// discard bytes that are gone (issue #1376).
void main() {
  late AppDatabase db;
  late ProviderContainer container;

  const nowMs = 1768471200000; // 2026-01-15 10:00 UTC

  setUp(() async {
    db = await setUpTestDatabase();
    container = ProviderContainer(
      overrides: [
        reparseServiceProvider.overrideWithValue(ReparseService(db: db)),
      ],
    );
    addTearDown(container.dispose);

    final now = DateTime.fromMillisecondsSinceEpoch(nowMs);
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
        .into(db.diveDataSources)
        .insert(
          DiveDataSourcesCompanion(
            id: const Value('s1'),
            diveId: const Value('d1'),
            computerId: const Value('c1'),
            importedAt: Value(now),
            createdAt: Value(now),
            rawData: Value(Uint8List.fromList([1, 2, 3])),
          ),
        );
  });

  tearDown(() async => tearDownTestDatabase());

  test('refreshes after raw data is discarded, without an explicit '
      'invalidate', () async {
    container.listen(rawDataCountProvider('c1'), (_, _) {});
    expect(await container.read(rawDataCountProvider('c1').future), (
      withRawData: 1,
      withoutRawData: 0,
    ));

    await RawDiveDataService(db: db).discard();
    // Let the table-update tick reach the provider.
    await pumpEventQueue();

    expect(await container.read(rawDataCountProvider('c1').future), (
      withRawData: 0,
      withoutRawData: 1,
    ));
  });

  test('the usage tile\'s provider reads the live database and refreshes '
      'after a discard', () async {
    // No service override: setUpTestDatabase installed the database the
    // production providers read through DatabaseService.
    final live = ProviderContainer();
    addTearDown(live.dispose);
    live.listen(rawDiveDataUsageProvider, (_, _) {});
    final before = await live.read(rawDiveDataUsageProvider.future);
    expect(before.diveCount, 1);
    expect(before.storedBytes, greaterThan(0));

    await live.read(rawDiveDataServiceProvider).discard(computerId: 'c1');
    await pumpEventQueue();

    expect(await live.read(rawDiveDataUsageProvider.future), (
      diveCount: 0,
      storedBytes: 0,
    ));
  });
}
