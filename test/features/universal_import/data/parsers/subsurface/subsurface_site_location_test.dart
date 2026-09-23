import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_warning.dart';
import 'package:submersion/features/universal_import/data/parsers/subsurface/subsurface_site_folder.dart';
import 'package:submersion/features/universal_import/data/parsers/subsurface_xml_parser.dart';

/// Subsurface's share of the shared location contract (#2232).
///
/// The fold named a nameless entry from its coordinates before the contract
/// existed, and read those coordinates without its rules. A nameless entry at
/// 0,0, the pair logbooks write for "no fix", came out as a real site called
/// "0.000000, 0.000000", which the importer could then no longer drop.
void main() {
  group('foldSubsurfaceSites', () {
    test('drops a nameless entry at 0,0 rather than naming it', () {
      final folded = foldSubsurfaceSites([
        {'uddfId': 'aaa', 'latitude': 0.0, 'longitude': 0.0},
      ]);

      expect(folded.sites, isEmpty);
    });

    test('drops a nameless entry off the globe', () {
      final folded = foldSubsurfaceSites([
        {'uddfId': 'aaa', 'latitude': 91.0, 'longitude': -66.0},
      ]);

      expect(folded.sites, isEmpty);
    });

    test('still names a nameless entry at a usable fix', () {
      final folded = foldSubsurfaceSites([
        {'uddfId': 'aaa', 'latitude': 18.465562, 'longitude': -66.084902},
      ]);

      expect(folded.sites.single['name'], '18.465562, -66.084902');
    });

    test('a nameless 0,0 entry does not fold into a named site at 0,0', () {
      // Two "no fix" entries are not a match: 0,0 is an absent position, so
      // it cannot place one site on top of another.
      final folded = foldSubsurfaceSites([
        {'uddfId': 'aaa', 'name': 'Reef', 'latitude': 0.0, 'longitude': 0.0},
        {'uddfId': 'bbb', 'latitude': 0.0, 'longitude': 0.0},
      ]);

      expect(folded.sites.map((s) => s['uddfId']), ['aaa']);
      expect(folded.aliases, isEmpty);
    });
  });

  group('SubsurfaceXmlParser', () {
    final parser = SubsurfaceXmlParser();
    Uint8List xmlBytes(String xml) => Uint8List.fromList(utf8.encode(xml));

    test('a dive whose only site sat at 0,0 is reported, not left linked '
        'to "0.000000, 0.000000"', () async {
      final result = await parser.parse(
        xmlBytes('''
<divelog program='subsurface' version='3'>
<divesites>
<site uuid='abc123' gps='0.000000 0.000000'/>
</divesites>
<dives>
<dive number='1' divesiteid='abc123' date='2025-01-15' time='10:00:00' duration='30:00 min'>
  <divecomputer model='Test'><depth max='20.0 m' mean='15.0 m' /></divecomputer>
</dive>
</dives>
</divelog>
'''),
      );

      expect(result.entitiesOf(ImportEntityType.sites), isEmpty);
      expect(
        result.warnings
            .singleWhere((w) => w.code == ImportWarningCode.sitesUnresolved)
            .count,
        1,
      );
    });
  });
}
