import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/data/parsers/uddf_import_parser.dart';

import '../../../../helpers/test_database.dart';

void main() {
  setUp(() async {
    await setUpTestDatabase();
  });

  tearDown(() async => tearDownTestDatabase());

  test('carries custom dive role definitions in the metadata', () async {
    // Issue #1737: per-dive links name custom roles by id, so the wizard
    // must restore the definitions too, or the links point at nothing.
    const uddf = '''
<?xml version="1.0" encoding="UTF-8"?>
<uddf version="3.2.0">
  <applicationdata>
    <submersion>
      <diveroles>
        <diverole id="custom-uuid">
          <name>Photographer</name>
          <sortorder>10</sortorder>
          <isbuiltin>false</isbuiltin>
        </diverole>
      </diveroles>
    </submersion>
  </applicationdata>
</uddf>
''';

    final payload = await UddfImportParser().parse(
      Uint8List.fromList(utf8.encode(uddf)),
    );

    final roles = payload.metadata[ImportPayload.customDiveRolesKey] as List;
    expect(roles, hasLength(1));
    expect((roles.single as Map)['id'], 'custom-uuid');
    expect((roles.single as Map)['name'], 'Photographer');
  });

  test('carries certification currency rows in the metadata', () async {
    // Issue #2267: currency rows have no review step, so they cross the
    // wizard as metadata, each pref and event naming its <cert>.
    const uddf = '''
<?xml version="1.0" encoding="UTF-8"?>
<uddf version="3.2.0">
  <applicationdata>
    <submersion>
      <certifications>
        <cert id="cert_c1"><name>Full Cave</name><agency>tdi</agency></cert>
      </certifications>
      <currencyrules>
        <currencyrule id="custom-1">
          <name>Club check-out</name>
          <clockkind>activity</clockkind>
          <lapsedays>180</lapsedays>
          <leaddays>30</leaddays>
        </currencyrule>
      </currencyrules>
      <currencyprefs>
        <currencypref id="p1" certref="cert_c1" rule="custom-1">
          <muted>true</muted>
        </currencypref>
      </currencyprefs>
      <currencyevents>
        <currencyevent id="e1" certref="cert_c1" rule="custom-1">
          <type>refresher</type>
          <date>2026-05-01T00:00:00.000</date>
        </currencyevent>
      </currencyevents>
    </submersion>
  </applicationdata>
</uddf>
''';

    final payload = await UddfImportParser().parse(
      Uint8List.fromList(utf8.encode(uddf)),
    );

    final rules = payload.metadata[ImportPayload.currencyRulesKey] as List;
    final prefs = payload.metadata[ImportPayload.currencyPrefsKey] as List;
    final events = payload.metadata[ImportPayload.currencyEventsKey] as List;
    expect((rules.single as Map)['id'], 'custom-1');
    expect((prefs.single as Map)['certificationRef'], 'cert_c1');
    expect((events.single as Map)['eventType'], 'refresher');
  });
}
