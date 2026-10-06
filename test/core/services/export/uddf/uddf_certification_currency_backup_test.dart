import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/export/models/currency_backup_data.dart';
import 'package:submersion/core/services/export/uddf/uddf_export_builders.dart';
import 'package:submersion/core/services/export/uddf/uddf_full_import_service.dart';
import 'package:submersion/features/certifications/domain/entities/currency_event.dart';
import 'package:submersion/features/certifications/domain/entities/currency_pref.dart';
import 'package:submersion/features/certifications/domain/entities/currency_rule.dart';
import 'package:xml/xml.dart';

import '../../../../helpers/test_database.dart';

/// Certification currency in the UDDF full backup (issue #2267): custom
/// rules, per card prefs and ledger events survive a write and a parse.
final _now = DateTime(2026, 9, 22);

final _customRule = CurrencyRule(
  id: 'custom-1',
  diverId: 'diver-1',
  name: 'Club refresher',
  clockKind: CurrencyClockKind.activity,
  agencies: const [CertificationAgency.bsac],
  levels: const [CertificationLevel.bsacOceanDiver],
  lapseDays: 200,
  leadDays: 30,
  countedDiveTypeIds: const ['boat'],
  countedDiveModes: const [DiveMode.oc],
  advisoryText: 'Our club asks for one every spring',
  supersedesRuleId: 'generic_refresher',
  createdAt: _now,
  updatedAt: _now,
);

final _builtInCave = CurrencyRule(
  id: 'cave_currency',
  name: 'Cave currency',
  clockKind: CurrencyClockKind.activity,
  lapseDays: 365,
  leadDays: 90,
  advisoryKey: 'currencyRule_cave_currency_advisory',
  isBuiltIn: true,
  createdAt: _now,
  updatedAt: _now,
);

final _inheritingPref = CurrencyPref(
  id: 'p1',
  certificationId: 'c1',
  ruleId: 'padi_reactivate',
  createdAt: _now,
  updatedAt: _now,
);

final _tunedPref = CurrencyPref(
  id: 'p2',
  certificationId: 'c1',
  ruleId: 'cave_currency',
  lapseDaysOverride: 400,
  leadDaysOverride: 60,
  countedDiveTypeIds: const [],
  countedDiveModes: const [DiveMode.ccr],
  muted: true,
  createdAt: _now,
  updatedAt: _now,
);

final _refresher = CurrencyEvent(
  id: 'e1',
  certificationId: 'c1',
  ruleId: 'padi_reactivate',
  eventType: CurrencyEventType.refresher,
  eventDate: DateTime(2026, 3, 4),
  provider: 'Blue Hole Divers',
  notes: 'Pool session',
  createdAt: _now,
  updatedAt: _now,
);

String _xml(CurrencyBackupData currency) {
  final builder = XmlBuilder();
  builder.element(
    'uddf',
    attributes: {'version': '3.2.1'},
    nest: () {
      UddfExportBuilders.buildApplicationData(builder, currency: currency);
    },
  );
  return builder.buildDocument().toXmlString();
}

void main() {
  test('an empty bundle writes nothing', () {
    expect(_xml(const CurrencyBackupData()), isNot(contains('currency')));
  });

  test('a built-in rule is never written to the file', () {
    final xml = _xml(CurrencyBackupData(rules: [_builtInCave, _customRule]));
    expect(xml, isNot(contains('cave_currency')));
    expect(xml, contains('<currencyrule id="custom-1">'));
  });

  group('round trip', () {
    setUp(() async => setUpTestDatabase());
    tearDown(() async => tearDownTestDatabase());

    Future<dynamic> roundTrip(CurrencyBackupData currency) =>
        UddfFullImportService().importAllDataFromUddf(_xml(currency));

    test('a custom rule keeps its scope arrays and supersedes link', () async {
      final result = await roundTrip(CurrencyBackupData(rules: [_customRule]));
      final read = result.currencyRules.single as Map<String, dynamic>;
      expect(read['id'], 'custom-1');
      expect(read['name'], 'Club refresher');
      expect(read['clockKind'], 'activity');
      expect(read['applicableAgencies'], '["bsac"]');
      expect(read['applicableLevels'], '["bsacOceanDiver"]');
      expect(read['lapseDays'], 200);
      expect(read['leadDays'], 30);
      expect(read['countedDiveTypeIds'], '["boat"]');
      expect(read['countedDiveModes'], '["oc"]');
      expect(read['advisoryText'], 'Our club asks for one every spring');
      expect(read['supersedesRuleId'], 'generic_refresher');
    });

    test('an inheriting pref comes back inheriting, not empty', () async {
      // NULL means "inherit the rule's mapping"; '[]' means "any dive
      // counts". A round trip that turns one into the other silently
      // changes the rule.
      final result = await roundTrip(
        CurrencyBackupData(prefs: [_inheritingPref, _tunedPref]),
      );
      final prefs = {
        for (final p in result.currencyPrefs as List<Map<String, dynamic>>)
          p['id']: p,
      };
      expect(prefs['p1']!['certificationRef'], 'cert_c1');
      expect(prefs['p1']!['ruleId'], 'padi_reactivate');
      expect(prefs['p1']!['countedDiveTypeIds'], isNull);
      expect(prefs['p1']!['countedDiveModes'], isNull);
      expect(prefs['p1']!['lapseDaysOverride'], isNull);
      expect(prefs['p1']!['muted'], isFalse);

      expect(prefs['p2']!['countedDiveTypeIds'], '[]');
      expect(prefs['p2']!['countedDiveModes'], '["ccr"]');
      expect(prefs['p2']!['lapseDaysOverride'], 400);
      expect(prefs['p2']!['leadDaysOverride'], 60);
      expect(prefs['p2']!['muted'], isTrue);
    });

    test('an event keeps its date, type, provider and notes', () async {
      final result = await roundTrip(CurrencyBackupData(events: [_refresher]));
      final read = result.currencyEvents.single as Map<String, dynamic>;
      expect(read['id'], 'e1');
      expect(read['certificationRef'], 'cert_c1');
      expect(read['ruleId'], 'padi_reactivate');
      expect(read['eventType'], 'refresher');
      expect(read['eventDate'], DateTime(2026, 3, 4));
      expect(read['provider'], 'Blue Hole Divers');
      expect(read['notes'], 'Pool session');
    });
  });
}
