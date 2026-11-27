import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/export/models/export_service_record.dart';
import 'package:submersion/core/services/export/uddf/uddf_full_export_service.dart';
import 'package:submersion/core/services/export/uddf/uddf_full_import_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:xml/xml.dart';

/// A firmware update in a full UDDF backup keeps the version it installed
/// (issue #5104), so a restore does not leave "Firmware updated to" blank.
void main() {
  const computer = EquipmentItem(
    id: 'perdix',
    name: 'Perdix 2',
    type: EquipmentType.computer,
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

  Future<String> backup(List<ServiceRecord> records) =>
      UddfFullExportService().generateAllDataXmlForTest(
        dives: [dive],
        equipment: [computer],
        serviceRecords: records,
      );

  test('a firmware record writes its version and reads it back', () async {
    final xml = await backup([
      ServiceRecord(
        id: 'f1',
        equipmentId: 'perdix',
        serviceCategory: ServiceCategory.firmwareUpdate,
        serviceDate: DateTime(2026, 10, 1),
        firmwareVersion: 'V95',
      ),
    ]);

    final record = XmlDocument.parse(xml).findAllElements('record').single;
    expect(record.findElements('firmwareversion').single.innerText, 'V95');

    final result = await UddfFullImportService().importAllDataFromUddf(xml);
    final parsed = result.serviceRecords.single;
    expect(parsed['serviceCategory'], ServiceCategory.firmwareUpdate);
    expect(parsed['firmwareVersion'], 'V95');
  });

  test('a service record writes no version', () async {
    final xml = await backup([
      ServiceRecord(
        id: 's1',
        equipmentId: 'perdix',
        serviceCategory: ServiceCategory.annual,
        serviceDate: DateTime(2026, 5, 1),
      ),
    ]);
    expect(xml, isNot(contains('firmwareversion')));
    final result = await UddfFullImportService().importAllDataFromUddf(xml);
    expect(result.serviceRecords.single['firmwareVersion'], isNull);
  });
}
