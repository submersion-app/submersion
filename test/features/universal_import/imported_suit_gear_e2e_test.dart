// Parse -> import -> read back, against the in-memory database (#1824).
//
// The Suit Thickness statistic reads three things: equipment.type as the text
// 'wetsuit' or 'drysuit', a dive_equipment link, and for a thickness bucket a
// curated (is_custom = 0) thickness_mm row with a numeric value. These tests
// assert that persisted shape and then the statistic itself, so an imported
// suit is proven to reach the chart.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/export/export_service.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/certifications/data/repositories/certification_repository.dart';
import 'package:submersion/features/courses/data/repositories/course_repository.dart';
import 'package:submersion/features/dive_centers/data/repositories/dive_center_repository.dart';
import 'package:submersion/features/dive_import/data/services/uddf_entity_importer.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_repository.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_types/data/repositories/dive_type_repository.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart'
    as domain;
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_set_repository_impl.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/statistics/data/repositories/statistics_repository.dart';
import 'package:submersion/features/tags/data/repositories/tag_repository.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/features/universal_import/data/csv/models/import_configuration.dart';
import 'package:submersion/features/universal_import/data/csv/models/transformed_rows.dart';
import 'package:submersion/features/universal_import/data/csv/pipeline/csv_correlator.dart';
import 'package:submersion/features/universal_import/data/models/field_mapping.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/parsers/subsurface_xml_parser.dart';

import '../../helpers/test_database.dart';

ImportRepositories _repositories() => ImportRepositories(
  tripRepository: TripRepository(),
  equipmentRepository: EquipmentRepository(),
  equipmentSetRepository: EquipmentSetRepository(),
  buddyRepository: BuddyRepository(),
  diveCenterRepository: DiveCenterRepository(),
  certificationRepository: CertificationRepository(),
  tagRepository: TagRepository(),
  diveTypeRepository: DiveTypeRepository(),
  siteRepository: SiteRepository(),
  diveRepository: DiveRepository(),
  tankPressureRepository: TankPressureRepository(),
  courseRepository: CourseRepository(),
);

const _diverId = 'diver-suit-e2e';

Future<String> _createDiver() async {
  final now = DateTime.now();
  const diverId = _diverId;
  await DiverRepository().createDiver(
    domain.Diver(
      id: diverId,
      name: 'Test Diver',
      isDefault: true,
      createdAt: now,
      updatedAt: now,
    ),
  );
  return diverId;
}

/// Imports every equipment item and dive in [equipment] and [dives], then
/// returns each dive's linked gear, in dive order.
Future<List<List<EquipmentItem>>> _importAll(
  List<Map<String, dynamic>> equipment,
  List<Map<String, dynamic>> dives,
) async {
  final diverId = await _createDiver();
  await UddfEntityImporter().import(
    data: UddfImportResult(equipment: equipment, dives: dives),
    selections: UddfImportSelections(
      equipment: {for (var i = 0; i < equipment.length; i++) i},
      dives: {for (var i = 0; i < dives.length; i++) i},
    ),
    repositories: _repositories(),
    diverId: diverId,
  );
  final imported = await DiveRepository().getAllDives(diverId: diverId);
  imported.sort((a, b) => a.dateTime.compareTo(b.dateTime));
  final equipmentRepo = EquipmentRepository();
  return [
    for (final dive in imported)
      [
        for (final item in dive.equipment)
          (await equipmentRepo.getEquipmentById(item.id))!,
      ],
  ];
}

void _expectThickness(EquipmentItem item, String text, double mm) {
  final attr = item.attributes.singleWhere(
    (a) => a.key == EquipmentAttrKeys.thicknessMm,
  );
  expect(attr.isCustom, isFalse);
  expect(attr.valueText, text);
  expect(attr.valueNum, mm);
}

void _expectNoThickness(EquipmentItem item) {
  expect(
    item.attributes.where((a) => a.key == EquipmentAttrKeys.thicknessMm),
    isEmpty,
  );
}

/// The Suit Thickness chart's numbers for the imported diver. Compared field
/// by field: a record holding a List compares by identity.
Future<void> _expectSuitStats({
  required List<({double mm, int count})> byThickness,
  required int unknownThickness,
  required int drysuit,
}) async {
  final stats = await StatisticsRepository().getDivesBySuitThickness(
    diverId: _diverId,
  );
  expect(stats.byThickness, byThickness);
  expect(stats.unknownThicknessCount, unknownThickness);
  expect(stats.drysuitCount, drysuit);
}

void main() {
  setUp(() async => setUpTestDatabase());
  tearDown(() async => tearDownTestDatabase());

  test('a Subsurface suit becomes typed gear on each dive', () async {
    const xml = '''
<divelog program='subsurface' version='3'>
<dives>
<dive number='1' date='2025-01-15' time='10:00:00' duration='30:00 min'>
  <suit>3mm Bare wetsuit</suit>
  <divecomputer model='Test'><depth max='20.0 m' /></divecomputer>
</dive>
<dive number='2' date='2025-01-16' time='10:00:00' duration='30:00 min'>
  <suit>Drysuit</suit>
  <divecomputer model='Test'><depth max='20.0 m' /></divecomputer>
</dive>
<dive number='3' date='2025-01-17' time='10:00:00' duration='30:00 min'>
  <suit>Full suit</suit>
  <divecomputer model='Test'><depth max='20.0 m' /></divecomputer>
</dive>
<dive number='4' date='2025-01-18' time='10:00:00' duration='30:00 min'>
  <suit>Wetsuit</suit>
  <divecomputer model='Test'><depth max='20.0 m' /></divecomputer>
</dive>
</dives>
</divelog>
''';
    final payload = await SubsurfaceXmlParser().parse(
      Uint8List.fromList(utf8.encode(xml)),
    );

    final gearByDive = await _importAll(
      payload.entitiesOf(ImportEntityType.equipment),
      payload.entitiesOf(ImportEntityType.dives),
    );

    expect(gearByDive, hasLength(4));
    final wetsuit = gearByDive[0].single;
    expect(wetsuit.name, '3mm Bare wetsuit');
    expect(wetsuit.type, EquipmentType.wetsuit);
    _expectThickness(wetsuit, '3mm', 3.0);

    final drysuit = gearByDive[1].single;
    expect(drysuit.type, EquipmentType.drysuit);
    _expectNoThickness(drysuit);

    // "Full suit" does not say which suit it is: no gear, as before.
    expect(gearByDive[2], isEmpty);

    final unrated = gearByDive[3].single;
    expect(unrated.type, EquipmentType.wetsuit);
    _expectNoThickness(unrated);

    // One dive in each of the chart's three kinds of bucket; the "Full suit"
    // dive reaches none.
    await _expectSuitStats(
      byThickness: [(mm: 3.0, count: 1)],
      unknownThickness: 1,
      drysuit: 1,
    );
  });

  test('a CSV suit column becomes typed gear on each dive', () async {
    final payload = const CsvCorrelator().correlate(
      diveListRows: TransformedRows(
        rows: [
          {'dateTime': DateTime(2025, 1, 15, 10), 'suit': 'Xcel 5/4'},
          {'dateTime': DateTime(2025, 1, 16, 10), 'suit': 'Membrane'},
          {'dateTime': DateTime(2025, 1, 17, 10), 'suit': 'Xcel 5/4'},
          {'dateTime': DateTime(2025, 1, 18, 10), 'suit': 'Full suit'},
        ],
      ),
      config: const ImportConfiguration(
        mappings: {'primary': FieldMapping(name: 'Test', columns: [])},
        entityTypesToImport: {
          ImportEntityType.dives,
          ImportEntityType.equipment,
        },
      ),
    );

    final gearByDive = await _importAll(
      payload.entitiesOf(ImportEntityType.equipment),
      payload.entitiesOf(ImportEntityType.dives),
    );

    expect(gearByDive, hasLength(4));
    final wetsuit = gearByDive[0].single;
    expect(wetsuit.type, EquipmentType.wetsuit);
    _expectThickness(wetsuit, '5/4', 5.0);
    expect(gearByDive[2].single.id, wetsuit.id);
    expect(gearByDive[1].single.type, EquipmentType.drysuit);
    // "Full suit" does not say which suit it is: no gear, notes only.
    expect(gearByDive[3], isEmpty);

    // Two dives share the 5/4 suit, whose primary panel is 5 mm.
    await _expectSuitStats(
      byThickness: [(mm: 5.0, count: 2)],
      unknownThickness: 0,
      drysuit: 1,
    );
  });
}
