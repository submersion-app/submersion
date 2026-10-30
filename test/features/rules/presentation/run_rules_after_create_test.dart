import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/rules/data/repositories/rule_repository.dart';
import 'package:submersion/features/rules/data/services/rule_engine.dart';
import 'package:submersion/features/rules/domain/entities/rule_action.dart';
import 'package:submersion/features/rules/domain/rule_subject.dart';
import 'package:submersion/features/rules/presentation/providers/rule_providers.dart';
import 'package:submersion/features/rules/presentation/run_rules_flow.dart';

import '../../../helpers/test_database.dart';
import '../rules_fixture.dart';
import 'rules_test_app.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    await seedRuleDivers(db, ['me']);
    await seedRuleDive(db, 'd35', maxDepth: 35);
    await seedRuleSite(db, 's1', country: 'Egypt');
    await db.customStatement(
      "INSERT INTO tags (id, name, created_at, updated_at, applies_to_sites) "
      "VALUES ('red', 'Red Sea', 0, 0, 1)",
    );
  });
  tearDown(tearDownTestDatabase);

  Future<void> rule(
    RuleSubject subject,
    Set<RuleTrigger> triggers,
    RuleAction action,
  ) => RuleRepository().create(
    diverId: 'me',
    subject: subject,
    name: subject == RuleSubject.dives ? 'Deep' : 'Red Sea',
    triggers: triggers,
    condition: subject == RuleSubject.dives ? depthOver(30) : null,
    actions: [action],
  );

  Future<List<String>> pumpAndRun(
    WidgetTester tester,
    RuleSubject subject,
    List<String> ids, {
    List<dynamic> extra = const [],
  }) async {
    final pushed = await tester.runAsync(
      () => pumpRulesApp(
        tester,
        extra: extra,
        path: '/host',
        home: (_) => Scaffold(
          body: Consumer(
            builder: (context, ref, _) => Center(
              child: ElevatedButton(
                onPressed: () => runRulesAfterCreate(
                  context,
                  ref,
                  subject: subject,
                  ids: ids,
                ),
                child: const Text('saved'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('saved'));
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
    return pushed!;
  }

  testWidgets('a hand-logged dive gets its type and a snackbar', (
    tester,
  ) async {
    await tester.runAsync(
      () => rule(RuleSubject.dives, {
        RuleTrigger.afterManualCreate,
      }, kAddDeepType),
    );
    final pushed = await pumpAndRun(tester, RuleSubject.dives, ['d35']);
    expect(await tester.runAsync(() => ruleDiveTypes(db, 'd35')), [
      'deep',
      'recreational',
    ]);
    expect(find.text('Rules changed this dive: Deep'), findsOneWidget);
    await tester.tap(find.text('Details'));
    await tester.pumpAndSettle();
    expect(pushed.single, startsWith('/rules/history/'));
  });

  testWidgets('a skipped action is reported though nothing changed', (
    tester,
  ) async {
    await tester.runAsync(
      () => rule(
        RuleSubject.dives,
        {RuleTrigger.afterManualCreate},
        const DiveMembershipAction(DiveCollection.tags, MembershipMode.add, [
          'deleted',
        ]),
      ),
    );
    await pumpAndRun(tester, RuleSubject.dives, ['d35']);
    expect(
      find.text('Some actions name deleted items and were skipped: Deep'),
      findsOneWidget,
    );
  });

  testWidgets('rules failing after a save say the save stands', (tester) async {
    await tester.runAsync(
      () => rule(RuleSubject.dives, {
        RuleTrigger.afterManualCreate,
      }, kAddDeepType),
    );
    await pumpAndRun(
      tester,
      RuleSubject.dives,
      ['d35'],
      extra: [
        ruleEngineProvider.overrideWithValue(
          RuleEngine(names: (_) => throw StateError('names failed')),
        ),
      ],
    );
    expect(find.text('Saved, but your rules could not run.'), findsOneWidget);
  });

  testWidgets('an after-import-only rule does not run', (tester) async {
    await tester.runAsync(
      () => rule(RuleSubject.dives, {RuleTrigger.afterImport}, kAddDeepType),
    );
    await pumpAndRun(tester, RuleSubject.dives, ['d35']);
    expect(await tester.runAsync(() => ruleDiveTypes(db, 'd35')), isEmpty);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('a site created by hand gets the site rule\'s tag', (
    tester,
  ) async {
    await tester.runAsync(
      () => rule(
        RuleSubject.sites,
        {RuleTrigger.afterManualCreate},
        const SiteMembershipAction(SiteCollection.tags, MembershipMode.add, [
          'red',
        ]),
      ),
    );
    await pumpAndRun(tester, RuleSubject.sites, ['s1']);
    final tags = await tester.runAsync(
      () => db
          .customSelect("SELECT tag_id FROM site_tags WHERE site_id = 's1'")
          .get(),
    );
    expect(tags!.single.read<String>('tag_id'), 'red');
    expect(find.text('Rules changed this site: Red Sea'), findsOneWidget);
  });
}
