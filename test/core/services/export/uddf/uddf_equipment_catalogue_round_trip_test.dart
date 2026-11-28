import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/export/export_service.dart';
import 'package:submersion/core/services/export/uddf/uddf_full_export_service.dart';
import 'package:submersion/features/dive_import/data/services/uddf_entity_importer.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_catalogue_answers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/parsers/uddf_import_parser.dart';

import '../../../../helpers/test_database.dart';
import 'uddf_raw_data_round_trip_test.dart'
    show buildRepositories, createTestDiver;

/// An item's equipment catalogue link and answers through a UDDF backup and
/// restore (issue #5118). Nothing else in the file can rebuild them, so
/// they travel as their own elements, as a site's do.
void main() {
  final answers = EquipmentCatalogueAnswers.empty
      .withNotSame('mares-quad')
      .withDeclined('shearwater-perdix-2', ['mount']);

  setUp(() async => setUpTestDatabase());
  tearDown(() async => tearDownTestDatabase());

  Future<EquipmentItem> roundTrip(EquipmentItem item) async {
    final xml = await UddfFullExportService().generateAllDataXmlForTest(
      dives: const [],
      equipment: [item],
    );
    await tearDownTestDatabase();
    await setUpTestDatabase();
    final payload = await UddfImportParser().parse(
      Uint8List.fromList(utf8.encode(xml)),
    );
    final data = UddfImportResult(
      equipment: payload.entitiesOf(ImportEntityType.equipment),
    );
    await UddfEntityImporter().import(
      data: data,
      selections: UddfImportSelections.selectAll(data),
      repositories: buildRepositories(),
      diverId: await createTestDiver(),
    );
    return (await EquipmentRepository().getAllEquipment()).single;
  }

  test('an item keeps its link and answers', () async {
    final restored = await roundTrip(
      EquipmentItem(
        id: 'e1',
        name: 'Perdix',
        type: EquipmentType.computer,
        catalogueId: 'shearwater-perdix-2',
        catalogueAnswers: answers,
      ),
    );
    expect(restored.catalogueId, 'shearwater-perdix-2');
    expect(restored.catalogueAnswers, answers);
  });

  test('an item without a link restores without one', () async {
    final restored = await roundTrip(
      const EquipmentItem(id: 'e1', name: 'Mask', type: EquipmentType.mask),
    );
    expect(restored.catalogueId, isNull);
    expect(restored.catalogueAnswers.isEmpty, isTrue);
  });
}
