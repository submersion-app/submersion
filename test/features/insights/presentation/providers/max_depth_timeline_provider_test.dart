import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/insights/presentation/providers/vertical_distance_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// The Max Depths Added Up card's timeline follows the current diver and
/// refreshes when a dive is written (issue #4569).
void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  final day1 = DateTime.utc(2026, 1, 1).millisecondsSinceEpoch;

  Future<void> diver(String id) => db
      .into(db.divers)
      .insert(
        DiversCompanion(
          id: Value(id),
          name: Value(id),
          createdAt: Value(day1),
          updatedAt: Value(day1),
        ),
      );

  Future<void> dive(String id, double maxDepth, {String? diverId}) => db
      .into(db.dives)
      .insert(
        DivesCompanion(
          id: Value(id),
          diveDateTime: Value(day1),
          maxDepth: Value(maxDepth),
          diverId: Value(diverId),
          createdAt: Value(day1),
          updatedAt: Value(day1),
        ),
      );

  Future<ProviderContainer> container() async {
    final c = ProviderContainer(overrides: (await getBaseOverrides()).cast());
    addTearDown(c.dispose);
    // Keep the provider subscribed so a write invalidates it.
    c.listen(maxDepthTimelineProvider, (_, _) {});
    return c;
  }

  test('reads the current diver\'s dives', () async {
    await diver('x');
    await diver('y');
    await dive('a', 20, diverId: 'x');
    await dive('b', 30, diverId: 'y');

    final c = await container();
    await c.read(currentDiverIdProvider.notifier).setCurrentDiver('x');

    expect((await c.read(maxDepthTimelineProvider.future)).totalMeters, 20);
  });

  test('refreshes when a dive is written', () async {
    await dive('a', 20);

    final c = await container();
    expect((await c.read(maxDepthTimelineProvider.future)).totalMeters, 20);

    await dive('b', 15);

    // The Insights change tick is debounced, so wait for the refresh to land.
    double? total() => c.read(maxDepthTimelineProvider).value?.totalMeters;
    for (var i = 0; i < 200 && total() != 35; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(total(), 35);
  });
}
