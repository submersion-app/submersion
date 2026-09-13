import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/export/models/uddf_import_result.dart';
import 'package:submersion/features/dive_import/data/services/uddf_entity_importer.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';

import '../../../../core/services/export/uddf/uddf_raw_data_round_trip_test.dart'
    show buildRepositories, createTestDiver;
import '../../../../helpers/test_database.dart';

/// Fields the Submersion CSV importers hand the entity importer that no
/// other format carried before #1813.
void main() {
  setUp(() async => setUpTestDatabase());
  tearDown(() async => tearDownTestDatabase());

  Future<String> importData(UddfImportResult data) async {
    final diverId = await createTestDiver();
    await UddfEntityImporter().import(
      data: data,
      selections: UddfImportSelections.selectAll(data),
      repositories: buildRepositories(),
      diverId: diverId,
    );
    return diverId;
  }

  test('a site keeps its entry method', () async {
    final diverId = await importData(
      const UddfImportResult(
        sites: [
          {'uddfId': 's1', 'name': 'Reef', 'entryMethod': 'giantStride'},
        ],
      ),
    );
    final site = (await SiteRepository().getAllSites(diverId: diverId)).single;
    expect(site.entryMethod, EntryMethod.giantStride);
  });

  test('equipment keeps every attribute, not only size', () async {
    final diverId = await importData(
      const UddfImportResult(
        equipment: [
          {
            'uddfId': 'e1',
            'name': 'Hose',
            'type': 'hose',
            'size': 'L',
            'attributes': [
              {'key': 'hose_length_m', 'isCustom': false, 'valueNum': 0.5588},
              {'key': 'Batch', 'isCustom': true, 'valueText': 'B-77'},
            ],
          },
        ],
      ),
    );
    final item = (await EquipmentRepository().getAllEquipment(
      diverId: diverId,
    )).single;
    expect(item.size, 'L');
    expect(item.attrNum('hose_length_m'), 0.5588);
    expect(item.attributes.where((a) => a.isCustom).single.valueText, 'B-77');
  });

  test('a dive keeps its weather and custom fields', () async {
    await importData(
      UddfImportResult(
        dives: [
          {
            'dateTime': DateTime.utc(2025, 3, 15, 9, 5),
            'maxDepth': 20.0,
            'windSpeed': 4.2,
            'windDirection': 'northEast',
            'cloudCover': 'partlyCloudy',
            'precipitation': 'none',
            'humidity': 71.0,
            'weatherDescription': 'Sunny',
            'customFields': [
              {'key': 'Boat', 'value': 'Sea Dog'},
            ],
          },
        ],
      ),
    );
    final id = (await DiveRepository().getAllDives()).single.id;
    final dive = (await DiveRepository().getDiveById(id))!;
    expect(dive.windSpeed, 4.2);
    expect(dive.windDirection, CurrentDirection.northEast);
    expect(dive.cloudCover, CloudCover.partlyCloudy);
    expect(dive.precipitation, Precipitation.none);
    expect(dive.humidity, 71.0);
    expect(dive.weatherDescription, 'Sunny');
    expect(dive.customFields.single.key, 'Boat');
    expect(dive.customFields.single.value, 'Sea Dog');
  });
}
