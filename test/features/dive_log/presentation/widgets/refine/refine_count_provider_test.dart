import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/refine/refine_count_provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';

import '../../../../../helpers/test_database.dart';

void main() {
  late DiveRepository repository;

  setUp(() async {
    await setUpTestDatabase();
    repository = DiveRepository();
    for (final (id, depth) in [('a', 10.0), ('b', 35.0), ('c', 40.0)]) {
      await repository.createDive(
        domain.Dive(id: id, dateTime: DateTime(2026, 1, 1), maxDepth: depth),
      );
    }
  });
  tearDown(() async => tearDownTestDatabase());

  ProviderContainer make() {
    final c = ProviderContainer(
      overrides: [
        diveRepositoryProvider.overrideWithValue(repository),
        validatedCurrentDiverIdProvider.overrideWith((ref) async => null),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<int> count(ProviderContainer c, DiveFilterState f) {
    final sub = c.listen(refineMatchCountProvider(f), (_, _) {});
    addTearDown(sub.close);
    return c.read(refineMatchCountProvider(f).future);
  }

  test('counts the dives a draft matches', () async {
    final c = make();
    expect(await count(c, const DiveFilterState()), 3);
    expect(await count(c, const DiveFilterState(minDepth: 30)), 2);
  });

  test('a suspended draft counts the query alone', () async {
    final c = make();
    expect(
      await count(c, const DiveFilterState(minDepth: 30, axesSuspended: true)),
      3,
    );
  });
}
