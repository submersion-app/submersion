import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/features/dive_sites/domain/entities/site_with_dive_count.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

/// The site list narrows its rows to the compiled query's id set (#2365).
void main() {
  late AppDatabase db;
  late ProviderContainer container;
  const now = 1735689600000;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    db = await setUpTestDatabase();
    await db
        .into(db.divers)
        .insert(
          DiversCompanion.insert(
            id: 'me',
            name: 'me',
            createdAt: now,
            updatedAt: now,
          ),
        );
    for (final (id, depth) in [('deep', 40.0), ('shallow', 8.0)]) {
      await db
          .into(db.diveSites)
          .insert(
            DiveSitesCompanion.insert(
              id: id,
              name: id,
              diverId: const Value('me'),
              maxDepth: Value(depth),
              createdAt: now,
              updatedAt: now,
            ),
          );
    }
    await prefs.setString(currentDiverIdKey, 'me');
    container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    final sub = container.listen(filteredSitesWithCountsProvider, (_, _) {});
    addTearDown(sub.close);
  });
  tearDown(() async {
    container.dispose();
    await tearDownTestDatabase();
  });

  /// The list's value once it stops loading.
  Future<AsyncValue<List<SiteWithDiveCount>>> settled() async {
    for (var i = 0; i < 200; i++) {
      final v = container.read(filteredSitesWithCountsProvider);
      if (!v.isLoading) return v;
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    return container.read(filteredSitesWithCountsProvider);
  }

  test('the filtered list narrows to the compiled id set', () async {
    container.read(siteFilterProvider.notifier).state = const SiteFilterState(
      minDepth: 20,
    );
    final value = await settled();
    expect(value.value!.map((s) => s.site.id), ['deep']);
  });

  test('an invalid query surfaces as the list error', () async {
    container.read(siteFilterProvider.notifier).state = SiteFilterState(
      query: ConditionNode(
        FieldPath(['warpFactor']),
        QueryOp.gt,
        const NumberValue(9, null),
      ),
    );
    final value = await settled();
    expect(value.hasError, isTrue);
  });
}
