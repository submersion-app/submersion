import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/parsers/submersion_csv/submersion_sites_csv_parser.dart';

/// The Submersion sites CSV's half of the shared location contract (#2232).
///
/// A row with no `Name` was skipped with an error, which took its `Latitude`
/// and `Longitude` with it. Submersion's own exports always write a name, but
/// a hand-edited file need not, and the contract holds for every importer.
void main() {
  Future<List<Map<String, dynamic>>> sitesOf(String csv) async {
    final payload = await const SubmersionSitesCsvParser().parse(
      Uint8List.fromList(utf8.encode(csv)),
    );
    return payload.entitiesOf(ImportEntityType.sites);
  }

  const header = 'Name,Country,Region,Latitude,Longitude\n';

  test(
    'a row with coordinates and no name survives under a coordinate name',
    () async {
      final sites = await sitesOf('$header,Mexico,,20.2114,-87.4654\n');

      expect(sites, hasLength(1));
      expect(sites.single['name'], '20.211400, -87.465400');
      expect(sites.single['latitude'], 20.2114);
      expect(sites.single['longitude'], -87.4654);
      expect(sites.single['country'], 'Mexico');
    },
  );

  test('a named row still wins its own name', () async {
    final sites = await sitesOf('${header}Dos Ojos,Mexico,,20.2114,-87.4654\n');

    expect(sites.single['name'], 'Dos Ojos');
  });

  test('a row with neither a name nor coordinates is still skipped', () async {
    final payload = await const SubmersionSitesCsvParser().parse(
      Uint8List.fromList(utf8.encode('$header,Mexico,,,\n')),
    );

    expect(payload.entitiesOf(ImportEntityType.sites), isEmpty);
    expect(payload.warnings.where((w) => w.field == 'Name'), hasLength(1));
  });
}
