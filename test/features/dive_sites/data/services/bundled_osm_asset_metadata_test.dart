import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards the metadata block that `scripts/dive_site_harvester.py` stamps
/// onto both of the assets it writes: the site catalogue and the dive
/// centre list.
///
/// The generator used to append "Z" to an `isoformat()` that already carried
/// "+00:00", producing a timestamp no ISO-8601 parser accepts. This asserts
/// the shipped files, not just the generator, so a hand-edited or
/// half-regenerated asset cannot slip a broken stamp back in.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const assets = <String, String>{
    'assets/data/site_catalogue.json': 'sites',
    'assets/data/dive_centers.json': 'centers',
  };

  assets.forEach((assetPath, entriesKey) {
    group(assetPath, () {
      late Map<String, dynamic> metadata;
      late List<dynamic> entries;

      setUpAll(() async {
        final raw = await rootBundle.loadString(assetPath);
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        metadata = decoded['metadata'] as Map<String, dynamic>;
        entries = decoded[entriesKey] as List<dynamic>;
      });

      test('stamps metadata a parser can actually read', () {
        final stamp = metadata['generated_at'] as String;

        expect(stamp, endsWith('Z'));
        expect(stamp, isNot(contains('+00:00')));
        expect(DateTime.parse(stamp).isUtc, isTrue);
      });

      test('counts the entries it actually ships', () {
        expect(metadata['total_count'], entries.length);
      });

      test('says where its entries come from', () {
        if (entriesKey == 'sites') {
          // The catalogue names a source per record; its metadata declares
          // each one, with its licence.
          expect(metadata['format'], 2);
          expect((metadata['sources'] as Map).keys, contains('osm'));
        } else {
          expect(metadata['source'], 'OpenStreetMap via Overpass API');
        }
      });
    });
  });
}
