import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/services/shearwater_db_reader.dart';
import 'package:submersion/features/universal_import/data/services/shearwater_dive_mapper.dart';

/// Shearwater Cloud's half of the shared location contract (#2210, #2232).
///
/// A Swift records a GNSS fix on entry whether or not the diver ever typed a
/// site name, and `mapSites` used to bail on the missing name before it ever
/// read the fix.
void main() {
  const filename = 'Teric[69FE56D7]#23 2025-12-27 14-01-08.swlogzp';

  ShearwaterRawDive rawDive({
    String? site,
    String? gnssEntryLocation,
    String? gnssExitLocation,
    String diveId = 'd1',
  }) => ShearwaterRawDive(
    diveId: diveId,
    diveDate: '2025-12-27 14:01:08',
    site: site,
    gnssEntryLocation: gnssEntryLocation,
    gnssExitLocation: gnssExitLocation,
    fileName: filename,
  );

  group('a site with coordinates and no name', () {
    test('survives under a name built from its coordinates', () {
      final sites = ShearwaterDiveMapper.mapSites([
        rawDive(gnssEntryLocation: '20.2114, -87.4654'),
      ]);

      expect(sites, hasLength(1));
      expect(sites.single['name'], '20.211400, -87.465400');
      expect(sites.single['latitude'], 20.2114);
      expect(sites.single['longitude'], -87.4654);
    });

    test('is the site the dive links to', () {
      final raw = rawDive(gnssEntryLocation: '20.2114, -87.4654');
      final sites = ShearwaterDiveMapper.mapSites([raw]);
      final dive = ShearwaterDiveMapper.mapDiveMetadata(raw);

      final ref = (dive['site'] as Map<String, dynamic>)['uddfId'];
      expect(ref, sites.single['uddfId']);
    });

    test('does not fold into a differently placed nameless dive', () {
      final sites = ShearwaterDiveMapper.mapSites([
        rawDive(diveId: 'd1', gnssEntryLocation: '20.2114, -87.4654'),
        rawDive(diveId: 'd2', gnssEntryLocation: '18.5100, -87.4000'),
      ]);

      expect(sites, hasLength(2));
    });

    test('a named dive still wins its own name', () {
      final sites = ShearwaterDiveMapper.mapSites([
        rawDive(site: 'Maclearie Park', gnssEntryLocation: '40.1900, -74.0300'),
      ]);

      expect(sites.single['name'], 'Maclearie Park');
      expect(sites.single['latitude'], 40.19);
    });

    test('a dive with neither a name nor a fix produces no site', () {
      expect(ShearwaterDiveMapper.mapSites([rawDive()]), isEmpty);
      expect(ShearwaterDiveMapper.mapDiveMetadata(rawDive())['site'], isNull);
    });
  });

  group('the dive keeps its own fix', () {
    test('entry GNSS becomes the dive\'s entry coordinates', () {
      final dive = ShearwaterDiveMapper.mapDiveMetadata(
        rawDive(site: 'Maclearie Park', gnssEntryLocation: '40.1900, -74.0300'),
      );

      expect(dive['latitude'], 40.19);
      expect(dive['longitude'], -74.03);
    });

    test('exit GNSS becomes the dive\'s exit coordinates', () {
      final dive = ShearwaterDiveMapper.mapDiveMetadata(
        rawDive(gnssExitLocation: '40.1901, -74.0301'),
      );

      expect(dive['exitLatitude'], 40.1901);
      expect(dive['exitLongitude'], -74.0301);
    });

    test('an unusable fix is not persisted as a location', () {
      // 0,0 is the sentinel a logbook writes when no fix was taken, and the
      // site built from the same string is already dropped. The dive must
      // agree, or it lands in the Atlantic.
      final atNullIsland = ShearwaterDiveMapper.mapDiveMetadata(
        rawDive(gnssEntryLocation: '0, 0'),
      );
      expect(atNullIsland['latitude'], isNull);
      expect(atNullIsland['longitude'], isNull);

      final offGlobe = ShearwaterDiveMapper.mapDiveMetadata(
        rawDive(gnssEntryLocation: '91.5, -74.03'),
      );
      expect(offGlobe['latitude'], isNull);

      final badExit = ShearwaterDiveMapper.mapDiveMetadata(
        rawDive(gnssExitLocation: '40.19, 181.0'),
      );
      expect(badExit['exitLatitude'], isNull);
    });

    test('an unreadable fix leaves the dive without coordinates', () {
      final dive = ShearwaterDiveMapper.mapDiveMetadata(
        rawDive(gnssEntryLocation: 'not a fix'),
      );

      expect(dive['latitude'], isNull);
      expect(dive['longitude'], isNull);
    });
  });
}
