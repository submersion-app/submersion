import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/uddf/uddf_full_import_service.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/data/models/import_warning.dart';
import 'package:submersion/features/universal_import/data/parsers/uddf_import_parser.dart';

import '../../../../helpers/test_database.dart';

/// UDDF's half of the shared location contract (#2209, #2232).
///
/// A dive's `<link ref>` elements are walked by one if/else-if chain over
/// sites, buddies, deco models and dive computers. A ref matching none of
/// them used to fall off the end of that chain in silence, so a logbook whose
/// `<divesite>` block was lost or renamed imported every dive with no site
/// and said nothing about it.
void main() {
  setUp(() async => setUpTestDatabase());
  tearDown(() async => tearDownTestDatabase());

  Future<ImportPayload> parse(String uddf) =>
      UddfImportParser().parse(Uint8List.fromList(utf8.encode(uddf)));

  /// The same document with its links directly under `<dive>` instead of
  /// inside `<informationbeforedive>`. UDDF allows either.
  String documentWithDirectLinks({
    String sites = '',
    required String diveLinks,
  }) =>
      '''<?xml version="1.0" encoding="UTF-8" ?>
<uddf version="3.2.0">
  <divesite>$sites</divesite>
  <profiledata>
    <repetitiongroup id="rg-1">
      <dive id="d-1">
        $diveLinks
        <informationbeforedive>
          <datetime>2024-06-01T09:00:00</datetime>
        </informationbeforedive>
        <informationafterdive>
          <greatestdepth>18.0</greatestdepth>
          <diveduration>2400</diveduration>
        </informationafterdive>
      </dive>
    </repetitiongroup>
  </profiledata>
</uddf>''';

  String document({String sites = '', required String diveLinks}) =>
      '''<?xml version="1.0" encoding="UTF-8" ?>
<uddf version="3.2.0">
  <divesite>$sites</divesite>
  <profiledata>
    <repetitiongroup id="rg-1">
      <dive id="d-1">
        <informationbeforedive>
          $diveLinks
          <datetime>2024-06-01T09:00:00</datetime>
        </informationbeforedive>
        <informationafterdive>
          <greatestdepth>18.0</greatestdepth>
          <diveduration>2400</diveduration>
        </informationafterdive>
      </dive>
    </repetitiongroup>
  </profiledata>
</uddf>''';

  group('a dive whose site reference does not resolve', () {
    test('raises the unresolved-sites notice', () async {
      final payload = await parse(
        document(diveLinks: '<link ref="site-the-file-never-describes" />'),
      );

      final warning = payload.warnings.singleWhere(
        (w) => w.code == ImportWarningCode.sitesUnresolved,
      );
      expect(warning.count, 1);
      expect(warning.severity, ImportWarningSeverity.warning);
    });

    test('still imports the dive, without a site', () async {
      final payload = await parse(
        document(diveLinks: '<link ref="site-the-file-never-describes" />'),
      );

      final dives = payload.entitiesOf(ImportEntityType.dives);
      expect(dives, hasLength(1));
      expect(dives.single['site'], isNull);
    });

    test('a dive whose reference resolves raises nothing', () async {
      final payload = await parse(
        document(
          sites: '<site id="s1"><name>Test Site</name></site>',
          diveLinks: '<link ref="s1" />',
        ),
      );

      expect(
        payload.warnings.where(
          (w) => w.code == ImportWarningCode.sitesUnresolved,
        ),
        isEmpty,
      );
    });

    test(
      'a trip, centre, course or buddy link is not a dangling site',
      () async {
        // The same <link> elements are walked by an earlier pass that keys on
        // these prefixes. Counting them here would raise the notice on a file
        // that never lost a site at all.
        for (final ref in const [
          'trip_1',
          'center_1',
          'course_1',
          'buddy_1',
          'dive_1',
        ]) {
          final payload = await parse(
            document(diveLinks: '<link ref="$ref" />'),
          );

          expect(
            payload.warnings.where(
              (w) => w.code == ImportWarningCode.sitesUnresolved,
            ),
            isEmpty,
            reason: ref,
          );
        }
      },
    );

    test('a dangling dive-computer link is not a dangling site', () async {
      // Submersion's own exporter mints `dc_` ids for <divecomputer>. A file
      // that lost that block has lost a computer, not a location.
      final payload = await parse(
        document(diveLinks: '<link ref="dc_Perdix_2_1234" />'),
      );

      expect(
        payload.warnings.where(
          (w) => w.code == ImportWarningCode.sitesUnresolved,
        ),
        isEmpty,
      );
    });

    test('every non-site prefix the exporter mints is excluded', () {
      // The exclusion list was first built by hand and missed `dc_`. This
      // pins it to the writers, so a new entity type the exporter starts
      // linking cannot be mistaken for a lost site.
      final minted = <String>{};
      for (final file in Directory(
        'lib/core/services/export/uddf',
      ).listSync().whereType<File>().where((f) => f.path.endsWith('.dart'))) {
        for (final m in RegExp(
          r"'([a-z]+_)\$",
        ).allMatches(file.readAsStringSync())) {
          minted.add(m.group(1)!);
        }
      }

      expect(minted, contains('site_'), reason: 'scan found no site ids');
      expect(
        minted.difference({'site_'}),
        everyElement(isIn(UddfFullImportService.nonSiteRefPrefixes)),
      );
      expect(
        UddfFullImportService.nonSiteRefPrefixes,
        isNot(contains('site_')),
      );
    });

    test(
      'a dive with a trip link and a dangling site link still counts',
      () async {
        final payload = await parse(
          document(diveLinks: '<link ref="trip_1" /><link ref="s-missing" />'),
        );

        expect(
          payload.warnings
              .singleWhere((w) => w.code == ImportWarningCode.sitesUnresolved)
              .count,
          1,
        );
      },
    );

    test('a dive with no link at all raises nothing', () async {
      final payload = await parse(document(diveLinks: ''));

      expect(
        payload.warnings.where(
          (w) => w.code == ImportWarningCode.sitesUnresolved,
        ),
        isEmpty,
      );
    });
  });

  group('a site with coordinates and no name', () {
    test('survives under a name built from its coordinates', () async {
      final payload = await parse(
        document(
          sites:
              '<site id="s1"><geography>'
              '<latitude>20.2114</latitude><longitude>-87.4654</longitude>'
              '</geography></site>',
          diveLinks: '<link ref="s1" />',
        ),
      );

      final site = payload.entitiesOf(ImportEntityType.sites).single;
      expect(site['name'], '20.211400, -87.465400');
      expect(site['latitude'], 20.2114);
      expect(site['longitude'], -87.4654);
      // Named at parse time, so the review step shows where the site is
      // rather than "Unnamed", and the dive's link still resolves.
      final dive = payload.entitiesOf(ImportEntityType.dives).single;
      expect((dive['site'] as Map<String, dynamic>)['uddfId'], 's1');
      expect(
        payload.warnings.where(
          (w) => w.code == ImportWarningCode.sitesUnresolved,
        ),
        isEmpty,
      );
    });

    test('a site with neither a name nor coordinates is dropped', () async {
      final payload = await parse(
        document(
          sites: '<site id="s1"><notes><para>nothing</para></notes></site>',
          diveLinks: '<link ref="s1" />',
        ),
      );

      expect(payload.entitiesOf(ImportEntityType.sites), isEmpty);
    });
  });

  group('a link directly under <dive>', () {
    test(
      'resolves its site, as one inside informationbeforedive does',
      () async {
        final payload = await parse(
          documentWithDirectLinks(
            sites: '<site id="s1"><name>Test Site</name></site>',
            diveLinks: '<link ref="s1" />',
          ),
        );

        final dive = payload.entitiesOf(ImportEntityType.dives).single;
        expect((dive['site'] as Map<String, dynamic>)['uddfId'], 's1');
      },
    );

    test('raises the notice when it does not resolve', () async {
      final payload = await parse(
        documentWithDirectLinks(diveLinks: '<link ref="s-missing" />'),
      );

      expect(
        payload.warnings
            .singleWhere((w) => w.code == ImportWarningCode.sitesUnresolved)
            .count,
        1,
      );
    });

    test('a trip link there is still not a dangling site', () async {
      final payload = await parse(
        documentWithDirectLinks(diveLinks: '<link ref="trip_1" />'),
      );

      expect(
        payload.warnings.where(
          (w) => w.code == ImportWarningCode.sitesUnresolved,
        ),
        isEmpty,
      );
    });

    test('does not override a site the inner links already resolved', () async {
      // Both places carry a link; the one that resolves must win rather
      // than the last one read.
      final payload = await parse(
        documentWithDirectLinks(
          sites: '<site id="s1"><name>Test Site</name></site>',
          diveLinks: '<link ref="s1" /><link ref="s-missing" />',
        ),
      );

      final dive = payload.entitiesOf(ImportEntityType.dives).single;
      expect((dive['site'] as Map<String, dynamic>)['uddfId'], 's1');
      expect(
        payload.warnings.where(
          (w) => w.code == ImportWarningCode.sitesUnresolved,
        ),
        isEmpty,
      );
    });
  });
}
