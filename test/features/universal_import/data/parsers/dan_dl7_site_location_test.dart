import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_warning.dart';
import 'package:submersion/features/universal_import/data/parsers/dan_dl7_import_parser.dart';

/// DAN DL7's half of the shared location contract (#2211, #2232).
///
/// A DL7 file carries one `ZAR` block, and the `<LOCATION>` inside it is the
/// only place the file records GPS. The parser applies the ZAR to a dive only
/// when the file holds exactly one, which is right for per-dive values but
/// used to throw the position away entirely for a multi-dive file.
void main() {
  const parser = DanDl7Parser();

  String document({required int dives, String? location}) {
    final buffer = StringBuffer()
      ..writeln(r'FSH|^~\&{}|ANST01^12X456^A|ZXU|20240310120000|')
      ..writeln(r'ZRH|^~\&{}|||MFWG|ThM|C|bar|L|');
    if (location != null) {
      buffer
        ..writeln('ZAR{')
        ..writeln('<AQUALUNG>')
        ..writeln('<APP>DiverLog+</APP>')
        ..writeln('<LOCATION>$location</LOCATION>')
        ..writeln('</AQUALUNG>')
        ..writeln('}');
    }
    for (var i = 1; i <= dives; i++) {
      buffer
        ..writeln('ZDH|$i|$i|M|QS|2024030${i}100000|22|||')
        ..writeln('ZDT|1|$i|12.0|2024030${i}102500|21||');
    }
    return buffer.toString();
  }

  Future<List<Map<String, dynamic>>> sitesOf(String doc) async {
    final payload = await parser.parse(Uint8List.fromList(utf8.encode(doc)));
    return payload.entitiesOf(ImportEntityType.sites);
  }

  const withName =
      'GPS=[20.877432,-156.679867],LOCNAME=[Molokini Crater],'
      'CITY=[Kihei],STATE/PROVINCE=[Hawaii],COUNTRY=[United States]';
  const withoutName = 'GPS=[20.877432,-156.679867],CITY=[Kihei]';

  group('a multi-dive file', () {
    test(
      'keeps the ZAR location as a site rather than discarding it',
      () async {
        final sites = await sitesOf(document(dives: 3, location: withName));

        expect(sites, hasLength(1));
        expect(sites.single['name'], 'Molokini Crater');
        expect(sites.single['latitude'], closeTo(20.877432, 1e-9));
        expect(sites.single['longitude'], closeTo(-156.679867, 1e-9));
      },
    );

    test('warns that the dives could not be attached to it', () async {
      final payload = await parser.parse(
        Uint8List.fromList(utf8.encode(document(dives: 3, location: withName))),
      );

      final warning = payload.warnings.singleWhere(
        (w) => w.code == ImportWarningCode.sitesUnresolved,
      );
      expect(warning.count, 3);
    });

    test('leaves the dives themselves unattached', () async {
      final payload = await parser.parse(
        Uint8List.fromList(utf8.encode(document(dives: 3, location: withName))),
      );

      final dives = payload.entitiesOf(ImportEntityType.dives);
      expect(dives, hasLength(3));
      expect(dives.every((d) => d['site'] == null), isTrue);
    });

    test(
      'names a location the file never labelled from its coordinates',
      () async {
        final sites = await sitesOf(document(dives: 2, location: withoutName));

        expect(sites.single['name'], '20.877432, -156.679867');
      },
    );

    test(
      'a ZAR with no location at all raises nothing and adds no site',
      () async {
        final payload = await parser.parse(
          Uint8List.fromList(
            utf8.encode(document(dives: 2, location: 'CITY=[Kihei]')),
          ),
        );

        expect(payload.entitiesOf(ImportEntityType.sites), isEmpty);
        expect(
          payload.warnings.where(
            (w) => w.code == ImportWarningCode.sitesUnresolved,
          ),
          isEmpty,
        );
      },
    );

    test('a file with no ZAR raises nothing', () async {
      final payload = await parser.parse(
        Uint8List.fromList(utf8.encode(document(dives: 2))),
      );

      expect(
        payload.warnings.where(
          (w) => w.code == ImportWarningCode.sitesUnresolved,
        ),
        isEmpty,
      );
    });
  });

  group('a single-dive file', () {
    test('still attaches its dive to the ZAR site', () async {
      final payload = await parser.parse(
        Uint8List.fromList(utf8.encode(document(dives: 1, location: withName))),
      );

      final dive = payload.entitiesOf(ImportEntityType.dives).single;
      expect((dive['site'] as Map<String, dynamic>)['uddfId'], isNotNull);
      expect(
        payload.warnings.where(
          (w) => w.code == ImportWarningCode.sitesUnresolved,
        ),
        isEmpty,
      );
    });

    test('names a nameless ZAR location from its coordinates', () async {
      final sites = await sitesOf(document(dives: 1, location: withoutName));

      expect(sites.single['name'], '20.877432, -156.679867');
    });
  });
}
