import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/uddf/uddf_export_service.dart';
import 'package:submersion/core/services/export/uddf/uddf_full_export_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:xml/xml.dart';

/// Issue #1874: both UDDF dive writers put a separate (0 s, 0 m) waypoint
/// before the recorded samples, so a restored profile gained a point, and
/// invented a descent, bottom and ascent for a dive with no samples, which a
/// restore then stored as that dive's profile.
void main() {
  Dive dive({List<DiveProfilePoint> profile = const []}) => Dive(
    id: 'dive-a',
    diveNumber: 1,
    dateTime: DateTime.utc(2026, 3, 1, 9),
    bottomTime: const Duration(minutes: 45),
    maxDepth: 25.0,
    avgDepth: 18.0,
    waterTemp: 22.0,
    tanks: const [
      DiveTank(id: 'tank-a', gasMix: GasMix(o2: 32)),
      DiveTank(id: 'tank-b', gasMix: GasMix(o2: 50), order: 1),
    ],
    profile: profile,
  );

  const recorded = [
    DiveProfilePoint(timestamp: 10, depth: 4.5),
    DiveProfilePoint(timestamp: 60, depth: 12.0),
    DiveProfilePoint(timestamp: 120, depth: 6.0),
  ];

  final writers = <String, Future<String> Function(Dive)>{
    'full backup': (d) =>
        UddfFullExportService().generateAllDataXmlForTest(dives: [d]),
    'dives-only export': (d) =>
        UddfExportService().generateDivesUddfContent([d]),
  };

  XmlElement onlyDive(String xml) =>
      XmlDocument.parse(xml).findAllElements('dive').single;

  for (final MapEntry(key: name, value: write) in writers.entries) {
    group(name, () {
      test('writes exactly the recorded samples', () async {
        final samples = onlyDive(await write(dive(profile: recorded)))
            .findAllElements('waypoint')
            .map(
              (w) => (
                w.getElement('divetime')!.innerText,
                double.parse(w.getElement('depth')!.innerText),
              ),
            );

        expect(samples, [('10', 4.5), ('60', 12.0), ('120', 6.0)]);
      });

      test('marks the starting mix on the first recorded sample', () async {
        final waypoints = onlyDive(
          await write(dive(profile: recorded)),
        ).findAllElements('waypoint').toList();

        expect(
          waypoints.first.getElement('switchmix')?.getAttribute('ref'),
          'mix_32_0',
        );
        expect(
          waypoints.skip(1).expand((w) => w.findElements('switchmix')),
          isEmpty,
          reason: 'no gas switch was recorded after the start',
        );
      });

      test('writes no samples for a dive without a recorded profile', () async {
        // Depth and duration are known, which is what the old fallback drew
        // its invented descent, bottom and ascent from.
        final written = onlyDive(await write(dive()));

        expect(written.findElements('samples'), isEmpty);
        final after = written.getElement('informationafterdive')!;
        expect(after.getElement('greatestdepth')?.innerText, '25.0');
      });
    });
  }
}
