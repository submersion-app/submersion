import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/features/rules/data/repositories/rule_repository.dart';
import 'package:submersion/features/rules/domain/entities/rule_action.dart';
import 'package:submersion/features/rules/domain/rule_subject.dart';
import 'package:submersion/features/rules/presentation/pages/rules_page.dart';

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

  Future<String> make(
    String name, {
    RuleSubject subject = RuleSubject.dives,
    List<RuleAction> actions = const [
      DiveMembershipAction(DiveCollection.diveTypes, MembershipMode.add, [
        'deep',
      ]),
    ],
    QueryNode? condition,
  }) => repo.create(
    diverId: 'me',
    subject: subject,
    name: name,
    triggers: const {RuleTrigger.afterImport},
    condition: condition,
    actions: actions,
  );

  testWidgets('empty state offers New rule', (tester) async {
    await tester.runAsync(() async {
      await pumpRulesApp(tester, home: (_) => const RulesPage());
    });
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Nothing runs until you create a rule'),
      findsOneWidget,
    );
    expect(find.widgetWithText(FilledButton, 'New rule'), findsOneWidget);
  });

  testWidgets('lists dive and site rules in their sections', (tester) async {
    await tester.runAsync(() async {
      await make('Deep', condition: depthOver(18));
      await make('Boat');
      await make(
        'Red Sea',
        subject: RuleSubject.sites,
        actions: const [AppendSiteDescriptionAction('Warm')],
      );
      await pumpRulesApp(tester, home: (_) => const RulesPage());
    });
    await tester.pumpAndSettle();
    expect(find.text('Dive rules'), findsOneWidget);
    expect(find.text('Site rules'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Deep')).dy,
      lessThan(tester.getTopLeft(find.text('Boat')).dy),
    );
    expect(
      tester.getTopLeft(find.text('Boat')).dy,
      lessThan(tester.getTopLeft(find.text('Red Sea')).dy),
    );
    expect(find.text('Add dive types: Deep'), findsNWidgets(2));
    expect(find.text('Append to description: Warm'), findsOneWidget);
    expect(find.text('Every dive'), findsOneWidget);
    expect(find.textContaining('After import'), findsWidgets);
  });

  testWidgets('the switch turns a rule off', (tester) async {
    late String id;
    await tester.runAsync(() async {
      id = await make('Deep');
      await pumpRulesApp(tester, home: (_) => const RulesPage());
    });
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    final rule = await tester.runAsync(
      () => repo.getById(id, names: kRuleTestNames),
    );
    expect(rule!.enabled, isFalse);
  });

  testWidgets('a broken action and a problem rule are flagged', (tester) async {
    await tester.runAsync(() async {
      await make(
        'Gone tag',
        actions: const [
          DiveMembershipAction(DiveCollection.tags, MembershipMode.add, [
            'nope',
          ]),
        ],
      );
      final id = await make('Future');
      await db.customStatement(
        "UPDATE rules SET actions_json = '{\"version\":9,\"actions\":[]}' "
        "WHERE id = '$id'",
      );
      await pumpRulesApp(tester, home: (_) => const RulesPage());
    });
    await tester.pumpAndSettle();
    expect(find.textContaining('that action is skipped'), findsOneWidget);
    expect(find.textContaining('Made by a newer version'), findsOneWidget);
  });

  testWidgets('Run on all from a row opens the preview', (tester) async {
    await tester.runAsync(() async {
      await seedRuleDive(db, 'd40', maxDepth: 40);
      await make('Deep', condition: depthOver(30));
      await pumpRulesApp(tester, home: (_) => const RulesPage());
    });
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Rule actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Run on all dives'));
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.text('1 dive will change.'), findsOneWidget);
  });
}
