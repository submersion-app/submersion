import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/data/models/import_warning.dart';
import 'package:submersion/features/universal_import/data/services/macdive_dive_mapper.dart';
import 'package:submersion/features/universal_import/data/services/macdive_raw_types.dart';

/// MacDive's half of the shared location contract (#2213, #2232).
///
/// Both shapes of the bug live here: a `ZDIVESITE` row with an empty name was
/// skipped before `ZGPSLAT`/`ZGPSLON` were ever read, and a dive whose
/// `ZRELATIONSHIPDIVESITE` pointed at a row that is not in the file fell
/// through without a word.
void main() {
  MacDiveRawLogbook logbook({
    List<MacDiveRawSite> sites = const [],
    List<MacDiveRawDive> dives = const [],
  }) => MacDiveRawLogbook(
    dives: dives,
    sitesByPk: {for (final s in sites) s.pk: s},
    buddiesByPk: const {},
    tagsByPk: const {},
    gearByPk: const {},
    tanksByPk: const {},
    gasesByPk: const {},
    tankAndGases: const [],
    crittersByPk: const {},
    certifications: const [],
    serviceRecords: const [],
    events: const [],
    diveToBuddyPks: const {},
    diveToTagPks: const {},
    diveToGearPks: const {},
    diveToCritterPks: const {},
    unitsPreference: 'Metric',
  );

  List<Map<String, dynamic>> sitesOf(ImportPayload p) =>
      p.entities[ImportEntityType.sites] ?? const [];
  List<Map<String, dynamic>> divesOf(ImportPayload p) =>
      p.entities[ImportEntityType.dives] ?? const [];

  group('a site with coordinates and no name', () {
    test('survives under a name built from its coordinates', () async {
      final payload = await MacDiveDiveMapper.toPayload(
        logbook(
          sites: const [
            MacDiveRawSite(
              pk: 1,
              uuid: 'site-1',
              latitude: 20.2114,
              longitude: -87.4654,
            ),
          ],
        ),
      );

      final site = sitesOf(payload).single;
      expect(site['name'], '20.211400, -87.465400');
      expect(site['latitude'], 20.2114);
      expect(site['longitude'], -87.4654);
    });

    test('is the site the dive links to', () async {
      final payload = await MacDiveDiveMapper.toPayload(
        logbook(
          sites: const [
            MacDiveRawSite(
              pk: 1,
              uuid: 'site-1',
              latitude: 20.2114,
              longitude: -87.4654,
            ),
          ],
          dives: const [MacDiveRawDive(pk: 10, uuid: 'dive-1', diveSiteFk: 1)],
        ),
      );

      final dive = divesOf(payload).single;
      final ref = (dive['site'] as Map<String, dynamic>)['uddfId'];
      expect(ref, sitesOf(payload).single['uddfId']);
      expect(dive['siteName'], '20.211400, -87.465400');
    });

    test(
      'a site with neither a name nor coordinates is still dropped',
      () async {
        final payload = await MacDiveDiveMapper.toPayload(
          logbook(
            sites: const [
              MacDiveRawSite(pk: 1, uuid: 'site-1', country: 'Mexico'),
            ],
          ),
        );

        expect(sitesOf(payload), isEmpty);
      },
    );

    test('a nameless site at MacDive\'s 0/0 "no GPS set" is dropped', () async {
      final payload = await MacDiveDiveMapper.toPayload(
        logbook(
          sites: const [
            MacDiveRawSite(
              pk: 1,
              uuid: 'site-1',
              latitude: 0.0,
              longitude: 0.0,
            ),
          ],
        ),
      );

      expect(sitesOf(payload), isEmpty);
    });
  });

  group('a dive whose site reference does not resolve', () {
    test('raises the unresolved-sites notice', () async {
      final payload = await MacDiveDiveMapper.toPayload(
        logbook(
          dives: const [
            MacDiveRawDive(pk: 10, uuid: 'dive-1', diveSiteFk: 99),
            MacDiveRawDive(pk: 11, uuid: 'dive-2', diveSiteFk: 99),
          ],
        ),
      );

      final warning = payload.warnings.singleWhere(
        (w) => w.code == ImportWarningCode.sitesUnresolved,
      );
      expect(warning.count, 2);
      expect(warning.severity, ImportWarningSeverity.warning);
    });

    test('still imports the dive, without a site', () async {
      final payload = await MacDiveDiveMapper.toPayload(
        logbook(
          dives: const [MacDiveRawDive(pk: 10, uuid: 'dive-1', diveSiteFk: 99)],
        ),
      );

      expect(divesOf(payload), hasLength(1));
      expect(divesOf(payload).single['site'], isNull);
    });

    test('a dive that never referenced a site raises nothing', () async {
      final payload = await MacDiveDiveMapper.toPayload(
        logbook(dives: const [MacDiveRawDive(pk: 10, uuid: 'dive-1')]),
      );

      expect(
        payload.warnings.where(
          (w) => w.code == ImportWarningCode.sitesUnresolved,
        ),
        isEmpty,
      );
    });

    test('a dive whose reference resolves raises nothing', () async {
      final payload = await MacDiveDiveMapper.toPayload(
        logbook(
          sites: const [
            MacDiveRawSite(pk: 1, uuid: 'site-1', name: 'Dos Ojos'),
          ],
          dives: const [MacDiveRawDive(pk: 10, uuid: 'dive-1', diveSiteFk: 1)],
        ),
      );

      expect(
        payload.warnings.where(
          (w) => w.code == ImportWarningCode.sitesUnresolved,
        ),
        isEmpty,
      );
    });
  });
}
