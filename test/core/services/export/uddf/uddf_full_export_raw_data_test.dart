import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';
import 'package:submersion/core/services/export/models/uddf_export_options.dart';
import 'package:submersion/core/services/export/uddf/uddf_dump_codec.dart';
import 'package:submersion/core/services/export/uddf/uddf_full_export_service.dart';
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
    tanks: const [],
    profile: const [],
    equipment: const [],
    notes: '',
    photoIds: const [],
    sightings: const [],
    weights: const [],
    tags: const [],
  );

  final raw = Uint8List.fromList(List<int>.generate(256, (i) => i));

  DiveSourceExport sourceFor({
    required String id,
    required int ordinal,
    bool isPrimary = true,
    Uint8List? rawData,
  }) {
    return DiveSourceExport(
      id: id,
      diveId: 'dive-1',
      ordinal: ordinal,
      isPrimary: isPrimary,
      importedAt: DateTime(2019, 6, 2, 18, 41, 7),
      createdAt: DateTime(2019, 6, 2, 18, 41, 7),
      rawData: rawData,
      descriptorVendor: 'Shearwater',
      descriptorProduct: 'Perdix',
      descriptorModel: 5,
    );
  }

  test('includes the dump and the source record when enabled', () async {
    final service = UddfFullExportService();

    final xml = await service.generateAllDataXmlForTest(
      dives: [dive],
      dataSources: [sourceFor(id: 'src-a', ordinal: 0, rawData: raw)],
      options: const UddfExportOptions(),
    );
    final doc = XmlDocument.parse(xml);

    final dumps = doc.findAllElements('divecomputerdump').toList();
    expect(dumps, hasLength(1));
    expect(
      UddfDumpCodec.decodeOne(
        dumps.single.findElements('dcdump').single.innerText,
      ),
      equals(raw),
    );

    final entries = doc.findAllElements('source').toList();
    expect(entries, hasLength(1));
    expect(entries.single.getAttribute('hasdump'), 'true');

    // divecomputercontrol is the last section of a UDDF document.
    expect(
      doc.rootElement.childElements.last.name.local,
      'divecomputercontrol',
    );
  });

  test('writes an entry with no dump for a source that has no bytes', () async {
    final service = UddfFullExportService();

    final xml = await service.generateAllDataXmlForTest(
      dives: [dive],
      dataSources: [
        sourceFor(id: 'src-a', ordinal: 0, rawData: raw),
        sourceFor(id: 'src-b', ordinal: 1, isPrimary: false),
      ],
      options: const UddfExportOptions(),
    );
    final doc = XmlDocument.parse(xml);

    expect(doc.findAllElements('source'), hasLength(2));
    expect(doc.findAllElements('divecomputerdump'), hasLength(1));
    expect(
      doc.findAllElements('source').map((e) => e.getAttribute('hasdump')),
      ['true', 'false'],
    );
  });

  test('omits both sections when includeRawData is false', () async {
    final service = UddfFullExportService();

    final xml = await service.generateAllDataXmlForTest(
      dives: [dive],
      dataSources: [sourceFor(id: 'src-a', ordinal: 0, rawData: raw)],
      options: const UddfExportOptions(includeRawData: false),
    );
    final doc = XmlDocument.parse(xml);

    expect(doc.findAllElements('divecomputercontrol'), isEmpty);
    expect(doc.findAllElements('datasources'), isEmpty);
  });

  test('defaults to including raw data', () {
    expect(const UddfExportOptions().includeRawData, isTrue);
  });
}
