import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/query/names/name_index.dart';
import 'package:submersion/features/dive_log/domain/bulk_edit/bulk_edit_field_set.dart';
import 'package:submersion/features/rules/data/repositories/rule_repository.dart';
import 'package:submersion/features/rules/data/repositories/rule_run_repository.dart';
import 'package:submersion/features/rules/data/services/rule_engine.dart';
import 'package:submersion/features/rules/domain/entities/rule_action.dart';
import 'package:submersion/features/rules/domain/entities/rule_run.dart';
import 'package:submersion/features/rules/domain/rule_subject.dart';
import 'package:submersion/features/rules/presentation/pages/rule_history_page.dart';
import 'package:submersion/features/rules/presentation/pages/rule_run_page.dart';

import '../../../helpers/test_database.dart';
import '../rules_fixture.dart';
import 'rules_test_app.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    await seedRuleDivers(db, ['me']);
    await seedRuleDive(db, 'd35', maxDepth: 35, waterType: 'fresh');
    await seedRuleDive(db, 'd40', maxDepth: 40, waterType: 'fresh');
  });
  tearDown(tearDownTestDatabase);

  Future<String> runSalt(RuleRunTrigger trigger, {String? source}) async {
    final repo = RuleRepository();
    final all = await repo.getAll(
      subject: RuleSubject.dives,
      diverId: 'me',
      names: NameIndex(const []),
    );
    if (all.isEmpty) {
      await repo.create(
        diverId: 'me',
        subject: RuleSubject.dives,
        name: 'Salty',
        triggers: const {
          RuleTrigger.afterImport,
          RuleTrigger.afterManualCreate,
        },
        condition: depthOver(30),
        actions: const [
          SetDiveFieldAction(BulkField.waterType, {'waterType': 'salt'}),
        ],
      );
    }
    await db.customStatement("UPDATE dives SET water_type = 'fresh'");
    final r =
        await RuleEngine(
          names: (_) async => NameIndex(const []),
          deviceLabel: () async => 'MacBook',
        ).run(
          RuleRunRequest(
            diverId: 'me',
            trigger: trigger,
            sourceLabel: source,
            targets: const {RuleSubject.dives: null},
          ),
        );
    return r.runId!;
  }

  Future<List<String>> pumpHistory(WidgetTester tester) async {
    final pushed = await tester.runAsync(
      () => pumpRulesApp(
        tester,
        path: '/rules/history',
        home: (_) => const RuleHistoryPage(),
      ),
    );
    await settleRuleWork(tester);
    return pushed!;
  }

  testWidgets('lists runs newest first with what started them', (tester) async {
    await tester.runAsync(() async {
      await runSalt(RuleRunTrigger.imported, source: 'Perdix 2');
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await runSalt(RuleRunTrigger.onDemandAll);
    });
    await pumpHistory(tester);
    expect(find.text('Run by hand on everything'), findsOneWidget);
    expect(find.text('After import (Perdix 2)'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Run by hand on everything')).dy,
      lessThan(tester.getTopLeft(find.text('After import (Perdix 2)')).dy),
    );
    expect(find.textContaining('2 items changed by Salty'), findsNWidgets(2));
    expect(find.textContaining('on MacBook'), findsNWidgets(2));
  });

  testWidgets('Undo marks the run undone and reports skipped edits', (
    tester,
  ) async {
    late String run;
    await tester.runAsync(() async {
      run = await runSalt(RuleRunTrigger.imported);
      await db.customStatement(
        "UPDATE dives SET water_type = 'brackish' WHERE id = 'd35'",
      );
    });
    await pumpHistory(tester);
    await tester.tap(find.byTooltip('Undo this run'));
    await settleRuleWork(tester);
    expect(
      find.textContaining('1 item was edited after this run'),
      findsOneWidget,
    );
    expect(find.textContaining('Undone '), findsOneWidget);
    final r = await tester.runAsync(() => RuleRunRepository().getRun(run));
    expect(r!.isUndone, isTrue);
  });

  testWidgets('nothing undoable yet keeps Undo available', (tester) async {
    await tester.runAsync(() async {
      await runSalt(RuleRunTrigger.imported);
      await db.customStatement("UPDATE dives SET water_type = 'brackish'");
    });
    await pumpHistory(tester);
    await tester.tap(find.byTooltip('Undo this run'));
    await settleRuleWork(tester);
    expect(
      find.textContaining('Nothing to undo on this device yet'),
      findsOneWidget,
    );
    expect(find.byTooltip('Undo this run'), findsOneWidget);
  });

  testWidgets('tapping a run opens its change list', (tester) async {
    late String run;
    await tester.runAsync(() async {
      run = await runSalt(RuleRunTrigger.imported);
    });
    final pushed = await pumpHistory(tester);
    await tester.tap(find.text('After import'));
    await tester.pumpAndSettle();
    expect(pushed, ['/rules/history/$run']);
  });

  testWidgets('the run page lists the changes and undoes them', (tester) async {
    late String run;
    await tester.runAsync(() async {
      run = await runSalt(RuleRunTrigger.imported);
    });
    await tester.runAsync(
      () => pumpRulesApp(
        tester,
        path: '/rules/history/x',
        home: (_) => RuleRunPage(runId: run),
      ),
    );
    await settleRuleWork(tester);
    expect(
      find.text('Salty: water type Fresh Water → Salt Water'),
      findsNWidgets(2),
    );
    await tester.tap(find.text('Undo this run'));
    await settleRuleWork(tester);
    expect(find.text('Undone.'), findsOneWidget);
  });

  /// A run of profile 'other', not the active one, adding its own tag.
  Future<String> runOtherProfile() async {
    await seedRuleDivers(db, ['other']);
    await seedRuleDive(db, 'd50', diver: 'other', maxDepth: 50);
    await db.customStatement(
      'INSERT INTO tags (id, diver_id, name, created_at, updated_at) '
      "VALUES ('wrecky', 'other', 'Wrecky', 0, 0)",
    );
    await RuleRepository().create(
      diverId: 'other',
      subject: RuleSubject.dives,
      name: 'Wreck',
      triggers: const {RuleTrigger.afterImport},
      condition: depthOver(30),
      actions: const [
        DiveMembershipAction(DiveCollection.tags, MembershipMode.add, [
          'wrecky',
        ]),
      ],
    );
    final r = await RuleEngine(names: (_) async => NameIndex(const [])).run(
      const RuleRunRequest(
        diverId: 'other',
        trigger: RuleRunTrigger.imported,
        targets: {
          RuleSubject.dives: {'d50'},
        },
      ),
    );
    return r.runId!;
  }

  testWidgets('a history of given runs lists them whatever their profile', (
    tester,
  ) async {
    // A multi-profile import's See changes: each profile's run, though the
    // full history shows only the active profile's.
    late String mine;
    late String theirs;
    await tester.runAsync(() async {
      mine = await runSalt(RuleRunTrigger.imported);
      theirs = await runOtherProfile();
    });
    await tester.runAsync(
      () => pumpRulesApp(
        tester,
        path: '/rules/history',
        home: (_) => RuleHistoryPage(runIds: [mine, theirs]),
      ),
    );
    await settleRuleWork(tester);
    expect(find.text('After import'), findsNWidgets(2));
  });

  testWidgets('another profile\'s run names its own items', (tester) async {
    late String theirs;
    await tester.runAsync(() async {
      theirs = await runOtherProfile();
    });
    await tester.runAsync(
      () => pumpRulesApp(
        tester,
        path: '/rules/history/x',
        home: (_) => RuleRunPage(runId: theirs),
      ),
    );
    await settleRuleWork(tester);
    expect(find.textContaining('Wrecky'), findsWidgets);
    expect(find.textContaining('(deleted)'), findsNothing);
  });

  testWidgets('Clear history removes every run after confirming', (
    tester,
  ) async {
    await tester.runAsync(() => runSalt(RuleRunTrigger.imported));
    await pumpHistory(tester);
    await tester.tap(find.byKey(const ValueKey('rules_history_menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear history'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Clear history'));
    await settleRuleWork(tester);
    expect(find.textContaining('Each time your rules change'), findsOneWidget);
  });
}
