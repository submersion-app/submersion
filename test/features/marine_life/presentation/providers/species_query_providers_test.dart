import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_query_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() async {
    db = await setUpTestDatabase();
    await db.customStatement(
      'INSERT INTO species (id, common_name, category, is_built_in) VALUES '
      "('t_whale', 'Test Whale', 'mammal', 0), "
      "('t_coral', 'Test Coral', 'coral', 0)",
    );
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
  });
  tearDown(() async {
    container.dispose();
    await tearDownTestDatabase();
  });

  test('the catalog query narrows the catalog', () async {
    final sub = container.listen(filteredSpeciesCatalogProvider, (_, _) {});
    addTearDown(sub.close);
    container.read(speciesCatalogQueryProvider.notifier).state = ConditionNode(
      FieldPath(['category']),
      QueryOp.eq,
      const EnumValue('mammal'),
    );
    Set<String> ours() => {
      for (final s
          in container.read(filteredSpeciesCatalogProvider).value ?? const [])
        if (s.id.startsWith('t_')) s.id,
    };
    for (var i = 0; i < 200 && ours().isEmpty; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(ours(), {'t_whale'});
  });
}
