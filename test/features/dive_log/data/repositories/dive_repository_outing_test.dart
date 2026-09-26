import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late DiveRepository repository;

  setUp(() async {
    await setUpTestDatabase();
    repository = DiveRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  test('createDive and updateDive round-trip outingId', () async {
    final created = await repository.createDive(
      Dive(id: '', dateTime: DateTime(2026, 6, 1, 9), outingId: 'outing-1'),
    );
    expect((await repository.getDiveById(created.id))?.outingId, 'outing-1');
    await repository.updateDive(created.copyWith(outingId: 'outing-2'));
    expect((await repository.getDiveById(created.id))?.outingId, 'outing-2');
  });

  test(
    'getDivesByOutingId returns every dive in the outing, newest first',
    () async {
      final a = await repository.createDive(
        Dive(id: '', dateTime: DateTime(2026, 6, 1, 9), outingId: 'o'),
      );
      final b = await repository.createDive(
        Dive(id: '', dateTime: DateTime(2026, 6, 1, 9, 5), outingId: 'o'),
      );
      await repository.createDive(
        Dive(id: '', dateTime: DateTime(2026, 6, 1, 9), outingId: 'other'),
      );
      final ids = (await repository.getDivesByOutingId('o')).map((d) => d.id);
      expect(ids, [b.id, a.id]);
    },
  );
}
