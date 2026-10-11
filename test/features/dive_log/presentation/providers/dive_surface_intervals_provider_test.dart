import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';

import '../../../../helpers/test_database.dart';

/// The table's surface intervals follow every input of their SQL (#2984),
/// including a profile span that stands in for a missing runtime.
void main() {
  late AppDatabase db;
  setUp(() async => db = await setUpTestDatabase());
  tearDown(() async => tearDownTestDatabase());

  test('a profile series write refreshes the next dive\'s interval', () async {
    final repository = DiveRepository();
    final at = DateTime.utc(2026, 4, 1, 10);
    await repository.createDive(
      domain.Dive(id: 'a', dateTime: at, entryTime: at),
    );
    await repository.createDive(
      domain.Dive(
        id: 'b',
        dateTime: at.add(const Duration(hours: 1)),
        entryTime: at.add(const Duration(hours: 1)),
      ),
    );
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final sub = container.listen(diveSurfaceIntervalsProvider, (_, _) {});
    addTearDown(sub.close);

    expect(
      (await container.read(diveSurfaceIntervalsProvider.future))['b'],
      const Duration(hours: 1),
    );

    // Dive a gains a 20-minute profile and nothing else changes in `dives`.
    await db
        .into(db.diveProfileSeries)
        .insert(
          DiveProfileSeriesCompanion(
            id: const Value('s-a'),
            diveId: const Value('a'),
            isPrimary: const Value(true),
            sampleCount: const Value(2),
            startTimestamp: const Value(0),
            endTimestamp: const Value(1200),
            maxDepth: const Value(12),
            firstDepth: const Value(0),
            lastDepth: const Value(0),
            codecVersion: const Value(1),
            samples: Value(Uint8List(0)),
            createdAt: const Value(1000),
            updatedAt: const Value(1000),
          ),
        );
    await Future<void>.delayed(const Duration(milliseconds: 600));

    expect(
      (await container.read(diveSurfaceIntervalsProvider.future))['b'],
      const Duration(minutes: 40),
    );
  });

  test('is released once the table stops listening', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final sub = container.listen(diveSurfaceIntervalsProvider, (_, _) {});
    await container.read(diveSurfaceIntervalsProvider.future);
    expect(container.exists(diveSurfaceIntervalsProvider), isTrue);

    sub.close();
    await container.pump();

    expect(container.exists(diveSurfaceIntervalsProvider), isFalse);
  });

  test(
    'a write to an unrelated dive table does not re-run the query',
    () async {
      final repository = DiveRepository();
      final at = DateTime.utc(2026, 4, 1, 10);
      await repository.createDive(
        domain.Dive(id: 'a', dateTime: at, entryTime: at),
      );
      final container = ProviderContainer();
      addTearDown(container.dispose);
      var emissions = 0;
      final sub = container.listen(
        diveSurfaceIntervalsProvider,
        (_, _) => emissions++,
      );
      addTearDown(sub.close);
      await container.read(diveSurfaceIntervalsProvider.future);
      await Future<void>.delayed(const Duration(milliseconds: 600));
      final settled = emissions;

      // A tank row: the detail tick fires, the surface interval inputs do not.
      await db
          .into(db.diveTanks)
          .insert(
            const DiveTanksCompanion(id: Value('t-a'), diveId: Value('a')),
          );
      await Future<void>.delayed(const Duration(milliseconds: 600));

      expect(emissions, settled);
    },
  );
}
