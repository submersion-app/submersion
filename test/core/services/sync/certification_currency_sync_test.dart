import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';

import '../../../helpers/test_database.dart';

/// Certification currency sync (issue #2267). Built-in rules are reference
/// data: seeded on every device, never exported, and spared when an adopt
/// clears the table. Custom rules, prefs and events are ordinary rows.
void main() {
  late SyncDataSerializer serializer;

  setUp(() async {
    await setUpTestDatabase();
    serializer = SyncDataSerializer();
  });
  tearDown(tearDownTestDatabase);

  Map<String, dynamic> customRule({String id = 'custom-1'}) => {
    'id': id,
    'diverId': null,
    'name': 'Club refresher',
    'clockKind': 'activity',
    'applicableAgencies': '["bsac"]',
    'applicableLevels': '[]',
    'lapseDays': 200,
    'leadDays': 30,
    'countedDiveTypeIds': '[]',
    'countedDiveModes': '[]',
    'advisoryKey': null,
    'advisoryText': 'Club rule',
    'supersedesRuleId': 'generic_refresher',
    'isBuiltIn': false,
    'createdAt': 1000,
    'updatedAt': 1000,
    'hlc': null,
  };

  Future<void> seedCertification() =>
      serializer.upsertRecord('certifications', {
        'id': 'c1',
        'name': 'Open Water',
        'agency': 'padi',
        'notes': '',
        'createdAt': 1000,
        'updatedAt': 1000,
      });

  test('all three entities are registered everywhere', () {
    expect(SyncRepository.hlcTargets['certificationCurrencyRules'], (
      table: 'certification_currency_rules',
      pk: 'id',
    ));
    expect(SyncRepository.hlcTargets['certificationCurrencyPrefs'], (
      table: 'certification_currency_prefs',
      pk: 'id',
    ));
    expect(SyncRepository.hlcTargets['certificationCurrencyEvents'], (
      table: 'certification_currency_events',
      pk: 'id',
    ));
    for (final type in const [
      'certificationCurrencyRules',
      'certificationCurrencyPrefs',
      'certificationCurrencyEvents',
    ]) {
      expect(SyncService.entityHasUpdatedAt[type], isTrue, reason: type);
    }
    expect(SyncService.parentRefs['certificationCurrencyPrefs'], [
      (field: 'certificationId', parent: 'certifications', nullable: false),
    ]);
    expect(SyncService.parentRefs['certificationCurrencyEvents'], [
      (field: 'certificationId', parent: 'certifications', nullable: false),
    ]);
  });

  test(
    'the export omits built-in rules, so a refill cannot restore them',
    () async {
      final data = (await serializer.exportData(
        deviceId: 'peer',
        deletions: const [],
      )).data;
      expect(
        data.certificationCurrencyRules,
        isEmpty,
        reason: 'ten built-ins are seeded; none of them may travel',
      );
    },
  );

  test('a custom rule, a pref and an event all travel', () async {
    await seedCertification();
    await serializer.upsertRecord('certificationCurrencyRules', customRule());
    await serializer.upsertRecord('certificationCurrencyPrefs', {
      'id': 'p1',
      'certificationId': 'c1',
      'ruleId': 'padi_reactivate',
      'lapseDaysOverride': 400,
      'leadDaysOverride': null,
      'countedDiveTypeIds': null,
      'countedDiveModes': '[]',
      'muted': true,
      'createdAt': 1000,
      'updatedAt': 1000,
      'hlc': null,
    });
    await serializer.upsertRecord('certificationCurrencyEvents', {
      'id': 'e1',
      'certificationId': 'c1',
      'ruleId': 'padi_reactivate',
      'eventType': 'refresher',
      'eventDate': 1758499200000,
      'provider': 'Blue Hole Divers',
      'notes': '',
      'createdAt': 1000,
      'updatedAt': 1000,
      'hlc': null,
    });

    final data = (await serializer.exportData(
      deviceId: 'peer',
      deletions: const [],
    )).data;
    expect(data.certificationCurrencyRules.single['id'], 'custom-1');
    final pref = data.certificationCurrencyPrefs.single;
    expect(pref['countedDiveTypeIds'], isNull, reason: 'null means inherit');
    expect(pref['countedDiveModes'], '[]', reason: '[] means any dive');
    expect(pref['muted'], isTrue);
    expect(data.certificationCurrencyEvents.single['eventDate'], 1758499200000);

    final roundTrip = SyncData.fromJson(data.toJson());
    expect(roundTrip.certificationCurrencyRules.single['id'], 'custom-1');
    expect(roundTrip.certificationCurrencyPrefs.single['id'], 'p1');
    expect(roundTrip.certificationCurrencyEvents.single['id'], 'e1');
  });

  test('single-record fetch, batch fetch and delete', () async {
    await serializer.upsertRecords('certificationCurrencyRules', [
      customRule(id: 'r1'),
      customRule(id: 'r2'),
    ]);
    expect(
      (await serializer.fetchRecord('certificationCurrencyRules', 'r1'))?['id'],
      'r1',
    );
    expect(
      (await serializer.fetchRecords('certificationCurrencyRules', [
        'r1',
        'r2',
      ])).keys.toSet(),
      {'r1', 'r2'},
    );
    await serializer.deleteRecord('certificationCurrencyRules', 'r1');
    expect(
      await serializer.fetchRecord('certificationCurrencyRules', 'r1'),
      isNull,
    );
  });

  test('deleteAllRecords spares built-ins and clears custom rules', () async {
    await serializer.upsertRecord('certificationCurrencyRules', customRule());
    await serializer.deleteAllRecords('certificationCurrencyRules');
    final ids = await serializer.recordIdsFor('certificationCurrencyRules');
    expect(ids.length, 11);
    expect(ids, isNot(contains('custom-1')));
    expect(ids, contains('cave_currency'));
  });

  test('prefs and events fetch, batch fetch and delete by id', () async {
    await seedCertification();
    Map<String, dynamic> pref(String id) => {
      'id': id,
      'certificationId': 'c1',
      'ruleId': 'padi_reactivate',
      'lapseDaysOverride': null,
      'leadDaysOverride': null,
      'countedDiveTypeIds': null,
      'countedDiveModes': null,
      'muted': false,
      'createdAt': 1000,
      'updatedAt': 1000,
      'hlc': null,
    };
    Map<String, dynamic> event(String id) => {
      'id': id,
      'certificationId': 'c1',
      'ruleId': null,
      'eventType': 'renewal',
      'eventDate': 1758499200000,
      'provider': null,
      'notes': '',
      'createdAt': 1000,
      'updatedAt': 1000,
      'hlc': null,
    };
    await serializer.upsertRecords('certificationCurrencyPrefs', [
      pref('p1'),
      pref('p2'),
    ]);
    await serializer.upsertRecords('certificationCurrencyEvents', [
      event('e1'),
      event('e2'),
    ]);

    for (final (type, a, b) in [
      ('certificationCurrencyPrefs', 'p1', 'p2'),
      ('certificationCurrencyEvents', 'e1', 'e2'),
    ]) {
      expect((await serializer.fetchRecord(type, a))?['id'], a, reason: type);
      expect((await serializer.fetchRecords(type, [a, b])).keys.toSet(), {
        a,
        b,
      }, reason: type);
      expect(await serializer.recordIdsFor(type), {a, b}, reason: type);
      await serializer.deleteRecord(type, a);
      expect(await serializer.fetchRecord(type, a), isNull, reason: type);
      await serializer.deleteAllRecords(type);
      expect(await serializer.recordIdsFor(type), isEmpty, reason: type);
    }
  });
}
