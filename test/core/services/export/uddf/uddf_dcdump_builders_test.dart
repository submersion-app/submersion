import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';
import 'package:submersion/core/services/export/uddf/uddf_export_builders.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_source_export.dart';

DiveSourceExport source({
  required String id,
  required String diveId,
  required int ordinal,
  bool isPrimary = true,
  Uint8List? rawData,
  String? computerId,
}) {
  return DiveSourceExport(
    id: id,
    diveId: diveId,
    ordinal: ordinal,
    isPrimary: isPrimary,
    importedAt: DateTime(2019, 6, 2, 18, 41, 7),
    createdAt: DateTime(2019, 6, 2, 18, 41, 7),
    rawData: rawData,
    rawFingerprint: Uint8List.fromList([0xA1, 0x7F, 0x3C]),
    computerId: computerId,
    computerModel: 'Perdix AI',
    computerSerial: 'SN123',
    descriptorVendor: 'Shearwater',
    descriptorProduct: 'Perdix',
    descriptorModel: 5,
    libdivecomputerVersion: '0.9.0-devel',
    mergeSourceSlot: 0,
    timeOffsetSeconds: 0,
    maxDepth: 31.5,
    cns: 12.5,
    decoAlgorithm: 'ZHL16C',
  );
}

String render(void Function(XmlBuilder) body) {
  final builder = XmlBuilder();
  builder.element('root', nest: () => body(builder));
  return builder.buildDocument().toXmlString(pretty: true);
}

void main() {
  group('buildDataSources', () {
    test('writes one entry per source with hasdump reflecting the bytes', () {
      final withBytes = source(
        id: 'src-a',
        diveId: 'dive-1',
        ordinal: 0,
        rawData: Uint8List.fromList([1, 2, 3]),
      );
      final withoutBytes = source(
        id: 'src-b',
        diveId: 'dive-1',
        ordinal: 1,
        isPrimary: false,
      );

      final xml = render(
        (b) =>
            UddfExportBuilders.buildDataSources(b, [withBytes, withoutBytes]),
      );
      final doc = XmlDocument.parse(xml);
      final entries = doc.findAllElements('source').toList();

      expect(entries, hasLength(2));
      expect(entries[0].getAttribute('diveref'), 'dive_dive-1');
      expect(entries[0].getAttribute('ordinal'), '0');
      expect(entries[0].getAttribute('hasdump'), 'true');
      expect(entries[1].getAttribute('hasdump'), 'false');

      final descriptor = entries[0].findElements('descriptor').single;
      expect(descriptor.getAttribute('vendor'), 'Shearwater');
      expect(descriptor.getAttribute('product'), 'Perdix');
      expect(descriptor.getAttribute('model'), '5');

      expect(entries[0].findElements('fingerprint').single.innerText, 'A17F3C');
      expect(entries[0].findElements('primary').single.innerText, 'true');
      expect(entries[1].findElements('primary').single.innerText, 'false');
      expect(entries[0].findElements('maxdepth').single.innerText, '31.5');
      expect(
        entries[0].findElements('decoalgorithm').single.innerText,
        'ZHL16C',
      );
      expect(
        entries[0].findElements('importedat').single.innerText,
        DateTime(2019, 6, 2, 18, 41, 7).toIso8601String(),
      );
    });

    test('writes nothing at all for an empty source list', () {
      final xml = render(
        (b) => UddfExportBuilders.buildDataSources(b, const []),
      );
      expect(XmlDocument.parse(xml).findAllElements('datasources'), isEmpty);
    });
  });

  group('buildDiveComputerControl', () {
    test('emits a dump only for sources with an encoded payload', () {
      final a = source(
        id: 'src-a',
        diveId: 'dive-1',
        ordinal: 0,
        rawData: Uint8List.fromList([1, 2, 3]),
        computerId: 'computer_9c21',
      );
      final b = source(
        id: 'src-b',
        diveId: 'dive-1',
        ordinal: 1,
        isPrimary: false,
        rawData: Uint8List.fromList([4, 5, 6]),
      );
      final c = source(id: 'src-c', diveId: 'dive-2', ordinal: 0);

      final xml = render(
        (builder) => UddfExportBuilders.buildDiveComputerControl(
          builder,
          [a, b, c],
          const {'src-a': 'QlpoOUFB', 'src-b': null},
          declaredComputerIds: {
            UddfExportBuilders.computerRefId('Perdix AI', 'SN123'),
          },
        ),
      );
      final doc = XmlDocument.parse(xml);
      final dumps = doc.findAllElements('divecomputerdump').toList();

      expect(dumps, hasLength(1));
      expect(dumps.single.findElements('dcdump').single.innerText, 'QlpoOUFB');
      final refs = dumps.single
          .findElements('link')
          .map((e) => e.getAttribute('ref'))
          .toList();
      // The computer ref is the id the standard sections declare, built from
      // model and serial. NOT the dive_computers row id, which appears only
      // inside <applicationdata> and is not a valid IDREF target.
      expect(refs, ['dive_dive-1', 'dc_Perdix_AI_SN123']);
      expect(
        dumps.single.findElements('datetime').single.innerText,
        DateTime(2019, 6, 2, 18, 41, 7).toIso8601String(),
      );
    });

    test('omits the computer link when the document declares no computers', () {
      final a = source(
        id: 'src-a',
        diveId: 'dive-1',
        ordinal: 0,
        rawData: Uint8List.fromList([1, 2, 3]),
        computerId: 'computer_9c21',
      );

      final xml = render(
        (builder) => UddfExportBuilders.buildDiveComputerControl(
          builder,
          [a],
          const {'src-a': 'QlpoOUFB'},
          declaredComputerIds: const {},
        ),
      );
      final refs = XmlDocument.parse(
        xml,
      ).findAllElements('link').map((e) => e.getAttribute('ref')).toList();

      // A ref pointing at an undeclared id would dangle under IDREF
      // validation, and the dives only export declares no <divecomputer>.
      expect(refs, ['dive_dive-1']);
    });

    test('omits the link for a computer this document did not declare', () {
      // The case a boolean could not express: in a full export the
      // <divecomputer> elements are minted from the dives' own model and
      // serial snapshots, so a multi-source dive's second computer is never
      // declared even though its source row names it.
      final secondary = source(
        id: 'src-b',
        diveId: 'dive-1',
        ordinal: 1,
        isPrimary: false,
        rawData: Uint8List.fromList([4, 5, 6]),
      );

      final xml = render(
        (builder) => UddfExportBuilders.buildDiveComputerControl(
          builder,
          [secondary],
          const {'src-b': 'QlpoOUFB'},
          declaredComputerIds: const {'dc_Some_Other_Computer_SN999'},
        ),
      );
      final refs = XmlDocument.parse(
        xml,
      ).findAllElements('link').map((e) => e.getAttribute('ref')).toList();

      expect(refs, ['dive_dive-1']);
    });

    test('writes no section when nothing encoded', () {
      final xml = render(
        (builder) => UddfExportBuilders.buildDiveComputerControl(
          builder,
          [source(id: 'src-a', diveId: 'dive-1', ordinal: 0)],
          const {},
          declaredComputerIds: const {},
        ),
      );
      expect(
        XmlDocument.parse(xml).findAllElements('divecomputercontrol'),
        isEmpty,
      );
    });
  });
}
