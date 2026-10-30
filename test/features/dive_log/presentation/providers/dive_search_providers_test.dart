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
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
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

/// Answers text queries from the real repository but fails every dive
/// number lookup.
class _NumberFailingRepository implements DiveRepository {
  _NumberFailingRepository(this.inner);
  final DiveRepository inner;

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
  }) => filter.query is ConditionNode
      ? Future.error(StateError('number lookup failed'))
      : inner.getDiveSummaries(
          diverId: diverId,
          filter: filter,
          limit: limit,
          disabledSafetyRules: disabledSafetyRules,
        );
}

void main() {
  late DiveRepository repository;

  setUp(() async {
    await setUpTestDatabase();
    repository = DiveRepository();
  });
  tearDown(() async => tearDownTestDatabase());

  ProviderContainer makeContainer(DiveRepository repo, {String? diverId}) {
    final c = ProviderContainer(
      overrides: [
        diveRepositoryProvider.overrideWithValue(repo),
        validatedCurrentDiverIdProvider.overrideWith((ref) async => diverId),
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

  group('a typed dive number (#3455)', () {
    Future<void> dive(
      String id,
      DateTime when, {
      int? number,
      String? notes,
      String? diverId,
    }) => repository.createDive(
      domain.Dive(
        id: id,
        diveNumber: number,
        dateTime: when,
        notes: notes ?? '',
        diverId: diverId,
      ),
    );

    test('puts that dive above the text matches', () async {
      await dive(
        'swim',
        DateTime(2026, 3, 1),
        number: 487,
        notes: '500 m swim',
      );
      await dive('target', DateTime(2026, 1, 1), number: 500, notes: 'reef');
      await dive('other', DateTime(2026, 2, 1), number: 12, notes: 'reef');
      final c = makeContainer(repository);
      final rows = await jump(c, TextNode(['500']));
      expect(rows.map((d) => d.id), ['target', 'swim']);
    });

    test('a leading # finds the same dive', () async {
      await dive('target', DateTime(2026, 1, 1), number: 500);
      final c = makeContainer(repository);
      final rows = await jump(c, TextNode(['#500']));
      expect(rows.map((d) => d.id), ['target']);
    });

    test('dives sharing the number all show, newest first', () async {
      await dive('older', DateTime(2025, 1, 1), number: 500);
      await dive('newer', DateTime(2026, 1, 1), number: 500);
      final c = makeContainer(repository);
      final rows = await jump(c, TextNode(['500']));
      expect(rows.map((d) => d.id), ['newer', 'older']);
    });

    test('a dive matching both ways shows once, as the number', () async {
      await dive('both', DateTime(2026, 1, 1), number: 500, notes: '500 bar');
      final c = makeContainer(repository);
      final rows = await jump(c, TextNode(['500']));
      expect(rows.map((d) => d.id), ['both']);
    });

    test('no dive with the number leaves the text matches alone', () async {
      await dive(
        'swim',
        DateTime(2026, 3, 1),
        number: 487,
        notes: '500 m swim',
      );
      final c = makeContainer(repository);
      final rows = await jump(c, TextNode(['500']));
      expect(rows.map((d) => d.id), ['swim']);
    });

    test('a failed number lookup still shows the text matches', () async {
      await dive(
        'swim',
        DateTime(2026, 3, 1),
        number: 487,
        notes: '500 m swim',
      );
      final c = makeContainer(_NumberFailingRepository(repository));
      final rows = await jump(c, TextNode(['500']));
      expect(rows.map((d) => d.id), ['swim']);
    });

    test('the rows stay capped', () async {
      for (var i = 0; i < kDiveJumpResultLimit; i++) {
        await dive('t$i', DateTime(2026, 1, 1 + i), notes: '500 bar');
      }
      await dive('target', DateTime(2020, 1, 1), number: 500);
      final c = makeContainer(repository);
      final rows = await jump(c, TextNode(['500']));
      expect(rows, hasLength(kDiveJumpResultLimit));
      expect(rows.first.id, 'target');
    });

    test("only the current diver's dive", () async {
      Future<String> diver(String name) async =>
          (await DiverRepository().createDiver(
            Diver(
              id: '',
              name: name,
              createdAt: DateTime(2026),
              updatedAt: DateTime(2026),
            ),
          )).id;
      final ana = await diver('Ana');
      final bo = await diver('Bo');
      await dive('mine', DateTime(2026, 1, 1), number: 500, diverId: ana);
      await dive('theirs', DateTime(2026, 2, 1), number: 500, diverId: bo);
      final c = makeContainer(repository, diverId: ana);
      final rows = await jump(c, TextNode(['500']));
      expect(rows.map((d) => d.id), ['mine']);
    });
  });
}
