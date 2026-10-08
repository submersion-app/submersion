import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/certifications/data/repositories/certification_currency_repository.dart';
import 'package:submersion/features/certifications/data/repositories/certification_repository.dart';
import 'package:submersion/features/certifications/domain/entities/currency_event.dart';
import 'package:submersion/features/certifications/domain/entities/currency_pref.dart';
import 'package:submersion/features/certifications/domain/entities/currency_rule.dart';

import '../../../helpers/test_database.dart';

/// The certification currency repository (issue #2267): the seeded catalog,
/// custom rules, per card prefs, the event ledger, and the sync bookkeeping
/// every write must leave behind.
void main() {
  late AppDatabase db;
  late CertificationCurrencyRepository repository;
  const diverId = 'd1';
  const certId = 'c1';

  setUp(() async {
    db = await setUpTestDatabase();
    repository = CertificationCurrencyRepository();
    final t = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.divers)
        .insert(
          DiversCompanion.insert(
            id: diverId,
            name: 'Diver',
            createdAt: t,
            updatedAt: t,
          ),
        );
    await db
        .into(db.certifications)
        .insert(
          CertificationsCompanion.insert(
            id: certId,
            name: 'Open Water',
            agency: 'padi',
            diverId: const Value(diverId),
            createdAt: t,
            updatedAt: t,
          ),
        );
  });

  tearDown(tearDownTestDatabase);

  Future<List<String>> pendingIds(String entityType) async {
    final rows = await db.select(db.syncRecords).get();
    return [
      for (final r in rows)
        if (r.entityType == entityType) r.recordId,
    ];
  }

  Future<List<String>> tombstones(String entityType) async {
    final rows = await db.select(db.deletionLog).get();
    return [
      for (final r in rows)
        if (r.entityType == entityType) r.recordId,
    ];
  }

  CurrencyRule customRule({String id = 'custom-1'}) => CurrencyRule(
    id: id,
    diverId: diverId,
    name: 'Club refresher',
    clockKind: CurrencyClockKind.activity,
    agencies: const [CertificationAgency.bsac],
    levels: const [CertificationLevel.openWater],
    lapseDays: 200,
    leadDays: 30,
    countedDiveTypeIds: const ['boat'],
    countedDiveModes: const [DiveMode.oc],
    advisoryText: 'My club asks for one every spring',
    supersedesRuleId: 'generic_refresher',
    createdAt: DateTime(2026, 9, 22),
    updatedAt: DateTime(2026, 9, 22),
  );

  CurrencyPref inheritingPref() => CurrencyPref(
    id: 'p1',
    certificationId: certId,
    ruleId: 'padi_reactivate',
    createdAt: DateTime(2026, 9, 22),
    updatedAt: DateTime(2026, 9, 22),
  );

  CurrencyEvent refresher({String id = 'e1', DateTime? date}) => CurrencyEvent(
    id: id,
    certificationId: certId,
    ruleId: 'padi_reactivate',
    eventType: CurrencyEventType.refresher,
    eventDate: date ?? DateTime(2026, 3, 4),
    provider: 'Blue Hole Divers',
    createdAt: DateTime(2026, 3, 4),
    updatedAt: DateTime(2026, 3, 4),
  );

  group('rules', () {
    test('getRules returns the ten seeded built-ins', () async {
      final rules = await repository.getRules();
      expect(rules.where((r) => r.isBuiltIn).length, 10);
      final cave = rules.firstWhere((r) => r.id == 'cave_currency');
      expect(cave.clockKind, CurrencyClockKind.activity);
      expect(cave.countedDiveTypeIds, ['cave', 'cavern']);
      expect(cave.levels, contains(CertificationLevel.gueCave1));
      expect(cave.advisoryKey, 'currencyRule_cave_currency_advisory');
      final rebreather = rules.firstWhere((r) => r.id == 'rebreather_currency');
      expect(rebreather.countedDiveModes, [DiveMode.ccr, DiveMode.scr]);
    });

    test('a custom rule round trips with its scope arrays', () async {
      final created = await repository.createRule(customRule());
      final read = (await repository.getRules()).firstWhere(
        (r) => r.id == created.id,
      );
      expect(read.agencies, [CertificationAgency.bsac]);
      expect(read.levels, [CertificationLevel.openWater]);
      expect(read.countedDiveTypeIds, ['boat']);
      expect(read.countedDiveModes, [DiveMode.oc]);
      expect(read.advisoryText, 'My club asks for one every spring');
      expect(read.supersedesRuleId, 'generic_refresher');
      expect(read.isBuiltIn, isFalse);
      expect(await pendingIds('certificationCurrencyRules'), [created.id]);
    });

    test('a stored scope this build cannot read maps to unreadable', () async {
      final t = DateTime.now().millisecondsSinceEpoch;
      for (final (id, levels) in [
        ('future', '["levelFromTheFuture"]'),
        ('corrupt', 'not json'),
        ('known', '["cave","levelFromTheFuture"]'),
      ]) {
        await db
            .into(db.certificationCurrencyRules)
            .insert(
              CertificationCurrencyRulesCompanion.insert(
                id: id,
                name: id,
                clockKind: 'activity',
                applicableLevels: Value(levels),
                lapseDays: 365,
                leadDays: 90,
                createdAt: t,
                updatedAt: t,
              ),
            );
      }
      final byId = {for (final r in await repository.getRules()) r.id: r};
      expect(byId['future']!.unreadableScope, isTrue);
      expect(byId['corrupt']!.unreadableScope, isTrue);
      expect(byId['known']!.unreadableScope, isFalse);
      expect(byId['cave_currency']!.unreadableScope, isFalse);
    });

    test('createRule never writes a built-in row, even when asked', () async {
      final created = await repository.createRule(
        customRule(id: 'sneaky').copyWith(isBuiltIn: true),
      );
      final read = (await repository.getRules()).firstWhere(
        (r) => r.id == created.id,
      );
      expect(read.isBuiltIn, isFalse);
    });

    test('createRule with an empty id assigns one', () async {
      final created = await repository.createRule(customRule(id: ''));
      expect(created.id, isNotEmpty);
    });

    test('updateRule rewrites a custom rule and marks it pending', () async {
      await repository.createRule(customRule());
      await db.delete(db.syncRecords).go();
      await repository.updateRule(
        customRule().copyWith(lapseDays: 400, name: 'Spring refresher'),
      );
      final read = (await repository.getRules()).firstWhere(
        (r) => r.id == 'custom-1',
      );
      expect(read.lapseDays, 400);
      expect(read.name, 'Spring refresher');
      expect(await pendingIds('certificationCurrencyRules'), ['custom-1']);
    });

    test('built-ins can be neither updated nor deleted', () async {
      final cave = (await repository.getRules()).firstWhere(
        (r) => r.id == 'cave_currency',
      );
      expect(
        () => repository.updateRule(cave.copyWith(lapseDays: 1)),
        throwsStateError,
      );
      expect(() => repository.deleteRule('cave_currency'), throwsStateError);
      final again = (await repository.getRules()).firstWhere(
        (r) => r.id == 'cave_currency',
      );
      expect(again.lapseDays, 365);
    });

    test(
      'deleting a custom rule tombstones it and keeps prefs and events',
      () async {
        await repository.createRule(customRule());
        await repository.upsertPref(
          inheritingPref().copyWith(ruleId: 'custom-1'),
        );
        await repository.createEvent(refresher().copyWith(ruleId: 'custom-1'));

        await repository.deleteRule('custom-1');

        expect(
          (await repository.getRules()).where((r) => r.id == 'custom-1'),
          isEmpty,
        );
        expect(await tombstones('certificationCurrencyRules'), ['custom-1']);
        expect(await repository.getPrefs(certId), isNotEmpty);
        expect(await repository.getEvents(certId), isNotEmpty);
      },
    );
  });

  group('prefs', () {
    test('a null mapping is distinct from an empty one', () async {
      // Null inherits the rule's mapping; an empty list is the diver saying
      // "any dive counts". Collapsing the two would silently change a rule.
      await repository.upsertPref(inheritingPref());
      final first = (await repository.getPrefs(certId)).single;
      expect(first.countedDiveTypeIds, isNull);
      expect(first.countedDiveModes, isNull);

      await repository.upsertPref(
        inheritingPref().copyWith(
          countedDiveTypeIds: const [],
          countedDiveModes: const [],
        ),
      );
      final second = (await repository.getPrefs(certId)).single;
      expect(second.countedDiveTypeIds, isEmpty);
      expect(second.countedDiveModes, isEmpty);
    });

    test(
      'upsertPref writes the full value, so it can return to inherit',
      () async {
        await repository.upsertPref(
          inheritingPref().copyWith(lapseDaysOverride: 90, muted: true),
        );
        await repository.upsertPref(inheritingPref());
        final read = (await repository.getPrefs(certId)).single;
        expect(read.lapseDaysOverride, isNull);
        expect(read.muted, isFalse);
      },
    );

    test(
      'getAllPrefs spans certifications and every write is pending',
      () async {
        await repository.upsertPref(inheritingPref());
        expect((await repository.getAllPrefs()).map((p) => p.id), ['p1']);
        expect(await pendingIds('certificationCurrencyPrefs'), ['p1']);
      },
    );

    test('deletePref removes and tombstones the row', () async {
      await repository.upsertPref(inheritingPref());
      await repository.deletePref('p1');
      expect(await repository.getPrefs(certId), isEmpty);
      expect(await tombstones('certificationCurrencyPrefs'), ['p1']);
    });
  });

  group('events', () {
    test('events read back newest first and every write is pending', () async {
      await repository.createEvent(refresher(id: 'old', date: DateTime(2025)));
      await repository.createEvent(refresher(id: 'new', date: DateTime(2026)));
      expect((await repository.getEvents(certId)).map((e) => e.id), [
        'new',
        'old',
      ]);
      expect((await repository.getAllEvents()).map((e) => e.id).toSet(), {
        'new',
        'old',
      });
      expect((await pendingIds('certificationCurrencyEvents')).toSet(), {
        'new',
        'old',
      });
      final read = (await repository.getEvents(certId)).last;
      expect(read.eventType, CurrencyEventType.refresher);
      expect(read.provider, 'Blue Hole Divers');
      expect(read.eventDate, DateTime(2025));
    });

    test('deleteEvent removes and tombstones the row', () async {
      await repository.createEvent(refresher());
      await repository.deleteEvent('e1');
      expect(await repository.getEvents(certId), isEmpty);
      expect(await tombstones('certificationCurrencyEvents'), ['e1']);
    });
  });

  test('deleting a certification tombstones its prefs and events', () async {
    // SQLite's cascade writes no deletion-log rows, so without explicit
    // tombstones a peer would push the orphaned children straight back.
    await repository.upsertPref(inheritingPref());
    await repository.createEvent(refresher());

    await CertificationRepository().deleteCertification(certId);

    expect(await repository.getAllPrefs(), isEmpty);
    expect(await repository.getAllEvents(), isEmpty);
    expect(await tombstones('certificationCurrencyPrefs'), ['p1']);
    expect(await tombstones('certificationCurrencyEvents'), ['e1']);
  });
}
