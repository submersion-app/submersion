import 'package:drift/drift.dart' show Variable;
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

  Future<List<String>> typesOf(String id) async => [
    for (final r
        in await db
            .customSelect(
              'SELECT dive_type_id FROM dive_dive_types WHERE dive_id = ? '
              'ORDER BY dive_type_id',
              variables: [Variable.withString(id)],
            )
            .get())
      r.read<String>('dive_type_id'),
  ];

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

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  Future<void> openPreview(WidgetTester tester) async {
    await tester.tap(find.text('go'));
    await settle(tester);
  }

  testWidgets('the preview shows each change and the count', (tester) async {
    await pumpHost(tester);
    await openPreview(tester);
    expect(find.text('Apply rules to 2 dives?'), findsOneWidget);
    expect(find.text('1 dive will change.'), findsOneWidget);
    expect(find.textContaining('#411'), findsOneWidget);
    expect(
      find.text('Deep: dive types Recreational → Deep, Recreational'),
      findsOneWidget,
    );
  });

  testWidgets('Cancel changes nothing', (tester) async {
    await pumpHost(tester);
    await openPreview(tester);
    await tester.tap(find.text('Cancel'));
    await settle(tester);
    expect(await tester.runAsync(() => typesOf('d35')), isEmpty);
  });

  testWidgets('Apply writes and Undo reverts', (tester) async {
    await pumpHost(tester);
    await openPreview(tester);
    await tester.tap(find.text('Apply to 1 dive'));
    await settle(tester);
    expect(await tester.runAsync(() => typesOf('d35')), [
      'deep',
      'recreational',
    ]);
    expect(find.text('Rules changed 1 dive'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await settle(tester);
    expect(await tester.runAsync(() => typesOf('d35')), ['recreational']);
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
    await settle(tester);
    expect(find.text('Rules changed 1 dive'), findsOneWidget);
    // The widget whose ref started the run is disposed before Undo.
    show.value = false;
    await tester.pump();
    await tester.tap(find.text('Undo'));
    await settle(tester);
    expect(await tester.runAsync(() => typesOf('d35')), ['recreational']);
  });

  testWidgets('Apply recomputes when data moved after the preview', (
    tester,
  ) async {
    await pumpHost(tester);
    await openPreview(tester);
    await tester.runAsync(() => seedRuleDive(db, 'd50', maxDepth: 50));
    await tester.tap(find.text('Apply to 1 dive'));
    await settle(tester);
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
    await settle(tester);
    expect(
      find.text('No changes: these dives already match your rules.'),
      findsOneWidget,
    );
  });
}
