import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/models/uddf_import_result.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/certifications/data/repositories/certification_currency_repository.dart';
import 'package:submersion/features/dive_import/data/services/uddf_entity_importer.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/import_wizard/domain/models/import_cancellation_token.dart';
import 'package:submersion/features/import_wizard/domain/models/import_phase.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';

import '../../../../core/services/export/uddf/uddf_raw_data_round_trip_test.dart'
    show buildRepositories, createTestDiver;
import '../../../../helpers/fake_hosts.dart';
import '../../../../helpers/test_database.dart';

/// Cancelling an import stops it where it is (issue #3216).
///
/// Only the dive loop used to poll the token, so a cancel pressed while
/// sites were importing waited for every stage before the dives to finish.
/// A MacDive export reverse geocodes each of its sites through a throttled
/// network lookup, which left the wizard on "Cancelling..." for minutes.
///
/// `country` and `region` are set on every site so the best-effort reverse
/// geocode is skipped and the tests stay off the network.
void main() {
  // The dive loop's altitude lookup calls Open-Meteo; it answers as offline.
  setUp(() {
    serveFakeHost('api.open-meteo.com');
  });

  setUp(() async => setUpTestDatabase());
  tearDown(() async => tearDownTestDatabase());

  Map<String, dynamic> site(String id) => {
    'uddfId': id,
    'name': 'Site $id',
    'latitude': 20.2114,
    'longitude': -87.4654,
    'country': 'MX',
    'region': 'Quintana Roo',
  };

  final logbook = UddfImportResult(
    trips: [
      {
        'name': 'Cozumel',
        'startDate': DateTime.utc(2025, 3, 14),
        'endDate': DateTime.utc(2025, 3, 20),
      },
    ],
    buddies: const [
      {'uddfId': 'b1', 'name': 'Ana Diaz'},
    ],
    sites: [site('s1'), site('s2'), site('s3')],
    dives: [
      {
        'dateTime': DateTime.utc(2025, 3, 15, 9, 5),
        'maxDepth': 20.0,
        'diveComputerModel': 'Perdix 2',
        'diveComputerSerial': 'A1B2',
        'site': const {'uddfId': 's1'},
      },
    ],
  );

  test('a cancel during the sites stage stops at the next site', () async {
    final diverId = await createTestDiver();
    final token = ImportCancellationToken();

    final result = await UddfEntityImporter().import(
      data: logbook,
      selections: UddfImportSelections.selectAll(logbook),
      repositories: buildRepositories(),
      diverId: diverId,
      onProgress: (phase, current, total) {
        if (phase == ImportPhase.sites && current == 1) token.cancel();
      },
      cancelToken: token,
    );

    final sites = await SiteRepository().getAllSites(diverId: diverId);
    expect(sites.map((s) => s.name), ['Site s1']);
    expect(result.sites, 1);
    expect(result.dives, 0);
    expect(await DiveRepository().getAllDives(), isEmpty);
  });

  test('a cancel while overwriting sites stops at the next site', () async {
    final diverId = await createTestDiver();
    final first = UddfImportResult(sites: [site('s1'), site('s2')]);
    await UddfEntityImporter().import(
      data: first,
      selections: UddfImportSelections.selectAll(first),
      repositories: buildRepositories(),
      diverId: diverId,
    );
    final existing = await SiteRepository().getAllSites(diverId: diverId);
    final idByName = {for (final s in existing) s.name: s.id};

    final renamed = UddfImportResult(
      sites: [
        {...site('s1'), 'name': 'Renamed s1'},
        {...site('s2'), 'name': 'Renamed s2'},
      ],
    );
    final token = ImportCancellationToken();
    final result = await UddfEntityImporter().import(
      data: renamed,
      selections: UddfImportSelections(
        siteOverrides: {0: idByName['Site s1']!, 1: idByName['Site s2']!},
      ),
      repositories: buildRepositories(),
      diverId: diverId,
      onProgress: (phase, current, total) {
        if (phase == ImportPhase.sites && current == 1) token.cancel();
      },
      cancelToken: token,
    );

    final names = (await SiteRepository().getAllSites(
      diverId: diverId,
    )).map((s) => s.name).toSet();
    expect(names, {'Renamed s1', 'Site s2'});
    expect(result.sites, 1);
  });

  test('a cancel before the import starts writes nothing', () async {
    final diverId = await createTestDiver();

    final result = await UddfEntityImporter().import(
      data: logbook,
      selections: UddfImportSelections.selectAll(logbook),
      repositories: buildRepositories(),
      diverId: diverId,
      cancelToken: ImportCancellationToken()..cancel(),
    );

    expect(result.trips, 0);
    expect(result.buddies, 0);
    expect(result.sites, 0);
    expect(result.dives, 0);
    expect(await TripRepository().getAllTrips(diverId: diverId), isEmpty);
    expect(await BuddyRepository().getAllBuddies(diverId: diverId), isEmpty);
    expect(await SiteRepository().getAllSites(diverId: diverId), isEmpty);
    // The dive stage registers the batch's computers before its loop, so a
    // cancel that skips the stage must skip that too.
    expect(
      await DiveComputerRepository().getAllComputers(diverId: diverId),
      isEmpty,
    );
  });

  test('a cancel before a stage also skips the stages that finish its '
      'records', () async {
    final diverId = await createTestDiver();
    final base = buildRepositories();
    final currency = CertificationCurrencyRepository();
    final repositories = ImportRepositories(
      tripRepository: base.tripRepository,
      equipmentRepository: base.equipmentRepository,
      equipmentSetRepository: base.equipmentSetRepository,
      buddyRepository: base.buddyRepository,
      diveCenterRepository: base.diveCenterRepository,
      certificationRepository: base.certificationRepository,
      tagRepository: base.tagRepository,
      diveTypeRepository: base.diveTypeRepository,
      diveRoleRepository: base.diveRoleRepository,
      siteRepository: base.siteRepository,
      diveRepository: base.diveRepository,
      tankPressureRepository: base.tankPressureRepository,
      courseRepository: base.courseRepository,
      diveComputerRepository: base.diveComputerRepository,
      siteTypeRepository: base.siteTypeRepository,
      certificationCurrencyRepository: currency,
    );
    const data = UddfImportResult(
      // Custom rules restore with the certifications, which a cancel
      // before that stage never imports.
      currencyRules: [
        {
          'id': 'custom-1',
          'name': 'Club refresher',
          'clockKind': 'activity',
          'applicableAgencies': '["bsac"]',
          'applicableLevels': '[]',
          'lapseDays': 200,
          'leadDays': 30,
          'countedDiveTypeIds': '[]',
          'countedDiveModes': '[]',
        },
      ],
    );

    await UddfEntityImporter().import(
      data: data,
      selections: UddfImportSelections.selectAll(data),
      repositories: repositories,
      diverId: diverId,
      cancelToken: ImportCancellationToken()..cancel(),
    );

    final rules = await currency.getRules();
    expect(rules.where((r) => r.id == 'custom-1'), isEmpty);
  });

  test('a cancel in an earlier stage skips every stage after it', () async {
    final diverId = await createTestDiver();
    final token = ImportCancellationToken();

    final result = await UddfEntityImporter().import(
      data: logbook,
      selections: UddfImportSelections.selectAll(logbook),
      repositories: buildRepositories(),
      diverId: diverId,
      onProgress: (phase, current, total) {
        if (phase == ImportPhase.buddies && current == 1) token.cancel();
      },
      cancelToken: token,
    );

    expect(result.trips, 1);
    expect(result.buddies, 1);
    expect(result.sites, 0);
    expect(await SiteRepository().getAllSites(diverId: diverId), isEmpty);
    expect(await DiveRepository().getAllDives(), isEmpty);
  });

  test('without a cancel every stage still runs', () async {
    final diverId = await createTestDiver();

    final result = await UddfEntityImporter().import(
      data: logbook,
      selections: UddfImportSelections.selectAll(logbook),
      repositories: buildRepositories(),
      diverId: diverId,
      cancelToken: ImportCancellationToken(),
    );

    expect(result.trips, 1);
    expect(result.buddies, 1);
    expect(result.sites, 3);
    expect(result.dives, 1);
  });
}
