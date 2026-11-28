import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/gear_photo_repository.dart';
import 'package:submersion/features/equipment/data/services/gear_item_edit_save_service.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_catalogue_answers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_edit_fields.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

import '../../../../helpers/test_database.dart';

/// The equipment catalogue link and answers held in a gear sitting reach
/// the row at Save, through their own write (issue #5118).
void main() {
  late EquipmentRepository equipment;
  late GearItemEditSaveService service;
  final answers = EquipmentCatalogueAnswers.empty.withDeclined(
    'shearwater-perdix-2',
    ['mount'],
  );

  Future<EquipmentItem> stored() async =>
      (await equipment.getEquipmentById('g1'))!;

  Future<void> save(EditSession<EquipmentItem> session) => service.save(
    equipmentId: session.stored.id,
    apply: (s) => gearItemToSave(s, session.applyTo(s)),
    changedCardIds: session.changedCardIds,
  );

  setUp(() async {
    await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    equipment = EquipmentRepository();
    service = GearItemEditSaveService(equipment, GearPhotoRepository());
    await equipment.createEquipment(
      const EquipmentItem(
        id: 'g1',
        name: 'Perdix',
        type: EquipmentType.computer,
        brand: 'Shearwater',
        model: 'Perdix 2',
      ),
    );
  });
  tearDown(tearDownTestDatabase);

  test('a link and answers held in the sitting are written at Save', () async {
    final session = EditSession(await stored());
    addTearDown(session.dispose);
    session
      ..set(gearCatalogueIdField, 'shearwater-perdix-2')
      ..set(gearCatalogueAnswersField, answers);
    await save(session);
    final after = await stored();
    expect(after.catalogueId, 'shearwater-perdix-2');
    expect(after.catalogueAnswers, answers);
  });

  test('a sitting that changes only the name keeps the stored link', () async {
    await equipment.setCatalogueLink(
      'g1',
      catalogueId: 'shearwater-perdix-2',
      answers: answers,
    );
    final session = EditSession(await stored());
    addTearDown(session.dispose);
    session.set(gearNameField, 'My Perdix');
    await save(session);
    final after = await stored();
    expect(after.name, 'My Perdix');
    expect(after.catalogueId, 'shearwater-perdix-2');
    expect(after.catalogueAnswers, answers);
  });

  test('clearing the link in the sitting unlinks at Save', () async {
    await equipment.setCatalogueLink(
      'g1',
      catalogueId: 'shearwater-perdix-2',
      answers: EquipmentCatalogueAnswers.empty,
    );
    final session = EditSession(await stored());
    addTearDown(session.dispose);
    session.set(gearCatalogueIdField, null);
    await save(session);
    expect((await stored()).catalogueId, isNull);
  });

  test('a new item is created with the link held in its sitting', () async {
    await service.create(
      item: gearCatalogueIdField.write(
        const EquipmentItem(
          id: 'g2',
          name: 'Teric',
          type: EquipmentType.computer,
        ),
        'shearwater-teric',
      ),
      changedCardIds: const ['header'],
    );
    expect(
      (await equipment.getEquipmentById('g2'))!.catalogueId,
      'shearwater-teric',
    );
  });
}
