import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late DiveRepository repository;

  setUp(() async {
    await setUpTestDatabase();
    repository = DiveRepository();
  });
  tearDown(() async => tearDownTestDatabase());

  test('SQL filter matches a dive that has the type among several', () async {
    await repository.createDive(
      domain.Dive(
        id: 'd1',
        dateTime: DateTime(2026, 1, 1),
        diveTypeIds: const ['shore', 'wreck'],
      ),
    );
    await repository.createDive(
      domain.Dive(
        id: 'd2',
        dateTime: DateTime(2026, 1, 2),
        diveTypeIds: const ['boat'],
      ),
    );

    final results = await repository.getDiveSummaries(
      filter: const DiveFilterState(diveTypeId: 'wreck'),
    );
    final ids = results.map((d) => d.id).toSet();
    expect(ids, contains('d1')); // 'wreck' is its second type
    expect(ids, isNot(contains('d2')));
  });

  test('in-memory apply() matches by membership', () {
    final dives = [
      domain.Dive(
        id: 'a',
        dateTime: DateTime(2026, 1, 1),
        diveTypeIds: const ['shore', 'wreck'],
      ),
      domain.Dive(
        id: 'b',
        dateTime: DateTime(2026, 1, 2),
        diveTypeIds: const ['boat'],
      ),
    ];
    final filtered = const DiveFilterState(diveTypeId: 'wreck').apply(dives);
    expect(filtered.map((d) => d.id), ['a']);
  });
}
