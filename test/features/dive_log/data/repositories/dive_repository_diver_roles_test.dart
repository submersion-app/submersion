import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

import '../../../../helpers/test_database.dart';

/// The diver's own role set on a dive (issue #1221).
void main() {
  late DiveRepository repository;

  setUp(() async {
    await setUpTestDatabase();
    repository = DiveRepository();
  });

  tearDown(tearDownTestDatabase);

  Dive dive(List<String> roles) =>
      Dive(id: '', dateTime: DateTime.utc(2026, 1, 1, 9), diverRoleIds: roles);

  test('createDive stores several roles and getDiveById reads them', () async {
    final created = await repository.createDive(
      dive(const ['diveMaster', 'diveGuide']),
    );
    final read = await repository.getDiveById(created.id);
    expect(read!.diverRoleIds, ['diveGuide', 'diveMaster']);
  });

  test('updateDive replaces the set', () async {
    final created = await repository.createDive(
      dive(const ['diveMaster', 'diveGuide']),
    );
    final loaded = await repository.getDiveById(created.id);
    await repository.updateDive(
      loaded!.copyWith(diverRoleIds: const ['instructor']),
    );
    expect((await repository.getDiveById(created.id))!.diverRoleIds, [
      'instructor',
    ]);
  });

  test('the list loader hydrates the set', () async {
    final created = await repository.createDive(
      dive(const ['diveMaster', 'diveGuide']),
    );
    final all = await repository.getAllDives();
    expect(all.firstWhere((d) => d.id == created.id).diverRoleIds, [
      'diveGuide',
      'diveMaster',
    ]);
  });

  test('a dive with no role reads an empty set', () async {
    final created = await repository.createDive(dive(const []));
    expect((await repository.getDiveById(created.id))!.diverRoleIds, isEmpty);
  });
}
