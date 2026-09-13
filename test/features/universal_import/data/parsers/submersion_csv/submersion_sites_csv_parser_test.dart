import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/csv/codec/csv_export_units.dart';
import 'package:submersion/core/services/export/csv/csv_sites_writer.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_warning.dart';
import 'package:submersion/features/universal_import/data/parsers/parser_registry.dart';
import 'package:submersion/features/universal_import/data/parsers/submersion_csv/submersion_sites_csv_parser.dart';

import '../../../../../core/services/export/csv/csv_dives_writer_test.dart'
    show imperial;
import '../../../../../core/services/export/csv/csv_test_fixtures.dart';

Uint8List _bytes(String s) => Uint8List.fromList(utf8.encode(s));

void main() {
  test('the registry routes the format to this parser', () {
    expect(
      parserForFormat(ImportFormat.submersionSitesCsv),
      isA<SubmersionSitesCsvParser>(),
    );
  });

  test(
    'an imperial My units file comes back in metric with enum names',
    () async {
      final csv = CsvSitesWriter(
        CsvExportUnits.fromSettings(imperial),
      ).write(goldenSites());
      final payload = await const SubmersionSitesCsvParser().parse(_bytes(csv));
      final sites = payload.entitiesOf(ImportEntityType.sites);
      expect(sites, hasLength(2));
      final blue = sites.first;
      expect(blue['name'], 'Blue Hole');
      expect(blue['country'], 'Belize');
      expect(blue['latitude'], 17.316);
      expect(blue['longitude'], -87.535);
      expect(blue['maxDepth'] as double, closeTo(40.5, 0.02));
      expect(blue['waterType'], 'salt');
      expect(blue['entryMethod'], 'boat');
      expect(blue['rating'], 4.5);
      expect(blue['notes'], 'Line 1 Line 2');
      expect(blue.containsKey('uddfId'), isTrue);
      // A blank cell is absent, so an overwrite keeps the existing value.
      expect(sites.last.keys, unorderedEquals(['uddfId', 'name']));
    },
  );

  test('a row with no name is skipped with an error warning', () async {
    final payload = await const SubmersionSitesCsvParser().parse(
      _bytes(
        'Name,Country,Region,Latitude,Longitude,Max Depth (m),Water Type,'
        'Current,Entry Type,Rating,Description,Notes\n'
        ',Belize,,,,,,,,,,\n',
      ),
    );
    expect(payload.entitiesOf(ImportEntityType.sites), isEmpty);
    expect(payload.warnings.single.severity, ImportWarningSeverity.error);
  });
}
