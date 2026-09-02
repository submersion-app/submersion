import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_types/data/repositories/dive_type_repository.dart';
import 'package:submersion/features/dive_types/domain/entities/dive_type_entity.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late DiveTypeRepository repository;

  setUp(() async {
    await setUpTestDatabase();
    repository = DiveTypeRepository();
    // Custom dive types carry a diverId FK, so a row must exist for it to
    // reference.
    await DatabaseService.instance.database.customStatement(
      "INSERT INTO divers (id, name, created_at, updated_at) "
      "VALUES ('diver-1', 'Test Diver', 1000, 1000)",
    );
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  test('createDiveType persists and round-trips a short name', () async {
    final created = await repository.createDiveType(
      DiveTypeEntity.create(
        id: '',
        name: 'Search & Recovery',
        diverId: 'diver-1',
        shortName: 'S&R',
      ),
    );

    expect(created.shortName, 'S&R');

    final reloaded = await repository.getDiveTypeById(created.id);
    expect(reloaded?.shortName, 'S&R');
  });

  test('createDiveType with no short name leaves it null', () async {
    final created = await repository.createDiveType(
      DiveTypeEntity.create(id: '', name: 'Cenote', diverId: 'diver-1'),
    );

    expect(created.shortName, isNull);

    final reloaded = await repository.getDiveTypeById(created.id);
    expect(reloaded?.shortName, isNull);
  });

  test('updateDiveType changes the persisted short name', () async {
    final created = await repository.createDiveType(
      DiveTypeEntity.create(
        id: '',
        name: 'Cenote',
        diverId: 'diver-1',
        shortName: 'Cen',
      ),
    );

    await repository.updateDiveType(created.copyWith(shortName: 'CEN'));

    final reloaded = await repository.getDiveTypeById(created.id);
    expect(reloaded?.shortName, 'CEN');
  });
}
