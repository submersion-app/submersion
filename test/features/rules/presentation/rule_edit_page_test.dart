import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/features/dive_log/domain/bulk_edit/bulk_edit_field_set.dart';
import 'package:submersion/features/rules/data/repositories/rule_repository.dart';
import 'package:submersion/features/rules/domain/entities/rule.dart';
import 'package:submersion/features/rules/domain/entities/rule_action.dart';
import 'package:submersion/features/rules/domain/rule_subject.dart';
import 'package:submersion/features/rules/presentation/pages/rule_edit_page.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/shared/widgets/app_bar_text_action.dart';

import '../../../helpers/mock_providers.dart';
import '../../../helpers/test_database.dart';
import '../rules_fixture.dart';
import 'rules_test_app.dart';

void main() {
  late AppDatabase db;
  late RuleRepository repo;

  setUp(() async {
    db = await setUpTestDatabase();
    await seedRuleDivers(db, ['me']);
    repo = RuleRepository();
  });
  tearDown(tearDownTestDatabase);

  Future<List<Rule>> saved([RuleSubject s = RuleSubject.dives]) async =>
      repo.getAll(subject: s, diverId: 'me', names: kRuleTestNames);

  Future<void> pumpEditor(
    WidgetTester tester, {
    String? ruleId,
    MockSettingsNotifier? settings,
  }) async {
    await tester.runAsync(
      () => pumpRulesApp(
        tester,
        path: '/rules/edit',
        home: (_) => RuleEditPage(ruleId: ruleId),
        settings: settings,
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> addAction(WidgetTester tester, String entry) async {
    await tester.ensureVisible(find.byKey(const ValueKey('rule_add_action')));
    await tester.tap(find.byKey(const ValueKey('rule_add_action')));
    await tester.pumpAndSettle();
    // The list is long and built lazily; search the way a diver would.
    await tester.enterText(
      find.byKey(const ValueKey('rule_action_search')),
      entry,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(entry).last);
    await tester.pumpAndSettle();
  }

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('rule_save')));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a new dive rule saves its name and a type action', (
    tester,
  ) async {
    await pumpEditor(tester);
    await tester.enterText(
      find.byKey(const ValueKey('rule_name')),
      'Deep dives',
    );
    await addAction(tester, 'Add dive types');
    await tester.tap(find.text('Deep'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Add dive types: Deep'), findsOneWidget);
    await save(tester);
    final rules = await tester.runAsync(saved);
    expect(rules!.single.name, 'Deep dives');
    expect(rules.single.triggers, {RuleTrigger.afterImport});
    expect(rules.single.actions, const [
      DiveMembershipAction(DiveCollection.diveTypes, MembershipMode.add, [
        'deep',
      ]),
    ]);
  });

  testWidgets('an imperial diver sets swell height in feet', (tester) async {
    await pumpEditor(
      tester,
      settings: MockSettingsNotifier(
        const AppSettings(depthUnit: DepthUnit.feet),
      ),
    );
    await tester.enterText(find.byKey(const ValueKey('rule_name')), 'Swell');
    await addAction(tester, 'Set swell height');
    await tester.enterText(
      find.byKey(const ValueKey('rule_value_number')),
      '3',
    );
    // NumberField reports its value a frame after the edit.
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('rule_action_ok')));
    await tester.pumpAndSettle();
    expect(find.textContaining('3'), findsWidgets);
    expect(find.textContaining('ft'), findsWidgets);
    await save(tester);
    final action =
        (await tester.runAsync(saved))!.single.actions.single
            as SetDiveFieldAction;
    expect(action.field, BulkField.swellHeight);
    expect(action.values['swellHeight'] as double, closeTo(0.9144, 1e-6));
  });

  testWidgets('Save stays disabled with no actions', (tester) async {
    await pumpEditor(tester);
    await tester.enterText(find.byKey(const ValueKey('rule_name')), 'Empty');
    await tester.pump();
    final button = tester.widget<AppBarTextAction>(
      find.byKey(const ValueKey('rule_save')),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('editing keeps the id and the subject', (tester) async {
    late String id;
    await tester.runAsync(() async {
      id = await repo.create(
        diverId: 'me',
        subject: RuleSubject.sites,
        name: 'Red Sea',
        triggers: const {RuleTrigger.afterImport},
        condition: null,
        actions: const [AppendSiteDescriptionAction('Warm')],
      );
    });
    await pumpEditor(tester, ruleId: id);
    expect(find.byKey(const ValueKey('rule_subject_picker')), findsNothing);
    await tester.enterText(
      find.byKey(const ValueKey('rule_name')),
      'Red Sea 2',
    );
    await save(tester);
    final rules = await tester.runAsync(() => saved(RuleSubject.sites));
    expect(rules!.single.id, id);
    expect(rules.single.name, 'Red Sea 2');
    expect(rules.single.subject, RuleSubject.sites);
  });

  testWidgets('the action picker filters by search', (tester) async {
    await pumpEditor(tester);
    await tester.tap(find.byKey(const ValueKey('rule_add_action')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('rule_action_search')),
      'swell',
    );
    await tester.pumpAndSettle();
    expect(find.text('Set swell height'), findsOneWidget);
    expect(find.text('Set water type'), findsNothing);
  });

  testWidgets('a rule from a newer version opens read-only', (tester) async {
    late String id;
    await tester.runAsync(() async {
      id = await repo.create(
        diverId: 'me',
        subject: RuleSubject.dives,
        name: 'Future',
        triggers: const {RuleTrigger.afterImport},
        condition: null,
        actions: const [AppendDiveNotesAction('x')],
      );
      await db.customStatement(
        "UPDATE rules SET actions_json = '{\"version\":9,\"actions\":[]}' "
        "WHERE id = '$id'",
      );
    });
    await pumpEditor(tester, ruleId: id);
    expect(find.textContaining('Made by a newer version'), findsOneWidget);
    expect(find.byKey(const ValueKey('rule_save')), findsNothing);
  });

  testWidgets('the condition shows a live match count', (tester) async {
    await tester.runAsync(() async {
      await seedRuleDive(db, 'd1', maxDepth: 25);
      await seedRuleDive(db, 'd2', maxDepth: 40);
      await repo.create(
        diverId: 'me',
        subject: RuleSubject.dives,
        name: 'Deep',
        triggers: const {RuleTrigger.afterImport},
        condition: depthOver(30) as QueryNode,
        actions: const [AppendDiveNotesAction('deep')],
      );
    });
    final id = (await tester.runAsync(saved))!.single.id;
    await pumpEditor(tester, ruleId: id);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 400)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Matches 1 of your dives'), findsOneWidget);
  });
}
