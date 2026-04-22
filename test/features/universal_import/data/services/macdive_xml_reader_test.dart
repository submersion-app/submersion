import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/universal_import/data/services/macdive_xml_models.dart';
import 'package:submersion/features/universal_import/data/services/macdive_xml_reader.dart';

void main() {
  group('MacDiveXmlReader (metric fixture)', () {
    late String content;

    setUpAll(() async {
      content = await File(
        'test/fixtures/macdive_xml/metric_small.xml',
      ).readAsString();
    });

    test('parses units, schema version, and single dive', () {
      final logbook = MacDiveXmlReader.parse(content);
      expect(logbook.units, MacDiveUnitSystem.metric);
      expect(logbook.schemaVersion, '2.2.0');
      expect(logbook.dives.length, 1);
    });

    test('parses identifier, date, diveNumber', () {
      final dive = MacDiveXmlReader.parse(content).dives.first;
      expect(dive.identifier, '20240601090000-ABC123');
      expect(dive.date, DateTime(2024, 6, 1, 9, 0, 0));
      expect(dive.diveNumber, 42);
    });

    test(
      'parses metric depths/temps/weight in canonical units (no conversion)',
      () {
        final dive = MacDiveXmlReader.parse(content).dives.first;
        expect(dive.maxDepthMeters, 25.4);
        expect(dive.avgDepthMeters, 18.0);
        expect(dive.tempHighCelsius, 26.5);
        expect(dive.tempLowCelsius, 20.0);
        expect(dive.weightKg, 5.0);
      },
    );

    test('parses durations as Duration objects', () {
      final dive = MacDiveXmlReader.parse(content).dives.first;
      expect(dive.duration, const Duration(seconds: 2400));
      expect(dive.sampleInterval, const Duration(seconds: 10));
    });

    test('parses tags as list', () {
      final dive = MacDiveXmlReader.parse(content).dives.first;
      expect(dive.tags, ['Reef', 'Photography']);
    });

    test('parses buddies as list', () {
      final dive = MacDiveXmlReader.parse(content).dives.first;
      expect(dive.buddies, ['Alice']);
    });

    test('parses site block with coordinates', () {
      final dive = MacDiveXmlReader.parse(content).dives.first;
      expect(dive.site?.name, 'Test Reef');
      expect(dive.site?.country, 'Mexico');
      expect(dive.site?.location, 'Baja California');
      expect(dive.site?.waterType, 'saltwater');
      expect(dive.site?.latitude, closeTo(24.12345, 0.00001));
      expect(dive.site?.longitude, closeTo(-110.54321, 0.00001));
    });

    test('parses gear items', () {
      final dive = MacDiveXmlReader.parse(content).dives.first;
      expect(dive.gear.length, 1);
      expect(dive.gear.first.type, 'BCD');
      expect(dive.gear.first.manufacturer, 'Test');
      expect(dive.gear.first.name, 'BCD1');
    });

    test('parses gas definition (metric)', () {
      final dive = MacDiveXmlReader.parse(content).dives.first;
      expect(dive.gases.length, 1);
      final gas = dive.gases.first;
      expect(gas.pressureStartBar, 200);
      expect(gas.pressureEndBar, 60);
      expect(gas.oxygenPercent, 32);
      expect(gas.heliumPercent, 0);
      expect(gas.supplyType, 'Open Circuit');
      expect(gas.duration, const Duration(seconds: 2400));
      expect(gas.tankName, 'AL80');
      expect(gas.doubleTank, false);
      expect(gas.workingPressureBar, 232);
    });

    test('parses samples with time as Duration', () {
      final dive = MacDiveXmlReader.parse(content).dives.first;
      expect(dive.samples.length, 3);
      expect(dive.samples[0].time, Duration.zero);
      expect(dive.samples[1].time, const Duration(seconds: 60));
      expect(dive.samples[2].time, const Duration(seconds: 2400));
      expect(dive.samples[0].temperatureCelsius, 26.5);
    });

    test('parses notes from CDATA', () {
      final dive = MacDiveXmlReader.parse(content).dives.first;
      expect(dive.notes, 'Nice reef dive');
    });

    test('parses operator and boat', () {
      final dive = MacDiveXmlReader.parse(content).dives.first;
      expect(dive.diveOperator, 'Test Operator');
      expect(dive.boat, 'MV Test');
      expect(dive.weather, 'Sunny');
    });
  });

  group('MacDiveXmlReader edge cases', () {
    test('treats lat=0 lon=0 as no-GPS', () {
      const xml = '''<?xml version="1.0"?>
<dives>
  <units>Metric</units>
  <schema>2.2.0</schema>
  <dive>
    <date>2024-01-01 00:00:00</date>
    <site><name>X</name><lat>0</lat><lon>0</lon></site>
    <samples/>
  </dive>
</dives>''';
      final dive = MacDiveXmlReader.parse(xml).dives.first;
      expect(dive.site?.latitude, isNull);
      expect(dive.site?.longitude, isNull);
    });

    test('missing optional fields produce null, not crash', () {
      const xml = '''<?xml version="1.0"?>
<dives>
  <units>Metric</units>
  <schema>2.2.0</schema>
  <dive>
    <date>2024-01-01 00:00:00</date>
    <maxDepth>20</maxDepth>
    <duration>1800</duration>
    <samples/>
  </dive>
</dives>''';
      final dive = MacDiveXmlReader.parse(xml).dives.first;
      expect(dive.site, isNull);
      expect(dive.tags, isEmpty);
      expect(dive.buddies, isEmpty);
      expect(dive.gases, isEmpty);
      expect(dive.gear, isEmpty);
      expect(dive.samples, isEmpty);
      expect(dive.notes, isNull);
      expect(dive.boat, isNull);
    });

    test('empty elements produce null, not empty string', () {
      const xml = '''<?xml version="1.0"?>
<dives>
  <units>Metric</units>
  <schema>2.2.0</schema>
  <dive>
    <date>2024-01-01 00:00:00</date>
    <notes></notes>
    <boat></boat>
    <samples/>
  </dive>
</dives>''';
      final dive = MacDiveXmlReader.parse(xml).dives.first;
      expect(dive.notes, isNull);
      expect(dive.boat, isNull);
    });

    test('unknown units system passes through numerics unchanged', () {
      const xml = '''<?xml version="1.0"?>
<dives>
  <schema>2.2.0</schema>
  <dive>
    <date>2024-01-01 00:00:00</date>
    <maxDepth>50</maxDepth>
    <samples/>
  </dive>
</dives>''';
      final logbook = MacDiveXmlReader.parse(xml);
      expect(logbook.units, MacDiveUnitSystem.unknown);
      expect(logbook.dives.first.maxDepthMeters, 50);
    });
  });

  group('MacDiveXmlReader (imperial fixture)', () {
    late String content;

    setUpAll(() async {
      content = await File(
        'test/fixtures/macdive_xml/imperial_small.xml',
      ).readAsString();
    });

    test('declares imperial unit system', () {
      final logbook = MacDiveXmlReader.parse(content);
      expect(logbook.units, MacDiveUnitSystem.imperial);
    });

    test('depths converted feet → meters', () {
      final dive = MacDiveXmlReader.parse(content).dives.first;
      // 100 ft × 0.3048 = 30.48 m
      expect(dive.maxDepthMeters, closeTo(30.48, 0.01));
      // 60 ft × 0.3048 = 18.288 m
      expect(dive.avgDepthMeters, closeTo(18.288, 0.01));
    });

    test('temperatures converted °F → °C', () {
      final dive = MacDiveXmlReader.parse(content).dives.first;
      // 80°F = 26.667°C
      expect(dive.tempHighCelsius, closeTo(26.667, 0.01));
      // 70°F = 21.111°C
      expect(dive.tempLowCelsius, closeTo(21.111, 0.01));
    });

    test('weight converted lb → kg', () {
      final dive = MacDiveXmlReader.parse(content).dives.first;
      // 10 lb × 0.453592 = 4.536 kg
      expect(dive.weightKg, closeTo(4.536, 0.01));
    });

    test('gas pressures converted psi → bar', () {
      final dive = MacDiveXmlReader.parse(content).dives.first;
      final gas = dive.gases.first;
      // 3000 psi × 0.0689476 = 206.843 bar
      expect(gas.pressureStartBar, closeTo(206.843, 0.1));
      // 1000 psi × 0.0689476 = 68.948 bar
      expect(gas.pressureEndBar, closeTo(68.948, 0.1));
      expect(gas.workingPressureBar, closeTo(206.843, 0.1));
    });

    test('tank size converted cft-at-working-pressure → liters', () {
      final dive = MacDiveXmlReader.parse(content).dives.first;
      // 77.4 cft × 28.3168 / (3000 × 0.0689476) ≈ 10.59 L
      expect(dive.gases.first.tankSizeLiters, closeTo(10.59, 0.1));
    });

    test('sample temperatures converted °F → °C', () {
      final dive = MacDiveXmlReader.parse(content).dives.first;
      // Sample 1: 80°F → 26.667°C
      expect(dive.samples.first.temperatureCelsius, closeTo(26.667, 0.01));
      // Sample 2: 72°F → 22.222°C
      expect(dive.samples[1].temperatureCelsius, closeTo(22.222, 0.01));
    });

    test('sample depths and pressures converted', () {
      final dive = MacDiveXmlReader.parse(content).dives.first;
      // Sample 2: 100 ft → 30.48 m, 2000 psi → 137.9 bar
      expect(dive.samples[1].depthMeters, closeTo(30.48, 0.01));
      expect(dive.samples[1].pressureBar, closeTo(137.895, 0.1));
    });

    test('sample times remain in seconds (no unit conversion)', () {
      final dive = MacDiveXmlReader.parse(content).dives.first;
      expect(dive.samples[0].time, Duration.zero);
      expect(dive.samples[1].time, const Duration(seconds: 600));
    });
  });

  group('MacDiveXmlReader - photos', () {
    late String content;

    setUpAll(() async {
      content = await File(
        'test/fixtures/macdive_xml/metric_small.xml',
      ).readAsString();
    });

    test('reads both photo entries with paths and position index', () {
      final dive = MacDiveXmlReader.parse(content).dives.first;
      expect(dive.photos.length, 2);
      expect(dive.photos[0].path, '/Users/test/Pictures/a.jpg');
      expect(dive.photos[0].position, 0);
      expect(dive.photos[1].path, '/Users/test/Pictures/b.jpg');
      expect(dive.photos[1].position, 1);
    });

    test('caption read from first photo, null on the second', () {
      final dive = MacDiveXmlReader.parse(content).dives.first;
      expect(dive.photos[0].caption, 'Shark');
      expect(dive.photos[1].caption, isNull);
    });

    test('dives without <photos> container return empty list, not null', () {
      const xml = '''<?xml version="1.0"?>
<dives>
  <units>Metric</units>
  <schema>2.2.0</schema>
  <dive>
    <date>2024-01-01 00:00:00</date>
    <samples/>
  </dive>
</dives>''';
      final dive = MacDiveXmlReader.parse(xml).dives.first;
      expect(dive.photos, isEmpty);
    });

    test(
      'empty path is skipped (no silent zero-path ImportImageRef later)',
      () {
        const xml = '''<?xml version="1.0"?>
<dives>
  <units>Metric</units>
  <schema>2.2.0</schema>
  <dive>
    <date>2024-01-01 00:00:00</date>
    <photos>
      <photo><path></path><caption>orphan</caption></photo>
      <photo><path>/real/path.jpg</path></photo>
    </photos>
    <samples/>
  </dive>
</dives>''';
        final dive = MacDiveXmlReader.parse(xml).dives.first;
        expect(dive.photos.length, 1);
        expect(dive.photos.first.path, '/real/path.jpg');
      },
    );
  });
}
