import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_types/domain/entities/dive_type_entity.dart';
import 'package:submersion/features/universal_import/data/services/divinglog_raw_types.dart';
import 'package:submersion/features/universal_import/data/services/divinglog_reference_mapper.dart';

DivingLogLogbook logbook({
  Map<int, DivingLogRawBuddy> buddies = const {},
  Map<int, DivingLogRawPlace> places = const {},
  Map<int, String> cities = const {},
  Map<int, String> countries = const {},
  Map<int, DivingLogRawTrip> trips = const {},
  Map<int, DivingLogRawShop> shops = const {},
  Map<int, DivingLogRawDiveType> diveTypes = const {},
  List<DivingLogRawCertification> certifications = const [],
  List<DivingLogRawDive> dives = const [],
}) => DivingLogLogbook(
  dives: dives,
  capabilities: const DivingLogCapabilities(tables: {}, columns: {}),
  buddiesById: buddies,
  placesById: places,
  cityNamesById: cities,
  countryNamesById: countries,
  tripsById: trips,
  shopsById: shops,
  diveTypesById: diveTypes,
  certifications: certifications,
);

void main() {
  group('sites', () {
    test('builds a site with coordinates from the Place row', () {
      final book = logbook(
        places: {
          10: const DivingLogRawPlace(
            id: 10,
            countryId: 30,
            place: 'Salt Pier',
            latitude: 12.13,
            longitude: -68.28,
            maxDepthMeters: 24.0,
          ),
        },
        countries: {30: 'Bonaire'},
        cities: {20: 'Kralendijk'},
        dives: [
          const DivingLogRawDive(id: 1, placeId: 10, cityId: 20, countryId: 30),
        ],
      );
      final sites = DivingLogReferenceMapper.sites(book);
      final site = sites.values.single;
      expect(site['name'], 'Salt Pier');
      expect(site['country'], 'Bonaire');
      expect(site['region'], 'Kralendijk');
      expect(site['latitude'], closeTo(12.13, 1e-9));
      expect(site['longitude'], closeTo(-68.28, 1e-9));
      expect(site['maxDepth'], closeTo(24.0, 1e-9));
    });

    test('keys the site exactly as phase 1 did, so the two fold', () {
      final book = logbook(
        places: {10: const DivingLogRawPlace(id: 10, place: 'Salt Pier')},
        cities: {20: 'Kralendijk'},
        countries: {30: 'Bonaire'},
        dives: [
          const DivingLogRawDive(id: 1, placeId: 10, cityId: 20, countryId: 30),
        ],
      );
      expect(
        DivingLogReferenceMapper.sites(book).keys.single,
        'divinglog_site_bonaire|kralendijk|salt pier',
      );
    });
  });

  group('site fallback', () {
    test('falls back per component when a referenced row is missing', () {
      // PlaceID points at a row the file does not have. Dropping the
      // component would key the site on country and city alone, which no
      // longer matches the phase 1 key and names the site wrongly.
      const book = DivingLogLogbook(
        dives: [
          DivingLogRawDive(
            id: 1,
            placeId: 999,
            cityId: 20,
            countryId: 30,
            place: 'Salt Pier',
            city: 'Kralendijk',
            country: 'Bonaire',
          ),
        ],
        capabilities: DivingLogCapabilities(tables: {}, columns: {}),
        cityNamesById: {20: 'Kralendijk'},
        countryNamesById: {30: 'Bonaire'},
      );
      expect(
        DivingLogReferenceMapper.sites(book).keys.single,
        'divinglog_site_bonaire|kralendijk|salt pier',
      );
      expect(
        DivingLogReferenceMapper.sites(book).values.single['name'],
        'Salt Pier',
      );
    });
  });

  group('country fallback', () {
    test('takes the country from the Place when the dive lacks one', () {
      // Place carries its own CountryID, so a dive whose CountryID is
      // absent still has a relational country available.
      final book = logbook(
        places: {
          10: const DivingLogRawPlace(id: 10, countryId: 30, place: 'Karpata'),
        },
        countries: const {30: 'Bonaire'},
        dives: [const DivingLogRawDive(id: 1, placeId: 10)],
      );
      final site = DivingLogReferenceMapper.sites(book).values.single;
      expect(site['country'], 'Bonaire');
      expect(
        DivingLogReferenceMapper.sites(book).keys.single,
        'divinglog_site_bonaire|karpata',
      );
    });
  });

  group('site enrichment', () {
    test('a later Place-backed dive fills what an earlier one lacked', () {
      // The first dive's PlaceID dangles, so it reaches the same key only
      // through the free-text fallback and carries no Place data. The
      // second dive's Place row has the coordinates. First-wins would
      // emit the site without them.
      final book = logbook(
        places: {
          10: const DivingLogRawPlace(
            id: 10,
            countryId: 30,
            place: 'Salt Pier',
            latitude: 12.13,
            longitude: -68.28,
            maxDepthMeters: 24.0,
          ),
        },
        countries: const {30: 'Bonaire'},
        dives: [
          const DivingLogRawDive(
            id: 1,
            placeId: 999,
            countryId: 30,
            place: 'Salt Pier',
          ),
          const DivingLogRawDive(id: 2, placeId: 10, countryId: 30),
        ],
      );
      final sites = DivingLogReferenceMapper.sites(book);
      expect(sites, hasLength(1));
      final site = sites.values.single;
      expect(site['latitude'], closeTo(12.13, 1e-9));
      expect(site['longitude'], closeTo(-68.28, 1e-9));
      expect(site['maxDepth'], closeTo(24.0, 1e-9));
    });
  });

  group('zero sentinels', () {
    test('omits a zero max depth rather than storing it as a depth', () {
      final book = logbook(
        places: {
          10: const DivingLogRawPlace(
            id: 10,
            place: 'Salt Pier',
            maxDepthMeters: 0,
          ),
        },
        dives: [const DivingLogRawDive(id: 1, placeId: 10)],
      );
      final site = DivingLogReferenceMapper.sites(book).values.single;
      expect(site.containsKey('maxDepth'), isFalse);
    });
  });

  group('buddies', () {
    test('joins the name parts and keeps contact details', () {
      final book = logbook(
        buddies: {
          1: const DivingLogRawBuddy(
            id: 1,
            firstName: 'Alice',
            lastName: 'Smith',
            email: 'a@x.test',
            phone: '123',
            comments: 'good buddy',
          ),
        },
      );
      final buddy = DivingLogReferenceMapper.buddies(book).values.single;
      expect(buddy['name'], 'Alice Smith');
      expect(buddy['uddfId'], 'Alice Smith');
      expect(buddy['email'], 'a@x.test');
      expect(buddy['phone'], '123');
      expect(buddy['notes'], 'good buddy');
    });

    test('reports two buddy rows that share a display name', () {
      // Buddies are keyed by name so free-text references fold onto them,
      // which makes two distinct people with one name a single record.
      // That merge is reported rather than done silently.
      final book = logbook(
        buddies: {
          1: const DivingLogRawBuddy(id: 1, firstName: 'Sam', lastName: 'Lee'),
          2: const DivingLogRawBuddy(id: 2, firstName: 'Sam', lastName: 'Lee'),
          3: const DivingLogRawBuddy(id: 3, firstName: 'Ana'),
        },
      );
      expect(DivingLogReferenceMapper.buddyNameCollisions(book), ['Sam Lee']);
    });

    test('skips a row with no name at all', () {
      final book = logbook(buddies: {1: const DivingLogRawBuddy(id: 1)});
      expect(DivingLogReferenceMapper.buddies(book), isEmpty);
    });
  });

  group('trips, centers, types, certifications', () {
    test('maps a trip with its dates', () {
      final book = logbook(
        trips: {
          50: DivingLogRawTrip(
            id: 50,
            name: 'Bonaire 2024',
            startDate: DateTime.utc(2024, 5, 30),
            endDate: DateTime.utc(2024, 6, 8),
            comments: 'shore week',
          ),
        },
      );
      final trip = DivingLogReferenceMapper.trips(book).values.single;
      expect(trip['name'], 'Bonaire 2024');
      expect(trip['startDate'], DateTime.utc(2024, 5, 30));
      expect(trip['endDate'], DateTime.utc(2024, 6, 8));
      expect(trip['notes'], 'shore week');
    });

    test('maps a shop to a dive center', () {
      final book = logbook(
        shops: {
          40: const DivingLogRawShop(
            id: 40,
            name: 'Dive Friends',
            shopType: 'Dive Center',
            city: 'Kralendijk',
            country: 'Bonaire',
            email: 'd@x.test',
            url: 'https://x.test',
          ),
        },
      );
      final center = DivingLogReferenceMapper.diveCenters(book).values.single;
      expect(center['name'], 'Dive Friends');
      expect(center['city'], 'Kralendijk');
      expect(center['country'], 'Bonaire');
      expect(center['email'], 'd@x.test');
      expect(center['website'], 'https://x.test');
    });

    test('maps dive types keyed by the shared slug', () {
      final book = logbook(
        diveTypes: {
          5: const DivingLogRawDiveType(
            id: 5,
            name: 'Live Aboard',
            sortOrder: 6,
          ),
        },
      );
      final types = DivingLogReferenceMapper.diveTypes(book);
      final slug = DiveTypeEntity.generateSlug('Live Aboard');
      // The importer matches dive types on this slug, and a dive references
      // it through `diveTypeIds`, so id, uddfId and the ref must all be it.
      expect(types.keys.single, slug);
      final type = types.values.single;
      expect(type['id'], slug);
      expect(type['uddfId'], slug);
      expect(type['name'], 'Live Aboard');
      expect(type['sortOrder'], 6);
      expect(type['isBuiltIn'], isFalse);
    });

    test('counts a dive type whose name yields no slug as unresolved', () {
      // generateSlug strips everything outside [a-z0-9 -], so a name can be
      // non-blank and still produce nothing. Both diveTypes and
      // diveTypeIdsFor skip it, so the counter must agree or the loss is
      // silent.
      final book = logbook(
        diveTypes: {9: const DivingLogRawDiveType(id: 9, name: '!!!')},
        dives: [
          const DivingLogRawDive(id: 1, diveTypeIds: [9]),
        ],
      );
      expect(DivingLogReferenceMapper.diveTypes(book), isEmpty);
      expect(
        DivingLogReferenceMapper.diveTypeIdsFor(book, book.dives.single),
        isEmpty,
      );
      expect(
        DivingLogReferenceMapper.unresolvedDiveTypeCount(
          book,
          book.dives.single,
        ),
        1,
      );
    });

    test('maps a certification with its agency and date', () {
      final book = logbook(
        certifications: [
          DivingLogRawCertification(
            id: 1,
            name: 'Rescue Diver',
            organisation: 'PADI',
            certDate: DateTime.utc(2023, 9, 8),
            number: '12345',
            instructor: 'Jane Doe',
          ),
        ],
      );
      final cert = DivingLogReferenceMapper.certifications(book).values.single;
      expect(cert['name'], 'Rescue Diver');
      expect(cert['agency'], 'PADI');
      expect(cert['issueDate'], DateTime.utc(2023, 9, 8));
      expect(cert['cardNumber'], '12345');
      expect(cert['instructorName'], 'Jane Doe');
    });
  });
}
