import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/models/sort_state.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_search_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

class _FailingRepository implements DiveRepository {
  @override
  Stream<void> watchDivesChanges() => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<List<DiveSummary>> getDiveSummaries({
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
    DiveSummaryCursor? cursor,
    int? offset,
    int limit = 50,
    SortState<DiveSortField>? sort,
    Set<String> disabledSafetyRules = const {},
  }) => Future.error(StateError('boom'));
}

void main() {
  late DiveRepository repository;

  setUp(() async {
    await setUpTestDatabase();
    repository = DiveRepository();
  });
  tearDown(() async => tearDownTestDatabase());

  ProviderContainer makeContainer(DiveRepository repo) {
    final c = ProviderContainer(
      overrides: [
        diveRepositoryProvider.overrideWithValue(repo),
        validatedCurrentDiverIdProvider.overrideWith((ref) async => null),
        safetyReviewDisabledRulesProvider.overrideWithValue(const <String>{}),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<List<DiveSummary>> jump(ProviderContainer c, QueryNode q) async {
    final sub = c.listen(diveJumpResultsProvider(q), (_, _) {});
    addTearDown(sub.close);
    return c.read(diveJumpResultsProvider(q).future);
  }

  test('the row shows when opened or when anything is filtered', () {
    final c = makeContainer(repository);
    expect(c.read(diveSearchBarVisibleProvider), isFalse);
    c.read(diveSearchBarOpenProvider.notifier).state = true;
    expect(c.read(diveSearchBarVisibleProvider), isTrue);
    c.read(diveSearchBarOpenProvider.notifier).state = false;
    c.read(diveFilterProvider.notifier).state = const DiveFilterState(
      minDepth: 30,
    );
    expect(c.read(diveSearchBarVisibleProvider), isTrue);
  });

  test('jump results ignore the list filter, newest first', () async {
    await repository.createDive(
      domain.Dive(
        id: 'shallow',
        dateTime: DateTime(2026, 1, 1),
        maxDepth: 10,
        notes: 'manta cleaning station',
      ),
    );
    await repository.createDive(
      domain.Dive(
        id: 'deep',
        dateTime: DateTime(2026, 1, 2),
        maxDepth: 40,
        notes: 'manta at depth',
      ),
    );
    await repository.createDive(
      domain.Dive(id: 'other', dateTime: DateTime(2026, 1, 3), notes: 'reef'),
    );
    final c = makeContainer(repository);
    // The list is filtered to deep dives; the jump list must still find
    // the shallow manta dive (the old Search overlay's behaviour).
    c.read(diveFilterProvider.notifier).state = const DiveFilterState(
      minDepth: 30,
    );
    final rows = await jump(c, TextNode(['manta']));
    expect(rows.map((d) => d.id), ['deep', 'shallow']);
  });

  test('jump results are capped', () async {
    for (var i = 0; i < kDiveJumpResultLimit + 2; i++) {
      await repository.createDive(
        domain.Dive(
          id: 'm$i',
          dateTime: DateTime(2026, 1, 1 + i),
          notes: 'manta',
        ),
      );
    }
    final c = makeContainer(repository);
    expect(await jump(c, TextNode(['manta'])), hasLength(kDiveJumpResultLimit));
  });

  test('a failing jump query yields no rows instead of an error', () async {
    final c = makeContainer(_FailingRepository());
    expect(await jump(c, TextNode(['manta'])), isEmpty);
  });
}
