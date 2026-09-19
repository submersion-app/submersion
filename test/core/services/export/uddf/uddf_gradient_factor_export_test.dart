import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/uddf/uddf_export_service.dart';
import 'package:submersion/core/services/export/uddf/uddf_full_export_service.dart';
import 'package:submersion/core/services/export/uddf/uddf_full_import_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:xml/xml.dart';

/// A sample's computer-reported GF99 goes out as the waypoint's
/// `<gradientfactor>` (UDDF 3.2), so a backup and restore keeps it.
///
/// Covers both waypoint writers: the shared one in
/// `uddf_export_builders.dart` used by the full backup, and the dives-only
/// writer in `uddf_export_service.dart`.
void main() {
  Dive dive({List<DiveProfilePoint> profile = const []}) => Dive(
    id: 'dive-a',
    diveNumber: 1,
    dateTime: DateTime.utc(2026, 3, 1, 9),
    bottomTime: const Duration(minutes: 45),
    maxDepth: 25.0,
    avgDepth: 18.0,
    tanks: const [DiveTank(id: 'tank-a', gasMix: GasMix(o2: 32))],
    profile: profile,
  );

  const recorded = [
    DiveProfilePoint(timestamp: 10, depth: 4.5, gf99: 0),
    DiveProfilePoint(timestamp: 60, depth: 12.0),
    DiveProfilePoint(timestamp: 120, depth: 6.0, gf99: 63),
    DiveProfilePoint(timestamp: 180, depth: 3.0, gf99: 104),
  ];

  final writers = <String, Future<String> Function(Dive)>{
    'full backup': (d) =>
        UddfFullExportService().generateAllDataXmlForTest(dives: [d]),
    'dives-only export': (d) =>
        UddfExportService().generateDivesUddfContent([d]),
  };

  List<XmlElement> waypoints(String xml) => XmlDocument.parse(
    xml,
  ).findAllElements('dive').single.findAllElements('waypoint').toList();

  for (final MapEntry(key: name, value: write) in writers.entries) {
    group(name, () {
      test('writes gradientfactor only on samples that have a GF99', () async {
        final points = waypoints(await write(dive(profile: recorded)));

        expect(points.map((w) => w.getElement('gradientfactor')?.innerText), [
          '0',
          null,
          '63',
          '104',
        ]);
      });

      test('writes gradientfactor as a direct child of the waypoint', () async {
        final points = waypoints(await write(dive(profile: recorded)));

        for (final waypoint in points) {
          expect(
            waypoint.findAllElements('gradientfactor').length,
            waypoint.findElements('gradientfactor').length,
          );
        }
      });

      test('restores the GF99 through the UDDF reader', () async {
        final xml = await write(dive(profile: recorded));
        final result = await UddfFullImportService().importAllDataFromUddf(xml);

        final profile =
            result.dives.single['profile'] as List<Map<String, dynamic>>;
        expect(profile.map((point) => point['gf99']), [0, null, 63, 104]);
        expect(profile[1].containsKey('gf99'), isFalse);
      });
    });
  }
}
