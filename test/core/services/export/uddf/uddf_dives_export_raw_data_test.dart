import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';
import 'package:submersion/core/services/export/models/uddf_export_options.dart';
import 'package:submersion/core/services/export/uddf/uddf_export_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_source_export.dart';

void main() {
  final dive = Dive(
    id: 'dive-1',
    diveNumber: 1,
    dateTime: DateTime(2019, 6, 2, 10, 0),
    bottomTime: const Duration(minutes: 45),
    maxDepth: 31.5,
    avgDepth: 18.0,
    waterTemp: 22.0,
    diveComputerModel: 'Perdix AI',
    diveComputerSerial: 'SN123',
    tanks: const [],
    profile: const [],
    equipment: const [],
    notes: '',
    photoIds: const [],
    sightings: const [],
    weights: const [],
    tags: const [],
  );

  final source = DiveSourceExport(
    id: 'src-a',
    diveId: 'dive-1',
    ordinal: 0,
    isPrimary: true,
    importedAt: DateTime(2019, 6, 2, 18, 41, 7),
    createdAt: DateTime(2019, 6, 2, 18, 41, 7),
    rawData: Uint8List.fromList([1, 2, 3, 4]),
    computerId: 'computer_9c21',
    computerModel: 'Perdix AI',
    computerSerial: 'SN123',
    descriptorVendor: 'Shearwater',
    descriptorProduct: 'Perdix',
    descriptorModel: 5,
  );

  test('emits the dive link but no computer link', () async {
    final xml = await UddfExportService().generateDivesUddfContent(
      [dive],
      dataSources: [source],
    );
    final doc = XmlDocument.parse(xml);

    // This path declares no <divecomputer> at all, so any computer ref would
    // dangle under IDREF validation.
    expect(doc.findAllElements('divecomputer'), isEmpty);
    final dump = doc.findAllElements('divecomputerdump').single;
    expect(dump.findElements('link').map((e) => e.getAttribute('ref')), [
      'dive_dive-1',
    ]);
  });

  test(
    'hosts the source record in its own top level applicationdata',
    () async {
      final xml = await UddfExportService().generateDivesUddfContent(
        [dive],
        dataSources: [source],
      );
      final doc = XmlDocument.parse(xml);

      final topLevel = doc.rootElement.childElements
          .where((e) => e.name.local == 'applicationdata')
          .toList();
      expect(topLevel, hasLength(1));
      expect(
        topLevel.single
            .findElements('submersion')
            .single
            .findElements('datasources'),
        hasLength(1),
      );

      // And divecomputercontrol still comes last.
      expect(
        doc.rootElement.childElements.last.name.local,
        'divecomputercontrol',
      );
    },
  );

  test('omits both sections when includeRawData is false', () async {
    final xml = await UddfExportService().generateDivesUddfContent(
      [dive],
      dataSources: [source],
      options: const UddfExportOptions(includeRawData: false),
    );
    final doc = XmlDocument.parse(xml);

    expect(doc.findAllElements('divecomputercontrol'), isEmpty);
    expect(doc.findAllElements('datasources'), isEmpty);
  });
}
