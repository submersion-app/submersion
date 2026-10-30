import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/query/names/name_index.dart';
import 'package:submersion/features/rules/data/repositories/rule_repository.dart';
import 'package:submersion/features/rules/data/services/rule_engine.dart';
import 'package:submersion/features/rules/data/services/rule_undo_service.dart';
import 'package:submersion/features/rules/domain/entities/rule_action.dart';
import 'package:submersion/features/rules/domain/entities/rule_run.dart';
import 'package:submersion/features/rules/domain/rule_subject.dart';
import 'package:submersion/features/rules/presentation/widgets/import_rules_box.dart';

import '../../../helpers/test_database.dart';
import '../rules_fixture.dart';
import 'rules_test_app.dart';

void main() {
  late AppDatabase db;
  late RuleRunResult run;

  Future<int> diveCount() async =>
      (await db.customSelect('SELECT COUNT(*) AS n FROM dives').getSingle())
          .read<int>('n');

  setUp(() async {
    db = await setUpTestDatabase();
    await seedRuleDivers(db, ['me']);
    await seedRuleDive(db, 'd35', maxDepth: 35);
    await seedRuleDive(db, 'd40', maxDepth: 40);
    await RuleRepository().create(
      diverId: 'me',
      subject: RuleSubject.dives,
      name: 'Deep',
      triggers: const {RuleTrigger.afterImport},
      condition: depthOver(30),
      actions: const [
        DiveMembershipAction(DiveCollection.diveTypes, MembershipMode.add, [
          'deep',
        ]),
      ],
    );
    run = await RuleEngine(names: (_) async => NameIndex(const [])).run(
      const RuleRunRequest(
        diverId: 'me',
        trigger: RuleRunTrigger.imported,
        targets: {
          RuleSubject.dives: {'d35', 'd40'},
        },
      ),
    );
  });
  tearDown(tearDownTestDatabase);

  Future<List<String>> pump(
    WidgetTester tester, {
    List<RuleRunResult>? runs,
    bool failed = false,
    List<String> skippedRules = const [],
    List<String> skippedActions = const [],
  }) async {
    final pushed = await tester.runAsync(
      () => pumpRulesApp(
        tester,
        path: '/summary',
        home: (_) => Scaffold(
          body: ImportRulesBox(
            runs: runs ?? [run],
            failed: failed,
            skippedRules: skippedRules,
            skippedActions: skippedActions,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return pushed!;
  }

  testWidgets('says what the rules changed, per rule', (tester) async {
    await pump(tester);
    expect(find.text('Rules changed 2 of these dives'), findsOneWidget);
    expect(find.text('Deep 2'), findsOneWidget);
  });

  testWidgets('See changes opens the run', (tester) async {
    final pushed = await pump(tester);
    await tester.tap(find.text('See changes'));
    await tester.pumpAndSettle();
    expect(pushed, ['/rules/history/${run.runId}']);
  });

  testWidgets('See changes on a multi-profile import opens the history', (
    tester,
  ) async {
    const other = RuleRunResult(
      runId: 'other-run',
      changes: [],
      changedTargetCount: 1,
      changedCountByRule: {'Shallow': 1},
      skippedRuleNames: [],
      skippedActionRuleNames: [],
      targetCount: 1,
      outOfScopeCount: 0,
    );
    final pushed = await pump(tester, runs: [run, other]);
    await tester.tap(find.text('See changes'));
    await tester.pumpAndSettle();
    // Just this import's runs, each profile's included.
    expect(pushed, ['/rules/history?runs=${run.runId},other-run']);
  });

  testWidgets('Undo reverts the rules and keeps the dives', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Undo rule changes'));
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(await tester.runAsync(() => ruleDiveTypes(db, 'd35')), [
      'recreational',
    ]);
    expect(await tester.runAsync(diveCount), 2);
    expect(find.text('Undo rule changes'), findsNothing);
  });

  testWidgets('Undo goes once the runs were undone elsewhere', (tester) async {
    // Undone from the history meanwhile: there is nothing left for this
    // button to do.
    await tester.runAsync(() => RuleUndoService().undo(run.runId!));
    await pump(tester);
    await tester.tap(find.text('Undo rule changes'));
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.text('Undo rule changes'), findsNothing);
  });

  testWidgets('a failure is reported', (tester) async {
    await pump(tester, runs: const [], failed: true);
    expect(
      find.text('Dives imported, but your rules could not run.'),
      findsOneWidget,
    );
  });

  testWidgets('a skipped action is reported though nothing changed', (
    tester,
  ) async {
    await pump(tester, runs: const [], skippedActions: const ['Gone tag']);
    expect(
      find.text('Some actions name deleted items and were skipped: Gone tag'),
      findsOneWidget,
    );
  });

  testWidgets('skipped rules are reported beside the changes', (tester) async {
    await pump(tester, skippedRules: const ['Broken']);
    expect(find.text('Rules changed 2 of these dives'), findsOneWidget);
    expect(
      find.text("These rules can't run and were skipped: Broken"),
      findsOneWidget,
    );
  });

  testWidgets('nothing to show without runs or a failure', (tester) async {
    await pump(tester, runs: const []);
    expect(find.byType(Card), findsNothing);
  });
}
