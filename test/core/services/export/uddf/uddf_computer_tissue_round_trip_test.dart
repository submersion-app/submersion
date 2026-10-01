import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/uddf/uddf_export_service.dart';
import 'package:submersion/core/services/export/uddf/uddf_full_export_service.dart';
import 'package:submersion/core/services/export/uddf/uddf_full_import_service.dart';
import 'package:submersion/features/dive_log/domain/entities/computer_tissue_snapshot.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:xml/xml.dart';

/// The tissue state a dive computer reported (the dive-level snapshot and
/// the per-sample N2 load) has no standard UDDF element, so both writers
/// carry it in the private `<applicationdata><submersion><computertissue>`
/// block and the reader puts it back on the dive (issue #2557).
void main() {
  const snapshot = ComputerTissueSnapshot(
    algorithm: 'Suunto Fused2 RGBM',
    start: ComputerTissueState(
      n2Bar: [0.79, 0.81],
      heBar: [0.0, 0.0],
      n2LoadPercent: 12,
      cnsPercent: 3,
    ),
    end: ComputerTissueState(
      n2Bar: [1.52, 1.21],
      loadPercent: [64.5, 48],
      gf99Percent: 37,
      surfaceGfPercent: 41.5,
      otu: 22,
      rgbmNitrogen: 0.97,
      rgbmHelium: 1,
    ),
  );

  const recorded = [
    DiveProfilePoint(timestamp: 0, depth: 0.5, n2Load: 12),
    DiveProfilePoint(timestamp: 60, depth: 12.0),
    DiveProfilePoint(timestamp: 120, depth: 18.0, n2Load: 34, gf99: 20),
    DiveProfilePoint(timestamp: 180, depth: 3.0, n2Load: 101),
  ];

  Dive dive({
    String id = 'dive-a',
    ComputerTissueSnapshot? computerTissue,
    List<DiveProfilePoint> profile = const [],
  }) => Dive(
    id: id,
    diveNumber: 1,
    dateTime: DateTime.utc(2026, 3, 1, 9),
    bottomTime: const Duration(minutes: 45),
    maxDepth: 25.0,
    avgDepth: 18.0,
    tanks: const [DiveTank(id: 'tank-a', gasMix: GasMix(o2: 32))],
    computerTissue: computerTissue,
    profile: profile,
  );

  final writers = <String, Future<String> Function(List<Dive>)>{
    'full backup': (dives) =>
        UddfFullExportService().generateAllDataXmlForTest(dives: dives),
    'dives-only export': (dives) =>
        UddfExportService().generateDivesUddfContent(dives),
  };

  Future<List<Map<String, dynamic>>> restore(String xml) async =>
      (await UddfFullImportService().importAllDataFromUddf(xml)).dives;

  List<Map<String, dynamic>> profileOf(Map<String, dynamic> dive) =>
      dive['profile'] as List<Map<String, dynamic>>;

  for (final MapEntry(key: name, value: write) in writers.entries) {
    group(name, () {
      test('restores the dive-level snapshot', () async {
        final xml = await write([dive(computerTissue: snapshot)]);

        final restored = (await restore(xml)).single;
        expect(
          ComputerTissueSnapshot.from(restored['computerTissue']),
          snapshot,
        );
      });

      test('restores the per-sample N2 load, and only on samples that '
          'had one', () async {
        final xml = await write([dive(profile: recorded)]);

        final profile = profileOf((await restore(xml)).single);
        expect(profile.map((p) => p['n2Load']), [12, null, 34, 101]);
        expect(profile[1].containsKey('n2Load'), isFalse);
        // GF99 still rides on the standard waypoint element.
        expect(profile[2]['gf99'], 20);
      });

      test('keeps each dive\'s data on its own dive', () async {
        final xml = await write([
          dive(id: 'dive-a', computerTissue: snapshot, profile: recorded),
          dive(
            id: 'dive-b',
            profile: const [
              DiveProfilePoint(timestamp: 0, depth: 1.0),
              DiveProfilePoint(timestamp: 60, depth: 10.0),
            ],
          ),
        ]);

        final restored = {
          for (final d in await restore(xml)) d['sourceUuid']: d,
        };
        expect(
          ComputerTissueSnapshot.from(
            restored['dive_dive-a']!['computerTissue'],
          ),
          snapshot,
        );
        expect(restored['dive_dive-b']!.containsKey('computerTissue'), isFalse);
        expect(
          profileOf(
            restored['dive_dive-b']!,
          ).any((p) => p.containsKey('n2Load')),
          isFalse,
        );
      });

      test('writes the block inside the top level private section and keeps '
          'the waypoints standard', () async {
        final xml = await write([
          dive(computerTissue: snapshot, profile: recorded),
        ]);
        final doc = XmlDocument.parse(xml);

        final block = doc.rootElement
            .findElements('applicationdata')
            .single
            .findElements('submersion')
            .single
            .findElements('computertissue')
            .single;
        expect(
          block.findElements('dive').single.getAttribute('ref'),
          'dive_dive-a',
        );
        expect(
          doc
              .findAllElements('waypoint')
              .expand((w) => w.findElements('n2load')),
          isEmpty,
        );
      });

      test('writes no block when no dive has computer tissue data', () async {
        final xml = await write([
          dive(profile: const [DiveProfilePoint(timestamp: 0, depth: 1.0)]),
        ]);

        expect(
          XmlDocument.parse(xml).findAllElements('computertissue'),
          isEmpty,
        );
      });
    });
  }
}
