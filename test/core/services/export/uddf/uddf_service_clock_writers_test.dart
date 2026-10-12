import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/export/models/export_service_record.dart';
import 'package:submersion/core/services/export/uddf/uddf_full_export_service.dart';
import 'package:submersion/core/services/export/uddf/uddf_full_import_service.dart';
import 'package:submersion/core/services/export/uddf/uddf_import_parsers.dart';
import 'package:submersion/core/services/export/uddf/uddf_service_clock_writers.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/exposure_unit.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';
import 'package:xml/xml.dart';

/// Service kinds, clocks and record kinds in a full UDDF backup (#2651).
void main() {
  final kind = ServiceKind(
    id: 'k-burst',
    diverId: 'me',
    name: 'Burst disc',
    applicableTypes: const [EquipmentType.tank],
    defaultIntervalDays: 365,
    defaultIntervalHours: 50.5,
    exposureIntervals: const {ExposureUnit.saltHours: 50},
    defaultCost: 25,
    defaultCurrency: 'EUR',
    defaultCategory: ServiceCategory.inspection,
    autoAttach: true,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
  final clock = ServiceSchedule(
    id: 'auto-hydro-tank-1',
    equipmentId: 'tank-1',
    serviceKindId: 'hydro',
    intervalDays: 1095,
    exposureIntervals: const {ExposureUnit.cycles: 500},
    anchorDate: DateTime(2026, 1, 10),
    anchorSetAt: DateTime(2026, 1, 11, 8),
    enabled: false,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
  const tank = EquipmentItem(
    id: 'tank-1',
    name: 'AL80',
    type: EquipmentType.tank,
  );
  final record = ServiceRecord(
    id: 's1',
    equipmentId: 'tank-1',
    serviceCategory: ServiceCategory.inspection,
    serviceKindId: 'k-burst',
    serviceDate: DateTime(2026, 5, 1),
  );
  final dive = Dive(
    id: 'dive-1',
    diveNumber: 1,
    dateTime: DateTime(2026, 6, 2, 10),
    bottomTime: const Duration(minutes: 45),
    maxDepth: 18.0,
    tanks: const [],
    profile: const [],
    gear: const [],
    notes: '',
    photoIds: const [],
    sightings: const [],
    weights: const [],
    tags: const [],
  );

  Future<XmlDocument> backup() async => XmlDocument.parse(
    await UddfFullExportService().generateAllDataXmlForTest(
      dives: [dive],
      equipment: [tank],
      serviceRecords: [record],
      serviceKinds: [kind],
      serviceSchedulesByItem: {
        'tank-1': [clock],
      },
    ),
  );

  test('a custom kind is written and parsed back whole', () async {
    final submersion = (await backup()).findAllElements('submersion').single;
    expect(UddfServiceClockWriters.parseKinds(submersion).single, {
      'id': 'k-burst',
      'name': 'Burst disc',
      'applicableTypes': ['tank'],
      'defaultIntervalDays': 365,
      'defaultIntervalHours': 50.5,
      'exposureIntervals': {'saltHours': 50.0},
      'defaultCost': 25.0,
      'defaultCurrency': 'EUR',
      'defaultCategory': 'inspection',
      'autoAttach': true,
    });
  });

  test('an item writes its clocks, parsed back whole', () async {
    final item = (await backup()).findAllElements('item').single;
    expect(UddfServiceClockWriters.parseSchedules(item)!.single, {
      'kindRef': 'hydro',
      'intervalDays': 1095,
      'exposureIntervals': {'cycles': 500.0},
      'anchorDate': DateTime(2026, 1, 10),
      'anchorSetAt': DateTime(2026, 1, 11, 8),
      'enabled': false,
    });
  });

  test('the full parser carries kinds, clocks and record kinds', () async {
    final result = await UddfFullImportService().importAllDataFromUddf(
      (await backup()).toXmlString(),
    );
    expect(result.serviceKinds.single['id'], 'k-burst');
    expect(result.equipment.single['serviceSchedules'], hasLength(1));
    expect(result.serviceRecords.single['serviceKindRef'], 'k-burst');
  });

  test('a record names its kind', () async {
    final rec = (await backup()).findAllElements('record').single;
    expect(rec.findElements('servicekind').single.innerText, 'k-burst');
  });

  test('no kinds and no clocks write no sections', () async {
    final xml = await UddfFullExportService().generateAllDataXmlForTest(
      dives: [dive],
      equipment: [tank],
    );
    expect(xml, isNot(contains('servicekinds')));
    expect(xml, isNot(contains('servicekind>')));
  });

  test(
    'an item without clocks says so, and an old item reads as absent',
    () async {
      final xml = await UddfFullExportService().generateAllDataXmlForTest(
        dives: [dive],
        equipment: [tank],
      );
      final item = XmlDocument.parse(xml).findAllElements('item').single;
      // Written empty, so a restore can tell "no clocks" from an old file.
      expect(item.findElements('serviceschedules').single.children, isEmpty);
      expect(
        UddfImportParsers.parseEquipmentItem(item)['serviceSchedules'],
        isEmpty,
      );
      final old = XmlDocument.parse(
        '<item id="equip_x"><name>Old</name><type>tank</type></item>',
      ).rootElement;
      expect(
        UddfImportParsers.parseEquipmentItem(
          old,
        ).containsKey('serviceSchedules'),
        isFalse,
      );
    },
  );

  test('an unknown exposure unit and a ref-less schedule are dropped', () {
    final item = XmlDocument.parse(
      '<item><serviceschedules>'
      '<schedule kindref="hydro">'
      '<exposureinterval unit="moonPhases">3</exposureinterval>'
      '</schedule>'
      '<schedule><intervaldays>9</intervaldays></schedule>'
      '</serviceschedules></item>',
    ).rootElement;
    expect(UddfServiceClockWriters.parseSchedules(item), [
      {'kindRef': 'hydro', 'enabled': true},
    ]);
  });
}
