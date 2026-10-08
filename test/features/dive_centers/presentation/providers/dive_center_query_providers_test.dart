import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_query_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;
  const now = 1735689600000;

  setUp(() async {
    db = await setUpTestDatabase();
    Future<void> sql(String s) => db.customStatement(s);
    await sql(
      'INSERT INTO divers (id, name, created_at, updated_at) '
      "VALUES ('me', 'Me', $now, $now)",
    );
    await sql(
      'INSERT INTO dive_centers (id, diver_id, name, rating, created_at, '
      "updated_at) VALUES ('reef', 'me', 'Reef', 5, $now, $now), "
      "('lake', 'me', 'Lake', 2, $now, $now)",
    );
    SharedPreferences.setMockInitialValues({currentDiverIdKey: 'me'});
    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
  });
  tearDown(() async {
    container.dispose();
    await tearDownTestDatabase();
  });

  Future<List<String>> visible() async {
    final sub = container.listen(filteredDiveCentersProvider, (_, _) {});
    addTearDown(sub.close);
    for (var i = 0; i < 200; i++) {
      final v = container.read(filteredDiveCentersProvider);
      if (v.hasError) throw v.error!;
      if (v.hasValue && !v.isLoading) return [for (final c in v.value!) c.id];
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    fail('the center list never settled');
  }

  test('no query lists every center; a query narrows them', () async {
    expect(await visible(), unorderedEquals(['reef', 'lake']));
    container.read(diveCenterQueryProvider.notifier).state = ConditionNode(
      FieldPath(['rating']),
      QueryOp.gte,
      const NumberValue(4, null),
    );
    expect(await visible(), ['reef']);
  });
}
