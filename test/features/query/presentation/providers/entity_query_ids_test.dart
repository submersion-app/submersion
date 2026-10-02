import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/features/buddies/query/buddy_query_entity.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/marine_life/query/species_query_entity.dart';
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

  group('with an active diver', () {
    late ProviderContainer scoped;

    setUp(() async {
      for (final d in ['d1', 'd2']) {
        await db.customStatement(
          'INSERT INTO divers (id, name, created_at, updated_at) '
          "VALUES ('$d', '$d', $now, $now)",
        );
        await db.customStatement(
          'INSERT INTO buddies (id, diver_id, name, created_at, updated_at) '
          "VALUES ('ann-$d', '$d', 'Ann', $now, $now)",
        );
      }
      final prefs = await SharedPreferences.getInstance();
      scoped = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          validatedCurrentDiverIdProvider.overrideWith((ref) async => 'd1'),
        ],
      );
      addTearDown(scoped.dispose);
    });

    test('a per-diver root keeps only the active diver\'s rows', () async {
      final key = (root: buddyQueryEntity, query: ann);
      final sub = scoped.listen(entityQueryIdsProvider(key), (_, _) {});
      addTearDown(sub.close);
      expect(await scoped.read(entityQueryIdsProvider(key).future), {'ann-d1'});
    });

    test('a root shared across divers stays unscoped', () async {
      await db.customStatement(
        'INSERT INTO species (id, common_name, category, is_built_in) '
        "VALUES ('sp1', 'Clownfish', 'fish', 1)",
      );
      final key = (
        root: speciesQueryEntity,
        query: ConditionNode(
          FieldPath(['name']),
          QueryOp.eq,
          const StringValue('Clownfish'),
        ),
      );
      final sub = scoped.listen(entityQueryIdsProvider(key), (_, _) {});
      addTearDown(sub.close);
      expect(await scoped.read(entityQueryIdsProvider(key).future), {'sp1'});
    });
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
