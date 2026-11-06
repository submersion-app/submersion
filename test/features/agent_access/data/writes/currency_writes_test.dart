import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' hide Dive;
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/certifications/presentation/currency_rule_display.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/test_database.dart';
import '../records/record_harness.dart';
import 'child_write_harness.dart';

/// Currency rules, a card's interval overrides and its refresher ledger, as
/// the currency section of a certification keeps them.
void main() {
  late AppDatabase db;
  late ChildWriteHarness h;
  late String card;

  Future<String> make(String entity, Map<String, Object?> values) async =>
      (await h.run([createOp(entity, values)])).created.single.id;

  setUp(() async {
    db = await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    h = ChildWriteHarness(db);
    await h.seed();
    card = await make('certifications', {'level': 'openWater'});
  });
  tearDown(() => tearDownTestDatabase());

  test('a custom rule is created, edited and deleted', () async {
    final id = await make('currency_rules', {
      'name': ' Club rule ',
      'lapse_days': 400,
      'lead_days': 30,
      'agencies': ['padi'],
    });
    final rule = (await h.one('currency_rules', id))!;
    expect(
      [rule['name'], rule['clock_kind'], rule['diver_id']],
      ['Club rule', 'activity', kDiverA],
    );

    await h.run([
      updateOp('currency_rules', id, {'lead_days': 60}),
    ]);
    expect((await h.one('currency_rules', id))!['lead_days'], 60);

    await h.run([deleteOp('currency_rules', id)]);
    expect(await h.one('currency_rules', id), isNull);
  });

  test('editing a built-in rule adds its custom copy', () async {
    final plan = await h.preview([
      updateOp('currency_rules', 'padi_reactivate', {'lapse_days': 500}),
    ]);
    expect(plan.items.single.alsoCreates, {'certification_currency_rules': 1});
    final drop = await h.preview([
      deleteOp('currency_rules', 'padi_reactivate'),
    ]);
    expect(drop.items.single.block!.reason, BlockReason.notPermitted);

    await h.apply(
      await h.preview([
        updateOp('currency_rules', 'padi_reactivate', {'lapse_days': 500}),
      ]),
    );
    final rows = await (db.select(
      db.certificationCurrencyRules,
    )..where((r) => r.supersedesRuleId.equals('padi_reactivate'))).get();
    expect(
      [for (final r in rows) (r.lapseDays, r.diverId, r.isBuiltIn)],
      [(500, kDiverA, false)],
    );
    final builtIn = await (db.select(
      db.certificationCurrencyRules,
    )..where((r) => r.id.equals('padi_reactivate'))).getSingle();
    expect(builtIn.lapseDays, 365);
  });

  // The rule dialog seeds a copy with the built-in's translated name and
  // advisory, so the copy reads as the rule it replaces.
  test('a built-in rule\'s copy keeps its name and advisory', () async {
    final l10n = lookupAppLocalizations(const Locale('en'));

    await h.run([
      updateOp('currency_rules', 'padi_reactivate', {'lapse_days': 500}),
    ]);

    final copy = await (db.select(
      db.certificationCurrencyRules,
    )..where((r) => r.supersedesRuleId.equals('padi_reactivate'))).getSingle();
    expect(copy.name, builtInCurrencyRuleName(l10n, 'padi_reactivate'));
    expect(
      copy.advisoryText,
      builtInCurrencyRuleAdvisory(l10n, 'padi_reactivate'),
    );
  });

  test('a lead above the lapse is refused', () async {
    final plan = await h.preview([
      createOp('currency_rules', {
        'name': 'Short',
        'lapse_days': 10,
        'lead_days': 20,
      }),
      createOp('currency_rules', {
        'name': 'Dated',
        'clock_kind': 'date',
        'lapse_days': 10,
        'lead_days': 5,
        'counted_dive_modes': ['ccr'],
      }),
      createOp('currency_prefs', {
        'certification_id': card,
        'rule_id': 'padi_reactivate',
        'lapse_days_override': 100,
      }),
      createOp('currency_prefs', {
        'certification_id': card,
        'rule_id': 'card_expiry',
        'lapse_days_override': 100,
      }),
    ]);

    for (final item in plan.items) {
      expect(item.block!.reason, BlockReason.invalidValue);
    }
  });

  test('a pref is written once per card and rule, and reset', () async {
    final id = await make('currency_prefs', {
      'certification_id': card,
      'rule_id': 'padi_reactivate',
      'lapse_days_override': 400,
      'lead_days_override': 30,
    });
    final again = await h.preview([
      createOp('currency_prefs', {
        'certification_id': card,
        'rule_id': 'padi_reactivate',
      }),
    ]);
    expect(again.items.single.block!.reason, BlockReason.duplicateRecord);

    await h.run([
      updateOp('currency_prefs', id, {
        'lapse_days_override': null,
        'lead_days_override': null,
      }),
    ]);
    final pref = (await h.one('currency_prefs', id))!;
    expect(
      [pref['lapse_days_override'], pref['lead_days_override']],
      [null, null],
    );
  });

  test('an event in the future is refused', () async {
    final next = DateTime.now().add(const Duration(days: 2));
    final day =
        '${next.year}-${'${next.month}'.padLeft(2, '0')}-'
        '${'${next.day}'.padLeft(2, '0')}';
    final plan = await h.preview([
      createOp('currency_events', {
        'certification_id': card,
        'event_date': day,
      }),
    ]);
    expect(plan.items.single.block!.reason, BlockReason.invalidValue);

    final id = await make('currency_events', {
      'certification_id': card,
      'rule_id': 'padi_reactivate',
      'event_date': '2024-02-01',
      'provider': ' Reef Club ',
    });
    final event = (await h.one('currency_events', id))!;
    expect(
      [event['event_type'], event['provider']],
      ['refresher', 'Reef Club'],
    );
    final edit = await h.preview([
      updateOp('currency_events', id, {'notes': 'x'}),
    ]);
    expect(edit.items.single.block!.reason, BlockReason.notPermitted);
  });
}
