import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/rules/data/repositories/rule_repository.dart';
import 'package:submersion/features/rules/domain/entities/rule_action.dart';
import 'package:submersion/features/rules/domain/rule_subject.dart';
import 'package:submersion/features/rules/presentation/run_rules_flow.dart';

import '../../../helpers/test_database.dart';
import '../rules_fixture.dart';
import 'rules_test_app.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    await seedRuleDivers(db, ['me']);
    await seedRuleDive(db, 'd20', maxDepth: 20, number: 410);
    await seedRuleDive(db, 'd35', maxDepth: 35, number: 411);
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
  });
  tearDown(tearDownTestDatabase);

  Future<void> pumpHost(WidgetTester tester, {Set<String>? targets}) async {
    await tester.runAsync(
      () => pumpRulesApp(
        tester,
        path: '/host',
        home: (_) => Scaffold(
          body: Consumer(
            builder: (context, ref, _) => Center(
              child: ElevatedButton(
                onPressed: () => runRulesOnDemand(
                  context,
                  ref,
                  subject: RuleSubject.dives,
                  targetIds: targets,
                ),
                child: const Text('go'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openPreview(WidgetTester tester) async {
    await tester.tap(find.text('go'));
    await settleRuleWork(tester);
  }

  testWidgets('with every dive rule off, a run says so', (tester) async {
    await tester.runAsync(() async {
      final repo = RuleRepository();
      for (final r in await repo.getAll(
        subject: RuleSubject.dives,
        diverId: 'me',
        names: kRuleTestNames,
      )) {
        await repo.setEnabled(r.id, false);
      }
    });
    await pumpHost(tester);
    await openPreview(tester);
    expect(
      find.text(
        'No dive rules are on. Turn one on, or run it from its own menu.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('a selection of items not yours says so, not "no changes"', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await seedRuleDivers(db, ['other']);
      await seedRuleDive(db, 'theirs', diver: 'other', maxDepth: 40);
    });
    await pumpHost(tester, targets: {'theirs'});
    await openPreview(tester);
    expect(
      find.text('1 selected item is not yours to change and was left out.'),
      findsOneWidget,
    );
    expect(find.textContaining('already match'), findsNothing);
  });

  testWidgets('a skipped action is reported, not passed off as no changes', (
    tester,
  ) async {
    await tester.runAsync(
      () => RuleRepository().create(
        diverId: 'me',
        subject: RuleSubject.dives,
        name: 'Gone tag',
        triggers: const {RuleTrigger.afterImport},
        condition: null,
        actions: const [
          DiveMembershipAction(DiveCollection.tags, MembershipMode.add, [
            'deleted',
          ]),
        ],
      ),
    );
    await pumpHost(tester, targets: {'d20'});
    await openPreview(tester);
    expect(
      find.text('Some actions name deleted items and were skipped: Gone tag'),
      findsOneWidget,
    );
  });

  testWidgets('the preview shows each change and the count', (tester) async {
    await pumpHost(tester);
    await openPreview(tester);
    expect(find.text('Apply rules to 2 dives?'), findsOneWidget);
    expect(find.text('1 dive will change.'), findsOneWidget);
    expect(find.textContaining('#411'), findsOneWidget);
    expect(
      find.text('Deep: dive types Recreational → Recreational, Deep'),
      findsOneWidget,
    );
  });

  testWidgets('Cancel changes nothing', (tester) async {
    await pumpHost(tester);
    await openPreview(tester);
    await tester.tap(find.text('Cancel'));
    await settleRuleWork(tester);
    expect(await tester.runAsync(() => ruleDiveTypes(db, 'd35')), isEmpty);
  });

  testWidgets('Apply writes and Undo reverts', (tester) async {
    await pumpHost(tester);
    await openPreview(tester);
    await tester.tap(find.text('Apply to 1 dive'));
    await settleRuleWork(tester);
    expect(await tester.runAsync(() => ruleDiveTypes(db, 'd35')), [
      'deep',
      'recreational',
    ]);
    expect(find.text('Rules changed 1 dive'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await settleRuleWork(tester);
    expect(await tester.runAsync(() => ruleDiveTypes(db, 'd35')), [
      'recreational',
    ]);
  });

  testWidgets('Undo still works after the page that ran the rules is gone', (
    tester,
  ) async {
    final show = ValueNotifier(true);
    addTearDown(show.dispose);
    await tester.runAsync(
      () => pumpRulesApp(
        tester,
        path: '/host',
        home: (_) => Scaffold(
          body: ValueListenableBuilder<bool>(
            valueListenable: show,
            builder: (context, visible, _) => !visible
                ? const SizedBox.shrink()
                : Consumer(
                    builder: (context, ref, _) => Center(
                      child: ElevatedButton(
                        onPressed: () => runRulesOnDemand(
                          context,
                          ref,
                          subject: RuleSubject.dives,
                        ),
                        child: const Text('go'),
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await openPreview(tester);
    await tester.tap(find.text('Apply to 1 dive'));
    await settleRuleWork(tester);
    expect(find.text('Rules changed 1 dive'), findsOneWidget);
    // The widget whose ref started the run is disposed before Undo.
    show.value = false;
    await tester.pump();
    await tester.tap(find.text('Undo'));
    await settleRuleWork(tester);
    expect(await tester.runAsync(() => ruleDiveTypes(db, 'd35')), [
      'recreational',
    ]);
  });

  testWidgets('Apply recomputes when data moved after the preview', (
    tester,
  ) async {
    await pumpHost(tester);
    await openPreview(tester);
    await tester.runAsync(() => seedRuleDive(db, 'd50', maxDepth: 50));
    await tester.tap(find.text('Apply to 1 dive'));
    await settleRuleWork(tester);
    expect(find.text('Rules changed 2 dives'), findsOneWidget);
  });

  testWidgets('grouping by rule regroups lines', (tester) async {
    await pumpHost(tester);
    await openPreview(tester);
    await tester.tap(find.text('By rule'));
    await tester.pumpAndSettle();
    expect(find.textContaining('#411'), findsOneWidget);
    expect(find.textContaining(': dive types'), findsOneWidget);
  });

  testWidgets('a selection with nothing to change says so', (tester) async {
    await pumpHost(tester, targets: {'d20'});
    await openPreview(tester);
    expect(
      find.text('No changes: these dives already match your rules.'),
      findsOneWidget,
    );
  });

  testWidgets('Apply says so when the recomputed run changes nothing', (
    tester,
  ) async {
    await pumpHost(tester);
    await openPreview(tester);
    // Between the preview and Apply the dive already gained the type.
    await tester.runAsync(
      () => db.customStatement(
        "INSERT INTO dive_dive_types (id, dive_id, dive_type_id, created_at) "
        "VALUES ('m1', 'd35', 'deep', 0), ('m2', 'd35', 'recreational', 0)",
      ),
    );
    await tester.tap(find.text('Apply to 1 dive'));
    await settleRuleWork(tester);
    expect(
      find.text('No changes: these dives already match your rules.'),
      findsOneWidget,
    );
  });
}
