import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_catalogue_answers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';

import '../../../../helpers/test_database.dart';

/// An item's equipment catalogue link and answers (issue #5118): stored on
/// create, written by their own call, and never touched by an ordinary
/// update, so no path that rebuilds an item can drop them.
void main() {
  late EquipmentRepository repo;
  final answers = EquipmentCatalogueAnswers.empty.withNotSame('mares-quad');

  setUp(() async {
    await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    repo = EquipmentRepository();
  });
  tearDown(tearDownTestDatabase);

  test('createEquipment stores the link and answers', () async {
    await repo.createEquipment(
      EquipmentItem(
        id: 'e1',
        name: 'Perdix',
        type: EquipmentType.computer,
        catalogueId: 'shearwater-perdix-2',
        catalogueAnswers: answers,
      ),
    );
    final read = (await repo.getEquipmentById('e1'))!;
    expect(read.catalogueId, 'shearwater-perdix-2');
    expect(read.catalogueAnswers, answers);
  });

  test('updateEquipment leaves the link as stored', () async {
    await repo.createEquipment(
      const EquipmentItem(
        id: 'e1',
        name: 'Perdix',
        type: EquipmentType.computer,
        catalogueId: 'shearwater-perdix-2',
      ),
    );
    // A path that rebuilds the item without the link.
    await repo.updateEquipment(
      const EquipmentItem(
        id: 'e1',
        name: 'Renamed',
        type: EquipmentType.computer,
      ),
    );
    final read = (await repo.getEquipmentById('e1'))!;
    expect(read.name, 'Renamed');
    expect(read.catalogueId, 'shearwater-perdix-2');
  });

  test('setCatalogueLink writes both and can clear them', () async {
    await repo.createEquipment(
      const EquipmentItem(
        id: 'e1',
        name: 'Perdix',
        type: EquipmentType.computer,
      ),
    );
    await repo.setCatalogueLink(
      'e1',
      catalogueId: 'shearwater-perdix-2',
      answers: answers,
    );
    var read = (await repo.getEquipmentById('e1'))!;
    expect(read.catalogueId, 'shearwater-perdix-2');
    expect(read.catalogueAnswers, answers);

    await repo.setCatalogueLink(
      'e1',
      catalogueId: null,
      answers: EquipmentCatalogueAnswers.empty,
    );
    read = (await repo.getEquipmentById('e1'))!;
    expect(read.catalogueId, isNull);
    expect(read.catalogueAnswers.isEmpty, isTrue);
  });
}
