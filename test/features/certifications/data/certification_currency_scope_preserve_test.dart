import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/certifications/data/repositories/certification_currency_repository.dart';
import 'package:submersion/features/certifications/domain/entities/currency_pref.dart';
import 'package:submersion/features/certifications/domain/entities/currency_rule.dart';

import '../../../helpers/test_database.dart';

/// Issue #4942: a rule or card setting whose stored scope this build cannot
/// read decodes to an empty list, and an empty list means "any". A save that
/// leaves the scope alone must write back exactly what was stored, or a name
/// or mute edit widens the rule to every dive and syncs that everywhere.
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

  Future<void> insertRule({
    String clockKind = 'activity',
    String agencies = '[]',
    String levels = '[]',
    String types = '[]',
    String modes = '[]',
  }) async {
    final t = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.certificationCurrencyRules)
        .insert(
          CertificationCurrencyRulesCompanion.insert(
            id: 'r1',
            diverId: const Value(diverId),
            name: 'Club rule',
            clockKind: clockKind,
            applicableAgencies: Value(agencies),
            applicableLevels: Value(levels),
            countedDiveTypeIds: Value(types),
            countedDiveModes: Value(modes),
            lapseDays: 365,
            leadDays: 90,
            createdAt: t,
            updatedAt: t,
          ),
        );
  }

  Future<CurrencyRuleRow> storedRule() => (db.select(
    db.certificationCurrencyRules,
  )..where((r) => r.id.equals('r1'))).getSingle();

  Future<CurrencyPrefRow> storedPref() => (db.select(
    db.certificationCurrencyPrefs,
  )..where((p) => p.id.equals('p1'))).getSingle();

  group('updateRule', () {
    test('a name edit keeps every unreadable scope column as stored', () async {
      await insertRule(
        agencies: '["agencyFromTheFuture"]',
        levels: '["levelFromTheFuture"]',
        types: 'not json',
        modes: '["modeFromTheFuture"]',
      );
      final rule = (await repository.getRules()).firstWhere(
        (r) => r.id == 'r1',
      );
      expect(rule.unreadableScope, isTrue);

      await repository.updateRule(rule.copyWith(name: 'Renamed'));

      final row = await storedRule();
      expect(row.name, 'Renamed');
      expect(row.applicableAgencies, '["agencyFromTheFuture"]');
      expect(row.applicableLevels, '["levelFromTheFuture"]');
      expect(row.countedDiveTypeIds, 'not json');
      expect(row.countedDiveModes, '["modeFromTheFuture"]');
      final reread = (await repository.getRules()).firstWhere(
        (r) => r.id == 'r1',
      );
      expect(reread.unreadableScope, isTrue);
    });

    test('an unchanged scope keeps the values this build drops', () async {
      // Readable, because it names one known level, but a plain rewrite
      // would still lose the level a newer build wrote.
      await insertRule(levels: '["cave","levelFromTheFuture"]');
      final rule = (await repository.getRules()).firstWhere(
        (r) => r.id == 'r1',
      );
      expect(rule.levels, [CertificationLevel.cave]);

      await repository.updateRule(rule.copyWith(lapseDays: 400));

      final row = await storedRule();
      expect(row.lapseDays, 400);
      expect(row.applicableLevels, '["cave","levelFromTheFuture"]');
    });

    test('dating a rule writes its unused mapping as given', () async {
      // A date clock never reads the mapping, so the empty one the dialog
      // saves cannot widen it, and the rule becomes readable again.
      await insertRule(modes: '["modeFromTheFuture"]');
      final rule = (await repository.getRules()).firstWhere(
        (r) => r.id == 'r1',
      );

      await repository.updateRule(
        rule.copyWith(
          clockKind: CurrencyClockKind.date,
          countedDiveModes: const [],
        ),
      );

      expect((await storedRule()).countedDiveModes, '[]');
      final reread = (await repository.getRules()).firstWhere(
        (r) => r.id == 'r1',
      );
      expect(reread.unreadableScope, isFalse);
    });

    test(
      'moving a date rule to an activity clock writes its mapping',
      () async {
        // The dialog shows the new clock's mapping and saves it, so the rule
        // counts what the diver saw instead of still matching nothing.
        await insertRule(clockKind: 'date', types: 'not json');
        final rule = (await repository.getRules()).firstWhere(
          (r) => r.id == 'r1',
        );
        expect(rule.unreadableScope, isTrue);

        await repository.updateRule(
          rule.copyWith(
            clockKind: CurrencyClockKind.activity,
            countedDiveTypeIds: const ['boat'],
          ),
        );

        final row = await storedRule();
        expect(row.clockKind, 'activity');
        expect(row.countedDiveTypeIds, '["boat"]');
        final reread = (await repository.getRules()).firstWhere(
          (r) => r.id == 'r1',
        );
        expect(reread.unreadableScope, isFalse);
      },
    );

    test('a date rule\'s name edit keeps its stored mapping', () async {
      await insertRule(modes: '["modeFromTheFuture"]');
      await (db.update(
        db.certificationCurrencyRules,
      )..where((r) => r.id.equals('r1'))).write(
        const CertificationCurrencyRulesCompanion(clockKind: Value('date')),
      );
      final rule = (await repository.getRules()).firstWhere(
        (r) => r.id == 'r1',
      );

      await repository.updateRule(rule.copyWith(name: 'Renamed'));

      final row = await storedRule();
      expect(row.name, 'Renamed');
      expect(row.countedDiveModes, '["modeFromTheFuture"]');
    });

    test('editing one half of a rule\'s mapping writes both', () async {
      // Types and modes are one answer to "which dives count". The dialog
      // showed no modes, so adding a type writes what it showed, and the
      // rule counts boat dives instead of still matching nothing.
      await insertRule(modes: '["modeFromTheFuture"]');
      final rule = (await repository.getRules()).firstWhere(
        (r) => r.id == 'r1',
      );

      await repository.updateRule(
        rule.copyWith(countedDiveTypeIds: const ['boat']),
      );

      final row = await storedRule();
      expect(row.countedDiveTypeIds, '["boat"]');
      expect(row.countedDiveModes, '[]');
      final reread = (await repository.getRules()).firstWhere(
        (r) => r.id == 'r1',
      );
      expect(reread.unreadableScope, isFalse);
    });

    test('a clock kind this build does not know survives a rename', () async {
      await insertRule(clockKind: 'clockFromTheFuture');
      final rule = (await repository.getRules()).firstWhere(
        (r) => r.id == 'r1',
      );
      expect(rule.clockKind, CurrencyClockKind.activity);

      await repository.updateRule(rule.copyWith(name: 'Renamed'));

      expect((await storedRule()).clockKind, 'clockFromTheFuture');
    });

    test('a scope the edit changes is written', () async {
      await insertRule(agencies: '["agencyFromTheFuture"]', modes: '["oc"]');
      final rule = (await repository.getRules()).firstWhere(
        (r) => r.id == 'r1',
      );

      await repository.updateRule(
        rule.copyWith(
          agencies: const [CertificationAgency.padi],
          countedDiveModes: const [DiveMode.ccr],
        ),
      );

      final row = await storedRule();
      expect(row.applicableAgencies, '["padi"]');
      expect(row.countedDiveModes, '["ccr"]');
      final reread = (await repository.getRules()).firstWhere(
        (r) => r.id == 'r1',
      );
      expect(reread.unreadableScope, isFalse);
    });
  });

  group('upsertPref', () {
    Future<void> insertPref({String? types, String? modes}) async {
      final t = DateTime.now().millisecondsSinceEpoch;
      await db
          .into(db.certificationCurrencyPrefs)
          .insert(
            CertificationCurrencyPrefsCompanion.insert(
              id: 'p1',
              certificationId: certId,
              ruleId: 'padi_reactivate',
              countedDiveTypeIds: Value(types),
              countedDiveModes: Value(modes),
              createdAt: t,
              updatedAt: t,
            ),
          );
    }

    test('a mapping this build cannot read is flagged', () async {
      await insertPref(types: 'not json');
      expect(
        (await repository.getPrefs(certId)).single.unreadableMapping,
        isTrue,
      );
      await db.delete(db.certificationCurrencyPrefs).go();

      await insertPref(modes: '["modeFromTheFuture"]');
      expect(
        (await repository.getPrefs(certId)).single.unreadableMapping,
        isTrue,
      );
      await db.delete(db.certificationCurrencyPrefs).go();

      // Inherit (NULL) and "any" ([]) are both readable answers.
      await insertPref(types: '[]');
      expect(
        (await repository.getPrefs(certId)).single.unreadableMapping,
        isFalse,
      );
    });

    test('a mute toggle keeps an unreadable mapping as stored', () async {
      await insertPref(types: 'not json', modes: '["modeFromTheFuture"]');
      final pref = (await repository.getPrefs(certId)).single;

      await repository.upsertPref(pref.copyWith(muted: true));

      final row = await storedPref();
      expect(row.muted, isTrue);
      expect(row.countedDiveTypeIds, 'not json');
      expect(row.countedDiveModes, '["modeFromTheFuture"]');
    });

    test('the pref returned is the mapping as written', () async {
      await insertPref(modes: '["modeFromTheFuture"]');
      final pref = (await repository.getPrefs(certId)).single;

      final written = await repository.upsertPref(pref.copyWith(muted: true));

      expect(written.unreadableMapping, isTrue);
      expect(written.mappingJson.modes, '["modeFromTheFuture"]');
    });

    test('a mapping the diver set is written even when it decodes the same, '
        'over one this build cannot read', () async {
      await insertPref(types: '["boat"]', modes: '["modeFromTheFuture"]');
      // Read back, so it carries the stored mapping a save would keep.
      final edited = (await repository.getPrefs(
        certId,
      )).single.copyWith(countedDiveModes: const []);

      await repository.upsertPref(edited);
      expect((await storedPref()).countedDiveModes, '["modeFromTheFuture"]');

      await repository.upsertPref(edited, mappingEdited: true);
      final row = await storedPref();
      expect(row.countedDiveTypeIds, '["boat"]');
      expect(row.countedDiveModes, '[]');
    });

    test('a mapping the edit changes is written', () async {
      await insertPref(types: 'not json', modes: '["modeFromTheFuture"]');
      final pref = (await repository.getPrefs(certId)).single;

      await repository.upsertPref(
        pref.copyWith(
          countedDiveTypeIds: const ['boat'],
          countedDiveModes: const [DiveMode.oc],
        ),
      );

      final row = await storedPref();
      expect(row.countedDiveTypeIds, '["boat"]');
      expect(row.countedDiveModes, '["oc"]');
    });

    test('changing one half of a mapping writes the whole mapping', () async {
      // Types and modes are one answer to "which dives count". A diver who
      // re-picks it in the mapping dialog sees the rule's mapping in place of
      // the unreadable one, so the save writes what they saw; keeping the
      // unreadable modes would leave the card ignoring their edit.
      await insertPref(types: '[]', modes: '["modeFromTheFuture"]');
      final pref = (await repository.getPrefs(certId)).single;

      await repository.upsertPref(
        pref.copyWith(countedDiveTypeIds: const ['boat']),
      );

      final row = await storedPref();
      expect(row.countedDiveTypeIds, '["boat"]');
      expect(row.countedDiveModes, '[]');
      expect(
        (await repository.getPrefs(certId)).single.unreadableMapping,
        isFalse,
      );
    });

    test('inherit and "any" stay distinct across a save', () async {
      // NULL inherits the rule; an empty list is the diver's "any dive".
      // Neither may be read as the other when deciding what is unchanged.
      await insertPref(modes: 'not json');
      final pref = (await repository.getPrefs(certId)).single;

      await repository.upsertPref(
        CurrencyPref(
          id: pref.id,
          certificationId: pref.certificationId,
          ruleId: pref.ruleId,
          countedDiveTypeIds: const [],
          createdAt: pref.createdAt,
          updatedAt: pref.updatedAt,
        ),
      );

      final row = await storedPref();
      expect(row.countedDiveTypeIds, '[]');
      expect(row.countedDiveModes, isNull);
    });
  });
}
