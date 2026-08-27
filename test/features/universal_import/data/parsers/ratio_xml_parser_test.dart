import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    show GasMix;
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_options.dart';
import 'package:submersion/features/universal_import/data/parsers/ratio_xml_parser.dart';

/// Builds a minimal Ratio XML string with the given header fields and samples.
String _buildRatioXml({
  int utcStartS = 586371714,
  int depthMax = 1361,
  int avgDepth = 631,
  int diveMode = 0,
  int water = 1,
  int lastSurfaceTimeS = 2739,
  int surfacePressureMbar = 9971,
  int desaturationTimeS = 83961,
  List<Map<String, int>>? samples,
}) {
  final buf = StringBuffer()
    ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
    ..writeln('<diveSegment version="1.2">')
    ..writeln('<segmentHeader>')
    ..writeln('<equipmentType>258</equipmentType>')
    ..writeln('<UTCStartingTimeS>$utcStartS</UTCStartingTimeS>')
    ..writeln('<surfacePressureMbar>$surfacePressureMbar</surfacePressureMbar>')
    ..writeln('<lastSurfaceTimeS>$lastSurfaceTimeS</lastSurfaceTimeS>')
    ..writeln('<desaturationTimeS>$desaturationTimeS</desaturationTimeS>')
    ..writeln('<depthMax>$depthMax</depthMax>')
    ..writeln('<avgDepth>$avgDepth</avgDepth>')
    ..writeln('<diveMode>$diveMode</diveMode>')
    ..writeln('<water>$water</water>')
    ..writeln('</segmentHeader>')
    ..writeln('<samples>');

  final sampleList = samples ?? _defaultSamples();
  for (final s in sampleList) {
    buf.writeln('<sample>');
    s.forEach((k, v) => buf.writeln('<$k>$v</$k>'));
    buf.writeln('</sample>');
  }

  buf
    ..writeln('</samples>')
    ..writeln('</diveSegment>');
  return buf.toString();
}

List<Map<String, int>> _defaultSamples() => [
  {
    'runtimeS': 10,
    'depthDm': 21,
    'temperatureDc': 237,
    'activeMixO2Percent': 21,
    'activeMixHePercent': 0,
    'activeAlgorithm': 0,
    'buhlGfHigh': 80,
    'buhlGfLow': 30,
    'NDLOrTTS': 32767,
    'CNS': 0,
    'OTU': 0,
    'firstStopDepth': 0,
    'firstStopTime': 0,
    'tankPressure': 200,
    'tankId': 14,
  },
  {
    'runtimeS': 60,
    'depthDm': 136,
    'temperatureDc': 151,
    'activeMixO2Percent': 21,
    'activeMixHePercent': 0,
    'activeAlgorithm': 0,
    'buhlGfHigh': 80,
    'buhlGfLow': 30,
    'NDLOrTTS': 3000,
    'CNS': 2,
    'OTU': 5,
    'firstStopDepth': 0,
    'firstStopTime': 0,
    'tankPressure': 180,
    'tankId': 14,
  },
  {
    'runtimeS': 3180,
    'depthDm': 9,
    'temperatureDc': 235,
    'activeMixO2Percent': 21,
    'activeMixHePercent': 0,
    'activeAlgorithm': 0,
    'buhlGfHigh': 80,
    'buhlGfLow': 30,
    'NDLOrTTS': 32767,
    'CNS': 3,
    'OTU': 8,
    'firstStopDepth': 0,
    'firstStopTime': 0,
    'tankPressure': 71,
    'tankId': 14,
  },
];

Uint8List _toBytes(String text) => Uint8List.fromList(utf8.encode(text));

ImportOptions _optionsWithFile(String name) => ImportOptions(
  sourceApp: SourceApp.ratio,
  format: ImportFormat.ratioXml,
  fileName: name,
);

void main() {
  const parser = RatioXmlParser();

  test('supportedFormats contains ratioXml', () {
    expect(parser.supportedFormats, contains(ImportFormat.ratioXml));
  });

  test('returns error for non-XML content', () async {
    final payload = await parser.parse(Uint8List.fromList([0, 1, 2, 3]));
    expect(payload.entities, isEmpty);
    expect(payload.warnings, isNotEmpty);
  });

  test('returns error for XML without diveSegment root', () async {
    const xml = '<?xml version="1.0"?><data><item/></data>';
    final payload = await parser.parse(_toBytes(xml));
    expect(payload.entities, isEmpty);
    expect(
      payload.warnings.any((w) => w.message.contains('diveSegment')),
      isTrue,
    );
  });

  test('returns error for diveSegment without segmentHeader', () async {
    const xml =
        '<?xml version="1.0"?>'
        '<diveSegment version="1.2">'
        '<samples><sample><runtimeS>10</runtimeS></sample></samples>'
        '</diveSegment>';
    final payload = await parser.parse(_toBytes(xml));
    expect(payload.entities, isEmpty);
    expect(
      payload.warnings.any((w) => w.message.contains('segmentHeader')),
      isTrue,
    );
  });

  group('header parsing', () {
    test('converts UTCStartingTimeS using Ratio epoch (2008-01-01)', () async {
      // 586371714 seconds from 2008-01-01 00:00:00 UTC
      // = 2026-07-31 17:01:54 UTC
      final xml = _buildRatioXml(utcStartS: 586371714);
      final payload = await parser.parse(_toBytes(xml));
      final dive = payload.entities[ImportEntityType.dives]!.single;
      final dt = dive['dateTime'] as DateTime;
      expect(dt.isUtc, isTrue);
      expect(dt.year, 2026);
      expect(dt.month, 7);
      expect(dt.day, 31);
      expect(dt.hour, 17);
      expect(dt.minute, 1);
    });

    test('converts depthMax from centimeters to meters', () async {
      final xml = _buildRatioXml(depthMax: 1361);
      final payload = await parser.parse(_toBytes(xml));
      final dive = payload.entities[ImportEntityType.dives]!.single;
      expect(dive['maxDepth'], closeTo(13.61, 0.001));
    });

    test('converts avgDepth from centimeters to meters', () async {
      final xml = _buildRatioXml(avgDepth: 631);
      final payload = await parser.parse(_toBytes(xml));
      final dive = payload.entities[ImportEntityType.dives]!.single;
      expect(dive['avgDepth'], closeTo(6.31, 0.001));
    });

    test('maps diveMode 0 to OC', () async {
      final xml = _buildRatioXml(diveMode: 0);
      final payload = await parser.parse(_toBytes(xml));
      final dive = payload.entities[ImportEntityType.dives]!.single;
      expect(dive['diveMode'], 'OC');
    });

    test('maps diveMode 2 to CCR', () async {
      final xml = _buildRatioXml(diveMode: 2);
      final payload = await parser.parse(_toBytes(xml));
      final dive = payload.entities[ImportEntityType.dives]!.single;
      expect(dive['diveMode'], 'CCR');
    });

    test('maps water type 1 to fresh', () async {
      final xml = _buildRatioXml(water: 1);
      final payload = await parser.parse(_toBytes(xml));
      final dive = payload.entities[ImportEntityType.dives]!.single;
      expect(dive['waterType'], 'fresh');
    });

    test('maps water type 0 to salt', () async {
      final xml = _buildRatioXml(water: 0);
      final payload = await parser.parse(_toBytes(xml));
      final dive = payload.entities[ImportEntityType.dives]!.single;
      expect(dive['waterType'], 'salt');
    });

    test('parses surface interval', () async {
      final xml = _buildRatioXml(lastSurfaceTimeS: 2739);
      final payload = await parser.parse(_toBytes(xml));
      final dive = payload.entities[ImportEntityType.dives]!.single;
      expect(dive['surfaceInterval'], const Duration(seconds: 2739));
    });

    test('parses surface pressure in bar', () async {
      final xml = _buildRatioXml(surfacePressureMbar: 9971);
      final payload = await parser.parse(_toBytes(xml));
      final dive = payload.entities[ImportEntityType.dives]!.single;
      expect(dive['surfacePressure'], closeTo(0.9971, 0.0001));
    });
  });

  group('sample profile parsing', () {
    test('builds profile with depth in meters and temp in Celsius', () async {
      final xml = _buildRatioXml();
      final payload = await parser.parse(_toBytes(xml));
      final dive = payload.entities[ImportEntityType.dives]!.single;
      final profile = dive['profile'] as List<Map<String, dynamic>>;

      expect(profile, hasLength(3));

      // First sample: 21 dm = 2.1m, 237 dC = 23.7 C
      expect(profile[0]['timestamp'], 10);
      expect(profile[0]['depth'], closeTo(2.1, 0.001));
      expect(profile[0]['temperature'], closeTo(23.7, 0.1));

      // Second sample: 136 dm = 13.6m, 151 dC = 15.1 C
      expect(profile[1]['depth'], closeTo(13.6, 0.001));
      expect(profile[1]['temperature'], closeTo(15.1, 0.1));
    });

    test('computes duration from last sample runtimeS', () async {
      final xml = _buildRatioXml();
      final payload = await parser.parse(_toBytes(xml));
      final dive = payload.entities[ImportEntityType.dives]!.single;
      expect(dive['duration'], const Duration(seconds: 3180));
      expect(dive['runtime'], const Duration(seconds: 3180));
    });

    test('reports minimum temperature as waterTemp', () async {
      final xml = _buildRatioXml();
      final payload = await parser.parse(_toBytes(xml));
      final dive = payload.entities[ImportEntityType.dives]!.single;
      // min temp across samples: 151 dC = 15.1 C
      expect(dive['waterTemp'], closeTo(15.1, 0.1));
    });

    test('parses NDL when no deco stop', () async {
      final samples = [
        {
          'runtimeS': 10,
          'depthDm': 50,
          'temperatureDc': 200,
          'activeMixO2Percent': 21,
          'activeMixHePercent': 0,
          'activeAlgorithm': 0,
          'buhlGfHigh': 80,
          'buhlGfLow': 30,
          'NDLOrTTS': 3000,
          'CNS': 0,
          'OTU': 0,
          'firstStopDepth': 0,
          'firstStopTime': 0,
          'tankPressure': 200,
          'tankId': 14,
        },
      ];
      final xml = _buildRatioXml(samples: samples);
      final payload = await parser.parse(_toBytes(xml));
      final dive = payload.entities[ImportEntityType.dives]!.single;
      final profile = dive['profile'] as List<Map<String, dynamic>>;
      expect(profile[0]['ndl'], 3000);
      expect(profile[0].containsKey('tts'), isFalse);
    });

    test('parses TTS and ceiling when in deco', () async {
      final samples = [
        {
          'runtimeS': 600,
          'depthDm': 400,
          'temperatureDc': 150,
          'activeMixO2Percent': 21,
          'activeMixHePercent': 0,
          'activeAlgorithm': 0,
          'buhlGfHigh': 80,
          'buhlGfLow': 30,
          'NDLOrTTS': 120,
          'CNS': 5,
          'OTU': 10,
          'firstStopDepth': 60,
          'firstStopTime': 3,
          'tankPressure': 150,
          'tankId': 14,
        },
      ];
      final xml = _buildRatioXml(samples: samples);
      final payload = await parser.parse(_toBytes(xml));
      final dive = payload.entities[ImportEntityType.dives]!.single;
      final profile = dive['profile'] as List<Map<String, dynamic>>;
      expect(profile[0]['tts'], 120);
      expect(profile[0]['ceiling'], closeTo(6.0, 0.001));
      expect(profile[0].containsKey('ndl'), isFalse);
    });

    test('treats NDLOrTTS 32767 as unlimited (no NDL or TTS)', () async {
      final xml = _buildRatioXml();
      final payload = await parser.parse(_toBytes(xml));
      final dive = payload.entities[ImportEntityType.dives]!.single;
      final profile = dive['profile'] as List<Map<String, dynamic>>;
      // First sample has NDLOrTTS=32767
      expect(profile[0].containsKey('ndl'), isFalse);
      expect(profile[0].containsKey('tts'), isFalse);
    });

    test('captures CNS and OTU at end of dive', () async {
      final xml = _buildRatioXml();
      final payload = await parser.parse(_toBytes(xml));
      final dive = payload.entities[ImportEntityType.dives]!.single;
      expect(dive['cnsEnd'], closeTo(3.0, 0.001));
      expect(dive['otu'], closeTo(8.0, 0.001));
    });

    test('captures gradient factors from first sample', () async {
      final xml = _buildRatioXml();
      final payload = await parser.parse(_toBytes(xml));
      final dive = payload.entities[ImportEntityType.dives]!.single;
      expect(dive['gradientFactorLow'], 30);
      expect(dive['gradientFactorHigh'], 80);
    });

    test('detects deco algorithm from first sample', () async {
      final xml = _buildRatioXml();
      final payload = await parser.parse(_toBytes(xml));
      final dive = payload.entities[ImportEntityType.dives]!.single;
      expect(dive['decoAlgorithm'], 'Buhlmann');
    });

    test('detects VPM algorithm', () async {
      final samples = [
        {
          'runtimeS': 10,
          'depthDm': 50,
          'temperatureDc': 200,
          'activeMixO2Percent': 21,
          'activeMixHePercent': 0,
          'activeAlgorithm': 1,
          'buhlGfHigh': 80,
          'buhlGfLow': 30,
          'NDLOrTTS': 32767,
          'CNS': 0,
          'OTU': 0,
          'firstStopDepth': 0,
          'firstStopTime': 0,
          'tankPressure': 200,
          'tankId': 14,
        },
      ];
      final xml = _buildRatioXml(samples: samples);
      final payload = await parser.parse(_toBytes(xml));
      final dive = payload.entities[ImportEntityType.dives]!.single;
      expect(dive['decoAlgorithm'], 'VPM');
    });
  });

  group('tank data', () {
    test('builds tank with start and end pressure', () async {
      final xml = _buildRatioXml();
      final payload = await parser.parse(_toBytes(xml));
      final dive = payload.entities[ImportEntityType.dives]!.single;
      final tanks = dive['tanks'] as List<Map<String, dynamic>>;
      expect(tanks, hasLength(1));
      expect(tanks[0]['startPressure'], 200.0);
      expect(tanks[0]['endPressure'], 71.0);
      expect(tanks[0]['order'], 0);
    });

    test('includes gas mix on single-tank dive', () async {
      final xml = _buildRatioXml();
      final payload = await parser.parse(_toBytes(xml));
      final dive = payload.entities[ImportEntityType.dives]!.single;
      final tanks = dive['tanks'] as List<Map<String, dynamic>>;
      final gasMix = tanks[0]['gasMix'] as GasMix;
      expect(gasMix.o2, 21.0);
      expect(gasMix.he, 0.0);
    });

    test('tracks tank pressure per sample in profile', () async {
      final xml = _buildRatioXml();
      final payload = await parser.parse(_toBytes(xml));
      final dive = payload.entities[ImportEntityType.dives]!.single;
      final profile = dive['profile'] as List<Map<String, dynamic>>;
      final pressures = profile[0]['allTankPressures'] as List;
      expect(pressures, hasLength(1));
      final reading = pressures[0] as Map<String, dynamic>;
      expect(reading['tankIndex'], 0);
      expect(reading['pressure'], 200.0);
    });
  });

  group('gas switch detection', () {
    test('emits gasSwitches when O2 changes mid-dive', () async {
      final samples = [
        {
          'runtimeS': 10,
          'depthDm': 400,
          'temperatureDc': 150,
          'activeMixO2Percent': 21,
          'activeMixHePercent': 0,
          'activeAlgorithm': 0,
          'buhlGfHigh': 80,
          'buhlGfLow': 30,
          'NDLOrTTS': 32767,
          'CNS': 0,
          'OTU': 0,
          'firstStopDepth': 0,
          'firstStopTime': 0,
          'tankPressure': 200,
          'tankId': 14,
        },
        {
          'runtimeS': 1800,
          'depthDm': 60,
          'temperatureDc': 150,
          'activeMixO2Percent': 50,
          'activeMixHePercent': 0,
          'activeAlgorithm': 0,
          'buhlGfHigh': 80,
          'buhlGfLow': 30,
          'NDLOrTTS': 32767,
          'CNS': 5,
          'OTU': 10,
          'firstStopDepth': 0,
          'firstStopTime': 0,
          'tankPressure': 180,
          'tankId': 15,
        },
      ];
      final xml = _buildRatioXml(samples: samples);
      final payload = await parser.parse(_toBytes(xml));
      final dive = payload.entities[ImportEntityType.dives]!.single;
      final switches = dive['gasSwitches'] as List<Map<String, dynamic>>;
      expect(switches, hasLength(1));
      expect(switches[0]['timestamp'], 1800);
      expect(switches[0]['o2'], 50);
      expect(switches[0]['he'], 0);
      expect(switches[0]['depth'], closeTo(6.0, 0.001));
      expect(switches[0]['tankIndex'], 1);

      // Verify that tanks were correctly mapped from tankMixes
      final tanks = dive['tanks'] as List<Map<String, dynamic>>;
      expect(tanks, hasLength(2));

      final tank0Mix = tanks[0]['gasMix'] as GasMix;
      expect(tank0Mix.o2, 21.0);
      expect(tank0Mix.he, 0.0);

      final tank1Mix = tanks[1]['gasMix'] as GasMix;
      expect(tank1Mix.o2, 50.0);
      expect(tank1Mix.he, 0.0);
    });

    test('no gasSwitches when gas stays constant', () async {
      final xml = _buildRatioXml();
      final payload = await parser.parse(_toBytes(xml));
      final dive = payload.entities[ImportEntityType.dives]!.single;
      expect(dive.containsKey('gasSwitches'), isFalse);
    });
  });

  group('filename parsing', () {
    test(
      'extracts model, serial, and dive number from standard filename',
      () async {
        final xml = _buildRatioXml();
        final payload = await parser.parse(
          _toBytes(xml),
          options: _optionsWithFile(
            'IX3M_2_PRO_012345-dive_16-19880819_165840.xml',
          ),
        );
        final dive = payload.entities[ImportEntityType.dives]!.single;
        expect(dive['diveComputerModel'], 'IX3M 2 PRO');
        expect(dive['diveComputerSerial'], '012345');
        expect(dive['diveNumber'], 16);
      },
    );

    test('works with shorter model names', () async {
      final xml = _buildRatioXml();
      final payload = await parser.parse(
        _toBytes(xml),
        options: _optionsWithFile('IDIVE_99999-dive_3-20260101_120000.xml'),
      );
      final dive = payload.entities[ImportEntityType.dives]!.single;
      expect(dive['diveComputerModel'], 'IDIVE');
      expect(dive['diveComputerSerial'], '99999');
      expect(dive['diveNumber'], 3);
    });

    test('gracefully handles missing filename', () async {
      final xml = _buildRatioXml();
      final payload = await parser.parse(_toBytes(xml));
      final dive = payload.entities[ImportEntityType.dives]!.single;
      expect(dive.containsKey('diveComputerModel'), isFalse);
      expect(dive.containsKey('diveComputerSerial'), isFalse);
      expect(dive.containsKey('diveNumber'), isFalse);
    });

    test('handles filename without dive marker', () async {
      final xml = _buildRatioXml();
      final payload = await parser.parse(
        _toBytes(xml),
        options: _optionsWithFile('random_file.xml'),
      );
      final dive = payload.entities[ImportEntityType.dives]!.single;
      expect(dive.containsKey('diveNumber'), isFalse);
    });
  });

  group('metadata', () {
    test('sets source to ratio_xml in metadata', () async {
      final xml = _buildRatioXml();
      final payload = await parser.parse(
        _toBytes(xml),
        options: _optionsWithFile(
          'IX3M_2_PRO_012345-dive_16-19880819_165840.xml',
        ),
      );
      expect(payload.metadata['source'], 'ratio_xml');
      expect(payload.metadata['computerModel'], 'IX3M 2 PRO');
      expect(payload.metadata['computerSerial'], '012345');
    });

    test('produces exactly one dive entity', () async {
      final xml = _buildRatioXml();
      final payload = await parser.parse(_toBytes(xml));
      final dives = payload.entities[ImportEntityType.dives]!;
      expect(dives, hasLength(1));
    });
  });

  group('warning on missing samples', () {
    test('warns when no samples section present', () async {
      const xml =
          '<?xml version="1.0" encoding="UTF-8"?>'
          '<diveSegment version="1.2">'
          '<segmentHeader>'
          '<UTCStartingTimeS>586371714</UTCStartingTimeS>'
          '<depthMax>1361</depthMax>'
          '<avgDepth>631</avgDepth>'
          '<diveMode>0</diveMode>'
          '<water>1</water>'
          '</segmentHeader>'
          '</diveSegment>';
      final payload = await parser.parse(_toBytes(xml));
      expect(
        payload.warnings.any((w) => w.message.contains('samples')),
        isTrue,
      );
      // Should still produce a dive from header data
      expect(payload.entities[ImportEntityType.dives], hasLength(1));
    });
    test('does not throw when samples element is empty', () async {
      const xml =
          '<?xml version="1.0" encoding="UTF-8"?>'
          '<diveSegment version="1.2">'
          '<segmentHeader>'
          '<UTCStartingTimeS>586371714</UTCStartingTimeS>'
          '</segmentHeader>'
          '<samples></samples>'
          '</diveSegment>';
      final payload = await parser.parse(_toBytes(xml));
      expect(payload.entities[ImportEntityType.dives], hasLength(1));
    });

    test('handles sample with missing tankId and tankPressure', () async {
      final samples = [
        {
          'runtimeS': 10,
          'depthDm': 400,
          'temperatureDc': 150,
          'activeMixO2Percent': 21,
          'activeMixHePercent': 0,
        },
      ];
      final xml = _buildRatioXml(samples: samples);
      final payload = await parser.parse(_toBytes(xml));
      final dive = payload.entities[ImportEntityType.dives]!.single;
      final profile = dive['profile'] as List<Map<String, dynamic>>;
      expect(profile.first.containsKey('allTankPressures'), isFalse);
    });
  });
}
