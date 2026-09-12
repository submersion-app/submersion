import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/data/repositories/dive_sensor_summary_repository.dart';
import 'package:submersion/features/equipment/data/services/sensor_summary_worker.dart';
import 'package:submersion/features/equipment/presentation/providers/dive_sensor_summary_providers.dart';

import '../../../../helpers/test_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late ProviderContainer container;
  var runs = 0;

  setUp(() async {
    db = await setUpTestDatabase();
    runs = 0;
    container = ProviderContainer(
      overrides: [
        diveSensorSummaryRepositoryProvider.overrideWithValue(
          DiveSensorSummaryRepository(
            db: db,
            runner: (input) async {
              runs++;
              return computeSensorSummaryFromBlobs(input);
            },
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    await db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: 'd1',
            diveDateTime: 1000,
            createdAt: 1000,
            updatedAt: 1000,
          ).copyWith(runtime: const Value(600), diveMode: const Value('ccr')),
        );
  });

  tearDown(tearDownTestDatabase);

  test('computes on first read and serves the row afterwards', () async {
    final first = await container.read(diveSensorSummaryProvider('d1').future);
    expect(first!.scrubberConsumedMinutes, 10);
    expect(runs, 1);

    container.invalidate(diveSensorSummaryProvider('d1'));
    final second = await container.read(diveSensorSummaryProvider('d1').future);
    expect(second, first);
    expect(runs, 1);
  });

  test('a dive write ticks the provider into a recompute', () async {
    final sub = container.listen(diveSensorSummaryProvider('d1'), (_, _) {});
    addTearDown(sub.close);
    await container.read(diveSensorSummaryProvider('d1').future);
    expect(runs, 1);

    await (db.update(db.dives)..where((t) => t.id.equals('d1'))).write(
      const DivesCompanion(updatedAt: Value(2000), runtime: Value(1200)),
    );
    // The detail-change stream is debounced; poll rather than pump the
    // event queue (see the drift tick memory).
    for (var i = 0; i < 50 && runs < 2; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    final refreshed = await container.read(
      diveSensorSummaryProvider('d1').future,
    );
    expect(runs, 2);
    expect(refreshed!.scrubberConsumedMinutes, 20);
  });

  test('an unknown dive yields null', () async {
    expect(await container.read(diveSensorSummaryProvider('x').future), isNull);
  });
}
