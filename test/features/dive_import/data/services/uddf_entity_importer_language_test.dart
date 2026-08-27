import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:submersion/core/services/geocoding/nominatim_throttle.dart';
import 'package:submersion/core/services/export/models/uddf_import_result.dart';
import 'package:submersion/core/services/location_service.dart';
import 'package:submersion/features/dive_import/data/services/uddf_entity_importer.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

import '../../../../helpers/fake_nominatim.dart';
import 'uddf_entity_importer_test.mocks.dart';

/// Issue #1187: the importer's own country/region lookup for sites that
/// arrive with coordinates but no address must use the diver's place name
/// language, not the old English pin.
void main() {
  late MockSiteRepository sites;
  late ImportRepositories repos;

  setUp(() {
    LocationService.throttle = NominatimThrottle(minimumGap: Duration.zero);
    addTearDown(() => LocationService.throttle = NominatimThrottle());
    sites = MockSiteRepository();
    when(
      sites.getAllSites(diverId: anyNamed('diverId')),
    ).thenAnswer((_) async => []);
    when(sites.createSite(any)).thenAnswer(
      (invocation) async => invocation.positionalArguments[0] as DiveSite,
    );
    repos = ImportRepositories(
      tripRepository: MockTripRepository(),
      equipmentRepository: MockEquipmentRepository(),
      equipmentSetRepository: MockEquipmentSetRepository(),
      buddyRepository: MockBuddyRepository(),
      diveCenterRepository: MockDiveCenterRepository(),
      certificationRepository: MockCertificationRepository(),
      tagRepository: MockTagRepository(),
      diveTypeRepository: MockDiveTypeRepository(),
      diveRoleRepository: MockDiveRoleRepository(),
      siteRepository: sites,
      diveRepository: MockDiveRepository(),
      tankPressureRepository: MockTankPressureRepository(),
      courseRepository: MockCourseRepository(),
      serviceRecordRepository: MockServiceRecordRepository(),
    );
  });

  test('geocodes an address-less site in the place name language', () async {
    final server = FakeNominatim(
      body: '{"address": {"country": "Suisse", "state": "Lucerne"}}',
    );
    final importer = UddfEntityImporter(placeNameLanguage: 'fr');
    const data = UddfImportResult(
      sites: [
        {
          'name': 'Hertenstein',
          'uddfId': 'site-1',
          'latitude': 47.027631,
          'longitude': 8.400640,
        },
      ],
    );

    await server.run(
      () => importer.import(
        data: data,
        selections: const UddfImportSelections(sites: {0}),
        repositories: repos,
        diverId: 'diver-1',
      ),
    );

    expect(server.requestedUris, isNotEmpty);
    for (final uri in server.requestedUris) {
      expect(uri.queryParameters['accept-language'], 'fr');
    }
    final site =
        verify(sites.createSite(captureAny)).captured.single as DiveSite;
    expect(site.country, 'Suisse');
  });
}
