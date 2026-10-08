import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_query_providers.dart';
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
      'INSERT INTO buddies (id, diver_id, name, is_favorite, created_at, '
      "updated_at) VALUES ('ann', 'me', 'Ann', 1, $now, $now), "
      "('bob', 'me', 'Bob', 0, $now, $now)",
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
    final sub = container.listen(
      filteredBuddiesWithDiveCountProvider,
      (_, _) {},
    );
    addTearDown(sub.close);
    for (var i = 0; i < 200; i++) {
      final v = container.read(filteredBuddiesWithDiveCountProvider);
      if (v.hasError) throw v.error!;
      if (v.hasValue && !v.isLoading) {
        return [for (final b in v.value!) b.buddy.id];
      }
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    fail('the buddy list never settled');
  }

  test('no query lists every buddy; a query narrows them', () async {
    expect(await visible(), unorderedEquals(['ann', 'bob']));
    container.read(buddyQueryProvider.notifier).state = ConditionNode(
      FieldPath(['favorite']),
      QueryOp.eq,
      const BoolValue(true),
    );
    expect(await visible(), ['ann']);
  });
}
