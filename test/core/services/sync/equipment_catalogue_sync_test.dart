import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_catalogue_answers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';

import '../../../helpers/test_database.dart';

/// An item's equipment catalogue link and answers, through the sync
/// serializer itself: a link or an answer given on one device is known on
/// the next, so a declined offer is not made again there (issue #5118).
void main() {
  late SyncDataSerializer serializer;
  late EquipmentRepository repo;
  final answers = EquipmentCatalogueAnswers.empty.withDeclined(
    'shearwater-perdix-2',
    ['mount'],
  );

  setUp(() async {
    await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    serializer = SyncDataSerializer();
    repo = EquipmentRepository();
  });
  tearDown(tearDownTestDatabase);

  test('an item is written out with its link and answers', () async {
    await repo.createEquipment(
      EquipmentItem(
        id: 'e1',
        name: 'Perdix',
        type: EquipmentType.computer,
        catalogueId: 'shearwater-perdix-2',
        catalogueAnswers: answers,
      ),
    );
    final record = await serializer.fetchRecord('equipment', 'e1');
    expect(record!['catalogueId'], 'shearwater-perdix-2');
    expect(record['catalogueAnswers'], answers.encode());
  });

  test('an item without either is written out with none', () async {
    await repo.createEquipment(
      const EquipmentItem(id: 'e1', name: 'Mask', type: EquipmentType.mask),
    );
    final record = await serializer.fetchRecord('equipment', 'e1');
    expect(record!.containsKey('catalogueId'), isTrue);
    expect(record['catalogueId'], isNull);
    expect(record['catalogueAnswers'], isNull);
  });

  test("a record round-trips from one device's row to another's", () async {
    await repo.createEquipment(
      EquipmentItem(
        id: 'e1',
        name: 'Perdix',
        type: EquipmentType.computer,
        catalogueId: 'shearwater-perdix-2',
        catalogueAnswers: answers,
      ),
    );
    final record = (await serializer.fetchRecord('equipment', 'e1'))!;

    await tearDownTestDatabase();
    await setUpTestDatabase();
    await SyncDataSerializer().upsertRecord('equipment', record);

    final arrived = (await EquipmentRepository().getEquipmentById('e1'))!;
    expect(arrived.catalogueId, 'shearwater-perdix-2');
    expect(arrived.catalogueAnswers, answers);
  });
}
