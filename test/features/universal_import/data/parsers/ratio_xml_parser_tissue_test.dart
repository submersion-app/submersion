import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/computer_tissue_snapshot.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_options.dart';
import 'package:submersion/features/universal_import/data/parsers/ratio_xml_parser.dart';

const _fixturePath =
    'test/fixtures/universal_import/ratio_xml/'
    'IX3M_2_PRO_123456-dive_14-19880731_190154.xml';

/// Builds a minimal Ratio XML document whose samples carry the given
/// extra elements (values are written verbatim, so text is allowed).
String _ratioXml(List<Map<String, Object>> samples) {
  final buf = StringBuffer()
    ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
    ..writeln('<diveSegment version="1.2">')
    ..writeln('<segmentHeader>')
    ..writeln('<UTCStartingTimeS>586371714</UTCStartingTimeS>')
    ..writeln('<depthMax>1200</depthMax>')
    ..writeln('</segmentHeader>')
    ..writeln('<samples>');
  for (final sample in samples) {
    buf.writeln('<sample>');
    sample.forEach((k, v) => buf.writeln('<$k>$v</$k>'));
    buf.writeln('</sample>');
  }
  buf
    ..writeln('</samples>')
    ..writeln('</diveSegment>');
  return buf.toString();
}

Map<String, Object> _sample(
  int runtimeS, {
  Map<String, Object> extra = const {},
}) {
  return {
    'runtimeS': runtimeS,
    'depthDm': 100,
    'activeMixO2Percent': 21,
    'activeAlgorithm': 0,
    'CNS': 1,
    ...extra,
  };
}

Map<String, Object> _groups(List<Object> values) => {
  for (var i = 0; i < values.length; i++)
    'tissueGroup${i + 1}Percent': values[i],
};

Future<Map<String, dynamic>> _parseDive(String xml) async {
  const parser = RatioXmlParser();
  final payload = await parser.parse(
    Uint8List.fromList(utf8.encode(xml)),
    options: const ImportOptions(
      sourceApp: SourceApp.ratio,
      format: ImportFormat.ratioXml,
    ),
  );
  return payload.entities[ImportEntityType.dives]!.single;
}

void main() {
  group('RatioXmlParser computer tissue', () {
    test(
      'reads start and end compartment loading from the iX3M fixture',
      () async {
        final bytes = await File(_fixturePath).readAsBytes();
        const parser = RatioXmlParser();
        final payload = await parser.parse(
          bytes,
          options: const ImportOptions(
            sourceApp: SourceApp.ratio,
            format: ImportFormat.ratioXml,
            fileName: 'IX3M_2_PRO_123456-dive_14-19880731_190154.xml',
          ),
        );
        final dive = payload.entities[ImportEntityType.dives]!.single;

        final tissue = dive['computerTissue'];
        expect(tissue, isA<ComputerTissueSnapshot>());
        final snapshot = tissue as ComputerTissueSnapshot;

        expect(snapshot.algorithm, 'Buhlmann');

        // First sample of the fixture.
        expect(snapshot.start?.loadPercent, hasLength(16));
        expect(snapshot.start?.loadPercent?.first, 7.0);
        expect(snapshot.start?.loadPercent, [
          7.0, 7.0, 7.0, 8.0, 8.0, 8.0, 8.0, 8.0, //
          0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
        ]);
        expect(snapshot.start?.cnsPercent, 1.0);

        // Last sample of the fixture.
        expect(snapshot.end?.loadPercent, hasLength(16));
        expect(snapshot.end?.loadPercent, [
          10.0, 12.0, 12.0, 12.0, 11.0, 11.0, 10.0, 10.0, //
          0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
        ]);
        expect(snapshot.end?.cnsPercent, 1.0);
        expect(snapshot.hasCompartmentData, isTrue);
      },
    );

    test('sets no computerTissue when no sample has tissue groups', () async {
      final dive = await _parseDive(_ratioXml([_sample(10), _sample(20)]));

      expect(dive.containsKey('computerTissue'), isFalse);
    });

    test('names VPM when the active algorithm is 1', () async {
      final dive = await _parseDive(
        _ratioXml([
          _sample(
            10,
            extra: {
              'activeAlgorithm': 1,
              ..._groups([5, 6]),
            },
          ),
        ]),
      );

      final snapshot = dive['computerTissue'] as ComputerTissueSnapshot;
      expect(snapshot.algorithm, 'VPM');
      expect(snapshot.end?.loadPercent, [5.0, 6.0]);
    });

    test('stops the compartment list at the first missing index', () async {
      final dive = await _parseDive(
        _ratioXml([
          _sample(
            10,
            extra: {
              'tissueGroup1Percent': 3,
              'tissueGroup2Percent': 4,
              'tissueGroup4Percent': 9,
            },
          ),
        ]),
      );

      final snapshot = dive['computerTissue'] as ComputerTissueSnapshot;
      expect(snapshot.end?.loadPercent, [3.0, 4.0]);
    });

    test('treats a non-numeric group as missing and stops there', () async {
      final dive = await _parseDive(
        _ratioXml([
          _sample(10, extra: _groups([2, 'n/a', 7])),
        ]),
      );

      final snapshot = dive['computerTissue'] as ComputerTissueSnapshot;
      expect(snapshot.end?.loadPercent, [2.0]);
    });

    test('ignores a sample whose first group is non-numeric', () async {
      final dive = await _parseDive(
        _ratioXml([
          _sample(10, extra: _groups(['x', 4])),
          _sample(20),
        ]),
      );

      expect(dive.containsKey('computerTissue'), isFalse);
    });

    test('takes start from the first and end from the last sample', () async {
      final dive = await _parseDive(
        _ratioXml([
          _sample(
            10,
            extra: {
              ..._groups([1, 2]),
              'CNS': 0,
            },
          ),
          _sample(20, extra: _groups([3, 4])),
          _sample(
            30,
            extra: {
              ..._groups([5, 6]),
              'CNS': 4,
            },
          ),
        ]),
      );

      final snapshot = dive['computerTissue'] as ComputerTissueSnapshot;
      expect(snapshot.start?.loadPercent, [1.0, 2.0]);
      expect(snapshot.start?.cnsPercent, 0.0);
      expect(snapshot.end?.loadPercent, [5.0, 6.0]);
      expect(snapshot.end?.cnsPercent, 4.0);
    });
  });
}
