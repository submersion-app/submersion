import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/query/data/repositories/saved_query_repository.dart';
import 'package:submersion/features/query/presentation/providers/saved_query_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';
import '../../../dive_log/query/dive_query_fixture.dart';

void main() {
  late AppDatabase db;
  setUp(() async {
    db = await setUpTestDatabase();
    await seedQueryFixture(db);
  });
  tearDown(tearDownTestDatabase);

  test(
    'loads the diver\'s queries for a subject and refreshes on a write',
    () async {
      final overrides = await getBaseOverrides();
      final container = ProviderContainer(overrides: overrides.cast());
      addTearDown(container.dispose);
      await container
          .read(currentDiverIdProvider.notifier)
          .setCurrentDiver('me');
      final sub = container.listen(savedQueryLoadsProvider('dives'), (_, _) {});
      addTearDown(sub.close);

      expect(
        await container.read(savedQueryLoadsProvider('dives').future),
        isEmpty,
      );

      await SavedQueryRepository().create(
        subject: QuerySubject.dives,
        name: 'Deep',
        node: ConditionNode(
          FieldPath(['depth']),
          QueryOp.gt,
          const NumberValue(30, null),
        ),
        diverId: 'me',
      );
      await Future<void>.delayed(const Duration(milliseconds: 400));
      final loads = await container.read(
        savedQueryLoadsProvider('dives').future,
      );
      expect(loads.map((l) => l.saved.name), ['Deep']);
      expect(loads.single.problem, isNull);
      expect(
        await container.read(savedQueriesProvider(null).future),
        hasLength(1),
      );
    },
  );
}
