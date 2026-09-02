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

  test('createDiveType defaults both visibility flags to shown', () async {
    final created = await repository.createDiveType(
      DiveTypeEntity.create(id: '', name: 'Cenote', diverId: 'diver-1'),
    );

    expect(created.showInDetailHeader, isTrue);
    expect(created.showInListView, isTrue);

    final reloaded = await repository.getDiveTypeById(created.id);
    expect(reloaded?.showInDetailHeader, isTrue);
    expect(reloaded?.showInListView, isTrue);
  });

  test('createDiveType persists explicit visibility flags', () async {
    final created = await repository.createDiveType(
      DiveTypeEntity.create(
        id: '',
        name: 'Cenote',
        diverId: 'diver-1',
        showInDetailHeader: false,
        showInListView: true,
      ),
    );

    expect(created.showInDetailHeader, isFalse);
    expect(created.showInListView, isTrue);

    final reloaded = await repository.getDiveTypeById(created.id);
    expect(reloaded?.showInDetailHeader, isFalse);
    expect(reloaded?.showInListView, isTrue);
  });

  test(
    'setDiveTypeVisibility updates both flags independently of each other',
    () async {
      final created = await repository.createDiveType(
        DiveTypeEntity.create(id: '', name: 'Cenote', diverId: 'diver-1'),
      );

      await repository.setDiveTypeVisibility(
        created.id,
        showInDetailHeader: false,
        showInListView: true,
      );

      final reloaded = await repository.getDiveTypeById(created.id);
      expect(reloaded?.showInDetailHeader, isFalse);
      expect(reloaded?.showInListView, isTrue);
    },
  );

  test('setDiveTypeVisibility is allowed on built-in types', () async {
    // Built-in types are seeded on a fresh database (see kSeedBuiltInDiveTypesSql);
    // 'wreck' is one of the seeded slugs.
    final before = await repository.getDiveTypeById('wreck');
    expect(before?.isBuiltIn, isTrue);

    await expectLater(
      repository.setDiveTypeVisibility(
        'wreck',
        showInDetailHeader: false,
        showInListView: false,
      ),
      completes,
    );

    final reloaded = await repository.getDiveTypeById('wreck');
    expect(reloaded?.showInDetailHeader, isFalse);
    expect(reloaded?.showInListView, isFalse);
    // The protected core definition is untouched.
    expect(reloaded?.name, before?.name);
  });
}
