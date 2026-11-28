import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/opening_hours/opening_hours.dart';
import 'package:submersion/core/services/export/export_service.dart';
import 'package:submersion/core/services/export/uddf/uddf_full_export_service.dart';
import 'package:submersion/features/dive_import/data/services/uddf_entity_importer.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/parsers/uddf_import_parser.dart';

import '../../../../helpers/test_database.dart';
import 'uddf_raw_data_round_trip_test.dart'
    show buildRepositories, createTestDiver;

/// A site's address, contact details and opening hours (issue #5073)
/// through a UDDF backup and restore, in Submersion's own site elements.
void main() {
  final hours = OpeningHours(
    note: 'Book slots by phone',
    schedules: [
      OpeningSchedule(
        name: 'Summer',
        season: const YearlyDateRange(
          start: MonthDay(4, 1),
          end: MonthDay(10, 31),
        ),
        days: {
          DateTime.saturday: DayHours.ranges(const [TimeRange(480, 1020)]),
          DateTime.sunday: const DayHours.open24h(),
        },
      ),
    ],
  );

  setUp(() async {
    await setUpTestDatabase();
  });

  tearDown(() async => tearDownTestDatabase());

  Future<DiveSite> restore(String xml) async {
    await tearDownTestDatabase();
    await setUpTestDatabase();
    final payload = await UddfImportParser().parse(
      Uint8List.fromList(utf8.encode(xml)),
    );
    final data = UddfImportResult(
      sites: payload.entitiesOf(ImportEntityType.sites),
    );
    await UddfEntityImporter().import(
      data: data,
      selections: UddfImportSelections.selectAll(data),
      repositories: buildRepositories(),
      diverId: await createTestDiver(),
    );
    return (await SiteRepository().getAllSites()).single;
  }

  test('a site keeps its contact details and hours', () async {
    final diverId = await createTestDiver();
    final site = await SiteRepository().createSite(
      DiveSite(
        id: '',
        name: 'Stoney Cove',
        diverId: diverId,
        address: 'Stoney Cove\nLE9 4DW',
        phone: '+44 1455 273089',
        email: 'info@stoneycove.com',
        website: 'stoneycove.com',
        openingHours: hours,
      ),
    );

    final xml = await UddfFullExportService().generateAllDataXmlForTest(
      dives: const [],
      sites: [site],
    );
    final restored = await restore(xml);

    // The file reflows text, so the lines come back joined.
    expect(restored.address, 'Stoney Cove, LE9 4DW');
    expect(restored.phone, '+44 1455 273089');
    expect(restored.email, 'info@stoneycove.com');
    expect(restored.website, 'stoneycove.com');
    expect(restored.openingHours, hours);
  });

  test('a site without them writes none of the elements', () async {
    final diverId = await createTestDiver();
    final site = await SiteRepository().createSite(
      DiveSite(id: '', name: 'Reef', diverId: diverId),
    );

    final xml = await UddfFullExportService().generateAllDataXmlForTest(
      dives: const [],
      sites: [site],
    );
    expect(xml, isNot(contains('<openinghours')));
    expect(xml, isNot(contains('<siteaddress')));
  });
}
