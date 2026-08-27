import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;

import '../../../../helpers/test_database.dart';

void main() {
  late DiveRepository repository;

  setUp(() async {
    await setUpTestDatabase();
    repository = DiveRepository();
  });
  tearDown(() async => tearDownTestDatabase());

  domain.Dive dive(String id, {String? notes, String? name, DateTime? when}) =>
      domain.Dive(
        id: id,
        dateTime: when ?? DateTime(2026, 1, 1),
        notes: notes ?? '',
        name: name,
      );

  test('matches notes and name, most recent first', () async {
    await repository.createDive(
      dive('d1', notes: 'great manta sighting', when: DateTime(2026, 1, 1)),
    );
    await repository.createDive(
      dive('d2', name: 'Manta Point', when: DateTime(2026, 2, 1)),
    );
    await repository.createDive(dive('d3', notes: 'nothing here'));

    final results = await repository.searchDiveSummaries('manta');
    expect(results.map((s) => s.id).toList(), ['d2', 'd1']);
  });

  test('bound keeps the most recent matches and honors limit', () async {
    for (var i = 0; i < 8; i++) {
      await repository.createDive(
        dive('d$i', notes: 'wreck dive', when: DateTime(2026, 1, 1 + i)),
      );
    }

    final results = await repository.searchDiveSummaries('wreck', limit: 5);
    expect(results, hasLength(5));
    expect(results.first.id, 'd7');
    final ids = results.map((s) => s.id).toList();
    expect(ids, isNot(contains('d0')));
    expect(ids, isNot(contains('d1')));
    expect(ids, isNot(contains('d2')));
  });

  test('tie-broken bound matches the final ordering', () async {
    // All six dives share the same timestamp, so the LIMIT cutoff is decided
    // entirely by the tie-breakers. The bounded id pre-query must apply the
    // same dive_number/id tie-breakers as the hydration query, otherwise it
    // can drop dives that should survive the cut.
    final when = DateTime(2026, 1, 1);
    for (final (id, number) in [
      ('a', 10),
      ('b', 20),
      ('c', 30),
      ('d', 40),
      ('e', 50),
      ('f', 60),
    ]) {
      await repository.createDive(
        domain.Dive(
          id: id,
          dateTime: when,
          notes: 'reef survey',
          diveNumber: number,
        ),
      );
    }

    final results = await repository.searchDiveSummaries('reef', limit: 3);
    // Highest dive_number wins the tie: f(60), e(50), d(40).
    expect(results.map((s) => s.id).toList(), ['f', 'e', 'd']);
  });

  test('empty or whitespace query returns empty', () async {
    await repository.createDive(dive('present', notes: 'manta'));
    expect(await repository.searchDiveSummaries(''), isEmpty);
    expect(await repository.searchDiveSummaries('   '), isEmpty);
  });

  test('surrounding whitespace is trimmed before matching', () async {
    await repository.createDive(dive('d1', notes: 'giant manta'));

    // Without trimming, "%manta %" would fail to match a trailing-word hit.
    expect(await repository.searchDiveSummaries('manta '), hasLength(1));
    expect(await repository.searchDiveSummaries('  manta  '), hasLength(1));
  });

  test('summary fields are populated', () async {
    await repository.createDive(
      domain.Dive(
        id: 's1',
        dateTime: DateTime(2026, 3, 1),
        notes: 'blue water',
        maxDepth: 30.5,
        rating: 4,
        isFavorite: true,
      ),
    );

    final results = await repository.searchDiveSummaries('blue');
    final s = results.single;
    expect(s.maxDepth, 30.5);
    expect(s.rating, 4);
    expect(s.isFavorite, isTrue);
    expect(s.diveTypeIds, isNotEmpty);
    expect(s.sortTimestamp, DateTime(2026, 3, 1).millisecondsSinceEpoch);
  });

  test('no matches returns empty', () async {
    await repository.createDive(dive('x1', notes: 'kelp forest'));
    expect(await repository.searchDiveSummaries('zzznope'), isEmpty);
  });

  test('diverId scopes results', () async {
    await repository.createDive(dive('mine', notes: 'manta'));

    final unscoped = await repository.searchDiveSummaries('manta');
    expect(unscoped.map((s) => s.id), contains('mine'));

    final scoped = await repository.searchDiveSummaries(
      'manta',
      diverId: 'some-other-diver',
    );
    expect(scoped, isEmpty);
  });
}
