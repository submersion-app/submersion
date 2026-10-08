import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/data/models/import_warning.dart';
import 'package:submersion/features/universal_import/data/parsers/dan_dl7_import_parser.dart';

/// Which dive a multi-dive DL7 file's `ZAR` block describes (#2211).
///
/// DiverLog+ stamps each `<AQUALUNG>` block with `<DIVE_DT>` (and the same
/// timestamp inside `<DUID>`), the start time the dive's `ZDH` segment also
/// carries. The block used to be dropped whole for any file holding more than
/// one dive, losing its site, GPS, rating, surface interval and tanks.
void main() {
  const parser = DanDl7Parser();

  const molokini =
      'GPS=[20.877432,-156.679867],LOCNAME=[Molokini Crater],'
      'COUNTRY=[United States]';
  const turtleTown = 'GPS=[20.6297,-156.4453],LOCNAME=[Turtle Town]';

  String zar({
    String? diveDt,
    String? duid,
    String location = molokini,
    int rating = 4,
    String title = 'Morning Reef Drift',
  }) => [
    'ZAR{',
    '<AQUALUNG>',
    '<APP>DiverLog+</APP>',
    if (duid != null) '<DUID>$duid</DUID>',
    '<TITLE>$title</TITLE>',
    if (diveDt != null) '<DIVE_DT>$diveDt</DIVE_DT>',
    '<LOCATION>$location</LOCATION>',
    '<GEAR>GEAR_UNITS=1</GEAR>',
    '<RATING>$rating</RATING>',
    '<DIVESTATS>DIVENO=7,SI=010000</DIVESTATS>',
    '<TANK>CYLNAME=[AL80],STARTPRESSURE=200,ENDPRESSURE=50,FO2=32</TANK>',
    '</AQUALUNG>',
    '}',
  ].join('\n');

  String dive(int n, String start) =>
      'ZDH|$n|$n|M|QS|$start|22|||\n'
      'ZDT|1|$n|12.0|${start.substring(0, 10)}2500|21||';

  const header =
      'FSH|^~\\&{}|ANST01^12X456^A|ZXU|20240310120000|\n'
      'ZRH|^~\\&{}|||MFWG|ThM|C|bar|L|';

  Future<ImportPayload> parse(List<String> segments) => parser.parse(
    Uint8List.fromList(utf8.encode([header, ...segments].join('\n'))),
  );

  List<Map<String, dynamic>> divesOf(ImportPayload payload) =>
      payload.entitiesOf(ImportEntityType.dives);

  Iterable<ImportWarning> unresolved(ImportPayload payload) => payload.warnings
      .where((w) => w.code == ImportWarningCode.sitesUnresolved);

  group('a ZAR block in a multi-dive file', () {
    test('attaches its site and GPS to the dive DIVE_DT names', () async {
      final payload = await parse([
        zar(diveDt: '20240302110000'),
        dive(1, '20240301100000'),
        dive(2, '20240302110000'),
      ]);

      final dives = divesOf(payload);
      expect(dives, hasLength(2));
      expect(dives[0]['site'], isNull);
      expect(dives[0]['latitude'], isNull);

      final sites = payload.entitiesOf(ImportEntityType.sites);
      expect(sites.single['name'], 'Molokini Crater');
      expect(
        (dives[1]['site'] as Map<String, dynamic>)['uddfId'],
        sites.single['uddfId'],
      );
      expect(dives[1]['latitude'], closeTo(20.877432, 1e-9));
      expect(dives[1]['longitude'], closeTo(-156.679867, 1e-9));
      expect(unresolved(payload), isEmpty);
    });

    test('brings the rest of the block to that dive', () async {
      final payload = await parse([
        zar(diveDt: '20240302110000', duid: '1_2_20240302110000_7'),
        dive(1, '20240301100000'),
        dive(2, '20240302110000'),
      ]);

      final matched = divesOf(payload)[1];
      expect(matched['rating'], 4);
      expect(matched['name'], 'Morning Reef Drift');
      expect(matched['sourceUuid'], '1_2_20240302110000_7');
      expect(matched['surfaceInterval'], const Duration(hours: 1));
      expect(matched['diveNumber'], 7);
      final tank = (matched['tanks'] as List).single as Map<String, dynamic>;
      expect(tank['name'], 'AL80');
      expect(tank['startPressure'], 200);

      final other = divesOf(payload)[0];
      for (final key in const ['rating', 'name', 'sourceUuid', 'tanks']) {
        expect(other[key], isNull, reason: key);
      }
      expect(other['diveNumber'], 1, reason: 'from its own ZDH');
    });

    test(
      'is matched by the timestamp in DUID when it has no DIVE_DT',
      () async {
        final payload = await parse([
          zar(duid: '4321_98765_20240301100000_42'),
          dive(1, '20240301100000'),
          dive(2, '20240302110000'),
        ]);

        final dives = divesOf(payload);
        expect(dives[0]['site'], isNotNull);
        expect(dives[1]['site'], isNull);
        expect(unresolved(payload), isEmpty);
      },
    );

    test('matches a dive whose start differs only in seconds', () async {
      // ZDH may record the start to the minute while DIVE_DT carries seconds;
      // no two dives start within the same minute.
      final payload = await parse([
        zar(diveDt: '20240302110045'),
        dive(1, '20240301100000'),
        dive(2, '202403021100'),
      ]);

      expect(divesOf(payload)[1]['site'], isNotNull);
      expect(unresolved(payload), isEmpty);
    });

    test('prefers an exact start over a same-minute one', () async {
      // Two records in one minute: the block for 10:00:30 comes first and
      // would take the 10:00:00 dive if the minute alone decided.
      final payload = await parse([
        zar(diveDt: '20240301100030', rating: 5),
        zar(diveDt: '20240301100000', rating: 3),
        dive(1, '20240301100000'),
        dive(2, '20240301100030'),
      ]);

      final dives = divesOf(payload);
      expect(dives[0]['rating'], 3);
      expect(dives[1]['rating'], 5);
    });

    test(
      'gives each dive its own block when the file has one per dive',
      () async {
        final payload = await parse([
          zar(diveDt: '20240301100000', rating: 3),
          dive(1, '20240301100000'),
          zar(diveDt: '20240302110000', location: turtleTown, rating: 5),
          dive(2, '20240302110000'),
        ]);

        final dives = divesOf(payload);
        final sites = {
          for (final site in payload.entitiesOf(ImportEntityType.sites))
            site['uddfId']: site['name'],
        };
        expect(
          sites.values,
          unorderedEquals(['Molokini Crater', 'Turtle Town']),
        );
        expect(sites[(dives[0]['site'] as Map)['uddfId']], 'Molokini Crater');
        expect(sites[(dives[1]['site'] as Map)['uddfId']], 'Turtle Town');
        expect(dives[0]['rating'], 3);
        expect(dives[1]['rating'], 5);
        expect(unresolved(payload), isEmpty);
      },
    );

    test('that names no dive in the file keeps its site and says so', () async {
      final payload = await parse([
        zar(diveDt: '20231225080000'),
        dive(1, '20240301100000'),
        dive(2, '20240302110000'),
      ]);

      final dives = divesOf(payload);
      expect(dives.every((d) => d['site'] == null), isTrue);
      expect(dives.every((d) => d['rating'] == null), isTrue);
      expect(
        payload.entitiesOf(ImportEntityType.sites).single['name'],
        'Molokini Crater',
      );
      expect(unresolved(payload).single.count, 2);
    });

    test('counts only the dives left without a block as unattached', () async {
      final payload = await parse([
        zar(diveDt: '20240301100000'),
        zar(diveDt: '20231225080000', location: turtleTown),
        dive(1, '20240301100000'),
        dive(2, '20240302110000'),
        dive(3, '20240303090000'),
      ]);

      final dives = divesOf(payload);
      expect(dives[0]['site'], isNotNull);
      expect(dives[1]['site'], isNull);
      expect(dives[2]['site'], isNull);
      expect(payload.entitiesOf(ImportEntityType.sites), hasLength(2));
      expect(unresolved(payload).single.count, 2);
    });

    test('is not applied to a second dive at the same time', () async {
      // A duplicated record: the block describes one dive, not both.
      final payload = await parse([
        zar(diveDt: '20240301100000'),
        dive(1, '20240301100000'),
        dive(2, '20240301100000'),
      ]);

      final dives = divesOf(payload);
      expect(dives[0]['rating'], 4);
      expect(dives[1]['rating'], isNull);
    });
  });

  group('a single-dive file', () {
    test('still takes its block when DIVE_DT disagrees with ZDH', () async {
      // DiveCloud files hold one dive and one block; the block is that dive's
      // whatever its clock says.
      final payload = await parse([
        zar(diveDt: '20231225080000'),
        dive(1, '20240301100000'),
      ]);

      final only = divesOf(payload).single;
      expect(only['site'], isNotNull);
      expect(only['rating'], 4);
      expect(unresolved(payload), isEmpty);
    });

    test('prefers the block whose DIVE_DT matches', () async {
      final payload = await parse([
        zar(diveDt: '20231225080000', rating: 2),
        zar(diveDt: '20240301100000', rating: 5),
        dive(1, '20240301100000'),
      ]);

      expect(divesOf(payload).single['rating'], 5);
    });
  });

  group('a ZAR block in a dialect the parser does not read', () {
    test('is recorded as a diagnostic rather than dropped silently', () async {
      final payload = await parse([
        'ZAR{More Mobile Software, DiveLogDT, version 4.144}',
        dive(1, '20240301100000'),
      ]);

      final diagnostic = payload.warnings.singleWhere(
        (w) => w.code == ImportWarningCode.diagnostic,
      );
      expect(diagnostic.message, contains('ZAR'));
      expect(divesOf(payload), hasLength(1));
    });

    test('an Aqualung block raises no such diagnostic', () async {
      final payload = await parse([
        zar(diveDt: '20240301100000'),
        dive(1, '20240301100000'),
      ]);

      expect(
        payload.warnings.where((w) => w.code == ImportWarningCode.diagnostic),
        isEmpty,
      );
    });
  });
}
