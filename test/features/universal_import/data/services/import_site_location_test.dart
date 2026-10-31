import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_warning.dart';
import 'package:submersion/features/universal_import/data/services/import_site_location.dart';

void main() {
  group('nameFromCoordinates', () {
    test('reads as a coordinate pair at six decimal places', () {
      expect(
        ImportSiteLocation.nameFromCoordinates(20.2114, -87.4654),
        '20.211400, -87.465400',
      );
    });

    test('matches the name the Subsurface fold already gives a site', () {
      // import_site_fold.dart names an unnamed survivor with
      // GeoPoint.toString(); the shared contract must not diverge from it,
      // or the same reef imports under two different names depending on
      // which file it arrived in.
      expect(
        ImportSiteLocation.nameFromCoordinates(20.2114, -87.4654),
        const GeoPoint(20.2114, -87.4654).toString(),
      );
    });

    test('distinguishes two points a parser would otherwise collapse', () {
      expect(
        ImportSiteLocation.nameFromCoordinates(20.2114, -87.4654),
        isNot(ImportSiteLocation.nameFromCoordinates(20.2115, -87.4654)),
      );
    });
  });

  group('placesConflict', () {
    test('needs both sides to state a field and to differ on it', () {
      expect(
        ImportSiteLocation.placesConflict(
          {'country': 'Egypt'},
          {'country': 'Belize'},
        ),
        isTrue,
      );
      expect(
        ImportSiteLocation.placesConflict(
          {'country': 'Egypt'},
          {'region': 'Belize District'},
        ),
        isFalse,
      );
      expect(
        ImportSiteLocation.placesConflict({'country': 'Egypt'}, {}),
        isFalse,
      );
    });

    test('reads every place field', () {
      for (final key in ['city', 'island', 'region', 'country']) {
        expect(
          ImportSiteLocation.placesConflict({key: 'One'}, {key: 'Other'}),
          isTrue,
          reason: key,
        );
      }
    });

    test('ignores case, surrounding space and a blank', () {
      expect(
        ImportSiteLocation.placesConflict(
          {'country': ' EGYPT '},
          {'country': 'egypt'},
        ),
        isFalse,
      );
      expect(
        ImportSiteLocation.placesConflict(
          {'country': '  '},
          {'country': 'Belize'},
        ),
        isFalse,
      );
    });

    test('ignores a field that is not a place', () {
      expect(
        ImportSiteLocation.placesConflict(
          {'name': 'One', 'country': 'Egypt', 'latitude': 1.0},
          {'name': 'Other', 'country': 'Egypt', 'latitude': 2.0},
        ),
        isFalse,
      );
    });
  });

  group('samePlace', () {
    test('needs every field to match', () {
      expect(
        ImportSiteLocation.samePlace(
          {'city': 'Dahab', 'country': ' EGYPT '},
          {'city': 'dahab', 'country': 'egypt'},
        ),
        isTrue,
      );
      expect(
        ImportSiteLocation.samePlace(
          {'city': 'Dahab', 'country': 'Egypt'},
          {'country': 'Egypt'},
        ),
        isFalse,
      );
    });

    test('two sites that state no place are not in the same one', () {
      expect(
        ImportSiteLocation.samePlace({'name': 'Reef'}, {'country': ' '}),
        isFalse,
      );
    });
  });

  group('namesakeOf', () {
    const egypt = DiveSite(id: 'e', name: 'Blue Hole', country: 'Egypt');
    const belize = DiveSite(id: 'b', name: 'Blue Hole', country: 'Belize');

    test('prefers the namesake in exactly that place over a blank one', () {
      const unplaced = DiveSite(id: 'u', name: 'Blue Hole');

      expect(
        ImportSiteLocation.namesakeOf(
          {'country': 'Belize'},
          const [belize, unplaced],
        ),
        belize,
      );
    });

    test('takes the namesake the file does not contradict', () {
      expect(
        ImportSiteLocation.namesakeOf(
          {'country': 'Egypt'},
          const [egypt, belize],
        ),
        egypt,
      );
    });

    test('falls back on the last when nothing tells them apart', () {
      expect(
        ImportSiteLocation.namesakeOf(const {}, const [egypt, belize]),
        belize,
      );
      expect(
        ImportSiteLocation.namesakeOf(
          {'country': 'Malta'},
          const [egypt, belize],
        ),
        belize,
      );
    });

    test('reads the city, island and region of a namesake', () {
      const city = DiveSite(id: 'c', name: 'Reef', city: 'One');
      const island = DiveSite(id: 'i', name: 'Reef', island: 'One');
      const region = DiveSite(id: 'r', name: 'Reef', region: 'One');

      expect(
        ImportSiteLocation.namesakeOf(
          {'city': 'One'},
          const [city, DiveSite(id: 'x', name: 'Reef', city: 'Two')],
        ),
        city,
      );
      expect(
        ImportSiteLocation.namesakeOf(
          {'island': 'One'},
          const [island, DiveSite(id: 'x', name: 'Reef', island: 'Two')],
        ),
        island,
      );
      expect(
        ImportSiteLocation.namesakeOf(
          {'region': 'One'},
          const [region, DiveSite(id: 'x', name: 'Reef', region: 'Two')],
        ),
        region,
      );
    });
  });

  group('named', () {
    test('leaves a named site untouched', () {
      final site = <String, dynamic>{
        'name': 'Dos Ojos',
        'uddfId': 'site-1',
        'latitude': 20.2114,
        'longitude': -87.4654,
      };

      expect(ImportSiteLocation.named(site), same(site));
    });

    test('names a site that has coordinates but no name', () {
      final named = ImportSiteLocation.named(<String, dynamic>{
        'uddfId': 'site-1',
        'latitude': 20.2114,
        'longitude': -87.4654,
      });

      expect(named?['name'], '20.211400, -87.465400');
      expect(named?['latitude'], 20.2114);
      expect(named?['longitude'], -87.4654);
      expect(named?['uddfId'], 'site-1');
    });

    test('names a site whose name is blank rather than absent', () {
      final named = ImportSiteLocation.named(<String, dynamic>{
        'name': '   ',
        'latitude': 20.2114,
        'longitude': -87.4654,
      });

      expect(named?['name'], '20.211400, -87.465400');
    });

    test('does not mutate the caller\'s map', () {
      final site = <String, dynamic>{
        'latitude': 20.2114,
        'longitude': -87.4654,
      };

      ImportSiteLocation.named(site);

      expect(site.containsKey('name'), isFalse);
    });

    test('accepts whole-degree coordinates a parser emitted as int', () {
      // uddf_entity_importer reads `siteData['latitude'] as double?`, so an
      // int latitude used to throw rather than name the site.
      final named = ImportSiteLocation.named(<String, dynamic>{
        'latitude': 20,
        'longitude': -87,
      });

      expect(named?['name'], '20.000000, -87.000000');
    });

    test('drops a site with neither a name nor coordinates', () {
      expect(
        ImportSiteLocation.named(<String, dynamic>{'country': 'MX'}),
        isNull,
      );
    });

    test('drops a site with only one half of a coordinate pair', () {
      expect(
        ImportSiteLocation.named(<String, dynamic>{'latitude': 20.2114}),
        isNull,
      );
    });

    test('drops a site whose coordinates are not finite', () {
      expect(
        ImportSiteLocation.named(<String, dynamic>{
          'latitude': double.nan,
          'longitude': -87.4654,
        }),
        isNull,
      );
    });

    test('keeps a named site that carries no coordinates', () {
      final site = <String, dynamic>{'name': 'Dos Ojos'};

      expect(ImportSiteLocation.named(site), same(site));
    });
  });

  group('coordinatesOf', () {
    test('reads a coordinate pair', () {
      expect(
        ImportSiteLocation.coordinatesOf(<String, dynamic>{
          'latitude': 20.2114,
          'longitude': -87.4654,
        }),
        const GeoPoint(20.2114, -87.4654),
      );
    });

    test('rejects MacDive\'s 0/0 stand-in for "no GPS set"', () {
      expect(
        ImportSiteLocation.coordinatesOf(<String, dynamic>{
          'latitude': 0.0,
          'longitude': 0.0,
        }),
        isNull,
      );
    });

    test('rejects a pair outside the valid range', () {
      expect(
        ImportSiteLocation.coordinatesOf(<String, dynamic>{
          'latitude': 91.0,
          'longitude': -87.4654,
        }),
        isNull,
      );
      expect(
        ImportSiteLocation.coordinatesOf(<String, dynamic>{
          'latitude': 20.2114,
          'longitude': 181.0,
        }),
        isNull,
      );
    });
  });

  group('fix', () {
    test('accepts a usable pair', () {
      expect(
        ImportSiteLocation.fix(20.2114, -87.4654),
        const GeoPoint(20.2114, -87.4654),
      );
    });

    test('rejects the same pairs coordinatesOf rejects', () {
      expect(ImportSiteLocation.fix(0, 0), isNull);
      expect(ImportSiteLocation.fix(91, -87.4654), isNull);
      expect(ImportSiteLocation.fix(20.2114, 181), isNull);
      expect(ImportSiteLocation.fix(double.nan, -87.4654), isNull);
      expect(ImportSiteLocation.fix(double.infinity, -87.4654), isNull);
      expect(ImportSiteLocation.fix(20.2114, null), isNull);
      expect(ImportSiteLocation.fix(null, null), isNull);
    });

    test('is the rule coordinatesOf applies to a map', () {
      // A dive's own fix and a site's coordinates must be judged alike, or
      // a Shearwater dive at 0,0 persists an entry location while the site
      // built from the very same string is dropped.
      expect(
        ImportSiteLocation.coordinatesOf(<String, dynamic>{
          'latitude': 0.0,
          'longitude': 0.0,
        }),
        ImportSiteLocation.fix(0, 0),
      );
    });
  });

  group('sitesUnresolved', () {
    test('carries the code the summary groups on', () {
      final warning = ImportSiteLocation.sitesUnresolved(3);

      expect(warning.code, ImportWarningCode.sitesUnresolved);
      expect(warning.severity, ImportWarningSeverity.warning);
      expect(warning.entityType, ImportEntityType.dives);
      expect(warning.count, 3);
    });
  });
}
