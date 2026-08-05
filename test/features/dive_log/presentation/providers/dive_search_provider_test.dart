import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late DiveRepository repository;
  late ProviderContainer container;

  setUp(() async {
    await setUpTestDatabase();
    repository = DiveRepository();
    container = ProviderContainer(
      overrides: [
        diveRepositoryProvider.overrideWithValue(repository),
        // The search provider awaits this before hitting the repository; a
        // null diver id means "all divers", which the repository query allows.
        validatedCurrentDiverIdProvider.overrideWith((ref) async => null),
        // The search count now excludes disabled safety rules; pin an empty
        // set so the test does not build the real settings/prefs chain.
        safetyReviewDisabledRulesProvider.overrideWithValue(const <String>{}),
      ],
    );
    addTearDown(container.dispose);
  });
  tearDown(() async => tearDownTestDatabase());

  test('empty query short-circuits without touching the repository', () async {
    final results = await container.read(diveSearchProvider('').future);
    expect(results, isEmpty);
  });

  test('whitespace-only query short-circuits to empty', () async {
    // The provider trims before doing any async work, so a blank-looking
    // query never debounces into a repository call.
    final results = await container.read(diveSearchProvider('   ').future);
    expect(results, isEmpty);
  });

  test('non-empty query returns bounded summary matches', () async {
    await repository.createDive(
      domain.Dive(
        id: 'd1',
        dateTime: DateTime(2026, 1, 1),
        notes: 'manta cleaning station',
      ),
    );
    await repository.createDive(
      domain.Dive(
        id: 'd2',
        dateTime: DateTime(2026, 1, 2),
        notes: 'nothing relevant',
      ),
    );

    final results = await container.read(diveSearchProvider('manta').future);
    expect(results, hasLength(1));
    expect(results.single.id, 'd1');
  });
}
