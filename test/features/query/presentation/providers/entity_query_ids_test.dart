import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/features/buddies/query/buddy_query_entity.dart';
import 'package:submersion/features/query/presentation/providers/narrow_by_ids.dart';
import 'package:submersion/features/query/presentation/providers/query_id_set_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

/// Any root entity's query as an id set, and a list narrowed by it (#2365).
void main() {
  late AppDatabase db;
  late ProviderContainer container;
  const now = 1735689600000;

  setUp(() async {
    db = await setUpTestDatabase();
    for (final (id, name) in [('ann', 'Ann'), ('bob', 'Bob')]) {
      await db.customStatement(
        'INSERT INTO buddies (id, name, created_at, updated_at) '
        "VALUES ('$id', '$name', $now, $now)",
      );
    }
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

  final ann = ConditionNode(
    FieldPath(['name']),
    QueryOp.eq,
    const StringValue('Ann'),
  );

  test('a query rooted at any entity runs as an id set', () async {
    final key = (root: buddyQueryEntity, query: ann);
    final sub = container.listen(entityQueryIdsProvider(key), (_, _) {});
    addTearDown(sub.close);
    expect(await container.read(entityQueryIdsProvider(key).future), {'ann'});
  });

  test('an invalid query is the id set\'s error', () async {
    final key = (
      root: buddyQueryEntity,
      query: ConditionNode(
        FieldPath(['noSuchField']),
        QueryOp.eq,
        const StringValue('x'),
      ),
    );
    final sub = container.listen(entityQueryIdsProvider(key), (_, _) {});
    addTearDown(sub.close);
    await expectLater(
      container.read(entityQueryIdsProvider(key).future),
      throwsA(anything),
    );
  });

  test('no query passes the list through; a query narrows it', () async {
    const rows = AsyncValue.data(['ann', 'bob']);
    final probe = Provider(
      (ref) =>
          narrowByQuery<String>(ref, rows, buddyQueryEntity, null, (s) => s),
    );
    expect(container.read(probe).value, ['ann', 'bob']);

    final narrowed = Provider(
      (ref) =>
          narrowByQuery<String>(ref, rows, buddyQueryEntity, ann, (s) => s),
    );
    final sub = container.listen(narrowed, (_, _) {});
    addTearDown(sub.close);
    await container.read(
      entityQueryIdsProvider((root: buddyQueryEntity, query: ann)).future,
    );
    await container.pump();
    expect(container.read(narrowed).value, ['ann']);
  });
}
