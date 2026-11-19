import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/uddf/uddf_export_service.dart';
import 'package:submersion/core/services/export/uddf/uddf_full_export_service.dart';
import 'package:submersion/core/services/export/uddf/uddf_full_import_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:xml/xml.dart';

/// Issue #4664: the values Shearwater's Avelo mode logs per sample (buoyancy,
/// gas remaining, the computer's RMV) have no standard UDDF element, so both
/// writers carry them in the private `<computertissue>` block beside the N2
/// load, and the reader puts them back on the samples.
void main() {
  const recorded = [
    DiveProfilePoint(
      timestamp: 0,
      depth: 0.5,
      aveloBuoyancy: -0.096,
      aveloGasRemaining: 100,
    ),
    DiveProfilePoint(timestamp: 60, depth: 12.0),
    DiveProfilePoint(
      timestamp: 120,
      depth: 18.0,
      aveloBuoyancy: -0.393,
      aveloGasRemaining: 64,
      computerRmv: 10.68,
    ),
    DiveProfilePoint(
      timestamp: 180,
      depth: 3.0,
      aveloBuoyancy: 1.242,
      computerRmv: 29.75,
    ),
  ];

  Dive dive({
    String id = 'dive-a',
    List<DiveProfilePoint> profile = const [],
  }) => Dive(
    id: id,
    diveNumber: 1,
    dateTime: DateTime.utc(2025, 4, 19, 11),
    bottomTime: const Duration(minutes: 45),
    maxDepth: 25.0,
    avgDepth: 18.0,
    tanks: const [DiveTank(id: 'tank-a', gasMix: GasMix())],
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
      test('restores each Avelo value on the sample that had it', () async {
        final xml = await write([dive(profile: recorded)]);

        final profile = profileOf((await restore(xml)).single);
        expect(profile.map((p) => p['aveloBuoyancy']), [
          -0.096,
          null,
          -0.393,
          1.242,
        ]);
        expect(profile.map((p) => p['aveloGasRemaining']), [
          100,
          null,
          64,
          null,
        ]);
        expect(profile.map((p) => p['computerRmv']), [
          null,
          null,
          10.68,
          29.75,
        ]);
        expect(profile[1].containsKey('aveloBuoyancy'), isFalse);
      });

      test('a dive without Avelo data writes no block', () async {
        final xml = await write([
          dive(
            profile: const [
              DiveProfilePoint(timestamp: 0, depth: 1.0),
              DiveProfilePoint(timestamp: 60, depth: 10.0),
            ],
          ),
        ]);

        expect(
          XmlDocument.parse(xml).findAllElements('computertissue'),
          isEmpty,
        );
      });

      test('keeps each dive\'s values on its own dive', () async {
        final xml = await write([
          dive(id: 'dive-a', profile: recorded),
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
        expect(profileOf(restored['dive_dive-a']!)[2]['computerRmv'], 10.68);
        expect(
          profileOf(restored['dive_dive-b']!).any(
            (p) =>
                p.containsKey('aveloBuoyancy') ||
                p.containsKey('aveloGasRemaining') ||
                p.containsKey('computerRmv'),
          ),
          isFalse,
        );
      });
    });
  }
}
